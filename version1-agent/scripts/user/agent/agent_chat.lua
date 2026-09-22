-- agent_chat.lua
-- 功能：对话查询
-- 版本：V7.3
-- 说明：处理飞书查询指令，返回分析结果

local json = require("json")
local storage = require("storage")

local M = {}

-- 查询处理函数
function M.handleQuery(query, memory, learning)
    query = query or ""
    query = query:lower()
    
    -- 查询今日天气统计
    if query:find("今天天气") or query:find("今日天气") then
        local stats = memory.todayStats()
        if stats then
            return string.format(
                "今日气象统计（%s）\n" ..
                "温度：%.1fC（最低%.1fC，最高%.1fC）\n" ..
                "湿度：%.1f%%（最低%.1f%%，最高%.1f%%）\n" ..
                "记录次数：%d次",
                stats.date,
                stats.temp.avg, stats.temp.min, stats.temp.max,
                stats.humidity.avg, stats.humidity.min, stats.humidity.max,
                stats.count
            )
        else
            return "今日无气象数据"
        end
    end
    
    -- 查询最近物种访问（支持多种问法）
    if query:find("最近来了什么") or query:find("最近访问") or 
       query:find("来了什么") or query:find("最近来了") or
       query:find("物种访问") or query:find("动物访问") then
        local records = memory.readLast(memory.SPECIES_LOG, 5)
        if #records > 0 then
            local result = "最近物种访问记录：\n"
            for _, r in ipairs(records) do
                result = result .. string.format(
                    "- %s %s %d时（温度%.1fC，湿度%.1f%%）\n",
                    r.d, r.sp, r.h, r.lt or 0, r.lh or 0
                )
            end
            return result
        else
            return "最近无物种访问记录"
        end
    end
    
    -- 查询物种分析
    if query:find("分析") then
        local species = query:match("分析(.+)") or query:match("分析(.-)$")
        if species then
            species = species:gsub("^%s*", ""):gsub("%s*$", "")
            local report = learning.analyzeBehaviorWithLLM(species, 3)
            if report then
                return species .. " 行为分析报告：\n" .. report
            else
                return "无法分析 " .. species .. "（数据不足）"
            end
        end
    end
    
    -- 查询季节阈值
    if query:find("季节阈值") or query:find("当前阈值") then
        local season = learning.getCurrentSeason()
        local adj = learning.SEASONAL_ADJUSTMENTS[season]
        
        local seasonNames = {
            spring = "春季",
            summer = "夏季",
            autumn = "秋季",
            winter = "冬季"
        }
        
        return string.format(
            "当前季节：%s\n" ..
            "温度调整：%+dC ~ %+dC\n" ..
            "湿度调整：%+d%% ~ %+d%%",
            seasonNames[season] or season,
            adj.t_min, adj.t_max,
            adj.h_min, adj.h_max
        )
    end
    
    -- 查询物种偏好
    if query:find("物种偏好") or query:find("偏好") then
        local result = "物种环境偏好配置：\n"
        for species, pref in pairs(learning.SPECIES_PREFERENCES) do
            result = result .. string.format(
                "- %s：温度 %d-%dC，湿度 %d-%d%%\n",
                species, pref.t_min, pref.t_max, pref.h_min, pref.h_max
            )
        end
        return result
    end
    
    -- 查询关系分析
    if query:find("关系分析") then
        local species = query:match("关系分析(.+)") or query:match("关系分析(.-)$")
        if species then
            species = species:gsub("^%s*", ""):gsub("%s*$", "")
            local relation = learning.analyzeSpeciesWeatherRelation(species, 3)
            if relation then
                return string.format(
                    "%s 温湿度关联分析（最近%d天）：\n" ..
                    "出现温度：%.1fC - %.1fC（平均%.1fC，%d次记录）\n" ..
                    "出现湿度：%.1f%% - %.1f%%（平均%.1f%%）\n" ..
                    "访问次数：%d次",
                    species, relation.days,
                    relation.temp.min, relation.temp.max, relation.temp.avg, relation.temp.count,
                    relation.humidity.min, relation.humidity.max, relation.humidity.avg,
                    relation.visits
                )
            else
                return "无法分析 " .. species .. " 的关系（数据不足）"
            end
        end
    end
    
    -- 查询每天报告
    if query:find("每天报告") or query:find("日报") then
        local reports = learning.dailyBehaviorAnalysis()
        if #reports > 0 then
            local result = "每日行为分析报告（" .. os.date("%Y-%m-%d") .. "）：\n\n"
            for _, r in ipairs(reports) do
                result = result .. string.format(
                    "%s：\n%s\n\n",
                    r.species, r.report
                )
            end
            return result
        else
            return "今日无行为分析报告"
        end
    end
    
    -- 默认回复
    return "可用指令：\n" ..
           "今天天气 - 今日气象统计\n" ..
           "最近来了什么 - 最近物种访问\n" ..
           "分析[物种] - 行为分析（如：分析白头鹎）\n" ..
           "季节阈值 - 当前季节阈值\n" ..
           "物种偏好 - 物种环境偏好\n" ..
           "关系分析[物种] - 温湿度关联（如：关系分析白头鹎）\n" ..
           "每天报告 - 所有物种日报"
end

return M
