// 设置首页
user_pref("browser.startup.homepage", "https://idx.google.com");
user_pref("browser.startup.page", 1);
// 禁用首次运行向导
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
// 关键：允许从 addons.mozilla.org 安装扩展
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.experiments.enabled", true);
// 优化远程环境
user_pref("gfx.webrender.all", false);
