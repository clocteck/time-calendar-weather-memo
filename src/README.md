# 开发说明

这是纯 Lua/LVGL 应用，无需编译。运行代码位于 `../package/main.lua`。

建议部署到 `/sd/apps/time-calendar-weather-memo/`。`main.lua` 通过 `app.current().entry` 动态解析当前安装目录，使字体、天气图标、备忘录和 WebUI 路由始终指向同一个应用目录。

时间由设备 `time` 模块提供。应用先从 `/sd/apps/settings.json` 读取 POSIX `timezone`，调用 `time.settimezone()`，再调用 `time.getlocal()`；因此带 DST 规则的时区会由运行时自动切换。
