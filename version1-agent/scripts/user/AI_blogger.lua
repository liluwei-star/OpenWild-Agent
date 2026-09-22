-- AI_blogger.lua v2.7.8 野生动物AI博主模块
-- 改进点(对比 v2.7.7):
--   1. take3Photos 简化为单次打开(根因是 PSRAM 碎片,collectgarbage 即可修复,无需 4 次重试)
--   2. 保留 closeCameraHard / safeCleanup 的 collectgarbage
--   3. 保留 run() 的分阶段错误上报(用于诊断 AI_blogger 模块自身崩溃)
local delay=require("delay")
local camera=require("camera")
local image=require("image")
local storage=require("storage")
local board_manager=require("board_manager")
local capability=require("capability")
local json=require("json")

if not _G._ai_blogger_cv then
    local ok, mod = pcall(dofile, "/fatfs/scripts/user/cloud_vision.lua")
    if ok and type(mod) == "table" then
        _G._ai_blogger_cv = mod
    else
        return { run = function() return false end }
    end
end
local cv = _G._ai_blogger_cv

local FEISHU = "ou_XXXXXXXXXXXXXXXXXXXXXXXX"
local g = _G.g or {}

local function cleanOldFiles()
    local ok1, R = pcall(storage.get_root_dir)
    if not ok1 or not R then return end
    local ok2, P = pcall(storage.join_path, R, "blog")
    if not ok2 or not P then return end
    pcall(storage.mkdir, P)
    local ok3, files = pcall(storage.list_dir, P)
    if ok3 and files then
        for _, f in ipairs(files) do
            if f.name and f.name:match("%.jpg$") then
                local fp = storage.join_path(P, f.name)
                pcall(storage.remove, fp)
            end
        end
        pcall(storage.sync)
    end
end

pcall(cleanOldFiles)

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
        local ok, f = pcall(camera.get_frame, 2000)
        if ok and f then f:release() end
    end
end

local BAD = {
    ["true"]=1, ["false"]=1, ["nil"]=1, ["null"]=1,
    ["unknown"]=1, ["error"]=1, ["fail"]=1, ["none"]=1,
    [""]=1, ["ok"]=1, ["yes"]=1, ["no"]=1
}

local function clean(r)
    local n = tostring(r or "")
    local ln = n:lower()
    if BAD[ln] then return "" end
    n = n:gsub("注.*", "")
    n = n:gsub("：.*", "")
    n = n:gsub(":.*", "")
    n = n:gsub("[\r\n]+", " ")
    n = n:gsub("%b()", " ")
    n = n:gsub("%b（）", " ")
    n = n:gsub("%b【】", " ")
    n = n:gsub("%b[]", " ")
    n = n:gsub("[%s%p%c]", " ")
    n = n:gsub("^[%s%p]+", "")
    n = n:gsub("[%s%p]+$", "")
    n = n:gsub("%s+", " ")
    if #n > 10 then n = n:sub(1, 10) end
    if #n < 2 then return "" end
    return n
end

local function insp(p)
    if aborted() then return nil, "aborted" end
    local ok, r, e = pcall(cv.analyze, p)
    if not ok then return nil, "cv_throw:" .. tostring(r) end
    if not r then return nil, e end
    local n = clean(r)
    if n == "" then return nil, "empty" end
    return n, nil
end

local function inspDetail(p)
    if aborted() then return nil, "aborted" end
    local prompt = "请详细描述这张图片中的野生动物状态,包括:动物种类、姿态(站立/趴卧/行走/进食等)、表情、环境特征。用简洁中文回答。"
    local ok, r, e = pcall(cv.analyze, p, prompt, 300)
    if not ok then return nil, "cv_throw:" .. tostring(r) end
    if not r then return nil, "inspect_failed:" .. tostring(e) end
    if r == "" then return nil, "no_result" end
    return tostring(r), nil
end

local last_article = ""

local function genArticle(animal, descs, t, h)
    if aborted() then return "", "aborted" end
    local d1 = descs[1] or "无有效描述"
    local d2 = descs[2] or "无有效描述"
    local d3 = descs[3] or "无有效描述"
    local history_context = ""
    if last_article ~= "" then
        history_context = "\n\n【上一期笔记内容(请延续故事,不要简单重复)】:\n" .. last_article .. "\n\n"
    end
    local prompt = "你是野生动物保护领域的AI博主,正在为\"野生动物之家\"自动撰写小红书笔记。\n\n" ..
                   "任务:根据下面3张连续拍摄的照片(按时间顺序),生成一篇温暖、治愈、有趣的小红书风格笔记。" .. history_context .. "\n\n" ..
                   "动物种类:" .. animal .. "\n" ..
                   "照片1描述:" .. d1 .. "\n" ..
                   "照片2描述:" .. d2 .. "\n" ..
                   "照片3描述:" .. d3 .. "\n" ..
                   "当前巢穴环境:温度" .. tostring(t) .. "°C,湿度" .. tostring(h) .. "%\n\n" ..
                   "要求:\n" ..
                   "1. 标题要吸引眼球,带2~3个emoji,长度不超过20字。\n" ..
                   "2. 正文以第一人称或拟人化口吻(如\"小家伙今天…\"),描述动物从第一张到第三张的状态变化。\n" ..
                   "3. 正文中加入5~8个自然emoji(🐾🐿️🌿🍃💤✨等)。\n" ..
                   "4. 笔记总字数控制在150~250字之间。\n" ..
                   "5. 结尾必须有一个互动提问,鼓励读者评论。\n" ..
                   "6. 加上3个标签:#野生动物保护 #" .. animal .. "观察 #自然笔记\n\n" ..
                   "请直接输出笔记全文,不要额外解释。"
    local ok, out, err = pcall(capability.call, "llm_generate",
        {prompt = prompt, max_tokens = 800, temperature = 0.8})
    if not ok or not out then
        return "🦊【" .. animal .. "观察日记】\n今天巢穴里的小家伙很活跃呢!📸\n连续捕捉到了精彩瞬间\n\n巢穴环境舒适,小家伙状态不错~\n\n💬你最喜欢野生动物的哪个瞬间?\n#野生动物保护 #" .. animal .. "观察 #自然笔记", nil
    end
    local article = tostring(out)
    if #article > 120 then
        last_article = article:sub(1, 120) .. "……"
    else
        last_article = article
    end
    return article, nil
end

-- 简化为单次打开(collectgarbage 已保证 PSRAM 干净,无需重试)
local function take3Photos(animal)
    local R = storage.get_root_dir()
    local P = storage.join_path(R, "blog")
    pcall(storage.mkdir, P)

    local paths = {}
    local descs = {}

    local cp = board_manager.get_camera_paths()
    if not cp then
        txt("❌AI博主:无摄像头路径")
        return {}, {}
    end

    if aborted() then return {}, {} end

    closeCameraHard()
    if g then g.cam = false end
    if _G.g then _G.g.cam = false end
    collectgarbage("collect")
    collectgarbage("collect")

    local ok, ret = pcall(camera.open, cp.dev_path)
    if not ok or ret == false or ret == nil then
        pcall(camera.close)
        txt("❌AI博主:相机打开失败")
        return {}, {}
    end
    if g then g.cam = true end
    if _G.g then _G.g.cam = true end

    dropStaleFrames()

    for i = 1, 3 do
        if aborted() then break end
        dropStaleFrames()
        if aborted() then break end

        local id = "blog_" .. tostring(os.time()) .. "_" .. i
        local pp = storage.join_path(P, animal .. "_" .. id .. ".jpg")

        local okf, f = pcall(camera.get_frame, 3000)
        if okf and f then
            local sav = pcall(image.save_file, pp, f)
            pcall(function() f:release() end)
            if sav then
                table.insert(paths, pp)
            else
                table.insert(paths, nil)
                descs[i] = "照片" .. i .. "(保存失败)"
            end
        else
            table.insert(paths, nil)
            descs[i] = "照片" .. i .. "(拍摄失败)"
        end

        if i < 3 then sd(22000) end
    end

    closeCameraHard()
    if g then g.cam = false end
    if _G.g then _G.g.cam = false end

    for i = 1, #paths do
        if aborted() then break end
        local p = paths[i]
        if p then
            local d, de = inspDetail(p)
            if d then
                descs[i] = d
            else
                descs[i] = "照片" .. i .. "(识别失败)"
            end
        else
            if not descs[i] then descs[i] = "照片" .. i end
        end
        if i < #paths and not aborted() then sd(1000) end
    end

    return paths, descs
end

local function sendBlog(animal, paths, descs, article)
    if not paths or #paths == 0 then
        txt("❌AI博主:无可用照片")
        return false
    end

    if aborted() then return false end

    txt("📕【野生动物AI博主】\n━━━━━━━━\n" .. article .. "\n━━━━━━━━")

    for i, p in ipairs(paths) do
        if aborted() then break end
        if p then
            pic(p, descs[i] or "")
            sd(500)
        end
    end

    for i, p in ipairs(paths) do
        if p then
            local deleted = false
            for retry = 1, 3 do
                local ok = pcall(storage.remove, p)
                if ok then
                    deleted = true
                    break
                else
                    if retry < 3 and not aborted() then sd(1000) end
                end
            end
            if not deleted and not aborted() then
                txt("❌AI博主:删除失败 " .. p)
            end
        end
    end
    pcall(storage.sync)
    return true
end

function run(animal, env)
    local function fail(step, err)
        txt("❌AI博主[" .. step .. "]\n" .. tostring(err))
    end

    local ok_a, err_a = pcall(function()
        safeCleanup()
        pcall(cleanOldFiles)
    end)
    if not ok_a then fail("清理", err_a) end

    if aborted() then safeCleanup() return false end

    local t = (g and g.lt) or "--"
    local h = (g and g.lh) or "--"

    local paths, descs = {}, {}
    local ok_b, paths_b, descs_b = pcall(take3Photos, animal)
    if not ok_b then
        fail("拍照", paths_b)
        safeCleanup()
        return false
    end
    paths, descs = paths_b, descs_b

    if aborted() then safeCleanup() return false end

    local article = ""
    if paths and #paths > 0 then
        local ok_c, article_c = pcall(genArticle, animal, descs, t, h)
        if not ok_c then
            fail("生成", article_c)
            article = "🦊【" .. animal .. "观察日记】\nAI博主暂时无法生成文章,但已记录精彩瞬间~📸\n#野生动物保护 #" .. animal .. "观察"
        else
            article = article_c or ""
        end
    end

    if aborted() then safeCleanup() return false end

    if paths and #paths > 0 then
        local ok_d, send_err = pcall(sendBlog, animal, paths, descs, article)
        if not ok_d then
            fail("发送", send_err)
        end
    end

    safeCleanup()
    return true
end

return { run = run }