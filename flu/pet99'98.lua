local _CREATOR = "by pufyftyk"
local _PROJECT = "PS99 Point Recorder"
local _VERSION = "1.0.0"

pcall(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
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
    if ParentGui:FindFirstChild("PS99PointRecorder") then
        ParentGui:FindFirstChild("PS99PointRecorder"):Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99PointRecorder"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 120
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
MainFrame.Name = "RecorderCard"
MainFrame.Size = UDim2.new(0, 340, 0, 310)
MainFrame.Position = UDim2.new(0.5, -170, 0.5, -155)
MainFrame.BackgroundColor3 = Colors.Bg
MainFrame.BorderSizePixel = 0
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui
addCorner(MainFrame, 10)
addStroke(MainFrame, Colors.Stroke, 1.5)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 38)
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

makeLabel(TopBar, UDim2.new(1, -60, 0, 20), UDim2.new(0, 10, 0, 3), "[*] POINT RECORDER | by pufyftyk", Colors.IceAccent, Enum.Font.GothamBold, 12)
makeLabel(TopBar, UDim2.new(1, -60, 0, 14), UDim2.new(0, 10, 0, 20), "Stand & Record Points for Chat", Colors.SubText, Enum.Font.Gotham, 10)

local CloseBtn = makeBtn(TopBar, UDim2.new(0, 24, 0, 22), UDim2.new(1, -28, 0, 8), Colors.Red, "X", 12)
bindClick(CloseBtn, function() ScreenGui:Destroy() end)

local PosBox = Instance.new("Frame")
PosBox.Size = UDim2.new(1, -16, 0, 26)
PosBox.Position = UDim2.new(0, 8, 0, 44)
PosBox.BackgroundColor3 = Colors.Card
PosBox.BorderSizePixel = 0
PosBox.ZIndex = 12
PosBox.Parent = MainFrame
addCorner(PosBox, 6)
addStroke(PosBox, Colors.Stroke, 1)

local PosLabel = makeLabel(PosBox, UDim2.new(1, -10, 1, 0), UDim2.new(0, 8, 0, 0), "Current Pos: (0, 0, 0)", Colors.SnowWhite, Enum.Font.Gotham, 10)

local TagRow = Instance.new("Frame")
TagRow.Size = UDim2.new(1, -16, 0, 24)
TagRow.Position = UDim2.new(0, 8, 0, 74)
TagRow.BackgroundTransparency = 1
TagRow.ZIndex = 12
TagRow.Parent = MainFrame

local SelectedTag = "Spot"
local TagEggBtn = makeBtn(TagRow, UDim2.new(0.2, -4, 1, 0), UDim2.new(0, 0, 0, 0), Colors.Card, "Egg", 9)
local TagTunnelBtn = makeBtn(TagRow, UDim2.new(0.2, -4, 1, 0), UDim2.new(0.2, 2, 0, 0), Colors.Card, "Tunnel", 9)
local TagChestBtn = makeBtn(TagRow, UDim2.new(0.2, -4, 1, 0), UDim2.new(0.4, 4, 0, 0), Colors.Card, "Chest", 9)
local TagCampBtn = makeBtn(TagRow, UDim2.new(0.2, -4, 1, 0), UDim2.new(0.6, 6, 0, 0), Colors.Card, "Camp", 9)
local TagWallBtn = makeBtn(TagRow, UDim2.new(0.2, -4, 1, 0), UDim2.new(0.8, 8, 0, 0), Colors.Card, "Wall", 9)

local function updateTagButtons()
    TagEggBtn.BackgroundColor3 = (SelectedTag == "Egg") and Colors.Green or Colors.Card
    TagTunnelBtn.BackgroundColor3 = (SelectedTag == "Tunnel") and Colors.Green or Colors.Card
    TagChestBtn.BackgroundColor3 = (SelectedTag == "Chest") and Colors.Green or Colors.Card
    TagCampBtn.BackgroundColor3 = (SelectedTag == "Camp") and Colors.Green or Colors.Card
    TagWallBtn.BackgroundColor3 = (SelectedTag == "Wall") and Colors.Green or Colors.Card
end

bindClick(TagEggBtn, function() SelectedTag = "Egg" updateTagButtons() end)
bindClick(TagTunnelBtn, function() SelectedTag = "Tunnel" updateTagButtons() end)
bindClick(TagChestBtn, function() SelectedTag = "Chest" updateTagButtons() end)
bindClick(TagCampBtn, function() SelectedTag = "Camp" updateTagButtons() end)
bindClick(TagWallBtn, function() SelectedTag = "Wall" updateTagButtons() end)

local AddPointBtn = makeBtn(MainFrame, UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, 102), Colors.Green, "[+] RECORD THIS SPOT", 11)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -16, 0, 115)
ScrollFrame.Position = UDim2.new(0, 8, 0, 134)
ScrollFrame.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
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

local StatusLabel = makeLabel(MainFrame, UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 252), "Stand at a spot and tap RECORD! | by pufyftyk", Colors.SubText, Enum.Font.Gotham, 9)

local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, -16, 0, 28)
BottomBar.Position = UDim2.new(0, 8, 0, 272)
BottomBar.BackgroundTransparency = 1
BottomBar.ZIndex = 12
BottomBar.Parent = MainFrame

local CopyAllBtn = makeBtn(BottomBar, UDim2.new(0.65, -4, 1, 0), UDim2.new(0, 0, 0, 0), Colors.IceAccent, "[#] COPY ALL FOR CHAT", 10)
CopyAllBtn.TextColor3 = Color3.fromRGB(10, 16, 28)
local ClearBtn = makeBtn(BottomBar, UDim2.new(0.35, -4, 1, 0), UDim2.new(0.65, 4, 0, 0), Colors.Red, "Clear", 10)

local SavedPoints = {}

local function renderList()
    for _, ch in ipairs(ScrollFrame:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end

    for i, pt in ipairs(SavedPoints) do
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -6, 0, 24)
        item.BackgroundColor3 = Colors.Card
        item.BorderSizePixel = 0
        item.ZIndex = 13
        item.Parent = ScrollFrame
        addCorner(item, 4)

        local txt = string.format("%d. [%s] %.0f, %.0f, %.0f", i, pt.Tag, pt.X, pt.Y, pt.Z)
        makeLabel(item, UDim2.new(1, -70, 1, 0), UDim2.new(0, 6, 0, 0), txt, Colors.SnowWhite, Enum.Font.Gotham, 9)

        local tpBtn = makeBtn(item, UDim2.new(0, 30, 0, 18), UDim2.new(1, -66, 0, 3), Colors.Header, "TP", 8)
        bindClick(tpBtn, function()
            local hrp = getHRP()
            if hrp then
                hrp.CFrame = CFrame.new(pt.X, pt.Y + 3, pt.Z)
                StatusLabel.Text = "Teleported to Point " .. i
            end
        end)

        local delBtn = makeBtn(item, UDim2.new(0, 30, 0, 18), UDim2.new(1, -33, 0, 3), Colors.Red, "X", 8)
        bindClick(delBtn, function()
            table.remove(SavedPoints, i)
            renderList()
            StatusLabel.Text = "Removed Point " .. i
        end)
    end

    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 15)
end

bindClick(AddPointBtn, function()
    local hrp = getHRP()
    if not hrp then return end
    local p = hrp.Position
    local pt = {
        Tag = SelectedTag,
        X = math.floor(p.X * 10) / 10,
        Y = math.floor(p.Y * 10) / 10,
        Z = math.floor(p.Z * 10) / 10
    }
    table.insert(SavedPoints, pt)
    renderList()
    StatusLabel.Text = string.format("Recorded Point %d [%s]!", #SavedPoints, SelectedTag)
end)

bindClick(CopyAllBtn, function()
    if #SavedPoints == 0 then
        StatusLabel.Text = "No points recorded yet!"
        return
    end

    local lines = {}
    table.insert(lines, "=== MY RECORDED PS99 POINTS ===")
    for i, pt in ipairs(SavedPoints) do
        table.insert(lines, string.format("Point %d (%s): CFrame.new(%.1f, %.1f, %.1f)", i, pt.Tag, pt.X, pt.Y, pt.Z))
    end
    table.insert(lines, "==============================")
    local fullText = table.concat(lines, "\n")
    copyText(fullText)
    StatusLabel.Text = string.format("COPIED %d POINTS! Paste into chat!", #SavedPoints)
end)

bindClick(ClearBtn, function()
    SavedPoints = {}
    renderList()
    StatusLabel.Text = "All points cleared!"
end)

task.spawn(function()
    while ScreenGui.Parent do
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            PosLabel.Text = string.format("Current Pos: %.1f, %.1f, %.1f", p.X, p.Y, p.Z)
        end
        task.wait(0.2)
    end
end)
