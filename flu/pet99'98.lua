--[[ ============================================================
     Cameraman TD · All-in-One Loader & Cloud Analytics Tracker
     
     ЧАСТИНА 1: Завантажувач Kero Hub (авто-фарм, авто-юніти, макроси)
     ЧАСТИНА 2: Хмарний трекер для сайту на Hugging Face (24/7 моніторинг)
     
     Особливості трекера:
     - Підрахунок заробітку за 1 повний раунд (монети і цукерки)
     - Розрахунок середнього прибутку за 1 пройдену хвилю
     - Збереження сесії та лічильника перезаходів (Rejoins) при стрибках серверів
     - Відправка сигналу на Hugging Face сайт (живий статус без перезавантажень)
     - Детекція AFK при відсутності зв'язку чи активності довше 7 хвилин (> 7m)
     ============================================================ ]]

repeat task.wait() until game:IsLoaded()

-- ============================================================
-- ЧАСТИНА 1: Завантажувач Kero Hub (Auto-Farm & Features)
-- ============================================================
task.spawn(function()
    local ok, err = pcall(function()
        print("[Kero Loader] Запуск Kero Hub...")
        loadstring(game:HttpGet("https://raw.githubusercontent.com/KeroTwT/Kero-Hub/main/Sources/Cameraman%20TD"))()
    end)
    if ok then
        print("[Kero Loader] Kero Hub успішно запущено!")
    else
        warn("[Kero Loader] Помилка завантаження Kero Hub: " .. tostring(err))
    end
end)

-- ============================================================
-- ЧАСТИНА 2: Хмарний трекер, HUD та аналітика за раунд/хвилю
-- ============================================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local genv = (getgenv and getgenv()) or _G
local Folder = "CameraTD_Macros"
local StatsPath = Folder .. "/DashboardStats.json"
local HF_SITE_URL = "https://kvires-ps99-cloud.static.hf.space"
local NTFY_TOPIC = "camtd_stats_kvires"

if makefolder and isfolder and not isfolder(Folder) then
    pcall(makefolder, Folder)
end

-- HTTP request helper
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or (delta and delta.request) or request
local function doHttpPost(url, body)
    if httpRequest then
        pcall(function()
            httpRequest({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body
            })
        end)
    end
end

local function copyToClipboardSafe(text)
    local clipFn = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
    if clipFn then
        return pcall(clipFn, tostring(text))
    end
    return false
end

-- 1. Helper functions to read money and candy
local function getCoins()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local money = leaderstats and leaderstats:FindFirstChild("Money")
    if money and money:IsA("ValueBase") then return tonumber(money.Value) or 0 end
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    local title = pgui and pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("Stats")
    local m = title and title:FindFirstChild("OtherUI") and title.OtherUI:FindFirstChild("Money") and title.OtherUI.Money:FindFirstChild("Title")
    if m then
        local num = m.Text:gsub(",", ""):match("[%d%.]+")
        return tonumber(num) or 0
    end
    return 0
end

local function getCandy()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    local candyLabel = pgui and pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("HUD")
    candyLabel = candyLabel and candyLabel:FindFirstChild("Currencies") and candyLabel.Currencies:FindFirstChild("Candy")
    candyLabel = candyLabel and candyLabel:FindFirstChild("CurrencyFrame") and candyLabel.CurrencyFrame:FindFirstChild("AmountLabel")
    if candyLabel then
        local num = candyLabel.Text:gsub(",", ""):match("(%d+)")
        return tonumber(num) or 0
    end
    return 0
end

-- Scan current wave number from UI
local function getCurrentWave()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return 0 end
    local gameUI = pgui:FindFirstChild("GameUI")
    if not gameUI then return 0 end

    -- Try common wave labels
    for _, obj in pairs(gameUI:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local text = obj.Text
            local wMatch = text:match("[Ww]ave%s*[:%-]?%s*(%d+)")
            if wMatch then
                return tonumber(wMatch) or 0
            end
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

-- 2. Restore or Initialize Cross-Server Session
local savedData = {}
if readfile and isfile and isfile(StatsPath) then
    pcall(function()
        local content = readfile(StatsPath)
        savedData = HttpService:JSONDecode(content) or {}
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
    LastRoundCoins = savedData.LastRoundCoins or 0,
    LastRoundCandy = savedData.LastRoundCandy or 0,
    LastRoundWaves = savedData.LastRoundWaves or 0,
    CoinsPerWave = savedData.CoinsPerWave or 0,
    CandyPerWave = savedData.CandyPerWave or 0,
    InitialCoins = nil,
    InitialCandy = nil,
    MatchStartCoins = nil,
    MatchStartCandy = nil,
    MatchStartWave = 1,
    LastActionTime = os.time(),
    LastPlaceId = game.PlaceId,
    LastJobId = game.JobId,
    Status = "Ініціалізація..."
}
local Session = genv.__CameraTDSession

-- 3. Match End & Round Earnings Detector
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

            -- Calculate Round Specific Earnings
            local curCoins = getCoins()
            local curCandy = getCandy()
            local startCoins = Session.MatchStartCoins or curCoins
            local startCandy = Session.MatchStartCandy or curCandy

            local roundCoins = math.max(0, curCoins - startCoins)
            local roundCandy = math.max(0, curCandy - startCandy)
            local wavesCompleted = math.max(1, getCurrentWave())

            Session.LastRoundCoins = roundCoins
            Session.LastRoundCandy = roundCandy
            Session.LastRoundWaves = wavesCompleted
            Session.CoinsPerWave = math.floor(roundCoins / wavesCompleted)
            Session.CandyPerWave = math.floor(roundCandy / wavesCompleted)

            Session.TotalCoinsEarned = Session.TotalCoinsEarned + roundCoins
            Session.TotalCandyEarned = Session.TotalCandyEarned + roundCandy

            Session.LastRecordedMatchResult = os.time()
            Session.LastActionTime = os.time()

            -- Reset match start benchmarks for next round
            Session.MatchStartCoins = curCoins
            Session.MatchStartCandy = curCandy
        end
    else
        Session.LastRecordedMatchResult = nil
    end
end

-- 4. Create Modern In-Game Tracker HUD
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CameraTD_Tracker_HUD"
screenGui.ResetOnSpawn = false

pcall(function()
    if gethui then
        screenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(screenGui)
        screenGui.Parent = CoreGui
    else
        screenGui.Parent = CoreGui
    end
end)
if not screenGui.Parent then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(0, 290, 0, 245)
mainFrame.Position = UDim2.new(0, 20, 0.45, -120)
mainFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 38)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(92, 71, 134)
stroke.Thickness = 1.8
stroke.Parent = mainFrame

-- Title Bar
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 26)
title.Position = UDim2.new(0, 12, 0, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "🦇 Camera TD | AFK & Cloud Tracker"
title.TextColor3 = Color3.fromRGB(246, 193, 119)
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local function createRow(yPos, icon, labelText)
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(1, -24, 0, 20)
    valLabel.Position = UDim2.new(0, 12, 0, yPos)
    valLabel.BackgroundTransparency = 1
    valLabel.Font = Enum.Font.GothamMedium
    valLabel.Text = icon .. " " .. labelText .. ": --"
    valLabel.TextColor3 = Color3.fromRGB(224, 222, 244)
    valLabel.TextSize = 11
    valLabel.TextXAlignment = Enum.TextXAlignment.Left
    valLabel.Parent = mainFrame
    return valLabel
end

local lblUptime   = createRow(34,  "⏱️", "Час в AFK")
local lblRounds   = createRow(56,  "🏆", "Раундів (Він/Луз)")
local lblRejoins  = createRow(78,  "🔄", "Перезаходів")
local lblPerRound = createRow(100, "💰", "За 1 раунд")
local lblPerWave  = createRow(122, "🌊", "За 1 хвилю")
local lblStatus   = createRow(144, "🟢", "Статус")
local lblCloud    = createRow(166, "☁️", "Хмара HuggingFace")

lblStatus.TextColor3 = Color3.fromRGB(166, 227, 161)
lblPerRound.TextColor3 = Color3.fromRGB(246, 193, 119)
lblPerWave.TextColor3 = Color3.fromRGB(156, 207, 216)

-- Web Link Button
local btnWeb = Instance.new("TextButton")
btnWeb.Size = UDim2.new(1, -24, 0, 28)
btnWeb.Position = UDim2.new(0, 12, 0, 202)
btnWeb.BackgroundColor3 = Color3.fromRGB(61, 47, 90)
btnWeb.Font = Enum.Font.GothamBold
btnWeb.Text = "🌐 Відкрити сайт (Скопіювати)"
btnWeb.TextColor3 = Color3.fromRGB(255, 255, 255)
btnWeb.TextSize = 11
btnWeb.Parent = mainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = btnWeb

btnWeb.MouseButton1Click:Connect(function()
    copyToClipboardSafe(HF_SITE_URL)
    btnWeb.Text = "✅ Ссилку скопійовано!"
    task.wait(2)
    btnWeb.Text = "🌐 Відкрити сайт (Скопіювати)"
end)

-- 5. Main Loop: Tracks Analytics, Heartbeat, and Sends to Cloud
local lastCloudSync = 0
local previousCoins = 0

task.spawn(function()
    while task.wait(1) do
        local now = os.time()
        local uptime = now - Session.SessionStartTime

        -- Current Wallet
        local curCoins = getCoins()
        local curCandy = getCandy()

        -- Initial baseline
        if not Session.InitialCoins and curCoins > 0 then Session.InitialCoins = curCoins end
        if not Session.InitialCandy and curCandy > 0 then Session.InitialCandy = curCandy end
        if not Session.MatchStartCoins and curCoins > 0 then Session.MatchStartCoins = curCoins end
        if not Session.MatchStartCandy and curCandy > 0 then Session.MatchStartCandy = curCandy end

        -- Activity check: if coins changed, reset idle timer
        if curCoins ~= previousCoins then
            previousCoins = curCoins
            Session.LastActionTime = now
        end

        local idleSeconds = now - (Session.LastActionTime or now)
        local isAFKTimeout = (idleSeconds > 420) -- > 7 minutes timeout

        -- Detect Current Game State
        local inMatch = (game.PlaceId == 114068177100380)
        local inLobby = (game.PlaceId == 132929771812494)
        local curWave = getCurrentWave()

        local stateText = ""
        if isAFKTimeout then
            stateText = "⚠️ AFK: Немає активності (>7 хв)"
            lblStatus.TextColor3 = Color3.fromRGB(235, 111, 146)
        elseif inMatch then
            stateText = string.format("У матчі (Хвиля %d)", curWave > 0 and curWave or 1)
            lblStatus.TextColor3 = Color3.fromRGB(166, 227, 161)
        elseif inLobby then
            stateText = "У лобі (Очікування гри)"
            lblStatus.TextColor3 = Color3.fromRGB(246, 193, 119)
        else
            stateText = "У грі (Фарм активний)"
            lblStatus.TextColor3 = Color3.fromRGB(166, 227, 161)
        end
        Session.Status = stateText

        -- Check match result UI
        checkMatchResult()

        -- Real-time estimate of current match earnings
        local liveMatchCoins = math.max(0, curCoins - (Session.MatchStartCoins or curCoins))
        local liveMatchCandy = math.max(0, curCandy - (Session.MatchStartCandy or curCandy))
        local displayRoundCoins = inMatch and liveMatchCoins or Session.LastRoundCoins
        local displayRoundCandy = inMatch and liveMatchCandy or Session.LastRoundCandy

        local waveDiv = curWave > 0 and curWave or math.max(1, Session.LastRoundWaves)
        local displayPerWaveCoins = math.floor(displayRoundCoins / waveDiv)
        local displayPerWaveCandy = math.floor(displayRoundCandy / waveDiv)

        -- Update HUD
        lblUptime.Text   = "⏱️ Час в AFK: " .. formatTime(uptime)
        lblRounds.Text   = string.format("🏆 Раундів: %d (В: %d | Л: %d)", Session.TotalRounds, Session.TotalWins, Session.TotalLosses)
        lblRejoins.Text  = "🔄 Перезаходів: " .. tostring(Session.Rejoins)
        lblPerRound.Text = string.format("💰 За 1 раунд: +%s 💵 | +%s 🍬", tostring(displayRoundCoins), tostring(displayRoundCandy))
        lblPerWave.Text  = string.format("🌊 За 1 хвилю: ~%s 💵 | ~%s 🍬", tostring(displayPerWaveCoins), tostring(displayPerWaveCandy))
        lblStatus.Text   = (isAFKTimeout and "⚠️ " or "🟢 ") .. stateText
        lblCloud.Text    = "☁️ Хмара: Онлайн (Синхронізація)"

        -- 6. Synchronize to File & Hugging Face Cloud every 3 seconds
        if now - lastCloudSync >= 3 then
            lastCloudSync = now

            local exportData = {
                PlayerName = LocalPlayer.Name,
                UptimeSeconds = uptime,
                UptimeFormatted = formatTime(uptime),
                TotalRounds = Session.TotalRounds,
                TotalWins = Session.TotalWins,
                TotalLosses = Session.TotalLosses,
                Rejoins = Session.Rejoins,
                TotalCoinsEarned = Session.TotalCoinsEarned + liveMatchCoins,
                TotalCandyEarned = Session.TotalCandyEarned + liveMatchCandy,
                CurrentCoins = curCoins,
                CurrentCandy = curCandy,
                LastRoundCoins = displayRoundCoins,
                LastRoundCandy = displayRoundCandy,
                CoinsPerWave = displayPerWaveCoins,
                CandyPerWave = displayPerWaveCandy,
                CurrentWave = curWave,
                Status = stateText,
                IsAFK = isAFKTimeout,
                IdleSeconds = idleSeconds,
                LastHeartbeat = now,
                SessionStartTime = Session.SessionStartTime
            }

            local jsonString = HttpService:JSONEncode(exportData)

            -- 1. Save locally for persistence across crashes/reconnects
            if writefile then
                pcall(function()
                    writefile(StatsPath, jsonString)
                end)
            end

            -- 2. Push to Cloud (ntfy.sh bridge for Hugging Face Web Dashboard)
            task.spawn(function()
                doHttpPost("https://ntfy.sh/" .. NTFY_TOPIC, jsonString)
            end)
        end
    end
end)

print("[Camera TD Tracker] Повний завантажувач + хмарний трекер успішно запущено!")
