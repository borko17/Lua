-- gemini_core.lua
-- Gemini chat logic — loaded remotely by gemini_launcher.lua
-- Receives API_KEY, MODEL, SYSTEM_PROMPT as arguments (no globals)

local API_KEY, MODEL, SYSTEM_PROMPT = ...

if not API_KEY or API_KEY == "" then
    print("Missing API_KEY — check gemini_launcher.lua")
    return
end

local API_URL = "https://generativelanguage.googleapis.com/v1beta/models/" .. MODEL .. ":generateContent?key=" .. API_KEY

-- Conversation history (kept in memory while the script runs)
local history = {}

-- Escapes special characters for a JSON string
local function json_escape(s)
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return s
end

-- Builds the JSON request body including full history and system prompt
local function build_body()
    local parts = {}
    for _, msg in ipairs(history) do
        table.insert(parts, string.format(
            '{"role":"%s","parts":[{"text":"%s"}]}',
            msg.role, json_escape(msg.text)
        ))
    end

    local contents_json = '"contents":[' .. table.concat(parts, ",") .. ']'
    local gen_config = '"generationConfig":{"thinkingConfig":{"thinkingBudget":0}}'

    if SYSTEM_PROMPT and SYSTEM_PROMPT ~= "" then
        local sys_json = '"system_instruction":{"parts":[{"text":"' .. json_escape(SYSTEM_PROMPT) .. '"}]}'
        return '{' .. sys_json .. ',' .. contents_json .. ',' .. gen_config .. '}'
    end

    return '{' .. contents_json .. ',' .. gen_config .. '}'
end

-- Lightweight text extractor from the JSON response
local function extract_text(json_str)
    -- Stop at the first closing quote followed by ',' or '}'
    -- (avoids swallowing later fields like "thoughtSignature")
    local text = json_str:match('"text"%s*:%s*"(.-)"%s*[,}]')
    if not text then
        text = json_str:match('"text"%s*:%s*"(.-)"')
    end
    if text then
        text = text:gsub('\\n', '\n')
        text = text:gsub('\\"', '"')
        text = text:gsub('\\\\', '\\')
    end
    return text
end

-- Sends a message to Gemini and returns the response as a string
local function gemini_send(user_message)
    table.insert(history, { role = "user", text = user_message })

    local url = luajava.newInstance("java.net.URL", API_URL)
    local conn = url:openConnection()
    conn:setRequestMethod("POST")
    conn:setRequestProperty("Content-Type", "application/json")
    conn:setDoOutput(true)
    conn:setConnectTimeout(15000)
    conn:setReadTimeout(60000)

    local body = build_body()

    local osw = luajava.newInstance("java.io.OutputStreamWriter", conn:getOutputStream(), "UTF-8")
    osw:write(body)
    osw:flush()
    osw:close()

    local respCode = conn:getResponseCode()
    local stream
    if respCode < 400 then
        stream = conn:getInputStream()
    else
        stream = conn:getErrorStream()
    end

    local isr = luajava.newInstance("java.io.InputStreamReader", stream, "UTF-8")
    local br = luajava.newInstance("java.io.BufferedReader", isr)

    local result = {}
    local line = br:readLine()
    while line ~= nil do
        table.insert(result, line)
        line = br:readLine()
    end
    br:close()

    local raw = table.concat(result, "\n")

    if respCode >= 400 then
        return "ERROR (" .. respCode .. "): " .. raw
    end

    local answer = extract_text(raw)
    if not answer then
        return "Failed to parse response:\n" .. raw
    end

    table.insert(history, { role = "model", text = answer })
    return answer
end

-- Main chat loop in the Yantra terminal
local function chat_loop()
    print("=== Gemini Chat ===\n(" .. MODEL .. ")\n\nType a prompt or just press Enter to exit.")
    while true do
        local user_text = input("You: ")

        if user_text == nil or user_text == "" then
            print("Bye!")
            break
        end

        if user_text ~= "" then
            print("-------------------------")
            print("You: " .. user_text)
            print("...")
            local reply = gemini_send(user_text)
            print("Gemini: " .. reply)
        end
    end
end

chat_loop()
