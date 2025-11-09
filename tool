local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')
local ProximityPromptService = game:GetService('ProximityPromptService')
local VirtualUser = game:GetService('VirtualUser')

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')

-- 🖥️ GUI Setup
local screenGui = Instance.new('ScreenGui', playerGui)
screenGui.Name = 'MiniMenu'
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new('Frame', screenGui)
mainFrame.Name = 'MainFrame'
mainFrame.Size = UDim2.new(0, 200, 0, 245)
mainFrame.Position = UDim2.new(0, 10, 1, -255)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
Instance.new('UICorner', mainFrame).CornerRadius = UDim.new(0, 10)

local title = Instance.new('TextButton', mainFrame)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.Text = 'Mini Menu ▼'
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
Instance.new('UICorner', title).CornerRadius = UDim.new(0, 10)

---------------------------------------------------------
-- 🖱️ Cho phép kéo GUI bằng phần tiêu đề
---------------------------------------------------------
local dragging = false
local dragInput, dragStart, startPos
local collapsed = false
local buttons = {}

local function update(input)
	local delta = input.Position - dragStart
	mainFrame.Position = UDim2.new(
		startPos.X.Scale, startPos.X.Offset + delta.X,
		startPos.Y.Scale, startPos.Y.Offset + delta.Y
	)
end

title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

title.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		update(input)
	end
end)

---------------------------------------------------------
-- 🔘 Helper tạo nút
---------------------------------------------------------
local function makeButton(name, text, color, posY)
	local btn = Instance.new('TextButton', mainFrame)
	btn.Name = name
	btn.Size = UDim2.new(1, -20, 0, 35)
	btn.Position = UDim2.new(0, 10, 0, posY)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.Text = text
	Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 6)
	table.insert(buttons, btn)
	return btn
end

---------------------------------------------------------
-- 🎛 Buttons
---------------------------------------------------------
local btnClearAvatar = makeButton('ClearAvatarBtn', 'Xóa Avatar (Tất cả)', Color3.fromRGB(220, 50, 50), 40)
local btnSpamSlap   = makeButton('SpamSlapBtn', 'Spam Slap: OFF (R)', Color3.fromRGB(50, 150, 220), 80)
local btnXRay       = makeButton('XRayBtn', 'X-Ray Plots: OFF', Color3.fromRGB(150, 50, 220), 120)
local btnLift       = makeButton('LiftBtn', 'Bệ Nâng: OFF (C)', Color3.fromRGB(255, 140, 0), 160)
local btnAutoHold   = makeButton('AutoHoldBtn', 'Auto-Hold Steal: OFF (T)', Color3.fromRGB(255, 200, 50), 200)

---------------------------------------------------------
-- 🔽 Toggle rút gọn / mở rộng menu
---------------------------------------------------------
local function toggleCollapse()
	collapsed = not collapsed
	if collapsed then
		title.Text = "Mini Menu ▲"
		for _, b in ipairs(buttons) do b.Visible = false end
		mainFrame:TweenSize(UDim2.new(0, 200, 0, 30), "Out", "Quad", 0.2, true)
	else
		title.Text = "Mini Menu ▼"
		for _, b in ipairs(buttons) do b.Visible = true end
		mainFrame:TweenSize(UDim2.new(0, 200, 0, 245), "Out", "Quad", 0.25, true)
	end
end
title.MouseButton1Click:Connect(function()
	if not dragging then toggleCollapse() end
end)

-- ⚙️ Variables
local isSpamming = false
local xrayEnabled = false
local liftEnabled = false
local AUTO_HOLD_ENABLED = true                                       -- mặc định OFF

---------------------------------------------------------
-- ======================= AUTO HOLD E (FIX+) ==================
---------------------------------------------------------
local HOLD_CHECK_DELAY = 0.02
local MAX_HOLD_TIME = 1.65

local VirtualUser = game:GetService("VirtualUser")
local ProximityPromptService = game:GetService("ProximityPromptService")

AUTO_HOLD_ENABLED = AUTO_HOLD_ENABLED or false
local currentHoldingPrompt = nil
local holdingThread = nil

---------------------------------------------------------
-- ✅ Kiểm tra prompt có phải steal
---------------------------------------------------------
local function isStealPrompt(prompt)
	if not prompt then return false end
	local a = tostring(prompt.ActionText or ""):lower()
	local o = tostring(prompt.ObjectText or ""):lower()
	local n = tostring(prompt.Name or ""):lower()
	return a:find("steal") or o:find("steal") or n:find("steal")
end

---------------------------------------------------------
-- 🧩 Giải phóng phím E
---------------------------------------------------------
local function release_virtualuser()
	pcall(function()
		VirtualUser:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	end)
end

---------------------------------------------------------
-- 🧩 Dừng hold an toàn
---------------------------------------------------------
local function safe_end_hold(prompt, usedAPI, usedVirtual)
	pcall(function()
		if usedAPI and prompt and prompt.Parent then
			prompt:InputHoldEnd()
		end
	end)
	if usedVirtual then
		release_virtualuser()
	end
end

---------------------------------------------------------
-- 🧠 Dừng mọi thread đang chạy
---------------------------------------------------------
local function stopCurrentHold()
	if holdingThread and coroutine.status(holdingThread) ~= "dead" then
		coroutine.close(holdingThread)
	end
	if currentHoldingPrompt then
		safe_end_hold(currentHoldingPrompt, true, true)
		currentHoldingPrompt = nil
	end
	release_virtualuser()
end

---------------------------------------------------------
-- ⚡ Giữ E đến khi prompt biến mất hoặc hết thời gian
---------------------------------------------------------
local function holdPromptUntilDone(prompt)
	-- Ngắt prompt cũ (nếu đang giữ)
	stopCurrentHold()

	currentHoldingPrompt = prompt
	holdingThread = coroutine.create(function()
		if not AUTO_HOLD_ENABLED or not prompt or not prompt.Parent then return end
		if not isStealPrompt(prompt) then return end

		local usedAPI, usedVirtual = false, false
		local success = pcall(function()
			if typeof(prompt.InputHoldBegin) == "function" then
				usedAPI = true
				prompt:InputHoldBegin()
			else
				usedVirtual = true
				VirtualUser:CaptureController()
				VirtualUser:SendKeyEvent(true, Enum.KeyCode.E, false, game)
			end
		end)

		if not success then
			pcall(function()
				if fireproximityprompt then
					while AUTO_HOLD_ENABLED and prompt and prompt.Enabled and prompt.Parent do
						fireproximityprompt(prompt)
						task.wait(0.05)
					end
				end
			end)
			return
		end

		local start = os.clock()
		while AUTO_HOLD_ENABLED and prompt and prompt.Parent and prompt.Enabled and (os.clock() - start < MAX_HOLD_TIME) do
			task.wait(HOLD_CHECK_DELAY)
		end

		safe_end_hold(prompt, usedAPI, usedVirtual)
		currentHoldingPrompt = nil
		task.delay(0.2, release_virtualuser)
	end)
	coroutine.resume(holdingThread)
end

---------------------------------------------------------
-- 📡 Khi prompt xuất hiện
---------------------------------------------------------
ProximityPromptService.PromptShown:Connect(function(prompt)
	if AUTO_HOLD_ENABLED and isStealPrompt(prompt) then
		holdPromptUntilDone(prompt)
	end
end)

---------------------------------------------------------
-- 🚨 Khi prompt bị xoá
---------------------------------------------------------
workspace.DescendantRemoving:Connect(function(v)
	if v:IsA("ProximityPrompt") and v == currentHoldingPrompt then
		stopCurrentHold()
	end
end)

---------------------------------------------------------
-- 🔘 Toggle Auto Hold
---------------------------------------------------------
local function toggleAutoHold()
	AUTO_HOLD_ENABLED = not AUTO_HOLD_ENABLED
	if AUTO_HOLD_ENABLED then
		btnAutoHold.Text = "Auto-Hold Steal: ON (T)"
		btnAutoHold.BackgroundColor3 = Color3.fromRGB(100, 220, 100)
		print("🟢 Auto-Hold Steal: ON")
	else
		btnAutoHold.Text = "Auto-Hold Steal: OFF (T)"
		btnAutoHold.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		stopCurrentHold()
		print("🔴 Auto-Hold Steal: OFF")
	end
end



---------------------------------------------------------
-- ======================= CLEAR OUTFIT =================
---------------------------------------------------------
local function clearMyAvatar()
	player:ClearCharacterAppearance()
	print('✅ Đã xóa outfit của BẠN!')
end
local function clearAllAvatars()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then plr:ClearCharacterAppearance() end
	end
	print('✅ Đã xóa outfit của TẤT CẢ người chơi (local only)')
end
if player.Character then clearMyAvatar() else player.CharacterAdded:Wait(); clearMyAvatar() end

---------------------------------------------------------
-- ======================= SPAM SLAP ====================
---------------------------------------------------------
local function getSlapTool()
	local backpack = player:WaitForChild('Backpack')
	for _, item in ipairs(backpack:GetChildren()) do
		if item:IsA('Tool') and string.find(string.lower(item.Name), 'slap') then
			return item
		end
	end
	local char = player.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA('Tool') and string.find(string.lower(item.Name), 'slap') then
				return item
			end
		end
	end
end

local function startSpamSlap()
	task.spawn(function()
		while isSpamming do
			local char = player.Character
			if char then
				local hum = char:FindFirstChild('Humanoid')
				local tool = getSlapTool()
				if hum and tool then
					if tool.Parent == player.Backpack then hum:EquipTool(tool) end
					task.wait(0.1)
				else task.wait(0.5) end
			else task.wait(0.5) end
		end
	end)
end

---------------------------------------------------------
-- ======================= X-RAY ========================
---------------------------------------------------------
local ModifiedParts, OriginalProperties = {}, {}
local XrayTransparency = 0.7
local PlotsFolder = Workspace:FindFirstChild("Plots")
local possible = {"Plot","plots","Buildings","Houses","Bases"}
if not PlotsFolder then
	for _, n in ipairs(possible) do
		PlotsFolder = Workspace:FindFirstChild(n)
		if PlotsFolder then break end
	end
end

local function isInPlots(part)
	if not PlotsFolder then return false end
	local c = part
	while c and c ~= Workspace do
		if c == PlotsFolder then return true end
		c = c.Parent
	end
end
local function isInsideClaim(part)
	local c = part
	while c and c ~= Workspace do
		if string.find(string.lower(c.Name), "claim") then return true end
		c = c.Parent
	end
end
local function isWall(part)
	if not part:IsA("BasePart") then return false end
	if part.Parent and (part.Parent:FindFirstChild("Humanoid") or (part.Parent.Parent and part.Parent.Parent:FindFirstChild("Humanoid"))) then
		return false
	end
	if isInsideClaim(part) then return false end
	return isInPlots(part)
end
local function applyXray(part)
	if isWall(part) then
		if not OriginalProperties[part] then
			OriginalProperties[part] = {Transparency = part.Transparency}
		end
		part.Transparency = XrayTransparency
		ModifiedParts[part] = true
	end
end
local function restorePlots()
	for part, _ in pairs(ModifiedParts) do
		if part and part.Parent and OriginalProperties[part] then
			part.Transparency = OriginalProperties[part].Transparency
		end
	end
	table.clear(ModifiedParts)
end
local function toggleXray()
	xrayEnabled = not xrayEnabled
	if xrayEnabled then
		btnXRay.Text = 'X-Ray Plots: ON'
		btnXRay.BackgroundColor3 = Color3.fromRGB(100, 220, 100)
		for _, obj in pairs(PlotsFolder:GetDescendants()) do
			if obj:IsA("BasePart") then applyXray(obj) end
		end
	else
		btnXRay.Text = 'X-Ray Plots: OFF'
		btnXRay.BackgroundColor3 = Color3.fromRGB(150, 50, 220)
		restorePlots()
	end
end
if PlotsFolder then
	PlotsFolder.DescendantAdded:Connect(function(obj)
		if xrayEnabled and obj:IsA("BasePart") then task.wait(0.1) applyXray(obj) end
	end)
end

---------------------------------------------------------
-- ======================= LIFT =========================
---------------------------------------------------------
local Settings = {
	PlatformSize = Vector3.new(6, 1, 6),
	LiftSpeed = 50,
	PlatformColor = Color3.fromRGB(100, 100, 255),
	Transparency = 0.3,
	CheckDistance = 8
}
local platform, liftConnection
local isBlocked = false

local function checkCeiling()
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local rayOrigin = hrp.Position + Vector3.new(0, 2, 0)
	local rayDirection = Vector3.new(0, Settings.CheckDistance, 0)

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char, platform}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rayOrigin, rayDirection, params)
	if result then
		local dist = (result.Position - rayOrigin).Magnitude
		if dist < 3 then return true end
	end
	return false
end

local function createPlatform()
	if platform then platform:Destroy() end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	platform = Instance.new("Part")
	platform.Size = Settings.PlatformSize
	platform.Anchored = true
	platform.CanCollide = true
	platform.Material = Enum.Material.Neon
	platform.Color = Settings.PlatformColor
	platform.Transparency = Settings.Transparency
	platform.Name = "LiftPlatform"
	platform.Parent = workspace

	local posBelow = hrp.Position - Vector3.new(0, 3.5, 0)
	platform.CFrame = CFrame.new(posBelow)

	local light = Instance.new("PointLight", platform)
	light.Brightness = 2
	light.Range = 15
	light.Color = Settings.PlatformColor

	isBlocked = false
	return platform
end

local function stopLifting()
	if liftConnection then liftConnection:Disconnect() liftConnection = nil end
	if platform then platform:Destroy() platform = nil end
	isBlocked = false
end

local function startLifting()
	if not platform then return end
	if liftConnection then liftConnection:Disconnect() end
	liftConnection = RunService.Heartbeat:Connect(function(dt)
		if not platform or not platform.Parent then stopLifting(); return end
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		if checkCeiling() then
			if not isBlocked then
				isBlocked = true
				platform.Color = Color3.fromRGB(255, 100, 100)
			end
			local x, z = hrp.Position.X, hrp.Position.Z
			local y = platform.Position.Y
			platform.CFrame = CFrame.new(x, y, z)
			return
		else
			if isBlocked then
				isBlocked = false
				platform.Color = Settings.PlatformColor
			end
		end

		local current = platform.Position
		local newY = current.Y + Settings.LiftSpeed * dt
		local x, z = hrp.Position.X, hrp.Position.Z
		platform.CFrame = CFrame.new(x, newY, z)
	end)
end

local function toggleLift()
	liftEnabled = not liftEnabled
	if liftEnabled then
		btnLift.Text = "Bệ Nâng: ON (X)"
		btnLift.BackgroundColor3 = Color3.fromRGB(100, 220, 100)
		createPlatform()
		startLifting()
	else
		btnLift.Text = "Bệ Nâng: OFF (X)"
		btnLift.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
		stopLifting()
	end
end
player.CharacterAdded:Connect(stopLifting)

---------------------------------------------------------
-- ======================= BUTTONS ======================
---------------------------------------------------------
btnClearAvatar.MouseButton1Click:Connect(function()
	clearAllAvatars()
	btnClearAvatar.BackgroundColor3 = Color3.fromRGB(100, 220, 100)
	task.wait(0.2)
	btnClearAvatar.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
end)

btnSpamSlap.MouseButton1Click:Connect(function()
	isSpamming = not isSpamming
	if isSpamming then
		btnSpamSlap.Text = 'Spam Slap: ON (R)'
		btnSpamSlap.BackgroundColor3 = Color3.fromRGB(50, 220, 100)
		startSpamSlap()
	else
		btnSpamSlap.Text = 'Spam Slap: OFF (R)'
		btnSpamSlap.BackgroundColor3 = Color3.fromRGB(50, 150, 220)
	end
end)

btnXRay.MouseButton1Click:Connect(toggleXray)
btnLift.MouseButton1Click:Connect(toggleLift)
btnAutoHold.MouseButton1Click:Connect(toggleAutoHold)

---------------------------------------------------------
-- ======================= HOTKEYS ======================
---------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.R then
		isSpamming = not isSpamming
		if isSpamming then
			btnSpamSlap.Text = 'Spam Slap: ON (R)'
			btnSpamSlap.BackgroundColor3 = Color3.fromRGB(50, 220, 100)
			startSpamSlap()
		else
			btnSpamSlap.Text = 'Spam Slap: OFF (R)'
			btnSpamSlap.BackgroundColor3 = Color3.fromRGB(50, 150, 220)
		end
	elseif input.KeyCode == Enum.KeyCode.X then
		toggleLift()
	end
end)
