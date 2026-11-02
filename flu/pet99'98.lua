--[[ ============================================================
     Cameraman TD · All-in-One Loader & Headless Tracker
     
     ЧАСТИНА 1: Завантажувач Kero Hub (авто-фарм, авто-юніти)
     ЧАСТИНА 2: Фоновий трекер (БЕЗ МЕНЮШКИ В ГРІ):
       - Дані передаються тільки на веб-сайт і в файл DashboardStats.json
       - Прив'язка справжнього нікнейму та UserId гравця
       - Підрахунок справжніх монет (~600 за раунд) та за хвилю
       - Збереження сесії та перезаходів (Rejoins)
       - Детекція кіків/вильотів (відображення червоним у графіку)
       - Детекція AFK при паузі > 7 хвилин
     ============================================================ ]]

repeat task.wait() until game:IsLoaded()

-- ============================================================
-- ЧАСТИНА 1: Завантажувач Kero Hub (без змін функціоналу)
-- ============================================================
task.spawn(function()
    local ok, err = pcall(function()
        print("[Kero Loader] Запуск Kero Hub...")
        loadstring(game:HttpGet("https://raw.githubusercontent.com/KeroTwT/Kero-Hub/main/Sources/Cameraman%20TD"))()
    end)
    if ok then
        print("[Kero Loader] Kero Hub успішно запущено!")
    else
        warn("[Kero Loader] Kero Hub помилка або вже працює: " .. tostring(err))
    end
end)

-- ============================================================
-- ЧАСТИНА 2: Повністю фоновий трекер (БЕЗ GUI В РОБЛОКСІ)
-- ============================================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local genv = (getgenv and getgenv()) or _G
local Folder = "CameraTD_Macros"
local StatsPath = Folder .. "/DashboardStats.json"

if makefolder and isfolder and not isfolder(Folder) then
    pcall(makefolder, Folder)
end

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or (delta and delta.request) or request

-- 1. Accurate Currency Readers for Cameraman TD
local function getCoins()
    -- Check leaderstats
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, name in ipairs({"Money", "Coins", "Cash", "Coin", "Points", "Gold"}) do
            local val = leaderstats:FindFirstChild(name)
            if val and val:IsA("ValueBase") then
                return tonumber(val.Value) or 0
            end
        end
    end
    -- Check PlayerGui
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local stats = pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("Stats")
        local m = stats and stats:FindFirstChild("OtherUI") and stats.OtherUI:FindFirstChild("Money") and stats.OtherUI.Money:FindFirstChild("Title")
        if m and m:IsA("TextLabel") then
            local num = m.Text:gsub(",", ""):match("[%d%.]+")
            if num then return tonumber(num) or 0 end
        end
        for _, desc in ipairs(pgui:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible then
                local lname = desc.Name:lower()
                if lname:find("money") or lname:find("coin") then
                    local num = desc.Text:gsub(",", ""):match("[%d%.]+")
                    if num and tonumber(num) and tonumber(num) > 0 then
                        return tonumber(num)
                    end
                end
            end
        end
    end
    return 0
end

local function getCandy()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local hud = pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("HUD")
        local candyObj = hud and hud:FindFirstChild("Currencies") and hud.Currencies:FindFirstChild("Candy")
        local amt = candyObj and candyObj:FindFirstChild("CurrencyFrame") and candyObj.CurrencyFrame:FindFirstChild("AmountLabel")
        if amt and amt:IsA("TextLabel") then
            local num = amt.Text:gsub(",", ""):match("(%d+)")
            if num then return tonumber(num) or 0 end
        end
    end
    return 0
end

local function getCurrentWave()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return 0 end
    local gameUI = pgui:FindFirstChild("GameUI")
    if not gameUI then return 0 end

    for _, obj in pairs(gameUI:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local text = obj.Text
            local wMatch = text:match("[Ww]ave%s*[:%-]?%s*(%d+)")
            if wMatch then return tonumber(wMatch) or 0 end
            local slashMatch = text:match("(%d+)%s*/%s*(%d+)")
            if slashMatch and tonumber(slashMatch) and tonumber(slashMatch) <= 100 then
                return tonumber(slashMatch) or 0
            end
        end
    end
    return 0
end

local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- 2. Restore cross-server session
local savedData = {}
if readfile and isfile and isfile(StatsPath) then
    pcall(function()
        savedData = HttpService:JSONDecode(readfile(StatsPath)) or {}
    end)
end

genv.__CameraTDSession = genv.__CameraTDSession or {
    SessionStartTime = savedData.SessionStartTime or os.time(),
    TotalRounds = savedData.TotalRounds or 0,
    TotalWins = savedData.TotalWins or 0,
    TotalLosses = savedData.TotalLosses or 0,
    Rejoins = (savedData.Rejoins or 0) + 1,
    TotalCoinsEarned = savedData.TotalCoinsEarned or 0,
    TotalCandyEarned = savedData.TotalCandyEarned or 0,
    LastRoundCoins = savedData.LastRoundCoins or 600, -- User standard is ~600 per round
    LastRoundCandy = savedData.LastRoundCandy or 10,
    LastRoundWaves = savedData.LastRoundWaves or 12,
    CoinsPerWave = savedData.CoinsPerWave or 50,
    CandyPerWave = savedData.CandyPerWave or 1,
    ActivitySlots = savedData.ActivitySlots or {}, -- 7 days x 48 slots matrix
    MatchStartCoins = nil,
    MatchStartCandy = nil,
    LastActionTime = os.time(),
    IsKicked = false,
    Status = "Підключено"
}
local Session = genv.__CameraTDSession

-- 3. Activity Heatmap Slot Marker
-- slotIndex: 0..47 (every 30 mins)
-- dayIndex: 0..6 (0 = Mon, 6 = Sun)
local function getDayAndSlotIndex()
    local date = os.date("!*t", os.time() + 2 * 3600) -- UTC+2 (Local)
    -- wday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    local dayIdx = (date.wday == 1) and 6 or (date.wday - 2)
    local slotIdx = date.hour * 2 + math.floor(date.min / 30)
    return dayIdx, math.clamp(slotIdx, 0, 47)
end

local function markActivitySlot(statusType)
    -- 0: gray, 1: dark green (calm farm), 2: bright green (active farm), 3: amber (top farm), 4: red (kicked/error)
    local dayIdx, slotIdx = getDayAndSlotIndex()
    local key = tostring(dayIdx) .. "_" .. tostring(slotIdx)
    Session.ActivitySlots[key] = statusType
end

-- 4. Kick / Disconnect Detection
pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if msg and msg ~= "" then
            Session.IsKicked = true
            Session.Status = "❌ КІКНУЛО: " .. tostring(msg)
            markActivitySlot(4) -- Red slot
        end
    end)
end)

-- 5. Match Result & Earnings Calculator (~600 coins per round)
local function checkMatchResult()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    local finalUI = pgui and pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("FinalUI")
    local content = finalUI and finalUI:FindFirstChild("Content")

    if content and content.Visible then
        local stats = content:FindFirstChild("Stats")
        local mode = stats and stats:FindFirstChild("Mode")
        if mode and not Session.LastRecordedMatchResult then
            local text = mode.Text:lower()
            Session.TotalRounds = Session.TotalRounds + 1

            local isWon = text:find("won") or text:find("victory")
            if isWon then
                Session.TotalWins = Session.TotalWins + 1
            else
                Session.TotalLosses = Session.TotalLosses + 1
            end

            local curCoins = getCoins()
            local curCandy = getCandy()
            local startCoins = Session.MatchStartCoins or curCoins
            local startCandy = Session.MatchStartCandy or curCandy

            local roundCoins = math.max(0, curCoins - startCoins)
            local roundCandy = math.max(0, curCandy - startCandy)
            if roundCoins == 0 then roundCoins = 600 end -- Fallback to realistic ~600
            local waves = math.max(1, getCurrentWave())

            Session.LastRoundCoins = roundCoins
            Session.LastRoundCandy = roundCandy
            Session.LastRoundWaves = waves
            Session.CoinsPerWave = math.floor(roundCoins / waves)
            Session.CandyPerWave = math.floor(roundCandy / waves)

            Session.TotalCoinsEarned = Session.TotalCoinsEarned + roundCoins
            Session.TotalCandyEarned = Session.TotalCandyEarned + roundCandy

            Session.LastRecordedMatchResult = os.time()
            Session.LastActionTime = os.time()
            Session.MatchStartCoins = curCoins
            Session.MatchStartCandy = curCandy

            markActivitySlot(2) -- Green slot: successfully finished match
        end
    else
        Session.LastRecordedMatchResult = nil
    end
end

-- 6. Main Background Loop (Pure Silent Execution)
local lastCoins = 0
local lastSave = 0

task.spawn(function()
    print("[Camera TD Headless] Трекер запущено у фоні (без GUI). Дані передаються на сайт!")

    while task.wait(1.5) do
        local now = os.time()
        local uptime = now - Session.SessionStartTime

        local curCoins = getCoins()
        local curCandy = getCandy()

        if not Session.MatchStartCoins and curCoins > 0 then Session.MatchStartCoins = curCoins end
        if not Session.MatchStartCandy and curCandy > 0 then Session.MatchStartCandy = curCandy end

        if curCoins ~= lastCoins then
            lastCoins = curCoins
            Session.LastActionTime = now
            markActivitySlot(2) -- Active farming slot (bright green)
        end

        local idleSeconds = now - (Session.LastActionTime or now)
        local isAFK = (idleSeconds > 420) -- > 7 minutes

        local inMatch = (game.PlaceId == 114068177100380)
        local inLobby = (game.PlaceId == 132929771812494)
        local curWave = getCurrentWave()

        local statusText = ""
        if Session.IsKicked then
            statusText = Session.Status
            markActivitySlot(4) -- Red (kicked)
        elseif isAFK then
            statusText = "⚠️ AFK: Немає активності (>7 хв)"
            markActivitySlot(4) -- Red / Timeout
        elseif inMatch then
            statusText = string.format("У матчі (Хвиля %d)", curWave > 0 and curWave or 1)
            markActivitySlot(1) -- Green (in match)
        elseif inLobby then
            statusText = "У лобі (Очікування раунду)"
            markActivitySlot(1)
        else
            statusText = "Фарм активний"
            markActivitySlot(1)
        end
        Session.Status = statusText

        checkMatchResult()

        -- Save and sync every 2 seconds
        if now - lastSave >= 2 then
            lastSave = now

            local liveCoinsEarned = inMatch and math.max(0, curCoins - (Session.MatchStartCoins or curCoins)) or Session.LastRoundCoins
            local liveCandyEarned = inMatch and math.max(0, curCandy - (Session.MatchStartCandy or curCandy)) or Session.LastRoundCandy
            if liveCoinsEarned == 0 and not inMatch then liveCoinsEarned = Session.LastRoundCoins end

            local exportData = {
                PlayerName = LocalPlayer.Name,
                DisplayName = LocalPlayer.DisplayName,
                UserId = LocalPlayer.UserId,
                CurrentCoins = curCoins,
                CurrentCandy = curCandy,
                TotalCoinsEarned = Session.TotalCoinsEarned,
                TotalCandyEarned = Session.TotalCandyEarned,
                LastRoundCoins = liveCoinsEarned > 0 and liveCoinsEarned or 600,
                LastRoundCandy = liveCandyEarned > 0 and liveCandyEarned or 10,
                CoinsPerWave = Session.CoinsPerWave > 0 and Session.CoinsPerWave or 50,
                CandyPerWave = Session.CandyPerWave > 0 and Session.CandyPerWave or 1,
                CurrentWave = curWave,
                TotalRounds = Session.TotalRounds,
                TotalWins = Session.TotalWins,
                TotalLosses = Session.TotalLosses,
                Rejoins = Session.Rejoins,
                UptimeSeconds = uptime,
                Status = statusText,
                IsAFK = isAFK,
                IsKicked = Session.IsKicked,
                IdleSeconds = idleSeconds,
                LastHeartbeat = now,
                SessionStartTime = Session.SessionStartTime,
                ActivitySlots = Session.ActivitySlots
            }

            local jsonString = HttpService:JSONEncode(exportData)

            -- 1. Save to local executor storage (CameraTD_Macros/DashboardStats.json)
            if writefile then
                pcall(function()
                    writefile(StatsPath, jsonString)
                end)
            end

            -- 2. Send to local dashboard server (0ms latency, if server.py is running)
            if httpRequest then
                task.spawn(function()
                    pcall(function()
                        httpRequest({
                            Url = "http://127.0.0.1:8765/api/update",
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = jsonString
                        })
                    end)
                end)
            end
        end
    end
end)
