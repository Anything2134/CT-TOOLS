use ffmpeg_next as ffmpeg;
use ffmpeg::codec::Id;
use ffmpeg::format::context::Output;
use ffmpeg::format::Pixel;
use std::path::Path;

pub struct StreamMuxer {
    output_context: Output,
        stream_index: usize,
        }

        impl StreamMuxer {
            /// Sets up an FFmpeg muxing context without invoking CPU re-encoding.
                pub fn new(output_file: &str, width: i32, height: i32) -> Result<Self, ffmpeg::Error> {
                        ffmpeg::init()?;
                                let mut out_ctx = ffmpeg::format::output(&Path::new(output_file))?;
                                        
                                                let codec = ffmpeg::encoder::find(Id::H264)
                                                            .ok_or(ffmpeg::Error::EncoderNotFound)?;

                                                                    let mut stream = out_ctx.add_stream(codec)?;
                                                                            let stream_index = stream.index();

                                                                                    unsafe {
                                                                                                let codec_params = (*stream.as_mut_ptr()).codecpar;
                                                                                                            (*codec_params).codec_type = ffmpeg::sys::AVMEDIA_TYPE_VIDEO;
                                                                                                                        (*codec_params).codec_id = ffmpeg::sys::AV_CODEC_ID_H264;
                                                                                                                                    (*codec_params).width = width;
                                                                                                                                                (*codec_params).height = height;
                                                                                                                                                            (*codec_params).format = Pixel::YUV420P as i32;
                                                                                                                                                                    }

                                                                                                                                                                            out_ctx.write_header()?;
                                                                                                                                                                                    Ok(Self {
                                                                                                                                                                                                output_context: out_ctx,
                                                                                                                                                                                                            stream_index,
                                                                                                                                                                                                                    })
                                                                                                                                                                                                                        }

                                                                                                                                                                                                                            /// Writes a pre-encoded packet directly into the container.
                                                                                                                                                                                                                                pub fn write_packet(&mut self, data: &[u8], pts_us: i64, is_keyframe: bool) -> Result<(), ffmpeg::Error> {
                                                                                                                                                                                                                                        let mut packet = ffmpeg::Packet::copy(data);
                                                                                                                                                                                                                                                // Rescale PTS from microseconds to stream timebase
                                                                                                                                                                                                                                                        packet.set_pts(Some(pts_us));
                                                                                                                                                                                                                                                                packet.set_dts(Some(pts_us));
                                                                                                                                                                                                                                                                        packet.set_stream(self.stream_index);
                                                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                                                        if is_keyframe {
                                                                                                                                                                                                                                                                                                    packet.set_flags(ffmpeg::packet::Flags::KEY);
                                                                                                                                                                                                                                                                                                            }

                                                                                                                                                                                                                                                                                                                    packet.write_interleaved(&mut self.output_context)?;
                                                                                                                                                                                                                                                                                                                            Ok(())
                                                                                                                                                                                                                                                                                                                                }

                                                                                                                                                                                                                                                                                                                                    pub fn finalize(&mut self) -> Result<(), ffmpeg::Error> {
                                                                                                                                                                                                                                                                                                                                            self.output_context.write_trailer()?;
                                                                                                                                                                                                                                                                                                                                                    Ok(())
                                                                                                                                                                                                                                                                                                                                                        }
                                                                                                                                                                                                                                                                                                                                                        }