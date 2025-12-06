// 注释掉或删除下面这行，不强制设置首页
// user_pref("browser.startup.homepage", "https://idx.google.com");

// 将启动行为设置为“恢复上次会话”或“新建标签页”
// 3 = 恢复上次会话 (默认)，1 = 打开新建标签页
user_pref("browser.startup.page", 3);

// 以下配置保持不变，用于优化和允许安装插件
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.experiments.enabled", true);
user_pref("gfx.webrender.all", false);
