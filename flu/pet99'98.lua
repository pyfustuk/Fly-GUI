local _CREATOR = "by pufyftyk"
local _PROJECT = "PS99 Point Recorder Pro"
local _VERSION = "2.0.0"

pcall(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
    Bg = Color3.fromRGB(11, 17, 28),
    Header = Color3.fromRGB(16, 26, 44),
    Card = Color3.fromRGB(18, 30, 50),
    CardAlt = Color3.fromRGB(24, 38, 64),
    Stroke = Color3.fromRGB(56, 160, 240),
    StrokeDim = Color3.fromRGB(30, 75, 120),
    IceAccent = Color3.fromRGB(80, 220, 255),
    IceCyan = Color3.fromRGB(0, 190, 240),
    SnowWhite = Color3.fromRGB(245, 250, 255),
    SubText = Color3.fromRGB(160, 200, 235),
    Green = Color3.fromRGB(46, 213, 115),
    GreenDark = Color3.fromRGB(30, 140, 80),
    Red = Color3.fromRGB(255, 71, 87),
    Gold = Color3.fromRGB(255, 210, 60),
    Purple = Color3.fromRGB(190, 110, 255)
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
    if ParentGui:FindFirstChild("PS99PointRecorderPro") then
        ParentGui:FindFirstChild("PS99PointRecorderPro"):Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99PointRecorderPro"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 150
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

local function addGradient(inst, c1, c2, rot)
    local g = Instance.new("UIGradient", inst)
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rot or 0
    return g
end

local function makeBtn(parent, size, pos, bg, text, textSize, cornerRadius)
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
    b.ZIndex = 25
    b.Parent = parent
    addCorner(b, cornerRadius or 6)
    addStroke(b, Colors.StrokeDim, 1)
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

local function bindSafeClick(btn, cb)
    btn.Active = true
    btn.Selectable = true
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
    btn.Activated:Connect(execute)
    btn.MouseButton1Click:Connect(execute)
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "RecorderCard"
MainFrame.Size = UDim2.new(0, 350, 0, 335)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -167)
MainFrame.BackgroundColor3 = Colors.Bg
MainFrame.BorderSizePixel = 0
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui
addCorner(MainFrame, 10)
local mainStroke = addStroke(MainFrame, Colors.Stroke, 1.5)
addGradient(MainFrame, Colors.Bg, Color3.fromRGB(15, 24, 40), 45)

local MiniBadge = makeBtn(ScreenGui, UDim2.new(0, 130, 0, 32), UDim2.new(0, 10, 0, 10), Colors.Header, "[*] Recorder (0)", 11, 8)
MiniBadge.TextColor3 = Colors.IceAccent
MiniBadge.Visible = false
addStroke(MiniBadge, Colors.IceAccent, 1.5)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 38)
TopBar.BackgroundColor3 = Colors.Header
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 11
TopBar.Active = true
TopBar.Parent = MainFrame
addCorner(TopBar, 10)
addGradient(TopBar, Color3.fromRGB(22, 36, 60), Colors.Header, 90)

local isDragging = false
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

makeLabel(TopBar, UDim2.new(1, -70, 0, 20), UDim2.new(0, 12, 0, 2), "PS99 POINT RECORDER | PRO", Colors.IceAccent, Enum.Font.GothamBold, 12)
makeLabel(TopBar, UDim2.new(1, -70, 0, 14), UDim2.new(0, 12, 0, 20), "Winter Event | One-Tap Waypoint Saver", Colors.SubText, Enum.Font.Gotham, 10)

local MinBtn = makeBtn(TopBar, UDim2.new(0, 24, 0, 22), UDim2.new(1, -54, 0, 8), Colors.CardAlt, "-", 13, 5)
local CloseBtn = makeBtn(TopBar, UDim2.new(0, 24, 0, 22), UDim2.new(1, -28, 0, 8), Colors.Red, "X", 11, 5)

bindSafeClick(MinBtn, function()
    MainFrame.Visible = false
    MiniBadge.Visible = true
end)

bindSafeClick(MiniBadge, function()
    MainFrame.Visible = true
    MiniBadge.Visible = false
end)

bindSafeClick(CloseBtn, function()
    ScreenGui:Destroy()
end)

local PosCard = Instance.new("Frame")
PosCard.Size = UDim2.new(1, -16, 0, 28)
PosCard.Position = UDim2.new(0, 8, 0, 44)
PosCard.BackgroundColor3 = Colors.Card
PosCard.BorderSizePixel = 0
PosCard.ZIndex = 12
PosCard.Parent = MainFrame
addCorner(PosCard, 6)
addStroke(PosCard, Colors.StrokeDim, 1)

local PulseDot = Instance.new("Frame")
PulseDot.Size = UDim2.new(0, 8, 0, 8)
PulseDot.Position = UDim2.new(0, 8, 0.5, -4)
PulseDot.BackgroundColor3 = Colors.Green
PulseDot.BorderSizePixel = 0
PulseDot.ZIndex = 13
PulseDot.Parent = PosCard
addCorner(PulseDot, 4)

local PosLabel = makeLabel(PosCard, UDim2.new(1, -26, 1, 0), UDim2.new(0, 22, 0, 0), "TRACKING: X: 0 | Y: 0 | Z: 0", Colors.SnowWhite, Enum.Font.Gotham, 10)

local TagContainer = Instance.new("Frame")
TagContainer.Size = UDim2.new(1, -16, 0, 26)
TagContainer.Position = UDim2.new(0, 8, 0, 76)
TagContainer.BackgroundTransparency = 1
TagContainer.ZIndex = 12
TagContainer.Parent = MainFrame

local SelectedTag = "Egg"
local TagBtns = {}

local TagList = {
    { Name = "Egg", Label = "Egg", Col = Colors.Gold },
    { Name = "Tunnel", Label = "Tunnel", Col = Colors.IceAccent },
    { Name = "Chest", Label = "Chest", Col = Colors.Purple },
    { Name = "Camp", Label = "Camp", Col = Colors.IceCyan },
    { Name = "Wall", Label = "Wall", Col = Colors.Red }
}

local function refreshTags()
    for _, item in ipairs(TagList) do
        local b = TagBtns[item.Name]
        if b then
            if SelectedTag == item.Name then
                b.BackgroundColor3 = item.Col
                b.TextColor3 = Color3.fromRGB(10, 16, 26)
            else
                b.BackgroundColor3 = Colors.Card
                b.TextColor3 = Colors.SubText
            end
        end
    end
end

for idx, item in ipairs(TagList) do
    local b = makeBtn(TagContainer, UDim2.new(0.2, -4, 1, 0), UDim2.new(0.2 * (idx - 1), 2, 0, 0), Colors.Card, item.Label, 10, 5)
    TagBtns[item.Name] = b
    bindSafeClick(b, function()
        SelectedTag = item.Name
        refreshTags()
    end)
end
refreshTags()

local AddHeroBtn = makeBtn(MainFrame, UDim2.new(1, -16, 0, 32), UDim2.new(0, 8, 0, 106), Colors.GreenDark, "[+] RECORD THIS SPOT", 12, 8)
AddHeroBtn.TextColor3 = Colors.SnowWhite
local heroStroke = addStroke(AddHeroBtn, Colors.Green, 1.5)
addGradient(AddHeroBtn, Color3.fromRGB(36, 180, 95), Color3.fromRGB(20, 120, 65), 90)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -16, 0, 122)
ScrollFrame.Position = UDim2.new(0, 8, 0, 142)
ScrollFrame.BackgroundColor3 = Color3.fromRGB(9, 14, 24)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Colors.IceAccent
ScrollFrame.ZIndex = 12
ScrollFrame.Parent = MainFrame
addCorner(ScrollFrame, 6)
addStroke(ScrollFrame, Colors.StrokeDim, 1)

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 3)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Parent = ScrollFrame

local StatusLabel = makeLabel(MainFrame, UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 268), "Ready. Choose tag & tap RECORD | by pufyftyk", Colors.SubText, Enum.Font.Gotham, 9)

local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1, -16, 0, 30)
BottomBar.Position = UDim2.new(0, 8, 0, 288)
BottomBar.BackgroundTransparency = 1
BottomBar.ZIndex = 12
BottomBar.Parent = MainFrame

local CopyAllBtn = makeBtn(BottomBar, UDim2.new(0.55, -4, 1, 0), UDim2.new(0, 0, 0, 0), Colors.IceAccent, "[#] COPY ALL FOR CHAT", 10, 6)
CopyAllBtn.TextColor3 = Color3.fromRGB(10, 16, 28)
addGradient(CopyAllBtn, Colors.IceAccent, Color3.fromRGB(40, 160, 240), 90)

local UndoBtn = makeBtn(BottomBar, UDim2.new(0.23, -4, 1, 0), UDim2.new(0.55, 2, 0, 0), Colors.CardAlt, "Undo", 10, 6)
local ClearBtn = makeBtn(BottomBar, UDim2.new(0.22, -4, 1, 0), UDim2.new(0.78, 4, 0, 0), Colors.Red, "Clear", 10, 6)

local SavedPoints = {}
local DeletedHistory = {}
local nextPointId = 1

local function getTagColor(tag)
    for _, t in ipairs(TagList) do
        if t.Name == tag then return t.Col end
    end
    return Colors.IceAccent
end

local function renderList()
    for _, ch in ipairs(ScrollFrame:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end

    MiniBadge.Text = string.format("[*] Recorder (%d)", #SavedPoints)

    for i, pt in ipairs(SavedPoints) do
        local item = Instance.new("Frame")
        item.Size = UDim2.new(1, -6, 0, 26)
        item.BackgroundColor3 = (i % 2 == 0) and Colors.Card or Colors.CardAlt
        item.BorderSizePixel = 0
        item.ZIndex = 13
        item.Parent = ScrollFrame
        addCorner(item, 4)

        local tagColor = getTagColor(pt.Tag)

        local tagBadge = Instance.new("Frame")
        tagBadge.Size = UDim2.new(0, 52, 0, 18)
        tagBadge.Position = UDim2.new(0, 4, 0.5, -9)
        tagBadge.BackgroundColor3 = tagColor
        tagBadge.BorderSizePixel = 0
        tagBadge.ZIndex = 14
        tagBadge.Parent = item
        addCorner(tagBadge, 3)

        local tagTxt = makeLabel(tagBadge, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), string.format("#%d %s", i, pt.Tag), Color3.fromRGB(10, 16, 26), Enum.Font.GothamBold, 8, Enum.TextXAlignment.Center)
        tagTxt.ZIndex = 15

        local coordsTxt = string.format("%.0f, %.0f, %.0f", pt.X, pt.Y, pt.Z)
        local coordLbl = makeLabel(item, UDim2.new(1, -165, 1, 0), UDim2.new(0, 60, 0, 0), coordsTxt, Colors.SnowWhite, Enum.Font.Gotham, 9)

        local tpBtn = makeBtn(item, UDim2.new(0, 30, 0, 18), UDim2.new(1, -94, 0.5, -9), Colors.Header, "TP", 8, 4)
        local cpBtn = makeBtn(item, UDim2.new(0, 36, 0, 18), UDim2.new(1, -61, 0.5, -9), Colors.IceAccent, "Copy", 8, 4)
        cpBtn.TextColor3 = Color3.fromRGB(10, 16, 26)
        local delBtn = makeBtn(item, UDim2.new(0, 22, 0, 18), UDim2.new(1, -23, 0.5, -9), Colors.Red, "X", 9, 4)

        bindSafeClick(tpBtn, function()
            local hrp = getHRP()
            if hrp then
                hrp.CFrame = CFrame.new(pt.X, pt.Y + 3, pt.Z)
                StatusLabel.Text = string.format("Teleported to Point #%d (%s)!", i, pt.Tag)
            end
        end)

        bindSafeClick(cpBtn, function()
            local cfCode = string.format("CFrame.new(%.1f, %.1f, %.1f)", pt.X, pt.Y, pt.Z)
            copyText(cfCode)
            StatusLabel.Text = string.format("Copied Point #%d to clipboard!", i)
        end)

        bindSafeClick(delBtn, function()
            local targetId = pt.Id
            for idx, p in ipairs(SavedPoints) do
                if p.Id == targetId then
                    table.insert(DeletedHistory, p)
                    table.remove(SavedPoints, idx)
                    break
                end
            end
            renderList()
            StatusLabel.Text = string.format("Deleted Point #%d! (Tap Undo to restore)", i)
        end)
    end

    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 12)
end

bindSafeClick(AddHeroBtn, function()
    local hrp = getHRP()
    if not hrp then return end
    local p = hrp.Position

    local newPoint = {
        Id = nextPointId,
        Tag = SelectedTag,
        X = math.floor(p.X * 10) / 10,
        Y = math.floor(p.Y * 10) / 10,
        Z = math.floor(p.Z * 10) / 10
    }
    nextPointId = nextPointId + 1

    table.insert(SavedPoints, newPoint)
    renderList()
    StatusLabel.Text = string.format("RECORDED Point #%d [%s]! Total: %d", #SavedPoints, SelectedTag, #SavedPoints)

    pcall(function()
        ScrollFrame.CanvasPosition = Vector2.new(0, 9999)
    end)
end)

bindSafeClick(CopyAllBtn, function()
    if #SavedPoints == 0 then
        StatusLabel.Text = "No points recorded yet! Record spots first."
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
    StatusLabel.Text = string.format("COPIED %d POINTS TO CLIPBOARD! Paste in chat!", #SavedPoints)
end)

bindSafeClick(UndoBtn, function()
    if #DeletedHistory == 0 then
        StatusLabel.Text = "Nothing to undo!"
        return
    end
    local lastDeleted = table.remove(DeletedHistory)
    table.insert(SavedPoints, lastDeleted)
    renderList()
    StatusLabel.Text = string.format("Restored Point (%s)!", lastDeleted.Tag)
end)

local clearArmed = false
bindSafeClick(ClearBtn, function()
    if not clearArmed then
        clearArmed = true
        ClearBtn.Text = "Sure?"
        StatusLabel.Text = "Tap Sure? again to confirm clearing all!"
        task.delay(3, function()
            clearArmed = false
            ClearBtn.Text = "Clear"
        end)
    else
        clearArmed = false
        ClearBtn.Text = "Clear"
        for _, p in ipairs(SavedPoints) do
            table.insert(DeletedHistory, p)
        end
        SavedPoints = {}
        renderList()
        StatusLabel.Text = "Cleared all points! (Tap Undo to restore)"
    end
end)

task.spawn(function()
    local pulseCount = 0
    while ScreenGui.Parent do
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            PosLabel.Text = string.format("TRACKING: X: %.1f | Y: %.1f | Z: %.1f", p.X, p.Y, p.Z)
        end
        pulseCount = pulseCount + 1
        PulseDot.BackgroundTransparency = (pulseCount % 2 == 0) and 0.1 or 0.6
        task.wait(0.25)
    end
end)
