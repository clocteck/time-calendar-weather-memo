local APP_ID = "assistant"
local APP_ROOT = "/sd/apps/" .. APP_ID
local APP_KEY = "HOLOCUBIC_ASSISTANT_APP"

local previous = rawget(_G, APP_KEY)
if previous and previous.stop then
  pcall(function()
    previous.stop("reload")
  end)
end

local APP = {
  timer = nil,
  last_date = "",
  weather = "天气获取",
  weather_code = "103",
  weather_location = "101010100",
  timezone = "CST-8",
  weather_valid = false,
  weather_error = "",
  weather_timer = nil,
  lunar = "五月廿八",
  font_handles = {},
  memos = {
    "项目复盘",
    "阅读二十分钟",
    "散步放松",
  },
}
_G[APP_KEY] = APP

local root = lv_scr_act()
local MAIN = LV_PART_MAIN | LV_STATE_DEFAULT
local FONT_10 = LV_FONT_MONTSERRAT_10
local FONT_12 = LV_FONT_MONTSERRAT_12
local FONT_16 = LV_FONT_MONTSERRAT_16
local FONT_20 = LV_FONT_MONTSERRAT_20
local FONT_TIME = FONT_20
local FONT_CN = FONT_12
local FONT_CN_SMALL = FONT_12
local FONT_BOLD = FONT_12
local FONT_WEEKDAY_BOLD = FONT_CN_SMALL

local C = {
  bg = 0x000000,
  calendar = 0x000000,
  ink = 0xFFFFFF,
  muted = 0xFFFFFF,
  line = 0x666666,
  accent = 0x2E78D6,
  accent_ink = 0xFFFFFF,
  weekday_red = 0xFF0000,
  weekday_green = 0x00FF00,
  lunar_green = 0x00FF00,
}

local UI = {}
local WEEKDAY_CN = { "日", "一", "二", "三", "四", "五", "六" }

local function call(fn, ...)
  if fn then
    return pcall(fn, ...)
  end
  return false
end

local function style(obj, bg, radius)
  call(lv_obj_set_style_bg_color, obj, bg, MAIN)
  call(lv_obj_set_style_bg_opa, obj, 255, MAIN)
  call(lv_obj_set_style_border_width, obj, 0, MAIN)
  call(lv_obj_set_style_radius, obj, radius or 0, MAIN)
  call(lv_obj_set_style_pad_all, obj, 0, MAIN)
end

local function label(parent, text, font, color, x, y, width, align)
  local obj = lv_label_create(parent)
  lv_label_set_text(obj, text)
  call(lv_obj_set_pos, obj, x, y)
  call(lv_obj_set_width, obj, width)
  call(lv_obj_set_style_text_font, obj, font, MAIN)
  call(lv_obj_set_style_text_color, obj, color, MAIN)
  call(lv_obj_set_style_text_opa, obj, 255, MAIN)
  call(lv_obj_set_style_text_outline_width, obj, 1, MAIN)
  call(lv_obj_set_style_text_outline_color, obj, color, MAIN)
  call(lv_obj_set_style_text_align, obj, align or LV_TEXT_ALIGN_LEFT, MAIN)
  return obj
end

local function load_font_ref(path, fallback)
  if not lv_font_load then return fallback end
  local ok, handle = pcall(lv_font_load, path)
  if ok and type(handle) == "number" and handle > 0 then
    APP.font_handles[#APP.font_handles + 1] = handle
    return handle
  end
  return fallback
end

local function load_fonts()
  FONT_CN = load_font_ref(APP_ROOT .. "/font/18chinese.bin", FONT_CN)
  FONT_CN_SMALL = load_font_ref(APP_ROOT .. "/font/font_cn_12.bin", FONT_CN_SMALL)
  FONT_TIME = load_font_ref(APP_ROOT .. "/font/weather_time_40.bin", FONT_TIME)
  FONT_BOLD = load_font_ref(APP_ROOT .. "/font/font_bold_18.bin", FONT_CN)
  FONT_WEEKDAY_BOLD = load_font_ref(APP_ROOT .. "/font/font_weekday_bold_12.bin", FONT_CN_SMALL)
end

local function value_of(cal, first, second, fallback)
  local value = cal and (cal[first] or (second and cal[second]))
  value = tonumber(value)
  return value or fallback
end

local function is_leap(year)
  return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function days_in_month(year, month)
  local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if month == 2 and is_leap(year) then return 29 end
  return days[month] or 30
end

local function weekday_sun0(year, month, day)
  local offset = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
  if month < 3 then year = year - 1 end
  return (year + math.floor(year / 4) - math.floor(year / 100) + math.floor(year / 400) + offset[month] + day) % 7
end

local function local_time()
  -- POSIX TZ strings (for example EST5EDT,M3.2.0/2,M11.1.0/2) let the
  -- runtime apply daylight-saving transitions before time.getlocal().
  if time and time.settimezone then pcall(time.settimezone, APP.timezone) end
  local cal = nil
  if time and time.getlocal then
    local ok, value = pcall(time.getlocal)
    if ok and type(value) == "table" then cal = value end
  end

  local year = value_of(cal, "year", "tm_year", 2026)
  local month = value_of(cal, "mon", "month", 7)
  local day = value_of(cal, "day", "mday", 11)
  local hour = value_of(cal, "hour", "tm_hour", 12)
  local minute = value_of(cal, "min", "minute", 0)

  if month < 1 or month > 12 then month = 7 end
  if day < 1 or day > days_in_month(year, month) then day = 1 end
  if hour < 0 or hour > 23 then hour = 0 end
  if minute < 0 or minute > 59 then minute = 0 end

  local wday0 = weekday_sun0(year, month, day)
  return { year = year, month = month, day = day, hour = hour, minute = minute, wday0 = wday0 }
end

local function lunar_text(cal)
  local month_names = { "正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月" }
  local day_names = { "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十", "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十", "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十" }
  -- Lunar month 1 starts on 2026-02-17; the January entry is lunar month 12.
  local starts_2026 = { 48, 78, 107, 137, 166, 195, 225, 254, 283, 313, 343 }
  if cal and cal.year == 2026 then
    local ordinal = cal.day
    local days_before = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
    ordinal = (days_before[cal.month] or 0) + cal.day
    local month_index = 1
    for i = 1, #starts_2026 do
      if ordinal >= starts_2026[i] then month_index = i end
    end
    local lunar_day = ordinal - starts_2026[month_index] + 1
    if lunar_day >= 1 and lunar_day <= 30 then
      return month_names[month_index] .. day_names[lunar_day]
    end
  end
  return APP.lunar
end

local function date_key(cal)
  return tostring(cal.year) .. "-" .. tostring(cal.month) .. "-" .. tostring(cal.day)
end

local refresh

local function read_text(path)
  if not file or not file.getcontents then return nil end
  local ok, value = pcall(file.getcontents, path)
  return ok and type(value) == "string" and value or nil
end

local function decode_json(raw)
  if not raw then return nil end
  if json and json.decode then
    local ok, value = pcall(json.decode, raw)
    if ok and type(value) == "table" then return value end
  end
  if sjson and sjson.decode then
    local ok, value = pcall(sjson.decode, raw)
    if ok and type(value) == "table" then return value end
  end
  return nil
end

local function url_encode(value)
  return tostring(value or ""):gsub("([^%w%-%._~])", function(ch)
    return string.format("%%%02X", string.byte(ch))
  end)
end

local function load_runtime_settings()
  local doc = decode_json(read_text("/sd/apps/settings.json")) or {}
  local location = doc.weather_address or doc.weatherAddress or doc.weather_city or doc.city_name or doc.city
  if type(location) == "string" and location ~= "" then
    APP.weather_location = location
  end
  if type(doc.timezone) == "string" and doc.timezone ~= "" then
    APP.timezone = doc.timezone
  end
  if time and time.settimezone then pcall(time.settimezone, APP.timezone) end
end

local MEMO_FILE = APP_ROOT .. "/memos.json"
local WEB_HTML = [=[<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>备忘录</title><style>
body{font-family:system-ui,"Microsoft YaHei",sans-serif;background:#f4f6f8;color:#17202a;margin:0}.page{max-width:620px;margin:0 auto;padding:22px 16px}.panel{background:#fff;border:1px solid #dce2e8;border-radius:10px;padding:20px;box-shadow:0 5px 18px #0000000d}h1{margin:0 0 6px;font-size:25px}p{color:#687583;margin:0 0 18px}label{display:block;font-weight:700;margin:15px 0 6px}input{box-sizing:border-box;width:100%;padding:12px;border:1px solid #cbd3dc;border-radius:7px;font-size:16px}button{margin-top:20px;padding:11px 20px;border:0;border-radius:7px;background:#2675d8;color:#fff;font-size:16px;font-weight:700;cursor:pointer}button:disabled{opacity:.55}.status{display:inline-block;margin-left:12px;color:#287a45}.error{color:#c0392b}</style><main class="page"><section class="panel"><h1>备忘录</h1><p>修改后点击保存，设备上的内容会立即更新。</p><label>第一条</label><input id="m1"><label>第二条</label><input id="m2"><label>第三条</label><input id="m3"><button id="save">保存备忘录</button><span id="status" class="status"></span></section></main><script>
const api=location.pathname.replace(/\/?$/,'/')+'api/memos';const q=id=>document.getElementById(id);async function load(){let r=await fetch(api);let d=await r.json();if(!d.ok)throw Error(d.error||'读取失败');(d.memos||[]).forEach((v,i)=>q('m'+(i+1)).value=v||'')}async function save(){q('save').disabled=true;q('status').className='status';q('status').textContent='保存中';try{let r=await fetch(api,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({memos:[q('m1').value,q('m2').value,q('m3').value]})});let d=await r.json();if(!d.ok)throw Error(d.error||'保存失败');q('status').textContent='已保存'}catch(e){q('status').className='status error';q('status').textContent=e.message}q('save').disabled=false}q('save').onclick=save;load().catch(e=>{q('status').className='status error';q('status').textContent=e.message});
</script></html>]=]

local function memo_save()
  if not (file and file.open and json and json.encode) then return false end
  local fd = file.open(MEMO_FILE, "w+")
  if not fd then return false end
  local ok, body = pcall(json.encode, { memos = APP.memos })
  if ok and body then pcall(function() fd:write(body) fd:flush() end) end
  pcall(function() fd:close() end)
  return ok and body ~= nil
end

local function memo_load()
  local raw = read_text(MEMO_FILE)
  local doc = decode_json(raw)
  if type(doc) == "table" and type(doc.memos) == "table" then
    for i = 1, 3 do if type(doc.memos[i]) == "string" then APP.memos[i] = doc.memos[i] end end
  end
end

local function web_response(body, content_type, status)
  return { status = status or "200 OK", type = content_type or "text/plain; charset=utf-8", headers = { ["cache-control"] = "no-store" }, body = body or "" }
end

local function web_json(data, status)
  return web_response(json.encode(data), "application/json; charset=utf-8", status)
end

local function normalize_route_base(base)
  if type(base) ~= "string" then return nil end
  base = base:gsub("\\", "/"):gsub("^/*", ""):gsub("/*$", "")
  if base == "" then return nil end
  return "/" .. base
end

local function start_web()
  if not (httpd and httpd.start and httpd.dynamic) then return end
  pcall(httpd.stop)
  pcall(httpd.start, { webroot = "/sd", auto_index = httpd.INDEX_NONE, max_handlers = 16 })
  local function route(method, path, handler) pcall(httpd.dynamic, method, path, handler) end
  local function index() return web_response(WEB_HTML, "text/html; charset=utf-8") end
  local function memos(req)
    if req and req.method == httpd.POST then
      local raw = req.body or req.payload
      if not raw and req.getbody then
        local ok, value = pcall(req.getbody)
        if ok then raw = value end
      end
      local doc = decode_json(raw or "")
      if type(doc) == "table" and type(doc.memos) == "table" then
        for i = 1, 3 do APP.memos[i] = tostring(doc.memos[i] or "") end
        memo_save()
        refresh(local_time())
        return web_json({ ok = true, memos = APP.memos })
      end
      return web_json({ ok = false, error = "数据格式错误" }, "400 Bad Request")
    end
    return web_json({ ok = true, memos = APP.memos })
  end
  local bases = {}
  local seen = {}
  local function add_base(base)
    base = normalize_route_base(base)
    if base and not seen[base] then
      seen[base] = true
      bases[#bases + 1] = base
    end
  end
  add_base(APP_ID)
  add_base(app and app.route_base and app.route_base())
  for _, base in ipairs(bases) do
    route(httpd.GET, base, index)
    route(httpd.GET, base .. "/", index)
    route(httpd.GET, base .. "/api/memos", memos)
    route(httpd.POST, base .. "/api/memos", memos)
  end
  APP.web_started = true
end

local function weather_body(body)
  if zlib and zlib.isgzip and zlib.isgzip(body) and zlib.gunzip then
    local plain = zlib.gunzip(body)
    if plain then return plain end
  end
  return body
end

local function parse_weather(status_code, body)
  body = weather_body(body)
  local doc = status_code == 200 and decode_json(body) or nil
  local now = doc and doc.code == "200" and doc.now
  if type(now) ~= "table" then
    APP.weather_valid = false
    APP.weather_error = "HTTP " .. tostring(status_code)
    APP.weather = "天气获取失败"
    return
  end
  local temp = tonumber(now.temp)
  local text = tostring(now.text or "")
  APP.weather_valid = true
  APP.weather_error = ""
  APP.weather_code = tostring(now.icon or "103")
  APP.weather = text .. (temp and (" " .. tostring(temp) .. "°C") or "")
end

local function request_weather_now(location)
  if not http or not http.cubicserver or not http.cubicserver.get then
    APP.weather = "天气接口不可用"
    return
  end
  local url = "/v1/weather/now?location=" .. url_encode(location) .. "&unit=m"
  http.cubicserver.get(url, "Accept-Encoding: gzip\r\n", function(status_code, body)
    parse_weather(status_code, body)
    refresh(local_time())
  end)
end

local function request_weather()
  local location = tostring(APP.weather_location or "")
  if location == "" then return end
  if location:match("^%d+$") then
    request_weather_now(location)
    return
  end
  if not http or not http.cubicserver or not http.cubicserver.get then return end
  local url = "/v1/weather/cities?location=" .. url_encode(location) .. "&number=1&lang=zh"
  http.cubicserver.get(url, "Accept-Encoding: gzip\r\n", function(status_code, body)
    local doc = decode_json(weather_body(body))
    local locations = doc and (doc.location or doc.locations)
    local first = type(locations) == "table" and locations[1]
    local id = type(first) == "table" and first.id
    if id then request_weather_now(id) else APP.weather = "天气获取失败" end
    refresh(local_time())
  end)
end

local function build_calendar(cal)
  local panel = lv_obj_create(root)
  call(lv_obj_set_pos, panel, 181, 0)
  call(lv_obj_set_size, panel, 139, 240)
  style(panel, C.calendar, 0)

  UI.month = label(panel, "", FONT_CN, C.ink, 0, 11, 139, LV_TEXT_ALIGN_CENTER)
  for col = 0, 6 do
    local weekday_color = (col == 0 or col == 6) and C.weekday_red or C.weekday_green
    label(panel, WEEKDAY_CN[col + 1], FONT_WEEKDAY_BOLD, weekday_color, 4 + col * 19, 45, 18, LV_TEXT_ALIGN_CENTER)
  end

  UI.days = {}
  UI.today_bg = nil
  local first = weekday_sun0(cal.year, cal.month, 1)
  local total = days_in_month(cal.year, cal.month)
  for day = 1, total do
    local slot = first + day - 1
    local col = slot % 7
    local row = math.floor(slot / 7)
    local x = 4 + col * 19
    local y = 59 + row * 26
    if day == cal.day then
      local highlight = lv_obj_create(panel)
      call(lv_obj_set_pos, highlight, x, y + 4)
      call(lv_obj_set_size, highlight, 18, 19)
      style(highlight, C.accent, 4)
      UI.today_bg = highlight
    end
    UI.days[day] = label(panel, tostring(day), FONT_12, day == cal.day and C.accent_ink or C.ink, x, y + 6, 18, LV_TEXT_ALIGN_CENTER)
  end
end

local function build_ui(cal)
  lv_obj_clean(root)
  style(root, C.bg, 0)

  UI.time = label(root, "", FONT_TIME, C.ink, 14, 6, 158, LV_TEXT_ALIGN_LEFT)
  UI.lunar = label(root, APP.lunar, FONT_CN, C.lunar_green, 14, 48, 84, LV_TEXT_ALIGN_LEFT)
  UI.weather = label(root, APP.weather, FONT_CN, C.muted, 14, 72, 84, LV_TEXT_ALIGN_LEFT)
  UI.weather_icon = lv_img_create(root)
  call(lv_obj_set_pos, UI.weather_icon, 100, 42)
  call(lv_img_set_zoom, UI.weather_icon, 224)
  call(lv_img_set_antialias, UI.weather_icon, true)
  if lv_img_set_src then
    call(lv_img_set_src, UI.weather_icon, "S:/apps/" .. APP_ID .. "/assets/icons/set2/103.png")
  end

  local separator = lv_obj_create(root)
  call(lv_obj_set_pos, separator, 14, 106)
  call(lv_obj_set_size, separator, 151, 1)
  style(separator, C.line, 0)

  label(root, "备忘录", FONT_BOLD, C.accent, 14, 110, 150, LV_TEXT_ALIGN_LEFT)
  UI.memo_labels = {}
  for i = 1, 3 do
    local y = 136 + (i - 1) * 30
    UI.memo_labels[i] = label(root, APP.memos[i], FONT_CN, C.ink, 14, y, 144, LV_TEXT_ALIGN_LEFT)
    local memo_line = lv_obj_create(root)
    call(lv_obj_set_pos, memo_line, 14, y + 30)
    call(lv_obj_set_size, memo_line, 151, 1)
    style(memo_line, C.line, 0)
  end

  build_calendar(cal)
end

refresh = function(cal)
  lv_label_set_text(UI.time, string.format("%02d:%02d", cal.hour, cal.minute))
  APP.lunar = lunar_text(cal)
  lv_label_set_text(UI.lunar, APP.lunar)
  lv_label_set_text(UI.weather, APP.weather)
  if UI.weather_icon and lv_img_set_src then
    call(lv_img_set_src, UI.weather_icon, "S:/apps/" .. APP_ID .. "/assets/icons/set2/" .. tostring(APP.weather_code or "103") .. ".png")
  end
  lv_label_set_text(UI.month, tostring(cal.year) .. "年" .. tostring(cal.month) .. "月")
  for i = 1, 3 do
    lv_label_set_text(UI.memo_labels[i], APP.memos[i])
  end
end

load_runtime_settings()
local cal = local_time()
APP.last_date = date_key(cal)
memo_load()
load_fonts()
build_ui(cal)
refresh(cal)
request_weather()
start_web()

APP.timer = tmr.create()
APP.timer:alarm(1000, tmr.ALARM_AUTO, function()
  if app.exiting() then return end
  local now = local_time()
  if date_key(now) ~= APP.last_date then
    APP.last_date = date_key(now)
    build_ui(now)
  end
  refresh(now)
end)

APP.weather_timer = tmr.create()
APP.weather_timer:alarm(60000, tmr.ALARM_AUTO, function()
  if not app.exiting() then request_weather() end
end)

key.on(key.HOME, function(event)
  if event == key.SHORT then
    app.exit()
  end
end)

function APP.stop()
  for _, timer in pairs({ APP.timer, APP.weather_timer }) do
    if timer then
      pcall(function() timer:stop() end)
      pcall(function() timer:unregister() end)
    end
  end
  APP.timer = nil
  APP.weather_timer = nil
  if APP.web_started and httpd and httpd.stop then
    pcall(httpd.stop)
    APP.web_started = false
  end
  pcall(function() key.off() end)
  if #APP.font_handles > 0 and lv_font_free then
    for _, handle in ipairs(APP.font_handles) do pcall(lv_font_free, handle) end
    APP.font_handles = {}
  end
  if rawget(_G, APP_KEY) == APP then
    _G[APP_KEY] = nil
  end
end

APP.shutdown = APP.stop
