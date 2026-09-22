-- AI_blogger.lua v2.10.0 野生动物AI博主模块
-- v2.9.0 Plan B+:拍完三张立即关灯,减少对动物干扰
--   - take3Photos 末尾(closeCameraHard 前)调 fillLEDOffSafe()
--   - 识别/生成/发送期间灯关(这些阶段不依赖 GPIO46)
--   - sendBlog / safeCleanup 末尾的 fillLEDOffSafe() 保留(幂等兜底)
-- v2.8.0 Plan B 灯控重构:
--   - 去掉模块加载时的 pcall(fillLEDOff)(灯态由主脚本 yeshengdongwu17b.lua 统一管理)
--   - take3Photos 循环去掉每张的 on/off,只 sd(200) 做帧稳定
--   - sendBlog 成功后 fillLEDOffSafe()(业务完成关灯)
--   - safeCleanup 改为 fillLEDOffSafe()(兜底)
--   - 新增 fillLEDOnSafe/fillLEDOffSafe 包装函数,与 yeshengdongwu17b.lua 共享 g.fillOn 状态
-- v2.7.54 补光时机对齐 yeshengdongwu17b.lua cap:
-- v2.7.53 补光时机修正:开灯 -> 等 800ms -> 丢过渡帧 -> 等 200ms -> 抓帧
-- v2.7.52 GPIO46 普通 LED 补光(yeshengdongwu17b.lua cap 节奏):
--   - take3Photos 每轮:dropStaleFrames -> 开灯 -> sd(1000) -> 抓帧保存 -> sd(200) -> 关灯
-- v2.7.51 识别间隔 2s -> 3s(仍有失败,继续加间隔):
--   - v2.7.51 改为 3s:3 张图识别阶段总用时 8s -> 12s,接近 v2.7.47 的 16s
--   - 流程延长 2s,可接受
-- v2.7.50 识别间隔 1s -> 2s(基于 v2.7.47 三图全成经验):
--   - v2.7.47 识别间隔 8s,三图全成功
--   - v2.7.48 把识别间隔改回 1s 后,图2 出现概率性识别失败
--   - v2.7.49 沿用 1s + 改 max_tokens 后,图3 仍识别失败
--   - 折中方案:识别间隔 1s -> 2s,给 cloud_vision 服务端足够恢复时间
--   - 3 张图识别阶段总增加 3s(8s -> 11s),可接受
-- v2.7.49 修复"总报告必然走兜底 + 图识别偶发失败":
--   - v2.7.48 测试反馈:图2识别失败(概率性);v2.7.47 三图全失败
--   - 两个版本总报告都触发兜底(100% 失败)
--   - 根因(从 cloud_resp.json 抓到的硬证据):
--     * finish_reason = "length" -> 响应被 max_tokens 截断
--     * completion_tokens = 1200(用满)
--     * completion_tokens_details.reasoning_tokens = 1199
--       => MiniMax-M3 把 1199/1200 tokens 全部花在<think>...</think>思考块
--       => 实际响应只剩 1 token,content 字段被截断在 think 中间
--       => cloud_vision.clean_resp 用<think>.-` 把整个内容全删,返回 ""
--       => genArticle 拿到空字符串 -> parseSegments 全空 -> 走兜底
--   - 这是模型层面的问题(think 极长),不是 PSRAM / 拍照 / 连接的问题
--   - v2.7.49 修复:
--     1) genArticle max_tokens 1200 -> 3000
--        留 ~1500 tokens 给 think,~1500 tokens 给实际输出(标题+整体观察+小科普+互动话题)
--     2) inspDetail max_tokens 300 -> 500
--        v2.7.48 用 300 时 think 偶发 >300 把响应截断,500 给出充足缓冲
--     3) inspDetail prompt 加 "直接给出最终描述,无需思考过程" 提示
--        减少 think 长度,降低被截断概率
--     4) 拍照/识别间隔、4 段报告、sanitizeText、多样化兜底、历史延续全部保留
-- v2.7.48 拍照间隔 8s / 识别间隔 1s / inspDetail 单次 / genArticle 3 次重试
-- v2.7.47 识别间隔 1s->8s + inspDetail 7 次重试(假设速率限流,错误)
-- v2.7.46 7 次重试 + 删除单图重拍
-- v2.7.45 加重拍机制 + 7 次重试
-- v2.7.44 genArticle + inspDetail 双重重试升级
-- v2.7.43 加重试 + 再精简(inspDetail)
-- v2.7.42 精简(inspDetail 改为不分行 + 短 prompt)
-- v2.7.41 修复(genArticle 100% 走兜底) -> 改用 cv.generate(prompt, max_tokens, temperature)
local delay=require("delay")
local camera=require("camera")
local image=require("image")
local storage=require("storage")
local board_manager=require("board_manager")
local capability=require("capability")
local json=require("json")
local gpio=require("gpio")

local FILL_GPIO=46
local function fillLEDInit()pcall(gpio.set_direction,FILL_GPIO,"output")end
local function fillLEDOn()pcall(gpio.set_level,FILL_GPIO,1)end
local function fillLEDOff()pcall(gpio.set_level,FILL_GPIO,0)end
local function fillLEDOnSafe()if g.fillOn then return end fillLEDOn()g.fillOn=true end
local function fillLEDOffSafe()if not g.fillOn then return end fillLEDOff()g.fillOn=false end

if not _G._ai_blogger_cv then
    local ok, mod = pcall(dofile, "/fatfs/scripts/user/cloud_vision.lua")
    if ok and type(mod) == "table" then
        _G._ai_blogger_cv = mod
    else
        return { run = function() return false end }
    end
end
local cv = _G._ai_blogger_cv

local FEISHU = "ou_XXXXXXXXXXXXXXXXXXXXXXXX"  -- TODO: 替换为你的飞书 chat_id
local g = _G.g or {}
if g.fillOn == nil then g.fillOn = false end

local function cleanOldFiles()
    local R = storage.get_root_dir()
    local P = storage.join_path(R, "blog")
    pcall(storage.mkdir, P)
    local files = storage.list_dir(P)
    if files then
        for _, f in ipairs(files) do
            if f.name and f.name:match("%.jpg$") then
                pcall(storage.remove, storage.join_path(P, f.name))
            end
        end
        pcall(storage.sync)
    end
end

pcall(cleanOldFiles)
pcall(fillLEDInit)

local function aborted()
    return not (_G.g and _G.g.running)
end

local function sd(ms)
    ms = math.floor(ms + 0.5)
    if ms <= 0 then return end
    while ms > 0 do
        if aborted() then break end
        local s = math.min(ms, 10)
        delay.delay_ms(s)
        ms = ms - s
    end
end

local function txt(m)
    pcall(capability.call, "feishu_send_message",
        {message = m},
        {channel = "feishu", chat_id = FEISHU, source_cap = "lua_wildlife_monitor"})
end

local function pic(p, c)
    pcall(capability.call, "feishu_send_image",
        {path = p, caption = c or ""},
        {channel = "feishu", chat_id = FEISHU, source_cap = "lua_wildlife_monitor"})
end

local function safeCleanup()
    pcall(camera.close)
    if g then g.cam = false end
    if _G.g then _G.g.cam = false end
    collectgarbage("collect")
    collectgarbage("collect")
    sd(300)
    fillLEDOffSafe()
end

local function closeCameraHard()
    pcall(camera.close)
    sd(400)
    pcall(camera.close)
    sd(400)
    collectgarbage("collect")
    collectgarbage("collect")
    sd(300)
end

local function dropStaleFrames()
    if aborted() then return end
    pcall(camera.flush)
    for i = 1, 2 do
        if aborted() then break end
        local f = camera.get_frame(2000)
        if f then f:release() end
    end
end

local stripAnalysisFields
stripAnalysisFields = function(input)
    local n = tostring(input or "")
    if n == "" then return n end
    n = n:gsub("%*%*结构特征%*%*%s*[：:]?", "巢穴细节:")
    n = n:gsub("%*%*拍摄视角%*%*%s*[：:]?", "画面描述:")
    n = n:gsub("%*%*拍摄角度%*%*%s*[：:]?", "画面描述:")
    return n
end

local FORBIDDEN_TERMS = {
    "藤编", "编织", "柳编", "竹编", "编制",
    "篮筐", "篮子", "篮篓",
    "藤篮", "竹篮", "柳篮", "藤篓", "竹篓", "柳篓",
    "藤条", "柳条", "竹条",
    "编织筐", "编织篮", "藤编筐", "藤编篮", "编筐", "编篮",
}
local PATTERN_CANG = "[^%p%s%c]+"

local function filterNaming(text)
    if not text or text == "" then return text end
    for _, term in ipairs(FORBIDDEN_TERMS) do
        text = text:gsub(term, "智能巢穴")
    end
    text = text:gsub("藤编" .. PATTERN_CANG, "智能巢穴")
    text = text:gsub("编织" .. PATTERN_CANG, "智能巢穴")
    text = text:gsub("柳编" .. PATTERN_CANG, "智能巢穴")
    text = text:gsub("竹编" .. PATTERN_CANG, "智能巢穴")
    text = text:gsub("编制" .. PATTERN_CANG, "智能巢穴")
    return text
end

local sanitizeText
sanitizeText = function(input)
    local n = tostring(input or "")
    if n == "" then return n end
    n = stripAnalysisFields(n)
    n = filterNaming(n)
    n = n:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return n
end

-- v2.7.49:max_tokens 300 -> 500,prompt 加"直接给出最终描述,无需思考过程"
--   原因:M3 模型 think 极长,300 tokens 时 think 偶发 >300 把响应截断
--        500 tokens 给出充足缓冲,同时 prompt 引导减少 think 长度
local function inspDetail(p, idx)
    if aborted() then return nil, "aborted" end
    local prompt = "请直接给出这张图片中野生动物的最终描述(无需思考过程),包括:动物种类、姿态(站立/趴卧/行走/进食等)、表情、环境特征。用简洁中文回答。"
    local ok, r, e = pcall(cv.analyze, p, prompt, 500)
    if not ok then return nil, "cv_throw:" .. tostring(r) end
    if not r then return nil, "inspect_failed:" .. tostring(e) end
    if r == "" then return nil, "no_result" end
    local detail = sanitizeText(tostring(r))
    if detail == "" then return nil, "empty_after_filter" end
    return detail, nil
end

local last_article = ""

local function parseSegments(raw)
    local s = raw
    if type(s) == "table" then
        s = s.text or s.content or ""
    end
    s = tostring(s or "")
    s = s:gsub("<think>.-</think>", "")
    s = s:gsub("<think>.-", "")
    s = s:gsub("^%s*```%w*%s*", ""):gsub("%s*```%s*$", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")

    local result = { title = "", story = "", fact = "", question = "" }
    local function set_field(tag, content)
        content = (content or ""):gsub("^%s+", ""):gsub("[%s　]+$", "")
        if tag == "标题" then result.title = content
        elseif tag == "整体观察" then result.story = content
        elseif tag == "小科普" then result.fact = content
        elseif tag == "互动话题" then result.question = content
        end
    end

    for tag, content in s:gmatch("【([^】]+)】%s*(.-)%s*【") do
        set_field(tag, content)
    end
    local last_tag, last_content = s:match("【([^】]+)】%s*(.-)$")
    if last_tag then set_field(last_tag, last_content) end

    return result
end

local function extractSpeciesFromDetail(s)
    if not s or s == "" then return nil end
    local n = s:match("动物种类[%s:：]+([^。,.;；、]+)")
    if not n then
        n = s:match("动物[%s:：]+([^。,.;；、]+)")
    end
    if not n then return nil end
    n = n:gsub("[%*#]", ""):gsub("^[%s　]+", ""):gsub("[%s　]+$", "")
    if #n < 2 or #n > 14 then return nil end
    return n
end

local function pickAnimalLabel(raw, descs)
    raw = tostring(raw or "")
    if raw ~= "" and not raw:lower():find("unknown") and raw ~= "unknown(默认阈值)" then
        return raw
    end
    for _, d in ipairs(descs or {}) do
        if d then
            local n = extractSpeciesFromDetail(d)
            if n then return n end
        end
    end
    return "小家伙"
end

local function strHash(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 2147483647
    end
    return h
end

local FALLBACK_STORIES = {
    "今天的%s在镜头前呈现出一种稳定而温润的状态🌿 三段连续画面记录下它与巢穴相处的节奏,从一处细节到一个表情,都让人越看越平静✨ 没有刻意的表演,只有最自然的栖息瞬间~%s",
    "本期记录到%s的几个关键时刻🌿 巢穴的光线、材质的触感、空气里微弱的气流,都能在画面里被放大,显得格外温柔✨ 这种被认真记录的片段,本身就是最珍贵的~%s",
    "%s今日状态平稳,镜头捕捉到了从神情体态到环境氛围的多个切面 三段连续画面既能看到它的小习惯,也能感受到巢穴整体的温度✨ 越是简单的瞬间,越值得反复品味~%s",
    "在%s的小世界里,安静是一种常态🌿 三帧连续画面的变化,既有节奏也有留白,每一个切片都是它日常的一角~✨ 镜头只负责记录,情绪交给屏幕前的你去感受~%s",
    "今日%s的小记录来啦🌿 三段连续画面既是它一日的小缩影,也折射出巢穴里光线与材质的细节✨ 没有跌宕起伏,有的只是温柔的陪伴感~%s",
    "跟随镜头一起走近%s的栖息空间🌿 连续画面里能看到它的神情、巢穴的触感以及空气里细微的氛围,层层叠加出此刻的温度✨ 这种被认真对待的瞬间,本身就很有治愈感~%s",
}
local FALLBACK_END_EMOJI = {"🍃","✨","","💤","","🍂","🌟","🌈","☁️","🌙"}

local function buildFallbackStory(animal_label, descs)
    local combined = table.concat({descs[1] or "", descs[2] or "", descs[3] or ""})
    local h = strHash(combined)
    local idx = (h % #FALLBACK_STORIES) + 1
    local eIdx = (h % #FALLBACK_END_EMOJI) + 1
    return FALLBACK_STORIES[idx]:format(animal_label, FALLBACK_END_EMOJI[eIdx])
end

local FALLBACK_TITLES = {
    "✨【%s今日观察】",
    "🌿【%s小记·第%s期】",
    "📕【巢穴日志·%s篇】",
    "🐾【%s今日时间线】",
}
local function buildFallbackTitle(animal_label, descs)
    local combined = table.concat({descs[1] or "", descs[2] or "", descs[3] or ""})
    local h = strHash(combined .. "title")
    local idx = (h % #FALLBACK_TITLES) + 1
    if idx == 2 then
        local episode = ((math.floor(h / 7)) % 99) + 1
        return FALLBACK_TITLES[idx]:format(animal_label, tostring(episode))
    end
    return FALLBACK_TITLES[idx]:format(animal_label)
end

local FALLBACK_FACTS = {
    "作为生态链中的一环,%s的每一次出现都让这片小天地多了些许生机 持续观察它们的活动节律,正是守护的开始~🌿",
    "你知道吗?%s的日常作息其实非常规律,从觅食到休憩都对应着微弱的环境变化✨ 这种节奏感,正是自然最迷人的地方之一~🍃",
    "有趣的冷知识:%s往往会根据光线、温度选择最舒适的角落停留,而每一次停留都是它对环境的一次\"投票\"🌿 观察这些选择,本身就是一种享受~💤",
}
local function buildFallbackFact(animal_label, descs)
    local combined = table.concat({descs[1] or "", descs[2] or "", descs[3] or ""})
    local h = strHash(combined .. "fact")
    local idx = (h % #FALLBACK_FACTS) + 1
    return FALLBACK_FACTS[idx]:format(animal_label)
end

local FALLBACK_QUESTIONS = {
    "在这三段画面里,你更被哪一个瞬间打动?",
    "你最喜欢今天哪个细节的瞬间呀?",
    "看完这三张照片,你最想为它做点什么?",
}
local function buildFallbackQuestion(descs)
    local combined = table.concat({descs[1] or "", descs[2] or "", descs[3] or ""})
    local h = strHash(combined .. "question")
    local idx = (h % #FALLBACK_QUESTIONS) + 1
    return FALLBACK_QUESTIONS[idx]
end

-- v2.7.49:genArticle max_tokens 1200 -> 3000
--   原因:M3 模型实测 reasoning_tokens=1199(占满 1200),实际响应 1 token 被截断
--        3000 tokens 留 ~1500 给 think,~1500 给实际输出
--        4 段报告(标题+整体观察+小科普+互动话题)约 400-500 字,折合 ~800-1000 tokens
--   文本生成(LLM)比图像识别(LLM+图)稳定,3 次重试价值高,继续保留
local function genArticle(animal, descs, t, h)
    if aborted() then return "", "aborted" end

    local d1 = sanitizeText(descs[1] or "无有效描述")
    local d2 = sanitizeText(descs[2] or "无有效描述")
    local d3 = sanitizeText(descs[3] or "无有效描述")

    local animal_label = pickAnimalLabel(animal, {d1, d2, d3})

    local history_context = ""
    if last_article ~= "" then
        history_context = "\n\n【上一期笔记内容(请延续故事,不要简单重复)】:\n" .. last_article .. "\n\n"
    end

    local prompt = "你是野生动物保护领域的AI博主,正在为\"野生动物之家\"自动撰写小红书笔记。\n\n" ..
                   "任务:下面提供了 3 张连续拍摄的照片描述(按时间顺序)。" ..
                   "请为这组照片撰写一段「总报告式」的整体性文字。" .. history_context .. "\n\n" ..
                   "动物种类:" .. animal_label .. "\n" ..
                   "照片1描述:" .. d1 .. "\n" ..
                   "照片2描述:" .. d2 .. "\n" ..
                   "照片3描述:" .. d3 .. "\n" ..
                   "当前巢穴环境:温度" .. tostring(t) .. "°C,湿度" .. tostring(h) .. "%\n\n" ..
                   "【重要:总报告与单张照片文案的区分】\n" ..
                   "  - 这段\"总报告\"会作为一段综合叙述单独发出,而每张单张照片稍后会**单独发送**各自的详细描述。\n" ..
                   "  - 因此,总报告中**不要**逐一复读式地列举\"图1...图2...图3...\"。\n" ..
                   "  - **不要**使用\"图1/图2/图3/第一张/第二张/第三张\"等序号小标题或目录式罗列。\n" ..
                   "  - **不要**逐张复述单张照片的具体细节(姿态、毛色、表情、动作等)。\n\n" ..
                   "请按下面**纯文本分段**输出,严格使用【XXX】包裹每段标题,每段之间空一行," ..
                   "**不要输出 JSON、不要输出 Markdown 代码块、不要加任何额外前缀、解释或注释**:\n\n" ..
                   "【标题】不超过20字,含2~3个emoji\n\n" ..
                   "【整体观察】180~260字。围绕这3张连续画面的【整体主线、氛围基调、观察结论】展开," ..
                   "用第一人称或拟人化口吻,综合概括3张图的共性与核心主题(栖息舒适度/活动节律/性格气质/今日亮点等)," ..
                   "形成一段概括并梳理汇总的总体性文字描述,不要逐张描述。\n" ..
                   "    建议素材:从3张图中提炼出1~2个共性/整体气质/今日主线,辅以环境(温度/湿度/光线/材质)的整体氛围," ..
                   "穿插6~10个自然emoji,语言自然、有温度,适合小红书阅读。\n\n" ..
                   "【小科普】50~80字,与该动物相关的小科普或趣味冷知识\n\n" ..
                   "【互动话题】一句不超过30字的互动提问,鼓励读者评论\n\n" ..
                   "注意:\n" ..
                   "1. 必须严格按上面 4 个【XXX】分段顺序输出,标题只能是【标题】【整体观察】【小科普】【互动话题】这4个,不要新增/删减分段。\n" ..
                   "2. 【整体观察】段是对 3 张图的「总体性/综合性」描述,不是逐张描述;不要出现\"图1/图2/图3/第一张/第二张/第三张\",也不要复读单张照片的具体细节。\n" ..
                   "3. 各段文字中不要出现任何关于\"编织/藤编/篮筐/藤条/柳条/竹条\"的描述,如出现请改写为\"智能巢穴\"。"

    local parsed = { title = "", story = "", fact = "", question = "" }
    local last_err = nil

    for attempt = 1, 3 do
        if aborted() then return "", "aborted" end

        local ok, out, err = pcall(cv.generate, prompt, 3000, 0.8)
        if ok and type(out) == "string" and out ~= "" then
            parsed = parseSegments(out)
            local non_empty = 0
            if parsed.title ~= "" then non_empty = non_empty + 1 end
            if parsed.story ~= "" then non_empty = non_empty + 1 end
            if parsed.fact ~= "" then non_empty = non_empty + 1 end
            if parsed.question ~= "" then non_empty = non_empty + 1 end
            if non_empty >= 2 then
                if attempt > 1 then
                    print(string.format("[genArticle] 第%d次重试成功,有效段=%d", attempt, non_empty))
                end
                break
            end
            last_err = "parse_insufficient"
        elseif not ok then
            last_err = "cv_throw:" .. tostring(out)
        elseif not out then
            last_err = "gen_failed:" .. tostring(err)
        else
            last_err = "empty_output"
        end

        if attempt < 3 and not aborted() then
            sd(2000)
        end
    end

    if parsed.title == "" then parsed.title = buildFallbackTitle(animal_label, {d1, d2, d3}) end
    if parsed.story == "" then parsed.story = buildFallbackStory(animal_label, {d1, d2, d3}) end
    if parsed.fact == "" then parsed.fact = buildFallbackFact(animal_label, {d1, d2, d3}) end
    if parsed.question == "" then parsed.question = buildFallbackQuestion({d1, d2, d3}) end

    local envText = string.format("🐾 状态: %s\n🌡️ 温度: %s°C\n 湿度: %s%%\n 时间: %s",
        animal_label, tostring(t), tostring(h), (os.date("%H:%M") or "--"))

    local article = table.concat({
        parsed.title,
        "✨ 整体观察 \n" .. parsed.story,
        "🌿 巢穴环境小档案 \n" .. envText,
        "💡 小科普 \n" .. parsed.fact,
        "💬 互动话题 💬\n" .. parsed.question,
        "🏷️ 话题标签 ️\n#野生动物保护 #" .. animal_label .. "观察 #自然笔记",
    }, "\n\n")

    article = sanitizeText(article)
    last_article = #article > 200 and (article:sub(1, 200) .. "……") or article
    return article, nil
end

-- v2.8.0 Plan B 灯控重构:
--   - 循环内不再 on/off,只 sd(200) 做帧稳定(灯已由主脚本保持开启)
--   - 失败路径(fillLEDOff)改为 fillLEDOffSafe()(幂等)
-- v2.7.54:补光节奏对齐 yeshengdongwu17b.lua cap,逐轮:
--   fillLEDOn -> sd(1000) -> dropStaleFrames -> get_frame -> save -> sd(200) -> fillLEDOff
--   - 去掉循环内冗余 pcall(fillLEDInit)(模块加载时已 init)
--   - 开灯后等待 1000ms(原 800ms),给 LED 充分点亮 + 传感器完成曝光/白平衡调整
--   - 去掉 dropStaleFrames 与 get_frame 之间的 sd(200)(cap 中无此段)
-- v2.7.53:补光顺序改为 开灯 -> sd(800) -> 丢过渡帧 -> sd(200) -> 抓帧保存 -> sd(200) -> 关灯
-- v2.7.52:每轮拍照补光节奏(对齐 yeshengdongwu17b cap)
--   dropStaleFrames -> 开灯 -> sd(1000) -> 抓帧保存 -> sd(200) -> 关灯
--   循环结束后保险关灯
--   safeCleanup 末尾关灯
-- v2.7.51:识别间隔 2s -> 3s(v2.7.50 仍图3 失败,继续加间隔)
--   拍照间隔 8s 保留不变,识别间隔从 2s 改为 3s
--   3 张图识别阶段总用时 8s -> 12s(比 v2.7.47 的 16s 短 4s)
-- v2.7.50:识别间隔 1s -> 2s,基于 v2.7.47 三图全成的成功经验
-- v2.7.49:拍照/识别间隔、4 段报告、sanitizeText、多样化兜底、历史延续全部保留
--   拍照间隔 8s / 识别间隔 1s / inspDetail 单次调用(无重试,沿用 v2.7.48)
--   genArticle max_tokens 3000(原 1200,本次修复)
--   总调用次数:3 次 cv.analyze + 最多 3 次 cv.generate
local function take3Photos(animal)
    local R = storage.get_root_dir()
    local P = storage.join_path(R, "blog")
    pcall(storage.mkdir, P)

    local paths, descs = {}, {}

    local cp = board_manager.get_camera_paths()
    if not cp then
        txt("AI博主:无摄像头路径")
        fillLEDOffSafe()
        return {}, {}
    end

    if aborted() then
        fillLEDOffSafe()
        return {}, {}
    end

    closeCameraHard()
    if g then g.cam = false end
    if _G.g then _G.g.cam = false end
    collectgarbage("collect")
    collectgarbage("collect")

    local ok, ret = pcall(camera.open, cp.dev_path)
    if not ok or ret == false or ret == nil then
        pcall(camera.close)
        txt("❌AI博主:相机打开失败")
        fillLEDOffSafe()
        return {}, {}
    end
    if g then g.cam = true end
    if _G.g then _G.g.cam = true end

    for i = 1, 3 do
        if aborted() then break end

        -- v2.8.0 Plan B:灯已由主脚本开启,这里只做帧稳定
        sd(200)

        dropStaleFrames()
        if aborted() then break end

        local pp = storage.join_path(P, animal .. "_blog_" .. os.time() .. "_" .. i .. ".jpg")

        local okf, f = pcall(camera.get_frame, 3000)
        if okf and f then
            local sav = pcall(image.save_file, pp, f)
            pcall(function() f:release() end)
            if sav then
                paths[i] = pp
            else
                paths[i] = nil
                descs[i] = "照片" .. i .. "(保存失败)"
            end
        else
            paths[i] = nil
            descs[i] = "照片" .. i .. "(拍摄失败)"
        end

        sd(200)
        -- v2.8.0 Plan B:循环内不关灯,由 sendBlog 成功后统一关灯

        if i < 3 then sd(8000) end  -- 拍照间隔 8s(沿用 v2.7.48)
    end

    -- v2.9.0 Plan B+:循环后立即关灯,识别/生成/发送期间不亮灯,减少对动物干扰
    fillLEDOffSafe()
    closeCameraHard()
    if g then g.cam = false end
    if _G.g then _G.g.cam = false end

    -- 识别循环:3s 间隔(v2.7.51,继续加间隔)
    for i = 1, #paths do
        if aborted() then break end
        if paths[i] then
            local d = inspDetail(paths[i], i)
            descs[i] = d and ("📸 图" .. i .. "：" .. d) or ("📸 图" .. i .. "：(识别失败)")
        else
            descs[i] = descs[i] or ("📸 图" .. i)
        end
        if i < #paths and not aborted() then sd(3000) end  -- 识别间隔 3s(v2.7.51)

    end


    return paths, descs
end

local function sendBlog(animal, paths, descs, article)
    if not paths or #paths == 0 then
        txt("❌AI博主:无可用照片")
        return false
    end
    if aborted() then return false end

    txt("📕【野生动物AI博主】")
    txt("━━━━━━━━━━━━━━━━")
    for seg in (article .. "\n\n"):gmatch("([^\n]+)\n\n") do
        if seg ~= "" then txt(seg); sd(300) end
    end
    txt("━━━━━━━━━━━━━━━━")

    for i, p in ipairs(paths) do
        if aborted() then break end
        if p then pic(p, descs[i] or ""); sd(500) end
    end

    for _, p in ipairs(paths) do
        if p then
            for retry = 1, 3 do
                if pcall(storage.remove, p) then break end
                if retry < 3 and not aborted() then sd(1000) end
            end
        end
    end
    pcall(storage.sync)
    fillLEDOffSafe()  -- v2.8.0 Plan B:业务完成关灯
    return true
end

function run(animal, env)
    local function fail(step, err) txt("❌AI博主[" .. step .. "]\n" .. tostring(err)) end

    -- v2.10.0: ai.run() 入口不再调 safeCleanup(它会 fillLEDOffSafe 关灯,
    -- 导致 take3Photos 拍照时灯已关=失败)。只关相机,保留主脚本已开的灯。
    pcall(camera.close)
    if g then g.cam = false end
    if _G.g then _G.g.cam = false end
    collectgarbage("collect")
    collectgarbage("collect")
    sd(300)
    pcall(cleanOldFiles)
    if aborted() then fillLEDOffSafe() return false end

    local t = (g and g.lt) or "--"
    local h = (g and g.lh) or "--"

    local paths, descs = {}, {}
    local ok_b, paths_b, descs_b = pcall(take3Photos, animal)
    if not ok_b then fail("拍照", paths_b); safeCleanup(); return false end
    paths, descs = paths_b, descs_b

    if aborted() then safeCleanup() return false end

    local article = ""
    if paths and #paths > 0 then
        local ok_c, article_c = pcall(genArticle, animal, descs, t, h)
        if not ok_c then
            fail("生成", article_c)
            article = "🦊【观察日记】\nAI博主暂时无法生成文章,但已记录精彩瞬间~📸\n#野生动物保护 #自然笔记"
        else
            article = article_c or ""
        end
    end

    if aborted() then safeCleanup() return false end

    if paths and #paths > 0 then
        local ok_d, send_err = pcall(sendBlog, animal, paths, descs, article)
        if not ok_d then fail("发送", send_err) end
    end

    safeCleanup()
    return true
end

return { run = run }