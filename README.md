# Assistant

面向 Cubic 320×240 设备的桌面信息助手，在一屏内显示本地时间、农历、实时天气、月历和三条备忘录。

由群友🥶开发。当前 App 版本为 `1.0.1`，已经过实际设备测试。

## 目录结构

```text
assistant/
├─ package/              # 可直接部署到设备的运行包
│  ├─ app.info
│  ├─ main.lua
│  ├─ main.png
│  ├─ info.html          # Launcher 中显示的双语介绍页
│  ├─ assets/icons/set2/ # 本地天气图标
│  └─ font/              # 本地 LVGL 字体
└─ src/                  # 开发说明
```

## 部署

将 `package/` 中的内容复制到设备的 `/sd/apps/assistant/`，不要复制 `package` 目录本身。入口文件和全部运行素材均已包含在包内。

当前版本已经过测试，可按上述目录直接部署。

## 配置

应用读取 `/sd/apps/settings.json`：

- `weather_address`（兼容 `weatherAddress`、`weather_city`、`city_name`、`city`）：天气位置或城市 ID。
- `timezone`：POSIX 时区字符串，默认 `CST-8`。支持带夏令时规则的写法，例如 `EST5EDT,M3.2.0/2,M11.1.0/2`；运行时会在 `time.getlocal()` 前应用该时区，使 DST 切换生效。

备忘录保存在 `/sd/apps/assistant/memos.json`，也可通过应用 WebUI 修改。

## 素材

- 应用图标：`package/main.png`
- 天气图标：`package/assets/icons/set2/`
- 字体：`package/font/`

天气图标集的授权文件与字体授权说明均随素材保留在对应目录中。

## 开源协议

GPL-3.0，详见 `LICENSE`。
