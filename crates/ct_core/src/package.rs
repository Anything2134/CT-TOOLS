use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

/// Defines the transport origin used to fetch a module, package, or hot-update.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PackageOrigin {
    /// Traditional HTTP/HTTPS repository URL.
        HttpUrl { url: String },
            /// Content-addressed P2P swarm identifier and bootstrap peer addresses.
                P2pSwarm {
                        info_hash: String,
                                bootstrap_peers: Vec<String>,
                                        chunk_size_bytes: usize,
                                            },
                                                /// Hybrid distribution supporting P2P primary transfer with HTTP fallback.
                                                    Hybrid {
                                                            info_hash: String,
                                                                    bootstrap_peers: Vec<String>,
                                                                            fallback_url: String,
                                                                                },
                                                                                }

                                                                                /// Specifies what kind of hot-updatable artifact a package contains.
                                                                                #[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
                                                                                pub enum ModuleKind {
                                                                                    /// Sandboxed WebAssembly sub-application or logic plugin.
                                                                                        WasmModule,
                                                                                            /// Declarative UI schema / layout definition for Flutter hot-updates.
                                                                                                UiManifest,
                                                                                                    /// GPU shader bundle (GLSL/SPIR-V) or MediaCodec/FFmpeg encoding preset.
                                                                                                        MediaPreset,
                                                                                                        }

                                                                                                        /// Signed metadata describing an installable package or hot-update bundle.
                                                                                                        #[derive(Debug, Clone, Serialize, Deserialize)]
                                                                                                        pub struct PackageManifest {
                                                                                                            pub id: String,
                                                                                                                pub version: String,
                                                                                                                    pub min_host_api: u32,
                                                                                                                        pub kind: ModuleKind,
                                                                                                                            pub sha256_hex: String,
                                                                                                                                /// Hex-encoded Ed25519 signature over the raw artifact bytes.
                                                                                                                                    pub signature_hex: String,
                                                                                                                                        pub origin: PackageOrigin,
                                                                                                                                            pub dependencies: Vec<String>,
                                                                                                                                            }

                                                                                                                                            /// Verifies integrity (SHA-256) and authenticity (Ed25519) before allowing hot-swap.
                                                                                                                                            pub fn verify_package_artifact(
                                                                                                                                                artifact_bytes: &[u8],
                                                                                                                                                    manifest: &PackageManifest,
                                                                                                                                                        trusted_public_key_hex: &str,
                                                                                                                                                        ) -> Result<(), String> {
                                                                                                                                                            // 1. Validate SHA-256 content hash
                                                                                                                                                                let mut hasher = Sha256::new();
                                                                                                                                                                    hasher.update(artifact_bytes);
                                                                                                                                                                        let computed_hash = hex::encode(hasher.finalize());

                                                                                                                                                                            if computed_hash != manifest.sha256_hex.to_lowercase() {
                                                                                                                                                                                    return Err(format!(
                                                                                                                                                                                                "SHA-256 integrity mismatch: expected {}, got {}",
                                                                                                                                                                                                            manifest.sha256_hex, computed_hash
                                                                                                                                                                                                                    ));
                                                                                                                                                                                                                        }

                                                                                                                                                                                                                            // 2. Validate Ed25519 cryptographic signature
                                                                                                                                                                                                                                let pub_bytes = hex::decode(trusted_public_key_hex)
                                                                                                                                                                                                                                        .map_err(|e| format!("Invalid public key hex: {}", e))?;
                                                                                                                                                                                                                                            let pub_array: [u8; 32] = pub_bytes
                                                                                                                                                                                                                                                    .try_into()
                                                                                                                                                                                                                                                            .map_err(|_| "Public key must be exactly 32 bytes".to_string())?;
                                                                                                                                                                                                                                                                let verifying_key = VerifyingKey::from_bytes(&pub_array)
                                                                                                                                                                                                                                                                        .map_err(|e| format!("Malformed Ed25519 verifying key: {}", e))?;

                                                                                                                                                                                                                                                                            let sig_bytes = hex::decode(&manifest.signature_hex)
                                                                                                                                                                                                                                                                                    .map_err(|e| format!("Invalid signature hex: {}", e))?;
                                                                                                                                                                                                                                                                                        let sig_array: [u8; 64] = sig_bytes
                                                                                                                                                                                                                                                                                                .try_into()
                                                                                                                                                                                                                                                                                                        .map_err(|_| "Signature must be exactly 64 bytes".to_string())?;
                                                                                                                                                                                                                                                                                                            let signature = Signature::from_bytes(&sig_array);

                                                                                                                                                                                                                                                                                                                verifying_key
                                                                                                                                                                                                                                                                                                                        .verify(artifact_bytes, &signature)
                                                                                                                                                                                                                                                                                                                                .map_err(|e| format!("Ed25519 signature verification failed: {}", e))
                                                                                                                                                                                                                                                                                                                                }