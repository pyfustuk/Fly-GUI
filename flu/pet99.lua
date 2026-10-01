

local WS         = game:GetService("Workspace")
local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local RunS       = game:GetService("RunService")
local RepS       = game:GetService("ReplicatedStorage")
local Lighting   = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

-- Ожидание загрузки игрока
local player = Players.LocalPlayer
if not player then
    repeat
        task.wait(0.1)
        player = Players.LocalPlayer
    until player
end

local camera = WS.CurrentCamera or WS:WaitForChild("Camera", 5)

-- ======================== БЕЗОПАСНЫЙ ПОИСК РОДИТЕЛЯ GUI ========================
local function getGuiParent()
    local parent = nil
    pcall(function()
        if gethui then parent = gethui() end
    end)
    if not parent then
        pcall(function()
            local cg = game:GetService("CoreGui")
            local _ = cg.Name
            parent = cg
        end)
    end
    if not parent then
        pcall(function()
            parent = player:WaitForChild("PlayerGui", 5) or player:FindFirstChild("PlayerGui")
        end)
    end
    return parent
end

-- Полная очистка старых окон
local function cleanPrevious()
    pcall(function()
        if _G.Pufyftyk_Cleanup then
            _G.Pufyftyk_Cleanup()
        end
    end)
    pcall(function()
        if _G.Pufyftyk_Hub_Instance then
            _G.Pufyftyk_Hub_Instance:Destroy()
            _G.Pufyftyk_Hub_Instance = nil
        end
    end)

    local containers = {}
    pcall(function() if gethui then table.insert(containers, gethui()) end end)
    pcall(function() table.insert(containers, game:GetService("CoreGui")) end)
    pcall(function() if player and player:FindFirstChild("PlayerGui") then table.insert(containers, player.PlayerGui) end end)

    for _, c in ipairs(containers) do
        pcall(function()
            for _, child in ipairs(c:GetChildren()) do
                local nm = string.lower(tostring(child.Name))
                if string.find(nm, "pufyftyk") or string.find(nm, "orehub") or string.find(nm, "darkoverlay") or string.find(nm, "zaphub") then
                    pcall(function() child:Destroy() end)
                elseif child:IsA("ScreenGui") and (child:FindFirstChild("MainWindow") or child:FindFirstChild("BlackScreenOverlay")) then
                    pcall(function() child:Destroy() end)
                end
            end
        end)
    end
end
cleanPrevious()

-- ======================== СЕТЕВЫЕ РЕМОУТЫ PS99 ========================
local net = RepS:FindFirstChild("Network") or RepS:WaitForChild("Network", 4)
local remTarget          = net and net:FindFirstChild("BlockWorlds_Target")
local remBreak           = net and net:FindFirstChild("BlockWorlds_Break")
local remBreakables      = net and net:FindFirstChild("Breakables_PlayerDealDamage")
local remBlockWorlds     = net and net:FindFirstChild("BlockWorlds")
local remInstancing      = net and net:FindFirstChild("Instancing_FireCustomFromClient")
local remAutoMineEnable  = net and (net:FindFirstChild("AutoMine_Enable") or net:FindFirstChild("AutoMine") or net:FindFirstChild("AutoDig_Enable") or net:FindFirstChild("AutoDig"))
local remAutoMineToggle  = net and (net:FindFirstChild("AutoMine_Toggle") or net:FindFirstChild("AutoFarm_Toggle"))
local remAutoMineDisable = net and net:FindFirstChild("AutoMine_Disable")

-- ======================== КОНФИГУРАЦИЯ ========================
local userCfg = (typeof(getgenv) == "function" and typeof(getgenv().PufyftykConfig) == "table") and getgenv().PufyftykConfig or {}

local function opt(val, def)
    if val == nil then return def end
    return val
end

local cfg = {
    dwell              = userCfg.dwell or 0.02,        -- пауза после ТП (с)
    maxBreakTime       = userCfg.maxBreakTime or 15.0,  -- макс. время на руду (с)
    yOffset            = userCfg.yOffset or 2.2,       -- высота над рудой при ТП
    maxDist            = userCfg.maxDist or 2500,      -- радиус поиска руд
    scanTime           = userCfg.scanTime or 25.0,     -- авто-обновление руд (с)
    spamTp             = opt(userCfg.spamTp, true),    -- спам-ТП фиксация над рудой
    spamInterval       = userCfg.spamInterval or 0.08, -- интервал спам-ТП (с)
    toolSwing          = opt(userCfg.toolSwing, true), -- взмахи киркой (Activate)
    aimAtOre           = opt(userCfg.aimAtOre, true),  -- прицел на руду
    autoPrioritizeRare = opt(userCfg.autoPrioritizeRare, true),
    useGameAutoMine    = opt(userCfg.useGameAutoMine, true), -- официальный AutoMine игры!
    autoKey1           = opt(userCfg.autoKey1, true),  -- авто-прожатие [1]
    key1Interval       = userCfg.key1Interval or 15.0, -- интервал [1] (с)
    autoKey2           = opt(userCfg.autoKey2, true),  -- авто-прожатие [2]
    key2Interval       = userCfg.key2Interval or 30.0, -- интервал [2] (с)
    noclip             = opt(userCfg.noclip, true),    -- ноклип
    freeCam            = opt(userCfg.freeCam, false),
    espOn              = opt(userCfg.espOn, true),     -- ESP руд
    espText            = opt(userCfg.espText, true),   -- текстовые метки ESP
    espHighlights      = opt(userCfg.espHighlights, true), -- 3D подсветка (до 12 шт)
    espTransp          = userCfg.espTransp or 0.45,
    espMaxCount        = userCfg.espMaxCount or 25,    -- макс. меток ESP
    autoBreak          = opt(userCfg.autoBreak, true), -- авто-добыча
    fpsCap30           = opt(userCfg.fpsCap30, false),
    potatoMode         = opt(userCfg.potatoMode, false),-- картофельная графика
    darkScreen         = opt(userCfg.darkScreen, false),-- затемнение
    render3dOff        = opt(userCfg.render3dOff, false),-- черный экран (3D OFF)
    antiAfk            = opt(userCfg.antiAfk, true),   -- безопасный анти-афк
}

local priorityOrder    = {}
local selected         = {}
local allIds           = {}
local route            = {}
local highlights       = {}
local minedStats       = {}
local totalMinedCount  = 0
local sessionStartTime = tick()
local updateStatsUI    = nil
local syncScanTimeSettings = nil
local scanTimeBox      = nil

local function recordMinedOre(id)
    if not id then return end
    minedStats[id] = (minedStats[id] or 0) + 1
    totalMinedCount = totalMinedCount + 1
    if updateStatsUI then
        pcall(updateStatsUI)
    end
end

local brokenOres     = {}
local farmOn, paused = false, false
local currentTarget  = nil
local connections    = {}
local potatoTask     = nil
local win            = nil
local blackOverlay   = nil

local function getTargetBasePart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local rareKeywords = {
    "chest", "huge", "magic", "golden", "gold", "diamond",
    "emerald", "rainbow", "amethyst", "ruby", "sapphire",
    "obsidian", "tnt", "bomb", "corrupt", "vault", "relic", "lucky"
}

local function isRareOre(id)
    if not id then return false end
    local lower = string.lower(tostring(id))
    for _, kw in ipairs(rareKeywords) do
        if string.find(lower, kw, 1, true) then
            return true
        end
    end
    return false
end

-- Сохранение оригинального освещения
local origLighting = {}
pcall(function()
    origLighting.Brightness = Lighting.Brightness
    origLighting.GlobalShadows = Lighting.GlobalShadows
    origLighting.Ambient = Lighting.Ambient
    origLighting.OutdoorAmbient = Lighting.OutdoorAmbient
    origLighting.ExposureCompensation = Lighting.ExposureCompensation
    origLighting.ClockTime = Lighting.ClockTime
end)

local planSmartRoute, rebuildOreList, rebuildBlockList, applyESP, clearESP, updStatus, setGameAutoMine

-- ======================== ФУНКЦИЯ ОЧИСТКИ ========================
_G.Pufyftyk_Cleanup = function()
    _G.Pufyftyk_Loaded = false
    farmOn = false
    paused = false
    if potatoTask then pcall(function() task.cancel(potatoTask) end); potatoTask = nil end
    for _, c in pairs(connections) do
        if c and typeof(c) == "RBXScriptConnection" then
            pcall(function() c:Disconnect() end)
        end
    end
    pcall(function()
        if origLighting.Brightness then Lighting.Brightness = origLighting.Brightness end
        if origLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = origLighting.GlobalShadows end
        if origLighting.Ambient then Lighting.Ambient = origLighting.Ambient end
        if origLighting.OutdoorAmbient then Lighting.OutdoorAmbient = origLighting.OutdoorAmbient end
        if origLighting.ExposureCompensation then Lighting.ExposureCompensation = origLighting.ExposureCompensation end
        if origLighting.ClockTime then Lighting.ClockTime = origLighting.ClockTime end
        RunS:Set3dRenderingEnabled(true)
    end)
    if blackOverlay then blackOverlay.Visible = false end
    if clearESP then pcall(clearESP) end
    cleanPrevious()
end
_G.Pufyftyk_Loaded = true

-- ======================== ПРОВЕРКА РУДЫ НА ЖИЗНЬ ========================
local function isAlive(inst)
    if not inst or not inst.Parent then return false end
    if not inst:IsDescendantOf(WS) then return false end
    if brokenOres[inst] then return false end

    if inst:GetAttribute("Broken") == true or inst:GetAttribute("Dead") == true or inst:GetAttribute("Destroyed") == true then
        return false
    end

    local hp = inst:GetAttribute("health") or inst:GetAttribute("hp") or inst:GetAttribute("Health")
    if hp and type(hp) == "number" and hp <= 0 then return false end

    if inst:IsA("BasePart") then
        if inst.Transparency >= 0.99 then return false end
    elseif inst:IsA("Model") then
        local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        if not p or p.Transparency >= 0.99 then return false end
    end

    return true
end

-- ======================== ОПТИМИЗАЦИЯ И КАРТОФЕЛЬНАЯ ГРАФИКА ========================
local function setFpsLimit(fps)
    pcall(function()
        if setfpscap then setfpscap(fps) end
    end)
end

local function applyDarkScreen(enable)
    pcall(function()
        if enable then
            Lighting.Brightness = 1.1
            Lighting.ClockTime = 18
            Lighting.Ambient = Color3.fromRGB(90, 95, 110)
            Lighting.OutdoorAmbient = Color3.fromRGB(90, 95, 110)
            Lighting.ExposureCompensation = -0.3
        else
            if origLighting.Brightness then
                Lighting.Brightness = origLighting.Brightness
                Lighting.ClockTime = origLighting.ClockTime
                Lighting.Ambient = origLighting.Ambient
                Lighting.OutdoorAmbient = origLighting.OutdoorAmbient
                Lighting.ExposureCompensation = origLighting.ExposureCompensation
            end
        end
    end)
end

-- ПРОВЕРКА: РУДА ИЛИ БЛОК ШАХТЫ (ЧТОБЫ КАРТОШКА ИХ НЕ ПОРТИЛА!)
local function isOreOrMineBlock(v)
    if not v then return false end
    if v:GetAttribute("id") ~= nil or v:GetAttribute("Ore") ~= nil or v:GetAttribute("Type") ~= nil then
        return true
    end
    if v.Parent and (v.Parent:GetAttribute("id") ~= nil or v.Parent:GetAttribute("Ore") ~= nil) then
        return true
    end
    if v.Parent and v.Parent.Parent and v.Parent.Parent:GetAttribute("id") ~= nil then
        return true
    end

    local things = WS:FindFirstChild("__THINGS")
    if things then
        local bw = things:FindFirstChild("BlockWorlds")
        if bw and v:IsDescendantOf(bw) then return true end
        local br = things:FindFirstChild("Breakables")
        if br and v:IsDescendantOf(br) then return true end
        local ds = things:FindFirstChild("Digsite")
        if ds and v:IsDescendantOf(ds) then return true end
        local ic = things:FindFirstChild("__INSTANCE_CONTAINER")
        if ic and v:IsDescendantOf(ic) then return true end
    end

    local pName = v.Parent and v.Parent.Name or ""
    if string.find(pName, "Blocks_") or string.find(pName, "BlockWorld") then
        return true
    end

    return false
end

-- КАРТОФЕЛЬНАЯ ОБРАБОТКА ДЕКОРАЦИЙ ЛОКАЦИИ
local function makePotatoPart(v)
    if not v or not v.Parent then return end
    if player.Character and v:IsDescendantOf(player.Character) then return end

    -- НЕ ТРОГАЕМ РУДЫ И БЛОКИ ШАХТЫ!
    if isOreOrMineBlock(v) then return end

    -- Убираем текстуры и эффекты с декораций карты
    if v:IsA("BasePart") and not v:IsA("Terrain") then
        v.Material = Enum.Material.SmoothPlastic
        v.CastShadow = false
        v.Reflectance = 0
        if v:IsA("MeshPart") then
            v.TextureID = ""
        end
    elseif v:IsA("SurfaceAppearance") then
        pcall(function() v:Destroy() end)
    elseif v:IsA("Decal") or v:IsA("Texture") then
        if not v:FindFirstAncestorOfClass("ScreenGui") and not v:FindFirstAncestorOfClass("BillboardGui") then
            v.Transparency = 1
        end
    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("Beam") then
        v.Enabled = false
    elseif v:IsA("Light") then
        v.Enabled = false
    end
end

local function applyPotatoGraphics(enable)
    if enable then
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
        pcall(function()
            WS.GlobalShadows = false
            Lighting.GlobalShadows = false
            if WS.Terrain then
                WS.Terrain.Decoration = false
                WS.Terrain.WaterWaveSize = 0
                WS.Terrain.WaterWaveSpeed = 0
                WS.Terrain.WaterReflectance = 0
            end
        end)
        pcall(function()
            for _, eff in ipairs(Lighting:GetChildren()) do
                if eff:IsA("PostEffect") or eff:IsA("Atmosphere") or eff:IsA("BloomEffect")
                    or eff:IsA("DepthOfFieldEffect") or eff:IsA("SunRaysEffect") or eff:IsA("ColorCorrectionEffect") or eff:IsA("BlurEffect") then
                    eff.Enabled = false
                end
            end
        end)

        if potatoTask then task.cancel(potatoTask) end
        potatoTask = task.spawn(function()
            local all = WS:GetDescendants()
            for i = 1, #all do
                if not cfg.potatoMode then break end
                pcall(makePotatoPart, all[i])
                if i % 250 == 0 then
                    task.wait()
                end
            end
        end)

        if not connections.PotatoWatcher then
            connections.PotatoWatcher = WS.DescendantAdded:Connect(function(v)
                if cfg.potatoMode then
                    pcall(makePotatoPart, v)
                end
            end)
        end
    else
        if potatoTask then task.cancel(potatoTask); potatoTask = nil end
        if connections.PotatoWatcher then
            pcall(function() connections.PotatoWatcher:Disconnect() end)
            connections.PotatoWatcher = nil
        end
        pcall(function()
            WS.GlobalShadows = true
            Lighting.GlobalShadows = true
            if WS.Terrain then WS.Terrain.Decoration = true end
            for _, eff in ipairs(Lighting:GetChildren()) do
                if eff:IsA("PostEffect") or eff:IsA("BloomEffect")
                    or eff:IsA("DepthOfFieldEffect") or eff:IsA("SunRaysEffect") or eff:IsA("ColorCorrectionEffect") then
                    eff.Enabled = true
                end
            end
        end)
    end
end

-- ======================== ЧЁРНЫЙ ЭКРАН 3D OFF (С ЖИВОЙ СТАТИСТИКОЙ) ========================
local function applyRender3d(enableOff)
    pcall(function()
        RunS:Set3dRenderingEnabled(not enableOff)
    end)
    if blackOverlay then
        blackOverlay.Visible = enableOff
    end
end

if cfg.fpsCap30 then setFpsLimit(30) end
if cfg.potatoMode then applyPotatoGraphics(true) end
if cfg.darkScreen then applyDarkScreen(true) end

-- ======================== NOCLIP (БЕЗ ЛАГОВ) ========================
local charParts = {}
local function updateCharCache()
    charParts = {}
    local char = player.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                table.insert(charParts, p)
            end
        end
    end
end
player.CharacterAdded:Connect(updateCharCache)
updateCharCache()

local function setCameraMode(isFree)
    pcall(function()
        if isFree then
            player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
        else
            player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
        end
    end)
end
setCameraMode(cfg.freeCam)

local function setCharacterCollision(canCollide)
    for _, p in ipairs(charParts) do
        if p and p.Parent then
            pcall(function() p.CanCollide = canCollide end)
        end
    end
end

connections.Noclip = RunS.Stepped:Connect(function()
    if cfg.noclip and farmOn and not paused then
        for i = 1, #charParts do
            local p = charParts[i]
            if p and p.Parent and p.CanCollide then
                p.CanCollide = false
            end
        end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end)

-- ПРИЦЕЛ НА РУДУ
connections.Aimbot = RunS.RenderStepped:Connect(function()
    if farmOn and not paused and cfg.aimAtOre and currentTarget and currentTarget.pos then
        if isAlive(currentTarget.inst) then
            pcall(function()
                local cam = WS.CurrentCamera
                if cam then
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, currentTarget.pos)
                end
            end)
        end
    end
end)

-- ======================== СКАНЕР И МАРШРУТ ========================
local function getAllMiningDescendants()
    local descendants = {}
    local things = WS:FindFirstChild("__THINGS")
    local searchRoots = {}
    if things then
        local bw = things:FindFirstChild("BlockWorlds")
        if bw then table.insert(searchRoots, bw) end
        local br = things:FindFirstChild("Breakables")
        if br then table.insert(searchRoots, br) end
        local ds = things:FindFirstChild("Digsite")
        if ds then table.insert(searchRoots, ds) end
        local ic = things:FindFirstChild("__INSTANCE_CONTAINER")
        local act = ic and ic:FindFirstChild("Active")
        if act then
            for _, ch in ipairs(act:GetChildren()) do
                local imp = ch:FindFirstChild("Important")
                if imp then
                    if imp:FindFirstChild("ActiveBlocks") then table.insert(searchRoots, imp.ActiveBlocks) end
                    if imp:FindFirstChild("ActiveChests") then table.insert(searchRoots, imp.ActiveChests) end
                end
                table.insert(searchRoots, ch)
            end
        end
    end
    if #searchRoots == 0 then
        local bw = WS:FindFirstChild("BlockWorlds", true) or WS:FindFirstChild("Breakables", true)
        if bw then table.insert(searchRoots, bw) end
    end
    for _, root in ipairs(searchRoots) do
        for _, d in ipairs(root:GetDescendants()) do
            table.insert(descendants, d)
        end
    end
    return descendants
end

local function getBlockWorlds()
    local t = WS:FindFirstChild("__THINGS")
    if t then
        local bw = t:FindFirstChild("BlockWorlds") or t:FindFirstChild("BlockWorlds", true) or t:FindFirstChild("Breakables") or t:FindFirstChild("Digsite")
        if bw then return bw end
    end
    return WS:FindFirstChild("BlockWorlds", true) or WS:FindFirstChild("Breakables", true)
end

local function getOreId(inst)
    if not inst then return nil end
    local v = inst:GetAttribute("id")
    if type(v) == "string" and #v > 0 then return v end
    local v2 = inst:GetAttribute("Ore") or inst:GetAttribute("Type")
    if type(v2) == "string" and #v2 > 0 then return v2 end
    local nm = tostring(inst.Name)
    local lowerNm = string.lower(nm)
    if string.find(lowerNm, "crate") or string.find(lowerNm, "chest") or string.find(lowerNm, "ore") then
        return nm
    end
    return nil
end

local function markOreBroken(inst)
    if not inst then return end
    brokenOres[inst] = true
    pcall(function()
        if inst:IsA("Model") then
            for _, child in ipairs(inst:GetDescendants()) do
                brokenOres[child] = true
            end
        end
    end)
end

local function isOreObject(inst)
    if not inst or brokenOres[inst] then return false end
    if inst:IsA("BasePart") and inst.Parent and inst.Parent:IsA("Model") and inst.Parent ~= WS then
        if getOreId(inst.Parent) ~= nil or brokenOres[inst.Parent] then
            return false
        end
    end
    return (inst:IsA("BasePart") or inst:IsA("Model")) and (getOreId(inst) ~= nil) and isAlive(inst)
end

local function getObjectPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then
        return inst.Position
    elseif inst:IsA("Model") then
        local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        if p then return p.Position end
    end
    return nil
end

-- Управление приоритетами
addOrTogglePriority = function(id)
    local foundIdx = nil
    for i, v in ipairs(priorityOrder) do
        if v == id then foundIdx = i; break end
    end
    if foundIdx then
        table.remove(priorityOrder, foundIdx)
    else
        table.insert(priorityOrder, id)
    end
    selected = {}
    for rank, oId in ipairs(priorityOrder) do
        selected[oId] = rank
    end
    planSmartRoute()
    if rebuildOreList then rebuildOreList() end
    if rebuildBlockList then rebuildBlockList() end
    if updStatus then updStatus() end
    if cfg.espOn and applyESP then applyESP() end
end

removePriority = function(id)
    for i, v in ipairs(priorityOrder) do
        if v == id then
            table.remove(priorityOrder, i)
            break
        end
    end
    selected = {}
    for rank, oId in ipairs(priorityOrder) do
        selected[oId] = rank
    end
    planSmartRoute()
    if rebuildOreList then rebuildOreList() end
    if rebuildBlockList then rebuildBlockList() end
    if updStatus then updStatus() end
    if cfg.espOn and applyESP then applyESP() end
end

clearAllPriority = function()
    priorityOrder = {}
    selected = {}
    planSmartRoute()
    if rebuildOreList then rebuildOreList() end
    if rebuildBlockList then rebuildBlockList() end
    if updStatus then updStatus() end
    if clearESP then clearESP() end
end

autoSetRarePriority = function()
    priorityOrder = {}
    selected = {}
    local rareList = {}
    for id in pairs(allIds) do
        if isRareOre(id) then
            table.insert(rareList, id)
        end
    end
    table.sort(rareList, function(a, b)
        local la, lb = string.lower(a), string.lower(b)
        local function score(s)
            if string.find(s, "huge") or string.find(s, "chest") then return 100 end
            if string.find(s, "rainbow") then return 90 end
            if string.find(s, "diamond") then return 80 end
            if string.find(s, "emerald") then return 70 end
            if string.find(s, "amethyst") or string.find(s, "ruby") or string.find(s, "sapphire") then return 60 end
            if string.find(s, "gold") then return 50 end
            if string.find(s, "tnt") or string.find(s, "bomb") then return 40 end
            return 10
        end
        return score(la) > score(lb)
    end)
    for _, id in ipairs(rareList) do
        table.insert(priorityOrder, id)
    end
    for rank, oId in ipairs(priorityOrder) do
        selected[oId] = rank
    end
    planSmartRoute()
    if rebuildOreList then rebuildOreList() end
    if rebuildBlockList then rebuildBlockList() end
    if updStatus then updStatus() end
    if cfg.espOn and applyESP then applyESP() end
end

planSmartRoute = function()
    allIds = {}
    local char = player.Character
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    local origin = hrp and hrp.Position or Vector3.zero

    local descendants = getAllMiningDescendants()
    if #descendants == 0 then route = {} return end
    local oreMap = {}
    local seen = {}
    local anyList = {}

    for i = 1, #descendants do
        local d = descendants[i]
        local isPart = d:IsA("BasePart")
        local isModel = not isPart and d:IsA("Model")
        if isPart or isModel then
            local id = getOreId(d)
            if id and not seen[d] and not brokenOres[d] then
                local skip = false
                if isPart and d.Parent and d.Parent:IsA("Model") and d.Parent ~= WS then
                    if getOreId(d.Parent) ~= nil or brokenOres[d.Parent] then
                        skip = true
                    end
                end
                if not skip and isAlive(d) then
                    seen[d] = true
                    allIds[id] = (allIds[id] or 0) + 1
                    local p = getObjectPos(d)
                    if p then
                        local dist = (p - origin).Magnitude
                        if dist <= cfg.maxDist then
                            if selected[id] then
                                oreMap[id] = oreMap[id] or {}
                                table.insert(oreMap[id], { inst = d, pos = p, id = id, rank = selected[id] })
                            else
                                table.insert(anyList, { inst = d, pos = p, id = id, d = dist })
                            end
                        end
                    end
                end
            end
        end
    end

    local planned = {}
    local currPos = origin

    for rank, targetId in ipairs(priorityOrder) do
        local pool = oreMap[targetId]
        if pool and #pool > 0 then
            while #pool > 0 do
                local bestIdx = 1
                local bestDist = (pool[1].pos - currPos).Magnitude
                for i = 2, #pool do
                    local d = (pool[i].pos - currPos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestIdx = i
                    end
                end
                local nextTarget = table.remove(pool, bestIdx)
                nextTarget.d = (nextTarget.pos - origin).Magnitude
                table.insert(planned, nextTarget)
                currPos = nextTarget.pos
            end
        end
    end

    -- Если в зоне нет выбранных приоритетных руд — автоматически копаем ближайшие доступные блоки!
    if #planned == 0 then
        table.sort(anyList, function(a, b) return a.d < b.d end)
        for i = 1, math.min(30, #anyList) do
            table.insert(planned, anyList[i])
        end
    end

    route = planned
end

clearESP = function()
    for _, item in pairs(highlights) do
        if item and typeof(item) == "Instance" and item.Parent then
            pcall(function() item:Destroy() end)
        end
    end
    table.clear(highlights)
end

applyESP = function()
    clearESP()
    if not cfg.espOn then return end

    local count = 0
    local maxCount = math.clamp(cfg.espMaxCount or 25, 5, 40)

    local list = {}
    if #route > 0 then
        for _, b in ipairs(route) do table.insert(list, b) end
    else
        local bw = getBlockWorlds()
        if bw then
            local char = player.Character
            local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
            local orig = hrp and hrp.Position or Vector3.zero
            for _, d in ipairs(bw:GetDescendants()) do
                if isOreObject(d) then
                    local id = getOreId(d)
                    if selected[id] then
                        local p = getObjectPos(d)
                        if p and (p - orig).Magnitude <= cfg.maxDist then
                            table.insert(list, { inst = d, pos = p, id = id, d = (p - orig).Magnitude, rank = selected[id] })
                        end
                    end
                end
            end
            table.sort(list, function(a, b)
                local rA = a.rank or 999
                local rB = b.rank or 999
                if rA ~= rB then return rA < rB end
                return (a.d or 0) < (b.d or 0)
            end)
        end
    end

    local myPos = (player.Character and player.Character:GetPivot().Position) or Vector3.zero

    for _, b in ipairs(list) do
        if count >= maxCount then break end
        local d = b.inst
        if d and d.Parent and isAlive(d) then
            local rank = b.rank or selected[b.id]
            local isFirst = (rank == 1)
            local isTop = (rank and rank <= 3) or isRareOre(b.id)
            local espColor = isFirst and Color3.fromRGB(255, 215, 0)
                or (isTop and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(0, 229, 255))

            local pPart = d:IsA("BasePart") and d or (d:FindFirstChildWhichIsA("BasePart", true) or d.PrimaryPart)

            if cfg.espHighlights and count < 12 and pPart then
                pcall(function()
                    local hl = Instance.new("Highlight")
                    hl.Name = "OreHighlight"
                    hl.FillColor = espColor
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = cfg.espTransp or 0.45
                    hl.OutlineTransparency = 0.15
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Adornee = d
                    hl.Parent = d
                    table.insert(highlights, hl)
                end)
            end

            if cfg.espText and pPart then
                pcall(function()
                    local bb = Instance.new("BillboardGui")
                    bb.Name = "OreLabel"
                    bb.Adornee = pPart
                    bb.Size = UDim2.new(0, 120, 0, 22)
                    bb.StudsOffset = Vector3.new(0, 2.0, 0)
                    bb.AlwaysOnTop = true
                    bb.Parent = pPart

                    local bg = Instance.new("Frame")
                    bg.Size = UDim2.new(1, 0, 1, 0)
                    bg.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
                    bg.BackgroundTransparency = 0.25
                    bg.BorderSizePixel = 0
                    bg.Parent = bb
                    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 5)
                    local st = Instance.new("UIStroke", bg)
                    st.Color = espColor; st.Thickness = 1.1; st.Transparency = 0.3

                    local txt = Instance.new("TextLabel")
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.TextColor3 = espColor
                    txt.Font = Enum.Font.GothamBold
                    txt.TextSize = 9
                    local dist = b.d or (pPart.Position - myPos).Magnitude
                    local prefix = rank and (rank == 1 and "🥇 #1 " or (rank == 2 and "🥈 #2 " or (rank == 3 and "🥉 #3 " or string.format("#%d ", rank)))) or ""
                    txt.Text = string.format("%s%s [%dм]", prefix, b.id, math.floor(dist))
                    txt.Parent = bg

                    table.insert(highlights, bb)
                end)
            end

            count = count + 1
        end
    end
end

-- ======================== УПРАВЛЕНИЕ КИРКОЙ И AUTO-MINE ИГРЫ ========================
local function getPickaxe()
    local char = player.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    local bp = player:FindFirstChild("Backpack")
    local t = bp and bp:FindFirstChildOfClass("Tool")
    if t then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(t) end) end
        return t
    end
    return nil
end

-- ВКЛЮЧЕНИЕ / ВЫКЛЮЧЕНИЕ ВСТРОЕННОГО AUTO MINE ИГРЫ (ОФИЦИАЛЬНАЯ КНОПКА И РЕМОУТЫ)
setGameAutoMine = function(enable)
    -- 1. Вызов сетевых ремоутов игры
    if enable then
        if remAutoMineEnable then
            pcall(function() remAutoMineEnable:FireServer() end)
            pcall(function() remAutoMineEnable:FireServer(true) end)
        end
        if remAutoMineToggle then
            pcall(function() remAutoMineToggle:FireServer(true) end)
        end
    else
        if remAutoMineDisable then
            pcall(function() remAutoMineDisable:FireServer() end)
            pcall(function() remAutoMineDisable:FireServer(false) end)
        end
        if remAutoMineToggle then
            pcall(function() remAutoMineToggle:FireServer(false) end)
        end
    end

    -- 2. Ремоут инстанции (Space Mining Event / Digsite)
    if remInstancing then
        local things = WS:FindFirstChild("__THINGS")
        local ic = things and things:FindFirstChild("__INSTANCE_CONTAINER")
        local act = ic and ic:FindFirstChild("Active")
        local instName = (act and #act:GetChildren() > 0 and act:GetChildren()[1].Name) or "SpaceMiningEvent"
        if enable then
            pcall(function() remInstancing:FireServer(instName, "AutoMine", true) end)
            pcall(function() remInstancing:FireServer(instName, "ToggleAutoMine") end)
            pcall(function() remInstancing:FireServer(instName, "AutoDig", true) end)
        else
            pcall(function() remInstancing:FireServer(instName, "AutoMine", false) end)
        end
    end

    -- 3. Библиотека PS99 Client Library
    pcall(function()
        local lib = require(RepS:WaitForChild("Library", 1))
        if lib and lib.Client then
            if lib.Client.AutoFarm then pcall(function() lib.Client.AutoFarm.Set(enable) end) end
            if lib.Client.AutoMine then pcall(function() lib.Client.AutoMine.Set(enable) end) end
        end
    end)

    -- 4. Поиск и клик по кнопке Auto Mine в интерфейсе игры (PlayerGui)
    pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, b in ipairs(pg:GetDescendants()) do
            if b:IsA("GuiButton") and b.Visible then
                local nm = string.lower(b.Name)
                local txt = b:IsA("TextButton") and string.lower(b.Text) or ""
                local childTxt = ""
                for _, ch in ipairs(b:GetChildren()) do
                    if ch:IsA("TextLabel") then childTxt = childTxt .. " " .. string.lower(ch.Text) end
                end

                local isAutoBtn = string.find(nm, "automine") or string.find(nm, "autofarm") or string.find(nm, "autodig")
                    or string.find(txt, "auto mine") or string.find(txt, "auto farm") or string.find(txt, "auto dig") or string.find(txt, "авто")
                    or string.find(childTxt, "auto mine") or string.find(childTxt, "auto farm") or string.find(childTxt, "авто")

                if isAutoBtn then
                    local isCurrentlyOn = false
                    if b:GetAttribute("Active") == true or b:GetAttribute("Enabled") == true or b:GetAttribute("Toggled") == true then
                        isCurrentlyOn = true
                    elseif string.find(txt, "on") or string.find(txt, "вкл") or string.find(childTxt, "on") or string.find(childTxt, "вкл") then
                        isCurrentlyOn = true
                    elseif b.BackgroundColor3.G > b.BackgroundColor3.R + 0.2 and b.BackgroundColor3.G > 0.4 then
                        isCurrentlyOn = true
                    end

                    if (enable and not isCurrentlyOn) or (not enable and isCurrentlyOn) then
                        if firesignal then
                            pcall(function() firesignal(b.MouseButton1Click) end)
                            pcall(function() firesignal(b.Activated) end)
                        end
                    end
                end
            end
        end
    end)
end

-- ТЕЛЕПОРТ: Персонаж становится точно НАД целевой рудой
local function teleportTo(pos, inst)
    if not isAlive(inst) then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return end

    local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    if hrp then
        local halfHeight = 1.5
        local basePart = getTargetBasePart(inst)
        if basePart then
            halfHeight = basePart.Size.Y / 2
        end

        local standPos = Vector3.new(pos.X, pos.Y + halfHeight + cfg.yOffset, pos.Z)
        pcall(function()
            hrp.CFrame = CFrame.lookAt(standPos, pos)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- СЕТЕВОЙ УРОН ПО РУДЕ
local function sendDamageToOre(inst, pos, oreId)
    local targetPart = getTargetBasePart(inst) or inst
    local blockName = inst.Name

    if remTarget then
        pcall(function() remTarget:FireServer(targetPart) end)
        pcall(function() remTarget:FireServer(blockName) end)
        pcall(function() remTarget:FireServer(pos) end)
    end

    if remBreak then
        pcall(function() remBreak:FireServer(targetPart) end)
        pcall(function() remBreak:FireServer(blockName) end)
        pcall(function() remBreak:FireServer(pos) end)
        pcall(function() remBreak:FireServer(targetPart, pos) end)
    end

    if remBreakables then
        pcall(function() remBreakables:FireServer(blockName) end)
        if oreId then pcall(function() remBreakables:FireServer(oreId) end) end
    end

    if remBlockWorlds then
        pcall(function() remBlockWorlds:FireServer("Break", targetPart) end)
        pcall(function() remBlockWorlds:FireServer(targetPart) end)
    end

    if remInstancing then
        local things = WS:FindFirstChild("__THINGS")
        local ic = things and things:FindFirstChild("__INSTANCE_CONTAINER")
        local act = ic and ic:FindFirstChild("Active")
        local instName = (act and #act:GetChildren() > 0 and act:GetChildren()[1].Name) or "SpaceMiningEvent"
        local isChest = string.find(string.lower(blockName), "chest") or string.find(string.lower(blockName), "crate")
        local action = isChest and "DigChest" or "DigBlock"
        local coord = inst:GetAttribute("Coord") or inst:GetAttribute("id") or pos
        pcall(function() remInstancing:FireServer(instName, action, coord) end)
        pcall(function() remInstancing:FireServer(instName, action, pos) end)
        pcall(function() remInstancing:FireServer(instName, action, targetPart) end)
    end

    local pp = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pp and fireproximityprompt then pcall(fireproximityprompt, pp) end
    local cd = inst:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and fireclickdetector then pcall(fireclickdetector, cd) end

    if cfg.toolSwing then
        local tool = getPickaxe()
        if tool then
            pcall(function() tool:Activate() end)
        end
    end
end

-- ======================== ДОБЫЧА РУДЫ (IN-GAME AUTO MINE + ТЕЛЕПОРТ) ========================
local function breakOreKillaura(b)
    if not cfg.autoBreak then return end
    currentTarget = b
    local inst = b.inst
    local pos  = b.pos
    local oreId = b.id or getOreId(inst)

    if not isAlive(inst) then
        markOreBroken(inst)
        currentTarget = nil
        return
    end

    -- 1. Телепорт над рудой
    teleportTo(pos, inst)
    task.wait(0.04)

    -- 2. Убеждаемся что кирка в руках и Auto-Mine активен
    getPickaxe()
    if cfg.useGameAutoMine then
        setGameAutoMine(true)
    end

    local char = player.Character
    local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
    local lockCFrame = hrp and hrp.CFrame

    local start = tick()
    local minedRecorded = false
    local maxT = math.clamp(cfg.maxBreakTime or 15.0, 3.0, 90.0)

    while (tick() - start < maxT) and farmOn and not paused do
        if not isAlive(inst) then
            markOreBroken(inst)
            if not minedRecorded then
                minedRecorded = true
                recordMinedOre(oreId)
            end
            break
        end

        -- Фиксация позиции над рудой
        if cfg.spamTp and hrp and lockCFrame and isAlive(inst) then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                if (hrp.Position - lockCFrame.Position).Magnitude > 1.2 then
                    hrp.CFrame = lockCFrame
                end
            end)
        end

        -- Удар и пакеты
        sendDamageToOre(inst, pos, oreId)

        task.wait(0.08)
    end

    markOreBroken(inst)
    if not isAlive(inst) and not minedRecorded then
        minedRecorded = true
        recordMinedOre(oreId)
    end
    currentTarget = nil
end

-- ======================== ОЧЕРЕДЬ ШАГОВ ========================
local function stepFarm()
    while #route > 0 do
        if route[1] and isAlive(route[1].inst) then
            break
        else
            table.remove(route, 1)
        end
    end

    if #route == 0 then
        planSmartRoute()
        rebuildBlockList()
        applyESP()
        updStatus()
        if #route == 0 then task.wait(0.2) return end
    end

    local b = route[1]
    if b and isAlive(b.inst) then
        if cfg.dwell > 0 then task.wait(cfg.dwell) end
        breakOreKillaura(b)
        table.remove(route, 1)
    else
        table.remove(route, 1)
    end
end

-- ======================== ФУНКЦИЯ ДЛЯ КЛАВИШ [1] И [2] ========================
local function triggerKeySlot(code, slotNum)
    pcall(function()
        if keypress and keyrelease then
            keypress(code.Value)
            task.wait(0.04)
            keyrelease(code.Value)
        end
    end)
    pcall(function()
        local bp = player:FindFirstChild("Backpack")
        if bp then
            local tools = bp:GetChildren()
            local t = tools[slotNum]
            if t and t:IsA("Tool") then
                local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:EquipTool(t)
                    task.wait(0.05)
                    t:Activate()
                    task.wait(0.05)
                    getPickaxe() -- Сразу возвращаем кирку в руки после использования слота!
                end
            end
        end
    end)
end

-- ======================== ФОНОВЫЕ ПОТОКИ ========================
task.spawn(function()
    while _G.Pufyftyk_Loaded do
        if farmOn and not paused then
            stepFarm()
        else
            task.wait(0.2)
        end
    end
end)

-- Авто-нажатие [1]
task.spawn(function()
    while _G.Pufyftyk_Loaded do
        local waitT = math.max(0.2, tonumber(cfg.key1Interval) or 15.0)
        task.wait(waitT)
        if farmOn and not paused and cfg.autoKey1 then
            triggerKeySlot(Enum.KeyCode.One, 1)
        end
    end
end)

-- Авто-нажатие [2]
task.spawn(function()
    while _G.Pufyftyk_Loaded do
        local waitT = math.max(0.2, tonumber(cfg.key2Interval) or 30.0)
        task.wait(waitT)
        if farmOn and not paused and cfg.autoKey2 then
            triggerKeySlot(Enum.KeyCode.Two, 2)
        end
    end
end)

-- Авто-обновление руд
task.spawn(function()
    while _G.Pufyftyk_Loaded do
        local waitT = math.clamp(tonumber(cfg.scanTime) or 25.0, 1.0, 120.0)
        task.wait(waitT)

        pcall(function()
            local waitCount = 0
            while currentTarget and currentTarget.inst and isAlive(currentTarget.inst) and farmOn and not paused and waitCount < 100 do
                task.wait(0.3)
                waitCount = waitCount + 1
            end

            planSmartRoute()

            if oresPage and oresPage.Visible then
                if rebuildOreList then rebuildOreList() end
                if rebuildBlockList then rebuildBlockList() end
            end

            if updStatus then updStatus() end

            if cfg.espOn and applyESP then
                applyESP()
            end
        end)
    end
end)

-- Фоновое обновление ESP меток каждые 3.5 секунды
task.spawn(function()
    while _G.Pufyftyk_Loaded do
        task.wait(3.5)
        if cfg.espOn and applyESP and farmOn then
            pcall(applyESP)
        end
    end
end)

-- Фоновое обновление таймера статистики (каждую 1 секунду)
task.spawn(function()
    while _G.Pufyftyk_Loaded do
        task.wait(1.0)
        if updateStatsUI and statsPage and statsPage.Visible then
            pcall(updateStatsUI)
        end
    end
end)

-- Watchdog защиты от зависаний + поддержание Auto-Mine
task.spawn(function()
    while _G.Pufyftyk_Loaded do
        task.wait(8)
        if farmOn and not paused then
            pcall(function()
                if cfg.useGameAutoMine then
                    setGameAutoMine(true)
                end
                if currentTarget and currentTarget.inst then
                    if isAlive(currentTarget.inst) then
                        teleportTo(currentTarget.pos, currentTarget.inst)
                        getPickaxe()
                    else
                        brokenOres[currentTarget.inst] = true
                        currentTarget = nil
                    end
                end
            end)
        end
    end
end)

-- Безопасный Anti-AFK
connections.AntiAfk = player.Idled:Connect(function()
    if cfg.antiAfk then
        pcall(function()
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end)

-- ======================== ИНТЕРФЕЙС PUFYFTYK-KVIRES ========================
local Theme = {
    bg          = Color3.fromRGB(11, 13, 20),
    sidebar     = Color3.fromRGB(15, 18, 28),
    card        = Color3.fromRGB(21, 25, 38),
    cardHover   = Color3.fromRGB(28, 34, 52),
    cardActive  = Color3.fromRGB(34, 42, 64),
    accent      = Color3.fromRGB(0, 229, 255),
    accentGlow  = Color3.fromRGB(60, 235, 255),
    violet      = Color3.fromRGB(139, 92, 246),
    gold        = Color3.fromRGB(245, 158, 11),
    silver      = Color3.fromRGB(203, 213, 225),
    bronze      = Color3.fromRGB(217, 119, 6),
    text        = Color3.fromRGB(248, 250, 252),
    textDark    = Color3.fromRGB(148, 163, 184),
    on          = Color3.fromRGB(16, 185, 129),
    off         = Color3.fromRGB(30, 36, 52),
    red         = Color3.fromRGB(239, 68, 68),
}

local gui = Instance.new("ScreenGui")
gui.Name = "Pufyftyk_Hub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local targetParent = getGuiParent()
gui.Parent = targetParent
_G.Pufyftyk_Hub_Instance = gui

-- ======================== ЧЁРНЫЙ ЭКРАН 3D OFF (ПОЛНОЭКРАННЫЙ OVERLAY) ========================
blackOverlay = Instance.new("Frame")
blackOverlay.Name = "BlackScreenOverlay"
blackOverlay.Size = UDim2.new(1, 0, 1, 0)
blackOverlay.Position = UDim2.new(0, 0, 0, 0)
blackOverlay.BackgroundColor3 = Color3.fromRGB(6, 7, 10)
blackOverlay.BorderSizePixel = 0
blackOverlay.Visible = false
blackOverlay.ZIndex = 5
blackOverlay.Parent = gui

local boCard = Instance.new("Frame")
boCard.Size = UDim2.new(0, 380, 0, 250)
boCard.Position = UDim2.new(0.5, -190, 0.5, -125)
boCard.BackgroundColor3 = Theme.bg
boCard.BorderSizePixel = 0
boCard.Parent = blackOverlay
Instance.new("UICorner", boCard).CornerRadius = UDim.new(0, 12)
local boStroke = Instance.new("UIStroke", boCard)
boStroke.Color = Theme.accent; boStroke.Thickness = 1.5; boStroke.Transparency = 0.4

local boTitle = Instance.new("TextLabel")
boTitle.Size = UDim2.new(1, -20, 0, 24); boTitle.Position = UDim2.new(0, 10, 0, 10)
boTitle.BackgroundTransparency = 1
boTitle.Text = "⚡ PUFYFTYK · РЕЖИМ ЕНЕРГОЗБЕРЕЖЕННЯ"
boTitle.TextColor3 = Theme.accent; boTitle.Font = Enum.Font.GothamBold; boTitle.TextSize = 13
boTitle.Parent = boCard

local boSub = Instance.new("TextLabel")
boSub.Size = UDim2.new(1, -20, 0, 16); boSub.Position = UDim2.new(0, 10, 0, 32)
boSub.BackgroundTransparency = 1
boSub.Text = "🖤 3D Рендер вимкнено (0% GPU) · Екран холодний"
boSub.TextColor3 = Theme.textDark; boSub.Font = Enum.Font.Gotham; boSub.TextSize = 10
boSub.Parent = boCard

local boStatsBox = Instance.new("Frame")
boStatsBox.Size = UDim2.new(1, -24, 0, 110); boStatsBox.Position = UDim2.new(0, 12, 0, 54)
boStatsBox.BackgroundColor3 = Theme.card; boStatsBox.BorderSizePixel = 0
boStatsBox.Parent = boCard
Instance.new("UICorner", boStatsBox).CornerRadius = UDim.new(0, 8)

local boTotalLbl = Instance.new("TextLabel")
boTotalLbl.Size = UDim2.new(0.5, -10, 0, 20); boTotalLbl.Position = UDim2.new(0, 10, 0, 8)
boTotalLbl.BackgroundTransparency = 1; boTotalLbl.Font = Enum.Font.GothamBold; boTotalLbl.TextSize = 11
boTotalLbl.TextColor3 = Theme.accent; boTotalLbl.TextXAlignment = Enum.TextXAlignment.Left
boTotalLbl.Text = "💎 Здобуто: 0 шт"; boTotalLbl.Parent = boStatsBox

local boTimeLbl = Instance.new("TextLabel")
boTimeLbl.Size = UDim2.new(0.5, -10, 0, 20); boTimeLbl.Position = UDim2.new(0.5, 0, 0, 8)
boTimeLbl.BackgroundTransparency = 1; boTimeLbl.Font = Enum.Font.GothamBold; boTimeLbl.TextSize = 11
boTimeLbl.TextColor3 = Theme.text; boTimeLbl.TextXAlignment = Enum.TextXAlignment.Right
boTimeLbl.Text = "⏱️ 00:00"; boTimeLbl.Parent = boStatsBox

local boRateLbl = Instance.new("TextLabel")
boRateLbl.Size = UDim2.new(1, -20, 0, 20); boRateLbl.Position = UDim2.new(0, 10, 0, 32)
boRateLbl.BackgroundTransparency = 1; boRateLbl.Font = Enum.Font.GothamBold; boRateLbl.TextSize = 11
boRateLbl.TextColor3 = Theme.on; boRateLbl.TextXAlignment = Enum.TextXAlignment.Left
boRateLbl.Text = "⚡ Темп: 0.0 руд/хв"; boRateLbl.Parent = boStatsBox

local boTargetLbl = Instance.new("TextLabel")
boTargetLbl.Size = UDim2.new(1, -20, 0, 20); boTargetLbl.Position = UDim2.new(0, 10, 0, 56)
boTargetLbl.BackgroundTransparency = 1; boTargetLbl.Font = Enum.Font.GothamBold; boTargetLbl.TextSize = 10
boTargetLbl.TextColor3 = Theme.gold; boTargetLbl.TextXAlignment = Enum.TextXAlignment.Left
boTargetLbl.Text = "🎯 Ціль: Очікування..."; boTargetLbl.Parent = boStatsBox

local boQueueLbl = Instance.new("TextLabel")
boQueueLbl.Size = UDim2.new(1, -20, 0, 20); boQueueLbl.Position = UDim2.new(0, 10, 0, 80)
boQueueLbl.BackgroundTransparency = 1; boQueueLbl.Font = Enum.Font.GothamSemibold; boQueueLbl.TextSize = 10
boQueueLbl.TextColor3 = Theme.textDark; boQueueLbl.TextXAlignment = Enum.TextXAlignment.Left
boQueueLbl.Text = "🥇 Перша в черзі: Немає"; boQueueLbl.Parent = boStatsBox

local boRestoreBtn = Instance.new("TextButton")
boRestoreBtn.Size = UDim2.new(0.6, -14, 0, 32); boRestoreBtn.Position = UDim2.new(0, 12, 0, 172)
boRestoreBtn.BackgroundColor3 = Theme.accent; boRestoreBtn.BorderSizePixel = 0
boRestoreBtn.Text = "👁️ УВІМКНУТИ 3D ГРАФІКУ"; boRestoreBtn.TextColor3 = Color3.fromRGB(10, 15, 25)
boRestoreBtn.Font = Enum.Font.GothamBold; boRestoreBtn.TextSize = 10
boRestoreBtn.Parent = boCard
Instance.new("UICorner", boRestoreBtn).CornerRadius = UDim.new(0, 6)

boRestoreBtn.MouseButton1Click:Connect(function()
    cfg.render3dOff = false
    applyRender3d(false)
end)

local boMenuBtn = Instance.new("TextButton")
boMenuBtn.Size = UDim2.new(0.4, -14, 0, 32); boMenuBtn.Position = UDim2.new(0.6, 2, 0, 172)
boMenuBtn.BackgroundColor3 = Theme.cardActive; boMenuBtn.BorderSizePixel = 0
boMenuBtn.Text = "📋 МЕНЮ ХАБУ"; boMenuBtn.TextColor3 = Theme.text
boMenuBtn.Font = Enum.Font.GothamBold; boMenuBtn.TextSize = 10
boMenuBtn.Parent = boCard
Instance.new("UICorner", boMenuBtn).CornerRadius = UDim.new(0, 6)

boMenuBtn.MouseButton1Click:Connect(function()
    if win then win.Visible = not win.Visible end
end)

-- Обновление данных на чёрном экране
task.spawn(function()
    while _G.Pufyftyk_Loaded do
        task.wait(0.5)
        if blackOverlay and blackOverlay.Visible then
            local elapsed = math.max(1, tick() - sessionStartTime)
            local mins = math.floor(elapsed / 60)
            local secs = math.floor(elapsed % 60)
            local hours = math.floor(mins / 60)
            mins = mins % 60
            local timeStr = (hours > 0) and string.format("%02d:%02d:%02d", hours, mins, secs) or string.format("%02d:%02d", mins, secs)
            local rate = (totalMinedCount / elapsed) * 60

            boTotalLbl.Text = string.format("💎 Здобуто: %d шт", totalMinedCount)
            boTimeLbl.Text  = string.format("⏱️ %s", timeStr)
            boRateLbl.Text  = string.format("⚡ Темп: %.1f руд/хв", rate)

            local curName = currentTarget and (currentTarget.id or (currentTarget.inst and currentTarget.inst.Name)) or "Пошук цілі..."
            boTargetLbl.Text = string.format("🎯 Ціль: %s", tostring(curName))

            local nextOre = priorityOrder[1] or (route[1] and route[1].id) or "Не вибрано"
            boQueueLbl.Text  = string.format("🥇 Перша в черзі: %s (Всього: %d)", tostring(nextOre), #route)
        end
    end
end)

-- ======================== ГЛАВНОЕ ОКНО GUI ========================
win = Instance.new("Frame")
win.Name = "MainWindow"
win.Size = UDim2.new(0, 520, 0, 330)
win.Position = UDim2.new(0.5, -260, 0.08, 0)
win.BackgroundColor3 = Theme.bg; win.BorderSizePixel = 0; win.Active = true; win.Draggable = false
win.ClipsDescendants = true
win.ZIndex = 10
win.Parent = gui

Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
local winStroke = Instance.new("UIStroke")
winStroke.Color = Theme.accent; winStroke.Thickness = 1.4; winStroke.Transparency = 0.55
winStroke.Parent = win

-- Верхняя панель заголовка
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 38); topBar.BackgroundColor3 = Theme.sidebar; topBar.BorderSizePixel = 0; topBar.Active = true; topBar.Parent = win
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local logoLabel = Instance.new("TextLabel")
logoLabel.Text = "⚡ pufyftyk · AUTO-MINE PRO"
logoLabel.Font = Enum.Font.GothamBold; logoLabel.TextSize = 13
logoLabel.TextColor3 = Theme.accent; logoLabel.TextXAlignment = Enum.TextXAlignment.Left
logoLabel.Size = UDim2.new(0, 280, 1, 0); logoLabel.Position = UDim2.new(0, 14, 0, 0)
logoLabel.BackgroundTransparency = 1; logoLabel.Active = false; logoLabel.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Text = "—"; minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 13
minBtn.TextColor3 = Theme.textDark; minBtn.BackgroundColor3 = Theme.card; minBtn.BorderSizePixel = 0
minBtn.Size = UDim2.new(0, 30, 0, 26); minBtn.Position = UDim2.new(1, -70, 0, 6); minBtn.Parent = topBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "✕"; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 12
closeBtn.TextColor3 = Theme.red; closeBtn.BackgroundColor3 = Theme.card; closeBtn.BorderSizePixel = 0
closeBtn.Size = UDim2.new(0, 30, 0, 26); closeBtn.Position = UDim2.new(1, -36, 0, 6); closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
closeBtn.MouseButton1Click:Connect(function()
    _G.Pufyftyk_Cleanup()
end)

local collapsed = false
minBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    win.Size = collapsed and UDim2.new(0, 520, 0, 38) or UDim2.new(0, 520, 0, 330)
    minBtn.Text = collapsed and "+" or "—"
end)

-- Перетаскивание за шапку (Touch и Mouse)
local isDragging = false
local dragStart = nil
local startPos = nil

connections.DragBegan = topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local mPos = input.Position
        local cPos, cSz = closeBtn.AbsolutePosition, closeBtn.AbsoluteSize
        local mBtnPos, mBtnSz = minBtn.AbsolutePosition, minBtn.AbsoluteSize
        local inClose = (mPos.X >= cPos.X and mPos.X <= cPos.X + cSz.X and mPos.Y >= cPos.Y and mPos.Y <= cPos.Y + cSz.Y)
        local inMin   = (mPos.X >= mBtnPos.X and mPos.X <= mBtnPos.X + mBtnSz.X and mPos.Y >= mBtnPos.Y and mPos.Y <= mBtnPos.Y + mBtnSz.Y)

        if not inClose and not inMin then
            isDragging = true
            dragStart = input.Position
            startPos = win.Position
        end
    end
end)

connections.DragEnded = UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)

connections.DragChanged = UIS.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        win.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Боковая панель
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, -38); sidebar.Position = UDim2.new(0, 0, 0, 38)
sidebar.BackgroundColor3 = Theme.sidebar; sidebar.BorderSizePixel = 0; sidebar.Parent = win

local sList = Instance.new("UIListLayout", sidebar)
sList.Padding = UDim.new(0, 5); sList.SortOrder = Enum.SortOrder.LayoutOrder
local sPad = Instance.new("UIPadding", sidebar)
sPad.PaddingTop = UDim.new(0, 8); sPad.PaddingLeft = UDim.new(0, 6); sPad.PaddingRight = UDim.new(0, 6)

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -140, 1, -46); container.Position = UDim2.new(0, 135, 0, 42)
container.BackgroundTransparency = 1; container.Parent = win

local tabs = {}
local tabButtons = {}

local function createTab(id, titleText, icon, order)
    local page = Instance.new("Frame")
    page.Name = id .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = container

    local tBtn = Instance.new("TextButton")
    tBtn.Size = UDim2.new(1, 0, 0, 32); tBtn.LayoutOrder = order
    tBtn.BackgroundColor3 = Theme.card; tBtn.BorderSizePixel = 0
    tBtn.Text = icon .. "  " .. titleText
    tBtn.Font = Enum.Font.GothamSemibold; tBtn.TextSize = 10
    tBtn.TextColor3 = Theme.textDark; tBtn.TextXAlignment = Enum.TextXAlignment.Left
    tBtn.Parent = sidebar
    Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 6)
    local tPad = Instance.new("UIPadding", tBtn); tPad.PaddingLeft = UDim.new(0, 8)

    tabs[id] = page
    tabButtons[id] = tBtn

    tBtn.MouseButton1Click:Connect(function()
        for k, p in pairs(tabs) do p.Visible = (k == id) end
        for k, b in pairs(tabButtons) do
            local isSel = (k == id)
            b.BackgroundColor3 = isSel and Theme.cardActive or Theme.card
            b.TextColor3 = isSel and Theme.accent or Theme.textDark
            local st = b:FindFirstChildWhichIsA("UIStroke")
            if isSel then
                if not st then
                    st = Instance.new("UIStroke", b)
                    st.Color = Theme.accent; st.Thickness = 1.2; st.Transparency = 0.5
                end
            elseif st then
                st:Destroy()
            end
        end
        if id == "Ores" then
            pcall(rebuildOreList)
            pcall(rebuildBlockList)
        elseif id == "Stats" then
            if updateStatsUI then pcall(updateStatsUI) end
        end
    end)

    return page
end

local farmPage   = createTab("Farm", "Майнинг", "⛏️", 1)
local oresPage   = createTab("Ores", "Приоритеты", "🎯", 2)
local statsPage  = createTab("Stats", "Статистика", "📊", 3)
local optPage    = createTab("Opt", "Буст FPS", "⚡", 4)
local configPage = createTab("Config", "Настройки", "⚙️", 5)

tabs["Farm"].Visible = true
tabButtons["Farm"].BackgroundColor3 = Theme.cardActive
tabButtons["Farm"].TextColor3 = Theme.accent
local fst = Instance.new("UIStroke", tabButtons["Farm"])
fst.Color = Theme.accent; fst.Thickness = 1.2; fst.Transparency = 0.5

-- ======================== ВКЛАДКА 1: МАЙНИНГ ========================
local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, 0, 0, 30); statusBar.BackgroundColor3 = Theme.card; statusBar.BorderSizePixel = 0
statusBar.Parent = farmPage
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 6)
local sbStroke = Instance.new("UIStroke", statusBar)
sbStroke.Color = Theme.cardHover; sbStroke.Thickness = 1

local statusChip1 = Instance.new("TextLabel")
statusChip1.Size = UDim2.new(0, 75, 1, 0); statusChip1.Position = UDim2.new(0, 8, 0, 0)
statusChip1.BackgroundTransparency = 1; statusChip1.Text = "● ОНЛАЙН"
statusChip1.TextColor3 = Theme.on; statusChip1.Font = Enum.Font.GothamBold; statusChip1.TextSize = 10
statusChip1.TextXAlignment = Enum.TextXAlignment.Left; statusChip1.Parent = statusBar

local statusChip2 = Instance.new("TextLabel")
statusChip2.Size = UDim2.new(0, 100, 1, 0); statusChip2.Position = UDim2.new(0, 85, 0, 0)
statusChip2.BackgroundTransparency = 1; statusChip2.Text = "⏹ СТОП"
statusChip2.TextColor3 = Theme.textDark; statusChip2.Font = Enum.Font.GothamBold; statusChip2.TextSize = 10
statusChip2.TextXAlignment = Enum.TextXAlignment.Left; statusChip2.Parent = statusBar

local statusChip3 = Instance.new("TextLabel")
statusChip3.Size = UDim2.new(1, -195, 1, 0); statusChip3.Position = UDim2.new(0, 190, 0, 0)
statusChip3.BackgroundTransparency = 1; statusChip3.Text = "В очереди: 0"
statusChip3.TextColor3 = Theme.accent; statusChip3.Font = Enum.Font.GothamSemibold; statusChip3.TextSize = 10
statusChip3.TextXAlignment = Enum.TextXAlignment.Right; statusChip3.Parent = statusBar
local sPad3 = Instance.new("UIPadding", statusChip3); sPad3.PaddingRight = UDim.new(0, 8)

updStatus = function()
    local firstOre = priorityOrder[1] or (route[1] and route[1].id) or "Нет"
    statusChip2.Text = farmOn and (paused and "⏸ ПАУЗА" or "⛏️ КОПАЮ...") or "⏹ СТОП"
    statusChip2.TextColor3 = farmOn and (paused and Theme.gold or Theme.on) or Theme.textDark
    statusChip3.Text = string.format("В очереди: %d | 🥇 %s", #route, tostring(firstOre))
end

local farmGrid = Instance.new("ScrollingFrame")
farmGrid.Size = UDim2.new(1, 0, 1, -36); farmGrid.Position = UDim2.new(0, 0, 0, 36)
farmGrid.BackgroundTransparency = 1; farmGrid.BorderSizePixel = 0
farmGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y; farmGrid.CanvasSize = UDim2.new(0,0,0,0)
farmGrid.ScrollBarThickness = 3; farmGrid.Parent = farmPage

local fGridLay = Instance.new("UIGridLayout")
fGridLay.CellSize = UDim2.new(0.485, 0, 0, 36)
fGridLay.CellPadding = UDim2.new(0.03, 0, 0, 6)
fGridLay.Parent = farmGrid

local function createToggle(parent, title, stateKey, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 10
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local function refresh()
        local active = cfg[stateKey]
        btn.BackgroundColor3 = active and Color3.fromRGB(24, 45, 40) or Theme.card
        btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Theme.textDark
        btn.Text = title .. (active and "  [🔘 ВКЛ]" or "  [○ ВЫКЛ]")
        local st = btn:FindFirstChildWhichIsA("UIStroke")
        if active then
            if not st then
                st = Instance.new("UIStroke", btn)
                st.Color = Theme.on; st.Thickness = 1.2; st.Transparency = 0.3
            end
        elseif st then
            st:Destroy()
        end
    end
    refresh()

    btn.MouseButton1Click:Connect(function()
        cfg[stateKey] = not cfg[stateKey]
        refresh()
        if callback then callback(cfg[stateKey]) end
    end)
    return btn
end

local function createAction(parent, title, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BorderSizePixel = 0
    btn.Text = title; btn.Font = Enum.Font.GothamBold; btn.TextSize = 10
    btn.TextColor3 = Color3.new(1,1,1); btn.BackgroundColor3 = color; btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    if callback then
        btn.MouseButton1Click:Connect(callback)
    end
    return btn
end

local farmBtn = createAction(farmGrid, "▶ СТАРТ ФАРМ", Theme.on, function()
    farmOn = not farmOn
    if farmOn then
        if #route == 0 then planSmartRoute() end
        if cfg.useGameAutoMine then setGameAutoMine(true) end
        applyESP()
    else
        if cfg.useGameAutoMine then setGameAutoMine(false) end
        clearESP()
    end
    updStatus()
end)

connections.FarmBtnWatcher = RunS.Heartbeat:Connect(function()
    farmBtn.Text = farmOn and "⏹ СТОП ФАРМ" or "▶ СТАРТ ФАРМ"
    farmBtn.BackgroundColor3 = farmOn and Theme.red or Theme.on
end)

createToggle(farmGrid, "⏸ Пауза", "paused", function()
    paused = not paused
    updStatus()
end)

createToggle(farmGrid, "🤖 Auto Mine игры", "useGameAutoMine", function(v)
    if farmOn then setGameAutoMine(v) end
end)

createToggle(farmGrid, "📍 Спам-ТП (Фиксация)", "spamTp")
createToggle(farmGrid, "🎯 Прицел на руду", "aimAtOre")
createToggle(farmGrid, "👁️ ESP подсветка руд", "espOn", function(v)
    if v then applyESP() else clearESP() end
end)
createToggle(farmGrid, "⚔️ Взмах киркой", "toolSwing")
createToggle(farmGrid, "👻 Noclip (Сквозь блоки)", "noclip")

createToggle(farmGrid, "⌨️ Авто-клик [1]", "autoKey1")
createToggle(farmGrid, "⌨️ Авто-клик [2]", "autoKey2")

createAction(farmGrid, "🔍 Пересканировать", Color3.fromRGB(35, 95, 150), function()
    table.clear(brokenOres)
    planSmartRoute(); rebuildOreList(); rebuildBlockList(); updStatus()
    if cfg.espOn then applyESP() end
end)

createAction(farmGrid, "🗑 Сбросить цели", Color3.fromRGB(150, 45, 55), function()
    clearAllPriority()
    table.clear(brokenOres)
    updStatus()
end)

-- ======================== ВКЛАДКА 2: ПРИОРИТЕТЫ ========================
local oreTopBar = Instance.new("Frame")
oreTopBar.Size = UDim2.new(1, 0, 0, 26); oreTopBar.Position = UDim2.new(0, 0, 0, 0)
oreTopBar.BackgroundTransparency = 1; oreTopBar.Parent = oresPage

local topRareBtn = Instance.new("TextButton")
topRareBtn.Size = UDim2.new(0.33, 0, 1, 0); topRareBtn.BackgroundColor3 = Color3.fromRGB(190, 120, 15)
topRareBtn.Text = "⭐ Авто-ранг"; topRareBtn.Font = Enum.Font.GothamBold; topRareBtn.TextSize = 10
topRareBtn.TextColor3 = Color3.new(1,1,1); topRareBtn.Parent = oreTopBar
Instance.new("UICorner", topRareBtn).CornerRadius = UDim.new(0, 5)
topRareBtn.MouseButton1Click:Connect(function()
    autoSetRarePriority()
end)

local clearPriBtn = Instance.new("TextButton")
clearPriBtn.Size = UDim2.new(0.30, 0, 1, 0); clearPriBtn.Position = UDim2.new(0.345, 0, 0, 0)
clearPriBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 50)
clearPriBtn.Text = "🗑 Очистить"; clearPriBtn.Font = Enum.Font.GothamBold; clearPriBtn.TextSize = 10
clearPriBtn.TextColor3 = Color3.new(1,1,1); clearPriBtn.Parent = oreTopBar
Instance.new("UICorner", clearPriBtn).CornerRadius = UDim.new(0, 5)
clearPriBtn.MouseButton1Click:Connect(function()
    clearAllPriority()
end)

local scanControl = Instance.new("Frame")
scanControl.Size = UDim2.new(0.34, 0, 1, 0); scanControl.Position = UDim2.new(0.66, 0, 0, 0)
scanControl.BackgroundColor3 = Theme.card; scanControl.BorderSizePixel = 0; scanControl.Parent = oreTopBar
Instance.new("UICorner", scanControl).CornerRadius = UDim.new(0, 5)
local scStroke = Instance.new("UIStroke", scanControl)
scStroke.Color = Theme.accent; scStroke.Thickness = 1; scStroke.Transparency = 0.5

local scanLbl = Instance.new("TextLabel")
scanLbl.Size = UDim2.new(0.55, 0, 1, 0); scanLbl.Position = UDim2.new(0, 4, 0, 0)
scanLbl.BackgroundTransparency = 1; scanLbl.Font = Enum.Font.GothamBold; scanLbl.TextSize = 9
scanLbl.TextColor3 = Theme.accent; scanLbl.TextXAlignment = Enum.TextXAlignment.Left
scanLbl.Text = "⏱️ Скан:"; scanLbl.Parent = scanControl

scanTimeBox = Instance.new("TextBox")
scanTimeBox.Size = UDim2.new(0.40, 0, 1, -4); scanTimeBox.Position = UDim2.new(0.57, 0, 0, 2)
scanTimeBox.BackgroundColor3 = Theme.sidebar; scanTimeBox.BorderSizePixel = 0
scanTimeBox.TextColor3 = Color3.new(1, 1, 1); scanTimeBox.Font = Enum.Font.GothamBold; scanTimeBox.TextSize = 10
scanTimeBox.Text = string.format("%.1f", cfg.scanTime or 25.0)
scanTimeBox.ClearTextOnFocus = false; scanTimeBox.Parent = scanControl
Instance.new("UICorner", scanTimeBox).CornerRadius = UDim.new(0, 4)

scanTimeBox.FocusLost:Connect(function()
    local raw = scanTimeBox.Text:gsub(",", "."):gsub("[^%d%.]", "")
    local val = tonumber(raw)
    if val and val >= 1.0 and val <= 120.0 then
        cfg.scanTime = val
    end
    scanTimeBox.Text = string.format("%.1f", cfg.scanTime)
    if syncScanTimeSettings then syncScanTimeSettings(cfg.scanTime) end
end)

local colTitle1 = Instance.new("TextLabel")
colTitle1.Text = "📋 Каталог руд (Клик = выбор)"
colTitle1.Font = Enum.Font.GothamBold; colTitle1.TextSize = 9; colTitle1.TextColor3 = Theme.accent
colTitle1.Size = UDim2.new(0.485, 0, 0, 16); colTitle1.Position = UDim2.new(0, 0, 0, 28)
colTitle1.BackgroundTransparency = 1; colTitle1.TextXAlignment = Enum.TextXAlignment.Left; colTitle1.Parent = oresPage

local colTitle2 = Instance.new("TextLabel")
colTitle2.Text = "🎯 Порядок (#1 копается первой)"
colTitle2.Font = Enum.Font.GothamBold; colTitle2.TextSize = 9; colTitle2.TextColor3 = Theme.gold
colTitle2.Size = UDim2.new(0.485, 0, 0, 16); colTitle2.Position = UDim2.new(0.515, 0, 0, 28)
colTitle2.BackgroundTransparency = 1; colTitle2.TextXAlignment = Enum.TextXAlignment.Left; colTitle2.Parent = oresPage

local oreList = Instance.new("ScrollingFrame")
oreList.Size = UDim2.new(0.485, 0, 1, -48); oreList.Position = UDim2.new(0, 0, 0, 46)
oreList.BackgroundColor3 = Theme.card; oreList.BorderSizePixel = 0
oreList.AutomaticCanvasSize = Enum.AutomaticSize.Y; oreList.CanvasSize = UDim2.new(0,0,0,0)
oreList.ScrollBarThickness = 3; oreList.Parent = oresPage
Instance.new("UICorner", oreList).CornerRadius = UDim.new(0, 6)
local oll = Instance.new("UIListLayout", oreList); oll.Padding = UDim.new(0, 3)
local opad = Instance.new("UIPadding", oreList)
opad.PaddingTop = UDim.new(0, 3); opad.PaddingLeft = UDim.new(0, 3); opad.PaddingRight = UDim.new(0, 4)

local blkList = Instance.new("ScrollingFrame")
blkList.Size = UDim2.new(0.485, 0, 1, -48); blkList.Position = UDim2.new(0.515, 0, 0, 46)
blkList.BackgroundColor3 = Theme.card; blkList.BorderSizePixel = 0
blkList.AutomaticCanvasSize = Enum.AutomaticSize.Y; blkList.CanvasSize = UDim2.new(0,0,0,0)
blkList.ScrollBarThickness = 3; blkList.Parent = oresPage
Instance.new("UICorner", blkList).CornerRadius = UDim.new(0, 6)
local bll = Instance.new("UIListLayout", blkList); bll.Padding = UDim.new(0, 3)
local bpad = Instance.new("UIPadding", blkList)
bpad.PaddingTop = UDim.new(0, 3); bpad.PaddingLeft = UDim.new(0, 3); bpad.PaddingRight = UDim.new(0, 4)

local oreBtnCache = {}

rebuildOreList = function()
    local arr = {}
    for id, n in pairs(allIds) do table.insert(arr, { id = id, n = n }) end
    for _, id in ipairs(priorityOrder) do
        if not allIds[id] then
            table.insert(arr, { id = id, n = 0 })
        end
    end
    table.sort(arr, function(a, b)
        local rA = selected[a.id] or 999
        local rB = selected[b.id] or 999
        if rA ~= rB then return rA < rB end
        local isRA, isRB = isRareOre(a.id), isRareOre(b.id)
        if isRA ~= isRB then return isRA end
        return a.n > b.n
    end)

    local activeIds = {}
    for i, o in ipairs(arr) do
        activeIds[o.id] = true
        local rank = selected[o.id]
        local bgColor, txtColor, textStr
        if rank then
            if rank == 1 then
                bgColor = Color3.fromRGB(180, 120, 10)
                textStr = string.format(" 🥇 [#1] %s (%d)", o.id, o.n)
            elseif rank == 2 then
                bgColor = Color3.fromRGB(70, 85, 110)
                textStr = string.format(" 🥈 [#2] %s (%d)", o.id, o.n)
            elseif rank == 3 then
                bgColor = Color3.fromRGB(140, 80, 30)
                textStr = string.format(" 🥉 [#3] %s (%d)", o.id, o.n)
            else
                bgColor = Theme.cardActive
                textStr = string.format(" [#%d] %s (%d)", rank, o.id, o.n)
            end
            txtColor = Color3.new(1, 1, 1)
        else
            bgColor = Theme.sidebar
            txtColor = isRareOre(o.id) and Color3.fromRGB(255, 215, 100) or Theme.textDark
            textStr = string.format("   + %s%s (%d)", isRareOre(o.id) and "⭐ " or "", o.id, o.n)
        end

        local e = oreBtnCache[o.id]
        if not e or not e.Parent then
            e = Instance.new("TextButton")
            e.Size = UDim2.new(1, -2, 0, 24)
            e.TextSize = 10; e.Font = Enum.Font.GothamBold; e.TextXAlignment = Enum.TextXAlignment.Left
            Instance.new("UICorner", e).CornerRadius = UDim.new(0, 4)
            local oreIdToToggle = o.id
            e.MouseButton1Click:Connect(function()
                addOrTogglePriority(oreIdToToggle)
            end)
            e.Parent = oreList
            oreBtnCache[o.id] = e
        end

        e.LayoutOrder = i
        e.BackgroundColor3 = bgColor
        e.TextColor3 = txtColor
        e.Text = textStr
        e.Visible = true
    end

    for id, btn in pairs(oreBtnCache) do
        if not activeIds[id] and btn then
            btn.Visible = false
        end
    end
end

local blockRowCache = {}
local emptyQueueLabel = nil

rebuildBlockList = function()
    if #priorityOrder == 0 then
        for _, item in ipairs(blockRowCache) do
            if item and item.frame then item.frame.Visible = false end
        end
        if not emptyQueueLabel or not emptyQueueLabel.Parent then
            emptyQueueLabel = Instance.new("TextLabel")
            emptyQueueLabel.Size = UDim2.new(1, -10, 0, 60); emptyQueueLabel.Position = UDim2.new(0, 5, 0, 10)
            emptyQueueLabel.BackgroundTransparency = 1
            emptyQueueLabel.Text = "Очередь пуста.\nНажмите на руду слева, чтобы выбрать ее первой!"
            emptyQueueLabel.Font = Enum.Font.GothamMedium; emptyQueueLabel.TextSize = 10
            emptyQueueLabel.TextColor3 = Theme.textDark; emptyQueueLabel.TextWrapped = true
            emptyQueueLabel.Parent = blkList
        end
        emptyQueueLabel.Visible = true
    else
        if emptyQueueLabel then emptyQueueLabel.Visible = false end

        for rank, id in ipairs(priorityOrder) do
            local count = allIds[id] or 0
            local badge = (rank == 1 and "🥇 #1") or (rank == 2 and "🥈 #2") or (rank == 3 and "🥉 #3") or string.format("#%d", rank)
            local isRank1 = (rank == 1)

            local item = blockRowCache[rank]
            if not item or not item.frame.Parent then
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, -2, 0, 24); row.BorderSizePixel = 0
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

                local txt = Instance.new("TextLabel")
                txt.Size = UDim2.new(1, -28, 1, 0); txt.Position = UDim2.new(0, 6, 0, 0)
                txt.BackgroundTransparency = 1
                txt.Font = Enum.Font.GothamBold; txt.TextSize = 10; txt.TextXAlignment = Enum.TextXAlignment.Left
                txt.Parent = row

                local delBtn = Instance.new("TextButton")
                delBtn.Size = UDim2.new(0, 20, 0, 20); delBtn.Position = UDim2.new(1, -22, 0.5, -10)
                delBtn.BackgroundColor3 = Color3.fromRGB(70, 25, 30); delBtn.BorderSizePixel = 0
                delBtn.Text = "✕"; delBtn.TextColor3 = Theme.red; delBtn.Font = Enum.Font.GothamBold; delBtn.TextSize = 10
                Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 4)
                delBtn.Parent = row

                local capturedRank = rank
                delBtn.MouseButton1Click:Connect(function()
                    local currentId = priorityOrder[capturedRank]
                    if currentId then removePriority(currentId) end
                end)

                row.Parent = blkList
                item = { frame = row, label = txt, del = delBtn }
                blockRowCache[rank] = item
            end

            item.frame.LayoutOrder = rank
            item.frame.BackgroundColor3 = isRank1 and Color3.fromRGB(50, 40, 15) or Theme.sidebar
            item.label.Text = string.format("%s. %s (%d шт)", badge, id, count)
            item.label.TextColor3 = isRank1 and Theme.gold or Theme.text
            item.frame.Visible = true
        end

        for r = #priorityOrder + 1, #blockRowCache do
            if blockRowCache[r] and blockRowCache[r].frame then
                blockRowCache[r].frame.Visible = false
            end
        end
    end
    updStatus()
end

-- ======================== ВКЛАДКА 3: СТАТИСТИКА ========================
local statsTopBar = Instance.new("Frame")
statsTopBar.Size = UDim2.new(1, 0, 0, 32); statsTopBar.Position = UDim2.new(0, 0, 0, 0)
statsTopBar.BackgroundColor3 = Theme.card; statsTopBar.BorderSizePixel = 0; statsTopBar.Parent = statsPage
Instance.new("UICorner", statsTopBar).CornerRadius = UDim.new(0, 6)
local stTopStroke = Instance.new("UIStroke", statsTopBar)
stTopStroke.Color = Theme.cardHover; stTopStroke.Thickness = 1

local statCard1 = Instance.new("TextLabel")
statCard1.Size = UDim2.new(0.33, 0, 1, 0); statCard1.Position = UDim2.new(0, 8, 0, 0)
statCard1.BackgroundTransparency = 1; statCard1.Font = Enum.Font.GothamBold; statCard1.TextSize = 10
statCard1.TextColor3 = Theme.accent; statCard1.TextXAlignment = Enum.TextXAlignment.Left
statCard1.Text = "💎 Всего: 0 шт"
statCard1.Parent = statsTopBar

local statCard2 = Instance.new("TextLabel")
statCard2.Size = UDim2.new(0.33, 0, 1, 0); statCard2.Position = UDim2.new(0.33, 0, 0, 0)
statCard2.BackgroundTransparency = 1; statCard2.Font = Enum.Font.GothamBold; statCard2.TextSize = 10
statCard2.TextColor3 = Theme.text; statCard2.TextXAlignment = Enum.TextXAlignment.Center
statCard2.Text = "⏱️ 00:00"
statCard2.Parent = statsTopBar

local statCard3 = Instance.new("TextLabel")
statCard3.Size = UDim2.new(0.33, -12, 1, 0); statCard3.Position = UDim2.new(0.66, 4, 0, 0)
statCard3.BackgroundTransparency = 1; statCard3.Font = Enum.Font.GothamBold; statCard3.TextSize = 10
statCard3.TextColor3 = Theme.on; statCard3.TextXAlignment = Enum.TextXAlignment.Right
statCard3.Text = "⚡ 0.0 руд/мин"
statCard3.Parent = statsTopBar

local statsSubBar = Instance.new("Frame")
statsSubBar.Size = UDim2.new(1, 0, 0, 24); statsSubBar.Position = UDim2.new(0, 0, 0, 38)
statsSubBar.BackgroundTransparency = 1; statsSubBar.Parent = statsPage

local statsTitle = Instance.new("TextLabel")
statsTitle.Size = UDim2.new(1, -110, 1, 0); statsTitle.Position = UDim2.new(0, 2, 0, 0)
statsTitle.BackgroundTransparency = 1; statsTitle.Font = Enum.Font.GothamBold; statsTitle.TextSize = 9
statsTitle.TextColor3 = Theme.gold; statsTitle.TextXAlignment = Enum.TextXAlignment.Left
statsTitle.Text = "🎯 Результаты фарма руд:"
statsTitle.Parent = statsSubBar

local resetStatsBtn = Instance.new("TextButton")
resetStatsBtn.Size = UDim2.new(0, 100, 1, 0); resetStatsBtn.Position = UDim2.new(1, -100, 0, 0)
resetStatsBtn.BackgroundColor3 = Color3.fromRGB(60, 25, 30); resetStatsBtn.BorderSizePixel = 0
resetStatsBtn.Text = "🔄 Сброс стат."; resetStatsBtn.Font = Enum.Font.GothamBold; resetStatsBtn.TextSize = 10
resetStatsBtn.TextColor3 = Theme.red; resetStatsBtn.Parent = statsSubBar
Instance.new("UICorner", resetStatsBtn).CornerRadius = UDim.new(0, 5)

local statsScroll = Instance.new("ScrollingFrame")
statsScroll.Size = UDim2.new(1, 0, 1, -66); statsScroll.Position = UDim2.new(0, 0, 0, 64)
statsScroll.BackgroundColor3 = Theme.card; statsScroll.BorderSizePixel = 0
statsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; statsScroll.CanvasSize = UDim2.new(0,0,0,0)
statsScroll.ScrollBarThickness = 3; statsScroll.Parent = statsPage
Instance.new("UICorner", statsScroll).CornerRadius = UDim.new(0, 6)

local sLay = Instance.new("UIListLayout", statsScroll); sLay.Padding = UDim.new(0, 4)
local sPad = Instance.new("UIPadding", statsScroll)
sPad.PaddingTop = UDim.new(0, 4); sPad.PaddingLeft = UDim.new(0, 4); sPad.PaddingRight = UDim.new(0, 5)

resetStatsBtn.MouseButton1Click:Connect(function()
    table.clear(minedStats)
    totalMinedCount = 0
    sessionStartTime = tick()
    if updateStatsUI then updateStatsUI() end
end)

updateStatsUI = function()
    local elapsed = math.max(1, tick() - sessionStartTime)
    local mins = math.floor(elapsed / 60)
    local secs = math.floor(elapsed % 60)
    local hours = math.floor(mins / 60)
    mins = mins % 60
    local timeStr = (hours > 0) and string.format("%02d:%02d:%02d", hours, mins, secs) or string.format("%02d:%02d", mins, secs)

    local rate = (totalMinedCount / elapsed) * 60
    statCard1.Text = string.format("💎 Всего: %d шт", totalMinedCount)
    statCard2.Text = string.format("⏱️ %s", timeStr)
    statCard3.Text = string.format("⚡ %.1f руд/мин", rate)

    if not statsPage.Visible then return end

    for _, c in ipairs(statsScroll:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end

    local shownKeys = {}
    local rows = {}

    for rank, id in ipairs(priorityOrder) do
        shownKeys[id] = true
        local mined = minedStats[id] or 0
        table.insert(rows, { id = id, count = mined, rank = rank, isPriority = true })
    end

    local otherRows = {}
    for id, count in pairs(minedStats) do
        if not shownKeys[id] and count > 0 then
            table.insert(otherRows, { id = id, count = count, rank = 999, isPriority = false })
        end
    end
    table.sort(otherRows, function(a, b) return a.count > b.count end)
    for _, r in ipairs(otherRows) do table.insert(rows, r) end

    if #rows == 0 then
        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, -20, 0, 60); emptyLbl.Position = UDim2.new(0, 10, 0, 10)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Text = "⛏️ Список пока пуст.\nВыберите руды во вкладке «Приоритеты» и включите фарм!"
        emptyLbl.Font = Enum.Font.GothamMedium; emptyLbl.TextSize = 10
        emptyLbl.TextColor3 = Theme.textDark; emptyLbl.TextWrapped = true; emptyLbl.Parent = statsScroll
        return
    end

    for orderIdx, item in ipairs(rows) do
        local rFrame = Instance.new("Frame")
        rFrame.Size = UDim2.new(1, -2, 0, 24); rFrame.LayoutOrder = orderIdx
        rFrame.BackgroundColor3 = item.isPriority and ((item.rank == 1 and Color3.fromRGB(45, 36, 15)) or Color3.fromRGB(22, 28, 44)) or Theme.sidebar
        rFrame.BorderSizePixel = 0; rFrame.Parent = statsScroll
        Instance.new("UICorner", rFrame).CornerRadius = UDim.new(0, 5)

        if item.isPriority then
            local strk = Instance.new("UIStroke", rFrame)
            strk.Color = (item.rank == 1 and Theme.gold) or (item.rank == 2 and Theme.silver) or (item.rank == 3 and Theme.bronze) or Theme.accent
            strk.Thickness = 1; strk.Transparency = 0.4
        end

        local prefix = ""
        local nameColor = Theme.text
        if item.isPriority then
            prefix = (item.rank == 1 and "🥇 #1 ") or (item.rank == 2 and "🥈 #2 ") or (item.rank == 3 and "🥉 #3 ") or string.format("🎯 #%d ", item.rank)
            nameColor = (item.rank == 1 and Theme.gold) or Theme.text
        else
            prefix = "📦 "
            nameColor = Theme.textDark
        end

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -115, 1, 0); nameLbl.Position = UDim2.new(0, 6, 0, 0)
        nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 9
        nameLbl.TextColor3 = nameColor; nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Text = prefix .. item.id
        nameLbl.Parent = rFrame

        local countBadge = Instance.new("TextLabel")
        countBadge.Size = UDim2.new(0, 105, 1, 0); countBadge.Position = UDim2.new(1, -110, 0, 0)
        countBadge.BackgroundTransparency = 1; countBadge.Font = Enum.Font.GothamBold; countBadge.TextSize = 9
        countBadge.TextXAlignment = Enum.TextXAlignment.Right
        if item.count > 0 then
            countBadge.TextColor3 = item.isPriority and Theme.on or Theme.accent
            countBadge.Text = string.format("+%d шт", item.count)
        else
            countBadge.TextColor3 = Color3.fromRGB(120, 130, 150)
            countBadge.Text = "0 шт (в очереди)"
        end
        countBadge.Parent = rFrame
    end
end

-- ======================== ВКЛАДКА 4: ОПТИМИЗАЦИЯ И БУСТ FPS ========================
local optGrid = Instance.new("ScrollingFrame")
optGrid.Size = UDim2.new(1, 0, 1, 0); optGrid.BackgroundTransparency = 1; optGrid.BorderSizePixel = 0
optGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y; optGrid.CanvasSize = UDim2.new(0,0,0,0)
optGrid.ScrollBarThickness = 3; optGrid.Parent = optPage

local oLay = Instance.new("UIGridLayout")
oLay.CellSize = UDim2.new(0.485, 0, 0, 38)
oLay.CellPadding = UDim2.new(0.03, 0, 0, 8)
oLay.Parent = optGrid

createToggle(optGrid, "🥔 Картофельная графика", "potatoMode", function(v)
    applyPotatoGraphics(v)
end)

createToggle(optGrid, "🌑 Мягкое затемнение 3D", "darkScreen", function(v)
    applyDarkScreen(v)
end)

createToggle(optGrid, "📺 Чёрный экран (3D OFF)", "render3dOff", function(v)
    applyRender3d(v)
end)

createToggle(optGrid, "⚡ Лимит 30 FPS", "fpsCap30", function(v)
    if v then setFpsLimit(30) else setFpsLimit(60) end
end)

createToggle(optGrid, "👻 Noclip (Сквозь блоки)", "noclip", function(v)
    if not v then setCharacterCollision(true) end
end)

createToggle(optGrid, "🛡️ Anti-AFK (Защита)", "antiAfk")

createToggle(optGrid, "👁️ ESP подсветка руд", "espOn", function(v)
    if v then applyESP() else clearESP() end
end)

createToggle(optGrid, "🏷️ Метки дистанции ESP", "espText", function()
    if cfg.espOn then applyESP() end
end)

-- ======================== ВКЛАДКА 5: НАСТРОЙКИ ========================
local scrollSettings = Instance.new("ScrollingFrame")
scrollSettings.Size = UDim2.new(1, 0, 1, 0); scrollSettings.BackgroundColor3 = Theme.card; scrollSettings.BorderSizePixel = 0
scrollSettings.AutomaticCanvasSize = Enum.AutomaticSize.Y; scrollSettings.CanvasSize = UDim2.new(0,0,0,0)
scrollSettings.ScrollBarThickness = 3; scrollSettings.Parent = configPage
Instance.new("UICorner", scrollSettings).CornerRadius = UDim.new(0, 6)

local sListLay = Instance.new("UIListLayout", scrollSettings); sListLay.Padding = UDim.new(0, 5)
local sPadding = Instance.new("UIPadding", scrollSettings)
sPadding.PaddingTop = UDim.new(0, 6); sPadding.PaddingLeft = UDim.new(0, 6); sPadding.PaddingRight = UDim.new(0, 6)

local function makeSetting(parent, label, min, max, init, isInt, cb)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -6, 0, 28)
    holder.BackgroundColor3 = Theme.sidebar; holder.BorderSizePixel = 0; holder.Parent = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.68, 0, 1, 0); lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = Theme.text; lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamMedium; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label; lbl.Parent = holder

    local valBox = Instance.new("TextBox")
    valBox.Size = UDim2.new(0.26, 0, 0, 20); valBox.Position = UDim2.new(0.72, 0, 0.5, -10)
    valBox.BackgroundColor3 = Theme.card; valBox.TextColor3 = Theme.accent
    valBox.TextSize = 10; valBox.Font = Enum.Font.GothamBold; valBox.ClearTextOnFocus = false
    valBox.Text = isInt and tostring(init) or string.format("%.2f", init)
    valBox.BorderSizePixel = 0; valBox.Parent = holder
    Instance.new("UICorner", valBox).CornerRadius = UDim.new(0, 4)

    valBox.FocusLost:Connect(function()
        local raw = valBox.Text:gsub(",", "."):gsub("[^%d%.%-]", "")
        local n = tonumber(raw)
        if n and n > 0 then
            if isInt then n = math.floor(n + 0.5) end
            valBox.Text = isInt and tostring(n) or string.format("%.2f", n)
            cb(n)
        else
            valBox.Text = isInt and tostring(init) or string.format("%.2f", init)
        end
    end)
    return holder, valBox
end

makeSetting(scrollSettings, "Высота над рудой (Y)",        0.5,  5.0,   cfg.yOffset,      false, function(v) cfg.yOffset = v end)
makeSetting(scrollSettings, "Интервал Спам-ТП (с)",       0.02, 1.0,   cfg.spamInterval, false, function(v) cfg.spamInterval = v end)
makeSetting(scrollSettings, "Макс. время на руду (с)",    2.0,  120.0, cfg.maxBreakTime, false, function(v) cfg.maxBreakTime = v end)
makeSetting(scrollSettings, "Пауза после ТП (с)",         0.01, 1.0,   cfg.dwell,        false, function(v) cfg.dwell = v end)

local _, cfgScanValBox = makeSetting(scrollSettings, "Авто-обновление руд (с)", 1.0, 120.0, cfg.scanTime, false, function(v)
    cfg.scanTime = v
    if scanTimeBox then scanTimeBox.Text = string.format("%.1f", v) end
end)

syncScanTimeSettings = function(v)
    if cfgScanValBox then
        cfgScanValBox.Text = string.format("%.2f", v)
    end
end

makeSetting(scrollSettings, "Авто-клик [1] (с)",          1.0,  120.0, cfg.key1Interval, false, function(v) cfg.key1Interval = v end)
makeSetting(scrollSettings, "Авто-клик [2] (с)",          1.0,  120.0, cfg.key2Interval, false, function(v) cfg.key2Interval = v end)
makeSetting(scrollSettings, "Дистанция поиска руд (м)",   100,  8000,  cfg.maxDist,      true,  function(v) cfg.maxDist = v end)
makeSetting(scrollSettings, "Макс. меток ESP",            5,    40,    cfg.espMaxCount,  true,  function(v) cfg.espMaxCount = v; if cfg.espOn and applyESP then applyESP() end end)

-- Первоначальный скан
planSmartRoute()
pcall(rebuildOreList)
pcall(rebuildBlockList)
pcall(updStatus)

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "pufyftyk · Auto-Mine",
        Text = "Готов к работе: Auto-Mine + Чёрный экран 3D!",
        Duration = 4
    })
end)

print("[pufyftyk-kvires Auto-Mine Pro] Успешно загружен! Все мобильные улучшения активны.")
