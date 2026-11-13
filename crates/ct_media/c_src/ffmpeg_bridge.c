#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>
#include <time.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/audio_fifo.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <opus/opus.h>

typedef void (*CtLogCallback)(int level, const char *msg);

typedef struct {
    AVFormatContext *fmt_ctx;
    AVStream *video_st;
    AVStream *audio_st;

    int video_codec_id;
    int width;
    int height;
    int fps;

    int audio_enabled;
    int audio_codec_type; // 0=Opus, 1=FLAC, 2=PCM, 3=Custom
    int in_sample_rate;
    int channels;
    int audio_bitrate;
    int opus_vbr_mode;
    int audio_complexity;
    int opus_frame_samples; // samples per channel at 48kHz

    OpusEncoder *opus_enc;
    AVCodecContext *audio_enc_ctx;
    SwrContext *swr_ctx;
    AVAudioFifo *audio_fifo;

    AVFilterGraph *filter_graph;
    AVFilterContext *abuffer_ctx;
    AVFilterContext *abuffersink_ctx;

    int header_written;
    int64_t base_pts_us;
    int64_t last_video_dts_us;
    int64_t audio_samples_written;

    pthread_mutex_t mux_lock;
    CtLogCallback log_cb;
    char last_error[512];
} CtFfmpegBridge;

static int64_t monotonic_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000LL + (int64_t)ts.tv_nsec / 1000LL;
}

static void bridge_log(CtFfmpegBridge *b, int level, const char *fmt, ...) {
    char buf[512];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    if (level >= 2) {
        snprintf(b->last_error, sizeof(b->last_error), "%s", buf);
    }
    if (b->log_cb) {
        b->log_cb(level, buf);
    }
}

static void write_le16(uint8_t *p, uint16_t v) {
    p[0] = (uint8_t)(v & 0xFF);
    p[1] = (uint8_t)((v >> 8) & 0xFF);
}

static void write_le32(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v & 0xFF);
    p[1] = (uint8_t)((v >> 8) & 0xFF);
    p[2] = (uint8_t)((v >> 16) & 0xFF);
    p[3] = (uint8_t)((v >> 24) & 0xFF);
}

static enum AVSampleFormat pick_encoder_sample_fmt(const AVCodec *codec, enum AVSampleFormat preferred) {
    const enum AVSampleFormat *fmts = NULL;
    int num_fmts = 0;
#if LIBAVCODEC_VERSION_MAJOR >= 61
    if (avcodec_get_supported_config(NULL, codec, AV_CODEC_CONFIG_SAMPLE_FORMAT, 0,
                                     (const void **)&fmts, &num_fmts) == 0 && fmts && num_fmts > 0) {
        for (int i = 0; i < num_fmts; i++) {
            if (fmts[i] == preferred) return preferred;
        }
        return fmts[0];
    }
#endif
    return preferred;
}

static void parse_custom_audio_args(const char *args, char *out_codec, size_t codec_sz,
                                    char *out_filter, size_t filter_sz, int *out_bitrate) {
    out_codec[0] = '\0';
    out_filter[0] = '\0';
    if (!args || !args[0]) return;

    char *copy = strdup(args);
    char *saveptr = NULL;
    char *tok = strtok_r(copy, " \t\n", &saveptr);
    while (tok) {
        if (strcmp(tok, "-c:a") == 0 || strcmp(tok, "-acodec") == 0) {
            char *val = strtok_r(NULL, " \t\n", &saveptr);
            if (val) snprintf(out_codec, codec_sz, "%s", val);
        } else if (strcmp(tok, "-b:a") == 0) {
            char *val = strtok_r(NULL, " \t\n", &saveptr);
            if (val) {
                int br = atoi(val);
                if (strchr(val, 'k') || strchr(val, 'K')) br *= 1000;
                if (br > 0) *out_bitrate = br;
            }
        } else if (strcmp(tok, "-af") == 0 || strcmp(tok, "-filter:a") == 0) {
            char *val = strtok_r(NULL, " \t\n", &saveptr);
            if (val) snprintf(out_filter, filter_sz, "%s", val);
        }
        tok = strtok_r(NULL, " \t\n", &saveptr);
    }
    free(copy);
}

static int init_audio_filter(CtFfmpegBridge *b, const char *filter_desc,
                             int target_rate, enum AVSampleFormat target_fmt) {
    if (!filter_desc || !filter_desc[0]) return 0;

    char args[256];
    char ch_str[64];
    AVChannelLayout in_layout;
    av_channel_layout_default(&in_layout, b->channels);
    av_channel_layout_describe(&in_layout, ch_str, sizeof(ch_str));

    snprintf(args, sizeof(args),
             "time_base=1/%d:sample_rate=%d:sample_fmt=%s:channel_layout=%s",
             b->in_sample_rate, b->in_sample_rate,
             av_get_sample_fmt_name(AV_SAMPLE_FMT_S16), ch_str);

    b->filter_graph = avfilter_graph_alloc();
    if (!b->filter_graph) return -1;

    const AVFilter *abuffersrc = avfilter_get_by_name("abuffer");
    const AVFilter *abuffersink = avfilter_get_by_name("abuffersink");
    if (!abuffersrc || !abuffersink) return -2;

    if (avfilter_graph_create_filter(&b->abuffer_ctx, abuffersrc, "in", args, NULL, b->filter_graph) < 0)
        return -3;
    if (avfilter_graph_create_filter(&b->abuffersink_ctx, abuffersink, "out", NULL, NULL, b->filter_graph) < 0)
        return -4;

    AVFilterInOut *outputs = avfilter_inout_alloc();
    AVFilterInOut *inputs = avfilter_inout_alloc();
    outputs->name = av_strdup("in");
    outputs->filter_ctx = b->abuffer_ctx;
    outputs->pad_idx = 0;
    outputs->next = NULL;

    inputs->name = av_strdup("out");
    inputs->filter_ctx = b->abuffersink_ctx;
    inputs->pad_idx = 0;
    inputs->next = NULL;

    int ret = avfilter_graph_parse_ptr(b->filter_graph, filter_desc, &inputs, &outputs, NULL);
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);
    if (ret < 0) return -5;

    ret = avfilter_graph_config(b->filter_graph, NULL);
    if (ret < 0) return -6;

    bridge_log(b, 0, "Audio filter graph initialized: %s", filter_desc);
    return 0;
}

CtFfmpegBridge *ct_ff_create(
    const char *output_path,
    const char *mime_type,
    int width,
    int height,
    int fps,
    int audio_enabled,
    int audio_codec_type,
    int sample_rate,
    int channels,
    int audio_bitrate,
    int opus_vbr_mode,
    int audio_complexity,
    float opus_frame_ms,
    int flac_bit_depth,
    const char *wav_fmt,
    const char *custom_audio_args,
    CtLogCallback log_cb
) {
    CtFfmpegBridge *b = (CtFfmpegBridge *)calloc(1, sizeof(CtFfmpegBridge));
    if (!b) return NULL;

    pthread_mutex_init(&b->mux_lock, NULL);
    b->log_cb = log_cb;
    b->width = width;
    b->height = height;
    b->fps = fps > 0 ? fps : 30;
    b->base_pts_us = monotonic_us();
    b->last_video_dts_us = -1;

    const char *fmt_name = "matroska";
    size_t plen = strlen(output_path);
    if (plen >= 4 && strcmp(output_path + plen - 4, ".mp4") == 0) {
        fmt_name = "mp4";
    }

    if (avformat_alloc_output_context2(&b->fmt_ctx, NULL, fmt_name, output_path) < 0 || !b->fmt_ctx) {
        bridge_log(b, 2, "avformat_alloc_output_context2 failed for %s (%s)", output_path, fmt_name);
        free(b);
        return NULL;
    }

    // 1. Setup Video Stream
    b->video_st = avformat_new_stream(b->fmt_ctx, NULL);
    if (!b->video_st) {
        bridge_log(b, 2, "Failed to allocate video stream");
        avformat_free_context(b->fmt_ctx);
        free(b);
        return NULL;
    }

    enum AVCodecID v_id = AV_CODEC_ID_H264;
    if (mime_type && strcmp(mime_type, "video/hevc") == 0) v_id = AV_CODEC_ID_HEVC;
    else if (mime_type && strcmp(mime_type, "video/av01") == 0) v_id = AV_CODEC_ID_AV1;

    b->video_codec_id = v_id;
    b->video_st->codecpar->codec_type = AVMEDIA_TYPE_VIDEO;
    b->video_st->codecpar->codec_id = v_id;
    b->video_st->codecpar->width = width;
    b->video_st->codecpar->height = height;
    b->video_st->codecpar->format = AV_PIX_FMT_YUV420P;
    b->video_st->avg_frame_rate = (AVRational){b->fps, 1};
    b->video_st->r_frame_rate = (AVRational){b->fps, 1};
    b->video_st->time_base = (AVRational){1, 1000000};

    // 2. Setup Audio Stream if enabled
    b->audio_enabled = audio_enabled;
    if (audio_enabled) {
        b->audio_codec_type = audio_codec_type;
        b->in_sample_rate = sample_rate > 0 ? sample_rate : 48000;
        b->channels = (channels == 1) ? 1 : 2;
        b->audio_bitrate = audio_bitrate > 0 ? audio_bitrate : 128000;
        b->opus_vbr_mode = opus_vbr_mode;
        b->audio_complexity = audio_complexity;

        char custom_codec[64];
        char custom_filter[256];
        parse_custom_audio_args(custom_audio_args, custom_codec, sizeof(custom_codec),
                                custom_filter, sizeof(custom_filter), &b->audio_bitrate);

        b->audio_st = avformat_new_stream(b->fmt_ctx, NULL);
        if (!b->audio_st) {
            bridge_log(b, 2, "Failed to allocate audio stream");
            avformat_free_context(b->fmt_ctx);
            free(b);
            return NULL;
        }

        int use_xiph_opus = (audio_codec_type == 0) &&
                            (custom_codec[0] == '\0' || strcmp(custom_codec, "libopus") == 0 || strcmp(custom_codec, "opus") == 0);

        if (use_xiph_opus) {
            int opus_err = 0;
            b->opus_enc = opus_encoder_create(48000, b->channels, OPUS_APPLICATION_AUDIO, &opus_err);
            if (!b->opus_enc || opus_err != OPUS_OK) {
                bridge_log(b, 2, "opus_encoder_create failed: %s", opus_strerror(opus_err));
                avformat_free_context(b->fmt_ctx);
                free(b);
                return NULL;
            }

            int clamped_br = b->audio_bitrate;
            if (clamped_br < 6000) clamped_br = 6000;
            if (clamped_br > 510000) clamped_br = 510000;

            opus_encoder_ctl(b->opus_enc, OPUS_SET_BITRATE(clamped_br));
            opus_encoder_ctl(b->opus_enc, OPUS_SET_VBR(opus_vbr_mode == 0 ? 0 : 1));
            opus_encoder_ctl(b->opus_enc, OPUS_SET_VBR_CONSTRAINT(opus_vbr_mode == 2 ? 1 : 0));
            int comp = audio_complexity < 0 ? 0 : (audio_complexity > 10 ? 10 : audio_complexity);
            opus_encoder_ctl(b->opus_enc, OPUS_SET_COMPLEXITY(comp));

            opus_int32 lookahead = 312;
            opus_encoder_ctl(b->opus_enc, OPUS_GET_LOOKAHEAD(&lookahead));

            // Exact frame size in samples per channel at 48kHz
            int fs = (int)(48.0f * opus_frame_ms + 0.5f);
            if (fs != 120 && fs != 240 && fs != 480 && fs != 960 && fs != 1920 && fs != 2880) {
                fs = 960;
            }
            b->opus_frame_samples = fs;

            uint8_t *opus_head = (uint8_t *)av_mallocz(19 + AV_INPUT_BUFFER_PADDING_SIZE);
            memcpy(opus_head, "OpusHead", 8);
            opus_head[8] = 1; // Version
            opus_head[9] = (uint8_t)b->channels;
            write_le16(opus_head + 10, (uint16_t)lookahead);
            write_le32(opus_head + 12, (uint32_t)b->in_sample_rate);
            write_le16(opus_head + 16, 0);
            opus_head[18] = 0;

            b->audio_st->codecpar->codec_type = AVMEDIA_TYPE_AUDIO;
            b->audio_st->codecpar->codec_id = AV_CODEC_ID_OPUS;
            b->audio_st->codecpar->sample_rate = 48000;
            b->audio_st->codecpar->bit_rate = clamped_br;
            av_channel_layout_default(&b->audio_st->codecpar->ch_layout, b->channels);
            b->audio_st->codecpar->extradata = opus_head;
            b->audio_st->codecpar->extradata_size = 19;
            b->audio_st->time_base = (AVRational){1, 48000};

            AVChannelLayout in_l, out_l;
            av_channel_layout_default(&in_l, b->channels);
            av_channel_layout_default(&out_l, b->channels);
            swr_alloc_set_opts2(&b->swr_ctx, &out_l, AV_SAMPLE_FMT_S16, 48000,
                                &in_l, AV_SAMPLE_FMT_S16, b->in_sample_rate, 0, NULL);
            if (b->swr_ctx) swr_init(b->swr_ctx);
            b->audio_fifo = av_audio_fifo_alloc(AV_SAMPLE_FMT_S16, b->channels, 48000 * 2);

            bridge_log(b, 0, "Xiph libopus configured: %d bps, vbr=%d, comp=%d, frame=%d samples",
                       clamped_br, opus_vbr_mode, comp, fs);
        } else {
            const char *codec_name = "flac";
            if (custom_codec[0] != '\0') {
                codec_name = custom_codec;
            } else if (audio_codec_type == 1) {
                codec_name = "flac";
            } else if (audio_codec_type == 2) {
                codec_name = (wav_fmt && wav_fmt[0]) ? wav_fmt : "pcm_s16le";
            }

            const AVCodec *acodec = avcodec_find_encoder_by_name(codec_name);
            if (!acodec) {
                bridge_log(b, 2, "FFmpeg audio encoder not found: %s", codec_name);
                avformat_free_context(b->fmt_ctx);
                free(b);
                return NULL;
            }

            b->audio_enc_ctx = avcodec_alloc_context3(acodec);
            b->audio_enc_ctx->sample_rate = b->in_sample_rate;
            av_channel_layout_default(&b->audio_enc_ctx->ch_layout, b->channels);
            b->audio_enc_ctx->bit_rate = b->audio_bitrate;

            enum AVSampleFormat pref_fmt = AV_SAMPLE_FMT_S16;
            if (audio_codec_type == 1 && flac_bit_depth == 24) pref_fmt = AV_SAMPLE_FMT_S32;
            else if (strcmp(codec_name, "pcm_s24le") == 0 || strcmp(codec_name, "pcm_s32le") == 0) pref_fmt = AV_SAMPLE_FMT_S32;
            else if (strcmp(codec_name, "pcm_f32le") == 0) pref_fmt = AV_SAMPLE_FMT_FLT;

            b->audio_enc_ctx->sample_fmt = pick_encoder_sample_fmt(acodec, pref_fmt);
            b->audio_enc_ctx->time_base = (AVRational){1, b->in_sample_rate};
            if (audio_codec_type == 1) {
                b->audio_enc_ctx->compression_level = audio_complexity;
                if (flac_bit_depth == 24) {
                    b->audio_enc_ctx->bits_per_raw_sample = 24;
                }
            }
            if (b->fmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
                b->audio_enc_ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
            }

            if (avcodec_open2(b->audio_enc_ctx, acodec, NULL) < 0) {
                bridge_log(b, 2, "avcodec_open2 failed for audio encoder: %s", codec_name);
                avcodec_free_context(&b->audio_enc_ctx);
                avformat_free_context(b->fmt_ctx);
                free(b);
                return NULL;
            }

            avcodec_parameters_from_context(b->audio_st->codecpar, b->audio_enc_ctx);
            b->audio_st->time_base = b->audio_enc_ctx->time_base;

            AVChannelLayout in_l;
            av_channel_layout_default(&in_l, b->channels);
            swr_alloc_set_opts2(&b->swr_ctx, &b->audio_enc_ctx->ch_layout,
                                b->audio_enc_ctx->sample_fmt, b->audio_enc_ctx->sample_rate,
                                &in_l, AV_SAMPLE_FMT_S16, b->in_sample_rate, 0, NULL);
            if (b->swr_ctx) swr_init(b->swr_ctx);
            b->audio_fifo = av_audio_fifo_alloc(b->audio_enc_ctx->sample_fmt, b->channels, b->in_sample_rate * 2);

            bridge_log(b, 0, "FFmpeg audio encoder opened: %s (%d Hz)", codec_name, b->in_sample_rate);
        }

        if (custom_filter[0] != '\0') {
            if (init_audio_filter(b, custom_filter, b->in_sample_rate, AV_SAMPLE_FMT_S16) != 0) {
                bridge_log(b, 1, "Failed to parse audio filter '%s'; continuing unfiltered", custom_filter);
                if (b->filter_graph) {
                    avfilter_graph_free(&b->filter_graph);
                    b->abuffer_ctx = NULL;
                    b->abuffersink_ctx = NULL;
                }
            }
        }
    }

    if (!(b->fmt_ctx->oformat->flags & AVFMT_NOFILE)) {
        if (avio_open(&b->fmt_ctx->pb, output_path, AVIO_FLAG_WRITE) < 0) {
            bridge_log(b, 2, "avio_open failed for %s", output_path);
            avformat_free_context(b->fmt_ctx);
            free(b);
            return NULL;
        }
    }

    return b;
}

int ct_ff_set_video_csd_and_write_header(CtFfmpegBridge *b, const uint8_t *csd, int csd_len) {
    if (!b || !csd || csd_len <= 0) return -1;

    pthread_mutex_lock(&b->mux_lock);
    if (b->header_written) {
        pthread_mutex_unlock(&b->mux_lock);
        return 0;
    }

    uint8_t *extra = (uint8_t *)av_mallocz((size_t)csd_len + AV_INPUT_BUFFER_PADDING_SIZE);
    if (!extra) {
        pthread_mutex_unlock(&b->mux_lock);
        return -2;
    }
    memcpy(extra, csd, (size_t)csd_len);
    b->video_st->codecpar->extradata = extra;
    b->video_st->codecpar->extradata_size = csd_len;

    AVDictionary *opts = NULL;
    if (strcmp(b->fmt_ctx->oformat->name, "mp4") == 0) {
        av_dict_set(&opts, "movflags", "frag_keyframe+empty_moov+default_base_moof", 0);
    }

    int ret = avformat_write_header(b->fmt_ctx, &opts);
    av_dict_free(&opts);
    if (ret < 0) {
        char errbuf[128];
        av_strerror(ret, errbuf, sizeof(errbuf));
        bridge_log(b, 2, "avformat_write_header failed: %s", errbuf);
        pthread_mutex_unlock(&b->mux_lock);
        return ret;
    }

    b->header_written = 1;
    bridge_log(b, 0, "FFmpeg container header written (%s)", b->fmt_ctx->oformat->name);
    pthread_mutex_unlock(&b->mux_lock);
    return 0;
}

int ct_ff_write_video_packet(CtFfmpegBridge *b, const uint8_t *data, int len,
                             int64_t pts_us, int is_keyframe) {
    if (!b || !data || len <= 0) return -1;

    pthread_mutex_lock(&b->mux_lock);
    if (!b->header_written) {
        pthread_mutex_unlock(&b->mux_lock);
        return 0;
    }

    int64_t rel_us = pts_us - b->base_pts_us;
    if (rel_us < 0) rel_us = 0;
    if (rel_us <= b->last_video_dts_us) {
        rel_us = b->last_video_dts_us + 1;
    }
    b->last_video_dts_us = rel_us;

    AVPacket *pkt = av_packet_alloc();
    if (!pkt) {
        pthread_mutex_unlock(&b->mux_lock);
        return -2;
    }
    if (av_new_packet(pkt, len) < 0) {
        av_packet_free(&pkt);
        pthread_mutex_unlock(&b->mux_lock);
        return -3;
    }

    memcpy(pkt->data, data, (size_t)len);
    pkt->stream_index = b->video_st->index;
    pkt->pts = rel_us;
    pkt->dts = rel_us;
    pkt->duration = 1000000 / b->fps;
    if (is_keyframe) pkt->flags |= AV_PKT_FLAG_KEY;

    av_packet_rescale_ts(pkt, (AVRational){1, 1000000}, b->video_st->time_base);
    int ret = av_interleaved_write_frame(b->fmt_ctx, pkt);
    if (is_keyframe && b->fmt_ctx->pb) {
        avio_flush(b->fmt_ctx->pb);
    }
    av_packet_free(&pkt);
    pthread_mutex_unlock(&b->mux_lock);
    return ret;
}

static void drain_encoded_audio(CtFfmpegBridge *b, int flush) {
    if (b->opus_enc) {
        uint8_t out_buf[4096];
        int frame_sz = b->opus_frame_samples;
        int16_t *pcm = (int16_t *)alloca((size_t)frame_sz * (size_t)b->channels * sizeof(int16_t));

        while (av_audio_fifo_size(b->audio_fifo) >= frame_sz) {
            void *ptrs[1] = { pcm };
            av_audio_fifo_read(b->audio_fifo, ptrs, frame_sz);

            int bytes = opus_encode(b->opus_enc, pcm, frame_sz, out_buf, sizeof(out_buf));
            if (bytes > 2) {
                AVPacket *pkt = av_packet_alloc();
                if (pkt && av_new_packet(pkt, bytes) == 0) {
                    memcpy(pkt->data, out_buf, (size_t)bytes);
                    pkt->stream_index = b->audio_st->index;
                    pkt->pts = b->audio_samples_written;
                    pkt->dts = b->audio_samples_written;
                    pkt->duration = frame_sz;
                    av_packet_rescale_ts(pkt, (AVRational){1, 48000}, b->audio_st->time_base);
                    av_interleaved_write_frame(b->fmt_ctx, pkt);
                    av_packet_free(&pkt);
                }
            }
            b->audio_samples_written += frame_sz;
        }
    } else if (b->audio_enc_ctx) {
        int frame_sz = b->audio_enc_ctx->frame_size > 0 ? b->audio_enc_ctx->frame_size : 1024;
        while (av_audio_fifo_size(b->audio_fifo) >= frame_sz || (flush && av_audio_fifo_size(b->audio_fifo) > 0)) {
            int n = av_audio_fifo_size(b->audio_fifo);
            if (n > frame_sz) n = frame_sz;

            AVFrame *frame = av_frame_alloc();
            frame->nb_samples = n;
            av_channel_layout_copy(&frame->ch_layout, &b->audio_enc_ctx->ch_layout);
            frame->format = b->audio_enc_ctx->sample_fmt;
            frame->sample_rate = b->audio_enc_ctx->sample_rate;
            if (av_frame_get_buffer(frame, 0) < 0) {
                av_frame_free(&frame);
                break;
            }
            av_audio_fifo_read(b->audio_fifo, (void **)frame->data, n);
            frame->pts = b->audio_samples_written;
            b->audio_samples_written += n;

            avcodec_send_frame(b->audio_enc_ctx, frame);
            av_frame_free(&frame);

            AVPacket *pkt = av_packet_alloc();
            while (avcodec_receive_packet(b->audio_enc_ctx, pkt) == 0) {
                pkt->stream_index = b->audio_st->index;
                av_packet_rescale_ts(pkt, b->audio_enc_ctx->time_base, b->audio_st->time_base);
                av_interleaved_write_frame(b->fmt_ctx, pkt);
                av_packet_unref(pkt);
            }
            av_packet_free(&pkt);
        }

        if (flush) {
            avcodec_send_frame(b->audio_enc_ctx, NULL);
            AVPacket *pkt = av_packet_alloc();
            while (avcodec_receive_packet(b->audio_enc_ctx, pkt) == 0) {
                pkt->stream_index = b->audio_st->index;
                av_packet_rescale_ts(pkt, b->audio_enc_ctx->time_base, b->audio_st->time_base);
                av_interleaved_write_frame(b->fmt_ctx, pkt);
                av_packet_unref(pkt);
            }
            av_packet_free(&pkt);
        }
    }
}

static void feed_swr_and_fifo(CtFfmpegBridge *b, const uint8_t **in_data, int nb_samples) {
    int out_rate = b->opus_enc ? 48000 : b->audio_enc_ctx->sample_rate;
    enum AVSampleFormat out_fmt = b->opus_enc ? AV_SAMPLE_FMT_S16 : b->audio_enc_ctx->sample_fmt;
    int max_out = swr_get_out_samples(b->swr_ctx, nb_samples);
    if (max_out <= 0) max_out = nb_samples + 256;

    uint8_t **converted = NULL;
    int linesize = 0;
    if (av_samples_alloc_array_and_samples(&converted, &linesize, b->channels, max_out, out_fmt, 0) < 0)
        return;

    int out_samples = swr_convert(b->swr_ctx, converted, max_out, in_data, nb_samples);
    if (out_samples > 0) {
        av_audio_fifo_write(b->audio_fifo, (void **)converted, out_samples);
        drain_encoded_audio(b, 0);
    }

    if (converted) {
        av_freep(&converted[0]);
        av_freep(&converted);
    }
}

int ct_ff_push_audio_pcm(CtFfmpegBridge *b, const int16_t *pcm_s16, int nb_samples_per_ch) {
    if (!b || !b->audio_enabled || !pcm_s16 || nb_samples_per_ch <= 0) return -1;

    pthread_mutex_lock(&b->mux_lock);
    if (!b->header_written) {
        pthread_mutex_unlock(&b->mux_lock);
        return 0;
    }

    if (b->filter_graph && b->abuffer_ctx && b->abuffersink_ctx) {
        AVFrame *in_f = av_frame_alloc();
        in_f->nb_samples = nb_samples_per_ch;
        in_f->sample_rate = b->in_sample_rate;
        in_f->format = AV_SAMPLE_FMT_S16;
        av_channel_layout_default(&in_f->ch_layout, b->channels);
        if (av_frame_get_buffer(in_f, 0) == 0) {
            memcpy(in_f->data[0], pcm_s16, (size_t)nb_samples_per_ch * (size_t)b->channels * sizeof(int16_t));
            av_buffersrc_add_frame_flags(b->abuffer_ctx, in_f, AV_BUFFERSRC_FLAG_KEEP_REF);
            AVFrame *out_f = av_frame_alloc();
            while (av_buffersink_get_frame(b->abuffersink_ctx, out_f) >= 0) {
                feed_swr_and_fifo(b, (const uint8_t **)out_f->data, out_f->nb_samples);
                av_frame_unref(out_f);
            }
            av_frame_free(&out_f);
        }
        av_frame_free(&in_f);
    } else {
        const uint8_t *in_ptr[1] = { (const uint8_t *)pcm_s16 };
        feed_swr_and_fifo(b, in_ptr, nb_samples_per_ch);
    }

    pthread_mutex_unlock(&b->mux_lock);
    return 0;
}

void ct_ff_finish_and_destroy(CtFfmpegBridge *b) {
    if (!b) return;

    pthread_mutex_lock(&b->mux_lock);
    if (b->header_written) {
        if (b->audio_enabled) {
            drain_encoded_audio(b, 1);
        }
        av_write_trailer(b->fmt_ctx);
        bridge_log(b, 0, "FFmpeg trailer finalized cleanly");
    }

    if (b->fmt_ctx && !(b->fmt_ctx->oformat->flags & AVFMT_NOFILE)) {
        avio_closep(&b->fmt_ctx->pb);
    }
    if (b->fmt_ctx) avformat_free_context(b->fmt_ctx);
    if (b->opus_enc) opus_encoder_destroy(b->opus_enc);
    if (b->audio_enc_ctx) avcodec_free_context(&b->audio_enc_ctx);
    if (b->swr_ctx) swr_free(&b->swr_ctx);
    if (b->audio_fifo) av_audio_fifo_free(b->audio_fifo);
    if (b->filter_graph) avfilter_graph_free(&b->filter_graph);

    pthread_mutex_unlock(&b->mux_lock);
    pthread_mutex_destroy(&b->mux_lock);
    free(b);
}

const char *ct_ff_last_error(CtFfmpegBridge *b) {
    return b ? b->last_error : "";
}
