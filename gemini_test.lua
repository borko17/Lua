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
        if msg.thoughtSignature then
            table.insert(parts, string.format(
                '{"role":"%s","parts":[{"text":"%s","thoughtSignature":"%s"}]}',
                msg.role, json_escape(msg.text), msg.thoughtSignature
            ))
        else
            table.insert(parts, string.format(
                '{"role":"%s","parts":[{"text":"%s"}]}',
                msg.role, json_escape(msg.text)
            ))
        end
    end

    local contents_json = '"contents":[' .. table.concat(parts, ",") .. ']'
    local gen_config = '"generationConfig":{"thinkingConfig":{"thinkingLevel":"low"}}'

    if SYSTEM_PROMPT and SYSTEM_PROMPT ~= "" then
        local sys_json = '"system_instruction":{"parts":[{"text":"' .. json_escape(SYSTEM_PROMPT) .. '"}]}'
        return '{' .. sys_json .. ',' .. contents_json .. ',' .. gen_config .. '}'
    end

    return '{' .. contents_json .. ',' .. gen_config .. '}'
end

-- Finds all balanced top-level-and-nested {...} objects in a string.
-- Needed because a plain regex can't correctly handle nested JSON braces.
local function find_all_objects(s)
    local objs = {}
    local n = #s
    for i = 1, n do
        if s:sub(i, i) == '{' then
            local depth = 0
            for j = i, n do
                local c = s:sub(j, j)
                if c == '{' then
                    depth = depth + 1
                elseif c == '}' then
                    depth = depth - 1
                    if depth == 0 then
                        table.insert(objs, s:sub(i, j))
                        break
                    end
                end
            end
        end
    end
    return objs
end

-- Extracts the final answer text (skipping any "thought":true parts) and,
-- if present, the accompanying thoughtSignature for that part.
local function extract_answer(json_str)
    for _, obj in ipairs(find_all_objects(json_str)) do
        if obj:find('"text"%s*:%s*"') and not obj:find('"thought"%s*:%s*true') then
            local text = obj:match('"text"%s*:%s*"(.-)"%s*[,}]')
                       or obj:match('"text"%s*:%s*"(.-)"')
            if text then
                text = text:gsub('\\n', '\n')
                text = text:gsub('\\"', '"')
                text = text:gsub('\\\\', '\\')
                local sig = obj:match('"thoughtSignature"%s*:%s*"(.-)"')
                return text, sig
            end
        end
    end
    return nil, nil
end

-- Extracts only the "message" field from a Google API error JSON
local function extract_error_message(json_str)
    local msg = json_str:match('"message"%s*:%s*"(.-)"%s*[,}]')
    if not msg then
        msg = json_str:match('"message"%s*:%s*"(.-)"')
    end
    if msg then
        msg = msg:gsub('\\n', ' ')
        msg = msg:gsub('\\"', '"')
    end
    return msg or json_str
end

-- Safely reads all lines from a Java stream. Returns nil if stream is nil or read fails.
local function read_stream(stream)
    if not stream then
        return nil
    end
    local ok, out = pcall(function()
        local isr = luajava.newInstance("java.io.InputStreamReader", stream, "UTF-8")
        local br = luajava.newInstance("java.io.BufferedReader", isr)
        local result = {}
        local line = br:readLine()
        while line ~= nil do
            table.insert(result, line)
            line = br:readLine()
        end
        br:close()
        return table.concat(result, "\n")
    end)
    if ok then
        return out
    end
    return nil
end

-- Sends a message to Gemini and returns the response as a string.
-- Never throws — always returns a printable string.
local function gemini_send(user_message)
    table.insert(history, { role = "user", text = user_message })

    local ok, result = pcall(function()
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

        local raw
        if respCode < 400 then
            raw = read_stream(conn:getInputStream())
        else
            raw = read_stream(conn:getErrorStream())
        end

        if not raw or raw == "" then
            return "ERROR (" .. respCode .. "): no response body."
        end

        if respCode >= 400 then
            return "ERROR (" .. respCode .. "): " .. extract_error_message(raw)
        end

        local answer, thought_sig = extract_answer(raw)
        if not answer then
            return "Failed to parse response:\n" .. raw
        end

        table.insert(history, { role = "model", text = answer, thoughtSignature = thought_sig })
        return answer
    end)

    if ok then
        return result
    else
        -- Undo the history entry we added for the failed request
        table.remove(history)
        return "Connection error: " .. tostring(result)
    end
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
            print("👤 " .. user_text)
            local reply = gemini_send(user_text)
            print("💠 " .. reply)
        end
    end
end

chat_loop()
