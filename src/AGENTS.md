# Assistant app notes

- `package/` 是完整设备运行包，部署目标为 `/sd/apps/time-calendar-weather-memo/`。
- 运行素材必须保存在 `package/` 内，不得依赖其他 app 的目录。
- 安装目录由 `package/main.lua` 通过 `app.current().entry` 动态获取，不要重新硬编码应用 ID 或根目录。
- 字体从当前 App 目录加载；新增字体时放入 `package/font/` 并保留相应授权文件。
- 天气图标位于 `package/assets/icons/set2/`，Lua 将当前 App 目录转换为 LVGL 的 `S:` 路径。
- 时间显示必须先应用 `/sd/apps/settings.json` 中的 POSIX `timezone`，以支持 DST 规则。
- `package/info.html` 必须保持单文件、双语、无外部资源，并以内嵌 base64 使用原始 `main.png`。
