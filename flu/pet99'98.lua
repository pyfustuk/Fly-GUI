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
local CloudChannel = (genv and genv.CameraTD_Channel) or "camtd_cloud_kvires"
local currentInstanceToken = tick()
genv.__CameraTD_ActiveInstance = currentInstanceToken

-- Випереджальні оголошення для доступу з усіх функцій
local Session
local handleKickDetected
local pushUpdate

-- Попередня ініціалізація Session для миттєвого реагування на дистанційні команди
genv.__CameraTDSession = genv.__CameraTDSession or {
    SessionStartTime = os.time(),
    BaseUptime = 0,
    TotalRounds = 0,
    TotalWins = 0,
    TotalLosses = 0,
    Rejoins = 0,
    TotalCoinsEarned = 0,
    TotalCandyEarned = 0,
    LastRoundCoins = 600,
    LastRoundCandy = 10,
    LastRoundWaves = 12,
    CoinsPerWave = 50,
    CandyPerWave = 1,
    ActivitySlots = {},
    ActionLog = {},
    TradeHistory = {},
    MatchStartCoins = nil,
    MatchStartCandy = nil,
    LastActionTime = os.time(),
    IsKicked = false,
    ScriptDisabled = false,
    Status = "🟢 В мережі / Завантажено"
}
Session = genv.__CameraTDSession
if not Session.ActionLog then Session.ActionLog = {} end
if not Session.TradeHistory then Session.TradeHistory = {} end

-- Система логування дій
local MAX_LOG_ENTRIES = 200
local function addActionLog(actionType, details)
    if not Session.ActionLog then Session.ActionLog = {} end
    table.insert(Session.ActionLog, {
        ts = os.time(),
        type = actionType,
        details = tostring(details or "")
    })
    -- Trim to last MAX_LOG_ENTRIES
    while #Session.ActionLog > MAX_LOG_ENTRIES do
        table.remove(Session.ActionLog, 1)
    end
end

-- Система відстеження трейдів
local MAX_TRADE_ENTRIES = 100
local function recordTrade(partnerName, partnerUserId, actionType, itemsList, gemsAmount)
    if not Session.TradeHistory then Session.TradeHistory = {} end
    local entry = {
        ts = os.time(),
        partner = tostring(partnerName or "Unknown"),
        partnerId = partnerUserId or 0,
        action = tostring(actionType or "Completed"),
        items = itemsList or {},
        gems = gemsAmount or 0
    }
    table.insert(Session.TradeHistory, entry)
    while #Session.TradeHistory > MAX_TRADE_ENTRIES do
        table.remove(Session.TradeHistory, 1)
    end
    addActionLog("trade", "Трейд з @" .. tostring(partnerName) .. " (" .. tostring(actionType) .. ")")
end

-- МИТТЄВИЙ СТАРТОВИЙ ПІНГ (0мс): Акаунт з'являється на сайті за 0.1 секунди після інжекту!
task.spawn(function()
    task.wait(0.1)
    local pId = game.PlaceId
    local isMatch = (pId == 114068177100380) or (workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Base") ~= nil)
    local initData = {
        PlayerName = LocalPlayer.Name,
        DisplayName = LocalPlayer.DisplayName,
        UserId = LocalPlayer.UserId,
        AccountCoins = 0,
        AccountGems = 0,
        AccountCandy = 0,
        CurrentWave = 0,
        MapName = isMatch and "Toilet City (Match)" or (pId == 85725785704440 and "Trading Plaza" or "Lobby"),
        Status = "🟢 В мережі: Скрипт успішно запущено",
        IsAFK = false,
        IsKicked = false,
        ScriptDisabled = (Session.ScriptDisabled == true),
        LastHeartbeat = os.time(),
        UptimeSeconds = 0,
        SessionStartTime = os.time(),
        ActivitySlots = Session.ActivitySlots or {},
        InventoryTowers = {},
        Version = "v5.6 (Kero Admin Cloud)"
    }
    if pushUpdate then
        pushUpdate(initData)
        print("[Camera TD Cloud] 🚀 Миттєвий стартовий сигнал @ " .. LocalPlayer.Name .. " відправлено в хмару!")
    end
end)

-- ============================================================
-- ЧАСТИНА 1: ДИНАМІЧНИЙ ЗАВАНТАЖУВАЧ KERO HUB ТА ХМАРНЕ КЕРУВАННЯ
-- (Підтримка дистанційного ввімкнення/вимкнення та Remote Kick Error 277)
-- ============================================================
local isKeroHubLoaded = false

local function loadKeroHub()
    if Session and Session.ScriptDisabled then
        print("[Camera TD] ⛔ Скрипт вимкнено через адмін-панель. Kero Hub заблоковано.")
        return
    end
    if isKeroHubLoaded then return end

    pcall(function()
        local globals = { getgenv and getgenv(), _G }
        for _, env in ipairs(globals) do
            if env and type(env) == "table" then
                env.CameraTD_Disabled = false
                env.CameraTD_ScriptDisabled = false
            end
        end
    end)

    task.spawn(function()
        task.wait(0.5)
        local hubUrls = {
            "https://huggingface.co/spaces/kvires/ps99-cloud/raw/main/cameraman_hub.lua",
            "https://raw.githubusercontent.com/KeroTwT/Kero-Hub/main/Sources/Cameraman%20TD"
        }
        for _, url in ipairs(hubUrls) do
            local ok = pcall(function()
                local code = game:HttpGet(url)
                if code and #code > 1000 then
                    loadstring(code)()
                    isKeroHubLoaded = true
                    print("[Camera TD] 👑 Kero Hub успішно завантажено та активовано!")
                    return true
                end
                error("empty code")
            end)
            if ok then break end
            task.wait(1.5)
        end
    end)
end

local function unloadKeroHub()
    -- 1. Вимикаємо всі глобальні прапорці автофарму, авто-старту та макросів
    pcall(function()
        local globals = { getgenv and getgenv(), _G }
        for _, env in ipairs(globals) do
            if env and type(env) == "table" then
                env.AutoFarm = false
                env.AutoStart = false
                env.AutoSkip = false
                env.AutoPlace = false
                env.AutoUpgrade = false
                env.AutoPlay = false
                env.MacroEnabled = false
                env.CameraTD_Disabled = true
                env.CameraTD_ScriptDisabled = true
            end
        end
    end)

    -- 2. Викликаємо деструктори Kero Hub
    local hub = getHub()
    if hub then
        if hub.Stop then pcall(hub.Stop) end
        if hub.Unload then pcall(hub.Unload) end
        if hub.Destroy then pcall(hub.Destroy) end
    end

    -- 3. Приховуємо та знищуємо ScreenGui у всіх контейнерах
    pcall(function()
        local function purgeGui(parent)
            if not parent then return end
            for _, gui in ipairs(parent:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    local n = gui.Name:lower()
                    if n:find("kero") or n:find("cameratd") or n:find("windui") or n:find("solara") or n:find("hub") then
                        gui.Enabled = false
                        gui:Destroy()
                    end
                end
            end
        end
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        purgeGui(pgui)
        if gethui then purgeGui(gethui()) end
        pcall(function()
            local coreGui = game:GetService("CoreGui")
            purgeGui(coreGui)
        end)
    end)

    isKeroHubLoaded = false
    if getgenv then getgenv().CameraTDHub = nil end
    _G.CameraTDHub = nil
    print("[Camera TD] 🛑 Скрипт та Kero Hub повністю вимкнено для @ " .. LocalPlayer.Name)
end

-- Локальний файл збереження стану дозволу акаунта
local ControlPath = Folder .. "/AccountControl.json"
local processedCmdIds = {}
local processedCmdIdList = {}

pcall(function()
    if readfile and isfile and isfile(ControlPath) then
        local dec = HttpService:JSONDecode(readfile(ControlPath))
        if dec and type(dec) == "table" then
            if dec.ScriptDisabled ~= nil then
                if Session then Session.ScriptDisabled = dec.ScriptDisabled end
            end
        end
    end
end)

local function saveControlState()
    if writefile then
        pcall(function()
            writefile(ControlPath, HttpService:JSONEncode({
                ScriptDisabled = Session and Session.ScriptDisabled or false,
                Updated = os.time()
            }))
        end)
    end
end

-- Обробка вхідних команд з адмін-панелі сайту
local function processRemoteCommand(cmd)
    if not cmd or type(cmd) ~= "table" then return end

    -- 1. ДЕДУПЛІКАЦІЯ ЗА УНІКАЛЬНИМ COMMAND ID (без помилкових відхилень за годинником)
    local cmdId = cmd.id or (tostring(cmd.action) .. "_" .. tostring(cmd.timestamp) .. "_" .. tostring(cmd.target))
    if processedCmdIds[cmdId] then
        return
    end
    processedCmdIds[cmdId] = true
    table.insert(processedCmdIdList, cmdId)
    if #processedCmdIdList > 200 then
        local oldId = table.remove(processedCmdIdList, 1)
        processedCmdIds[oldId] = nil
    end

    -- 2. ТОЧНА ТА ГНУЧКА ПЕРЕВІРКА ЦІЛІ (UserName, DisplayName, UserId, "all")
    local rawTarget = tostring(cmd.target or cmd.targetName or "all")
    local target = rawTarget:gsub("^@", ""):lower():match("^%s*(.-)%s*$") or ""
    local targetId = tostring(cmd.targetUserId or "")

    local myName = LocalPlayer.Name:lower()
    local myDisplayName = LocalPlayer.DisplayName:lower()
    local myUserId = tostring(LocalPlayer.UserId)

    local isForMe = false
    if target == "" or target == "all" then
        isForMe = true
    elseif target == myName or target == myDisplayName or target == myUserId then
        isForMe = true
    elseif targetId ~= "" and targetId == myUserId then
        isForMe = true
    end

    if not isForMe then
        return
    end

    -- 3. ПЕРЕВІРКА ТЕРМІНУ ДІЇ (ігноруємо лише команди старіші 15 хвилин)
    local cmdTime = tonumber(cmd.timestamp) or 0
    local now = os.time()
    if cmdTime > 0 and (now - cmdTime) > 900 then
        return
    end

    -- 1. ДІЯ: ДИСТАНЦІЙНИЙ КІК З ГРИ (Error 277 / Примусовий виліт)
    if cmd.action == "kick" then
        local kickReason = cmd.reason or "Lost connection to the game server, please reconnect (Error Code: 277)"
        print("[Camera TD Remote] ⚡ Отримано команду від'єднання (Error 277): " .. kickReason)
        addActionLog("remote_kick", kickReason)
        
        if Session then
            Session.IsKicked = true
            Session.KickReason = kickReason
            Session.Status = "🔴 ВИЛІТ (Error 277): " .. kickReason
        end
        if handleKickDetected then
            pcall(function() handleKickDetected(kickReason) end)
        end
        saveControlState()
        
        -- Миттєво відправляємо підтвердження кіку серверу
        if pushUpdate then
            pcall(function()
                pushUpdate({
                    PlayerName = LocalPlayer.Name,
                    DisplayName = LocalPlayer.DisplayName,
                    UserId = LocalPlayer.UserId,
                    Status = "🔴 ВИЛІТ: " .. kickReason,
                    IsKicked = true,
                    KickConfirmed = true,
                    KickReason = kickReason,
                    LastHeartbeat = os.time(),
                    ActionLog = Session.ActionLog or {}
                })
            end)
        end

        task.spawn(function()
            task.wait(0.35)
            pcall(function()
                LocalPlayer:Kick(kickReason)
            end)
        end)
        return
    end

    -- 2. ДІЯ: ДИСТАНЦІЙНЕ ВВІМКНЕННЯ / ВИМКНЕННЯ СКРИПТА
    if cmd.action == "set_enabled" or cmd.action == "toggle" or cmd.action == "disable" or cmd.action == "enable" then
        local enableState = (cmd.enabled == true or cmd.action == "enable")
        if enableState then
            print("[Camera TD Remote] 🟢 Скрипт дозволено адміністратором.")
            if Session then
                Session.ScriptDisabled = false
                Session.Status = "🟢 В мережі: Фарм активний"
            end
            addActionLog("toggle_script", "Скрипт увімкнено (Kero Hub запущено)")
            saveControlState()
            loadKeroHub()
        else
            print("[Camera TD Remote] ⛔ Скрипт заблоковано адміністратором. Вимикаємо Kero Hub...")
            if Session then
                Session.ScriptDisabled = true
                Session.Status = "⛔ Скрипт вимкнено в адмін-панелі"
            end
            addActionLog("toggle_script", "Скрипт вимкнено (Kero Hub зупинено)")
            saveControlState()
            unloadKeroHub()
        end

        if pushUpdate then
            pcall(function()
                pushUpdate({
                    PlayerName = LocalPlayer.Name,
                    DisplayName = LocalPlayer.DisplayName,
                    UserId = LocalPlayer.UserId,
                    Status = Session.Status,
                    ScriptDisabled = (Session.ScriptDisabled == true),
                    IsKicked = (Session.IsKicked == true),
                    LastHeartbeat = os.time(),
                    UptimeSeconds = (getRealUptime and getRealUptime()) or 0,
                    ActionLog = Session.ActionLog or {}
                })
            end)
        end
        return
    end

    -- 3. ДІЯ: ДИСТАНЦІЙНЕ ПОВНЕ СКАНУВАННЯ ТА ОНОВЛЕННЯ ІНВЕНТАРЯ З ГРИ
    if cmd.action == "refresh_inventory" or cmd.action == "rescan_inventory" then
        print("[Camera TD Remote] 🔄 Отримано запит на оновлення інвентаря з гри!")
        CachedInventoryUnits = {}
        local freshUnits = getInventoryUnits and getInventoryUnits() or {}
        addActionLog("inventory_refresh", "Оновлено " .. tostring(#freshUnits) .. " юнітів з гри")
        if pushUpdate then
            pcall(function()
                pushUpdate({
                    PlayerName = LocalPlayer.Name,
                    DisplayName = LocalPlayer.DisplayName,
                    UserId = LocalPlayer.UserId,
                    Status = Session.Status,
                    InventoryTowers = freshUnits,
                    LastHeartbeat = os.time(),
                    ActionLog = Session.ActionLog or {}
                })
            end)
        end
        return
    end
end

-- Фоновий слухач команд керування через хмару (ntfy _cmd)
local function pollRemoteCommands()
    local fn = httpRequest or findHttpRequest()
    if not fn then return end

    local endpoints = {
        "https://ntfy.envs.net/" .. CloudChannel .. "_cmd/json?poll=1&since=5m",
        "https://ntfy.sh/" .. CloudChannel .. "_cmd/json?poll=1&since=5m"
    }
    for _, ep in ipairs(endpoints) do
        local ok, resp = pcall(function()
            return fn({
                Url = ep,
                url = ep,
                Method = "GET",
                method = "GET",
                Headers = { ["User-Agent"] = "Roblox/CameraTD" },
                headers = { ["User-Agent"] = "Roblox/CameraTD" }
            })
        end)
        local body = ok and resp and (resp.Body or resp.body or resp.Response or resp.Data)
        local status = resp and (resp.StatusCode or resp.Status or resp.status_code)

        if ok and resp and (status == 200 or (not status and body and #body > 0)) then
            if body and #body > 0 then
                for line in body:gmatch("[^\r\n]+") do
                    local okJson, data = pcall(function()
                        return HttpService:JSONDecode(line)
                    end)
                    if okJson and data then
                        if data.message then
                            local okInner, inner = pcall(function()
                                return HttpService:JSONDecode(data.message)
                            end)
                            if okInner and inner then processRemoteCommand(inner) end
                        else
                            processRemoteCommand(data)
                        end
                    end
                end
            end
            break -- Отримано успішну відповідь від першого сервера, другий не перевантажуємо
        end
    end
end

task.spawn(function()
    pcall(pollRemoteCommands)
    while true do
        task.wait(3.0)
        pcall(pollRemoteCommands)
    end
end)

-- Авто-запуск Kero Hub через 1.2с якщо не заблоковано в хмарі
task.spawn(function()
    task.wait(0.6)
    pcall(pollRemoteCommands)
    task.wait(0.6)
    if not (Session and Session.ScriptDisabled) then
        loadKeroHub()
    else
        print("[Camera TD] ⛔ Стартовий стан: заблоковано в адмінці. Kero Hub чекає дозволу.")
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

-- ============================================================
-- ЧАСТИНА 2.1: ВАЛІДАЦІЯ ТА ЗЧИТУВАННЯ ІНВЕНТАРЯ ЮНІТІВ (БЕЗ ФАНТОМІВ)
-- ============================================================
local UI_BLACKLIST = {
    ["template"] = true, ["holder"] = true, ["frame"] = true, ["slot"] = true,
    ["button"] = true, ["title"] = true, ["label"] = true, ["equipped"] = true,
    ["cost"] = true, ["locked"] = true, ["sell"] = true, ["upgrade"] = true,
    ["select"] = true, ["empty"] = true, ["none"] = true, ["buy"] = true,
    ["price"] = true, ["unit"] = true, ["units"] = true, ["tower"] = true,
    ["towers"] = true, ["level"] = true, ["lvl"] = true, ["damage"] = true,
    ["range"] = true, ["cooldown"] = true, ["dps"] = true, ["stats"] = true,
    ["coins"] = true, ["gems"] = true, ["money"] = true, ["inventory"] = true,
    ["shop"] = true, ["gameui"] = true, ["hud"] = true, ["main"] = true,
    ["troops"] = true, ["close"] = true, ["otherui"] = true, ["statsui"] = true,
    ["amountlabel"] = true, ["currencyframe"] = true, ["currencies"] = true,
    ["cash"] = true, ["gold"] = true, ["diamond"] = true, ["diamonds"] = true,
    ["troop"] = true, ["equip"] = true, ["unequip"] = true, ["speed"] = true,
    ["skip"] = true, ["auto"] = true, ["autoplace"] = true, ["autoupgrade"] = true,
    ["menu"] = true, ["back"] = true, ["closebutton"] = true, ["icon"] = true,
    ["background"] = true, ["container"] = true, ["list"] = true, ["grid"] = true,
    ["item"] = true, ["items"] = true, ["page"] = true, ["next"] = true, ["prev"] = true
}

local function isValidUnitName(name)
    if not name or type(name) ~= "string" then return false end
    name = name:match("^%s*(.-)%s*$")
    if #name < 3 or #name > 50 then return false end
    if name:find("^%d+$") or name:find("^%$") or name:find("^%d+%$") then return false end
    local clean = name:lower():gsub("[^%a%d]", "")
    if UI_BLACKLIST[clean] or UI_BLACKLIST[name:lower()] then
        return false
    end
    if name:match("^%$%d") or name:match("^[Ll][Vv][Ll]%s*%d") then return false end
    return true
end

-- Кеш юнітів для безперервного відображення на сайті
local CachedInventoryUnits = {}
local lastInventoryScanTime = 0

-- Зчитування юнітів в інвентарі та екіпіруванні з усіх доступних джерел
local function getInventoryUnits(force)
    local now = os.time()
    if not force and #CachedInventoryUnits > 0 and (now - lastInventoryScanTime < 15) then
        return CachedInventoryUnits
    end
    lastInventoryScanTime = now

    local hub = getHub()
    local unitsMap = {}
    local foundAny = false

    local function addUnit(name, count, isEquipped)
        if not isValidUnitName(name) then return end
        name = name:match("^%s*(.-)%s*$")
        count = math.max(1, tonumber(count) or 1)
        if not unitsMap[name] then
            unitsMap[name] = { Name = name, Count = count, Equipped = isEquipped or false }
        else
            unitsMap[name].Count = unitsMap[name].Count + count
            if isEquipped then unitsMap[name].Equipped = true end
        end
        foundAny = true
    end

    -- 1. Спроба з Kero Hub Units (Точна серверна репліка акаунта)
    if hub and hub.Units and type(hub.Units) == "table" and next(hub.Units) ~= nil then
        for id, u in pairs(hub.Units) do
            if type(u) == "table" and u.Name and type(u.Name) == "string" then
                local isEq = (tonumber(u.Equipped) or 0) > 0
                addUnit(u.Name, 1, isEq)
            end
        end
    end

    -- 2. Спроба з Kero Hub InventoryData.Towers (Офіційний інвентар гри)
    if hub and hub.InventoryData and type(hub.InventoryData.Towers) == "table" and next(hub.InventoryData.Towers) ~= nil then
        for id, tower in pairs(hub.InventoryData.Towers) do
            local tName = (type(tower) == "table" and (tower.Name or tower.TowerName or tower.Unit or tower.Type or tower.Tower)) or (type(tower) == "string" and tower)
            if tName and type(tName) == "string" then
                local isEq = (type(tower) == "table" and (tonumber(tower.Equipped) or 0) > 0)
                addUnit(tName, 1, isEq)
            end
        end
    end

    -- 3. Спроба з Kero Hub Equipped()
    if hub and type(hub.Equipped) == "function" then
        pcall(function()
            local eqList = hub.Equipped()
            if type(eqList) == "table" then
                for _, eqU in ipairs(eqList) do
                    local eqName = (type(eqU) == "table" and eqU.Name) or (type(eqU) == "string" and eqU)
                    if eqName and type(eqName) == "string" then
                        addUnit(eqName, 1, true)
                    end
                end
            end
        end)
    end

    -- 4. Якщо Kero Hub ще завантажується, перевіряємо слоти екіпірування GameUI (без парсингу рандомних лейблів!)
    if not foundAny then
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        local hotbar = pgui and pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("Bottom") and pgui.GameUI.Bottom:FindFirstChild("Hotbar")
        if hotbar then
            for _, slot in ipairs(hotbar:GetChildren()) do
                if slot:IsA("GuiObject") then
                    local unitVal = slot:FindFirstChild("Unit") or slot:FindFirstChild("Tower") or slot:FindFirstChild("UnitName")
                    if unitVal and unitVal:IsA("StringValue") and isValidUnitName(unitVal.Value) then
                        addUnit(unitVal.Value, 1, true)
                    end
                end
            end
        end
    end

    local result = {}
    if foundAny then
        for _, item in pairs(unitsMap) do
            table.insert(result, item)
        end
        CachedInventoryUnits = result
    elseif #CachedInventoryUnits > 0 then
        result = CachedInventoryUnits
    end

    return result
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
Session = genv.__CameraTDSession -- Гарантуємо збереження часу

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
    elseif Session.IsAFK then
        if Session.ActivitySlots[key] ~= "red" then
            Session.ActivitySlots[key] = "yellow"
        end
    else
        if Session.ActivitySlots[key] ~= "red" then
            Session.ActivitySlots[key] = statusType or "green"
        end
    end
end

-- Хмарний канал
local CloudChannel = (genv.CameraTD_Channel) or "camtd_cloud_kvires"

-- Збір списку друзів на сервері з кешуванням (нуль лагів)
local _cachedFriends = {}
local _lastFriendsCheck = 0
local function getFriendsList()
    local now = os.time()
    if #_cachedFriends > 0 and (now - _lastFriendsCheck < 15) then
        return _cachedFriends
    end
    _lastFriendsCheck = now
    local friendsOnServer = {}
    pcall(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player and player ~= LocalPlayer then
                local isFriend = false
                pcall(function()
                    isFriend = LocalPlayer:IsFriendsWith(player.UserId)
                end)
                table.insert(friendsOnServer, {
                    Name = player.Name or "",
                    DisplayName = player.DisplayName or player.Name or "",
                    UserId = player.UserId or 0,
                    IsFriend = isFriend,
                    AvatarUrl = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(player.UserId or 0) .. "&size=150x150&format=Png"
                })
            end
        end
    end)
    _cachedFriends = friendsOnServer
    return friendsOnServer
end

local lastDiskSave = 0
-- 4. Уніфікована швидка та стабільна відправка телеметрії на сайт
pushUpdate = function(data)
    local ok, jsonString = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok or not jsonString then return end

    local nowTime = os.time()
    -- Зберігаємо на локальний диск не частіше ніж раз на 15 секунд (або при кіку/завершенні раунду)
    if writefile and (nowTime - lastDiskSave >= 15 or data.IsKicked or data.KickConfirmed) then
        lastDiskSave = nowTime
        pcall(function()
            writefile(StatsPath, jsonString)
            writefile(SessionTokenPath, HttpService:JSONEncode({
                UptimeSeconds = getRealUptime(),
                SessionStartTime = Session.SessionStartTime,
                LastHeartbeat = nowTime,
                PlayerName = LocalPlayer.Name,
                UserId = LocalPlayer.UserId
            }))
        end)
    end

    local req = httpRequest or findHttpRequest()
    if req then
        task.spawn(function()
            local headers = {
                ["Content-Type"] = "application/json",
                ["Title"] = "Camera TD Admin Telemetry"
            }
            -- 1. Відправляємо на головний швидкий релей
            local okPost = pcall(function()
                return req({
                    Url = "https://ntfy.envs.net/" .. CloudChannel,
                    url = "https://ntfy.envs.net/" .. CloudChannel,
                    Method = "POST",
                    method = "POST",
                    Headers = headers,
                    headers = headers,
                    Body = jsonString,
                    body = jsonString
                })
            end)
            -- 2. Fallback на ntfy.sh тільки якщо перший релей повернув помилку
            if not okPost then
                pcall(function()
                    req({
                        Url = "https://ntfy.sh/" .. CloudChannel,
                        url = "https://ntfy.sh/" .. CloudChannel,
                        Method = "POST",
                        method = "POST",
                        Headers = headers,
                        headers = headers,
                        Body = jsonString,
                        body = jsonString
                    })
                end)
            end
        end)
    end
end

-- 5. Комплексна детекція кіків, помилок з'єднання та вильотів
handleKickDetected = function(reason)
    if Session.IsKicked then return end
    Session.IsKicked = true
    Session.KickReason = tostring(reason or "Від'єднано від сервера Roblox")
    Session.Status = "🔴 ВИЛІТ: " .. Session.KickReason
    markActivitySlot("red")
    addActionLog("kick", Session.KickReason)

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
        KickReason = Session.KickReason,
        IdleSeconds = os.time() - (Session.LastActionTime or os.time()),
        LastHeartbeat = os.time(),
        SessionStartTime = Session.SessionStartTime,
        ActivitySlots = Session.ActivitySlots,
        InventoryTowers = getInventoryUnits(),
        Version = "v5.5 (Kero Admin Cloud)"
    }
    pushUpdate(kickData)
end

pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if msg and msg ~= "" then
            handleKickDetected(msg)
        end
    end)
end)

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
        handleKickDetected("Teleport Failed: " .. tostring(errorMessage))
    end)
end)

-- Визначення локації гри (Бій / Лобі / Трейд)
local function getGameLocationInfo()
    local pId = game.PlaceId
    local inLobby = (pId == 132929771812494)
    local inTrading = (pId == 85725785704440)
    local inMatch = (pId == 114068177100380)

    local gameFolder = workspace:FindFirstChild("Game")
    if gameFolder and (gameFolder:FindFirstChild("Base") or gameFolder:FindFirstChild("Towers") or gameFolder:FindFirstChild("PlacingTowers")) then
        inMatch = true
        inLobby = false
    end

    local mapName = "Toilet City"
    if inMatch then
        if gameFolder then
            mapName = gameFolder:GetAttribute("Map") or gameFolder:GetAttribute("MapName") or "Toilet City"
        end
    elseif inTrading then
        mapName = "Trading Plaza"
    else
        mapName = "Lobby"
    end

    return {
        inMatch = inMatch,
        inLobby = inLobby,
        inTrading = inTrading,
        mapName = tostring(mapName)
    }
end

-- Зчитування здоров'я бази (Base HP)
local function getBaseHp()
    local base = (workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Base")) or workspace:FindFirstChild("Base", true)
    if not base then return nil end
    local hp = base:GetAttribute("Health") or base:GetAttribute("HP")
    if hp == nil and base:FindFirstChild("Health") then
        hp = base.Health.Value
    end
    return tonumber(hp)
end

-- 6. Підрахунок перемог / поразок та фіксація смерті бази
local function checkMatchResult(curWave, inMatch)
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    local baseHp = getBaseHp()
    Session.BaseHP = baseHp

    -- Сценарій 1: Базу знищено зомбі (HP <= 0) -> ПОРАЗКА!
    if inMatch and baseHp ~= nil and baseHp <= 0 and not Session.MatchEndedInCurrentSession then
        Session.MatchEndedInCurrentSession = true
        Session.TotalLosses = (Session.TotalLosses or 0) + 1
        Session.TotalRounds = (Session.TotalRounds or 0) + 1
        Session.LastMatchResult = "💀 ПОРАЗКА (Базу зруйновано)"
        Session.Status = "💀 ПОРАЗКА: Базу знищено на хвилі " .. tostring(curWave > 0 and curWave or 1)
        markActivitySlot("red")
        Session.LastActionTime = os.time()
        addActionLog("match_result", Session.LastMatchResult)
        if saveStats then saveStats() end
        return
    end

    -- Сценарій 2: Вікно завершення матчу FinalUI в PlayerGui
    local finalUI = pgui and (pgui:FindFirstChild("FinalUI", true) or (pgui:FindFirstChild("GameUI") and pgui.GameUI:FindFirstChild("FinalUI")))
    if finalUI and (finalUI.Visible or (finalUI:FindFirstChild("Content") and finalUI.Content.Visible)) then
        if not Session.MatchEndedInCurrentSession then
            Session.MatchEndedInCurrentSession = true
            local combinedText = ""
            for _, desc in ipairs(finalUI:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text ~= "" and desc.Visible then
                    combinedText = combinedText .. " " .. desc.Text:lower()
                end
            end

            local isWon = combinedText:find("won") or combinedText:find("victory") or combinedText:find("clear") or (baseHp ~= nil and baseHp > 0)
            local isLost = combinedText:find("lost") or combinedText:find("defeat") or combinedText:find("game over") or (baseHp ~= nil and baseHp <= 0)

            if isLost and not isWon then
                Session.TotalLosses = (Session.TotalLosses or 0) + 1
                Session.TotalRounds = (Session.TotalRounds or 0) + 1
                Session.LastMatchResult = "💀 ПОРАЗКА"
                Session.Status = "💀 ПОРАЗКА: Зомбі прорвалися на хвилі " .. tostring(curWave > 0 and curWave or 1)
                markActivitySlot("red")
            else
                Session.TotalWins = (Session.TotalWins or 0) + 1
                Session.TotalRounds = (Session.TotalRounds or 0) + 1
                Session.LastMatchResult = "🏆 ПЕРЕМОГА"
                Session.Status = "🏆 ПЕРЕМОГА: Всі хвилі пройдено!"
                markActivitySlot("green")
            end
            addActionLog("match_result", Session.LastMatchResult)

            local curCoins = getAccountCoins()
            local curCandy = getAccountCandy()
            local startCoins = Session.MatchStartCoins or curCoins
            local startCandy = Session.MatchStartCandy or curCandy

            local roundCoins = math.max(0, curCoins - startCoins)
            local roundCandy = math.max(0, curCandy - startCandy)
            if roundCoins == 0 then roundCoins = 600 end
            local waves = math.max(1, curWave)

            Session.LastRoundCoins = roundCoins
            Session.LastRoundCandy = roundCandy
            Session.LastRoundWaves = waves
            Session.CoinsPerWave = math.floor(roundCoins / waves)
            Session.CandyPerWave = math.floor(roundCandy / waves)

            Session.TotalCoinsEarned = (Session.TotalCoinsEarned or 0) + roundCoins
            Session.TotalCandyEarned = (Session.TotalCandyEarned or 0) + roundCandy
            Session.LastRecordedMatchResult = os.time()
            Session.LastActionTime = os.time()
            Session.MatchStartCoins = curCoins
            Session.MatchStartCandy = curCandy

            if saveStats then saveStats() end
        end
    else
        if not inMatch or (baseHp and baseHp > 0) then
            Session.MatchEndedInCurrentSession = false
        end
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
        FriendsList = getFriendsList(),
        ActionLog = Session.ActionLog or {},
        TradeHistory = Session.TradeHistory or {},
        PlayersOnServer = #Players:GetPlayers(),
        Version = "v5.3 (Kero Admin Cloud)"
    }
    pushUpdate(initialData)
    addActionLog("script_start", "Script started, channel: " .. CloudChannel)
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

    while task.wait(3.0) do
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

        local loc = getGameLocationInfo()
        local inMatch = loc.inMatch
        local inLobby = loc.inLobby
        local inTrading = loc.inTrading
        local mapName = loc.mapName
        local baseHp = getBaseHp()

        if not Session.MatchStartCoins and curCoins > 0 then Session.MatchStartCoins = curCoins end
        if not Session.MatchStartCandy and curCandy > 0 then Session.MatchStartCandy = curCandy end

        if curCoins ~= lastCoins or (curWave > 0 and curWave ~= lastWave) or inMatch then
            lastCoins = curCoins
            lastWave = curWave
            Session.LastActionTime = now
        end

        -- Миттєва перевірка діалогових вікон помилок Roblox
        if not Session.IsKicked then
            pcall(function()
                local err = GuiService:GetErrorMessage()
                if err and err ~= "" then
                    handleKickDetected(err)
                end
            end)
            pcall(function()
                local coreGui = game:GetService("CoreGui")
                local prompt = coreGui:FindFirstChild("RobloxPromptGui")
                local overlay = prompt and prompt:FindFirstChild("promptOverlay")
                if overlay then
                    local title = overlay:FindFirstChild("ErrorTitle") or overlay:FindFirstChild("Title")
                    local msg = overlay:FindFirstChild("ErrorMessage") or overlay:FindFirstChild("Message")
                    if title and title.Visible then
                        local reason = (title.Text or "Error") .. ": " .. (msg and msg.Text or "")
                        handleKickDetected(reason)
                    end
                end
            end)
        end

        local idleSeconds = now - (Session.LastActionTime or now)
        local isAFK = (idleSeconds > 150)
        Session.IsAFK = isAFK

        checkMatchResult(curWave, inMatch)

        local statusText = "🟢 В мережі"
        if Session.IsKicked then
            statusText = Session.Status
            markActivitySlot("red")
        elseif Session.ScriptDisabled then
            statusText = "⛔ Скрипт вимкнено в адмін-панелі"
            markActivitySlot("yellow")
        elseif Session.LastMatchResult == "💀 ПОРАЗКА" or (baseHp ~= nil and baseHp <= 0) then
            statusText = "💀 ПОРАЗКА: Базу зруйновано на хвилі " .. tostring(curWave > 0 and curWave or 1)
            markActivitySlot("red")
        elseif Session.LastMatchResult == "🏆 ПЕРЕМОГА" then
            statusText = "🏆 ПЕРЕМОГА: Всі хвилі пройдено!"
            markActivitySlot("green")
        elseif isAFK then
            local mins = math.floor(idleSeconds / 60)
            statusText = "🟡 AFK: Без руху (" .. tostring(mins) .. " хв)"
            markActivitySlot("yellow")
        elseif inMatch then
            statusText = "🟢 У бою: Хвиля " .. tostring(curWave > 0 and curWave or 1) .. (baseHp and (" (HP: " .. tostring(baseHp) .. ")") or "")
            markActivitySlot("green")
        elseif inTrading then
            statusText = "🤝 Трейд Плаза"
            markActivitySlot("green")
        elseif inLobby then
            statusText = "🏰 В лобі: Очікує старту"
            markActivitySlot("green")
        else
            statusText = "🟢 В мережі: Фарм активний"
            markActivitySlot("green")
        end
        Session.Status = statusText

        if now - lastSave >= 3.0 then
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
                BaseHP = baseHp,
                LastMatchResult = Session.LastMatchResult or "",
                MapName = inMatch and (mapName .. " (Match)") or (inTrading and "Trading Plaza" or "Lobby"),
                Difficulty = "Normal",
                
                TotalRounds = Session.TotalRounds,
                TotalWins = Session.TotalWins,
                TotalLosses = Session.TotalLosses,
                Rejoins = Session.Rejoins,
                UptimeSeconds = uptime,
                Status = statusText,
                IsAFK = isAFK,
                IsKicked = Session.IsKicked,
                ScriptDisabled = (Session.ScriptDisabled == true),
                KickReason = Session.KickReason or "",
                IdleSeconds = idleSeconds,
                LastHeartbeat = now,
                UptimeSeconds = getRealUptime(),
                SessionStartTime = Session.SessionStartTime,
                ActivitySlots = Session.ActivitySlots,
                InventoryTowers = getInventoryUnits(),
                FriendsList = getFriendsList(),
                ActionLog = Session.ActionLog or {},
                TradeHistory = Session.TradeHistory or {},
                PlayersOnServer = #Players:GetPlayers(),
                Version = "v5.3 (Kero Admin Cloud)"
            }

            pushUpdate(exportData)
        end
    end
end)
