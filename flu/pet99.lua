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
local CoordsFileName = "ps99_halloween_coords_v2.txt"
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
        magnetFlag = "Auto Magnet Flag (1 Active Only)",
        savePos = "Save Position",
        savedPos = "Position Saved!",
        tpPos = "Teleport to Coords",
        runHousesNow = "Open Ready Houses Now",
        autoBuyHouses = "Auto Buy Houses (Lollipop)",
        addHousePt = "Add House Point",
        resetHouseTimers = "Reset All Houses to READY",
        autoMinigame = "Auto Door Minigame & Close Errors",
        blackScreenBtn = "Stats Screen (Disable 3D)",
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
        exitBlack = "Exit Stats Screen (3D ON)",
        openMenu = "Menu",
        tpBlack = "Teleport to Coords (7538.1, 15.7, 21965.5)",
        checkHousesBlack = "Check & Open Houses Now",
        houseReadyShort = "READY",
        houseLockedShort = "LOCKED",
        houseTimersHeader = "House Timers (10m after open):"
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
        magnetFlag = "Авто Магніт-Флаг (тільки 1 активний)",
        savePos = "Зберегти позицію",
        savedPos = "Збережено!",
        tpPos = "На координати",
        runHousesNow = "Відкрити готові домики зараз",
        autoBuyHouses = "Авто-купівля домиків за цукерки",
        addHousePt = "Додати точку дому",
        resetHouseTimers = "Оновити всі домики (ГОТОВО)",
        autoMinigame = "Авто-капча дверей та закриття помилок",
        blackScreenBtn = "Екран статистики (3D ВИМК)",
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
        exitBlack = "Вийти з екрану статистики (3D УВІМК)",
        openMenu = "Меню",
        tpBlack = "Телепорт на координати (7538.1, 15.7, 21965.5)",
        checkHousesBlack = "Перевірити і відкрити домики зараз",
        houseReadyShort = "ГОТОВО",
        houseLockedShort = "ЗАКРИТО",
        houseTimersHeader = "Таймери домиків (10хв після відкриття):"
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
        magnetFlag = "Авто Магнит-Флаг (только 1 активный)",
        savePos = "Сохранить позицию",
        savedPos = "Сохранено!",
        tpPos = "На координаты",
        runHousesNow = "Открыть готовые домики сейчас",
        autoBuyHouses = "Авто-покупка домиков за конфеты",
        addHousePt = "Добавить точку дома",
        resetHouseTimers = "Обновить все домики (ГОТОВО)",
        autoMinigame = "Авто-капча дверей и закрытие ошибок",
        blackScreenBtn = "Экран статистики (3D ВЫКЛ)",
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
        exitBlack = "Выйти с экрана статистики (3D ВКЛ)",
        openMenu = "Меню",
        tpBlack = "Телепорт на координаты (7538.1, 15.7, 21965.5)",
        checkHousesBlack = "Проверить и открыть домики сейчас",
        houseReadyShort = "ГОТОВО",
        houseLockedShort = "ЗАКРЫТО",
        houseTimersHeader = "Таймеры домиков (10м после открытия):"
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
    IsPlacingFlag = false,
    LastMagnetFlagTime = 0,
    FlagActiveUntil = 0,
    MagnetFlagUid = nil,
    MagnetFlagCount = 0,
    LanguageIndex = 1,
    EggHatchDelay = 2.0,
    HouseStepDelay = 4.0,
    CustomEggCount = 79,
    MaxHatchDetected = 0,
    WorkingEggAmount = 79,
    ConsecutiveHatchFails = 0,
    CachedEggRemoteName = nil,
    CachedEggId = nil,
    LearnedEggId = nil,
    LearnedCurrencyKey = nil,
    LearnedBatchCost = 0,
    LowCoinWaitCount = 0,
    SavedEggCFrame = DefaultSpawnCFrame,
    MaxUnlockedHouses = 0,
    HouseCooldownDefault = 600,
    HouseCooldownMap = {},
    LockedHouseInfo = {},
    ConfirmedUnlockedHouses = {},
    HouseKnownList = {},
    NextAutoHouseCheckTime = tick() + 6,
    AllowConfirmPurchasePopup = false,
    LastPopupWasError = false,
    LastPopupPurchased = false,
    LastHouseWasOnCooldown = false,
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
    CurrentPetCounts = { HeadlessDominus = 0, Wendigo = 0, GrinningGoat = 0 },
    CurrentLollipops = 0,
    CurrentActionText = "Ready",
    Logs = {},
    MaxLogs = 200
}

local LogBoxLabel, LogScrollFrame, EggStatusLabel, HouseStatusLabel
local EggCountInput, CoordsInputBox, BlackOverlayFrame, MainFrame
local TitleLabel, TabFarmBtn, TabHousesBtn, TabSettingsBtn, TabLogsBtn
local FullAutoToggle, OnlyEggsToggle, InstantAnimToggle, MagnetFlagToggleBtn
local SaveEggPosBtn, ReturnToEggBtn, RunHousesNowBtn, AutoBuyHouseToggle
local AddPointBtn, ClearPointsBtn, AutoCapToggle, BlackToggleBtnInSettings
local Render3DToggleBtn, JumpToggle, SetCoordsManualBtn, CopyLogsBtn
local DiagEventBtn, ClearLogsBtn, DashTitle, ExitBlackBtn, OpenMenuOnBlackBtn
local TeleportNowOnBlackBtn, RunHousesOnBlackBtn
local LangCycleBtnFarm, LangCycleBtnSettings, LangCycleBtnBlack
local LangDirectBtns = {}
local StatTimeTitle, StatEggsTitle, StatHousesTitle, StatLollipopTitle
local StatTimeValue, StatEggsValue, StatHousesValue, StatDominusValue
local StatWendigoValue, StatGoatValue, StatLollipopValue, StatStatusValue
local DashHouseCells, MenuFarmHouseCells, MenuHousesTabCells = {}, {}, {}
local MenuFarmTimersTitle, MenuHousesTimersTitle

local OrigGameText = setmetatable({}, { __mode = "k" })

local function L()
    local code = LangCodes[State.LanguageIndex] or "EN"
    return UILang[code] or UILang.EN
end

local function translateSingleGameString(rawText, langIdx)
    if not rawText or rawText == "" then return rawText end
    local res = rawText
    for _, entry in ipairs(GameTextTranslations) do
        if langIdx == 1 then
            res = string.gsub(res, entry.uk, entry.en)
            res = string.gsub(res, entry.ru, entry.en)
        elseif langIdx == 2 then
            res = string.gsub(res, entry.ru, entry.en)
            res = string.gsub(res, entry.en, entry.uk)
        elseif langIdx == 3 then
            res = string.gsub(res, entry.uk, entry.en)
            res = string.gsub(res, entry.en, entry.ru)
        end
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

    if MenuFarmTimersTitle then MenuFarmTimersTitle.Text = t.houseTimersHeader end
    if MenuHousesTimersTitle then MenuHousesTimersTitle.Text = t.houseTimersHeader end

    if LangCycleBtnFarm then LangCycleBtnFarm.Text = t.langBtn end
    if LangCycleBtnSettings then LangCycleBtnSettings.Text = t.langBtn end
    if LangCycleBtnBlack then LangCycleBtnBlack.Text = t.langBtn end

    for idx, btnList in pairs(LangDirectBtns) do
        for _, b in ipairs(btnList) do
            if idx == State.LanguageIndex then
                b.BackgroundColor3 = Color3.fromRGB(46, 184, 114)
                b.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                b.BackgroundColor3 = Color3.fromRGB(45, 40, 72)
                b.TextColor3 = Color3.fromRGB(190, 185, 220)
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

    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if pgui then
            for _, gui in ipairs(pgui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name ~= "HalloweenEventGui" then
                    gui.AutoLocalize = false
                    for _, obj in ipairs(gui:GetDescendants()) do
                        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                            local cur = obj.Text
                            if cur and cur ~= "" and not tonumber(cur) then
                                if not OrigGameText[obj] then
                                    OrigGameText[obj] = translateSingleGameString(cur, 1)
                                end
                                local newTxt = translateSingleGameString(OrigGameText[obj], idx)
                                if newTxt and newTxt ~= obj.Text then
                                    obj.Text = newTxt
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function cycleGameLanguage()
    applyGameLanguageNow((State.LanguageIndex % 3) + 1)
end

local function setStatusText(eggTxt, houseTxt)
    if eggTxt then
        State.CurrentActionText = eggTxt
        if EggStatusLabel then EggStatusLabel.Text = eggTxt end
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
    if suffix == "k" then val = val * 1000
    elseif suffix == "m" then val = val * 1000000
    elseif suffix == "b" then val = val * 1000000000 end
    return math.floor(val)
end

local function formatDuration(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    local hrs = math.floor(total / 3600)
    local mins = math.floor((total % 3600) / 60)
    local secs = total % 60
    return string.format("%02d:%02d:%02d", hrs, mins, secs)
end

local function formatShortHouseTimer(sec)
    local s = math.max(0, math.floor(tonumber(sec) or 0))
    return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

local function addLog(level, msg)
    local entry = string.format("[%s] [%s] %s", os.date("%H:%M:%S"), level, tostring(msg))
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
            addLog((messageType == Enum.MessageType.MessageError) and "ERR" or "WARN", message)
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
    if CoordsInputBox then CoordsInputBox.Text = str end
    pcall(function()
        if writefile then writefile(CoordsFileName, str) end
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
    pcall(function() RunService:Set3dRenderingEnabled(enabled) end)
    if Render3DToggleBtn then
        Render3DToggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(46, 184, 114) or Color3.fromRGB(208, 72, 82)
    end
    refreshAllMenuLabels()
end

local function setBlackScreenMode(active)
    State.BlackScreenActive = active
    if BlackOverlayFrame then BlackOverlayFrame.Visible = active end
    set3DRendering(not active)
    if BlackToggleBtnInSettings then
        BlackToggleBtnInSettings.BackgroundColor3 = active and Color3.fromRGB(46, 184, 114) or Color3.fromRGB(45, 40, 72)
    end
    refreshAllMenuLabels()
end

local NetworkFolder = nil
pcall(function() NetworkFolder = ReplicatedStorage:WaitForChild("Network", 8) end)

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

local function checkAndDismissGamePopups()
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return false end
    local handled = false

    for _, guiName in ipairs({"Message", "Prompt", "Dialog", "Popup"}) do
        local msgGui = pgui:FindFirstChild(guiName)
        if msgGui and msgGui:IsA("ScreenGui") and msgGui.Enabled then
            local mainFrame = msgGui:FindFirstChild("Frame") or msgGui
            local isVisible = (not mainFrame:IsA("GuiObject")) or mainFrame.Visible
            if isVisible then
                local bodyText = ""
                local yesBtn, noOrCancelBtn, okBtn = nil, nil, nil
                local allButtons = {}

                for _, d in ipairs(msgGui:GetDescendants()) do
                    if d:IsA("TextLabel") and isGuiActuallyVisible(d) and d.Text ~= "" then
                        local tLow = string.lower(d.Text)
                        if tLow ~= "ok" and tLow ~= "yes" and tLow ~= "no" and tLow ~= "cancel" and tLow ~= "так" and tLow ~= "ні" and tLow ~= "ок" and tLow ~= "да" and tLow ~= "нет" then
                            bodyText = bodyText .. " " .. d.Text
                        end
                    elseif d:IsA("GuiButton") and isGuiActuallyVisible(d) then
                        table.insert(allButtons, d)
                        local bTxt = string.lower(d.Name .. " " .. (d:IsA("TextButton") and (d.Text or "") or ""))
                        for _, sub in ipairs(d:GetDescendants()) do
                            if sub:IsA("TextLabel") then bTxt = bTxt .. " " .. string.lower(sub.Text or "") end
                        end
                        if string.find(bTxt, "cancel") or string.find(bTxt, "no") or string.find(bTxt, "close") or string.find(bTxt, "ні") or string.find(bTxt, "скасув") or string.find(bTxt, "нет") or string.find(bTxt, "отмен") then
                            noOrCancelBtn = d
                        elseif string.find(bTxt, "yes") or string.find(bTxt, "unlock") or string.find(bTxt, "buy") or string.find(bTxt, "confirm") or string.find(bTxt, "так") or string.find(bTxt, "да") or string.find(bTxt, "купит") then
                            yesBtn = d
                        elseif string.find(bTxt, "ok") or string.find(bTxt, "ок") then
                            okBtn = d
                        end
                    end
                end

                local lowBody = string.lower(bodyText)
                local costMatch = parseSuffixedNumber(string.match(bodyText, "([%d%,%.]+%s*[kKmMbB]?)"))
                if costMatch and costMatch > 0 then
                    State.LastPopupCostNumber = costMatch
                end

                local isCooldownPopup = string.find(lowBody, "cooldown") or string.find(lowBody, "ready in") or string.find(lowBody, "перезаряд") or string.find(lowBody, "зачекай") or string.find(lowBody, "подожд")
                local isErrorPopup = string.find(lowBody, "cannot") or string.find(lowBody, "can't") or string.find(lowBody, "not enough") or string.find(lowBody, "afford") or string.find(lowBody, "need") or string.find(lowBody, "must unlock") or string.find(lowBody, "locked") or string.find(lowBody, "previous") or string.find(lowBody, "error") or string.find(lowBody, "fast") or string.find(lowBody, "недостат") or string.find(lowBody, "не хвата") or string.find(lowBody, "закрит") or string.find(lowBody, "закрыт") or (okBtn ~= nil and yesBtn == nil and noOrCancelBtn == nil)

                local function hideModal(btnToClick)
                    if btnToClick then fireSafeSignal(btnToClick) end
                    pcall(function()
                        if mainFrame:IsA("GuiObject") then mainFrame.Visible = false end
                        msgGui.Enabled = false
                    end)
                end

                if isCooldownPopup then
                    State.LastHouseWasOnCooldown = true
                    hideModal(okBtn or noOrCancelBtn or allButtons[1])
                    handled = true
                elseif isErrorPopup and not (yesBtn and noOrCancelBtn) then
                    State.LastPopupWasError = true
                    State.LastPopupErrorText = bodyText
                    hideModal(okBtn or noOrCancelBtn or allButtons[1])
                    handled = true
                elseif (yesBtn or okBtn) and State.AllowConfirmPurchasePopup and State.AutoBuyHouses then
                    local reqCost = State.LastPopupCostNumber
                    if reqCost and reqCost > 0 and State.CurrentLollipops < reqCost then
                        State.LastPopupWasError = true
                        hideModal(noOrCancelBtn or okBtn or allButtons[1])
                    else
                        State.LastPopupPurchased = true
                        fireSafeSignal(yesBtn or okBtn)
                    end
                    handled = true
                elseif noOrCancelBtn or okBtn or #allButtons > 0 then
                    State.LastPopupWasError = true
                    hideModal(noOrCancelBtn or okBtn or allButtons[1])
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
                if string.find(gn, "notif") or string.find(gn, "alert") or string.find(gn, "toast") then
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
                            if string.find(low, "cooldown") or string.find(low, "wait") or string.find(low, "ready in") or string.find(low, "перезаряд") then
                                State.LastHouseWasOnCooldown = true
                            elseif string.find(low, "lock") or string.find(low, "not enough") or string.find(low, "afford") or string.find(low, "need") or string.find(low, "previous") or string.find(low, "недостат") or string.find(low, "закрит") then
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
        task.wait(0.15)
    end
end)

local function getObjectPosition(obj)
    if not obj then return nil end
    local pos = nil
    pcall(function()
        if obj:IsA("BasePart") then pos = obj.Position
        elseif obj:IsA("Attachment") then pos = obj.WorldPosition
        elseif obj:IsA("Model") then pos = obj:GetPivot().Position
        else
            local part = obj:FindFirstChildWhichIsA("BasePart", true)
            if part then pos = part.Position end
        end
    end)
    return pos
end

local function updatePetsAndLollipopsInventory()
    local dominusCount, wendigoCount, goatCount, lollipopCount = 0, 0, 0, 0
    local magnetUid, magnetCount = nil, 0

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
                    if string.find(idLow, "headless dominus") then dominusCount = dominusCount + amt
                    elseif string.find(idLow, "wendigo") then wendigoCount = wendigoCount + amt
                    elseif string.find(idLow, "grinning goat") then goatCount = goatCount + amt end
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
        State.StartPetCounts = { HeadlessDominus = dominusCount, Wendigo = wendigoCount, GrinningGoat = goatCount }
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
    if tick() < (State.FlagActiveUntil or 0) then
        return true
    end

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
                        if not fPos or (fPos - refPos).Magnitude <= 220 then
                            activeFound = true
                            return
                        end
                    end
                end
            end
        end

        local activeInst = getActiveInstanceContainer()
        if activeInst then
            for _, d in ipairs(activeInst:GetDescendants()) do
                local dn = string.lower(d.Name)
                if string.find(dn, "flag") then
                    local fPos = getObjectPosition(d)
                    if fPos and (fPos - refPos).Magnitude <= 220 then
                        activeFound = true
                        return
                    end
                end
            end
        end
    end)

    return activeFound
end

local function useOnlyMagnetFlagIfNoneActive()
    if not State.AutoMagnetFlag or State.IsVisitingHouses or State.IsPlacingFlag then
        return false
    end

    local now = tick()
    if now < (State.FlagActiveUntil or 0) or (now - (State.LastMagnetFlagTime or 0) < 300) then
        return false
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local targetCF = State.SavedEggCFrame or DefaultSpawnCFrame
    if not hrp or (hrp.Position - targetCF.Position).Magnitude > 45 then
        return false
    end

    if isMagnetOrAnyFlagActiveInZone() then
        State.FlagActiveUntil = now + 45
        return false
    end

    State.IsPlacingFlag = true
    State.LastMagnetFlagTime = now
    State.FlagActiveUntil = now + 305

    updatePetsAndLollipopsInventory()
    local uid = State.MagnetFlagUid
    if not uid or (State.MagnetFlagCount or 0) <= 0 then
        State.IsPlacingFlag = false
        return false
    end

    local okR, resR = invokeRemote("Flags: Consume", "Magnet Flag", uid)
    if not okR or resR == false then
        pcall(function()
            local lib = ReplicatedStorage:FindFirstChild("Library")
            local client = lib and lib:FindFirstChild("Client")
            local fMod = client and (client:FindFirstChild("FlexibleFlagCmds") or client:FindFirstChild("FlagCmds"))
            if fMod then
                local okM, mod = pcall(require, fMod)
                if okM and type(mod) == "table" and type(mod.Consume) == "function" then
                    pcall(mod.Consume, "Magnet Flag", uid)
                end
            end
        end)
    end

    addLog("OK", "Magnet Flag поставлено (1 шт на 5 хв).")
    State.IsPlacingFlag = false
    return true
end

task.spawn(function()
    task.wait(5.0)
    while State.Running do
        if State.AutoMagnetFlag and (State.FullAutoFarm or State.AutoEggs) and not State.IsVisitingHouses then
            pcall(useOnlyMagnetFlagIfNoneActive)
        end
        task.wait(8.0)
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
                            local origKey = "Orig_" .. modName .. "_" .. fnName
                            if type(env[origKey]) == "function" then
                                mod[fnName] = env[origKey]
                            end
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        if not getsenv or type(env.Orig_Senv_PlayEggAnimation) ~= "function" then return end
        local pscripts = LocalPlayer:FindFirstChild("PlayerScripts")
        if not pscripts then return end
        for _, desc in ipairs(pscripts:GetDescendants()) do
            if desc:IsA("LocalScript") and string.find(string.lower(desc.Name), "egg") and string.find(string.lower(desc.Name), "frontend") then
                local ok, senv = pcall(getsenv, desc)
                if ok and type(senv) == "table" then
                    senv.PlayEggAnimation = env.Orig_Senv_PlayEggAnimation
                end
            end
        end
    end)
end

setupInstantEggAnimationBypass()
State.TapEggUntil = tick() + 3.0

local function areEggsRenderingOnCamera()
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    for _, child in ipairs(cam:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            return true
        elseif child:IsA("Folder") and #child:GetChildren() > 0 then
            return true
        end
    end
    local debris = Workspace:FindFirstChild("__DEBRIS")
    if debris then
        for _, child in ipairs(debris:GetChildren()) do
            local cn = string.lower(child.Name)
            if string.find(cn, "egg") or string.find(cn, "hatch") then
                return true
            end
        end
    end
    return false
end

local function clearCameraEggModelsAndTap()
    if UserInputService:GetFocusedTextBox() then return false end
    local hasEggOnCam = areEggsRenderingOnCamera()
    if hasEggOnCam then
        State.TapEggUntil = math.max(State.TapEggUntil or 0, tick() + 0.85)
    end

    local shouldTapNow = hasEggOnCam or (tick() < (State.TapEggUntil or 0))
    if not shouldTapNow then
        return false
    end

    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1000, 600)
    local tx = math.floor(vp.X * 0.5)
    local ty = math.floor(vp.Y * 0.24)

    if MainFrame and MainFrame.Visible then
        local mp = MainFrame.AbsolutePosition
        local ms = MainFrame.AbsoluteSize
        if tx >= mp.X - 15 and tx <= mp.X + ms.X + 15 and ty >= mp.Y - 15 and ty <= mp.Y + ms.Y + 15 then
            if mp.Y > 75 then
                ty = math.floor(math.max(62, mp.Y - 20))
            else
                tx = math.floor(math.clamp(mp.X - 40, 85, vp.X - 85))
                ty = math.floor(vp.Y * 0.24)
            end
        end
    end

    pressKeyE(0.015)

    if VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(tx, ty))
        end)
    end

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(tx, ty, 0, true, game, 1)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(tx, ty, 0, false, game, 1)
        end)
    end

    if getconnections then
        pcall(function()
            local mouse = LocalPlayer:GetMouse()
            if mouse then
                for _, conn in ipairs(getconnections(mouse.Button1Down)) do
                    if conn.Function then task.spawn(conn.Function, tx, ty) end
                end
                for _, conn in ipairs(getconnections(mouse.Button1Up)) do
                    if conn.Function then task.spawn(conn.Function, tx, ty) end
                end
            end
            for _, conn in ipairs(getconnections(UserInputService.TouchTap)) do
                if conn.Function then task.spawn(conn.Function, {Vector2.new(tx, ty)}, false) end
            end
            for _, conn in ipairs(getconnections(UserInputService.TouchTapInWorld)) do
                if conn.Function then task.spawn(conn.Function, Vector2.new(tx, ty), false) end
            end
        end)
    end

    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pgui then return end
        for _, gui in ipairs(pgui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "HalloweenEventGui" and gui.Name ~= "Message" then
                local gName = string.lower(gui.Name)
                if string.find(gName, "egg") or string.find(gName, "hatch") or string.find(gName, "open") or string.find(gName, "anim") then
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("GuiButton") and d.Visible then
                            local dn = string.lower(d.Name)
                            if not string.find(dn, "close") and not string.find(dn, "cancel") and not string.find(dn, "exit") and not string.find(dn, "auto") then
                                fireSafeSignal(d)
                            end
                        end
                    end
                end
            end
        end
    end)

    return true
end

task.spawn(function()
    while State.Running do
        if (State.AutoEggs or State.FullAutoFarm) and not State.IsVisitingHouses then
            if clearCameraEggModelsAndTap() then
                task.wait(0.04)
            else
                task.wait(0.08)
            end
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
                if hum then hum.Jump = true end
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
                    if args[1] then
                        State.CachedEggId = args[1]
                        State.CachedEggRemoteName = self.Name
                    end
                    if type(args[2]) == "number" and args[2] > 1 then
                        if args[2] > State.MaxHatchDetected then State.MaxHatchDetected = args[2] end
                        if args[2] > (State.WorkingEggAmount or 0) then State.WorkingEggAmount = args[2] end
                    end
                elseif string.find(rName, "trick") or string.find(rName, "house") or string.find(rName, "door") or string.find(rName, "knock") or string.find(rName, "instancing") then
                    local combined = string.lower(rName .. " " .. tostring(args[1] or "") .. " " .. tostring(args[2] or ""))
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
    for _ = 1, 3 do
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
                        if v and v > bestMax and v <= 150 then bestMax = v end
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
    if detected and detected > 1 then return detected end
    if State.WorkingEggAmount and State.WorkingEggAmount > 1 then return State.WorkingEggAmount end
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
        end
    end)
    return snapshot
end

local function hasEnoughCurrencyForFullBatch(eggId, batchCount)
    if State.LearnedEggId == eggId and State.LearnedCurrencyKey and State.LearnedBatchCost > 0 then
        local currSnap = getAllPlayerCurrencies()
        local curVal = currSnap[State.LearnedCurrencyKey]
        if type(curVal) == "number" and curVal < (State.LearnedBatchCost * 0.96) then
            return false
        end
    end
    return true
end

local function recordBatchCurrencySpend(eggId, beforeSnap, afterSnap)
    local bestKey, bestDrop = nil, 0
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
        State.LearnedEggId = eggId
        State.LearnedCurrencyKey = bestKey
        if bestDrop > State.LearnedBatchCost then
            State.LearnedBatchCost = bestDrop
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
                if orb:IsA("BasePart") then orb.CFrame = hrp.CFrame
                elseif orb:IsA("Model") then orb:PivotTo(hrp.CFrame) end
                local numId = tonumber(orb.Name)
                if numId then table.insert(orbIds, numId) end
            end
            if #orbIds > 0 then invokeRemote("Orbs: Collect", orbIds) end
        end

        local lootbags = things:FindFirstChild("Lootbags")
        if lootbags then
            for _, bag in ipairs(lootbags:GetChildren()) do
                if bag:IsA("BasePart") then bag.CFrame = hrp.CFrame
                elseif bag:IsA("Model") then bag:PivotTo(hrp.CFrame) end
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
            if bPos and (bPos - myPos).Magnitude <= 125 then
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
        table.insert(candidates, { uid = uid, attrId = attrId, pos = pos, dist = d, isCustom = isCustom, obj = obj })
    end

    local things = getThingsFolder()
    if things then
        local ce = things:FindFirstChild("CustomEggs")
        if ce then
            for _, egg in ipairs(ce:GetChildren()) do
                addCand(egg.Name, egg:GetAttribute("id") or egg:GetAttribute("EggName") or egg:GetAttribute("ID"), getObjectPosition(egg), true, egg)
            end
        end
        local ef = things:FindFirstChild("Eggs")
        if ef then
            for _, egg in ipairs(ef:GetChildren()) do
                local attr = egg:GetAttribute("EggName") or egg:GetAttribute("id") or egg:GetAttribute("ID")
                local cleanName = string.match(egg.Name, "^%d+%s*-%s*(.+)$") or egg.Name
                addCand(egg.Name, attr or cleanName, getObjectPosition(egg), false, egg)
            end
        end
    end

    local _, activeFolder = getActiveInstanceContainer()
    if activeFolder then
        for _, d in ipairs(activeFolder:GetDescendants()) do
            if d.Parent and (d.Parent.Name == "CustomEggs" or d.Parent.Name == "Eggs" or d.Parent.Name == "EggCapsules") then
                addCand(d.Name, d:GetAttribute("id") or d:GetAttribute("EggName") or d:GetAttribute("ID"), getObjectPosition(d), d.Parent.Name == "CustomEggs", d)
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
    task.wait(0.35)

    if #findNearestEggCandidates(120) == 0 then
        local things = getThingsFolder()
        local instancesFolder = things and things:FindFirstChild("Instances")
        local candidateIds = {}

        if instancesFolder then
            for _, instObj in ipairs(instancesFolder:GetChildren()) do
                local low = string.lower(instObj.Name)
                local isFishingOrOther = string.find(low, "fish") or string.find(low, "dig") or string.find(low, "mine") or string.find(low, "garden") or string.find(low, "obby") or string.find(low, "claw") or string.find(low, "chest") or string.find(low, "kart")
                if not isFishingOrOther and (string.find(low, "halloween") or string.find(low, "hatch") or string.find(low, "trick") or string.find(low, "spooky") or string.find(low, "manor")) then
                    table.insert(candidateIds, instObj.Name)
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

        task.wait(0.7)
        teleportSafelyTo(targetCF)
        task.wait(0.25)
    end

    applyGameLanguageNow(State.LanguageIndex)
    updatePetsAndLollipopsInventory()
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
    if not remoteObj or not eggId then return false, "nil" end
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
        State.ConsecutiveHatchFails = 0
        State.TapEggUntil = tick() + 3.2
        task.spawn(clearCameraEggModelsAndTap)
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
    local ladder = { 99, 90, 84, 79, 75, 64, 50, 35, 25, 15, 8, 4, 1 }
    for _, amt in ipairs(ladder) do
        if invokeEggBatch(remoteObj, eggId, amt) then
            if amt > 1 then
                local low = amt + 1
                local high = math.min(amt + 15, 110)
                local best = amt
                while low <= high do
                    local mid = math.floor((low + high) / 2)
                    task.wait(1.8)
                    if invokeEggBatch(remoteObj, eggId, mid) then
                        best = mid
                        low = mid + 1
                    else
                        high = mid - 1
                    end
                end
                State.WorkingEggAmount = best
                State.MaxHatchDetected = best
                return true, best
            else
                State.WorkingEggAmount = 1
                return true, 1
            end
        end
    end
    return false, 0
end

local function fastHatchOnce()
    if State.IsVisitingHouses or State.IsHatchingNow then return false end
    State.IsHatchingNow = true

    local didHatch = false
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local targetCF = State.SavedEggCFrame or DefaultSpawnCFrame

        if hrp and (hrp.Position - targetCF.Position).Magnitude > 14 then
            teleportSafelyTo(targetCF)
            task.wait(0.15)
        end

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
                if invokeEggBatch(r, State.CachedEggId, targetAmt) then
                    didHatch = true
                    setStatusText(string.format("Hatched: %d eggs (total: %s)", targetAmt, formatNumber(State.TotalEggsHatched)), nil)
                    return
                else
                    State.ConsecutiveHatchFails = (State.ConsecutiveHatchFails or 0) + 1
                    if State.ConsecutiveHatchFails >= 2 then
                        State.CachedEggRemoteName = nil
                        State.CachedEggId = nil
                    else
                        collectAllOrbsAndLootbagsNow()
                        farmNearbyBreakables()
                        setStatusText(string.format("Waiting coins/CD for %d eggs...", targetAmt), nil)
                        return
                    end
                end
            end
        end

        local cands = findNearestEggCandidates(85)
        if #cands > 0 then
            local best = cands[1]
            local remotesToTry = {"CustomEggs_Hatch", "Eggs_RequestPurchase"}
            local idsToTry = {}
            if best.uid then table.insert(idsToTry, best.uid) end
            if best.attrId and best.attrId ~= best.uid then table.insert(idsToTry, best.attrId) end

            for _, rName in ipairs(remotesToTry) do
                local r = findRemote(rName)
                if r and r:IsA("RemoteFunction") then
                    for _, idVal in ipairs(idsToTry) do
                        if invokeEggBatch(r, idVal, targetAmt) then
                            State.CachedEggRemoteName = rName
                            State.CachedEggId = idVal
                            didHatch = true
                            setStatusText(string.format("Hatched: %s (%dx | total %s)", tostring(best.attrId or idVal), targetAmt, formatNumber(State.TotalEggsHatched)), nil)
                            return
                        elseif State.CustomEggCount == 0 or (State.ConsecutiveHatchFails or 0) >= 3 then
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
            setStatusText("At coords (7538.1, 15.7, 21965.5) - waiting for egg...", nil)
        end
    end)

    State.IsHatchingNow = false
    return didHatch
end

task.spawn(function()
    while State.Running do
        if (State.AutoEggs or State.FullAutoFarm) and not State.IsVisitingHouses then
            fastHatchOnce()
            local waitDeadline = tick() + (State.EggHatchDelay or 2.0)
            while tick() < waitDeadline and State.Running and not State.IsVisitingHouses do
                clearCameraEggModelsAndTap()
                task.wait(0.06)
            end
            local extraFinishDeadline = tick() + 1.8
            while areEggsRenderingOnCamera() and tick() < extraFinishDeadline and State.Running and not State.IsVisitingHouses do
                clearCameraEggModelsAndTap()
                task.wait(0.05)
            end
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
            if string.find(sName, "minigame") or string.find(sName, "trickortreat") or string.find(sName, "trick_or_treat") or string.find(sName, "hatchbattle") or string.find(sName, "hatch_battle") or string.find(sName, "doorgame") or string.find(sName, "captcha") then
                for _, obj in ipairs(screen:GetDescendants()) do
                    if obj:IsA("GuiButton") and obj.Visible then
                        local oName = string.lower(obj.Name)
                        if not string.find(oName, "close") and not string.find(oName, "exit") and not string.find(oName, "cancel") and not string.find(oName, "leave") then
                            foundActive = true
                            if State.AutoMinigame and (now - (LastDotClick[obj] or 0) > 0.06) then
                                LastDotClick[obj] = now
                                fireSafeSignal(obj)
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
            task.wait(0.06)
        else
            task.wait(0.3)
        end
    end
end)

local function inspectDoorCloseUp(house)
    local isLocked = false
    local unlockCost = nil

    local function checkRawString(raw)
        if not raw or raw == "" then return end
        local low = string.lower(raw)
        if string.find(low, "locked") or string.find(low, "unlock") or string.find(low, "purchase") or string.find(low, "buy") or string.find(low, "lollipop") or string.find(low, "закрито") or string.find(low, "закрыто") or string.find(low, "розблок") or string.find(low, "разблок") or string.find(low, "купити") or string.find(low, "купить") then
            isLocked = true
            local c = parseSuffixedNumber(string.match(raw, "([%d%,%.]+%s*[kKmMbB]?)"))
            if c and c > 0 then unlockCost = c end
        end
    end

    pcall(function()
        if house.prompt and house.prompt.Parent then
            checkRawString(house.prompt.ActionText)
            checkRawString(house.prompt.ObjectText)
            local pAttr = tonumber(house.prompt:GetAttribute("Price")) or tonumber(house.prompt:GetAttribute("Cost")) or tonumber(house.prompt:GetAttribute("UnlockCost"))
            if pAttr and pAttr > 0 then isLocked = true; unlockCost = pAttr end
            if house.prompt:GetAttribute("Locked") == true or house.prompt:GetAttribute("Unlocked") == false then
                isLocked = true
            end
        end

        if house.instance then
            if house.instance:GetAttribute("Locked") == true or house.instance:GetAttribute("Unlocked") == false then
                isLocked = true
            end
            local mCost = tonumber(house.instance:GetAttribute("Price")) or tonumber(house.instance:GetAttribute("Cost")) or tonumber(house.instance:GetAttribute("UnlockCost"))
            if mCost and mCost > 0 then isLocked = true; unlockCost = mCost end
            for _, sub in ipairs(house.instance:GetDescendants()) do
                if sub:IsA("TextLabel") and isGuiActuallyVisible(sub) and sub.Text ~= "" then
                    checkRawString(sub.Text)
                elseif sub:IsA("ProximityPrompt") then
                    checkRawString(sub.ActionText)
                    checkRawString(sub.ObjectText)
                end
            end
        end
    end)

    return isLocked, unlockCost
end

local function findGroundDoorPosition(modelOrPart, playerGroundY)
    if modelOrPart:IsA("BasePart") then
        if math.abs(modelOrPart.Position.Y - playerGroundY) <= 14 then
            return Vector3.new(modelOrPart.Position.X, playerGroundY, modelOrPart.Position.Z), modelOrPart, nil
        end
        return nil, nil, nil
    end

    local bestPart, bestScore = nil, -999
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
            if (existing - groundPos).Magnitude < 14 then return end
        end

        local posKey = string.format("house_%d_%d", math.floor(groundPos.X / 12 + 0.5), math.floor(groundPos.Z / 12 + 0.5))
        local rawId = nil
        pcall(function()
            if inst then
                rawId = inst:GetAttribute("Id") or inst:GetAttribute("ID") or inst:GetAttribute("HouseId") or inst:GetAttribute("DoorId") or inst.Name
            end
        end)

        table.insert(seenPositions, groundPos)
        table.insert(rawHouses, { key = posKey, rawName = rawName, rawId = rawId, pos = groundPos, instance = inst, prompt = promptObj })
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
                            addUniqueHouse((desc.ObjectText ~= "" and desc.ObjectText) or hModel.Name, pPos, hModel, desc)
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
                            if doorPos then addUniqueHouse(hModel.Name, doorPos, hModel, promptObj) end
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
        if za ~= zb then return za < zb end
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
            local sinceLastTry = now - (lockedMem.lastTryTime or 0)
            if State.AutoBuyHouses and sinceLastTry >= 60 then
                local prevLolli = lockedMem.lollipopsAtAttempt or 0
                if unlockCost and unlockCost > 0 then
                    canTryUnlockNow = (curLollipops >= unlockCost)
                else
                    canTryUnlockNow = (curLollipops > prevLolli)
                end
            end
        end

        local isReady = (not isLocked and remCd <= 0) or (isLocked and canTryUnlockNow)

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

    if #houses > 0 then
        State.HouseKnownList = houses
    end

    if State.MaxUnlockedHouses > 0 and #houses > State.MaxUnlockedHouses then
        local limited = {}
        for i = 1, State.MaxUnlockedHouses do table.insert(limited, houses[i]) end
        return limited
    end

    return houses
end

local function triggerDoorFast(pos, inst, directPrompt)
    local promptsToFire = {}
    if directPrompt and directPrompt.Parent then
        table.insert(promptsToFire, directPrompt)
    end
    if inst then
        for _, desc in ipairs(inst:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                table.insert(promptsToFire, desc)
            end
        end
    end

    for _, pr in ipairs(promptsToFire) do
        pcall(function()
            pr.HoldDuration = 0
            pr.RequiresLineOfSight = false
            pr.MaxActivationDistance = 40
            pr.Enabled = true
        end)
        pcall(function()
            if fireproximityprompt then fireproximityprompt(pr) end
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
                if rem:IsA("RemoteFunction") then rem:InvokeServer(unpack(args))
                elseif rem:IsA("RemoteEvent") then rem:FireServer(unpack(args)) end
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
                end
            end
            invokeRemote("TrickOrTreat_UnlockHouse", numId)
            invokeRemote("TrickOrTreat_BuyHouse", numId)
        end
        for _, act in ipairs({ "Knock", "TrickOrTreat", "ClaimHouse", "OpenDoor", "Interact" }) do
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

local function buildCompactTimersSummary(housesList)
    if not housesList or #housesList == 0 then return "Houses: Ready" end
    local now = tick()
    local parts = {}
    local t = L()
    for i, h in ipairs(housesList) do
        local key = h.key
        local lockedMem = State.LockedHouseInfo[key]
        local isLocked = (lockedMem and lockedMem.locked and not State.ConfirmedUnlockedHouses[key]) or false
        local rem = math.max(0, (State.HouseCooldownMap[key] or 0) - now)
        if isLocked then
            table.insert(parts, string.format("H%d:%s", i, t.houseLockedShort))
        elseif rem > 0 then
            table.insert(parts, string.format("H%d:%s", i, formatShortHouseTimer(rem)))
        else
            table.insert(parts, string.format("H%d:%s", i, t.houseReadyShort))
        end
    end
    return table.concat(parts, " | ")
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
    for _, h in ipairs(allHouses) do
        if h.isReady or forceAll then
            table.insert(housesToProcess, h)
        end
    end

    if #housesToProcess == 0 then
        setStatusText(nil, buildCompactTimersSummary(allHouses))
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
            task.wait(0.25)

            local closeLocked, closeCost = inspectDoorCloseUp(house)

            if (closeLocked or house.isLocked) and not State.ConfirmedUnlockedHouses[house.key] and (not State.AutoBuyHouses or (closeCost and closeCost > 0 and lollipopsBefore < closeCost)) then
                local reqCost = closeCost or house.unlockCost
                State.LockedHouseInfo[house.key] = {
                    locked = true,
                    lollipopsAtAttempt = lollipopsBefore,
                    requiredCost = reqCost,
                    lastTryTime = tick()
                }
                setStatusText(nil, string.format("Skipping locked %s (Lollipops: %s/%s)", tostring(house.name), formatNumber(lollipopsBefore), tostring(reqCost or "?")))
            else
                State.LastPopupWasError = false
                State.LastPopupPurchased = false
                State.LastHouseWasOnCooldown = false
                State.LastPopupErrorText = ""
                State.LastPopupCostNumber = nil
                State.AllowConfirmPurchasePopup = State.AutoBuyHouses
                local notifBefore = snapshotNotifications()

                setStatusText(nil, string.format("Opening %s (%d/%d) - %.0fs...", tostring(house.name), i, #housesToProcess, stepWait))

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

                    if (tick() - waitStarted >= stepWait * 0.45) and not triggeredSecondTime then
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
                else
                    State.ConfirmedUnlockedHouses[house.key] = true
                    State.LockedHouseInfo[house.key] = nil
                    if not State.LastHouseWasOnCooldown then
                        State.TotalHousesOpened = State.TotalHousesOpened + 1
                    end
                    State.HouseCooldownMap[house.key] = tick() + (State.HouseCooldownDefault or 600)
                    addLog("OK", string.format("Відкрито %s! Таймер 10:00 запущено.", tostring(house.name)))
                end
            end
        end
    end)

    State.AllowConfirmPurchasePopup = false
    checkAndDismissGamePopups()
    if not ok then addLog("ERR", "House error: " .. tostring(err)) end

    if returnCF and State.Running then
        teleportSafelyTo(returnCF)
    end

    State.NextAutoHouseCheckTime = tick() + 15
    State.IsVisitingHouses = false
    setStatusText(nil, buildCompactTimersSummary(State.HouseKnownList))
end

task.spawn(function()
    while State.Running do
        if State.FullAutoFarm and not State.IsVisitingHouses and (tick() >= (State.NextAutoHouseCheckTime or 0)) then
            pcall(function() visitReadyHousesAndReturn(false) end)
            task.wait(2.0)
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
            task.wait(0.35)
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

    local cands = findNearestEggCandidates(85)
    addLog("INFO", "Eggs nearby (" .. #cands .. "):")
    for i, c in ipairs(cands) do
        addLog("INFO", string.format("  [%d] uid='%s' id='%s' dist=%.1f", i, tostring(c.uid), tostring(c.attrId), c.dist))
    end

    local houses = scanAllHousesWithState(myPos.Y, myPos)
    addLog("INFO", "Houses (" .. #houses .. "):")
    for i, h in ipairs(houses) do
        addLog("INFO", string.format("  [%d] %s | Locked=%s | Ready=%s | Timer=%s", i, tostring(h.name), tostring(h.isLocked), tostring(h.isReady), formatShortHouseTimer(h.remainingCd)))
    end
    addLog("OK", "Done.")
end

local ParentGui = nil
pcall(function() if gethui then ParentGui = gethui() end end)
if not ParentGui then pcall(function() ParentGui = game:GetService("CoreGui") end) end
if not ParentGui then ParentGui = LocalPlayer:WaitForChild("PlayerGui") end

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
    Bg = Color3.fromRGB(28, 25, 46),
    Header = Color3.fromRGB(39, 34, 66),
    Card = Color3.fromRGB(45, 40, 72),
    CardBright = Color3.fromRGB(58, 51, 92),
    Stroke = Color3.fromRGB(108, 92, 168),
    Accent = Color3.fromRGB(238, 130, 48),
    Blue = Color3.fromRGB(88, 132, 238),
    Green = Color3.fromRGB(46, 184, 114),
    Red = Color3.fromRGB(208, 72, 82),
    Gold = Color3.fromRGB(252, 192, 68),
    Text = Color3.fromRGB(248, 246, 255),
    SubText = Color3.fromRGB(192, 186, 224),
    InputBg = Color3.fromRGB(21, 18, 36)
}

local function addCornerAndStroke(inst, radius, strokeColor, thickness)
    if radius then Instance.new("UICorner", inst).CornerRadius = UDim.new(0, radius) end
    if strokeColor then
        local s = Instance.new("UIStroke", inst)
        s.Color = strokeColor
        s.Thickness = thickness or 1
        return s
    end
    return nil
end

local function makeBtn(parent, size, pos, bg, text, textSize, zIndex, radius, order)
    local b = Instance.new("TextButton")
    b.Size = size
    if pos then b.Position = pos end
    if order then b.LayoutOrder = order end
    b.BackgroundColor3 = bg
    b.Text = text or ""
    b.TextColor3 = Colors.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = textSize or 12
    b.ZIndex = zIndex or 33
    b.Parent = parent
    if radius then Instance.new("UICorner", b).CornerRadius = UDim.new(0, radius) end
    return b
end

local function makeLabel(parent, size, pos, text, color, font, textSize, zIndex, xAlign, order)
    local l = Instance.new("TextLabel")
    l.Size = size
    if pos then l.Position = pos end
    if order then l.LayoutOrder = order end
    l.BackgroundTransparency = 1
    l.Text = text or ""
    l.TextColor3 = color or Colors.Text
    l.Font = font or Enum.Font.GothamBold
    l.TextSize = textSize or 12
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.ZIndex = zIndex or 33
    l.Parent = parent
    return l
end

BlackOverlayFrame = Instance.new("Frame")
BlackOverlayFrame.Name = "BlackScreenOverlay"
BlackOverlayFrame.Size = UDim2.new(1, 0, 1, 0)
BlackOverlayFrame.BackgroundColor3 = Color3.fromRGB(15, 13, 25)
BlackOverlayFrame.BorderSizePixel = 0
BlackOverlayFrame.Active = false
BlackOverlayFrame.Visible = false
BlackOverlayFrame.ZIndex = 10
BlackOverlayFrame.Parent = ScreenGui

local DashCard = Instance.new("Frame")
DashCard.Size = UDim2.new(0, 476, 0, 405)
DashCard.Position = UDim2.new(0.5, -238, 0.5, -202)
DashCard.BackgroundColor3 = Colors.Bg
DashCard.BorderSizePixel = 0
DashCard.ZIndex = 11
DashCard.Parent = BlackOverlayFrame
addCornerAndStroke(DashCard, 8, Colors.Stroke, 1.5)

local DashTopBar = Instance.new("Frame")
DashTopBar.Size = UDim2.new(1, 0, 0, 34)
DashTopBar.BackgroundColor3 = Colors.Header
DashTopBar.BorderSizePixel = 0
DashTopBar.ZIndex = 12
DashTopBar.Parent = DashCard
addCornerAndStroke(DashTopBar, 8, nil, nil)

DashTitle = makeLabel(DashTopBar, UDim2.new(1, -24, 1, 0), UDim2.new(0, 12, 0, 0), "HATCH WARS AFK  |  3D RENDERING OFF", Colors.Gold, Enum.Font.GothamBold, 13, 13)

local function createStatBox(parent, title, initVal, posScaleX, posY, widthScale, heightPx, valColor)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(widthScale, -12, 0, heightPx)
    box.Position = UDim2.new(posScaleX, 10, 0, posY)
    box.BackgroundColor3 = Colors.Card
    box.BorderSizePixel = 0
    box.ZIndex = 12
    box.Parent = parent
    addCornerAndStroke(box, 6, Colors.Stroke, 1)

    local lblTitle = makeLabel(box, UDim2.new(1, -12, 0, 15), UDim2.new(0, 6, 0, 4), title, Colors.SubText, Enum.Font.Gotham, 11, 13)
    local lblVal = makeLabel(box, UDim2.new(1, -12, 0, heightPx - 20), UDim2.new(0, 6, 0, 19), initVal, valColor or Colors.Text, Enum.Font.GothamBold, 14, 13)
    return lblVal, lblTitle
end

StatTimeValue, StatTimeTitle = createStatBox(DashCard, "Farm Time", "00:00:00", 0, 42, 0.333, 48, Colors.Text)
StatEggsValue, StatEggsTitle = createStatBox(DashCard, "Eggs Hatched", "0 (0)", 0.333, 42, 0.333, 48, Colors.Gold)
StatHousesValue, StatHousesTitle = createStatBox(DashCard, "Houses Opened", "0", 0.666, 42, 0.334, 48, Colors.Green)

StatDominusValue = createStatBox(DashCard, "Headless Dominus", "+0 (0)", 0, 96, 0.25, 48, Colors.Text)
StatWendigoValue = createStatBox(DashCard, "Wendigo", "+0 (0)", 0.25, 96, 0.25, 48, Colors.Text)
StatGoatValue = createStatBox(DashCard, "Grinning Goat", "+0 (0)", 0.50, 96, 0.25, 48, Colors.Text)
StatLollipopValue, StatLollipopTitle = createStatBox(DashCard, "Lollipops", "0", 0.75, 96, 0.25, 48, Colors.Gold)

local function buildEightHouseTimersGrid(parentFrame, posY, layoutOrder, outCellsTable, zBase)
    local container = Instance.new("Frame")
    if layoutOrder then
        container.LayoutOrder = layoutOrder
        container.Size = UDim2.new(1, -6, 0, 56)
    else
        container.Size = UDim2.new(1, -20, 0, 56)
        container.Position = UDim2.new(0, 10, 0, posY)
    end
    container.BackgroundTransparency = 1
    container.ZIndex = zBase
    container.Parent = parentFrame

    for i = 1, 8 do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local cell = Instance.new("Frame")
        cell.Size = UDim2.new(0.25, -4, 0, 25)
        cell.Position = UDim2.new(col * 0.25, 2, 0, row * 29)
        cell.BackgroundColor3 = Color3.fromRGB(32, 72, 56)
        cell.BorderSizePixel = 0
        cell.ZIndex = zBase + 1
        cell.Parent = container
        local cellStroke = addCornerAndStroke(cell, 5, Colors.Green, 1)
        local lbl = makeLabel(cell, UDim2.new(1, -6, 1, 0), UDim2.new(0, 3, 0, 0), string.format("H%d: READY", i), Color3.fromRGB(140, 255, 190), Enum.Font.GothamBold, 11, zBase + 2, Enum.TextXAlignment.Center)
        outCellsTable[i] = { frame = cell, stroke = cellStroke, label = lbl }
    end
    return container
end

buildEightHouseTimersGrid(DashCard, 152, nil, DashHouseCells, 12)

local StatusBanner = Instance.new("Frame")
StatusBanner.Size = UDim2.new(1, -20, 0, 42)
StatusBanner.Position = UDim2.new(0, 10, 0, 214)
StatusBanner.BackgroundColor3 = Colors.InputBg
StatusBanner.BorderSizePixel = 0
StatusBanner.ZIndex = 12
StatusBanner.Parent = DashCard
addCornerAndStroke(StatusBanner, 6, Colors.Stroke, 1)

StatStatusValue = makeLabel(StatusBanner, UDim2.new(1, -16, 1, -8), UDim2.new(0, 8, 0, 4), "Ready...", Colors.Text, Enum.Font.Gotham, 12, 13)
StatStatusValue.TextWrapped = true

ExitBlackBtn = makeBtn(DashCard, UDim2.new(0.42, -8, 0, 34), UDim2.new(0, 10, 0, 264), Colors.Green, "Exit Stats Screen (3D ON)", 12, 13, 6)
OpenMenuOnBlackBtn = makeBtn(DashCard, UDim2.new(0.24, -6, 0, 34), UDim2.new(0.42, 4, 0, 264), Colors.Blue, "Menu", 12, 13, 6)
LangCycleBtnBlack = makeBtn(DashCard, UDim2.new(0.34, -10, 0, 34), UDim2.new(0.66, 0, 0, 264), Colors.CardBright, "Language: EN", 11, 13, 6)
TeleportNowOnBlackBtn = makeBtn(DashCard, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 306), Colors.CardBright, "Teleport to Coords (7538.1, 15.7, 21965.5)", 12, 13, 6)
RunHousesOnBlackBtn = makeBtn(DashCard, UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 346), Colors.Accent, "Check & Open Houses Now", 12, 13, 6)

bindButton(LangCycleBtnBlack, cycleGameLanguage)
bindButton(RunHousesOnBlackBtn, function() task.spawn(function() visitReadyHousesAndReturn(true) end) end)

local function updateHouseTimerCellList(cellList, housesData, nowTick)
    local t = L()
    for i = 1, 8 do
        local cellObj = cellList[i]
        if cellObj and cellObj.label then
            local h = housesData and housesData[i]
            local key = h and h.key or nil
            local lockedMem = key and State.LockedHouseInfo[key] or nil
            local isLocked = (key and lockedMem and lockedMem.locked and not State.ConfirmedUnlockedHouses[key]) or false
            local rem = key and math.max(0, (State.HouseCooldownMap[key] or 0) - nowTick) or 0

            if isLocked then
                local costTxt = (lockedMem and lockedMem.requiredCost) and formatNumber(lockedMem.requiredCost) or t.houseLockedShort
                cellObj.label.Text = string.format("H%d: %s", i, costTxt)
                cellObj.label.TextColor3 = Color3.fromRGB(255, 140, 145)
                cellObj.frame.BackgroundColor3 = Color3.fromRGB(64, 34, 48)
                cellObj.stroke.Color = Colors.Red
            elseif rem > 0 then
                cellObj.label.Text = string.format("H%d: %s", i, formatShortHouseTimer(rem))
                cellObj.label.TextColor3 = Colors.Gold
                cellObj.frame.BackgroundColor3 = Colors.Card
                cellObj.stroke.Color = Colors.Stroke
            else
                cellObj.label.Text = string.format("H%d: %s", i, t.houseReadyShort)
                cellObj.label.TextColor3 = Color3.fromRGB(140, 255, 190)
                cellObj.frame.BackgroundColor3 = Color3.fromRGB(32, 72, 56)
                cellObj.stroke.Color = Colors.Green
            end
        end
    end
end

task.spawn(function()
    local lastInvCheck = 0
    while State.Running do
        local now = tick()
        if now - lastInvCheck >= 2.5 then
            lastInvCheck = now
            updatePetsAndLollipopsInventory()
        end

        if StatTimeValue then StatTimeValue.Text = formatDuration(now - State.StartTime) end
        if StatEggsValue then StatEggsValue.Text = string.format("%s (%d)", formatNumber(State.TotalEggsHatched), State.TotalEggBatches) end
        if StatHousesValue then StatHousesValue.Text = formatNumber(State.TotalHousesOpened) end

        local baseDom = (State.StartPetCounts and State.StartPetCounts.HeadlessDominus) or 0
        local baseWen = (State.StartPetCounts and State.StartPetCounts.Wendigo) or 0
        local baseGoat = (State.StartPetCounts and State.StartPetCounts.GrinningGoat) or 0
        local curDom = State.CurrentPetCounts.HeadlessDominus or 0
        local curWen = State.CurrentPetCounts.Wendigo or 0
        local curGoat = State.CurrentPetCounts.GrinningGoat or 0

        if StatDominusValue then StatDominusValue.Text = string.format("+%s (%s)", formatNumber(math.max(0, curDom - baseDom)), formatNumber(curDom)) end
        if StatWendigoValue then StatWendigoValue.Text = string.format("+%s (%s)", formatNumber(math.max(0, curWen - baseWen)), formatNumber(curWen)) end
        if StatGoatValue then StatGoatValue.Text = string.format("+%s (%s)", formatNumber(math.max(0, curGoat - baseGoat)), formatNumber(curGoat)) end
        if StatLollipopValue then StatLollipopValue.Text = formatNumber(State.CurrentLollipops) end

        local knownHouses = State.HouseKnownList
        updateHouseTimerCellList(DashHouseCells, knownHouses, now)
        updateHouseTimerCellList(MenuFarmHouseCells, knownHouses, now)
        updateHouseTimerCellList(MenuHousesTabCells, knownHouses, now)

        task.wait(0.5)
    end
end)

local FloatBtn = makeBtn(ScreenGui, UDim2.new(0, 56, 0, 38), UDim2.new(0, 14, 0.5, -19), Colors.Accent, "MENU", 12, 60, 8)
FloatBtn.Visible = false
addCornerAndStroke(FloatBtn, 8, Colors.Text, 1)

MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 445, 0, 370)
MainFrame.Position = UDim2.new(0.5, -222, 0.5, -185)
MainFrame.BackgroundColor3 = Colors.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = false
MainFrame.ZIndex = 30
MainFrame.Parent = ScreenGui
addCornerAndStroke(MainFrame, 8, Colors.Stroke, 1.5)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 36)
TopBar.BackgroundColor3 = Colors.Header
TopBar.BorderSizePixel = 0
TopBar.Active = true
TopBar.ZIndex = 31
TopBar.Parent = MainFrame
addCornerAndStroke(TopBar, 8, nil, nil)

TitleLabel = makeLabel(TopBar, UDim2.new(1, -135, 1, 0), UDim2.new(0, 12, 0, 0), "PS99 Hatch Wars", Colors.Gold, Enum.Font.GothamBold, 14, 32)
local BlackModeHeaderBtn = makeBtn(TopBar, UDim2.new(0, 48, 0, 24), UDim2.new(1, -116, 0, 6), Colors.Blue, "3D OFF", 10, 33, 5)
local MinBtn = makeBtn(TopBar, UDim2.new(0, 28, 0, 24), UDim2.new(1, -64, 0, 6), Colors.CardBright, "_", 12, 33, 5)
local CloseBtn = makeBtn(TopBar, UDim2.new(0, 28, 0, 24), UDim2.new(1, -32, 0, 6), Colors.Red, "X", 12, 33, 5)

do
    local dragging, dragStart, startPos = false, nil, nil
    trackConn(TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        end
    end))
    trackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

bindButton(MinBtn, function() MainFrame.Visible = false; FloatBtn.Visible = true end)
bindButton(FloatBtn, function() MainFrame.Visible = true; FloatBtn.Visible = false end)
bindButton(BlackModeHeaderBtn, function()
    setBlackScreenMode(not State.BlackScreenActive)
    if State.BlackScreenActive then MainFrame.Visible = false; FloatBtn.Visible = true end
end)
bindButton(ExitBlackBtn, function() setBlackScreenMode(false); MainFrame.Visible = true; FloatBtn.Visible = false end)
bindButton(OpenMenuOnBlackBtn, function() MainFrame.Visible = not MainFrame.Visible; FloatBtn.Visible = not MainFrame.Visible end)
bindButton(TeleportNowOnBlackBtn, function() task.spawn(enterHalloweenEventAndGoToCoords) end)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 30)
TabBar.Position = UDim2.new(0, 8, 0, 40)
TabBar.BackgroundTransparency = 1
TabBar.ZIndex = 31
TabBar.Parent = MainFrame

TabFarmBtn = makeBtn(TabBar, UDim2.new(0.25, -4, 1, 0), UDim2.new(0, 2, 0, 0), Colors.Card, "Farm", 12, 32, 6)
TabHousesBtn = makeBtn(TabBar, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.25, 2, 0, 0), Colors.Card, "Houses", 12, 32, 6)
TabSettingsBtn = makeBtn(TabBar, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.50, 2, 0, 0), Colors.Card, "Settings", 12, 32, 6)
TabLogsBtn = makeBtn(TabBar, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.75, 2, 0, 0), Colors.Card, "Logs", 12, 32, 6)

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -16, 1, -78)
ContentArea.Position = UDim2.new(0, 8, 0, 74)
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
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 14)
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
        btn.BackgroundColor3 = (btn == activeBtn) and Colors.Accent or Colors.Card
        btn.TextColor3 = (btn == activeBtn) and Colors.Text or Colors.SubText
    end
end

bindButton(TabFarmBtn, function() switchTab(PageFarm, TabFarmBtn) end)
bindButton(TabHousesBtn, function() switchTab(PageHouses, TabHousesBtn) end)
bindButton(TabSettingsBtn, function() switchTab(PageSettings, TabSettingsBtn) end)
bindButton(TabLogsBtn, function() switchTab(PageLogs, TabLogsBtn) end)

FullAutoToggle = makeBtn(PageFarm, UDim2.new(1, -6, 0, 34), nil, Colors.Green, "", 12, 33, 6, 1)
EggStatusLabel = makeLabel(PageFarm, UDim2.new(1, -6, 0, 16), nil, "Eggs: Ready", Colors.Gold, Enum.Font.GothamBold, 11, 33, Enum.TextXAlignment.Left, 2)
HouseStatusLabel = makeLabel(PageFarm, UDim2.new(1, -6, 0, 16), nil, "Houses: Ready", Colors.SubText, Enum.Font.Gotham, 11, 33, Enum.TextXAlignment.Left, 3)
MenuFarmTimersTitle = makeLabel(PageFarm, UDim2.new(1, -6, 0, 15), nil, "House Timers (10m after open):", Colors.SubText, Enum.Font.GothamBold, 11, 33, Enum.TextXAlignment.Left, 4)
buildEightHouseTimersGrid(PageFarm, 0, 5, MenuFarmHouseCells, 33)

bindButton(FullAutoToggle, function()
    State.FullAutoFarm = not State.FullAutoFarm
    if State.FullAutoFarm then
        setupInstantEggAnimationBypass()
        FullAutoToggle.BackgroundColor3 = Colors.Green
    else
        FullAutoToggle.BackgroundColor3 = Colors.Red
    end
    refreshAllMenuLabels()
end)

MagnetFlagToggleBtn = makeBtn(PageFarm, UDim2.new(1, -6, 0, 30), nil, Colors.Green, "", 12, 33, 6, 6)
bindButton(MagnetFlagToggleBtn, function()
    State.AutoMagnetFlag = not State.AutoMagnetFlag
    MagnetFlagToggleBtn.BackgroundColor3 = State.AutoMagnetFlag and Colors.Green or Colors.Red
    refreshAllMenuLabels()
end)

local function createLanguageSelectorBlock(parentPage, orderIdx, isFarmRef)
    local cycleBtn = makeBtn(parentPage, UDim2.new(1, -6, 0, 30), nil, Colors.CardBright, "", 12, 33, 6, orderIdx)
    if isFarmRef then LangCycleBtnFarm = cycleBtn else LangCycleBtnSettings = cycleBtn end
    bindButton(cycleBtn, cycleGameLanguage)

    local row = Instance.new("Frame")
    row.LayoutOrder = orderIdx + 1
    row.Size = UDim2.new(1, -6, 0, 26)
    row.BackgroundTransparency = 1
    row.ZIndex = 33
    row.Parent = parentPage

    local labels = { "1. EN (English)", "2. UK (Українська)", "3. RU (Русский)" }
    for idx = 1, 3 do
        local b = makeBtn(row, UDim2.new(0.333, -3, 1, 0), UDim2.new((idx - 1) * 0.333, 1, 0, 0), (idx == State.LanguageIndex) and Colors.Green or Colors.Card, labels[idx], 11, 34, 5)
        LangDirectBtns[idx] = LangDirectBtns[idx] or {}
        table.insert(LangDirectBtns[idx], b)
        bindButton(b, function() applyGameLanguageNow(idx) end)
    end
end

createLanguageSelectorBlock(PageFarm, 7, true)

OnlyEggsToggle = makeBtn(PageFarm, UDim2.new(1, -6, 0, 30), nil, Colors.Card, "", 12, 33, 6, 9)
bindButton(OnlyEggsToggle, function()
    State.AutoEggs = not State.AutoEggs
    if State.AutoEggs then setupInstantEggAnimationBypass() end
    OnlyEggsToggle.BackgroundColor3 = State.AutoEggs and Colors.Green or Colors.Card
    refreshAllMenuLabels()
end)

InstantAnimToggle = makeBtn(PageFarm, UDim2.new(1, -6, 0, 30), nil, Colors.Green, "", 12, 33, 6, 10)
bindButton(InstantAnimToggle, function()
    State.InstantEggOpen = not State.InstantEggOpen
    if State.InstantEggOpen then setupInstantEggAnimationBypass() end
    InstantAnimToggle.BackgroundColor3 = State.InstantEggOpen and Colors.Green or Colors.Card
    refreshAllMenuLabels()
end)

EggCountInput = Instance.new("TextBox")
EggCountInput.LayoutOrder = 11
EggCountInput.Size = UDim2.new(1, -6, 0, 28)
EggCountInput.BackgroundColor3 = Colors.InputBg
EggCountInput.Text = "79"
EggCountInput.PlaceholderText = "Egg batch size (79, or 0 = Auto)"
EggCountInput.PlaceholderColor3 = Colors.SubText
EggCountInput.TextColor3 = Colors.Gold
EggCountInput.Font = Enum.Font.GothamBold
EggCountInput.TextSize = 12
EggCountInput.ClearTextOnFocus = false
EggCountInput.ZIndex = 33
EggCountInput.Parent = PageFarm
addCornerAndStroke(EggCountInput, 5, nil, nil)

local autoDetectedOnStart = detectPlayerMaxEggHatch()
if autoDetectedOnStart and autoDetectedOnStart > 1 then
    State.CustomEggCount = autoDetectedOnStart
    State.WorkingEggAmount = autoDetectedOnStart
    EggCountInput.Text = tostring(autoDetectedOnStart)
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
        if det and det > 1 then State.WorkingEggAmount = det end
    end
end))

local PosRow = Instance.new("Frame")
PosRow.LayoutOrder = 12
PosRow.Size = UDim2.new(1, -6, 0, 30)
PosRow.BackgroundTransparency = 1
PosRow.ZIndex = 33
PosRow.Parent = PageFarm

SaveEggPosBtn = makeBtn(PosRow, UDim2.new(0.5, -3, 1, 0), UDim2.new(0, 0, 0, 0), Colors.CardBright, "", 12, 34, 5)
ReturnToEggBtn = makeBtn(PosRow, UDim2.new(0.5, -3, 1, 0), UDim2.new(0.5, 3, 0, 0), Colors.Blue, "", 12, 34, 5)

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
        task.delay(1.2, refreshAllMenuLabels)
    end
end)
bindButton(ReturnToEggBtn, function() task.spawn(enterHalloweenEventAndGoToCoords) end)

MenuHousesTimersTitle = makeLabel(PageHouses, UDim2.new(1, -6, 0, 16), nil, "House Timers (10m after open):", Colors.Gold, Enum.Font.GothamBold, 11, 33, Enum.TextXAlignment.Left, 1)
buildEightHouseTimersGrid(PageHouses, 0, 2, MenuHousesTabCells, 33)

RunHousesNowBtn = makeBtn(PageHouses, UDim2.new(1, -6, 0, 34), nil, Colors.Accent, "", 12, 33, 6, 3)
bindButton(RunHousesNowBtn, function() task.spawn(function() visitReadyHousesAndReturn(true) end) end)

AutoBuyHouseToggle = makeBtn(PageHouses, UDim2.new(1, -6, 0, 32), nil, Colors.Green, "", 12, 33, 6, 4)
bindButton(AutoBuyHouseToggle, function()
    State.AutoBuyHouses = not State.AutoBuyHouses
    AutoBuyHouseToggle.BackgroundColor3 = State.AutoBuyHouses and Colors.Green or Colors.Red
    refreshAllMenuLabels()
end)

local RouteRow = Instance.new("Frame")
RouteRow.LayoutOrder = 5
RouteRow.Size = UDim2.new(1, -6, 0, 30)
RouteRow.BackgroundTransparency = 1
RouteRow.ZIndex = 33
RouteRow.Parent = PageHouses

AddPointBtn = makeBtn(RouteRow, UDim2.new(0.6, -3, 1, 0), UDim2.new(0, 0, 0, 0), Colors.CardBright, "", 11, 34, 5)
ClearPointsBtn = makeBtn(RouteRow, UDim2.new(0.4, -3, 1, 0), UDim2.new(0.6, 3, 0, 0), Colors.Card, "", 11, 34, 5)

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
LimitRow.LayoutOrder = 6
LimitRow.Size = UDim2.new(1, -6, 0, 28)
LimitRow.BackgroundTransparency = 1
LimitRow.ZIndex = 33
LimitRow.Parent = PageHouses

local LimitBtns = {}
local function makeLimitBtn(label, val, idx)
    local b = makeBtn(LimitRow, UDim2.new(0.2, -3, 1, 0), UDim2.new((idx - 1) * 0.2, 1, 0, 0), (State.MaxUnlockedHouses == val) and Colors.Accent or Colors.Card, label, 11, 34, 5)
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

AutoCapToggle = makeBtn(PageHouses, UDim2.new(1, -6, 0, 30), nil, Colors.Green, "", 12, 33, 6, 7)
bindButton(AutoCapToggle, function()
    State.AutoMinigame = not State.AutoMinigame
    AutoCapToggle.BackgroundColor3 = State.AutoMinigame and Colors.Green or Colors.Red
    refreshAllMenuLabels()
end)

BlackToggleBtnInSettings = makeBtn(PageSettings, UDim2.new(1, -6, 0, 32), nil, Colors.Green, "", 12, 33, 6, 1)
bindButton(BlackToggleBtnInSettings, function() setBlackScreenMode(not State.BlackScreenActive) end)

Render3DToggleBtn = makeBtn(PageSettings, UDim2.new(1, -6, 0, 30), nil, Colors.Green, "", 12, 33, 6, 2)
bindButton(Render3DToggleBtn, function() set3DRendering(not State.Rendering3DEnabled) end)

createLanguageSelectorBlock(PageSettings, 3, false)

JumpToggle = makeBtn(PageSettings, UDim2.new(1, -6, 0, 30), nil, Colors.Green, "", 12, 33, 6, 5)
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
addCornerAndStroke(CoordsInputBox, 5, nil, nil)

SetCoordsManualBtn = makeBtn(CoordsRow, UDim2.new(0.34, -3, 1, 0), UDim2.new(0.66, 3, 0, 0), Colors.Blue, "", 11, 34, 5)
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
HouseDelayInput.BackgroundColor3 = Colors.InputBg
HouseDelayInput.Text = "House delay: 4s"
HouseDelayInput.TextColor3 = Colors.Text
HouseDelayInput.Font = Enum.Font.Gotham
HouseDelayInput.TextSize = 11
HouseDelayInput.ClearTextOnFocus = true
HouseDelayInput.ZIndex = 34
HouseDelayInput.Parent = DelaysRow
addCornerAndStroke(HouseDelayInput, 5, nil, nil)

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
EggDelayInput.TextColor3 = Colors.Text
EggDelayInput.Font = Enum.Font.Gotham
EggDelayInput.TextSize = 11
EggDelayInput.ClearTextOnFocus = true
EggDelayInput.ZIndex = 34
EggDelayInput.Parent = DelaysRow
addCornerAndStroke(EggDelayInput, 5, nil, nil)

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

CopyLogsBtn = makeBtn(LogBtnsRow, UDim2.new(0.34, -3, 1, 0), UDim2.new(0, 0, 0, 0), Colors.Green, "", 12, 34, 5)
DiagEventBtn = makeBtn(LogBtnsRow, UDim2.new(0.34, -3, 1, 0), UDim2.new(0.34, 2, 0, 0), Colors.Blue, "", 12, 34, 5)
ClearLogsBtn = makeBtn(LogBtnsRow, UDim2.new(0.32, -3, 1, 0), UDim2.new(0.68, 4, 0, 0), Colors.Red, "", 12, 34, 5)

LogScrollFrame = Instance.new("ScrollingFrame")
LogScrollFrame.LayoutOrder = 2
LogScrollFrame.Size = UDim2.new(1, -6, 0, 210)
LogScrollFrame.BackgroundColor3 = Colors.InputBg
LogScrollFrame.BorderSizePixel = 0
LogScrollFrame.ScrollBarThickness = 4
LogScrollFrame.ScrollBarImageColor3 = Colors.Stroke
LogScrollFrame.ZIndex = 33
LogScrollFrame.Parent = PageLogs
addCornerAndStroke(LogScrollFrame, 5, nil, nil)

LogBoxLabel = makeLabel(LogScrollFrame, UDim2.new(1, -12, 0, 205), UDim2.new(0, 6, 0, 4), "", Colors.Text, Enum.Font.Code, 11, 34)
LogBoxLabel.TextYAlignment = Enum.TextYAlignment.Top
LogBoxLabel.TextWrapped = true
LogBoxLabel.AutomaticSize = Enum.AutomaticSize.Y

bindButton(CopyLogsBtn, function()
    if copyToClipboard(table.concat(State.Logs, "\n")) then
        CopyLogsBtn.Text = L().copiedLogs
        task.delay(1.2, refreshAllMenuLabels)
    end
end)
bindButton(DiagEventBtn, function() task.spawn(runEventDiagnostic) end)
bindButton(ClearLogsBtn, function() State.Logs = {}; if LogBoxLabel then LogBoxLabel.Text = "" end end)

local function cleanupAll()
    State.Running = false
    State.FullAutoFarm = false
    State.AutoEggs = false
    State.AutoMinigame = false
    State.AutoFarmCoins = false
    State.AutoMagnetFlag = false
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    pcall(function() if SafetyFloorPad then SafetyFloorPad:Destroy() end end)
    for _, c in ipairs(ActiveConnections) do pcall(function() c:Disconnect() end) end
    ActiveConnections = {}
    if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
end

env.HalloweenHubCleanup = cleanupAll
bindButton(CloseBtn, cleanupAll)

switchTab(PageFarm, TabFarmBtn)
env.HalloweenSavedCoords = nil
State.HouseCooldownMap = {}
State.LockedHouseInfo = {}
State.ConfirmedUnlockedHouses = {}
loadCoordsFromDisk()
updatePetsAndLollipopsInventory()
refreshAllMenuLabels()

task.spawn(function()
    pcall(enterHalloweenEventAndGoToCoords)
    State.HouseCooldownMap = {}
    State.LockedHouseInfo = {}
    State.ConfirmedUnlockedHouses = {}
    pcall(function()
        local refCF = State.SavedEggCFrame or DefaultSpawnCFrame
        scanAllHousesWithState(refCF.Position.Y, refCF.Position)
    end)
    State.NextAutoHouseCheckTime = tick() + 4
    State.FullAutoFarm = true
    refreshAllMenuLabels()
    if #findNearestEggCandidates(120) > 0 then
        setBlackScreenMode(true)
        MainFrame.Visible = false
        FloatBtn.Visible = true
        task.spawn(fastHatchOnce)
    else
        setBlackScreenMode(false)
        MainFrame.Visible = true
        FloatBtn.Visible = false
    end
    addLog("OK", "Ready.")
end)
