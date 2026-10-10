repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local LocalizationService = game:GetService("LocalizationService")

local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players.PlayerAdded:Wait()
    LocalPlayer = Players.LocalPlayer
end

local getgenv = getgenv or function() return _G end
local env = getgenv()

if env.HalloweenHubCleanup then
    pcall(env.HalloweenHubCleanup)
end

local ActiveConnections = {}
local function trackConn(conn)
    if conn then table.insert(ActiveConnections, conn) end
    return conn
end

local function bindButton(btn, callback)
    local busy = false
    local lastFire = 0
    trackConn(btn.MouseButton1Click:Connect(function()
        local now = tick()
        if busy or (now - lastFire < 0.22) then return end
        busy = true
        lastFire = now
        task.spawn(function()
            pcall(callback)
            task.wait(0.05)
            busy = false
        end)
    end))
end

local DefaultSpawnCFrame = CFrame.new(7538.1, 15.7, 21965.5)

local LangCodes = { "EN", "UK", "RU" }

local UILang = {
    EN = {
        windowTitle = "PS99 Hatch Wars",
        tabFarm = "Farm",
        tabHouses = "Houses",
        tabSettings = "Settings",
        tabLogs = "Logs",
        on = "ON",
        off = "OFF",
        fullAuto = "Auto Farm (Eggs + Coins + Houses)",
        onlyEggs = "Auto Eggs Only (No Houses)",
        instantEgg = "Fast Egg Open (Skip Animation)",
        magnetFlag = "Auto Magnet Flag (1 at a time)",
        savePos = "Save Position",
        savedPos = "Position Saved!",
        tpPos = "Teleport to Coords",
        runHousesNow = "Check & Open Houses Now",
        autoBuyHouses = "Auto Buy Houses (Lollipop)",
        addHousePt = "Add House Point",
        resetHouseTimers = "Reset Timers / Locks",
        autoMinigame = "Auto Door Minigame & Close Errors",
        blackScreenBtn = "Black Screen Stats (Disable 3D)",
        render3DBtn = "3D World Rendering",
        langBtn = "Language: EN (EN -> UK -> RU)",
        jumpBtn = "Anti-AFK Jump (Every 20s)",
        applyCoords = "Teleport",
        copyLogs = "Copy",
        copiedLogs = "Copied",
        scanBtn = "Scan",
        clearLogs = "Clear",
        dashHeader = "HATCH WARS AFK  |  3D RENDERING OFF",
        statTime = "Farm Time",
        statEggs = "Eggs Hatched",
        statHouses = "Houses Opened",
        statLollipop = "Lollipops",
        exitBlack = "Exit Black Screen (Enable 3D)",
        openMenu = "Menu",
        tpBlack = "Teleport to Farm Coords (7538.1, 15.7, 21965.5)",
        checkHousesBlack = "Check & Open Ready Houses Now"
    },
    UK = {
        windowTitle = "PS99 Hatch Wars",
        tabFarm = "Фарм",
        tabHouses = "Домики",
        tabSettings = "Налашт.",
        tabLogs = "Логи",
        on = "УВІМК",
        off = "ВИМК",
        fullAuto = "Авто-Фарм (Яйця + Монети + Домики)",
        onlyEggs = "Тільки Яйця (без домиків)",
        instantEgg = "Швидке відкриття яєць (без анімації)",
        magnetFlag = "Авто Магніт-Флаг (без дублів)",
        savePos = "Зберегти позицію",
        savedPos = "Збережено!",
        tpPos = "На координати",
        runHousesNow = "Перевірити та відкрити домики зараз",
        autoBuyHouses = "Авто-купівля домиків за цукерки",
        addHousePt = "Додати точку дому",
        resetHouseTimers = "Скинути таймери",
        autoMinigame = "Авто-капча дверей та закриття помилок",
        blackScreenBtn = "Чорний екран статистики (3D ВИМК)",
        render3DBtn = "3D Графіка гри",
        langBtn = "Мова: УКР (АНГЛ -> УКР -> РУС)",
        jumpBtn = "Анти-АФК стрибок (кожні 20с)",
        applyCoords = "Телепорт",
        copyLogs = "Копіювати",
        copiedLogs = "Скопійовано",
        scanBtn = "Сканер",
        clearLogs = "Очистити",
        dashHeader = "HATCH WARS AFK  |  3D ГРАФІКУ ВИМКНЕНО",
        statTime = "Час фарму",
        statEggs = "Відкрито яєць",
        statHouses = "Відкрито домиків",
        statLollipop = "Цукерки (Lollipop)",
        exitBlack = "Вийти з чорного екрану (Увімкнути 3D)",
        openMenu = "Меню",
        tpBlack = "Телепорт на координати (7538.1, 15.7, 21965.5)",
        checkHousesBlack = "Перевірити і відкрити доступні домики"
    },
    RU = {
        windowTitle = "PS99 Hatch Wars",
        tabFarm = "Фарм",
        tabHouses = "Домики",
        tabSettings = "Настр.",
        tabLogs = "Логи",
        on = "ВКЛ",
        off = "ВЫКЛ",
        fullAuto = "Авто-Фарм (Яйца + Монеты + Домики)",
        onlyEggs = "Только Яйца (без домиков)",
        instantEgg = "Быстрое открытие яиц (без анимации)",
        magnetFlag = "Авто Магнит-Флаг (без дублей)",
        savePos = "Сохранить позицию",
        savedPos = "Сохранено!",
        tpPos = "На координаты",
        runHousesNow = "Проверить и открыть домики сейчас",
        autoBuyHouses = "Авто-покупка домиков за конфеты",
        addHousePt = "Добавить точку дома",
        resetHouseTimers = "Сбросить таймеры",
        autoMinigame = "Авто-капча дверей и закрытие ошибок",
        blackScreenBtn = "Черный экран статистики (3D ВЫКЛ)",
        render3DBtn = "3D Графика игры",
        langBtn = "Язык: РУС (АНГЛ -> УКР -> РУС)",
        jumpBtn = "Анти-АФК прыжок (каждые 20с)",
        applyCoords = "Телепорт",
        copyLogs = "Копировать",
        copiedLogs = "Скопировано",
        scanBtn = "Сканер",
        clearLogs = "Очистить",
        dashHeader = "HATCH WARS AFK  |  3D ГРАФИКА ОТКЛЮЧЕНА",
        statTime = "Время фарма",
        statEggs = "Открыто яиц",
        statHouses = "Открыто домиков",
        statLollipop = "Конфеты (Lollipop)",
        exitBlack = "Выйти из черного экрана (Включить 3D)",
        openMenu = "Меню",
        tpBlack = "Телепорт на координаты (7538.1, 15.7, 21965.5)",
        checkHousesBlack = "Проверить и открыть доступные домики"
    }
}

local GameTextTranslations = {
    { en = "Not enough Lollipops", uk = "Недостатньо цукерок Lollipop", ru = "Недостаточно конфет Lollipop" },
    { en = "Not enough", uk = "Недостатньо", ru = "Недостаточно" },
    { en = "Unlock this house", uk = "Розблокувати цей домик", ru = "Разблокировать этот домик" },
    { en = "Trick or Treat", uk = "Відкрити домик", ru = "Открыть домик" },
    { en = "Unlocked", uk = "Відкрито", ru = "Открыто" },
    { en = "Locked", uk = "Закрито", ru = "Закрыто" },
    { en = "Unlock", uk = "Купити", ru = "Купить" },
    { en = "Cooldown", uk = "Перезарядка", ru = "Перезарядка" },
    { en = "Purchase", uk = "Купити", ru = "Купить" },
    { en = "Confirm", uk = "Підтвердити", ru = "Подтвердить" },
    { en = "Cancel", uk = "Скасувати", ru = "Отмена" },
    { en = "Close", uk = "Закрити", ru = "Закрыть" },
    { en = "Inventory", uk = "Інвентар", ru = "Инвентарь" },
    { en = "Teleport", uk = "Телепорт", ru = "Телепорт" },
    { en = "Settings", uk = "Налаштування", ru = "Настройки" },
    { en = "Rewards", uk = "Нагороди", ru = "Награды" },
    { en = "Trading", uk = "Обмін", ru = "Обмен" },
    { en = "Exclusive", uk = "Магазин", ru = "Магазин" },
    { en = "Mastery", uk = "Майстерність", ru = "Мастерство" },
    { en = "Upgrades", uk = "Покращення", ru = "Улучшения" },
    { en = "Pets", uk = "Пети", ru = "Петы" },
    { en = "Items", uk = "Предмети", ru = "Предметы" },
    { en = "Flags", uk = "Флаги", ru = "Флаги" },
    { en = "Eggs", uk = "Яйця", ru = "Яйца" },
    { en = "Open", uk = "Відкрити", ru = "Открыть" },
    { en = "Buy", uk = "Купити", ru = "Купить" },
    { en = "Yes", uk = "Так", ru = "Да" },
    { en = "No", uk = "Ні", ru = "Нет" }
}

local State = {
    Running = true,
    FullAutoFarm = false,
    AutoEggs = false,
    InstantEggOpen = true,
    AutoBuyHouses = true,
    AutoMagnetFlag = true,
    LastMagnetFlagTime = 0,
    MagnetFlagUid = nil,
    MagnetFlagCount = 0,
    LanguageIndex = 1,
    EggHatchDelay = 2.0,
    HouseStepDelay = 4.0,
    CustomEggCount = 79,
    MaxHatchDetected = 0,
    WorkingEggAmount = 79,
    CachedEggRemoteName = nil,
    CachedEggId = nil,
    LearnedEggId = nil,
    LearnedCurrencyKey = nil,
    LearnedBatchCost = 0,
    LowCoinWaitCount = 0,
    LastCapturedEggRemote = nil,
    LastCapturedEggArgs = nil,
    SavedEggCFrame = DefaultSpawnCFrame,
    MaxUnlockedHouses = 0,
    HouseCooldownDefault = 600,
    HouseCooldownMap = {},
    LockedHouseInfo = {},
    ConfirmedUnlockedHouses = {},
    AllowConfirmPurchasePopup = false,
    LastPopupWasError = false,
    LastPopupPurchased = false,
    LastHouseWasOnCooldown = false,
    LastParsedCooldownSecs = nil,
    LastPopupErrorText = "",
    LastPopupCostNumber = nil,
    IsVisitingHouses = false,
    IsHatchingNow = false,
    CustomHousePoints = {},
    LastCapturedHouseRemote = nil,
    LastCapturedHouseArgs = nil,
    AutoMinigame = true,
    AutoFarmCoins = true,
    AutoJump20s = true,
    BlackScreenActive = false,
    Rendering3DEnabled = true,
    StartTime = tick(),
    TotalEggsHatched = 0,
    TotalEggBatches = 0,
    TotalHousesOpened = 0,
    StartPetCounts = nil,
    StartLollipops = nil,
    CurrentPetCounts = {
        HeadlessDominus = 0,
        Wendigo = 0,
        GrinningGoat = 0
    },
    CurrentLollipops = 0,
    CurrentActionText = "Ready",
    Logs = {},
    MaxLogs = 250
}

local CoordsFileName = "ps99_halloween_coords_v2.txt"

local LogBoxLabel = nil
local LogScrollFrame = nil
local EggStatusLabel = nil
local HouseStatusLabel = nil
local EggCountInput = nil
local CoordsInputBox = nil
local BlackOverlayFrame = nil
local MainFrame = nil

local TitleLabel = nil
local TabFarmBtn = nil
local TabHousesBtn = nil
local TabSettingsBtn = nil
local TabLogsBtn = nil
local FullAutoToggle = nil
local OnlyEggsToggle = nil
local InstantAnimToggle = nil
local MagnetFlagToggleBtn = nil
local SaveEggPosBtn = nil
local ReturnToEggBtn = nil
local RunHousesNowBtn = nil
local AutoBuyHouseToggle = nil
local AddPointBtn = nil
local ClearPointsBtn = nil
local AutoCapToggle = nil
local BlackToggleBtnInSettings = nil
local Render3DToggleBtn = nil
local JumpToggle = nil
local SetCoordsManualBtn = nil
local CopyLogsBtn = nil
local DiagEventBtn = nil
local ClearLogsBtn = nil
local DashTitle = nil
local ExitBlackBtn = nil
local OpenMenuOnBlackBtn = nil
local TeleportNowOnBlackBtn = nil
local RunHousesOnBlackBtn = nil

local LangCycleBtnFarm = nil
local LangCycleBtnSettings = nil
local LangCycleBtnBlack = nil
local LangDirectBtns = {}

local StatTimeTitle = nil
local StatEggsTitle = nil
local StatHousesTitle = nil
local StatLollipopTitle = nil

local StatTimeValue = nil
local StatEggsValue = nil
local StatHousesValue = nil
local StatDominusValue = nil
local StatWendigoValue = nil
local StatGoatValue = nil
local StatLollipopValue = nil
local StatStatusValue = nil

local OrigGameText = setmetatable({}, { __mode = "k" })

local function L()
    local code = LangCodes[State.LanguageIndex] or "EN"
    return UILang[code] or UILang.EN
end

local function translateSingleGameString(rawText, langIdx)
    if not rawText or rawText == "" then return rawText end
    local res = rawText
    if langIdx == 1 then
        for _, entry in ipairs(GameTextTranslations) do
            res = string.gsub(res, entry.uk, entry.en)
            res = string.gsub(res, entry.ru, entry.en)
        end
        return res
    elseif langIdx == 2 then
        for _, entry in ipairs(GameTextTranslations) do
            res = string.gsub(res, entry.ru, entry.en)
            res = string.gsub(res, entry.en, entry.uk)
        end
        return res
    elseif langIdx == 3 then
        for _, entry in ipairs(GameTextTranslations) do
            res = string.gsub(res, entry.uk, entry.en)
            res = string.gsub(res, entry.en, entry.ru)
        end
        return res
    end
    return res
end

local function refreshAllMenuLabels()
    local t = L()
    local onOff = function(val) return val and ("[" .. t.on .. "]") or ("[" .. t.off .. "]") end

    if TitleLabel then TitleLabel.Text = t.windowTitle end
    if TabFarmBtn then TabFarmBtn.Text = t.tabFarm end
    if TabHousesBtn then TabHousesBtn.Text = t.tabHouses end
    if TabSettingsBtn then TabSettingsBtn.Text = t.tabSettings end
    if TabLogsBtn then TabLogsBtn.Text = t.tabLogs end

    if FullAutoToggle then FullAutoToggle.Text = t.fullAuto .. ": " .. onOff(State.FullAutoFarm) end
    if OnlyEggsToggle then OnlyEggsToggle.Text = t.onlyEggs .. ": " .. onOff(State.AutoEggs) end
    if InstantAnimToggle then InstantAnimToggle.Text = t.instantEgg .. ": " .. onOff(State.InstantEggOpen) end
    if MagnetFlagToggleBtn then MagnetFlagToggleBtn.Text = t.magnetFlag .. ": " .. onOff(State.AutoMagnetFlag) end
    if SaveEggPosBtn then SaveEggPosBtn.Text = t.savePos end
    if ReturnToEggBtn then ReturnToEggBtn.Text = t.tpPos end

    if RunHousesNowBtn then RunHousesNowBtn.Text = t.runHousesNow end
    if AutoBuyHouseToggle then AutoBuyHouseToggle.Text = t.autoBuyHouses .. ": " .. onOff(State.AutoBuyHouses) end
    if AddPointBtn then AddPointBtn.Text = t.addHousePt .. " (" .. #State.CustomHousePoints .. ")" end
    if ClearPointsBtn then ClearPointsBtn.Text = t.resetHouseTimers end
    if AutoCapToggle then AutoCapToggle.Text = t.autoMinigame .. ": " .. onOff(State.AutoMinigame) end

    if BlackToggleBtnInSettings then BlackToggleBtnInSettings.Text = t.blackScreenBtn .. ": " .. onOff(State.BlackScreenActive) end
    if Render3DToggleBtn then Render3DToggleBtn.Text = t.render3DBtn .. ": " .. onOff(State.Rendering3DEnabled) end
    if JumpToggle then JumpToggle.Text = t.jumpBtn .. ": " .. onOff(State.AutoJump20s) end
    if SetCoordsManualBtn then SetCoordsManualBtn.Text = t.applyCoords end

    if CopyLogsBtn then CopyLogsBtn.Text = t.copyLogs end
    if DiagEventBtn then DiagEventBtn.Text = t.scanBtn end
    if ClearLogsBtn then ClearLogsBtn.Text = t.clearLogs end

    if DashTitle then DashTitle.Text = t.dashHeader end
    if StatTimeTitle then StatTimeTitle.Text = t.statTime end
    if StatEggsTitle then StatEggsTitle.Text = t.statEggs end
    if StatHousesTitle then StatHousesTitle.Text = t.statHouses end
    if StatLollipopTitle then StatLollipopTitle.Text = t.statLollipop end

    if ExitBlackBtn then ExitBlackBtn.Text = t.exitBlack end
    if OpenMenuOnBlackBtn then OpenMenuOnBlackBtn.Text = t.openMenu end
    if TeleportNowOnBlackBtn then TeleportNowOnBlackBtn.Text = t.tpBlack end
    if RunHousesOnBlackBtn then RunHousesOnBlackBtn.Text = t.checkHousesBlack end

    if LangCycleBtnFarm then LangCycleBtnFarm.Text = t.langBtn end
    if LangCycleBtnSettings then LangCycleBtnSettings.Text = t.langBtn end
    if LangCycleBtnBlack then LangCycleBtnBlack.Text = t.langBtn end

    for idx, btnList in pairs(LangDirectBtns) do
        for _, b in ipairs(btnList) do
            if idx == State.LanguageIndex then
                b.BackgroundColor3 = Color3.fromRGB(45, 115, 75)
                b.TextColor3 = Color3.fromRGB(245, 247, 250)
            else
                b.BackgroundColor3 = Color3.fromRGB(32, 35, 44)
                b.TextColor3 = Color3.fromRGB(165, 172, 185)
            end
        end
    end
end

local function applyGameLanguageNow(langIndex)
    if langIndex then
        State.LanguageIndex = ((langIndex - 1) % 3) + 1
    end
    local idx = State.LanguageIndex
    local localeMap = { "en-us", "uk-ua", "ru-ru" }
    local localeCode = localeMap[idx] or "en-us"

    refreshAllMenuLabels()

    pcall(function()
        if setscriptable then
            pcall(setscriptable, LocalizationService, "RobloxLocaleId", true)
            pcall(setscriptable, LocalizationService, "SystemLocaleId", true)
            pcall(setscriptable, LocalPlayer, "LocaleId", true)
        end
        pcall(function() LocalizationService.RobloxLocaleId = localeCode end)
        pcall(function() LocalPlayer.LocaleId = localeCode end)
    end)

    local function translateGuiObjectText(obj)
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local cur = obj.Text
            if cur and cur ~= "" and not tonumber(cur) then
                if not OrigGameText[obj] then
                    OrigGameText[obj] = translateSingleGameString(cur, 1)
                end
                local enBase = OrigGameText[obj]
                obj.AutoLocalize = false
                local newTxt = translateSingleGameString(enBase, idx)
                if newTxt and newTxt ~= obj.Text then
                    obj.Text = newTxt
                end
            end
        elseif obj:IsA("ProximityPrompt") then
            if obj.ActionText and obj.ActionText ~= "" then
                local baseAct = translateSingleGameString(obj.ActionText, 1)
                obj.ActionText = translateSingleGameString(baseAct, idx)
            end
            if obj.ObjectText and obj.ObjectText ~= "" then
                local baseObj = translateSingleGameString(obj.ObjectText, 1)
                obj.ObjectText = translateSingleGameString(baseObj, idx)
            end
        end
    end

    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if pgui then
            for _, gui in ipairs(pgui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name ~= "HalloweenEventGui" then
                    gui.AutoLocalize = false
                    for _, d in ipairs(gui:GetDescendants()) do
                        translateGuiObjectText(d)
                    end
                end
            end
        end
    end)

    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
                d.AutoLocalize = false
                for _, sub in ipairs(d:GetDescendants()) do
                    translateGuiObjectText(sub)
                end
            elseif d:IsA("ProximityPrompt") then
                translateGuiObjectText(d)
            end
        end
    end)
end

local function cycleGameLanguage()
    local nextIdx = (State.LanguageIndex % 3) + 1
    applyGameLanguageNow(nextIdx)
end

task.spawn(function()
    applyGameLanguageNow(1)
    while State.Running do
        task.wait(12)
        if State.Running then
            applyGameLanguageNow(State.LanguageIndex)
        end
    end
end)

local function setStatusText(eggTxt, houseTxt)
    if eggTxt then
        State.CurrentActionText = eggTxt
        if EggStatusLabel then
            EggStatusLabel.Text = eggTxt
        end
    end
    if houseTxt and HouseStatusLabel then
        HouseStatusLabel.Text = houseTxt
    end
    if StatStatusValue then
        local eText = EggStatusLabel and EggStatusLabel.Text or State.CurrentActionText
        local hText = HouseStatusLabel and HouseStatusLabel.Text or ""
        StatStatusValue.Text = eText .. "\n" .. hText
    end
end

local function formatNumber(n)
    local num = math.floor(tonumber(n) or 0)
    local formatted = tostring(num)
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

local function parseSuffixedNumber(str)
    if not str then return nil end
    local clean = string.gsub(tostring(str), ",", "")
    local numStr, suffix = string.match(string.lower(clean), "([%d%.]+)%s*([kmb]?)")
    local val = tonumber(numStr)
    if not val then return nil end
    if suffix == "k" then
        val = val * 1000
    elseif suffix == "m" then
        val = val * 1000000
    elseif suffix == "b" then
        val = val * 1000000000
    end
    return math.floor(val)
end

local function formatDuration(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    local hrs = math.floor(total / 3600)
    local mins = math.floor((total % 3600) / 60)
    local secs = total % 60
    return string.format("%02d:%02d:%02d", hrs, mins, secs)
end

local function addLog(level, msg)
    local timestamp = os.date("%H:%M:%S")
    local entry = string.format("[%s] [%s] %s", timestamp, level, tostring(msg))
    table.insert(State.Logs, entry)
    if #State.Logs > State.MaxLogs then
        table.remove(State.Logs, 1)
    end
    if LogBoxLabel and LogScrollFrame then
        pcall(function()
            LogBoxLabel.Text = table.concat(State.Logs, "\n")
            local bounds = LogBoxLabel.TextBounds.Y
            LogScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(bounds + 24, 100))
            LogScrollFrame.CanvasPosition = Vector2.new(0, math.max(0, bounds - LogScrollFrame.AbsoluteSize.Y + 24))
        end)
    end
end

trackConn(LogService.MessageOut:Connect(function(message, messageType)
    if not State.Running then return end
    if messageType == Enum.MessageType.MessageError or messageType == Enum.MessageType.MessageWarning then
        if not string.find(message, "SimpleSpy") then
            local tag = (messageType == Enum.MessageType.MessageError) and "ERR" or "WARN"
            addLog(tag, message)
        end
    end
end))

local function copyToClipboard(text)
    local fn = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
    if fn then
        local ok = pcall(fn, tostring(text))
        if ok then return true end
    end
    return false
end

local function saveCoordsToDisk(cf)
    if not cf then return end
    local pos = cf.Position
    env.HalloweenSavedCoords = { x = pos.X, y = pos.Y, z = pos.Z }
    local str = string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
    if CoordsInputBox then
        CoordsInputBox.Text = str
    end
    pcall(function()
        if writefile then
            writefile(CoordsFileName, str)
        end
    end)
end

local function loadCoordsFromDisk()
    local loadedCF = nil
    pcall(function()
        if isfile and readfile and isfile(CoordsFileName) then
            local raw = readfile(CoordsFileName)
            if raw and raw ~= "" then
                local x, y, z = string.match(raw, "([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
                if x and y and z then
                    loadedCF = CFrame.new(tonumber(x), tonumber(y), tonumber(z))
                end
            end
        end
    end)
    if not loadedCF and type(env.HalloweenSavedCoords) == "table" then
        local c = env.HalloweenSavedCoords
        if c.x and c.y and c.z then
            loadedCF = CFrame.new(tonumber(c.x), tonumber(c.y), tonumber(c.z))
        end
    end
    if not loadedCF then
        loadedCF = DefaultSpawnCFrame
    end
    State.SavedEggCFrame = loadedCF
    if CoordsInputBox then
        local p = loadedCF.Position
        CoordsInputBox.Text = string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
    end
    return loadedCF
end

local function set3DRendering(enabled)
    State.Rendering3DEnabled = enabled
    pcall(function()
        RunService:Set3dRenderingEnabled(enabled)
    end)
    if Render3DToggleBtn then
        Render3DToggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(45, 115, 75) or Color3.fromRGB(130, 50, 50)
    end
    refreshAllMenuLabels()
end

local function setBlackScreenMode(active)
    State.BlackScreenActive = active
    if BlackOverlayFrame then
        BlackOverlayFrame.Visible = active
    end
    if active then
        set3DRendering(false)
    else
        set3DRendering(true)
    end
    if BlackToggleBtnInSettings then
        BlackToggleBtnInSettings.BackgroundColor3 = active and Color3.fromRGB(45, 115, 75) or Color3.fromRGB(32, 35, 44)
    end
    refreshAllMenuLabels()
end

local NetworkFolder = nil
pcall(function()
    NetworkFolder = ReplicatedStorage:WaitForChild("Network", 8)
end)

local RemoteCache = {}
local function findRemote(name)
    if RemoteCache[name] and RemoteCache[name].Parent then
        return RemoteCache[name]
    end
    if NetworkFolder then
        local r = NetworkFolder:FindFirstChild(name)
        if r then
            RemoteCache[name] = r
            return r
        end
        for _, desc in ipairs(NetworkFolder:GetDescendants()) do
            if string.lower(desc.Name) == string.lower(name) then
                RemoteCache[name] = desc
                return desc
            end
        end
    end
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if string.lower(desc.Name) == string.lower(name) and (desc:IsA("RemoteFunction") or desc:IsA("RemoteEvent")) then
            RemoteCache[name] = desc
            return desc
        end
    end
    return nil
end

local function invokeRemote(name, ...)
    local r = findRemote(name)
    if not r then return false, nil end
    local args = {...}
    if r:IsA("RemoteFunction") then
        local ok, res, extra = pcall(function() return r:InvokeServer(unpack(args)) end)
        return ok, res, extra
    elseif r:IsA("RemoteEvent") then
        local ok = pcall(function() r:FireServer(unpack(args)) end)
        return ok, true, nil
    end
    return false, nil, nil
end

local function getThingsFolder()
    return Workspace:FindFirstChild("__THINGS") or Workspace:FindFirstChild("Things")
end

local function getActiveInstanceContainer()
    local things = getThingsFolder()
    if not things then return nil, nil end
    local ic = things:FindFirstChild("__INSTANCE_CONTAINER")
    if ic then
        local active = ic:FindFirstChild("Active")
        if active then
            local children = active:GetChildren()
            if #children > 0 then
                return children[1], active
            end
        end
    end
    return nil, nil
end

local function pressKeyE(holdTime)
    local hold = holdTime or 0.08
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(hold)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end
end

local function fireSafeSignal(guiObj)
    if not guiObj or not firesignal then return false end
    local ok = false
    pcall(function()
        if guiObj:IsA("GuiButton") then
            firesignal(guiObj.Activated)
            firesignal(guiObj.MouseButton1Click)
            firesignal(guiObj.MouseButton1Down)
            firesignal(guiObj.MouseButton1Up)
            ok = true
        end
    end)
    return ok
end

local function isGuiActuallyVisible(guiObj)
    if not guiObj then return false end
    local cur = guiObj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") then
            if not cur.Visible then return false end
        elseif cur:IsA("ScreenGui") or cur:IsA("BillboardGui") or cur:IsA("SurfaceGui") then
            if not cur.Enabled then return false end
            return true
        end
        cur = cur.Parent
    end
    return true
end

local function parseCooldownFromText(txt)
    if not txt or txt == "" then return nil end
    local lower = string.lower(txt)
    local m, s = string.match(lower, "(%d+)%s*:%s*(%d+)")
    if m and s then
        return tonumber(m) * 60 + tonumber(s)
    end
    local m2, s2 = string.match(lower, "(%d+)%s*m%s*(%d+)%s*s")
    if m2 and s2 then
        return tonumber(m2) * 60 + tonumber(s2)
    end
    local onlyM = string.match(lower, "(%d+)%s*m")
    if onlyM and (string.find(lower, "cooldown") or string.find(lower, "wait") or #lower <= 8) then
        return tonumber(onlyM) * 60
    end
    local onlyS = string.match(lower, "^%s*(%d+)%s*s%s*$")
    if onlyS then
        return tonumber(onlyS)
    end
    return nil
end

local function checkAndDismissGamePopups()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return false end
    local handled = false

    for _, guiName in ipairs({"Message", "Prompt", "Dialog", "Popup"}) do
        local msgGui = pgui:FindFirstChild(guiName)
        if msgGui and msgGui:IsA("ScreenGui") and msgGui.Enabled then
            local mainFrame = msgGui:FindFirstChild("Frame") or msgGui
            local isVisible = true
            if mainFrame:IsA("GuiObject") then
                isVisible = mainFrame.Visible
            end

            if isVisible then
                local bodyText = ""
                local yesBtn = nil
                local noOrCancelBtn = nil
                local okBtn = nil
                local allButtons = {}

                for _, d in ipairs(msgGui:GetDescendants()) do
                    if d:IsA("TextLabel") and isGuiActuallyVisible(d) and d.Text ~= "" then
                        local tLow = string.lower(d.Text)
                        if tLow ~= "ok" and tLow ~= "yes" and tLow ~= "no" and tLow ~= "cancel" and tLow ~= "так" and tLow ~= "ні" and tLow ~= "ок" and tLow ~= "да" and tLow ~= "нет" then
                            bodyText = bodyText .. " " .. d.Text
                        end
                    elseif d:IsA("GuiButton") and isGuiActuallyVisible(d) then
                        table.insert(allButtons, d)
                        local bName = string.lower(d.Name)
                        local bTxt = ""
                        if d:IsA("TextButton") then
                            bTxt = string.lower(d.Text or "")
                        end
                        for _, sub in ipairs(d:GetDescendants()) do
                            if sub:IsA("TextLabel") then
                                bTxt = bTxt .. " " .. string.lower(sub.Text or "")
                            end
                        end
                        local combined = bName .. " " .. bTxt
                        if string.find(combined, "cancel") or string.find(combined, "no") or string.find(combined, "close") or string.find(combined, "ні") or string.find(combined, "відмін") or string.find(combined, "скасув") or string.find(combined, "нет") or string.find(combined, "отмен") then
                            noOrCancelBtn = d
                        elseif string.find(combined, "yes") or string.find(combined, "unlock") or string.find(combined, "buy") or string.find(combined, "confirm") or string.find(combined, "так") or string.find(combined, "да") or string.find(combined, "купит") or string.find(combined, "розблок") then
                            yesBtn = d
                        elseif string.find(combined, "ok") or string.find(combined, "ок") then
                            okBtn = d
                        end
                    end
                end

                local lowBody = string.lower(bodyText)
                local costMatch = parseSuffixedNumber(string.match(bodyText, "([%d%,%.]+%s*[kKmMbB]?)"))
                if costMatch and costMatch > 0 then
                    State.LastPopupCostNumber = costMatch
                end

                local isCooldownPopup = string.find(lowBody, "cooldown")
                    or string.find(lowBody, "ready in")
                    or string.find(lowBody, "перезаряд")
                    or string.find(lowBody, "зачекай")
                    or string.find(lowBody, "подожд")

                local isErrorPopup = string.find(lowBody, "cannot")
                    or string.find(lowBody, "can't")
                    or string.find(lowBody, "not enough")
                    or string.find(lowBody, "afford")
                    or string.find(lowBody, "need")
                    or string.find(lowBody, "must unlock")
                    or string.find(lowBody, "locked")
                    or string.find(lowBody, "previous")
                    or string.find(lowBody, "error")
                    or string.find(lowBody, "fast")
                    or string.find(lowBody, "недостат")
                    or string.find(lowBody, "не вистач")
                    or string.find(lowBody, "не хвата")
                    or string.find(lowBody, "закрит")
                    or string.find(lowBody, "закрыт")
                    or string.find(lowBody, "помилк")
                    or string.find(lowBody, "ошибк")
                    or (okBtn ~= nil and yesBtn == nil and noOrCancelBtn == nil)

                if isCooldownPopup then
                    State.LastHouseWasOnCooldown = true
                    local cdParsed = parseCooldownFromText(bodyText)
                    if cdParsed and cdParsed > 0 then
                        State.LastParsedCooldownSecs = cdParsed
                    end
                    local targetDismiss = okBtn or noOrCancelBtn or allButtons[1]
                    if targetDismiss then fireSafeSignal(targetDismiss) end
                    pcall(function()
                        if mainFrame:IsA("GuiObject") then mainFrame.Visible = false end
                        msgGui.Enabled = false
                    end)
                    handled = true
                elseif isErrorPopup and not (yesBtn and noOrCancelBtn) then
                    State.LastPopupWasError = true
                    State.LastPopupErrorText = bodyText
                    local targetDismiss = okBtn or noOrCancelBtn or allButtons[1]
                    if targetDismiss then
                        fireSafeSignal(targetDismiss)
                    end
                    pcall(function()
                        if mainFrame:IsA("GuiObject") then mainFrame.Visible = false end
                        msgGui.Enabled = false
                    end)
                    handled = true
                elseif (yesBtn or okBtn) and State.AllowConfirmPurchasePopup and State.AutoBuyHouses then
                    local reqCost = State.LastPopupCostNumber
                    if reqCost and reqCost > 0 and State.CurrentLollipops < reqCost then
                        State.LastPopupWasError = true
                        local cancelTarget = noOrCancelBtn or okBtn or allButtons[1]
                        if cancelTarget then fireSafeSignal(cancelTarget) end
                        pcall(function()
                            if mainFrame:IsA("GuiObject") then mainFrame.Visible = false end
                            msgGui.Enabled = false
                        end)
                    else
                        State.LastPopupPurchased = true
                        local confirmTarget = yesBtn or okBtn
                        fireSafeSignal(confirmTarget)
                    end
                    handled = true
                elseif noOrCancelBtn or okBtn or #allButtons > 0 then
                    State.LastPopupWasError = true
                    local closeTarget = noOrCancelBtn or okBtn or allButtons[1]
                    if closeTarget then fireSafeSignal(closeTarget) end
                    pcall(function()
                        if mainFrame:IsA("GuiObject") then mainFrame.Visible = false end
                        msgGui.Enabled = false
                    end)
                    handled = true
                end
            end
        end
    end

    return handled
end

local function snapshotNotifications()
    local snap = {}
    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pgui then return end
        for _, g in ipairs(pgui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name ~= "HalloweenEventGui" and g.Name ~= "Message" then
                local gn = string.lower(g.Name)
                if string.find(gn, "notif") or string.find(gn, "alert") or string.find(gn, "toast") or string.find(gn, "main") then
                    for _, d in ipairs(g:GetDescendants()) do
                        if d:IsA("TextLabel") and isGuiActuallyVisible(d) and d.Text ~= "" then
                            snap[d] = d.Text
                        end
                    end
                end
            end
        end
    end)
    return snap
end

local function inspectNewNotifications(beforeSnap)
    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pgui then return end
        for _, g in ipairs(pgui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name ~= "HalloweenEventGui" and g.Name ~= "Message" then
                local gn = string.lower(g.Name)
                if string.find(gn, "notif") or string.find(gn, "alert") or string.find(gn, "toast") then
                    for _, d in ipairs(g:GetDescendants()) do
                        if d:IsA("TextLabel") and isGuiActuallyVisible(d) and d.Text ~= "" and beforeSnap[d] ~= d.Text then
                            local low = string.lower(d.Text)
                            if string.find(low, "cooldown") or string.find(low, "wait") or string.find(low, "ready in") or string.find(low, "перезаряд") or string.find(low, "зачекай") or string.find(low, "подожд") then
                                State.LastHouseWasOnCooldown = true
                                local cd = parseCooldownFromText(d.Text)
                                if cd and cd > 0 then State.LastParsedCooldownSecs = cd end
                            elseif string.find(low, "lock") or string.find(low, "not enough") or string.find(low, "afford") or string.find(low, "need") or string.find(low, "previous") or string.find(low, "недостат") or string.find(low, "не вистач") or string.find(low, "не хвата") or string.find(low, "закрит") or string.find(low, "закрыт") then
                                State.LastPopupWasError = true
                                State.LastPopupErrorText = d.Text
                                local cVal = parseSuffixedNumber(string.match(d.Text, "([%d%,%.]+%s*[kKmMbB]?)"))
                                if cVal and cVal > 0 then State.LastPopupCostNumber = cVal end
                            end
                        end
                    end
                end
            end
        end
    end)
end

task.spawn(function()
    while State.Running do
        pcall(checkAndDismissGamePopups)
        task.wait(0.1)
    end
end)

local function getObjectPosition(obj)
    if not obj then return nil end
    local pos = nil
    pcall(function()
        if obj:IsA("BasePart") then
            pos = obj.Position
        elseif obj:IsA("Attachment") then
            pos = obj.WorldPosition
        elseif obj:IsA("Model") then
            pos = obj:GetPivot().Position
        else
            local part = obj:FindFirstChildWhichIsA("BasePart", true)
            if part then pos = part.Position end
        end
    end)
    return pos
end

local function updatePetsAndLollipopsInventory()
    local dominusCount = 0
    local wendigoCount = 0
    local goatCount = 0
    local lollipopCount = 0
    local magnetUid = nil
    local magnetCount = 0

    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local client = lib and lib:FindFirstChild("Client")
        local saveMod = client and client:FindFirstChild("Save")
        if not saveMod then return end

        local ok, Save = pcall(require, saveMod)
        local data = ok and Save and Save.Get and Save.Get()
        if type(data) ~= "table" or type(data.Inventory) ~= "table" then return end

        if type(data.Inventory.Pet) == "table" then
            for _, item in pairs(data.Inventory.Pet) do
                if type(item) == "table" and item.id then
                    local idLow = string.lower(tostring(item.id))
                    local amt = tonumber(item._am) or tonumber(item.amount) or 1
                    if string.find(idLow, "headless dominus") then
                        dominusCount = dominusCount + amt
                    elseif string.find(idLow, "wendigo") then
                        wendigoCount = wendigoCount + amt
                    elseif string.find(idLow, "grinning goat") then
                        goatCount = goatCount + amt
                    end
                end
            end
        end

        for invCategory, catTable in pairs(data.Inventory) do
            if invCategory ~= "Pet" and type(catTable) == "table" then
                for uid, item in pairs(catTable) do
                    if type(item) == "table" and item.id then
                        local idLow = string.lower(tostring(item.id))
                        local amt = tonumber(item._am) or tonumber(item.amount) or 1
                        if idLow == "lollipop" or string.find(idLow, "lollipop") then
                            lollipopCount = lollipopCount + amt
                        elseif idLow == "magnet flag" then
                            magnetUid = tostring(uid)
                            magnetCount = magnetCount + amt
                        end
                    end
                end
            end
        end
    end)

    if not State.StartPetCounts then
        State.StartPetCounts = {
            HeadlessDominus = dominusCount,
            Wendigo = wendigoCount,
            GrinningGoat = goatCount
        }
    end
    if State.StartLollipops == nil then
        State.StartLollipops = lollipopCount
    end

    State.CurrentPetCounts.HeadlessDominus = dominusCount
    State.CurrentPetCounts.Wendigo = wendigoCount
    State.CurrentPetCounts.GrinningGoat = goatCount
    State.CurrentLollipops = lollipopCount
    State.MagnetFlagUid = magnetUid
    State.MagnetFlagCount = magnetCount

    return dominusCount, wendigoCount, goatCount, lollipopCount
end

local function isMagnetOrAnyFlagActiveInZone()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local refPos = (hrp and hrp.Position) or (State.SavedEggCFrame and State.SavedEggCFrame.Position) or DefaultSpawnCFrame.Position
    local activeFound = false

    pcall(function()
        local things = getThingsFolder()
        if things then
            for _, folderName in ipairs({"Flags", "ActiveFlags", "ZoneFlags"}) do
                local fFolder = things:FindFirstChild(folderName)
                if fFolder then
                    for _, flagObj in ipairs(fFolder:GetChildren()) do
                        local fPos = getObjectPosition(flagObj)
                        if fPos and (fPos - refPos).Magnitude <= 170 then
                            activeFound = true
                            return
                        end
                    end
                end
            end
        end

        local activeInst, activeFolder = getActiveInstanceContainer()
        for _, container in ipairs({activeInst, activeFolder, Workspace}) do
            if container then
                for _, d in ipairs(container:GetDescendants()) do
                    if (d:IsA("Model") or d:IsA("BasePart")) then
                        local dn = string.lower(d.Name)
                        if string.find(dn, "magnet flag") or string.find(dn, "magnetflag") or (d.Parent and string.lower(d.Parent.Name) == "flags") then
                            local fPos = getObjectPosition(d)
                            if fPos and (fPos - refPos).Magnitude <= 170 then
                                activeFound = true
                                return
                            end
                        end
                    end
                end
            end
            if activeFound then return end
        end
    end)

    if not activeFound then
        pcall(function()
            local lib = ReplicatedStorage:FindFirstChild("Library")
            local client = lib and lib:FindFirstChild("Client")
            if client then
                for _, modName in ipairs({"FlexibleFlagCmds", "ZoneFlagCmds", "FlagCmds"}) do
                    local m = client:FindFirstChild(modName)
                    if m then
                        local ok, mod = pcall(require, m)
                        if ok and type(mod) == "table" then
                            for _, fnName in ipairs({"GetActiveFlag", "GetActiveFlags", "HasActiveFlag"}) do
                                if type(mod[fnName]) == "function" then
                                    local okF, res = pcall(mod[fnName])
                                    if okF and res then
                                        if type(res) == "boolean" and res == true then
                                            activeFound = true
                                        elseif type(res) == "table" and next(res) ~= nil then
                                            activeFound = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    return activeFound
end

local function useOnlyMagnetFlagIfNoneActive()
    if not State.AutoMagnetFlag or State.IsVisitingHouses then return false end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local targetCF = State.SavedEggCFrame or DefaultSpawnCFrame
    if not hrp or (hrp.Position - targetCF.Position).Magnitude > 140 then
        return false
    end

    if isMagnetOrAnyFlagActiveInZone() then
        return false
    end

    if tick() - State.LastMagnetFlagTime < 12 then
        return false
    end

    updatePetsAndLollipopsInventory()
    local uid = State.MagnetFlagUid
    if not uid or (State.MagnetFlagCount or 0) <= 0 then
        return false
    end

    local placed = false
    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local client = lib and lib:FindFirstChild("Client")
        if client then
            for _, modName in ipairs({"FlexibleFlagCmds", "FlagCmds"}) do
                local fMod = client:FindFirstChild(modName)
                if fMod then
                    local ok, FlagCmds = pcall(require, fMod)
                    if ok and type(FlagCmds) == "table" and type(FlagCmds.Consume) == "function" then
                        local ok1, res1 = pcall(FlagCmds.Consume, "Magnet Flag", uid)
                        if ok1 and res1 ~= false then placed = true; break end
                        local ok2, res2 = pcall(FlagCmds.Consume, uid)
                        if ok2 and res2 ~= false then placed = true; break end
                    end
                end
            end
        end
    end)

    if not placed then
        local okR, resR = invokeRemote("Flags: Consume", "Magnet Flag", uid)
        if okR and resR ~= false then
            placed = true
        else
            invokeRemote("Flags: Consume", uid, 1)
            invokeRemote("Flags_Consume", "Magnet Flag", uid)
        end
    end

    State.LastMagnetFlagTime = tick()
    if placed then
        addLog("OK", "Magnet Flag встановлено (попередній флаг закінчився).")
    end
    return placed
end

task.spawn(function()
    while State.Running do
        if State.AutoMagnetFlag and (State.FullAutoFarm or State.AutoEggs or State.AutoFarmCoins) and not State.IsVisitingHouses then
            pcall(useOnlyMagnetFlagIfNoneActive)
        end
        task.wait(4.0)
    end
end)

local function setupInstantEggAnimationBypass()
    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local client = lib and lib:FindFirstChild("Client")
        if client then
            for _, modName in ipairs({"EggFrontend", "CustomEggFrontend", "EggCmds"}) do
                local mObj = client:FindFirstChild(modName)
                if mObj then
                    local ok, mod = pcall(require, mObj)
                    if ok and type(mod) == "table" then
                        for _, fnName in ipairs({"PlayEggAnimation", "OpenEgg", "PlayAnimation"}) do
                            if type(mod[fnName]) == "function" then
                                local origFn = env["Orig_" .. modName .. "_" .. fnName] or mod[fnName]
                                env["Orig_" .. modName .. "_" .. fnName] = origFn
                                mod[fnName] = function(...)
                                    if State.InstantEggOpen and (State.AutoEggs or State.FullAutoFarm) then
                                        return true
                                    end
                                    return origFn(...)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    pcall(function()
        if not getsenv then return end
        local pscripts = LocalPlayer:FindFirstChild("PlayerScripts")
        if not pscripts then return end
        for _, desc in ipairs(pscripts:GetDescendants()) do
            if desc:IsA("LocalScript") and (string.find(string.lower(desc.Name), "egg") and string.find(string.lower(desc.Name), "frontend")) then
                local ok, senv = pcall(getsenv, desc)
                if ok and type(senv) == "table" and type(senv.PlayEggAnimation) == "function" then
                    local origFn = env.Orig_Senv_PlayEggAnimation or senv.PlayEggAnimation
                    env.Orig_Senv_PlayEggAnimation = origFn
                    senv.PlayEggAnimation = function(...)
                        if State.InstantEggOpen and (State.AutoEggs or State.FullAutoFarm) then
                            return true
                        end
                        return origFn(...)
                    end
                end
            end
        end
    end)
end

setupInstantEggAnimationBypass()

local function clearCameraEggModelsAndTap()
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local foundEggOnCam = false
    for _, child in ipairs(cam:GetChildren()) do
        local cName = string.lower(child.Name)
        if string.find(cName, "egg") or string.find(cName, "hatch") or child:IsA("Model") or child:IsA("Folder") then
            foundEggOnCam = true
            if State.InstantEggOpen then
                pcall(function()
                    for _, desc in ipairs(child:GetDescendants()) do
                        if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
                            desc:Destroy()
                        end
                    end
                    child:Destroy()
                end)
            end
        end
    end
    if foundEggOnCam and VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(0, 0))
        end)
    end
    return foundEggOnCam
end

task.spawn(function()
    while State.Running do
        if (State.AutoEggs or State.FullAutoFarm) and not State.IsVisitingHouses then
            clearCameraEggModelsAndTap()
            task.wait(0.08)
        else
            task.wait(0.25)
        end
    end
end)

task.spawn(function()
    while State.Running do
        task.wait(20)
        if State.Running and State.AutoJump20s and (State.FullAutoFarm or State.AutoEggs) and not State.IsVisitingHouses then
            pcall(function()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Jump = true
                end
            end)
        end
    end
end)

pcall(function()
    if hookmetamethod and getnamecallmethod and not env.HalloweenNamecallHooked then
        env.HalloweenNamecallHooked = true
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if (method == "InvokeServer" or method == "FireServer") and typeof(self) == "Instance" then
                local rName = string.lower(self.Name)
                local args = {...}
                if State.Running and State.AutoMagnetFlag and (string.find(rName, "flags: consume") or string.find(rName, "flags_consume")) then
                    local a1 = string.lower(tostring(args[1] or ""))
                    if a1 ~= "magnet flag" and tostring(args[1]) ~= tostring(State.MagnetFlagUid) then
                        return nil
                    end
                end
                if (string.find(rName, "egg") or string.find(rName, "hatch")) and not string.find(rName, "anim") then
                    State.LastCapturedEggRemote = self
                    State.LastCapturedEggArgs = args
                    if args[1] then
                        State.CachedEggId = args[1]
                        State.CachedEggRemoteName = self.Name
                    end
                    if type(args[2]) == "number" and args[2] > 1 then
                        if args[2] > State.MaxHatchDetected then
                            State.MaxHatchDetected = args[2]
                        end
                        if args[2] > (State.WorkingEggAmount or 0) then
                            State.WorkingEggAmount = args[2]
                        end
                    end
                elseif string.find(rName, "trick") or string.find(rName, "house") or string.find(rName, "door") or string.find(rName, "knock") or string.find(rName, "instancing") then
                    local arg1 = tostring(args[1] or "")
                    local arg2 = tostring(args[2] or "")
                    local combined = string.lower(rName .. " " .. arg1 .. " " .. arg2)
                    if string.find(combined, "trick") or string.find(combined, "house") or string.find(combined, "door") or string.find(combined, "knock") or string.find(combined, "treat") then
                        State.LastCapturedHouseRemote = self
                        State.LastCapturedHouseArgs = args
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end
end)

local SafetyFloorPad = nil
local function ensureSafetyFloorAt(pos)
    if not pos then return end
    pcall(function()
        if not SafetyFloorPad or not SafetyFloorPad.Parent then
            SafetyFloorPad = Instance.new("Part")
            SafetyFloorPad.Name = "HalloweenSafetyFloor"
            SafetyFloorPad.Size = Vector3.new(45, 2, 45)
            SafetyFloorPad.Anchored = true
            SafetyFloorPad.CanCollide = true
            SafetyFloorPad.Transparency = 1
            SafetyFloorPad.Parent = Workspace
        end
        SafetyFloorPad.CFrame = CFrame.new(pos.X, pos.Y - 3.2, pos.Z)
    end)
end

local function teleportSafelyTo(targetCF)
    if not targetCF then return end
    local pos = targetCF.Position
    ensureSafetyFloorAt(pos)
    pcall(function()
        if LocalPlayer.RequestStreamAroundAsync then
            LocalPlayer:RequestStreamAroundAsync(pos, 2)
        end
    end)
    for _ = 1, 4 do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = targetCF
            end)
        end
        task.wait(0.05)
    end
end

local function detectPlayerMaxEggHatch()
    local bestMax = State.MaxHatchDetected or 0

    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local client = lib and lib:FindFirstChild("Client")
        if client then
            for _, modName in ipairs({"EggCmds", "CustomEggCmds"}) do
                local mObj = client:FindFirstChild(modName)
                if mObj then
                    local ok, mod = pcall(require, mObj)
                    if ok and type(mod) == "table" then
                        for _, fnName in ipairs({"GetMaxHatch", "GetMaxHatchCount", "GetMax"}) do
                            if type(mod[fnName]) == "function" then
                                local ok2, val = pcall(mod[fnName])
                                if ok2 and tonumber(val) and tonumber(val) > bestMax then
                                    bestMax = tonumber(val)
                                end
                            end
                        end
                    end
                end
            end
            local saveMod = client:FindFirstChild("Save")
            if saveMod then
                local ok, Save = pcall(require, saveMod)
                local data = ok and Save and Save.Get and Save.Get()
                if type(data) == "table" then
                    for _, k in ipairs({"EggsHatched", "CustomEggsHatched", "EggSlotsPurchased", "MaxEggs"}) do
                        local v = tonumber(data[k])
                        if v and v > bestMax and v <= 150 then
                            bestMax = v
                        end
                    end
                end
            end
        end
    end)

    if bestMax > 1 then
        State.MaxHatchDetected = math.clamp(bestMax, 1, 150)
        State.WorkingEggAmount = State.MaxHatchDetected
    end
    return State.MaxHatchDetected
end

local function getTargetEggBatchSize()
    if State.CustomEggCount and State.CustomEggCount > 0 then
        return State.CustomEggCount
    end
    local detected = detectPlayerMaxEggHatch()
    if detected and detected > 1 then
        return detected
    end
    if State.WorkingEggAmount and State.WorkingEggAmount > 1 then
        return State.WorkingEggAmount
    end
    return 79
end

local function getAllPlayerCurrencies()
    local snapshot = {}
    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local client = lib and lib:FindFirstChild("Client")
        if client then
            local saveMod = client:FindFirstChild("Save")
            if saveMod then
                local ok, Save = pcall(require, saveMod)
                local data = ok and Save and Save.Get and Save.Get()
                if type(data) == "table" and type(data.Inventory) == "table" and type(data.Inventory.Currency) == "table" then
                    for uid, item in pairs(data.Inventory.Currency) do
                        if type(item) == "table" then
                            local id = tostring(item.id or uid)
                            local amt = tonumber(item._am) or tonumber(item.amount) or 0
                            snapshot["inv_" .. id] = (snapshot["inv_" .. id] or 0) + amt
                        end
                    end
                end
            end
            local currMod = client:FindFirstChild("CurrencyCmds")
            if currMod then
                local ok, CurrencyCmds = pcall(require, currMod)
                if ok and type(CurrencyCmds) == "table" and type(CurrencyCmds.Get) == "function" then
                    for _, cName in ipairs({"Halloween Candy", "Candy", "Coins", "HalloweenOrb", "HatchWarCoins", "Blood Moon", "Halloween Coins", "Event Coins", "Diamonds"}) do
                        local okC, val = pcall(CurrencyCmds.Get, cName)
                        if okC and type(val) == "number" and val > 0 then
                            snapshot["cmd_" .. cName] = val
                        end
                    end
                end
            end
        end
    end)

    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, stat in ipairs(ls:GetChildren()) do
                local v = tonumber(stat.Value)
                if v and v > 0 then
                    snapshot["ls_" .. stat.Name] = v
                end
            end
        end
    end)

    return snapshot
end

local function canAffordViaClientLibrary(eggId, batchCount)
    local canAfford = nil
    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        if not lib then return end
        local dirMod = lib:FindFirstChild("Directory")
        local client = lib:FindFirstChild("Client")
        if not dirMod or not client then return end

        local okD, Directory = pcall(require, dirMod)
        local calcMod = client:FindFirstChild("CalcEggPricePlayer")
        local currMod = client:FindFirstChild("CurrencyCmds")
        if not okD or type(Directory) ~= "table" or not currMod then return end

        local okC, CurrencyCmds = pcall(require, currMod)
        if not okC or type(CurrencyCmds) ~= "table" or type(CurrencyCmds.Get) ~= "function" then return end

        local eggData = (Directory.Eggs and Directory.Eggs[eggId]) or (Directory.CustomEggs and Directory.CustomEggs[eggId])
        if type(eggData) == "table" then
            local unitPrice = tonumber(eggData.currencyCost) or tonumber(eggData.cost)
            if calcMod then
                local okP, calcFn = pcall(require, calcMod)
                if okP and type(calcFn) == "function" then
                    local okVal, pVal = pcall(calcFn, eggData)
                    if okVal and tonumber(pVal) then
                        unitPrice = tonumber(pVal)
                    end
                end
            end
            local currId = eggData.currency or eggData.currencyId
            if unitPrice and unitPrice > 0 and currId then
                local okBal, balance = pcall(CurrencyCmds.Get, currId)
                if okBal and type(balance) == "number" then
                    canAfford = (balance >= (unitPrice * batchCount))
                end
            end
        end
    end)
    return canAfford
end

local function hasEnoughCurrencyForFullBatch(eggId, batchCount)
    local libCheck = canAffordViaClientLibrary(eggId, batchCount)
    if libCheck == false then
        return false
    end

    if State.LearnedEggId == eggId and State.LearnedCurrencyKey and State.LearnedBatchCost > 0 then
        local currSnap = getAllPlayerCurrencies()
        local curVal = currSnap[State.LearnedCurrencyKey]
        if type(curVal) == "number" then
            if curVal < (State.LearnedBatchCost * 0.96) then
                return false
            end
        end
    end

    return true
end

local function recordBatchCurrencySpend(eggId, beforeSnap, afterSnap)
    local bestKey = nil
    local bestDrop = 0
    for k, beforeVal in pairs(beforeSnap) do
        local afterVal = afterSnap[k]
        if type(beforeVal) == "number" and type(afterVal) == "number" then
            local drop = beforeVal - afterVal
            if drop > bestDrop then
                bestDrop = drop
                bestKey = k
            end
        end
    end
    if bestKey and bestDrop > 0 then
        if State.LearnedEggId ~= eggId then
            State.LearnedEggId = eggId
            State.LearnedCurrencyKey = bestKey
            State.LearnedBatchCost = bestDrop
        else
            State.LearnedCurrencyKey = bestKey
            if bestDrop > State.LearnedBatchCost then
                State.LearnedBatchCost = bestDrop
            end
        end
    end
end

local function collectAllOrbsAndLootbagsNow()
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local things = getThingsFolder()
        if not hrp or not things then return end

        local orbs = things:FindFirstChild("Orbs")
        if orbs then
            local orbIds = {}
            for _, orb in ipairs(orbs:GetChildren()) do
                if orb:IsA("BasePart") then
                    orb.CFrame = hrp.CFrame
                elseif orb:IsA("Model") then
                    orb:PivotTo(hrp.CFrame)
                end
                local numId = tonumber(orb.Name)
                if numId then table.insert(orbIds, numId) end
            end
            if #orbIds > 0 then
                invokeRemote("Orbs: Collect", orbIds)
            end
        end

        local lootbags = things:FindFirstChild("Lootbags")
        if lootbags then
            for _, bag in ipairs(lootbags:GetChildren()) do
                if bag:IsA("BasePart") then
                    bag.CFrame = hrp.CFrame
                elseif bag:IsA("Model") then
                    bag:PivotTo(hrp.CFrame)
                end
                invokeRemote("Lootbags_Claim", { bag.Name })
            end
        end
    end)
end

local function farmNearbyBreakables()
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local things = getThingsFolder()
        if not hrp or not things then return end

        local breakables = things:FindFirstChild("Breakables")
        if not breakables then return end

        local myPos = hrp.Position
        local dmgRemote = findRemote("Breakables_PlayerDealDamage")
        local count = 0

        for _, b in ipairs(breakables:GetChildren()) do
            local bPos = getObjectPosition(b)
            if bPos and (bPos - myPos).Magnitude <= 120 then
                local uid = b.Name
                if dmgRemote and (dmgRemote:IsA("RemoteEvent") or dmgRemote.ClassName == "UnreliableRemoteEvent") then
                    pcall(function() dmgRemote:FireServer(uid) end)
                else
                    invokeRemote("Breakables_PlayerDealDamage", uid)
                end
                count = count + 1
                if count >= 5 then break end
            end
        end
    end)
end

local function findNearestEggCandidates(maxRadius)
    local radius = maxRadius or 75
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    local myPos = hrp.Position

    local candidates = {}
    local seen = {}

    local function addCand(uid, attrId, pos, isCustom, obj)
        if not pos then return end
        local d = (pos - myPos).Magnitude
        if d > radius then return end
        local key = tostring(uid) .. "|" .. tostring(attrId)
        if seen[key] then return end
        seen[key] = true
        table.insert(candidates, {
            uid = uid,
            attrId = attrId,
            pos = pos,
            dist = d,
            isCustom = isCustom,
            obj = obj
        })
    end

    local things = getThingsFolder()
    if things then
        local ce = things:FindFirstChild("CustomEggs")
        if ce then
            for _, egg in ipairs(ce:GetChildren()) do
                local pos = getObjectPosition(egg)
                local attr = egg:GetAttribute("id") or egg:GetAttribute("EggName") or egg:GetAttribute("ID")
                addCand(egg.Name, attr, pos, true, egg)
            end
        end
        local ef = things:FindFirstChild("Eggs")
        if ef then
            for _, egg in ipairs(ef:GetChildren()) do
                local pos = getObjectPosition(egg)
                local attr = egg:GetAttribute("EggName") or egg:GetAttribute("id") or egg:GetAttribute("ID")
                local cleanName = string.match(egg.Name, "^%d+%s*-%s*(.+)$") or egg.Name
                addCand(egg.Name, attr or cleanName, pos, false, egg)
            end
        end
    end

    local activeInst, activeFolder = getActiveInstanceContainer()
    if activeFolder then
        for _, d in ipairs(activeFolder:GetDescendants()) do
            if d.Parent and (d.Parent.Name == "CustomEggs" or d.Parent.Name == "Eggs" or d.Parent.Name == "EggCapsules") then
                local pos = getObjectPosition(d)
                local attr = d:GetAttribute("id") or d:GetAttribute("EggName") or d:GetAttribute("ID")
                addCand(d.Name, attr, pos, d.Parent.Name == "CustomEggs", d)
            end
        end
    end

    table.sort(candidates, function(a, b) return a.dist < b.dist end)
    return candidates
end

local function enterHalloweenEventAndGoToCoords()
    loadCoordsFromDisk()
    local targetCF = State.SavedEggCFrame or DefaultSpawnCFrame

    setStatusText("Teleport -> 7538.1, 15.7, 21965.5...", nil)
    teleportSafelyTo(targetCF)
    task.wait(0.4)

    if #findNearestEggCandidates(120) == 0 then
        local things = getThingsFolder()
        local instancesFolder = things and things:FindFirstChild("Instances")
        local candidateIds = {}

        if instancesFolder then
            for _, instObj in ipairs(instancesFolder:GetChildren()) do
                local low = string.lower(instObj.Name)
                local isFishingOrOther = string.find(low, "fish") or string.find(low, "dig") or string.find(low, "mine") or string.find(low, "garden") or string.find(low, "obby") or string.find(low, "claw") or string.find(low, "chest") or string.find(low, "kart")
                if not isFishingOrOther then
                    if string.find(low, "halloween") or string.find(low, "hatch") or string.find(low, "trick") or string.find(low, "spooky") or string.find(low, "manor") then
                        table.insert(candidateIds, instObj.Name)
                    end
                end
            end
        end

        for _, extraId in ipairs({"HatchWars", "HalloweenEvent", "HalloweenWorld", "TrickOrTreat", "SpookyEvent"}) do
            table.insert(candidateIds, extraId)
        end

        for _, tryName in ipairs(candidateIds) do
            invokeRemote("Instancing_PlayerEnterInstance", tryName)
            invokeRemote("Teleports_RequestInstance", tryName)
        end

        task.wait(0.8)
        teleportSafelyTo(targetCF)
        task.wait(0.3)
    end

    applyGameLanguageNow(State.LanguageIndex)
    updatePetsAndLollipopsInventory()
    pcall(useOnlyMagnetFlagIfNoneActive)
    setStatusText("At coordinates (7538.1, 15.7, 21965.5)", nil)
end

trackConn(LocalPlayer.CharacterAdded:Connect(function()
    if not State.Running then return end
    task.wait(1.2)
    if State.SavedEggCFrame and (State.FullAutoFarm or State.AutoEggs) then
        pcall(enterHalloweenEventAndGoToCoords)
    end
end))

local function invokeEggBatch(remoteObj, eggId, batchCount)
    local beforeSnap = getAllPlayerCurrencies()
    local ok, res, extra = pcall(function()
        if remoteObj:IsA("RemoteFunction") then
            return remoteObj:InvokeServer(eggId, batchCount)
        else
            remoteObj:FireServer(eggId, batchCount)
            return true
        end
    end)
    if ok and res ~= false and res ~= nil then
        State.TotalEggsHatched = State.TotalEggsHatched + batchCount
        State.TotalEggBatches = State.TotalEggBatches + 1
        clearCameraEggModelsAndTap()
        task.delay(0.08, function()
            local afterSnap = getAllPlayerCurrencies()
            recordBatchCurrencySpend(eggId, beforeSnap, afterSnap)
            updatePetsAndLollipopsInventory()
            clearCameraEggModelsAndTap()
        end)
        return true, nil
    end
    return false, tostring(extra or res or "")
end

local function probeMaxEggCountForOtherPlayers(remoteObj, eggId)
    local ladder = { 99, 90, 84, 79, 75, 64, 50, 35, 25, 15, 8, 4 }
    for _, amt in ipairs(ladder) do
        local success = invokeEggBatch(remoteObj, eggId, amt)
        if success then
            local low = amt + 1
            local high = math.min(amt + 20, 120)
            local best = amt
            while low <= high do
                local mid = math.floor((low + high) / 2)
                task.wait(2.0)
                local okM = invokeEggBatch(remoteObj, eggId, mid)
                if okM then
                    best = mid
                    low = mid + 1
                else
                    high = mid - 1
                end
            end
            State.WorkingEggAmount = best
            State.MaxHatchDetected = best
            return true, best
        end
    end
    return false, 0
end

local function fastHatchOnce()
    if State.IsVisitingHouses or State.IsHatchingNow then return false end
    State.IsHatchingNow = true

    local didHatch = false
    pcall(function()
        local targetAmt = getTargetEggBatchSize()

        if State.CachedEggRemoteName and State.CachedEggId then
            local r = findRemote(State.CachedEggRemoteName)
            if r then
                if not hasEnoughCurrencyForFullBatch(State.CachedEggId, targetAmt) and State.LowCoinWaitCount < 3 then
                    State.LowCoinWaitCount = State.LowCoinWaitCount + 1
                    collectAllOrbsAndLootbagsNow()
                    farmNearbyBreakables()
                    setStatusText(string.format("Coins wait for %d eggs (%d/3)...", targetAmt, State.LowCoinWaitCount), nil)
                    return
                end

                State.LowCoinWaitCount = 0
                local success = invokeEggBatch(r, State.CachedEggId, targetAmt)
                if success then
                    didHatch = true
                    setStatusText(string.format("Hatched: %d eggs (total: %s)", targetAmt, formatNumber(State.TotalEggsHatched)), nil)
                    return
                else
                    collectAllOrbsAndLootbagsNow()
                    farmNearbyBreakables()
                    setStatusText(string.format("Waiting coins/CD for %d eggs...", targetAmt), nil)
                    return
                end
            end
        end

        local cands = findNearestEggCandidates(75)
        if #cands == 0 and State.SavedEggCFrame then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - State.SavedEggCFrame.Position).Magnitude > 18 then
                pcall(function() hrp.CFrame = State.SavedEggCFrame end)
                task.wait(0.15)
                cands = findNearestEggCandidates(75)
            end
        end

        if #cands > 0 then
            local best = cands[1]
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and not State.SavedEggCFrame then
                State.SavedEggCFrame = hrp.CFrame
                saveCoordsToDisk(hrp.CFrame)
            end

            local remotesToTry = {"CustomEggs_Hatch", "Eggs_RequestPurchase"}
            local idsToTry = {}
            if best.uid then table.insert(idsToTry, best.uid) end
            if best.attrId and best.attrId ~= best.uid then table.insert(idsToTry, best.attrId) end

            for _, rName in ipairs(remotesToTry) do
                local r = findRemote(rName)
                if r and r:IsA("RemoteFunction") then
                    for _, idVal in ipairs(idsToTry) do
                        local success = invokeEggBatch(r, idVal, targetAmt)
                        if success then
                            State.CachedEggRemoteName = rName
                            State.CachedEggId = idVal
                            didHatch = true
                            setStatusText(string.format("Hatched: %s (%dx | total %s)", tostring(best.attrId or idVal), targetAmt, formatNumber(State.TotalEggsHatched)), nil)
                            return
                        elseif State.CustomEggCount == 0 then
                            local okProbe, bestCount = probeMaxEggCountForOtherPlayers(r, idVal)
                            if okProbe then
                                State.CachedEggRemoteName = rName
                                State.CachedEggId = idVal
                                didHatch = true
                                setStatusText(string.format("Auto-max: %s (%dx)", tostring(best.attrId or idVal), bestCount), nil)
                                return
                            end
                        end
                    end
                end
            end

            collectAllOrbsAndLootbagsNow()
            farmNearbyBreakables()
            setStatusText(string.format("Farming coins for %d eggs...", targetAmt), nil)
        else
            setStatusText("Stand near egg and click Save Position", nil)
        end
    end)

    State.IsHatchingNow = false
    return didHatch
end

task.spawn(function()
    while State.Running do
        if (State.AutoEggs or State.FullAutoFarm) and not State.IsVisitingHouses then
            fastHatchOnce()
            task.wait(State.EggHatchDelay or 2.0)
        else
            task.wait(0.25)
        end
    end
end)

local LastDotClick = {}
local function isMinigameActiveOnScreen()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return false end
    local foundActive = false
    local now = tick()

    for _, screen in ipairs(pgui:GetChildren()) do
        if screen:IsA("ScreenGui") and screen.Enabled and screen.Name ~= "HalloweenEventGui" and screen.Name ~= "Message" then
            local sName = string.lower(screen.Name)
            local isMinigameScreen = string.find(sName, "minigame")
                or string.find(sName, "trickortreat")
                or string.find(sName, "trick_or_treat")
                or string.find(sName, "hatchbattle")
                or string.find(sName, "hatch_battle")
                or string.find(sName, "doorgame")
                or string.find(sName, "captcha")

            if isMinigameScreen then
                for _, obj in ipairs(screen:GetDescendants()) do
                    if obj:IsA("GuiButton") and obj.Visible then
                        local oName = string.lower(obj.Name)
                        if not string.find(oName, "close") and not string.find(oName, "exit") and not string.find(oName, "cancel") and not string.find(oName, "leave") then
                            foundActive = true
                            if State.AutoMinigame then
                                local lastTime = LastDotClick[obj] or 0
                                if now - lastTime > 0.06 then
                                    LastDotClick[obj] = now
                                    fireSafeSignal(obj)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return foundActive
end

task.spawn(function()
    while State.Running do
        if State.AutoMinigame then
            pcall(isMinigameActiveOnScreen)
            task.wait(0.05)
        else
            task.wait(0.3)
        end
    end
end)

local function inspectDoorCloseUp(house)
    local isLocked = false
    local unlockCost = nil
    local liveCooldown = nil

    local function checkRawString(raw)
        if not raw or raw == "" then return end
        local low = string.lower(raw)
        local cd = parseCooldownFromText(raw)
        if cd and cd > 0 then
            liveCooldown = cd
            return
        end
        if string.find(low, "locked") or string.find(low, "unlock") or string.find(low, "purchase") or string.find(low, "buy") or string.find(low, "lollipop") or string.find(low, "закрито") or string.find(low, "закрыто") or string.find(low, "розблок") or string.find(low, "разблок") or string.find(low, "купити") or string.find(low, "купить") then
            isLocked = true
            local c = parseSuffixedNumber(string.match(raw, "([%d%,%.]+%s*[kKmMbB]?)"))
            if c and c > 0 then
                unlockCost = c
            end
        end
    end

    pcall(function()
        if house.prompt and house.prompt.Parent then
            checkRawString(house.prompt.ActionText)
            checkRawString(house.prompt.ObjectText)
            local pAttr = tonumber(house.prompt:GetAttribute("Price")) or tonumber(house.prompt:GetAttribute("Cost")) or tonumber(house.prompt:GetAttribute("UnlockCost"))
            if pAttr and pAttr > 0 then
                isLocked = true
                unlockCost = pAttr
            end
            if house.prompt:GetAttribute("Locked") == true or house.prompt:GetAttribute("Unlocked") == false then
                isLocked = true
            end
        end

        if house.instance then
            if house.instance:GetAttribute("Locked") == true or house.instance:GetAttribute("Unlocked") == false then
                isLocked = true
            end
            local mCost = tonumber(house.instance:GetAttribute("Price")) or tonumber(house.instance:GetAttribute("Cost")) or tonumber(house.instance:GetAttribute("UnlockCost"))
            if mCost and mCost > 0 then
                isLocked = true
                unlockCost = mCost
            end
        end

        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                local pPos = getObjectPosition(d.Parent)
                if pPos and (pPos - house.pos).Magnitude <= 14 then
                    checkRawString(d.ActionText)
                    checkRawString(d.ObjectText)
                end
            elseif (d:IsA("BillboardGui") or d:IsA("SurfaceGui")) and d.Enabled then
                local bPos = getObjectPosition(d.Adornee or d.Parent)
                if bPos and (bPos - house.pos).Magnitude <= 15 then
                    for _, sub in ipairs(d:GetDescendants()) do
                        if sub:IsA("TextLabel") and isGuiActuallyVisible(sub) and sub.Text ~= "" then
                            checkRawString(sub.Text)
                        end
                    end
                end
            end
        end
    end)

    return isLocked, unlockCost, liveCooldown
end

local function findGroundDoorPosition(modelOrPart, playerGroundY)
    if modelOrPart:IsA("BasePart") then
        if math.abs(modelOrPart.Position.Y - playerGroundY) <= 14 then
            return Vector3.new(modelOrPart.Position.X, playerGroundY, modelOrPart.Position.Z), modelOrPart, nil
        end
        return nil, nil, nil
    end

    local bestPart = nil
    local bestScore = -999

    for _, d in ipairs(modelOrPart:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Parent and d.Parent:IsA("BasePart") then
            local p = d.Parent
            if math.abs(p.Position.Y - playerGroundY) <= 16 then
                return Vector3.new(p.Position.X, playerGroundY, p.Position.Z), p, d
            end
        elseif d:IsA("TouchTransmitter") and d.Parent and d.Parent:IsA("BasePart") then
            local p = d.Parent
            if math.abs(p.Position.Y - playerGroundY) <= 14 then
                return Vector3.new(p.Position.X, playerGroundY, p.Position.Z), p, nil
            end
        elseif d:IsA("BasePart") then
            local n = string.lower(d.Name)
            local yDiff = math.abs(d.Position.Y - playerGroundY)
            if yDiff <= 14 then
                local score = 0
                if string.find(n, "pad") or string.find(n, "interact") or string.find(n, "prompt") or string.find(n, "trigger") or string.find(n, "ring") or string.find(n, "zone") then
                    score = 50 - yDiff
                elseif string.find(n, "door") or string.find(n, "step") or string.find(n, "mat") then
                    score = 30 - yDiff
                end
                if score > bestScore then
                    bestScore = score
                    bestPart = d
                end
            end
        end
    end

    if bestPart then
        local offset = bestPart.CFrame.LookVector * 3.5
        return Vector3.new(bestPart.Position.X + offset.X, playerGroundY, bestPart.Position.Z + offset.Z), bestPart, nil
    end

    return nil, nil, nil
end

local function scanAllHousesWithState(playerGroundY, originPos)
    local rawHouses = {}
    local seenPositions = {}
    local _, _, _, curLollipops = updatePetsAndLollipopsInventory()

    local function addUniqueHouse(rawName, pos, inst, promptObj)
        if not pos then return end
        if (pos - originPos).Magnitude > 380 then return end
        local groundPos = Vector3.new(pos.X, playerGroundY, pos.Z)
        for _, existing in ipairs(seenPositions) do
            if (existing - groundPos).Magnitude < 14 then
                return
            end
        end

        local posKey = string.format("house_%d_%d", math.floor(groundPos.X / 12 + 0.5), math.floor(groundPos.Z / 12 + 0.5))
        local rawId = nil
        pcall(function()
            if inst then
                rawId = inst:GetAttribute("Id") or inst:GetAttribute("ID") or inst:GetAttribute("HouseId") or inst:GetAttribute("DoorId") or inst.Name
            end
        end)

        table.insert(seenPositions, groundPos)
        table.insert(rawHouses, {
            key = posKey,
            rawName = rawName,
            rawId = rawId,
            pos = groundPos,
            instance = inst,
            prompt = promptObj
        })
    end

    if #State.CustomHousePoints > 0 then
        for idx, cf in ipairs(State.CustomHousePoints) do
            addUniqueHouse("House" .. idx, cf.Position, nil, nil)
        end
    else
        local searchRoots = {}
        local activeInst, activeFolder = getActiveInstanceContainer()
        if activeInst then table.insert(searchRoots, activeInst) end
        if activeFolder then table.insert(searchRoots, activeFolder) end
        local things = getThingsFolder()
        if things then table.insert(searchRoots, things) end
        local mapFolder = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("Map2")
        if mapFolder then table.insert(searchRoots, mapFolder) end

        for _, root in ipairs(searchRoots) do
            for _, desc in ipairs(root:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    local pPos = getObjectPosition(desc.Parent)
                    if pPos and math.abs(pPos.Y - playerGroundY) <= 16 then
                        local actionTxt = string.lower((desc.ActionText or "") .. " " .. (desc.ObjectText or "") .. " " .. desc:GetFullName())
                        if not string.find(actionTxt, "egg") and not string.find(actionTxt, "leave") and not string.find(actionTxt, "exit") and not string.find(actionTxt, "teleport") and not string.find(actionTxt, "upgrade") and not string.find(actionTxt, "machine") and not string.find(actionTxt, "merchant") then
                            local hModel = desc.Parent
                            if hModel.Parent and string.find(string.lower(hModel.Parent.Name), "house") and string.lower(hModel.Parent.Name) ~= "houses" then
                                hModel = hModel.Parent
                            end
                            local hName = (desc.ObjectText ~= "" and desc.ObjectText) or hModel.Name
                            addUniqueHouse(hName, pPos, hModel, desc)
                        end
                    end
                end
            end
            if #rawHouses > 0 then break end
        end

        if #rawHouses == 0 then
            for _, root in ipairs(searchRoots) do
                for _, folder in ipairs(root:GetDescendants()) do
                    local fn = string.lower(folder.Name)
                    if (folder:IsA("Folder") or folder:IsA("Model")) and (fn == "houses" or fn == "trickortreat" or fn == "spookyhouses" or fn == "doors") then
                        for _, hModel in ipairs(folder:GetChildren()) do
                            local doorPos, _, promptObj = findGroundDoorPosition(hModel, playerGroundY)
                            if doorPos then
                                addUniqueHouse(hModel.Name, doorPos, hModel, promptObj)
                            end
                        end
                    end
                end
                if #rawHouses > 0 then break end
            end
        end
    end

    table.sort(rawHouses, function(a, b)
        local za = math.floor(a.pos.Z / 16 + 0.5)
        local zb = math.floor(b.pos.Z / 16 + 0.5)
        if za ~= zb then
            return za < zb
        end
        return a.pos.X < b.pos.X
    end)

    local now = tick()
    local houses = {}
    for idx, rh in ipairs(rawHouses) do
        local key = rh.key
        local displayName = "House" .. idx
        local readyAt = State.HouseCooldownMap[key] or 0
        local remCd = math.max(0, readyAt - now)

        local lockedMem = State.LockedHouseInfo[key]
        local isLocked = false
        local unlockCost = nil
        local canTryUnlockNow = false

        if lockedMem and lockedMem.locked and not State.ConfirmedUnlockedHouses[key] then
            isLocked = true
            unlockCost = lockedMem.requiredCost
            if State.AutoBuyHouses then
                local prevLolli = lockedMem.lollipopsAtAttempt or 0
                if unlockCost and unlockCost > 0 then
                    canTryUnlockNow = (curLollipops >= unlockCost)
                else
                    canTryUnlockNow = (curLollipops > prevLolli and (now - (lockedMem.lastTryTime or 0) >= 35))
                end
            end
        end

        local isReady = false
        if not isLocked then
            isReady = (remCd <= 0)
        elseif canTryUnlockNow then
            isReady = true
        end

        table.insert(houses, {
            index = idx,
            key = key,
            name = displayName,
            rawName = rh.rawName,
            rawId = rh.rawId,
            pos = rh.pos,
            instance = rh.instance,
            prompt = rh.prompt,
            isLocked = isLocked,
            unlockCost = unlockCost,
            canTryUnlockNow = canTryUnlockNow,
            remainingCd = remCd,
            isReady = isReady
        })
    end

    if State.MaxUnlockedHouses > 0 and #houses > State.MaxUnlockedHouses then
        local limited = {}
        for i = 1, State.MaxUnlockedHouses do
            table.insert(limited, houses[i])
        end
        return limited
    end

    return houses
end

local function triggerDoorFast(pos, inst, directPrompt)
    local promptsToFire = {}
    if directPrompt and directPrompt.Parent then
        table.insert(promptsToFire, directPrompt)
    end

    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local pPos = getObjectPosition(desc.Parent)
            if pPos and (pPos - pos).Magnitude <= 18 then
                table.insert(promptsToFire, desc)
            end
        end
    end

    for _, pr in ipairs(promptsToFire) do
        pcall(function()
            pr.HoldDuration = 0
            pr.RequiresLineOfSight = false
            pr.MaxActivationDistance = math.max(pr.MaxActivationDistance or 10, 40)
            pr.Enabled = true
        end)
        pcall(function()
            if fireproximityprompt then
                fireproximityprompt(pr)
            end
        end)
        pcall(function()
            pr:InputHoldBegin()
            task.wait(0.04)
            pr:InputHoldEnd()
        end)
    end

    pressKeyE(0.1)

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hrp and firetouchinterest and inst then
        pcall(function()
            if inst:IsA("BasePart") then
                firetouchinterest(hrp, inst, 0)
                firetouchinterest(hrp, inst, 1)
            elseif inst:IsA("Model") then
                for _, p in ipairs(inst:GetDescendants()) do
                    if p:IsA("BasePart") and math.abs(p.Position.Y - pos.Y) <= 12 then
                        firetouchinterest(hrp, p, 0)
                        firetouchinterest(hrp, p, 1)
                    end
                end
            end
        end)
    end
end

local function fireHouseRemotes(house, tryBuyToo)
    if State.LastCapturedHouseRemote and State.LastCapturedHouseArgs then
        local rem = State.LastCapturedHouseRemote
        local args = {}
        for i, v in ipairs(State.LastCapturedHouseArgs) do args[i] = v end
        task.spawn(function()
            pcall(function()
                if rem:IsA("RemoteFunction") then
                    rem:InvokeServer(unpack(args))
                elseif rem:IsA("RemoteEvent") then
                    rem:FireServer(unpack(args))
                end
            end)
        end)
    end

    local activeInst = getActiveInstanceContainer()
    local instName = activeInst and activeInst.Name or "HatchWars"
    local numId = tonumber(string.match(tostring(house.rawId or house.rawName or house.name), "%d+")) or house.index or 1
    local rawId = house.rawId or numId

    task.spawn(function()
        if tryBuyToo then
            for _, buyAct in ipairs({"UnlockHouse", "BuyHouse", "PurchaseHouse", "UnlockDoor", "PurchaseDoor"}) do
                invokeRemote("Instancing_FireCustomFromClient", instName, buyAct, numId)
                invokeRemote("Instancing_InvokeCustomFromClient", instName, buyAct, numId)
                if rawId ~= numId then
                    invokeRemote("Instancing_FireCustomFromClient", instName, buyAct, rawId)
                    invokeRemote("Instancing_InvokeCustomFromClient", instName, buyAct, rawId)
                end
            end
            invokeRemote("TrickOrTreat_UnlockHouse", numId)
            invokeRemote("TrickOrTreat_BuyHouse", numId)
        end
        local actions = { "Knock", "TrickOrTreat", "ClaimHouse", "OpenDoor", "Interact" }
        for _, act in ipairs(actions) do
            invokeRemote("Instancing_FireCustomFromClient", instName, act, numId)
            invokeRemote("Instancing_InvokeCustomFromClient", instName, act, numId)
            if rawId ~= numId then
                invokeRemote("Instancing_FireCustomFromClient", instName, act, rawId)
            end
        end
        invokeRemote("TrickOrTreat_Knock", numId)
        invokeRemote("TrickOrTreat_Interact", numId)
    end)
end

local function visitReadyHousesAndReturn(forceAll)
    if State.IsVisitingHouses then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if forceAll then
        State.HouseCooldownMap = {}
        State.LockedHouseInfo = {}
    end

    local returnCF = State.SavedEggCFrame or DefaultSpawnCFrame
    local groundY = returnCF.Position.Y
    local allHouses = scanAllHousesWithState(groundY, returnCF.Position)

    if #allHouses == 0 then
        setStatusText(nil, "Houses not found nearby")
        return
    end

    local housesToProcess = {}
    local minCd = 999999
    local onTimerCount = 0
    local lockedCount = 0

    for _, h in ipairs(allHouses) do
        if h.isReady or forceAll then
            table.insert(housesToProcess, h)
        elseif h.isLocked then
            lockedCount = lockedCount + 1
        else
            onTimerCount = onTimerCount + 1
            if h.remainingCd < minCd then
                minCd = h.remainingCd
            end
        end
    end

    if #housesToProcess == 0 then
        local mins = math.floor(minCd / 60)
        local secs = math.floor(minCd % 60)
        if minCd >= 999999 then mins, secs = 0, 0 end
        setStatusText(nil, string.format("Houses on 10m timer: %d | Locked: %d | Next: %02d:%02d", onTimerCount, lockedCount, mins, secs))
        return
    end

    State.IsVisitingHouses = true
    local stepWait = math.max(1.0, tonumber(State.HouseStepDelay) or 4.0)

    local ok, err = pcall(function()
        for i, house in ipairs(housesToProcess) do
            if not State.Running then break end
            char = LocalPlayer.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then break end

            local _, _, _, lollipopsBefore = updatePetsAndLollipopsInventory()
            local doorGroundCF = CFrame.new(house.pos.X, groundY + 0.5, house.pos.Z)
            teleportSafelyTo(doorGroundCF)
            task.wait(0.3)

            local closeLocked, closeCost, closeCd = inspectDoorCloseUp(house)

            if closeCd and closeCd > 0 and not State.ConfirmedUnlockedHouses[house.key] then
                State.ConfirmedUnlockedHouses[house.key] = true
                State.LockedHouseInfo[house.key] = nil
                State.HouseCooldownMap[house.key] = tick() + closeCd
                addLog("INFO", string.format("%s already on timer (%ds), skipping.", tostring(house.name), closeCd))
            elseif (closeLocked or house.isLocked) and not State.ConfirmedUnlockedHouses[house.key] and (not State.AutoBuyHouses or (closeCost and closeCost > 0 and lollipopsBefore < closeCost)) then
                local reqCost = closeCost or house.unlockCost
                State.LockedHouseInfo[house.key] = {
                    locked = true,
                    lollipopsAtAttempt = lollipopsBefore,
                    requiredCost = reqCost,
                    lastTryTime = tick()
                }
                setStatusText(nil, string.format("Skipping locked %s (Lollipops: %s/%s)", tostring(house.name), formatNumber(lollipopsBefore), tostring(reqCost or "?")))
                addLog("INFO", string.format("Пропущено закритий %s (Lollipop %s/%s) без натискання.", tostring(house.name), formatNumber(lollipopsBefore), tostring(reqCost or "?")))
            else
                State.LastPopupWasError = false
                State.LastPopupPurchased = false
                State.LastHouseWasOnCooldown = false
                State.LastParsedCooldownSecs = nil
                State.LastPopupErrorText = ""
                State.LastPopupCostNumber = nil
                State.AllowConfirmPurchasePopup = State.AutoBuyHouses
                local notifBefore = snapshotNotifications()

                setStatusText(nil, string.format("Opening %s (%d/%d) — %.0fs...", tostring(house.name), i, #housesToProcess, stepWait))

                local waitStarted = tick()
                local triggeredSecondTime = false
                local triggeredAfterBuy = false

                triggerDoorFast(doorGroundCF.Position, house.instance, house.prompt)
                fireHouseRemotes(house, closeLocked or house.isLocked)

                while (tick() - waitStarted < stepWait) and State.Running do
                    checkAndDismissGamePopups()
                    inspectNewNotifications(notifBefore)

                    if State.LastPopupPurchased and not triggeredAfterBuy then
                        triggeredAfterBuy = true
                        task.wait(0.25)
                        triggerDoorFast(doorGroundCF.Position, house.instance, house.prompt)
                        fireHouseRemotes(house, false)
                    end

                    if State.LastPopupWasError or State.LastHouseWasOnCooldown then
                        break
                    end

                    local elapsed = tick() - waitStarted
                    if elapsed >= (stepWait * 0.45) and not triggeredSecondTime then
                        triggeredSecondTime = true
                        triggerDoorFast(doorGroundCF.Position, house.instance, house.prompt)
                    end
                    isMinigameActiveOnScreen()
                    collectAllOrbsAndLootbagsNow()
                    task.wait(0.12)
                end

                State.AllowConfirmPurchasePopup = false
                checkAndDismissGamePopups()
                inspectNewNotifications(notifBefore)
                collectAllOrbsAndLootbagsNow()

                local _, _, _, lollipopsAfter = updatePetsAndLollipopsInventory()

                if State.LastPopupWasError and not State.LastPopupPurchased and lollipopsAfter <= lollipopsBefore then
                    local reqCost = State.LastPopupCostNumber or closeCost or house.unlockCost
                    State.LockedHouseInfo[house.key] = {
                        locked = true,
                        lollipopsAtAttempt = lollipopsAfter,
                        requiredCost = reqCost,
                        lastTryTime = tick()
                    }
                    State.ConfirmedUnlockedHouses[house.key] = nil
                    addLog("INFO", string.format("%s закритий (Lollipop %s/%s). Переходжу далі.", tostring(house.name), formatNumber(lollipopsAfter), tostring(reqCost or "?")))
                elseif State.LastHouseWasOnCooldown and lollipopsAfter <= lollipopsBefore then
                    State.ConfirmedUnlockedHouses[house.key] = true
                    State.LockedHouseInfo[house.key] = nil
                    local cdToSet = State.LastParsedCooldownSecs or 180
                    State.HouseCooldownMap[house.key] = tick() + cdToSet
                else
                    State.ConfirmedUnlockedHouses[house.key] = true
                    State.LockedHouseInfo[house.key] = nil
                    State.TotalHousesOpened = State.TotalHousesOpened + 1
                    State.HouseCooldownMap[house.key] = tick() + (State.HouseCooldownDefault or 600)
                    addLog("OK", string.format("Відкрито %s! Таймер 10:00 запущено.", tostring(house.name)))
                end
            end
        end
    end)

    State.AllowConfirmPurchasePopup = false
    checkAndDismissGamePopups()

    if not ok then
        addLog("ERR", "House error: " .. tostring(err))
    end

    if returnCF and State.Running then
        teleportSafelyTo(returnCF)
        pcall(useOnlyMagnetFlagIfNoneActive)
        setStatusText(nil, string.format("Returned to egg (waiting %.0fs)...", stepWait))
        task.wait(stepWait)
    end

    State.IsVisitingHouses = false
end

task.spawn(function()
    while State.Running do
        if State.FullAutoFarm and not State.IsVisitingHouses then
            pcall(function()
                visitReadyHousesAndReturn(false)
            end)
            task.wait(1.5)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while State.Running do
        if State.AutoFarmCoins or State.FullAutoFarm then
            collectAllOrbsAndLootbagsNow()
            if not State.IsVisitingHouses then
                farmNearbyBreakables()
            end
            task.wait(0.3)
        else
            task.wait(0.5)
        end
    end
end)

local function runEventDiagnostic()
    addLog("INFO", "=== SCANNER ===")
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position or Vector3.zero
    local batchAmt = getTargetEggBatchSize()
    local dom, wen, goat, lolli = updatePetsAndLollipopsInventory()
    local flagActive = isMagnetOrAnyFlagActiveInZone()

    addLog("INFO", string.format("Pos: %.1f, %.1f, %.1f | Batch: %d | FlagActive=%s", myPos.X, myPos.Y, myPos.Z, batchAmt, tostring(flagActive)))
    addLog("INFO", string.format("Dominus=%d | Wendigo=%d | Goat=%d | Lollipop=%d | MagnetFlag=%d", dom, wen, goat, lolli, State.MagnetFlagCount or 0))

    local cands = findNearestEggCandidates(75)
    addLog("INFO", "Eggs nearby (" .. #cands .. "):")
    for i, c in ipairs(cands) do
        addLog("INFO", string.format("  [%d] uid='%s' id='%s' dist=%.1f", i, tostring(c.uid), tostring(c.attrId), c.dist))
    end

    local houses = scanAllHousesWithState(myPos.Y, myPos)
    addLog("INFO", "Houses (" .. #houses .. "):")
    for i, h in ipairs(houses) do
        addLog("INFO", string.format("  [%d] %s | Locked=%s | Ready=%s | Timer=%.0fs", i, tostring(h.name), tostring(h.isLocked), tostring(h.isReady), h.remainingCd))
    end

    addLog("OK", "Done.")
end

local ParentGui = nil
pcall(function()
    if gethui then ParentGui = gethui() end
end)
if not ParentGui then
    pcall(function() ParentGui = game:GetService("CoreGui") end)
end
if not ParentGui then
    ParentGui = LocalPlayer:WaitForChild("PlayerGui")
end

local OldGui = ParentGui:FindFirstChild("HalloweenEventGui")
if OldGui then OldGui:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HalloweenEventGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = ParentGui

local Colors = {
    Bg = Color3.fromRGB(20, 22, 28),
    Header = Color3.fromRGB(26, 29, 36),
    Card = Color3.fromRGB(32, 35, 44),
    CardBright = Color3.fromRGB(38, 42, 52),
    Stroke = Color3.fromRGB(62, 68, 82),
    Accent = Color3.fromRGB(68, 125, 205),
    Green = Color3.fromRGB(45, 115, 75),
    Red = Color3.fromRGB(130, 50, 50),
    Text = Color3.fromRGB(235, 238, 244),
    SubText = Color3.fromRGB(160, 166, 178),
    InputBg = Color3.fromRGB(15, 17, 22)
}

BlackOverlayFrame = Instance.new("Frame")
BlackOverlayFrame.Name = "BlackScreenOverlay"
BlackOverlayFrame.Size = UDim2.new(1, 0, 1, 0)
BlackOverlayFrame.Position = UDim2.new(0, 0, 0, 0)
BlackOverlayFrame.BackgroundColor3 = Color3.fromRGB(10, 11, 14)
BlackOverlayFrame.BorderSizePixel = 0
BlackOverlayFrame.Active = true
BlackOverlayFrame.Visible = false
BlackOverlayFrame.ZIndex = 10
BlackOverlayFrame.Parent = ScreenGui

local DashCard = Instance.new("Frame")
DashCard.Size = UDim2.new(0, 460, 0, 350)
DashCard.Position = UDim2.new(0.5, -230, 0.5, -175)
DashCard.BackgroundColor3 = Colors.Bg
DashCard.BorderSizePixel = 0
DashCard.ZIndex = 11
DashCard.Parent = BlackOverlayFrame
Instance.new("UICorner", DashCard).CornerRadius = UDim.new(0, 6)
local DashStroke = Instance.new("UIStroke", DashCard)
DashStroke.Color = Colors.Stroke
DashStroke.Thickness = 1

DashTitle = Instance.new("TextLabel")
DashTitle.Size = UDim2.new(1, -24, 0, 26)
DashTitle.Position = UDim2.new(0, 12, 0, 8)
DashTitle.BackgroundTransparency = 1
DashTitle.Text = "HATCH WARS AFK  |  3D RENDERING OFF"
DashTitle.TextColor3 = Colors.Text
DashTitle.Font = Enum.Font.GothamBold
DashTitle.TextSize = 13
DashTitle.TextXAlignment = Enum.TextXAlignment.Left
DashTitle.ZIndex = 12
DashTitle.Parent = DashCard

local function createStatBox(parent, title, initVal, posScaleX, posY, widthScale, heightPx)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(widthScale, -12, 0, heightPx)
    box.Position = UDim2.new(posScaleX, 10, 0, posY)
    box.BackgroundColor3 = Colors.Card
    box.BorderSizePixel = 0
    box.ZIndex = 12
    box.Parent = parent
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)
    local st = Instance.new("UIStroke", box)
    st.Color = Colors.Stroke
    st.Thickness = 1

    local lblTitle = Instance.new("TextLabel")
    lblTitle.Size = UDim2.new(1, -12, 0, 16)
    lblTitle.Position = UDim2.new(0, 6, 0, 4)
    lblTitle.BackgroundTransparency = 1
    lblTitle.Text = title
    lblTitle.TextColor3 = Colors.SubText
    lblTitle.Font = Enum.Font.Gotham
    lblTitle.TextSize = 11
    lblTitle.TextXAlignment = Enum.TextXAlignment.Left
    lblTitle.ZIndex = 13
    lblTitle.Parent = box

    local lblVal = Instance.new("TextLabel")
    lblVal.Size = UDim2.new(1, -12, 0, heightPx - 22)
    lblVal.Position = UDim2.new(0, 6, 0, 20)
    lblVal.BackgroundTransparency = 1
    lblVal.Text = initVal
    lblVal.TextColor3 = Colors.Text
    lblVal.Font = Enum.Font.GothamBold
    lblVal.TextSize = 14
    lblVal.TextXAlignment = Enum.TextXAlignment.Left
    lblVal.ZIndex = 13
    lblVal.Parent = box

    return lblVal, lblTitle
end

StatTimeValue, StatTimeTitle = createStatBox(DashCard, "Farm Time", "00:00:00", 0, 40, 0.333, 52)
StatEggsValue, StatEggsTitle = createStatBox(DashCard, "Eggs Hatched", "0 (0)", 0.333, 40, 0.333, 52)
StatHousesValue, StatHousesTitle = createStatBox(DashCard, "Houses Opened", "0", 0.666, 40, 0.334, 52)

StatDominusValue = createStatBox(DashCard, "Headless Dominus", "+0 (0)", 0, 100, 0.25, 52)
StatWendigoValue = createStatBox(DashCard, "Wendigo", "+0 (0)", 0.25, 100, 0.25, 52)
StatGoatValue = createStatBox(DashCard, "Grinning Goat", "+0 (0)", 0.50, 100, 0.25, 52)
StatLollipopValue, StatLollipopTitle = createStatBox(DashCard, "Lollipops", "0", 0.75, 100, 0.25, 52)

local StatusBanner = Instance.new("Frame")
StatusBanner.Size = UDim2.new(1, -20, 0, 48)
StatusBanner.Position = UDim2.new(0, 10, 0, 160)
StatusBanner.BackgroundColor3 = Colors.InputBg
StatusBanner.BorderSizePixel = 0
StatusBanner.ZIndex = 12
StatusBanner.Parent = DashCard
Instance.new("UICorner", StatusBanner).CornerRadius = UDim.new(0, 5)
local BannerStroke = Instance.new("UIStroke", StatusBanner)
BannerStroke.Color = Colors.Stroke
BannerStroke.Thickness = 1

StatStatusValue = Instance.new("TextLabel")
StatStatusValue.Size = UDim2.new(1, -16, 1, -8)
StatStatusValue.Position = UDim2.new(0, 8, 0, 4)
StatStatusValue.BackgroundTransparency = 1
StatStatusValue.Text = "Ready..."
StatStatusValue.TextColor3 = Colors.Text
StatStatusValue.Font = Enum.Font.Gotham
StatStatusValue.TextSize = 12
StatStatusValue.TextXAlignment = Enum.TextXAlignment.Left
StatStatusValue.TextWrapped = true
StatStatusValue.ZIndex = 13
StatStatusValue.Parent = StatusBanner

ExitBlackBtn = Instance.new("TextButton")
ExitBlackBtn.Size = UDim2.new(0.42, -8, 0, 34)
ExitBlackBtn.Position = UDim2.new(0, 10, 0, 218)
ExitBlackBtn.BackgroundColor3 = Colors.Green
ExitBlackBtn.Text = "Exit Black Screen (3D ON)"
ExitBlackBtn.TextColor3 = Colors.Text
ExitBlackBtn.Font = Enum.Font.GothamBold
ExitBlackBtn.TextSize = 12
ExitBlackBtn.ZIndex = 13
ExitBlackBtn.Parent = DashCard
Instance.new("UICorner", ExitBlackBtn).CornerRadius = UDim.new(0, 5)

OpenMenuOnBlackBtn = Instance.new("TextButton")
OpenMenuOnBlackBtn.Size = UDim2.new(0.24, -6, 0, 34)
OpenMenuOnBlackBtn.Position = UDim2.new(0.42, 4, 0, 218)
OpenMenuOnBlackBtn.BackgroundColor3 = Colors.CardBright
OpenMenuOnBlackBtn.Text = "Menu"
OpenMenuOnBlackBtn.TextColor3 = Colors.Text
OpenMenuOnBlackBtn.Font = Enum.Font.GothamBold
OpenMenuOnBlackBtn.TextSize = 12
OpenMenuOnBlackBtn.ZIndex = 13
OpenMenuOnBlackBtn.Parent = DashCard
Instance.new("UICorner", OpenMenuOnBlackBtn).CornerRadius = UDim.new(0, 5)

LangCycleBtnBlack = Instance.new("TextButton")
LangCycleBtnBlack.Size = UDim2.new(0.34, -10, 0, 34)
LangCycleBtnBlack.Position = UDim2.new(0.66, 0, 0, 218)
LangCycleBtnBlack.BackgroundColor3 = Colors.Card
LangCycleBtnBlack.Text = "Language: EN"
LangCycleBtnBlack.TextColor3 = Colors.Text
LangCycleBtnBlack.Font = Enum.Font.GothamBold
LangCycleBtnBlack.TextSize = 11
LangCycleBtnBlack.ZIndex = 13
LangCycleBtnBlack.Parent = DashCard
Instance.new("UICorner", LangCycleBtnBlack).CornerRadius = UDim.new(0, 5)

bindButton(LangCycleBtnBlack, function()
    cycleGameLanguage()
end)

TeleportNowOnBlackBtn = Instance.new("TextButton")
TeleportNowOnBlackBtn.Size = UDim2.new(1, -20, 0, 32)
TeleportNowOnBlackBtn.Position = UDim2.new(0, 10, 0, 260)
TeleportNowOnBlackBtn.BackgroundColor3 = Colors.Card
TeleportNowOnBlackBtn.Text = "Teleport to Coords (7538.1, 15.7, 21965.5)"
TeleportNowOnBlackBtn.TextColor3 = Colors.Text
TeleportNowOnBlackBtn.Font = Enum.Font.GothamBold
TeleportNowOnBlackBtn.TextSize = 12
TeleportNowOnBlackBtn.ZIndex = 13
TeleportNowOnBlackBtn.Parent = DashCard
Instance.new("UICorner", TeleportNowOnBlackBtn).CornerRadius = UDim.new(0, 5)

RunHousesOnBlackBtn = Instance.new("TextButton")
RunHousesOnBlackBtn.Size = UDim2.new(1, -20, 0, 32)
RunHousesOnBlackBtn.Position = UDim2.new(0, 10, 0, 300)
RunHousesOnBlackBtn.BackgroundColor3 = Colors.Accent
RunHousesOnBlackBtn.Text = "Check & Open Ready Houses Now"
RunHousesOnBlackBtn.TextColor3 = Colors.Text
RunHousesOnBlackBtn.Font = Enum.Font.GothamBold
RunHousesOnBlackBtn.TextSize = 12
RunHousesOnBlackBtn.ZIndex = 13
RunHousesOnBlackBtn.Parent = DashCard
Instance.new("UICorner", RunHousesOnBlackBtn).CornerRadius = UDim.new(0, 5)

bindButton(RunHousesOnBlackBtn, function()
    task.spawn(function()
        visitReadyHousesAndReturn(true)
    end)
end)

task.spawn(function()
    local lastInvCheck = 0
    while State.Running do
        local now = tick()
        if now - lastInvCheck >= 2.0 then
            lastInvCheck = now
            updatePetsAndLollipopsInventory()
        end

        if StatTimeValue then
            StatTimeValue.Text = formatDuration(now - State.StartTime)
        end
        if StatEggsValue then
            StatEggsValue.Text = string.format("%s (%d)", formatNumber(State.TotalEggsHatched), State.TotalEggBatches)
        end
        if StatHousesValue then
            StatHousesValue.Text = formatNumber(State.TotalHousesOpened)
        end

        local baseDom = (State.StartPetCounts and State.StartPetCounts.HeadlessDominus) or 0
        local baseWen = (State.StartPetCounts and State.StartPetCounts.Wendigo) or 0
        local baseGoat = (State.StartPetCounts and State.StartPetCounts.GrinningGoat) or 0

        local curDom = State.CurrentPetCounts.HeadlessDominus or 0
        local curWen = State.CurrentPetCounts.Wendigo or 0
        local curGoat = State.CurrentPetCounts.GrinningGoat or 0

        local diffDom = math.max(0, curDom - baseDom)
        local diffWen = math.max(0, curWen - baseWen)
        local diffGoat = math.max(0, curGoat - baseGoat)

        if StatDominusValue then
            StatDominusValue.Text = string.format("+%s (%s)", formatNumber(diffDom), formatNumber(curDom))
        end
        if StatWendigoValue then
            StatWendigoValue.Text = string.format("+%s (%s)", formatNumber(diffWen), formatNumber(curWen))
        end
        if StatGoatValue then
            StatGoatValue.Text = string.format("+%s (%s)", formatNumber(diffGoat), formatNumber(curGoat))
        end
        if StatLollipopValue then
            StatLollipopValue.Text = formatNumber(State.CurrentLollipops)
        end

        task.wait(0.5)
    end
end)

local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "FloatToggle"
FloatBtn.Size = UDim2.new(0, 48, 0, 36)
FloatBtn.Position = UDim2.new(0, 14, 0.5, -18)
FloatBtn.BackgroundColor3 = Colors.CardBright
FloatBtn.Text = "MENU"
FloatBtn.TextSize = 11
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextColor3 = Colors.Text
FloatBtn.Visible = false
FloatBtn.ZIndex = 60
FloatBtn.Parent = ScreenGui
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 6)
local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Color = Colors.Stroke
FloatStroke.Thickness = 1

MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 430, 0, 340)
MainFrame.Position = UDim2.new(0.5, -215, 0.5, -170)
MainFrame.BackgroundColor3 = Colors.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ZIndex = 30
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Colors.Stroke
MainStroke.Thickness = 1

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 34)
TopBar.BackgroundColor3 = Colors.Header
TopBar.BorderSizePixel = 0
TopBar.Active = true
TopBar.ZIndex = 31
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 6)

TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -130, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "PS99 Hatch Wars"
TitleLabel.TextColor3 = Colors.Text
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 32
TitleLabel.Parent = TopBar

local BlackModeHeaderBtn = Instance.new("TextButton")
BlackModeHeaderBtn.Size = UDim2.new(0, 42, 0, 24)
BlackModeHeaderBtn.Position = UDim2.new(1, -110, 0, 5)
BlackModeHeaderBtn.BackgroundColor3 = Colors.Card
BlackModeHeaderBtn.Text = "3D OFF"
BlackModeHeaderBtn.TextColor3 = Colors.Text
BlackModeHeaderBtn.Font = Enum.Font.GothamBold
BlackModeHeaderBtn.TextSize = 10
BlackModeHeaderBtn.ZIndex = 33
BlackModeHeaderBtn.Parent = TopBar
Instance.new("UICorner", BlackModeHeaderBtn).CornerRadius = UDim.new(0, 4)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 24)
MinBtn.Position = UDim2.new(1, -64, 0, 5)
MinBtn.BackgroundColor3 = Colors.Card
MinBtn.Text = "_"
MinBtn.TextColor3 = Colors.Text
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.ZIndex = 33
MinBtn.Parent = TopBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 24)
CloseBtn.Position = UDim2.new(1, -32, 0, 5)
CloseBtn.BackgroundColor3 = Colors.Red
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Colors.Text
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.ZIndex = 33
CloseBtn.Parent = TopBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

do
    local dragging = false
    local dragStart = nil
    local startPos = nil

    trackConn(TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end))

    trackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end))

    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

bindButton(MinBtn, function()
    MainFrame.Visible = false
    FloatBtn.Visible = true
end)

bindButton(FloatBtn, function()
    MainFrame.Visible = true
    FloatBtn.Visible = false
end)

bindButton(BlackModeHeaderBtn, function()
    setBlackScreenMode(not State.BlackScreenActive)
    if State.BlackScreenActive then
        MainFrame.Visible = false
        FloatBtn.Visible = true
    end
end)

bindButton(ExitBlackBtn, function()
    setBlackScreenMode(false)
    MainFrame.Visible = true
    FloatBtn.Visible = false
end)

bindButton(OpenMenuOnBlackBtn, function()
    MainFrame.Visible = not MainFrame.Visible
    FloatBtn.Visible = not MainFrame.Visible
end)

bindButton(TeleportNowOnBlackBtn, function()
    task.spawn(enterHalloweenEventAndGoToCoords)
end)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 28)
TabBar.Position = UDim2.new(0, 8, 0, 38)
TabBar.BackgroundTransparency = 1
TabBar.ZIndex = 31
TabBar.Parent = MainFrame

local function createTabButton(text, posScale, widthScale)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(widthScale, -4, 1, 0)
    b.Position = UDim2.new(posScale, 2, 0, 0)
    b.BackgroundColor3 = Colors.Card
    b.Text = text
    b.TextColor3 = Colors.SubText
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.ZIndex = 32
    b.Parent = TabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

TabFarmBtn = createTabButton("Farm", 0, 0.25)
TabHousesBtn = createTabButton("Houses", 0.25, 0.25)
TabSettingsBtn = createTabButton("Settings", 0.50, 0.25)
TabLogsBtn = createTabButton("Logs", 0.75, 0.25)

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -16, 1, -74)
ContentArea.Position = UDim2.new(0, 8, 0, 70)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex = 31
ContentArea.Parent = MainFrame

local function createPage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Colors.Stroke
    page.Visible = false
    page.ZIndex = 32
    page.Parent = ContentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    trackConn(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end))

    return page
end

local PageFarm = createPage()
local PageHouses = createPage()
local PageSettings = createPage()
local PageLogs = createPage()

local function switchTab(activePage, activeBtn)
    PageFarm.Visible = (activePage == PageFarm)
    PageHouses.Visible = (activePage == PageHouses)
    PageSettings.Visible = (activePage == PageSettings)
    PageLogs.Visible = (activePage == PageLogs)

    for _, btn in ipairs({TabFarmBtn, TabHousesBtn, TabSettingsBtn, TabLogsBtn}) do
        if btn == activeBtn then
            btn.BackgroundColor3 = Colors.Accent
            btn.TextColor3 = Colors.Text
        else
            btn.BackgroundColor3 = Colors.Card
            btn.TextColor3 = Colors.SubText
        end
    end
end

bindButton(TabFarmBtn, function() switchTab(PageFarm, TabFarmBtn) end)
bindButton(TabHousesBtn, function() switchTab(PageHouses, TabHousesBtn) end)
bindButton(TabSettingsBtn, function() switchTab(PageSettings, TabSettingsBtn) end)
bindButton(TabLogsBtn, function() switchTab(PageLogs, TabLogsBtn) end)

FullAutoToggle = Instance.new("TextButton")
FullAutoToggle.LayoutOrder = 1
FullAutoToggle.Size = UDim2.new(1, -6, 0, 34)
FullAutoToggle.BackgroundColor3 = Colors.Green
FullAutoToggle.TextColor3 = Colors.Text
FullAutoToggle.Font = Enum.Font.GothamBold
FullAutoToggle.TextSize = 12
FullAutoToggle.ZIndex = 33
FullAutoToggle.Parent = PageFarm
Instance.new("UICorner", FullAutoToggle).CornerRadius = UDim.new(0, 5)

EggStatusLabel = Instance.new("TextLabel")
EggStatusLabel.LayoutOrder = 2
EggStatusLabel.Size = UDim2.new(1, -6, 0, 16)
EggStatusLabel.BackgroundTransparency = 1
EggStatusLabel.Text = "Eggs: Ready"
EggStatusLabel.TextColor3 = Colors.SubText
EggStatusLabel.Font = Enum.Font.Gotham
EggStatusLabel.TextSize = 11
EggStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
EggStatusLabel.ZIndex = 33
EggStatusLabel.Parent = PageFarm

HouseStatusLabel = Instance.new("TextLabel")
HouseStatusLabel.LayoutOrder = 3
HouseStatusLabel.Size = UDim2.new(1, -6, 0, 16)
HouseStatusLabel.BackgroundTransparency = 1
HouseStatusLabel.Text = "Houses: Ready (10m timer after open)"
HouseStatusLabel.TextColor3 = Colors.SubText
HouseStatusLabel.Font = Enum.Font.Gotham
HouseStatusLabel.TextSize = 11
HouseStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
HouseStatusLabel.ZIndex = 33
HouseStatusLabel.Parent = PageFarm

bindButton(FullAutoToggle, function()
    State.FullAutoFarm = not State.FullAutoFarm
    if State.FullAutoFarm then
        setupInstantEggAnimationBypass()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and not State.SavedEggCFrame then
            State.SavedEggCFrame = hrp.CFrame
            saveCoordsToDisk(hrp.CFrame)
        end
        FullAutoToggle.BackgroundColor3 = Colors.Green
    else
        FullAutoToggle.BackgroundColor3 = Colors.Red
    end
    refreshAllMenuLabels()
end)

MagnetFlagToggleBtn = Instance.new("TextButton")
MagnetFlagToggleBtn.LayoutOrder = 4
MagnetFlagToggleBtn.Size = UDim2.new(1, -6, 0, 30)
MagnetFlagToggleBtn.BackgroundColor3 = Colors.Green
MagnetFlagToggleBtn.TextColor3 = Colors.Text
MagnetFlagToggleBtn.Font = Enum.Font.GothamBold
MagnetFlagToggleBtn.TextSize = 12
MagnetFlagToggleBtn.ZIndex = 33
MagnetFlagToggleBtn.Parent = PageFarm
Instance.new("UICorner", MagnetFlagToggleBtn).CornerRadius = UDim.new(0, 5)

bindButton(MagnetFlagToggleBtn, function()
    State.AutoMagnetFlag = not State.AutoMagnetFlag
    MagnetFlagToggleBtn.BackgroundColor3 = State.AutoMagnetFlag and Colors.Green or Colors.Red
    refreshAllMenuLabels()
    if State.AutoMagnetFlag then
        task.spawn(useOnlyMagnetFlagIfNoneActive)
    end
end)

local function createLanguageSelectorBlock(parentPage, orderIdx, isFarmRef)
    local cycleBtn = Instance.new("TextButton")
    cycleBtn.LayoutOrder = orderIdx
    cycleBtn.Size = UDim2.new(1, -6, 0, 30)
    cycleBtn.BackgroundColor3 = Colors.CardBright
    cycleBtn.TextColor3 = Colors.Text
    cycleBtn.Font = Enum.Font.GothamBold
    cycleBtn.TextSize = 12
    cycleBtn.ZIndex = 33
    cycleBtn.Parent = parentPage
    Instance.new("UICorner", cycleBtn).CornerRadius = UDim.new(0, 5)

    if isFarmRef then
        LangCycleBtnFarm = cycleBtn
    else
        LangCycleBtnSettings = cycleBtn
    end

    bindButton(cycleBtn, function()
        cycleGameLanguage()
    end)

    local row = Instance.new("Frame")
    row.LayoutOrder = orderIdx + 1
    row.Size = UDim2.new(1, -6, 0, 26)
    row.BackgroundTransparency = 1
    row.ZIndex = 33
    row.Parent = parentPage

    local labels = { "1. EN (English)", "2. UK (Українська)", "3. RU (Русский)" }
    for idx = 1, 3 do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.333, -3, 1, 0)
        b.Position = UDim2.new((idx - 1) * 0.333, 1, 0, 0)
        b.BackgroundColor3 = (idx == State.LanguageIndex) and Colors.Green or Colors.Card
        b.Text = labels[idx]
        b.TextColor3 = Colors.Text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.ZIndex = 34
        b.Parent = row
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        LangDirectBtns[idx] = LangDirectBtns[idx] or {}
        table.insert(LangDirectBtns[idx], b)
        bindButton(b, function()
            applyGameLanguageNow(idx)
        end)
    end
end

createLanguageSelectorBlock(PageFarm, 5, true)

OnlyEggsToggle = Instance.new("TextButton")
OnlyEggsToggle.LayoutOrder = 7
OnlyEggsToggle.Size = UDim2.new(1, -6, 0, 30)
OnlyEggsToggle.BackgroundColor3 = Colors.Card
OnlyEggsToggle.TextColor3 = Colors.Text
OnlyEggsToggle.Font = Enum.Font.GothamBold
OnlyEggsToggle.TextSize = 12
OnlyEggsToggle.ZIndex = 33
OnlyEggsToggle.Parent = PageFarm
Instance.new("UICorner", OnlyEggsToggle).CornerRadius = UDim.new(0, 5)

bindButton(OnlyEggsToggle, function()
    State.AutoEggs = not State.AutoEggs
    if State.AutoEggs then
        setupInstantEggAnimationBypass()
        OnlyEggsToggle.BackgroundColor3 = Colors.Green
    else
        OnlyEggsToggle.BackgroundColor3 = Colors.Card
    end
    refreshAllMenuLabels()
end)

InstantAnimToggle = Instance.new("TextButton")
InstantAnimToggle.LayoutOrder = 8
InstantAnimToggle.Size = UDim2.new(1, -6, 0, 30)
InstantAnimToggle.BackgroundColor3 = Colors.Green
InstantAnimToggle.TextColor3 = Colors.Text
InstantAnimToggle.Font = Enum.Font.GothamBold
InstantAnimToggle.TextSize = 12
InstantAnimToggle.ZIndex = 33
InstantAnimToggle.Parent = PageFarm
Instance.new("UICorner", InstantAnimToggle).CornerRadius = UDim.new(0, 5)

bindButton(InstantAnimToggle, function()
    State.InstantEggOpen = not State.InstantEggOpen
    if State.InstantEggOpen then
        setupInstantEggAnimationBypass()
        InstantAnimToggle.BackgroundColor3 = Colors.Green
    else
        InstantAnimToggle.BackgroundColor3 = Colors.Card
    end
    refreshAllMenuLabels()
end)

EggCountInput = Instance.new("TextBox")
EggCountInput.LayoutOrder = 9
EggCountInput.Size = UDim2.new(1, -6, 0, 28)
EggCountInput.BackgroundColor3 = Colors.InputBg
EggCountInput.Text = "79"
EggCountInput.PlaceholderText = "Egg batch size (79, or 0 = Auto)"
EggCountInput.PlaceholderColor3 = Colors.SubText
EggCountInput.TextColor3 = Colors.Text
EggCountInput.Font = Enum.Font.GothamBold
EggCountInput.TextSize = 12
EggCountInput.ClearTextOnFocus = false
EggCountInput.ZIndex = 33
EggCountInput.Parent = PageFarm
Instance.new("UICorner", EggCountInput).CornerRadius = UDim.new(0, 4)

local autoDetectedOnStart = detectPlayerMaxEggHatch()
if autoDetectedOnStart and autoDetectedOnStart > 1 then
    State.CustomEggCount = autoDetectedOnStart
    State.WorkingEggAmount = autoDetectedOnStart
    EggCountInput.Text = tostring(autoDetectedOnStart)
else
    State.CustomEggCount = 79
    State.WorkingEggAmount = 79
    EggCountInput.Text = "79"
end

trackConn(EggCountInput.FocusLost:Connect(function()
    local n = tonumber(EggCountInput.Text)
    if n and n >= 1 then
        State.CustomEggCount = math.floor(n)
        State.WorkingEggAmount = math.floor(n)
        State.LearnedBatchCost = 0
    else
        State.CustomEggCount = 0
        State.LearnedBatchCost = 0
        local det = detectPlayerMaxEggHatch()
        if det and det > 1 then
            State.WorkingEggAmount = det
        end
    end
end))

local PosRow = Instance.new("Frame")
PosRow.LayoutOrder = 10
PosRow.Size = UDim2.new(1, -6, 0, 30)
PosRow.BackgroundTransparency = 1
PosRow.ZIndex = 33
PosRow.Parent = PageFarm

SaveEggPosBtn = Instance.new("TextButton")
SaveEggPosBtn.Size = UDim2.new(0.5, -3, 1, 0)
SaveEggPosBtn.Position = UDim2.new(0, 0, 0, 0)
SaveEggPosBtn.BackgroundColor3 = Colors.CardBright
SaveEggPosBtn.TextColor3 = Colors.Text
SaveEggPosBtn.Font = Enum.Font.GothamBold
SaveEggPosBtn.TextSize = 12
SaveEggPosBtn.ZIndex = 34
SaveEggPosBtn.Parent = PosRow
Instance.new("UICorner", SaveEggPosBtn).CornerRadius = UDim.new(0, 4)

ReturnToEggBtn = Instance.new("TextButton")
ReturnToEggBtn.Size = UDim2.new(0.5, -3, 1, 0)
ReturnToEggBtn.Position = UDim2.new(0.5, 3, 0, 0)
ReturnToEggBtn.BackgroundColor3 = Colors.Accent
ReturnToEggBtn.TextColor3 = Colors.Text
ReturnToEggBtn.Font = Enum.Font.GothamBold
ReturnToEggBtn.TextSize = 12
ReturnToEggBtn.ZIndex = 34
ReturnToEggBtn.Parent = PosRow
Instance.new("UICorner", ReturnToEggBtn).CornerRadius = UDim.new(0, 4)

bindButton(SaveEggPosBtn, function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        State.SavedEggCFrame = hrp.CFrame
        State.CachedEggId = nil
        State.CachedEggRemoteName = nil
        State.LearnedBatchCost = 0
        saveCoordsToDisk(hrp.CFrame)
        SaveEggPosBtn.Text = L().savedPos
        task.delay(1.2, function()
            refreshAllMenuLabels()
        end)
    end
end)

bindButton(ReturnToEggBtn, function()
    task.spawn(enterHalloweenEventAndGoToCoords)
end)

RunHousesNowBtn = Instance.new("TextButton")
RunHousesNowBtn.LayoutOrder = 1
RunHousesNowBtn.Size = UDim2.new(1, -6, 0, 34)
RunHousesNowBtn.BackgroundColor3 = Colors.Accent
RunHousesNowBtn.TextColor3 = Colors.Text
RunHousesNowBtn.Font = Enum.Font.GothamBold
RunHousesNowBtn.TextSize = 12
RunHousesNowBtn.ZIndex = 33
RunHousesNowBtn.Parent = PageHouses
Instance.new("UICorner", RunHousesNowBtn).CornerRadius = UDim.new(0, 5)

bindButton(RunHousesNowBtn, function()
    task.spawn(function()
        visitReadyHousesAndReturn(true)
    end)
end)

AutoBuyHouseToggle = Instance.new("TextButton")
AutoBuyHouseToggle.LayoutOrder = 2
AutoBuyHouseToggle.Size = UDim2.new(1, -6, 0, 32)
AutoBuyHouseToggle.BackgroundColor3 = Colors.Green
AutoBuyHouseToggle.TextColor3 = Colors.Text
AutoBuyHouseToggle.Font = Enum.Font.GothamBold
AutoBuyHouseToggle.TextSize = 12
AutoBuyHouseToggle.ZIndex = 33
AutoBuyHouseToggle.Parent = PageHouses
Instance.new("UICorner", AutoBuyHouseToggle).CornerRadius = UDim.new(0, 5)

bindButton(AutoBuyHouseToggle, function()
    State.AutoBuyHouses = not State.AutoBuyHouses
    AutoBuyHouseToggle.BackgroundColor3 = State.AutoBuyHouses and Colors.Green or Colors.Red
    refreshAllMenuLabels()
end)

local RouteRow = Instance.new("Frame")
RouteRow.LayoutOrder = 3
RouteRow.Size = UDim2.new(1, -6, 0, 30)
RouteRow.BackgroundTransparency = 1
RouteRow.ZIndex = 33
RouteRow.Parent = PageHouses

AddPointBtn = Instance.new("TextButton")
AddPointBtn.Size = UDim2.new(0.6, -3, 1, 0)
AddPointBtn.Position = UDim2.new(0, 0, 0, 0)
AddPointBtn.BackgroundColor3 = Colors.CardBright
AddPointBtn.TextColor3 = Colors.Text
AddPointBtn.Font = Enum.Font.GothamBold
AddPointBtn.TextSize = 11
AddPointBtn.ZIndex = 34
AddPointBtn.Parent = RouteRow
Instance.new("UICorner", AddPointBtn).CornerRadius = UDim.new(0, 4)

ClearPointsBtn = Instance.new("TextButton")
ClearPointsBtn.Size = UDim2.new(0.4, -3, 1, 0)
ClearPointsBtn.Position = UDim2.new(0.6, 3, 0, 0)
ClearPointsBtn.BackgroundColor3 = Colors.Card
ClearPointsBtn.TextColor3 = Colors.Text
ClearPointsBtn.Font = Enum.Font.GothamBold
ClearPointsBtn.TextSize = 11
ClearPointsBtn.ZIndex = 34
ClearPointsBtn.Parent = RouteRow
Instance.new("UICorner", ClearPointsBtn).CornerRadius = UDim.new(0, 4)

bindButton(AddPointBtn, function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        table.insert(State.CustomHousePoints, hrp.CFrame)
        refreshAllMenuLabels()
    end
end)

bindButton(ClearPointsBtn, function()
    State.CustomHousePoints = {}
    State.HouseCooldownMap = {}
    State.LockedHouseInfo = {}
    refreshAllMenuLabels()
end)

local LimitRow = Instance.new("Frame")
LimitRow.LayoutOrder = 4
LimitRow.Size = UDim2.new(1, -6, 0, 28)
LimitRow.BackgroundTransparency = 1
LimitRow.ZIndex = 33
LimitRow.Parent = PageHouses

local LimitBtns = {}
local function makeLimitBtn(label, val, idx)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.2, -3, 1, 0)
    b.Position = UDim2.new((idx - 1) * 0.2, 1, 0, 0)
    b.BackgroundColor3 = (State.MaxUnlockedHouses == val) and Colors.Accent or Colors.Card
    b.Text = label
    b.TextColor3 = Colors.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.ZIndex = 34
    b.Parent = LimitRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    LimitBtns[val] = b
    bindButton(b, function()
        State.MaxUnlockedHouses = val
        for k, btn in pairs(LimitBtns) do
            btn.BackgroundColor3 = (k == val) and Colors.Accent or Colors.Card
        end
    end)
end

makeLimitBtn("1", 1, 1)
makeLimitBtn("2", 2, 2)
makeLimitBtn("3", 3, 3)
makeLimitBtn("4", 4, 4)
makeLimitBtn("All", 0, 5)

AutoCapToggle = Instance.new("TextButton")
AutoCapToggle.LayoutOrder = 5
AutoCapToggle.Size = UDim2.new(1, -6, 0, 30)
AutoCapToggle.BackgroundColor3 = Colors.Green
AutoCapToggle.TextColor3 = Colors.Text
AutoCapToggle.Font = Enum.Font.GothamBold
AutoCapToggle.TextSize = 12
AutoCapToggle.ZIndex = 33
AutoCapToggle.Parent = PageHouses
Instance.new("UICorner", AutoCapToggle).CornerRadius = UDim.new(0, 5)

bindButton(AutoCapToggle, function()
    State.AutoMinigame = not State.AutoMinigame
    AutoCapToggle.BackgroundColor3 = State.AutoMinigame and Colors.Green or Colors.Red
    refreshAllMenuLabels()
end)

BlackToggleBtnInSettings = Instance.new("TextButton")
BlackToggleBtnInSettings.LayoutOrder = 1
BlackToggleBtnInSettings.Size = UDim2.new(1, -6, 0, 32)
BlackToggleBtnInSettings.BackgroundColor3 = Colors.Green
BlackToggleBtnInSettings.TextColor3 = Colors.Text
BlackToggleBtnInSettings.Font = Enum.Font.GothamBold
BlackToggleBtnInSettings.TextSize = 12
BlackToggleBtnInSettings.ZIndex = 33
BlackToggleBtnInSettings.Parent = PageSettings
Instance.new("UICorner", BlackToggleBtnInSettings).CornerRadius = UDim.new(0, 5)

bindButton(BlackToggleBtnInSettings, function()
    setBlackScreenMode(not State.BlackScreenActive)
end)

Render3DToggleBtn = Instance.new("TextButton")
Render3DToggleBtn.LayoutOrder = 2
Render3DToggleBtn.Size = UDim2.new(1, -6, 0, 30)
Render3DToggleBtn.BackgroundColor3 = Colors.Green
Render3DToggleBtn.TextColor3 = Colors.Text
Render3DToggleBtn.Font = Enum.Font.GothamBold
Render3DToggleBtn.TextSize = 12
Render3DToggleBtn.ZIndex = 33
Render3DToggleBtn.Parent = PageSettings
Instance.new("UICorner", Render3DToggleBtn).CornerRadius = UDim.new(0, 5)

bindButton(Render3DToggleBtn, function()
    set3DRendering(not State.Rendering3DEnabled)
end)

createLanguageSelectorBlock(PageSettings, 3, false)

JumpToggle = Instance.new("TextButton")
JumpToggle.LayoutOrder = 5
JumpToggle.Size = UDim2.new(1, -6, 0, 30)
JumpToggle.BackgroundColor3 = Colors.Green
JumpToggle.TextColor3 = Colors.Text
JumpToggle.Font = Enum.Font.GothamBold
JumpToggle.TextSize = 12
JumpToggle.ZIndex = 33
JumpToggle.Parent = PageSettings
Instance.new("UICorner", JumpToggle).CornerRadius = UDim.new(0, 5)

bindButton(JumpToggle, function()
    State.AutoJump20s = not State.AutoJump20s
    JumpToggle.BackgroundColor3 = State.AutoJump20s and Colors.Green or Colors.Red
    refreshAllMenuLabels()
end)

local CoordsRow = Instance.new("Frame")
CoordsRow.LayoutOrder = 6
CoordsRow.Size = UDim2.new(1, -6, 0, 30)
CoordsRow.BackgroundTransparency = 1
CoordsRow.ZIndex = 33
CoordsRow.Parent = PageSettings

CoordsInputBox = Instance.new("TextBox")
CoordsInputBox.Size = UDim2.new(0.66, -3, 1, 0)
CoordsInputBox.Position = UDim2.new(0, 0, 0, 0)
CoordsInputBox.BackgroundColor3 = Colors.InputBg
CoordsInputBox.Text = "7538.1, 15.7, 21965.5"
CoordsInputBox.PlaceholderText = "X, Y, Z"
CoordsInputBox.PlaceholderColor3 = Colors.SubText
CoordsInputBox.TextColor3 = Colors.Text
CoordsInputBox.Font = Enum.Font.GothamBold
CoordsInputBox.TextSize = 11
CoordsInputBox.ClearTextOnFocus = false
CoordsInputBox.ZIndex = 34
CoordsInputBox.Parent = CoordsRow
Instance.new("UICorner", CoordsInputBox).CornerRadius = UDim.new(0, 4)

SetCoordsManualBtn = Instance.new("TextButton")
SetCoordsManualBtn.Size = UDim2.new(0.34, -3, 1, 0)
SetCoordsManualBtn.Position = UDim2.new(0.66, 3, 0, 0)
SetCoordsManualBtn.BackgroundColor3 = Colors.Accent
SetCoordsManualBtn.TextColor3 = Colors.Text
SetCoordsManualBtn.Font = Enum.Font.GothamBold
SetCoordsManualBtn.TextSize = 11
SetCoordsManualBtn.ZIndex = 34
SetCoordsManualBtn.Parent = CoordsRow
Instance.new("UICorner", SetCoordsManualBtn).CornerRadius = UDim.new(0, 4)

bindButton(SetCoordsManualBtn, function()
    local raw = CoordsInputBox.Text or ""
    local x, y, z = string.match(raw, "([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
    if x and y and z then
        local cf = CFrame.new(tonumber(x), tonumber(y), tonumber(z))
        State.SavedEggCFrame = cf
        saveCoordsToDisk(cf)
        teleportSafelyTo(cf)
    end
end)

local DelaysRow = Instance.new("Frame")
DelaysRow.LayoutOrder = 7
DelaysRow.Size = UDim2.new(1, -6, 0, 28)
DelaysRow.BackgroundTransparency = 1
DelaysRow.ZIndex = 33
DelaysRow.Parent = PageSettings

local HouseDelayInput = Instance.new("TextBox")
HouseDelayInput.Size = UDim2.new(0.5, -3, 1, 0)
HouseDelayInput.Position = UDim2.new(0, 0, 0, 0)
HouseDelayInput.BackgroundColor3 = Colors.InputBg
HouseDelayInput.Text = "House delay: 4s"
HouseDelayInput.PlaceholderText = "House delay (4s)"
HouseDelayInput.PlaceholderColor3 = Colors.SubText
HouseDelayInput.TextColor3 = Colors.Text
HouseDelayInput.Font = Enum.Font.Gotham
HouseDelayInput.TextSize = 11
HouseDelayInput.ClearTextOnFocus = true
HouseDelayInput.ZIndex = 34
HouseDelayInput.Parent = DelaysRow
Instance.new("UICorner", HouseDelayInput).CornerRadius = UDim.new(0, 4)

trackConn(HouseDelayInput.FocusLost:Connect(function()
    local v = tonumber(string.match(HouseDelayInput.Text or "", "([%d%.]+)"))
    State.HouseStepDelay = (v and v >= 1) and v or 4.0
    HouseDelayInput.Text = string.format("House delay: %.1fs", State.HouseStepDelay)
end))

local EggDelayInput = Instance.new("TextBox")
EggDelayInput.Size = UDim2.new(0.5, -3, 1, 0)
EggDelayInput.Position = UDim2.new(0.5, 3, 0, 0)
EggDelayInput.BackgroundColor3 = Colors.InputBg
EggDelayInput.Text = "Egg delay: 2s"
EggDelayInput.PlaceholderText = "Egg delay (2s)"
EggDelayInput.PlaceholderColor3 = Colors.SubText
EggDelayInput.TextColor3 = Colors.Text
EggDelayInput.Font = Enum.Font.Gotham
EggDelayInput.TextSize = 11
EggDelayInput.ClearTextOnFocus = true
EggDelayInput.ZIndex = 34
EggDelayInput.Parent = DelaysRow
Instance.new("UICorner", EggDelayInput).CornerRadius = UDim.new(0, 4)

trackConn(EggDelayInput.FocusLost:Connect(function()
    local v = tonumber(string.match(EggDelayInput.Text or "", "([%d%.]+)"))
    State.EggHatchDelay = (v and v >= 0.5) and v or 2.0
    EggDelayInput.Text = string.format("Egg delay: %.1fs", State.EggHatchDelay)
end))

local LogBtnsRow = Instance.new("Frame")
LogBtnsRow.LayoutOrder = 1
LogBtnsRow.Size = UDim2.new(1, -6, 0, 30)
LogBtnsRow.BackgroundTransparency = 1
LogBtnsRow.ZIndex = 33
LogBtnsRow.Parent = PageLogs

CopyLogsBtn = Instance.new("TextButton")
CopyLogsBtn.Size = UDim2.new(0.34, -3, 1, 0)
CopyLogsBtn.Position = UDim2.new(0, 0, 0, 0)
CopyLogsBtn.BackgroundColor3 = Colors.Green
CopyLogsBtn.TextColor3 = Colors.Text
CopyLogsBtn.Font = Enum.Font.GothamBold
CopyLogsBtn.TextSize = 12
CopyLogsBtn.ZIndex = 34
CopyLogsBtn.Parent = LogBtnsRow
Instance.new("UICorner", CopyLogsBtn).CornerRadius = UDim.new(0, 4)

DiagEventBtn = Instance.new("TextButton")
DiagEventBtn.Size = UDim2.new(0.34, -3, 1, 0)
DiagEventBtn.Position = UDim2.new(0.34, 2, 0, 0)
DiagEventBtn.BackgroundColor3 = Colors.Accent
DiagEventBtn.TextColor3 = Colors.Text
DiagEventBtn.Font = Enum.Font.GothamBold
DiagEventBtn.TextSize = 12
DiagEventBtn.ZIndex = 34
DiagEventBtn.Parent = LogBtnsRow
Instance.new("UICorner", DiagEventBtn).CornerRadius = UDim.new(0, 4)

ClearLogsBtn = Instance.new("TextButton")
ClearLogsBtn.Size = UDim2.new(0.32, -3, 1, 0)
ClearLogsBtn.Position = UDim2.new(0.68, 4, 0, 0)
ClearLogsBtn.BackgroundColor3 = Colors.Red
ClearLogsBtn.TextColor3 = Colors.Text
ClearLogsBtn.Font = Enum.Font.GothamBold
ClearLogsBtn.TextSize = 12
ClearLogsBtn.ZIndex = 34
ClearLogsBtn.Parent = LogBtnsRow
Instance.new("UICorner", ClearLogsBtn).CornerRadius = UDim.new(0, 4)

LogScrollFrame = Instance.new("ScrollingFrame")
LogScrollFrame.LayoutOrder = 2
LogScrollFrame.Size = UDim2.new(1, -6, 0, 200)
LogScrollFrame.BackgroundColor3 = Colors.InputBg
LogScrollFrame.BorderSizePixel = 0
LogScrollFrame.ScrollBarThickness = 4
LogScrollFrame.ScrollBarImageColor3 = Colors.Stroke
LogScrollFrame.ZIndex = 33
LogScrollFrame.Parent = PageLogs
Instance.new("UICorner", LogScrollFrame).CornerRadius = UDim.new(0, 4)

LogBoxLabel = Instance.new("TextLabel")
LogBoxLabel.Size = UDim2.new(1, -12, 0, 195)
LogBoxLabel.Position = UDim2.new(0, 6, 0, 4)
LogBoxLabel.BackgroundTransparency = 1
LogBoxLabel.Text = ""
LogBoxLabel.TextColor3 = Colors.Text
LogBoxLabel.Font = Enum.Font.Code
LogBoxLabel.TextSize = 11
LogBoxLabel.TextXAlignment = Enum.TextXAlignment.Left
LogBoxLabel.TextYAlignment = Enum.TextYAlignment.Top
LogBoxLabel.TextWrapped = true
LogBoxLabel.AutomaticSize = Enum.AutomaticSize.Y
LogBoxLabel.ZIndex = 34
LogBoxLabel.Parent = LogScrollFrame

bindButton(CopyLogsBtn, function()
    local fullText = table.concat(State.Logs, "\n")
    if copyToClipboard(fullText) then
        CopyLogsBtn.Text = L().copiedLogs
        task.delay(1.2, function()
            refreshAllMenuLabels()
        end)
    end
end)

bindButton(DiagEventBtn, function()
    task.spawn(runEventDiagnostic)
end)

bindButton(ClearLogsBtn, function()
    State.Logs = {}
    if LogBoxLabel then LogBoxLabel.Text = "" end
end)

local function cleanupAll()
    State.Running = false
    State.FullAutoFarm = false
    State.AutoEggs = false
    State.AutoMinigame = false
    State.AutoFarmCoins = false
    State.AutoMagnetFlag = false
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
    end)
    pcall(function()
        if SafetyFloorPad then SafetyFloorPad:Destroy() end
    end)
    for _, c in ipairs(ActiveConnections) do
        pcall(function() c:Disconnect() end)
    end
    ActiveConnections = {}
    if ScreenGui then
        pcall(function() ScreenGui:Destroy() end)
    end
end

env.HalloweenHubCleanup = cleanupAll
bindButton(CloseBtn, cleanupAll)

switchTab(PageFarm, TabFarmBtn)
env.HalloweenSavedCoords = nil
loadCoordsFromDisk()
updatePetsAndLollipopsInventory()
refreshAllMenuLabels()

task.spawn(function()
    pcall(enterHalloweenEventAndGoToCoords)
    State.FullAutoFarm = true
    refreshAllMenuLabels()
    if #findNearestEggCandidates(120) > 0 then
        setBlackScreenMode(true)
        MainFrame.Visible = false
        FloatBtn.Visible = true
    else
        setBlackScreenMode(false)
        MainFrame.Visible = true
        FloatBtn.Visible = false
    end
    addLog("OK", "Ready.")
end)
