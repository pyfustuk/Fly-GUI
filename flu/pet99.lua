repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")

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
        if busy or (now - lastFire < 0.3) then return end
        busy = true
        lastFire = now
        task.spawn(function()
            pcall(callback)
            task.wait(0.08)
            busy = false
        end)
    end))
end

local DefaultSpawnCFrame = CFrame.new(7538.1, 15.7, 21965.5)

local State = {
    Running = true,
    FullAutoFarm = false,
    AutoEggs = false,
    InstantEggOpen = true,
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
    CurrentActionText = "Ініціалізація...",
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
local BlackToggleBtnInSettings = nil
local Render3DToggleBtn = nil
local FullAutoToggle = nil

local StatTimeValue = nil
local StatEggsValue = nil
local StatHousesValue = nil
local StatStatusValue = nil

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
    local str = string.format("%.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z)
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
        if enabled then
            Render3DToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            Render3DToggleBtn.Text = "🎮 3D Графіка (Рендер світу): УВІМК"
        else
            Render3DToggleBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
            Render3DToggleBtn.Text = "🎮 3D Графіка (Рендер світу): ВИМК"
        end
    end
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
        if active then
            BlackToggleBtnInSettings.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            BlackToggleBtnInSettings.Text = "🌑 Чорний Екран Статистики + 3D ВИМК: АКТИВНО"
        else
            BlackToggleBtnInSettings.BackgroundColor3 = Color3.fromRGB(36, 31, 52)
            BlackToggleBtnInSettings.Text = "🌑 Чорний Екран Статистики + 3D ВИМК: ВИМК"
        end
    end
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

local function pressKeyE()
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.03)
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
                    for _, cName in ipairs({"Halloween Candy", "Candy", "Coins", "Blood Moon", "Halloween Coins", "Event Coins", "Diamonds"}) do
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

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local alreadyInEventZone = false

    if hrp and (hrp.Position - targetCF.Position).Magnitude < 1000 then
        alreadyInEventZone = true
    elseif #findNearestEggCandidates(120) > 0 then
        alreadyInEventZone = true
    end

    if not alreadyInEventZone then
        setStatusText("🎃 Вхід у Halloween Івент...", nil)
        local things = getThingsFolder()
        local instancesFolder = things and things:FindFirstChild("Instances")
        local candidateIds = {}
        local validEnterPad = nil

        if instancesFolder then
            for _, instObj in ipairs(instancesFolder:GetChildren()) do
                local low = string.lower(instObj.Name)
                if string.find(low, "halloween") or string.find(low, "trick") or string.find(low, "spooky") or string.find(low, "blood") or string.find(low, "haunt") or string.find(low, "event") then
                    table.insert(candidateIds, instObj.Name)
                    local teleports = instObj:FindFirstChild("Teleports")
                    local enterP = teleports and teleports:FindFirstChild("Enter")
                    if enterP and enterP:IsA("BasePart") and enterP.Position.Y > 1 then
                        validEnterPad = enterP
                    end
                end
            end
        end

        for _, extraId in ipairs({"HalloweenEvent", "HalloweenWorld", "TrickOrTreat", "SpookyEvent", "Event"}) do
            table.insert(candidateIds, extraId)
        end

        pcall(function()
            local lib = ReplicatedStorage:FindFirstChild("Library")
            local client = lib and lib:FindFirstChild("Client")
            local instCmdsMod = client and client:FindFirstChild("InstancingCmds")
            if instCmdsMod then
                local ok, InstancingCmds = pcall(require, instCmdsMod)
                if ok and type(InstancingCmds) == "table" and type(InstancingCmds.Enter) == "function" then
                    for _, id in ipairs(candidateIds) do
                        local okE = pcall(InstancingCmds.Enter, id)
                        if okE then
                            task.wait(0.4)
                            if getActiveInstanceContainer() then break end
                        end
                    end
                end
            end
        end)

        if not getActiveInstanceContainer() and validEnterPad and hrp and (validEnterPad.Position - hrp.Position).Magnitude < 800 then
            teleportSafelyTo(validEnterPad.CFrame + Vector3.new(0, 3, 0))
            if firetouchinterest then
                pcall(function()
                    firetouchinterest(hrp, validEnterPad, 0)
                    firetouchinterest(hrp, validEnterPad, 1)
                end)
            end
            pressKeyE()
            task.wait(1.2)
        end

        for _, tryName in ipairs(candidateIds) do
            invokeRemote("Instancing_PlayerEnterInstance", tryName)
            invokeRemote("Teleports_RequestInstance", tryName)
        end

        local waitStart = tick()
        while (tick() - waitStart < 3.5) and State.Running do
            char = LocalPlayer.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            if getActiveInstanceContainer() or (hrp and (hrp.Position - targetCF.Position).Magnitude < 1000) then
                break
            end
            task.wait(0.25)
        end
    end

    setStatusText("📍 Телепорт на 7538.1, 15.7, 21965.5...", nil)
    teleportSafelyTo(targetCF)
    task.wait(0.3)
    setStatusText("🐣 На точці (7538.1, 15.7, 21965.5)! Фарм активний.", nil)
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
                    setStatusText(string.format("💰 Збираю монети на всі %d яєць (%d/3)...", targetAmt, State.LowCoinWaitCount), nil)
                    return
                end

                State.LowCoinWaitCount = 0
                local success = invokeEggBatch(r, State.CachedEggId, targetAmt)
                if success then
                    didHatch = true
                    setStatusText(string.format("🐣 Відкрито пачку: %d яєць (всього: %s)", targetAmt, formatNumber(State.TotalEggsHatched)), nil)
                    return
                else
                    collectAllOrbsAndLootbagsNow()
                    farmNearbyBreakables()
                    setStatusText(string.format("⏳ Чекаю монети або КД на всі %d яєць...", targetAmt), nil)
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
                            setStatusText(string.format("🐣 Відкрито: %s (%dx | всього %s)", tostring(best.attrId or idVal), targetAmt, formatNumber(State.TotalEggsHatched)), nil)
                            return
                        elseif State.CustomEggCount == 0 then
                            local okProbe, bestCount = probeMaxEggCountForOtherPlayers(r, idVal)
                            if okProbe then
                                State.CachedEggRemoteName = rName
                                State.CachedEggId = idVal
                                didHatch = true
                                setStatusText(string.format("🐣 Авто-макс: %s (%dx)", tostring(best.attrId or idVal), bestCount), nil)
                                return
                            end
                        end
                    end
                end
            end

            collectAllOrbsAndLootbagsNow()
            farmNearbyBreakables()
            setStatusText(string.format("⏳ Коплю монети на всі %d яєць...", targetAmt), nil)
        else
            setStatusText("🐣 Підійди до яйця і натисни 'Зберегти координати'", nil)
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
        if screen:IsA("ScreenGui") and screen.Enabled and screen.Name ~= "HalloweenEventGui" then
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

local function inspectDoorState(inst, pos)
    local isLocked = false
    local cooldownSecs = nil

    local function checkObj(rootObj)
        if not rootObj then return end
        if rootObj:GetAttribute("Locked") == true or rootObj:GetAttribute("Disabled") == true then
            isLocked = true
        end
        local cdAttr = tonumber(rootObj:GetAttribute("Cooldown"))
        if cdAttr and cdAttr > 0 then
            cooldownSecs = cdAttr
        end
        for _, d in ipairs(rootObj:GetDescendants()) do
            if d:IsA("TextLabel") and d.Visible then
                local raw = d.Text or ""
                local low = string.lower(raw)
                if string.find(low, "locked") or string.find(low, "unlock") then
                    isLocked = true
                end
                local parsed = parseCooldownFromText(raw)
                if parsed and parsed > 0 then
                    cooldownSecs = parsed
                end
            elseif d:IsA("ProximityPrompt") and not d.Enabled then
                if not cooldownSecs then
                    cooldownSecs = 60
                end
            end
        end
    end

    pcall(function()
        if inst then
            checkObj(inst)
            if inst.Parent and inst.Parent ~= Workspace then
                checkObj(inst.Parent)
            end
        elseif pos then
            for _, desc in ipairs(Workspace:GetDescendants()) do
                if (desc:IsA("BillboardGui") or desc:IsA("SurfaceGui")) and desc.Enabled then
                    local pPos = getObjectPosition(desc.Adornee or desc.Parent)
                    if pPos and (pPos - pos).Magnitude <= 16 then
                        checkObj(desc)
                    end
                end
            end
        end
    end)

    return isLocked, cooldownSecs
end

local function isBlockedByLockedZoneGate(fromPos, toPos)
    local blocked = false
    pcall(function()
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = {}
        if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
        params.FilterDescendantsInstances = ignore

        local startP = Vector3.new(fromPos.X, fromPos.Y + 3, fromPos.Z)
        local endP = Vector3.new(toPos.X, fromPos.Y + 3, toPos.Z)
        local result = Workspace:Raycast(startP, endP - startP, params)
        if result and result.Instance then
            local hit = result.Instance
            local full = string.lower(hit:GetFullName())
            if hit.CanCollide and (string.find(full, "gate") or string.find(full, "barrier") or string.find(full, "lock") or string.find(full, "forcefield") or string.find(full, "zonewall")) then
                blocked = true
            end
        end
    end)
    return blocked
end

local function findGroundDoorPosition(modelOrPart, playerGroundY)
    if modelOrPart:IsA("BasePart") then
        if math.abs(modelOrPart.Position.Y - playerGroundY) <= 12 then
            return Vector3.new(modelOrPart.Position.X, playerGroundY, modelOrPart.Position.Z), modelOrPart
        end
        return nil, nil
    end

    local bestPart = nil
    local bestScore = -999

    for _, d in ipairs(modelOrPart:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Parent and d.Parent:IsA("BasePart") then
            local p = d.Parent
            if math.abs(p.Position.Y - playerGroundY) <= 14 then
                return Vector3.new(p.Position.X, playerGroundY, p.Position.Z), p
            end
        elseif d:IsA("TouchTransmitter") and d.Parent and d.Parent:IsA("BasePart") then
            local p = d.Parent
            if math.abs(p.Position.Y - playerGroundY) <= 12 then
                return Vector3.new(p.Position.X, playerGroundY, p.Position.Z), p
            end
        elseif d:IsA("BasePart") then
            local n = string.lower(d.Name)
            local yDiff = math.abs(d.Position.Y - playerGroundY)
            if yDiff <= 12 then
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
        return Vector3.new(bestPart.Position.X + offset.X, playerGroundY, bestPart.Position.Z + offset.Z), bestPart
    end

    return nil, nil
end

local function scanAllUnlockedHouses(playerGroundY, originPos)
    local houses = {}
    local seenPositions = {}

    local function addUniqueHouse(name, pos, inst, idVal)
        if not pos then return end
        local groundPos = Vector3.new(pos.X, playerGroundY, pos.Z)
        for _, existing in ipairs(seenPositions) do
            if (existing - groundPos).Magnitude < 14 then
                return
            end
        end
        local key = string.format("%d_%d", math.floor(groundPos.X / 10), math.floor(groundPos.Z / 10))
        local isLocked, liveCd = inspectDoorState(inst, groundPos)
        if isLocked then return end

        local now = tick()
        if liveCd and liveCd > 0 then
            State.HouseCooldownMap[key] = now + liveCd
        end
        local readyAt = State.HouseCooldownMap[key] or 0
        local remCd = math.max(0, readyAt - now)

        table.insert(seenPositions, groundPos)
        table.insert(houses, {
            key = key,
            name = name or ("Дім #" .. (#houses + 1)),
            pos = groundPos,
            instance = inst,
            id = idVal or (inst and inst.Name) or tostring(#houses + 1),
            remainingCd = remCd,
            isReady = (remCd <= 0)
        })
    end

    if #State.CustomHousePoints > 0 then
        for idx, cf in ipairs(State.CustomHousePoints) do
            addUniqueHouse("Дім #" .. idx, cf.Position, nil, idx)
        end
        return houses
    end

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
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local pPos = getObjectPosition(desc.Parent)
                if pPos and math.abs(pPos.Y - playerGroundY) <= 14 then
                    local actionTxt = string.lower((desc.ActionText or "") .. " " .. (desc.ObjectText or "") .. " " .. desc:GetFullName())
                    if not string.find(actionTxt, "egg") and not string.find(actionTxt, "leave") and not string.find(actionTxt, "exit") and not string.find(actionTxt, "teleport") and not string.find(actionTxt, "upgrade") then
                        if not isBlockedByLockedZoneGate(originPos, pPos) then
                            addUniqueHouse(desc.ObjectText ~= "" and desc.ObjectText or desc.Parent.Name, pPos, desc.Parent, desc.Parent.Name)
                        end
                    end
                end
            end
        end
        if #houses > 0 then break end
    end

    if #houses == 0 then
        for _, root in ipairs(searchRoots) do
            for _, folder in ipairs(root:GetDescendants()) do
                local fn = string.lower(folder.Name)
                if (folder:IsA("Folder") or folder:IsA("Model")) and (fn == "houses" or fn == "trickortreat" or fn == "spookyhouses" or fn == "doors") then
                    for _, hModel in ipairs(folder:GetChildren()) do
                        local doorPos, doorPart = findGroundDoorPosition(hModel, playerGroundY)
                        if doorPos and not isBlockedByLockedZoneGate(originPos, doorPos) then
                            addUniqueHouse(hModel.Name, doorPos, doorPart or hModel, hModel.Name)
                        end
                    end
                end
            end
            if #houses > 0 then break end
        end
    end

    table.sort(houses, function(a, b)
        local na = tonumber(string.match(tostring(a.id), "%d+"))
        local nb = tonumber(string.match(tostring(b.id), "%d+"))
        if na and nb and na ~= nb then
            return na < nb
        end
        return (a.pos - originPos).Magnitude < (b.pos - originPos).Magnitude
    end)

    if State.MaxUnlockedHouses > 0 and #houses > State.MaxUnlockedHouses then
        local limited = {}
        for i = 1, State.MaxUnlockedHouses do
            table.insert(limited, houses[i])
        end
        return limited
    end

    return houses
end

local function triggerDoorFast(pos, inst)
    pressKeyE()

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hrp and firetouchinterest and inst then
        pcall(function()
            if inst:IsA("BasePart") then
                firetouchinterest(hrp, inst, 0)
                firetouchinterest(hrp, inst, 1)
            elseif inst:IsA("Model") then
                for _, p in ipairs(inst:GetDescendants()) do
                    if p:IsA("BasePart") and math.abs(p.Position.Y - pos.Y) <= 10 then
                        firetouchinterest(hrp, p, 0)
                        firetouchinterest(hrp, p, 1)
                    end
                end
            end
        end)
    end

    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            local pPos = getObjectPosition(desc.Parent)
            if pPos and (pPos - pos).Magnitude <= 16 then
                pcall(function()
                    if fireproximityprompt then
                        fireproximityprompt(desc)
                    end
                end)
            end
        end
    end
end

local function fireHouseRemotes(house)
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
    local instName = activeInst and activeInst.Name or "HalloweenEvent"
    local numId = tonumber(string.match(tostring(house.id), "%d+")) or house.id

    task.spawn(function()
        local actions = { "Knock", "TrickOrTreat", "ClaimHouse", "OpenDoor", "Interact" }
        for _, act in ipairs(actions) do
            invokeRemote("Instancing_FireCustomFromClient", instName, act, numId)
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

    if not State.SavedEggCFrame then
        local cands = findNearestEggCandidates(75)
        if #cands > 0 then
            local eggPos = cands[1].pos
            State.SavedEggCFrame = CFrame.new(eggPos.X, hrp.Position.Y, eggPos.Z + 6)
            saveCoordsToDisk(State.SavedEggCFrame)
        else
            State.SavedEggCFrame = hrp.CFrame
            saveCoordsToDisk(State.SavedEggCFrame)
        end
    end

    local returnCF = State.SavedEggCFrame
    local groundY = returnCF.Position.Y
    local allHouses = scanAllUnlockedHouses(groundY, returnCF.Position)

    if #allHouses == 0 then
        setStatusText(nil, "🏠 Додай свої відкриті двері кнопкою '+ Додати дім'")
        return
    end

    local readyHouses = {}
    local minCd = 999999
    for _, h in ipairs(allHouses) do
        if forceAll or h.isReady then
            table.insert(readyHouses, h)
        else
            if h.remainingCd < minCd then
                minCd = h.remainingCd
            end
        end
    end

    if #readyHouses == 0 then
        local mins = math.floor(minCd / 60)
        local secs = math.floor(minCd % 60)
        setStatusText(nil, string.format("🏠 Домики на КД (%02d:%02d) | Відкрито: %d", mins, secs, State.TotalHousesOpened))
        return
    end

    State.IsVisitingHouses = true
    local stepWait = math.max(1.0, tonumber(State.HouseStepDelay) or 4.0)

    local ok, err = pcall(function()
        for i, house in ipairs(readyHouses) do
            if not State.Running then break end
            char = LocalPlayer.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then break end

            setStatusText(nil, string.format("🏠 Дім %d/%d (%s) — чекаю %.0fс...", i, #readyHouses, tostring(house.name), stepWait))

            local doorGroundCF = CFrame.new(house.pos.X, groundY + 0.5, house.pos.Z)
            teleportSafelyTo(doorGroundCF)

            local waitStarted = tick()
            local triggeredSecondTime = false
            triggerDoorFast(doorGroundCF.Position, house.instance)
            fireHouseRemotes(house)

            while (tick() - waitStarted < stepWait) and State.Running do
                local elapsed = tick() - waitStarted
                if elapsed >= (stepWait * 0.45) and not triggeredSecondTime then
                    triggeredSecondTime = true
                    triggerDoorFast(doorGroundCF.Position, house.instance)
                    pressKeyE()
                end
                isMinigameActiveOnScreen()
                collectAllOrbsAndLootbagsNow()
                task.wait(0.15)
            end

            State.TotalHousesOpened = State.TotalHousesOpened + 1
            local _, newLiveCd = inspectDoorState(house.instance, house.pos)
            State.HouseCooldownMap[house.key] = tick() + (newLiveCd and newLiveCd > 0 and newLiveCd or State.HouseCooldownDefault)
        end
    end)

    if not ok then
        addLog("ERR", "Помилка домиків: " .. tostring(err))
    end

    if returnCF and State.Running then
        teleportSafelyTo(returnCF)
        setStatusText(nil, string.format("🏠 Повернувся на координати! Чекаю %.0fс...", stepWait))
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
            task.wait(0.3)
        else
            task.wait(0.5)
        end
    end
end)

local function runEventDiagnostic()
    addLog("INFO", "=== СКАНЕР ===")
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position or Vector3.zero
    local batchAmt = getTargetEggBatchSize()
    addLog("INFO", string.format("Позиція: %.1f, %.1f, %.1f | Пачка яєць: %d", myPos.X, myPos.Y, myPos.Z, batchAmt))
    addLog("INFO", string.format("Статистика: Яєць=%d | Домиків=%d | Час=%s", State.TotalEggsHatched, State.TotalHousesOpened, formatDuration(tick() - State.StartTime)))

    local currSnap = getAllPlayerCurrencies()
    for k, v in pairs(currSnap) do
        addLog("INFO", string.format("  Валюта [%s] = %s", tostring(k), tostring(v)))
    end

    local cands = findNearestEggCandidates(75)
    addLog("INFO", "Яєць поруч (" .. #cands .. "):")
    for i, c in ipairs(cands) do
        addLog("INFO", string.format("  [%d] uid='%s' id='%s' dist=%.1f", i, tostring(c.uid), tostring(c.attrId), c.dist))
    end

    local houses = scanAllUnlockedHouses(myPos.Y, myPos)
    addLog("INFO", "Відкритих домиків (" .. #houses .. "):")
    for i, h in ipairs(houses) do
        addLog("INFO", string.format("  [%d] %s | Готовий=%s | КД=%.0fс", i, tostring(h.name), tostring(h.isReady), h.remainingCd))
    end

    addLog("OK", "Готово! Натисни 'Копіювати'.")
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
    Bg = Color3.fromRGB(14, 12, 20),
    Header = Color3.fromRGB(24, 18, 36),
    Card = Color3.fromRGB(22, 19, 32),
    CardBright = Color3.fromRGB(30, 25, 44),
    Stroke = Color3.fromRGB(130, 75, 220),
    Orange = Color3.fromRGB(255, 130, 35),
    Green = Color3.fromRGB(46, 204, 113),
    Red = Color3.fromRGB(231, 76, 60),
    Blue = Color3.fromRGB(52, 152, 219),
    Purple = Color3.fromRGB(155, 89, 182),
    Text = Color3.fromRGB(248, 245, 255),
    SubText = Color3.fromRGB(175, 168, 200),
    InputBg = Color3.fromRGB(10, 8, 15)
}

BlackOverlayFrame = Instance.new("Frame")
BlackOverlayFrame.Name = "BlackScreenOverlay"
BlackOverlayFrame.Size = UDim2.new(1, 0, 1, 0)
BlackOverlayFrame.Position = UDim2.new(0, 0, 0, 0)
BlackOverlayFrame.BackgroundColor3 = Color3.fromRGB(7, 6, 11)
BlackOverlayFrame.BorderSizePixel = 0
BlackOverlayFrame.Active = true
BlackOverlayFrame.Visible = false
BlackOverlayFrame.ZIndex = 10
BlackOverlayFrame.Parent = ScreenGui

local DashCard = Instance.new("Frame")
DashCard.Size = UDim2.new(0, 450, 0, 310)
DashCard.Position = UDim2.new(0.5, -225, 0.5, -155)
DashCard.BackgroundColor3 = Color3.fromRGB(15, 13, 24)
DashCard.BorderSizePixel = 0
DashCard.ZIndex = 11
DashCard.Parent = BlackOverlayFrame
Instance.new("UICorner", DashCard).CornerRadius = UDim.new(0, 14)
local DashStroke = Instance.new("UIStroke", DashCard)
DashStroke.Color = Colors.Orange
DashStroke.Thickness = 2

local DashTitle = Instance.new("TextLabel")
DashTitle.Size = UDim2.new(1, -24, 0, 32)
DashTitle.Position = UDim2.new(0, 12, 0, 10)
DashTitle.BackgroundTransparency = 1
DashTitle.Text = "🎃 HALLOWEEN AFK FARM  •  3D ВИМКНЕНО"
DashTitle.TextColor3 = Colors.Orange
DashTitle.Font = Enum.Font.GothamBold
DashTitle.TextSize = 16
DashTitle.ZIndex = 12
DashTitle.Parent = DashCard

local DashSub = Instance.new("TextLabel")
DashSub.Size = UDim2.new(1, -24, 0, 18)
DashSub.Position = UDim2.new(0, 12, 0, 38)
DashSub.BackgroundTransparency = 1
DashSub.Text = "Економія GPU/Батареї активна — гра фармить у фоні"
DashSub.TextColor3 = Colors.SubText
DashSub.Font = Enum.Font.Gotham
DashSub.TextSize = 12
DashSub.ZIndex = 12
DashSub.Parent = DashCard

local function createStatBox(parent, title, initVal, posScaleX, posY, widthScale, accentColor)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(widthScale, -16, 0, 68)
    box.Position = UDim2.new(posScaleX, 12, 0, posY)
    box.BackgroundColor3 = Colors.CardBright
    box.BorderSizePixel = 0
    box.ZIndex = 12
    box.Parent = parent
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", box)
    st.Color = accentColor
    st.Thickness = 1.5

    local lblTitle = Instance.new("TextLabel")
    lblTitle.Size = UDim2.new(1, -16, 0, 20)
    lblTitle.Position = UDim2.new(0, 8, 0, 6)
    lblTitle.BackgroundTransparency = 1
    lblTitle.Text = title
    lblTitle.TextColor3 = Colors.SubText
    lblTitle.Font = Enum.Font.GothamBold
    lblTitle.TextSize = 11
    lblTitle.TextXAlignment = Enum.TextXAlignment.Left
    lblTitle.ZIndex = 13
    lblTitle.Parent = box

    local lblVal = Instance.new("TextLabel")
    lblVal.Size = UDim2.new(1, -16, 0, 34)
    lblVal.Position = UDim2.new(0, 8, 0, 26)
    lblVal.BackgroundTransparency = 1
    lblVal.Text = initVal
    lblVal.TextColor3 = Colors.Text
    lblVal.Font = Enum.Font.GothamBold
    lblVal.TextSize = 18
    lblVal.TextXAlignment = Enum.TextXAlignment.Left
    lblVal.ZIndex = 13
    lblVal.Parent = box

    return lblVal
end

StatTimeValue = createStatBox(DashCard, "⏱️ ЧАС ФАРМУ", "00:00:00", 0, 64, 0.34, Colors.Blue)
StatEggsValue = createStatBox(DashCard, "🐣 ВІДКРИТО ЯЄЦЬ", "0 (0 пачок)", 0.33, 64, 0.34, Colors.Orange)
StatHousesValue = createStatBox(DashCard, "🏠 ВІДКРИТО ДОМИКІВ", "0", 0.66, 64, 0.34, Colors.Green)

local StatusBanner = Instance.new("Frame")
StatusBanner.Size = UDim2.new(1, -24, 0, 56)
StatusBanner.Position = UDim2.new(0, 12, 0, 142)
StatusBanner.BackgroundColor3 = Colors.InputBg
StatusBanner.BorderSizePixel = 0
StatusBanner.ZIndex = 12
StatusBanner.Parent = DashCard
Instance.new("UICorner", StatusBanner).CornerRadius = UDim.new(0, 8)
local BannerStroke = Instance.new("UIStroke", StatusBanner)
BannerStroke.Color = Colors.Stroke
BannerStroke.Thickness = 1

StatStatusValue = Instance.new("TextLabel")
StatStatusValue.Size = UDim2.new(1, -16, 1, -8)
StatStatusValue.Position = UDim2.new(0, 8, 0, 4)
StatStatusValue.BackgroundTransparency = 1
StatStatusValue.Text = "🐣 Завантаження...\n🏠 Очікування..."
StatStatusValue.TextColor3 = Colors.Text
StatStatusValue.Font = Enum.Font.GothamBold
StatStatusValue.TextSize = 12
StatStatusValue.TextWrapped = true
StatStatusValue.ZIndex = 13
StatStatusValue.Parent = StatusBanner

local ExitBlackBtn = Instance.new("TextButton")
ExitBlackBtn.Size = UDim2.new(0.54, -14, 0, 42)
ExitBlackBtn.Position = UDim2.new(0, 12, 0, 210)
ExitBlackBtn.BackgroundColor3 = Colors.Green
ExitBlackBtn.Text = "👁️ ВИЙТИ І УВІМКНУТИ 3D"
ExitBlackBtn.TextColor3 = Color3.new(1, 1, 1)
ExitBlackBtn.Font = Enum.Font.GothamBold
ExitBlackBtn.TextSize = 13
ExitBlackBtn.ZIndex = 13
ExitBlackBtn.Parent = DashCard
Instance.new("UICorner", ExitBlackBtn).CornerRadius = UDim.new(0, 8)

local OpenMenuOnBlackBtn = Instance.new("TextButton")
OpenMenuOnBlackBtn.Size = UDim2.new(0.46, -14, 0, 42)
OpenMenuOnBlackBtn.Position = UDim2.new(0.54, 2, 0, 210)
OpenMenuOnBlackBtn.BackgroundColor3 = Colors.Purple
OpenMenuOnBlackBtn.Text = "⚙️ ВІДКРИТИ МЕНЮ"
OpenMenuOnBlackBtn.TextColor3 = Color3.new(1, 1, 1)
OpenMenuOnBlackBtn.Font = Enum.Font.GothamBold
OpenMenuOnBlackBtn.TextSize = 13
OpenMenuOnBlackBtn.ZIndex = 13
OpenMenuOnBlackBtn.Parent = DashCard
Instance.new("UICorner", OpenMenuOnBlackBtn).CornerRadius = UDim.new(0, 8)

local TeleportNowOnBlackBtn = Instance.new("TextButton")
TeleportNowOnBlackBtn.Size = UDim2.new(1, -24, 0, 36)
TeleportNowOnBlackBtn.Position = UDim2.new(0, 12, 0, 260)
TeleportNowOnBlackBtn.BackgroundColor3 = Colors.CardBright
TeleportNowOnBlackBtn.Text = "🚀 Телепорт в Івент -> На збережені координати"
TeleportNowOnBlackBtn.TextColor3 = Colors.Orange
TeleportNowOnBlackBtn.Font = Enum.Font.GothamBold
TeleportNowOnBlackBtn.TextSize = 12
TeleportNowOnBlackBtn.ZIndex = 13
TeleportNowOnBlackBtn.Parent = DashCard
Instance.new("UICorner", TeleportNowOnBlackBtn).CornerRadius = UDim.new(0, 8)

task.spawn(function()
    while State.Running do
        if StatTimeValue then
            StatTimeValue.Text = formatDuration(tick() - State.StartTime)
        end
        if StatEggsValue then
            StatEggsValue.Text = string.format("%s (%d)", formatNumber(State.TotalEggsHatches or State.TotalEggsHatched), State.TotalEggBatches)
        end
        if StatHousesValue then
            StatHousesValue.Text = formatNumber(State.TotalHousesOpened)
        end
        task.wait(0.5)
    end
end)

local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "FloatToggle"
FloatBtn.Size = UDim2.new(0, 52, 0, 52)
FloatBtn.Position = UDim2.new(0, 15, 0.5, -26)
FloatBtn.BackgroundColor3 = Colors.Orange
FloatBtn.Text = "🎃"
FloatBtn.TextSize = 25
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextColor3 = Color3.new(1, 1, 1)
FloatBtn.Visible = false
FloatBtn.ZIndex = 60
FloatBtn.Parent = ScreenGui
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0)
local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Color = Color3.new(1, 1, 1)
FloatStroke.Thickness = 2

MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 460, 0, 380)
MainFrame.Position = UDim2.new(0.5, -230, 0.5, -190)
MainFrame.BackgroundColor3 = Colors.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ZIndex = 30
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Colors.Stroke
MainStroke.Thickness = 2

bindButton(ExitBlackBtn, function()
    setBlackScreenMode(false)
    MainFrame.Visible = true
    FloatBtn.Visible = false
end)

bindButton(OpenMenuOnBlackBtn, function()
    MainFrame.Visible = not MainFrame.Visible
    if MainFrame.Visible then
        FloatBtn.Visible = false
    end
end)

bindButton(TeleportNowOnBlackBtn, function()
    task.spawn(enterHalloweenEventAndGoToCoords)
end)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = Colors.Header
Header.BorderSizePixel = 0
Header.ZIndex = 31
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -150, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🎃 Halloween Hub"
TitleLabel.TextColor3 = Colors.Orange
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 32
TitleLabel.Parent = Header

local QuickBlackBtn = Instance.new("TextButton")
QuickBlackBtn.Size = UDim2.new(0, 68, 0, 26)
QuickBlackBtn.Position = UDim2.new(1, -140, 0, 6)
QuickBlackBtn.BackgroundColor3 = Colors.Purple
QuickBlackBtn.Text = "🌑 3D Екран"
QuickBlackBtn.TextColor3 = Color3.new(1, 1, 1)
QuickBlackBtn.Font = Enum.Font.GothamBold
QuickBlackBtn.TextSize = 11
QuickBlackBtn.ZIndex = 32
QuickBlackBtn.Parent = Header
Instance.new("UICorner", QuickBlackBtn).CornerRadius = UDim.new(0, 6)

bindButton(QuickBlackBtn, function()
    setBlackScreenMode(not State.BlackScreenActive)
end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 26)
MinBtn.Position = UDim2.new(1, -68, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(48, 42, 68)
MinBtn.Text = "_"
MinBtn.TextColor3 = Colors.Text
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.ZIndex = 32
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0, 6)
CloseBtn.BackgroundColor3 = Colors.Red
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.ZIndex = 32
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local function makeDraggable(dragHandle, targetFrame, onTapCallback)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local movedDist = 0

    trackConn(dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            movedDist = 0
        end
    end))

    trackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            movedDist = delta.Magnitude
            if movedDist > 6 then
                targetFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end))

    trackConn(UserInputService.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if onTapCallback and movedDist <= 10 then
                task.spawn(onTapCallback)
            end
        end
    end))
end

makeDraggable(Header, MainFrame, nil)
makeDraggable(FloatBtn, FloatBtn, function()
    FloatBtn.Visible = false
    MainFrame.Visible = true
end)

bindButton(MinBtn, function()
    MainFrame.Visible = false
    FloatBtn.Visible = true
end)

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 30)
TabBar.Position = UDim2.new(0, 8, 0, 42)
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
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local TabFarmBtn = createTabButton("⚡ Фарм", 0, 0.25)
local TabHousesBtn = createTabButton("🏠 Домики", 0.25, 0.25)
local TabSettingsBtn = createTabButton("⚙️ Налашт.", 0.50, 0.25)
local TabLogsBtn = createTabButton("📋 Лог", 0.75, 0.25)

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -16, 1, -80)
ContentArea.Position = UDim2.new(0, 8, 0, 76)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex = 31
ContentArea.Parent = MainFrame

local function createPage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 5
    page.ScrollBarImageColor3 = Colors.Orange
    page.Visible = false
    page.ZIndex = 32
    page.Parent = ContentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
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
        if btn == activeBtn then
            btn.BackgroundColor3 = Colors.Orange
            btn.TextColor3 = Color3.new(1, 1, 1)
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
FullAutoToggle.Size = UDim2.new(1, -6, 0, 38)
FullAutoToggle.BackgroundColor3 = Colors.Green
FullAutoToggle.Text = "⚡ АВТО: ЯЙЦЯ + МОНЕТИ + ДОМИКИ: УВІМК"
FullAutoToggle.TextColor3 = Color3.new(1, 1, 1)
FullAutoToggle.Font = Enum.Font.GothamBold
FullAutoToggle.TextSize = 13
FullAutoToggle.ZIndex = 33
FullAutoToggle.Parent = PageFarm
Instance.new("UICorner", FullAutoToggle).CornerRadius = UDim.new(0, 8)

EggStatusLabel = Instance.new("TextLabel")
EggStatusLabel.LayoutOrder = 2
EggStatusLabel.Size = UDim2.new(1, -6, 0, 18)
EggStatusLabel.BackgroundTransparency = 1
EggStatusLabel.Text = "🐣 Завантаження..."
EggStatusLabel.TextColor3 = Colors.Orange
EggStatusLabel.Font = Enum.Font.GothamBold
EggStatusLabel.TextSize = 12
EggStatusLabel.ZIndex = 33
EggStatusLabel.Parent = PageFarm

HouseStatusLabel = Instance.new("TextLabel")
HouseStatusLabel.LayoutOrder = 3
HouseStatusLabel.Size = UDim2.new(1, -6, 0, 18)
HouseStatusLabel.BackgroundTransparency = 1
HouseStatusLabel.Text = "🏠 Домики: очікування (4с на дім)"
HouseStatusLabel.TextColor3 = Colors.Green
HouseStatusLabel.Font = Enum.Font.GothamBold
HouseStatusLabel.TextSize = 12
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
        FullAutoToggle.Text = "⚡ АВТО: ЯЙЦЯ + МОНЕТИ + ДОМИКИ: УВІМК"
    else
        FullAutoToggle.BackgroundColor3 = Colors.Red
        FullAutoToggle.Text = "⚡ АВТО: ЯЙЦЯ + МОНЕТИ + ДОМИКИ: ВИМК"
    end
end)

local OnlyEggsToggle = Instance.new("TextButton")
OnlyEggsToggle.LayoutOrder = 4
OnlyEggsToggle.Size = UDim2.new(1, -6, 0, 32)
OnlyEggsToggle.BackgroundColor3 = Colors.Card
OnlyEggsToggle.Text = "🐣 Тільки Швидкі Яйця (без домиків): ВИМК"
OnlyEggsToggle.TextColor3 = Colors.Text
OnlyEggsToggle.Font = Enum.Font.GothamBold
OnlyEggsToggle.TextSize = 12
OnlyEggsToggle.ZIndex = 33
OnlyEggsToggle.Parent = PageFarm
Instance.new("UICorner", OnlyEggsToggle).CornerRadius = UDim.new(0, 7)

bindButton(OnlyEggsToggle, function()
    State.AutoEggs = not State.AutoEggs
    if State.AutoEggs then
        setupInstantEggAnimationBypass()
        OnlyEggsToggle.BackgroundColor3 = Colors.Green
        OnlyEggsToggle.Text = "🐣 Тільки Швидкі Яйця (без домиків): УВІМК"
    else
        OnlyEggsToggle.BackgroundColor3 = Colors.Card
        OnlyEggsToggle.Text = "🐣 Тільки Швидкі Яйця (без домиків): ВИМК"
    end
end)

local InstantAnimToggle = Instance.new("TextButton")
InstantAnimToggle.LayoutOrder = 5
InstantAnimToggle.Size = UDim2.new(1, -6, 0, 32)
InstantAnimToggle.BackgroundColor3 = Colors.Green
InstantAnimToggle.Text = "⚡ Миттєве відкриття (без тук-тук і лагів): УВІМК"
InstantAnimToggle.TextColor3 = Color3.new(1, 1, 1)
InstantAnimToggle.Font = Enum.Font.GothamBold
InstantAnimToggle.TextSize = 12
InstantAnimToggle.ZIndex = 33
InstantAnimToggle.Parent = PageFarm
Instance.new("UICorner", InstantAnimToggle).CornerRadius = UDim.new(0, 7)

bindButton(InstantAnimToggle, function()
    State.InstantEggOpen = not State.InstantEggOpen
    if State.InstantEggOpen then
        setupInstantEggAnimationBypass()
        InstantAnimToggle.BackgroundColor3 = Colors.Green
        InstantAnimToggle.Text = "⚡ Миттєве відкриття (без тук-тук і лагів): УВІМК"
    else
        InstantAnimToggle.BackgroundColor3 = Colors.Card
        InstantAnimToggle.Text = "⚡ Миттєве відкриття (без тук-тук і лагів): ВИМК"
    end
end)

EggCountInput = Instance.new("TextBox")
EggCountInput.LayoutOrder = 6
EggCountInput.Size = UDim2.new(1, -6, 0, 30)
EggCountInput.BackgroundColor3 = Colors.InputBg
EggCountInput.Text = "79"
EggCountInput.PlaceholderText = "Кількість яєць (79, або 0 = Авто для інших)"
EggCountInput.PlaceholderColor3 = Colors.SubText
EggCountInput.TextColor3 = Colors.Orange
EggCountInput.Font = Enum.Font.GothamBold
EggCountInput.TextSize = 12
EggCountInput.ClearTextOnFocus = false
EggCountInput.ZIndex = 33
EggCountInput.Parent = PageFarm
Instance.new("UICorner", EggCountInput).CornerRadius = UDim.new(0, 6)

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
PosRow.LayoutOrder = 7
PosRow.Size = UDim2.new(1, -6, 0, 34)
PosRow.BackgroundTransparency = 1
PosRow.ZIndex = 33
PosRow.Parent = PageFarm

local SaveEggPosBtn = Instance.new("TextButton")
SaveEggPosBtn.Size = UDim2.new(0.52, -3, 1, 0)
SaveEggPosBtn.Position = UDim2.new(0, 0, 0, 0)
SaveEggPosBtn.BackgroundColor3 = Colors.Blue
SaveEggPosBtn.Text = "📍 Зберегти ці координати"
SaveEggPosBtn.TextColor3 = Color3.new(1, 1, 1)
SaveEggPosBtn.Font = Enum.Font.GothamBold
SaveEggPosBtn.TextSize = 12
SaveEggPosBtn.ZIndex = 34
SaveEggPosBtn.Parent = PosRow
Instance.new("UICorner", SaveEggPosBtn).CornerRadius = UDim.new(0, 6)

local ReturnToEggBtn = Instance.new("TextButton")
ReturnToEggBtn.Size = UDim2.new(0.48, -3, 1, 0)
ReturnToEggBtn.Position = UDim2.new(0.52, 3, 0, 0)
ReturnToEggBtn.BackgroundColor3 = Colors.Orange
ReturnToEggBtn.Text = "🚀 В Івент і на Координати"
ReturnToEggBtn.TextColor3 = Color3.new(1, 1, 1)
ReturnToEggBtn.Font = Enum.Font.GothamBold
ReturnToEggBtn.TextSize = 12
ReturnToEggBtn.ZIndex = 34
ReturnToEggBtn.Parent = PosRow
Instance.new("UICorner", ReturnToEggBtn).CornerRadius = UDim.new(0, 6)

bindButton(SaveEggPosBtn, function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        State.SavedEggCFrame = hrp.CFrame
        State.CachedEggId = nil
        State.CachedEggRemoteName = nil
        State.LearnedBatchCost = 0
        saveCoordsToDisk(hrp.CFrame)
        SaveEggPosBtn.Text = "✅ Координати збережено!"
        task.delay(1.5, function()
            if SaveEggPosBtn then SaveEggPosBtn.Text = "📍 Зберегти ці координати" end
        end)
    end
end)

bindButton(ReturnToEggBtn, function()
    task.spawn(enterHalloweenEventAndGoToCoords)
end)

local RunHousesNowBtn = Instance.new("TextButton")
RunHousesNowBtn.LayoutOrder = 1
RunHousesNowBtn.Size = UDim2.new(1, -6, 0, 38)
RunHousesNowBtn.BackgroundColor3 = Colors.Orange
RunHousesNowBtn.Text = "⚡ Обійти домики [E] (по 4 сек) і назад"
RunHousesNowBtn.TextColor3 = Color3.new(1, 1, 1)
RunHousesNowBtn.Font = Enum.Font.GothamBold
RunHousesNowBtn.TextSize = 13
RunHousesNowBtn.ZIndex = 33
RunHousesNowBtn.Parent = PageHouses
Instance.new("UICorner", RunHousesNowBtn).CornerRadius = UDim.new(0, 7)

bindButton(RunHousesNowBtn, function()
    State.HouseCooldownMap = {}
    task.spawn(function()
        visitReadyHousesAndReturn(true)
    end)
end)

local RouteRow = Instance.new("Frame")
RouteRow.LayoutOrder = 2
RouteRow.Size = UDim2.new(1, -6, 0, 34)
RouteRow.BackgroundTransparency = 1
RouteRow.ZIndex = 33
RouteRow.Parent = PageHouses

local AddPointBtn = Instance.new("TextButton")
AddPointBtn.Size = UDim2.new(0.62, -3, 1, 0)
AddPointBtn.Position = UDim2.new(0, 0, 0, 0)
AddPointBtn.BackgroundColor3 = Colors.Blue
AddPointBtn.Text = "➕ Додати відкритий дім (0)"
AddPointBtn.TextColor3 = Color3.new(1, 1, 1)
AddPointBtn.Font = Enum.Font.GothamBold
AddPointBtn.TextSize = 12
AddPointBtn.ZIndex = 34
AddPointBtn.Parent = RouteRow
Instance.new("UICorner", AddPointBtn).CornerRadius = UDim.new(0, 6)

local ClearPointsBtn = Instance.new("TextButton")
ClearPointsBtn.Size = UDim2.new(0.38, -3, 1, 0)
ClearPointsBtn.Position = UDim2.new(0.62, 3, 0, 0)
ClearPointsBtn.BackgroundColor3 = Colors.Card
ClearPointsBtn.Text = "🗑️ Скинути"
ClearPointsBtn.TextColor3 = Colors.Text
ClearPointsBtn.Font = Enum.Font.GothamBold
ClearPointsBtn.TextSize = 12
ClearPointsBtn.ZIndex = 34
ClearPointsBtn.Parent = RouteRow
Instance.new("UICorner", ClearPointsBtn).CornerRadius = UDim.new(0, 6)

bindButton(AddPointBtn, function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        table.insert(State.CustomHousePoints, hrp.CFrame)
        AddPointBtn.Text = "➕ Додати відкритий дім (" .. #State.CustomHousePoints .. ")"
        setStatusText(nil, "🏠 Додано відкритий дім #" .. #State.CustomHousePoints)
    end
end)

bindButton(ClearPointsBtn, function()
    State.CustomHousePoints = {}
    State.HouseCooldownMap = {}
    AddPointBtn.Text = "➕ Додати відкритий дім (0)"
    setStatusText(nil, "🏠 Точки скинуто (Авто-пошук)")
end)

local LimitRow = Instance.new("Frame")
LimitRow.LayoutOrder = 3
LimitRow.Size = UDim2.new(1, -6, 0, 30)
LimitRow.BackgroundTransparency = 1
LimitRow.ZIndex = 33
LimitRow.Parent = PageHouses

local LimitBtns = {}
local function makeLimitBtn(label, val, idx)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.2, -3, 1, 0)
    b.Position = UDim2.new((idx - 1) * 0.2, 1, 0, 0)
    b.BackgroundColor3 = (State.MaxUnlockedHouses == val) and Colors.Orange or Colors.Card
    b.Text = label
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.ZIndex = 34
    b.Parent = LimitRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    LimitBtns[val] = b
    bindButton(b, function()
        State.MaxUnlockedHouses = val
        for k, btn in pairs(LimitBtns) do
            btn.BackgroundColor3 = (k == val) and Colors.Orange or Colors.Card
        end
    end)
end

makeLimitBtn("1 дім", 1, 1)
makeLimitBtn("2 доми", 2, 2)
makeLimitBtn("3 доми", 3, 3)
makeLimitBtn("4 доми", 4, 4)
makeLimitBtn("Всі", 0, 5)

local AutoCapToggle = Instance.new("TextButton")
AutoCapToggle.LayoutOrder = 4
AutoCapToggle.Size = UDim2.new(1, -6, 0, 32)
AutoCapToggle.BackgroundColor3 = Colors.Green
AutoCapToggle.Text = "🎯 Авто-Точки (Капча): УВІМК"
AutoCapToggle.TextColor3 = Color3.new(1, 1, 1)
AutoCapToggle.Font = Enum.Font.GothamBold
AutoCapToggle.TextSize = 12
AutoCapToggle.ZIndex = 33
AutoCapToggle.Parent = PageHouses
Instance.new("UICorner", AutoCapToggle).CornerRadius = UDim.new(0, 7)

bindButton(AutoCapToggle, function()
    State.AutoMinigame = not State.AutoMinigame
    if State.AutoMinigame then
        AutoCapToggle.BackgroundColor3 = Colors.Green
        AutoCapToggle.Text = "🎯 Авто-Точки (Капча): УВІМК"
    else
        AutoCapToggle.BackgroundColor3 = Colors.Red
        AutoCapToggle.Text = "🎯 Авто-Точки (Капча): ВИМК"
    end
end)

BlackToggleBtnInSettings = Instance.new("TextButton")
BlackToggleBtnInSettings.LayoutOrder = 1
BlackToggleBtnInSettings.Size = UDim2.new(1, -6, 0, 36)
BlackToggleBtnInSettings.BackgroundColor3 = Colors.Green
BlackToggleBtnInSettings.Text = "🌑 Чорний Екран Статистики + 3D ВИМК: АКТИВНО"
BlackToggleBtnInSettings.TextColor3 = Color3.new(1, 1, 1)
BlackToggleBtnInSettings.Font = Enum.Font.GothamBold
BlackToggleBtnInSettings.TextSize = 12
BlackToggleBtnInSettings.ZIndex = 33
BlackToggleBtnInSettings.Parent = PageSettings
Instance.new("UICorner", BlackToggleBtnInSettings).CornerRadius = UDim.new(0, 7)

bindButton(BlackToggleBtnInSettings, function()
    setBlackScreenMode(not State.BlackScreenActive)
end)

Render3DToggleBtn = Instance.new("TextButton")
Render3DToggleBtn.LayoutOrder = 2
Render3DToggleBtn.Size = UDim2.new(1, -6, 0, 34)
Render3DToggleBtn.BackgroundColor3 = Colors.Green
Render3DToggleBtn.Text = "🎮 3D Графіка (Рендер світу): УВІМК"
Render3DToggleBtn.TextColor3 = Color3.new(1, 1, 1)
Render3DToggleBtn.Font = Enum.Font.GothamBold
Render3DToggleBtn.TextSize = 12
Render3DToggleBtn.ZIndex = 33
Render3DToggleBtn.Parent = PageSettings
Instance.new("UICorner", Render3DToggleBtn).CornerRadius = UDim.new(0, 7)

bindButton(Render3DToggleBtn, function()
    set3DRendering(not State.Rendering3DEnabled)
end)

local JumpToggle = Instance.new("TextButton")
JumpToggle.LayoutOrder = 3
JumpToggle.Size = UDim2.new(1, -6, 0, 32)
JumpToggle.BackgroundColor3 = Colors.Green
JumpToggle.Text = "🦘 Стрибок раз на 20 сек (Анти-АФК): УВІМК"
JumpToggle.TextColor3 = Color3.new(1, 1, 1)
JumpToggle.Font = Enum.Font.GothamBold
JumpToggle.TextSize = 12
JumpToggle.ZIndex = 33
JumpToggle.Parent = PageSettings
Instance.new("UICorner", JumpToggle).CornerRadius = UDim.new(0, 7)

bindButton(JumpToggle, function()
    State.AutoJump20s = not State.AutoJump20s
    if State.AutoJump20s then
        JumpToggle.BackgroundColor3 = Colors.Green
        JumpToggle.Text = "🦘 Стрибок раз на 20 сек (Анти-АФК): УВІМК"
    else
        JumpToggle.BackgroundColor3 = Colors.Red
        JumpToggle.Text = "🦘 Стрибок раз на 20 сек (Анти-АФК): ВИМК"
    end
end)

local CoordsRow = Instance.new("Frame")
CoordsRow.LayoutOrder = 4
CoordsRow.Size = UDim2.new(1, -6, 0, 32)
CoordsRow.BackgroundTransparency = 1
CoordsRow.ZIndex = 33
CoordsRow.Parent = PageSettings

CoordsInputBox = Instance.new("TextBox")
CoordsInputBox.Size = UDim2.new(0.65, -3, 1, 0)
CoordsInputBox.Position = UDim2.new(0, 0, 0, 0)
CoordsInputBox.BackgroundColor3 = Colors.InputBg
CoordsInputBox.Text = ""
CoordsInputBox.PlaceholderText = "Координати X, Y, Z (авто або вручну)"
CoordsInputBox.PlaceholderColor3 = Colors.SubText
CoordsInputBox.TextColor3 = Colors.Orange
CoordsInputBox.Font = Enum.Font.GothamBold
CoordsInputBox.TextSize = 11
CoordsInputBox.ClearTextOnFocus = false
CoordsInputBox.ZIndex = 34
CoordsInputBox.Parent = CoordsRow
Instance.new("UICorner", CoordsInputBox).CornerRadius = UDim.new(0, 6)

local SetCoordsManualBtn = Instance.new("TextButton")
SetCoordsManualBtn.Size = UDim2.new(0.35, -3, 1, 0)
SetCoordsManualBtn.Position = UDim2.new(0.65, 3, 0, 0)
SetCoordsManualBtn.BackgroundColor3 = Colors.Blue
SetCoordsManualBtn.Text = "💾 Застосувати"
SetCoordsManualBtn.TextColor3 = Color3.new(1, 1, 1)
SetCoordsManualBtn.Font = Enum.Font.GothamBold
SetCoordsManualBtn.TextSize = 11
SetCoordsManualBtn.ZIndex = 34
SetCoordsManualBtn.Parent = CoordsRow
Instance.new("UICorner", SetCoordsManualBtn).CornerRadius = UDim.new(0, 6)

bindButton(SetCoordsManualBtn, function()
    local raw = CoordsInputBox.Text or ""
    local x, y, z = string.match(raw, "([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
    if x and y and z then
        local cf = CFrame.new(tonumber(x), tonumber(y), tonumber(z))
        State.SavedEggCFrame = cf
        saveCoordsToDisk(cf)
        teleportSafelyTo(cf)
    else
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            State.SavedEggCFrame = hrp.CFrame
            saveCoordsToDisk(hrp.CFrame)
        end
    end
end)

local DelaysRow = Instance.new("Frame")
DelaysRow.LayoutOrder = 5
DelaysRow.Size = UDim2.new(1, -6, 0, 32)
DelaysRow.BackgroundTransparency = 1
DelaysRow.ZIndex = 33
DelaysRow.Parent = PageSettings

local HouseDelayInput = Instance.new("TextBox")
HouseDelayInput.Size = UDim2.new(0.5, -3, 1, 0)
HouseDelayInput.Position = UDim2.new(0, 0, 0, 0)
HouseDelayInput.BackgroundColor3 = Colors.InputBg
HouseDelayInput.Text = "Домик пауза: 4 с"
HouseDelayInput.PlaceholderText = "Пауза на домик (сек, напр. 4)"
HouseDelayInput.PlaceholderColor3 = Colors.SubText
HouseDelayInput.TextColor3 = Colors.Green
HouseDelayInput.Font = Enum.Font.GothamBold
HouseDelayInput.TextSize = 11
HouseDelayInput.ClearTextOnFocus = true
HouseDelayInput.ZIndex = 34
HouseDelayInput.Parent = DelaysRow
Instance.new("UICorner", HouseDelayInput).CornerRadius = UDim.new(0, 6)

trackConn(HouseDelayInput.FocusLost:Connect(function()
    local v = tonumber(string.match(HouseDelayInput.Text or "", "([%d%.]+)"))
    if v and v >= 1 then
        State.HouseStepDelay = v
    else
        State.HouseStepDelay = 4.0
    end
    HouseDelayInput.Text = string.format("Домик пауза: %.1f с", State.HouseStepDelay)
end))

local EggDelayInput = Instance.new("TextBox")
EggDelayInput.Size = UDim2.new(0.5, -3, 1, 0)
EggDelayInput.Position = UDim2.new(0.5, 3, 0, 0)
EggDelayInput.BackgroundColor3 = Colors.InputBg
EggDelayInput.Text = "Яйця пауза: 2 с"
EggDelayInput.PlaceholderText = "Пауза між яйцями (сек, напр. 2)"
EggDelayInput.PlaceholderColor3 = Colors.SubText
EggDelayInput.TextColor3 = Colors.Orange
EggDelayInput.Font = Enum.Font.GothamBold
EggDelayInput.TextSize = 11
EggDelayInput.ClearTextOnFocus = true
EggDelayInput.ZIndex = 34
EggDelayInput.Parent = DelaysRow
Instance.new("UICorner", EggDelayInput).CornerRadius = UDim.new(0, 6)

trackConn(EggDelayInput.FocusLost:Connect(function()
    local v = tonumber(string.match(EggDelayInput.Text or "", "([%d%.]+)"))
    if v and v >= 0.5 then
        State.EggHatchDelay = v
    else
        State.EggHatchDelay = 2.0
    end
    EggDelayInput.Text = string.format("Яйця пауза: %.1f с", State.EggHatchDelay)
end))

local LogBtnsRow = Instance.new("Frame")
LogBtnsRow.LayoutOrder = 1
LogBtnsRow.Size = UDim2.new(1, -6, 0, 32)
LogBtnsRow.BackgroundTransparency = 1
LogBtnsRow.ZIndex = 33
LogBtnsRow.Parent = PageLogs

local CopyLogsBtn = Instance.new("TextButton")
CopyLogsBtn.Size = UDim2.new(0.34, -3, 1, 0)
CopyLogsBtn.Position = UDim2.new(0, 0, 0, 0)
CopyLogsBtn.BackgroundColor3 = Colors.Green
CopyLogsBtn.Text = "📋 Копіювати"
CopyLogsBtn.TextColor3 = Color3.new(1, 1, 1)
CopyLogsBtn.Font = Enum.Font.GothamBold
CopyLogsBtn.TextSize = 12
CopyLogsBtn.ZIndex = 34
CopyLogsBtn.Parent = LogBtnsRow
Instance.new("UICorner", CopyLogsBtn).CornerRadius = UDim.new(0, 6)

local DiagEventBtn = Instance.new("TextButton")
DiagEventBtn.Size = UDim2.new(0.34, -3, 1, 0)
DiagEventBtn.Position = UDim2.new(0.34, 2, 0, 0)
DiagEventBtn.BackgroundColor3 = Colors.Orange
DiagEventBtn.Text = "🔍 Сканер"
DiagEventBtn.TextColor3 = Color3.new(1, 1, 1)
DiagEventBtn.Font = Enum.Font.GothamBold
DiagEventBtn.TextSize = 12
DiagEventBtn.ZIndex = 34
DiagEventBtn.Parent = LogBtnsRow
Instance.new("UICorner", DiagEventBtn).CornerRadius = UDim.new(0, 6)

local ClearLogsBtn = Instance.new("TextButton")
ClearLogsBtn.Size = UDim2.new(0.32, -3, 1, 0)
ClearLogsBtn.Position = UDim2.new(0.68, 4, 0, 0)
ClearLogsBtn.BackgroundColor3 = Colors.Red
ClearLogsBtn.Text = "🗑️ Очистити"
ClearLogsBtn.TextColor3 = Color3.new(1, 1, 1)
ClearLogsBtn.Font = Enum.Font.GothamBold
ClearLogsBtn.TextSize = 12
ClearLogsBtn.ZIndex = 34
ClearLogsBtn.Parent = LogBtnsRow
Instance.new("UICorner", ClearLogsBtn).CornerRadius = UDim.new(0, 6)

LogScrollFrame = Instance.new("ScrollingFrame")
LogScrollFrame.LayoutOrder = 2
LogScrollFrame.Size = UDim2.new(1, -6, 0, 200)
LogScrollFrame.BackgroundColor3 = Colors.InputBg
LogScrollFrame.BorderSizePixel = 0
LogScrollFrame.ScrollBarThickness = 5
LogScrollFrame.ScrollBarImageColor3 = Colors.Orange
LogScrollFrame.ZIndex = 33
LogScrollFrame.Parent = PageLogs
Instance.new("UICorner", LogScrollFrame).CornerRadius = UDim.new(0, 6)

LogBoxLabel = Instance.new("TextLabel")
LogBoxLabel.Size = UDim2.new(1, -12, 0, 195)
LogBoxLabel.Position = UDim2.new(0, 6, 0, 4)
LogBoxLabel.BackgroundTransparency = 1
LogBoxLabel.Text = ""
LogBoxLabel.TextColor3 = Color3.fromRGB(210, 230, 215)
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
        CopyLogsBtn.Text = "✅ Скопійовано"
        task.delay(1.2, function()
            if CopyLogsBtn then CopyLogsBtn.Text = "📋 Копіювати" end
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
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
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

task.spawn(function()
    pcall(enterHalloweenEventAndGoToCoords)
    State.FullAutoFarm = true
    if #findNearestEggCandidates(120) > 0 then
        setBlackScreenMode(true)
        MainFrame.Visible = false
        FloatBtn.Visible = true
    else
        setBlackScreenMode(false)
        MainFrame.Visible = true
        FloatBtn.Visible = false
    end
    addLog("OK", "Координати 7538.1, 15.7, 21965.5 встановлено! Авто-фарм активовано.")
end)
