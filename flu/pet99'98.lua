local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local Configuration = {
    AutonomousAI = true,
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
    FinalWave = 30,
    SellFarmsWave = 27,
    GreedThreshold = 0.35,
    EmergencyThreshold = 0.65,
    MinTowerSpacing = 4.8,
    MaxLateralOffset = 12.0,
    LateralLayers = 3,
    ActionCooldown = 0.25,
    MaxPlacedUnits = 15,
    TargetFps = 60
}

local Engine = {
    Author = "by pufyftyk",
    Running = true,
    Phase = "INITIALIZING",
    Regime = "BALANCED",
    ThreatIndex = 0.0,
    ThreatVelocity = 0.0,
    LastThreat = 0.0,
    LiquidCash = 0,
    CurrentWave = 0,
    WaveStatusText = "",
    ConfirmedSpeed = 1,
    FarmsSold = false,
    CombatUnitsCount = 0,
    FarmUnitsCount = 0,
    LastActionTimestamp = 0,
    LastVoteTimestamp = 0,
    LastSpeedTimestamp = 0,
    LastClaimTimestamp = 0,
    LastReplayTimestamp = 0,
    LastSkipWave = -1,
    SelectedTab = "Strategist",
    Waypoints = {},
    CurvatureNodes = {},
    GridAnchors = {},
    PlacedTowers = {},
    EquippedRoster = {},
    ActionQueue = {},
    RateTokens = 5,
    MaxTokens = 5,
    LastTokenRefill = os.clock(),
    TokenRefillRate = 4
}

local function allocateToken()
    local now = os.clock()
    local elapsed = now - Engine.LastTokenRefill
    Engine.LastTokenRefill = now
    Engine.RateTokens = math.min(Engine.MaxTokens, Engine.RateTokens + (elapsed * Engine.TokenRefillRate))
    if Engine.RateTokens >= 1 then
        Engine.RateTokens = Engine.RateTokens - 1
        return true
    end
    return false
end

local function getNetworkRoot()
    local ml = ReplicatedStorage:FindFirstChild("ModuleLoader")
    if not ml then return nil end
    local shared = ml:FindFirstChild("Shared")
    if not shared then return nil end
    return shared:FindFirstChild("Network")
end

local function resolveRemote(groupName, remoteName)
    local root = getNetworkRoot()
    if not root then return nil end
    local grp = root:FindFirstChild(groupName)
    if not grp then return nil end
    return grp:FindFirstChild(remoteName)
end

local function dispatchRemoteEvent(name, ...)
    if not allocateToken() then return false end
    local rem = resolveRemote("RemoteEvent", name)
    if rem and rem:IsA("RemoteEvent") then
        local payload = { ... }
        return pcall(function()
            rem:FireServer(table.unpack(payload))
        end)
    end
    return false
end

local function dispatchRemoteFunction(name, ...)
    if not allocateToken() then return false end
    local rem = resolveRemote("RemoteFunction", name)
    if rem and rem:IsA("RemoteFunction") then
        local payload = { ... }
        return pcall(function()
            return rem:InvokeServer(table.unpack(payload))
        end)
    end
    return false
end

local function fetchPlayerGui()
    return LocalPlayer:FindFirstChild("PlayerGui")
end

local function fetchGameUI()
    local pg = fetchPlayerGui()
    if pg then
        return pg:FindFirstChild("GameUI")
    end
    return nil
end

local function isMatchLive()
    local gui = fetchGameUI()
    if not gui then return false end
    local stats = gui:FindFirstChild("Stats")
    if not stats or not stats.Visible then return false end
    local finalUI = gui:FindFirstChild("FinalUI")
    if finalUI and finalUI.Visible then return false end
    return true
end

local function isFinalScreenOpen()
    local gui = fetchGameUI()
    if gui then
        local finalUI = gui:FindFirstChild("FinalUI")
        if finalUI and finalUI.Visible then
            return true
        end
    end
    return false
end

local function scanWaveState()
    local gui = fetchGameUI()
    if gui then
        local stats = gui:FindFirstChild("Stats")
        if stats then
            local waveLbl = stats:FindFirstChild("Wave")
            if waveLbl and waveLbl:IsA("TextLabel") then
                local rawText = waveLbl.Text
                local matchNum = string.match(rawText, "[Ww]ave%s*(%d+)")
                if matchNum then
                    Engine.CurrentWave = tonumber(matchNum) or 0
                else
                    Engine.CurrentWave = 0
                end
                Engine.WaveStatusText = rawText
                return Engine.CurrentWave, rawText
            end
        end
    end
    Engine.CurrentWave = 0
    Engine.WaveStatusText = "Unknown"
    return 0, "Unknown"
end

local function scanCashBalance()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local mVal = ls:FindFirstChild("Money")
        if mVal and mVal:IsA("ValueBase") then
            local n = tonumber(mVal.Value)
            if n then
                Engine.LiquidCash = n
                return n
            end
        end
    end
    local gui = fetchGameUI()
    if gui then
        local stats = gui:FindFirstChild("Stats")
        if stats then
            local other = stats:FindFirstChild("OtherUI")
            if other then
                local moneyBox = other:FindFirstChild("Money")
                if moneyBox then
                    local title = moneyBox:FindFirstChild("Title")
                    if title and title:IsA("TextLabel") then
                        local stripped = string.gsub(title.Text, ",", "")
                        local found = string.match(stripped, "%d+%.?%d*")
                        if found then
                            local n = tonumber(found)
                            if n then
                                Engine.LiquidCash = n
                                return n
                            end
                        end
                    end
                end
            end
        end
    end
    Engine.LiquidCash = 0
    return 0
end

local function inspectReplicaStorage()
    local modules = (type(getloadedmodules) == "function") and getloadedmodules() or {}
    for _, mod in ipairs(modules) do
        if mod:IsA("ModuleScript") then
            local low = string.lower(mod.Name)
            if string.find(low, "replica", 1, true) or string.find(low, "playerdata", 1, true) or string.find(low, "inventory", 1, true) then
                local ok, result = pcall(require, mod)
                if ok and type(result) == "table" then
                    for _, entry in pairs(result) do
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
        local gcObjects = getgc(true)
        for _, obj in pairs(gcObjects) do
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

local function deduceUnitArchetype(unitName, cost)
    local low = string.lower(unitName)
    if string.find(low, "scientist", 1, true) or string.find(low, "farm", 1, true) or string.find(low, "bank", 1, true) or string.find(low, "money", 1, true) then
        return "ECONOMY", 100
    end
    if string.find(low, "titan", 1, true) or string.find(low, "hyper", 1, true) or string.find(low, "upgraded", 1, true) or cost >= 900 then
        return "HEAVY_TITAN", 500
    end
    if cost <= 350 or string.find(low, "camera", 1, true) or string.find(low, "scout", 1, true) or string.find(low, "basic", 1, true) or string.find(low, "ninja", 1, true) then
        return "EARLY_STARTER", 50
    end
    return "MID_TACTICAL", 200
end

local function scanEquippedRoster()
    local replicaTowers = inspectReplicaStorage()
    Engine.EquippedRoster = {}
    if replicaTowers then
        for uuid, tower in pairs(replicaTowers) do
            if type(tower) == "table" and tower.Name then
                local eq = tonumber(tower.Equipped) or (tower.Equipped == true and 1 or 0)
                if eq > 0 then
                    local estimatedCost = 250
                    if string.find(string.lower(tower.Name), "titan", 1, true) then
                        estimatedCost = 1200
                    elseif string.find(string.lower(tower.Name), "scientist", 1, true) then
                        estimatedCost = 400
                    end
                    local archetype, dpsRating = deduceUnitArchetype(tower.Name, estimatedCost)
                    table.insert(Engine.EquippedRoster, {
                        UUID = tostring(uuid),
                        Name = tower.Name,
                        Slot = eq,
                        BaseCost = estimatedCost,
                        Archetype = archetype,
                        BaseDps = dpsRating
                    })
                end
            end
        end
    end
    if #Engine.EquippedRoster == 0 then
        local defaults = {
            { UUID = "auto_farm", Name = "Scientist Cameraman", Slot = 1, BaseCost = 400, Archetype = "ECONOMY", BaseDps = 0 },
            { UUID = "auto_starter", Name = "Cameraman", Slot = 2, BaseCost = 200, Archetype = "EARLY_STARTER", BaseDps = 60 },
            { UUID = "auto_titan", Name = "Titan Cameraman", Slot = 3, BaseCost = 1200, Archetype = "HEAVY_TITAN", BaseDps = 550 },
            { UUID = "auto_mid", Name = "TV Man", Slot = 4, BaseCost = 600, Archetype = "MID_TACTICAL", BaseDps = 220 }
        }
        for _, item in ipairs(defaults) do
            table.insert(Engine.EquippedRoster, item)
        end
    end
    table.sort(Engine.EquippedRoster, function(a, b)
        return a.BaseCost < b.BaseCost
    end)
end

local function projectGroundLevel(originPos)
    local rayStart = Vector3.new(originPos.X, originPos.Y + 20, originPos.Z)
    local rayDirection = Vector3.new(0, -60, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if LocalPlayer.Character then
        params.FilterDescendantsInstances = { LocalPlayer.Character }
    end
    local hit = Workspace:Raycast(rayStart, rayDirection, params)
    if hit and hit.Position then
        return hit.Position
    end
    return originPos
end

local function reconstructTrackGeometry()
    local gameFolder = Workspace:FindFirstChild("Game")
    if not gameFolder then return false end
    local wpFolder = gameFolder:FindFirstChild("Waypoints")
    if not wpFolder then return false end
    local indexedWps = {}
    for _, child in ipairs(wpFolder:GetChildren()) do
        if child:IsA("BasePart") then
            local idx = tonumber(string.match(child.Name, "%d+")) or 0
            table.insert(indexedWps, { Part = child, Index = idx, Position = child.Position })
        end
    end
    if #indexedWps < 2 then return false end
    table.sort(indexedWps, function(a, b)
        return a.Index < b.Index
    end)
    Engine.Waypoints = {}
    for _, item in ipairs(indexedWps) do
        table.insert(Engine.Waypoints, item.Position)
    end
    local curvatureNodes = {}
    local totalWps = #Engine.Waypoints
    for i = 2, totalWps - 1 do
        local pPrev = Engine.Waypoints[i - 1]
        local pCurr = Engine.Waypoints[i]
        local pNext = Engine.Waypoints[i + 1]
        local vPrev = (pCurr - pPrev).Unit
        local vNext = (pNext - pCurr).Unit
        local dotProduct = math.clamp(vPrev:Dot(vNext), -1, 1)
        local curvatureMetric = 1 - dotProduct
        local tangent = (vPrev + vNext).Unit
        local normal = Vector3.new(-tangent.Z, 0, tangent.X).Unit
        table.insert(curvatureNodes, {
            Index = i,
            Position = pCurr,
            Normal = normal,
            Tangent = tangent,
            Curvature = curvatureMetric
        })
    end
    table.sort(curvatureNodes, function(a, b)
        return a.Curvature > b.Curvature
    end)
    Engine.CurvatureNodes = curvatureNodes
    local anchors = {}
    for _, node in ipairs(curvatureNodes) do
        for layer = 1, Configuration.LateralLayers do
            local lateralDist = (Configuration.MaxLateralOffset / Configuration.LateralLayers) * layer
            local leftCandidate = projectGroundLevel(node.Position + (node.Normal * lateralDist))
            local rightCandidate = projectGroundLevel(node.Position - (node.Normal * lateralDist))
            table.insert(anchors, {
                Position = leftCandidate,
                Curvature = node.Curvature,
                TrackIndex = node.Index,
                OffsetLayer = layer,
                Side = "LEFT"
            })
            table.insert(anchors, {
                Position = rightCandidate,
                Curvature = node.Curvature,
                TrackIndex = node.Index,
                OffsetLayer = layer,
                Side = "RIGHT"
            })
        end
    end
    table.sort(anchors, function(a, b)
        if math.abs(a.Curvature - b.Curvature) > 0.08 then
            return a.Curvature > b.Curvature
        end
        return a.OffsetLayer < b.OffsetLayer
    end)
    Engine.GridAnchors = anchors
    return true
end

local function scanPlacedTowers()
    local gameFolder = Workspace:FindFirstChild("Game")
    Engine.PlacedTowers = {}
    Engine.CombatUnitsCount = 0
    Engine.FarmUnitsCount = 0
    if not gameFolder then return end
    local towersFolder = gameFolder:FindFirstChild("Towers")
    if not towersFolder then return end
    for _, model in ipairs(towersFolder:GetChildren()) do
        local belongsToMe = false
        local ownerAttr = model:GetAttribute("OwnerUserId") or model:GetAttribute("Owner")
        if ownerAttr then
            if tonumber(ownerAttr) == LocalPlayer.UserId or tostring(ownerAttr) == LocalPlayer.Name then
                belongsToMe = true
            end
        else
            belongsToMe = true
        end
        if belongsToMe then
            local pos = Vector3.zero
            if model:IsA("Model") then
                pos = model:GetPivot().Position
            elseif model:IsA("BasePart") then
                pos = model.Position
            end
            local tName = model.Name
            local low = string.lower(tName)
            local isEconomy = string.find(low, "scientist", 1, true) or string.find(low, "farm", 1, true) or string.find(low, "bank", 1, true)
            if isEconomy then
                Engine.FarmUnitsCount = Engine.FarmUnitsCount + 1
            else
                Engine.CombatUnitsCount = Engine.CombatUnitsCount + 1
            end
            table.insert(Engine.PlacedTowers, {
                Instance = model,
                Id = model.Name,
                Position = pos,
                IsFarm = isEconomy
            })
        end
    end
end

local function isSpatialAnchorVacant(targetPos)
    for _, tower in ipairs(Engine.PlacedTowers) do
        local horizDist = (Vector2.new(targetPos.X, targetPos.Z) - Vector2.new(tower.Position.X, tower.Position.Z)).Magnitude
        if horizDist < Configuration.MinTowerSpacing then
            return false
        end
    end
    return true
end

local function evaluateDynamicThreat()
    local gameFolder = Workspace:FindFirstChild("Game")
    if not gameFolder then return 0.0 end
    local enemyFolder = gameFolder:FindFirstChild("Enemies") or gameFolder:FindFirstChild("Zombies") or gameFolder:FindFirstChild("Toilets")
    if not enemyFolder or #enemyFolder:GetChildren() == 0 then
        Engine.ThreatVelocity = -Engine.ThreatIndex
        Engine.ThreatIndex = 0.0
        return 0.0
    end
    local maxDistanceAlongTrack = 0.0
    local totalWaypoints = #Engine.Waypoints
    if totalWaypoints == 0 then return 0.0 end
    for _, enemy in ipairs(enemyFolder:GetChildren()) do
        local ePos = Vector3.zero
        if enemy:IsA("Model") then
            ePos = enemy:GetPivot().Position
        elseif enemy:IsA("BasePart") then
            ePos = enemy.Position
        end
        local closestIdx = 1
        local minSqDist = 1e6
        for idx, wpPos in ipairs(Engine.Waypoints) do
            local sqDist = (ePos.X - wpPos.X)^2 + (ePos.Z - wpPos.Z)^2
            if sqDist < minSqDist then
                minSqDist = sqDist
                closestIdx = idx
            end
        end
        local trackProgress = closestIdx / totalWaypoints
        if trackProgress > maxDistanceAlongTrack then
            maxDistanceAlongTrack = trackProgress
        end
    end
    Engine.ThreatVelocity = maxDistanceAlongTrack - Engine.LastThreat
    Engine.LastThreat = maxDistanceAlongTrack
    Engine.ThreatIndex = maxDistanceAlongTrack
    return maxDistanceAlongTrack
end

local function querySpatialPlacementSlot(archetype)
    if #Engine.GridAnchors == 0 then
        reconstructTrackGeometry()
    end
    if archetype == "ECONOMY" then
        for i = #Engine.GridAnchors, 1, -1 do
            local anchor = Engine.GridAnchors[i]
            if isSpatialAnchorVacant(anchor.Position) then
                return anchor.Position
            end
        end
    else
        for _, anchor in ipairs(Engine.GridAnchors) do
            if isSpatialAnchorVacant(anchor.Position) then
                return anchor.Position
            end
        end
    end
    if #Engine.Waypoints >= 2 then
        local fallbackPos = Engine.Waypoints[2] + Vector3.new(Configuration.MaxLateralOffset, 0, 0)
        local ground = projectGroundLevel(fallbackPos)
        if isSpatialAnchorVacant(ground) then
            return ground
        end
    end
    return nil
end

local function fetchCandidateRosterUnit(targetArchetype)
    local filtered = {}
    for _, unit in ipairs(Engine.EquippedRoster) do
        if unit.Archetype == targetArchetype then
            table.insert(filtered, unit)
        end
    end
    if #filtered > 0 then
        table.sort(filtered, function(a, b)
            return a.BaseCost > b.BaseCost
        end)
        return filtered[1]
    end
    for _, unit in ipairs(Engine.EquippedRoster) do
        if unit.Archetype ~= "ECONOMY" then
            return unit
        end
    end
    return Engine.EquippedRoster[1]
end

local function executeEconomicModel(wave, cash)
    if wave >= Configuration.SellFarmsWave and not Engine.FarmsSold then
        Engine.FarmsSold = true
        for _, tower in ipairs(Engine.PlacedTowers) do
            if tower.IsFarm then
                dispatchRemoteEvent("TowerSell", { Id = tower.Id })
            end
        end
        return true
    end
    local remainingHorizon = Configuration.FinalWave - wave
    local paybackHorizon = 3
    local netEconomicValue = remainingHorizon - paybackHorizon
    if netEconomicValue <= 0 or wave >= Configuration.SellFarmsWave then
        return false
    end
    if Engine.FarmUnitsCount < 4 and cash >= 400 then
        local farmUnit = fetchCandidateRosterUnit("ECONOMY")
        if farmUnit and cash >= farmUnit.BaseCost then
            local coord = querySpatialPlacementSlot("ECONOMY")
            if coord then
                local cf = CFrame.new(coord)
                dispatchRemoteEvent("TowerAdd", {
                    Name = farmUnit.Name,
                    UnitId = farmUnit.UUID,
                    Pos = coord,
                    CFrame = cf
                })
                return true
            end
        end
    end
    return false
end

local function executeTacticalDefense(wave, cash)
    if Engine.CombatUnitsCount == 0 and cash >= 200 then
        local starter = fetchCandidateRosterUnit("EARLY_STARTER")
        if starter and cash >= starter.BaseCost then
            local coord = querySpatialPlacementSlot("EARLY_STARTER")
            if coord then
                local cf = CFrame.new(coord)
                dispatchRemoteEvent("TowerAdd", {
                    Name = starter.Name,
                    UnitId = starter.UUID,
                    Pos = coord,
                    CFrame = cf
                })
                return true
            end
        end
    end
    local shouldPlaceHeavy = wave >= 12 or Engine.Regime == "EMERGENCY" or Engine.FarmUnitsCount >= 3
    if shouldPlaceHeavy and Engine.CombatUnitsCount < Configuration.MaxPlacedUnits then
        local titan = fetchCandidateRosterUnit("HEAVY_TITAN")
        if titan and cash >= titan.BaseCost then
            local coord = querySpatialPlacementSlot("HEAVY_TITAN")
            if coord then
                local cf = CFrame.new(coord)
                dispatchRemoteEvent("TowerAdd", {
                    Name = titan.Name,
                    UnitId = titan.UUID,
                    Pos = coord,
                    CFrame = cf
                })
                return true
            end
        end
    end
    if cash >= 150 and #Engine.PlacedTowers > 0 then
        table.sort(Engine.PlacedTowers, function(a, b)
            if a.IsFarm ~= b.IsFarm then
                if Engine.Regime == "GREED" then
                    return a.IsFarm
                else
                    return not a.IsFarm
                end
            end
            return a.Id < b.Id
        end)
        for _, tower in ipairs(Engine.PlacedTowers) do
            dispatchRemoteEvent("TowerUpgrade", { Id = tower.Id })
            break
        end
        return true
    end
    return false
end

local function executeAutonomousStrategist()
    if not isMatchLive() then
        Engine.Phase = "LOBBY_IDLE"
        Engine.ThreatIndex = 0.0
        return
    end
    local wave = scanWaveState()
    local cash = scanCashBalance()
    scanPlacedTowers()
    local threat = evaluateDynamicThreat()
    if threat > Configuration.EmergencyThreshold then
        Engine.Regime = "EMERGENCY"
    elseif threat < Configuration.GreedThreshold then
        Engine.Regime = "GREED"
    else
        Engine.Regime = "BALANCED"
    end
    if wave <= 4 then
        Engine.Phase = "EARLY_STABILIZATION"
    elseif wave < Configuration.SellFarmsWave then
        Engine.Phase = "COMPOUND_ACCUMULATION"
    else
        Engine.Phase = "BOSS_TERMINAL_PURGE"
    end
    local now = os.clock()
    if now - Engine.LastActionTimestamp < Configuration.ActionCooldown then
        return
    end
    Engine.LastActionTimestamp = now
    if Engine.Regime == "EMERGENCY" then
        if executeTacticalDefense(wave, cash) then return end
    elseif Engine.Regime == "GREED" then
        if executeEconomicModel(wave, cash) then return end
        if executeTacticalDefense(wave, cash) then return end
    else
        if Engine.CombatUnitsCount < 2 then
            if executeTacticalDefense(wave, cash) then return end
        else
            if executeEconomicModel(wave, cash) then return end
            if executeTacticalDefense(wave, cash) then return end
        end
    end
end

local function processMatchAutomation()
    local wave, waveText = scanWaveState()
    if Configuration.AutoVote then
        local now = os.clock()
        if now - Engine.LastVoteTimestamp > 3 then
            local low = string.lower(waveText)
            if string.find(low, "voting", 1, true) or string.find(low, "intermission", 1, true) then
                Engine.LastVoteTimestamp = now
                dispatchRemoteEvent("ModeVote", Configuration.VoteDifficulty)
            end
        end
    end
    if Configuration.AutoSpeed and isMatchLive() then
        local now = os.clock()
        if now - Engine.LastSpeedTimestamp > 4 and Engine.ConfirmedSpeed ~= Configuration.TargetSpeed then
            Engine.LastSpeedTimestamp = now
            local ok, res = dispatchRemoteFunction("ChangeSpeed", Configuration.TargetSpeed)
            if ok and res == true then
                Engine.ConfirmedSpeed = Configuration.TargetSpeed
            elseif ok and res == false and Configuration.TargetSpeed == 2 then
                Configuration.TargetSpeed = 1.5
                dispatchRemoteFunction("ChangeSpeed", 1.5)
            end
        end
    end
    if Configuration.AutoSkip and isMatchLive() then
        local gui = fetchGameUI()
        if gui then
            local stats = gui:FindFirstChild("Stats")
            if stats then
                local skipGui = stats:FindFirstChild("WaveSkipGui")
                if skipGui and skipGui.Visible and Engine.LastSkipWave ~= wave then
                    Engine.LastSkipWave = wave
                    dispatchRemoteEvent("WaveSkip")
                end
            end
        end
    end
    if Configuration.AutoPlayAgain and isFinalScreenOpen() then
        local now = os.clock()
        if now - Engine.LastReplayTimestamp > 5 then
            Engine.LastReplayTimestamp = now
            dispatchRemoteEvent("PlayAgain")
        end
    end
end

local function processRewardAutomation()
    if not Configuration.AutoClaimQuests and not Configuration.AutoClaimPass then return end
    local now = os.clock()
    if now - Engine.LastClaimTimestamp < 6 then return end
    Engine.LastClaimTimestamp = now
    if Configuration.AutoClaimQuests then
        local pg = fetchPlayerGui()
        if pg then
            local mainGui = pg:FindFirstChild("Main")
            if mainGui then
                local mainFrame = mainGui:FindFirstChild("Main")
                if mainFrame then
                    local quests = mainFrame:FindFirstChild("Quests")
                    if quests then
                        local qf = quests:FindFirstChild("QuestsFrame")
                        if qf then
                            local allQ = qf:FindFirstChild("AllQuests")
                            if allQ then
                                local list = allQ:FindFirstChild("List")
                                if list then
                                    for _, item in ipairs(list:GetChildren()) do
                                        if item.Name ~= "Template" and item:IsA("GuiObject") then
                                            local prog = item:FindFirstChild("Progress")
                                            if prog then
                                                local claimBtn = prog:FindFirstChild("ClaimButton")
                                                if claimBtn and claimBtn.Visible then
                                                    dispatchRemoteFunction("CollectQuest", item.Name, "Daily")
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
    if Configuration.AutoClaimPass then
        for tier = 1, 50 do
            dispatchRemoteFunction("ClaimTier", tier, false)
        end
    end
end

local function applyPerformanceTweaks()
    if Configuration.FPSBoost then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostProcessEffect") then
                v.Enabled = false
            end
        end
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
        end
    end
end

local function bindAntiAFK()
    if Configuration.AntiAFK then
        LocalPlayer.Idled:Connect(function()
            local vu = game:GetService("VirtualUser")
            if vu then
                vu:CaptureController()
                vu:ClickButton2(Vector2.new(0, 0))
            end
        end)
    end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PufyftykIndustrialStrategist"
ScreenGui.ResetOnSpawn = false

local function resolveGuiHost()
    local ok, res = pcall(function() return CoreGui end)
    if ok and res then return res end
    return LocalPlayer:WaitForChild("PlayerGui")
end

ScreenGui.Parent = resolveGuiHost()

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Size = UDim2.new(0, 360, 0, 460)
Window.Position = UDim2.new(0.03, 0, 0.12, 0)
Window.BackgroundColor3 = Color3.fromRGB(11, 12, 17)
Window.BorderSizePixel = 0
Window.Active = true
Window.Draggable = true
Window.Parent = ScreenGui

local WinCorner = Instance.new("UICorner")
WinCorner.CornerRadius = UDim.new(0, 10)
WinCorner.Parent = Window

local WinStroke = Instance.new("UIStroke")
WinStroke.Thickness = 1.8
WinStroke.Color = Color3.fromRGB(0, 180, 255)
WinStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
WinStroke.Parent = Window

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(16, 18, 25)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Name = "TitleText"
TitleText.Size = UDim2.new(1, -50, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 13
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Text = "CAMERAMAN TD INDUSTRIAL | by pufyftyk"
TitleText.Parent = TitleBar

local ExitBtn = Instance.new("TextButton")
ExitBtn.Name = "ExitBtn"
ExitBtn.Size = UDim2.new(0, 28, 0, 28)
ExitBtn.Position = UDim2.new(1, -34, 0, 7)
ExitBtn.BackgroundColor3 = Color3.fromRGB(225, 45, 65)
ExitBtn.Font = Enum.Font.GothamBold
ExitBtn.TextSize = 12
ExitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ExitBtn.Text = "X"
ExitBtn.Parent = TitleBar

local ExitCorner = Instance.new("UICorner")
ExitCorner.CornerRadius = UDim.new(0, 6)
ExitCorner.Parent = ExitBtn

local TelemetryFrame = Instance.new("Frame")
TelemetryFrame.Name = "TelemetryFrame"
TelemetryFrame.Size = UDim2.new(1, -20, 0, 85)
TelemetryFrame.Position = UDim2.new(0, 10, 0, 48)
TelemetryFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
TelemetryFrame.BorderSizePixel = 0
TelemetryFrame.Parent = Window

local TelemetryCorner = Instance.new("UICorner")
TelemetryCorner.CornerRadius = UDim.new(0, 8)
TelemetryCorner.Parent = TelemetryFrame

local PhaseLbl = Instance.new("TextLabel")
PhaseLbl.Name = "PhaseLbl"
PhaseLbl.Size = UDim2.new(1, -14, 0, 20)
PhaseLbl.Position = UDim2.new(0, 10, 0, 6)
PhaseLbl.BackgroundTransparency = 1
PhaseLbl.Font = Enum.Font.GothamBold
PhaseLbl.TextSize = 11
PhaseLbl.TextColor3 = Color3.fromRGB(0, 230, 255)
PhaseLbl.TextXAlignment = Enum.TextXAlignment.Left
PhaseLbl.Text = "Phase: INITIALIZING | Regime: BALANCED"
PhaseLbl.Parent = TelemetryFrame

local FinancialLbl = Instance.new("TextLabel")
FinancialLbl.Name = "FinancialLbl"
FinancialLbl.Size = UDim2.new(1, -14, 0, 20)
FinancialLbl.Position = UDim2.new(0, 10, 0, 30)
FinancialLbl.BackgroundTransparency = 1
FinancialLbl.Font = Enum.Font.GothamMedium
FinancialLbl.TextSize = 11
FinancialLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
FinancialLbl.TextXAlignment = Enum.TextXAlignment.Left
FinancialLbl.Text = "Wave: 0 | Cash: $0 | Threat: 0%"
FinancialLbl.Parent = TelemetryFrame

local TroopsLbl = Instance.new("TextLabel")
TroopsLbl.Name = "TroopsLbl"
TroopsLbl.Size = UDim2.new(1, -14, 0, 20)
TroopsLbl.Position = UDim2.new(0, 10, 0, 56)
TroopsLbl.BackgroundTransparency = 1
TroopsLbl.Font = Enum.Font.Gotham
TroopsLbl.TextSize = 10
TroopsLbl.TextColor3 = Color3.fromRGB(160, 255, 160)
TroopsLbl.TextXAlignment = Enum.TextXAlignment.Left
TroopsLbl.Text = "Forces: 0 Combat | 0 Farms | 0 Waypoints"
TroopsLbl.Parent = TelemetryFrame

local TabSelector = Instance.new("Frame")
TabSelector.Name = "TabSelector"
TabSelector.Size = UDim2.new(1, -20, 0, 32)
TabSelector.Position = UDim2.new(0, 10, 0, 140)
TabSelector.BackgroundColor3 = Color3.fromRGB(14, 15, 22)
TabSelector.BorderSizePixel = 0
TabSelector.Parent = Window

local TabCorner = Instance.new("UICorner")
TabCorner.CornerRadius = UDim.new(0, 6)
TabCorner.Parent = TabSelector

local TabList = Instance.new("UIListLayout")
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.Padding = UDim.new(0, 4)
TabList.Parent = TabSelector

local ContentPages = Instance.new("Frame")
ContentPages.Name = "ContentPages"
ContentPages.Size = UDim2.new(1, -20, 0, 270)
ContentPages.Position = UDim2.new(0, 10, 0, 178)
ContentPages.BackgroundTransparency = 1
ContentPages.BorderSizePixel = 0
ContentPages.Parent = Window

local Pages = {}

local function createPage(pageName)
    local page = Instance.new("ScrollingFrame")
    page.Name = pageName
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.CanvasSize = UDim2.new(0, 0, 0, 300)
    page.Visible = (pageName == Engine.SelectedTab)
    page.Parent = ContentPages

    local uiLayout = Instance.new("UIListLayout")
    uiLayout.Padding = UDim.new(0, 6)
    uiLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiLayout.Parent = page

    Pages[pageName] = page
    return page
end

local StrategistPage = createPage("Strategist")
local AutomationPage = createPage("Automation")
local RewardsPage = createPage("Rewards")
local SystemPage = createPage("System")

local function switchTab(name)
    Engine.SelectedTab = name
    for pName, page in pairs(Pages) do
        page.Visible = (pName == name)
    end
end

local function registerTabButton(name, label)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0.24, 0, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(200, 220, 255)
    btn.Text = label
    btn.Parent = TabSelector

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        switchTab(name)
    end)
end

registerTabButton("Strategist", "Strategist")
registerTabButton("Automation", "Match")
registerTabButton("Rewards", "Rewards")
registerTabButton("System", "System")

local function appendToggle(parentPage, name, label, initialValue, onToggle)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = initialValue and Color3.fromRGB(20, 80, 160) or Color3.fromRGB(22, 24, 34)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = initialValue and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 170)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = "  " .. label .. ": " .. (initialValue and "ON" or "OFF")
    btn.Parent = parentPage

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local current = initialValue
    btn.MouseButton1Click:Connect(function()
        current = not current
        btn.BackgroundColor3 = current and Color3.fromRGB(20, 80, 160) or Color3.fromRGB(22, 24, 34)
        btn.TextColor3 = current and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 170)
        btn.Text = "  " .. label .. ": " .. (current and "ON" or "OFF")
        onToggle(current)
    end)
    return btn
end

appendToggle(StrategistPage, "TglAutoAI", "Autonomous Math Strategist", Configuration.AutonomousAI, function(v)
    Configuration.AutonomousAI = v
end)

appendToggle(StrategistPage, "TglChokeOptimize", "Curvature Choke-Point Placement", true, function(v) end)

appendToggle(StrategistPage, "TglNPVEconomy", "Net Economic Value (NPV) Farms", true, function(v) end)

appendToggle(StrategistPage, "TglAutoSellFarms", "Auto-Sell Farms on Wave 27", true, function(v) end)

appendToggle(AutomationPage, "TglAutoSkip", "Auto Skip Wave (Zero Lag)", Configuration.AutoSkip, function(v)
    Configuration.AutoSkip = v
end)

appendToggle(AutomationPage, "TglAutoVote", "Auto Vote Nightmare", Configuration.AutoVote, function(v)
    Configuration.AutoVote = v
end)

appendToggle(AutomationPage, "TglAutoSpeed", "Auto Speed 2x / 1.5x", Configuration.AutoSpeed, function(v)
    Configuration.AutoSpeed = v
    if v then Engine.ConfirmedSpeed = 1 end
end)

appendToggle(AutomationPage, "TglAutoPlayAgain", "Auto Play Again (Replay)", Configuration.AutoPlayAgain, function(v)
    Configuration.AutoPlayAgain = v
end)

appendToggle(RewardsPage, "TglAutoQuests", "Auto Claim Daily Quests", Configuration.AutoClaimQuests, function(v)
    Configuration.AutoClaimQuests = v
end)

appendToggle(RewardsPage, "TglAutoPass", "Auto Claim Battlepass Tiers", Configuration.AutoClaimPass, function(v)
    Configuration.AutoClaimPass = v
end)

appendToggle(SystemPage, "TglFPSBoost", "FPS Boost (Reduce Graphics)", Configuration.FPSBoost, function(v)
    Configuration.FPSBoost = v
    applyPerformanceTweaks()
end)

appendToggle(SystemPage, "TglAntiAFK", "Anti-AFK Protection", Configuration.AntiAFK, function(v)
    Configuration.AntiAFK = v
end)

ExitBtn.MouseButton1Click:Connect(function()
    ScreenGui.Enabled = not ScreenGui.Enabled
end)

reconstructTrackGeometry()
scanEquippedRoster()
bindAntiAFK()
applyPerformanceTweaks()

local function systemLoop()
    if not Engine.Running then return end
    processMatchAutomation()
    processRewardAutomation()

    if Configuration.AutonomousAI then
        executeAutonomousStrategist()
    end

    local wave = Engine.CurrentWave
    local cash = Engine.LiquidCash
    local threatPct = math.floor(Engine.ThreatIndex * 100)

    PhaseLbl.Text = "Phase: " .. Engine.Phase .. " | Regime: " .. Engine.Regime
    FinancialLbl.Text = "Wave: " .. tostring(wave) .. " | Cash: $" .. tostring(cash) .. " | Threat: " .. tostring(threatPct) .. "%"
    TroopsLbl.Text = "Forces: " .. tostring(Engine.CombatUnitsCount) .. " Combat | " .. tostring(Engine.FarmUnitsCount) .. " Farms | " .. tostring(#Engine.Waypoints) .. " WPs"
end

local MainLoopConnection = RunService.Heartbeat:Connect(systemLoop)

LocalPlayer.CharacterRemoving:Connect(function()
    Engine.LastSkipWave = -1
    Engine.LastVoteTimestamp = 0
    Engine.ConfirmedSpeed = 1
    Engine.FarmsSold = false
    Engine.PlacedTowers = {}
    reconstructTrackGeometry()
    scanEquippedRoster()
end)
