-- 功能：环境自适应：实现五个核心问题：天气自适应、关系分析、季节阈值、物种个性化、LLM分析

local json = require("json")
local storage = require("storage")
local capability = require("capability")
local M = {}
-- ==================== 环境自适应 ====================
-- 夜间降频配置
local NIGHT_HOURS = {22, 23, 0, 1, 2, 3, 4, 5}

function M.isNightTime()
    local hour = tonumber(os.date("%H"))
    for _, h in ipairs(NIGHT_HOURS) do
        if h == hour then return true end
    end
    return false
end

-- WiFi信号检测
function M.getWiFiSignal()
    local ok, info = pcall(capability.call, "wifi", "get_info")
    if ok and info then
        return info.rssi  -- 信号强度（dBm）
    end
    return nil
end

-- 自适应调整
function M.adaptiveAdjust(base_interval)
    local interval = base_interval or 60000
    
    -- 夜间降频
    if M.isNightTime() then
        interval = interval * 2  -- 夜间上报间隔翻倍
    end
    
    -- WiFi弱时降频
    local rssi = M.getWiFiSignal()
    if rssi and rssi < -70 then
        interval = interval * 3  -- WiFi弱时上报间隔三倍
    end
    
    -- 添加上下限限制（防止无限增长或过小）
    if interval > 600000 then interval = 600000 end  -- 最大10分钟
    if interval < 30000 then interval = 30000 end    -- 最小30秒
    
    return interval
end

-- ==================== 阈值学习 ====================
-- 平滑更新阈值
function M.smoothUpdate(current, target, factor)
    factor = factor or 0.3
    return current + (target - current) * factor
end

-- 学习阈值
function M.learnThreshold(current, observations)
    if #observations < 3 then return current end
    
    -- 计算平均值
    local sum = 0
    for _, v in ipairs(observations) do
        sum = sum + v
    end
    local target = sum / #observations
    
    -- 平滑更新
    return M.smoothUpdate(current, target, 0.3)
end

-- ==================== 五个核心问题实现 ====================

-- 问题一：天气变化时自动调整策略
-- 实现位置：main.lua 主循环内
-- 核心思路：main.lua 读取 animal_db.lua 获取物种阈值，根据天气/季节调整，写回 animal_env.json

-- 读取物种阈值（从animal_db.lua）
-- 修复：路径改为 /fatfs/config/animal_db.lua
function M.getSpeciesThreshold(species)
    local ok, db = pcall(dofile, "/fatfs/config/animal_db.lua")
    if ok and db and db[species] then
        local t = db[species]
        return {t_min = t[1], t_max = t[2], h_min = t[3], h_max = t[4]}
    end
    return {t_min = 15, t_max = 30, h_min = 40, h_max = 70}  -- 默认
end

-- 季节调整
function M.adjustBySeason(threshold)
    local month = tonumber(os.date("%m"))
    if month >= 6 and month <= 8 then
        -- 夏季：放宽上限
        threshold.t_max = threshold.t_max + 3
        threshold.h_min = threshold.h_min + 5
    elseif month >= 12 or month <= 2 then
        -- 冬季：收紧下限
        threshold.t_min = threshold.t_min - 3
        threshold.h_max = threshold.h_max - 5
    end
    return threshold
end

-- 天气调整
function M.adjustByWeather(threshold, weather)
    local temp = tonumber(weather.temp) or 25
    if temp > 35 then
        threshold.t_max = threshold.t_max + 2  -- 高温放宽
    elseif temp < 5 then
        threshold.t_min = threshold.t_min - 2  -- 低温收紧
    end
    return threshold
end

-- 写入animal_env.json
function M.writeThreshold(threshold, species)
    local config = {
        animal = species or "unknown",
        temp_threshold = {min = threshold.t_min, max = threshold.t_max},
        humidity_threshold = {min = threshold.h_min, max = threshold.h_max},
        source = "main.lua",
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
    pcall(storage.write_file, "/fatfs/config/animal_env.json", json.encode(config))
end

-- 问题二：发现"温湿度与物种出现的关系"
-- 实现位置：agent_learning.lua 模块
-- 核心思路：关联 weather_log.jsonl 和 species_log.jsonl，计算统计关联

function M.analyzeSpeciesWeatherRelation(species, days)
    days = days or 1  -- 默认1天
    local since = os.time() - (days * 86400)
    
    -- 获取物种访问记录
    local ok, data = pcall(storage.read_file, "/fatfs/data/species_log.jsonl")
    if not ok or not data then return nil end
    
    local speciesRecords = {}
    for line in data:gmatch("[^\n]+") do
        local ok2, record = pcall(json.decode, line)
        if ok2 and record.sp == species and record.ts >= since then
            table.insert(speciesRecords, record)
        end
    end
    
    if #speciesRecords < 3 then
        return nil, "数据不足（需要至少3次记录）"
    end
    
    -- 获取对应时间的气象数据
    local ok2, weatherData = pcall(storage.read_file, "/fatfs/data/weather_log.jsonl")
    if not ok2 or not weatherData then return nil end
    
    -- 统计物种出现时的温湿度
    local temps, humis = {}, {}
    for _, s in ipairs(speciesRecords) do
        -- 查找物种访问前后30分钟的气象数据
        for line in weatherData:gmatch("[^\n]+") do
            local ok3, w = pcall(json.decode, line)
            if ok3 and w.ts and math.abs(w.ts - s.ts) <= 1800 then
                if w.t then table.insert(temps, w.t) end
                if w.u then table.insert(humis, w.u) end
            end
        end
    end
    
    if #temps == 0 then return nil end
    
    -- 计算统计值
    local function stats(t)
        table.sort(t)
        local sum = 0
        for _, v in ipairs(t) do sum = sum + v end
        return {
            min = t[1],
            max = t[#t],
            avg = sum / #t,
            count = #t
        }
    end
    
    return {
        species = species,
        days = days,
        temp = stats(temps),
        humidity = stats(humis),
        visits = #speciesRecords
    }
end

-- 问题三：夏季和冬季使用相同阈值，不合理
-- 实现位置：agent_learning.lua 模块
-- 核心思路：根据季节调整阈值

local SEASONAL_ADJUSTMENTS = {
    spring = {t_min = 0, t_max = 0, h_min = 0, h_max = 0},
    summer = {t_min = 0, t_max = 3, h_min = 5, h_max = 5},
    autumn = {t_min = 0, t_max = 0, h_min = 0, h_max = 0},
    winter = {t_min = -3, t_max = 0, h_min = 0, h_max = -5}
}

-- 暴露给外部访问
M.SEASONAL_ADJUSTMENTS = SEASONAL_ADJUSTMENTS

function M.getCurrentSeason()
    local month = tonumber(os.date("%m"))
    if month >= 3 and month <= 5 then return "spring" end
    if month >= 6 and month <= 8 then return "summer" end
    if month >= 9 and month <= 11 then return "autumn" end
    return "winter"
end

function M.applySeasonalThreshold(threshold)
    local season = M.getCurrentSeason()
    local adj = SEASONAL_ADJUSTMENTS[season]
    
    threshold.t_min = threshold.t_min + adj.t_min
    threshold.t_max = threshold.t_max + adj.t_max
    threshold.h_min = threshold.h_min + adj.h_min
    threshold.h_max = threshold.h_max + adj.h_max
    
    return threshold
end

-- 问题四：不同物种偏好不同环境，无法个性化
-- 实现位置：agent_learning.lua 模块
-- 核心思路：物种个性化阈值配置

local SPECIES_PREFERENCES = {
    ["白头鹎"] = {t_min = 18, t_max = 28, h_min = 50, h_max = 75},
    ["麻雀"] = {t_min = 15, t_max = 25, h_min = 45, h_max = 70},
    ["喜鹊"] = {t_min = 10, t_max = 30, h_min = 40, h_max = 80},
    ["燕子"] = {t_min = 20, t_max = 32, h_min = 55, h_max = 85}
}

-- 暴露给外部访问
M.SPECIES_PREFERENCES = SPECIES_PREFERENCES

function M.getSpeciesPreference(species)
    return SPECIES_PREFERENCES[species]
end

function M.applySpeciesPreference(threshold, species)
    local pref = SPECIES_PREFERENCES[species]
    if pref then
        threshold.t_min = pref.t_min
        threshold.t_max = pref.t_max
        threshold.h_min = pref.h_min
        threshold.h_max = pref.h_max
    end
    return threshold
end

-- 问题五：行为模式学习，使用LLM分析
-- 实现位置：agent_learning.lua 模块
-- 核心思路：读取数据，构建prompt，调用LLM分析

function M.analyzeBehaviorWithLLM(species, days)
    days = days or 1  -- 默认1天
    
    -- 获取统计数据（从memory模块获取）
    -- 注意：speciesStats在agent_memory.lua中定义，需要通过外部传入或使用全局访问
    -- 这里使用简化版本，直接读取日志文件
    local ok, data = pcall(storage.read_file, "/fatfs/data/species_log.jsonl")
    if not ok or not data then return nil, "无数据" end
    
    local visits = {}
    local since = os.time() - (days * 86400)
    for line in data:gmatch("[^\n]+") do
        local ok2, record = pcall(json.decode, line)
        if ok2 and record.sp == species and record.ts >= since then
            table.insert(visits, record)
        end
    end
    
    if #visits == 0 then return nil, "无数据" end
    
    -- 计算统计信息
    local hourCounts = {}
    for _, v in ipairs(visits) do
        hourCounts[v.h] = (hourCounts[v.h] or 0) + 1
    end
    
    local activeHours = {}
    for h, c in pairs(hourCounts) do
        if c >= 1 then table.insert(activeHours, h .. "时") end
    end
    
    local stats = {
        total_visits = #visits,
        avg_per_day = math.floor(#visits / days * 10) / 10,
        active_hours = activeHours
    }
    
    -- 获取关系分析
    local relation = M.analyzeSpeciesWeatherRelation(species, days)
    
    -- 构建prompt
    local prompt = string.format([[
分析 %s 的行为模式：

最近%d天访问统计：
- 总访问次数：%d次
- 平均每天：%.1f次
- 活跃时段：%s

温湿度偏好分析：
- 出现温度范围：%.1f°C - %.1f°C（平均%.1f°C）
- 出现湿度范围：%.1f%% - %.1f%%（平均%.1f%%）

请分析：
1. 该物种的活动规律（时段偏好）
2. 环境偏好（温湿度范围）
3. 与季节/天气的关系
4. 保护建议
]], species, days, stats.total_visits, stats.avg_per_day,
    table.concat(stats.active_hours, ", ") or "数据不足",
    relation and relation.temp.min or 0,
    relation and relation.temp.max or 0,
    relation and relation.temp.avg or 0,
    relation and relation.humidity.min or 0,
    relation and relation.humidity.max or 0,
    relation and relation.humidity.avg or 0)
    
    -- 调用LLM
    local ok, result = pcall(capability.call, "llm", "generate", {prompt = prompt})
    if ok and result then
        return result.text or result.content or result
    end
    
    return nil, "LLM调用失败"
end

-- 定期行为分析（每天一次）
function M.dailyBehaviorAnalysis()
    local speciesList = {"白头鹎", "麻雀", "喜鹊", "燕子"}
    local reports = {}
    
    for _, species in ipairs(speciesList) do
        local report = M.analyzeBehaviorWithLLM(species, 1)  -- 分析最近1天
        if report then
            table.insert(reports, {
                species = species,
                report = report,
                date = os.date("%Y-%m-%d")
            })
        end
    end
    
    return reports
end

return M
