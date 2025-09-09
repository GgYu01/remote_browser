// Similar tuning as Xpra, but a bit more aggressive for headless use
user_pref("fission.autostart", false);
user_pref("dom.ipc.processCount", 1);
user_pref("dom.ipc.processCount.webIsolated", 1);

user_pref("gfx.webrender.all", false);
user_pref("layers.acceleration.disabled", true);
user_pref("image.animation_mode", "none");
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("layout.frame_rate", 10);

user_pref("javascript.options.ion", false);
user_pref("javascript.options.baselinejit", false);

user_pref("media.autoplay.default", 5);
user_pref("media.autoplay.blocking_policy", 2);
user_pref("network.http.max-connections", 60);
user_pref("network.http.max-persistent-connections-per-server", 2);

user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", true);
user_pref("browser.cache.memory.capacity", 20480);

user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.sessionstore.resume_from_crash", false);

user_pref("browser.sessionstore.max_tabs_undo", 0);
user_pref("browser.tabs.unloadOnLowMemory", true);