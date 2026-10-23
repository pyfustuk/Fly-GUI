local _CREATOR = "by pufyftyk"
local _PROJECT = "Cameraman Tower Defense Deep Mathematical Strategist AI Masterpiece"
local _VERSION = "10.0.0"

pcall(function()
    local players = game:GetService("Players")
    local lp = players.LocalPlayer
    local vu = game:GetService("VirtualUser")

    if type(getconnections) == "function" then
        pcall(function()
            for _, conn in ipairs(getconnections(lp.Idled)) do
                pcall(function()
                    if conn and conn.Disable then conn:Disable() end
                end)
            end
        end)
    end

    pcall(function()
        lp.Idled:Connect(function()
            pcall(function()
                if vu then
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new(0, 0))
                end
            end)
        end)
    end)

    task.spawn(function()
        local c = 0
        while true do
            task.wait(15)
            c = c + 1
            pcall(function()
                if vu then
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new(0, 0))
                end
            end)
            if c % 4 == 0 then
                pcall(function()
                    local char = lp.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Jump = true end
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
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local getgenv = getgenv or function() return _G end
local env = getgenv()

if env.CameramanTDHubCleanup then
    pcall(env.CameramanTDHubCleanup)
end

local ActiveConnections = {}
local function trackConn(conn)
    if conn then table.insert(ActiveConnections, conn) end
    return conn
end

local Config = {
    AutonomousAI = true,
    StrategyMode = "TITAN_RUSH_FARM",
    AutoSkip = true,
    AutoVote = true,
    VoteDifficulty = "Nightmare",
    AutoSpeed = true,
    TargetSpeed = 2,
    AutoPlayAgain = true,
    AutoClaimQuests = true,
    AutoClaimPass = true,
    FPSBoost = false,
    AntiAFK = true,
    SellFarmsWave = 27,
    FinalWave = 30,
    MinTowerSpacing = 5.0,
    ChokeOffset = 9.5,
    FarmOffset = 22.0,
    UpgradeCooldown = 1.35,
    PlacementCooldown = 0.45
}

local State = {
    Running = true,
    Phase = "BOOT",
    SubPhase = "IDLE",
    StatusLog = {},
    MaxLogLines = 40,
    CurrentWave = 0,
    WaveString = "Lobby",
    Cash = 0,
    CurrentTowersCount = 0,
    MaxTowersCount = 15,
    RequiredDPS = 0,
    CalculatedArmyDPS = 0,
    CalculatedFarmIncome = 0,
    ThreatRatio = 0.0,
    SpeedConfirmed = 1,
    FarmsSold = false,
    LastDecisionTime = 0,
    LastVoteTime = 0,
    LastSpeedAttempt = 0,
    LastSkipWave = -1,
    LastClaimTime = 0,
    LastReplayTime = 0,
    SelectedTab = "Dashboard",
    Waypoints = {},
    FrontChokePoints = {},
    RearSafePoints = {},
    PlacedTowers = {},
    TowerUpgradeTimers = {},
    EquippedUnits = {},
    DetectedUUIDs = {},
    IdentifiedTitan = nil,
    IdentifiedFarm = nil,
    IdentifiedStarter = nil,
    PendingPlacements = {},
    PendingUpgrades = {},
    Tokens = 6,
    MaxTokens = 6,
    TokenRefillClock = os.clock(),
    TokenRate = 5
}

local function appendLog(msg)
    local timestamp = os.date("%H:%M:%S")
    local line = string.format("[%s] %s", timestamp, msg)
    table.insert(State.StatusLog, line)
    if #State.StatusLog > State.MaxLogLines then
        table.remove(State.StatusLog, 1)
    end
end

appendLog("Cameraman TD AI Masterpiece initializing...")

local function takeToken()
    local now = os.clock()
    local delta = now - State.TokenRefillClock
    State.TokenRefillClock = now
    State.Tokens = math.min(State.MaxTokens, State.Tokens + (delta * State.TokenRate))
    if State.Tokens >= 1 then
        State.Tokens = State.Tokens - 1
        return true
    end
    return false
end

local function getNetworkFolder(subFolder)
    local ml = ReplicatedStorage:FindFirstChild("ModuleLoader")
    if not ml then return nil end
    local sh = ml:FindFirstChild("Shared")
    if not sh then return nil end
    local net = sh:FindFirstChild("Network")
    if not net then return nil end
    return net:FindFirstChild(subFolder)
end

local function fireRemote(name, ...)
    if not takeToken() then return false end
    local folder = getNetworkFolder("RemoteEvent")
    if not folder then return false end
    local rem = folder:FindFirstChild(name)
    if rem and rem:IsA("RemoteEvent") then
        local payload = { ... }
        return pcall(function()
            rem:FireServer(table.unpack(payload))
        end)
    end
    return false
end

local function invokeRemote(name, ...)
    if not takeToken() then return false end
    local folder = getNetworkFolder("RemoteFunction")
    if not folder then return false end
    local rem = folder:FindFirstChild(name)
    if rem and rem:IsA("RemoteFunction") then
        local payload = { ... }
        return pcall(function()
            return rem:InvokeServer(table.unpack(payload))
        end)
    end
    return false
end

local function getGameUI()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        return pg:FindFirstChild("GameUI")
    end
    return nil
end

local function isMatchActive()
    local gui = getGameUI()
    if not gui then return false end
    local stats = gui:FindFirstChild("Stats")
    if not stats or not stats.Visible then return false end
    local finalUI = gui:FindFirstChild("FinalUI")
    if finalUI and finalUI.Visible then return false end
    return true
end

local function updateGameState()
    local gui = getGameUI()
    if gui then
        local stats = gui:FindFirstChild("Stats")
        if stats then
            local waveLbl = stats:FindFirstChild("Wave")
            if waveLbl and waveLbl:IsA("TextLabel") then
                local txt = waveLbl.Text
                State.WaveString = txt
                local num = string.match(txt, "[Ww]ave%s*(%d+)")
                if num then
                    State.CurrentWave = tonumber(num) or 0
                else
                    State.CurrentWave = 0
                end
            end
            local other = stats:FindFirstChild("OtherUI")
            if other then
                local moneyBox = other:FindFirstChild("Money")
                if moneyBox then
                    local title = moneyBox:FindFirstChild("Title")
                    if title and title:IsA("TextLabel") then
                        local stripped = string.gsub(title.Text, ",", "")
                        local found = string.match(stripped, "%d+%.?%d*")
                        if found then
                            State.Cash = tonumber(found) or 0
                        end
                    end
                end
                local towersBox = other:FindFirstChild("Towers")
                if towersBox and towersBox:IsA("TextLabel") then
                    local cur, maxT = string.match(towersBox.Text, "(%d+)%s*/%s*(%d+)")
                    if cur and maxT then
                        State.CurrentTowersCount = tonumber(cur) or 0
                        State.MaxTowersCount = tonumber(maxT) or 15
                    end
                end
            end
        end
    end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local mVal = ls:FindFirstChild("Money")
        if mVal and mVal:IsA("ValueBase") then
            local n = tonumber(mVal.Value)
            if n and n > 0 then
                State.Cash = n
            end
        end
    end
    local w = math.max(1, State.CurrentWave)
    State.RequiredDPS = math.floor(70 * (w^1.38))
end

local function readReplicaTowers()
    local loaded = (type(getloadedmodules) == "function") and getloadedmodules() or {}
    for _, mod in ipairs(loaded) do
        if mod:IsA("ModuleScript") then
            local low = string.lower(mod.Name)
            if string.find(low, "replica", 1, true) or string.find(low, "playerdata", 1, true) or string.find(low, "inventory", 1, true) then
                local ok, res = pcall(require, mod)
                if ok and type(res) == "table" then
                    for _, entry in pairs(res) do
                        if type(entry) == "table" then
                            local data = rawget(entry, "Data")
                            if type(data) == "table" and type(rawget(data, "Towers")) == "table" then
                                return rawget(data, "Towers")
                            end
                        end
                    end
                end
            end
        end
    end
    if type(getgc) == "function" then
        local gc = getgc(true)
        for _, obj in pairs(gc) do
            if type(obj) == "table" then
                local data = rawget(obj, "Data")
                if type(data) == "table" and type(rawget(data, "Towers")) == "table" then
                    return rawget(data, "Towers")
                end
            end
        end
    end
    return nil
end

local function scanHotbarSlots()
    local gui = getGameUI()
    if not gui then return {} end
    local slotsFolder = gui:FindFirstChild("Slots")
    if not slotsFolder then return {} end
    local result = {}
    for i = 1, 6 do
        local slot = slotsFolder:FindFirstChild("Slot" .. tostring(i))
        if slot then
            local tf = slot:FindFirstChild("TroopFrame")
            if tf then
                local priceLabel = tf:FindFirstChild("Price")
                local cost = 300
                if priceLabel and priceLabel:IsA("TextLabel") then
                    local clean = string.gsub(priceLabel.Text, ",", "")
                    local n = tonumber(string.match(clean, "%d+"))
                    if n then cost = n end
                end
                local unitName = ""
                for _, desc in ipairs(tf:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc ~= priceLabel then
                        local t = desc.Text
                        if t and #t > 1 and not string.find(t, "^%$") and not string.match(t, "^%d+$") then
                            unitName = t
                            break
                        end
                    end
                end
                if unitName == "" then
                    local img = tf:FindFirstChildOfClass("ImageLabel")
                    if img then unitName = img.Name end
                end
                if unitName ~= "" then
                    table.insert(result, {
                        SlotNumber = i,
                        Name = unitName,
                        Cost = cost
                    })
                end
            end
        end
    end
    return result
end

local function scanFullRoster()
    local inventoryTowers = readReplicaTowers()
    local slots = scanHotbarSlots()
    local classified = {}

    if inventoryTowers then
        for uuid, tData in pairs(inventoryTowers) do
            if type(tData) == "table" and tData.Name then
                State.DetectedUUIDs[tData.Name] = tostring(uuid)
                local eq = tonumber(tData.Equipped) or (tData.Equipped == true and 1 or 0)
                if eq > 0 then
                    local low = string.lower(tData.Name)
                    local basePrice = 300
                    local role = "COMBAT"
                    if string.find(low, "scientist", 1, true) or string.find(low, "farm", 1, true) then
                        role = "FARM"
                        basePrice = 400
                    elseif string.find(low, "titan", 1, true) or string.find(low, "tv", 1, true) or string.find(low, "speaker", 1, true) then
                        role = "TITAN"
                        basePrice = 1200
                    else
                        role = "STARTER"
                        basePrice = 200
                    end
                    table.insert(classified, {
                        SlotNumber = eq,
                        Name = tData.Name,
                        Cost = basePrice,
                        Role = role,
                        UUID = tostring(uuid)
                    })
                end
            end
        end
    end

    if #classified == 0 and #slots > 0 then
        for _, s in ipairs(slots) do
            local low = string.lower(s.Name)
            local role = "COMBAT"
            if string.find(low, "scientist", 1, true) or string.find(low, "farm", 1, true) then
                role = "FARM"
            elseif string.find(low, "titan", 1, true) or string.find(low, "tv", 1, true) or string.find(low, "speaker", 1, true) or s.Cost >= 800 then
                role = "TITAN"
            elseif s.Cost <= 400 then
                role = "STARTER"
            end
            table.insert(classified, {
                SlotNumber = s.SlotNumber,
                Name = s.Name,
                Cost = s.Cost,
                Role = role,
                UUID = State.DetectedUUIDs[s.Name] or ("uuid_slot_" .. tostring(s.SlotNumber))
            })
        end
    end

    if #classified == 0 then
        classified = {
            { SlotNumber = 1, Name = "Scientist Cameraman", Cost = 400, Role = "FARM", UUID = "farm_mock" },
            { SlotNumber = 2, Name = "Titan TV Man", Cost = 1200, Role = "TITAN", UUID = "titan_mock" },
            { SlotNumber = 3, Name = "Cameraman", Cost = 200, Role = "STARTER", UUID = "starter_mock" }
        }
    end

    State.EquippedUnits = classified
    State.IdentifiedTitan = nil
    State.IdentifiedFarm = nil
    State.IdentifiedStarter = nil

    for _, u in ipairs(classified) do
        if u.Role == "TITAN" and (not State.IdentifiedTitan or string.find(string.lower(u.Name), "tv", 1, true)) then
            State.IdentifiedTitan = u
        elseif u.Role == "FARM" and not State.IdentifiedFarm then
            State.IdentifiedFarm = u
        elseif u.Role == "STARTER" and not State.IdentifiedStarter then
            State.IdentifiedStarter = u
        end
    end

    if not State.IdentifiedTitan then State.IdentifiedTitan = classified[1] end
    if not State.IdentifiedStarter then State.IdentifiedStarter = classified[#classified] end
    appendLog(string.format("Roster identified: Carry=[%s], Farm=[%s], Starter=[%s]",
        State.IdentifiedTitan.Name,
        State.IdentifiedFarm and State.IdentifiedFarm.Name or "None",
        State.IdentifiedStarter and State.IdentifiedStarter.Name or "None"
    ))
end

local function projectFloor(vec)
    local origin = Vector3.new(vec.X, vec.Y + 30, vec.Z)
    local dir = Vector3.new(0, -80, 0)
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    if LocalPlayer.Character then
        p.FilterDescendantsInstances = { LocalPlayer.Character }
    end
    local hit = Workspace:Raycast(origin, dir, p)
    if hit and hit.Position then
        return hit.Position
    end
    return vec
end

local function computeSpatialGeometry()
    local gameFolder = Workspace:FindFirstChild("Game")
    if not gameFolder then return end
    local wpFolder = gameFolder:FindFirstChild("Waypoints")
    if not wpFolder then return end
    local raw = {}
    for _, part in ipairs(wpFolder:GetChildren()) do
        if part:IsA("BasePart") then
            local idx = tonumber(string.match(part.Name, "%d+")) or 0
            table.insert(raw, { Part = part, Index = idx, Position = part.Position })
        end
    end
    if #raw < 2 then return end
    table.sort(raw, function(a, b) return a.Index < b.Index end)
    State.Waypoints = {}
    for _, item in ipairs(raw) do
        table.insert(State.Waypoints, item.Position)
    end
    local frontChokes = {}
    local rearSafes = {}
    local total = #State.Waypoints
    for i = 2, total - 1 do
        local pPrev = State.Waypoints[i - 1]
        local pCurr = State.Waypoints[i]
        local pNext = State.Waypoints[i + 1]
        local vPrev = (pCurr - pPrev).Unit
        local vNext = (pNext - pCurr).Unit
        local curvature = 1 - math.clamp(vPrev:Dot(vNext), -1, 1)
        local tangent = (vPrev + vNext).Unit
        local normal = Vector3.new(-tangent.Z, 0, tangent.X).Unit
        local leftFront = projectFloor(pCurr + (normal * Config.ChokeOffset))
        local rightFront = projectFloor(pCurr - (normal * Config.ChokeOffset))
        local leftRear = projectFloor(pCurr + (normal * Config.FarmOffset))
        local rightRear = projectFloor(pCurr - (normal * Config.FarmOffset))
        table.insert(frontChokes, {
            Index = i,
            Position = leftFront,
            Curvature = curvature,
            Side = "LEFT"
        })
        table.insert(frontChokes, {
            Index = i,
            Position = rightFront,
            Curvature = curvature,
            Side = "RIGHT"
        })
        table.insert(rearSafes, {
            Index = i,
            Position = leftRear,
            Side = "LEFT_REAR"
        })
        table.insert(rearSafes, {
            Index = i,
            Position = rightRear,
            Side = "RIGHT_REAR"
        })
    end
    table.sort(frontChokes, function(a, b)
        if a.Index <= 4 and b.Index > 4 then
            return true
        elseif b.Index <= 4 and a.Index > 4 then
            return false
        end
        return a.Curvature > b.Curvature
    end)
    State.FrontChokePoints = frontChokes
    State.RearSafePoints = rearSafes
    appendLog(string.format("Geometry compiled: %d Waypoints, %d Choke anchors, %d Rear anchors", #State.Waypoints, #frontChokes, #rearSafes))
end

local function scanBoardTowers()
    local gameFolder = Workspace:FindFirstChild("Game")
    State.PlacedTowers = {}
    State.CalculatedArmyDPS = 0
    State.CalculatedFarmIncome = 0
    local farmCount = 0
    local combatCount = 0
    if not gameFolder then return farmCount, combatCount end
    local towersFolder = gameFolder:FindFirstChild("Towers")
    if not towersFolder then return farmCount, combatCount end
    for _, model in ipairs(towersFolder:GetChildren()) do
        local isMine = false
        local ownerAttr = model:GetAttribute("OwnerUserId") or model:GetAttribute("Owner")
        if ownerAttr then
            if tonumber(ownerAttr) == LocalPlayer.UserId or tostring(ownerAttr) == LocalPlayer.Name then
                isMine = true
            end
        else
            isMine = true
        end
        if isMine then
            local pos = Vector3.zero
            if model:IsA("Model") then
                pos = model:GetPivot().Position
            elseif model:IsA("BasePart") then
                pos = model.Position
            end
            local tName = model.Name
            local low = string.lower(tName)
            local isFarm = string.find(low, "scientist", 1, true) or string.find(low, "farm", 1, true)
            local isTitan = string.find(low, "titan", 1, true) or string.find(low, "tv", 1, true)
            local level = tonumber(model:GetAttribute("Level")) or 1
            local dps = 0
            local inc = 0
            if isFarm then
                inc = 150 + (level * 140)
                farmCount = farmCount + 1
                State.CalculatedFarmIncome = State.CalculatedFarmIncome + inc
            else
                if isTitan then
                    dps = 850 + (level * 700)
                else
                    dps = 120 + (level * 160)
                end
                combatCount = combatCount + 1
                State.CalculatedArmyDPS = State.CalculatedArmyDPS + dps
            end
            table.insert(State.PlacedTowers, {
                Id = model.Name,
                Model = model,
                Position = pos,
                Level = level,
                IsFarm = isFarm,
                IsTitan = isTitan,
                Dps = dps,
                Income = inc
            })
        end
    end
    return farmCount, combatCount
end

local function isPositionAvailable(targetPos)
    for _, t in ipairs(State.PlacedTowers) do
        local d = (Vector2.new(targetPos.X, targetPos.Z) - Vector2.new(t.Position.X, t.Position.Z)).Magnitude
        if d < Config.MinTowerSpacing then
            return false
        end
    end
    return true
end

local function acquirePlacementAnchor(targetRole)
    if #State.FrontChokePoints == 0 then
        computeSpatialGeometry()
    end
    if targetRole == "FARM" then
        for _, pt in ipairs(State.RearSafePoints) do
            if isPositionAvailable(pt.Position) then
                return pt.Position
            end
        end
        for i = #State.FrontChokePoints, 1, -1 do
            local pt = State.FrontChokePoints[i]
            if isPositionAvailable(pt.Position) then
                return pt.Position
            end
        end
    else
        for _, pt in ipairs(State.FrontChokePoints) do
            if isPositionAvailable(pt.Position) then
                return pt.Position
            end
        end
    end
    if #State.Waypoints >= 2 then
        local emergency = State.Waypoints[2] + Vector3.new(Config.ChokeOffset, 0, 0)
        local flr = projectFloor(emergency)
        if isPositionAvailable(flr) then
            return flr
        end
    end
    return nil
end

local function deployUnit(unit, anchor)
    if State.CurrentTowersCount >= State.MaxTowersCount then
        appendLog(string.format("Cannot deploy %s: Tower limit reached (%d/%d)", unit.Name, State.CurrentTowersCount, State.MaxTowersCount))
        return false
    end
    local uuid = unit.UUID or State.DetectedUUIDs[unit.Name] or "uuid_unit"
    local cf = CFrame.new(anchor)
    fireRemote("TowerAdd", {
        Name = unit.Name,
        UnitId = uuid,
        Pos = anchor,
        CFrame = cf
    })
    appendLog(string.format("DEPLOYED: %s at Choke position", unit.Name))
    return true
end

local function upgradeTower(tower)
    local now = os.clock()
    local lastUp = State.TowerUpgradeTimers[tower.Id] or 0
    if now - lastUp < Config.UpgradeCooldown then
        return false
    end
    if tower.Level >= 5 then
        return false
    end
    State.TowerUpgradeTimers[tower.Id] = now
    fireRemote("TowerUpgrade", { Id = tower.Id })
    appendLog(string.format("UPGRADE: %s [Lv%d -> Lv%d]", tower.IsTitan and "Titan" or (tower.IsFarm and "Farm" or "Tower"), tower.Level, tower.Level + 1))
    return true
end

local function runStrategistDecisionLoop()
    if not isMatchActive() then
        State.Phase = "LOBBY_WAIT"
        return
    end
    updateGameState()
    local farmCount, combatCount = scanBoardTowers()
    local wave = State.CurrentWave
    local cash = State.Cash
    local now = os.clock()
    if now - State.LastDecisionTime < Config.PlacementCooldown then
        return
    end
    State.LastDecisionTime = now

    if wave >= Config.SellFarmsWave and not State.FarmsSold then
        State.FarmsSold = true
        State.Phase = "LIQUIDATION_BOSS_PURGE"
        appendLog("Wave 27 reached! Liquidating all farms for Terminal Boss DPS!")
        for _, t in ipairs(State.PlacedTowers) do
            if t.IsFarm then
                fireRemote("TowerSell", { Id = t.Id })
            end
        end
        return
    end

    local titan = State.IdentifiedTitan
    local farm = State.IdentifiedFarm
    local starter = State.IdentifiedStarter

    if combatCount == 0 then
        State.Phase = "EARLY_SECURITY"
        if starter and cash >= starter.Cost then
            local anchor = acquirePlacementAnchor("COMBAT")
            if anchor then
                deployUnit(starter, anchor)
                return
            end
        end
    end

    local hasTitanOnBoard = false
    for _, t in ipairs(State.PlacedTowers) do
        if t.IsTitan then
            hasTitanOnBoard = true
            break
        end
    end

    if wave <= 3 and combatCount >= 1 then
        for _, t in ipairs(State.PlacedTowers) do
            if not t.IsFarm and t.Level < 2 and cash >= 150 then
                if upgradeTower(t) then return end
            end
        end
    end

    if farm and farmCount < 2 and wave <= 10 and wave < Config.SellFarmsWave then
        State.Phase = "SEED_FARMS"
        if cash >= farm.Cost then
            local anchor = acquirePlacementAnchor("FARM")
            if anchor then
                deployUnit(farm, anchor)
                return
            end
        else
            State.SubPhase = string.format("Accumulating Farm #%d ($%d/$%d)", farmCount + 1, cash, farm.Cost)
            return
        end
    end

    if titan and not hasTitanOnBoard then
        State.Phase = "TITAN_ACCUMULATION"
        if cash >= titan.Cost then
            local anchor = acquirePlacementAnchor("TITAN")
            if anchor then
                deployUnit(titan, anchor)
                return
            end
        else
            State.SubPhase = string.format("SAVING FOR %s ($%d/$%d)", titan.Name, cash, titan.Cost)
            return
        end
    end

    if hasTitanOnBoard then
        State.Phase = "TITAN_APEX_UPGRADE"
        for _, t in ipairs(State.PlacedTowers) do
            if t.IsTitan and t.Level < 5 and cash >= (350 * t.Level) then
                if upgradeTower(t) then return end
            end
        end
    end

    if farm and farmCount < 4 and wave <= 18 and wave < Config.SellFarmsWave then
        State.Phase = "EXPAND_FARMS"
        if cash >= farm.Cost then
            local anchor = acquirePlacementAnchor("FARM")
            if anchor then
                deployUnit(farm, anchor)
                return
            end
        end
    end

    if farmCount > 0 and wave < 23 then
        for _, t in ipairs(State.PlacedTowers) do
            if t.IsFarm and t.Level < 3 and cash >= (300 * t.Level) then
                if upgradeTower(t) then return end
            end
        end
    end

    if titan and combatCount < State.MaxTowersCount and cash >= titan.Cost and wave >= 13 then
        State.Phase = "SECONDARY_TITAN_REINFORCE"
        local anchor = acquirePlacementAnchor("TITAN")
        if anchor then
            deployUnit(titan, anchor)
            return
        end
    end

    for _, t in ipairs(State.PlacedTowers) do
        if not t.IsFarm and t.Level < 5 and cash >= (250 * t.Level) then
            if upgradeTower(t) then return end
        end
    end

    State.Phase = "ACTIVE_DEFENSE"
    State.SubPhase = string.format("Army DPS: %d | Req DPS: %d | Wave: %d", State.CalculatedArmyDPS, State.RequiredDPS, wave)
end

local function handleMatchFlow()
    local wave = State.CurrentWave
    if Config.AutoVote then
        local now = os.clock()
        if now - State.LastVoteTime > 3 then
            local low = string.lower(State.WaveString)
            if string.find(low, "voting", 1, true) or string.find(low, "intermission", 1, true) then
                State.LastVoteTime = now
                fireRemote("ModeVote", Config.VoteDifficulty)
                appendLog(string.format("Auto-Vote cast: %s", Config.VoteDifficulty))
            end
        end
    end
    if Config.AutoSpeed and isMatchActive() then
        local now = os.clock()
        if now - State.LastSpeedAttempt > 4 and State.SpeedConfirmed ~= Config.TargetSpeed then
            State.LastSpeedAttempt = now
            local ok, res = invokeRemote("ChangeSpeed", Config.TargetSpeed)
            if ok and res == true then
                State.SpeedConfirmed = Config.TargetSpeed
                appendLog(string.format("Game speed locked: %dx", Config.TargetSpeed))
            elseif ok and res == false and Config.TargetSpeed == 2 then
                Config.TargetSpeed = 1.5
                invokeRemote("ChangeSpeed", 1.5)
                appendLog("2x Speed unavailable. Reverting to 1.5x")
            end
        end
    end
    if Config.AutoSkip and isMatchActive() then
        local gui = getGameUI()
        if gui then
            local stats = gui:FindFirstChild("Stats")
            if stats then
                local skipGui = stats:FindFirstChild("WaveSkipGui")
                if skipGui and skipGui.Visible and State.LastSkipWave ~= wave then
                    State.LastSkipWave = wave
                    fireRemote("WaveSkip")
                    appendLog(string.format("Wave %d skipped instantly!", wave))
                end
            end
        end
    end
    if Config.AutoPlayAgain then
        local gui = getGameUI()
        if gui then
            local finalUI = gui:FindFirstChild("FinalUI")
            if finalUI and finalUI.Visible then
                local now = os.clock()
                if now - State.LastReplayTime > 5 then
                    State.LastReplayTime = now
                    fireRemote("PlayAgain")
                    appendLog("Match concluded! Requesting PlayAgain replay.")
                end
            end
        end
    end
end

local function handleRewards()
    if not Config.AutoClaimQuests and not Config.AutoClaimPass then return end
    local now = os.clock()
    if now - State.LastClaimTime < 6 then return end
    State.LastClaimTime = now
    if Config.AutoClaimQuests then
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            local mainGui = pg:FindFirstChild("Main")
            if mainGui then
                local mFrame = mainGui:FindFirstChild("Main")
                if mFrame then
                    local q = mFrame:FindFirstChild("Quests")
                    if q then
                        local qf = q:FindFirstChild("QuestsFrame")
                        if qf then
                            local allQ = qf:FindFirstChild("AllQuests")
                            if allQ then
                                local list = allQ:FindFirstChild("List")
                                if list then
                                    for _, item in ipairs(list:GetChildren()) do
                                        if item.Name ~= "Template" and item:IsA("GuiObject") then
                                            local prog = item:FindFirstChild("Progress")
                                            if prog then
                                                local btn = prog:FindFirstChild("ClaimButton")
                                                if btn and btn.Visible then
                                                    invokeRemote("CollectQuest", item.Name, "Daily")
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
    if Config.AutoClaimPass then
        for tier = 1, 50 do
            invokeRemote("ClaimTier", tier, false)
        end
    end
end

local function applyLightingTweaks()
    if Config.FPSBoost then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostProcessEffect") then
                v.Enabled = false
            end
        end
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PufyftykMasterpieceStrategist"
ScreenGui.ResetOnSpawn = false

local function resolveGuiParent()
    local ok, p = pcall(function() return CoreGui end)
    if ok and p then return p end
    return LocalPlayer:WaitForChild("PlayerGui")
end

ScreenGui.Parent = resolveGuiParent()

local Shell = Instance.new("Frame")
Shell.Name = "Shell"
Shell.Size = UDim2.new(0, 420, 0, 520)
Shell.Position = UDim2.new(0.02, 0, 0.08, 0)
Shell.BackgroundColor3 = Color3.fromRGB(10, 12, 17)
Shell.BorderSizePixel = 0
Shell.Active = true
Shell.Draggable = true
Shell.ClipsDescendants = true
Shell.Parent = ScreenGui

local ShellCorner = Instance.new("UICorner")
ShellCorner.CornerRadius = UDim.new(0, 14)
ShellCorner.Parent = Shell

local ShellStroke = Instance.new("UIStroke")
ShellStroke.Thickness = 2.0
ShellStroke.Color = Color3.fromRGB(0, 220, 255)
ShellStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
ShellStroke.Parent = Shell

local HeaderBar = Instance.new("Frame")
HeaderBar.Name = "HeaderBar"
HeaderBar.Size = UDim2.new(1, 0, 0, 50)
HeaderBar.BackgroundColor3 = Color3.fromRGB(15, 18, 27)
HeaderBar.BorderSizePixel = 0
HeaderBar.Parent = Shell

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 14)
HeaderCorner.Parent = HeaderBar

local Beacon = Instance.new("Frame")
Beacon.Name = "Beacon"
Beacon.Size = UDim2.new(0, 10, 0, 10)
Beacon.Position = UDim2.new(0, 14, 0.5, -5)
Beacon.BackgroundColor3 = Color3.fromRGB(0, 255, 170)
Beacon.BorderSizePixel = 0
Beacon.Parent = HeaderBar

local BeaconCorner = Instance.new("UICorner")
BeaconCorner.CornerRadius = UDim.new(1, 0)
BeaconCorner.Parent = Beacon

local HeaderMain = Instance.new("TextLabel")
HeaderMain.Name = "HeaderMain"
HeaderMain.Size = UDim2.new(1, -75, 0, 22)
HeaderMain.Position = UDim2.new(0, 32, 0, 6)
HeaderMain.BackgroundTransparency = 1
HeaderMain.Font = Enum.Font.GothamBold
HeaderMain.TextSize = 13
HeaderMain.TextColor3 = Color3.fromRGB(255, 255, 255)
HeaderMain.TextXAlignment = Enum.TextXAlignment.Left
HeaderMain.Text = "CAMERAMAN TD | MASTERPIECE AI"
HeaderMain.Parent = HeaderBar

local HeaderAuthor = Instance.new("TextLabel")
HeaderAuthor.Name = "HeaderAuthor"
HeaderAuthor.Size = UDim2.new(1, -75, 0, 16)
HeaderAuthor.Position = UDim2.new(0, 32, 0, 27)
HeaderAuthor.BackgroundTransparency = 1
HeaderAuthor.Font = Enum.Font.GothamMedium
HeaderAuthor.TextSize = 10
HeaderAuthor.TextColor3 = Color3.fromRGB(0, 210, 255)
HeaderAuthor.TextXAlignment = Enum.TextXAlignment.Left
HeaderAuthor.Text = "Quantum Autonomous Engine by pufyftyk v10.0"
HeaderAuthor.Parent = HeaderBar

local DismissBtn = Instance.new("TextButton")
DismissBtn.Name = "DismissBtn"
DismissBtn.Size = UDim2.new(0, 30, 0, 30)
DismissBtn.Position = UDim2.new(1, -40, 0, 10)
DismissBtn.BackgroundColor3 = Color3.fromRGB(235, 45, 70)
DismissBtn.Font = Enum.Font.GothamBold
DismissBtn.TextSize = 12
DismissBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DismissBtn.Text = "X"
DismissBtn.Parent = HeaderBar

local DismissCorner = Instance.new("UICorner")
DismissCorner.CornerRadius = UDim.new(0, 8)
DismissCorner.Parent = DismissBtn

local HUDBox = Instance.new("Frame")
HUDBox.Name = "HUDBox"
HUDBox.Size = UDim2.new(1, -24, 0, 108)
HUDBox.Position = UDim2.new(0, 12, 0, 58)
HUDBox.BackgroundColor3 = Color3.fromRGB(17, 21, 31)
HUDBox.BorderSizePixel = 0
HUDBox.Parent = Shell

local HUDCorner = Instance.new("UICorner")
HUDCorner.CornerRadius = UDim.new(0, 10)
HUDCorner.Parent = HUDBox

local HUDStroke = Instance.new("UIStroke")
HUDStroke.Thickness = 1
HUDStroke.Color = Color3.fromRGB(35, 45, 65)
HUDStroke.Parent = HUDBox

local LivePhaseLabel = Instance.new("TextLabel")
LivePhaseLabel.Name = "LivePhaseLabel"
LivePhaseLabel.Size = UDim2.new(1, -20, 0, 20)
LivePhaseLabel.Position = UDim2.new(0, 10, 0, 6)
LivePhaseLabel.BackgroundTransparency = 1
LivePhaseLabel.Font = Enum.Font.GothamBold
LivePhaseLabel.TextSize = 12
LivePhaseLabel.TextColor3 = Color3.fromRGB(0, 240, 255)
LivePhaseLabel.TextXAlignment = Enum.TextXAlignment.Left
LivePhaseLabel.Text = "PHASE: BOOT | Sub: IDLE"
LivePhaseLabel.Parent = HUDBox

local LiveMetricsRow1 = Instance.new("TextLabel")
LiveMetricsRow1.Name = "LiveMetricsRow1"
LiveMetricsRow1.Size = UDim2.new(1, -20, 0, 18)
LiveMetricsRow1.Position = UDim2.new(0, 10, 0, 28)
LiveMetricsRow1.BackgroundTransparency = 1
LiveMetricsRow1.Font = Enum.Font.GothamMedium
LiveMetricsRow1.TextSize = 11
LiveMetricsRow1.TextColor3 = Color3.fromRGB(255, 215, 0)
LiveMetricsRow1.TextXAlignment = Enum.TextXAlignment.Left
LiveMetricsRow1.Text = "Wave: 0 | Cash: $0 | Income: +$0/wave"
LiveMetricsRow1.Parent = HUDBox

local LiveMetricsRow2 = Instance.new("TextLabel")
LiveMetricsRow2.Name = "LiveMetricsRow2"
LiveMetricsRow2.Size = UDim2.new(1, -20, 0, 18)
LiveMetricsRow2.Position = UDim2.new(0, 10, 0, 48)
LiveMetricsRow2.BackgroundTransparency = 1
LiveMetricsRow2.Font = Enum.Font.Gotham
LiveMetricsRow2.TextSize = 10
LiveMetricsRow2.TextColor3 = Color3.fromRGB(160, 255, 175)
LiveMetricsRow2.TextXAlignment = Enum.TextXAlignment.Left
LiveMetricsRow2.Text = "Army: 0/15 | DPS: 0 (Req: 0) | Deficit: 0"
LiveMetricsRow2.Parent = HUDBox

local LimitGaugeBg = Instance.new("Frame")
LimitGaugeBg.Name = "LimitGaugeBg"
LimitGaugeBg.Size = UDim2.new(1, -20, 0, 8)
LimitGaugeBg.Position = UDim2.new(0, 10, 0, 72)
LimitGaugeBg.BackgroundColor3 = Color3.fromRGB(28, 33, 48)
LimitGaugeBg.BorderSizePixel = 0
LimitGaugeBg.Parent = HUDBox

local LimitGaugeCorner = Instance.new("UICorner")
LimitGaugeCorner.CornerRadius = UDim.new(1, 0)
LimitGaugeCorner.Parent = LimitGaugeBg

local LimitGaugeFill = Instance.new("Frame")
LimitGaugeFill.Name = "LimitGaugeFill"
LimitGaugeFill.Size = UDim2.new(0.05, 0, 1, 0)
LimitGaugeFill.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
LimitGaugeFill.BorderSizePixel = 0
LimitGaugeFill.Parent = LimitGaugeBg

local LimitFillCorner = Instance.new("UICorner")
LimitFillCorner.CornerRadius = UDim.new(1, 0)
LimitFillCorner.Parent = LimitGaugeFill

local LiveDecisionLabel = Instance.new("TextLabel")
LiveDecisionLabel.Name = "LiveDecisionLabel"
LiveDecisionLabel.Size = UDim2.new(1, -20, 0, 18)
LiveDecisionLabel.Position = UDim2.new(0, 10, 0, 84)
LiveDecisionLabel.BackgroundTransparency = 1
LiveDecisionLabel.Font = Enum.Font.GothamSemibold
LiveDecisionLabel.TextSize = 10
LiveDecisionLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
LiveDecisionLabel.TextXAlignment = Enum.TextXAlignment.Left
LiveDecisionLabel.Text = "ACTION: Initializing..."
LiveDecisionLabel.Parent = HUDBox

local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -24, 0, 36)
TabBar.Position = UDim2.new(0, 12, 0, 174)
TabBar.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
TabBar.BorderSizePixel = 0
TabBar.Parent = Shell

local TabBarCorner = Instance.new("UICorner")
TabBarCorner.CornerRadius = UDim.new(0, 8)
TabBarCorner.Parent = TabBar

local TabBarLayout = Instance.new("UIListLayout")
TabBarLayout.FillDirection = Enum.FillDirection.Horizontal
TabBarLayout.Padding = UDim.new(0, 4)
TabBarLayout.Parent = TabBar

local Deck = Instance.new("Frame")
Deck.Name = "Deck"
Deck.Size = UDim2.new(1, -24, 0, 296)
Deck.Position = UDim2.new(0, 12, 0, 216)
Deck.BackgroundTransparency = 1
Deck.Parent = Shell

local DeckPages = {}
local DeckButtons = {}

local function buildPage(id)
    local page = Instance.new("ScrollingFrame")
    page.Name = id
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new(0, 0, 0, 330)
    page.Visible = (id == State.SelectedTab)
    page.Parent = Deck

    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = page

    DeckPages[id] = page
    return page
end

local PageDashboard = buildPage("Dashboard")
local PageRoster = buildPage("Roster")
local PageConsole = buildPage("Console")
local PageServices = buildPage("Services")

local function switchDeckPage(id)
    State.SelectedTab = id
    for name, page in pairs(DeckPages) do
        if name == id then
            page.Visible = true
            page.Position = UDim2.new(0, 10, 0, 0)
            TweenService:Create(page, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0, 0)
            }):Play()
        else
            page.Visible = false
        end
    end
    for name, btn in pairs(DeckButtons) do
        local on = (name == id)
        TweenService:Create(btn, TweenInfo.new(0.18), {
            BackgroundColor3 = on and Color3.fromRGB(0, 140, 240) or Color3.fromRGB(20, 24, 34),
            TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 180, 210)
        }):Play()
    end
end

local function makeDeckButton(id, title)
    local btn = Instance.new("TextButton")
    btn.Name = id
    btn.Size = UDim2.new(0.24, 0, 1, 0)
    btn.BackgroundColor3 = (id == State.SelectedTab) and Color3.fromRGB(0, 140, 240) or Color3.fromRGB(20, 24, 34)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = (id == State.SelectedTab) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 180, 210)
    btn.Text = title
    btn.Parent = TabBar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    btn.MouseButton1Click:Connect(function()
        switchDeckPage(id)
    end)
    DeckButtons[id] = btn
end

makeDeckButton("Dashboard", "Strategist")
makeDeckButton("Roster", "Roster DPS")
makeDeckButton("Console", "Live Logs")
makeDeckButton("Services", "Automation")

local function addSwitch(parent, label, initial, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = initial and Color3.fromRGB(18, 90, 180) or Color3.fromRGB(20, 24, 35)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = initial and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 170, 190)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = "  " .. label .. ": " .. (initial and "ON" or "OFF")
    btn.Parent = parent

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn

    local active = initial
    btn.MouseButton1Click:Connect(function()
        active = not active
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = active and Color3.fromRGB(18, 90, 180) or Color3.fromRGB(20, 24, 35),
            TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 170, 190)
        }):Play()
        btn.Text = "  " .. label .. ": " .. (active and "ON" or "OFF")
        callback(active)
    end)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and Color3.fromRGB(25, 110, 215) or Color3.fromRGB(28, 33, 48)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and Color3.fromRGB(18, 90, 180) or Color3.fromRGB(20, 24, 35)
        }):Play()
    end)
    return btn
end

addSwitch(PageDashboard, "Titan Rush Priority (Save for TV Titan)", true, function(v) end)
addSwitch(PageDashboard, "Dynamic NPV Farm Engine", true, function(v) end)
addSwitch(PageDashboard, "Wave 27 Liquidation (Mass Sell Farms)", true, function(v) end)
addSwitch(PageDashboard, "Smart Cooldown Upgrader (Anti-Spam)", true, function(v) end)

local RosterListHolder = Instance.new("Frame")
RosterListHolder.Name = "RosterListHolder"
RosterListHolder.Size = UDim2.new(1, 0, 1, 0)
RosterListHolder.BackgroundTransparency = 1
RosterListHolder.Parent = PageRoster

local RosterLayout = Instance.new("UIListLayout")
RosterLayout.Padding = UDim.new(0, 6)
RosterLayout.Parent = RosterListHolder

local function renderRosterCards()
    for _, ch in ipairs(RosterListHolder:GetChildren()) do
        if ch:IsA("Frame") then
            ch:Destroy()
        end
    end
    for _, u in ipairs(State.EquippedUnits) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 52)
        card.BackgroundColor3 = Color3.fromRGB(18, 22, 33)
        card.BorderSizePixel = 0
        card.Parent = RosterListHolder

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Thickness = 1.2
        cStroke.Color = (u.Role == "TITAN") and Color3.fromRGB(0, 225, 255) or ((u.Role == "FARM") and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(45, 55, 75))
        cStroke.Parent = card

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(0.65, 0, 0, 20)
        title.Position = UDim2.new(0, 10, 0, 6)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.TextSize = 11
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = u.Name
        title.Parent = card

        local badge = Instance.new("TextLabel")
        badge.Size = UDim2.new(0.32, 0, 0, 20)
        badge.Position = UDim2.new(0.66, 0, 0, 6)
        badge.BackgroundTransparency = 1
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 10
        badge.TextColor3 = (u.Role == "TITAN") and Color3.fromRGB(0, 230, 255) or ((u.Role == "FARM") and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(170, 255, 175))
        badge.TextXAlignment = Enum.TextXAlignment.Right
        badge.Text = (u.Role == "TITAN") and "PRIMARY CARRY" or ((u.Role == "FARM") and "FARM GENERATOR" or "EARLY DEFENDER")
        badge.Parent = card

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -20, 0, 18)
        info.Position = UDim2.new(0, 10, 0, 28)
        info.BackgroundTransparency = 1
        info.Font = Enum.Font.Gotham
        info.TextSize = 10
        info.TextColor3 = Color3.fromRGB(160, 175, 195)
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Text = string.format("Slot: #%d | Cost: $%d | Strategy: %s", u.SlotNumber, u.Cost, (u.Role == "TITAN") and "Save Cash & Max Upgrade" or ((u.Role == "FARM") and "Deploy early 2x Farms" or "Early waves solo defense"))
        info.Parent = card
    end
end

local ConsoleScroll = Instance.new("ScrollingFrame")
ConsoleScroll.Name = "ConsoleScroll"
ConsoleScroll.Size = UDim2.new(1, 0, 1, 0)
ConsoleScroll.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
ConsoleScroll.BorderSizePixel = 0
ConsoleScroll.ScrollBarThickness = 4
ConsoleScroll.CanvasSize = UDim2.new(0, 0, 0, 500)
ConsoleScroll.Parent = PageConsole

local ConsoleCorner = Instance.new("UICorner")
ConsoleCorner.CornerRadius = UDim.new(0, 8)
ConsoleCorner.Parent = ConsoleScroll

local ConsoleText = Instance.new("TextLabel")
ConsoleText.Name = "ConsoleText"
ConsoleText.Size = UDim2.new(1, -12, 1, 0)
ConsoleText.Position = UDim2.new(0, 6, 0, 4)
ConsoleText.BackgroundTransparency = 1
ConsoleText.Font = Enum.Font.Code
ConsoleText.TextSize = 10
ConsoleText.TextColor3 = Color3.fromRGB(150, 255, 160)
ConsoleText.TextXAlignment = Enum.TextXAlignment.Left
ConsoleText.TextYAlignment = Enum.TextYAlignment.Top
ConsoleText.TextWrapped = true
ConsoleText.Text = "System initialized.\nWaiting for match stream..."
ConsoleText.Parent = ConsoleScroll

addSwitch(PageServices, "Auto Skip Wave (Speedrun)", Config.AutoSkip, function(v)
    Config.AutoSkip = v
end)
addSwitch(PageServices, "Auto Vote Nightmare Difficulty", Config.AutoVote, function(v)
    Config.AutoVote = v
end)
addSwitch(PageServices, "Auto Speed 2x / 1.5x", Config.AutoSpeed, function(v)
    Config.AutoSpeed = v
    if v then State.SpeedConfirmed = 1 end
end)
addSwitch(PageServices, "Auto Play Again (Replay Loop)", Config.AutoPlayAgain, function(v)
    Config.AutoPlayAgain = v
end)
addSwitch(PageServices, "Auto Claim Daily Quests", Config.AutoClaimQuests, function(v)
    Config.AutoClaimQuests = v
end)
addSwitch(PageServices, "Auto Claim Battlepass Tiers", Config.AutoClaimPass, function(v)
    Config.AutoClaimPass = v
end)
addSwitch(PageServices, "FPS Boost (Disable Shadows/Fog)", Config.FPSBoost, function(v)
    Config.FPSBoost = v
    applyLightingTweaks()
end)

DismissBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = not ScreenGui.Enabled
end)

local function hookEvents()
    local folder = getNetworkFolder("RemoteEvent")
    if not folder then return end
    local addEv = folder:FindFirstChild("TowerAdd")
    if addEv and addEv:IsA("RemoteEvent") then
        trackConn(addEv.OnClientEvent:Connect(function(payload)
            if type(payload) == "table" and payload.Name and payload.UnitId then
                State.DetectedUUIDs[payload.Name] = payload.UnitId
            end
        end))
    end
    local upEv = folder:FindFirstChild("TowerUpgrade")
    if upEv and upEv:IsA("RemoteEvent") then
        trackConn(upEv.OnClientEvent:Connect(function(payload)
            if type(payload) == "table" and payload.Id then
                State.TowerUpgradeTimers[payload.Id] = 0
            end
        end))
    end
end

hookEvents()
computeSpatialGeometry()
scanFullRoster()
renderRosterCards()
applyLightingTweaks()

local function pulseLoop()
    if not State.Running then return end
    handleMatchFlow()
    handleRewards()
    runStrategistDecisionLoop()

    LivePhaseLabel.Text = string.format("PHASE: %s | %s", State.Phase, State.SubPhase)
    LiveMetricsRow1.Text = string.format("Wave: %d (%s) | Cash: $%d | Farm: +$%d/w", State.CurrentWave, State.WaveString, State.Cash, State.CalculatedFarmIncome)
    LiveMetricsRow2.Text = string.format("Army: %d/%d | DPS: %d (Req: %d) | Deficit: %d", State.CurrentTowersCount, State.MaxTowersCount, State.CalculatedArmyDPS, State.RequiredDPS, math.max(0, State.RequiredDPS - State.CalculatedArmyDPS))
    LiveDecisionLabel.Text = string.format("AI FOCUS: %s", (State.IdentifiedTitan and State.IdentifiedTitan.Name or "Titan Rush"))

    local fillRatio = math.clamp(State.CurrentTowersCount / math.max(1, State.MaxTowersCount), 0.05, 1.0)
    local gaugeColor = (fillRatio >= 0.95) and Color3.fromRGB(255, 45, 65) or ((fillRatio >= 0.7) and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(0, 220, 255))
    TweenService:Create(LimitGaugeFill, TweenInfo.new(0.2), {
        Size = UDim2.new(fillRatio, 0, 1, 0),
        BackgroundColor3 = gaugeColor
    }):Play()

    ConsoleText.Text = table.concat(State.StatusLog, "\n")
    ConsoleScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(300, #State.StatusLog * 14))
end

local MainLoop = RunService.Heartbeat:Connect(pulseLoop)
trackConn(MainLoop)

trackConn(LocalPlayer.CharacterRemoving:Connect(function()
    State.LastSkipWave = -1
    State.LastVoteTime = 0
    State.SpeedConfirmed = 1
    State.FarmsSold = false
    State.PlacedTowers = {}
    State.TowerUpgradeTimers = {}
    computeSpatialGeometry()
    scanFullRoster()
    renderRosterCards()
end))

env.CameramanTDHubCleanup = function()
    State.Running = false
    for _, conn in ipairs(ActiveConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(ActiveConnections)
    if ScreenGui then
        ScreenGui:Destroy()
    end
    appendLog("Cleanup concluded.")
end

appendLog("Masterpiece AI Online! Good luck and enjoy winning!")
