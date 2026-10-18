
local _CREATOR = "by pufyftyk"
local _PROJECT = "PS99 Diamond Mountain - Full Master Progression Hub v2.0"
local _VERSION = "2.0.0"

pcall(function()
    local _players = game:GetService("Players")
    local _lp = _players.LocalPlayer
    local _vu = game:GetService("VirtualUser")
    local _vim = nil
    pcall(function() _vim = game:GetService("VirtualInputManager") end)

    if getconnections then
        pcall(function()
            for _, conn in ipairs(getconnections(_lp.Idled)) do
                if conn and conn.Disable then conn:Disable() end
            end
        end)
    end

    _lp.Idled:Connect(function()
        pcall(function()
            if _vu then
                _vu:CaptureController()
                _vu:ClickButton2(Vector2.new(0, 0))
            end
        end)
    end)

    task.spawn(function()
        local pulseCount = 0
        while true do
            task.wait(15)
            pulseCount = pulseCount + 1
            pcall(function()
                if _vu then
                    _vu:CaptureController()
                    _vu:ClickButton2(Vector2.new(0, 0))
                end
            end)
            if pulseCount % 8 == 0 then
                pcall(function()
                    if _vim and _vim.SendKeyEvent then
                        _vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        task.wait(0.04)
                        _vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                    else
                        local ch = _lp.Character
                        local hu = ch and ch:FindFirstChildOfClass("Humanoid")
                        if hu then hu.Jump = true end
                    end
                end)
            end
        end
    end)
end)

pcall(function()
    local _gs = game:GetService("GuiService")
    local _ts = game:GetService("TeleportService")
    local _lp = game:GetService("Players").LocalPlayer

    local qot = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
    if qot then
        pcall(function()
            qot([[
                task.spawn(function()
                    repeat task.wait(1) until game:IsLoaded()
                    task.wait(2.5)
                    pcall(function()
                        if readfile and pcall(readfile, "diamond_mountain_hub.lua") then
                            loadstring(readfile("diamond_mountain_hub.lua"))()
                        end
                    end)
                end)
            ]])
        end)
    end

    local reconnecting = false
    local function tryReconnect()
        if reconnecting then return end
        reconnecting = true
        task.spawn(function()
            while true do
                pcall(function()
                    _ts:Teleport(game.PlaceId, _lp)
                end)
                task.wait(6)
            end
        end)
    end

    _gs.ErrorMessageChanged:Connect(function()
        task.wait(1.5)
        tryReconnect()
    end)
end)

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LogService = game:GetService("LogService")

local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

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

if env.DiamondMountainMasterCleanup then
    pcall(env.DiamondMountainMasterCleanup)
end

local ActiveConnections = {}
local function trackConn(conn)
    if conn then table.insert(ActiveConnections, conn) end
    return conn
end

local Config = {
    AutoStages = true,
    TargetMaxZone = 6,
    AutoHatch = true,
    HatchBatch = 10,
    FocusTunnel6 = true,
    MinAcornsForTunnel = 300,
    AutoFarmBreakables = true,
    AutoEquipBest = true,
    AutoBuyMerchants = true,
    AutoUpgrades = true,
    AutoCollectRelics = true,
    PotatoGraphics = true,
    BlackScreen = false,
    EggHatchDelay = 0.12,
    WallAttackDelay = 0.08,
    ZoneCheckInterval = 2.0
}

local State = {
    Running = true,
    StartTime = os.clock(),
    CurrentZone = 1,
    HighestUnlockedZone = 1,
    StartDiamonds = 0,
    CurrentDiamonds = 0,
    DiamondsGained = 0,
    StartAcorns = 0,
    CurrentAcorns = 0,
    AcornsGained = 0,
    EggsHatched = 0,
    HugesHatched = 0,
    TitanicsHatched = 0,
    RelicsCollected = 0,
    Tunnel6Open = false,
    InTunnel6 = false,
    AtZoneFarm = false,
    LastHatchTime = 0,
    LastWallAttackTime = 0,
    LastMerchantTime = 0,
    LastUpgradeTime = 0,
    LastRelicCheckTime = 0,
    LastZoneScanTime = 0,
    CurrentActionText = "Starting Master Hub... (by pufyftyk)",
    SubStatusText = "Initializing PS99 Framework...",
    CurrentWallTarget = nil,
    CurrentWallPosition = nil,
    CurrentEggTarget = nil,
    CurrentEggId = nil,
    CurrentEggRemoteName = nil,
    ZoneEggPositions = {},
    ZoneFarmPositions = {},
    ZoneGatePositions = {},
    Tunnel6CF = nil,
    RelicPositions = {},
    Logs = {},
    MaxLogs = 120
}

local function addLog(level, msg)
    local entry = string.format("[%s] [%s] %s", os.date("%H:%M:%S"), level, tostring(msg))
    table.insert(State.Logs, entry)
    if #State.Logs > State.MaxLogs then
        table.remove(State.Logs, 1)
    end
end

trackConn(LogService.MessageOut:Connect(function(msg, msgType)
    if not State.Running then return end
    if msgType == Enum.MessageType.MessageError then
        if not string.find(msg, "SimpleSpy") and not string.find(msg, "Dex") then
            addLog("ERR", msg)
        end
    end
end))

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

local function formatDuration(sec)
    local s = math.max(0, math.floor(tonumber(sec) or 0))
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local r = s % 60
    return string.format("%02d:%02d:%02d", h, m, r)
end

local function fireSafePrompt(prompt)
    if not prompt then return false end
    local ok = false
    if fireproximityprompt then
        ok = pcall(fireproximityprompt, prompt, 0)
    end
    if not ok then
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration or 0.1)
            prompt:InputHoldEnd()
            ok = true
        end)
    end
    return ok
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

local function getThingsFolder()
    local things = Workspace:FindFirstChild("__THINGS") or Workspace:FindFirstChild("Things")
    return things
end

local NetworkFolder = nil
pcall(function() NetworkFolder = ReplicatedStorage:WaitForChild("Network", 6) end)

local RemoteCache = {}
local function findRemote(name)
    if RemoteCache[name] and RemoteCache[name].Parent then
        return RemoteCache[name]
    end
    if NetworkFolder then
        local direct = NetworkFolder:FindFirstChild(name)
        if direct then
            RemoteCache[name] = direct
            return direct
        end
        local low = string.lower(name)
        for _, desc in ipairs(NetworkFolder:GetDescendants()) do
            if string.lower(desc.Name) == low then
                RemoteCache[name] = desc
                return desc
            end
        end
    end
    local lowName = string.lower(name)
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if string.lower(desc.Name) == lowName and (desc:IsA("RemoteFunction") or desc:IsA("RemoteEvent")) then
            RemoteCache[name] = desc
            return desc
        end
    end
    return nil
end

local function invokeRemote(name, ...)
    local r = findRemote(name)
    if not r then return false, "Remote not found: " .. tostring(name) end
    if r:IsA("RemoteFunction") then
        return pcall(function(...) return r:InvokeServer(...) end, ...)
    elseif r:IsA("RemoteEvent") or r.ClassName == "UnreliableRemoteEvent" then
        return pcall(function(...) r:FireServer(...) end, ...)
    end
    return false, "Invalid remote class"
end

local function getClientModule(modName)
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local client = lib and lib:FindFirstChild("Client")
    if not client then return nil end
    local m = client:FindFirstChild(modName)
    if m and m:IsA("ModuleScript") then
        local ok, res = pcall(require, m)
        if ok and res then return res end
    end
    return nil
end

local SaveModule = getClientModule("Save")
local DirectoryModule = getClientModule("Directory")
local BreakableCmds = getClientModule("BreakableCmds")
local PlayerPetModule = getClientModule("PlayerPet")

local function getSaveData()
    if SaveModule and SaveModule.Get then
        local ok, data = pcall(SaveModule.Get)
        if ok and type(data) == "table" then return data end
    end
    local freshSave = getClientModule("Save")
    if freshSave and freshSave.Get then
        SaveModule = freshSave
        local ok, data = pcall(freshSave.Get)
        if ok and type(data) == "table" then return data end
    end
    return nil
end

local function updatePlayerInventoryAndCurrencies()
    local diamonds = 0
    local acorns = 0
    local hugeCount = 0
    local titanicCount = 0

    pcall(function()
        local data = getSaveData()
        if data then
            if type(data.Diamonds) == "number" then
                diamonds = data.Diamonds
            end
            if type(data.Inventory) == "table" then
                if type(data.Inventory.Currency) == "table" then
                    for curId, item in pairs(data.Inventory.Currency) do
                        local low = string.lower(tostring(curId))
                        local amt = tonumber(item) or (type(item) == "table" and (tonumber(item._am) or tonumber(item.amount))) or 0
                        if string.find(low, "acorn") or string.find(low, "event") or string.find(low, "mountain") then
                            acorns = acorns + amt
                        elseif string.find(low, "diamond") then
                            if diamonds == 0 then diamonds = amt end
                        end
                    end
                end
                if type(data.Inventory.Pet) == "table" then
                    for _, pItem in pairs(data.Inventory.Pet) do
                        if type(pItem) == "table" and pItem.id then
                            local petId = string.lower(tostring(pItem.id))
                            local pAmt = tonumber(pItem._am) or tonumber(pItem.amount) or 1
                            if string.find(petId, "titanic") then
                                titanicCount = titanicCount + pAmt
                            elseif string.find(petId, "huge") then
                                hugeCount = hugeCount + pAmt
                            end
                        end
                    end
                end
            end
        end
    end)

    if diamonds == 0 then
        pcall(function()
            local ls = LocalPlayer:FindFirstChild("leaderstats")
            if ls then
                local d = ls:FindFirstChild("Diamonds")
                if not d then
                    for _, ch in ipairs(ls:GetChildren()) do
                        if string.find(string.lower(ch.Name), "diamond") then d = ch; break end
                    end
                end
                if d and tonumber(d.Value) then diamonds = tonumber(d.Value) end
            end
        end)
    end

    if State.StartDiamonds == 0 and diamonds > 0 then
        State.StartDiamonds = diamonds
    end
    if State.StartAcorns == 0 and acorns > 0 then
        State.StartAcorns = acorns
    end

    State.CurrentDiamonds = diamonds
    State.CurrentAcorns = acorns
    State.DiamondsGained = math.max(0, diamonds - (State.StartDiamonds or diamonds))
    State.AcornsGained = math.max(0, acorns - (State.StartAcorns or acorns))
    State.HugesHatched = hugeCount
    State.TitanicsHatched = titanicCount
end

local function applyPotatoGraphics(enable)
    pcall(function()
        if enable then
            settings().Rendering.QualityLevel = 1
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                end
            end
        else
            Lighting.GlobalShadows = true
            Lighting.FogEnd = 100000
        end
    end)
end

local function teleportSafely(cf)
    if not cf then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = cf + Vector3.new(0, 3.5, 0)
        end
    end)
end

local function getObjectPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        local p = obj:FindFirstChildWhichIsA("BasePart", true)
        if p then return p.Position end
    end
    return nil
end

local function getObjectCFrame(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.CFrame end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.CFrame end
        local p = obj:FindFirstChildWhichIsA("BasePart", true)
        if p then return p.CFrame end
    end
    return nil
end

local function findActiveBreakableWall(zoneIndex)
    local things = getThingsFolder()
    if not things then return nil, nil end
    local breakables = things:FindFirstChild("Breakables")
    if not breakables then return nil, nil end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end
    local myPos = hrp.Position

    local wallCandidates = {}
    for _, b in ipairs(breakables:GetChildren()) do
        local bPos = getObjectPosition(b)
        if bPos then
            local dist = (bPos - myPos).Magnitude
            if dist <= 160 then
                local low = string.lower(b.Name)
                local isWallName = string.find(low, "wall") or string.find(low, "gate") or string.find(low, "door") or string.find(low, "barrier") or string.find(low, "blockade")
                local hp = b:GetAttribute("Health") or b:GetAttribute("MaxHealth") or b:GetAttribute("hp") or 0
                local size = (b:IsA("BasePart") and b.Size.Magnitude) or (b:IsA("Model") and b:GetExtentsSize().Magnitude) or 0
                if isWallName or hp > 50000 or size > 30 then
                    table.insert(wallCandidates, { obj = b, pos = bPos, dist = dist, size = size, hp = hp, isName = isWallName })
                end
            end
        end
    end

    table.sort(wallCandidates, function(a, b)
        if a.isName ~= b.isName then return a.isName end
        if a.hp ~= b.hp then return a.hp > b.hp end
        return a.dist < b.dist
    end)

    if #wallCandidates > 0 then
        return wallCandidates[1].obj, wallCandidates[1].pos
    end

    local mapFolder = Workspace:FindFirstChild("Map") or things:FindFirstChild("Map")
    if mapFolder then
        for _, obj in ipairs(mapFolder:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("BasePart") then
                local low = string.lower(obj.Name)
                if string.find(low, "wall") or string.find(low, "gate") or string.find(low, "barrier") then
                    local p = getObjectPosition(obj)
                    if p and (p - myPos).Magnitude <= 120 then
                        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt or obj:FindFirstChildWhichIsA("TouchTransmitter", true) then
                            return obj, p
                        end
                    end
                end
            end
        end
    end

    return nil, nil
end

local function attackTargetWall(wallObj)
    if not wallObj then return end
    pcall(function()
        local uid = wallObj.Name
        local dmgRemote = findRemote("Breakables_PlayerDealDamage")
        if dmgRemote then
            if dmgRemote:IsA("RemoteEvent") or dmgRemote.ClassName == "UnreliableRemoteEvent" then
                dmgRemote:FireServer(uid)
            else
                pcall(function() dmgRemote:InvokeServer(uid) end)
            end
        end
    end)
    pcall(function()
        if PlayerPetModule and PlayerPetModule.SetTarget then
            PlayerPetModule.SetTarget(wallObj)
        end
    end)
end

local function farmNearbyAcorns(centerPos, maxDist)
    local things = getThingsFolder()
    if not things then return end
    local breakables = things:FindFirstChild("Breakables")
    if not breakables then return end
    local radius = maxDist or 80
    local dmgRemote = findRemote("Breakables_PlayerDealDamage")

    local count = 0
    for _, b in ipairs(breakables:GetChildren()) do
        local p = getObjectPosition(b)
        if p and (p - centerPos).Magnitude <= radius then
            local uid = b.Name
            if dmgRemote then
                if dmgRemote:IsA("RemoteEvent") or dmgRemote.ClassName == "UnreliableRemoteEvent" then
                    dmgRemote:FireServer(uid)
                else
                    pcall(function() dmgRemote:InvokeServer(uid) end)
                end
            end
            count = count + 1
            if count >= 8 then break end
        end
    end
end

local function activateZoneAutoFarmRemote()
    pcall(function()
        local r = findRemote("AutoFarm: Toggle") or findRemote("AutoFarm_Toggle") or findRemote("ToggleAutoFarm")
        if r then
            if r:IsA("RemoteFunction") then r:InvokeServer(true)
            elseif r:IsA("RemoteEvent") then r:FireServer(true) end
        end
    end)
end

local function autoEquipBestPets()
    if not Config.AutoEquipBest then return end
    pcall(function()
        local equipRemotes = { "Pets: EquipBest", "EquipBest", "Pets_EquipBest", "PlayerPet: EquipBest" }
        for _, rName in ipairs(equipRemotes) do
            local r = findRemote(rName)
            if r then
                if r:IsA("RemoteFunction") then r:InvokeServer()
                else r:FireServer() end
                return
            end
        end
    end)
    pcall(function()
        local petMod = getClientModule("PetCmds") or getClientModule("PlayerPet")
        if petMod and petMod.EquipBest then
            petMod.EquipBest()
        end
    end)
end

local function findNearestEggMachine(maxDist)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil, nil end
    local myPos = hrp.Position
    local things = getThingsFolder()
    local limit = maxDist or 100

    local eggCandidates = {}
    local function checkContainer(cont, isCustom)
        if not cont then return end
        for _, egg in ipairs(cont:GetChildren()) do
            local p = getObjectPosition(egg)
            if p then
                local d = (p - myPos).Magnitude
                if d <= limit then
                    local eggId = egg:GetAttribute("id") or egg:GetAttribute("EggName") or egg:GetAttribute("ID") or egg.Name
                    table.insert(eggCandidates, { obj = egg, pos = p, dist = d, id = eggId, isCustom = isCustom })
                end
            end
        end
    end

    if things then
        checkContainer(things:FindFirstChild("CustomEggs"), true)
        checkContainer(things:FindFirstChild("Eggs"), false)
        checkContainer(things:FindFirstChild("EggCapsules"), true)
    end

    table.sort(eggCandidates, function(a, b) return a.dist < b.dist end)
    if #eggCandidates > 0 then
        return eggCandidates[1].obj, eggCandidates[1].id, eggCandidates[1].pos
    end
    return nil, nil, nil
end

local function hatchTargetEgg(eggId, batchCount)
    if not eggId then return false end
    local batch = batchCount or Config.HatchBatch or 10
    local remotesToTry = { "CustomEggs_Hatch", "Eggs_RequestPurchase", "Eggs_Roll" }

    for _, rName in ipairs(remotesToTry) do
        local r = findRemote(rName)
        if r then
            local ok, res = false, nil
            if r:IsA("RemoteFunction") then
                ok, res = pcall(function() return r:InvokeServer(eggId, batch) end)
            else
                ok = pcall(function() r:FireServer(eggId, batch) end)
            end
            if ok and res ~= false and res ~= nil then
                State.EggsHatched = State.EggsHatched + batch
                State.LastHatchTime = os.clock()
                State.CurrentEggRemoteName = rName
                State.CurrentEggId = eggId
                return true
            end
        end
    end
    return false
end

local function checkAndBuyMerchantStalls()
    if not Config.AutoBuyMerchants then return end
    local now = os.clock()
    if now - State.LastMerchantTime < 7.0 then return end
    State.LastMerchantTime = now

    pcall(function()
        local merchantRemotes = { "Merchant_Purchase", "Merchants_Purchase", "TravelingMerchant_Buy", "Merchant: Buy" }
        for _, rName in ipairs(merchantRemotes) do
            local r = findRemote(rName)
            if r then
                for slot = 1, 3 do
                    pcall(function()
                        if r:IsA("RemoteFunction") then r:InvokeServer("TravelingMerchant", slot)
                        else r:FireServer("TravelingMerchant", slot) end
                    end)
                    pcall(function()
                        if r:IsA("RemoteFunction") then r:InvokeServer(slot)
                        else r:FireServer(slot) end
                    end)
                end
            end
        end
    end)

    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local low = string.lower(obj.Name)
            if string.find(low, "merchant") or string.find(low, "booth") or string.find(low, "stall") then
                local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    fireSafePrompt(prompt)
                end
            end
        end
    end)
end

local function checkAndBuyUpgrades()
    if not Config.AutoUpgrades then return end
    local now = os.clock()
    if now - State.LastUpgradeTime < 8.0 then return end
    State.LastUpgradeTime = now

    pcall(function()
        local upgradeRemotes = { "Upgrades_Purchase", "Upgrades: Purchase", "EventUpgrades_Purchase", "DiamondMountain_BuyUpgrade" }
        local targetUpgrades = { "Wall Power", "Expedition Speed", "Acorn Drops", "Offline Power", "Speed" }
        for _, rName in ipairs(upgradeRemotes) do
            local r = findRemote(rName)
            if r then
                for _, upg in ipairs(targetUpgrades) do
                    pcall(function()
                        if r:IsA("RemoteFunction") then r:InvokeServer(upg)
                        else r:FireServer(upg) end
                    end)
                end
            end
        end
    end)
end

local function scanAndCollectSecretRelics()
    if not Config.AutoCollectRelics then return end
    local now = os.clock()
    if now - State.LastRelicCheckTime < 15.0 then return end
    State.LastRelicCheckTime = now

    local relicCount = 0
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        for _, obj in ipairs(Workspace:GetDescendants()) do
            local low = string.lower(obj.Name)
            local isRelic = string.find(low, "relic") or string.find(low, "secret") or string.find(low, "psx") or string.find(low, "artifact") or string.find(low, "index")
            if isRelic then
                local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    fireSafePrompt(prompt)
                    relicCount = relicCount + 1
                end
            end
        end
    end)
    if relicCount > State.RelicsCollected then
        State.RelicsCollected = relicCount
    end
end

local Colors = {
    DarkBg = Color3.fromRGB(11, 17, 32),
    CardBg = Color3.fromRGB(18, 28, 52),
    HeaderBg = Color3.fromRGB(24, 38, 70),
    IceAccent = Color3.fromRGB(100, 200, 255),
    IceGlow = Color3.fromRGB(60, 160, 255),
    SnowWhite = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(175, 200, 230),
    Green = Color3.fromRGB(46, 204, 113),
    Red = Color3.fromRGB(235, 75, 75),
    Gold = Color3.fromRGB(255, 195, 50),
    Purple = Color3.fromRGB(190, 85, 255),
    Stroke = Color3.fromRGB(40, 70, 120),
    ActiveTab = Color3.fromRGB(30, 50, 92),
    InactiveTab = Color3.fromRGB(16, 24, 44)
}

local function addCornerAndStroke(inst, radius, strokeColor, thickness)
    if radius then Instance.new("UICorner", inst).CornerRadius = UDim.new(0, radius) end
    if strokeColor then
        local s = Instance.new("UIStroke", inst)
        s.Color = strokeColor
        s.Thickness = thickness or 1.5
        return s
    end
    return nil
end

local function makeBtn(parent, size, pos, bg, text, textSize, radius)
    local b = Instance.new("TextButton")
    b.Size = size
    if pos then b.Position = pos end
    b.BackgroundColor3 = bg
    b.Text = text or ""
    b.TextColor3 = Colors.SnowWhite
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = textSize or 12
    b.TextStrokeTransparency = 0.4
    b.TextStrokeColor3 = Color3.new(0, 0, 0)
    b.Parent = parent
    if radius then Instance.new("UICorner", b).CornerRadius = UDim.new(0, radius) end
    addCornerAndStroke(b, radius or 6, Colors.Stroke, 1.2)
    return b
end

local function makeLabel(parent, size, pos, text, color, font, textSize, xAlign)
    local l = Instance.new("TextLabel")
    l.Size = size
    if pos then l.Position = pos end
    l.BackgroundTransparency = 1
    l.Text = text or ""
    l.TextColor3 = color or Colors.SnowWhite
    l.Font = font or Enum.Font.SourceSansBold
    l.TextSize = textSize or 12
    l.TextStrokeTransparency = 0.3
    l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local BlackScreenFrame = Instance.new("Frame")
BlackScreenFrame.Name = "BlackScreenAFK"
BlackScreenFrame.Size = UDim2.new(1, 0, 1, 0)
BlackScreenFrame.Position = UDim2.new(0, 0, 0, 0)
BlackScreenFrame.BackgroundColor3 = Color3.new(0, 0, 0)
BlackScreenFrame.BorderSizePixel = 0
BlackScreenFrame.Visible = false
BlackScreenFrame.ZIndex = 1000
BlackScreenFrame.Parent = ScreenGui

local BlackText = makeLabel(BlackScreenFrame, UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0.4, 0), "AFK Screen Saver Active (OLED Battery Saver)\nTap below to wake screen", Colors.IceAccent, Enum.Font.SourceSansBold, 15, Enum.TextXAlignment.Center)
local BlackExitBtn = makeBtn(BlackScreenFrame, UDim2.new(0, 180, 0, 42), UDim2.new(0.5, -90, 0.5, 20), Colors.HeaderBg, "[+] Wake Screen", 14, 8)
addCornerAndStroke(BlackExitBtn, 8, Colors.IceAccent, 1.5)

local DashCard = Instance.new("Frame")
DashCard.Name = "MainHubFrame"
DashCard.Size = UDim2.new(0, 350, 0, 460)
DashCard.Position = UDim2.new(0.5, -175, 0.5, -230)
DashCard.BackgroundColor3 = Colors.DarkBg
DashCard.BorderSizePixel = 0
DashCard.Parent = ScreenGui
addCornerAndStroke(DashCard, 10, Colors.IceAccent, 2)

local DashTopBar = Instance.new("Frame")
DashTopBar.Size = UDim2.new(1, 0, 0, 42)
DashTopBar.BackgroundColor3 = Colors.HeaderBg
DashTopBar.BorderSizePixel = 0
DashTopBar.Parent = DashCard
addCornerAndStroke(DashTopBar, 10, nil, nil)

pcall(function()
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    trackConn(DashTopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = DashCard.Position
            trackConn(input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end))
        end
    end))
    trackConn(DashTopBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))
    trackConn(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            DashCard.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end)

makeLabel(DashTopBar, UDim2.new(1, -65, 1, 0), UDim2.new(0, 12, 0, 0), "[*] DIAMOND MOUNTAIN MASTER [*]", Colors.IceAccent, Enum.Font.SourceSansBold, 13)
local MinBtn = makeBtn(DashTopBar, UDim2.new(0, 28, 0, 28), UDim2.new(1, -34, 0, 7), Colors.CardBg, "-", 15, 6)

local RestoreBtn = makeBtn(ScreenGui, UDim2.new(0, 150, 0, 36), UDim2.new(0, 14, 0, 14), Colors.HeaderBg, "[*] Diamond Hub", 13, 8)
RestoreBtn.TextColor3 = Colors.IceAccent
RestoreBtn.Visible = false
addCornerAndStroke(RestoreBtn, 8, Colors.IceAccent, 1.5)

trackConn(MinBtn.MouseButton1Click:Connect(function()
    DashCard.Visible = false
    RestoreBtn.Visible = true
end))
trackConn(RestoreBtn.MouseButton1Click:Connect(function()
    DashCard.Visible = true
    RestoreBtn.Visible = false
end))

trackConn(BlackExitBtn.MouseButton1Click:Connect(function()
    Config.BlackScreen = false
    BlackScreenFrame.Visible = false
end))

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -16, 0, 32)
TabBar.Position = UDim2.new(0, 8, 0, 48)
TabBar.BackgroundTransparency = 1
TabBar.Parent = DashCard

local TabBtnMain = makeBtn(TabBar, UDim2.new(0.25, -4, 1, 0), UDim2.new(0, 0, 0, 0), Colors.ActiveTab, "Stats", 11, 6)
local TabBtnProg = makeBtn(TabBar, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.25, 2, 0, 0), Colors.InactiveTab, "Stages", 11, 6)
local TabBtnFarm = makeBtn(TabBar, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.5, 4, 0, 0), Colors.InactiveTab, "Tunnel", 11, 6)
local TabBtnMisc = makeBtn(TabBar, UDim2.new(0.25, -4, 1, 0), UDim2.new(0.75, 6, 0, 0), Colors.InactiveTab, "Config", 11, 6)

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -16, 1, -90)
TabContainer.Position = UDim2.new(0, 8, 0, 84)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = DashCard

local PageMain = Instance.new("Frame")
PageMain.Size = UDim2.new(1, 0, 1, 0)
PageMain.BackgroundTransparency = 1
PageMain.Visible = true
PageMain.Parent = TabContainer

local PageProg = Instance.new("Frame")
PageProg.Size = UDim2.new(1, 0, 1, 0)
PageProg.BackgroundTransparency = 1
PageProg.Visible = false
PageProg.Parent = TabContainer

local PageFarm = Instance.new("Frame")
PageFarm.Size = UDim2.new(1, 0, 1, 0)
PageFarm.BackgroundTransparency = 1
PageFarm.Visible = false
PageFarm.Parent = TabContainer

local PageMisc = Instance.new("Frame")
PageMisc.Size = UDim2.new(1, 0, 1, 0)
PageMisc.BackgroundTransparency = 1
PageMisc.Visible = false
PageMisc.Parent = TabContainer

local function switchTab(activeBtn, activePage)
    for _, b in ipairs({ TabBtnMain, TabBtnProg, TabBtnFarm, TabBtnMisc }) do
        b.BackgroundColor3 = (b == activeBtn) and Colors.ActiveTab or Colors.InactiveTab
        b.TextColor3 = (b == activeBtn) and Colors.IceAccent or Colors.SubText
    end
    PageMain.Visible = (activePage == PageMain)
    PageProg.Visible = (activePage == PageProg)
    PageFarm.Visible = (activePage == PageFarm)
    PageMisc.Visible = (activePage == PageMisc)
end

trackConn(TabBtnMain.MouseButton1Click:Connect(function() switchTab(TabBtnMain, PageMain) end))
trackConn(TabBtnProg.MouseButton1Click:Connect(function() switchTab(TabBtnProg, PageProg) end))
trackConn(TabBtnFarm.MouseButton1Click:Connect(function() switchTab(TabBtnFarm, PageFarm) end))
trackConn(TabBtnMisc.MouseButton1Click:Connect(function() switchTab(TabBtnMisc, PageMisc) end))

local StatsBox = Instance.new("Frame")
StatsBox.Size = UDim2.new(1, 0, 0, 150)
StatsBox.Position = UDim2.new(0, 0, 0, 4)
StatsBox.BackgroundColor3 = Colors.CardBg
StatsBox.BorderSizePixel = 0
StatsBox.Parent = PageMain
addCornerAndStroke(StatsBox, 8, Colors.Stroke, 1.5)

local StatGems = makeLabel(StatsBox, UDim2.new(0.5, -8, 0, 20), UDim2.new(0, 10, 0, 8), "Gems: +0 (Total: 0)", Colors.Green, Enum.Font.SourceSansBold, 12)
local StatAcorns = makeLabel(StatsBox, UDim2.new(0.5, -8, 0, 20), UDim2.new(0.5, 4, 0, 8), "Acorns: 0 (+0)", Colors.Gold, Enum.Font.SourceSansBold, 12)

local StatEggs = makeLabel(StatsBox, UDim2.new(0.5, -8, 0, 20), UDim2.new(0, 10, 0, 32), "Eggs Opened: 0", Colors.IceAccent, Enum.Font.SourceSansBold, 12)
local StatTime = makeLabel(StatsBox, UDim2.new(0.5, -8, 0, 20), UDim2.new(0.5, 4, 0, 32), "Time: 00:00:00", Colors.SubText, Enum.Font.SourceSansBold, 12)

local StatPets = makeLabel(StatsBox, UDim2.new(0.5, -8, 0, 20), UDim2.new(0, 10, 0, 56), "Huges: 0 | Titanics: 0", Colors.Purple, Enum.Font.SourceSansBold, 12)
local StatRelics = makeLabel(StatsBox, UDim2.new(0.5, -8, 0, 20), UDim2.new(0.5, 4, 0, 56), "PSX Relics: 0/6", Colors.IceAccent, Enum.Font.SourceSansBold, 12)

local StatZone = makeLabel(StatsBox, UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 80), "Current Zone: Zone 1 / 6", Colors.Gold, Enum.Font.SourceSansBold, 12)
local StatStatus = makeLabel(StatsBox, UDim2.new(1, -20, 0, 42), UDim2.new(0, 10, 0, 102), "Status: Loading... | by pufyftyk", Colors.SnowWhite, Enum.Font.SourceSans, 11)
StatStatus.TextWrapped = true

local QuickToggleBox = Instance.new("Frame")
QuickToggleBox.Size = UDim2.new(1, 0, 0, 180)
QuickToggleBox.Position = UDim2.new(0, 0, 0, 162)
QuickToggleBox.BackgroundColor3 = Colors.CardBg
QuickToggleBox.BorderSizePixel = 0
QuickToggleBox.Parent = PageMain
addCornerAndStroke(QuickToggleBox, 8, Colors.Stroke, 1.2)

local BtnStagesQ = makeBtn(QuickToggleBox, UDim2.new(0.5, -12, 0, 36), UDim2.new(0, 8, 0, 8), Colors.Green, "Auto Stages: ON", 12, 6)
local BtnTunnel6Q = makeBtn(QuickToggleBox, UDim2.new(0.5, -12, 0, 36), UDim2.new(0.5, 4, 0, 8), Colors.Green, "Focus Tunnel 6: ON", 12, 6)

local BtnHatchQ = makeBtn(QuickToggleBox, UDim2.new(0.5, -12, 0, 36), UDim2.new(0, 8, 0, 50), Colors.Green, "Auto Hatch: ON", 12, 6)
local BtnBatchQ = makeBtn(QuickToggleBox, UDim2.new(0.5, -12, 0, 36), UDim2.new(0.5, 4, 0, 50), Colors.IceAccent, "Batch Size: 10", 12, 6)
BtnBatchQ.TextColor3 = Colors.DarkBg

local BtnMerchantsQ = makeBtn(QuickToggleBox, UDim2.new(0.5, -12, 0, 36), UDim2.new(0, 8, 0, 92), Colors.Green, "Merchants: ON", 12, 6)
local BtnUpgradesQ = makeBtn(QuickToggleBox, UDim2.new(0.5, -12, 0, 36), UDim2.new(0.5, 4, 0, 92), Colors.Green, "Upgrades: ON", 12, 6)

local BtnPotatoQ = makeBtn(QuickToggleBox, UDim2.new(0.5, -12, 0, 36), UDim2.new(0, 8, 0, 134), Colors.Green, "Potato FPS: ON", 12, 6)
local BtnBlackScreenQ = makeBtn(QuickToggleBox, UDim2.new(0.5, -12, 0, 36), UDim2.new(0.5, 4, 0, 134), Colors.CardBg, "Black Screen: OFF", 12, 6)

local ProgBox = Instance.new("Frame")
ProgBox.Size = UDim2.new(1, 0, 1, -10)
ProgBox.Position = UDim2.new(0, 0, 0, 4)
ProgBox.BackgroundColor3 = Colors.CardBg
ProgBox.BorderSizePixel = 0
ProgBox.Parent = PageProg
addCornerAndStroke(ProgBox, 8, Colors.Stroke, 1.5)

makeLabel(ProgBox, UDim2.new(1, -16, 0, 24), UDim2.new(0, 10, 0, 8), "AUTO STAGE PROGRESSION ENGINE", Colors.IceAccent, Enum.Font.SourceSansBold, 13)
makeLabel(ProgBox, UDim2.new(1, -16, 0, 38), UDim2.new(0, 10, 0, 32), "Automatically farms zone coins, hatches zone eggs, equips best pets, & breaks zone walls until Zone 6.", Colors.SubText, Enum.Font.SourceSans, 11).TextWrapped = true

local BtnToggleAutoStages = makeBtn(ProgBox, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 0, 78), Colors.Green, "Auto Progress Stages (1 -> 6): ON", 12, 6)
local BtnAutoEquipPets = makeBtn(ProgBox, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 0, 122), Colors.Green, "Auto Equip Best Pets: ON", 12, 6)
local BtnCollectRelicsNow = makeBtn(ProgBox, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 0, 166), Colors.Purple, "[*] Scan & Collect 6 PSX Relics", 12, 6)
local BtnAttackWallNow = makeBtn(ProgBox, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 0, 210), Colors.Gold, "[!] Force Attack Current Zone Wall", 12, 6)
BtnAttackWallNow.TextColor3 = Colors.DarkBg

local FarmBox = Instance.new("Frame")
FarmBox.Size = UDim2.new(1, 0, 1, -10)
FarmBox.Position = UDim2.new(0, 0, 0, 4)
FarmBox.BackgroundColor3 = Colors.CardBg
FarmBox.BorderSizePixel = 0
FarmBox.Parent = PageFarm
addCornerAndStroke(FarmBox, 8, Colors.Stroke, 1.5)

makeLabel(FarmBox, UDim2.new(1, -16, 0, 24), UDim2.new(0, 10, 0, 8), "TUNNEL 6 & ZONE 6 FARMING", Colors.IceAccent, Enum.Font.SourceSansBold, 13)
makeLabel(FarmBox, UDim2.new(1, -16, 0, 40), UDim2.new(0, 10, 0, 32), "Prioritizes Tunnel 6 (300x egg). If acorns run low, retreats to Zone 6 farm spot. If closed, farms Zone 6 & egg.", Colors.SubText, Enum.Font.SourceSans, 11).TextWrapped = true

local BtnToggleTunnel6 = makeBtn(FarmBox, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 0, 78), Colors.Green, "Focus Tunnel 6 (300x Lucky Egg): ON", 12, 6)
local BtnTeleportZone6Farm = makeBtn(FarmBox, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 0, 122), Colors.HeaderBg, "[*] Teleport to Zone 6 Farm Spot", 12, 6)
local BtnTeleportTunnel6Now = makeBtn(FarmBox, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 0, 166), Colors.Purple, "[*] Teleport to Tunnel 6 (Inside)", 12, 6)
local BtnCycleHatchBatch = makeBtn(FarmBox, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 0, 210), Colors.IceAccent, "Egg Hatch Batch: 10 eggs", 12, 6)
BtnCycleHatchBatch.TextColor3 = Colors.DarkBg

local MiscBox = Instance.new("Frame")
MiscBox.Size = UDim2.new(1, 0, 1, -10)
MiscBox.Position = UDim2.new(0, 0, 0, 4)
MiscBox.BackgroundColor3 = Colors.CardBg
MiscBox.BorderSizePixel = 0
MiscBox.Parent = PageMisc
addCornerAndStroke(MiscBox, 8, Colors.Stroke, 1.5)

makeLabel(MiscBox, UDim2.new(1, -16, 0, 24), UDim2.new(0, 10, 0, 8), "PERFORMANCE & AUTOMATION CONFIG", Colors.IceAccent, Enum.Font.SourceSansBold, 13)

local BtnToggleMerchants = makeBtn(MiscBox, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 38), Colors.Green, "Auto Buy Merchant Buffs: ON", 12, 6)
local BtnToggleUpgrades = makeBtn(MiscBox, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 80), Colors.Green, "Auto Buy Zone 1 Upgrades: ON", 12, 6)
local BtnTogglePotato = makeBtn(MiscBox, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 122), Colors.Green, "Potato Graphics (Mobile Anti-Lag): ON", 12, 6)
local BtnToggleBlackScreen = makeBtn(MiscBox, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 164), Colors.CardBg, "Black Screen AFK (OLED Battery Saver): OFF", 12, 6)
local BtnUnloadScript = makeBtn(MiscBox, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 206), Colors.Red, "[!] Unload Script Completely", 12, 6)

local batchSizes = { 1, 3, 10, 25, 50, 75, 100 }
local batchIdx = 3

local function updateBatchDisplay()
    local txt = "Batch Size: " .. tostring(Config.HatchBatch)
    BtnBatchQ.Text = txt
    BtnCycleHatchBatch.Text = "Egg Hatch Batch: " .. tostring(Config.HatchBatch) .. " eggs"
end

local function cycleBatch()
    batchIdx = batchIdx + 1
    if batchIdx > #batchSizes then batchIdx = 1 end
    Config.HatchBatch = batchSizes[batchIdx]
    updateBatchDisplay()
end

trackConn(BtnBatchQ.MouseButton1Click:Connect(cycleBatch))
trackConn(BtnCycleHatchBatch.MouseButton1Click:Connect(cycleBatch))

local function toggleAutoStages()
    Config.AutoStages = not Config.AutoStages
    local txt = Config.AutoStages and "Auto Stages: ON" or "Auto Stages: OFF"
    local bg = Config.AutoStages and Colors.Green or Colors.CardBg
    BtnStagesQ.Text = txt
    BtnStagesQ.BackgroundColor3 = bg
    BtnToggleAutoStages.Text = "Auto Progress Stages (1 -> 6): " .. (Config.AutoStages and "ON" or "OFF")
    BtnToggleAutoStages.BackgroundColor3 = bg
end

trackConn(BtnStagesQ.MouseButton1Click:Connect(toggleAutoStages))
trackConn(BtnToggleAutoStages.MouseButton1Click:Connect(toggleAutoStages))

local function toggleTunnel6()
    Config.FocusTunnel6 = not Config.FocusTunnel6
    local txt = Config.FocusTunnel6 and "Focus Tunnel 6: ON" or "Focus Tunnel 6: OFF"
    local bg = Config.FocusTunnel6 and Colors.Green or Colors.CardBg
    BtnTunnel6Q.Text = txt
    BtnTunnel6Q.BackgroundColor3 = bg
    BtnToggleTunnel6.Text = "Focus Tunnel 6 (300x Lucky Egg): " .. (Config.FocusTunnel6 and "ON" or "OFF")
    BtnToggleTunnel6.BackgroundColor3 = bg
end

trackConn(BtnTunnel6Q.MouseButton1Click:Connect(toggleTunnel6))
trackConn(BtnToggleTunnel6.MouseButton1Click:Connect(toggleTunnel6))

local function toggleHatch()
    Config.AutoHatch = not Config.AutoHatch
    local txt = Config.AutoHatch and "Auto Hatch: ON" or "Auto Hatch: OFF"
    local bg = Config.AutoHatch and Colors.Green or Colors.CardBg
    BtnHatchQ.Text = txt
    BtnHatchQ.BackgroundColor3 = bg
end

trackConn(BtnHatchQ.MouseButton1Click:Connect(toggleHatch))

local function toggleMerchants()
    Config.AutoBuyMerchants = not Config.AutoBuyMerchants
    local txt = Config.AutoBuyMerchants and "Merchants: ON" or "Merchants: OFF"
    local bg = Config.AutoBuyMerchants and Colors.Green or Colors.CardBg
    BtnMerchantsQ.Text = txt
    BtnMerchantsQ.BackgroundColor3 = bg
    BtnToggleMerchants.Text = "Auto Buy Merchant Buffs: " .. (Config.AutoBuyMerchants and "ON" or "OFF")
    BtnToggleMerchants.BackgroundColor3 = bg
end

trackConn(BtnMerchantsQ.MouseButton1Click:Connect(toggleMerchants))
trackConn(BtnToggleMerchants.MouseButton1Click:Connect(toggleMerchants))

local function toggleUpgrades()
    Config.AutoUpgrades = not Config.AutoUpgrades
    local txt = Config.AutoUpgrades and "Upgrades: ON" or "Upgrades: OFF"
    local bg = Config.AutoUpgrades and Colors.Green or Colors.CardBg
    BtnUpgradesQ.Text = txt
    BtnUpgradesQ.BackgroundColor3 = bg
    BtnToggleUpgrades.Text = "Auto Buy Zone 1 Upgrades: " .. (Config.AutoUpgrades and "ON" or "OFF")
    BtnToggleUpgrades.BackgroundColor3 = bg
end

trackConn(BtnUpgradesQ.MouseButton1Click:Connect(toggleUpgrades))
trackConn(BtnToggleUpgrades.MouseButton1Click:Connect(toggleUpgrades))

local function togglePotato()
    Config.PotatoGraphics = not Config.PotatoGraphics
    local txt = Config.PotatoGraphics and "Potato FPS: ON" or "Potato FPS: OFF"
    local bg = Config.PotatoGraphics and Colors.Green or Colors.CardBg
    BtnPotatoQ.Text = txt
    BtnPotatoQ.BackgroundColor3 = bg
    BtnTogglePotato.Text = "Potato Graphics (Mobile Anti-Lag): " .. (Config.PotatoGraphics and "ON" or "OFF")
    BtnTogglePotato.BackgroundColor3 = bg
    applyPotatoGraphics(Config.PotatoGraphics)
end

trackConn(BtnPotatoQ.MouseButton1Click:Connect(togglePotato))
trackConn(BtnTogglePotato.MouseButton1Click:Connect(togglePotato))

local function toggleBlackScreen()
    Config.BlackScreen = not Config.BlackScreen
    local txt = Config.BlackScreen and "Black Screen: ON" or "Black Screen: OFF"
    local bg = Config.BlackScreen and Colors.Green or Colors.CardBg
    BtnBlackScreenQ.Text = txt
    BtnBlackScreenQ.BackgroundColor3 = bg
    BtnToggleBlackScreen.Text = "Black Screen AFK (OLED Battery Saver): " .. (Config.BlackScreen and "ON" or "OFF")
    BtnToggleBlackScreen.BackgroundColor3 = bg
    BlackScreenFrame.Visible = Config.BlackScreen
end

trackConn(BtnBlackScreenQ.MouseButton1Click:Connect(toggleBlackScreen))
trackConn(BtnToggleBlackScreen.MouseButton1Click:Connect(toggleBlackScreen))

trackConn(BtnAutoEquipPets.MouseButton1Click:Connect(function()
    Config.AutoEquipBest = not Config.AutoEquipBest
    BtnAutoEquipPets.Text = "Auto Equip Best Pets: " .. (Config.AutoEquipBest and "ON" or "OFF")
    BtnAutoEquipPets.BackgroundColor3 = Config.AutoEquipBest and Colors.Green or Colors.CardBg
    if Config.AutoEquipBest then autoEquipBestPets() end
end))

trackConn(BtnCollectRelicsNow.MouseButton1Click:Connect(function()
    scanAndCollectSecretRelics()
end))

trackConn(BtnAttackWallNow.MouseButton1Click:Connect(function()
    local wall, wallPos = findActiveBreakableWall(State.CurrentZone)
    if wall then
        attackTargetWall(wall)
        State.CurrentActionText = "Manual Force Attacking Wall: " .. tostring(wall.Name)
    end
end))

trackConn(BtnTeleportZone6Farm.MouseButton1Click:Connect(function()
    if State.ZoneFarmPositions[6] then
        teleportSafely(State.ZoneFarmPositions[6])
    else
        pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                State.ZoneFarmPositions[6] = hrp.CFrame
                State.CurrentActionText = "Zone 6 spot set to current position!"
            end
        end)
    end
end))

trackConn(BtnTeleportTunnel6Now.MouseButton1Click:Connect(function()
    if State.Tunnel6CF then
        teleportSafely(State.Tunnel6CF)
    else
        pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                State.Tunnel6CF = hrp.CFrame
                State.CurrentActionText = "Tunnel 6 spot set to current position!"
            end
        end)
    end
end))

local function analyzeWorldZonesAndGates()
    local now = os.clock()
    if now - State.LastZoneScanTime < Config.ZoneCheckInterval then return end
    State.LastZoneScanTime = now

    pcall(function()
        local things = getThingsFolder()
        if not things then return end

        for _, obj in ipairs(Workspace:GetDescendants()) do
            local low = string.lower(obj.Name)
            if string.find(low, "tunnel6") or string.find(low, "300x") or (string.find(low, "tunnel") and string.find(low, "6")) then
                local cf = getObjectCFrame(obj)
                if cf then
                    State.Tunnel6CF = cf
                    State.Tunnel6Open = true
                end
            elseif string.find(low, "zone 6") or string.find(low, "zone6") or string.find(low, "mountain_peak") then
                local cf = getObjectCFrame(obj)
                if cf and not State.ZoneFarmPositions[6] then
                    State.ZoneFarmPositions[6] = cf
                end
            end
        end
    end)
end

local function runStageProgressionStep()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local myPos = hrp.Position

    local wallObj, wallPos = findActiveBreakableWall(State.CurrentZone)
    if wallObj and wallPos then
        State.CurrentWallTarget = wallObj
        State.CurrentWallPosition = wallPos

        local distToWall = (myPos - wallPos).Magnitude
        if distToWall > 25 then
            teleportSafely(CFrame.new(wallPos + Vector3.new(0, 0, 14), wallPos))
        end

        State.CurrentActionText = string.format("Zone %d: Pets Attacking Wall [%s]...", State.CurrentZone, tostring(wallObj.Name))
        attackTargetWall(wallObj)
        farmNearbyAcorns(wallPos, 60)
        activateZoneAutoFarmRemote()

        local now = os.clock()
        if now - State.LastHatchTime >= 1.2 and State.CurrentAcorns >= 50 then
            local eggObj, eggId, eggPos = findNearestEggMachine(90)
            if eggObj and eggId then
                hatchTargetEgg(eggId, Config.HatchBatch)
            end
        end
        return
    else
        State.CurrentWallTarget = nil
        State.CurrentWallPosition = nil

        local eggObj, eggId, eggPos = findNearestEggMachine(75)
        if eggObj and eggPos then
            if not State.ZoneEggPositions[State.CurrentZone] then
                State.ZoneEggPositions[State.CurrentZone] = CFrame.new(eggPos)
            end
            if Config.AutoHatch and State.CurrentAcorns >= 50 then
                hatchTargetEgg(eggId, Config.HatchBatch)
            end
        end

        farmNearbyAcorns(myPos, 75)
        activateZoneAutoFarmRemote()

        pcall(function()
            local nextStepCF = hrp.CFrame + (hrp.CFrame.LookVector * 28)
            teleportSafely(nextStepCF)
        end)

        State.CurrentActionText = string.format("Zone %d Wall Broken! Advancing forward...", State.CurrentZone)
    end
end

local function runTunnel6AndZone6Loop()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local myPos = hrp.Position

    if Config.FocusTunnel6 and State.Tunnel6Open and State.Tunnel6CF then
        if State.CurrentAcorns >= Config.MinAcornsForTunnel then
            if (myPos - State.Tunnel6CF.Position).Magnitude > 35 then
                teleportSafely(State.Tunnel6CF)
                task.wait(0.25)
            end
            State.InTunnel6 = true
            State.AtZoneFarm = false
            State.CurrentActionText = "In Tunnel 6: Hatching 300x Egg! | by pufyftyk"

            local eggObj, eggId = findNearestEggMachine(85)
            if eggObj and eggId then
                hatchTargetEgg(eggId, Config.HatchBatch)
            else
                pressKeyE(0.1)
            end
        else
            if State.ZoneFarmPositions[6] and (myPos - State.ZoneFarmPositions[6].Position).Magnitude > 35 then
                teleportSafely(State.ZoneFarmPositions[6])
                task.wait(0.25)
            end
            State.InTunnel6 = false
            State.AtZoneFarm = true
            State.CurrentActionText = "Acorns Low! Farming Zone 6 Acorns... | by pufyftyk"

            farmNearbyAcorns(myPos, 90)
            activateZoneAutoFarmRemote()
        end
    else
        if State.ZoneFarmPositions[6] and (myPos - State.ZoneFarmPositions[6].Position).Magnitude > 35 then
            teleportSafely(State.ZoneFarmPositions[6])
            task.wait(0.25)
        end
        State.InTunnel6 = false
        State.AtZoneFarm = true
        State.CurrentActionText = "Tunnel 6 Closed/Cooldown: Farming Zone 6 & Egg | by pufyftyk"

        farmNearbyAcorns(myPos, 90)
        activateZoneAutoFarmRemote()

        local eggObj, eggId = findNearestEggMachine(80)
        if eggObj and eggId and Config.AutoHatch and State.CurrentAcorns >= 50 then
            hatchTargetEgg(eggId, Config.HatchBatch)
        end
    end
end

task.spawn(function()
    applyPotatoGraphics(Config.PotatoGraphics)
    autoEquipBestPets()

    while State.Running do
        updatePlayerInventoryAndCurrencies()
        analyzeWorldZonesAndGates()

        if Config.AutoStages and State.CurrentZone < Config.TargetMaxZone then
            runStageProgressionStep()
        else
            runTunnel6AndZone6Loop()
        end

        checkAndBuyMerchantStalls()
        checkAndBuyUpgrades()
        scanAndCollectSecretRelics()

        local elapsed = os.clock() - State.StartTime
        StatTime.Text = "Time: " .. formatDuration(elapsed)
        StatGems.Text = string.format("Gems: +%s (Total: %s)", formatNumber(State.DiamondsGained), formatNumber(State.CurrentDiamonds))
        StatAcorns.Text = string.format("Acorns: %s (+%s)", formatNumber(State.CurrentAcorns), formatNumber(State.AcornsGained))
        StatEggs.Text = "Eggs Opened: " .. formatNumber(State.EggsHatched)
        StatPets.Text = string.format("Huges: %d | Titanics: %d", State.HugesHatched, State.TitanicsHatched)
        StatRelics.Text = string.format("PSX Relics: %d/6", State.RelicsCollected)
        StatZone.Text = string.format("Current Zone: Zone %d / %d", State.CurrentZone, Config.TargetMaxZone)
        StatStatus.Text = State.CurrentActionText

        task.wait(0.18)
    end
end)

local function cleanupAll()
    State.Running = false
    for _, conn in ipairs(ActiveConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ActiveConnections = {}
    if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
    if BlackScreenFrame then pcall(function() BlackScreenFrame:Destroy() end) end
end

env.DiamondMountainMasterCleanup = cleanupAll
trackConn(BtnUnloadScript.MouseButton1Click:Connect(cleanupAll))
