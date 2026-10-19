local _CREATOR = "by pufyftyk"
local _PROJECT = "PS99 Autonomous Winter Yeti & Tunnel Hub Definitive Edition"
local _VERSION = "9.9.0"

pcall(function()
    local _players = game:GetService("Players")
    local _lp = _players.LocalPlayer
    local _vu = game:GetService("VirtualUser")

    if type(getconnections) == "function" then
        pcall(function()
            for _, conn in ipairs(getconnections(_lp.Idled)) do
                pcall(function()
                    if conn and conn.Disable then conn:Disable() end
                end)
            end
        end)
    end

    pcall(function()
        _lp.Idled:Connect(function()
            pcall(function()
                if _vu then
                    _vu:CaptureController()
                    _vu:ClickButton2(Vector2.new(0, 0))
                end
            end)
        end)
    end)

    task.spawn(function()
        local count = 0
        while true do
            task.wait(10)
            count = count + 1
            pcall(function()
                if _vu then
                    _vu:CaptureController()
                    _vu:ClickButton2(Vector2.new(0, 0))
                end
            end)
            if count % 6 == 0 then
                pcall(function()
                    local ch = _lp.Character
                    local hu = ch and ch:FindFirstChildOfClass("Humanoid")
                    if hu then hu.Jump = true end
                end)
            end
        end
    end)
end)

pcall(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local Camera = Workspace.CurrentCamera
while not Camera do
    task.wait(0.1)
    Camera = Workspace.CurrentCamera
end

local getgenv = getgenv or function() return _G end
local env = getgenv()

if env.DiamondMountainHubCleanup then
    pcall(env.DiamondMountainHubCleanup)
end

local ActiveConnections = {}
local function trackConn(conn)
    if conn then table.insert(ActiveConnections, conn) end
    return conn
end

local Points = {
    Chest1 = CFrame.new(-30030.2, 752.5, 30984.2),
    Chest2 = CFrame.new(-29976.0, 752.5, 31014.7),
    Chest3 = CFrame.new(-29938.7, 752.5, 30979.1),
    TunnelEgg = CFrame.new(-29905.1, 752.5, 30932.4),
    FarmEgg = CFrame.new(-30137.7, 752.6, 30916.3),
    Yeti = CFrame.new(-30046.1, 754.9, 31107.3),
}

local AcornsTarget = 2600000000000

local StartClock = os.clock()
local StartTimeString = os.date("%H:%M:%S")

local State = {
    Running = true,
    StartTime = StartClock,
    StartTimeStr = StartTimeString,
    StartGems = nil,
    CurrentGems = 0,
    GemsGained = 0,
    StartAcorns = nil,
    CurrentAcorns = 0,
    YetiKills = 0,
    YetiCooldownEnd = 0,
    TunnelOpen = false,
    TunnelTimeRemaining = 0,
    LastTunnelCheck = 0,
    CurrentPhase = "INIT",
    CurrentActionText = "SYSTEM INITIALIZING...",
    LastFlagTime = StartClock + 15,
    LastHatchTime = 0,
    LastMerchantTime = StartClock + 25,
    LastUltimateTime = 0,
    LastOrbCollectTime = 0,
    LastLogMessage = "System initialized.",
    AutoTunnelEnabled = true,
    FarmYetiEnabled = true,
    MagnetFlagEnabled = true,
    OledModeActive = false
}

local function pushLog(msg)
    State.LastLogMessage = msg
end

local NetworkRemotes = {}
pcall(function()
    local net = ReplicatedStorage:FindFirstChild("Network")
    if net then
        for _, child in ipairs(net:GetChildren()) do
            if child:IsA("RemoteFunction") or child:IsA("RemoteEvent") then
                NetworkRemotes[child.Name] = child
            end
        end
    end
end)

local ClientModules = {}
pcall(function()
    local library = ReplicatedStorage:FindFirstChild("Library")
    if library then
        local client = library:FindFirstChild("Client")
        if client then
            for _, child in ipairs(client:GetChildren()) do
                if child:IsA("ModuleScript") then
                    pcall(function()
                        ClientModules[child.Name] = require(child)
                    end)
                end
            end
        end
    end
end)

local function fireNetwork(name, ...)
    local args = {...}
    local remote = NetworkRemotes[name]
    if remote then
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(unpack(args))
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(unpack(args))
            end
        end)
    end
    if ClientModules["Network"] and ClientModules["Network"].Fire then
        pcall(function()
            ClientModules["Network"].Fire(name, unpack(args))
        end)
    end
    return nil
end

local function invokeNetwork(name, ...)
    local args = {...}
    local remote = NetworkRemotes[name]
    if remote and remote:IsA("RemoteFunction") then
        local res = nil
        pcall(function() res = remote:InvokeServer(unpack(args)) end)
        return res
    end
    if ClientModules["Network"] and ClientModules["Network"].Invoke then
        local res = nil
        pcall(function() res = ClientModules["Network"].Invoke(name, unpack(args)) end)
        return res
    end
    return nil
end

local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChildWhichIsA("BasePart")
end

local function teleportSafely(targetCFrame, offset)
    local hrp = getHRP()
    if not hrp then return false end
    local finalCF = targetCFrame
    if offset then
        finalCF = targetCFrame * CFrame.new(offset.X, offset.Y, offset.Z)
    end
    hrp.CFrame = finalCF
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

local function collectGroundDrops()
    local now = os.clock()
    if now - State.LastOrbCollectTime < 0.25 then return end
    State.LastOrbCollectTime = now

    pcall(function()
        local things = Workspace:FindFirstChild("__THINGS")
        if not things then return end

        local orbsFolder = things:FindFirstChild("Orbs")
        if orbsFolder then
            local collected = {}
            for _, orb in ipairs(orbsFolder:GetChildren()) do
                table.insert(collected, orb.Name)
                if #collected >= 30 then break end
            end
            if #collected > 0 then
                fireNetwork("Orbs: Collect", collected)
                fireNetwork("Orbs_Collect", collected)
                fireNetwork("Orb_Pickup", collected)
            end
        end

        local lootbagsFolder = things:FindFirstChild("Lootbags")
        if lootbagsFolder then
            local bags = {}
            for _, bag in ipairs(lootbagsFolder:GetChildren()) do
                table.insert(bags, bag.Name)
                if #bags >= 20 then break end
            end
            if #bags > 0 then
                fireNetwork("Lootbags_Claim", bags)
                fireNetwork("Lootbag_Claim", bags)
            end
        end
    end)
end

local function parseFormattedNumber(str)
    if not str or type(str) ~= "string" then return 0 end
    local sClean = string.gsub(str, "[,%+%$%s]", "")
    local val, suf = string.match(sClean, "^([%d%.]+)%s*([kKmMbBtT]?)$")
    if not val then
        val, suf = string.match(sClean, "([%d%.]+)%s*([kKmMbBtT])")
    end
    if not val then
        val = string.match(sClean, "([%d%.]+)")
        suf = ""
    end
    if not val then return 0 end
    local n = tonumber(val) or 0
    local sLower = string.lower(suf or "")
    if sLower == "k" then return n * 1e3
    elseif sLower == "m" then return n * 1e6
    elseif sLower == "b" then return n * 1e9
    elseif sLower == "t" then return n * 1e12
    end
    return n
end

local function formatCompact(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    end
    return tostring(math.floor(n))
end

local function formatTimer(seconds)
    local s = math.max(0, math.floor(seconds))
    local mins = math.floor(s / 60)
    local secs = s % 60
    return string.format("%02d:%02d", mins, secs)
end

local function formatDuration(seconds)
    local s = math.max(0, math.floor(seconds))
    local hrs = math.floor(s / 3600)
    local mins = math.floor((s % 3600) / 60)
    local secs = s % 60
    return string.format("%02d:%02d:%02d", hrs, mins, secs)
end

local ScreenGui = nil

local function updateCurrencies()
    pcall(function()
        local gems = 0
        local acorns = 0

        pcall(function()
            if ClientModules["CurrencyCmds"] and ClientModules["CurrencyCmds"].Get then
                local g = ClientModules["CurrencyCmds"].Get("Diamonds")
                if g and tonumber(g) then gems = tonumber(g) end
                for _, aName in ipairs({"Acorns", "Event Coins", "Gingerbread", "Snowflakes"}) do
                    local a = ClientModules["CurrencyCmds"].Get(aName)
                    if a and tonumber(a) and tonumber(a) > 0 then acorns = tonumber(a); break end
                end
            end
        end)

        if gems == 0 or acorns == 0 then
            pcall(function()
                if ClientModules["Save"] then
                    local data = ClientModules["Save"].Get()
                    if data then
                        if data.Diamonds and gems == 0 then gems = tonumber(data.Diamonds) or gems end
                        if data.Acorns and acorns == 0 then acorns = tonumber(data.Acorns) or acorns end
                        if data.Inventory and data.Inventory.Currency then
                            local c = data.Inventory.Currency
                            if c.Diamonds and gems == 0 then gems = tonumber(c.Diamonds) or gems end
                            if c.Acorns and acorns == 0 then acorns = tonumber(c.Acorns) or acorns end
                            if c["Event Coins"] and acorns == 0 then acorns = tonumber(c["Event Coins"]) or acorns end
                        end
                    end
                end
            end)
        end

        if gems == 0 or acorns == 0 then
            pcall(function()
                local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                if leaderstats then
                    local d = leaderstats:FindFirstChild("Diamonds") or leaderstats:FindFirstChild("Gems")
                    if d and d.Value and gems == 0 then gems = tonumber(d.Value) or 0 end
                    local a = leaderstats:FindFirstChild("Acorns") or leaderstats:FindFirstChild("Event Coins")
                    if a and a.Value and acorns == 0 then acorns = tonumber(a.Value) or 0 end
                end
            end)
        end

        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                for _, desc in ipairs(pg:GetDescendants()) do
                    pcall(function()
                        if desc:IsA("TextLabel") and desc.Visible and desc.Text and desc.Text ~= "" then
                            local isSelf = false
                            if ScreenGui and (desc == ScreenGui or desc:IsDescendantOf(ScreenGui)) then isSelf = true end
                            if not isSelf then
                                local pName = string.lower(desc.Parent and desc.Parent.Name or "")
                                local sName = string.lower(desc.Name)
                                local txt = desc.Text
                                if string.find(pName, "acorn") or string.find(sName, "acorn") or string.find(pName, "event") or string.find(sName, "event") then
                                    local parsed = parseFormattedNumber(txt)
                                    if parsed > 0 then acorns = parsed end
                                elseif string.find(pName, "diamond") or string.find(sName, "diamond") or string.find(pName, "gem") or string.find(sName, "gem") then
                                    local parsed = parseFormattedNumber(txt)
                                    if parsed > 0 then gems = parsed end
                                end
                            end
                        end
                    end)
                end
            end
        end)

        if gems > 0 then
            State.CurrentGems = gems
            if State.StartGems == nil then State.StartGems = gems end
            State.GemsGained = math.max(0, gems - State.StartGems)
        end
        if acorns > 0 then
            State.CurrentAcorns = acorns
            if State.StartAcorns == nil then State.StartAcorns = acorns end
        end
    end)
end

local function getBreakablesFolder()
    local things = Workspace:FindFirstChild("__THINGS")
    if things then
        return things:FindFirstChild("Breakables")
    end
    return nil
end

local function findYetiBoss()
    local targetPos = Points.Yeti.Position
    local bestObj = nil
    local bestUid = nil
    local bestDist = 350
    pcall(function()
        local things = Workspace:FindFirstChild("__THINGS")
        if things then
            for _, folderName in ipairs({"Bosses", "Boss", "Breakables", "CustomBreakables", "EventBreakables", "Event"}) do
                local f = things:FindFirstChild(folderName)
                if f then
                    for _, child in ipairs(f:GetChildren()) do
                        local lName = string.lower(child.Name)
                        local isCandidate = string.find(lName, "yeti") or string.find(lName, "boss") or string.find(lName, "wall") or string.find(lName, "abominable")
                        local p = child:IsA("Model") and (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")) or (child:IsA("BasePart") and child)
                        local pPos = p and p.Position or (child:IsA("Model") and child:GetPivot().Position)
                        if pPos then
                            local d = (pPos - targetPos).Magnitude
                            if isCandidate and d <= 300 then
                                if d < bestDist then
                                    bestDist = d
                                    bestObj = child
                                    bestUid = child.Name
                                end
                            elseif d <= 150 then
                                if d < bestDist then
                                    bestDist = d
                                    bestObj = child
                                    bestUid = child.Name
                                end
                            end
                        else
                            if isCandidate then
                                bestObj = child
                                bestUid = child.Name
                            end
                        end
                    end
                end
            end
        end
    end)
    if bestObj then return bestObj, bestUid or "Yeti", bestDist end
    pcall(function()
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Model") then
                local lName = string.lower(child.Name)
                if string.find(lName, "yeti") or string.find(lName, "abominable") then
                    local p = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
                    local pPos = p and p.Position or child:GetPivot().Position
                    if pPos then
                        local d = (pPos - targetPos).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestObj = child
                            bestUid = child.Name
                        end
                    else
                        bestObj = child
                        bestUid = child.Name
                    end
                end
            end
        end
    end)
    if bestObj then return bestObj, bestUid or "Yeti", bestDist end
    if ClientModules["BreakableCmds"] then
        pcall(function()
            local all = ClientModules["BreakableCmds"].All()
            if type(all) == "table" then
                for uid, data in pairs(all) do
                    if data and data.pos then
                        local d = (data.pos - targetPos).Magnitude
                        if d <= 150 and d < bestDist then
                            bestDist = d
                            bestUid = uid
                            bestObj = uid
                        end
                    end
                end
            end
        end)
    end
    if bestObj then return bestObj, bestUid or "Yeti", bestDist end
    return nil, nil, nil
end

local function findBreakableNear(cframeTarget, maxRadius)
    local targetPos = cframeTarget.Position
    local bestObj = nil
    local bestDist = maxRadius or 45
    local bestUid = nil
    pcall(function()
        local things = Workspace:FindFirstChild("__THINGS")
        if things then
            for _, fName in ipairs({"Breakables", "Chests", "CustomBreakables", "Bosses"}) do
                local bFolder = things:FindFirstChild(fName)
                if bFolder then
                    for _, child in ipairs(bFolder:GetChildren()) do
                        local p = child:IsA("Model") and (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")) or (child:IsA("BasePart") and child)
                        if p then
                            local d = (p.Position - targetPos).Magnitude
                            if d <= bestDist then
                                bestDist = d
                                bestObj = child
                                bestUid = child.Name
                            end
                        end
                    end
                end
            end
        end
    end)
    if not bestObj and ClientModules["BreakableCmds"] then
        pcall(function()
            local all = ClientModules["BreakableCmds"].All()
            if type(all) == "table" then
                for uid, data in pairs(all) do
                    if data and data.pos then
                        local d = (data.pos - targetPos).Magnitude
                        if d <= bestDist then
                            bestDist = d
                            bestUid = uid
                            bestObj = uid
                        end
                    end
                end
            end
        end)
    end
    if not bestObj then
        pcall(function()
            for _, desc in ipairs(Workspace:GetChildren()) do
                if desc:IsA("Model") then
                    local lName = string.lower(desc.Name)
                    if string.find(lName, "yeti") or string.find(lName, "boss") or string.find(lName, "wall") or string.find(lName, "chest") then
                        local p = desc.PrimaryPart or desc:FindFirstChildWhichIsA("BasePart")
                        if p then
                            local d = (p.Position - targetPos).Magnitude
                            if d <= bestDist then
                                bestDist = d
                                bestObj = desc
                                bestUid = desc.Name
                            end
                        end
                    end
                end
            end
        end)
    end
    return bestObj, bestUid, bestDist
end

local function attackBreakableUID(uid, obj)
    if not uid then return end
    pcall(function()
        fireNetwork("Breakables_PlayerDealDamage", uid)
        fireNetwork("Breakables_JoinPet", uid)
        fireNetwork("Breakables_JoinPetAll", uid)
    end)
    if ClientModules["BreakableCmds"] and ClientModules["BreakableCmds"].Damage then
        pcall(function() ClientModules["BreakableCmds"].Damage(uid) end)
    end
    if ClientModules["PetCmds"] and ClientModules["PetCmds"].Attack then
        pcall(function() ClientModules["PetCmds"].Attack(uid) end)
    end
end

local function farmAmbientBreakables(centerCFrame, radius)
    local bFolder = getBreakablesFolder()
    if not bFolder then return end
    local centerPos = centerCFrame.Position
    local maxR = radius or 45
    local count = 0
    for _, child in ipairs(bFolder:GetChildren()) do
        local p = child:IsA("Model") and (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")) or (child:IsA("BasePart") and child)
        if p then
            local d = (p.Position - centerPos).Magnitude
            if d <= maxR then
                attackBreakableUID(child.Name, child)
                count = count + 1
                if count >= 6 then break end
            end
        end
    end
    collectGroundDrops()
end

local function tapBossVirtual(bossObj, uid)
    if not uid then return end
    local id = tostring(uid)
    pcall(function()
        for _ = 1, 3 do
            fireNetwork("Breakables_PlayerDealDamage", id)
        end
        fireNetwork("Breakables_JoinPet", id)
        fireNetwork("Breakables_JoinPetAll", id)
    end)
    if ClientModules["BreakableCmds"] and ClientModules["BreakableCmds"].Damage then
        pcall(function() ClientModules["BreakableCmds"].Damage(id) end)
    end
end
local sendAllPetsToBoss = tapBossVirtual

local function useUltimateAbility()
    local now = os.clock()
    if now - State.LastUltimateTime < 2.0 then return end
    State.LastUltimateTime = now
    pcall(function()
        fireNetwork("Ultimate_Activate")
        fireNetwork("Ultimates_Activate")
        fireNetwork("Ultimate_Cast")
    end)
    if ClientModules["UltimateCmds"] then
        pcall(function()
            ClientModules["UltimateCmds"].Activate()
        end)
    end
end

local function getSafeHatchCount()
    local count = 1
    pcall(function()
        if ClientModules["EggCmds"] and ClientModules["EggCmds"].GetMaxHatch then
            count = ClientModules["EggCmds"].GetMaxHatch()
        elseif ClientModules["Save"] then
            local data = ClientModules["Save"].Get()
            if data and data.EggHatchCount then
                count = tonumber(data.EggHatchCount) or 1
            elseif data and data.MaxHatch then
                count = tonumber(data.MaxHatch) or 1
            end
        end
    end)
    if not count or count < 1 then count = 1 end
    if count > 8 and not ClientModules["EggCmds"] then count = 1 end
    return count
end

local function findNearestEgg(pos, maxDist)
    local targetPos = pos or (getHRP() and getHRP().Position)
    if not targetPos then return nil, nil end
    local maxD = maxDist or 45
    local bestName = nil
    local bestPrompt = nil
    local bestDist = maxD
    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                local pPart = desc.Parent:IsA("BasePart") and desc.Parent or desc.Parent:FindFirstChildWhichIsA("BasePart")
                local pPos = pPart and pPart.Position or (desc.Parent:IsA("Model") and desc.Parent:GetPivot().Position)
                if pPos then
                    local d = (pPos - targetPos).Magnitude
                    if d <= maxD then
                        local act = string.lower(desc.ActionText or "")
                        local obj = string.lower(desc.ObjectText or "")
                        if string.find(act, "egg") or string.find(act, "hatch") or string.find(act, "open") or string.find(obj, "egg") then
                            if d < bestDist then
                                bestDist = d
                                bestPrompt = desc
                                if desc.ObjectText and desc.ObjectText ~= "" then bestName = desc.ObjectText end
                            end
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        local things = Workspace:FindFirstChild("__THINGS")
        if things then
            for _, fName in ipairs({"CustomEggs", "Eggs", "EggMachines", "Podiums"}) do
                local f = things:FindFirstChild(fName)
                if f then
                    for _, eggObj in ipairs(f:GetChildren()) do
                        local p = eggObj:IsA("Model") and (eggObj.PrimaryPart or eggObj:FindFirstChildWhichIsA("BasePart")) or (eggObj:IsA("BasePart") and eggObj)
                        if p then
                            local d = (p.Position - targetPos).Magnitude
                            if d < bestDist then
                                bestDist = d
                                bestName = eggObj.Name
                                local pr = eggObj:FindFirstChildWhichIsA("ProximityPrompt", true)
                                if pr then bestPrompt = pr end
                            end
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        if ClientModules["EggCmds"] and ClientModules["EggCmds"].GetNearestEgg then
            local eg = ClientModules["EggCmds"].GetNearestEgg()
            if type(eg) == "string" and eg ~= "" then bestName = eg end
            if type(eg) == "table" and eg.Name then bestName = eg.Name end
        end
    end)
    return bestName, bestPrompt
end

local function hatchNearestEgg(eggCFrame, batchCount)
    local now = os.clock()
    if now - State.LastHatchTime < 0.5 then return end
    State.LastHatchTime = now
    local hrp = getHRP()
    if not hrp then return end
    local safeBatch = batchCount or getSafeHatchCount()
    local targetPos = eggCFrame and eggCFrame.Position or hrp.Position
    local eggName, prompt = findNearestEgg(targetPos, 45)
    if prompt and fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
    end
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        if vim then
            vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.04)
            vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end)
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g.Enabled and g ~= ScreenGui then
                    local gName = string.lower(g.Name)
                    if string.find(gName, "egg") or string.find(gName, "hatch") then
                        findAndClickButton(g, {"hatch", "open", "max", "auto", "buy", "yes", "e"})
                    end
                end
            end
        end
    end)
    local targetEgg = eggName or "Tunnel Egg"
    pcall(function()
        fireNetwork("Eggs_RequestPurchase", targetEgg, safeBatch)
        fireNetwork("Eggs: RequestPurchase", targetEgg, safeBatch)
        fireNetwork("Eggs_RequestHatch", targetEgg, safeBatch)
        fireNetwork("Eggs: RequestHatch", targetEgg, safeBatch)
        fireNetwork("Eggs: Hatch", targetEgg, safeBatch)
        fireNetwork("Eggs_Hatch", targetEgg, safeBatch)
    end)
    if ClientModules["EggCmds"] then
        pcall(function()
            if ClientModules["EggCmds"].RequestPurchase then
                ClientModules["EggCmds"].RequestPurchase(targetEgg, safeBatch)
            elseif ClientModules["EggCmds"].Purchase then
                ClientModules["EggCmds"].Purchase(targetEgg, safeBatch)
            end
        end)
    end
end

local function checkTunnelStatus()
    local c1 = findBreakableNear(Points.Chest1, 45)
    if c1 then return true end
    local c2 = findBreakableNear(Points.Chest2, 45)
    if c2 then return true end
    local c3 = findBreakableNear(Points.Chest3, 45)
    if c3 then return true end

    local isOpenByPart = false
    pcall(function()
        local things = Workspace:FindFirstChild("__THINGS")
        if things then
            local gates = things:FindFirstChild("Gates") or things:FindFirstChild("Barriers") or things:FindFirstChild("Doors")
            if gates then
                for _, g in ipairs(gates:GetChildren()) do
                    if string.find(string.lower(g.Name), "tunnel") then
                        if g.Transparency >= 0.5 or not g.CanCollide then
                            isOpenByPart = true
                        end
                    end
                end
            end
        end
    end)
    return isOpenByPart
end

local function findNearestFlagPole(pos, maxDist)
    local targetPos = pos or (getHRP() and getHRP().Position)
    if not targetPos then return nil, nil, nil end
    local bestPole = nil
    local bestPrompt = nil
    local bestPos = nil
    local bestD = maxDist or 800
    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                local act = string.lower(desc.ActionText or "")
                local obj = string.lower(desc.ObjectText or "")
                local pName = string.lower(desc.Parent and desc.Parent.Name or "")
                local ppName = string.lower(desc.Parent and desc.Parent.Parent and desc.Parent.Parent.Name or "")
                local isFlag = string.find(act, "flag") or string.find(obj, "flag") or string.find(pName, "flag") or string.find(ppName, "flag") or string.find(pName, "pole") or string.find(ppName, "pole") or string.find(act, "place") or string.find(act, "plant")
                if isFlag then
                    local pPart = desc.Parent:IsA("BasePart") and desc.Parent or desc.Parent:FindFirstChildWhichIsA("BasePart")
                    local pPos = pPart and pPart.Position or (desc.Parent:IsA("Model") and desc.Parent:GetPivot().Position)
                    if pPos then
                        local d = (pPos - targetPos).Magnitude
                        if d <= bestD then
                            bestD = d
                            bestPole = desc.Parent
                            bestPrompt = desc
                            bestPos = pPos
                        end
                    end
                end
            end
        end
    end)
    if bestPole then return bestPole, bestPrompt, bestPos end
    pcall(function()
        local things = Workspace:FindFirstChild("__THINGS")
        local containers = {things, Workspace}
        for _, cont in ipairs(containers) do
            if cont then
                for _, folderName in ipairs({"FlagPoles", "Flags", "Poles", "ZoneFlags"}) do
                    local folder = cont:FindFirstChild(folderName)
                    if folder then
                        for _, p in ipairs(folder:GetChildren()) do
                            local pPart = p:IsA("Model") and (p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart")) or (p:IsA("BasePart") and p)
                            if pPart and pPart.Position then
                                local d = (pPart.Position - targetPos).Magnitude
                                if d <= bestD then
                                    bestD = d
                                    bestPole = p
                                    bestPrompt = p:FindFirstChildWhichIsA("ProximityPrompt", true)
                                    bestPos = pPart.Position
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    return bestPole, bestPrompt, bestPos
end

local function clickSmartButton(btn)
    if not btn then return end
    pcall(function()
        if firesignal then
            firesignal(btn.Activated)
            firesignal(btn.MouseButton1Click)
            firesignal(btn.MouseButton1Down)
            firesignal(btn.MouseButton1Up)
        end
        if btn.MouseButton1Click then btn.MouseButton1Click:Fire() end
        if btn.Activated then btn.Activated:Fire() end
    end)
end

local function isSafeGuiContainer(container)
    if not container then return false end
    local c = container
    while c and c ~= game do
        local cName = string.lower(c.Name)
        if string.find(cName, "hud") or string.find(cName, "hotbar") or string.find(cName, "enchant") or string.find(cName, "mastery") or string.find(cName, "coregui") or string.find(cName, "robux") or string.find(cName, "gamepass") or string.find(cName, "topbar") or string.find(cName, "sidemenu") then
            return false
        end
        c = c.Parent
    end
    return true
end

local function findAndClickButton(container, keywords)
    if not container or not isSafeGuiContainer(container) then return false end
    for _, desc in ipairs(container:GetDescendants()) do
        if desc:IsA("GuiButton") and desc.Visible then
            local btnName = string.lower(desc.Name)
            local btnText = desc:IsA("TextButton") and string.lower(desc.Text or "") or ""
            local combined = btnName .. " " .. btnText
            if not (string.find(combined, "enchant") or string.find(combined, "robux") or string.find(combined, "r$") or string.find(combined, "gamepass") or string.find(combined, "pass") or string.find(combined, "buy slot") or string.find(combined, "unlock slot") or string.find(combined, "+1")) then
                local matched = false
                for _, kw in ipairs(keywords) do
                    if string.find(btnName, kw) or string.find(btnText, kw) then
                        matched = true
                        break
                    end
                end
                if not matched then
                    for _, child in ipairs(desc:GetChildren()) do
                        if child:IsA("TextLabel") and child.Visible then
                            local childText = string.lower(child.Text or "")
                            if not (string.find(childText, "enchant") or string.find(childText, "robux") or string.find(childText, "r$") or string.find(childText, "gamepass")) then
                                for _, kw in ipairs(keywords) do
                                    if string.find(childText, kw) then
                                        matched = true
                                        break
                                    end
                                end
                            end
                        end
                        if matched then break end
                    end
                end
                if matched then
                    clickSmartButton(desc)
                    return true
                end
            end
        end
    end
    return false
end

local function placeMagnetFlag()
    local now = os.clock()
    if now - State.LastFlagTime < 240 then return end
    local pole, prompt, polePos = findNearestFlagPole(Points.FarmEgg.Position, 800)
    if pole and polePos then
        pushLog("Deploying Magnet Flag at flagpole...")
        local savedPos = getHRP() and getHRP().CFrame
        teleportSafely(CFrame.new(polePos) * CFrame.new(0, 2, 3))
        task.wait(0.3)
        if prompt and fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
            task.wait(0.5)
        end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g.Enabled and g ~= ScreenGui then
                    findAndClickButton(g, {"magnet", "magnet flag", "place", "use", "deploy"})
                    task.wait(0.15)
                end
            end
        end
        local poleRef = pole.Name
        pcall(function()
            fireNetwork("Flags: Consume", "Magnet Flag", poleRef)
            fireNetwork("Flags: Consume", "Magnet Flag", pole)
            fireNetwork("Flags: Consume", "Magnet Flag")
            fireNetwork("Flags: Place", "Magnet Flag", poleRef)
            fireNetwork("Flags: Place", "Magnet Flag", pole)
            fireNetwork("Flags: Place", "Magnet Flag")
            fireNetwork("Flags: Deploy", "Magnet Flag", poleRef)
            fireNetwork("Flags: Deploy", "Magnet Flag", pole)
            fireNetwork("Flags: RequestPlace", "Magnet Flag", poleRef)
            fireNetwork("Flags: RequestPlace", "Magnet Flag", pole)
            fireNetwork("Flag: Place", "Magnet Flag", poleRef)
            fireNetwork("Flag_Consume", "Magnet Flag", pole)
            fireNetwork("Flag_Place", "Magnet Flag", pole)
        end)
        if ClientModules["FlagCmds"] then
            pcall(function() ClientModules["FlagCmds"].Place(pole, "Magnet Flag") end)
            pcall(function() ClientModules["FlagCmds"].Consume(pole, "Magnet Flag") end)
            pcall(function() ClientModules["FlagCmds"].Deploy(pole, "Magnet Flag") end)
            pcall(function() ClientModules["FlagCmds"].RequestPlace(pole, "Magnet Flag") end)
        end
        task.wait(0.3)
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g ~= ScreenGui then
                    local gName = string.lower(g.Name)
                    if string.find(gName, "flag") then g.Enabled = false end
                end
            end
        end
        if savedPos then
            teleportSafely(savedPos)
        else
            teleportSafely(Points.FarmEgg, Vector3.new(0, 2, 0))
        end
        State.LastFlagTime = now
        pushLog("Magnet Flag placed successfully in Farm Zone.")
    else
        pcall(function()
            fireNetwork("Flags: Consume", "Magnet Flag", "Zone")
            fireNetwork("Flags: Consume", "Magnet Flag")
            fireNetwork("Flags: Place", "Magnet Flag", "Zone")
            fireNetwork("Flags: Place", "Magnet Flag")
            fireNetwork("Flags_Consume", "Magnet Flag")
            fireNetwork("Flags_Place", "Magnet Flag")
        end)
        State.LastFlagTime = now - 180
    end
end

local function findMerchantLocation()
    local hrp = getHRP()
    local myPos = hrp and hrp.Position or Vector3.zero
    local bestCF = nil
    local bestPrompt = nil
    local bestName = nil
    local bestDist = 99999
    pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                local act = string.lower(desc.ActionText or "")
                local obj = string.lower(desc.ObjectText or "")
                local pName = string.lower(desc.Parent and desc.Parent.Name or "")
                local textAll = act .. " " .. obj .. " " .. pName
                if string.find(textAll, "merchant") or string.find(textAll, "buff") or string.find(textAll, "boost") or string.find(textAll, "vendor") or string.find(textAll, "traveling") or string.find(textAll, "shop") then
                    local pPart = desc.Parent:IsA("BasePart") and desc.Parent or desc.Parent:FindFirstChildWhichIsA("BasePart")
                    local pPos = pPart and pPart.Position or (desc.Parent:IsA("Model") and desc.Parent:GetPivot().Position)
                    if pPos then
                        local d = (pPos - myPos).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestCF = CFrame.new(pPos)
                            bestPrompt = desc
                            bestName = desc.ObjectText ~= "" and desc.ObjectText or desc.Parent.Name
                        end
                    end
                end
            end
        end
    end)
    if bestCF then return bestCF, bestPrompt, bestName end
    pcall(function()
        local things = Workspace:FindFirstChild("__THINGS")
        local containers = {things, Workspace}
        for _, cont in ipairs(containers) do
            if cont then
                for _, child in ipairs(cont:GetChildren()) do
                    local cName = string.lower(child.Name)
                    if string.find(cName, "merchant") or string.find(cName, "buff") or string.find(cName, "vendor") or string.find(cName, "boost") then
                        local p = child:IsA("Model") and (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")) or (child:IsA("BasePart") and child)
                        if p then
                            local d = (p.Position - myPos).Magnitude
                            if d < bestDist then
                                bestDist = d
                                bestCF = CFrame.new(p.Position)
                                bestPrompt = child:FindFirstChildWhichIsA("ProximityPrompt", true)
                                bestName = child.Name
                            end
                        end
                    end
                end
            end
        end
    end)
    return bestCF, bestPrompt, bestName
end

local function buyAllFromOpenMerchantGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, g in ipairs(pg:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled and g ~= ScreenGui then
            local gName = string.lower(g.Name)
            local isShop = string.find(gName, "merchant") or string.find(gName, "shop") or string.find(gName, "stall") or string.find(gName, "buff") or string.find(gName, "traveling")
            local containers = {}
            if isShop then
                table.insert(containers, g)
            end
            for _, desc in ipairs(g:GetDescendants()) do
                if (desc:IsA("Frame") or desc:IsA("ScrollingFrame")) and desc.Visible then
                    local dName = string.lower(desc.Name)
                    if string.find(dName, "merchant") or string.find(dName, "shop") or string.find(dName, "stall") or string.find(dName, "buff") or string.find(dName, "items") or string.find(dName, "slots") then
                        table.insert(containers, desc)
                    end
                end
            end
            for _, c in ipairs(containers) do
                for _, btn in ipairs(c:GetDescendants()) do
                    if btn:IsA("GuiButton") and btn.Visible and btn.Active ~= false then
                        local bName = string.lower(btn.Name)
                        local bText = btn:IsA("TextButton") and string.lower(btn.Text or "") or ""
                        local isClose = string.find(bName, "close") or string.find(bName, "exit") or string.find(bName, "back") or string.find(bName, "cancel") or bText == "x" or bText == "close" or bText == "exit"
                        local isRobux = string.find(bName, "robux") or string.find(bName, "r$") or string.find(bName, "gamepass") or string.find(bName, "pass") or string.find(bName, "+1") or string.find(bText, "r$") or string.find(bText, "robux")
                        if not isClose and not isRobux then
                            clickSmartButton(btn)
                            task.wait(0.08)
                            for _, mGui in ipairs(pg:GetChildren()) do
                                if mGui:IsA("ScreenGui") and mGui.Enabled and mGui ~= ScreenGui then
                                    for _, mBtn in ipairs(mGui:GetDescendants()) do
                                        if mBtn:IsA("GuiButton") and mBtn.Visible then
                                            local mName = string.lower(mBtn.Name)
                                            local mText = mBtn:IsA("TextButton") and string.lower(mBtn.Text or "") or ""
                                            if string.find(mName, "yes") or string.find(mName, "confirm") or string.find(mName, "ok") or string.find(mText, "yes") or string.find(mText, "confirm") or string.find(mText, "ok") or string.find(mText, "sure") then
                                                clickSmartButton(mBtn)
                                                task.wait(0.05)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function buyMerchantItems()
    local now = os.clock()
    if now - State.LastMerchantTime < 60 then return end
    State.LastMerchantTime = now

    local merchantCF, prompt, merchantName = findMerchantLocation()
    if merchantCF then
        pushLog("Visiting Merchant vendor: " .. tostring(merchantName))
        State.CurrentActionText = "BUYING MERCHANT BUFFS & ITEMS..."
        teleportSafely(merchantCF, Vector3.new(0, 2, 2))
        task.wait(0.8)

        if prompt and fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
            task.wait(1.0)
        end

        for _ = 1, 3 do
            buyAllFromOpenMerchantGui()
            task.wait(0.2)
        end

        pcall(function()
            local mList = {merchantName or "TravelingMerchant", "TravelingMerchant", "RegularMerchant", "AdvancedMerchant", "DealerMerchant", "BuffMerchant", "WinterMerchant", "EventMerchant", "SnowMerchant", "IceMerchant", "Buffs", "WinterBuffs"}
            for _, mId in ipairs(mList) do
                for slot = 1, 6 do
                    fireNetwork("Merchant_RequestPurchase", mId, slot)
                    fireNetwork("Merchant: RequestPurchase", mId, slot)
                    fireNetwork("Merchant: RequestBuy", mId, slot)
                    fireNetwork("Merchant: Buy", mId, slot)
                    fireNetwork("Merchant_Buy", mId, slot)
                    fireNetwork("Buffs: Buy", slot)
                    fireNetwork("WinterBuffs: Buy", slot)
                end
                if ClientModules["MerchantCmds"] then
                    pcall(function()
                        for slot = 1, 6 do
                            if ClientModules["MerchantCmds"].RequestPurchase then
                                ClientModules["MerchantCmds"].RequestPurchase(mId, slot)
                            end
                            if ClientModules["MerchantCmds"].Buy then
                                ClientModules["MerchantCmds"].Buy(mId, slot)
                            end
                        end
                    end)
                end
            end
        end)
        task.wait(0.8)

        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and g ~= ScreenGui then
                    local gName = string.lower(g.Name)
                    if string.find(gName, "merchant") or string.find(gName, "shop") or string.find(gName, "buff") then
                        findAndClickButton(g, {"close", "exit", "cancel", "back", "x"})
                        g.Enabled = false
                    end
                end
            end
        end

        teleportSafely(Points.FarmEgg, Vector3.new(0, 2, 0))
        pushLog("Merchant purchase cycle complete. Returned to farm.")
    else
        pcall(function()
            local mList = {"TravelingMerchant", "RegularMerchant", "AdvancedMerchant", "DealerMerchant", "BuffMerchant", "WinterMerchant", "Buffs", "WinterBuffs"}
            for _, mId in ipairs(mList) do
                for slot = 1, 6 do
                    fireNetwork("Merchant_RequestPurchase", mId, slot)
                    fireNetwork("Merchant: RequestBuy", mId, slot)
                    fireNetwork("Merchant: Buy", mId, slot)
                    fireNetwork("Buffs: Buy", slot)
                    fireNetwork("WinterBuffs: Buy", slot)
                end
            end
        end)
    end
end

local Colors = {
    Obsidian = Color3.fromRGB(10, 14, 22),
    Midnight = Color3.fromRGB(16, 23, 36),
    Panel = Color3.fromRGB(18, 26, 42),
    PanelBright = Color3.fromRGB(24, 35, 56),
    Card = Color3.fromRGB(12, 17, 28),
    Cyan = Color3.fromRGB(0, 225, 255),
    CyanBright = Color3.fromRGB(115, 245, 255),
    CyanDim = Color3.fromRGB(20, 85, 120),
    Amber = Color3.fromRGB(245, 135, 45),
    AmberBright = Color3.fromRGB(255, 175, 65),
    Emerald = Color3.fromRGB(46, 220, 130),
    Ruby = Color3.fromRGB(255, 70, 85),
    Gold = Color3.fromRGB(255, 215, 65),
    Snow = Color3.fromRGB(245, 250, 255),
    Frost = Color3.fromRGB(175, 225, 255),
    Muted = Color3.fromRGB(140, 175, 205),
    PurpleBg = Color3.fromRGB(4, 2, 8),
    PurplePanel = Color3.fromRGB(14, 8, 24),
    PurpleNeon = Color3.fromRGB(195, 85, 255),
    PurpleBright = Color3.fromRGB(230, 145, 255),
    PurpleDim = Color3.fromRGB(80, 25, 130)
}

local ParentGui = nil
pcall(function()
    if gethui then ParentGui = gethui() end
end)
if not ParentGui then
    pcall(function() ParentGui = game:GetService("CoreGui") end)
end
if not ParentGui then
    pcall(function() ParentGui = LocalPlayer:WaitForChild("PlayerGui", 5) end)
end
if not ParentGui then ParentGui = Workspace end

pcall(function()
    if ParentGui:FindFirstChild("PS99AutonomousWinterHub") then
        ParentGui:FindFirstChild("PS99AutonomousWinterHub"):Destroy()
    end
end)

ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99AutonomousWinterHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 250
pcall(function() ScreenGui.IgnoreGuiInset = true end)
ScreenGui.Parent = ParentGui

local function addCorner(inst, r)
    local c = Instance.new("UICorner", inst)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end

local function addStroke(inst, col, th)
    local s = Instance.new("UIStroke", inst)
    s.Color = col or Colors.CyanDim
    s.Thickness = th or 1.2
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function addGradient(inst, c1, c2, rot)
    local g = Instance.new("UIGradient", inst)
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rot or 0
    return g
end

local function makeBtn(parent, size, pos, bg, text, textSize, cornerRadius, zIndex)
    local b = Instance.new("TextButton")
    b.Size = size
    if pos then b.Position = pos end
    b.BackgroundColor3 = bg
    b.Text = text or ""
    b.TextColor3 = Colors.Snow
    b.Font = Enum.Font.GothamBold
    b.TextSize = textSize or 11
    b.TextStrokeTransparency = 0.6
    b.TextStrokeColor3 = Color3.new(0, 0, 0)
    b.Active = true
    b.Selectable = true
    b.AutoButtonColor = true
    b.ZIndex = zIndex or 25
    b.Parent = parent
    addCorner(b, cornerRadius or 6)
    addStroke(b, Colors.CyanDim, 1)
    return b
end

local function makeLabel(parent, size, pos, text, color, font, textSize, xAlign, zIndex)
    local l = Instance.new("TextLabel")
    l.Size = size
    if pos then l.Position = pos end
    l.BackgroundTransparency = 1
    l.Text = text or ""
    l.TextColor3 = color or Colors.Snow
    l.Font = font or Enum.Font.GothamBold
    l.TextSize = textSize or 11
    l.TextStrokeTransparency = 0.5
    l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.ZIndex = zIndex or 25
    l.Parent = parent
    return l
end

local function bindSafeClick(inst, cb)
    if not inst then return end
    local isLocked = false
    local function execute()
        if isLocked then return end
        isLocked = true
        task.spawn(function()
            pcall(cb)
            task.wait(0.3)
            isLocked = false
        end)
    end
    if inst:IsA("GuiButton") then
        pcall(function() trackConn(inst.Activated:Connect(execute)) end)
        pcall(function() trackConn(inst.MouseButton1Click:Connect(execute)) end)
    else
        pcall(function()
            trackConn(inst.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    execute()
                end
            end))
        end)
    end
end

local MainCard = Instance.new("Frame")
MainCard.Name = "PufyftykMasterCard"
MainCard.Size = UDim2.new(0, 460, 0, 290)
MainCard.Position = UDim2.new(0.5, -230, 0.5, -145)
MainCard.BackgroundColor3 = Colors.Obsidian
MainCard.BorderSizePixel = 0
MainCard.ZIndex = 10
MainCard.Parent = ScreenGui
addCorner(MainCard, 12)
local MainStroke = addStroke(MainCard, Colors.Cyan, 2.0)
addGradient(MainCard, Colors.Obsidian, Colors.Midnight, 45)

local SnowCapBar = Instance.new("Frame")
SnowCapBar.Size = UDim2.new(1, 16, 0, 14)
SnowCapBar.Position = UDim2.new(0, -8, 0, -8)
SnowCapBar.BackgroundTransparency = 1
SnowCapBar.ZIndex = 35
SnowCapBar.Parent = MainCard

for sIdx = 1, 15 do
    local snowPuff = Instance.new("Frame")
    local sw = 35
    local sh = 12
    local sx = (sIdx - 1) * 31 - 6
    snowPuff.Size = UDim2.new(0, sw, 0, sh)
    snowPuff.Position = UDim2.new(0, sx, 0, 0)
    snowPuff.BackgroundColor3 = Colors.Snow
    snowPuff.BorderSizePixel = 0
    snowPuff.ZIndex = 36
    snowPuff.Parent = SnowCapBar
    addCorner(snowPuff, 6)
    addGradient(snowPuff, Color3.fromRGB(255, 255, 255), Colors.Frost, 90)
end

local CableTray = Instance.new("Frame")
CableTray.Size = UDim2.new(0.92, 0, 0, 14)
CableTray.Position = UDim2.new(0.04, 0, 1, -2)
CableTray.BackgroundTransparency = 1
CableTray.ZIndex = 6
CableTray.Parent = MainCard

local CableLine1 = Instance.new("Frame")
CableLine1.Size = UDim2.new(0.48, 0, 0, 6)
CableLine1.Position = UDim2.new(0.01, 0, 0, 2)
CableLine1.BackgroundColor3 = Colors.Amber
CableLine1.BorderSizePixel = 0
CableLine1.ZIndex = 6
CableLine1.Parent = CableTray
addCorner(CableLine1, 3)
addGradient(CableLine1, Colors.Amber, Colors.AmberBright, 0)

local CableLine2 = Instance.new("Frame")
CableLine2.Size = UDim2.new(0.48, 0, 0, 6)
CableLine2.Position = UDim2.new(0.51, 0, 0, 4)
CableLine2.BackgroundColor3 = Colors.AmberBright
CableLine2.BorderSizePixel = 0
CableLine2.ZIndex = 6
CableLine2.Parent = CableTray
addCorner(CableLine2, 3)
addGradient(CableLine2, Colors.AmberBright, Colors.Amber, 0)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = Colors.Panel
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 11
TopBar.Active = true
TopBar.Parent = MainCard
addCorner(TopBar, 12)
addGradient(TopBar, Color3.fromRGB(22, 32, 50), Colors.Panel, 90)

do
    local isDragging = false
    local dragStart, startPos = nil, nil
    trackConn(TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = MainCard.Position
            local connEnd, connMove = nil, nil
            connMove = UserInputService.InputChanged:Connect(function(moveInput)
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
                    local delta = moveInput.Position - dragStart
                    MainCard.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
            connEnd = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    isDragging = false
                    if connMove then connMove:Disconnect() end
                    if connEnd then connEnd:Disconnect() end
                end
            end)
        end
    end))
end

local TitleText = makeLabel(TopBar, UDim2.new(0, 180, 0, 22), UDim2.new(0, 14, 0, 6), "<< PUFYFTYK >>", Colors.CyanBright, Enum.Font.GothamBold, 16, Enum.TextXAlignment.Left, 15)
local SubBadgeText = makeLabel(TopBar, UDim2.new(0, 250, 0, 14), UDim2.new(0, 14, 0, 28), "SYSTEM: OPERATIONAL // WINTER AFB HUB v9.5", Colors.Muted, Enum.Font.Code, 9, Enum.TextXAlignment.Left, 15)

local MinBtn = makeBtn(TopBar, UDim2.new(0, 28, 0, 28), UDim2.new(1, -68, 0, 10), Colors.Card, "-", 15, 6, 20)
local CloseBtn = makeBtn(TopBar, UDim2.new(0, 28, 0, 28), UDim2.new(1, -36, 0, 10), Colors.Ruby, "X", 12, 6, 20)

local MetricsGrid = Instance.new("Frame")
MetricsGrid.Size = UDim2.new(1, -20, 0, 54)
MetricsGrid.Position = UDim2.new(0, 10, 0, 54)
MetricsGrid.BackgroundTransparency = 1
MetricsGrid.ZIndex = 12
MetricsGrid.Parent = MainCard

local function makeMetricCard(parent, xFrac, strokeCol)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(0.235, 0, 1, 0)
    c.Position = UDim2.new(xFrac, 0, 0, 0)
    c.BackgroundColor3 = Colors.Card
    c.BorderSizePixel = 0
    c.ZIndex = 13
    c.Parent = parent
    addCorner(c, 8)
    addStroke(c, strokeCol or Colors.CyanDim, 1.2)
    addGradient(c, Color3.fromRGB(16, 23, 36), Colors.Card, 90)
    return c
end

local CardYeti = makeMetricCard(MetricsGrid, 0.00, Colors.CyanDim)
local CardTunnel = makeMetricCard(MetricsGrid, 0.255, Colors.CyanDim)
local CardShiny = makeMetricCard(MetricsGrid, 0.510, Colors.Amber)
local CardAcorns = makeMetricCard(MetricsGrid, 0.765, Colors.Gold)

local YetiTitle = makeLabel(CardYeti, UDim2.new(1, -10, 0, 14), UDim2.new(0, 5, 0, 6), "YETI KILLS", Colors.Muted, Enum.Font.GothamBold, 9, Enum.TextXAlignment.Center, 14)
local YetiVal = makeLabel(CardYeti, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, 22), "0", Colors.CyanBright, Enum.Font.GothamBold, 15, Enum.TextXAlignment.Center, 14)

local TunnelTitle = makeLabel(CardTunnel, UDim2.new(1, -10, 0, 14), UDim2.new(0, 5, 0, 6), "TUNNEL STATUS", Colors.Muted, Enum.Font.GothamBold, 9, Enum.TextXAlignment.Center, 14)
local TunnelVal = makeLabel(CardTunnel, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, 22), "CLOSED", Colors.Ruby, Enum.Font.GothamBold, 12, Enum.TextXAlignment.Center, 14)

local ShinyTitle = makeLabel(CardShiny, UDim2.new(1, -10, 0, 14), UDim2.new(0, 5, 0, 6), "YETI: RAINBOW SHINY", Colors.AmberBright, Enum.Font.GothamBold, 8, Enum.TextXAlignment.Center, 14)
local ShinyVal = makeLabel(CardShiny, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, 22), "READY", Colors.Emerald, Enum.Font.GothamBold, 12, Enum.TextXAlignment.Center, 14)

local AcornsTitle = makeLabel(CardAcorns, UDim2.new(1, -10, 0, 14), UDim2.new(0, 5, 0, 6), "ACORNS", Colors.Gold, Enum.Font.GothamBold, 9, Enum.TextXAlignment.Center, 14)
local AcornsVal = makeLabel(CardAcorns, UDim2.new(1, -10, 0, 26), UDim2.new(0, 5, 0, 22), "0 / 2.6T", Colors.Snow, Enum.Font.GothamBold, 11, Enum.TextXAlignment.Center, 14)

local ActionBox = Instance.new("Frame")
ActionBox.Size = UDim2.new(1, -20, 0, 86)
ActionBox.Position = UDim2.new(0, 10, 0, 114)
ActionBox.BackgroundColor3 = Colors.Card
ActionBox.BorderSizePixel = 0
ActionBox.ZIndex = 12
ActionBox.Parent = MainCard
addCorner(ActionBox, 8)
addStroke(ActionBox, Colors.CyanDim, 1.2)
addGradient(ActionBox, Color3.fromRGB(16, 24, 38), Colors.Card, 90)

local ActionHeader = makeLabel(ActionBox, UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 6), "CURRENT ACTION:", Colors.Muted, Enum.Font.Code, 9, Enum.TextXAlignment.Center, 14)
local ActionBanner = makeLabel(ActionBox, UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 22), "FARM ZONE: ACCUMULATING ACORNS...", Colors.CyanBright, Enum.Font.GothamBold, 13, Enum.TextXAlignment.Center, 14)

local ActionSubBanner = makeLabel(ActionBox, UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 52), "PURE VIRTUAL SERVER-SIDE ENGINE ACTIVE", Colors.Emerald, Enum.Font.GothamMedium, 10, Enum.TextXAlignment.Center, 14)

local ButtonRow = Instance.new("Frame")
ButtonRow.Size = UDim2.new(1, -20, 0, 34)
ButtonRow.Position = UDim2.new(0, 10, 0, 206)
ButtonRow.BackgroundTransparency = 1
ButtonRow.ZIndex = 12
ButtonRow.Parent = MainCard

local function makeActionBtn(parent, xFrac, label, activeBg)
    local b = makeBtn(parent, UDim2.new(0.188, 0, 1, 0), UDim2.new(xFrac, 0, 0, 0), activeBg or Colors.Panel, label, 9, 6, 25)
    return b
end

local BtnAutoTunnel = makeActionBtn(ButtonRow, 0.00, "[AUTO TUNNEL]", Colors.PanelBright)
local BtnFarmYeti = makeActionBtn(ButtonRow, 0.255, "[FARM YETI]", Colors.PanelBright)
local BtnMagnetFlag = makeActionBtn(ButtonRow, 0.510, "[MAGNET FLAG]", Colors.PanelBright)
local BtnOledSleep = makeActionBtn(ButtonRow, 0.765, "[OLED SLEEP]", Colors.PurpleDim)

local FooterBar = Instance.new("Frame")
FooterBar.Size = UDim2.new(1, -20, 0, 34)
FooterBar.Position = UDim2.new(0, 10, 0, 246)
FooterBar.BackgroundColor3 = Colors.Panel
FooterBar.BorderSizePixel = 0
FooterBar.ZIndex = 12
FooterBar.Parent = MainCard
addCorner(FooterBar, 6)

local GemsLabel = makeLabel(FooterBar, UDim2.new(0.4, 0, 1, 0), UDim2.new(0, 10, 0, 0), "GEMS GAINED: +0", Colors.Emerald, Enum.Font.GothamBold, 11, Enum.TextXAlignment.Left, 14)
local TimeLabel = makeLabel(FooterBar, UDim2.new(0.25, 0, 1, 0), UDim2.new(0.4, 0, 0, 0), "TIME: 00:00:00", Colors.Snow, Enum.Font.Code, 9, Enum.TextXAlignment.Center, 14)
local LogLabel = makeLabel(FooterBar, UDim2.new(0.35, -10, 1, 0), UDim2.new(0.65, 0, 0, 0), "LOG: INITIALIZED", Colors.Muted, Enum.Font.Code, 9, Enum.TextXAlignment.Right, 14)

local OledOverlay = Instance.new("Frame")
OledOverlay.Name = "OledSleepOverlay"
OledOverlay.Size = UDim2.new(1, 0, 1, 0)
OledOverlay.Position = UDim2.new(0, 0, 0, 0)
OledOverlay.BackgroundColor3 = Colors.PurpleBg
OledOverlay.BorderSizePixel = 0
OledOverlay.ZIndex = 100
OledOverlay.Visible = false
OledOverlay.Parent = ScreenGui

local OledLogoText = makeLabel(OledOverlay, UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0.12, 0), "<< by pufyftyk >>", Colors.PurpleBright, Enum.Font.GothamBold, 24, Enum.TextXAlignment.Center, 105)

local OledCard = Instance.new("Frame")
OledCard.Size = UDim2.new(0, 400, 0, 230)
OledCard.Position = UDim2.new(0.5, -200, 0.5, -105)
OledCard.BackgroundColor3 = Colors.PurplePanel
OledCard.BorderSizePixel = 0
OledCard.ZIndex = 105
OledCard.Parent = OledOverlay
addCorner(OledCard, 12)
addStroke(OledCard, Colors.PurpleNeon, 2.0)
addGradient(OledCard, Color3.fromRGB(18, 10, 32), Colors.PurplePanel, 90)

local OledTag = makeLabel(OledCard, UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 8), "// OLED STATE MONITOR", Colors.PurpleDim, Enum.Font.Code, 10, Enum.TextXAlignment.Center, 110)
local OledGemsLabel = makeLabel(OledCard, UDim2.new(1, -24, 0, 22), UDim2.new(0, 20, 0, 34), "GEMS GAINED: +0", Colors.PurpleBright, Enum.Font.GothamBold, 15, Enum.TextXAlignment.Left, 110)
local OledYetiLabel = makeLabel(OledCard, UDim2.new(1, -24, 0, 20), UDim2.new(0, 20, 0, 64), "YETI KILLS: 0", Colors.Snow, Enum.Font.GothamBold, 13, Enum.TextXAlignment.Left, 110)
local OledAcornsLabel = makeLabel(OledCard, UDim2.new(1, -24, 0, 20), UDim2.new(0, 20, 0, 92), "ACORNS: 0 / 2.6T", Colors.Gold, Enum.Font.GothamBold, 13, Enum.TextXAlignment.Left, 110)
local OledTunnelLabel = makeLabel(OledCard, UDim2.new(1, -24, 0, 20), UDim2.new(0, 20, 0, 120), "TUNNEL STATUS: CLOSED", Colors.CyanBright, Enum.Font.GothamBold, 13, Enum.TextXAlignment.Left, 110)
local OledActionLabel = makeLabel(OledCard, UDim2.new(1, -24, 0, 20), UDim2.new(0, 20, 0, 148), "ACTION: ACTIVE", Colors.Muted, Enum.Font.Code, 11, Enum.TextXAlignment.Left, 110)

local WakeBtn = makeBtn(OledOverlay, UDim2.new(0, 180, 0, 38), UDim2.new(0.5, -90, 0.86, 0), Color3.fromRGB(45, 18, 70), "[*] WAKE SCREEN", 13, 8, 120)
addStroke(WakeBtn, Colors.PurpleBright, 1.8)

local function setOledMode(active)
    State.OledModeActive = active
    OledOverlay.Visible = active
    MainCard.Visible = not active
    pcall(function()
        if setfpscap then
            setfpscap(active and 15 or 60)
        end
    end)
end

bindSafeClick(BtnAutoTunnel, function()
    State.AutoTunnelEnabled = not State.AutoTunnelEnabled
    BtnAutoTunnel.BackgroundColor3 = State.AutoTunnelEnabled and Colors.PanelBright or Colors.Panel
    pushLog("AutoTunnel: " .. tostring(State.AutoTunnelEnabled))
end)

bindSafeClick(BtnFarmYeti, function()
    State.FarmYetiEnabled = not State.FarmYetiEnabled
    BtnFarmYeti.BackgroundColor3 = State.FarmYetiEnabled and Colors.PanelBright or Colors.Panel
    pushLog("FarmYeti: " .. tostring(State.FarmYetiEnabled))
end)

bindSafeClick(BtnMagnetFlag, function()
    State.MagnetFlagEnabled = not State.MagnetFlagEnabled
    BtnMagnetFlag.BackgroundColor3 = State.MagnetFlagEnabled and Colors.PanelBright or Colors.Panel
    pushLog("MagnetFlag: " .. tostring(State.MagnetFlagEnabled))
end)

bindSafeClick(BtnOledSleep, function()
    setOledMode(true)
end)

bindSafeClick(WakeBtn, function()
    setOledMode(false)
end)

local isMinimized = false
bindSafeClick(MinBtn, function()
    isMinimized = not isMinimized
    MetricsGrid.Visible = not isMinimized
    ActionBox.Visible = not isMinimized
    ButtonRow.Visible = not isMinimized
    FooterBar.Visible = not isMinimized
    MainCard.Size = isMinimized and UDim2.new(0, 460, 0, 48) or UDim2.new(0, 460, 0, 290)
    MinBtn.Text = isMinimized and "+" or "-"
end)

bindSafeClick(CloseBtn, function()
    if env.DiamondMountainHubCleanup then
        pcall(env.DiamondMountainHubCleanup)
    end
end)

local function updateUI()
    pcall(function()
        YetiVal.Text = tostring(State.YetiKills)

        if State.TunnelOpen then
            TunnelVal.Text = string.format("OPEN (%s)", formatTimer(State.TunnelTimeRemaining))
            TunnelVal.TextColor3 = Colors.Emerald
        else
            TunnelVal.Text = "CLOSED"
            TunnelVal.TextColor3 = Colors.Ruby
        end

        local now = os.clock()
        local yLive = findYetiBoss()
        if yLive then
            ShinyVal.Text = "ACTIVE"
            ShinyVal.TextColor3 = Colors.Ruby
        elseif now < State.YetiCooldownEnd then
            local rem = State.YetiCooldownEnd - now
            ShinyVal.Text = string.format("CD (%s)", formatTimer(rem))
            ShinyVal.TextColor3 = Colors.AmberBright
        else
            ShinyVal.Text = "READY"
            ShinyVal.TextColor3 = Colors.Emerald
        end

        AcornsVal.Text = string.format("%s / 2.6T", formatCompact(State.CurrentAcorns))
        ActionBanner.Text = State.CurrentActionText

        if State.CurrentPhase == "YETI" then
            ActionSubBanner.Text = "ATTACKING YETI (100% VIRTUAL PACKETS)"
            ActionSubBanner.TextColor3 = Colors.Ruby
        elseif State.CurrentPhase == "TUNNEL" then
            ActionSubBanner.Text = string.format("TUNNEL OPEN (%s REMAINING)", formatTimer(State.TunnelTimeRemaining))
            ActionSubBanner.TextColor3 = Colors.Gold
        else
            ActionSubBanner.Text = "PURE VIRTUAL ENGINE (NO SCREEN CLICKS)"
            ActionSubBanner.TextColor3 = Colors.Emerald
        end

        GemsLabel.Text = string.format("GEMS GAINED: +%s", formatCompact(State.GemsGained))
        local uptime = os.clock() - State.StartTime
        TimeLabel.Text = "TIME: " .. formatDuration(uptime)
        LogLabel.Text = "LOG: " .. string.sub(State.LastLogMessage, 1, 28)

        if State.OledModeActive then
            OledGemsLabel.Text = string.format("GEMS GAINED: +%s", formatCompact(State.GemsGained))
            OledYetiLabel.Text = string.format("YETI KILLS: %d", State.YetiKills)
            OledAcornsLabel.Text = string.format("ACORNS: %s / 2.6T", formatCompact(State.CurrentAcorns))
            OledTunnelLabel.Text = State.TunnelOpen and string.format("TUNNEL: OPEN (%s)", formatTimer(State.TunnelTimeRemaining)) or "TUNNEL: CLOSED"
            OledActionLabel.Text = "ACTION: " .. string.sub(State.CurrentActionText, 1, 36)
        end
    end)
end

task.spawn(function()
    while State.Running do
        updateUI()
        task.wait(0.2)
    end
end)

task.spawn(function()
    while State.Running do
        updateCurrencies()
        task.wait(1.5)
    end
end)

local function breakChestAtPoint(cframePt, chestIndex)
    State.CurrentActionText = string.format("TUNNEL: TELEPORTING TO CHEST #%d...", chestIndex)
    pushLog(string.format("Teleporting to Chest #%d...", chestIndex))
    teleportSafely(cframePt, Vector3.new(0, 3, 0))
    task.wait(0.3)

    local targetObj, targetUid = findBreakableNear(cframePt, 35)
    if not targetObj then
        pushLog(string.format("Chest #%d already cleared. Moving on...", chestIndex))
        return
    end

    State.CurrentActionText = string.format("TUNNEL: DESTROYING CHEST #%d...", chestIndex)
    pushLog(string.format("Destroying Chest #%d with pets & taps!", chestIndex))
    local attackStart = os.clock()
    while State.Running do
        if os.clock() - attackStart > 8 then break end
        if not targetObj.Parent then
            pushLog(string.format("Chest #%d destroyed!", chestIndex))
            break
        end

        local hrp = getHRP()
        if hrp and (hrp.Position - cframePt.Position).Magnitude > 8 then
            teleportSafely(cframePt, Vector3.new(0, 2, 0))
        end

        attackBreakableUID(targetUid, targetObj)
        useUltimateAbility()
        collectGroundDrops()
        task.wait(0.08)
    end
    collectGroundDrops()
    task.wait(0.15)
end

local function runTunnelSequence()
    State.TunnelOpen = true
    State.CurrentPhase = "TUNNEL"
    pushLog("Tunnel priority engaged! Smashing tunnel chests...")
    local tunnelStart = os.clock()
    local tunnelDuration = 300

    breakChestAtPoint(Points.Chest1, 1)
    if not State.Running then return end
    task.wait(0.15)

    breakChestAtPoint(Points.Chest2, 2)
    if not State.Running then return end
    task.wait(0.15)

    breakChestAtPoint(Points.Chest3, 3)
    if not State.Running then return end
    task.wait(0.15)

    State.CurrentActionText = "TUNNEL EGG: 300X LUCK EGG (HATCHING)..."
    pushLog("Chests cleared! Teleporting to 300x egg!")
    teleportSafely(Points.TunnelEgg, Vector3.new(0, 2, 0))
    task.wait(0.35)

    while State.Running do
        local elapsed = os.clock() - tunnelStart
        local remaining = tunnelDuration - elapsed
        State.TunnelTimeRemaining = remaining

        if remaining <= 10 then
            pushLog("Tunnel closing soon. Exiting safely...")
            break
        end

        local hrp = getHRP()
        if hrp and (hrp.Position - Points.TunnelEgg.Position).Magnitude > 6 then
            teleportSafely(Points.TunnelEgg, Vector3.new(0, 2, 0))
        end

        hatchNearestEgg(Points.TunnelEgg, getSafeHatchCount())
        useUltimateAbility()
        collectGroundDrops()
        task.wait(0.4)
    end

    State.TunnelOpen = false
    teleportSafely(Points.FarmEgg, Vector3.new(0, 2, 0))
    pushLog("Tunnel sequence complete. Returned to farm.")
end

local function runYetiSequence()
    State.CurrentPhase = "YETI"
    State.CurrentActionText = "YETI: ENGAGING BOSS (HYPER VIRTUAL TAPS & PETS)..."
    pushLog("Yeti ready! Teleporting to boss summit...")
    teleportSafely(Points.Yeti, Vector3.new(0, 2, 0))
    task.wait(0.35)

    local obj, uid, dist = findYetiBoss()
    if not obj then
        local retryStart = os.clock()
        while State.Running and (os.clock() - retryStart < 2.0) do
            task.wait(0.2)
            obj, uid, dist = findYetiBoss()
            if obj then break end
        end
    end

    if not obj then
        pushLog("Yeti not visible. Probing area with packets...")
        attackBreakableUID("Yeti", nil)
        tapBossVirtual(nil, "Yeti")
        useUltimateAbility()
        collectGroundDrops()
        task.wait(0.5)
        obj, uid, dist = findYetiBoss()
    end

    if not obj then
        pushLog("Yeti not spawned at summit. Checking again in 10s...")
        State.YetiCooldownEnd = os.clock() + 10
        teleportSafely(Points.FarmEgg, Vector3.new(0, 2, 0))
        return
    end

    pushLog("Attacking Yeti with hyper virtual taps (300/s), pets & ult!")
    local engageStart = os.clock()
    local lastSeen = os.clock()
    while State.Running do
        local currObj, currUid, currDist = findYetiBoss()
        if currObj then
            lastSeen = os.clock()
            obj = currObj
            uid = currUid
        else
            if os.clock() - lastSeen > 3.0 then
                State.YetiKills = State.YetiKills + 1
                State.YetiCooldownEnd = os.clock() + 270
                State.CurrentActionText = string.format("YETI DEFEATED! (TOTAL: %d). COOLDOWN 4.5M...", State.YetiKills)
                pushLog(string.format("Yeti defeated! Total kills: %d.", State.YetiKills))
                task.wait(0.8)
                collectGroundDrops()
                teleportSafely(Points.FarmEgg, Vector3.new(0, 2, 0))
                break
            end
        end

        local hrp = getHRP()
        if hrp and (hrp.Position - Points.Yeti.Position).Magnitude > 8 then
            teleportSafely(Points.Yeti, Vector3.new(0, 2, 0))
        end

        attackBreakableUID(uid or "Yeti", obj)
        tapBossVirtual(obj, uid or "Yeti")
        useUltimateAbility()
        collectGroundDrops()

        local elapsed = os.clock() - engageStart
        task.wait(0.04)
    end
end

local function runFreeTimeSequence()
    local now = os.clock()


    State.CurrentPhase = "FLAG"
    State.CurrentActionText = "FARM ZONE: ACCUMULATING ACORNS & AMBIENT FARM..."

    local hrp = getHRP()
    if hrp and (hrp.Position - Points.FarmEgg.Position).Magnitude > 8 then
        teleportSafely(Points.FarmEgg, Vector3.new(0, 2, 0))
    end

    if State.MagnetFlagEnabled then
        placeMagnetFlag()
    end

    farmAmbientBreakables(Points.FarmEgg, 45)

    hatchNearestEgg(Points.FarmEgg, getSafeHatchCount())
    useUltimateAbility()
    buyMerchantItems()
    collectGroundDrops()

    local targetProgress = math.clamp(State.CurrentAcorns / AcornsTarget, 0, 1)
end

task.spawn(function()
    while State.Running do
        pcall(function()
            local now = os.clock()
            local checkTunnelNow = false
            if State.AutoTunnelEnabled and (now - State.LastTunnelCheck >= 20) then
                State.LastTunnelCheck = now
                checkTunnelNow = checkTunnelStatus()
            end

            if checkTunnelNow then
                runTunnelSequence()
            else
                local yetiActive = false
                if State.FarmYetiEnabled then
                    if now >= State.YetiCooldownEnd then
                        yetiActive = true
                    else
                        local yObj = findYetiBoss()
                        if yObj then yetiActive = true end
                    end
                end

                if yetiActive then
                    runYetiSequence()
                else
                    runFreeTimeSequence()
                end
            end
        end)
        task.wait(0.35)
    end
end)

local function cleanupAll()
    State.Running = false
    setOledMode(false)
    for _, conn in ipairs(ActiveConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ActiveConnections = {}
    if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
    if env.DiamondMountainHubCleanup == cleanupAll then
        env.DiamondMountainHubCleanup = nil
    end
end

env.DiamondMountainHubCleanup = cleanupAll
