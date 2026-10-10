repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LogService = game:GetService("LogService")

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
        if busy or (now - lastFire < 0.35) then return end
        busy = true
        lastFire = now
        task.spawn(function()
            pcall(callback)
            task.wait(0.1)
            busy = false
        end)
    end))
end

local State = {
    Running = true,
    AutoEggs = false,
    RemoveEggAnim = true,
    EggAmount = 0,
    SelectedEggName = "",
    LastCapturedEggRemote = nil,
    LastCapturedEggArgs = nil,
    SavedEggCFrame = nil,
    AutoHouses = false,
    HouseInterval = 600,
    LastHouseRun = 0,
    IsVisitingHouses = false,
    HouseWaitTime = 4.0,
    CustomHousePoints = {},
    LastCapturedHouseRemote = nil,
    LastCapturedHouseArgs = nil,
    AutoMinigame = false,
    AutoCollectCandy = false,
    Logs = {},
    MaxLogs = 250
}

local LogBoxLabel = nil
local LogScrollFrame = nil
local EggStatusLabel = nil
local HouseStatusLabel = nil

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

local NetworkFolder = nil
pcall(function()
    NetworkFolder = ReplicatedStorage:WaitForChild("Network", 8)
end)

local function findRemote(name)
    if NetworkFolder then
        local r = NetworkFolder:FindFirstChild(name)
        if r then return r end
        for _, desc in ipairs(NetworkFolder:GetDescendants()) do
            if string.lower(desc.Name) == string.lower(name) then
                return desc
            end
        end
    end
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if string.lower(desc.Name) == string.lower(name) and (desc:IsA("RemoteFunction") or desc:IsA("RemoteEvent")) then
            return desc
        end
    end
    return nil
end

local function invokeRemote(name, ...)
    local r = findRemote(name)
    if not r then return false, "NotFound" end
    local args = {...}
    if r:IsA("RemoteFunction") then
        return pcall(function() return r:InvokeServer(unpack(args)) end)
    elseif r:IsA("RemoteEvent") then
        return pcall(function() r:FireServer(unpack(args)) end)
    end
    return false, "InvalidType"
end

local function getThingsFolder()
    return Workspace:FindFirstChild("__THINGS") or Workspace:FindFirstChild("Things")
end

local function getActiveInstanceContainer()
    local things = getThingsFolder()
    if not things then return nil end
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

pcall(function()
    if hookmetamethod and getnamecallmethod and not env.HalloweenNamecallHooked then
        env.HalloweenNamecallHooked = true
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if (method == "InvokeServer" or method == "FireServer") and typeof(self) == "Instance" then
                local rName = string.lower(self.Name)
                local args = {...}
                if string.find(rName, "egg") or string.find(rName, "hatch") then
                    if not string.find(rName, "anim") then
                        State.LastCapturedEggRemote = self
                        State.LastCapturedEggArgs = args
                        if EggStatusLabel and args[1] then
                            pcall(function()
                                EggStatusLabel.Text = "Яйце: " .. tostring(args[1])
                            end)
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

local OriginalPlayEggAnim = nil

local function applyEggAnimationSkip(disableAnim)
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        if not ps then return end
        local scriptsFolder = ps:FindFirstChild("Scripts")
        if not scriptsFolder then return end
        local gameFolder = scriptsFolder:FindFirstChild("Game")
        if not gameFolder then return end
        local eggFrontend = gameFolder:FindFirstChild("Egg Opening Frontend")
        if eggFrontend and getsenv then
            local senv = getsenv(eggFrontend)
            if senv then
                if disableAnim then
                    if senv.PlayEggAnimation and not OriginalPlayEggAnim then
                        OriginalPlayEggAnim = senv.PlayEggAnimation
                    end
                    senv.PlayEggAnimation = function() return end
                else
                    if OriginalPlayEggAnim then
                        senv.PlayEggAnimation = OriginalPlayEggAnim
                    end
                end
            end
        end
    end)
end

task.spawn(function()
    while State.Running do
        if State.RemoveEggAnim and State.AutoEggs then
            pcall(function()
                local cam = Workspace.CurrentCamera
                if cam then
                    for _, child in ipairs(cam:GetChildren()) do
                        local n = string.lower(child.Name)
                        if string.find(n, "egg") or string.find(n, "pet") then
                            child:Destroy()
                        end
                    end
                end
            end)
        end
        task.wait(0.2)
    end
end)

local function getObjectPosition(obj)
    local pos = nil
    pcall(function()
        if obj:IsA("BasePart") then
            pos = obj.Position
        elseif obj:IsA("Model") then
            pos = obj:GetPivot().Position
        else
            local part = obj:FindFirstChildWhichIsA("BasePart", true)
            if part then pos = part.Position end
        end
    end)
    return pos
end

local function findNearestEgg()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil, nil end
    local myPos = hrp.Position

    local things = getThingsFolder()
    local bestId = nil
    local bestDist = 75
    local isCustom = false

    local customContainers = {}
    if things then
        local ce = things:FindFirstChild("CustomEggs")
        if ce then table.insert(customContainers, ce) end
    end
    local activeInst, activeFolder = getActiveInstanceContainer()
    if activeFolder then
        for _, d in ipairs(activeFolder:GetDescendants()) do
            if d.Name == "CustomEggs" or d.Name == "Eggs" then
                table.insert(customContainers, d)
            end
        end
    end

    for _, container in ipairs(customContainers) do
        for _, egg in ipairs(container:GetChildren()) do
            local pos = getObjectPosition(egg)
            if pos then
                local d = (pos - myPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestId = egg:GetAttribute("id") or egg:GetAttribute("EggName") or egg:GetAttribute("ID") or egg.Name
                    isCustom = (container.Name == "CustomEggs")
                end
            end
        end
    end

    if things then
        local eggsFolder = things:FindFirstChild("Eggs")
        if eggsFolder then
            for _, eggModel in ipairs(eggsFolder:GetChildren()) do
                local pos = getObjectPosition(eggModel)
                if pos then
                    local d = (pos - myPos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        local idAttr = eggModel:GetAttribute("EggName") or eggModel:GetAttribute("id") or eggModel:GetAttribute("ID")
                        if not idAttr then
                            for _, sub in ipairs(eggModel:GetDescendants()) do
                                local a = sub:GetAttribute("EggName") or sub:GetAttribute("id")
                                if a then idAttr = a break end
                            end
                        end
                        bestId = idAttr or eggModel.Name
                        isCustom = false
                    end
                end
            end
        end
    end

    if not bestId and activeInst then
        for _, desc in ipairs(activeInst:GetDescendants()) do
            if desc:IsA("Model") or desc:IsA("BasePart") then
                local n = string.lower(desc.Name)
                local eggAttr = desc:GetAttribute("EggName") or desc:GetAttribute("EggId") or desc:GetAttribute("CustomEgg")
                if eggAttr or string.find(n, "egg") then
                    local pos = getObjectPosition(desc)
                    if pos then
                        local d = (pos - myPos).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestId = eggAttr or desc.Name
                            isCustom = true
                        end
                    end
                end
            end
        end
    end

    return bestId, isCustom, bestDist
end

local function detectMaxHatchAmount()
    local maxHatch = 1
    pcall(function()
        if ReplicatedStorage:FindFirstChild("Library") then
            local saveMod = ReplicatedStorage.Library:FindFirstChild("Client") and ReplicatedStorage.Library.Client:FindFirstChild("Save")
            if saveMod then
                local Save = require(saveMod)
                local data = Save.Get()
                if data then
                    local slots = data.EggSlotsPurchased or data.EggsHatchedAtOnce or data.MaxEggs
                    if slots then
                        maxHatch = math.clamp(tonumber(slots) or 8, 1, 99)
                    end
                end
            end
        end
    end)
    if maxHatch <= 1 then maxHatch = 8 end
    return maxHatch
end

local function hatchTargetEgg()
    if State.IsVisitingHouses then return end
    if State.RemoveEggAnim then
        applyEggAnimationSkip(true)
    end

    local amount = State.EggAmount
    if amount <= 0 then
        amount = detectMaxHatchAmount()
    end

    local manualName = State.SelectedEggName
    if manualName and manualName ~= "" then
        if EggStatusLabel then EggStatusLabel.Text = "Яйце: " .. manualName end
        invokeRemote("CustomEggs_Hatch", manualName, amount)
        invokeRemote("Eggs_RequestPurchase", manualName, amount)
        local activeInst = getActiveInstanceContainer()
        if activeInst then
            invokeRemote("Instancing_InvokeCustomFromClient", activeInst.Name, "HatchEgg", manualName, amount)
            invokeRemote("Instancing_FireCustomFromClient", activeInst.Name, "HatchEgg", manualName, amount)
        end
        return
    end

    local nearestId, isCustom, dist = findNearestEgg()
    if nearestId then
        if EggStatusLabel then
            EggStatusLabel.Text = string.format("Яйце: %s (%.0fм)", tostring(nearestId), dist or 0)
        end
        if isCustom then
            invokeRemote("CustomEggs_Hatch", nearestId, amount)
            invokeRemote("Eggs_RequestPurchase", nearestId, amount)
        else
            invokeRemote("Eggs_RequestPurchase", nearestId, amount)
            invokeRemote("CustomEggs_Hatch", nearestId, amount)
        end
        local activeInst = getActiveInstanceContainer()
        if activeInst then
            invokeRemote("Instancing_InvokeCustomFromClient", activeInst.Name, "CustomEggs_Hatch", nearestId, amount)
            invokeRemote("Instancing_FireCustomFromClient", activeInst.Name, "CustomEggs_Hatch", nearestId, amount)
        end
        return
    end

    if State.LastCapturedEggRemote and State.LastCapturedEggArgs then
        local rem = State.LastCapturedEggRemote
        local args = {}
        for i, v in ipairs(State.LastCapturedEggArgs) do args[i] = v end
        if State.EggAmount > 0 and #args >= 2 and type(args[2]) == "number" then
            args[2] = State.EggAmount
        end
        pcall(function()
            if rem:IsA("RemoteFunction") then
                rem:InvokeServer(unpack(args))
            elseif rem:IsA("RemoteEvent") then
                rem:FireServer(unpack(args))
            end
        end)
        return
    end

    if EggStatusLabel then
        EggStatusLabel.Text = "Підійди до яйця (або відкрий 1 раз вручну)"
    end
end

task.spawn(function()
    while State.Running do
        if State.AutoEggs and not State.IsVisitingHouses then
            pcall(hatchTargetEgg)
            task.wait(0.1)
        else
            task.wait(0.25)
        end
    end
end)

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

local LastDotClick = {}
local function scanAndSolveMinigame()
    if not State.AutoMinigame then return end
    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pgui then return end

    local now = tick()
    for _, screen in ipairs(pgui:GetChildren()) do
        if screen:IsA("ScreenGui") and screen.Enabled and screen.Name ~= "HalloweenEventGui" then
            local sName = string.lower(screen.Name)
            local isMinigameScreen = string.find(sName, "minigame")
                or string.find(sName, "trickortreat")
                or string.find(sName, "trick_or_treat")
                or string.find(sName, "doorgame")
                or string.find(sName, "housegame")
                or string.find(sName, "captcha")

            if isMinigameScreen then
                for _, obj in ipairs(screen:GetDescendants()) do
                    if obj:IsA("GuiButton") and obj.Visible then
                        local oName = string.lower(obj.Name)
                        if not string.find(oName, "close") and not string.find(oName, "exit") and not string.find(oName, "cancel") then
                            local lastTime = LastDotClick[obj] or 0
                            if now - lastTime > 0.08 then
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

task.spawn(function()
    while State.Running do
        if State.AutoMinigame then
            pcall(scanAndSolveMinigame)
            task.wait(0.05)
        else
            task.wait(0.3)
        end
    end
end)

local function triggerInteractionsAt(pos, inst, radius)
    radius = radius or 22
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    if hrp and firetouchinterest then
        if inst then
            pcall(function()
                if inst:IsA("BasePart") then
                    firetouchinterest(hrp, inst, 0)
                    firetouchinterest(hrp, inst, 1)
                elseif inst:IsA("Model") then
                    for _, p in ipairs(inst:GetDescendants()) do
                        if p:IsA("BasePart") then
                            firetouchinterest(hrp, p, 0)
                            firetouchinterest(hrp, p, 1)
                        end
                    end
                end
            end)
        end
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("TouchTransmitter") and desc.Parent and desc.Parent:IsA("BasePart") then
                local p = desc.Parent
                if (p.Position - pos).Magnitude <= radius then
                    pcall(function()
                        firetouchinterest(hrp, p, 0)
                        firetouchinterest(hrp, p, 1)
                    end)
                end
            end
        end
    end

    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled then
            local pPos = getObjectPosition(desc.Parent)
            if pPos and (pPos - pos).Magnitude <= radius then
                pcall(function()
                    if fireproximityprompt then
                        fireproximityprompt(desc)
                    else
                        desc:InputHoldBegin()
                        task.wait(0.1)
                        desc:InputHoldEnd()
                    end
                end)
            end
        elseif desc:IsA("ClickDetector") then
            local pPos = getObjectPosition(desc.Parent)
            if pPos and (pPos - pos).Magnitude <= radius then
                pcall(function()
                    if fireclickdetector then
                        fireclickdetector(desc)
                    end
                end)
            end
        end
    end
end

local function scanHalloweenHouses()
    local houses = {}
    local seenPositions = {}

    local function addUniqueHouse(name, pos, inst, idVal)
        if not pos then return end
        for _, existing in ipairs(seenPositions) do
            if (existing - pos).Magnitude < 12 then
                return
            end
        end
        table.insert(seenPositions, pos)
        table.insert(houses, {
            name = name or "House",
            pos = pos,
            instance = inst,
            id = idVal or (inst and inst.Name) or tostring(#houses + 1)
        })
    end

    for idx, cf in ipairs(State.CustomHousePoints) do
        addUniqueHouse("Точка #" .. idx, cf.Position, nil, idx)
    end
    if #houses > 0 then
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
            local fullPath = string.lower(desc:GetFullName())
            local n = string.lower(desc.Name)

            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local pos = getObjectPosition(desc.Parent)
                if pos then
                    addUniqueHouse(desc.ObjectText ~= "" and desc.ObjectText or desc.Parent.Name, pos, desc.Parent, desc.Parent.Name)
                end
            elseif (desc:IsA("Model") or desc:IsA("BasePart")) then
                local isHouseFolder = string.find(fullPath, "trickortreat")
                    or string.find(fullPath, "houses")
                    or string.find(fullPath, "spookyhouse")
                    or string.find(fullPath, "doors")
                    or string.find(n, "house")
                    or string.find(n, "trickortreat")

                if isHouseFolder then
                    local targetPart = nil
                    if desc:IsA("Model") then
                        targetPart = desc:FindFirstChild("Door", true)
                            or desc:FindFirstChild("Pad", true)
                            or desc:FindFirstChild("Interact", true)
                            or desc:FindFirstChild("Prompt", true)
                            or desc:FindFirstChild("Hitbox", true)
                            or desc.PrimaryPart
                    elseif desc:IsA("BasePart") and (n == "door" or n == "pad" or n == "interact" or n == "prompt") then
                        targetPart = desc
                    end
                    local pos = targetPart and getObjectPosition(targetPart) or getObjectPosition(desc)
                    if pos then
                        addUniqueHouse(desc.Name, pos, targetPart or desc, desc.Name)
                    end
                end
            end
        end
        if #houses > 0 then break end
    end

    table.sort(houses, function(a, b)
        local na = tonumber(string.match(tostring(a.id), "%d+"))
        local nb = tonumber(string.match(tostring(b.id), "%d+"))
        if na and nb and na ~= nb then
            return na < nb
        end
        return a.pos.Z < b.pos.Z
    end)

    return houses
end

local function fireHouseRemotes(house)
    if State.LastCapturedHouseRemote and State.LastCapturedHouseArgs then
        local rem = State.LastCapturedHouseRemote
        local args = {}
        for i, v in ipairs(State.LastCapturedHouseArgs) do args[i] = v end
        pcall(function()
            if rem:IsA("RemoteFunction") then
                rem:InvokeServer(unpack(args))
            elseif rem:IsA("RemoteEvent") then
                rem:FireServer(unpack(args))
            end
        end)
    end

    local activeInst = getActiveInstanceContainer()
    local instName = activeInst and activeInst.Name or "HalloweenEvent"
    local numId = tonumber(string.match(tostring(house.id), "%d+")) or house.id

    local actions = { "Knock", "TrickOrTreat", "ClaimHouse", "OpenDoor", "Interact", "VisitHouse", "Claim" }
    for _, act in ipairs(actions) do
        invokeRemote("Instancing_FireCustomFromClient", instName, act, numId)
        invokeRemote("Instancing_InvokeCustomFromClient", instName, act, numId)
        if numId ~= house.id then
            invokeRemote("Instancing_FireCustomFromClient", instName, act, house.id)
            invokeRemote("Instancing_InvokeCustomFromClient", instName, act, house.id)
        end
    end

    local directRemotes = {
        "TrickOrTreat_Knock",
        "TrickOrTreat_Interact",
        "TrickOrTreat_Claim",
        "Halloween_KnockDoor",
        "Houses_Knock",
        "Houses_Interact"
    }
    for _, rName in ipairs(directRemotes) do
        invokeRemote(rName, numId)
        if numId ~= house.id then
            invokeRemote(rName, house.id)
        end
    end
end

local function runHousesRoutine()
    if State.IsVisitingHouses then return end
    State.IsVisitingHouses = true

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        State.IsVisitingHouses = false
        return
    end

    local returnCF = State.SavedEggCFrame or hrp.CFrame
    local houses = scanHalloweenHouses()

    if #houses == 0 then
        addLog("WARN", "Домики не знайдено. Додай точки кнопкою '+ Додати точку' або натисни 'Сканер' у Логах.")
        if HouseStatusLabel then
            HouseStatusLabel.Text = "Не знайдено (додай точки вручну)"
        end
        State.IsVisitingHouses = false
        return
    end

    addLog("INFO", "Обхід домиків: " .. #houses .. " шт.")

    for i, house in ipairs(houses) do
        if not State.Running then break end
        char = LocalPlayer.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then break end

        if HouseStatusLabel then
            HouseStatusLabel.Text = string.format("Дім %d/%d: %s", i, #houses, tostring(house.name))
        end

        pcall(function()
            hrp.CFrame = CFrame.new(house.pos + Vector3.new(0, 3, 0))
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
        task.wait(0.35)

        triggerInteractionsAt(house.pos, house.instance, 22)
        fireHouseRemotes(house)

        local waitStart = tick()
        while tick() - waitStart < State.HouseWaitTime and State.Running do
            triggerInteractionsAt(house.pos, house.instance, 22)
            scanAndSolveMinigame()
            task.wait(0.25)
        end
    end

    if returnCF and State.Running then
        char = LocalPlayer.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.CFrame = returnCF
                hrp.AssemblyLinearVelocity = Vector3.zero
            end)
        end
    end

    State.LastHouseRun = tick()
    State.IsVisitingHouses = false
    addLog("OK", "Обхід завершено (" .. #houses .. " домиків)")
end

task.spawn(function()
    while State.Running do
        if State.AutoHouses and not State.IsVisitingHouses then
            local elapsed = tick() - State.LastHouseRun
            local remaining = math.max(0, State.HouseInterval - elapsed)
            if HouseStatusLabel then
                local mins = math.floor(remaining / 60)
                local secs = math.floor(remaining % 60)
                HouseStatusLabel.Text = string.format("Наступний обхід: %02d:%02d", mins, secs)
            end
            if elapsed >= State.HouseInterval or State.LastHouseRun == 0 then
                pcall(runHousesRoutine)
            end
        elseif not State.AutoHouses and HouseStatusLabel and not State.IsVisitingHouses then
            HouseStatusLabel.Text = "Очікування"
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while State.Running do
        if State.AutoCollectCandy then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local things = getThingsFolder()
                if hrp and things then
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
                end
            end)
        end
        task.wait(0.4)
    end
end)

local function runEventDiagnostic()
    addLog("INFO", "=== СКАНЕР НАВКОЛО ГРАВЦЯ ===")
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myPos = hrp and hrp.Position or Vector3.zero
    addLog("INFO", string.format("Позиція: %.1f, %.1f, %.1f", myPos.X, myPos.Y, myPos.Z))

    local things = getThingsFolder()
    if things then
        local cEggs = things:FindFirstChild("CustomEggs")
        if cEggs then
            for _, v in ipairs(cEggs:GetChildren()) do
                local p = getObjectPosition(v)
                local d = p and (p - myPos).Magnitude or -1
                if d >= 0 and d <= 150 then
                    addLog("INFO", string.format("CustomEgg: '%s' (%.1fм)", v.Name, d))
                end
            end
        end
        local eggsF = things:FindFirstChild("Eggs")
        if eggsF then
            for _, v in ipairs(eggsF:GetChildren()) do
                local p = getObjectPosition(v)
                local d = p and (p - myPos).Magnitude or -1
                if d >= 0 and d <= 150 then
                    addLog("INFO", string.format("Egg: '%s' (%.1fм)", v.Name, d))
                end
            end
        end
        local instCont = things:FindFirstChild("__INSTANCE_CONTAINER")
        if instCont and instCont:FindFirstChild("Active") then
            for _, inst in ipairs(instCont.Active:GetChildren()) do
                addLog("INFO", "Active World: " .. inst.Name)
                for _, sub in ipairs(inst:GetChildren()) do
                    addLog("INFO", "  Folder: " .. sub.Name .. " (" .. #sub:GetChildren() .. ")")
                    for _, item in ipairs(sub:GetChildren()) do
                        local p = getObjectPosition(item)
                        local d = p and (p - myPos).Magnitude or -1
                        if d >= 0 and d <= 200 then
                            addLog("INFO", string.format("    -> %s [%s] (%.1fм)", item.Name, item.ClassName, d))
                        end
                    end
                end
            end
        end
    end

    if State.LastCapturedEggRemote then
        addLog("INFO", "Captured Egg Remote: " .. State.LastCapturedEggRemote.Name)
    end
    if State.LastCapturedHouseRemote then
        addLog("INFO", "Captured House Remote: " .. State.LastCapturedHouseRemote.Name)
    end
    addLog("OK", "Сканування завершено! Натисни 'Копіювати'.")
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
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentGui

local Colors = {
    Bg = Color3.fromRGB(16, 14, 22),
    Header = Color3.fromRGB(26, 20, 36),
    Card = Color3.fromRGB(24, 21, 34),
    Stroke = Color3.fromRGB(110, 65, 190),
    Orange = Color3.fromRGB(255, 125, 30),
    Green = Color3.fromRGB(46, 204, 113),
    Red = Color3.fromRGB(231, 76, 60),
    Blue = Color3.fromRGB(52, 152, 219),
    Text = Color3.fromRGB(245, 242, 255),
    SubText = Color3.fromRGB(175, 168, 195),
    InputBg = Color3.fromRGB(12, 10, 18)
}

local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "FloatToggle"
FloatBtn.Size = UDim2.new(0, 50, 0, 50)
FloatBtn.Position = UDim2.new(0, 15, 0.5, -25)
FloatBtn.BackgroundColor3 = Colors.Orange
FloatBtn.Text = "🎃"
FloatBtn.TextSize = 24
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextColor3 = Color3.new(1, 1, 1)
FloatBtn.Visible = false
FloatBtn.Parent = ScreenGui
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(1, 0)
local FloatStroke = Instance.new("UIStroke", FloatBtn)
FloatStroke.Color = Color3.new(1, 1, 1)
FloatStroke.Thickness = 2

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 440, 0, 340)
MainFrame.Position = UDim2.new(0.5, -220, 0.5, -170)
MainFrame.BackgroundColor3 = Colors.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Colors.Stroke
MainStroke.Thickness = 2

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = Colors.Header
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -85, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🎃 Halloween"
TitleLabel.TextColor3 = Colors.Orange
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 26)
MinBtn.Position = UDim2.new(1, -68, 0, 5)
MinBtn.BackgroundColor3 = Color3.fromRGB(48, 42, 68)
MinBtn.Text = "_"
MinBtn.TextColor3 = Colors.Text
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.Parent = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0, 5)
CloseBtn.BackgroundColor3 = Colors.Red
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
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
TabBar.Position = UDim2.new(0, 8, 0, 40)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local function createTabButton(text, posScale, widthScale)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(widthScale, -4, 1, 0)
    b.Position = UDim2.new(posScale, 2, 0, 0)
    b.BackgroundColor3 = Colors.Card
    b.Text = text
    b.TextColor3 = Colors.SubText
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Parent = TabBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local TabEggsBtn = createTabButton("🐣 Яйця", 0, 0.333)
local TabHousesBtn = createTabButton("🏠 Домики", 0.333, 0.333)
local TabLogsBtn = createTabButton("📋 Лог", 0.666, 0.334)

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -16, 1, -78)
ContentArea.Position = UDim2.new(0, 8, 0, 74)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local function createPage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 5
    page.ScrollBarImageColor3 = Colors.Orange
    page.Visible = false
    page.Parent = ContentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    trackConn(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end))

    return page
end

local PageEggs = createPage()
local PageHouses = createPage()
local PageLogs = createPage()

local function switchTab(activePage, activeBtn)
    PageEggs.Visible = (activePage == PageEggs)
    PageHouses.Visible = (activePage == PageHouses)
    PageLogs.Visible = (activePage == PageLogs)

    for _, btn in ipairs({TabEggsBtn, TabHousesBtn, TabLogsBtn}) do
        if btn == activeBtn then
            btn.BackgroundColor3 = Colors.Orange
            btn.TextColor3 = Color3.new(1, 1, 1)
        else
            btn.BackgroundColor3 = Colors.Card
            btn.TextColor3 = Colors.SubText
        end
    end
end

bindButton(TabEggsBtn, function() switchTab(PageEggs, TabEggsBtn) end)
bindButton(TabHousesBtn, function() switchTab(PageHouses, TabHousesBtn) end)
bindButton(TabLogsBtn, function() switchTab(PageLogs, TabLogsBtn) end)

local AutoEggToggle = Instance.new("TextButton")
AutoEggToggle.LayoutOrder = 1
AutoEggToggle.Size = UDim2.new(1, -6, 0, 38)
AutoEggToggle.BackgroundColor3 = Colors.Red
AutoEggToggle.Text = "🐣 Авто-Яйця: ВИМК"
AutoEggToggle.TextColor3 = Color3.new(1, 1, 1)
AutoEggToggle.Font = Enum.Font.GothamBold
AutoEggToggle.TextSize = 14
AutoEggToggle.Parent = PageEggs
Instance.new("UICorner", AutoEggToggle).CornerRadius = UDim.new(0, 7)

EggStatusLabel = Instance.new("TextLabel")
EggStatusLabel.LayoutOrder = 2
EggStatusLabel.Size = UDim2.new(1, -6, 0, 20)
EggStatusLabel.BackgroundTransparency = 1
EggStatusLabel.Text = "Підійди до яйця (або відкрий 1 раз вручну)"
EggStatusLabel.TextColor3 = Colors.Orange
EggStatusLabel.Font = Enum.Font.GothamBold
EggStatusLabel.TextSize = 12
EggStatusLabel.Parent = PageEggs

bindButton(AutoEggToggle, function()
    State.AutoEggs = not State.AutoEggs
    if State.AutoEggs then
        AutoEggToggle.BackgroundColor3 = Colors.Green
        AutoEggToggle.Text = "🐣 Авто-Яйця: УВІМК"
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and not State.SavedEggCFrame then
            State.SavedEggCFrame = hrp.CFrame
        end
    else
        AutoEggToggle.BackgroundColor3 = Colors.Red
        AutoEggToggle.Text = "🐣 Авто-Яйця: ВИМК"
    end
end)

local SkipAnimBtn = Instance.new("TextButton")
SkipAnimBtn.LayoutOrder = 3
SkipAnimBtn.Size = UDim2.new(1, -6, 0, 34)
SkipAnimBtn.BackgroundColor3 = Colors.Green
SkipAnimBtn.Text = "⚡ Без анімації: УВІМК"
SkipAnimBtn.TextColor3 = Color3.new(1, 1, 1)
SkipAnimBtn.Font = Enum.Font.GothamBold
SkipAnimBtn.TextSize = 13
SkipAnimBtn.Parent = PageEggs
Instance.new("UICorner", SkipAnimBtn).CornerRadius = UDim.new(0, 7)

bindButton(SkipAnimBtn, function()
    State.RemoveEggAnim = not State.RemoveEggAnim
    applyEggAnimationSkip(State.RemoveEggAnim)
    if State.RemoveEggAnim then
        SkipAnimBtn.BackgroundColor3 = Colors.Green
        SkipAnimBtn.Text = "⚡ Без анімації: УВІМК"
    else
        SkipAnimBtn.BackgroundColor3 = Colors.Red
        SkipAnimBtn.Text = "⚡ Без анімації: ВИМК"
    end
end)

local CountRow = Instance.new("Frame")
CountRow.LayoutOrder = 4
CountRow.Size = UDim2.new(1, -6, 0, 32)
CountRow.BackgroundTransparency = 1
CountRow.Parent = PageEggs

local EggCountBtns = {}
local function makeCountBtn(label, val, idx)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.25, -4, 1, 0)
    b.Position = UDim2.new((idx - 1) * 0.25, 2, 0, 0)
    b.BackgroundColor3 = (State.EggAmount == val) and Colors.Orange or Colors.Card
    b.Text = label
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = CountRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    EggCountBtns[val] = b
    bindButton(b, function()
        State.EggAmount = val
        for k, btn in pairs(EggCountBtns) do
            btn.BackgroundColor3 = (k == val) and Colors.Orange or Colors.Card
        end
    end)
end

makeCountBtn("1x", 1, 1)
makeCountBtn("3x", 3, 2)
makeCountBtn("8x", 8, 3)
makeCountBtn("MAX", 0, 4)

local SaveEggPosBtn = Instance.new("TextButton")
SaveEggPosBtn.LayoutOrder = 5
SaveEggPosBtn.Size = UDim2.new(1, -6, 0, 34)
SaveEggPosBtn.BackgroundColor3 = Colors.Blue
SaveEggPosBtn.Text = "📍 Зберегти позицію яйця"
SaveEggPosBtn.TextColor3 = Color3.new(1, 1, 1)
SaveEggPosBtn.Font = Enum.Font.GothamBold
SaveEggPosBtn.TextSize = 13
SaveEggPosBtn.Parent = PageEggs
Instance.new("UICorner", SaveEggPosBtn).CornerRadius = UDim.new(0, 7)

bindButton(SaveEggPosBtn, function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        State.SavedEggCFrame = hrp.CFrame
        SaveEggPosBtn.Text = "✅ Позицію збережено"
        task.delay(1.5, function()
            if SaveEggPosBtn then SaveEggPosBtn.Text = "📍 Зберегти позицію яйця" end
        end)
    end
end)

local EggInput = Instance.new("TextBox")
EggInput.LayoutOrder = 6
EggInput.Size = UDim2.new(1, -6, 0, 32)
EggInput.BackgroundColor3 = Colors.InputBg
EggInput.Text = ""
EggInput.PlaceholderText = "Назва яйця (порожньо = авто-пошук)"
EggInput.PlaceholderColor3 = Colors.SubText
EggInput.TextColor3 = Colors.Text
EggInput.Font = Enum.Font.Gotham
EggInput.TextSize = 12
EggInput.ClearTextOnFocus = false
EggInput.Parent = PageEggs
Instance.new("UICorner", EggInput).CornerRadius = UDim.new(0, 6)

trackConn(EggInput.FocusLost:Connect(function()
    State.SelectedEggName = string.gsub(EggInput.Text or "", "^%s*(.-)%s*$", "%1")
end))

local AutoHousesToggle = Instance.new("TextButton")
AutoHousesToggle.LayoutOrder = 1
AutoHousesToggle.Size = UDim2.new(1, -6, 0, 38)
AutoHousesToggle.BackgroundColor3 = Colors.Red
AutoHousesToggle.Text = "🏠 Авто-Домики (10 хв): ВИМК"
AutoHousesToggle.TextColor3 = Color3.new(1, 1, 1)
AutoHousesToggle.Font = Enum.Font.GothamBold
AutoHousesToggle.TextSize = 14
AutoHousesToggle.Parent = PageHouses
Instance.new("UICorner", AutoHousesToggle).CornerRadius = UDim.new(0, 7)

bindButton(AutoHousesToggle, function()
    State.AutoHouses = not State.AutoHouses
    if State.AutoHouses then
        AutoHousesToggle.BackgroundColor3 = Colors.Green
        AutoHousesToggle.Text = "🏠 Авто-Домики (10 хв): УВІМК"
        State.LastHouseRun = 0
    else
        AutoHousesToggle.BackgroundColor3 = Colors.Red
        AutoHousesToggle.Text = "🏠 Авто-Домики (10 хв): ВИМК"
    end
end)

HouseStatusLabel = Instance.new("TextLabel")
HouseStatusLabel.LayoutOrder = 2
HouseStatusLabel.Size = UDim2.new(1, -6, 0, 20)
HouseStatusLabel.BackgroundTransparency = 1
HouseStatusLabel.Text = "Очікування"
HouseStatusLabel.TextColor3 = Colors.Orange
HouseStatusLabel.Font = Enum.Font.GothamBold
HouseStatusLabel.TextSize = 12
HouseStatusLabel.Parent = PageHouses

local IntervalRow = Instance.new("Frame")
IntervalRow.LayoutOrder = 3
IntervalRow.Size = UDim2.new(1, -6, 0, 30)
IntervalRow.BackgroundTransparency = 1
IntervalRow.Parent = PageHouses

local IntervalBtns = {}
local function makeIntervalBtn(label, secs, idx)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.25, -4, 1, 0)
    b.Position = UDim2.new((idx - 1) * 0.25, 2, 0, 0)
    b.BackgroundColor3 = (State.HouseInterval == secs) and Colors.Orange or Colors.Card
    b.Text = label
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = IntervalRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    IntervalBtns[secs] = b
    bindButton(b, function()
        State.HouseInterval = secs
        for k, btn in pairs(IntervalBtns) do
            btn.BackgroundColor3 = (k == secs) and Colors.Orange or Colors.Card
        end
    end)
end

makeIntervalBtn("10 хв", 600, 1)
makeIntervalBtn("5 хв", 300, 2)
makeIntervalBtn("1 хв", 60, 3)
makeIntervalBtn("10 сек", 10, 4)

local RunHousesNowBtn = Instance.new("TextButton")
RunHousesNowBtn.LayoutOrder = 4
RunHousesNowBtn.Size = UDim2.new(1, -6, 0, 34)
RunHousesNowBtn.BackgroundColor3 = Colors.Orange
RunHousesNowBtn.Text = "⚡ Обійти домики зараз"
RunHousesNowBtn.TextColor3 = Color3.new(1, 1, 1)
RunHousesNowBtn.Font = Enum.Font.GothamBold
RunHousesNowBtn.TextSize = 13
RunHousesNowBtn.Parent = PageHouses
Instance.new("UICorner", RunHousesNowBtn).CornerRadius = UDim.new(0, 7)

bindButton(RunHousesNowBtn, function()
    task.spawn(runHousesRoutine)
end)

local AutoCapToggle = Instance.new("TextButton")
AutoCapToggle.LayoutOrder = 5
AutoCapToggle.Size = UDim2.new(1, -6, 0, 34)
AutoCapToggle.BackgroundColor3 = Colors.Red
AutoCapToggle.Text = "🎯 Авто-Точки (Капча): ВИМК"
AutoCapToggle.TextColor3 = Color3.new(1, 1, 1)
AutoCapToggle.Font = Enum.Font.GothamBold
AutoCapToggle.TextSize = 13
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

local CandyToggle = Instance.new("TextButton")
CandyToggle.LayoutOrder = 6
CandyToggle.Size = UDim2.new(1, -6, 0, 34)
CandyToggle.BackgroundColor3 = Colors.Red
CandyToggle.Text = "🍬 Авто-Цукерки: ВИМК"
CandyToggle.TextColor3 = Color3.new(1, 1, 1)
CandyToggle.Font = Enum.Font.GothamBold
CandyToggle.TextSize = 13
CandyToggle.Parent = PageHouses
Instance.new("UICorner", CandyToggle).CornerRadius = UDim.new(0, 7)

bindButton(CandyToggle, function()
    State.AutoCollectCandy = not State.AutoCollectCandy
    if State.AutoCollectCandy then
        CandyToggle.BackgroundColor3 = Colors.Green
        CandyToggle.Text = "🍬 Авто-Цукерки: УВІМК"
    else
        CandyToggle.BackgroundColor3 = Colors.Red
        CandyToggle.Text = "🍬 Авто-Цукерки: ВИМК"
    end
end)

local RouteRow = Instance.new("Frame")
RouteRow.LayoutOrder = 7
RouteRow.Size = UDim2.new(1, -6, 0, 32)
RouteRow.BackgroundTransparency = 1
RouteRow.Parent = PageHouses

local AddPointBtn = Instance.new("TextButton")
AddPointBtn.Size = UDim2.new(0.6, -3, 1, 0)
AddPointBtn.Position = UDim2.new(0, 0, 0, 0)
AddPointBtn.BackgroundColor3 = Colors.Blue
AddPointBtn.Text = "➕ Додати точку (0)"
AddPointBtn.TextColor3 = Color3.new(1, 1, 1)
AddPointBtn.Font = Enum.Font.GothamBold
AddPointBtn.TextSize = 12
AddPointBtn.Parent = RouteRow
Instance.new("UICorner", AddPointBtn).CornerRadius = UDim.new(0, 6)

local ClearPointsBtn = Instance.new("TextButton")
ClearPointsBtn.Size = UDim2.new(0.4, -3, 1, 0)
ClearPointsBtn.Position = UDim2.new(0.6, 3, 0, 0)
ClearPointsBtn.BackgroundColor3 = Colors.Card
ClearPointsBtn.Text = "🗑️ Авто"
ClearPointsBtn.TextColor3 = Colors.Text
ClearPointsBtn.Font = Enum.Font.GothamBold
ClearPointsBtn.TextSize = 12
ClearPointsBtn.Parent = RouteRow
Instance.new("UICorner", ClearPointsBtn).CornerRadius = UDim.new(0, 6)

bindButton(AddPointBtn, function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        table.insert(State.CustomHousePoints, hrp.CFrame)
        AddPointBtn.Text = "➕ Додати точку (" .. #State.CustomHousePoints .. ")"
    end
end)

bindButton(ClearPointsBtn, function()
    State.CustomHousePoints = {}
    AddPointBtn.Text = "➕ Додати точку (0)"
end)

local LogBtnsRow = Instance.new("Frame")
LogBtnsRow.LayoutOrder = 1
LogBtnsRow.Size = UDim2.new(1, -6, 0, 32)
LogBtnsRow.BackgroundTransparency = 1
LogBtnsRow.Parent = PageLogs

local CopyLogsBtn = Instance.new("TextButton")
CopyLogsBtn.Size = UDim2.new(0.34, -3, 1, 0)
CopyLogsBtn.Position = UDim2.new(0, 0, 0, 0)
CopyLogsBtn.BackgroundColor3 = Colors.Green
CopyLogsBtn.Text = "📋 Копіювати"
CopyLogsBtn.TextColor3 = Color3.new(1, 1, 1)
CopyLogsBtn.Font = Enum.Font.GothamBold
CopyLogsBtn.TextSize = 12
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
ClearLogsBtn.Parent = LogBtnsRow
Instance.new("UICorner", ClearLogsBtn).CornerRadius = UDim.new(0, 6)

LogScrollFrame = Instance.new("ScrollingFrame")
LogScrollFrame.LayoutOrder = 2
LogScrollFrame.Size = UDim2.new(1, -6, 0, 200)
LogScrollFrame.BackgroundColor3 = Colors.InputBg
LogScrollFrame.BorderSizePixel = 0
LogScrollFrame.ScrollBarThickness = 5
LogScrollFrame.ScrollBarImageColor3 = Colors.Orange
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
    State.AutoEggs = false
    State.AutoHouses = false
    State.AutoMinigame = false
    State.AutoCollectCandy = false
    applyEggAnimationSkip(false)
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

applyEggAnimationSkip(true)
switchTab(PageEggs, TabEggsBtn)
addLog("OK", "Готово")
