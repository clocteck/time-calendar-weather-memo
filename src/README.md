# 开发说明

这是纯 Lua/LVGL 应用，无需编译。运行代码位于 `../package/main.lua`。

设备部署目录固定为 `/sd/apps/assistant/`。如需修改应用 ID，请同时更新 `main.lua` 顶部的 `APP_ID`，以保证字体、天气图标、备忘录和 WebUI 路由仍指向同一个应用目录。

时间由设备 `time` 模块提供。应用先从 `/sd/apps/settings.json` 读取 POSIX `timezone`，调用 `time.settimezone()`，再调用 `time.getlocal()`；因此带 DST 规则的时区会由运行时自动切换。
