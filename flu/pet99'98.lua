local _CREATOR = "by pufyftyk"
local _PROJECT = "PS99 Autonomous Winter Yeti & Tunnel Hub Masterpiece"
local _VERSION = "6.0.0"

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
    LastFlagTime = 0,
    LastCampDeposit = 0,
    LastMerchantTime = 0,
    LastUltimateTime = 0,
    LastHatchTime = 0,
    CurrentActionText = "ENGINE READY: STANDING BY...",
    CurrentPhase = "INIT",
    ProgressFraction = 0,
    IsOled = false,
    RecentLogs = {
        "System initialized.",
        "Awaiting target scan...",
        "Autonomous loop engaged."
    }
}

local function pushLog(msg)
    local tStr = os.date("%H:%M:%S")
    local entry = string.format("[%s] %s", tStr, msg)
    table.insert(State.RecentLogs, entry)
    if #State.RecentLogs > 3 then
        table.remove(State.RecentLogs, 1)
    end
end

local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function teleportSafely(cf, offset)
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

local function parseFormattedNumber(str)
    if type(str) == "number" then return str end
    if type(str) ~= "string" then return 0 end
    local clean = string.gsub(str, ",", "")
    local num, suffix = string.match(clean, "^([%d%.]+)%s*([kmbKMBtTqQ]?)$")
    if not num then return 0 end
    local val = tonumber(num) or 0
    local suf = string.lower(suffix or "")
    if suf == "k" then return val * 1e3
    elseif suf == "m" then return val * 1e6
    elseif suf == "b" then return val * 1e9
    elseif suf == "t" then return val * 1e12
    elseif suf == "q" then return val * 1e15
    end
    return val
end

local function formatDuration(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
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
    if not remote then
        for _, desc in ipairs(Network:GetDescendants()) do
            if desc.Name == name then
                remote = desc
                break
            end
        end
    end
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
            pcall(function() acorns = currMod.Get("Acorns") or currMod.Get("Winter Acorns") or currMod.Get("Acorn") or 0 end)
        end

        if saveMod and saveMod.Get then
            local data = saveMod.Get()
            if data then
                if type(data.Diamonds) == "number" and data.Diamonds > 0 then
                    gems = data.Diamonds
                end
                if type(data.Inventory) == "table" and type(data.Inventory.Currency) == "table" then
                    for curKey, curVal in pairs(data.Inventory.Currency) do
                        local kLow = string.lower(tostring(curKey))
                        local valAmt = 0
                        if type(curVal) == "number" then
                            valAmt = curVal
                        elseif type(curVal) == "table" then
                            valAmt = tonumber(curVal._am) or tonumber(curVal.amount) or tonumber(curVal.Value) or 0
                        end
                        if string.find(kLow, "acorn") or string.find(kLow, "winter") or string.find(kLow, "event") or string.find(kLow, "mountain") then
                            if valAmt > acorns then acorns = valAmt end
                        elseif string.find(kLow, "diamond") then
                            if valAmt > gems then gems = valAmt end
                        end
                    end
                end
            end
        end

        if gems == 0 then
            local ls = LocalPlayer:FindFirstChild("leaderstats")
            if ls then
                local d = ls:FindFirstChild("Diamonds")
                if d and tonumber(d.Value) then
                    gems = tonumber(d.Value)
                end
            end
        end

        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, desc in ipairs(pg:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible and desc.Text and desc.Text ~= "" then
                    local p = desc.Position
                    if p.X.Scale <= 0.25 then
                        local parsed = parseFormattedNumber(desc.Text)
                        if parsed > 0 then
                            local parentName = string.lower(desc.Parent and desc.Parent.Name or "")
                            local selfName = string.lower(desc.Name)
                            if string.find(parentName, "acorn") or string.find(selfName, "acorn") then
                                if parsed > acorns then acorns = parsed end
                            elseif string.find(parentName, "diamond") or string.find(selfName, "diamond") then
                                if parsed > gems then gems = parsed end
                            else
                                if parsed > 1e10 and parsed > acorns then
                                    acorns = parsed
                                elseif parsed > 1e6 and parsed < 1e10 and gems == 0 then
                                    gems = parsed
                                end
                            end
                        end
                    end
                end
            end
        end

        State.CurrentGems = gems
        State.CurrentAcorns = acorns

        if gems > 0 and State.StartGems == nil then
            State.StartGems = gems
        end
        if State.StartGems then
            State.GemsGained = math.max(0, gems - State.StartGems)
        else
            State.GemsGained = 0
        end

        if acorns > 0 and State.StartAcorns == nil then
            State.StartAcorns = acorns
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

local function findBreakableNear(cframeTarget, maxRadius)
    local targetPos = cframeTarget.Position
    local bestObj = nil
    local bestDist = maxRadius or 35
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
        fireNetwork("Breakables_Tap", uid)
        fireNetwork("Breakables_Click", uid)
        fireNetwork("Breakables_Damage", uid)
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
    local c1 = findBreakableNear(Points.Chest1, 35)
    if c1 then return true end
    local c2 = findBreakableNear(Points.Chest2, 35)
    if c2 then return true end
    local c3 = findBreakableNear(Points.Chest3, 35)
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
    local bestPole = nil
    local bestD = maxDist or 80
    pcall(function()
        local things = Workspace:FindFirstChild("__THINGS")
        if things then
            local poles = things:FindFirstChild("FlagPoles") or things:FindFirstChild("Flags")
            if poles then
                for _, p in ipairs(poles:GetChildren()) do
                    local pPart = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart") or p
                    if pPart and pPart.Position then
                        local d = (pPart.Position - pos).Magnitude
                        if d <= bestD then
                            bestD = d
                            bestPole = p
                        end
                    end
                end
            end
        end
        if not bestPole then
            for _, desc in ipairs(Workspace:GetDescendants()) do
                if string.find(string.lower(desc.Name), "flagpole") then
                    local pPart = desc:IsA("BasePart") and desc or desc:FindFirstChildWhichIsA("BasePart")
                    if pPart then
                        local d = (pPart.Position - pos).Magnitude
                        if d <= bestD then
                            bestD = d
                            bestPole = desc
                        end
                    end
                end
            end
        end
    end)
    return bestPole
end

local function placeMagnetFlag()
    local now = os.clock()
    if now - State.LastFlagTime < 300 then return end
    State.LastFlagTime = now

    local pole = findNearestFlagPole(Points.FarmEgg.Position, 80)
    pcall(function()
        if pole then
            fireNetwork("Flags_Place", "Magnet", pole)
            fireNetwork("Flags: Consume", "Magnet", pole)
        end
        fireNetwork("Flags_Place", "Magnet", Points.FarmEgg.Position)
        fireNetwork("Flags: Consume", "Magnet", Points.FarmEgg.Position)
        fireNetwork("Flags_Place", "Magnet", "Diamond Mountain")
    end)
    if ClientModules["FlagCmds"] then
        pcall(function()
            ClientModules["FlagCmds"].Place("Magnet", Points.FarmEgg.Position)
        end)
    end
    pushLog("Placed Magnet Flag at Farm Zone.")
end

local function executeCampPetDepositFlow()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local targetGui = nil
    for _, g in ipairs(pg:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled then
            local gLow = string.lower(g.Name)
            if string.find(gLow, "altar") or string.find(gLow, "camp") or string.find(gLow, "machine") or string.find(gLow, "deposit") or string.find(gLow, "shiny") or string.find(gLow, "yeti") or string.find(gLow, "upgrade") then
                targetGui = g
                break
            end
        end
    end

    if not targetGui then return end

    local function clickMatchingBtn(keywordList)
        for _, desc in ipairs(targetGui:GetDescendants()) do
            if desc:IsA("GuiButton") and desc.Visible then
                local t = string.lower(desc.Text or "")
                local n = string.lower(desc.Name or "")
                for _, kw in ipairs(keywordList) do
                    if string.find(t, kw) or string.find(n, kw) then
                        if firesignal then
                            firesignal(desc.Activated)
                        elseif desc.MouseButton1Click then
                            desc.MouseButton1Click:Fire()
                        end
                        return true
                    end
                end
            end
        end
        return false
    end

    clickMatchingBtn({"auto", "select all", "all", "max", "fill"})
    task.wait(0.35)

    clickMatchingBtn({"confirm", "deposit", "submit", "upgrade", "yes", "give"})
    task.wait(0.4)

    for _, topG in ipairs(pg:GetChildren()) do
        if topG:IsA("ScreenGui") and topG.Enabled then
            for _, desc in ipairs(topG:GetDescendants()) do
                if desc:IsA("GuiButton") and desc.Visible then
                    local t = string.lower(desc.Text or "")
                    local n = string.lower(desc.Name or "")
                    if t == "yes" or t == "confirm" or t == "sure" or t == "ok" or n == "yes" or n == "confirm" then
                        if firesignal then firesignal(desc.Activated) end
                    end
                end
            end
        end
    end
    task.wait(0.5)

    clickMatchingBtn({"close", "exit", "x", "back"})
    pushLog("Camp deposit confirmed (Auto-Add -> Confirm -> OK).")
end

local function depositCampPets()
    local now = os.clock()
    if now - State.LastCampDeposit < 90 then return end
    State.LastCampDeposit = now
    State.CurrentPhase = "DEPOSIT"
    State.CurrentActionText = "CAMP: DEPOSITING PETS FOR RAINBOW SHINY..."
    pushLog("Entering Camp to charge Rainbow Shiny...")

    teleportSafely(Points.Camp, Vector3.new(0, 3, 0))
    task.wait(0.5)

    pcall(function()
        local hrp = getHRP()
        if hrp then
            for _, desc in ipairs(Workspace:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and (desc.Position - hrp.Position).Magnitude <= 30 then
                    if fireproximityprompt then
                        fireproximityprompt(desc)
                    end
                end
            end
        end
    end)

    task.wait(0.4)
    pcall(executeCampPetDepositFlow)

    pcall(function()
        fireNetwork("Camp_DepositPets")
        fireNetwork("EventAltar_Deposit")
        fireNetwork("WinterCamp_Deposit")
        fireNetwork("ShinyMachine_Deposit")
        fireNetwork("Altar_Deposit")
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
            fireNetwork("Merchant: Buy", "TravelingMerchant", slot)
            fireNetwork("MysteryMerchant_Buy", slot)
            fireNetwork("Merchant_Buy", "MysteryMerchant", slot)
            fireNetwork("WinterMerchant_Buy", slot)
            fireNetwork("EventShop_Buy", slot)
            fireNetwork("WinterShop_Buy", slot)
        end
    end)

    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("ScreenGui") and string.find(string.lower(g.Name), "merchant") then
                    for _, desc in ipairs(g:GetDescendants()) do
                        if desc:IsA("GuiButton") and desc.Visible then
                            local t = string.lower(desc.Text or "")
                            if string.find(t, "buy") or string.find(t, "purchase") then
                                if firesignal then firesignal(desc.Activated) end
                            end
                        end
                    end
                end
            end
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
DayCard.Size = UDim2.new(0, 420, 0, 260)
DayCard.Position = UDim2.new(0.5, -210, 0.5, -130)
DayCard.BackgroundColor3 = Colors.Bg
DayCard.BorderSizePixel = 0
DayCard.ZIndex = 10
DayCard.Parent = ScreenGui
addCorner(DayCard, 10)
local DayCardStroke = addStroke(DayCard, Colors.Cyan, 1.8)
addGradient(DayCard, Colors.Bg, Colors.InnerCard, 45)

local DaySnowPuffHolder = Instance.new("Frame")
DaySnowPuffHolder.Size = UDim2.new(1, 16, 0, 14)
DaySnowPuffHolder.Position = UDim2.new(0, -8, 0, -8)
DaySnowPuffHolder.BackgroundTransparency = 1
DaySnowPuffHolder.ZIndex = 30
DaySnowPuffHolder.Parent = DayCard

for puffIdx = 1, 14 do
    local puff = Instance.new("Frame")
    local pw = 36
    local ph = 12
    local px = (puffIdx - 1) * 31 - 6
    puff.Size = UDim2.new(0, pw, 0, ph)
    puff.Position = UDim2.new(0, px, 0, 0)
    puff.BackgroundColor3 = Colors.SnowWhite
    puff.BorderSizePixel = 0
    puff.ZIndex = 31
    puff.Parent = DaySnowPuffHolder
    addCorner(puff, 6)
    addGradient(puff, Color3.fromRGB(255, 255, 255), Colors.Frost, 90)
end

local CableHolder = Instance.new("Frame")
CableHolder.Size = UDim2.new(0.9, 0, 0, 16)
CableHolder.Position = UDim2.new(0.05, 0, 1, -2)
CableHolder.BackgroundTransparency = 1
CableHolder.ZIndex = 6
CableHolder.Parent = DayCard

local DayCable1 = Instance.new("Frame")
DayCable1.Size = UDim2.new(0.48, 0, 0, 8)
DayCable1.Position = UDim2.new(0.02, 0, 0, 2)
DayCable1.BackgroundColor3 = Colors.Amber
DayCable1.BorderSizePixel = 0
DayCable1.ZIndex = 6
DayCable1.Parent = CableHolder
addCorner(DayCable1, 4)
addGradient(DayCable1, Colors.Amber, Colors.AmberBright, 0)

local DayCable2 = Instance.new("Frame")
DayCable2.Size = UDim2.new(0.48, 0, 0, 8)
DayCable2.Position = UDim2.new(0.50, 0, 0, 4)
DayCable2.BackgroundColor3 = Colors.AmberBright
DayCable2.BorderSizePixel = 0
DayCable2.ZIndex = 6
DayCable2.Parent = CableHolder
addCorner(DayCable2, 4)
addGradient(DayCable2, Colors.AmberBright, Colors.Amber, 0)

local DayTopHeader = Instance.new("Frame")
DayTopHeader.Size = UDim2.new(1, 0, 0, 42)
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

makeLabel(DayTopHeader, UDim2.new(0, 110, 0, 26), UDim2.new(0, 12, 0, 1), "pufyftyk", Colors.CyanBright, Enum.Font.GothamBold, 20)

local SysStatusBadge = Instance.new("Frame")
SysStatusBadge.Size = UDim2.new(0, 150, 0, 18)
SysStatusBadge.Position = UDim2.new(0, 125, 0, 5)
SysStatusBadge.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
SysStatusBadge.BorderSizePixel = 0
SysStatusBadge.ZIndex = 12
SysStatusBadge.Parent = DayTopHeader
addCorner(SysStatusBadge, 4)
addStroke(SysStatusBadge, Colors.Amber, 1.2)

makeLabel(SysStatusBadge, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "SYSTEM STATUS: OK // HUB", Colors.AmberBright, Enum.Font.GothamBold, 8, Enum.TextXAlignment.Center, 13)

local DayLblTimeStats = makeLabel(DayTopHeader, UDim2.new(0, 170, 0, 14), UDim2.new(0, 125, 0, 25), string.format("START: %s | UP: 00:00", StartTimeString), Colors.SubText, Enum.Font.Gotham, 8)

local BtnOledSwitch = makeBtn(DayTopHeader, UDim2.new(0, 48, 0, 24), UDim2.new(1, -108, 0, 9), Colors.PurpleDim, "OLED", 10, 5)
local BtnDayMin = makeBtn(DayTopHeader, UDim2.new(0, 24, 0, 24), UDim2.new(1, -56, 0, 9), Colors.CardBright, "-", 13, 5)
local BtnDayClose = makeBtn(DayTopHeader, UDim2.new(0, 24, 0, 24), UDim2.new(1, -28, 0, 9), Colors.Red, "X", 11, 5)

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

local DayLblYeti = createDayStatBox(DayCard, "[+]", "YETI KILLS", "0", 8, 48, 98, 34, Colors.SnowWhite)
local DayLblTunnel = createDayStatBox(DayCard, "[O]", "TUNNEL", "STANDBY", 110, 48, 98, 34, Colors.CyanBright)
local DayLblYetiState = createDayStatBox(DayCard, "[*]", "YETI", "READY", 212, 48, 98, 34, Colors.AmberBright, Colors.Amber)
local DayLblAcorns = createDayStatBox(DayCard, "[$]", "ACORNS", "0 / 2.6T", 314, 48, 98, 34, Colors.Gold)

local DayLblGems = createDayStatBox(DayCard, "[#]", "DIAMONDS", "0 (+0)", 8, 86, 200, 30, Colors.CyanBright)
local DayLblMerchant = createDayStatBox(DayCard, "[@]", "MERCHANT RESTOCK", "00:00", 212, 86, 200, 30, Colors.SnowWhite)

local ActionFrame = Instance.new("Frame")
ActionFrame.Size = UDim2.new(1, -16, 0, 56)
ActionFrame.Position = UDim2.new(0, 8, 0, 120)
ActionFrame.BackgroundColor3 = Colors.InputBg
ActionFrame.BorderSizePixel = 0
ActionFrame.ZIndex = 12
ActionFrame.Parent = DayCard
addCorner(ActionFrame, 6)
addStroke(ActionFrame, Colors.CyanDim, 1)

makeLabel(ActionFrame, UDim2.new(1, -12, 0, 14), UDim2.new(0, 8, 0, 2), "CURRENT ACTION:", Colors.SubText, Enum.Font.Gotham, 8)
local DayLblAction = makeLabel(ActionFrame, UDim2.new(1, -12, 0, 18), UDim2.new(0, 8, 0, 15), "INITIALIZING ENGINE...", Colors.SnowWhite, Enum.Font.GothamBold, 11)

local SegMeterFrame = Instance.new("Frame")
SegMeterFrame.Size = UDim2.new(1, -16, 0, 12)
SegMeterFrame.Position = UDim2.new(0, 8, 0, 36)
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
BadgesRow.Size = UDim2.new(1, -16, 0, 28)
BadgesRow.Position = UDim2.new(0, 8, 0, 180)
BadgesRow.BackgroundTransparency = 1
BadgesRow.ZIndex = 12
BadgesRow.Parent = DayCard

local PillList = {
    { Name = "TUNNEL", Label = "[AUTO TUNNEL]" },
    { Name = "YETI", Label = "[FARM YETI]" },
    { Name = "DEPOSIT", Label = "[DEPOSIT PETS]" },
    { Name = "FLAG", Label = "[MAGNET FLAG]" },
    { Name = "OLED", Label = "[OLED SLEEP]" }
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
DayBottomBar.Size = UDim2.new(1, -16, 0, 42)
DayBottomBar.Position = UDim2.new(0, 8, 0, 212)
DayBottomBar.BackgroundTransparency = 1
DayBottomBar.ZIndex = 12
DayBottomBar.Parent = DayCard

local DayStatusPill = Instance.new("Frame")
DayStatusPill.Size = UDim2.new(1, 0, 0, 22)
DayStatusPill.Position = UDim2.new(0, 0, 0, 0)
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

local DayLblLog = makeLabel(DayBottomBar, UDim2.new(1, 0, 0, 16), UDim2.new(0, 2, 0, 24), "Engine Standby...", Colors.SubText, Enum.Font.Gotham, 8)

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

local OledLblGems = createOledStatRow(OledCard, "DIAMONDS:", "0 (+0)", 54, Colors.PurpleBright)
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

            local elapsedSec = os.clock() - State.StartTime
            DayLblTimeStats.Text = string.format("START: %s | UP: %s", State.StartTimeStr, formatDuration(elapsedSec))

            local gemsText = string.format("%s (+%s)", formatNumber(State.CurrentGems), formatNumber(State.GemsGained))
            local acornsText = string.format("%s / 2.6T", formatNumber(State.CurrentAcorns))
            local yetiKillsText = tostring(State.YetiKills)

            local nowSec = os.time()
            local merchantRemaining = 3600 - (nowSec % 3600)
            local merchantText = formatDuration(merchantRemaining)

            local tunnelText = ""
            if State.TunnelOpen then
                tunnelText = string.format("OPEN (%s)", formatDuration(State.TunnelTimeRemaining))
            else
                tunnelText = "STANDBY"
            end

            local now = os.clock()
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
            DayLblLog.Text = table.concat(State.RecentLogs, "  //  ")

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
    State.CurrentActionText = string.format("TUNNEL: CHECKING CHEST #%d...", chestIndex)
    pushLog(string.format("Teleporting to Chest #%d...", chestIndex))
    teleportSafely(cframePt, Vector3.new(0, 3, 0))
    task.wait(0.5)

    local acquireStart = os.clock()
    local obj, uid, dist = nil, nil, nil
    while State.Running and (os.clock() - acquireStart < 3.5) do
        obj, uid, dist = findBreakableNear(cframePt, 35)
        if obj and dist <= 35 then break end
        task.wait(0.2)
    end

    if not obj or dist > 35 then
        pushLog(string.format("Chest #%d already destroyed. Continuing...", chestIndex))
        return
    end

    State.CurrentActionText = string.format("TUNNEL: SMASHING CHEST #%d...", chestIndex)
    pushLog(string.format("Smashing Chest #%d with pets & ult!", chestIndex))
    local attackStart = os.clock()
    while State.Running do
        if os.clock() - attackStart > 25 then break end
        local currObj, currUid, currDist = findBreakableNear(cframePt, 35)
        if not currObj or currDist > 35 then
            pushLog(string.format("Chest #%d destroyed!", chestIndex))
            break
        end

        local hrp = getHRP()
        if hrp and (hrp.Position - cframePt.Position).Magnitude > 8 then
            teleportSafely(cframePt, Vector3.new(0, 2, 0))
        end

        attackBreakableUID(currUid, currObj)
        useUltimateAbility()
        task.wait(0.12)
    end
end

local function runTunnelSequence()
    State.TunnelOpen = true
    State.CurrentPhase = "TUNNEL"
    pushLog("Tunnel open! Smashing tunnel chests...")
    local tunnelStart = os.clock()
    local tunnelDuration = 300

    breakChestAtPoint(Points.Chest1, 1)
    if not State.Running then return end
    task.wait(0.3)

    breakChestAtPoint(Points.Chest2, 2)
    if not State.Running then return end
    task.wait(0.3)

    breakChestAtPoint(Points.Chest3, 3)
    if not State.Running then return end
    task.wait(0.3)

    updateCurrencies()
    if State.CurrentAcorns >= AcornsTarget then
        State.CurrentActionText = "TUNNEL EGG: 300X LUCK EGG HATCHING..."
        pushLog("Balance >= 2.6T. Hatching 300x luck egg in tunnel!")
        teleportSafely(Points.TunnelEgg, Vector3.new(0, 2, 0))
        task.wait(0.4)

        while State.Running do
            local elapsed = os.clock() - tunnelStart
            local remaining = tunnelDuration - elapsed
            State.TunnelTimeRemaining = remaining
            State.ProgressFraction = math.clamp(remaining / tunnelDuration, 0, 1)

            if remaining <= 10 then
                pushLog("Tunnel closing soon (4:50). Exiting safely...")
                break
            end

            local hrp = getHRP()
            if hrp and (hrp.Position - Points.TunnelEgg.Position).Magnitude > 6 then
                teleportSafely(Points.TunnelEgg, Vector3.new(0, 2, 0))
            end

            hatchNearestEgg(Points.TunnelEgg, 79)
            useUltimateAbility()
            task.wait(1.0)
        end
    else
        State.CurrentActionText = "TUNNEL EGG SKIPPED (< 2.6T ACORNS). EXITING..."
        pushLog("Acorns < 2.6T. Exiting tunnel to farm acorns.")
        task.wait(0.8)
    end

    teleportSafely(Points.FarmEgg, Vector3.new(0, 3, 0))
    State.TunnelOpen = false
    pushLog("Returned to Farm Zone.")
end

local function runYetiSequence()
    State.CurrentPhase = "YETI"
    State.CurrentActionText = "YETI: ENGAGING BOSS WALL..."
    pushLog("Yeti ready! Teleporting to boss wall...")
    teleportSafely(Points.Yeti, Vector3.new(0, 2, 0))
    task.wait(0.5)

    local acquireStart = os.clock()
    local obj, uid, dist = nil, nil, nil
    while State.Running and (os.clock() - acquireStart < 3.0) do
        obj, uid, dist = findBreakableNear(Points.Yeti, 40)
        if obj and dist <= 40 then break end
        task.wait(0.2)
    end

    if not obj or dist > 40 then
        pushLog("Yeti not spawned. Setting 5m cooldown...")
        State.YetiCooldownEnd = os.clock() + 300
        return
    end

    pushLog("Attacking Yeti with pets, taps and ultimate!")
    local engageStart = os.clock()
    while State.Running do
        local currObj, currUid, currDist = findBreakableNear(Points.Yeti, 40)
        if not currObj or currDist > 40 then
            State.YetiKills = State.YetiKills + 1
            State.YetiCooldownEnd = os.clock() + 300
            State.CurrentActionText = string.format("YETI DEFEATED! (TOTAL: %d). COOLDOWN 5M...", State.YetiKills)
            pushLog(string.format("Yeti defeated! Total kills: %d.", State.YetiKills))
            task.wait(0.5)
            break
        end

        local hrp = getHRP()
        if hrp and (hrp.Position - Points.Yeti.Position).Magnitude > 8 then
            teleportSafely(Points.Yeti, Vector3.new(0, 2, 0))
        end

        attackBreakableUID(currUid, currObj)
        useUltimateAbility()

        local elapsed = os.clock() - engageStart
        State.ProgressFraction = math.abs(math.sin(elapsed * 2))
        task.wait(0.1)
    end

    depositCampPets()
end

local function runFreeTimeSequence()
    local now = os.clock()

    if now - State.LastCampDeposit > 180 then
        depositCampPets()
    end

    State.CurrentPhase = "FLAG"
    State.CurrentActionText = "FARM ZONE: ACCUMULATING ACORNS & BASE EGGS..."

    local hrp = getHRP()
    if hrp and (hrp.Position - Points.FarmEgg.Position).Magnitude > 8 then
        teleportSafely(Points.FarmEgg, Vector3.new(0, 2, 0))
    end

    placeMagnetFlag()

    local bObj, bUid, bDist = findBreakableNear(Points.FarmEgg, 35)
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
                    local yObj = findBreakableNear(Points.Yeti, 40)
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
