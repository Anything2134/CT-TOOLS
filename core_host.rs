use std::collections::HashMap;
use std::sync::{Arc, RwLock};

pub trait EcosystemPlugin: Send + Sync {
    fn plugin_id(&self) -> &'static str;
        fn on_initialize(&self, context: &PluginContext) -> Result<(), String>;
            fn handle_message(&self, message: &PluginMessage) -> Option<PluginMessage>;
            }

            pub struct PluginMessage {
                pub topic: String,
                    pub payload: Vec<u8>,
                    }

                    #[derive(Clone)]
                    pub struct PluginContext {
                        bus: Arc<RwLock<EventBus>>,
                        }

                        pub struct EventBus {
                            registry: HashMap<String, Vec<Box<dyn Fn(&PluginMessage) + Send + Sync>>>,
                            }

                            impl EventBus {
                                pub fn new() -> Self {
                                        Self { registry: HashMap::new() }
                                            }

                                                pub fn subscribe<F>(&mut self, topic: &str, handler: F)
                                                    where
                                                            F: Fn(&PluginMessage) + Send + Sync + 'static,
                                                                {
                                                                        self.registry.entry(topic.to_string())
                                                                                    .or_insert_with(Vec::new)
                                                                                                .push(Box::new(handler));
                                                                                                    }

                                                                                                        pub fn publish(&self, message: &PluginMessage) {
                                                                                                                if let Some(subscribers) = self.registry.get(&message.topic) {
                                                                                                                            for handler in subscribers {
                                                                                                                                            handler(message);
                                                                                                                                                        }
                                                                                                                                                                }
                                                                                                                                                                    }
                                                                                                                                                                    }

                                                                                                                                                                    pub struct EcosystemHost {
                                                                                                                                                                        plugins: HashMap<String, Arc<dyn EcosystemPlugin>>,
                                                                                                                                                                            bus: Arc<RwLock<EventBus>>,
                                                                                                                                                                            }

                                                                                                                                                                            impl EcosystemHost {
                                                                                                                                                                                pub fn new() -> Self {
                                                                                                                                                                                        Self {
                                                                                                                                                                                                    plugins: HashMap::new(),
                                                                                                                                                                                                                bus: Arc::new(RwLock::new(EventBus::new())),
                                                                                                                                                                                                                        }
                                                                                                                                                                                                                            }

                                                                                                                                                                                                                                pub fn register_plugin(&mut self, plugin: Arc<dyn EcosystemPlugin>) -> Result<(), String> {
                                                                                                                                                                                                                                        let id = plugin.plugin_id().to_string();
                                                                                                                                                                                                                                                let context = PluginContext { bus: Arc::clone(&self.bus) };
                                                                                                                                                                                                                                                        plugin.on_initialize(&context)?;
                                                                                                                                                                                                                                                                self.plugins.insert(id, plugin);
                                                                                                                                                                                                                                                                        Ok(())
                                                                                                                                                                                                                                                                            }

                                                                                                                                                                                                                                                                                pub fn dispatch_to_plugin(&self, plugin_id: &str, message: &PluginMessage) -> Option<PluginMessage> {
                                                                                                                                                                                                                                                                                        self.plugins.get(plugin_id).and_then(|p| p.handle_message(message))
                                                                                                                                                                                                                                                                                            }
                                                                                                                                                                                                                                                                                            }