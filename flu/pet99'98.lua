--[[ ============================================================
     Cameraman TD · All-in-One Loader & Cloud Realtime Tracker v4.0
     Хмарна синхронізація через ntfy.sh (0ms Live SSE на сайт)
     ============================================================ ]]
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

pcall(function()
    LocalPlayer:WaitForChild("PlayerGui", 12)
end)

local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local function findHttpRequest()
    local fn = (syn and syn.request) 
        or (http and http.request) 
        or http_request 
        or (fluxus and fluxus.request) 
        or (delta and delta.request) 
        or request
    if not fn and getgenv then
        local env = getgenv()
        fn = env.request or env.http_request or (env.syn and env.syn.request) or (env.fluxus and env.fluxus.request)
    end
    return fn
end
local httpRequest = findHttpRequest()

local Folder = "CameraTD_Macros"
local StatsPath = Folder .. "/DashboardStats.json"
pcall(function()
    if makefolder and isfolder and not isfolder(Folder) then
        makefolder(Folder)
    end
end)

local genv = (getgenv and getgenv()) or _G
local currentInstanceToken = tick()
genv.__CameraTD_ActiveInstance = currentInstanceToken

-- За замовчуванням глобальний хмарний канал для сайту
local CloudChannel = (genv.CameraTD_Channel) or "camtd_cloud_kvires"

-- 1. Запуск Kero Hub під Auto-Inject (з авто-повторами)
task.spawn(function()
    task.wait(1.5)
    local maxRetries = 3
    for attempt = 1, maxRetries do
        local ok, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/KeroTwT/Kero-Hub/main/Sources/Cameraman%20TD"))()
        end)
        if ok then
            print("[Kero Loader] ✅ Kero Hub успішно активовано!")
            break
        else
            task.wait(2.5)
        end
    end
end)

-- 2. Зчитування валюти та хвиль
local function getCoins()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, name in ipairs({"Money", "Coins", "Cash", "Coin", "Points", "Gold"}) do
            local val = leaderstats:FindFirstChild(name)
            if val and val:IsA("ValueBase") then
                return tonumber(val.Value) or 0
            end
        end
    end
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local stats = pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("Stats")
        local m = stats and stats:FindFirstChild("OtherUI") and stats.OtherUI:FindFirstChild("Money") and stats.OtherUI.Money:FindFirstChild("Title")
        if m and m:IsA("TextLabel") then
            local num = m.Text:gsub(",", ""):match("[%d%.]+")
            if num then return tonumber(num) or 0 end
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
    LastRoundCoins = savedData.LastRoundCoins or 600,
    LastRoundCandy = savedData.LastRoundCandy or 10,
    LastRoundWaves = savedData.LastRoundWaves or 12,
    CoinsPerWave = savedData.CoinsPerWave or 50,
    CandyPerWave = savedData.CandyPerWave or 1,
    ActivitySlots = savedData.ActivitySlots or {},
    MatchStartCoins = nil,
    MatchStartCandy = nil,
    LastActionTime = os.time(),
    IsKicked = false,
    Status = "🔄 Заходить на сервер / Завантаження..."
}
local Session = genv.__CameraTDSession

local function getDayAndSlotIndex()
    local date = os.date("!*t", os.time() + 2 * 3600)
    local dayIdx = (date.wday == 1) and 6 or (date.wday - 2)
    local slotIdx = date.hour * 2 + math.floor(date.min / 30)
    return dayIdx, math.clamp(slotIdx, 0, 47)
end

local function markActivitySlot(statusType)
    local dayIdx, slotIdx = getDayAndSlotIndex()
    local key = tostring(dayIdx) .. "_" .. tostring(slotIdx)
    Session.ActivitySlots[key] = statusType
end

-- 3. ГОЛОВНА ФУНКЦІЯ ПЕРЕДАЧІ В ХМАРУ ТА НА САЙТ
local function pushUpdate(data)
    local ok, jsonString = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok or not jsonString then return end

    if writefile then
        pcall(function()
            writefile(StatsPath, jsonString)
        end)
    end

    local req = httpRequest or findHttpRequest()
    if req then
        -- Відправка прямо на Хмарний Сервер ntfy.sh для Сайту (0ms Live)
        task.spawn(function()
            pcall(function()
                req({
                    Url = "https://ntfy.sh/" .. CloudChannel,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                        ["Title"] = "Camera TD Live Status"
                    },
                    Body = jsonString
                })
            end)
        end)

        -- Локальний сервер (якщо запущено)
        task.spawn(function()
            pcall(function()
                req({
                    Url = "http://127.0.0.1:8765/api/update",
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = jsonString
                })
            end)
        end)
    end
end

-- 4. Детектор вильотів (підсвічує клітинку червоним)
pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if msg and msg ~= "" then
            Session.IsKicked = true
            Session.Status = "❌ ВИЛЕТІЛО / КІКНУЛО: " .. tostring(msg)
            markActivitySlot(4)
            
            local kickData = {
                PlayerName = LocalPlayer.Name,
                DisplayName = LocalPlayer.DisplayName,
                UserId = LocalPlayer.UserId,
                CurrentCoins = getCoins(),
                CurrentCandy = getCandy(),
                TotalCoinsEarned = Session.TotalCoinsEarned,
                TotalCandyEarned = Session.TotalCandyEarned,
                LastRoundCoins = Session.LastRoundCoins or 600,
                LastRoundCandy = Session.LastRoundCandy or 10,
                CoinsPerWave = Session.CoinsPerWave or 50,
                CandyPerWave = Session.CandyPerWave or 1,
                CurrentWave = getCurrentWave(),
                TotalRounds = Session.TotalRounds,
                TotalWins = Session.TotalWins,
                TotalLosses = Session.TotalLosses,
                Rejoins = Session.Rejoins,
                UptimeSeconds = os.time() - Session.SessionStartTime,
                Status = Session.Status,
                IsAFK = false,
                IsKicked = true,
                IdleSeconds = os.time() - (Session.LastActionTime or os.time()),
                LastHeartbeat = os.time(),
                SessionStartTime = Session.SessionStartTime,
                ActivitySlots = Session.ActivitySlots
            }
            pushUpdate(kickData)
        end
    end)
end)

-- 5. Підрахунок перемог / поразок / нагород (~600 💵)
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
            if roundCoins == 0 then roundCoins = 600 end
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

            markActivitySlot(2)
        end
    else
        Session.LastRecordedMatchResult = nil
    end
end

-- 6. Миттєвий пінг при старті
task.spawn(function()
    pushUpdate({
        PlayerName = LocalPlayer.Name,
        DisplayName = LocalPlayer.DisplayName,
        UserId = LocalPlayer.UserId,
        CurrentCoins = getCoins(),
        CurrentCandy = getCandy(),
        TotalCoinsEarned = Session.TotalCoinsEarned,
        TotalCandyEarned = Session.TotalCandyEarned,
        LastRoundCoins = Session.LastRoundCoins or 600,
        LastRoundCandy = Session.LastRoundCandy or 10,
        CoinsPerWave = Session.CoinsPerWave or 50,
        CandyPerWave = Session.CandyPerWave or 1,
        CurrentWave = getCurrentWave(),
        TotalRounds = Session.TotalRounds,
        TotalWins = Session.TotalWins,
        TotalLosses = Session.TotalLosses,
        Rejoins = Session.Rejoins,
        UptimeSeconds = os.time() - Session.SessionStartTime,
        Status = "🔄 Заходить на сервер / Завантаження...",
        IsAFK = false,
        IsKicked = false,
        IdleSeconds = 0,
        LastHeartbeat = os.time(),
        SessionStartTime = Session.SessionStartTime,
        ActivitySlots = Session.ActivitySlots
    })
end)

-- 7. Головний фоновий цикл
task.spawn(function()
    print("[Camera TD Headless] ✅ Фоновий трекер успішно запущено!")
    print("[Camera TD Headless] ☁️ Хмарний канал: " .. CloudChannel)
    print("[Camera TD Headless] 🌐 Сайт: https://kvires-ps99-cloud.static.hf.space")

    task.wait(1.5)
    Session.Status = "🟢 В мережі / Завантажено"

    local lastCoins = 0
    local lastSave = 0

    while task.wait(1.5) do
        if genv.__CameraTD_ActiveInstance ~= currentInstanceToken then
            break
        end

        local now = os.time()
        local uptime = now - Session.SessionStartTime
        local curCoins = getCoins()
        local curCandy = getCandy()

        if not Session.MatchStartCoins and curCoins > 0 then Session.MatchStartCoins = curCoins end
        if not Session.MatchStartCandy and curCandy > 0 then Session.MatchStartCandy = curCandy end

        if curCoins ~= lastCoins then
            lastCoins = curCoins
            Session.LastActionTime = now
            markActivitySlot(2)
        end

        local idleSeconds = now - (Session.LastActionTime or now)
        local isAFK = (idleSeconds > 420)

        local inMatch = (game.PlaceId == 114068177100380)
        local inLobby = (game.PlaceId == 132929771812494)
        local curWave = getCurrentWave()

        local statusText = ""
        if Session.IsKicked then
            statusText = Session.Status
            markActivitySlot(4)
        elseif isAFK then
            statusText = "⚠️ AFK: Немає активності (>7 хв)"
            markActivitySlot(4)
        elseif inMatch then
            statusText = string.format("🟢 В мережі: У матчі (Хвиля %d)", curWave > 0 and curWave or 1)
            markActivitySlot(1)
        elseif inLobby then
            statusText = "🟢 В мережі: Лобі (Очікування раунду)"
            markActivitySlot(1)
        else
            statusText = "🟢 В мережі: Фарм активний"
            markActivitySlot(1)
        end
        Session.Status = statusText

        checkMatchResult()

        if now - lastSave >= 1.5 then
            lastSave = now

            local liveCoinsEarned = inMatch and math.max(0, curCoins - (Session.MatchStartCoins or curCoins)) or Session.LastRoundCoins
            local liveCandyEarned = inMatch and math.max(0, curCandy - (Session.MatchStartCandy or curCandy)) or Session.LastRoundCandy
            if liveCoinsEarned == 0 and not inMatch then liveCoinsEarned = Session.LastRoundCoins end

            pushUpdate({
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
            })
        end
    end
end)
