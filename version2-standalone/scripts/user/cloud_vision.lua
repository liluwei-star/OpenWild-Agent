-- /fatfs/scripts/user/cloud_vision.lua
-- 云端 AI 能力模块（OpenAI 兼容协议）
-- 功能:analyze(path,prompt) 图像+文本分析;generate(prompt,max_tokens,temp) 文本生成
-- 依赖:storage, json, capability 模块
-- 加载:local cv=dofile("/fatfs/scripts/user/cloud_vision.lua")

local M = {}
local storage = require("storage")
local json = require("json")
local capability = require("capability")

local b64c = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64e(d)
    if type(d) ~= "string" then return nil end
    local len = #d
    local out = {}
    local i = 1
    while i <= len do
        local c1 = string.byte(d, i)
        local c2 = (i + 1 <= len) and string.byte(d, i + 1) or 0
        local c3 = (i + 2 <= len) and string.byte(d, i + 2) or 0
        local n = (c1 * 65536) + (c2 * 256) + c3
        local b1 = math.floor(n / 262144) % 64 + 1
        local b2 = math.floor(n / 4096) % 64 + 1
        local b3 = math.floor(n / 64) % 64 + 1
        local b4 = (n % 64) + 1
        out[#out + 1] = b64c:sub(b1, b1)
        out[#out + 1] = b64c:sub(b2, b2)
        out[#out + 1] = (i + 1 > len) and "=" or b64c:sub(b3, b3)
        out[#out + 1] = (i + 2 > len) and "=" or b64c:sub(b4, b4)
        i = i + 3
    end
    return table.concat(out)
end

local function clean_resp(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("<think>.-</think>", "")
    s = s:gsub("<think>.-", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function load_cfg()
    local ok, cfg = pcall(dofile, "/fatfs/config/cloud_vision.lua")
    if not ok or type(cfg) ~= "table" then return nil, "no_config" end
    return cfg
end

local function post_chat(cfg, messages_body, max_tokens, temperature)
    local body = json.encode({
        model = cfg.model,
        messages = messages_body,
        max_tokens = max_tokens,
        temperature = temperature
    })
    if not body then return nil, "json_encode_fail" end
    _G._cv_seq = (_G._cv_seq or 0) + 1
    local save_path = "/fatfs/data/cloud_resp_" .. tostring(os.time()) .. "_" .. tostring(_G._cv_seq) .. ".json"
    pcall(function() storage.mkdir("/fatfs/data") end)
    local ok, status = capability.call("http_request", {
        url = cfg.endpoint .. "/chat/completions",
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. cfg.api_key
        },
        body = body,
        save_path = save_path,
        timeout_ms = cfg.timeout_ms or 30000,
        max_body_bytes = 65535
    })
    if not ok then pcall(storage.remove, save_path); return nil, "http_fail:" .. tostring(status) end
    local f = io.open(save_path, "r")
    if not f then return nil, "no_resp_file" end
    local resp = f:read("*a")
    f:close()
    pcall(storage.remove, save_path)  -- cleanup
    local d_ok, parsed = pcall(json.decode, resp)
    if not d_ok or type(parsed) ~= "table" then return nil, "json_fail" end
    if parsed.error then return nil, "api_err:" .. tostring(parsed.error.message or parsed.error) end
    if parsed.choices and parsed.choices[1] and parsed.choices[1].message then
        local content = parsed.choices[1].message.content
        if type(content) == "string" and content ~= "" then
            return clean_resp(content)
        end
    end
    return nil, "no_content"
end

function M.analyze(path, prompt, max_tokens)
    local cfg, err = load_cfg()
    if not cfg then return nil, err end
    local data, re = storage.read_file(path)
    if not data then return nil, "read_fail:" .. tostring(re) end
    local b64 = b64e(data)
    if not b64 then return nil, "b64_fail" end
    if not prompt or prompt == "" then
        prompt = "请识别这张图片中的内容。如果是动物，请回答动物名称，只回答名称，不需要额外描述；如果是鸟蛋或蛋，请回答'鸟蛋'。"
    end
    local messages = {{
        role = "user",
        content = {
            { type = "text", text = prompt },
            { type = "image_url", image_url = { url = "data:image/jpeg;base64," .. b64 } }
        }
    }}
    return post_chat(cfg, messages, max_tokens or 200, 0.5)
end

function M.generate(prompt, max_tokens, temperature)
    local cfg, err = load_cfg()
    if not cfg then return nil, err end
    if not prompt or prompt == "" then return nil, "no_prompt" end
    local messages = {{ role = "user", content = prompt }}
    return post_chat(cfg, messages, max_tokens or 500, temperature or 0.8)
end

return M