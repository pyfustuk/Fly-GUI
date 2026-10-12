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

local DirectoryInfoCache = {}
local PlayerAvatarUrl = nil
local SessionMailSends = 0

local function extractAssetNumber(val)
    if type(val) == "number" and val > 0 then
        return tostring( math.floor(val) )
    elseif type(val) == "string" then
        return string.match(val, "%d+")
    end
    return nil
end

local function registerDirectoryEntry(rawId, infoTbl)
    if type(rawId) ~= "string" or rawId == "" or type(infoTbl) ~= "table" then return end
    local key = string.lower(rawId)
    local icon = rawget(infoTbl, "thumbnail") or rawget(infoTbl, "icon") or rawget(infoTbl, "Icon") or rawget(infoTbl, "Texture")
    local goldIcon = rawget(infoTbl, "goldenThumbnail") or rawget(infoTbl, "GoldenThumbnail")
    local aid = extractAssetNumber(icon)
    local goldAid = extractAssetNumber(goldIcon)

    local tiersTbl = rawget(infoTbl, "tiers") or rawget(infoTbl, "Tiers")
    local tierIcons = nil
    if type(tiersTbl) == "table" then
        tierIcons = {}
        for tIdx, tData in pairs(tiersTbl) do
            if type(tData) == "table" then
                local tIcon = rawget(tData, "thumbnail") or rawget(tData, "icon") or rawget(tData, "Icon")
                local tAid = extractAssetNumber(tIcon)
                if tAid then
                    tierIcons[tonumber(tIdx) or tIdx] = tAid
                    if not aid then aid = tAid end
                end
            end
        end
    end

    local isTitanic = (rawget(infoTbl, "titanic") == true) or (string.find(key, "titanic") ~= nil)
    local isHuge = (rawget(infoTbl, "huge") == true) or (string.find(key, "huge") ~= nil)
    local isExcl = (rawget(infoTbl, "exclusiveLevel") ~= nil)
    local tier = isTitanic and 4 or (isHuge and 3 or (isExcl and 2 or 1))
    local pwr = tonumber(rawget(infoTbl, "strength") or rawget(infoTbl, "power")) or 0

    local existing = DirectoryInfoCache[key]
    if not existing then
        DirectoryInfoCache[key] = {
            aid = aid,
            goldAid = goldAid,
            tierIcons = tierIcons,
            tier = tier,
            pwr = pwr
        }
    else
        if aid and not existing.aid then existing.aid = aid end
        if goldAid and not existing.goldAid then existing.goldAid = goldAid end
        if tierIcons and not existing.tierIcons then existing.tierIcons = tierIcons end
        if tier > (existing.tier or 1) then existing.tier = tier end
        if pwr > (existing.pwr or 0) then existing.pwr = pwr end
    end
end

local VisitedDirTables = setmetatable({}, { __mode = "k" })
local function walkDirectoryTree(tbl, parentKey, depth)
    if type(tbl) ~= "table" or (depth or 0) > 6 or VisitedDirTables[tbl] then return end
    VisitedDirTables[tbl] = true

    local selfId = rawget(tbl, "_id") or rawget(tbl, "id") or (type(parentKey) == "string" and parentKey or nil)
    local hasThumb = rawget(tbl, "thumbnail") or rawget(tbl, "icon") or rawget(tbl, "Icon") or rawget(tbl, "tiers") or rawget(tbl, "huge") or rawget(tbl, "titanic")
    if type(selfId) == "string" and hasThumb then
        registerDirectoryEntry(selfId, tbl)
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" and k ~= "_script" then
            walkDirectoryTree(v, k, (depth or 0) + 1)
        end
    end
end

local function scanDirectoryFast()
    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local dirMod = lib and lib:FindFirstChild("Directory")
        if dirMod then
            local okReq, dir = pcall(require, dirMod)
            if okReq and type(dir) == "table" then
                walkDirectoryTree(dir, nil, 0)
            end
        end
    end)
    pcall(function()
        local rawDir = ReplicatedStorage:FindFirstChild("__DIRECTORY") or ReplicatedStorage:FindFirstChild("Directory")
        if rawDir then
            for _, mod in ipairs(rawDir:GetDescendants()) do
                if mod:IsA("ModuleScript") then
                    local okM, mData = pcall(require, mod)
                    if okM and type(mData) == "table" then
                        walkDirectoryTree(mData, mod.Name, 1)
                    end
                end
            end
        end
    end)
    if getgc then
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    local id = rawget(v, "_id") or rawget(v, "id")
                    if type(id) == "string" and (rawget(v, "thumbnail") or rawget(v, "icon") or rawget(v, "tiers") or rawget(v, "huge") or rawget(v, "titanic")) then
                        registerDirectoryEntry(id, v)
                    end
                end
            end
        end)
    end
end
scanDirectoryFast()

task.spawn(function()
    local url = "https://thumbnails.roproxy.com/v1/users/avatar-headshot?userIds=" .. tostring(LocalPlayer.UserId) .. "&size=150x150&format=Png&isCircular=true"
    local code, body = doHttp(url, "GET")
    if code == 200 and body ~= "" then
        pcall(function()
            local decoded = HttpService:JSONDecode(body)
            if decoded and type(decoded.data) == "table" and decoded.data[1] and decoded.data[1].imageUrl then
                PlayerAvatarUrl = decoded.data[1].imageUrl
            end
        end)
    end
end)

local function getItemPriorityScore(it)
    local idLow = string.lower(tostring(it.id or ""))
    local tier = tonumber(it.tier) or 1
    local pt = tonumber(it.pt) or 0
    local sh = it.sh and 1 or 0
    local varBonus = (pt == 2 and 3000 or (pt == 1 and 1000 or 0)) + (sh == 1 and 2000 or 0)

    if tier == 4 or string.find(idLow, "titanic") then
        return 1000000000 + varBonus + (it.am or 1)
    elseif tier == 3 or string.find(idLow, "huge") then
        return 500000000 + varBonus + (it.am or 1)
    elseif tier == 2 or string.find(idLow, "exclusive") then
        return 200000000 + varBonus + (it.am or 1)
    end

    local isEvent = string.find(idLow, "headless") or string.find(idLow, "dominus") or string.find(idLow, "wendigo") or
                    string.find(idLow, "grinning") or string.find(idLow, "goat") or string.find(idLow, "halloween") or
                    string.find(idLow, "reaper") or string.find(idLow, "spooky") or string.find(idLow, "pumpkin")
    if it.cat == "Pet" and (isEvent or (it.pwr or 0) > 0) then
        return 100000000 + (it.pwr or 5000) + varBonus + math.min(999999, it.am or 1)
    elseif it.cat == "Pet" then
        return 50000000 + varBonus + math.min(999999, it.am or 1)
    elseif it.cat == "Egg" or it.cat == "Lootbox" or it.cat == "Box" then
        return 10000000 + math.min(999999, it.am or 1)
    end
    return math.min(9999999, it.am or 1)
end

local RomanNumerals = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }

local function collectFullInventory()
    local groupedByKey = {}
    local seenUids = {}
    local diamonds = 0
    local lollipops = 0
    local hugeCount = 0

    local function processSingleItem(catName, uid, obj)
        if type(obj) ~= "table" then return end
        local uidStr = tostring(uid)
        if seenUids[uidStr] then return end

        local d = rawget(obj, "_data")
        if type(d) ~= "table" then
            pcall(function()
                if type(obj._data) == "table" then d = obj._data end
            end)
        end
        if type(d) ~= "table" then d = obj end

        if catName == "Box" then
            local boxItems = rawget(d, "bi") or rawget(d, "items") or rawget(obj, "bi")
            if type(boxItems) == "table" then
                for bCat, bTab in pairs(boxItems) do
                    if type(bTab) == "table" then
                        for bUid, bObj in pairs(bTab) do
                            processSingleItem(tostring(bCat), bUid, bObj)
                        end
                    end
                end
            end
        end

        local idVal = rawget(d, "id") or rawget(d, "Id") or rawget(d, "_id") or rawget(obj, "id")
        if type(idVal) ~= "string" then
            pcall(function()
                idVal = d.id or obj.id or (type(obj.GetId) == "function" and obj:GetId())
            end)
        end
        if type(idVal) ~= "string" or idVal == "" then return end

        seenUids[uidStr] = true

        local amt = tonumber(rawget(d, "_am") or rawget(d, "amount") or rawget(obj, "_am") or rawget(obj, "amount"))
        if not amt then
            pcall(function() amt = tonumber(d._am or d.amount or obj._am or obj.amount) end)
        end
        amt = (amt and amt > 0) and math.floor(amt) or 1

        local pt = tonumber(rawget(d, "pt") or rawget(obj, "pt")) or 0
        local sh = (rawget(d, "sh") == true) or (rawget(obj, "sh") == true)
        local tn = tonumber(rawget(d, "tn") or rawget(obj, "tn"))

        local idLow = string.lower(idVal)
        if catName == "Currency" then
            if idLow == "diamonds" and amt > diamonds then
                diamonds = amt
            elseif (string.find(idLow, "lollipop") or string.find(idLow, "candy")) and amt > lollipops then
                lollipops = amt
            end
            return
        end

        if string.find(idLow, "lollipop") and amt > lollipops then
            lollipops = amt
        end

        local dInfo = DirectoryInfoCache[idLow]
        local aid = nil
        local tier = 1
        local pwr = 0

        if dInfo then
            if tn and dInfo.tierIcons and dInfo.tierIcons[tn] then
                aid = dInfo.tierIcons[tn]
            elseif pt == 1 and dInfo.goldAid then
                aid = dInfo.goldAid
            else
                aid = dInfo.aid
            end
            tier = dInfo.tier or 1
            pwr = dInfo.pwr or 0
        end

        if string.find(idLow, "titanic") then
            tier = 4
        elseif string.find(idLow, "huge") then
            tier = 3
        elseif tier < 2 and string.find(idLow, "exclusive") then
            tier = 2
        end

        if tier >= 3 then
            hugeCount = hugeCount + amt
        end

        local displayName = idVal
        if tn and tn >= 1 then
            local roman = RomanNumerals[tn] or tostring(tn)
            displayName = idVal .. " " .. roman
        end

        local groupKey = tostring(catName) .. "|" .. displayName .. "|" .. tostring(pt) .. "|" .. tostring(sh)
        local existing = groupedByKey[groupKey]
        if not existing then
            groupedByKey[groupKey] = {
                uid = uidStr,
                uids = { uidStr },
                id = displayName,
                cat = tostring(catName),
                am = amt,
                pt = pt,
                sh = sh,
                aid = aid,
                tier = tier,
                pwr = pwr
            }
        else
            existing.am = existing.am + amt
            if not existing.aid and aid then existing.aid = aid end
            if #existing.uids < 60 then
                table.insert(existing.uids, uidStr)
            end
        end
    end

    local function processInventoryTable(inv)
        if type(inv) ~= "table" then return end
        for catName, catTab in pairs(inv) do
            if type(catName) == "string" and type(catTab) == "table" then
                for uid, obj in pairs(catTab) do
                    processSingleItem(catName, uid, obj)
                end
            end
        end
    end

    pcall(function()
        local lib = ReplicatedStorage:FindFirstChild("Library")
        local client = lib and lib:FindFirstChild("Client")
        local saveMod = client and client:FindFirstChild("Save")
        if saveMod then
            local okS, saveObj = pcall(require, saveMod)
            if okS and type(saveObj) == "table" then
                if type(saveObj.Get) == "function" then
                    local okD, saveData = pcall(saveObj.Get)
                    if okD and type(saveData) == "table" then
                        processInventoryTable(rawget(saveData, "Inventory") or saveData.Inventory)
                        local mSends = tonumber(rawget(saveData, "MailboxSends") or saveData.MailboxSends)
                        if mSends and mSends > SessionMailSends then
                            SessionMailSends = mSends
                        end
                    end
                end
                if type(saveObj.GetSaves) == "function" then
                    local okAll, allSaves = pcall(saveObj.GetSaves)
                    if okAll and type(allSaves) == "table" then
                        for _, sData in pairs(allSaves) do
                            if type(sData) == "table" then
                                processInventoryTable(rawget(sData, "Inventory") or sData.Inventory)
                            end
                        end
                    end
                end
            end
        end
    end)

    if getgc then
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    local testInv = rawget(v, "Inventory")
                    if type(testInv) == "table" and (type(rawget(testInv, "Pet")) == "table" or type(rawget(testInv, "Misc")) == "table") then
                        processInventoryTable(testInv)
                    elseif type(rawget(v, "Pet")) == "table" and (type(rawget(v, "Misc")) == "table" or type(rawget(v, "Enchant")) == "table" or type(rawget(v, "Potion")) == "table") then
                        processInventoryTable(v)
                    end
                end
            end
        end)
    end

    local itemsList = {}
    for _, item in pairs(groupedByKey) do
        if #item.uids <= 1 then
            item.uids = nil
        end
        table.insert(itemsList, item)
    end

    table.sort(itemsList, function(a, b)
        return getItemPriorityScore(a) > getItemPriorityScore(b)
    end)

    if #itemsList > 500 then
        local trimmed = {}
        for i = 1, 500 do trimmed[i] = itemsList[i] end
        itemsList = trimmed
    end

    return itemsList, diamonds, lollipops, hugeCount
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
    local uidsList = type(taskData.uids) == "table" and taskData.uids or nil
    local itemId = tostring(taskData.item_id or "")
    local amount = math.max(1, math.floor(tonumber(taskData.amount) or 1))
    local msg = tostring(taskData.message or "Gift")

    if StatusLabelRef then
        StatusLabelRef.Text = "📮 Отправка: " .. itemId .. " x" .. tostring(amount) .. " -> " .. recipient
    end

    local mailRemote = findMailboxSendRemote()
    local success = false
    local packetsSent = 0
    local resultMsg = "Remote Mailbox: Send не найден"

    if mailRemote then
        if uidsList and #uidsList > 1 then
            local toSendCount = math.min(#uidsList, amount)
            local lastErr = nil
            for i = 1, toSendCount do
                local targetUid = tostring(uidsList[i])
                local ok, r1, r2 = pcall(function()
                    if mailRemote:IsA("RemoteFunction") then
                        return mailRemote:InvokeServer(recipient, msg, category, targetUid, 1)
                    else
                        mailRemote:FireServer(recipient, msg, category, targetUid, 1)
                        return true
                    end
                end)
                if ok and r1 == true then
                    packetsSent = packetsSent + 1
                    SessionMailSends = SessionMailSends + 1
                else
                    lastErr = tostring(r2 or r1 or "Ошибка")
                    break
                end
                if i < toSendCount then
                    task.wait(1.2)
                end
            end
            if packetsSent > 0 then
                success = true
                resultMsg = string.format("Отправлено %d/%d шт. игроку %s!", packetsSent, toSendCount, recipient)
            else
                success = false
                resultMsg = tostring(lastErr or "Не удалось отправить (проверьте алмазы 20K/30K+)")
            end
        else
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
                packetsSent = 1
                SessionMailSends = SessionMailSends + 1
                resultMsg = "Успешно отправлено игроку " .. recipient .. "!"
            else
                success = false
                resultMsg = tostring(r2 or r1 or "Ошибка отправки (проверьте алмазы 20K/30K+)")
            end
        end
    end

    if StatusLabelRef then
        StatusLabelRef.Text = success and ("✅ Отправлено -> " .. recipient) or ("❌ Ошибка: " .. resultMsg)
    end

    local nextCost = math.floor(20000 * (1.5 ^ SessionMailSends))
    local replyPayload = HttpService:JSONEncode({
        type = "mail_result",
        task_id = tid,
        sender = LocalPlayer.Name,
        recipient = recipient,
        category = category,
        item_id = itemId,
        amount = amount,
        packets_sent = packetsSent,
        mail_cost = nextCost,
        status = success and "sent" or "failed",
        result_text = resultMsg,
        ts = os.time()
    })
    doHttp("https://ntfy.sh/" .. TopicCmd, "POST", { ["Content-Type"] = "application/json" }, replyPayload)
end

local function syncStateToCloud()
    local items, diamonds, lollipops, hugeCount = collectFullInventory()
    if StatusLabelRef then
        local curCost = math.floor(20000 * (1.5 ^ SessionMailSends))
        StatusLabelRef.Text = string.format("🟢 Хугов: %d | Видов: %d | 💎 Почта: %dK", hugeCount, #items, math.floor(curCost / 1000))
    end
    local payload = HttpService:JSONEncode({
        username = LocalPlayer.Name,
        user_id = LocalPlayer.UserId,
        avatar_url = PlayerAvatarUrl,
        diamonds = diamonds,
        lollipops = lollipops,
        mail_sends = SessionMailSends,
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
                        task.wait(0.3)
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
StatusLbl.Text = "⚡ Сканирование всех Хугов и предметов..."
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
    pcall(syncStateToCloud)
    local lastFullSync = tick()
    while CloudRunning do
        task.wait(3.0)
        pcall(pollCloudCommands)
        if tick() - lastFullSync >= 12 then
            lastFullSync = tick()
            pcall(syncStateToCloud)
        end
    end
end)
