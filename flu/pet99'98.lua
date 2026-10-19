local _CREATOR = "by pufyftyk"
local _PROJECT = "PS99 Autonomous Winter Yeti & Tunnel Hub"
local _VERSION = "4.1.0"

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

local Points = {
    Chest1 = CFrame.new(-30030.2, 752.5, 30984.2),
    Chest2 = CFrame.new(-29976.0, 752.5, 31014.7),
    Chest3 = CFrame.new(-29938.7, 752.5, 30979.1),
    TunnelEgg = CFrame.new(-29905.1, 752.5, 30932.4),
    FarmEgg = CFrame.new(-30137.7, 752.6, 30916.3),
    Yeti = CFrame.new(-30046.1, 754.9, 31107.3),
    Camp = CFrame.new(-29990.4, 753.5, 31150.8)
}

local AcornsTarget = 2600000000000

local State = {
    Running = true,
    StartTime = os.clock(),
    StartGems = nil,
    CurrentGems = 0,
    GemsGained = 0,
    CurrentAcorns = 0,
    YetiKills = 0,
    YetiCooldownEnd = 0,
    TunnelOpen = false,
    TunnelTimeRemaining = 0,
    NextTunnelCheck = 0,
    NextMerchantRestock = os.clock() + 3600,
    LastFlagTime = 0,
    LastCampDeposit = 0,
    LastMerchantTime = 0,
    LastUltimateTime = 0,
    LastHatchTime = 0,
    CurrentActionText = "Starting pufyftyk Autonomous Engine...",
    CurrentPhase = "INIT",
    ProgressFraction = 0,
    IsOled = false
}

local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(cf, offset)
    local hrp = getHRP()
    if not hrp then return end
    local targetCF = cf
    if offset then
        targetCF = cf * CFrame.new(offset.X, offset.Y, offset.Z)
    end
    pcall(function()
        hrp.CFrame = targetCF
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function formatNumber(num)
    num = tonumber(num) or 0
    if num >= 1000000000000000 then
        return string.format("%.2fQ", num / 1000000000000000)
    elseif num >= 1000000000000 then
        return string.format("%.2fT", num / 1000000000000)
    elseif num >= 1000000000 then
        return string.format("%.2fB", num / 1000000000)
    elseif num >= 1000000 then
        return string.format("%.2fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    end
    return tostring(math.floor(num))
end

local function formatDuration(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d", m, s)
end

local function formatGemsProfit(val)
    local v = tonumber(val) or 0
    if v >= 0 then
        return "+" .. formatNumber(v)
    else
        return "-" .. formatNumber(math.abs(v))
    end
end

local Library = nil
local Network = nil
local ClientModules = {}

pcall(function()
    Library = ReplicatedStorage:WaitForChild("Library", 5)
    if Library then
        local clientFolder = Library:FindFirstChild("Client")
        if clientFolder then
            for _, mod in ipairs(clientFolder:GetChildren()) do
                if mod:IsA("ModuleScript") then
                    pcall(function()
                        ClientModules[mod.Name] = require(mod)
                    end)
                end
            end
        end
    end
end)

pcall(function()
    Network = ReplicatedStorage:WaitForChild("Network", 5)
end)

local function fireNetwork(name, ...)
    if not Network then return nil end
    local remote = Network:FindFirstChild(name)
    if not remote then return nil end
    local res = nil
    if remote:IsA("RemoteEvent") then
        pcall(function(...) remote:FireServer(...) end, ...)
    elseif remote:IsA("RemoteFunction") then
        pcall(function(...) res = remote:InvokeServer(...) end, ...)
    end
    return res
end

local function updateCurrencies()
    pcall(function()
        local saveMod = ClientModules["Save"]
        local currMod = ClientModules["CurrencyCmds"]
        local gems = 0
        local acorns = 0

        if currMod and currMod.Get then
            pcall(function() gems = currMod.Get("Diamonds") or 0 end)
            pcall(function() acorns = currMod.Get("Acorns") or currMod.Get("Winter Acorns") or 0 end)
        end

        if gems == 0 and saveMod and saveMod.Get then
            local data = saveMod.Get()
            if data and data.Inventory and data.Inventory.Currency then
                gems = data.Inventory.Currency.Diamonds or 0
                acorns = data.Inventory.Currency.Acorns or 0
            end
        end

        State.CurrentGems = gems
        State.CurrentAcorns = acorns

        if State.StartGems == nil then
            State.StartGems = gems
        end
        State.GemsGained = gems - State.StartGems
    end)
end

local function getBreakablesFolder()
    local things = Workspace:FindFirstChild("__THINGS")
    if things then
        return things:FindFirstChild("Breakables")
    end
    return nil
end

local function findBreakableNear(cframeTarget, maxRadius)
    local targetPos = cframeTarget.Position
    local bestObj = nil
    local bestDist = maxRadius or 20
    local bestUid = nil

    local bFolder = getBreakablesFolder()
    if bFolder then
        for _, child in ipairs(bFolder:GetChildren()) do
            local p = nil
            if child:IsA("Model") then
                p = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
            elseif child:IsA("BasePart") then
                p = child
            end
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

    return bestObj, bestUid, bestDist
end

local function attackBreakableUID(uid, obj)
    if not uid then return end
    pcall(function()
        fireNetwork("Breakables_JoinPet", uid)
        fireNetwork("Breakables_PlayerDealDamage", uid)
    end)
    if ClientModules["BreakableCmds"] then
        pcall(function()
            ClientModules["BreakableCmds"].Damage(uid)
        end)
    end
end

local function useUltimateAbility()
    local now = os.clock()
    if now - State.LastUltimateTime < 2.0 then return end
    State.LastUltimateTime = now
    pcall(function()
        fireNetwork("Ultimate_Activate")
        fireNetwork("Ultimates_Activate")
    end)
    if ClientModules["UltimateCmds"] then
        pcall(function()
            ClientModules["UltimateCmds"].Activate()
        end)
    end
end

local function hatchNearestEgg(eggCFrame, batchCount)
    local now = os.clock()
    if now - State.LastHatchTime < 1.0 then return end
    State.LastHatchTime = now
    local hrp = getHRP()
    if not hrp then return end
    pcall(function()
        fireNetwork("Eggs_Roll", "Winter Mountain Egg", batchCount or 79)
        fireNetwork("Eggs_Open", "Winter Mountain Egg", batchCount or 79)
    end)
    if ClientModules["EggCmds"] then
        pcall(function()
            ClientModules["EggCmds"].Hatch("Winter Mountain Egg", batchCount or 79)
        end)
    end
end

local function checkTunnelStatus()
    local obj, uid, dist = findBreakableNear(Points.Chest1, 20)
    if obj and dist <= 20 then
        return true
    end
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

local function placeMagnetFlag()
    local now = os.clock()
    if now - State.LastFlagTime < 300 then return end
    State.LastFlagTime = now
    pcall(function()
        fireNetwork("Flags_Place", "Magnet", Points.FarmEgg.Position)
        fireNetwork("Flags: Consume", "Magnet", Points.FarmEgg.Position)
    end)
    if ClientModules["FlagCmds"] then
        pcall(function()
            ClientModules["FlagCmds"].Place("Magnet", Points.FarmEgg.Position)
        end)
    end
end

local function depositCampPets()
    local now = os.clock()
    if now - State.LastCampDeposit < 90 then return end
    State.LastCampDeposit = now
    State.CurrentPhase = "DEPOSIT"
    teleportTo(Points.Camp, Vector3.new(0, 3, 0))
    task.wait(0.4)

    pcall(function()
        local hrp = getHRP()
        if hrp then
            for _, desc in ipairs(Workspace:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and (desc.Position - hrp.Position).Magnitude <= 25 then
                    if fireproximityprompt then
                        fireproximityprompt(desc)
                    end
                end
            end
        end
    end)

    pcall(function()
        fireNetwork("Camp_DepositPets")
        fireNetwork("EventAltar_Deposit")
        fireNetwork("WinterCamp_Deposit")
        fireNetwork("ShinyMachine_Deposit")
    end)
end

local function buyMerchantItems()
    local now = os.clock()
    if now - State.LastMerchantTime < 30 then return end
    State.LastMerchantTime = now
    pcall(function()
        for slot = 1, 6 do
            fireNetwork("TravelingMerchant_Buy", slot)
            fireNetwork("Merchant_Buy", "TravelingMerchant", slot)
            fireNetwork("Merchant_Buy", "MysteryMerchant", slot)
            fireNetwork("Merchant_Buy", "WinterMerchant", slot)
        end
    end)
end

local Colors = {
    Bg = Color3.fromRGB(11, 15, 23),
    InnerCard = Color3.fromRGB(15, 21, 33),
    Header = Color3.fromRGB(14, 19, 30),
    Card = Color3.fromRGB(16, 22, 34),
    CardBright = Color3.fromRGB(22, 30, 48),
    Cyan = Color3.fromRGB(0, 215, 255),
    CyanBright = Color3.fromRGB(90, 235, 255),
    CyanDim = Color3.fromRGB(25, 95, 130),
    Amber = Color3.fromRGB(235, 125, 45),
    AmberBright = Color3.fromRGB(255, 165, 60),
    SnowWhite = Color3.fromRGB(240, 250, 255),
    Frost = Color3.fromRGB(160, 220, 250),
    SubText = Color3.fromRGB(135, 175, 205),
    Green = Color3.fromRGB(46, 213, 115),
    Red = Color3.fromRGB(255, 75, 85),
    Gold = Color3.fromRGB(255, 210, 60),
    InputBg = Color3.fromRGB(7, 10, 16),
    OledBg = Color3.fromRGB(5, 3, 10),
    Purple = Color3.fromRGB(180, 80, 255),
    PurpleBright = Color3.fromRGB(220, 135, 255),
    PurpleDim = Color3.fromRGB(95, 35, 145)
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99AutonomousWinterHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 200
pcall(function() ScreenGui.IgnoreGuiInset = true end)
ScreenGui.Parent = ParentGui

local function addCorner(inst, r)
    local c = Instance.new("UICorner", inst)
    c.CornerRadius = UDim.new(0, r or 6)
    return c
end

local function addStroke(inst, col, th)
    local s = Instance.new("UIStroke", inst)
    s.Color = col or Colors.CyanDim
    s.Thickness = th or 1.2
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
    b.TextColor3 = Colors.SnowWhite
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
    l.TextColor3 = color or Colors.SnowWhite
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
            task.wait(0.35)
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

local DayCard = Instance.new("Frame")
DayCard.Name = "DayCardCyberIce"
DayCard.Size = UDim2.new(0, 380, 0, 295)
DayCard.Position = UDim2.new(0.5, -190, 0.5, -147)
DayCard.BackgroundColor3 = Colors.Bg
DayCard.BorderSizePixel = 0
DayCard.ZIndex = 10
DayCard.Parent = ScreenGui
addCorner(DayCard, 10)
local DayCardStroke = addStroke(DayCard, Colors.Cyan, 1.8)
addGradient(DayCard, Colors.Bg, Colors.InnerCard, 45)

local DaySnowTop = Instance.new("Frame")
DaySnowTop.Size = UDim2.new(1, 8, 0, 6)
DaySnowTop.Position = UDim2.new(0, -4, 0, -4)
DaySnowTop.BackgroundColor3 = Colors.SnowWhite
DaySnowTop.BorderSizePixel = 0
DaySnowTop.ZIndex = 25
DaySnowTop.Parent = DayCard
addCorner(DaySnowTop, 4)
addGradient(DaySnowTop, Color3.fromRGB(255, 255, 255), Colors.Frost, 0)

for i = 1, 7 do
    local icicle = Instance.new("Frame")
    local w = math.random(6, 12)
    local h = math.random(5, 10)
    local xPos = (i - 1) * 52 + math.random(10, 25)
    icicle.Size = UDim2.new(0, w, 0, h)
    icicle.Position = UDim2.new(0, xPos, 0, 4)
    icicle.BackgroundColor3 = Colors.SnowWhite
    icicle.BorderSizePixel = 0
    icicle.ZIndex = 26
    icicle.Parent = DayCard
    addCorner(icicle, 3)
    addGradient(icicle, Colors.SnowWhite, Colors.Frost, 90)
end

local CableHolder = Instance.new("Frame")
CableHolder.Size = UDim2.new(0.8, 0, 0, 10)
CableHolder.Position = UDim2.new(0.1, 0, 1, 0)
CableHolder.BackgroundTransparency = 1
CableHolder.ZIndex = 8
CableHolder.Parent = DayCard

local DayCable1 = Instance.new("Frame")
DayCable1.Size = UDim2.new(0.5, 0, 0, 4)
DayCable1.Position = UDim2.new(0.05, 0, 0, 2)
DayCable1.BackgroundColor3 = Colors.Amber
DayCable1.BorderSizePixel = 0
DayCable1.ZIndex = 8
DayCable1.Parent = CableHolder
addCorner(DayCable1, 2)
addGradient(DayCable1, Colors.Amber, Colors.AmberBright, 0)

local DayCable2 = Instance.new("Frame")
DayCable2.Size = UDim2.new(0.5, 0, 0, 4)
DayCable2.Position = UDim2.new(0.45, 0, 0, 4)
DayCable2.BackgroundColor3 = Colors.AmberBright
DayCable2.BorderSizePixel = 0
DayCable2.ZIndex = 8
DayCable2.Parent = CableHolder
addCorner(DayCable2, 2)
addGradient(DayCable2, Colors.AmberBright, Colors.Amber, 0)

local DayTopHeader = Instance.new("Frame")
DayTopHeader.Size = UDim2.new(1, 0, 0, 46)
DayTopHeader.BackgroundColor3 = Colors.Header
DayTopHeader.BorderSizePixel = 0
DayTopHeader.ZIndex = 11
DayTopHeader.Active = true
DayTopHeader.Parent = DayCard
addCorner(DayTopHeader, 10)
addGradient(DayTopHeader, Color3.fromRGB(20, 28, 44), Colors.Header, 90)

local isDragging = false
do
    local dragStart, startPos = nil, nil
    DayTopHeader.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = DayCard.Position
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if dragStart and startPos then
                local delta = input.Position - dragStart
                DayCard.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
end

makeLabel(DayTopHeader, UDim2.new(0, 100, 0, 24), UDim2.new(0, 12, 0, 3), "pufyftyk", Colors.CyanBright, Enum.Font.GothamBold, 16)
local SysStatusBadge = Instance.new("Frame")
SysStatusBadge.Size = UDim2.new(0, 140, 0, 16)
SysStatusBadge.Position = UDim2.new(0, 12, 0, 26)
SysStatusBadge.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
SysStatusBadge.BorderSizePixel = 0
SysStatusBadge.ZIndex = 12
SysStatusBadge.Parent = DayTopHeader
addCorner(SysStatusBadge, 3)
addStroke(SysStatusBadge, Colors.Amber, 1)

makeLabel(SysStatusBadge, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "SYSTEM STATUS: OK // WINTER", Colors.AmberBright, Enum.Font.GothamBold, 8, Enum.TextXAlignment.Center, 13)

local BtnOledSwitch = makeBtn(DayTopHeader, UDim2.new(0, 50, 0, 24), UDim2.new(1, -114, 0, 11), Colors.PurpleDim, "OLED", 10, 5)
local BtnDayMin = makeBtn(DayTopHeader, UDim2.new(0, 24, 0, 24), UDim2.new(1, -58, 0, 11), Colors.CardBright, "-", 13, 5)
local BtnDayClose = makeBtn(DayTopHeader, UDim2.new(0, 24, 0, 24), UDim2.new(1, -30, 0, 11), Colors.Red, "X", 11, 5)

local MiniBadge = makeBtn(ScreenGui, UDim2.new(0, 145, 0, 36), UDim2.new(0, 10, 0, 10), Colors.Header, "[*] pufyftyk Hub", 11, 8)
MiniBadge.TextColor3 = Colors.CyanBright
MiniBadge.Visible = false
addStroke(MiniBadge, Colors.Cyan, 1.5)

bindSafeClick(BtnDayMin, function()
    DayCard.Visible = false
    MiniBadge.Visible = true
end)

bindSafeClick(MiniBadge, function()
    DayCard.Visible = true
    MiniBadge.Visible = false
end)

local function createDayStatBox(parent, iconTxt, title, initVal, posX, posY, w, h, col, strokeCol)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, w, 0, h)
    box.Position = UDim2.new(0, posX, 0, posY)
    box.BackgroundColor3 = Colors.Card
    box.BorderSizePixel = 0
    box.ZIndex = 12
    box.Parent = parent
    addCorner(box, 6)
    addStroke(box, strokeCol or Colors.CyanDim, 1.2)

    makeLabel(box, UDim2.new(1, -6, 0, 12), UDim2.new(0, 6, 0, 2), string.format("%s %s", iconTxt, title), Colors.SubText, Enum.Font.Gotham, 8)
    local lbl = makeLabel(box, UDim2.new(1, -6, 0, h - 14), UDim2.new(0, 6, 0, 13), initVal, col or Colors.SnowWhite, Enum.Font.GothamBold, 10)
    return lbl
end

local DayLblYeti = createDayStatBox(DayCard, "[+]", "YETI KILLS", "0", 8, 52, 86, 34, Colors.SnowWhite)
local DayLblTunnel = createDayStatBox(DayCard, "[O]", "TUNNEL", "CHECKING", 98, 52, 90, 34, Colors.CyanBright)
local DayLblYetiState = createDayStatBox(DayCard, "[*]", "YETI", "READY", 192, 52, 90, 34, Colors.AmberBright, Colors.Amber)
local DayLblAcorns = createDayStatBox(DayCard, "[$]", "ACORNS", "0 / 2.6T", 286, 52, 86, 34, Colors.Gold)

local DayLblGems = createDayStatBox(DayCard, "[#]", "GEMS GAINED", "+0", 8, 90, 180, 32, Colors.CyanBright)
local DayLblMerchant = createDayStatBox(DayCard, "[@]", "MERCHANT RESTOCK", "00:00", 192, 90, 180, 32, Colors.SnowWhite)

local ActionFrame = Instance.new("Frame")
ActionFrame.Size = UDim2.new(1, -16, 0, 58)
ActionFrame.Position = UDim2.new(0, 8, 0, 128)
ActionFrame.BackgroundColor3 = Colors.InputBg
ActionFrame.BorderSizePixel = 0
ActionFrame.ZIndex = 12
ActionFrame.Parent = DayCard
addCorner(ActionFrame, 6)
addStroke(ActionFrame, Colors.CyanDim, 1)

makeLabel(ActionFrame, UDim2.new(1, -12, 0, 14), UDim2.new(0, 8, 0, 4), "CURRENT ACTION:", Colors.SubText, Enum.Font.Gotham, 8)
local DayLblAction = makeLabel(ActionFrame, UDim2.new(1, -12, 0, 18), UDim2.new(0, 8, 0, 16), "INITIALIZING ENGINE...", Colors.SnowWhite, Enum.Font.GothamBold, 11)

local SegMeterFrame = Instance.new("Frame")
SegMeterFrame.Size = UDim2.new(1, -16, 0, 12)
SegMeterFrame.Position = UDim2.new(0, 8, 0, 38)
SegMeterFrame.BackgroundColor3 = Colors.Card
SegMeterFrame.BorderSizePixel = 0
SegMeterFrame.ZIndex = 13
SegMeterFrame.Parent = ActionFrame
addCorner(SegMeterFrame, 3)

local SegBlocks = {}
local TotalSegments = 20
for s = 1, TotalSegments do
    local b = Instance.new("Frame")
    b.Size = UDim2.new(1 / TotalSegments, -2, 1, 0)
    b.Position = UDim2.new((s - 1) / TotalSegments, 1, 0, 0)
    b.BackgroundColor3 = Colors.CyanDim
    b.BorderSizePixel = 0
    b.ZIndex = 14
    b.Parent = SegMeterFrame
    addCorner(b, 2)
    table.insert(SegBlocks, b)
end

local function setMeterPercent(pct)
    pct = math.clamp(pct or 0, 0, 1)
    local activeCount = math.floor(pct * TotalSegments)
    for idx, blk in ipairs(SegBlocks) do
        if idx <= activeCount then
            blk.BackgroundColor3 = Colors.CyanBright
        else
            blk.BackgroundColor3 = Colors.CardBright
        end
    end
end

local BadgesRow = Instance.new("Frame")
BadgesRow.Size = UDim2.new(1, -16, 0, 32)
BadgesRow.Position = UDim2.new(0, 8, 0, 192)
BadgesRow.BackgroundTransparency = 1
BadgesRow.ZIndex = 12
BadgesRow.Parent = DayCard

local PillList = {
    { Name = "TUNNEL", Label = "[AUTO TUNNEL]", Col = Colors.Cyan },
    { Name = "YETI", Label = "[FARM YETI]", Col = Colors.AmberBright },
    { Name = "DEPOSIT", Label = "[DEPOSIT PETS]", Col = Colors.PurpleBright },
    { Name = "FLAG", Label = "[MAGNET FLAG]", Col = Colors.Green },
    { Name = "OLED", Label = "[OLED SLEEP]", Col = Colors.Purple }
}

local PillFrames = {}
for i, item in ipairs(PillList) do
    local pill = makeBtn(BadgesRow, UDim2.new(0.2, -4, 1, 0), UDim2.new(0.2 * (i - 1), 2, 0, 0), Colors.Card, item.Label, 8, 5)
    pill.TextColor3 = Colors.SubText
    PillFrames[item.Name] = pill

    if item.Name == "OLED" then
        bindSafeClick(pill, function()
            State.IsOled = true
        end)
    end
end

local function updateActivePills()
    for name, pBtn in pairs(PillFrames) do
        local isAct = false
        if name == "TUNNEL" and State.CurrentPhase == "TUNNEL" then isAct = true end
        if name == "YETI" and State.CurrentPhase == "YETI" then isAct = true end
        if name == "DEPOSIT" and State.CurrentPhase == "DEPOSIT" then isAct = true end
        if name == "FLAG" and State.CurrentPhase == "FLAG" then isAct = true end

        if isAct then
            pBtn.BackgroundColor3 = Colors.CardBright
            pBtn.TextColor3 = Colors.CyanBright
            local s = pBtn:FindFirstChildOfClass("UIStroke")
            if s then s.Color = Colors.CyanBright s.Thickness = 1.4 end
        else
            pBtn.BackgroundColor3 = Colors.Card
            pBtn.TextColor3 = Colors.SubText
            local s = pBtn:FindFirstChildOfClass("UIStroke")
            if s then s.Color = Colors.CyanDim s.Thickness = 1 end
        end
    end
end

local DayBottomBar = Instance.new("Frame")
DayBottomBar.Size = UDim2.new(1, -16, 0, 48)
DayBottomBar.Position = UDim2.new(0, 8, 0, 230)
DayBottomBar.BackgroundTransparency = 1
DayBottomBar.ZIndex = 12
DayBottomBar.Parent = DayCard

local DayStatusPill = Instance.new("Frame")
DayStatusPill.Size = UDim2.new(1, 0, 0, 26)
DayStatusPill.Position = UDim2.new(0, 0, 0, 8)
DayStatusPill.BackgroundColor3 = Colors.CardBright
DayStatusPill.BorderSizePixel = 0
DayStatusPill.ZIndex = 13
DayStatusPill.Parent = DayBottomBar
addCorner(DayStatusPill, 5)
addStroke(DayStatusPill, Colors.Cyan, 1)

local DayPulseDot = Instance.new("Frame")
DayPulseDot.Size = UDim2.new(0, 8, 0, 8)
DayPulseDot.Position = UDim2.new(0, 8, 0.5, -4)
DayPulseDot.BackgroundColor3 = Colors.CyanBright
DayPulseDot.BorderSizePixel = 0
DayPulseDot.ZIndex = 14
DayPulseDot.Parent = DayStatusPill
addCorner(DayPulseDot, 4)

makeLabel(DayStatusPill, UDim2.new(1, -24, 1, 0), UDim2.new(0, 22, 0, 0), "AUTONOMOUS AUTOPILOT ACTIVE // by pufyftyk", Colors.CyanBright, Enum.Font.GothamBold, 9)

local OledOverlay = Instance.new("Frame")
OledOverlay.Name = "OledScreenOverlay"
OledOverlay.Size = UDim2.new(1, 0, 1, 0)
OledOverlay.Position = UDim2.new(0, 0, 0, 0)
OledOverlay.BackgroundColor3 = Colors.OledBg
OledOverlay.BorderSizePixel = 0
OledOverlay.Visible = false
OledOverlay.ZIndex = 60
OledOverlay.Parent = ScreenGui

local OledCard = Instance.new("Frame")
OledCard.Name = "OledCenterCard"
OledCard.Size = UDim2.new(0, 360, 0, 280)
OledCard.Position = UDim2.new(0.5, -180, 0.5, -140)
OledCard.BackgroundColor3 = Color3.fromRGB(10, 6, 18)
OledCard.BorderSizePixel = 0
OledCard.ZIndex = 61
OledCard.Parent = OledOverlay
addCorner(OledCard, 10)
local OledStroke = addStroke(OledCard, Colors.Purple, 1.8)

local OledSnowTop = Instance.new("Frame")
OledSnowTop.Size = UDim2.new(1, 6, 0, 5)
OledSnowTop.Position = UDim2.new(0, -3, 0, -3)
OledSnowTop.BackgroundColor3 = Colors.SnowWhite
OledSnowTop.BorderSizePixel = 0
OledSnowTop.ZIndex = 65
OledSnowTop.Parent = OledCard
addCorner(OledSnowTop, 4)
addGradient(OledSnowTop, Color3.fromRGB(255, 255, 255), Colors.Frost, 0)

for j = 1, 6 do
    local oicicle = Instance.new("Frame")
    local w = math.random(5, 10)
    local h = math.random(4, 8)
    local xPos = (j - 1) * 58 + math.random(10, 20)
    oicicle.Size = UDim2.new(0, w, 0, h)
    oicicle.Position = UDim2.new(0, xPos, 0, 3)
    oicicle.BackgroundColor3 = Colors.SnowWhite
    oicicle.BorderSizePixel = 0
    oicicle.ZIndex = 66
    oicicle.Parent = OledCard
    addCorner(oicicle, 2)
end

local OledCable = Instance.new("Frame")
OledCable.Size = UDim2.new(0.6, 0, 0, 4)
OledCable.Position = UDim2.new(0.2, 0, 1, 0)
OledCable.BackgroundColor3 = Colors.PurpleBright
OledCable.BorderSizePixel = 0
OledCable.ZIndex = 62
OledCable.Parent = OledCard
addCorner(OledCable, 2)
addGradient(OledCable, Colors.PurpleBright, Colors.PurpleDim, 0)

makeLabel(OledCard, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 8), "<< by pufyftyk >>", Colors.PurpleBright, Enum.Font.GothamBold, 18, Enum.TextXAlignment.Center, 63)
makeLabel(OledCard, UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 32), "(retrained text) // OLED STATS MONITOR", Colors.SubText, Enum.Font.Gotham, 9, Enum.TextXAlignment.Center, 63)

local function createOledStatRow(parent, labelText, valText, posY, valColor)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -24, 0, 24)
    row.Position = UDim2.new(0, 12, 0, posY)
    row.BackgroundColor3 = Color3.fromRGB(16, 10, 28)
    row.BorderSizePixel = 0
    row.ZIndex = 63
    row.Parent = parent
    addCorner(row, 4)
    addStroke(row, Colors.PurpleDim, 1)

    makeLabel(row, UDim2.new(0.5, -4, 1, 0), UDim2.new(0, 8, 0, 0), labelText, Colors.SubText, Enum.Font.Gotham, 10, Enum.TextXAlignment.Left, 64)
    local vLbl = makeLabel(row, UDim2.new(0.5, -8, 1, 0), UDim2.new(0.5, 0, 0, 0), valText, valColor or Colors.PurpleBright, Enum.Font.GothamBold, 10, Enum.TextXAlignment.Right, 64)
    return vLbl
end

local OledLblGems = createOledStatRow(OledCard, "GEMS GAINED:", "+0", 54, Colors.PurpleBright)
local OledLblYeti = createOledStatRow(OledCard, "YETI KILLS:", "0", 82, Colors.SnowWhite)
local OledLblAcorns = createOledStatRow(OledCard, "ACORNS:", "0 / 2.60T", 110, Colors.Gold)
local OledLblTunnel = createOledStatRow(OledCard, "TUNNEL STATUS:", "CHECKING", 138, Colors.CyanBright)
local OledLblMerchant = createOledStatRow(OledCard, "MERCHANT RESTOCK:", "00:00", 168, Colors.SnowWhite)
local OledLblAction = createOledStatRow(OledCard, "CURRENT ACTION:", "Starting...", 196, Colors.Green)

local BtnWakeScreen = makeBtn(OledCard, UDim2.new(0, 160, 0, 32), UDim2.new(0.5, -80, 0, 234), Colors.PurpleDim, "[+] WAKE SCREEN", 11, 6, 64)
BtnWakeScreen.TextColor3 = Colors.PurpleBright
addStroke(BtnWakeScreen, Colors.Purple, 1.2)

local function setOledMode(enable)
    State.IsOled = enable
    OledOverlay.Visible = enable
    DayCard.Visible = not enable
    pcall(function()
        if enable then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 0
            RunService:Set3dRenderingEnabled(false)
        else
            Lighting.GlobalShadows = true
            Lighting.Brightness = 1
            RunService:Set3dRenderingEnabled(true)
        end
    end)
end

bindSafeClick(BtnOledSwitch, function()
    setOledMode(true)
end)

bindSafeClick(BtnWakeScreen, function()
    setOledMode(false)
end)

bindSafeClick(OledOverlay, function()
    setOledMode(false)
end)

bindSafeClick(BtnDayClose, function()
    pcall(env.DiamondMountainHubCleanup)
end)

task.spawn(function()
    local pulseCount = 0
    while State.Running and ScreenGui.Parent do
        pulseCount = pulseCount + 1
        local glowCycle = math.abs(math.sin(pulseCount * 0.2))

        if DayCard.Visible then
            DayCardStroke.Color = Color3.fromRGB(math.floor(0 + glowCycle * 60), math.floor(180 + glowCycle * 60), 255)
            DayCable1.BackgroundColor3 = Color3.fromRGB(math.floor(220 + glowCycle * 35), math.floor(110 + glowCycle * 40), 30)
            DayCable2.BackgroundColor3 = Color3.fromRGB(math.floor(255 - glowCycle * 30), math.floor(140 + glowCycle * 40), 50)
            DayPulseDot.BackgroundTransparency = (pulseCount % 2 == 0) and 0.1 or 0.7
        end

        if OledOverlay.Visible then
            OledStroke.Color = Color3.fromRGB(math.floor(160 + glowCycle * 55), math.floor(60 + glowCycle * 50), 255)
            OledCable.BackgroundColor3 = Color3.fromRGB(math.floor(180 + glowCycle * 60), math.floor(80 + glowCycle * 40), 255)
        end

        task.wait(0.2)
    end
end)

task.spawn(function()
    while State.Running do
        pcall(function()
            updateCurrencies()

            local gemsText = formatGemsProfit(State.GemsGained)
            local acornsText = string.format("%s / 2.6T", formatNumber(State.CurrentAcorns))
            local yetiKillsText = tostring(State.YetiKills)

            local now = os.clock()
            local merchantRemaining = math.max(0, math.floor(State.NextMerchantRestock - now))
            if merchantRemaining == 0 then
                State.NextMerchantRestock = now + 3600
                merchantRemaining = 3600
            end
            local merchantText = formatDuration(merchantRemaining)

            local tunnelText = ""
            if State.TunnelOpen then
                tunnelText = string.format("OPEN (%s)", formatDuration(State.TunnelTimeRemaining))
            else
                tunnelText = "STANDBY"
            end

            local yetiStatusText = "READY"
            if now < State.YetiCooldownEnd then
                local cdLeft = math.floor(State.YetiCooldownEnd - now)
                yetiStatusText = string.format("CD (%s)", formatDuration(cdLeft))
            end

            DayLblYeti.Text = yetiKillsText
            DayLblTunnel.Text = tunnelText
            DayLblYetiState.Text = yetiStatusText
            DayLblAcorns.Text = acornsText
            DayLblGems.Text = gemsText
            DayLblMerchant.Text = merchantText
            DayLblAction.Text = State.CurrentActionText

            setMeterPercent(State.ProgressFraction)
            updateActivePills()

            OledLblGems.Text = gemsText
            OledLblYeti.Text = yetiKillsText
            OledLblAcorns.Text = acornsText
            OledLblTunnel.Text = tunnelText
            OledLblMerchant.Text = merchantText
            OledLblAction.Text = State.CurrentActionText

            if State.IsOled ~= OledOverlay.Visible then
                setOledMode(State.IsOled)
            end
        end)
        task.wait(0.25)
    end
end)

local function breakChestAtPoint(cframePt, chestIndex)
    State.CurrentPhase = "TUNNEL"
    State.CurrentActionText = string.format("Tunnel: Smashing Chest #%d...", chestIndex)
    teleportTo(cframePt, Vector3.new(0, 3, 0))

    local startTime = os.clock()
    while State.Running do
        if os.clock() - startTime > 25 then break end
        local obj, uid, dist = findBreakableNear(cframePt, 18)
        if not obj or dist > 18 then
            break
        end
        teleportTo(cframePt, Vector3.new(0, 2, 0))
        attackBreakableUID(uid, obj)
        useUltimateAbility()
        task.wait(0.12)
    end
end

local function runTunnelSequence()
    State.TunnelOpen = true
    State.CurrentPhase = "TUNNEL"
    local tunnelStart = os.clock()
    local tunnelDuration = 300

    breakChestAtPoint(Points.Chest1, 1)
    if not State.Running then return end
    breakChestAtPoint(Points.Chest2, 2)
    if not State.Running then return end
    breakChestAtPoint(Points.Chest3, 3)
    if not State.Running then return end

    updateCurrencies()
    if State.CurrentAcorns >= AcornsTarget then
        State.CurrentActionText = "Tunnel Egg: 300x Luck Egg Hatching..."
        teleportTo(Points.TunnelEgg, Vector3.new(0, 2, 0))

        while State.Running do
            local elapsed = os.clock() - tunnelStart
            local remaining = tunnelDuration - elapsed
            State.TunnelTimeRemaining = remaining
            State.ProgressFraction = math.clamp(remaining / tunnelDuration, 0, 1)

            if remaining <= 10 then break end

            teleportTo(Points.TunnelEgg, Vector3.new(0, 2, 0))
            hatchNearestEgg(Points.TunnelEgg, 79)
            useUltimateAbility()
            task.wait(1.0)
        end
    else
        State.CurrentActionText = "Tunnel Egg Skipped (< 2.6T Acorns). Teleporting to Farm..."
        task.wait(1.0)
    end

    teleportTo(Points.FarmEgg, Vector3.new(0, 3, 0))
    State.TunnelOpen = false
end

local function runYetiSequence()
    State.CurrentPhase = "YETI"
    State.CurrentActionText = "Yeti: Engaging Boss Wall..."
    teleportTo(Points.Yeti, Vector3.new(0, 2, 0))

    local obj, uid, dist = findBreakableNear(Points.Yeti, 22)
    if not obj then
        State.YetiCooldownEnd = os.clock() + 300
        return
    end

    local engageStart = os.clock()
    while State.Running do
        local currObj, currUid, currDist = findBreakableNear(Points.Yeti, 22)
        if not currObj or currDist > 22 then
            State.YetiKills = State.YetiKills + 1
            State.YetiCooldownEnd = os.clock() + 300
            State.CurrentActionText = string.format("Yeti Defeated! (Total: %d). Starting Cooldown...", State.YetiKills)
            task.wait(0.5)
            break
        end

        teleportTo(Points.Yeti, Vector3.new(0, 2, 0))
        attackBreakableUID(currUid, currObj)
        useUltimateAbility()

        local elapsed = os.clock() - engageStart
        State.ProgressFraction = math.abs(math.sin(elapsed * 2))
        task.wait(0.12)
    end

    depositCampPets()
end

local function runFreeTimeSequence()
    local now = os.clock()

    if now - State.LastCampDeposit > 180 then
        depositCampPets()
    end

    State.CurrentPhase = "FLAG"
    State.CurrentActionText = "Farm Zone: Farming Acorns & Base Eggs..."
    teleportTo(Points.FarmEgg, Vector3.new(0, 2, 0))

    placeMagnetFlag()

    local bObj, bUid, bDist = findBreakableNear(Points.FarmEgg, 30)
    if bObj and bUid then
        attackBreakableUID(bUid, bObj)
    end

    hatchNearestEgg(Points.FarmEgg, 79)
    useUltimateAbility()
    buyMerchantItems()

    local targetProgress = math.clamp(State.CurrentAcorns / AcornsTarget, 0, 1)
    State.ProgressFraction = targetProgress
end

task.spawn(function()
    while State.Running do
        pcall(function()
            local isTunnelOpen = checkTunnelStatus()

            if isTunnelOpen then
                runTunnelSequence()
            else
                local now = os.clock()
                if now >= State.YetiCooldownEnd then
                    local yObj = findBreakableNear(Points.Yeti, 22)
                    if yObj then
                        runYetiSequence()
                    else
                        runFreeTimeSequence()
                    end
                else
                    runFreeTimeSequence()
                end
            end
        end)
        task.wait(0.5)
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
