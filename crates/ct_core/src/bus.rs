use std::collections::HashMap;
use std::sync::{Arc, RwLock};

/// Represents an immutable message routed across modules within CT-TOOLS.
#[derive(Debug, Clone)]
pub struct EcosystemMessage {
    pub source_module: String,
        pub topic: String,
            pub payload: Vec<u8>,
            }

            type SubscriberCallback = Arc<dyn Fn(&EcosystemMessage) + Send + Sync>;

            /// Thread-safe publish-subscribe event bus enabling decoupled inter-module communication.
            pub struct EventBus {
                subscribers: RwLock<HashMap<String, Vec<SubscriberCallback>>>,
                }

                impl EventBus {
                    /// Creates a new empty event bus instance.
                        pub fn new() -> Self {
                                Self {
                                            subscribers: RwLock::new(HashMap::new()),
                                                    }
                                                        }

                                                            /// Registers a handler function to listen for messages matching a specific topic.
                                                                pub fn subscribe<F>(&self, topic: &str, handler: F)
                                                                    where
                                                                            F: Fn(&EcosystemMessage) + Send + Sync + 'static,
                                                                                {
                                                                                        if let Ok(mut map) = self.subscribers.write() {
                                                                                                    map.entry(topic.to_string())
                                                                                                                    .or_insert_with(Vec::new)
                                                                                                                                    .push(Arc::new(handler));
                                                                                                                                            }
                                                                                                                                                }

                                                                                                                                                    /// Dispatches a message to all active subscribers registered on the message topic.
                                                                                                                                                        pub fn publish(&self, message: EcosystemMessage) {
                                                                                                                                                                if let Ok(map) = self.subscribers.read() {
                                                                                                                                                                            if let Some(handlers) = map.get(&message.topic) {
                                                                                                                                                                                            for handler in handlers {
                                                                                                                                                                                                                handler(&message);
                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                            }
                                                                                                                                                                                                                                                    }
                                                                                                                                                                                                                                                        }
                                                                                                                                                                                                                                                        }