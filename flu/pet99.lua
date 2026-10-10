repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
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
    FullAutoFarm = false,
    AutoEggs = false,
    CustomEggCount = 0,
    MaxHatchDetected = 0,
    WorkingEggAmount = nil,
    CachedEggRemoteName = nil,
    CachedEggId = nil,
    LastCapturedEggRemote = nil,
    LastCapturedEggArgs = nil,
    SavedEggCFrame = nil,
    MaxUnlockedHouses = 0,
    HouseCooldownDefault = 600,
    HouseCooldownMap = {},
    IsVisitingHouses = false,
    CustomHousePoints = {},
    LastCapturedHouseRemote = nil,
    LastCapturedHouseArgs = nil,
    AutoMinigame = true,
    AutoFarmCoins = true,
    AutoJump20s = true,
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
        local ok, res = pcall(function() return r:InvokeServer(unpack(args)) end)
        return ok, res
    elseif r:IsA("RemoteEvent") then
        local ok = pcall(function() r:FireServer(unpack(args)) end)
        return ok, true
    end
    return false, nil
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

local function areEggsRenderingOnCamera()
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    for _, child in ipairs(cam:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") or string.find(string.lower(child.Name), "egg") then
            return true
        end
    end
    return false
end

local function fastTapEggAnimation()
    if VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(0, 0))
        end)
    end
end

task.spawn(function()
    while State.Running do
        if (State.AutoEggs or State.FullAutoFarm) and not State.IsVisitingHouses then
            if areEggsRenderingOnCamera() then
                fastTapEggAnimation()
                task.wait(0.04)
            else
                task.wait(0.1)
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
                    if type(args[2]) == "number" and args[2] >= 1 then
                        if args[2] > State.MaxHatchDetected then
                            State.MaxHatchDetected = args[2]
                        end
                        State.WorkingEggAmount = args[2]
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

local function detectPlayerMaxEggHatch()
    if State.CustomEggCount and State.CustomEggCount > 0 then
        return State.CustomEggCount
    end
    local bestMax = State.MaxHatchDetected or 0

    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local client = lib and lib:FindFirstChild("Client")
        if client then
            for _, modName in ipairs({"EggCmds", "CustomEggCmds"}) do
                local mObj = client:FindFirstChild(modName)
                if mObj then
                    local mod = require(mObj)
                    if type(mod) == "table" then
                        for _, fnName in ipairs({"GetMaxHatch", "GetMaxHatchCount", "GetMax"}) do
                            if type(mod[fnName]) == "function" then
                                local ok, val = pcall(mod[fnName])
                                if ok and tonumber(val) and tonumber(val) > bestMax then
                                    bestMax = tonumber(val)
                                end
                            end
                        end
                    end
                end
            end
            local saveMod = client:FindFirstChild("Save")
            if saveMod then
                local Save = require(saveMod)
                local data = Save and Save.Get and Save.Get()
                if data then
                    for _, k in ipairs({"EggsHatched", "CustomEggsHatched", "EggSlotsPurchased", "MaxEggs"}) do
                        local v = tonumber(data[k])
                        if v and v > bestMax then bestMax = v end
                    end
                end
            end
        end
    end)

    if bestMax > 0 then
        State.MaxHatchDetected = math.clamp(bestMax, 1, 150)
    end
    return State.MaxHatchDetected
end

local function findNearestEggCandidates()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {} end
    local myPos = hrp.Position

    local candidates = {}
    local seen = {}

    local function addCand(uid, attrId, pos, isCustom, obj)
        if not pos then return end
        local d = (pos - myPos).Magnitude
        if d > 70 then return end
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

local function findExactMaxHatchForEgg(remoteObj, eggArg)
    if State.CustomEggCount and State.CustomEggCount > 0 then
        local ok, res = pcall(function() return remoteObj:InvokeServer(eggArg, State.CustomEggCount) end)
        if ok and res ~= false and res ~= nil then
            State.WorkingEggAmount = State.CustomEggCount
            return true
        end
    end

    local detected = detectPlayerMaxEggHatch()
    if detected and detected > 0 then
        local ok, res = pcall(function() return remoteObj:InvokeServer(eggArg, detected) end)
        if ok and res ~= false and res ~= nil then
            State.WorkingEggAmount = detected
            return true
        end
    end

    if State.WorkingEggAmount and State.WorkingEggAmount > 0 then
        local ok, res = pcall(function() return remoteObj:InvokeServer(eggArg, State.WorkingEggAmount) end)
        if ok and res ~= false and res ~= nil then
            return true
        end
    end

    local ok79, res79 = pcall(function() return remoteObj:InvokeServer(eggArg, 79) end)
    if ok79 and res79 ~= false and res79 ~= nil then
        local low = 79
        local high = 120
        local best = 79
        while low <= high do
            local mid = math.floor((low + high) / 2)
            local okM, resM = pcall(function() return remoteObj:InvokeServer(eggArg, mid) end)
            if okM and resM ~= false and resM ~= nil then
                best = mid
                low = mid + 1
            else
                high = mid - 1
            end
        end
        State.WorkingEggAmount = best
        State.MaxHatchDetected = best
        return true
    end

    local ok1, res1 = pcall(function() return remoteObj:InvokeServer(eggArg, 1) end)
    if not (ok1 and res1 ~= false and res1 ~= nil) then
        return false
    end

    local low = 2
    local high = 99
    local best = 1
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local okM, resM = pcall(function() return remoteObj:InvokeServer(eggArg, mid) end)
        if okM and resM ~= false and resM ~= nil then
            best = mid
            low = mid + 1
        else
            high = mid - 1
        end
    end

    State.WorkingEggAmount = best
    if best > State.MaxHatchDetected then
        State.MaxHatchDetected = best
    end
    return true
end

local function fastHatchOnce()
    if State.IsVisitingHouses then return end

    local targetAmt = (State.CustomEggCount and State.CustomEggCount > 0 and State.CustomEggCount)
        or State.WorkingEggAmount
        or (State.MaxHatchDetected > 0 and State.MaxHatchDetected)
        or 79

    if State.CachedEggRemoteName and State.CachedEggId then
        local r = findRemote(State.CachedEggRemoteName)
        if r then
            local ok, res = pcall(function()
                if r:IsA("RemoteFunction") then
                    return r:InvokeServer(State.CachedEggId, targetAmt)
                else
                    r:FireServer(State.CachedEggId, targetAmt)
                    return true
                end
            end)
            if ok and res ~= false and res ~= nil then
                if EggStatusLabel then
                    EggStatusLabel.Text = string.format("🐣 Відкриття: %s (%dx)", tostring(State.CachedEggId), targetAmt)
                end
                fastTapEggAnimation()
                return
            end
        end
    end

    local cands = findNearestEggCandidates()
    if #cands == 0 and State.SavedEggCFrame then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - State.SavedEggCFrame.Position).Magnitude > 18 then
            pcall(function() hrp.CFrame = State.SavedEggCFrame end)
            task.wait(0.08)
            cands = findNearestEggCandidates()
        end
    end

    if #cands > 0 then
        local best = cands[1]
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and not State.SavedEggCFrame then
            State.SavedEggCFrame = hrp.CFrame
        end

        local remotesToTry = {"CustomEggs_Hatch", "Eggs_RequestPurchase"}
        local idsToTry = {}
        if best.uid then table.insert(idsToTry, best.uid) end
        if best.attrId and best.attrId ~= best.uid then table.insert(idsToTry, best.attrId) end

        for _, rName in ipairs(remotesToTry) do
            local r = findRemote(rName)
            if r and r:IsA("RemoteFunction") then
                for _, idVal in ipairs(idsToTry) do
                    if findExactMaxHatchForEgg(r, idVal) then
                        State.CachedEggRemoteName = rName
                        State.CachedEggId = idVal
                        if EggStatusLabel then
                            EggStatusLabel.Text = string.format("🐣 Відкриття: %s (%dx)", tostring(best.attrId or idVal), State.WorkingEggAmount or targetAmt)
                        end
                        fastTapEggAnimation()
                        return
                    end
                end
            end
        end

        pressKeyE()
        fastTapEggAnimation()
        if EggStatusLabel then
            EggStatusLabel.Text = string.format("🐣 Натискаю [E] біля: %s", tostring(best.attrId or best.uid))
        end
    else
        pressKeyE()
        if EggStatusLabel then
            EggStatusLabel.Text = "🐣 Підійди впритул до яйця і натисни 'Зберегти точку'"
        end
    end
end

task.spawn(function()
    while State.Running do
        if (State.AutoEggs or State.FullAutoFarm) and not State.IsVisitingHouses then
            task.spawn(function()
                pcall(fastHatchOnce)
            end)
            task.wait(0.08)
        else
            task.wait(0.2)
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
            if bPos and (bPos - myPos).Magnitude <= 115 then
                local uid = b.Name
                if dmgRemote and (dmgRemote:IsA("RemoteEvent") or dmgRemote.ClassName == "UnreliableRemoteEvent") then
                    pcall(function() dmgRemote:FireServer(uid) end)
                else
                    invokeRemote("Breakables_PlayerDealDamage", uid)
                end
                count = count + 1
                if count >= 4 then break end
            end
        end
    end)
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

local function teleportSafelyTo(targetCF)
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
        task.wait(0.04)
    end
end

local function visitReadyHousesAndReturn(forceAll)
    if State.IsVisitingHouses then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if not State.SavedEggCFrame then
        local cands = findNearestEggCandidates()
        if #cands > 0 then
            local eggPos = cands[1].pos
            State.SavedEggCFrame = CFrame.new(eggPos.X, hrp.Position.Y, eggPos.Z + 6)
        else
            State.SavedEggCFrame = hrp.CFrame
        end
    end

    local returnCF = State.SavedEggCFrame
    local groundY = returnCF.Position.Y
    local allHouses = scanAllUnlockedHouses(groundY, returnCF.Position)

    if #allHouses == 0 then
        if HouseStatusLabel then
            HouseStatusLabel.Text = "🏠 Додай свої відкриті двері кнопкою '+ Додати дім'"
        end
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
        if HouseStatusLabel then
            local mins = math.floor(minCd / 60)
            local secs = math.floor(minCd % 60)
            HouseStatusLabel.Text = string.format("🏠 Домики на КД (%02d:%02d) | Фарм яєць", mins, secs)
        end
        return
    end

    State.IsVisitingHouses = true

    local ok, err = pcall(function()
        for i, house in ipairs(readyHouses) do
            if not State.Running then break end
            char = LocalPlayer.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then break end

            if HouseStatusLabel then
                HouseStatusLabel.Text = string.format("🏠 Дім %d/%d [E]...", i, #readyHouses)
            end

            local doorGroundCF = CFrame.new(house.pos.X, groundY + 0.5, house.pos.Z)
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = doorGroundCF
            end)
            task.wait(0.08)

            triggerDoorFast(doorGroundCF.Position, house.instance)
            fireHouseRemotes(house)
            task.wait(0.12)
            pressKeyE()

            if isMinigameActiveOnScreen() then
                local waitStart = tick()
                while isMinigameActiveOnScreen() and (tick() - waitStart < 2.2) and State.Running do
                    task.wait(0.06)
                end
            end

            local _, newLiveCd = inspectDoorState(house.instance, house.pos)
            State.HouseCooldownMap[house.key] = tick() + (newLiveCd and newLiveCd > 0 and newLiveCd or State.HouseCooldownDefault)
        end
    end)

    if not ok then
        addLog("ERR", "Помилка: " .. tostring(err))
    end

    if returnCF and State.Running then
        teleportSafelyTo(returnCF)
        task.wait(0.08)
        pressKeyE()
    end

    State.IsVisitingHouses = false
    task.spawn(function()
        pcall(fastHatchOnce)
    end)
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
            task.wait(0.25)
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
    addLog("INFO", string.format("Позиція: %.1f, %.1f, %.1f | Пачка яєць: %s", myPos.X, myPos.Y, myPos.Z, tostring(State.WorkingEggAmount or State.CustomEggCount or 79)))

    local cands = findNearestEggCandidates()
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
MainFrame.Size = UDim2.new(0, 440, 0, 355)
MainFrame.Position = UDim2.new(0.5, -220, 0.5, -177)
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

local TabFarmBtn = createTabButton("⚡ Авто-Фарм", 0, 0.333)
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

local PageFarm = createPage()
local PageHouses = createPage()
local PageLogs = createPage()

local function switchTab(activePage, activeBtn)
    PageFarm.Visible = (activePage == PageFarm)
    PageHouses.Visible = (activePage == PageHouses)
    PageLogs.Visible = (activePage == PageLogs)

    for _, btn in ipairs({TabFarmBtn, TabHousesBtn, TabLogsBtn}) do
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
bindButton(TabLogsBtn, function() switchTab(PageLogs, TabLogsBtn) end)

local FullAutoToggle = Instance.new("TextButton")
FullAutoToggle.LayoutOrder = 1
FullAutoToggle.Size = UDim2.new(1, -6, 0, 40)
FullAutoToggle.BackgroundColor3 = Colors.Red
FullAutoToggle.Text = "⚡ АВТО: ЯЙЦЯ + МОНЕТИ + ДОМИКИ: ВИМК"
FullAutoToggle.TextColor3 = Color3.new(1, 1, 1)
FullAutoToggle.Font = Enum.Font.GothamBold
FullAutoToggle.TextSize = 13
FullAutoToggle.Parent = PageFarm
Instance.new("UICorner", FullAutoToggle).CornerRadius = UDim.new(0, 8)

EggStatusLabel = Instance.new("TextLabel")
EggStatusLabel.LayoutOrder = 2
EggStatusLabel.Size = UDim2.new(1, -6, 0, 18)
EggStatusLabel.BackgroundTransparency = 1
EggStatusLabel.Text = "🐣 Стань впритул до яйця і увімкни"
EggStatusLabel.TextColor3 = Colors.Orange
EggStatusLabel.Font = Enum.Font.GothamBold
EggStatusLabel.TextSize = 12
EggStatusLabel.Parent = PageFarm

HouseStatusLabel = Instance.new("TextLabel")
HouseStatusLabel.LayoutOrder = 3
HouseStatusLabel.Size = UDim2.new(1, -6, 0, 18)
HouseStatusLabel.BackgroundTransparency = 1
HouseStatusLabel.Text = "🏠 Домики: очікування"
HouseStatusLabel.TextColor3 = Colors.Green
HouseStatusLabel.Font = Enum.Font.GothamBold
HouseStatusLabel.TextSize = 12
HouseStatusLabel.Parent = PageFarm

bindButton(FullAutoToggle, function()
    State.FullAutoFarm = not State.FullAutoFarm
    if State.FullAutoFarm then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            State.SavedEggCFrame = hrp.CFrame
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
OnlyEggsToggle.Size = UDim2.new(1, -6, 0, 34)
OnlyEggsToggle.BackgroundColor3 = Colors.Card
OnlyEggsToggle.Text = "🐣 Тільки Швидкі Яйця: ВИМК"
OnlyEggsToggle.TextColor3 = Colors.Text
OnlyEggsToggle.Font = Enum.Font.GothamBold
OnlyEggsToggle.TextSize = 13
OnlyEggsToggle.Parent = PageFarm
Instance.new("UICorner", OnlyEggsToggle).CornerRadius = UDim.new(0, 7)

bindButton(OnlyEggsToggle, function()
    State.AutoEggs = not State.AutoEggs
    if State.AutoEggs then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and not State.SavedEggCFrame then
            State.SavedEggCFrame = hrp.CFrame
        end
        OnlyEggsToggle.BackgroundColor3 = Colors.Green
        OnlyEggsToggle.Text = "🐣 Тільки Швидкі Яйця: УВІМК"
    else
        OnlyEggsToggle.BackgroundColor3 = Colors.Card
        OnlyEggsToggle.Text = "🐣 Тільки Швидкі Яйця: ВИМК"
    end
end)

local EggCountInput = Instance.new("TextBox")
EggCountInput.LayoutOrder = 5
EggCountInput.Size = UDim2.new(1, -6, 0, 32)
EggCountInput.BackgroundColor3 = Colors.InputBg
EggCountInput.Text = "79"
EggCountInput.PlaceholderText = "Кількість яєць (напр. 79, або 0 = Авто)"
EggCountInput.PlaceholderColor3 = Colors.SubText
EggCountInput.TextColor3 = Colors.Orange
EggCountInput.Font = Enum.Font.GothamBold
EggCountInput.TextSize = 13
EggCountInput.ClearTextOnFocus = false
EggCountInput.Parent = PageFarm
Instance.new("UICorner", EggCountInput).CornerRadius = UDim.new(0, 6)

State.CustomEggCount = 79
trackConn(EggCountInput.FocusLost:Connect(function()
    local n = tonumber(EggCountInput.Text)
    if n and n >= 1 then
        State.CustomEggCount = math.floor(n)
        State.WorkingEggAmount = math.floor(n)
    else
        State.CustomEggCount = 0
        State.WorkingEggAmount = nil
    end
end))

local PosRow = Instance.new("Frame")
PosRow.LayoutOrder = 6
PosRow.Size = UDim2.new(1, -6, 0, 34)
PosRow.BackgroundTransparency = 1
PosRow.Parent = PageFarm

local SaveEggPosBtn = Instance.new("TextButton")
SaveEggPosBtn.Size = UDim2.new(0.62, -3, 1, 0)
SaveEggPosBtn.Position = UDim2.new(0, 0, 0, 0)
SaveEggPosBtn.BackgroundColor3 = Colors.Blue
SaveEggPosBtn.Text = "📍 Зберегти точку біля яйця"
SaveEggPosBtn.TextColor3 = Color3.new(1, 1, 1)
SaveEggPosBtn.Font = Enum.Font.GothamBold
SaveEggPosBtn.TextSize = 12
SaveEggPosBtn.Parent = PosRow
Instance.new("UICorner", SaveEggPosBtn).CornerRadius = UDim.new(0, 6)

local ReturnToEggBtn = Instance.new("TextButton")
ReturnToEggBtn.Size = UDim2.new(0.38, -3, 1, 0)
ReturnToEggBtn.Position = UDim2.new(0.62, 3, 0, 0)
ReturnToEggBtn.BackgroundColor3 = Colors.Card
ReturnToEggBtn.Text = "🔙 До яйця"
ReturnToEggBtn.TextColor3 = Colors.Text
ReturnToEggBtn.Font = Enum.Font.GothamBold
ReturnToEggBtn.TextSize = 12
ReturnToEggBtn.Parent = PosRow
Instance.new("UICorner", ReturnToEggBtn).CornerRadius = UDim.new(0, 6)

bindButton(SaveEggPosBtn, function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        State.SavedEggCFrame = hrp.CFrame
        SaveEggPosBtn.Text = "✅ Точку збережено!"
        task.delay(1.5, function()
            if SaveEggPosBtn then SaveEggPosBtn.Text = "📍 Зберегти точку біля яйця" end
        end)
    end
end)

bindButton(ReturnToEggBtn, function()
    if State.SavedEggCFrame then
        teleportSafelyTo(State.SavedEggCFrame)
    end
end)

local RunHousesNowBtn = Instance.new("TextButton")
RunHousesNowBtn.LayoutOrder = 1
RunHousesNowBtn.Size = UDim2.new(1, -6, 0, 38)
RunHousesNowBtn.BackgroundColor3 = Colors.Orange
RunHousesNowBtn.Text = "⚡ Швидко обійти домики [E] і до яйця"
RunHousesNowBtn.TextColor3 = Color3.new(1, 1, 1)
RunHousesNowBtn.Font = Enum.Font.GothamBold
RunHousesNowBtn.TextSize = 13
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
RouteRow.Parent = PageHouses

local AddPointBtn = Instance.new("TextButton")
AddPointBtn.Size = UDim2.new(0.62, -3, 1, 0)
AddPointBtn.Position = UDim2.new(0, 0, 0, 0)
AddPointBtn.BackgroundColor3 = Colors.Blue
AddPointBtn.Text = "➕ Додати відкритий дім (0)"
AddPointBtn.TextColor3 = Color3.new(1, 1, 1)
AddPointBtn.Font = Enum.Font.GothamBold
AddPointBtn.TextSize = 12
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
ClearPointsBtn.Parent = RouteRow
Instance.new("UICorner", ClearPointsBtn).CornerRadius = UDim.new(0, 6)

bindButton(AddPointBtn, function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        table.insert(State.CustomHousePoints, hrp.CFrame)
        AddPointBtn.Text = "➕ Додати відкритий дім (" .. #State.CustomHousePoints .. ")"
        HouseStatusLabel.Text = "🏠 Додано відкритий дім #" .. #State.CustomHousePoints
    end
end)

bindButton(ClearPointsBtn, function()
    State.CustomHousePoints = {}
    State.HouseCooldownMap = {}
    AddPointBtn.Text = "➕ Додати відкритий дім (0)"
    HouseStatusLabel.Text = "🏠 Точки скинуто (Авто-пошук)"
end)

local LimitRow = Instance.new("Frame")
LimitRow.LayoutOrder = 3
LimitRow.Size = UDim2.new(1, -6, 0, 30)
LimitRow.BackgroundTransparency = 1
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

local JumpToggle = Instance.new("TextButton")
JumpToggle.LayoutOrder = 5
JumpToggle.Size = UDim2.new(1, -6, 0, 32)
JumpToggle.BackgroundColor3 = Colors.Green
JumpToggle.Text = "🦘 Стрибок раз на 20 сек (Анти-АФК): УВІМК"
JumpToggle.TextColor3 = Color3.new(1, 1, 1)
JumpToggle.Font = Enum.Font.GothamBold
JumpToggle.TextSize = 12
JumpToggle.Parent = PageHouses
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
    State.FullAutoFarm = false
    State.AutoEggs = false
    State.AutoMinigame = false
    State.AutoFarmCoins = false
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
addLog("OK", "Готово")
