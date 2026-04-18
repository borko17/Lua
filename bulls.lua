-- ================================
--  Bulls and Cows 
--  for Yantra CLI Launcher Pro
-- ================================

math.randomseed(os.time())

local digits = {}
local CODE_LEN = 0
local easy_mode = false
local quit_flag = false
local raccoon_active = false
local fox_active = false
local global_intelligence = nil  -- Global intelligence (1-100, multiplied by 1000)

-- History of all moves (stored independently of raccoon)
local global_history = {}

-- Save settings for new game
local saved_digits = nil
local saved_length = nil

local function sep() print("----------------------------") end

local function show_help()
    print("")
    sep()
    print("HOW TO PLAY - BULLS AND COWS")
    sep()
    print("The computer has chosen a secret code made of numbers. Your goal is to guess it.")
    print("Numbers can repeat. \nE.g. [ 3 3 1 2 ] is valid.")
    print("")
    print("After each guess you get the following feedback:")
    sep()
    print("B Bull  -- correct digit at correct position.")
    print("C Cow   -- correct digit at wrong position.")
    print("T Tree  -- digit is not in the code, or already used as B or C.")
    print("")
    print("Modes:")
    sep()
    print("'n' -- Normal: shows only total correct digits, not their positions:\n e.g.  [ 2 3 4 5 ]  B:1  C:2")
    print("'e' -- Easy: shows icon per position:\n e.g.  [ 2 3 4 5 ]  [BTCC]\n e.g.  [ 2 4 4 5 ]  [BTCC]")
    print("")
    print("Animals:")
    sep()
    print("r Raccoon -- plays against you — both guessing the same secret code — until the end or until you turn it off. Try to beat it.")
    print("d Dolphin -- here to help you. Plays one move each time you call it.")
    print("b Bunny   -- if you give up, call the bunny and it will quickly finish the game for you.")
    print("f Fox     -- duel mode. You give the fox a secret code, and you have a different secret code. First to guess wins. Fox plays after each of your moves.")
    print("o Owl     -- it doesn't need to guess, the wise owl already knows the secret code. Each time you type 'o', it reveals info about one random digit: whether it's in the code, and if so, whether it's in the right place.")
    print("")
    print("ai -- animal intelligence.")
    sep()
    print("Can be changed mid-game or left at default. Its value is shown in each animal's guess line. e.g. \n1. [ 8 7 2 0 ]  B:0  C:0  d:5\n(in this example the dolphin's intelligence is 5.)")
    print("If we want to raise that value to 10, we type 'ai10'. Values from 1-100 can be used. A low value doesn't mean the animal can't solve the code. With higher ai the animals need fewer moves.")
    print("Best tested with the bunny. E.g. Bunny with ai1 can solve a 4-digit code in ~20 moves, with ai5 it solves it in ~6 moves.")
    print("")
    print("Commands:")
    sep()
    print("'h'   -- show this help")
    print("'q'   -- quit the game")
    print("'e'   -- switch to easy mode")
    print("'n'   -- switch to normal mode")
    print("'aiX' -- set animal intelligence (X=1-100, e.g. ai20)")
    print("'re'  -- restart game (resets ai settings and offers re-selecting digit count and code length)")
    print("'d'   -- activate dolphin")
    print("'b'   -- activate bunny")
    print("'r'   -- toggle raccoon on/off")
    print("'o'   -- owl (hint: reveal info about one digit)")
    print("'fX'  -- activate duel with fox (X = code you give it, e.g. f4532)")
    print("'f'   -- remove fox from game")
    sep()
end

local function generate_random_code(length)
    length = length or CODE_LEN
    local code = {}
    for i = 1, length do
        code[i] = digits[math.random(#digits)]
    end
    return code
end

local function check(secret, guess)
    local length = #secret
    local bulls, cows = 0, 0
    local so, ao = {}, {}
    for i = 1, length do
        if guess[i] == secret[i] then
            bulls = bulls + 1
            so[i] = true
            ao[i] = true
        end
    end
    for i = 1, length do
        if not ao[i] then
            for j = 1, length do
                if not so[j] and guess[i] == secret[j] then
                    cows = cows + 1
                    so[j] = true
                    break
                end
            end
        end
    end
    return bulls, cows
end

local function check_with_positions(secret, guess)
    local length = #secret
    local positions = {}
    local so, ao = {}, {}
    
    for i = 1, length do
        if guess[i] == secret[i] then
            positions[i] = "B"
            so[i] = true
            ao[i] = true
        end
    end
    for i = 1, length do
        if not ao[i] then
            for j = 1, length do
                if not so[j] and guess[i] == secret[j] then
                    positions[i] = "C"
                    so[j] = true
                    break
                end
            end
        end
        if not positions[i] then
            positions[i] = "T"
        end
    end
    
    local bulls = 0
    local cows = 0
    for i = 1, length do
        if positions[i] == "B" then bulls = bulls + 1
        elseif positions[i] == "C" then cows = cows + 1
        end
    end
    
    return bulls, cows, positions
end

local function short(code)
    if not code then return "[ ??? ]" end
    return "[ " .. table.concat(code, " ") .. " ]"
end

local function digits_str()
    local t = {}
    for i = 1, #digits do t[i] = digits[i] end
    return table.concat(t, " ")
end

local function owl_hint(secret_code, move_number)
    -- Pick a random digit from the digit set
    local chosen = digits[math.random(#digits)]
    
    -- Find all positions of that digit in the secret code
    local positions_in_code = {}
    for i = 1, #secret_code do
        if secret_code[i] == chosen then
            table.insert(positions_in_code, i)
        end
    end
    
    -- Build mask - show digit at a RANDOM position
    local mask = {}
    for i = 1, CODE_LEN do
        mask[i] = "*"
    end
    
    -- Pick a random position to reveal the digit (1..CODE_LEN)
    local reveal_pos = math.random(1, CODE_LEN)
    mask[reveal_pos] = chosen
    local mask_str = "[ " .. table.concat(mask, " ") .. " ]"
    local prefix = (move_number < 10 and " " .. move_number or tostring(move_number)) .. ". "
    
    if #positions_in_code == 0 then
        print(prefix .. mask_str .. "  T:1  o")
    else
        local is_bull = false
        for _, p in ipairs(positions_in_code) do
            if p == reveal_pos then
                is_bull = true
                break
            end
        end
        if is_bull then
            print(prefix .. mask_str .. "  B:1  o")
        else
            print(prefix .. mask_str .. "  C:1  o")
        end
    end
end

local function generate()
    local t = {}
    for i = 1, CODE_LEN do t[i] = digits[math.random(#digits)] end
    return t
end

local function parse(line, length)
    length = length or CODE_LEN
    local r = {}
    local c = line:gsub("%s+", "")
    if #c ~= length then return nil end
    for i = 1, length do
        local s = c:sub(i, i)
        local ok = false
        for _, d in ipairs(digits) do if s == d then ok = true; break end end
        if not ok then return nil end
        r[i] = s
    end
    return r
end

-- Returns number of samples based on intelligence
local function get_sample_count(length)
    if global_intelligence then
        return global_intelligence * 1000
    end
    length = length or CODE_LEN
    if length == 2 then
        return 1000
    elseif length == 3 then
        return 2000
    elseif length == 4 then
        return 5000
    elseif length == 5 then
        return 20000
    elseif length == 6 then
        return 80000
    else
        return 5000
    end
end

-- Returns displayed intelligence (number in thousands)
local function show_intelligence(sample_count)
    if not sample_count then return "" end
    local intel = math.floor(sample_count / 1000)
    if intel < 1 then intel = 1 end
    return tostring(intel)
end

local function make_animal(sample_count, code_length, empty_history)
    local history = {}
    local tried = {}
    code_length = code_length or CODE_LEN
    sample_count = sample_count or get_sample_count(code_length)
    
    -- Add all previous moves from global history (except fox which has its own)
    if not empty_history then
        for _, h in ipairs(global_history) do
            table.insert(history, {guess=h.guess, bulls=h.bulls, cows=h.cows, positions=h.positions})
        end
    end
    
    local function code_matches(code)
        for _, h in ipairs(history) do
            if easy_mode then
                if h.positions == nil then
                    local b, c = check(code, h.guess)
                    if b ~= h.bulls or c ~= h.cows then
                        return false
                    end
                else
                    local _, _, positions = check_with_positions(code, h.guess)
                    for i = 1, code_length do
                        if positions[i] ~= h.positions[i] then
                            return false
                        end
                    end
                end
            else
                local b, c = check(code, h.guess)
                if b ~= h.bulls or c ~= h.cows then
                    return false
                end
            end
        end
        return true
    end
    
    return {
        add = function(self, guess, bulls, cows, positions)
            table.insert(history, {guess=guess, bulls=bulls, cows=cows, positions=positions})
        end,
        
        pick = function(self)
            for _ = 1, sample_count do
                local candidate = generate_random_code(code_length)
                local key = table.concat(candidate, ",")
                if not tried[key] and code_matches(candidate) then
                    tried[key] = true
                    return candidate
                end
            end
            return generate_random_code(code_length)
        end,
        
        refresh = function(self)
            return make_animal(get_sample_count(code_length), code_length)
        end,
        
        refresh_empty = function(self)
            return make_animal(get_sample_count(code_length), code_length, true)
        end,
        
        refresh_with_history = function(self)
            local new = make_animal(get_sample_count(code_length), code_length, true)
            for _, h in ipairs(history) do
                new:add(h.guess, h.bulls, h.cows, h.positions)
            end
            return new
        end,
        
        get_sample_count = function(self)
            return sample_count
        end
    }
end

-- Ask for a number input
local function ask_number(min, max, message)
    repeat
        print(message)
        local raw = input()
        if raw == nil then return nil end
        local trimmed = raw:gsub("^%s*(.-)%s*$", "%1")
        local lower = trimmed:lower()
        
        if lower == "q" then
            quit_flag = true
            return nil
        end
        if lower == "h" then
            show_help()
        elseif lower == "e" then
            easy_mode = true
            print(">> Easy mode")
        elseif lower == "n" then
            easy_mode = false
            print(">> Normal mode")
        elseif lower == "re" then
            print("\n--- Game restart --- \n--- resetting all settings ---\n")
            return nil  -- Signal for restart
        elseif lower:match("^ai%d+$") then
            local num = tonumber(lower:sub(3))
            if num and num >= 1 and num <= 100 then
                global_intelligence = num
            else
                print("! Intelligence must be between 1 and 100")
            end
        else
            local n = tonumber(trimmed)
            if n and n >= min and n <= max then
                return n
            end
            print("! Enter a number between " .. min .. " and " .. max .. ".")
        end
    until false
end

local function get_input()
    local raw = input()
    if raw == nil then return nil end
    local trimmed = raw:gsub("^%s*(.-)%s*$", "%1")
    
    if trimmed == "" then
        return ""
    end
    
    local lower = trimmed:lower()
    if lower == "q" then
        quit_flag = true
        return nil
    end
    if lower == "h" then
        show_help()
        return ""
    end
    if lower == "e" then
        easy_mode = true
        print(">> Easy mode")
        return ""
    end
    if lower == "n" then
        easy_mode = false
        print(">> Normal mode")
        return ""
    end
    if lower == "r" then
        return "TOGGLE_RACCOON"
    end
    if lower == "d" then
        return "DOLPHIN"
    end
    if lower == "b" then
        return "BUNNY"
    end
    if lower == "f" then
        return "FOX_OFF"
    end
    if lower:match("^f%d+$") then
        return "FOX:" .. lower:sub(2)
    end
    if lower == "o" then
        return "OWL"
    end
    if lower == "re" then
        return "RESTART"
    end
    if lower:match("^ai%d+$") then
        return lower  -- Return ai command for processing
    end
    return trimmed
end

local function format_number(num)
    if num < 10 then
        return " " .. num
    else
        return num
    end
end

local function welcome_message()
    print("==============================")
    print("  BB BULLS AND COWS CC")
    print("==============================")
    print("The computer picks a secret code.\nGuess it!")
    print("q = quit  |  h = help")
    print("e = easy  |  n = normal")
    print("d = d  |  r = r  |  b = b")
    print("o = o  |  fX = f ")
    print("aiX = animal intelligence")
    print("re = restart")
    sep()
end

-- Main game function
local function play(first_game)
    if first_game then
        welcome_message()
    end
    
    -- If no saved digits or restart, ask for new settings
    if saved_digits == nil or saved_length == nil then
        local qty = ask_number(2, 10, "How many digits? (2-10):")
        if quit_flag then 
            print("\nGoodbye!")
            return false 
        end
        if qty == nil then 
            -- Reset all settings
            saved_digits = nil
            saved_length = nil
            global_intelligence = nil
            easy_mode = false
            raccoon_active = false
            fox_active = false
            return true  -- restart
        end
        
        digits = {}
        for i = 1, qty do
            digits[i] = i < 10 and tostring(i) or "0"
        end
        saved_digits = qty
        
        CODE_LEN = ask_number(2, 6, "Code length? (2-6):")
        if quit_flag then 
            print("\nGoodbye!")
            return false 
        end
        if CODE_LEN == nil then 
            saved_digits = nil
            saved_length = nil
            global_intelligence = nil
            easy_mode = false
            raccoon_active = false
            fox_active = false
            return true
        end
        saved_length = CODE_LEN
        sep()
        
        print("Digits: " .. digits_str())
        print("Length: " .. CODE_LEN)
        print("Numbers can repeat!")
        sep()
    else
        -- Use saved settings
        digits = {}
        for i = 1, saved_digits do
            digits[i] = i < 10 and tostring(i) or "0"
        end
        CODE_LEN = saved_length
        print("New game with same settings!")
        print("Digits: " .. digits_str())
        print("Length: " .. CODE_LEN)
        print("Numbers can repeat!")
        sep()
    end
    
    global_history = {}
    
    local secret_code = generate()
    local animal = nil
    local move_number = 0
    local winner = nil
    local solved = false
    local time_start = os.time()
    
    -- Fox duel setup
    local fox_code = nil         -- code you give to the fox
    local fox_animal = nil       -- fox animal that guesses your secret_code
    local fox_move_number = 0    -- separate numbering for fox
    
    -- If raccoon is active before start, play first move immediately
    if raccoon_active then
        animal = make_animal()
        
        move_number = move_number + 1
        local guess = animal:pick()
        local bulls, cows, positions
        local intel_show = show_intelligence(animal:get_sample_count())
        
        if easy_mode then
            bulls, cows, positions = check_with_positions(secret_code, guess)
            print(format_number(move_number) .. ". " .. short(guess) .. "  [" .. table.concat(positions, " ") .. "]  r:" .. intel_show)
            animal:add(guess, bulls, cows, positions)
            table.insert(global_history, {guess=guess, bulls=bulls, cows=cows, positions=positions})
        else
            bulls, cows = check(secret_code, guess)
            print(format_number(move_number) .. ". " .. short(guess) .. "  B:" .. bulls .. "  C:" .. cows .. "  r:" .. intel_show)
            animal:add(guess, bulls, cows, nil)
            table.insert(global_history, {guess=guess, bulls=bulls, cows=cows, positions=nil})
        end
    
        if bulls == CODE_LEN then
            winner = "RACCOON"
            solved = true
            print("\n*** Raccoon wins! r ***")
        end
    end
    
    while winner == nil do
        move_number = move_number + 1
        local raw = get_input()
    
        if quit_flag then
            print("\nGoodbye!")
            print("The secret code was: " .. short(secret_code))
            return false
        end
    
        if raw == "RESTART" then
            -- Reset all settings
            saved_digits = nil
            saved_length = nil
            global_intelligence = nil
            easy_mode = false
            raccoon_active = false
            fox_active = false
            print("\n--- Game restart --- \n--- resetting all settings ---\n")
            return true
        end
        
        -- AI command for changing intelligence
        if type(raw) == "string" and raw:match("^ai%d+$") then
            local num = tonumber(raw:sub(3))
            if num and num >= 1 and num <= 100 then
                global_intelligence = num
                if animal then
                    animal = animal:refresh()
                end
                if fox_animal then
                    fox_animal = fox_animal:refresh_with_history()
                end
            end
            move_number = move_number - 1
            goto end_of_turn
        end
        
        if raw == "DOLPHIN" then
            if not animal then
                animal = make_animal()
            end
            local dolphin_guess = animal:pick()
            local d_bulls, d_cows, d_positions
            local intel_show = show_intelligence(animal:get_sample_count())
            
            if easy_mode then
                d_bulls, d_cows, d_positions = check_with_positions(secret_code, dolphin_guess)
                print(format_number(move_number) .. ". " .. short(dolphin_guess) .. "  [" .. table.concat(d_positions, "") .. "]  d:" .. intel_show)
                animal:add(dolphin_guess, d_bulls, d_cows, d_positions)
                table.insert(global_history, {guess=dolphin_guess, bulls=d_bulls, cows=d_cows, positions=d_positions})
            else
                d_bulls, d_cows = check(secret_code, dolphin_guess)
                print(format_number(move_number) .. ". " .. short(dolphin_guess) .. "  B:" .. d_bulls .. "  C:" .. d_cows .. "  d:" .. intel_show)
                animal:add(dolphin_guess, d_bulls, d_cows, nil)
                table.insert(global_history, {guess=dolphin_guess, bulls=d_bulls, cows=d_cows, positions=nil})
            end
            
            if d_bulls == CODE_LEN then
                winner = "DOLPHIN"
                solved = true
                print("\n*** Dolphin guessed it! d ***")
                break
            end
            goto end_of_turn
        end
        
        if raw == "OWL" then
            owl_hint(secret_code, move_number)
            goto end_of_turn
        end
        
        if raw == "BUNNY" then
            if not animal then
                animal = make_animal()
            end
            
            while winner == nil do
                local bunny_guess = animal:pick()
                local b_bulls, b_cows, b_positions
                local intel_show = show_intelligence(animal:get_sample_count())
                
                if easy_mode then
                    b_bulls, b_cows, b_positions = check_with_positions(secret_code, bunny_guess)
                    print(format_number(move_number) .. ". " .. short(bunny_guess) .. "  [" .. table.concat(b_positions, "") .. "]  b:" .. intel_show)
                    animal:add(bunny_guess, b_bulls, b_cows, b_positions)
                    table.insert(global_history, {guess=bunny_guess, bulls=b_bulls, cows=b_cows, positions=b_positions})
                else
                    b_bulls, b_cows = check(secret_code, bunny_guess)
                    print(format_number(move_number) .. ". " .. short(bunny_guess) .. "  B:" .. b_bulls .. "  C:" .. b_cows .. "  b:" .. intel_show)
                    animal:add(bunny_guess, b_bulls, b_cows, nil)
                    table.insert(global_history, {guess=bunny_guess, bulls=b_bulls, cows=b_cows, positions=nil})
                end
                
                if b_bulls == CODE_LEN then
                    winner = "BUNNY"
                    solved = true
                    print("\n*** Bunny finished the game! b ***")
                    break
                end
                move_number = move_number + 1
            end
            break
        end
    
        if raw == "FOX_OFF" then
            if fox_active then
                fox_active = false
                fox_animal = nil
                fox_code = nil
            else
            end
            move_number = move_number - 1
            goto end_of_turn
        end

        if type(raw) == "string" and raw:match("^FOX:") then
            if fox_active then
                move_number = move_number - 1
                goto end_of_turn
            end
            
            local fox_input = nil
            local code_str = raw:sub(5)
            fox_input = parse(code_str)
            if fox_input == nil then
                print("! Invalid. Enter fX where X is a " .. CODE_LEN .. "-digit code from digits: " .. digits_str())
                move_number = move_number - 1
                goto end_of_turn
            end
            
            fox_code = fox_input
            fox_active = true
            fox_animal = make_animal(nil, nil, true)
            
            -- Fox plays first move immediately
            fox_move_number = fox_move_number + 1
            local f_guess = fox_animal:pick()
            local f_bulls, f_cows, f_positions
            local intel_show = show_intelligence(fox_animal:get_sample_count())
            
            if easy_mode then
                f_bulls, f_cows, f_positions = check_with_positions(fox_code, f_guess)
                print(format_number(fox_move_number) .. ". ------------ " .. short(f_guess) .. "  f:" .. intel_show)
                fox_animal:add(f_guess, f_bulls, f_cows, f_positions)
            else
                f_bulls, f_cows = check(fox_code, f_guess)
                print(format_number(fox_move_number) .. ". ------------ " .. short(f_guess) .. "  f:" .. intel_show)
                fox_animal:add(f_guess, f_bulls, f_cows, nil)
            end
            
            if f_bulls == CODE_LEN then
                winner = "FOX"
                solved = true
                print("\n*** Fox guessed the code you gave it! f You lose!")
                print("Your secret code was: " .. short(secret_code))
                break
            end
            move_number = move_number - 1
            goto end_of_turn
        end
    
        if raw == "TOGGLE_RACCOON" then
            if not raccoon_active then
                raccoon_active = true
                animal = make_animal()
                
                local r_guess = animal:pick()
                local r_bulls, r_cows, r_positions
                local intel_show = show_intelligence(animal:get_sample_count())
                
                if easy_mode then
                    r_bulls, r_cows, r_positions = check_with_positions(secret_code, r_guess)
                    print(format_number(move_number) .. ". " .. short(r_guess) .. "  [" .. table.concat(r_positions, "") .. "]  r:" .. intel_show)
                    animal:add(r_guess, r_bulls, r_cows, r_positions)
                    table.insert(global_history, {guess=r_guess, bulls=r_bulls, cows=r_cows, positions=r_positions})
                else
                    r_bulls, r_cows = check(secret_code, r_guess)
                    print(format_number(move_number) .. ". " .. short(r_guess) .. "  B:" .. r_bulls .. "  C:" .. r_cows .. "  r:" .. intel_show)
                    animal:add(r_guess, r_bulls, r_cows, nil)
                    table.insert(global_history, {guess=r_guess, bulls=r_bulls, cows=r_cows, positions=nil})
                end
    
                if r_bulls == CODE_LEN then
                    winner = "RACCOON"
                    solved = true
                    print("\n*** Raccoon wins! r ***")
                    break
                end
            else
                raccoon_active = false
                animal = nil
            end
            goto end_of_turn
        end
    
        if raw == "" then
            move_number = move_number - 1
            goto end_of_turn
        end
    
        local guess = parse(raw)
        if guess == nil then
            print("! Invalid. Enter a " .. CODE_LEN .. "-digit code\nfrom digits: " .. digits_str())
            move_number = move_number - 1
            goto end_of_turn
        end
    
        local bulls, cows, positions
        if easy_mode then
            bulls, cows, positions = check_with_positions(secret_code, guess)
            print(format_number(move_number) .. ". " .. short(guess) .. "  [" .. table.concat(positions, "") .. "]")
        else
            bulls, cows = check(secret_code, guess)
            print(format_number(move_number) .. ". " .. short(guess) .. "  B:" .. bulls .. "  C:" .. cows)
        end
        
        if easy_mode then
            table.insert(global_history, {guess=guess, bulls=bulls, cows=cows, positions=positions})
        else
            table.insert(global_history, {guess=guess, bulls=bulls, cows=cows, positions=nil})
        end
    
        if animal then
            if easy_mode then
                animal:add(guess, bulls, cows, positions)
            else
                animal:add(guess, bulls, cows, nil)
            end
        end
    
        if bulls == CODE_LEN then
            winner = "YOU"
            solved = true
            print("\n*** You win! ***")
            break
        end
        
        if fox_active and fox_animal and winner == nil then
            fox_move_number = fox_move_number + 1
            local f_guess = fox_animal:pick()
            local f_bulls, f_cows, f_positions
            local intel_show = show_intelligence(fox_animal:get_sample_count())
            
            if easy_mode then
                f_bulls, f_cows, f_positions = check_with_positions(fox_code, f_guess)
                print(format_number(fox_move_number) .. ". ------------ " .. short(f_guess) .. "  f:" .. intel_show)
                fox_animal:add(f_guess, f_bulls, f_cows, f_positions)
            else
                f_bulls, f_cows = check(fox_code, f_guess)
                print(format_number(fox_move_number) .. ". ------------ " .. short(f_guess) .. "  f:" .. intel_show)
                fox_animal:add(f_guess, f_bulls, f_cows, nil)
            end
            
            if f_bulls == CODE_LEN then
                winner = "FOX"
                solved = true
                print("\n*** Fox guessed the code you gave it! f You lose!")
                print("Your secret code was: " .. short(secret_code))
                break
            end
        end
    
        if raccoon_active and animal then
            move_number = move_number + 1
            
            local r_guess = animal:pick()
            local r_bulls, r_cows, r_positions
            local intel_show = show_intelligence(animal:get_sample_count())
            
            if easy_mode then
                r_bulls, r_cows, r_positions = check_with_positions(secret_code, r_guess)
                print(format_number(move_number) .. ". " .. short(r_guess) .. "  [" .. table.concat(r_positions, "") .. "]  r:" .. intel_show)
                animal:add(r_guess, r_bulls, r_cows, r_positions)
                table.insert(global_history, {guess=r_guess, bulls=r_bulls, cows=r_cows, positions=r_positions})
            else
                r_bulls, r_cows = check(secret_code, r_guess)
                print(format_number(move_number) .. ". " .. short(r_guess) .. "  B:" .. r_bulls .. "  C:" .. r_cows .. "  r:" .. intel_show)
                animal:add(r_guess, r_bulls, r_cows, nil)
                table.insert(global_history, {guess=r_guess, bulls=r_bulls, cows=r_cows, positions=nil})
            end
    
            if r_bulls == CODE_LEN then
                winner = "RACCOON"
                solved = true
                print("\n*** Raccoon wins! r ***")
                break
            end
        end
    
        ::end_of_turn::
    end
    
    if not solved then
        print("\nGame over!")
        print("The secret code was: " .. short(secret_code))
    end
    
    local time_end = os.time()
    local elapsed = math.floor(time_end - time_start)
    local min = math.floor(elapsed / 60)
    local sec = elapsed % 60
    if min > 0 then
        print("⏱  Time: " .. min .. "m " .. sec .. "s")
    else
        print("⏱  Time: " .. sec .. "s")
    end
    
    fox_active = false
    sep()
    
    return true  -- continue with new game (same settings)
end

-- ============ Main loop ============
local continue_game = true
local first_game = true
while continue_game do
    continue_game = play(first_game)
    first_game = false
    if quit_flag then
        break
    end
end
-- ============ Borko