--[[ ============================================================
     🚀 PUFYFTYK-KVIRES · PET SIMULATOR 99 TRADE PLAZA & SNIPER HUB
     📱 Повна оптимізація під Delta Mobile (Android / iOS) та ПК
     
     ФУНКЦІЇ:
     1. 🐱 ЦІЛЬОВІ ПЕТИ:
        - Пресети: Stitched Cat, Stitched Dragon, Any Stitched, Huge, Titanic, Всі
        - Свій пошук за будь-якою назвою пета або предмета
     2. 💎 ДІАПАЗОН ЦІН:
        - Фільтр: Ціна ВІД (Min) та Ціна ДО (Max) (підтримує 100k, 5m, 1b)
     3. 🔄 АВТО-ОНОВЛЕННЯ:
        - Автоматичне сканування будок кожні 3 сек із індикатором
     4. 📜 ВКЛАДКА ЛОГІВ ТА ПОМИЛОК:
        - Відображення помилок двигуна та дій скрипта в реальному часі
        - Кнопка швидкого копіювання всіх логів в 1 клік (setclipboard)
        - Текстове поле для легкого виділення на телефоні
     5. 📱 DELTA MOBILE ПІДТРИМКА:
        - Плаваюча кнопка відкриття/закриття на екрані (Touch-Draggable)
        - Адаптивний розмір під екрани телефонів
        - Сенсорне перетягування вікна
     6. 🖥️ СУПЕР КОМП'ЮТЕР / ТЕРМІНАЛ (5с обхід затримки)
     7. 👁️ 3D ESP БУДОК КРІЗЬ СТІНИ
     8. 🌐 СЕРВЕР-ХОП ЧЕРЕЗ ROBLOX API
     9. ⚡ БУСТ FPS ТА 20-ХВ ANTI-AFK
     ============================================================ ]]

local WS        = game:GetService("Workspace")
local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local RunS      = game:GetService("RunService")
local RepS      = game:GetService("ReplicatedStorage")
local Lighting  = game:GetService("Lighting")
local StarterGui= game:GetService("StarterGui")
local HttpS     = game:GetService("HttpService")
local TeleportS = game:GetService("TeleportService")
local LogService= game:GetService("LogService")
local VIM       = pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager") or nil
local VU        = pcall(function() return game:GetService("VirtualUser") end) and game:GetService("VirtualUser") or nil

-- Очікування завантаження гравця
local player = Players.LocalPlayer
if not player then
    repeat task.wait(0.1); player = Players.LocalPlayer until player
end
local camera = WS.CurrentCamera or WS:WaitForChild("Camera", 5)

-- Безпечний пошук контейнера GUI для Delta / PC
local function getGuiParent()
    local parent = nil
    pcall(function() if gethui then parent = gethui() end end)
    if not parent then
        pcall(function()
            local cg = game:GetService("CoreGui")
            local _ = cg.Name
            parent = cg
        end)
    end
    if not parent then
        parent = player:WaitForChild("PlayerGui", 5) or player:FindFirstChild("PlayerGui")
    end
    return parent
end

-- Закриття попередніх копій хабу
pcall(function()
    local old = getGuiParent():FindFirstChild("PufyftykTradeHub")
    if old then old:Destroy() end
    local oldT = getGuiParent():FindFirstChild("PufyMobileToggle")
    if oldT then oldT:Destroy() end
end)

_G.Pufyftyk_Trade_Loaded = true

-- Налаштування за замовчуванням
local cfg = {
    targetPet       = "Stitched Cat", -- вибір за замовчуванням: Stitched Cat
    minPrice        = 0,              -- ціна ВІД (гемів)
    maxPrice        = 100000000,      -- ціна ДО (100M гемів)
    minDiscount     = 0,              -- знижка від % (0 = показувати все в діапазоні ціни)
    maxBudget       = 50000000,       -- максимальний бюджет на авто-покупку (50M)
    autoBuy         = false,          -- авто-покупка
    autoHop         = false,          -- авто-перехід
    espOn           = true,           -- 3D ESP будок
    autoRefresh     = true,           -- авто-оновлення будок
    refreshInterval = 3.0,            -- інтервал авто-оновлення (сек)
    fpsCap30        = false,          -- ліміт 30 фпс
    potatoMode      = false,          -- картопляний режим
    antiAfk         = true,           -- захист від вильоту 20 хв
}

-- Тема оформлення (Cyber Dark)
local Theme = {
    bg         = Color3.fromRGB(13, 16, 23),
    sidebar    = Color3.fromRGB(18, 22, 32),
    card       = Color3.fromRGB(24, 30, 44),
    cardHover  = Color3.fromRGB(32, 40, 58),
    cardActive = Color3.fromRGB(28, 48, 70),
    accent     = Color3.fromRGB(0, 210, 255),
    gold       = Color3.fromRGB(255, 205, 50),
    green      = Color3.fromRGB(0, 230, 130),
    red        = Color3.fromRGB(235, 75, 75),
    purple     = Color3.fromRGB(175, 95, 255),
    text       = Color3.fromRGB(235, 240, 255),
    textDark   = Color3.fromRGB(140, 155, 180),
}

-- ==============================================================================
-- 📜 СИСТЕМА ЛОГУВАННЯ ТА ВІДСТЕЖЕННЯ ПОМИЛОК (ЛОГИ)
-- ==============================================================================
local logEntries       = {}
local errorCount       = 0
local logScrollFrame   = nil
local logStatsLabel    = nil
local copyFallbackBox  = nil
local refreshLogUI     = nil

local function addLog(lvl, text)
    local tStr = os.date("%H:%M:%S")
    local entry = {
        time  = tStr,
        level = lvl or "INFO",
        text  = tostring(text or "")
    }
    table.insert(logEntries, entry)
    if #logEntries > 250 then
        table.remove(logEntries, 1)
    end
    if lvl == "ERROR" then
        errorCount = errorCount + 1
    end

    if logStatsLabel then
        pcall(function()
            logStatsLabel.Text = string.format("📊 Всього: %d | 🔴 Помилок: %d", #logEntries, errorCount)
        end)
    end

    if refreshLogUI then
        refreshLogUI()
    end
end

-- Перехоплення помилок та попереджень двигуна гри
pcall(function()
    LogService.MessageOut:Connect(function(msg, msgType)
        if msgType == Enum.MessageType.MessageError then
            addLog("ERROR", msg)
        elseif msgType == Enum.MessageType.MessageWarning then
            if msg:find("Pufy") or msg:find("Booth") or msg:find("Network") or msg:find("Terminal") then
                addLog("WARN", msg)
            end
        end
    end)
end)

-- Функція копіювання логів у буфер обміну
local function copyAllLogs()
    local lines = {}
    table.insert(lines, "=== PUFYFTYK-KVIRES TRADE HUB LOGS ===")
    table.insert(lines, string.format("Час: %s | Пристрій: Delta/Mobile/PC | Гра: PS99", os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(lines, string.format("Всього записів: %d | Помилок: %d", #logEntries, errorCount))
    table.insert(lines, "--------------------------------------------------")
    for _, e in ipairs(logEntries) do
        table.insert(lines, string.format("[%s] [%s] %s", e.time, e.level, e.text))
    end
    table.insert(lines, "==================================================")
    local fullText = table.concat(lines, "\n")

    local copied = false
    pcall(function()
        if setclipboard then
            setclipboard(fullText)
            copied = true
        elseif toclipboard then
            toclipboard(fullText)
            copied = true
        elseif Synapse and Synapse.set_clipboard then
            Synapse.set_clipboard(fullText)
            copied = true
        end
    end)

    if copyFallbackBox then
        copyFallbackBox.Text = fullText
        copyFallbackBox.Visible = true
    end

    addLog("SUCCESS", "Логи сформовано (" .. #logEntries .. " рядків). Статус копіювання: " .. (copied and "ОК" or "В полі"))
    StarterGui:SetCore("SendNotification", {
        Title = "📋 Логи скопійовано!",
        Text = copied and "Успішно в буфері обміну! Можеш вставити і скинути мені." or "Дивись поле нижче - можна виділити весь текст вручну!",
        Duration = 4
    })
end

-- ==============================================================================
-- 💎 УТИЛІТИ ПАРСИНГУ ТА ФОРМАТУВАННЯ ЦІН
-- ==============================================================================
local function parsePrice(txt)
    if not txt or type(txt) ~= "string" then return 0 end
    local clean = txt:gsub(",", ""):gsub(" ", ""):gsub("💎", ""):upper()
    local numStr, unit = clean:match("([%d%.]+)%s*([KMB]?)")
    if not numStr then return 0 end
    local num = tonumber(numStr)
    if not num then return 0 end
    if unit == "K" then num = num * 1000
    elseif unit == "M" then num = num * 1000000
    elseif unit == "B" then num = num * 1000000000
    end
    return math.floor(num)
end

local function formatPrice(num)
    if not num or num == 0 then return "0" end
    if num >= 1000000000 then
        return string.format("%.1fB", num / 1000000000)
    elseif num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(num)
    end
end

-- Перевірка чи відповідає ім'я вибраному пету
local function matchesPetFilter(itemName)
    if not itemName then return false end
    local target = (cfg.targetPet or "all"):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if target == "all" or target == "" then
        return true
    end
    local nameLower = itemName:lower()
    if target == "stitched" or target == "any_stitched" then
        return nameLower:find("stitched") ~= nil
    end
    return nameLower:find(target, 1, true) ~= nil
end

-- Перевірка діапазону цін
local function matchesPriceFilter(price)
    if cfg.minPrice and cfg.minPrice > 0 and price < cfg.minPrice then
        return false
    end
    if cfg.maxPrice and cfg.maxPrice > 0 and price > cfg.maxPrice then
        return false
    end
    return true
end

-- ==============================================================================
-- 🛒 СКАЙПЕР БУДОК ТА ТОРГОВЕЛЬНІ ФУНКЦІЇ
-- ==============================================================================
local plazaHighlights       = {}
local currentBargains       = {}
local refreshBargainsUI     = nil
local isTerminalLoopActive  = false
local termLoopBtn           = nil

local function clearPlazaESP()
    for _, h in ipairs(plazaHighlights) do
        pcall(function() h:Destroy() end)
    end
    table.clear(plazaHighlights)
end

local function applyPlazaESP(bargains)
    clearPlazaESP()
    if not cfg.espOn then return end

    for _, b in ipairs(bargains) do
        if b.booth and b.booth:IsDescendantOf(WS) and matchesPetFilter(b.item) and matchesPriceFilter(b.price) then
            pcall(function()
                local hl = Instance.new("Highlight")
                hl.Name = "BargainHighlight"
                hl.Adornee = b.booth
                hl.FillColor = Theme.green
                hl.FillTransparency = 0.55
                hl.OutlineColor = Theme.gold
                hl.OutlineTransparency = 0.1
                hl.Parent = b.booth
                table.insert(plazaHighlights, hl)

                local bg = Instance.new("BillboardGui")
                bg.Name = "BargainTag"
                bg.Adornee = b.pad or b.booth.PrimaryPart
                bg.Size = UDim2.new(0, 160, 0, 36)
                bg.StudsOffset = Vector3.new(0, 6, 0)
                bg.AlwaysOnTop = true
                bg.Parent = b.booth

                local tag = Instance.new("TextLabel")
                tag.Size = UDim2.new(1, 0, 1, 0)
                tag.BackgroundColor3 = Theme.bg
                tag.BackgroundTransparency = 0.2
                tag.TextColor3 = Theme.gold
                tag.Font = Enum.Font.GothamBold
                tag.TextSize = 10
                local discTxt = (b.discount > 0) and string.format("🔥 -%d%%", b.discount) or "⭐ Знайдено"
                tag.Text = string.format("%s | %s\n💎 %s", discTxt, b.item, formatPrice(b.price))
                tag.Parent = bg
                Instance.new("UICorner", tag).CornerRadius = UDim.new(0, 5)
                local st = Instance.new("UIStroke", tag)
                st.Color = Theme.green
                st.Thickness = 1.2
                table.insert(plazaHighlights, bg)
            end)
        end
    end
end

-- Сканування всіх палаток на сервері
local function scanAllBooths()
    local bargains = {}
    local boothsFolder = WS:FindFirstChild("__THINGS") and WS.__THINGS:FindFirstChild("Booths")
    if not boothsFolder then boothsFolder = WS:FindFirstChild("Booths", true) end
    if not boothsFolder then
        addLog("WARN", "Папку наметів не знайдено (можливо, ще завантажується світ)")
        return bargains
    end

    local boothList = boothsFolder:GetChildren()
    for _, booth in ipairs(boothList) do
        if booth:IsA("Model") or booth:IsA("Folder") then
            local ownerName = booth:GetAttribute("Owner") or booth.Name
            local pad = booth:FindFirstChild("Pad") or booth:FindFirstChildWhichIsA("BasePart") or booth.PrimaryPart

            for _, gui in ipairs(booth:GetDescendants()) do
                if gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") then
                    local texts = {}
                    for _, lbl in ipairs(gui:GetDescendants()) do
                        if lbl:IsA("TextLabel") and lbl.Visible and #lbl.Text > 0 then
                            table.insert(texts, lbl.Text)
                        end
                    end

                    if #texts > 0 then
                        local itemName = nil
                        local priceVal = 0
                        local rapVal   = 0

                        for _, txt in ipairs(texts) do
                            local tLower = txt:lower()
                            if txt:find("💎") or tLower:find("price") or tLower:find("cost") or tLower:find("%d+k") or tLower:find("%d+m") or tLower:find("%d+b") then
                                local p = parsePrice(txt)
                                if p > 0 and (priceVal == 0 or not tLower:find("rap")) then
                                    priceVal = p
                                end
                            end

                            if tLower:find("rap") then
                                local r = parsePrice(txt)
                                if r > 0 then rapVal = r end
                            end

                            if not itemName and not tLower:find("💎") and not tLower:find("price") and not tLower:find("rap") and not tLower:find("diamonds") and #txt > 2 then
                                itemName = txt
                            end
                        end

                        if itemName and priceVal > 0 then
                            local discount = 0
                            if rapVal > 0 and rapVal > priceVal then
                                discount = math.floor((1 - (priceVal / rapVal)) * 100)
                            end

                            local category = "Item"
                            local inLower = itemName:lower()
                            if inLower:find("stitched cat") then category = "Stitched Cat"
                            elseif inLower:find("stitched dragon") then category = "Stitched Dragon"
                            elseif inLower:find("stitched") then category = "Stitched"
                            elseif inLower:find("huge") then category = "Huge"
                            elseif inLower:find("titanic") or inLower:find("gargantuan") then category = "Titanic"
                            elseif inLower:find("exclusive") then category = "Exclusive"
                            elseif inLower:find("egg") or inLower:find("gift") then category = "Egg"
                            end

                            table.insert(bargains, {
                                item     = itemName,
                                price    = priceVal,
                                rap      = rapVal,
                                discount = discount,
                                category = category,
                                owner    = ownerName,
                                booth    = booth,
                                pad      = pad,
                                pos      = pad and pad.Position or (booth:IsA("Model") and booth:GetBoundingBox().Position) or Vector3.zero
                            })
                        end
                    end
                end
            end
        end
    end

    -- Сортування: спершу за знижкою, потім за ціною
    table.sort(bargains, function(a, b)
        if a.discount ~= b.discount then return a.discount > b.discount end
        return a.price < b.price
    end)

    currentBargains = bargains
    applyPlazaESP(bargains)
    return bargains
end

-- Телепорт до будки продавця
local function teleportToBooth(bData)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not bData then return end

    local targetPos = bData.pos
    if targetPos == Vector3.zero and bData.booth then
        local cf = bData.booth:GetBoundingBox()
        targetPos = cf.Position
    end

    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 2))
    hrp.AssemblyLinearVelocity = Vector3.zero
    addLog("ACTION", string.format("Телепорт до намету: %s (%s)", bData.item, tostring(bData.owner)))
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "📍 ТП до будки!",
            Text = string.format("%s за 💎 %s (Власник: %s)", bData.item, formatPrice(bData.price), tostring(bData.owner)),
            Duration = 3
        })
    end)
end

-- Покупка речі з будки через Network Remote
local function buyBoothItem(bData)
    if not bData then return false end
    local net = RepS:FindFirstChild("Network")
    if not net then
        addLog("ERROR", "ReplicatedStorage.Network не знайдено!")
        return false
    end
    local buyRem = net:FindFirstChild("Booths_RequestPurchase")
    if buyRem then
        addLog("ACTION", string.format("Спроба покупки %s за 💎 %s у %s...", bData.item, formatPrice(bData.price), tostring(bData.owner)))
        local ok, res = pcall(function()
            return buyRem:InvokeServer(bData.owner, bData.uid or bData.item)
        end)
        if ok then
            addLog("SUCCESS", string.format("Запит покупки %s відправлено!", bData.item))
        else
            addLog("ERROR", string.format("Помилка покупки: %s", tostring(res)))
        end
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "💎 Покупка",
                Text = ok and string.format("Запит на покупку %s відправлено!", bData.item) or "Помилка покупки",
                Duration = 3
            })
        end)
        return ok and res
    else
        addLog("ERROR", "Ремоут Booths_RequestPurchase не знайдено в Network!")
    end
    return false
end

-- Сервер-хоп (Server Hopping)
local function serverHop()
    local placeId = game.PlaceId
    local currentJobId = game.JobId

    addLog("ACTION", "Початок пошуку нового сервера Трейд Плази...")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "🌐 Сервер-Хоп",
            Text = "Пошук нового сервера Трейд Плази...",
            Duration = 3
        })
    end)

    local ok, res = pcall(function()
        local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100", tostring(placeId))
        return game:HttpGet(url)
    end)

    if ok and res then
        local decodeOk, data = pcall(function() return HttpS:JSONDecode(res) end)
        if decodeOk and data and data.data then
            local candidates = {}
            for _, s in ipairs(data.data) do
                if s.id ~= currentJobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers - 2 and s.playing > 10 then
                    table.insert(candidates, s.id)
                end
            end
            if #candidates > 0 then
                local chosen = candidates[math.random(1, #candidates)]
                addLog("ACTION", "Стрибок на сервер JobId: " .. tostring(chosen))
                if queue_on_teleport then
                    queue_on_teleport([[loadstring(readfile("pufyftyk_perfect_hub.lua"))()]])
                end
                TeleportS:TeleportToPlaceInstance(placeId, chosen, player)
                return true
            end
        end
    end

    addLog("WARN", "Публічний список не повернув відповіді, стандартний ТП...")
    pcall(function()
        if queue_on_teleport then
            queue_on_teleport([[loadstring(readfile("pufyftyk_perfect_hub.lua"))()]])
        end
        TeleportS:Teleport(placeId, player)
    end)
    return false
end

-- Швидкий пошук через Термінал / Супер Комп'ютер
local function toggleTerminalLoop()
    isTerminalLoopActive = not isTerminalLoopActive
    if termLoopBtn then
        termLoopBtn.Text = isTerminalLoopActive and "⏹ Зупинити Термінал" or "🚀 Швидкий перехват (5с)"
        termLoopBtn.BackgroundColor3 = isTerminalLoopActive and Theme.red or Color3.fromRGB(80, 40, 120)
    end

    if isTerminalLoopActive then
        addLog("ACTION", "Запущено швидкий пошук терміналу кожні 5 сек...")
        task.spawn(function()
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "🖥️ Супер Комп'ютер",
                    Text = "Запущено пошук кожні 5 сек (без 60с затримки)!",
                    Duration = 4
                })
            end)

            local net = RepS:FindFirstChild("Network")
            while isTerminalLoopActive and _G.Pufyftyk_Trade_Loaded do
                local target = cfg.targetPet or "Stitched Cat"
                if target == "all" then target = "Huge" end
                addLog("INFO", "Термінал: запит на пет '" .. target .. "'")

                pcall(function()
                    if net then
                        local termRem = net:FindFirstChild("TradingTerminal_Search") or net:FindFirstChild("TradingTerminal") or net:FindFirstChild("Terminal_Search")
                        if termRem then
                            if termRem:IsA("RemoteFunction") then
                                local res = termRem:InvokeServer(target)
                                if res and type(res) == "table" and res.JobId then
                                    addLog("SUCCESS", "Термінал знайшов сервер із петом! ТП...")
                                    if queue_on_teleport then
                                        queue_on_teleport([[loadstring(readfile("pufyftyk_perfect_hub.lua"))()]])
                                    end
                                    TeleportS:TeleportToPlaceInstance(game.PlaceId, res.JobId, player)
                                    isTerminalLoopActive = false
                                    return
                                end
                            elseif termRem:IsA("RemoteEvent") then
                                termRem:FireServer(target)
                            end
                        end
                    end
                end)

                local pGui = player:FindFirstChild("PlayerGui")
                if pGui then
                    for _, g in ipairs(pGui:GetDescendants()) do
                        if g:IsA("TextButton") and g.Visible then
                            local btnTxt = g.Text:lower()
                            if btnTxt:find("teleport") or btnTxt:find("join") then
                                addLog("SUCCESS", "Знайдено кнопку телепорту в інтерфейсі терміналу!")
                                pcall(function()
                                    if firesignal then firesignal(g.MouseButton1Click) end
                                    if queue_on_teleport then
                                        queue_on_teleport([[loadstring(readfile("pufyftyk_perfect_hub.lua"))()]])
                                    end
                                end)
                                isTerminalLoopActive = false
                                return
                            end
                        end
                    end
                end

                task.wait(5.0)
            end
        end)
    else
        addLog("INFO", "Швидкий термінал зупинено")
    end
end

-- ==============================================================================
-- 🖥️ ІНТЕРФЕЙС PUFYFTYK TRADE PLAZA HUB
-- ==============================================================================
local sg = Instance.new("ScreenGui")
sg.Name = "PufyftykTradeHub"
sg.ResetOnSpawn = false
pcall(function() sg.Parent = getGuiParent() end)

-- Адаптивний розмір для телефону та ПК
local vp = camera.ViewportSize
local winW = math.min(540, math.max(340, vp.X - 20))
local winH = math.min(340, math.max(280, vp.Y - 20))

local win = Instance.new("Frame")
win.Size = UDim2.new(0, winW, 0, winH)
win.Position = UDim2.new(0.5, -math.floor(winW / 2), 0.5, -math.floor(winH / 2))
win.BackgroundColor3 = Theme.bg
win.BorderSizePixel = 0
win.Active = true
win.Parent = sg
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)

local winStroke = Instance.new("UIStroke", win)
winStroke.Color = Theme.accent
winStroke.Thickness = 1.4
winStroke.Transparency = 0.55

-- Верхня панель (TopBar)
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 36)
topBar.BackgroundColor3 = Theme.sidebar
topBar.BorderSizePixel = 0
topBar.Parent = win
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(0.7, 0, 1, 0); titleLbl.Position = UDim2.new(0, 12, 0, 0)
titleLbl.BackgroundTransparency = 1; titleLbl.Font = Enum.Font.GothamBold; titleLbl.TextSize = 12
titleLbl.TextColor3 = Theme.accent; titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Text = "🛒 pufyftyk-kvires · Trade Sniper (Mobile/PC)"
titleLbl.Parent = topBar

-- Кнопки згортання та закриття
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 24); closeBtn.Position = UDim2.new(1, -30, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 55); closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 12
closeBtn.TextColor3 = Color3.new(1, 1, 1); closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 26, 0, 24); minBtn.Position = UDim2.new(1, -60, 0, 6)
minBtn.BackgroundColor3 = Theme.card; minBtn.BorderSizePixel = 0
minBtn.Text = "—"; minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 12
minBtn.TextColor3 = Theme.text; minBtn.Parent = topBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

minBtn.MouseButton1Click:Connect(function()
    win.Visible = false
    addLog("INFO", "Вікно згорнуто. Натисніть кнопку '🛒' на екрані, щоб відкрити!")
end)

closeBtn.MouseButton1Click:Connect(function()
    _G.Pufyftyk_Trade_Loaded = false
    clearPlazaESP()
    sg:Destroy()
end)

-- 📱 Сенсорне та мишаче перетягування (Touch & Mouse Draggable)
local draggingWin, dragStartWin, startPosWin
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingWin = true
        dragStartWin = input.Position
        startPosWin = win.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingWin = false
            end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and draggingWin then
        local delta = input.Position - dragStartWin
        win.Position = UDim2.new(startPosWin.X.Scale, startPosWin.X.Offset + delta.X, startPosWin.Y.Scale, startPosWin.Y.Offset + delta.Y)
    end
end)

-- 📱 Плаваюча кнопка відкриття/закриття на екрані (Mobile Floating Toggle)
local mobileToggle = Instance.new("TextButton")
mobileToggle.Name = "PufyMobileToggle"
mobileToggle.Size = UDim2.new(0, 44, 0, 44)
mobileToggle.Position = UDim2.new(0, 12, 0.5, -22)
mobileToggle.BackgroundColor3 = Theme.cardActive
mobileToggle.BorderSizePixel = 0
mobileToggle.Text = "🛒"
mobileToggle.Font = Enum.Font.GothamBold
mobileToggle.TextSize = 20
mobileToggle.TextColor3 = Theme.accent
mobileToggle.Parent = sg
Instance.new("UICorner", mobileToggle).CornerRadius = UDim.new(0, 22)
local mtStroke = Instance.new("UIStroke", mobileToggle)
mtStroke.Color = Theme.accent
mtStroke.Thickness = 1.6

local draggingMt, dragStartMt, startPosMt
mobileToggle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingMt = true
        dragStartMt = input.Position
        startPosMt = mobileToggle.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingMt = false
            end
        end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and draggingMt then
        local delta = input.Position - dragStartMt
        mobileToggle.Position = UDim2.new(startPosMt.X.Scale, startPosMt.X.Offset + delta.X, startPosMt.Y.Scale, startPosMt.Y.Offset + delta.Y)
    end
end)

mobileToggle.MouseButton1Click:Connect(function()
    win.Visible = not win.Visible
end)

-- Бокова панель вкладок (Sidebar)
local sidebar = Instance.new("ScrollingFrame")
sidebar.Size = UDim2.new(0, 130, 1, -36); sidebar.Position = UDim2.new(0, 0, 0, 36)
sidebar.BackgroundColor3 = Theme.sidebar; sidebar.BorderSizePixel = 0; sidebar.Parent = win
sidebar.ScrollBarThickness = 2; sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)

local sList = Instance.new("UIListLayout", sidebar)
sList.Padding = UDim.new(0, 4); sList.SortOrder = Enum.SortOrder.LayoutOrder
local sPad = Instance.new("UIPadding", sidebar)
sPad.PaddingTop = UDim.new(0, 6); sPad.PaddingLeft = UDim.new(0, 5); sPad.PaddingRight = UDim.new(0, 5)

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -136, 1, -42); container.Position = UDim2.new(0, 133, 0, 38)
container.BackgroundTransparency = 1; container.Parent = win

local tabs = {}
local tabButtons = {}

local function createTab(id, titleText, icon, order)
    local page = Instance.new("Frame")
    page.Name = id .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = container

    local tBtn = Instance.new("TextButton")
    tBtn.Size = UDim2.new(1, 0, 0, 30); tBtn.LayoutOrder = order
    tBtn.BackgroundColor3 = Theme.card; tBtn.BorderSizePixel = 0
    tBtn.Text = icon .. "  " .. titleText
    tBtn.Font = Enum.Font.GothamSemibold; tBtn.TextSize = 10
    tBtn.TextColor3 = Theme.textDark; tBtn.TextXAlignment = Enum.TextXAlignment.Left
    tBtn.Parent = sidebar
    Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 6)
    local tPad = Instance.new("UIPadding", tBtn); tPad.PaddingLeft = UDim.new(0, 8)

    tabs[id] = page
    tabButtons[id] = tBtn

    tBtn.MouseButton1Click:Connect(function()
        for k, p in pairs(tabs) do p.Visible = (k == id) end
        for k, b in pairs(tabButtons) do
            local isSel = (k == id)
            b.BackgroundColor3 = isSel and Theme.cardActive or Theme.card
            b.TextColor3 = isSel and Theme.accent or Theme.textDark
        end
        if id == "Logs" and refreshLogUI then
            refreshLogUI()
        end
    end)

    return page
end

-- Створюємо 5 вкладок: Будки, Термінал, Логи, Буст FPS, Налаштування
local boothsPage   = createTab("Booths", "Будки", "🛒", 1)
local terminalPage = createTab("Terminal", "Термінал", "🖥️", 2)
local logsPage     = createTab("Logs", "Логи", "📜", 3)
local optPage      = createTab("Opt", "Буст FPS", "⚡", 4)
local settingsPage = createTab("Config", "Налаштування", "⚙️", 5)

tabs["Booths"].Visible = true
tabButtons["Booths"].BackgroundColor3 = Theme.cardActive
tabButtons["Booths"].TextColor3 = Theme.accent

-- ==============================================================================
-- 🛒 ВКЛАДКА 1: БУДКИ (СКАНЕР, ВИБІР ПЕТІВ ТА ЦІН)
-- ==============================================================================
local bTopBar = Instance.new("Frame")
bTopBar.Size = UDim2.new(1, 0, 0, 36); bTopBar.BackgroundColor3 = Theme.card; bTopBar.BorderSizePixel = 0
bTopBar.Parent = boothsPage
Instance.new("UICorner", bTopBar).CornerRadius = UDim.new(0, 6)

local bStatusLbl = Instance.new("TextLabel")
bStatusLbl.Size = UDim2.new(0.65, 0, 1, 0); bStatusLbl.Position = UDim2.new(0, 6, 0, 0)
bStatusLbl.BackgroundTransparency = 1; bStatusLbl.Font = Enum.Font.GothamBold; bStatusLbl.TextSize = 10
bStatusLbl.TextColor3 = Theme.gold; bStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
bStatusLbl.Text = "⚡ Знайдено: 0 | Ціль: Stitched Cat"
bStatusLbl.Parent = bTopBar

local bBtnRow = Instance.new("Frame")
bBtnRow.Size = UDim2.new(0.35, -4, 1, -6); bBtnRow.Position = UDim2.new(0.65, 0, 0, 3)
bBtnRow.BackgroundTransparency = 1; bBtnRow.Parent = bTopBar
local bbrLay = Instance.new("UIListLayout", bBtnRow)
bbrLay.FillDirection = Enum.FillDirection.Horizontal; bbrLay.Padding = UDim.new(0, 4)

local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(0.5, -2, 1, 0); scanBtn.BorderSizePixel = 0
scanBtn.BackgroundColor3 = Color3.fromRGB(30, 90, 140); scanBtn.TextColor3 = Color3.fromRGB(220, 240, 255)
scanBtn.Font = Enum.Font.GothamBold; scanBtn.TextSize = 9; scanBtn.Text = "🔄 Скан"
scanBtn.Parent = bBtnRow
Instance.new("UICorner", scanBtn).CornerRadius = UDim.new(0, 5)

local hopBtn = Instance.new("TextButton")
hopBtn.Size = UDim2.new(0.5, -2, 1, 0); hopBtn.BorderSizePixel = 0
hopBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 50); hopBtn.TextColor3 = Color3.fromRGB(180, 240, 190)
hopBtn.Font = Enum.Font.GothamBold; hopBtn.TextSize = 9; hopBtn.Text = "🌐 Хоп"
hopBtn.Parent = bBtnRow
Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0, 5)

hopBtn.MouseButton1Click:Connect(function() serverHop() end)

-- Панель вибору пета (Quick Preset Buttons)
local petPresetBar = Instance.new("Frame")
petPresetBar.Size = UDim2.new(1, 0, 0, 26); petPresetBar.Position = UDim2.new(0, 0, 0, 40)
petPresetBar.BackgroundTransparency = 1; petPresetBar.Parent = boothsPage
local ppbLay = Instance.new("UIListLayout", petPresetBar)
ppbLay.FillDirection = Enum.FillDirection.Horizontal; ppbLay.Padding = UDim.new(0, 3)

local petButtons = {}
local petPresets = {
    { id = "Stitched Cat",    name = "🐱 Stitched Cat" },
    { id = "Stitched Dragon", name = "🐉 Stitched Dragon" },
    { id = "stitched",        name = "🧵 Обидва" },
    { id = "Huge",            name = "👑 Huge" },
    { id = "all",             name = "⭐ Всі" },
}

local function selectPetPreset(targetId)
    cfg.targetPet = targetId
    addLog("INFO", "Вибрано ціль: " .. targetId)
    for id, btn in pairs(petButtons) do
        local isSel = (id == targetId)
        btn.BackgroundColor3 = isSel and Color3.fromRGB(40, 110, 80) or Theme.card
        btn.TextColor3 = isSel and Theme.green or Theme.textDark
    end
    if refreshBargainsUI then refreshBargainsUI() end
end

for _, pData in ipairs(petPresets) do
    local pBtn = Instance.new("TextButton")
    pBtn.Size = UDim2.new(0.2, -3, 1, 0); pBtn.BorderSizePixel = 0
    pBtn.Font = Enum.Font.GothamBold; pBtn.TextSize = 8
    pBtn.Text = pData.name
    pBtn.BackgroundColor3 = (cfg.targetPet == pData.id) and Color3.fromRGB(40, 110, 80) or Theme.card
    pBtn.TextColor3 = (cfg.targetPet == pData.id) and Theme.green or Theme.textDark
    pBtn.Parent = petPresetBar
    Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 4)
    petButtons[pData.id] = pBtn

    pBtn.MouseButton1Click:Connect(function()
        selectPetPreset(pData.id)
    end)
end

-- Панель діапазону цін (ВІД та ДО) + Пошук
local priceBar = Instance.new("Frame")
priceBar.Size = UDim2.new(1, 0, 0, 26); priceBar.Position = UDim2.new(0, 0, 0, 68)
priceBar.BackgroundColor3 = Theme.sidebar; priceBar.BorderSizePixel = 0
priceBar.Parent = boothsPage
Instance.new("UICorner", priceBar).CornerRadius = UDim.new(0, 5)

local pLbl1 = Instance.new("TextLabel")
pLbl1.Size = UDim2.new(0, 38, 1, 0); pLbl1.Position = UDim2.new(0, 4, 0, 0)
pLbl1.BackgroundTransparency = 1; pLbl1.Font = Enum.Font.GothamBold; pLbl1.TextSize = 9
pLbl1.TextColor3 = Theme.accent; pLbl1.Text = "💎 Від:"
pLbl1.Parent = priceBar

local minPriceBox = Instance.new("TextBox")
minPriceBox.Size = UDim2.new(0, 65, 0, 20); minPriceBox.Position = UDim2.new(0, 42, 0, 3)
minPriceBox.BackgroundColor3 = Theme.card; minPriceBox.BorderSizePixel = 0
minPriceBox.Font = Enum.Font.GothamBold; minPriceBox.TextSize = 9; minPriceBox.TextColor3 = Theme.gold
minPriceBox.Text = formatPrice(cfg.minPrice); minPriceBox.ClearTextOnFocus = false
minPriceBox.Parent = priceBar
Instance.new("UICorner", minPriceBox).CornerRadius = UDim.new(0, 4)

local pLbl2 = Instance.new("TextLabel")
pLbl2.Size = UDim2.new(0, 28, 1, 0); pLbl2.Position = UDim2.new(0, 112, 0, 0)
pLbl2.BackgroundTransparency = 1; pLbl2.Font = Enum.Font.GothamBold; pLbl2.TextSize = 9
pLbl2.TextColor3 = Theme.accent; pLbl2.Text = "До:"
pLbl2.Parent = priceBar

local maxPriceBox = Instance.new("TextBox")
maxPriceBox.Size = UDim2.new(0, 68, 0, 20); maxPriceBox.Position = UDim2.new(0, 142, 0, 3)
maxPriceBox.BackgroundColor3 = Theme.card; maxPriceBox.BorderSizePixel = 0
maxPriceBox.Font = Enum.Font.GothamBold; maxPriceBox.TextSize = 9; maxPriceBox.TextColor3 = Theme.gold
maxPriceBox.Text = formatPrice(cfg.maxPrice); maxPriceBox.ClearTextOnFocus = false
maxPriceBox.Parent = priceBar
Instance.new("UICorner", maxPriceBox).CornerRadius = UDim.new(0, 4)

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -220, 0, 20); searchBox.Position = UDim2.new(0, 215, 0, 3)
searchBox.BackgroundColor3 = Theme.card; searchBox.BorderSizePixel = 0
searchBox.Font = Enum.Font.GothamMedium; searchBox.TextSize = 9; searchBox.TextColor3 = Theme.text
searchBox.PlaceholderText = "🔍 Пошук за назвою..."; searchBox.Text = ""
searchBox.ClearTextOnFocus = false; searchBox.Parent = priceBar
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 4)

minPriceBox.FocusLost:Connect(function()
    local n = parsePrice(minPriceBox.Text)
    cfg.minPrice = n
    minPriceBox.Text = formatPrice(n)
    addLog("INFO", "Мінімальна ціна: " .. formatPrice(n))
    if refreshBargainsUI then refreshBargainsUI() end
end)

maxPriceBox.FocusLost:Connect(function()
    local n = parsePrice(maxPriceBox.Text)
    if n > 0 then
        cfg.maxPrice = n
        maxPriceBox.Text = formatPrice(n)
        addLog("INFO", "Максимальна ціна: " .. formatPrice(n))
        if refreshBargainsUI then refreshBargainsUI() end
    end
end)

searchBox.FocusLost:Connect(function()
    if #searchBox.Text > 0 then
        cfg.targetPet = searchBox.Text
        addLog("INFO", "Власний пошук: " .. searchBox.Text)
    else
        cfg.targetPet = "all"
    end
    if refreshBargainsUI then refreshBargainsUI() end
end)

-- Скролл списку знайдених будок
local bargainsScroll = Instance.new("ScrollingFrame")
bargainsScroll.Size = UDim2.new(1, 0, 1, -98); bargainsScroll.Position = UDim2.new(0, 0, 0, 96)
bargainsScroll.BackgroundColor3 = Theme.card; bargainsScroll.BorderSizePixel = 0
bargainsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; bargainsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
bargainsScroll.ScrollBarThickness = 3; bargainsScroll.Parent = boothsPage
Instance.new("UICorner", bargainsScroll).CornerRadius = UDim.new(0, 6)

local bsPad = Instance.new("UIPadding", bargainsScroll)
bsPad.PaddingTop = UDim.new(0, 4); bsPad.PaddingLeft = UDim.new(0, 4); bsPad.PaddingRight = UDim.new(0, 4)
local bsLay = Instance.new("UIListLayout", bargainsScroll); bsLay.Padding = UDim.new(0, 4)

refreshBargainsUI = function(isAuto)
    for _, ch in ipairs(bargainsScroll:GetChildren()) do
        if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
            ch:Destroy()
        end
    end

    local filtered = {}
    for _, b in ipairs(currentBargains) do
        if matchesPetFilter(b.item) and matchesPriceFilter(b.price) then
            if cfg.minDiscount == 0 or b.discount >= cfg.minDiscount then
                table.insert(filtered, b)
            end
        end
    end

    local petNameDisplay = (cfg.targetPet == "all" and "Всі пети") or (cfg.targetPet == "stitched" and "Stitched") or cfg.targetPet
    bStatusLbl.Text = string.format("⚡ Знайдено: %d | %s (💎 %s - %s)", #filtered, petNameDisplay, formatPrice(cfg.minPrice), formatPrice(cfg.maxPrice))

    if not isAuto then
        addLog("INFO", string.format("Фільтр: знайдено %d із %d товарів", #filtered, #currentBargains))
    end

    -- Авто-покупка (якщо увімкнено)
    if cfg.autoBuy and #filtered > 0 then
        for _, topBargain in ipairs(filtered) do
            if topBargain.price <= cfg.maxBudget then
                task.spawn(function()
                    buyBoothItem(topBargain)
                end)
                break
            end
        end
    end

    if #filtered == 0 then
        local emptyCard = Instance.new("Frame")
        emptyCard.Size = UDim2.new(1, 0, 0, 44); emptyCard.BackgroundColor3 = Theme.sidebar; emptyCard.BorderSizePixel = 0
        emptyCard.Parent = bargainsScroll
        Instance.new("UICorner", emptyCard).CornerRadius = UDim.new(0, 6)
        local el = Instance.new("TextLabel", emptyCard)
        el.Size = UDim2.new(1, 0, 1, 0); el.BackgroundTransparency = 1
        el.Font = Enum.Font.GothamMedium; el.TextSize = 10; el.TextColor3 = Theme.textDark
        el.Text = "Нічого не знайдено за фільтром. Спробуйте '🌐 Хоп' або змініть ціну!"
        return
    end

    for _, bData in ipairs(filtered) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 44); card.BackgroundColor3 = Theme.sidebar; card.BorderSizePixel = 0
        card.Parent = bargainsScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        local isSpecial = bData.category:find("Stitched") or bData.category == "Huge"
        local cStroke = Instance.new("UIStroke", card)
        cStroke.Color = isSpecial and Theme.gold or (bData.discount >= 40 and Theme.green or Theme.cardHover)
        cStroke.Thickness = isSpecial and 1.3 or 1

        local icon = (bData.category == "Stitched Cat" and "🐱 ") or (bData.category == "Stitched Dragon" and "🐉 ") or (bData.category == "Huge" and "👑 ") or "📦 "
        local tLabel = Instance.new("TextLabel")
        tLabel.Size = UDim2.new(0.58, 0, 0, 20); tLabel.Position = UDim2.new(0, 6, 0, 2)
        tLabel.BackgroundTransparency = 1; tLabel.Font = Enum.Font.GothamBold; tLabel.TextSize = 10
        tLabel.TextColor3 = isSpecial and Theme.gold or Theme.accent
        tLabel.TextXAlignment = Enum.TextXAlignment.Left
        tLabel.Text = icon .. bData.item
        tLabel.Parent = card

        local pLbl = Instance.new("TextLabel")
        pLbl.Size = UDim2.new(0.58, 0, 0, 18); pLbl.Position = UDim2.new(0, 6, 0, 22)
        pLbl.BackgroundTransparency = 1; pLbl.Font = Enum.Font.Gotham; pLbl.TextSize = 9
        pLbl.TextColor3 = Color3.fromRGB(220, 220, 220); pLbl.TextXAlignment = Enum.TextXAlignment.Left
        local discTxt = (bData.discount > 0) and string.format("🔥 -%d%%", bData.discount) or "Звичайна"
        pLbl.Text = string.format("💎 %s | RAP: %s | %s", formatPrice(bData.price), formatPrice(bData.rap), discTxt)
        pLbl.Parent = card

        -- Кнопка ТП
        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0.18, -2, 0, 28); tpBtn.Position = UDim2.new(0.60, 0, 0, 8)
        tpBtn.BackgroundColor3 = Color3.fromRGB(30, 75, 115); tpBtn.TextColor3 = Color3.fromRGB(220, 240, 255)
        tpBtn.Font = Enum.Font.GothamBold; tpBtn.TextSize = 9; tpBtn.Text = "📍 ТП"
        tpBtn.BorderSizePixel = 0; tpBtn.Parent = card
        Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 5)

        tpBtn.MouseButton1Click:Connect(function()
            teleportToBooth(bData)
        end)

        -- Кнопка Купити
        local buyBtn = Instance.new("TextButton")
        buyBtn.Size = UDim2.new(0.18, -2, 0, 28); buyBtn.Position = UDim2.new(0.80, 0, 0, 8)
        buyBtn.BackgroundColor3 = Color3.fromRGB(40, 115, 65); buyBtn.TextColor3 = Color3.fromRGB(220, 255, 230)
        buyBtn.Font = Enum.Font.GothamBold; buyBtn.TextSize = 9; buyBtn.Text = "💎 Купити"
        buyBtn.BorderSizePixel = 0; buyBtn.Parent = card
        Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 5)

        buyBtn.MouseButton1Click:Connect(function()
            buyBoothItem(bData)
        end)
    end
end

scanBtn.MouseButton1Click:Connect(function()
    scanBtn.Text = "⏳..."
    task.wait(0.05)
    scanAllBooths()
    if refreshBargainsUI then refreshBargainsUI() end
    scanBtn.Text = "🔄 Скан"
end)

-- ==============================================================================
-- 🖥️ ВКЛАДКА 2: СУПЕР КОМП'ЮТЕР / ТЕРМІНАЛ
-- ==============================================================================
local termTop = Instance.new("Frame")
termTop.Size = UDim2.new(1, 0, 0, 70); termTop.BackgroundColor3 = Theme.card; termTop.BorderSizePixel = 0
termTop.Parent = terminalPage
Instance.new("UICorner", termTop).CornerRadius = UDim.new(0, 6)

local ttLbl = Instance.new("TextLabel")
ttLbl.Size = UDim2.new(1, -12, 0, 18); ttLbl.Position = UDim2.new(0, 6, 0, 4)
ttLbl.BackgroundTransparency = 1; ttLbl.Font = Enum.Font.GothamBold; ttLbl.TextSize = 10
ttLbl.TextColor3 = Theme.accent; ttLbl.TextXAlignment = Enum.TextXAlignment.Left
ttLbl.Text = "🖥️ Термінал Снайпер (Пошук кожні 5 сек, без кулдауну 60с)"
ttLbl.Parent = termTop

local targetBox = Instance.new("TextBox")
targetBox.Size = UDim2.new(0.55, 0, 0, 28); targetBox.Position = UDim2.new(0, 6, 0, 30)
targetBox.BackgroundColor3 = Theme.sidebar; targetBox.BorderSizePixel = 0
targetBox.Font = Enum.Font.GothamBold; targetBox.TextSize = 10; targetBox.TextColor3 = Color3.new(1, 1, 1)
targetBox.PlaceholderText = "Ціль: Stitched Cat / Dragon..."; targetBox.Text = cfg.targetPet or "Stitched Cat"
targetBox.ClearTextOnFocus = false; targetBox.Parent = termTop
Instance.new("UICorner", targetBox).CornerRadius = UDim.new(0, 5)

targetBox.FocusLost:Connect(function()
    cfg.targetPet = targetBox.Text
    addLog("INFO", "Ціль терміналу змінена на: " .. targetBox.Text)
end)

termLoopBtn = Instance.new("TextButton")
termLoopBtn.Size = UDim2.new(0.40, -2, 0, 28); termLoopBtn.Position = UDim2.new(0.58, 0, 0, 30)
termLoopBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 120); termLoopBtn.TextColor3 = Color3.fromRGB(230, 210, 255)
termLoopBtn.Font = Enum.Font.GothamBold; termLoopBtn.TextSize = 9
termLoopBtn.Text = "🚀 Швидкий перехват (5с)"
termLoopBtn.BorderSizePixel = 0; termLoopBtn.Parent = termTop
Instance.new("UICorner", termLoopBtn).CornerRadius = UDim.new(0, 5)

termLoopBtn.MouseButton1Click:Connect(function()
    toggleTerminalLoop()
end)

local termInfoBox = Instance.new("TextBox")
termInfoBox.Size = UDim2.new(1, 0, 1, -78); termInfoBox.Position = UDim2.new(0, 0, 0, 76)
termInfoBox.BackgroundColor3 = Theme.card; termInfoBox.BorderSizePixel = 0
termInfoBox.Font = Enum.Font.Code; termInfoBox.TextSize = 9; termInfoBox.TextColor3 = Color3.fromRGB(200, 220, 240)
termInfoBox.TextXAlignment = Enum.TextXAlignment.Left; termInfoBox.TextYAlignment = Enum.TextYAlignment.Top
termInfoBox.ClearTextOnFocus = false; termInfoBox.TextEditable = false
termInfoBox.Text = "ℹ️ ЯК ПРАЦЮЄ ШВИДКИЙ ТЕРМІНАЛ:\n1. Виберіть 'Stitched Cat' або 'Stitched Dragon'.\n2. Натисніть '🚀 Швидкий перехват (5с)'.\n3. Скрипт опитує базу терміналу кожні 5 сек, обходячи кулдаун у 60 сек.\n4. Щойно пет з'являється на будь-якому сервері — скрипт миттєво перекидає вас туди.\n5. Завдяки queue_on_teleport хаб автоматично продовжить роботу на новому сервері!"
termInfoBox.Parent = terminalPage
Instance.new("UICorner", termInfoBox).CornerRadius = UDim.new(0, 6)

-- ==============================================================================
-- 📜 ВКЛАДКА 3: ЛОГИ ТА ПОМИЛКИ (ДЛЯ СКИДАННЯ МЕНІ)
-- ==============================================================================
local lTop = Instance.new("Frame")
lTop.Size = UDim2.new(1, 0, 0, 36); lTop.BackgroundColor3 = Theme.card; lTop.BorderSizePixel = 0
lTop.Parent = logsPage
Instance.new("UICorner", lTop).CornerRadius = UDim.new(0, 6)

logStatsLabel = Instance.new("TextLabel")
logStatsLabel.Size = UDim2.new(0.5, 0, 1, 0); logStatsLabel.Position = UDim2.new(0, 6, 0, 0)
logStatsLabel.BackgroundTransparency = 1; logStatsLabel.Font = Enum.Font.GothamBold; logStatsLabel.TextSize = 9
logStatsLabel.TextColor3 = Theme.gold; logStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
logStatsLabel.Text = "📊 Всього: 0 | 🔴 Помилок: 0"
logStatsLabel.Parent = lTop

local lBtnRow = Instance.new("Frame")
lBtnRow.Size = UDim2.new(0.5, -4, 1, -6); lBtnRow.Position = UDim2.new(0.5, 0, 0, 3)
lBtnRow.BackgroundTransparency = 1; lBtnRow.Parent = lTop
local lbrLay = Instance.new("UIListLayout", lBtnRow)
lbrLay.FillDirection = Enum.FillDirection.Horizontal; lbrLay.Padding = UDim.new(0, 4)

local copyLogsBtn = Instance.new("TextButton")
copyLogsBtn.Size = UDim2.new(0.68, -2, 1, 0); copyLogsBtn.BorderSizePixel = 0
copyLogsBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 80); copyLogsBtn.TextColor3 = Color3.fromRGB(220, 255, 230)
copyLogsBtn.Font = Enum.Font.GothamBold; copyLogsBtn.TextSize = 9; copyLogsBtn.Text = "📋 Скопіювати все"
copyLogsBtn.Parent = lBtnRow
Instance.new("UICorner", copyLogsBtn).CornerRadius = UDim.new(0, 5)

local clearLogsBtn = Instance.new("TextButton")
clearLogsBtn.Size = UDim2.new(0.32, -2, 1, 0); clearLogsBtn.BorderSizePixel = 0
clearLogsBtn.BackgroundColor3 = Color3.fromRGB(130, 45, 55); clearLogsBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
clearLogsBtn.Font = Enum.Font.GothamBold; clearLogsBtn.TextSize = 9; clearLogsBtn.Text = "🗑️ Очистити"
clearLogsBtn.Parent = lBtnRow
Instance.new("UICorner", clearLogsBtn).CornerRadius = UDim.new(0, 5)

copyLogsBtn.MouseButton1Click:Connect(function()
    copyAllLogs()
end)

clearLogsBtn.MouseButton1Click:Connect(function()
    table.clear(logEntries)
    errorCount = 0
    if logStatsLabel then logStatsLabel.Text = "📊 Всього: 0 | 🔴 Помилок: 0" end
    if refreshLogUI then refreshLogUI() end
    addLog("INFO", "Логи очищено")
end)

-- Скролл записів логу
logScrollFrame = Instance.new("ScrollingFrame")
logScrollFrame.Size = UDim2.new(1, 0, 1, -78); logScrollFrame.Position = UDim2.new(0, 0, 0, 40)
logScrollFrame.BackgroundColor3 = Theme.card; logScrollFrame.BorderSizePixel = 0
logScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y; logScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logScrollFrame.ScrollBarThickness = 3; logScrollFrame.Parent = logsPage
Instance.new("UICorner", logScrollFrame).CornerRadius = UDim.new(0, 6)

local lsPad = Instance.new("UIPadding", logScrollFrame)
lsPad.PaddingTop = UDim.new(0, 4); lsPad.PaddingLeft = UDim.new(0, 4); lsPad.PaddingRight = UDim.new(0, 4)
local lsLay = Instance.new("UIListLayout", logScrollFrame); lsLay.Padding = UDim.new(0, 2)

-- Поле виділення тексту для ручного копіювання на телефоні
copyFallbackBox = Instance.new("TextBox")
copyFallbackBox.Size = UDim2.new(1, 0, 0, 32); copyFallbackBox.Position = UDim2.new(0, 0, 1, -34)
copyFallbackBox.BackgroundColor3 = Theme.sidebar; copyFallbackBox.BorderSizePixel = 0
copyFallbackBox.Font = Enum.Font.Code; copyFallbackBox.TextSize = 8; copyFallbackBox.TextColor3 = Theme.gold
copyFallbackBox.PlaceholderText = "Тут з'явиться весь текст логу для копіювання на телефоні..."
copyFallbackBox.ClearTextOnFocus = false; copyFallbackBox.TextEditable = false
copyFallbackBox.Parent = logsPage
Instance.new("UICorner", copyFallbackBox).CornerRadius = UDim.new(0, 4)

refreshLogUI = function()
    if not logsPage.Visible then return end
    for _, ch in ipairs(logScrollFrame:GetChildren()) do
        if ch:IsA("GuiObject") and not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
            ch:Destroy()
        end
    end

    local startIdx = math.max(1, #logEntries - 40)
    for i = startIdx, #logEntries do
        local e = logEntries[i]
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 18)
        row.BackgroundColor3 = (i % 2 == 0) and Theme.card or Theme.sidebar
        row.BorderSizePixel = 0
        row.Parent = logScrollFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 3)

        local col = Theme.accent
        if e.level == "ERROR" then col = Theme.red
        elseif e.level == "WARN" then col = Theme.gold
        elseif e.level == "SUCCESS" then col = Theme.green
        elseif e.level == "ACTION" then col = Theme.purple
        end

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 1, 0); lbl.Position = UDim2.new(0, 3, 0, 0)
        lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.Code; lbl.TextSize = 8
        lbl.TextColor3 = col; lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.format("[%s] [%s] %s", e.time, e.level, e.text)
        lbl.Parent = row
    end
end

-- ==============================================================================
-- ⚡ ВКЛАДКА 4: БУСТ FPS ТА ОПТИМІЗАЦІЯ
-- ==============================================================================
local optGrid = Instance.new("Frame")
optGrid.Size = UDim2.new(1, 0, 1, 0); optGrid.BackgroundTransparency = 1; optGrid.Parent = optPage
local oLay = Instance.new("UIGridLayout", optGrid)
oLay.CellSize = UDim2.new(0.485, 0, 0, 34); oLay.CellPadding = UDim2.new(0.03, 0, 0, 6)

local function createToggle(parent, title, key, callback)
    local btn = Instance.new("TextButton")
    btn.BorderSizePixel = 0; btn.Font = Enum.Font.GothamBold; btn.TextSize = 9
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local function refresh()
        local v = cfg[key]
        btn.BackgroundColor3 = v and Color3.fromRGB(35, 80, 55) or Theme.card
        btn.TextColor3 = v and Theme.green or Theme.textDark
        btn.Text = string.format("%s: %s", title, v and "ВКЛ" or "ВИКЛ")
    end
    refresh()

    btn.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        refresh()
        addLog("INFO", title .. ": " .. (cfg[key] and "ВКЛ" or "ВИКЛ"))
        if callback then callback(cfg[key]) end
    end)
    return btn
end

createToggle(optGrid, "👁️ 3D ESP Будок", "espOn", function(v)
    if v then applyPlazaESP(currentBargains) else clearPlazaESP() end
end)

createToggle(optGrid, "🛡️ Anti-AFK (20 хв)", "antiAfk")

createToggle(optGrid, "⚡ Ліміт 30 FPS", "fpsCap30", function(v)
    pcall(function()
        if setfpscap then setfpscap(v and 30 or 60) end
    end)
end)

createToggle(optGrid, "🥔 Картопляна графіка", "potatoMode", function(v)
    pcall(function()
        for _, obj in ipairs(WS:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Parent:FindFirstChildWhichIsA("Humanoid") then
                obj.Material = v and Enum.Material.SmoothPlastic or Enum.Material.Plastic
            end
        end
    end)
end)

-- ==============================================================================
-- ⚙️ ВКЛАДКА 5: НАЛАШТУВАННЯ
-- ==============================================================================
local cfgScroll = Instance.new("ScrollingFrame")
cfgScroll.Size = UDim2.new(1, 0, 1, 0); cfgScroll.BackgroundColor3 = Theme.card; cfgScroll.BorderSizePixel = 0
cfgScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; cfgScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
cfgScroll.ScrollBarThickness = 3; cfgScroll.Parent = settingsPage
Instance.new("UICorner", cfgScroll).CornerRadius = UDim.new(0, 6)

local csPad = Instance.new("UIPadding", cfgScroll); csPad.PaddingTop = UDim.new(0, 6); csPad.PaddingLeft = UDim.new(0, 6); csPad.PaddingRight = UDim.new(0, 6)
local csLay = Instance.new("UIListLayout", cfgScroll); csLay.Padding = UDim.new(0, 6)

createToggle(cfgScroll, "🔄 Авто-оновлення будок", "autoRefresh")
createToggle(cfgScroll, "💎 Авто-купівля (Auto-Buy)", "autoBuy")

local function createSettingInput(title, defaultVal, onApply)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32); row.BackgroundColor3 = Theme.sidebar; row.BorderSizePixel = 0
    row.Parent = cfgScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 1, 0); lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 9
    lbl.TextColor3 = Theme.text; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = title; lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.3, 0, 0, 22); box.Position = UDim2.new(0.68, 0, 0, 5)
    box.BackgroundColor3 = Theme.card; box.BorderSizePixel = 0
    box.TextColor3 = Theme.gold; box.Font = Enum.Font.GothamBold; box.TextSize = 9
    box.Text = tostring(defaultVal); box.ClearTextOnFocus = false; box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

    box.FocusLost:Connect(function()
        if onApply then onApply(box.Text) end
    end)
end

createSettingInput("Макс. бюджет на авто-покупку:", formatPrice(cfg.maxBudget), function(val)
    local n = parsePrice(val)
    if n > 0 then
        cfg.maxBudget = n
        addLog("INFO", "Бюджет покупки встановлено: " .. formatPrice(n))
    end
end)

createSettingInput("Інтервал авто-оновлення (сек):", tostring(cfg.refreshInterval), function(val)
    local n = tonumber(val)
    if n and n >= 1 then
        cfg.refreshInterval = n
        addLog("INFO", "Інтервал авто-оновлення: " .. n .. " сек")
    end
end)

-- ==============================================================================
-- 🔄 ФОНОВІ ПОТОКИ (АВТО-ОНОВЛЕННЯ ТА ANTI-AFK)
-- ==============================================================================
-- Авто-оновлення будок
task.spawn(function()
    while _G.Pufyftyk_Trade_Loaded do
        task.wait(cfg.refreshInterval or 3.0)
        if cfg.autoRefresh then
            pcall(function()
                scanAllBooths()
                if refreshBargainsUI then refreshBargainsUI(true) end
            end)
        end
    end
end)

-- Anti-AFK
task.spawn(function()
    while _G.Pufyftyk_Trade_Loaded do
        task.wait(60)
        if cfg.antiAfk and VU then
            pcall(function() VU:Idled(Vector2.zero) end)
        end
    end
end)

-- Первинне сканування
task.delay(0.5, function()
    pcall(function()
        addLog("SUCCESS", "Скрипт успішно запущено!")
        scanAllBooths()
        if refreshBargainsUI then refreshBargainsUI() end
    end)
end)

print("[pufyftyk-kvires] Trade Sniper Hub для Delta & PC успішно завантажено!")
StarterGui:SetCore("SendNotification", {
    Title = "🛒 Pufyftyk Trade Sniper",
    Text = "Запущено! Ціль: " .. tostring(cfg.targetPet),
    Duration = 4
})
