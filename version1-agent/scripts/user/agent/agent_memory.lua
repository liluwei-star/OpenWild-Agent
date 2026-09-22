-- agent_memory.lua
-- 功能：数据记录与读取
-- 版本：V7.3
-- 说明：气象数据记录、物种访问记录、数据读取接口

local json = require("json")
local storage = require("storage")

local M = {}

-- 路径配置
M.DATA_DIR = "/fatfs/data"
M.WEATHER_LOG = M.DATA_DIR .. "/weather_log.jsonl"
M.SPECIES_LOG = M.DATA_DIR .. "/species_log.jsonl"

-- 初始化目录
pcall(storage.mkdir, M.DATA_DIR)

-- 安全追加写入
local function appendLog(path, data)
    local ok, existing = pcall(storage.read_file, path)
    local line = json.encode(data) .. "\n"
    if ok and existing then
        line = existing .. line
    end
    pcall(storage.write_file, path, line)
end

-- 记录气象数据（带数据清理）
function M.logWeather(data)
    -- 1. 追加新记录
    appendLog(M.WEATHER_LOG, {
        ts = os.time(),
        d = os.date("%Y-%m-%d"),
        h = tonumber(os.date("%H")),
        t = data.temp,
        u = data.humi,
        s = data.speed,
        r = data.dir,
        p = data.pressure,
        a = data.altitude
    })
    
    -- 2. 检查并清理过期数据（保留1天）
    M.cleanupIfNeeded(M.WEATHER_LOG, 1)
end

-- 记录物种访问（带数据清理）
function M.logSpecies(data)
    -- 1. 追加新记录
    -- 支持两种字段名：species 和 animal
    local species_name = data.species or data.animal or "unknown"
    
    appendLog(M.SPECIES_LOG, {
        ts = os.time(),
        d = os.date("%Y-%m-%d"),
        h = tonumber(os.date("%H")),
        sp = species_name,
        lt = data.temp or 0,
        lh = data.humidity or 0
    })
    
    -- 2. 检查并清理过期数据（保留1天）
    M.cleanupIfNeeded(M.SPECIES_LOG, 1)
end

-- 清理过期数据
function M.cleanupIfNeeded(path, keep_days)
    keep_days = keep_days or 1  -- 默认1天
    
    -- 检查文件大小
    local ok, size = pcall(storage.file_size, path)
    if ok and size and size > 512 * 1024 then  -- 超过512KB
        local ok2, data = pcall(storage.read_file, path)
        if ok2 and data then
            local cutoff = os.time() - (keep_days * 86400)
            local lines = {}
            
            for line in data:gmatch("[^\n]+") do
                local ok3, record = pcall(json.decode, line)
                if ok3 and record.ts and record.ts >= cutoff then
                    table.insert(lines, line)
                end
            end
            
            local cleaned = table.concat(lines, "\n") .. "\n"
            pcall(storage.write_file, path, cleaned)
        end
    end
end

-- 读取动物状态（从yeshengdongwu17a.lua写入的配置文件）
function M.readAnimalState()
    local ok, data = pcall(storage.read_file, "/fatfs/config/animal_env.json")
    if ok and data then
        -- 调试：记录原始数据
        -- print("[DEBUG] animal_env.json raw:", data)
        local ok2, state = pcall(json.decode, data)
        if ok2 then 
            -- 调试：记录解析后的数据
            -- print("[DEBUG] animal_env.json decoded:", json.encode(state))
            return state 
        end
    end
    return nil
end

-- 检测物种访问变化
function M.detectSpeciesVisit(lastState)
    local state = M.readAnimalState()
    if not state or not state.animal or state.animal == "unknown" then
        return nil, lastState
    end
    
    -- 检测到新物种
    if not lastState or lastState.animal ~= state.animal then
        return state, state
    end
    
    return nil, lastState
end

-- 读取最近记录
function M.readLast(path, n)
    n = n or 1
    local ok, data = pcall(storage.read_file, path)
    if not ok or not data then return {} end
    
    local lines = {}
    for line in data:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    local result = {}
    local start = math.max(1, #lines - n + 1)
    for i = start, #lines do
        local ok2, record = pcall(json.decode, lines[i])
        if ok2 then table.insert(result, record) end
    end
    return result
end

-- 读取今日统计
function M.todayStats()
    local today = os.date("%Y-%m-%d")
    local ok, data = pcall(storage.read_file, M.WEATHER_LOG)
    if not ok or not data then return nil end
    
    local temps, humis = {}, {}
    for line in data:gmatch("[^\n]+") do
        local ok2, record = pcall(json.decode, line)
        if ok2 and record.d == today then
            if record.t then table.insert(temps, record.t) end
            if record.u then table.insert(humis, record.u) end
        end
    end
    
    if #temps == 0 then return nil end
    
    local function stats(t)
        table.sort(t)
        local sum = 0
        for _, v in ipairs(t) do sum = sum + v end
        return {min = t[1], max = t[#t], avg = sum / #t}
    end
    
    return {
        date = today,
        count = #temps,
        temp = stats(temps),
        humidity = stats(humis)
    }
end

-- 读取指定日期统计
function M.dayStats(date)
    local ok, data = pcall(storage.read_file, M.SPECIES_LOG)
    if not ok or not data then return nil end
    
    local species = {}
    for line in data:gmatch("[^\n]+") do
        local ok2, record = pcall(json.decode, line)
        if ok2 and record.d == date then
            table.insert(species, record)
        end
    end
    
    return species
end

-- 读取物种统计
function M.speciesStats(species, days)
    days = days or 1  -- 默认1天
    local since = os.time() - (days * 86400)
    
    local ok, data = pcall(storage.read_file, M.SPECIES_LOG)
    if not ok or not data then return nil end
    
    local visits = {}
    for line in data:gmatch("[^\n]+") do
        local ok2, record = pcall(json.decode, line)
        if ok2 and record.sp == species and record.ts >= since then
            table.insert(visits, record)
        end
    end
    
    if #visits == 0 then return nil end
    
    -- 统计活跃时段
    local hourCounts = {}
    for _, v in ipairs(visits) do
        hourCounts[v.h] = (hourCounts[v.h] or 0) + 1
    end
    
    local activeHours = {}
    for h, c in pairs(hourCounts) do
        if c >= 2 then
            table.insert(activeHours, h .. "时")
        end
    end
    
    return {
        species = species,
        total_visits = #visits,
        avg_per_day = math.floor(#visits / days * 10) / 10,
        active_hours = activeHours,
        first_visit = os.date("%Y-%m-%d", visits[1].ts),
        last_visit = os.date("%Y-%m-%d", visits[#visits].ts)
    }
end

return M