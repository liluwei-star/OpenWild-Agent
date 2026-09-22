-- _check_storage.lua v4
local storage = require("storage")
local R = storage.get_root_dir()
print("Root:", R)

-- ============================================================
-- 0. 启动清理：删除 /blog/ 和 /photos/ 下所有残留文件
--    主脚本异常退出/断电时这两个目录可能残留未删除的照片
--    多次重试 + 反向校验，确保删除干净
-- ============================================================
print("\n=== 启动清理 ===")
local function purge_dir(dir_name, pattern)
    local dir = storage.join_path(R, dir_name)
    if not storage.exists(dir) then
        print(string.format("  [%s] 目录不存在，跳过", dir_name))
        return 0, 0
    end
    local removed, failed = 0, 0
    local function match(name)
        if not pattern then return true end
        return name and name:match(pattern) ~= nil
    end
    local function tag() return pattern and (" (pattern: " .. pattern .. ")") or "" end
    -- 第一轮：按 listdir 顺序删除
    local ok_l, files = pcall(storage.listdir, dir)
    if ok_l and files then
        for _, f in ipairs(files) do
            if match(f.name) then
                local p = storage.join_path(dir, f.name)
                local ok_r, res = pcall(storage.remove, p)
                if ok_r and res then
                    removed = removed + 1
                else
                    failed = failed + 1
                end
            end
        end
    end
    -- 第二轮：再次 listdir，删漏的（冗余）
    local ok_l2, files2 = pcall(storage.listdir, dir)
    if ok_l2 and files2 then
        for _, f in ipairs(files2) do
            if match(f.name) then
                local p = storage.join_path(dir, f.name)
                local ok_r, res = pcall(storage.remove, p)
                if ok_r and res then
                    removed = removed + 1
                else
                    failed = failed + 1
                end
            end
        end
    end
    -- 反向校验：再扫一次，若仍有文件则逐个强制再删
    local ok_l3, files3 = pcall(storage.listdir, dir)
    if ok_l3 and files3 and #files3 > 0 then
        for _, f in ipairs(files3) do
            if match(f.name) then
                local p = storage.join_path(dir, f.name)
                pcall(storage.remove, p)
            end
        end
        local ok_l4, files4 = pcall(storage.listdir, dir)
        local leftover = 0
        if ok_l4 and files4 then
            for _, f in ipairs(files4) do
                if match(f.name) then leftover = leftover + 1 end
            end
        end
        print(string.format("  [%s%s] 删除 %d 个，失败 %d 个，残留 %d 个",
            dir_name, tag(), removed, failed, leftover))
        return removed, leftover
    end
    print(string.format("  [%s%s] 删除 %d 个，失败 %d 个，残留 0 个",
        dir_name, tag(), removed, failed))
    return removed, 0
end

local b_rm, b_left = purge_dir("blog")
local p_rm, p_left = purge_dir("photos")
local d_rm, d_left = purge_dir("data", "^cloud_resp_%d+_%d+%.json$")

-- ============================================================
-- 1. 空间
-- ============================================================
print("\n=== get_free_space ===")
local ok, fs = pcall(storage.get_free_space, R)
print("ok:", ok, "type:", type(fs))
if type(fs) == "table" then
    for k, v in pairs(fs) do
        print(string.format("  %s = %s (%s)", k, tostring(v), type(v)))
    end
else
    print("value:", fs)
end

-- ============================================================
-- 2. 根目录列表
-- ============================================================
print("\n=== 根目录 ===")
local ok_l, files = pcall(storage.listdir, R)
if ok_l and files then
    print(string.format("%d 条目:", #files))
    local total = 0
    for _, f in ipairs(files) do
        local sz = f.size or 0
        total = total + sz
        local s = sz >= 1024 and string.format("%.1f KB", sz/1024) or string.format("%d B", sz)
        print(string.format("  %-30s %12s", f.name or "?", s))
    end
    print(string.format("根目录累计: %.1f KB", total / 1024.0))
else
    print("listdir 失败:", files)
end

-- ============================================================
-- 3. /blog/ 状态
-- ============================================================
print("\n=== /blog/ ===")
local blog = storage.join_path(R, "blog")
local ok_b, bf = pcall(storage.listdir, blog)
if ok_b and bf then
    print(string.format("清理结果: 删除 %d，残留 %d", b_rm, b_left))
    print(string.format("当前 %d 文件:", #bf))
    local tot = 0
    for _, f in ipairs(bf) do
        local sz = f.size or 0
        tot = tot + sz
        local s = sz >= 1024 and string.format("%.1f KB", sz/1024) or string.format("%d B", sz)
        print(string.format("  %-60s %12s", f.name or "?", s))
    end
    print(string.format("/blog/ 累计: %.1f KB", tot / 1024.0))
else
    print("无 /blog/ 或 listdir 失败:", bf)
end

-- ============================================================
-- 4. /photos/ 状态
-- ============================================================
print("\n=== /photos/ ===")
local photos = storage.join_path(R, "photos")
local ok_p, pf = pcall(storage.listdir, photos)
if ok_p and pf then
    print(string.format("清理结果: 删除 %d，残留 %d", p_rm, p_left))
    print(string.format("当前 %d 文件:", #pf))
    local tot = 0
    for _, f in ipairs(pf) do
        local sz = f.size or 0
        tot = tot + sz
        local s = sz >= 1024 and string.format("%.1f KB", sz/1024) or string.format("%d B", sz)
        print(string.format("  %-60s %12s", f.name or "?", s))
    end
    print(string.format("/photos/ 累计: %.1f KB", tot / 1024.0))
else
    print("无 /photos/ 或 listdir 失败:", pf)
end

-- ============================================================
-- 5. /data/cloud_resp_*.json 状态 (AI 临时响应文件)
-- ============================================================
print("\n=== /data/cloud_resp_*.json ===")
local data_dir = storage.join_path(R, "data")
local ok_d, df = pcall(storage.listdir, data_dir)
if ok_d and df then
    local pat = "^cloud_resp_%d+_%d+%.json$"
    local matched = 0
    for _, f in ipairs(df) do
        if f.name and f.name:match(pat) then matched = matched + 1 end
    end
    print(string.format("清理结果: 删除 %d，残留 %d (目录总 %d 个文件, 匹配模式 %d 个)",
        d_rm, d_left, #df, matched))
    local tot = 0
    for _, f in ipairs(df) do
        if f.name and f.name:match(pat) then
            local sz = f.size or 0
            tot = tot + sz
            local s = sz >= 1024 and string.format("%.1f KB", sz/1024) or string.format("%d B", sz)
            print(string.format("  %-60s %12s", f.name or "?", s))
        end
    end
    print(string.format("匹配累计: %.1f KB", tot / 1024.0))
else
    print("无 /data/ 或 listdir 失败:", df)
end