--[[ ============================================================
     🚀 PUFYFTYK-KVIRES · PET SIMULATOR 99 TRADE PLAZA & SNIPER HUB (V4.0)
     📱 Повна підтримка Delta Mobile (Android / iOS) та ПК
     🎯 Снайпер Stitched Cat / Dragon, Будки, Термінал та Сервер-Хоп
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
local VU        = pcall(function() return game:GetService("VirtualUser") end) and game:GetService("VirtualUser") or nil

-- Очікування локального гравця
local player = Players.LocalPlayer
if not player then
    repeat task.wait(0.1); player = Players.LocalPlayer until player
end

local camera = WS.CurrentCamera or WS:WaitForChild("Camera")

-- Закриття попередньої копії хабу
if _G.Pufyftyk_Trade_Cleanup then
    pcall(_G.Pufyftyk_Trade_Cleanup)
end
_G.Pufyftyk_Trade_Loaded = true

-- ==============================================================================
-- 🎨 ТЕМА ОФОРМЛЕННЯ
-- ==============================================================================
local Theme = {
    bgDark      = Color3.fromRGB(15, 17, 24),
    bgPanel     = Color3.fromRGB(22, 25, 36),
    bgCard      = Color3.fromRGB(30, 34, 48),
    bgInput     = Color3.fromRGB(18, 20, 28),
    accent      = Color3.fromRGB(150, 75, 255),
    accentGrad  = Color3.fromRGB(0, 210, 255),
    gold        = Color3.fromRGB(255, 185, 45),
    green       = Color3.fromRGB(46, 204, 113),
    red         = Color3.fromRGB(231, 76, 60),
    blue        = Color3.fromRGB(52, 152, 219),
    textWhite   = Color3.fromRGB(250, 250, 252),
    textMuted   = Color3.fromRGB(160, 165, 185),
    border      = Color3.fromRGB(42, 47, 65)
}

-- ==============================================================================
-- ⚙️ КОНФІГУРАЦІЯ
-- ==============================================================================
local cfg = {
    targetPet       = "stitched",         -- "stitched_cat", "stitched_dragon", "stitched", "huge", "all", або кастомний рядок
    targetPetName   = "Stitched (Будь-який)",
    usePriceFilter  = false,              -- За замовчуванням ВИМКНЕНО, щоб бачити ВСІ товари!
    minPrice        = 0,
    maxPrice        = 999999999999,
    autoBuySniper   = false,              -- Автоматична покупка знайденої цілі
    maxAutoBuyPrice = 50000000,           -- Ліміт авто-покупки (50M за замовчуванням)
    autoHopIfNone   = false,              -- Сервер-хоп якщо ціль не знайдено
    scanInterval    = 3.0,                -- Інтервал повторного сканування
    terminalLoop    = false,              -- Авто-пошук через Термінал
    terminalDelay   = 5.0                 -- Інтервал терміналу (секунди)
}

local currentBargains = {}
local isTerminalLoopActive = false
local isAutoBuyRunning = false
local termLoopBtn = nil
local refreshBargainsUI = nil

-- ==============================================================================
-- 🛡️ АНТИ-AFK
-- ==============================================================================
player.Idled:Connect(function()
    pcall(function()
        if VU then
            VU:Button2Down(Vector2.new(0, 0), camera.CFrame)
            task.wait(0.2)
            VU:Button2Up(Vector2.new(0, 0), camera.CFrame)
        end
    end)
end)

-- ==============================================================================
-- 📱 УНІВЕРСАЛЬНИЙ БІНДЕР КНОПОК ДЛЯ СЕНСОРНИХ ЕКРАНІВ (DELTA MOBILE + ПК)
-- ==============================================================================
local function bindButton(btn, callback)
    local debounce = false
    local function fire()
        if debounce then return end
        debounce = true
        task.spawn(function()
            local origColor = btn.BackgroundColor3
            pcall(function()
                btn.BackgroundColor3 = Color3.fromRGB(
                    math.clamp(math.floor(origColor.R * 255 + 35), 0, 255),
                    math.clamp(math.floor(origColor.G * 255 + 35), 0, 255),
                    math.clamp(math.floor(origColor.B * 255 + 35), 0, 255)
                )
            end)
            task.wait(0.12)
            pcall(function() btn.BackgroundColor3 = origColor end)
            task.wait(0.08)
            debounce = false
        end)
        callback()
    end

    btn.Activated:Connect(fire)
    btn.MouseButton1Click:Connect(fire)
end

-- ==============================================================================
-- 📋 СИСТЕМА ЛОГІВ ТА ПЕРЕХОПЛЕННЯ ПОМИЛОК
-- ==============================================================================
local logEntries = {}
local logScrollFrame = nil
local lastLogMsg = ""
local lastLogCount = 1
local lastLogLabel = nil

local function sanitizeMsg(msg)
    if not msg then return "" end
    local s = tostring(msg)
    s = s:gsub("\r\n", " "):gsub("\n", " "):gsub("\r", " ")
    s = s:gsub("\t", " ")
    s = s:gsub("%s+", " ")
    if #s > 140 then
        s = s:sub(1, 137) .. "..."
    end
    return s
end

local function addLog(level, msg)
    local timeStr = os.date("%H:%M:%S")
    local cleanMsg = sanitizeMsg(msg)
    if #cleanMsg == 0 then return end

    if cleanMsg == lastLogMsg and lastLogLabel then
        lastLogCount = lastLogCount + 1
        pcall(function()
            lastLogLabel.Text = string.format("[%s] [%s] %s (x%d)", timeStr, level, cleanMsg, lastLogCount)
        end)
        return
    end

    lastLogMsg = cleanMsg
    lastLogCount = 1

    local entryText = string.format("[%s] [%s] %s", timeStr, level, cleanMsg)
    table.insert(logEntries, { level = level, text = entryText, time = timeStr })
    if #logEntries > 120 then table.remove(logEntries, 1) end

    if logScrollFrame then
        local col = Theme.textMuted
        if level == "SUCCESS" then col = Theme.green
        elseif level == "WARN" then col = Theme.gold
        elseif level == "ERROR" then col = Theme.red
        elseif level == "ACTION" then col = Theme.accent
        elseif level == "ROBLOX" then col = Color3.fromRGB(255, 120, 120)
        end

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextColor3 = col
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        lbl.ClipsDescendants = true
        lbl.Text = entryText
        lbl.Parent = logScrollFrame

        lastLogLabel = lbl

        task.defer(function()
            if logScrollFrame then
                logScrollFrame.CanvasPosition = Vector2.new(0, math.max(0, logScrollFrame.UIListLayout.AbsoluteContentSize.Y - logScrollFrame.AbsoluteSize.Y))
            end
        end)
    end
end

-- Перехоплення системних помилок Roblox
LogService.MessageOut:Connect(function(message, msgType)
    if msgType == Enum.MessageType.MessageError then
        local clean = sanitizeMsg(message)
        if clean:find("BoothSpawns__OLD") or clean:find("Pufyftyk") or clean:find("Trade") or clean:find("Network") then
            addLog("ROBLOX", clean)
        end
    end
end)

local function copyAllLogs()
    local allLines = {}
    table.insert(allLines, "=== PUFYFTYK-KVIRES TRADE HUB V4.0 LOGS ===")
    table.insert(allLines, "Час експорту: " .. os.date("%Y-%m-%d %H:%M:%S") .. " | Сервер: " .. tostring(game.JobId))
    table.insert(allLines, "Кількість записів: " .. tostring(#logEntries))
    table.insert(allLines, "--------------------------------------------------")
    for _, e in ipairs(logEntries) do
        table.insert(allLines, e.text)
    end
    local combined = table.concat(allLines, "\n")
    local copied = false
    if setclipboard then pcall(setclipboard, combined); copied = true
    elseif toclipboard then pcall(toclipboard, combined); copied = true
    end
    addLog("SUCCESS", string.format("Логи збережено (%d рядків). Буфер: %s", #allLines, copied and "УСПІШНО" or "ПОТРІБЕН setclipboard"))
    return combined
end

-- ==============================================================================
-- 💰 ПАРСИНГ ТА ФОРМАТУВАННЯ ЦІНИ
-- ==============================================================================
local function parsePrice(str)
    if type(str) == "number" then return str end
    if not str then return 0 end
    local s = tostring(str):gsub(",", ""):gsub("💎", ""):gsub("%s+", ""):lower()
    local numPart = s:match("[%d%.]+")
    if not numPart then return 0 end
    local num = tonumber(numPart) or 0
    if s:find("b") then num = num * 1000000000
    elseif s:find("m") then num = num * 1000000
    elseif s:find("k") then num = num * 1000
    end
    return math.floor(num)
end

local function formatPrice(n)
    n = tonumber(n) or 0
    if n >= 1000000000 then return string.format("%.2fB", n / 1000000000)
    elseif n >= 1000000 then return string.format("%.2fM", n / 1000000)
    elseif n >= 1000 then return string.format("%.1fK", n / 1000)
    else return tostring(n)
    end
end

-- ==============================================================================
-- 🔍 ПЕРЕВІРКА ВІДПОВІДНОСТІ ЦІЛІ ТА ЦІНИ
-- ==============================================================================
local function matchesPetTarget(itemId, displayName)
    local t = cfg.targetPet or "stitched"
    if t == "all" then return true end

    local checkStr = (tostring(itemId) .. " " .. tostring(displayName)):lower()

    if t == "stitched_cat" then
        return checkStr:find("stitched") and checkStr:find("cat")
    elseif t == "stitched_dragon" then
        return checkStr:find("stitched") and checkStr:find("dragon")
    elseif t == "stitched" then
        return checkStr:find("stitched")
    elseif t == "huge" then
        return checkStr:find("huge")
    else
        return checkStr:find(t:lower()) ~= nil
    end
end

local function matchesPriceRange(price)
    if not cfg.usePriceFilter then return true end
    price = tonumber(price) or 0
    if price < cfg.minPrice then return false end
    if cfg.maxPrice > 0 and price > cfg.maxPrice then return false end
    return true
end

-- ==============================================================================
-- 🌐 БАГАТОРІВНЕВИЙ HTTP КЛІЄНТ ДЛЯ DELTA MOBILE ТА ПК
-- ==============================================================================
local function httpGetSafe(url)
    local requester = syn and syn.request or http_request or request or (http and http.request)
    if requester then
        local ok, res = pcall(function()
            return requester({ Url = url, Method = "GET" })
        end)
        if ok and res and res.Body then return res.Body end
    end
    local ok2, res2 = pcall(function() return game:HttpGet(url, true) end)
    if ok2 and res2 then return res2 end
    return nil
end

-- ==============================================================================
-- 🚀 СЕРВЕР-ХОП (SERVER HOPPING)
-- ==============================================================================
local function setupQueueTeleport()
    pcall(function()
        local queue = queue_on_teleport or (syn and syn.queue_on_teleport)
        if queue then
            queue([[
                task.spawn(function()
                    task.wait(2.5)
                    pcall(function()
                        if readfile and pcall(readfile, "pufyftyk_mobile.lua") then
                            loadstring(readfile("pufyftyk_mobile.lua"))()
                        else
                            loadstring(game:HttpGet("https://raw.githubusercontent.com/pyfustuk/Fly-GUI/refs/heads/main/flu/pet99.lua?t=" .. tostring(tick())))()
                        end
                    end)
                end)
            ]])
        end
    end)
end

local function serverHop()
    local placeId = 15502339080 -- Trading Plaza PlaceId
    local currentJobId = game.JobId

    addLog("ACTION", "Початок пошуку нового сервера Трейд Плази...")
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "🌐 Сервер-Хоп",
            Text = "Пошук населеного сервера Плази...",
            Duration = 3
        })
    end)

    -- Використовуємо RoProxy та офіційний API з випадковою сторінкою
    local endpoints = {
        string.format("https://games.roproxy.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", tostring(placeId)),
        string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", tostring(placeId))
    }

    local serverList = {}
    for _, ep in ipairs(endpoints) do
        local body = httpGetSafe(ep)
        if body then
            local decOk, data = pcall(function() return HttpS:JSONDecode(body) end)
            if decOk and data and data.data and #data.data > 0 then
                for _, s in ipairs(data.data) do
                    if s.id ~= currentJobId and tonumber(s.playing) and tonumber(s.maxPlayers) then
                        local playing = tonumber(s.playing)
                        local maxP = tonumber(s.maxPlayers)
                        if playing >= 12 and playing < maxP - 2 then
                            table.insert(serverList, s.id)
                        end
                    end
                end
                if #serverList > 0 then break end
            end
        end
    end

    if #serverList > 0 then
        local chosen = serverList[math.random(1, #serverList)]
        addLog("ACTION", "Стрибок на сервер Трейд Плази: " .. tostring(chosen))
        setupQueueTeleport()
        local tpOk = pcall(function() TeleportS:TeleportToPlaceInstance(placeId, chosen, player) end)
        if tpOk then return true end
    end

    addLog("WARN", "Прямий стрибок через TeleportService:Teleport...")
    setupQueueTeleport()
    pcall(function() TeleportS:Teleport(placeId, player) end)
    return false
end

-- ==============================================================================
-- 🛒 АВТО-ПОКУПКА ТА ПОКУПКА В 1 КЛІК ЧЕРЕЗ РЕМОУТ
-- ==============================================================================
local function buyBoothItem(bData)
    if not bData then return false end
    local net = RepS:FindFirstChild("Network")
    if not net then
        addLog("ERROR", "ReplicatedStorage.Network не знайдено!")
        return false
    end

    local buyRem = net:FindFirstChild("Booths_RequestPurchase")
    if not buyRem or not buyRem:IsA("RemoteFunction") then
        addLog("ERROR", "Ремоут Booths_RequestPurchase відсутній!")
        return false
    end

    -- Визначаємо ID продавця (UserId числом або нікнейм)
    local sellerId = tonumber(bData.ownerId) or tonumber(bData.owner)
    if not sellerId and typeof(bData.owner) == "string" then
        local p = Players:FindFirstChild(bData.owner)
        if p then sellerId = p.UserId end
    end

    addLog("ACTION", string.format("Спроба покупки %s за 💎 %s у ID:%s...", bData.displayName, formatPrice(bData.price), tostring(sellerId or bData.owner)))

    local ok, res = pcall(function()
        if sellerId then
            return buyRem:InvokeServer(sellerId, bData.uid)
        else
            return buyRem:InvokeServer(bData.owner, bData.uid)
        end
    end)

    if ok then
        local resStr = tostring(res)
        if res == true or resStr:lower():find("true") or resStr:lower():find("success") then
            addLog("SUCCESS", string.format("🎉 УСПІХ! Придбано %s за 💎 %s!", bData.displayName, formatPrice(bData.price)))
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "🎉 СНАЙПЕР СПРАЦЮВАВ!",
                    Text = string.format("Куплено %s за %s 💎!", bData.displayName, formatPrice(bData.price)),
                    Duration = 5
                })
            end)
            return true
        else
            addLog("WARN", string.format("Відповідь на покупку %s: %s", bData.displayName, resStr))
        end
    else
        addLog("ERROR", string.format("Помилка ремоута покупки: %s", tostring(res)))
    end
    return false
end

-- ==============================================================================
-- 📍 ТЕЛЕПОРТАЦІЯ ДО БУДКИ
-- ==============================================================================
local function getSafePadCFrame(booth)
    if not booth then return nil end
    local pad = booth:FindFirstChild("Pad") or booth:FindFirstChild("Stand")
    if pad and pad:IsA("BasePart") then
        return pad.CFrame + Vector3.new(0, 3, 0)
    end
    for _, ch in ipairs(booth:GetChildren()) do
        if ch.Name:lower():find("pad") and ch:IsA("BasePart") then
            return ch.CFrame + Vector3.new(0, 3, 0)
        end
    end
    if booth:IsA("Model") then
        local cf, size = booth:GetBoundingBox()
        return cf + Vector3.new(0, size.Y / 2 + 2, 0)
    elseif booth:IsA("BasePart") then
        return booth.CFrame + Vector3.new(0, 3, 0)
    end
    return nil
end

local function teleportToBooth(bData)
    if not bData then return end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        addLog("ERROR", "HumanoidRootPart не знайдено для телепортації!")
        return
    end

    if bData.cframe then
        hrp.CFrame = bData.cframe
        addLog("SUCCESS", "Телепортовано до будки з " .. bData.displayName)
        return
    end

    if bData.booth then
        local cf = getSafePadCFrame(bData.booth)
        if cf then
            hrp.CFrame = cf
            addLog("SUCCESS", "Телепортовано на майданчик будки!")
            return
        end
    end

    -- Пошук будки власника у Workspace
    local things = WS:FindFirstChild("__THINGS")
    local boothsFolder = (things and things:FindFirstChild("Booths")) or WS:FindFirstChild("Booths")
    if boothsFolder then
        for _, b in ipairs(boothsFolder:GetChildren()) do
            local o = b:GetAttribute("Owner") or b:GetAttribute("Player") or b.Name
            if tostring(o):lower() == tostring(bData.owner):lower() or tostring(o) == tostring(bData.ownerId) then
                local cf = getSafePadCFrame(b)
                if cf then
                    hrp.CFrame = cf
                    addLog("SUCCESS", "Знайдено будку " .. tostring(o) .. " та здійснено ТП!")
                    return
                end
            end
        end
    end

    addLog("WARN", "Координати будки не знайдено у 3D світі.")
end

-- ==============================================================================
-- 🔍 СКАНИРОВКА БУДОК (СЕРВЕРНИЙ СТАН + WORKSPACE)
-- ==============================================================================
local function parseSingleListing(uid, val, ownerId, boothModel)
    if type(val) ~= "table" then return nil end

    local price = tonumber(val.DiamondCost or val.Cost or val.Price or val.Diamonds) or 0
    local itemData = val.ItemData
    local data = (type(itemData) == "table" and itemData.data) or itemData or val.data or val
    local class = (type(itemData) == "table" and itemData.class) or val.class or "Pet"

    local itemId = nil
    if type(data) == "table" then
        itemId = data.id or data.Id or data.Name or data._id or data.item
    elseif type(data) == "string" then
        itemId = data
    end
    if not itemId and val.id then itemId = val.id end
    if not itemId and val.Name then itemId = val.Name end

    if itemId and price > 0 then
        local version = (type(data) == "table" and data.pt) or 0
        local shiny = (type(data) == "table" and data.sh) or false
        local amount = (type(data) == "table" and tonumber(data._am)) or 1

        local prefix = ""
        if shiny then prefix = "✨ Shiny " end
        if version == 1 then prefix = prefix .. "🌟 Golden "
        elseif version == 2 then prefix = prefix .. "🌈 Rainbow " end

        local dispName = prefix .. tostring(itemId)
        local unitPrice = math.floor(price / math.max(1, amount))

        -- Пошук CFrame для будки
        local cf = boothModel and getSafePadCFrame(boothModel) or nil

        return {
            uid          = tostring(uid),
            id           = tostring(itemId),
            displayName  = dispName,
            price        = price,
            unitPrice    = unitPrice,
            amount       = amount,
            ownerId      = tonumber(ownerId) or 0,
            owner        = tostring(ownerId),
            class        = tostring(class),
            booth        = boothModel,
            cframe       = cf
        }
    end
    return nil
end

local function scanAllBooths()
    local results = {}
    local seenUIDs = {}

    -- Карта будок у Workspace для швидкого пошуку CFrame
    local boothModelsByOwner = {}
    local things = WS:FindFirstChild("__THINGS")
    local boothsFolder = (things and things:FindFirstChild("Booths")) or WS:FindFirstChild("Booths")
    if boothsFolder then
        for _, b in ipairs(boothsFolder:GetChildren()) do
            local o = b:GetAttribute("Owner") or b:GetAttribute("Player") or b.Name
            if o then
                boothModelsByOwner[tostring(o):lower()] = b
            end
        end
    end

    -- 1. Офіційний серверний стан (RemoteFunction Booths_GetInitialState)
    pcall(function()
        local net = RepS:FindFirstChild("Network")
        local getInit = net and net:FindFirstChild("Booths_GetInitialState")
        if getInit and getInit:IsA("RemoteFunction") then
            local state = getInit:InvokeServer()
            if state and type(state) == "table" then
                for ownerKey, bInfo in pairs(state) do
                    if type(bInfo) == "table" then
                        local boothModel = boothModelsByOwner[tostring(ownerKey):lower()]
                        local listings = bInfo.Listings or bInfo.Items or bInfo
                        if type(listings) == "table" then
                            for uidKey, itemEntry in pairs(listings) do
                                local itemObj = parseSingleListing(uidKey, itemEntry, ownerKey, boothModel)
                                if itemObj and not seenUIDs[itemObj.uid] then
                                    seenUIDs[itemObj.uid] = true
                                    table.insert(results, itemObj)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    -- 2. Сканування фізичних моделей будок у Workspace якщо стан не дав результатів
    if #results == 0 and boothsFolder then
        for _, b in ipairs(boothsFolder:GetChildren()) do
            pcall(function()
                local owner = b:GetAttribute("Owner") or b:GetAttribute("Player") or b.Name
                for _, d in ipairs(b:GetDescendants()) do
                    if d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                        local txt = ""
                        local price = 0
                        for _, t in ipairs(d:GetDescendants()) do
                            if t:IsA("TextLabel") or t:IsA("TextButton") then
                                local text = t.Text
                                if text:find("💎") or text:lower():find("price") or text:match("%d+[kmbKMB]") then
                                    price = parsePrice(text)
                                elseif #text >= 3 and not text:lower():find("buy") and not text:lower():find("pad") then
                                    txt = text
                                end
                            end
                        end
                        if #txt > 0 and price > 0 then
                            local uid = d.Name .. "_" .. tostring(price)
                            if not seenUIDs[uid] then
                                seenUIDs[uid] = true
                                table.insert(results, {
                                    uid = uid,
                                    id = txt,
                                    displayName = txt,
                                    price = price,
                                    unitPrice = price,
                                    amount = 1,
                                    ownerId = 0,
                                    owner = tostring(owner),
                                    class = "Pet",
                                    booth = b,
                                    cframe = getSafePadCFrame(b)
                                })
                            end
                        end
                    end
                end
            end)
        end
    end

    -- Фільтрація за ціллю та ціною
    local filtered = {}
    for _, item in ipairs(results) do
        if matchesPetTarget(item.id, item.displayName) and matchesPriceRange(item.price) then
            table.insert(filtered, item)
        end
    end

    -- Сортування за ціною (від найдешевшого)
    table.sort(filtered, function(a, b) return a.price < b.price end)

    currentBargains = filtered

    -- Перевірка авто-покупки
    if cfg.autoBuySniper and not isAutoBuyRunning and #filtered > 0 then
        local cheapest = filtered[1]
        if cheapest.price <= cfg.maxAutoBuyPrice then
            isAutoBuyRunning = true
            task.spawn(function()
                buyBoothItem(cheapest)
                task.wait(1.0)
                isAutoBuyRunning = false
            end)
        end
    end

    return filtered, #results
end

-- ==============================================================================
-- ⚡ СЛУХАЧ МИТТЄВИХ ПОДІЙ СЕРВЕРА (BOOTHS_BROADCAST SNIPER)
-- ==============================================================================
pcall(function()
    local net = RepS:FindFirstChild("Network")
    if net then
        local bCast = net:FindFirstChild("Booths_Broadcast")
        if bCast and bCast:IsA("RemoteEvent") then
            addLog("SUCCESS", "Слухач Booths_Broadcast успішно підключено!")
            bCast.OnClientEvent:Connect(function(username, message)
                if type(message) == "table" and message["Listings"] then
                    local ownerId = message["PlayerID"] or username
                    for uid, listing in pairs(message["Listings"]) do
                        local itemObj = parseSingleListing(uid, listing, ownerId, nil)
                        if itemObj and matchesPetTarget(itemObj.id, itemObj.displayName) then
                            addLog("ACTION", string.format("⚡ НОВИЙ ЛОТ: %s за 💎 %s у %s!", itemObj.displayName, formatPrice(itemObj.price), tostring(ownerId)))
                            if cfg.autoBuySniper and itemObj.price <= cfg.maxAutoBuyPrice then
                                addLog("ACTION", "⚡ МИТТЄВИЙ АВТО-СНАЙП В ЛІЧЕНІ МІЛІСЕКУНДИ...")
                                task.spawn(function()
                                    buyBoothItem(itemObj)
                                end)
                            end
                        end
                    end
                    task.delay(0.2, function()
                        if refreshBargainsUI then refreshBargainsUI(true) end
                    end)
                end
            end)
        end
    end
end)

-- ==============================================================================
-- 🖥️ ТЕРМІНАЛ / СУПЕР КОМП'ЮТЕР СНАЙПЕР (5 СЕК)
-- ==============================================================================
local function toggleTerminalLoop()
    isTerminalLoopActive = not isTerminalLoopActive
    if termLoopBtn then
        termLoopBtn.Text = isTerminalLoopActive and "⏹ Зупинити Термінал" or "🚀 Швидкий перехват (5с)"
        termLoopBtn.BackgroundColor3 = isTerminalLoopActive and Theme.red or Color3.fromRGB(110, 50, 180)
    end

    if isTerminalLoopActive then
        addLog("ACTION", "Запущено швидкий пошук терміналу кожні 5 сек...")
        task.spawn(function()
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "🖥️ Супер Комп'ютер",
                    Text = "Запущено безперервний пошук (кожні 5с)!",
                    Duration = 4
                })
            end)

            local cycle = 0
            while isTerminalLoopActive and _G.Pufyftyk_Trade_Loaded do
                cycle = cycle + 1
                local query = "Stitched Cat"
                local t = cfg.targetPet or "stitched"
                if t == "stitched_dragon" then query = "Stitched Dragon"
                elseif t == "stitched" then
                    query = (cycle % 2 == 1) and "Stitched Cat" or "Stitched Dragon"
                elseif t == "huge" then query = "Huge"
                elseif t ~= "all" then query = t
                end

                addLog("INFO", "Термінал: пошук '" .. query .. "'...")

                pcall(function()
                    local net = RepS:FindFirstChild("Network")
                    if net then
                        local termRem = net:FindFirstChild("TradingTerminal_Search") or net:FindFirstChild("TradingTerminal")
                        if termRem and termRem:IsA("RemoteFunction") then
                            local res = termRem:InvokeServer(query)
                            if res then
                                addLog("INFO", "Відповідь терміналу: " .. tostring(res))
                                if type(res) == "table" and (res.JobId or res.Server) then
                                    local jId = res.JobId or res.Server
                                    addLog("SUCCESS", "Термінал знайшов сервер з " .. query .. "! Перехід...")
                                    setupQueueTeleport()
                                    TeleportS:TeleportToPlaceInstance(15502339080, jId, player)
                                    isTerminalLoopActive = false
                                    return
                                end
                            end
                        end
                    end
                end)

                -- Авто-підтвердження телепорту з вікна терміналу гри в PlayerGui
                pcall(function()
                    local pGui = player:FindFirstChild("PlayerGui")
                    if pGui then
                        for _, g in ipairs(pGui:GetDescendants()) do
                            if g:IsA("TextButton") and g.Visible then
                                local txt = g.Text:lower()
                                if txt:find("teleport") or txt:find("join") or txt:find("yes") then
                                    addLog("SUCCESS", "Знайдено кнопку підтвердження телепорту в терміналі!")
                                    if firesignal then firesignal(g.Activated or g.MouseButton1Click) end
                                    setupQueueTeleport()
                                    isTerminalLoopActive = false
                                    return
                                end
                            end
                        end
                    end
                end)

                task.wait(cfg.terminalDelay)
            end
        end)
    else
        addLog("INFO", "Швидкий термінал зупинено.")
    end
end

-- ==============================================================================
-- 🖥️ СТВОРЕННЯ ГРАФІЧНОГО ІНТЕРФЕЙСУ (GUI)
-- ==============================================================================
local function getGuiParent()
    local ok, res = pcall(function() return gethui() end)
    if ok and res then return res end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then return core end
    return player:WaitForChild("PlayerGui")
end

local sg = Instance.new("ScreenGui")
sg.Name = "PufyftykTradeHubV4"
sg.ResetOnSpawn = false
pcall(function() sg.Parent = getGuiParent() end)

local vp = camera.ViewportSize
local isSmall = vp.X < 850 or vp.Y < 550
local winW = isSmall and math.clamp(vp.X - 20, 310, 480) or 560
local winH = isSmall and math.clamp(vp.Y - 40, 360, 460) or 440

local win = Instance.new("Frame")
win.Name = "MainWindow"
win.Size = UDim2.new(0, winW, 0, winH)
win.Position = UDim2.new(0.5, -math.floor(winW / 2), 0.5, -math.floor(winH / 2))
win.BackgroundColor3 = Theme.bgDark
win.BorderSizePixel = 0
win.Active = true
win.Draggable = true
win.ClipsDescendants = true
win.Parent = sg
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)

local winStroke = Instance.new("UIStroke", win)
winStroke.Color = Theme.accent
winStroke.Thickness = 1.6

-- ==============================================================================
-- 🔘 ПЛАВАЮЧА КНОПКА ЗГОРТАННЯ/РОЗГОРТАННЯ
-- ==============================================================================
local minBtn = Instance.new("TextButton")
minBtn.Name = "PufyftykToggleBtn"
minBtn.Size = UDim2.new(0, 46, 0, 46)
minBtn.Position = UDim2.new(0, 16, 0.45, 0)
minBtn.BackgroundColor3 = Theme.bgPanel
minBtn.Text = "🛒"
minBtn.TextSize = 22
minBtn.Font = Enum.Font.GothamBold
minBtn.TextColor3 = Theme.textWhite
minBtn.Active = true
minBtn.Draggable = true
minBtn.Parent = sg
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 23)
local minStroke = Instance.new("UIStroke", minBtn)
minStroke.Color = Theme.accent
minStroke.Thickness = 2

bindButton(minBtn, function()
    win.Visible = not win.Visible
    addLog("INFO", win.Visible and "Вікно хабу розгорнуто" or "Вікно хабу сховано (натисніть 🛒 для відкриття)")
end)

-- Верхня панель (Header)
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = Theme.bgPanel
header.BorderSizePixel = 0
header.Parent = win
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Theme.textWhite
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "🛒 PUFYFTYK · TRADE SNIPER V4.0 (DELTA)"
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3 = Theme.bgCard
closeBtn.Text = "—"
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Theme.textMuted
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

bindButton(closeBtn, function()
    win.Visible = false
    addLog("INFO", "Вікно сховано. Натисніть '🛒' на екрані, щоб відкрити знову!")
end)

-- Навігаційні вкладки (Tabs Header)
local tabNav = Instance.new("Frame")
tabNav.Size = UDim2.new(1, -20, 0, 34)
tabNav.Position = UDim2.new(0, 10, 0, 48)
tabNav.BackgroundTransparency = 1
tabNav.Parent = win

local tabLayout = Instance.new("UIListLayout", tabNav)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -20, 1, -92)
container.Position = UDim2.new(0, 10, 0, 86)
container.BackgroundTransparency = 1
container.Parent = win

local tabs = {}
local tabButtons = {}

local function createTab(name, icon)
    local page = Instance.new("Frame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = container

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.24, -4, 1, 0)
    btn.BackgroundColor3 = Theme.bgPanel
    btn.Text = icon .. " " .. name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Theme.textMuted
    btn.Parent = tabNav
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Theme.border

    bindButton(btn, function()
        for tName, p in pairs(tabs) do
            p.Visible = (tName == name)
            tabButtons[tName].BackgroundColor3 = (tName == name) and Theme.accent or Theme.bgPanel
            tabButtons[tName].TextColor3 = (tName == name) and Theme.textWhite or Theme.textMuted
        end
    end)

    tabs[name] = page
    tabButtons[name] = btn
    return page
end

local marketTab   = createTab("Ринок", "🎯")
local settingsTab = createTab("Ціль/Ціна", "⚙️")
local terminalTab = createTab("Термінал", "🖥️")
local logsTab     = createTab("Логи", "📋")

-- Активація першої вкладки
tabs["Ринок"].Visible = true
tabButtons["Ринок"].BackgroundColor3 = Theme.accent
tabButtons["Ринок"].TextColor3 = Theme.textWhite

-- ==============================================================================
-- 🎯 ВКЛАДКА 1: РИНОК & СПИСОК ЗНАЙДЕНИХ ТОВАРІВ
-- ==============================================================================
local marketTopBar = Instance.new("Frame")
marketTopBar.Size = UDim2.new(1, 0, 0, 36)
marketTopBar.BackgroundTransparency = 1
marketTopBar.Parent = marketTab

local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(0.48, -4, 1, 0)
scanBtn.Position = UDim2.new(0, 0, 0, 0)
scanBtn.BackgroundColor3 = Theme.accent
scanBtn.Text = "🔄 Сканувати зараз"
scanBtn.Font = Enum.Font.GothamBold
scanBtn.TextSize = 12
scanBtn.TextColor3 = Theme.textWhite
scanBtn.Parent = marketTopBar
Instance.new("UICorner", scanBtn).CornerRadius = UDim.new(0, 8)

local autoBuyBtn = Instance.new("TextButton")
autoBuyBtn.Size = UDim2.new(0.5, -4, 1, 0)
autoBuyBtn.Position = UDim2.new(0.5, 2, 0, 0)
autoBuyBtn.BackgroundColor3 = cfg.autoBuySniper and Theme.green or Theme.bgPanel
autoBuyBtn.Text = cfg.autoBuySniper and "⚡ Авто-Снайпер: ВКЛ" or "⚡ Авто-Снайпер: ВИКЛ"
autoBuyBtn.Font = Enum.Font.GothamBold
autoBuyBtn.TextSize = 12
autoBuyBtn.TextColor3 = Theme.textWhite
autoBuyBtn.Parent = marketTopBar
Instance.new("UICorner", autoBuyBtn).CornerRadius = UDim.new(0, 8)
local autoBuyStroke = Instance.new("UIStroke", autoBuyBtn)
autoBuyStroke.Color = Theme.border

bindButton(autoBuyBtn, function()
    cfg.autoBuySniper = not cfg.autoBuySniper
    autoBuyBtn.BackgroundColor3 = cfg.autoBuySniper and Theme.green or Theme.bgPanel
    autoBuyBtn.Text = cfg.autoBuySniper and "⚡ Авто-Снайпер: ВКЛ" or "⚡ Авто-Снайпер: ВИКЛ"
    addLog("ACTION", "Режим Авто-Снайпера: " .. (cfg.autoBuySniper and "УВІМКНЕНО (ліміт " .. formatPrice(cfg.maxAutoBuyPrice) .. ")" or "ВИМКНЕНО"))
end)

local targetInfoLbl = Instance.new("TextLabel")
targetInfoLbl.Size = UDim2.new(1, 0, 0, 20)
targetInfoLbl.Position = UDim2.new(0, 0, 0, 38)
targetInfoLbl.BackgroundTransparency = 1
targetInfoLbl.Font = Enum.Font.GothamMedium
targetInfoLbl.TextSize = 11
targetInfoLbl.TextColor3 = Theme.gold
targetInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
targetInfoLbl.Text = "🎯 Пошук: " .. cfg.targetPetName .. " | Фільтр ціни: ВИМКНЕНО"
targetInfoLbl.Parent = marketTab

local marketScroll = Instance.new("ScrollingFrame")
marketScroll.Size = UDim2.new(1, 0, 1, -62)
marketScroll.Position = UDim2.new(0, 0, 0, 60)
marketScroll.BackgroundTransparency = 1
marketScroll.ScrollBarThickness = 5
marketScroll.ScrollBarImageColor3 = Theme.accent
marketScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
marketScroll.Parent = marketTab

local marketLayout = Instance.new("UIListLayout", marketScroll)
marketLayout.Padding = UDim.new(0, 6)

refreshBargainsUI = function(isAuto)
    local items, totalFound = scanAllBooths()
    targetInfoLbl.Text = string.format("🎯 Ціль: %s | Знайдено: %d із %d лотів на сервері", cfg.targetPetName, #items, totalFound)

    if not isAuto then
        addLog("INFO", string.format("Результат сканування: %d з %d лотів відповідають цілі", #items, totalFound))
    end

    for _, ch in ipairs(marketScroll:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end

    if #items == 0 then
        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, 0, 0, 80)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Font = Enum.Font.GothamMedium
        emptyLbl.TextSize = 12
        emptyLbl.TextColor3 = Theme.textMuted
        emptyLbl.Text = "Товарів не знайдено на цьому сервері.\nНатисніть 'Термінал' або 'Сервер-Хоп' для пошуку!"
        emptyLbl.Parent = marketScroll
        marketScroll.CanvasSize = UDim2.new(0, 0, 0, 90)
        return
    end

    local totalH = 0
    for _, bData in ipairs(items) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -6, 0, 54)
        card.BackgroundColor3 = Theme.bgPanel
        card.Parent = marketScroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
        local cardStroke = Instance.new("UIStroke", card)
        cardStroke.Color = Theme.border

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.55, -8, 0, 24)
        nameLbl.Position = UDim2.new(0, 10, 0, 4)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 13
        nameLbl.TextColor3 = Theme.textWhite
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ClipsDescendants = true
        nameLbl.Text = bData.displayName
        nameLbl.Parent = card

        local priceLbl = Instance.new("TextLabel")
        priceLbl.Size = UDim2.new(0.55, -8, 0, 20)
        priceLbl.Position = UDim2.new(0, 10, 0, 28)
        priceLbl.BackgroundTransparency = 1
        priceLbl.Font = Enum.Font.GothamBold
        priceLbl.TextSize = 12
        priceLbl.TextColor3 = Theme.gold
        priceLbl.TextXAlignment = Enum.TextXAlignment.Left
        priceLbl.Text = "💎 " .. formatPrice(bData.price) .. (bData.amount > 1 and (" (" .. tostring(bData.amount) .. " шт)") or "")
        priceLbl.Parent = card

        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0, 68, 0, 36)
        tpBtn.Position = UDim2.new(1, -150, 0, 9)
        tpBtn.BackgroundColor3 = Theme.blue
        tpBtn.Text = "📍 ТП"
        tpBtn.Font = Enum.Font.GothamBold
        tpBtn.TextSize = 12
        tpBtn.TextColor3 = Theme.textWhite
        tpBtn.Parent = card
        Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)

        bindButton(tpBtn, function()
            teleportToBooth(bData)
        end)

        local buyBtn = Instance.new("TextButton")
        buyBtn.Size = UDim2.new(0, 72, 0, 36)
        buyBtn.Position = UDim2.new(1, -78, 0, 9)
        buyBtn.BackgroundColor3 = Theme.green
        buyBtn.Text = "🛒 Купити"
        buyBtn.Font = Enum.Font.GothamBold
        buyBtn.TextSize = 12
        buyBtn.TextColor3 = Theme.textWhite
        buyBtn.Parent = card
        Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 6)

        bindButton(buyBtn, function()
            buyBoothItem(bData)
        end)

        totalH = totalH + 60
    end
    marketScroll.CanvasSize = UDim2.new(0, 0, 0, totalH + 10)
end

bindButton(scanBtn, function()
    refreshBargainsUI(false)
end)

-- ==============================================================================
-- ⚙️ ВКЛАДКА 2: НАЛАШТУВАННЯ ЦІЛІ ТА ЦІНОВОГО ДІАПАЗОНУ
-- ==============================================================================
local settingsScroll = Instance.new("ScrollingFrame")
settingsScroll.Size = UDim2.new(1, 0, 1, 0)
settingsScroll.BackgroundTransparency = 1
settingsScroll.ScrollBarThickness = 4
settingsScroll.CanvasSize = UDim2.new(0, 0, 0, 380)
settingsScroll.Parent = settingsTab

local setList = Instance.new("UIListLayout", settingsScroll)
setList.Padding = UDim.new(0, 8)

local function createSectionHeader(titleText)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -6, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextColor3 = Theme.accentGrad
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = titleText
    lbl.Parent = settingsScroll
end

createSectionHeader("🎯 Швидкий вибір пета для пошуку:")

local presetGrid = Instance.new("Frame")
presetGrid.Size = UDim2.new(1, -6, 0, 78)
presetGrid.BackgroundTransparency = 1
presetGrid.Parent = settingsScroll

local presetBtns = {
    { text = "🐱 Stitched Cat", key = "stitched_cat", name = "Stitched Cat" },
    { text = "🐲 Stitched Dragon", key = "stitched_dragon", name = "Stitched Dragon" },
    { text = "✨ Будь-який Stitched", key = "stitched", name = "Stitched (Cat/Dragon)" },
    { text = "⭐ Усі Huge пети", key = "huge", name = "Huge Пети" },
    { text = "💎 Усі товари на ринку", key = "all", name = "Усі товари" }
}

for i, p in ipairs(presetBtns) do
    local pBtn = Instance.new("TextButton")
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    pBtn.Size = UDim2.new(0.485, -2, 0, 22)
    pBtn.Position = UDim2.new(col * 0.505, 0, 0, row * 26)
    pBtn.BackgroundColor3 = (cfg.targetPet == p.key) and Theme.accent or Theme.bgPanel
    pBtn.Text = p.text
    pBtn.Font = Enum.Font.GothamMedium
    pBtn.TextSize = 11
    pBtn.TextColor3 = Theme.textWhite
    pBtn.Parent = presetGrid
    Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 6)

    bindButton(pBtn, function()
        cfg.targetPet = p.key
        cfg.targetPetName = p.name
        for _, other in ipairs(presetGrid:GetChildren()) do
            if other:IsA("TextButton") then other.BackgroundColor3 = Theme.bgPanel end
        end
        pBtn.BackgroundColor3 = Theme.accent
        addLog("INFO", "Змінено ціль пошуку: " .. p.name)
        if refreshBargainsUI then refreshBargainsUI(false) end
    end)
end

-- Власне поле вводу назви
local customTargetFrame = Instance.new("Frame")
customTargetFrame.Size = UDim2.new(1, -6, 0, 32)
customTargetFrame.BackgroundColor3 = Theme.bgPanel
customTargetFrame.Parent = settingsScroll
Instance.new("UICorner", customTargetFrame).CornerRadius = UDim.new(0, 6)

local customBox = Instance.new("TextBox")
customBox.Size = UDim2.new(1, -16, 1, 0)
customBox.Position = UDim2.new(0, 8, 0, 0)
customBox.BackgroundTransparency = 1
customBox.Font = Enum.Font.GothamMedium
customBox.TextSize = 11
customBox.TextColor3 = Theme.textWhite
customBox.PlaceholderText = "Або введіть свою назву пета..."
customBox.PlaceholderColor3 = Theme.textMuted
customBox.TextXAlignment = Enum.TextXAlignment.Left
customBox.Text = ""
customBox.Parent = customTargetFrame

customBox.FocusLost:Connect(function()
    local val = customBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if #val > 0 then
        cfg.targetPet = val
        cfg.targetPetName = val
        addLog("INFO", "Встановлено власну ціль пошуку: " .. val)
        if refreshBargainsUI then refreshBargainsUI(false) end
    end
end)

createSectionHeader("💰 Налаштування цінового фільтра:")

-- Перемикач фільтра ціни
local filterToggleBtn = Instance.new("TextButton")
filterToggleBtn.Size = UDim2.new(1, -6, 0, 30)
filterToggleBtn.BackgroundColor3 = cfg.usePriceFilter and Theme.accent or Theme.bgPanel
filterToggleBtn.Text = cfg.usePriceFilter and "🔘 Фільтр ціни: УВІМКНЕНО" or "⚪ Фільтр ціни: ВИМКНЕНО (показувати всі)"
filterToggleBtn.Font = Enum.Font.GothamBold
filterToggleBtn.TextSize = 11
filterToggleBtn.TextColor3 = Theme.textWhite
filterToggleBtn.Parent = settingsScroll
Instance.new("UICorner", filterToggleBtn).CornerRadius = UDim.new(0, 6)

bindButton(filterToggleBtn, function()
    cfg.usePriceFilter = not cfg.usePriceFilter
    filterToggleBtn.BackgroundColor3 = cfg.usePriceFilter and Theme.accent or Theme.bgPanel
    filterToggleBtn.Text = cfg.usePriceFilter and "🔘 Фільтр ціни: УВІМКНЕНО" or "⚪ Фільтр ціни: ВИМКНЕНО (показувати всі)"
    addLog("INFO", "Фільтр цін: " .. (cfg.usePriceFilter and "УВІМКНЕНО" or "ВИМКНЕНО"))
    if refreshBargainsUI then refreshBargainsUI(false) end
end)

local priceInputs = Instance.new("Frame")
priceInputs.Size = UDim2.new(1, -6, 0, 32)
priceInputs.BackgroundTransparency = 1
priceInputs.Parent = settingsScroll

local minBox = Instance.new("TextBox")
minBox.Size = UDim2.new(0.48, -4, 1, 0)
minBox.Position = UDim2.new(0, 0, 0, 0)
minBox.BackgroundColor3 = Theme.bgPanel
minBox.Font = Enum.Font.GothamMedium
minBox.TextSize = 11
minBox.TextColor3 = Theme.textWhite
minBox.PlaceholderText = "Ціна ВІД (напр. 1M)"
minBox.Text = "0"
minBox.Parent = priceInputs
Instance.new("UICorner", minBox).CornerRadius = UDim.new(0, 6)

local maxBox = Instance.new("TextBox")
maxBox.Size = UDim2.new(0.5, -4, 1, 0)
maxBox.Position = UDim2.new(0.5, 2, 0, 0)
maxBox.BackgroundColor3 = Theme.bgPanel
maxBox.Font = Enum.Font.GothamMedium
maxBox.TextSize = 11
maxBox.TextColor3 = Theme.textWhite
maxBox.PlaceholderText = "Ціна ДО (напр. 50M)"
maxBox.Text = "999B"
maxBox.Parent = priceInputs
Instance.new("UICorner", maxBox).CornerRadius = UDim.new(0, 6)

minBox.FocusLost:Connect(function()
    cfg.minPrice = parsePrice(minBox.Text)
    addLog("INFO", "Фільтр ціни ВІД: " .. formatPrice(cfg.minPrice))
    if refreshBargainsUI then refreshBargainsUI(false) end
end)

maxBox.FocusLost:Connect(function()
    cfg.maxPrice = parsePrice(maxBox.Text)
    addLog("INFO", "Фільтр ціни ДО: " .. formatPrice(cfg.maxPrice))
    if refreshBargainsUI then refreshBargainsUI(false) end
end)

createSectionHeader("⚡ Ліміт ціни Авто-Снайпера:")

local autoBuyLimitBox = Instance.new("TextBox")
autoBuyLimitBox.Size = UDim2.new(1, -6, 0, 30)
autoBuyLimitBox.BackgroundColor3 = Theme.bgPanel
autoBuyLimitBox.Font = Enum.Font.GothamMedium
autoBuyLimitBox.TextSize = 11
autoBuyLimitBox.TextColor3 = Theme.green
autoBuyLimitBox.PlaceholderText = "Макс. ціна для авто-покупки (напр. 25M)"
autoBuyLimitBox.Text = formatPrice(cfg.maxAutoBuyPrice)
autoBuyLimitBox.Parent = settingsScroll
Instance.new("UICorner", autoBuyLimitBox).CornerRadius = UDim.new(0, 6)

autoBuyLimitBox.FocusLost:Connect(function()
    local p = parsePrice(autoBuyLimitBox.Text)
    if p > 0 then
        cfg.maxAutoBuyPrice = p
        addLog("INFO", "Ліміт ціни авто-покупки встановлено: " .. formatPrice(cfg.maxAutoBuyPrice))
    end
end)

-- ==============================================================================
-- 🖥️ ВКЛАДКА 3: ТЕРМІНАЛ & СЕРВЕР-ХОП
-- ==============================================================================
local termContainer = Instance.new("Frame")
termContainer.Size = UDim2.new(1, 0, 1, 0)
termContainer.BackgroundTransparency = 1
termContainer.Parent = terminalTab

termLoopBtn = Instance.new("TextButton")
termLoopBtn.Size = UDim2.new(1, -6, 0, 42)
termLoopBtn.Position = UDim2.new(0, 0, 0, 10)
termLoopBtn.BackgroundColor3 = Color3.fromRGB(110, 50, 180)
termLoopBtn.Text = "🚀 Швидкий перехват терміналу (5с)"
termLoopBtn.Font = Enum.Font.GothamBold
termLoopBtn.TextSize = 13
termLoopBtn.TextColor3 = Theme.textWhite
termLoopBtn.Parent = termContainer
Instance.new("UICorner", termLoopBtn).CornerRadius = UDim.new(0, 8)

bindButton(termLoopBtn, function()
    toggleTerminalLoop()
end)

local termDesc = Instance.new("TextLabel")
termDesc.Size = UDim2.new(1, -10, 0, 48)
termDesc.Position = UDim2.new(0, 5, 0, 60)
termDesc.BackgroundTransparency = 1
termDesc.Font = Enum.Font.GothamMedium
termDesc.TextSize = 11
termDesc.TextColor3 = Theme.textMuted
termDesc.TextWrapped = true
termDesc.Text = "Супер Комп'ютер шукає обраного пета через серверний ремоут кожні 5 сек (обхід 60-сек затримки) та автоматично перекидає на знайдений сервер."
termDesc.Parent = termContainer

local hopNowBtn = Instance.new("TextButton")
hopNowBtn.Size = UDim2.new(1, -6, 0, 42)
hopNowBtn.Position = UDim2.new(0, 0, 0, 120)
hopNowBtn.BackgroundColor3 = Theme.blue
hopNowBtn.Text = "🌐 Сервер-Хоп зараз (новий сервер)"
hopNowBtn.Font = Enum.Font.GothamBold
hopNowBtn.TextSize = 13
hopNowBtn.TextColor3 = Theme.textWhite
hopNowBtn.Parent = termContainer
Instance.new("UICorner", hopNowBtn).CornerRadius = UDim.new(0, 8)

bindButton(hopNowBtn, function()
    serverHop()
end)

local hopDesc = Instance.new("TextLabel")
hopDesc.Size = UDim2.new(1, -10, 0, 40)
hopDesc.Position = UDim2.new(0, 5, 0, 170)
hopDesc.BackgroundTransparency = 1
hopDesc.Font = Enum.Font.GothamMedium
hopDesc.TextSize = 11
hopDesc.TextColor3 = Theme.textMuted
hopDesc.TextWrapped = true
hopDesc.Text = "Автоматично підбирає живий, населений сервер Трейд Плази (15-40 гравців) через захищений RoProxy та перепідключає скрипт."
hopDesc.Parent = termContainer

-- ==============================================================================
-- 📋 ВКЛАДКА 4: ЖУРНАЛ ЛОГІВ & ПОМИЛОК
-- ==============================================================================
local logTopBar = Instance.new("Frame")
logTopBar.Size = UDim2.new(1, 0, 0, 32)
logTopBar.BackgroundTransparency = 1
logTopBar.Parent = logsTab

local copyLogBtn = Instance.new("TextButton")
copyLogBtn.Size = UDim2.new(0.48, -4, 1, 0)
copyLogBtn.Position = UDim2.new(0, 0, 0, 0)
copyLogBtn.BackgroundColor3 = Theme.accent
copyLogBtn.Text = "📋 Скопіювати всі логи"
copyLogBtn.Font = Enum.Font.GothamBold
copyLogBtn.TextSize = 11
copyLogBtn.TextColor3 = Theme.textWhite
copyLogBtn.Parent = logTopBar
Instance.new("UICorner", copyLogBtn).CornerRadius = UDim.new(0, 6)

bindButton(copyLogBtn, function()
    copyAllLogs()
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "📋 Логи",
            Text = "Усі логи скопійовано в буфер обміну!",
            Duration = 3
        })
    end)
end)

local clearLogBtn = Instance.new("TextButton")
clearLogBtn.Size = UDim2.new(0.5, -4, 1, 0)
clearLogBtn.Position = UDim2.new(0.5, 2, 0, 0)
clearLogBtn.BackgroundColor3 = Theme.bgPanel
clearLogBtn.Text = "🗑 Очистити вікно"
clearLogBtn.Font = Enum.Font.GothamBold
clearLogBtn.TextSize = 11
clearLogBtn.TextColor3 = Theme.textWhite
clearLogBtn.Parent = logTopBar
Instance.new("UICorner", clearLogBtn).CornerRadius = UDim.new(0, 6)

bindButton(clearLogBtn, function()
    for _, ch in ipairs(logScrollFrame:GetChildren()) do
        if ch:IsA("TextLabel") then ch:Destroy() end
    end
    lastLogLabel = nil
    lastLogMsg = ""
    addLog("INFO", "Журнал логів очищено.")
end)

logScrollFrame = Instance.new("ScrollingFrame")
logScrollFrame.Size = UDim2.new(1, 0, 1, -40)
logScrollFrame.Position = UDim2.new(0, 0, 0, 38)
logScrollFrame.BackgroundColor3 = Theme.bgPanel
logScrollFrame.ScrollBarThickness = 4
logScrollFrame.ScrollBarImageColor3 = Theme.accent
logScrollFrame.ClipsDescendants = true
logScrollFrame.Parent = logsTab
Instance.new("UICorner", logScrollFrame).CornerRadius = UDim.new(0, 8)

local logLayout = Instance.new("UIListLayout", logScrollFrame)
logLayout.Padding = UDim.new(0, 3)

logLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    logScrollFrame.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize.Y + 10)
end)

-- Початковий запуск та сканування
addLog("SUCCESS", "🚀 PUFYFTYK TRADE SNIPER V4.0 УСПІШНО ЗАВАНТАЖЕНО!")
addLog("INFO", "Перевірка ReplicatedStorage.Network...")

pcall(function()
    local net = RepS:FindFirstChild("Network")
    if net then
        addLog("SUCCESS", "Network знайдено! Активні ремоути для трейду підключено.")
    else
        addLog("WARN", "ReplicatedStorage.Network очікується...")
    end
end)

task.spawn(function()
    task.wait(1.0)
    if refreshBargainsUI then refreshBargainsUI(false) end
end)

-- Фоновий цикл авто-оновлення ринку кожні 3.5 сек
task.spawn(function()
    while _G.Pufyftyk_Trade_Loaded do
        task.wait(cfg.scanInterval)
        if win.Visible and tabs["Ринок"].Visible then
            pcall(function()
                if refreshBargainsUI then refreshBargainsUI(true) end
            end)
        end
    end
end)

-- Функція деініціалізації
_G.Pufyftyk_Trade_Cleanup = function()
    _G.Pufyftyk_Trade_Loaded = false
    isTerminalLoopActive = false
    pcall(function() sg:Destroy() end)
end
