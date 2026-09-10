--// Fly GUI для Xeno — політ з машиною / структурою
--// Клавіші: F - увімк/вимк політ, E - приліпити структуру (навести прицел), WASD - рух, Space - вгору, Shift - вниз

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local flying = false
local speed = 100
local attachedWeld = nil
local bv, bg = nil, nil

--// ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "FlyGui"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(240, 190)
frame.Position = UDim2.new(0.03, 0, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true -- перетягування мишкою
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "✈ FLY — машина / структура"
title.TextColor3 = Color3.fromRGB(0, 255, 140)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 20)
status.Position = UDim2.new(0, 8, 0, 34)
status.BackgroundTransparency = 1
status.Text = "Політ: ВИКЛ | Структура: нема"
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = frame

local function updateStatus()
	status.Text = ("Політ: %s | Структура: %s"):format(
		flying and "УВІМК" or "ВИКЛ",
		attachedWeld and "приліплена" or "нема"
	)
end

-- Кнопка польоту
local flyBtn = Instance.new("TextButton")
flyBtn.Size = UDim2.new(1, -16, 0, 34)
flyBtn.Position = UDim2.new(0, 8, 0, 60)
flyBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 90)
flyBtn.Text = "[ F ] Політ: OFF"
flyBtn.TextColor3 = Color3.new(1, 1, 1)
flyBtn.Font = Enum.Font.GothamBold
flyBtn.TextSize = 14
flyBtn.Parent = frame
Instance.new("UICorner", flyBtn).CornerRadius = UDim.new(0, 8)

-- Кнопка приліплення структури
local attachBtn = Instance.new("TextButton")
attachBtn.Size = UDim2.new(1, -16, 0, 34)
attachBtn.Position = UDim2.new(0, 8, 0, 100)
attachBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 200)
attachBtn.Text = "[ E ] Приліпити структуру"
attachBtn.TextColor3 = Color3.new(1, 1, 1)
attachBtn.Font = Enum.Font.GothamBold
attachBtn.TextSize = 14
attachBtn.Parent = frame
Instance.new("UICorner", attachBtn).CornerRadius = UDim.new(0, 8)

-- Швидкість
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0, 90, 0, 30)
speedLabel.Position = UDim2.new(0, 8, 0, 145)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Швидкість:"
speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 13
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = frame

local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(0, 60, 0, 30)
speedBox.Position = UDim2.new(0, 95, 0, 145)
speedBox.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
speedBox.Text = tostring(speed)
speedBox.TextColor3 = Color3.new(1, 1, 1)
speedBox.Font = Enum.Font.Gotham
speedBox.TextSize = 14
speedBox.Parent = frame
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 6)

speedBox.FocusLost:Connect(function()
	local n = tonumber(speedBox.Text)
	if n and n > 0 then speed = math.clamp(n, 10, 1000) end
	speedBox.Text = tostring(speed)
end)

--// ==================== ЛОГІКА ====================
local function getHRP()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function stopFly()
	flying = false
	if bv then bv:Destroy() bv = nil end
	if bg then bg:Destroy() bg = nil end
	local hrp = getHRP()
	if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
	flyBtn.Text = "[ F ] Політ: OFF"
	flyBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 90)
	updateStatus()
end

local function startFly()
	local hrp = getHRP()
	if not hrp then return end
	flying = true

	bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bv.Velocity = Vector3.zero
	bv.Parent = hrp

	bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	bg.P = 9e4
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp

	flyBtn.Text = "[ F ] Політ: ON"
	flyBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	updateStatus()
end

local function toggleFly()
	if flying then stopFly() else startFly() end
end

-- Приліпити структуру (модель/збірку, на яку наведений прицел)
local function attachStructure()
	local target = mouse.Target
	local hrp = getHRP()
	if not (target and hrp) then return end

	-- шукаємо корінь збірки
	local rootPart = target:GetRootPart()
	if not rootPart then return end

	-- прибираємо анчори, щоб структура могла рухатись
	local model = rootPart:FindFirstAncestorOfClass("Model") or rootPart
	if model ~= workspace then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = false end
		end
		rootPart.Anchored = false
	end

	detachStructure() -- прибрати старий варп, якщо був

	attachedWeld = Instance.new("WeldConstraint")
	attachedWeld.Part0 = hrp
	attachedWeld.Part1 = rootPart
	attachedWeld.Name = "FlyAttachWeld"
	attachedWeld.Parent = rootPart

	-- перезапускаємо політ з новою масою
	if flying then stopFly() startFly() end
	updateStatus()
end

function detachStructure()
	if attachedWeld then
		attachedWeld:Destroy()
		attachedWeld = nil
		if flying then stopFly() startFly() end
		updateStatus()
	end
end

-- Основний цикл польоту
RunService.RenderStepped:Connect(function()
	if not flying or not bv or not bv.Parent then return end
	local hrp = getHRP()
	if not hrp then stopFly() return end

	local move = Vector3.zero
	local look = camera.CFrame.LookVector
	if UIS:IsKeyDown(Enum.KeyCode.W) then move += look end
	if UIS:IsKeyDown(Enum.KeyCode.S) then move -= look end
	if UIS:IsKeyDown(Enum.KeyCode.D) then move += camera.CFrame.RightVector end
	if UIS:IsKeyDown(Enum.KeyCode.A) then move -= camera.CFrame.RightVector end
	if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
	if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.yAxis end

	bv.Velocity = move.Magnitude > 0 and move.Unit * speed or Vector3.zero

	-- Гіро: тільки поворот по горизонталі (машина не перекидається)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		bg.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
	end
end)

-- Кнопки
flyBtn.MouseButton1Click:Connect(toggleFly)
attachBtn.MouseButton1Click:Connect(attachStructure)

-- Клавіші
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F then toggleFly() end
	if input.KeyCode == Enum.KeyCode.E then attachStructure() end
	if input.KeyCode == Enum.KeyCode.X then detachStructure() end
end)

-- Після респавна — вимикаємо політ
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	stopFly()
	detachStructure()
end)

print("[FlyGui] Завантажено! F - політ, E - приліпити структуру, X - відліпити")
