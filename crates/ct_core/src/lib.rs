pub mod bus;
pub mod package;
pub mod updater;

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};

pub use bus::{EcosystemMessage, EventBus};
pub use package::{ModuleKind, PackageManifest, PackageOrigin};
pub use updater::HotUpdateManager;

/// FFI entrypoint allowing Flutter/Kotlin to trigger a hot-update or module install
/// from either a P2P swarm or a standard repository URL using a JSON manifest.
#[no_mangle]
pub extern "C" fn ct_core_install_package_json(
    storage_dir_ptr: *const c_char,
        pubkey_hex_ptr: *const c_char,
            manifest_json_ptr: *const c_char,
            ) -> c_int {
                if storage_dir_ptr.is_null() || pubkey_hex_ptr.is_null() || manifest_json_ptr.is_null() {
                        return -1;
                            }

                                unsafe {
                                        let storage_dir = match CStr::from_ptr(storage_dir_ptr).to_str() {
                                                    Ok(s) => s,
                                                                Err(_) => return -2,
                                                                        };
                                                                                let pubkey_hex = match CStr::from_ptr(pubkey_hex_ptr).to_str() {
                                                                                            Ok(s) => s.to_string(),
                                                                                                        Err(_) => return -3,
                                                                                                                };
                                                                                                                        let manifest_json = match CStr::from_ptr(manifest_json_ptr).to_str() {
                                                                                                                                    Ok(s) => s,
                                                                                                                                                Err(_) => return -4,
                                                                                                                                                        };

                                                                                                                                                                let manifest: PackageManifest = match serde_json::from_str(manifest_json) {
                                                                                                                                                                            Ok(m) => m,
                                                                                                                                                                                        Err(_) => return -5,
                                                                                                                                                                                                };

                                                                                                                                                                                                        let manager = HotUpdateManager::new(storage_dir, pubkey_hex);
                                                                                                                                                                                                                match manager.install_or_hot_update(&manifest) {
                                                                                                                                                                                                                            Ok(_) => 0,
                                                                                                                                                                                                                                        Err(_) => -6,
                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                    }
                                                                                                                                                                                                                                                    }

                                                                                                                                                                                                                                                    /// Returns the core ABI version for runtime compatibility checks during hot-updates.
                                                                                                                                                                                                                                                    #[no_mangle]
                                                                                                                                                                                                                                                    pub extern "C" fn ct_core_abi_version() -> c_int {
                                                                                                                                                                                                                                                        1
                                                                                                                                                                                                                                                        }

                                                                                                                                                                                                                                                        /// Frees C strings allocated by Rust FFI helpers.
                                                                                                                                                                                                                                                        #[no_mangle]
                                                                                                                                                                                                                                                        pub extern "C" fn ct_core_free_string(ptr: *mut c_char) {
                                                                                                                                                                                                                                                            if !ptr.is_null() {
                                                                                                                                                                                                                                                                    unsafe {
                                                                                                                                                                                                                                                                                let _ = CString::from_raw(ptr);
                                                                                                                                                                                                                                                                                        }
                                                                                                                                                                                                                                                                                            }
                                                                                                                                                                                                                                                                                            }