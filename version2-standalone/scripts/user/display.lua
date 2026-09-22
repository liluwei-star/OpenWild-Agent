-- display.lua
local gpio = require("gpio")
local board_manager = require("board_manager")

local disp = nil
local sw, sh = 0, 0

function initDisp()
    local ok, d = pcall(require, "display")
    if not ok then
        print("[Display] 无法加载 display 模块")
        return false
    end
    local ok2, ph, ih, w, h, pf = pcall(board_manager.get_display_lcd_params, "display_lcd")
    if not ok2 or not ph then
        print("[Display] 无法获取显示参数")
        return false
    end
    if not pcall(d.init, ph, ih, w, h, pf) then
        print("[Display] 初始化失败")
        return false
    end
    disp = d
    sw = d.width or 240
    sh = d.height or 320
    return true
end

function scr(st, dt)
    if not disp or not disp.begin_frame then
        return
    end
    local g = _G.g
    if not g then
        return
    end
    local ht = g.ht or 0
    local fn = g.fn or 0
    local mt = g.mt or 0
    local t = g.lt or "--"
    local h = g.lh or "--"

    -- 使用全局 PIN 或默认值
    local pin_ir = 10
    local pin_radar = 18
    local pin_btn = 8
    if _G.PIN then
        pin_ir = _G.PIN.IR or 10
        pin_radar = _G.PIN.RADAR or 18
        pin_btn = _G.PIN.BUTTON or 8
    end

    local function get_level(p)
        local ok, v = pcall(gpio.get_level, p)
        if ok then return v end
        return "?"
    end
    local ir = get_level(pin_ir)
    local rd = get_level(pin_radar)
    local btn = get_level(pin_btn)

    local s1 = string.format("IR:%s RD:%s B:%s| H:%d F:%d M:%d", tostring(ir), tostring(rd), tostring(btn), ht, fn, mt)
    local s2 = string.format("T:%s H:%s", tostring(t), tostring(h))

    pcall(function()
        disp.begin_frame({clear=true, color="#0c1220"})
        disp.draw_text_aligned(0, 10, sw, 18, "Wildlife v17b",
            {color={r=72,g=208,b=235}, font_size=17, align="center"})
        disp.draw_text_aligned(0, 40, sw, 18, st or "Waiting...",
            {color="white", font_size=16, align="center"})
        if dt then
            disp.draw_text_aligned(0, 70, sw, 16, dt,
                {color={r=200,g=200,b=200}, font_size=14, align="center"})
        end
        disp.draw_text_aligned(0, 175, sw, 14, "Sensors & Devices",
            {color={r=255,g=200,b=100}, font_size=11, align="center"})
        disp.draw_text_aligned(0, 195, sw, 14, s1,
            {color={r=150,g=255,b=150}, font_size=9, align="center"})
        disp.draw_text_aligned(0, 215, sw, 14, s2,
            {color={r=150,g=255,b=150}, font_size=9, align="center"})
        disp.present()
        disp.end_frame()
    end)
end