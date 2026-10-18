local _CREATOR = "by pufyftyk"
local _PROJECT = "PS99 Diamond Mountain - Winter AFK Hub"
local _VERSION = "2.1.0"

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

repeat task.wait() until game:IsLoaded()

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
    AutoHatch = (UserConfig.AutoHatch ~= nil) and (UserConfig.AutoHatch == true) or true,
    AutoEquipBest = (UserConfig.AutoEquipBest ~= nil) and (UserConfig.AutoEquipBest == true) or true,
    AutoBuyMerchants = (UserConfig.AutoBuyMerchants ~= nil) and (UserConfig.AutoBuyMerchants == true) or true,
    AutoUpgrades = (UserConfig.AutoUpgrades ~= nil) and (UserConfig.AutoUpgrades == true) or true,
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
    ZoneEggPositions = {},
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
    CurrentActionText = "Initializing Winter AFK Hub... | by pufyftyk"
}

pcall(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        State.FarmCFrame = hrp.CFrame
    end
end)

local RemoteCache = {}
local NetworkFolder = ReplicatedStorage:FindFirstChild("Network")

local function findRemote(name)
    if RemoteCache[name] then return RemoteCache[name] end
    if NetworkFolder then
        local r = NetworkFolder:FindFirstChild(name)
        if r then
            RemoteCache[name] = r
            return r
        end
    end
    local r2 = ReplicatedStorage:FindFirstChild(name, true)
    if r2 and (r2:IsA("RemoteEvent") or r2:IsA("RemoteFunction") or r2.ClassName == "UnreliableRemoteEvent") then
        RemoteCache[name] = r2
        return r2
    end
    return nil
end

local function fireRemoteSafe(name, ...)
    local r = findRemote(name)
    if not r then return false end
    if r:IsA("RemoteEvent") or r.ClassName == "UnreliableRemoteEvent" then
        pcall(function(...) r:FireServer(...) end, ...)
        return true
    elseif r:IsA("RemoteFunction") then
        local ok, res = pcall(function(...) return r:InvokeServer(...) end, ...)
        return ok, res
    end
    return false
end

local ThingsFolder = nil
local function getThingsFolder()
    if ThingsFolder and ThingsFolder.Parent then return ThingsFolder end
    ThingsFolder = Workspace:FindFirstChild("__THINGS") or Workspace:FindFirstChild("Things")
    return ThingsFolder
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

local function updateCurrencies()
    pcall(function()
        local saveMod = nil
        local clientModules = ReplicatedStorage:FindFirstChild("Library") and ReplicatedStorage.Library:FindFirstChild("Client")
        if clientModules then
            local s = clientModules:FindFirstChild("Save")
            if s and s:IsA("ModuleScript") then
                pcall(function() saveMod = require(s) end)
            end
        end

        if saveMod and saveMod.Get then
            local data = saveMod.Get()
            if data then
                if data.Diamonds then
                    local d = tonumber(data.Diamonds) or 0
                    if not State.StartDiamonds then State.StartDiamonds = d end
                    State.CurrentDiamonds = d
                    State.DiamondsGained = math.max(0, d - State.StartDiamonds)
                end
                if data.Acorns or data.DiamondMountainCoins or data.EventCurrency then
                    local a = tonumber(data.Acorns or data.DiamondMountainCoins or data.EventCurrency) or 0
                    if not State.StartAcorns then State.StartAcorns = a end
                    State.CurrentAcorns = a
                    State.AcornsGained = math.max(0, a - State.StartAcorns)
                end
            end
        end
    end)
end

local function collectOrbsAndLootbags()
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
                if numId then
                    table.insert(orbIds, numId)
                end
                if #orbIds >= 35 then break end
            end
            if #orbIds > 0 then
                fireRemoteSafe("Orbs: Collect", orbIds)
                fireRemoteSafe("Orbs_Collect", orbIds)
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
                fireRemoteSafe("Lootbags_Claim", { bag.Name })
                fireRemoteSafe("Lootbags: Claim", { bag.Name })
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
            if bPos and (bPos - myPos).Magnitude <= 85 then
                local uid = b.Name
                if dmgRemote then
                    if dmgRemote:IsA("RemoteEvent") or dmgRemote.ClassName == "UnreliableRemoteEvent" then
                        dmgRemote:FireServer(uid)
                    else
                        pcall(function() dmgRemote:InvokeServer(uid) end)
                    end
                end
                count = count + 1
                if count >= 6 then break end
            end
        end
    end)
end

local function findNearestEggMachine(maxDist)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end
    local myPos = hrp.Position
    local things = getThingsFolder()
    local limit = maxDist or 100

    local eggCandidates = {}
    local function checkContainer(cont)
        if not cont then return end
        for _, egg in ipairs(cont:GetChildren()) do
            local p = getObjectPosition(egg)
            if p then
                local d = (p - myPos).Magnitude
                if d <= limit then
                    local eggId = egg:GetAttribute("id") or egg:GetAttribute("EggName") or egg:GetAttribute("ID") or egg.Name
                    table.insert(eggCandidates, { obj = egg, pos = p, dist = d, id = eggId })
                end
            end
        end
    end

    if things then
        checkContainer(things:FindFirstChild("CustomEggs"))
        checkContainer(things:FindFirstChild("Eggs"))
        checkContainer(things:FindFirstChild("EggCapsules"))
    end

    table.sort(eggCandidates, function(a, b) return a.dist < b.dist end)
    if #eggCandidates > 0 then
        return eggCandidates[1].obj, eggCandidates[1].id
    end
    return nil, nil
end

local function hatchNearestEgg(batchCount)
    local eggObj, eggId = findNearestEggMachine(90)
    if not eggId then return false end
    local batch = batchCount or Config.HatchBatch or 79
    local remotes = { "CustomEggs_Hatch", "Eggs_RequestPurchase", "Eggs_Roll" }
    for _, rName in ipairs(remotes) do
        local r = findRemote(rName)
        if r then
            pcall(function()
                if r:IsA("RemoteFunction") then
                    r:InvokeServer(eggId, batch)
                else
                    r:FireServer(eggId, batch)
                end
            end)
            State.EggsHatched = State.EggsHatched + batch
            State.LastHatchTime = os.clock()
            return true
        end
    end
    return false
end

local function autoEquipBestPets()
    if not Config.AutoEquipBest then return end
    pcall(function()
        fireRemoteSafe("Pets: EquipBest")
        fireRemoteSafe("EquipBest")
        fireRemoteSafe("Pets_EquipBest")
    end)
end

local function buyZone1Upgrades()
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

local function buyMerchantBuffs()
    if not Config.AutoBuyMerchants then return end
    local now = os.clock()
    if now - State.LastMerchantTime < 10.0 then return end
    State.LastMerchantTime = now

    pcall(function()
        local merchantRemotes = { "Merchant_RequestPurchase", "Merchants: RequestPurchase", "Merchant_Buy" }
        for _, rName in ipairs(merchantRemotes) do
            local r = findRemote(rName)
            if r then
                for slot = 1, 3 do
                    pcall(function()
                        if r:IsA("RemoteFunction") then r:InvokeServer("DiamondMountain", slot)
                        else r:FireServer("DiamondMountain", slot) end
                    end)
                end
            end
        end
    end)
end

local function collectSecretRelics()
    if not Config.AutoCollectRelics then return end
    local now = os.clock()
    if now - State.LastRelicScan < 30.0 then return end
    State.LastRelicScan = now

    pcall(function()
        local relicRemotes = { "Relic_Claim", "Relics: Claim", "Relics_Claim", "SecretRelic_Claim" }
        for _, rName in ipairs(relicRemotes) do
            local r = findRemote(rName)
            if r then
                for id = 1, 6 do
                    pcall(function()
                        if r:IsA("RemoteFunction") then r:InvokeServer(id)
                        else r:FireServer(id) end
                    end)
                end
                State.RelicsCollected = 6
                return
            end
        end
    end)
end

local Colors = {
    Bg = Color3.fromRGB(12, 18, 30),
    Header = Color3.fromRGB(18, 28, 48),
    Card = Color3.fromRGB(18, 26, 44),
    CardBright = Color3.fromRGB(24, 38, 64),
    Stroke = Color3.fromRGB(40, 75, 125),
    IceAccent = Color3.fromRGB(70, 200, 255),
    SnowWhite = Color3.fromRGB(245, 250, 255),
    SubText = Color3.fromRGB(160, 195, 235),
    Green = Color3.fromRGB(46, 204, 113),
    Red = Color3.fromRGB(235, 75, 75),
    Gold = Color3.fromRGB(255, 215, 0),
    InputBg = Color3.fromRGB(10, 14, 24)
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
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
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

local function makeBtn(parent, size, pos, bg, text, textSize, radius)
    local b = Instance.new("TextButton")
    b.Size = size
    if pos then b.Position = pos end
    b.BackgroundColor3 = bg
    b.Text = text or ""
    b.TextColor3 = Colors.SnowWhite
    b.Font = Enum.Font.GothamBold
    b.TextSize = textSize or 12
    b.Parent = parent
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
    l.Font = font or Enum.Font.GothamBold
    l.TextSize = textSize or 12
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local BlackOverlayFrame = Instance.new("Frame")
BlackOverlayFrame.Name = "BlackScreenOverlay"
BlackOverlayFrame.Size = UDim2.new(1, 0, 1, 0)
BlackOverlayFrame.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
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
DashCard.ZIndex = 20
DashCard.Parent = ScreenGui
addCornerAndStroke(DashCard, 10, Colors.Stroke, 1.5)

local DashTopBar = Instance.new("Frame")
DashTopBar.Size = UDim2.new(1, 0, 0, 48)
DashTopBar.BackgroundColor3 = Colors.Header
DashTopBar.BorderSizePixel = 0
DashTopBar.ZIndex = 21
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
local DashSubTitle = makeLabel(DashTopBar, UDim2.new(1, -90, 0, 16), UDim2.new(0, 14, 0, 26), "Winter Event | Zone 1-6 Farm | 100x Egg", Colors.SubText, Enum.Font.Gotham, 11)

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
    box.ZIndex = 21
    box.Parent = parent
    addCornerAndStroke(box, 6, Colors.Stroke, 1)
    makeLabel(box, UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 0, 3), title, Colors.SubText, Enum.Font.Gotham, 10)
    local lblVal = makeLabel(box, UDim2.new(1, -12, 0, heightPx - 18), UDim2.new(0, 6, 0, 17), initVal, valColor or Colors.SnowWhite, Enum.Font.GothamBold, 13)
    return lblVal
end

local StatTimeVal = createStatBox(DashCard, "Time", "00:00:00", 0, 54, 0.333, 44, Colors.SnowWhite)
local StatAcornsVal = createStatBox(DashCard, "Acorns", "0 (+0)", 0.333, 54, 0.333, 44, Colors.Gold)
local StatGemsVal = createStatBox(DashCard, "Diamonds", "0 (+0)", 0.666, 54, 0.334, 44, Colors.IceAccent)

local StatZoneVal = createStatBox(DashCard, "Zone", "Zone 1/6", 0, 104, 0.25, 44, Colors.IceAccent)
local StatEggsVal = createStatBox(DashCard, "Eggs", "0", 0.25, 104, 0.25, 44, Colors.Gold)
local StatPetsVal = createStatBox(DashCard, "Huge/Titan", "0 / 0", 0.50, 104, 0.25, 44, Colors.Green)
local StatRelicsVal = createStatBox(DashCard, "Relics", "0/6", 0.75, 104, 0.25, 44, Colors.SnowWhite)

local StatusBanner = Instance.new("Frame")
StatusBanner.Size = UDim2.new(1, -20, 0, 32)
StatusBanner.Position = UDim2.new(0, 10, 0, 154)
StatusBanner.BackgroundColor3 = Colors.InputBg
StatusBanner.BorderSizePixel = 0
StatusBanner.ZIndex = 21
StatusBanner.Parent = DashCard
addCornerAndStroke(StatusBanner, 6, Colors.Stroke, 1)

local StatStatusVal = makeLabel(StatusBanner, UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0), "Status: Initializing... | by pufyftyk", Colors.SnowWhite, Enum.Font.Gotham, 11)
StatStatusVal.TextWrapped = true

local BtnStages = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0, 10, 0, 192), Config.AutoStages and Colors.Green or Colors.CardBright, "Stages (1-6): " .. (Config.AutoStages and "ON" or "OFF"), 11, 6)
local BtnHatch = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0.5, 4, 0, 192), Config.AutoHatch and Colors.Green or Colors.CardBright, "Auto Hatch: " .. (Config.AutoHatch and "ON" or "OFF"), 11, 6)

local BtnMerchants = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0, 10, 0, 228), Config.AutoBuyMerchants and Colors.Green or Colors.CardBright, "Merchant Buffs: " .. (Config.AutoBuyMerchants and "ON" or "OFF"), 11, 6)
local BtnTunnel6 = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0.5, 4, 0, 228), Config.FocusTunnel6 and Colors.Green or Colors.CardBright, "Focus Tunnel 6: " .. (Config.FocusTunnel6 and "ON" or "OFF"), 11, 6)

local BtnUpgrades = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0, 10, 0, 264), Config.AutoUpgrades and Colors.Green or Colors.CardBright, "Zone Upgrades: " .. (Config.AutoUpgrades and "ON" or "OFF"), 11, 6)
local BtnRelics = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0.5, 4, 0, 264), Config.AutoCollectRelics and Colors.Green or Colors.CardBright, "Collect Relics: " .. (Config.AutoCollectRelics and "ON" or "OFF"), 11, 6)

local BtnPotato = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0, 10, 0, 300), Config.PotatoGraphics and Colors.Green or Colors.CardBright, "Potato FPS: " .. (Config.PotatoGraphics and "ON" or "OFF"), 11, 6)
local BtnBlackScreen = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 32), UDim2.new(0.5, 4, 0, 300), Config.BlackScreen and Colors.Green or Colors.CardBright, "Black Screen: " .. (Config.BlackScreen and "ON" or "OFF"), 11, 6)

local BtnSetFarmPos = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 24), UDim2.new(0, 10, 0, 334), Colors.Header, "[*] Set Farm Anchor Here", 10, 5)
local BtnHatchBatchCycle = makeBtn(DashCard, UDim2.new(0.5, -14, 0, 24), UDim2.new(0.5, 4, 0, 334), Colors.Header, "Hatch Batch: " .. tostring(Config.HatchBatch) .. "x", 10, 5)

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
    BtnStages.Text = "Stages (1-6): " .. (Config.AutoStages and "ON" or "OFF")
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

trackConn(BtnSetFarmPos.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        State.FarmCFrame = hrp.CFrame
        State.CurrentActionText = "Farm Anchor Saved to Current Position! | by pufyftyk"
    end
end))

local BatchSteps = { 1, 8, 20, 50, 79 }
local batchIdx = 5
trackConn(BtnHatchBatchCycle.MouseButton1Click:Connect(function()
    batchIdx = (batchIdx % #BatchSteps) + 1
    Config.HatchBatch = BatchSteps[batchIdx]
    BtnHatchBatchCycle.Text = "Hatch Batch: " .. tostring(Config.HatchBatch) .. "x"
end))

local function antiFallCheck()
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and State.FarmCFrame then
            if hrp.Position.Y < -40 or (hrp.Position - State.FarmCFrame.Position).Magnitude > 350 then
                hrp.CFrame = State.FarmCFrame + Vector3.new(0, 3, 0)
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end)
end

local function runZoneFarmCycle()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if not State.FarmCFrame then
        State.FarmCFrame = hrp.CFrame
    end

    local myPos = hrp.Position
    antiFallCheck()

    if Config.AutoFarmBreakables then
        farmNearbyBreakables()
        collectOrbsAndLootbags()
    end

    if Config.AutoHatch then
        local now = os.clock()
        if now - State.LastHatchTime >= 1.2 and State.CurrentAcorns >= 50 then
            local eggObj, eggId = findNearestEggMachine(90)
            if eggObj and eggId then
                hatchNearestEgg(Config.HatchBatch)
            end
        end
    end

    if Config.FocusTunnel6 and State.CurrentZone >= 6 and State.Tunnel6CF then
        if (myPos - State.Tunnel6CF.Position).Magnitude > 30 then
            hrp.CFrame = State.Tunnel6CF + Vector3.new(0, 3, 0)
        end
        State.CurrentActionText = "In Tunnel 6: Hatching Lucky Huge Egg! | by pufyftyk"
    else
        State.CurrentActionText = string.format("Zone %d: Farming Acorns & Pets Attacking | by pufyftyk", State.CurrentZone)
    end

    buyZone1Upgrades()
    buyMerchantBuffs()
    collectSecretRelics()
end

task.spawn(function()
    applyPotatoGraphics(Config.PotatoGraphics)
    autoEquipBestPets()
    collectSecretRelics()

    while State.Running do
        updateCurrencies()
        runZoneFarmCycle()

        local elapsed = os.clock() - State.StartTime
        StatTimeVal.Text = formatDuration(elapsed)
        StatAcornsVal.Text = string.format("%s (+%s)", formatNumber(State.CurrentAcorns), formatNumber(State.AcornsGained))
        StatGemsVal.Text = string.format("%s (+%s)", formatNumber(State.CurrentDiamonds), formatNumber(State.DiamondsGained))
        StatZoneVal.Text = string.format("Zone %d/6", State.CurrentZone)
        StatEggsVal.Text = formatNumber(State.EggsHatched)
        StatPetsVal.Text = string.format("%d / %d", State.HugesHatched, State.TitanicsHatched)
        StatRelicsVal.Text = string.format("%d/6", State.RelicsCollected)
        StatStatusVal.Text = State.CurrentActionText

        task.wait(0.25)
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
