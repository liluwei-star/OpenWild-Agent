-- agent_self_monitor.lua
-- 功能：系统监控与告警
-- 版本：V7.3
-- 说明：监控系统状态，自动清理，异常告警

local json = require("json")
local capability = require("capability")
local storage = require("storage")

local M = {}

-- 检查系统状态
function M.check(feishu)
    local ok, info = pcall(capability.call, "system", "info")
    if not ok or not info then return end
    
    -- 内存告警
    if info.heap and info.heap.free and info.heap.free < 20480 then
        pcall(capability.call, "feishu_send_message", {
            message = "⚠️内存告警：剩余 " .. info.heap.free .. " bytes"
        }, {channel = "feishu", chat_id = feishu})
    end
    
    -- WiFi信号告警
    if info.wifi and info.wifi.rssi and info.wifi.rssi < -80 then
        pcall(capability.call, "feishu_send_message", {
            message = "📶WiFi信号弱：" .. info.wifi.rssi .. " dBm"
        }, {channel = "feishu", chat_id = feishu})
    end
end

-- 清理 /fatfs/blog/ 文件夹
function M.cleanupBlogFolder()
    local blog_dir = "/fatfs/blog"
    
    -- 检查目录是否存在
    local ok, files = pcall(storage.list_dir, blog_dir)
    if not ok or not files then
        return  -- 目录不存在，无需清理
    end
    
    -- 删除目录下所有文件
    for _, file in ipairs(files) do
        if file.name then
            local file_path = blog_dir .. "/" .. file.name
            pcall(storage.remove, file_path)
        end
    end
    
    -- 同步文件系统
    pcall(storage.sync)
end

-- 获取系统状态（用于查询）
function M.getSystemStatus()
    local ok, info = pcall(capability.call, "system", "info")
    if not ok or not info then
        return {error = "无法获取系统状态"}
    end
    
    return {
        heap_free = info.heap and info.heap.free or 0,
        heap_total = info.heap and info.heap.total or 0,
        wifi_rssi = info.wifi and info.wifi.rssi or 0,
        uptime = info.uptime or 0
    }
end

return M