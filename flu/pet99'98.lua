local _CREATOR = "by pufyftyk"
local _PROJECT = "PS99 Diamond Mountain - Winter AFK Hub"
local _VERSION = "2.6.0"

pcall(function()
    local _players = game:GetService("Players")
    local _lp = _players.LocalPlayer
    local _vu = game:GetService("VirtualUser")

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
        local count = 0
        while true do
            task.wait(15)
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

local UserConfig = (type(env.Config) == "table" and env.Config) or (type(_G.Config) == "table" and _G.Config) or {}

local Config = {
    HatchBatch = tonumber(UserConfig.HatchBatch) or tonumber(UserConfig.EggCount) or tonumber(UserConfig.Batch) or 79,
    AutoStages = (UserConfig.AutoStages ~= nil) and (UserConfig.AutoStages == true) or true,
    FocusTunnel6 = (UserConfig.FocusTunnel6 ~= nil) and (UserConfig.FocusTunnel6 == true) or false,
    MinAcornsForTunnel = tonumber(UserConfig.MinAcornsForTunnel) or 300,
    AutoFarmBreakables = (UserConfig.AutoFarmBreakables ~= nil) and (UserConfig.AutoFarmBreakables == true) or true,
    AutoHatch = (UserConfig.AutoHatch == true),
    AutoEquipBest = (UserConfig.AutoEquipBest ~= nil) and (UserConfig.AutoEquipBest == true) or true,
    AutoBuyMerchants = (UserConfig.AutoBuyMerchants ~= nil) and (UserConfig.AutoBuyMerchants == true) or true,
    AutoUpgrades = (UserConfig.AutoUpgrades == true),
    AutoCollectRelics = (UserConfig.AutoCollectRelics ~= nil) and (UserConfig.AutoCollectRelics == true) or true,
    PotatoGraphics = (UserConfig.PotatoGraphics ~= nil) and (UserConfig.PotatoGraphics == true) or true,
    BlackScreen = (UserConfig.BlackScreen ~= nil) and (UserConfig.BlackScreen == true) or false,
    TargetMaxZone = tonumber(UserConfig.TargetMaxZone) or 6
}

local State = {
    Running = true,
    StartTime = os.clock(),
    CurrentZone = 1,
    FarmCFrame = nil,
    MenuMinimized = false,
    Tunnel6Open = false,
    Tunnel6CF = nil,
    WorkingBatch = nil,
    StartEggsOpened = nil,
    HadWallTarget = false,
    CampPoints = {},
    CurrentAcorns = 0,
    StartAcorns = nil,
    AcornsGained = 0,
    CurrentDiamonds = 0,
    StartDiamonds = nil,
    DiamondsGained = 0,
    EggsHatched = 0,
    HugesHatched = 0,
    TitanicsHatched = 0,
    RelicsCollected = 0,
    LastHatchTime = 0,
    LastUpgradeTime = 0,
    LastMerchantTime = 0,
    LastRelicScan = 0,
    LastExpeditionCheck = 0,
    LastWallInteraction = 0,
    CurrentActionText = "Starting Winter Farm... | by pufyftyk"
}

local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

pcall(function()
    local hrp = getHRP()
    if hrp then
        State.FarmCFrame = hrp.CFrame
        State.CampPoints[1] = hrp.CFrame
    end
end)

pcall(function()
    local userPoints = UserConfig.CampPoints or UserConfig.CampPositions
    if type(userPoints) == "table" then
        for i = 1, 6 do
            local p = userPoints[i]
            if p then
                if typeof and typeof(p) == "CFrame" then
                    State.CampPoints[i] = p
                elseif typeof and typeof(p) == "Vector3" then
                    State.CampPoints[i] = CFrame.new(p)
                elseif type(p) == "table" and p.X then
                    State.CampPoints[i] = CFrame.new(p.X, p.Y, p.Z)
                end
            end
        end
    end
end)

local RemoteCache = {}
local NetworkFolder = ReplicatedStorage:FindFirstChild("Network")

local GameNetwork = nil
pcall(function()
    local lib = ReplicatedStorage:FindFirstChild("Library")
    local client = lib and lib:FindFirstChild("Client")
    if client and client:FindFirstChild("Network") then
        GameNetwork = require(client.Network)
    end
end)

local function cleanRemoteName(s)
    return string.lower(string.gsub(tostring(s or ""), "[%s%_%:%-]", ""))
end

local function findRemote(name)
    if not name then return nil end
    if RemoteCache[name] and RemoteCache[name].Parent then
        return RemoteCache[name]
    end
    local targetClean = cleanRemoteName(name)
    local function checkRemote(desc)
        if desc and (desc:IsA("RemoteFunction") or desc:IsA("RemoteEvent") or desc.ClassName == "UnreliableRemoteEvent") then
            if cleanRemoteName(desc.Name) == targetClean then
                RemoteCache[name] = desc
                return desc
            end
        end
        return nil
    end
    if NetworkFolder then
        local r = NetworkFolder:FindFirstChild(name)
        if r then RemoteCache[name] = r return r end
        for _, desc in ipairs(NetworkFolder:GetChildren()) do
            local res = checkRemote(desc)
            if res then return res end
        end
    end
    local r2 = ReplicatedStorage:FindFirstChild(name)
    if r2 then
        local res = checkRemote(r2)
        if res then return res end
    end
    return nil
end

local function safeNetworkFire(name, ...)
    local args = { ... }
    local fired = false
    if GameNetwork then
        pcall(function()
            if GameNetwork.UnreliableFire then
                GameNetwork.UnreliableFire(GameNetwork, name, unpack(args))
                fired = true
            elseif GameNetwork.Fire then
                GameNetwork.Fire(GameNetwork, name, unpack(args))
                fired = true
            end
        end)
        if not fired then
            pcall(function()
                if GameNetwork.UnreliableFire then
                    GameNetwork.UnreliableFire(name, unpack(args))
                    fired = true
                elseif GameNetwork.Fire then
                    GameNetwork.Fire(name, unpack(args))
                    fired = true
                end
            end)
        end
    end
    if not fired then
        local r = findRemote(name)
        if r and (r:IsA("RemoteEvent") or r.ClassName == "UnreliableRemoteEvent") then
            pcall(function() r:FireServer(unpack(args)) end)
            fired = true
        end
    end
    return fired
end

local function safeNetworkInvoke(name, ...)
    local args = { ... }
    local resVal = nil
    local okVal = false
    local done = false

    task.spawn(function()
        if GameNetwork and GameNetwork.Invoke then
            local ok, res = pcall(function() return GameNetwork.Invoke(GameNetwork, name, unpack(args)) end)
            if ok and res ~= nil then okVal = true resVal = res done = true return end
            local ok2, res2 = pcall(function() return GameNetwork.Invoke(name, unpack(args)) end)
            if ok2 and res2 ~= nil then okVal = true res2 = res done = true return end
        end
        local r = findRemote(name)
        if r and r:IsA("RemoteFunction") then
            local ok, res = pcall(function() return r:InvokeServer(unpack(args)) end)
            if ok then okVal = true resVal = res done = true return end
        end
        done = true
    end)

    local started = os.clock()
    while not done and (os.clock() - started) < 1.2 do
        task.wait(0.05)
    end
    return okVal, resVal
end

local ThingsFolder = nil
local function getThingsFolder()
    if ThingsFolder and ThingsFolder.Parent then return ThingsFolder end
    ThingsFolder = Workspace:FindFirstChild("__THINGS") or Workspace:FindFirstChild("Things")
    return ThingsFolder
end

local function getBreakablesFolder()
    local things = getThingsFolder()
    if things and things:FindFirstChild("Breakables") then return things.Breakables end
    if Workspace:FindFirstChild("Breakables") then return Workspace.Breakables end
    return nil
end

local function getObjectPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        local p = obj:FindFirstChildWhichIsA("BasePart")
        if p then return p.Position end
    end
    return nil
end

local function parseSuffixedNumber(str)
    if not str then return nil end
    local clean = string.gsub(tostring(str), "<[^>]->", "")
    clean = string.gsub(clean, ",", "")
    local numStr, suffix = string.match(string.lower(clean), "([%d%.]+)%s*([kmb]?)")
    local val = tonumber(numStr)
    if not val then return nil end
    if suffix == "k" then val = val * 1000
    elseif suffix == "m" then val = val * 1000000
    elseif suffix == "b" then val = val * 1000000000 end
    return math.floor(val)
end

local function formatNumber(val)
    local n = tonumber(val) or 0
    if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end

local function formatDuration(sec)
    local s = math.floor(sec or 0)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sc = s % 60
    return string.format("%02d:%02d:%02d", h, m, sc)
end

local function applyPotatoGraphics(enable)
    pcall(function()
        if enable then
            settings().Rendering.QualityLevel = 1
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            if Workspace.Terrain then
                pcall(function() Workspace.Terrain.Decoration = false end)
            end
        else
            Lighting.GlobalShadows = true
            Lighting.FogEnd = 100000
        end
    end)
end

local function detectCurrentZone()
    pcall(function()
        local client = ReplicatedStorage:FindFirstChild("Library") and ReplicatedStorage.Library:FindFirstChild("Client")
        local saveMod = client and client:FindFirstChild("Save")
        if saveMod then
            local save = require(saveMod).Get()
            if save then
                local z = save.DiamondMountainCamp or save.DiamondMountainZone or save.Camp or save.CurrentCamp or save.Zone or save.MaxZone
                if z and tonumber(z) then
                    local nz = tonumber(z)
                    if nz >= 1 and nz <= 6 then State.CurrentZone = nz end
                end
                if save.UnlockedZones and type(save.UnlockedZones) == "table" then
                    local count = 0
                    for k, v in pairs(save.UnlockedZones) do
                        local num = tonumber(k) or tonumber(v) or tonumber(string.match(tostring(k), "%d+"))
                        if num and num > count then count = num end
                    end
                    if count >= 1 and count <= 6 then
                        State.CurrentZone = count
                    end
                end
            end
        end
    end)

    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if pgui then
            for _, desc in ipairs(pgui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible then
                    local t = desc.Text or desc.ContentText or ""
                    local cMatch = string.match(t, "[Cc]amp%s*(%d+)") or string.match(t, "[Zz]one%s*(%d+)")
                    if cMatch then
                        local n = tonumber(cMatch)
                        if n and n >= 1 and n <= 6 then
                            State.CurrentZone = n
                        end
                    end
                end
            end
        end
    end)

    pcall(function()
        local map = Workspace:FindFirstChild("Map") or Workspace
        for _, child in ipairs(map:GetChildren()) do
            local low = string.lower(child.Name)
            local num = string.match(low, "camp%s*(%d+)") or string.match(low, "zone%s*(%d+)")
            if num then
                local idx = tonumber(num)
                if idx and idx >= 1 and idx <= 6 and not State.CampPoints[idx] then
                    local p = getObjectPosition(child)
                    if p then
                        State.CampPoints[idx] = CFrame.new(p) + Vector3.new(0, 3, 0)
                    end
                end
            end
        end
    end)
end

local function updateCurrencies()
    pcall(function()
        local client = ReplicatedStorage:FindFirstChild("Library") and ReplicatedStorage.Library:FindFirstChild("Client")
        local saveMod = client and client:FindFirstChild("Save")
        if saveMod then
            local save = require(saveMod).Get()
            if save then
                local realEggs = save.EggsOpened or save.EggsHatched
                if realEggs and type(realEggs) == "number" then
                    if not State.StartEggsOpened then
                        State.StartEggsOpened = realEggs
                    else
                        local diff = realEggs - State.StartEggsOpened
                        if diff >= 0 then
                            State.EggsHatched = diff
                        end
                    end
                end
                if save.Diamonds and type(save.Diamonds) == "number" then
                    if not State.StartDiamonds then State.StartDiamonds = save.Diamonds end
                    State.CurrentDiamonds = save.Diamonds
                    State.DiamondsGained = math.max(0, save.Diamonds - State.StartDiamonds)
                end
            end
        end
    end)

    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, st in ipairs(ls:GetChildren()) do
                local sLow = string.lower(st.Name)
                if string.find(sLow, "diamond") or string.find(sLow, "gem") then
                    local d = parseSuffixedNumber(tostring(st.Value)) or 0
                    if not State.StartDiamonds then State.StartDiamonds = d end
                    State.CurrentDiamonds = d
                    State.DiamondsGained = math.max(0, d - State.StartDiamonds)
                elseif string.find(sLow, "acorn") or string.find(sLow, "coin") or string.find(sLow, "event") then
                    local a = parseSuffixedNumber(tostring(st.Value)) or 0
                    if not State.StartAcorns then State.StartAcorns = a end
                    State.CurrentAcorns = a
                    State.AcornsGained = math.max(0, a - State.StartAcorns)
                end
            end
        end

        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if pgui then
            local mainLeft = pgui:FindFirstChild("MainLeft")
            local leftFrame = mainLeft and mainLeft:FindFirstChild("Left")
            local currFolder = leftFrame and (leftFrame:FindFirstChild("Currency") or leftFrame:FindFirstChild("Currencies"))
            if currFolder then
                for _, cFrame in ipairs(currFolder:GetChildren()) do
                    if cFrame:IsA("GuiObject") and cFrame.Visible then
                        local cn = string.lower(cFrame.Name)
                        local isDiamond = string.find(cn, "diamond") or string.find(cn, "gem")
                        for _, sub in ipairs(cFrame:GetDescendants()) do
                            if sub:IsA("TextLabel") and string.lower(sub.Name) == "amount" then
                                local rawTxt = (sub.ContentText ~= "" and sub.ContentText) or sub.Text or ""
                                local parsed = parseSuffixedNumber(rawTxt)
                                if parsed then
                                    if isDiamond then
                                        if not State.StartDiamonds then State.StartDiamonds = parsed end
                                        State.CurrentDiamonds = parsed
                                        State.DiamondsGained = math.max(0, parsed - State.StartDiamonds)
                                    else
                                        if not State.StartAcorns then State.StartAcorns = parsed end
                                        State.CurrentAcorns = parsed
                                        State.AcornsGained = math.max(0, parsed - State.StartAcorns)
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

local function collectOrbsAndLootbags()
    local hrp = getHRP()
    if not hrp then return end
    local things = getThingsFolder()
    if not things then return end

    pcall(function()
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
                if numId then
                    table.insert(orbIds, numId)
                end
                if #orbIds >= 35 then break end
            end
            if #orbIds > 0 then
                safeNetworkFire("Orbs: Collect", orbIds)
                safeNetworkFire("Orbs_Collect", orbIds)
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
                safeNetworkFire("Lootbags_Claim", { bag.Name })
                safeNetworkFire("Lootbags: Claim", { bag.Name })
            end
        end

        local drops = things:FindFirstChild("Diamonds") or things:FindFirstChild("Drops")
        if drops then
            for _, d in ipairs(drops:GetChildren()) do
                if d:IsA("BasePart") then
                    d.CFrame = hrp.CFrame
                elseif d:IsA("Model") then
                    d:PivotTo(hrp.CFrame)
                end
            end
        end
    end)
end

local function commandPetsToAttack(b)
    if not b then return end
    local uid = b:GetAttribute("UID") or b:GetAttribute("id") or b.Name

    pcall(function()
        local client = ReplicatedStorage:FindFirstChild("Library") and ReplicatedStorage.Library:FindFirstChild("Client")
        if client then
            local petCmds = client:FindFirstChild("PetCmds")
            if petCmds then
                local m = require(petCmds)
                if m and type(m.SetTarget) == "function" then
                    pcall(function() m.SetTarget(b) end)
                    pcall(function() m.SetTarget(uid) end)
                end
            end
            local playerPet = client:FindFirstChild("PlayerPet")
            if playerPet then
                local m = require(playerPet)
                if m then
                    if type(m.SetTarget) == "function" then
                        pcall(function() m.SetTarget(b) end)
                        pcall(function() m.SetTarget(uid) end)
                    end
                    local allPets = (m.GetAll and m.GetAll()) or (m.GetAllForPlayer and m.GetAllForPlayer(LocalPlayer)) or (m.GetPets and m.GetPets())
                    if type(allPets) == "table" then
                        for _, p in pairs(allPets) do
                            if type(p) == "table" and p.SetTarget then
                                pcall(function() p:SetTarget(b) end)
                                pcall(function() p.SetTarget(p, b) end)
                            end
                        end
                    end
                end
            end
        end
    end)

    local petIds = {}
    pcall(function()
        local client = ReplicatedStorage:FindFirstChild("Library") and ReplicatedStorage.Library:FindFirstChild("Client")
        local saveMod = client and client:FindFirstChild("Save")
        if saveMod then
            local save = require(saveMod).Get()
            if save and save.EquippedPets then
                for k, v in pairs(save.EquippedPets) do
                    local pId = (type(v) == "string" and v) or (type(v) == "table" and (v.id or v.UUID or v.UID)) or (type(k) == "string" and k)
                    if pId then table.insert(petIds, pId) end
                end
            end
        end
    end)

    safeNetworkFire("Breakables_PlayerDealDamage", uid)
    safeNetworkFire("Breakables: PlayerDealDamage", uid)
    safeNetworkFire("Breakables_RequestTarget", uid)
    safeNetworkFire("Breakables: RequestTarget", uid)
    safeNetworkFire("Breakables_JoinPet", uid)
    safeNetworkFire("Breakables: JoinPet", uid)
    if #petIds > 0 then
        safeNetworkFire("Breakables_JoinPet", uid, petIds)
        safeNetworkFire("Breakables: JoinPet", uid, petIds)
    else
        safeNetworkFire("Breakables_JoinPet", uid, {})
    end
end

local function handleRubbleWallInteraction()
    local hrp = getHRP()
    if not hrp then return end
    local myPos = hrp.Position
    local now = os.clock()
    if now - State.LastWallInteraction < 1.5 then return end
    State.LastWallInteraction = now

    local foundPrompt = nil
    pcall(function()
        local map = Workspace:FindFirstChild("Map")
        if map then
            for _, desc in ipairs(map:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    local act = string.lower(desc.ActionText or "")
                    local objTxt = string.lower(desc.ObjectText or "")
                    local pName = string.lower(desc.Parent and desc.Parent.Name or "")
                    if string.find(act, "wall") or string.find(act, "rubble") or string.find(act, "break") or string.find(act, "mine") or
                       string.find(objTxt, "wall") or string.find(objTxt, "rubble") or
                       string.find(pName, "wall") or string.find(pName, "rubble") or string.find(pName, "gate") then
                        local p = desc.Parent
                        local pos = getObjectPosition(p)
                        if pos and (pos - myPos).Magnitude <= 50 then
                            foundPrompt = desc
                            break
                        end
                    end
                end
            end
        end
    end)

    if not foundPrompt then
        local things = getThingsFolder()
        if things and things:FindFirstChild("Breakables") then
            for _, b in ipairs(things.Breakables:GetChildren()) do
                local low = string.lower(b.Name)
                if string.find(low, "rubble") or string.find(low, "wall") or string.find(low, "gate") then
                    local p = b:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if p then
                        local pos = getObjectPosition(b)
                        if pos and (pos - myPos).Magnitude <= 50 then
                            foundPrompt = p
                            break
                        end
                    end
                end
            end
        end
    end

    if foundPrompt and fireproximityprompt then
        pcall(function() fireproximityprompt(foundPrompt) end)
    end

    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pgui then return end

        for _, g in ipairs(pgui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "DiamondMountainHub" then
                local selectBtn = nil
                local confirmBtn = nil
                local petButtons = {}

                for _, desc in ipairs(g:GetDescendants()) do
                    if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
                        local tLow = (desc:IsA("TextButton") and string.lower(desc.Text)) or ""
                        local nLow = string.lower(desc.Name)

                        if string.find(tLow, "select all") or string.find(tLow, "auto select") or string.find(nLow, "autoselect") or string.find(nLow, "selectall") or string.find(tLow, "best") then
                            selectBtn = desc
                        elseif string.find(tLow, "break") or string.find(tLow, "send") or string.find(tLow, "start") or string.find(tLow, "deploy") or string.find(tLow, "attack") or string.find(tLow, "confirm") or string.find(tLow, "smash") then
                            confirmBtn = desc
                        elseif string.find(nLow, "pet") or string.find(nLow, "slot") or string.find(nLow, "icon") then
                            table.insert(petButtons, desc)
                        end
                    end
                end

                if selectBtn or confirmBtn then
                    if selectBtn then
                        if firesignal then
                            firesignal(selectBtn.MouseButton1Click)
                            firesignal(selectBtn.Activated)
                        end
                    else
                        for i = 1, math.min(#petButtons, 12) do
                            local pb = petButtons[i]
                            if firesignal then
                                firesignal(pb.MouseButton1Click)
                                firesignal(pb.Activated)
                            end
                        end
                    end

                    task.wait(0.08)

                    if confirmBtn then
                        if firesignal then
                            firesignal(confirmBtn.MouseButton1Click)
                            firesignal(confirmBtn.Activated)
                        end
                        State.CurrentActionText = string.format("Pets Selected & Sent to Wall! | Camp %d | by pufyftyk", State.CurrentZone)
                    end
                end
            end
        end
    end)
end

local function farmNearbyBreakables()
    local hrp = getHRP()
    if not hrp then return end
    local myPos = hrp.Position
    local bFolder = getBreakablesFolder()
    if not bFolder then return end

    local wallTarget = nil
    local normalTargets = {}

    for _, b in ipairs(bFolder:GetChildren()) do
        local bPos = getObjectPosition(b)
        if bPos then
            local dist = (bPos - myPos).Magnitude
            local low = string.lower(b.Name)
            local isWall = string.find(low, "rubble") or string.find(low, "wall") or string.find(low, "gate") or string.find(low, "rock") or string.find(low, "door") or string.find(low, "yeti") or string.find(low, "boss")
            if isWall and dist <= 180 then
                wallTarget = b
                break
            elseif dist <= 95 then
                table.insert(normalTargets, { obj = b, dist = dist })
            end
        end
    end

    if wallTarget then
        State.HadWallTarget = true
        State.CurrentActionText = string.format("ALL PETS BREAKING WALL! | Camp %d | by pufyftyk", State.CurrentZone)
        commandPetsToAttack(wallTarget)
        commandPetsToAttack(wallTarget)
        return
    end

    if Config.AutoStages and State.HadWallTarget and not wallTarget then
        State.HadWallTarget = false
        local nextZ = math.min(Config.TargetMaxZone or 6, State.CurrentZone + 1)
        State.CurrentZone = nextZ
        if State.CampPoints[nextZ] then
            hrp.CFrame = State.CampPoints[nextZ]
            State.FarmCFrame = State.CampPoints[nextZ]
            State.CurrentActionText = string.format("WALL BROKEN! Teleported to Saved Camp %d! | by pufyftyk", nextZ)
        else
            local forwardCF = hrp.CFrame + (hrp.CFrame.LookVector * 45) + Vector3.new(0, 3.5, 0)
            hrp.CFrame = forwardCF
            State.FarmCFrame = forwardCF
            State.CurrentActionText = string.format("WALL BROKEN! Advanced to Camp %d! | by pufyftyk", nextZ)
        end
        return
    end

    table.sort(normalTargets, function(a, b) return a.dist < b.dist end)
    local maxAttacks = math.min(#normalTargets, 5)
    for i = 1, maxAttacks do
        commandPetsToAttack(normalTargets[i].obj)
    end

    if maxAttacks > 0 then
        State.CurrentActionText = string.format("Farming %d Breakables | Camp %d | by pufyftyk", maxAttacks, State.CurrentZone)
    else
        State.CurrentActionText = string.format("Camp %d: Searching Targets... | by pufyftyk", State.CurrentZone)
    end
end

local function findNearestEggMachine(maxDist)
    local hrp = getHRP()
    if not hrp then return nil, nil, nil, nil end
    local myPos = hrp.Position
    local limit = maxDist or 120

    local eggCandidates = {}
    local function checkCandidate(obj, customId, prompt)
        if not obj then return end
        local p = getObjectPosition(obj)
        if p then
            local d = (p - myPos).Magnitude
            if d <= limit then
                local eggId = customId or obj:GetAttribute("id") or obj:GetAttribute("EggName") or obj:GetAttribute("ID") or obj:GetAttribute("EggId") or obj.Name
                table.insert(eggCandidates, { obj = obj, pos = p, dist = d, id = eggId, prompt = prompt })
            end
        end
    end

    local things = getThingsFolder()
    if things then
        for _, fName in ipairs({ "CustomEggs", "Eggs", "EggCapsules", "EggMachines" }) do
            local f = things:FindFirstChild(fName)
            if f then
                for _, egg in ipairs(f:GetChildren()) do
                    checkCandidate(egg)
                end
            end
        end
    end

    table.sort(eggCandidates, function(a, b) return a.dist < b.dist end)
    if #eggCandidates > 0 then
        return eggCandidates[1].obj, eggCandidates[1].id, eggCandidates[1].pos, eggCandidates[1].prompt
    end
    return nil, nil, nil, nil
end

local function autoEquipBestPets()
    if not Config.AutoEquipBest then return end
    safeNetworkFire("Pets_EquipBest")
    safeNetworkFire("EquipBest")
    safeNetworkFire("Pets: EquipBest")

    pcall(function()
        local client = ReplicatedStorage:FindFirstChild("Library") and ReplicatedStorage.Library:FindFirstChild("Client")
        if client then
            for _, modName in ipairs({ "PetCmds", "PlayerPet", "EquipCmds", "PetEquip", "Equip" }) do
                local mod = client:FindFirstChild(modName)
                if mod then
                    local m = require(mod)
                    if m then
                        if type(m.EquipBest) == "function" then pcall(m.EquipBest) end
                        if type(m.AllEquipBest) == "function" then pcall(m.AllEquipBest) end
                    end
                end
            end
        end
    end)

    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if pgui then
            for _, b in ipairs(pgui:GetDescendants()) do
                if (b:IsA("TextButton") or b:IsA("ImageButton")) and b.Visible then
                    local nameLow = string.lower(b.Name)
                    local textLow = (b:IsA("TextButton") and string.lower(b.Text)) or ""
                    if string.find(nameLow, "equipbest") or string.find(textLow, "equip best") then
                        if firesignal then
                            firesignal(b.MouseButton1Click)
                            firesignal(b.Activated)
                        end
                    end
                end
            end
        end
    end)
end

local HatchStepDownList = { 79, 50, 25, 20, 15, 10, 8, 4, 3, 2, 1 }

local function hatchNearestEgg()
    if not Config.AutoHatch then return false end
    local eggObj, eggId, eggPos, eggPrompt = findNearestEggMachine(120)
    if not eggObj or not eggId then return false end

    local hrp = getHRP()
    if not hrp then return false end

    if eggPos and (hrp.Position - eggPos).Magnitude > 35 then
        return false
    end

    local targetBatch = State.WorkingBatch or Config.HatchBatch or 79
    local remotesToTry = { "CustomEggs_Hatch", "CustomEggs: Hatch", "Eggs_RequestPurchase", "Eggs: RequestPurchase", "Eggs_Roll" }
    local idsToTry = { eggId, eggObj.Name }
    local attr = eggObj:GetAttribute("EggName") or eggObj:GetAttribute("id") or eggObj:GetAttribute("ID")
    if attr then table.insert(idsToTry, attr) end

    local didHatch = false
    local actualCount = 0

    local function tryBatch(amt)
        for _, rName in ipairs(remotesToTry) do
            for _, idVal in ipairs(idsToTry) do
                local ok, res = safeNetworkInvoke(rName, idVal, amt)
                if ok and res ~= nil and res ~= false then
                    if type(res) == "table" and res.Success == false then
                    else
                        State.WorkingBatch = amt
                        return true, amt
                    end
                end
            end
        end
        return false, 0
    end

    local ok, count = tryBatch(targetBatch)
    if ok then
        didHatch = true
        actualCount = count
    else
        for _, stepAmt in ipairs(HatchStepDownList) do
            if stepAmt < targetBatch then
                local stepOk, stepCount = tryBatch(stepAmt)
                if stepOk then
                    didHatch = true
                    actualCount = stepCount
                    break
                end
            end
        end
    end

    if not didHatch and eggPrompt and fireproximityprompt then
        pcall(function() fireproximityprompt(eggPrompt) end)
    end

    if didHatch and actualCount > 0 then
        if not State.StartEggsOpened then
            State.EggsHatched = State.EggsHatched + actualCount
        end
        State.LastHatchTime = os.clock()
        task.spawn(autoEquipBestPets)
        return true
    end

    return false
end

local function buyZone1Upgrades()
    if not Config.AutoUpgrades then return end
    local now = os.clock()
    if now - State.LastUpgradeTime < 5.0 then return end
    State.LastUpgradeTime = now

    pcall(function()
        local targetUpgrades = { "Wall Power", "Expedition Speed", "Acorn Drops", "Offline Power", "Speed", "More Diamonds", "Luck", "Damage" }
        for _, upg in ipairs(targetUpgrades) do
            safeNetworkFire("Upgrades_Purchase", upg)
            safeNetworkFire("EventUpgrades_Purchase", upg)
            safeNetworkFire("Upgrades: Purchase", upg)
        end
    end)
end

local function buyMerchantBuffs()
    if not Config.AutoBuyMerchants then return end
    local now = os.clock()
    if now - State.LastMerchantTime < 3.0 then return end
    State.LastMerchantTime = now

    pcall(function()
        for slot = 1, 6 do
            safeNetworkFire("Merchant: RequestPurchase", "DiamondMountain", slot)
            safeNetworkFire("Merchants: RequestPurchase", "DiamondMountain", slot)
            safeNetworkFire("Merchant_RequestPurchase", "DiamondMountain", slot)
            safeNetworkFire("Merchant: RequestPurchase", "Mountain", slot)
            safeNetworkFire("Merchant_RequestPurchase", "Mountain", slot)
            safeNetworkFire("Merchant: RequestPurchase", slot)
            safeNetworkFire("Merchant_RequestPurchase", slot)
        end
    end)
end

local function collectSecretRelics()
    if not Config.AutoCollectRelics then return end
    local now = os.clock()
    if now - State.LastRelicScan < 30.0 then return end
    State.LastRelicScan = now

    pcall(function()
        for id = 1, 6 do
            safeNetworkFire("Relics: Claim", id)
            safeNetworkFire("Relics_Claim", id)
            safeNetworkFire("SecretRelic_Claim", id)
        end
        State.RelicsCollected = 6
    end)
end

local function handleExpeditions()
    local now = os.clock()
    if now - State.LastExpeditionCheck < 15.0 then return end
    State.LastExpeditionCheck = now
    pcall(function()
        safeNetworkFire("Expeditions_ClaimAll")
        safeNetworkFire("Expeditions: ClaimAll")
        for id = 1, 4 do
            safeNetworkFire("Expeditions: Claim", id)
            safeNetworkFire("Expeditions_Claim", id)
            safeNetworkFire("Expeditions_UnlockPedestal", id)
            safeNetworkFire("Expeditions_Send", id)
        end
    end)
end

local Colors = {
    Bg = Color3.fromRGB(10, 16, 28),
    Header = Color3.fromRGB(15, 25, 45),
    Card = Color3.fromRGB(16, 26, 46),
    CardBright = Color3.fromRGB(24, 40, 70),
    Stroke = Color3.fromRGB(50, 150, 230),
    IceAccent = Color3.fromRGB(80, 210, 255),
    SnowWhite = Color3.fromRGB(245, 250, 255),
    SubText = Color3.fromRGB(165, 205, 245),
    Green = Color3.fromRGB(46, 204, 113),
    Red = Color3.fromRGB(235, 75, 75),
    Gold = Color3.fromRGB(255, 215, 0),
    InputBg = Color3.fromRGB(8, 12, 22)
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
    if ParentGui:FindFirstChild("DiamondMountainHub") then
        ParentGui:FindFirstChild("DiamondMountainHub"):Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DiamondMountainHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 100
pcall(function() ScreenGui.IgnoreGuiInset = true end)
ScreenGui.Parent = ParentGui

local function addCornerAndStroke(inst, radius, strokeColor, thickness)
    if radius then Instance.new("UICorner", inst).CornerRadius = UDim.new(0, radius) end
    if strokeColor then
        local s = Instance.new("UIStroke", inst)
        s.Color = strokeColor
        s.Thickness = thickness or 1.2
        return s
    end
    return nil
end

local function makeBtn(parent, size, pos, bg, text, textSize, radius, zIndex)
    local b = Instance.new("TextButton")
    b.Size = size
    if pos then b.Position = pos end
    b.BackgroundColor3 = bg
    b.Text = text or ""
    b.TextColor3 = Colors.SnowWhite
    b.Font = Enum.Font.GothamBold
    b.TextSize = textSize or 12
    b.TextStrokeTransparency = 0.5
    b.TextStrokeColor3 = Color3.new(0, 0, 0)
    b.ZIndex = zIndex or 25
    b.Parent = parent
    addCornerAndStroke(b, radius or 6, Colors.Stroke, 1.2)
    return b
end

local function makeLabel(parent, size, pos, text, color, font, textSize, xAlign, zIndex)
    local l = Instance.new("TextLabel")
    l.Size = size
    if pos then l.Position = pos end
    l.BackgroundTransparency = 1
    l.Text = text or ""
    l.TextColor3 = color or Colors.SnowWhite
    l.Font = font or Enum.Font.GothamBold
    l.TextSize = textSize or 12
    l.TextStrokeTransparency = 0.5
    l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.ZIndex = zIndex or 25
    l.Parent = parent
    return l
end

local BlackOverlayFrame = Instance.new("Frame")
BlackOverlayFrame.Name = "BlackScreenOverlay"
BlackOverlayFrame.Size = UDim2.new(1, 0, 1, 0)
BlackOverlayFrame.BackgroundColor3 = Color3.fromRGB(5, 7, 12)
BlackOverlayFrame.BorderSizePixel = 0
BlackOverlayFrame.Visible = false
BlackOverlayFrame.ZIndex = 50
BlackOverlayFrame.Parent = ScreenGui

local BlackText = makeLabel(BlackOverlayFrame, UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0.4, 0), "OLED AFK Battery Saver Active\nTap Wake Screen to return", Colors.IceAccent, Enum.Font.GothamBold, 15, Enum.TextXAlignment.Center)
local BlackExitBtn = makeBtn(BlackOverlayFrame, UDim2.new(0, 180, 0, 42), UDim2.new(0.5, -90, 0.5, 20), Colors.Header, "[+] Wake Screen", 14, 8)
addCornerAndStroke(BlackExitBtn, 8, Colors.IceAccent, 1.5)

local DashCard = Instance.new("Frame")
DashCard.Name = "DiamondDashCard"
DashCard.Size = UDim2.new(0, 440, 0, 360)
DashCard.Position = UDim2.new(0.5, -220, 0.5, -180)
DashCard.BackgroundColor3 = Colors.Bg
DashCard.BorderSizePixel = 0
DashCard.ZIndex = 10
DashCard.Parent = ScreenGui
addCornerAndStroke(DashCard, 10, Colors.Stroke, 1.5)

local DashTopBar = Instance.new("Frame")
DashTopBar.Size = UDim2.new(1, 0, 0, 48)
DashTopBar.BackgroundColor3 = Colors.Header
DashTopBar.BorderSizePixel = 0
DashTopBar.ZIndex = 11
DashTopBar.Parent = DashCard
addCornerAndStroke(DashTopBar, 10, nil, nil)

do
    local dragging, dragStart, startPos = false, nil, nil
    trackConn(DashTopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = DashCard.Position
        end
    end))
    trackConn(DashTopBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    trackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            DashCard.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

makeLabel(DashTopBar, UDim2.new(1, -90, 0, 22), UDim2.new(0, 14, 0, 4), "[*] DIAMOND MOUNTAIN HUB | by pufyftyk", Colors.IceAccent, Enum.Font.GothamBold, 14)
local DashSubTitle = makeLabel(DashTopBar, UDim2.new(1, -90, 0, 16), UDim2.new(0, 14, 0, 26), "Winter Event | Wall Rush | Merchant Buffs", Colors.SubText, Enum.Font.Gotham, 11)

local MinMenuBtn = makeBtn(DashTopBar, UDim2.new(0, 30, 0, 28), UDim2.new(1, -74, 0, 10), Colors.CardBright, "-", 13, 6)
local CloseScriptBtn = makeBtn(DashTopBar, UDim2.new(0, 30, 0, 28), UDim2.new(1, -38, 0, 10), Colors.Red, "X", 12, 6)

local ReturnBtn = makeBtn(ScreenGui, UDim2.new(0, 140, 0, 34), UDim2.new(0, 12, 0, 12), Colors.Bg, "[*] Diamond Hub", 12, 8)
ReturnBtn.TextColor3 = Colors.IceAccent
ReturnBtn.Visible = false
addCornerAndStroke(ReturnBtn, 8, Colors.IceAccent, 1.5)

local function createStatBox(parent, title, initVal, posScaleX, posY, widthScale, heightPx, valColor)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(widthScale, -12, 0, heightPx)
    box.Position = UDim2.new(posScaleX, 10, 0, posY)
    box.BackgroundColor3 = Colors.Card
    box.BorderSizePixel = 0
    box.ZIndex = 12
    box.Parent = parent
    addCornerAndStroke(box, 6, Colors.Stroke, 1)
    makeLabel(box, UDim2.new(1, -8, 0, 14), UDim2.new(0, 6, 0, 3), title, Colors.SubText, Enum.Font.Gotham, 10)
    local lblVal = makeLabel(box, UDim2.new(1, -8, 0, heightPx - 18), UDim2.new(0, 6, 0, 17), initVal, valColor or Colors.SnowWhite, Enum.Font.GothamBold, 13)
    return lblVal
end

local StatTimeVal = createStatBox(DashCard, "Time", "00:00:00", 0, 54, 0.333, 44, Colors.SnowWhite)
local StatAcornsVal = createStatBox(DashCard, "Acorns", "0 (+0)", 0.333, 54, 0.333, 44, Colors.Gold)
local StatGemsVal = createStatBox(DashCard, "Diamonds", "0 (+0)", 0.666, 54, 0.334, 44, Colors.IceAccent)

local StatZoneVal = createStatBox(DashCard, "Zone", "Camp 1/6", 0, 104, 0.25, 44, Colors.IceAccent)
local StatEggsVal = createStatBox(DashCard, "Eggs", "0", 0.25, 104, 0.25, 44, Colors.Gold)
local StatPetsVal = createStatBox(DashCard, "Huge/Titan", "0 / 0", 0.50, 104, 0.25, 44, Colors.Green)
local StatRelicsVal = createStatBox(DashCard, "Relics", "0/6", 0.75, 104, 0.25, 44, Colors.SnowWhite)

local StatusBanner = Instance.new("Frame")
StatusBanner.Size = UDim2.new(1, -20, 0, 32)
StatusBanner.Position = UDim2.new(0, 10, 0, 154)
StatusBanner.BackgroundColor3 = Colors.InputBg
StatusBanner.BorderSizePixel = 0
StatusBanner.ZIndex = 12
StatusBanner.Parent = DashCard
addCornerAndStroke(StatusBanner, 6, Colors.Stroke, 1)

local StatStatusVal = makeLabel(StatusBanner, UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), "Status: Initializing... | by pufyftyk", Colors.SnowWhite, Enum.Font.Gotham, 11)
StatStatusVal.TextWrapped = true

local BtnStages = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0, 10, 0, 192), Config.AutoStages and Colors.Green or Colors.CardBright, "Wall Rush / Stages: " .. (Config.AutoStages and "ON" or "OFF"), 11, 6)
local BtnHatch = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0.5, 4, 0, 192), Config.AutoHatch and Colors.Green or Colors.CardBright, "Auto Hatch: " .. (Config.AutoHatch and "ON" or "OFF"), 11, 6)

local BtnMerchants = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0, 10, 0, 228), Config.AutoBuyMerchants and Colors.Green or Colors.CardBright, "Merchant Buffs: " .. (Config.AutoBuyMerchants and "ON" or "OFF"), 11, 6)
local BtnTunnel6 = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0.5, 4, 0, 228), Config.FocusTunnel6 and Colors.Green or Colors.CardBright, "Focus Tunnel 6: " .. (Config.FocusTunnel6 and "ON" or "OFF"), 11, 6)

local BtnUpgrades = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0, 10, 0, 264), Config.AutoUpgrades and Colors.Green or Colors.CardBright, "Zone Upgrades: " .. (Config.AutoUpgrades and "ON" or "OFF"), 11, 6)
local BtnRelics = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0.5, 4, 0, 264), Config.AutoCollectRelics and Colors.Green or Colors.CardBright, "Collect Relics: " .. (Config.AutoCollectRelics and "ON" or "OFF"), 11, 6)

local BtnPotato = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0, 10, 0, 300), Config.PotatoGraphics and Colors.Green or Colors.CardBright, "Potato FPS: " .. (Config.PotatoGraphics and "ON" or "OFF"), 11, 6)
local BtnBlackScreen = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0.5, 4, 0, 300), Config.BlackScreen and Colors.Green or Colors.CardBright, "Black Screen: " .. (Config.BlackScreen and "ON" or "OFF"), 11, 6)

local BtnSaveCamp = makeBtn(DashCard, UDim2.new(0.33, -10, 0, 24), UDim2.new(0, 8, 0, 334), Colors.Header, "[*] Save Point", 10, 5)
local BtnAdvanceCamp = makeBtn(DashCard, UDim2.new(0.33, -10, 0, 24), UDim2.new(0.33, 4, 0, 334), Colors.Header, "[+] Next Camp", 10, 5)
local BtnPrevCamp = makeBtn(DashCard, UDim2.new(0.34, -10, 0, 24), UDim2.new(0.66, 2, 0, 334), Colors.Header, "[-] Prev Camp", 10, 5)

trackConn(MinMenuBtn.MouseButton1Click:Connect(function()
    DashCard.Visible = false
    ReturnBtn.Visible = true
end))

trackConn(ReturnBtn.MouseButton1Click:Connect(function()
    DashCard.Visible = true
    ReturnBtn.Visible = false
end))

trackConn(BtnStages.MouseButton1Click:Connect(function()
    Config.AutoStages = not Config.AutoStages
    BtnStages.Text = "Wall Rush / Stages: " .. (Config.AutoStages and "ON" or "OFF")
    BtnStages.BackgroundColor3 = Config.AutoStages and Colors.Green or Colors.CardBright
end))

trackConn(BtnHatch.MouseButton1Click:Connect(function()
    Config.AutoHatch = not Config.AutoHatch
    BtnHatch.Text = "Auto Hatch: " .. (Config.AutoHatch and "ON" or "OFF")
    BtnHatch.BackgroundColor3 = Config.AutoHatch and Colors.Green or Colors.CardBright
end))

trackConn(BtnMerchants.MouseButton1Click:Connect(function()
    Config.AutoBuyMerchants = not Config.AutoBuyMerchants
    BtnMerchants.Text = "Merchant Buffs: " .. (Config.AutoBuyMerchants and "ON" or "OFF")
    BtnMerchants.BackgroundColor3 = Config.AutoBuyMerchants and Colors.Green or Colors.CardBright
end))

trackConn(BtnTunnel6.MouseButton1Click:Connect(function()
    Config.FocusTunnel6 = not Config.FocusTunnel6
    BtnTunnel6.Text = "Focus Tunnel 6: " .. (Config.FocusTunnel6 and "ON" or "OFF")
    BtnTunnel6.BackgroundColor3 = Config.FocusTunnel6 and Colors.Green or Colors.CardBright
end))

trackConn(BtnUpgrades.MouseButton1Click:Connect(function()
    Config.AutoUpgrades = not Config.AutoUpgrades
    BtnUpgrades.Text = "Zone Upgrades: " .. (Config.AutoUpgrades and "ON" or "OFF")
    BtnUpgrades.BackgroundColor3 = Config.AutoUpgrades and Colors.Green or Colors.CardBright
end))

trackConn(BtnRelics.MouseButton1Click:Connect(function()
    Config.AutoCollectRelics = not Config.AutoCollectRelics
    BtnRelics.Text = "Collect Relics: " .. (Config.AutoCollectRelics and "ON" or "OFF")
    BtnRelics.BackgroundColor3 = Config.AutoCollectRelics and Colors.Green or Colors.CardBright
    if Config.AutoCollectRelics then
        collectSecretRelics()
    end
end))

trackConn(BtnPotato.MouseButton1Click:Connect(function()
    Config.PotatoGraphics = not Config.PotatoGraphics
    BtnPotato.Text = "Potato FPS: " .. (Config.PotatoGraphics and "ON" or "OFF")
    BtnPotato.BackgroundColor3 = Config.PotatoGraphics and Colors.Green or Colors.CardBright
    applyPotatoGraphics(Config.PotatoGraphics)
end))

trackConn(BtnBlackScreen.MouseButton1Click:Connect(function()
    Config.BlackScreen = not Config.BlackScreen
    BtnBlackScreen.Text = "Black Screen: " .. (Config.BlackScreen and "ON" or "OFF")
    BtnBlackScreen.BackgroundColor3 = Config.BlackScreen and Colors.Green or Colors.CardBright
    BlackOverlayFrame.Visible = Config.BlackScreen
end))

trackConn(BlackExitBtn.MouseButton1Click:Connect(function()
    Config.BlackScreen = false
    BtnBlackScreen.Text = "Black Screen: OFF"
    BtnBlackScreen.BackgroundColor3 = Colors.CardBright
    BlackOverlayFrame.Visible = false
end))

trackConn(BtnSaveCamp.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    if hrp then
        State.CampPoints[State.CurrentZone] = hrp.CFrame
        State.FarmCFrame = hrp.CFrame
        State.CurrentActionText = string.format("Camp %d Point Saved! | by pufyftyk", State.CurrentZone)
    end
end))

trackConn(BtnAdvanceCamp.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    if hrp then
        local nextZ = math.min(Config.TargetMaxZone or 6, State.CurrentZone + 1)
        State.CurrentZone = nextZ
        if State.CampPoints[nextZ] then
            hrp.CFrame = State.CampPoints[nextZ]
            State.FarmCFrame = State.CampPoints[nextZ]
            State.CurrentActionText = string.format("Teleported to Saved Camp %d! | by pufyftyk", nextZ)
        else
            local forwardCF = hrp.CFrame + (hrp.CFrame.LookVector * 45) + Vector3.new(0, 3.5, 0)
            hrp.CFrame = forwardCF
            State.FarmCFrame = forwardCF
            State.CurrentActionText = string.format("Stepped forward to Camp %d! | by pufyftyk", nextZ)
        end
        StatZoneVal.Text = string.format("Camp %d/6", State.CurrentZone)
    end
end))

trackConn(BtnPrevCamp.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    if hrp then
        local prevZ = math.max(1, State.CurrentZone - 1)
        State.CurrentZone = prevZ
        if State.CampPoints[prevZ] then
            hrp.CFrame = State.CampPoints[prevZ]
            State.FarmCFrame = State.CampPoints[prevZ]
            State.CurrentActionText = string.format("Returned to Camp %d! | by pufyftyk", prevZ)
        end
        StatZoneVal.Text = string.format("Camp %d/6", State.CurrentZone)
    end
end))

local function antiFallCheck()
    pcall(function()
        local hrp = getHRP()
        if hrp and State.FarmCFrame then
            if hrp.Position.Y < -40 or (hrp.Position - State.FarmCFrame.Position).Magnitude > 350 then
                hrp.CFrame = State.FarmCFrame + Vector3.new(0, 3, 0)
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end)
end

task.spawn(function()
    applyPotatoGraphics(Config.PotatoGraphics)
end)

task.spawn(function()
    while State.Running do
        pcall(function()
            local elapsed = os.clock() - State.StartTime
            StatTimeVal.Text = formatDuration(elapsed)
            StatAcornsVal.Text = string.format("%s (+%s)", formatNumber(State.CurrentAcorns), formatNumber(State.AcornsGained))
            StatGemsVal.Text = string.format("%s (+%s)", formatNumber(State.CurrentDiamonds), formatNumber(State.DiamondsGained))
            StatZoneVal.Text = string.format("Camp %d/6", State.CurrentZone)
            StatEggsVal.Text = formatNumber(State.EggsHatched)
            StatPetsVal.Text = string.format("%d / %d", State.HugesHatched, State.TitanicsHatched)
            StatRelicsVal.Text = string.format("%d/6", State.RelicsCollected)
            StatStatusVal.Text = State.CurrentActionText
        end)
        task.wait(0.2)
    end
end)

task.spawn(function()
    while State.Running do
        pcall(updateCurrencies)
        pcall(detectCurrentZone)
        task.wait(0.5)
    end
end)

task.spawn(function()
    while State.Running do
        if Config.AutoFarmBreakables or Config.AutoStages then
            pcall(handleRubbleWallInteraction)
            pcall(farmNearbyBreakables)
            pcall(collectOrbsAndLootbags)
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while State.Running do
        if Config.AutoHatch then
            pcall(hatchNearestEgg)
        end
        task.wait(1.5)
    end
end)

task.spawn(function()
    while State.Running do
        pcall(autoEquipBestPets)
        pcall(buyMerchantBuffs)
        pcall(collectSecretRelics)
        pcall(handleExpeditions)
        if Config.AutoUpgrades then
            pcall(buyZone1Upgrades)
        end
        task.wait(3.0)
    end
end)

task.spawn(function()
    while State.Running do
        pcall(antiFallCheck)
        task.wait(1.0)
    end
end)

local function cleanupAll()
    State.Running = false
    for _, conn in ipairs(ActiveConnections) do
        pcall(function() conn:Disconnect() end)
    end
    ActiveConnections = {}
    if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
    if BlackOverlayFrame then pcall(function() BlackOverlayFrame:Destroy() end) end
end

env.DiamondMountainHubCleanup = cleanupAll
trackConn(CloseScriptBtn.MouseButton1Click:Connect(cleanupAll))
