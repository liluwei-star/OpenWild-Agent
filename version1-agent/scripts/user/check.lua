-- _check_storage.lua v3
local storage = require("storage")
local R = storage.get_root_dir()
print("Root:", R)

-- 1. 空间
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

-- 2. 根目录列表
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

-- 3. /blog/
print("\n=== /blog/ ===")
local blog = storage.join_path(R, "blog")
local ok_b, bf = pcall(storage.listdir, blog)
if ok_b and bf then
    print(string.format("%d 文件:", #bf))
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