local _CREATOR = "by pufyftyk"
local _PROJECT = "PS99 Diamond Mountain - Map Points Scanner"
local _VERSION = "1.0.0"

pcall(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function copyText(str)
    pcall(function()
        if setclipboard then
            setclipboard(str)
        elseif toclipboard then
            toclipboard(str)
        end
        print(str)
    end)
end

local function getObjectPos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        local p = obj:FindFirstChildWhichIsA("BasePart")
        if p then return p.Position end
    end
    if obj:IsA("Attachment") then return obj.WorldPosition end
    return nil
end

local Colors = {
    Bg = Color3.fromRGB(12, 18, 30),
    Header = Color3.fromRGB(18, 28, 48),
    Card = Color3.fromRGB(20, 32, 54),
    Stroke = Color3.fromRGB(60, 160, 240),
    IceAccent = Color3.fromRGB(80, 210, 255),
    SnowWhite = Color3.fromRGB(245, 250, 255),
    SubText = Color3.fromRGB(165, 205, 245),
    Green = Color3.fromRGB(46, 204, 113),
    Red = Color3.fromRGB(235, 75, 75),
    Gold = Color3.fromRGB(255, 215, 0)
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
    if ParentGui:FindFirstChild("PS99MapScanner") then
        ParentGui:FindFirstChild("PS99MapScanner"):Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99MapScanner"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 110
pcall(function() ScreenGui.IgnoreGuiInset = true end)
ScreenGui.Parent = ParentGui

local function addCorner(inst, r)
    Instance.new("UICorner", inst).CornerRadius = UDim.new(0, r or 6)
end

local function addStroke(inst, col, th)
    local s = Instance.new("UIStroke", inst)
    s.Color = col or Colors.Stroke
    s.Thickness = th or 1.2
    return s
end

local function makeBtn(parent, size, pos, bg, text, textSize)
    local b = Instance.new("TextButton")
    b.Size = size
    if pos then b.Position = pos end
    b.BackgroundColor3 = bg
    b.Text = text or ""
    b.TextColor3 = Colors.SnowWhite
    b.Font = Enum.Font.GothamBold
    b.TextSize = textSize or 11
    b.TextStrokeTransparency = 0.5
    b.TextStrokeColor3 = Color3.new(0, 0, 0)
    b.Active = true
    b.Selectable = true
    b.AutoButtonColor = true
    b.ZIndex = 25
    b.Parent = parent
    addCorner(b, 6)
    addStroke(b, Colors.Stroke, 1)
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
    l.TextSize = textSize or 11
    l.TextStrokeTransparency = 0.5
    l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
    l.ZIndex = 25
    l.Parent = parent
    return l
end

local isDragging = false
local function bindClick(btn, cb)
    btn.Active = true
    local last = 0
    local function fire()
        local now = os.clock()
        if now - last < 0.15 then return end
        last = now
        isDragging = false
        pcall(cb)
    end
    btn.Activated:Connect(fire)
    btn.MouseButton1Click:Connect(fire)
    pcall(function() btn.TouchTap:Connect(fire) end)
    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            fire()
        end
    end)
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "ScannerCard"
MainFrame.Size = UDim2.new(0, 360, 0, 320)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -160)
MainFrame.BackgroundColor3 = Colors.Bg
MainFrame.BorderSizePixel = 0
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui
addCorner(MainFrame, 10)
addStroke(MainFrame, Colors.Stroke, 1.5)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Colors.Header
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 11
TopBar.Active = true
TopBar.Parent = MainFrame
addCorner(TopBar, 10)

do
    local dragStart, startPos = nil, nil
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
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
                MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
end

makeLabel(TopBar, UDim2.new(1, -70, 0, 20), UDim2.new(0, 10, 0, 3), "[*] MAP POINTS SCANNER | by pufyftyk", Colors.IceAccent, Enum.Font.GothamBold, 12)
makeLabel(TopBar, UDim2.new(1, -70, 0, 14), UDim2.new(0, 10, 0, 22), "Eggs | Farm Zones | Tunnels Scanner", Colors.SubText, Enum.Font.Gotham, 10)

local CloseBtn = makeBtn(TopBar, UDim2.new(0, 26, 0, 24), UDim2.new(1, -32, 0, 8), Colors.Red, "X", 12)
bindClick(CloseBtn, function() ScreenGui:Destroy() end)

local PosBox = Instance.new("Frame")
PosBox.Size = UDim2.new(1, -16, 0, 32)
PosBox.Position = UDim2.new(0, 8, 0, 46)
PosBox.BackgroundColor3 = Colors.Card
PosBox.BorderSizePixel = 0
PosBox.ZIndex = 12
PosBox.Parent = MainFrame
addCorner(PosBox, 6)
addStroke(PosBox, Colors.Stroke, 1)

local PosLabel = makeLabel(PosBox, UDim2.new(1, -90, 1, 0), UDim2.new(0, 8, 0, 0), "Pos: (0, 0, 0)", Colors.SnowWhite, Enum.Font.Gotham, 10)
local CopyPosBtn = makeBtn(PosBox, UDim2.new(0, 76, 0, 22), UDim2.new(1, -82, 0, 5), Colors.Green, "Copy Pos", 10)

bindClick(CopyPosBtn, function()
    local hrp = getHRP()
    if hrp then
        local s = string.format("CFrame.new(%.1f, %.1f, %.1f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
        copyText(s)
        PosLabel.Text = "COPIED: " .. s
    end
end)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -16, 0, 195)
ScrollFrame.Position = UDim2.new(0, 8, 0, 84)
ScrollFrame.BackgroundColor3 = Color3.fromRGB(10, 14, 24)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Colors.IceAccent
ScrollFrame.ZIndex = 12
ScrollFrame.Parent = MainFrame
addCorner(ScrollFrame, 6)
addStroke(ScrollFrame, Colors.Stroke, 1)

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 4)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Parent = ScrollFrame

local StatusLabel = makeLabel(MainFrame, UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 283), "Status: Ready to scan | by pufyftyk", Colors.SubText, Enum.Font.Gotham, 9)

local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, -16, 0, 24)
BottomBar.Position = UDim2.new(0, 8, 0, 292)
BottomBar.BackgroundTransparency = 1
BottomBar.ZIndex = 12
BottomBar.Parent = MainFrame

local ScanBtn = makeBtn(BottomBar, UDim2.new(0.5, -4, 1, 0), UDim2.new(0, 0, 0, 0), Colors.Header, "[?] Re-Scan Map", 10)
local DumpBtn = makeBtn(BottomBar, UDim2.new(0.5, -4, 1, 0), UDim2.new(0.5, 4, 0, 0), Colors.Green, "[#] Dump All To Clip", 10)

local FoundPoints = {
    Eggs = {},
    Camps = {},
    Tunnels = {}
}

local function clearList()
    for _, ch in ipairs(ScrollFrame:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
end

local function addEntry(category, name, cf, color)
    local item = Instance.new("Frame")
    item.Size = UDim2.new(1, -6, 0, 28)
    item.BackgroundColor3 = Colors.Card
    item.BorderSizePixel = 0
    item.ZIndex = 13
    item.Parent = ScrollFrame
    addCorner(item, 4)

    local txt = string.format("[%s] %s (%.0f, %.0f, %.0f)", category, name, cf.Position.X, cf.Position.Y, cf.Position.Z)
    local lbl = makeLabel(item, UDim2.new(1, -85, 1, 0), UDim2.new(0, 6, 0, 0), txt, color or Colors.SnowWhite, Enum.Font.Gotham, 9)

    local tpBtn = makeBtn(item, UDim2.new(0, 36, 0, 20), UDim2.new(1, -80, 0, 4), Colors.Header, "TP", 9)
    bindClick(tpBtn, function()
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = cf + Vector3.new(0, 3, 0)
            StatusLabel.Text = "Teleported to: " .. name
        end
    end)

    local cpBtn = makeBtn(item, UDim2.new(0, 40, 0, 20), UDim2.new(1, -42, 0, 4), Colors.IceAccent, "Copy", 9)
    cpBtn.TextColor3 = Color3.fromRGB(10, 16, 28)
    bindClick(cpBtn, function()
        local s = string.format("CFrame.new(%.1f, %.1f, %.1f)", cf.Position.X, cf.Position.Y, cf.Position.Z)
        copyText(s)
        StatusLabel.Text = "Copied: " .. s
    end)
end

local function runScan()
    clearList()
    FoundPoints = { Eggs = {}, Camps = {}, Tunnels = {} }

    local things = Workspace:FindFirstChild("__THINGS") or Workspace:FindFirstChild("Things")
    if things then
        for _, fName in ipairs({ "CustomEggs", "Eggs", "EggCapsules", "EggMachines" }) do
            local f = things:FindFirstChild(fName)
            if f then
                for _, egg in ipairs(f:GetChildren()) do
                    local p = getObjectPos(egg)
                    if p then
                        table.insert(FoundPoints.Eggs, { Name = egg.Name, CF = CFrame.new(p) })
                    end
                end
            end
        end
    end

    local map = Workspace:FindFirstChild("Map") or Workspace
    for _, desc in ipairs(map:GetDescendants()) do
        local low = string.lower(desc.Name)
        if desc:IsA("BasePart") or desc:IsA("Model") then
            local p = getObjectPos(desc)
            if p then
                if string.find(low, "tunnel") or string.find(low, "passage") or string.find(low, "cave") or string.find(low, "gate") then
                    table.insert(FoundPoints.Tunnels, { Name = desc.Name, CF = CFrame.new(p) })
                elseif string.find(low, "camp") or string.find(low, "zone") then
                    table.insert(FoundPoints.Camps, { Name = desc.Name, CF = CFrame.new(p) })
                end
            end
        end
    end

    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            local act = string.lower(desc.ActionText or "")
            local obj = string.lower(desc.ObjectText or "")
            local p = getObjectPos(desc)
            if p then
                if string.find(act, "egg") or string.find(obj, "egg") or string.find(act, "hatch") then
                    local name = desc.Parent and desc.Parent.Name or "EggPrompt"
                    table.insert(FoundPoints.Eggs, { Name = name, CF = CFrame.new(p) })
                elseif string.find(act, "tunnel") or string.find(obj, "tunnel") or string.find(act, "enter") then
                    local name = desc.Parent and desc.Parent.Name or "TunnelPrompt"
                    table.insert(FoundPoints.Tunnels, { Name = name, CF = CFrame.new(p) })
                end
            end
        end
    end

    for _, egg in ipairs(FoundPoints.Eggs) do
        addEntry("EGG", egg.Name, egg.CF, Colors.Gold)
    end
    for _, camp in ipairs(FoundPoints.Camps) do
        addEntry("CAMP", camp.Name, camp.CF, Colors.IceAccent)
    end
    for _, tun in ipairs(FoundPoints.Tunnels) do
        addEntry("TUNNEL", tun.Name, tun.CF, Colors.Green)
    end

    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 20)
    StatusLabel.Text = string.format("Scan: %d Eggs, %d Camps, %d Tunnels found!", #FoundPoints.Eggs, #FoundPoints.Camps, #FoundPoints.Tunnels)
end

bindClick(ScanBtn, runScan)

bindClick(DumpBtn, function()
    local lines = {}
    table.insert(lines, "/* PS99 DIAMOND MOUNTAIN MAP CONFIG DUMP */")
    table.insert(lines, "getgenv().Config = getgenv().Config or {}")
    table.insert(lines, "getgenv().Config.CampPoints = {")
    for i, camp in ipairs(FoundPoints.Camps) do
        if i <= 6 then
            table.insert(lines, string.format("    [%d] = CFrame.new(%.1f, %.1f, %.1f), /* %s */", i, camp.CF.Position.X, camp.CF.Position.Y, camp.CF.Position.Z, camp.Name))
        end
    end
    table.insert(lines, "}")
    if #FoundPoints.Tunnels > 0 then
        table.insert(lines, string.format("getgenv().Config.Tunnel6CF = CFrame.new(%.1f, %.1f, %.1f) /* %s */", FoundPoints.Tunnels[1].CF.Position.X, FoundPoints.Tunnels[1].CF.Position.Y, FoundPoints.Tunnels[1].CF.Position.Z, FoundPoints.Tunnels[1].Name))
    end
    if #FoundPoints.Eggs > 0 then
        table.insert(lines, string.format("getgenv().Config.EggCF = CFrame.new(%.1f, %.1f, %.1f) /* %s */", FoundPoints.Eggs[1].CF.Position.X, FoundPoints.Eggs[1].CF.Position.Y, FoundPoints.Eggs[1].CF.Position.Z, FoundPoints.Eggs[1].Name))
    end
    local fullDump = table.concat(lines, "\n")
    copyText(fullDump)
    StatusLabel.Text = "COPIED FULL CONFIG TO CLIPBOARD & CONSOLE!"
end)

task.spawn(function()
    while ScreenGui.Parent do
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            PosLabel.Text = string.format("My Pos: %.1f, %.1f, %.1f", p.X, p.Y, p.Z)
        end
        task.wait(0.2)
    end
end)

task.spawn(runScan)
