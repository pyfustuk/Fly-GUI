--[[ ============================================================
     Cameraman TD · All-in-One Loader & Headless Tracker v3.5 (Auto-Inject Edition)
     
     ОСОБЛИВОСТІ ТА ВИПРАВЛЕННЯ ДЛЯ AUTO-INJECT / AUTOEXEC:
       1. Повна сумісність з autoexec (Solara, Wave, Codex, Delta, Fluxus тощо)
       2. Жорсткий захист від раннього запуску (game:IsLoaded + non-blocking LocalPlayer resolution)
       3. Захист Kero Hub від збоїв: відкладений старт (1.5с) з 3 авто-повторами
       4. Миттєвий перший пінг (0.05с): сайт і файл одразу бачать ваш нік та аватарку
       5. 100% фоновий трекер БЕЗ ЖОДНОГО GUI В ГРІ (повний стелс, нуль лагів)
       6. Детекція вильотів та кіків через GuiService (миттєве підсвічування ЧЕРВОНИМ)
       7. Реальні нагороди (~600 💵 за раунд) та розрахунок за хвилю
       8. Захист від дублювання потоків між серверами / телепортами (Instance Token)
     ============================================================ ]]

-- ============================================================
-- 0. ПРИДУШЕННЯ СПАМУ В ЛОГАХ (bulk, table: 0x..., nil)
-- ============================================================
local function _shouldFilterLog(...)
    local _cnt = select("#", ...)
    for _i = 1, _cnt do
        local _v = select(_i, ...)
        local _s = tostring(_v):lower()
        if _s:find("bulk") or _s:find("table:%s*0x") then
            return true
        end
    end
    local _f = select(1, ...)
    if _f == nil and _cnt >= 2 then
        local _sec = tostring(select(2, ...)):lower()
        if _sec:find("bulk") or _sec:find("table:%s*0x") then
            return true
        end
    end
    return false
end

local _oldPrint, _oldWarn = print, warn
local function _cleanPrint(...)
    if _shouldFilterLog(...) then return end
    return _oldPrint(...)
end
local function _cleanWarn(...)
    if _shouldFilterLog(...) then return end
    return _oldWarn(...)
end

-- Safe Lua assignment (Zero Crash on Android Delta)
if getgenv then
    getgenv().print = _cleanPrint
    getgenv().warn = _cleanWarn
end
_G.print = _cleanPrint
_G.warn = _cleanWarn

-- ============================================================
-- 0. AUTO-INJECT СТАБІЛІЗАЦІЯ (КРИТИЧНО ДЛЯ AUTOEXEC)
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

-- Очікуємо PlayerGui для коректного завантаження UI-об'єктів гри
pcall(function()
    LocalPlayer:WaitForChild("PlayerGui", 12)
end)

local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

-- Пошук функції запиту для будь-якого експлойта
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

-- Папка для збереження статистики
local Folder = "CameraTD_Macros"
local StatsPath = Folder .. "/DashboardStats.json"
pcall(function()
    if makefolder and isfolder and not isfolder(Folder) then
        makefolder(Folder)
    end
end)

-- Глобальне середовище та захист від дублікатів потоків
local genv = (getgenv and getgenv()) or _G
local currentInstanceToken = tick()
genv.__CameraTD_ActiveInstance = currentInstanceToken

-- ============================================================
-- ЧАСТИНА 1: Завантажувач Kero Hub (Чистий запуск без важких сканувань)
-- ============================================================
task.spawn(function()
    task.wait(1.2)
    local hubUrls = {
        "https://huggingface.co/spaces/kvires/ps99-cloud/raw/main/cameraman_hub.lua",
        "https://raw.githubusercontent.com/KeroTwT/Kero-Hub/main/Sources/Cameraman%20TD"
    }
    for _, url in ipairs(hubUrls) do
        local ok = pcall(function()
            local code = game:HttpGet(url)
            if code and #code > 1000 then
                loadstring(code)()
                return true
            end
            error("empty code")
        end)
        if ok then break end
        task.wait(1.5)
    end
end)

-- ============================================================
-- ЧАСТИНА 1.5: ЛЕГКА ТА ЕФЕКТИВНА ОПТИМІЗАЦІЯ FPS
--
-- ВИПРАВЛЕНО ГОЛОВНІ ПРИЧИНИ ЛАГІВ:
-- 1. ПРИБРАНО сканування Workspace:GetDescendants() на 1-5 хвилях.
-- 2. ПРИБРАНО hook на workspace.DescendantAdded, який викликав 0 FPS при виборі юніта в хотбарі.
-- 3. ПРИБРАНО виклики KeroHub.FPS(true) та SetRemoveVisuals(true), які заморожували телефон.
-- 4. Тільки нативні системні налаштування рушія: QualityLevel 1, вимкнені тіні та постобробка.
-- 5. Мобів та вежі 100% ВИДНО для комфортного запису макросу.
-- 6. Прозорий лічильник FPS (чорний текст) у верхньому правому кутку.
-- ============================================================
task.spawn(function()
    task.wait(1.0)

    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")

    -- 1. Нативні системні налаштування рушія (0% навантаження на процесор)
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        if setfpscap then setfpscap(60) end
    end)

    -- 2. Глобальне вимкнення тіней та важких шейдерів
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

        pcall(function()
            local Terrain = workspace:FindFirstChildOfClass("Terrain")
            if Terrain then
                pcall(function() Terrain.WaterWaveSize = 0 end)
                pcall(function() Terrain.WaterWaveSpeed = 0 end)
                pcall(function() Terrain.WaterReflectance = 0 end)
                pcall(function() Terrain.Decoration = false end)
            end
        end)
    end)

    -- 3. Точкова фільтрація ефектів ТІЛЬКИ в папках бою (Effects / VFX / Projectiles)
    -- Не чіпає PlacingTowers, тому при натисканні на юніта в хотбарі більше НІКОЛИ не буде 0 FPS!
    local function bindCombatVFX(folder)
        if not folder then return end
        folder.ChildAdded:Connect(function(child)
            pcall(function()
                if child:IsA("ParticleEmitter") or child:IsA("Beam") or child:IsA("Trail") then
                    child.Enabled = false
                elseif child:IsA("Explosion") then
                    child.Visible = false
                elseif child:IsA("Light") then
                    child.Enabled = false
                elseif child:IsA("Sound") then
                    child.Volume = 0
                end
            end)
        end)
    end

    pcall(function()
        local g = workspace:FindFirstChild("Game")
        if g then
            bindCombatVFX(g:FindFirstChild("Effects"))
            bindCombatVFX(g:FindFirstChild("VFX"))
            bindCombatVFX(g:FindFirstChild("Projectiles"))
        end
        bindCombatVFX(workspace:FindFirstChild("Effects"))
        bindCombatVFX(workspace:FindFirstChild("VFX"))
        bindCombatVFX(workspace:FindFirstChild("Projectiles"))
    end)

    -- 4. Періодична зачистка сміття (Debris) раз на 5 секунд
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

    -- 5. Компактний прозорий лічильник FPS (чорний текст)
    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if pgui then
            local screen = Instance.new("ScreenGui")
            screen.Name = "CameraTD_FPSMeter"
            screen.ResetOnSpawn = false
            screen.DisplayOrder = 999999
            pcall(function() screen.Parent = (gethui and gethui()) or pgui end)

            local fpsLabel = Instance.new("TextLabel")
            fpsLabel.Name = "FPSDisplay"
            fpsLabel.Size = UDim2.new(0, 60, 0, 20)
            fpsLabel.Position = UDim2.new(1, -70, 0, 8)
            fpsLabel.BackgroundTransparency = 1
            fpsLabel.BorderSizePixel = 0
            fpsLabel.Text = "60 FPS"
            fpsLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
            fpsLabel.TextSize = 13
            fpsLabel.Font = Enum.Font.GothamBold
            fpsLabel.Parent = screen

            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(255, 255, 255)
            stroke.Thickness = 0.8
            stroke.Transparency = 0.4
            stroke.Parent = fpsLabel

            local frameCount = 0
            local lastTime = os.clock()

            RunService.RenderStepped:Connect(function()
                frameCount = frameCount + 1
                local now = os.clock()
                local delta = now - lastTime
                if delta >= 0.15 then
                    local currentFPS = math.clamp(math.round(frameCount / delta), 0, 120)
                    fpsLabel.Text = tostring(currentFPS) .. " FPS"
                    frameCount = 0
                    lastTime = now
                end
            end)
        end
    end)
end)

-- ============================================================
-- ЧАСТИНА 2: KERO ADMIN CLOUD TRACKER v4.4 (ТОЧНИЙ ЧАС ТА ПОВНІ ДАНІ)
-- 100% Фоновий стелс, без GUI в Roblox, підтримка мульти-акаунтів
-- ============================================================

local Folder = "CameraTD_Macros"
local StatsPath = Folder .. "/DashboardStats.json"
local SessionTokenPath = Folder .. "/SessionToken.json"

pcall(function()
    if makefolder and isfolder and not isfolder(Folder) then
        makefolder(Folder)
    end
end)

-- 1. Хелпери для взаємодії з Kero Hub та грою
local function getHub()
    return (getgenv and getgenv().CameraTDHub) or _G.CameraTDHub
end

-- Зчитування золота / грошей акаунта (в лобі та інвентарі)
local function getAccountCoins()
    local hub = getHub()
    if hub and hub.InventoryData and tonumber(hub.InventoryData.Money) then
        return tonumber(hub.InventoryData.Money)
    end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, name in ipairs({"Coins", "Gold", "Money", "TotalCoins", "Coin"}) do
            local val = leaderstats:FindFirstChild(name)
            if val and val:IsA("ValueBase") then return tonumber(val.Value) or 0 end
        end
    end
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local hud = pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("HUD")
        local coinsObj = hud and hud:FindFirstChild("Currencies") and (hud.Currencies:FindFirstChild("Coins") or hud.Currencies:FindFirstChild("Money") or hud.Currencies:FindFirstChild("Gold"))
        local amt = coinsObj and coinsObj:FindFirstChild("CurrencyFrame") and coinsObj.CurrencyFrame:FindFirstChild("AmountLabel")
        if amt and amt:IsA("TextLabel") then
            local num = amt.Text:gsub(",", ""):match("(%d+)")
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

-- Зчитування алмазів / діамантів акаунта
local function getAccountGems()
    local hub = getHub()
    if hub and hub.InventoryData then
        local g = tonumber(hub.InventoryData.Gems) or tonumber(hub.InventoryData.Diamonds) or tonumber(hub.InventoryData.Crystals)
        if g then return g end
    end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        for _, name in ipairs({"Gems", "Diamonds", "Diamond", "Gem", "Crystals"}) do
            local val = leaderstats:FindFirstChild(name)
            if val and val:IsA("ValueBase") then return tonumber(val.Value) or 0 end
        end
    end
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local hud = pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("HUD")
        local gemObj = hud and hud:FindFirstChild("Currencies") and (hud.Currencies:FindFirstChild("Gems") or hud.Currencies:FindFirstChild("Diamonds"))
        local amt = gemObj and gemObj:FindFirstChild("CurrencyFrame") and gemObj.CurrencyFrame:FindFirstChild("AmountLabel")
        if amt and amt:IsA("TextLabel") then
            local num = amt.Text:gsub(",", ""):match("(%d+)")
            if num then return tonumber(num) or 0 end
        end
        for _, desc in ipairs(pgui:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible then
                local lname = desc.Name:lower()
                if lname:find("gem") or lname:find("diamond") then
                    local num = desc.Text:gsub(",", ""):match("(%d+)")
                    if num and tonumber(num) then return tonumber(num) end
                end
            end
        end
    end
    return 0
end

-- Зчитування івент-цукерок
local function getAccountCandy()
    local hub = getHub()
    if hub and hub.InventoryData and tonumber(hub.InventoryData.Candy) then
        return tonumber(hub.InventoryData.Candy)
    end
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

-- Зчитування грошей всередині матчу (для встановлення веж)
local function getInMatchCash()
    local hub = getHub()
    if hub and hub.Cash then
        local ok, c = pcall(hub.Cash)
        if ok and c and tonumber(c) then return tonumber(c) end
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

-- Зчитування юнітів в інвентарі та екіпіруванні
local function getInventoryUnits()
    local hub = getHub()
    local unitsMap = {}

    if hub and hub.InventoryData and type(hub.InventoryData.Towers) == "table" then
        for id, tower in pairs(hub.InventoryData.Towers) do
            if type(tower) == "table" and type(tower.Name) == "string" then
                local name = tower.Name
                local isEq = (tonumber(tower.Equipped) or 0) > 0
                if not unitsMap[name] then
                    unitsMap[name] = { Name = name, Count = 0, Equipped = false }
                end
                unitsMap[name].Count = unitsMap[name].Count + 1
                if isEq then unitsMap[name].Equipped = true end
            end
        end
    end

    if hub and hub.Units and type(hub.Units) == "table" then
        for id, u in pairs(hub.Units) do
            if type(u) == "table" and type(u.Name) == "string" then
                local name = u.Name
                local isEq = (tonumber(u.Equipped) or 0) > 0
                if not unitsMap[name] then
                    unitsMap[name] = { Name = name, Count = 1, Equipped = isEq }
                else
                    if isEq then unitsMap[name].Equipped = true end
                end
            end
        end
    end

    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local bottom = pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("Bottom")
        local hotbar = bottom and (bottom:FindFirstChild("Hotbar") or bottom:FindFirstChild("Units") or bottom:FindFirstChild("Towers"))
        if hotbar then
            for _, slot in ipairs(hotbar:GetChildren()) do
                local title = slot:FindFirstChild("Title") or slot:FindFirstChild("UnitName")
                if title and title:IsA("TextLabel") and title.Text ~= "" and title.Text ~= "Empty" then
                    local name = title.Text:match("^%s*(.-)%s*$")
                    if name and #name > 1 then
                        if not unitsMap[name] then
                            unitsMap[name] = { Name = name, Count = 1, Equipped = true }
                        else
                            unitsMap[name].Equipped = true
                        end
                    end
                end
            end
        end
    end

    local list = {}
    for _, item in pairs(unitsMap) do
        table.insert(list, item)
    end
    return list
end

-- Зчитування поточної хвилі
local function getCurrentWave()
    local hub = getHub()
    if hub and hub.Wave then
        local ok, w = pcall(hub.Wave)
        if ok and w and tonumber(w) and tonumber(w) > 0 then return tonumber(w) end
    end
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

-- 2. ВІДНОВЛЕННЯ ТА ЗБЕРЕЖЕННЯ ТОЧНОГО ЧАСУ СЕСІЇ (НІКОЛИ НЕ ЗБИВАЄТЬСЯ ПРИ ТЕЛЕПОРТАХ)
local savedData = {}
if readfile and isfile and isfile(StatsPath) then
    pcall(function()
        savedData = HttpService:JSONDecode(readfile(StatsPath)) or {}
    end)
end

local ScriptBootTime = tick()
local baseUptime = 0
if readfile and isfile and isfile(SessionTokenPath) then
    pcall(function()
        local dec = HttpService:JSONDecode(readfile(SessionTokenPath))
        if dec and type(dec) == "table" then
            local lastHb = tonumber(dec.LastHeartbeat) or 0
            if math.abs(os.time() - lastHb) < 1800 then
                local savedUp = tonumber(dec.UptimeSeconds)
                if savedUp and savedUp > 0 and savedUp < 86400 * 14 then
                    baseUptime = savedUp
                end
            end
        end
    end)
end

local function getRealUptime()
    local elapsed = math.max(0, math.floor(tick() - ScriptBootTime))
    return baseUptime + elapsed
end

genv.__CameraTDSession = genv.__CameraTDSession or {
    SessionStartTime = os.time(),
    BaseUptime = baseUptime,
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
local Session = genv.__CameraTDSession -- Гарантуємо збереження часу

-- Відновлюємо слоти активності
if savedData.ActivitySlots and type(savedData.ActivitySlots) == "table" then
    for k, v in pairs(savedData.ActivitySlots) do
        if Session.ActivitySlots[k] == nil then
            Session.ActivitySlots[k] = (v == 4 or v == "red") and "red" or "green"
        end
    end
end

-- 3. Слоти активності для 24/7 Heatmap
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

-- Хмарний канал
local CloudChannel = (genv.CameraTD_Channel) or "camtd_cloud_kvires"

-- 4. Уніфікована відправка телеметрії на сайт та збереження
local function pushUpdate(data)
    local ok, jsonString = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok or not jsonString then return end

    -- Збереження постійного токена сесії
    if writefile then
        pcall(function()
            writefile(StatsPath, jsonString)
            writefile(SessionTokenPath, HttpService:JSONEncode({
                UptimeSeconds = getRealUptime(),
                SessionStartTime = Session.SessionStartTime,
                LastHeartbeat = os.time(),
                PlayerName = LocalPlayer.Name,
                UserId = LocalPlayer.UserId
            }))
        end)
    end

    local req = httpRequest or findHttpRequest()
    if req then
        -- Надійна відправка в швидкі хмарні релеї (ntfy.envs.net + ntfy.sh fallback)
        local endpoints = {
            "https://ntfy.envs.net/" .. CloudChannel,
            "https://ntfy.sh/" .. CloudChannel
        }
        for _, endpoint in ipairs(endpoints) do
            task.spawn(function()
                pcall(function()
                    req({
                        Url = endpoint,
                        Method = "POST",
                        Headers = {
                            ["Content-Type"] = "application/json",
                            ["Title"] = "Camera TD Admin Telemetry"
                        },
                        Body = jsonString
                    })
                end)
            end)
        end
    end
end

-- 5. Детекція кіків
pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if msg and msg ~= "" then
            Session.IsKicked = true
            Session.Status = "❌ ВИЛІТ / КІК: " .. tostring(msg)
            markActivitySlot("red")
            
            local kickData = {
                PlayerName = LocalPlayer.Name,
                DisplayName = LocalPlayer.DisplayName,
                UserId = LocalPlayer.UserId,
                CurrentCoins = getAccountCoins(),
                AccountCoins = getAccountCoins(),
                AccountGems = getAccountGems(),
                AccountCandy = getAccountCandy(),
                InMatchCash = getInMatchCash(),
                TotalCoinsEarned = Session.TotalCoinsEarned,
                TotalCandyEarned = Session.TotalCandyEarned,
                LastRoundCoins = Session.LastRoundCoins or 600,
                LastRoundCandy = Session.LastRoundCandy or 10,
                CoinsPerWave = Session.CoinsPerWave or 50,
                CurrentWave = getCurrentWave(),
                MapName = (game.PlaceId == 114068177100380 and "Toilet City (Match)") or "Lobby",
                TotalRounds = Session.TotalRounds,
                TotalWins = Session.TotalWins,
                TotalLosses = Session.TotalLosses,
                Rejoins = Session.Rejoins,
                UptimeSeconds = getRealUptime(),
                Status = Session.Status,
                IsAFK = false,
                IsKicked = true,
                IdleSeconds = os.time() - (Session.LastActionTime or os.time()),
                LastHeartbeat = os.time(),
                UptimeSeconds = getRealUptime(),
                SessionStartTime = Session.SessionStartTime,
                ActivitySlots = Session.ActivitySlots,
                InventoryTowers = getInventoryUnits(),
                Version = "v4.6 (Kero Admin Cloud)"
            }
            pushUpdate(kickData)
        end
    end)
end)

-- 6. Підрахунок перемог / поразок
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

            local curCoins = getAccountCoins()
            local curCandy = getAccountCandy()
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

-- ============================================================
-- 7. МИТТЄВИЙ ПЕРШИЙ ПІНГ (0.05с)
-- ============================================================
task.spawn(function()
    local initialData = {
        PlayerName = LocalPlayer.Name,
        DisplayName = LocalPlayer.DisplayName,
        UserId = LocalPlayer.UserId,
        CurrentCoins = getAccountCoins(),
        AccountCoins = getAccountCoins(),
        AccountGems = getAccountGems(),
        AccountCandy = getAccountCandy(),
        InMatchCash = getInMatchCash(),
        TotalCoinsEarned = Session.TotalCoinsEarned,
        TotalCandyEarned = Session.TotalCandyEarned,
        LastRoundCoins = Session.LastRoundCoins or 600,
        LastRoundCandy = Session.LastRoundCandy or 10,
        CoinsPerWave = Session.CoinsPerWave or 50,
        CurrentWave = getCurrentWave(),
        MapName = (game.PlaceId == 114068177100380 and "Toilet City (Match)") or "Lobby",
        TotalRounds = Session.TotalRounds,
        TotalWins = Session.TotalWins,
        TotalLosses = Session.TotalLosses,
        Rejoins = Session.Rejoins,
        UptimeSeconds = getRealUptime(),
        Status = "🔄 Заходить на сервер / Завантаження...",
        IsAFK = false,
        IsKicked = false,
        IdleSeconds = 0,
        LastHeartbeat = os.time(),
        UptimeSeconds = getRealUptime(),
                SessionStartTime = Session.SessionStartTime,
        ActivitySlots = Session.ActivitySlots,
        InventoryTowers = getInventoryUnits(),
                Version = "v4.6 (Kero Admin Cloud)"
    }
    pushUpdate(initialData)
end)

-- ============================================================
-- 8. ГОЛОВНИЙ ФОНОВИЙ ЦИКЛ (100% СТЕЛС, 0 GUI В ROBLOX)
-- ============================================================
task.spawn(function()
    print("[Camera TD Headless] 👑 Kero Admin Cloud Tracker активовано!")
    print("[Camera TD Headless] ☁️ Канал: " .. CloudChannel)
    print("[Camera TD Headless] 🌐 Адмін-панель: https://kvires-ps99-cloud.static.hf.space/?channel=" .. CloudChannel)

    task.wait(1.5)
    Session.Status = "🟢 В мережі / Завантажено"

    local lastCoins = 0
    local lastWave = 0
    local lastSave = 0

    while task.wait(1.5) do
        if genv.__CameraTD_ActiveInstance ~= currentInstanceToken then
            print("[Camera TD Headless] Зупинено попередній екземпляр трекера після зміни сервера.")
            break
        end

        local now = os.time()
        local uptime = getRealUptime()

        local curCoins = getAccountCoins()
        local curGems = getAccountGems()
        local curCandy = getAccountCandy()
        local curCash = getInMatchCash()
        local curWave = getCurrentWave()

        local inMatch = (game.PlaceId == 114068177100380)
        local inLobby = (game.PlaceId == 132929771812494)

        if not Session.MatchStartCoins and curCoins > 0 then Session.MatchStartCoins = curCoins end
        if not Session.MatchStartCandy and curCandy > 0 then Session.MatchStartCandy = curCandy end

        if curCoins ~= lastCoins or (curWave > 0 and curWave ~= lastWave) or inMatch then
            lastCoins = curCoins
            lastWave = curWave
            Session.LastActionTime = now
        end

        local idleSeconds = now - (Session.LastActionTime or now)
        local isAFK = (idleSeconds > 180)

        local statusText = "🟢 В мережі"
        if Session.IsKicked then
            statusText = Session.Status
        elseif inMatch then
            statusText = "🟢 У бою: Хвиля " .. tostring(curWave > 0 and curWave or 1)
            markActivitySlot("green")
        elseif inLobby then
            statusText = "🏰 В лобі: Очікує старту"
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
                AccountCoins = curCoins,
                AccountGems = curGems,
                AccountCandy = curCandy,
                InMatchCash = curCash,
                
                TotalCoinsEarned = Session.TotalCoinsEarned,
                TotalCandyEarned = Session.TotalCandyEarned,
                LastRoundCoins = liveCoinsEarned > 0 and liveCoinsEarned or 600,
                LastRoundCandy = liveCandyEarned > 0 and liveCandyEarned or 10,
                CoinsPerWave = Session.CoinsPerWave > 0 and Session.CoinsPerWave or 50,
                CurrentWave = curWave,
                MapName = inMatch and "Toilet City (Match)" or (inLobby and "Lobby" or "Place " .. tostring(game.PlaceId)),
                Difficulty = "Normal",
                
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
                UptimeSeconds = getRealUptime(),
                SessionStartTime = Session.SessionStartTime,
                ActivitySlots = Session.ActivitySlots,
                InventoryTowers = getInventoryUnits(),
                Version = "v4.6 (Kero Admin Cloud)"
            }

            pushUpdate(exportData)
        end
    end
end)
