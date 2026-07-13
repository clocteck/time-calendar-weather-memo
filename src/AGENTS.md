# Assistant app notes

- `package/` 是完整设备运行包，部署目标为 `/sd/apps/assistant/`。
- 运行素材必须保存在 `package/` 内，不得依赖其他 app 的目录。
- 修改应用 ID 时，同步修改 `package/main.lua` 的 `APP_ID` 和根目录部署说明。
- 字体通过绝对 SD 路径加载；新增字体时放入 `package/font/` 并保留相应授权文件。
- 天气图标位于 `package/assets/icons/set2/`，Lua 路径使用 LVGL 的 `S:/apps/...` 形式。
- 时间显示必须先应用 `/sd/apps/settings.json` 中的 POSIX `timezone`，以支持 DST 规则。
- `package/info.html` 必须保持单文件、双语、无外部资源，并以内嵌 base64 使用原始 `main.png`。
