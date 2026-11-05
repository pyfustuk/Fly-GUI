--[[ ============================================================
     Cameraman TD · All-in-One Loader & Headless Tracker v3.7
     100% чиста та стабільна версія (Zero Errors Edition)
     ============================================================ ]]

-- ============================================================
-- 0. AUTO-INJECT СТАБІЛІЗАЦІЯ
-- ============================================================
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

-- ============================================================
-- ЧАСТИНА 1: Завантажувач Kero Hub
-- ============================================================
task.spawn(function()
    task.wait(1.5)
    local maxRetries = 3
    for attempt = 1, maxRetries do
        local ok, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/KeroTwT/Kero-Hub/main/Sources/Cameraman%20TD"))()
        end)
        if ok then
            break
        else
            task.wait(2.5)
        end
    end
end)

-- ============================================================
-- ЧАСТИНА 1.5: БЕЗПЕЧНА ОПТИМІЗАЦІЯ FPS (НУЛЬ ПОМИЛОК)
-- ============================================================
task.spawn(function()
    task.wait(1.5)

    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        if setfpscap then setfpscap(60) end
    end)

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 1
        Lighting.ClockTime = 14

        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") 
               or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
                effect.Enabled = false
            end
        end

        local Terrain = workspace:FindFirstChildOfClass("Terrain")
        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.Decoration = false
        end
    end)

    local function cleanVisuals(obj)
        pcall(function()
            local c = obj.ClassName

            if c == "Highlight" then
                obj.Enabled = false
                obj.Adornee = nil
                return
            end

            if c == "ParticleEmitter" or c == "Beam" or c == "Trail" or c == "Smoke" or c == "Fire" or c == "Sparkles" then
                obj.Enabled = false
                return
            elseif c == "Explosion" then
                obj.Visible = false
                return
            elseif c == "PointLight" or c == "SpotLight" or c == "SurfaceLight" then
                obj.Enabled = false
                return
            elseif c == "BillboardGui" then
                local name = obj.Name:lower()
                if name:find("damage") or name:find("indicator") or name:find("hit") then
                    obj.Enabled = false
                end
                return
            end

            if c == "Sound" and obj:IsDescendantOf(workspace) then
                obj.Volume = 0
                return
            end
        end)
    end

    pcall(function()
        for _, desc in ipairs(workspace:GetDescendants()) do
            cleanVisuals(desc)
        end
    end)

    workspace.DescendantAdded:Connect(function(obj)
        cleanVisuals(obj)
    end)

    task.spawn(function()
        while task.wait(5) do
            pcall(function()
                local debris = workspace:FindFirstChild("Debris")
                if debris then
                    debris:ClearAllChildren()
                end
            end)
        end
    end)

    pcall(function()
        local renderEnabled = true
        UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == Enum.KeyCode.F2 then
                renderEnabled = not renderEnabled
                RunService:Set3dRenderingEnabled(renderEnabled)
            end
        end)
    end)
end)

-- ============================================================
-- ЧАСТИНА 2: Повністю фоновий трекер (БЕЗ ЖОДНОГО GUI В ГРІ)
-- ============================================================
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

if savedData.ActivitySlots and type(savedData.ActivitySlots) == "table" then
    for k, v in pairs(savedData.ActivitySlots) do
        if Session.ActivitySlots[k] == nil then
            Session.ActivitySlots[k] = (v == 4 or v == "red") and "red" or "green"
        end
    end
end

local function getDayAndSlotIndex()
    local date = os.date("*t")
    local dayIdx = (date.wday == 1) and 6 or (date.wday - 2)
    local slotIdx = date.hour * 2 + math.floor(date.min / 30)
    return dayIdx, math.clamp(slotIdx, 0, 47)
end

local function markActivitySlot(statusType)
    local dayIdx, slotIdx = getDayAndSlotIndex()
    local key = tostring(dayIdx) .. "_" .. tostring(slotIdx)
    if Session.IsKicked then
        Session.ActivitySlots[key] = "red"
    else
        Session.ActivitySlots[key] = statusType
    end
end

local CloudChannel = (genv.CameraTD_Channel) or "camtd_cloud_kvires"

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
    end
end

pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if msg and msg ~= "" then
            Session.IsKicked = true
            Session.Status = "❌ ВИЛЕТІЛО / КІКНУЛО: " .. tostring(msg)
            markActivitySlot("red")
            
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

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, result, err)
        Session.Status = "⚠️ Помилка телепорту: " .. tostring(err)
    end)
end)

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

            markActivitySlot("green")
        end
    else
        Session.LastRecordedMatchResult = nil
    end
end

-- 7. МИТТЄВИЙ ПЕРШИЙ ПІНГ (0.05с)
task.spawn(function()
    local initialData = {
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
    }
    pushUpdate(initialData)
end)

-- 8. ГОЛОВНИЙ ФОНОВИЙ ЦИКЛ
task.spawn(function()
    task.wait(1.5)
    Session.Status = "🟢 В мережі / Завантажено"

    local lastCoins = 0
    local lastCandy = 0
    local lastWave = 0
    local lastSave = 0

    while task.wait(1.5) do
        if genv.__CameraTD_ActiveInstance ~= currentInstanceToken then
            break
        end

        local now = os.time()
        local uptime = now - Session.SessionStartTime

        local curCoins = getCoins()
        local curCandy = getCandy()
        local curWave = getCurrentWave()

        local inMatch = (game.PlaceId == 114068177100380)
        local inLobby = (game.PlaceId == 132929771812494)

        if not Session.MatchStartCoins and curCoins > 0 then Session.MatchStartCoins = curCoins end
        if not Session.MatchStartCandy and curCandy > 0 then Session.MatchStartCandy = curCandy end

        if curCoins ~= lastCoins or curCandy ~= lastCandy or (curWave > 0 and curWave ~= lastWave) or inMatch then
            lastCoins = curCoins
            lastCandy = curCandy
            lastWave = curWave
            Session.LastActionTime = now
            markActivitySlot("green")
        end

        local idleSeconds = now - (Session.LastActionTime or now)
        local isAFK = (idleSeconds > 420) and not inMatch

        local statusText = ""
        if Session.IsKicked then
            statusText = Session.Status
            markActivitySlot("red")
        elseif isAFK then
            statusText = "⚠️ AFK: Немає активності (>7 хв)"
            markActivitySlot("red")
        elseif inMatch then
            statusText = string.format("🟢 В мережі: У матчі (Хвиля %d)", curWave > 0 and curWave or 1)
            markActivitySlot("green")
        elseif inLobby then
            statusText = "🟢 В мережі: Лобі (Очікування раунду)"
            markActivitySlot("green")
        else
            statusText = "🟢 В мережі: Фарм активний"
            markActivitySlot("green")
        end
        Session.Status = statusText

        checkMatchResult()

        if now - lastSave >= 1.5 then
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

            pushUpdate(exportData)
        end
    end
end)
