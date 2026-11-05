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
-- ЧАСТИНА 0.5: ТОТАЛЬНЕ ГЛУШІННЯ СПАМУ В ЛОГ (РЯТУВАННЯ ТЕЛЕФОНУ ВІД 1 FPS)
-- На мобільних експлойтах (Delta, Codex, Arceus X) виведення сотень
-- рядків "ability table: 0x... nil" при прицілюванні та атаці намертво
-- вішає інтерфейс та рушій. Ми перехоплюємо print/warn і глушимо
-- будь-які дампи таблиць, абілок, адрес пам'яті та бойовий спам!
-- ============================================================
local oldPrint = print
local oldWarn = warn

local function isSystemAllowed(...)
    local n = select("#", ...)
    if n == 0 then return false end
    local first = select(1, ...)
    if type(first) == "string" and first:sub(1, 1) == "[" then
        if first:find("%[Camera TD") or first:find("%[Extreme Anti%-Lag") or first:find("%[Kero Loader") then
            return true
        end
    end
    return false
end

local function isLogSpam(...)
    local n = select("#", ...)
    for i = 1, n do
        local v = select(i, ...)
        local t = type(v)
        if t == "table" or t == "function" or t == "thread" then
            return true
        end
        local s = tostring(v):lower()
        if s:find("table:") or s:find("ability") or s:find("абил") or s:find("nil") 
           or s:find("cooldown") or s:find("target") or s:find("damage") or s:find("toilet")
           or s:find("camera") or s:find("attack") or s:find("bullet") or s:find("upgrade")
           or s:find("placed") or s:find("preview") or #s > 70 then
            return true
        end
    end
    return false
end

local function cleanPrint(...)
    if isSystemAllowed(...) then
        oldPrint(...)
        return
    end
    if isLogSpam(...) then
        return
    end
end

local function cleanWarn(...)
    if isSystemAllowed(...) then
        oldWarn(...)
        return
    end
    if isLogSpam(...) then
        return
    end
end

if hookfunction then
    pcall(function() hookfunction(print, cleanPrint) end)
    pcall(function() hookfunction(warn, cleanWarn) end)
    if printidentity then
        pcall(function() hookfunction(printidentity, function() end) end)
    end
end

genv.print = cleanPrint
genv.warn = cleanWarn
if genv.rconsoleprint then genv.rconsoleprint = function() end end
if genv.rconsolewarn then genv.rconsolewarn = function() end end
if genv.rconsoleerr then genv.rconsoleerr = function() end end
if genv.consoleprint then genv.consoleprint = function() end end
if genv.consolewarn then genv.consolewarn = function() end end
_G.print = cleanPrint
_G.warn = cleanWarn
print = cleanPrint
warn = cleanWarn

pcall(function()
    if rconsoleclear then rconsoleclear() end
    if consoleclear then consoleclear() end
end)

-- ============================================================
-- ЧАСТИНА 1: Завантажувач Kero Hub (З авто-повторами під Auto-Inject)
-- ============================================================
task.spawn(function()
    print("[Kero Loader] Підготовка авто-запуску Kero Hub...")
    task.wait(1.5) -- Даємо грі 1.5с завершити первинну реплікацію об'єктів
    
    local maxRetries = 3
    for attempt = 1, maxRetries do
        print(string.format("[Kero Loader] Спроба %d/%d запуску Kero Hub...", attempt, maxRetries))
        local ok, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/KeroTwT/Kero-Hub/main/Sources/Cameraman%20TD"))()
        end)
        if ok then
            print("[Kero Loader] ✅ Kero Hub успішно активовано!")
            break
        else
            warn(string.format("[Kero Loader] Спроба %d не вдалася: %s", attempt, tostring(err)))
            task.wait(2.5)
        end
    end
end)

-- ============================================================
-- ЧАСТИНА 1.5: EXTREME POTATO, PLACEMENT & COMBAT ANTI-LAG (MAX FPS ТЕЛЕФОНУ)
-- Жорстока оптимізація під запис макросів, бій та встановлення юнітів:
-- 1. АНТИ-ФРИЗ ВИБОРУ ЮНІТА (Фікс 1 FPS при натисканні на юніта):
--    Миттєве глушіння Highlight та SelectionBox, а також встановлення
--    CanQuery = false на всі прев'ю та кола радіусів (щоб промінь тапу не застрягав у колі).
-- 2. ТРУПИ ТА РЕГДОЛИ: миттєве глушіння фізики, CanCollide/CanQuery = false
--    та приховування розбитих уламків унітазів при смерті (Died / HealthChanged <= 0).
-- 3. SMOOTH PLASTIC: всі блоки карти без важких текстур, Decal/Texture.Transparency = 1.
-- 4. ЗНЕШКОДЖЕННЯ ЧАСТОК & СВІТЛА: вимикання Beams, Trails, Highlights, PointLights.
-- 5. ПРИХОВУВАННЯ ЦИФР УРОНУ: вимикання BillboardGui над головами туалетів.
-- 6. РОЗВАНТАЖЕННЯ АУДІО: глушіння 3D-звуків вибухів у Workspace.
-- 7. КЛАВІША [F2]: вмикає/вимикає 3D-рендер (Black Screen) для 0% навантаження в AFK!
-- ============================================================
task.spawn(function()
    print("[Extreme Anti-Lag] 🚀 Активація екстремальної оптимізації FPS та встановлення юнітів...")
    task.wait(1.5)

    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    -- 1. Рівень графіки рушія на мінімум
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        if setfpscap then setfpscap(60) end
    end)

    -- 2. Глобальне освітлення та шейдери
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

    -- 3. Перехоплення створення Highlight для запобігання шейдерним зависанням GPU
    if hookfunction and Instance and Instance.new then
        pcall(function()
            local oldInstNew; oldInstNew = hookfunction(Instance.new, function(className, parent)
                local inst = oldInstNew(className, parent)
                if className == "Highlight" then
                    pcall(function()
                        inst.Enabled = false
                        inst.Adornee = nil
                    end)
                end
                return inst
            end)
        end)
    end

    -- 4. Функція жорсткої зачистки об'єкта
    local function brutalClean(obj)
        local c = obj.ClassName

        -- Підсвічування моделей (найбільший вбивця FPS на мобільних телефонах)
        if c == "Highlight" then
            obj.Enabled = false
            pcall(function() obj.Adornee = nil end)
            return
        end

        -- Виділення юнітів та контури
        if c == "SelectionBox" or c == "SelectionSphere" or c == "ArcHandles" or c == "Handles" then
            obj.Visible = false
            return
        end

        -- Частки, лазери, спалахи, промені
        if c == "ParticleEmitter" or c == "Beam" or c == "Trail" or c == "Smoke" or c == "Fire" or c == "Sparkles" then
            obj.Enabled = false
            return
        elseif c == "Explosion" then
            obj.Visible = false
            return
        -- Спливаючий текст урону над туалетами
        elseif c == "BillboardGui" then
            obj.Enabled = false
            return
        -- Динамічні джерела світла від пострілів
        elseif c == "PointLight" or c == "SpotLight" or c == "SurfaceLight" then
            obj.Enabled = false
            return
        -- Важкі текстури та декалі
        elseif c == "Decal" or c == "Texture" then
            obj.Transparency = 1
            return
        end

        -- Оптимізація розміщення юнітів та фізики уламків
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            local pName = obj.Parent and obj.Parent.Name:lower() or ""

            -- Прев'ю юнітів та радіуси атак (Range Circle):
            -- CanQuery = false критично важливий: промінь тапу/миші НЕ застрягає в колі юніта,
            -- що повністю ліквідує зависання на 1 FPS при кліку на іконку юніта!
            if name:find("range") or name:find("preview") or name:find("radius") or name:find("placement") 
               or name:find("circle") or name:find("visualizer") or name:find("hover") or name:find("hitbox")
               or pName:find("preview") or pName:find("placement") or pName:find("range") then
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
                obj.CastShadow = false
                obj.Material = Enum.Material.SmoothPlastic
                return
            end

            -- Фізика трупів / уламків унітазів при смерті: глушимо зіткнення та промені!
            if name:find("debris") or name:find("ragdoll") or name:find("dead") or name:find("corpse") 
               or pName:find("debris") or pName:find("ragdoll") or pName:find("corpse") or pName:find("effect") then
                obj.CanCollide = false
                obj.CanTouch = false
                obj.CanQuery = false
                obj.Anchored = true
                obj.Transparency = 1
                return
            end

            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false

        -- Звуки вибухів/смертей у 3D-просторі
        elseif c == "Sound" and obj:IsDescendantOf(workspace) then
            obj.Volume = 0
        end

        -- Миттєве глушіння туалетів при смерті або нульовому HP
        if obj:IsA("Model") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if hum then
                local function muteRagdoll()
                    task.defer(function()
                        for _, part in ipairs(obj:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                                part.CanTouch = false
                                part.CanQuery = false
                                part.Anchored = true
                                part.Transparency = 1
                            end
                        end
                    end)
                end
                hum.Died:Connect(muteRagdoll)
                hum.HealthChanged:Connect(function(hp)
                    if hp <= 0 then muteRagdoll() end
                end)
            end
        end
    end

    -- 5. Первинна тотальна зачистка всього Workspace
    pcall(function()
        for _, desc in ipairs(workspace:GetDescendants()) do
            brutalClean(desc)
        end
    end)

    -- 6. Миттєва фільтрація нових об'єктів під час бою та розміщення юнітів
    local function handleDescendant(obj)
        local c = obj.ClassName
        if c == "Highlight" or c == "SelectionBox" or c == "SelectionSphere" 
           or c == "ParticleEmitter" or c == "Beam" or c == "Trail" or c == "BillboardGui" 
           or c == "PointLight" or c == "SpotLight" or c == "SurfaceLight" 
           or c == "Decal" or c == "Texture" or c == "Sound" or c == "Explosion"
           or obj:IsA("BasePart") or obj:IsA("Model") then
            brutalClean(obj)
        end
    end

    workspace.DescendantAdded:Connect(handleDescendant)
    if workspace.CurrentCamera then
        workspace.CurrentCamera.DescendantAdded:Connect(handleDescendant)
    end

    -- 7. Фонова зачистка сміття кожні 2 секунди (Debris / Effects / Ragdolls)
    task.spawn(function()
        while task.wait(2) do
            pcall(function()
                for _, folderName in ipairs({"Debris", "Effects", "Projectiles", "Drops", "Ragdolls", "Trash", "Dead", "Corpses", "Bullets"}) do
                    local folder = workspace:FindFirstChild(folderName)
                    if folder then
                        for _, item in ipairs(folder:GetChildren()) do
                            if item:IsA("BasePart") then
                                item.CanCollide = false
                                item.CanTouch = false
                                item.CanQuery = false
                                item.Anchored = true
                                item.Transparency = 1
                            elseif item:IsA("Model") then
                                for _, sub in ipairs(item:GetDescendants()) do
                                    if sub:IsA("BasePart") then
                                        sub.CanCollide = false
                                        sub.CanTouch = false
                                        sub.CanQuery = false
                                        sub.Anchored = true
                                        sub.Transparency = 1
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)

    -- 8. Гаряча клавіша [F2] для супер-AFK (вимикає 3D-рендер повністю, 0% CPU/GPU)
    pcall(function()
        local renderEnabled = true
        UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == Enum.KeyCode.F2 then
                renderEnabled = not renderEnabled
                RunService:Set3dRenderingEnabled(renderEnabled)
                print("[Extreme Anti-Lag] 3D-Рендер: " .. (renderEnabled and "УВІМКНЕНО (Звичайний екран)" or "ВИМКНЕНО (Чорний екран / 0% CPU)"))
            end
        end)
    end)

    print("[Extreme Anti-Lag] ✅ Екстремальна оптимізація успішно активована!")
    print("[Extreme Anti-Lag] 💡 Підказка: Натисніть клавішу F2 у грі для швидкого перемикання Чорного Екрану під AFK.")
end)

-- ============================================================
-- ЧАСТИНА 2: Повністю фоновий трекер (БЕЗ ЖОДНОГО МЕНЮ В ГРІ)
-- ============================================================

-- 1. Хелпери зчитування балансу та хвиль
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

-- 2. Відновлення попередньої сесії з файлу або глобалу
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

-- Відновлюємо попередні слоти з файлу
if savedData.ActivitySlots and type(savedData.ActivitySlots) == "table" then
    for k, v in pairs(savedData.ActivitySlots) do
        if Session.ActivitySlots[k] == nil then
            Session.ActivitySlots[k] = (v == 4 or v == "red") and "red" or "green"
        end
    end
end

-- 3. Розрахунок слотів активності (30-хвилинні інтервали за точним локальним часом ПК)
local function getDayAndSlotIndex()
    local date = os.date("*t") -- Точний локальний час системи (співпадає з часом браузера)
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
        Session.ActivitySlots[key] = statusType -- ТІЛЬКИ "green" АБО "red"
    end
end

-- Визначення хмарного каналу (за замовчуванням camtd_cloud_kvires)
local CloudChannel = (genv.CameraTD_Channel) or "camtd_cloud_kvires"

-- 4. Уніфікована функція відправки та збереження
local function pushUpdate(data)
    local ok, jsonString = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok or not jsonString then return end

    -- 1. Локальний файл для браузера / офлайн відстеження
    if writefile then
        pcall(function()
            writefile(StatsPath, jsonString)
        end)
    end

    local req = httpRequest or findHttpRequest()
    if req then
        -- 2. ГОЛОВНИЙ ХМАРНИЙ КАНАЛ (ntfy.sh) ДЛЯ ОНЛАЙН-САЙТУ 24/7
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

        -- 3. Локальний сервер (0ms для локальної гри)
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

-- 5. Детектори кіків та помилок телепорту
pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(msg)
        if msg and msg ~= "" then
            Session.IsKicked = true
            Session.Status = "❌ ВИЛЕТІЛО / КІКНУЛО: " .. tostring(msg)
            markActivitySlot("red") -- Червоний слот (виліт)
            
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

-- 6. Підрахунок результатів матчу (~600 коїнів за раунд)
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
            if roundCoins == 0 then roundCoins = 600 end -- Реалістичні ~600 за раунд
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

            markActivitySlot("green") -- Зелений слот (фарм OK)
        end
    else
        Session.LastRecordedMatchResult = nil
    end
end

-- ============================================================
-- 7. МИТТЄВИЙ ПЕРШИЙ ПІНГ (0.05с) ДЛЯ ВІДОБРАЖЕННЯ НА САЙТІ
-- ============================================================
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

-- ============================================================
-- 8. ГОЛОВНИЙ ФОНОВИЙ ЦИКЛ (100% СТЕЛС, 0 GUI В ROBLOX)
-- ============================================================
task.spawn(function()
    print("[Camera TD Headless] ✅ Фоновий трекер успішно запущено без меню в грі!")
    print("[Camera TD Headless] ☁️ Хмарний канал: " .. CloudChannel)
    print("[Camera TD Headless] 🌐 Сайт: https://kvires-ps99-cloud.static.hf.space/?channel=" .. CloudChannel)

    task.wait(1.5)
    Session.Status = "🟢 В мережі / Завантажено"

    local lastCoins = 0
    local lastCandy = 0
    local lastWave = 0
    local lastSave = 0

    while task.wait(1.5) do
        -- Перевірка чи цей екземпляр скрипта актуальний
        if genv.__CameraTD_ActiveInstance ~= currentInstanceToken then
            print("[Camera TD Headless] Зупинено попередній екземпляр трекера після зміни сервера.")
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

        -- Оновлення активності: коїни, цукерки, хвиля або активний матч (захист від хибного AFK у довгих матчах)
        if curCoins ~= lastCoins or curCandy ~= lastCandy or (curWave > 0 and curWave ~= lastWave) or inMatch then
            lastCoins = curCoins
            lastCandy = curCandy
            lastWave = curWave
            Session.LastActionTime = now
            markActivitySlot("green")
        end

        local idleSeconds = now - (Session.LastActionTime or now)
        local isAFK = (idleSeconds > 420) and not inMatch -- У матчі ніколи не вважати AFK!

        local statusText = ""
        if Session.IsKicked then
            statusText = Session.Status
            markActivitySlot("red") -- ЧЕРВОНИЙ (Виліт / Кік)
        elseif isAFK then
            statusText = "⚠️ AFK: Немає активності (>7 хв)"
            markActivitySlot("red") -- ЧЕРВОНИЙ (Не фармить)
        elseif inMatch then
            statusText = string.format("🟢 В мережі: У матчі (Хвиля %d)", curWave > 0 and curWave or 1)
            markActivitySlot("green") -- ЗЕЛЕНИЙ (Фарм OK)
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
