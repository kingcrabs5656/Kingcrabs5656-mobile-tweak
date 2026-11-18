-- ====================================================================
-- COMBINED HUD, FAKE JUMP BUTTON & SHIFT LOCK UTILITY (TOGGLEABLE)
-- Re-executing this script undoes all changes & restores default UI.
-- ====================================================================

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.__CombinedHudCleanup) == "function" then
	pcall(env.__CombinedHudCleanup)
	env.__CombinedHudCleanup = nil
	return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isUnloaded = false
local allConnections = {}
local function trackConn(conn)
	if conn then
		table.insert(allConnections, conn)
	end
	return conn
end

-- --------------------------------------------------------------------
-- CONFIGURATION SETTINGS
-- --------------------------------------------------------------------
local BUTTON_SIZE = 110          -- Size of fake jump button in pixels
local MOVE_BUTTON_SIZE = 100     -- Size of classic move joystick in pixels
local MOVE_OFFSET_X = 55         -- Distance from left edge for move joystick
local MOVE_OFFSET_Y = 55         -- Distance from bottom edge for move joystick

-- 3-State Jump Position Mode: 1 = LOW (Right), 2 = HIGH (Right), 3 = LEFT (Left)
local jumpMode = 1

local SHIFTLOCK_SIZE = 50        -- Size of Shift Lock button in pixels
local CORNER_PADDING_RIGHT = 12  -- Distance from literal right edge for Shift Lock
local CORNER_PADDING_BOTTOM = 12 -- Distance from literal bottom edge for Shift Lock

local CAMERA_OFFSET_RIGHT = 1.75 -- Right shoulder camera offset (in studs)

-- Ensure Classic Thumbstick mode is selected
pcall(function()
	UserSettings():GetService("UserGameSettings").TouchMovementMode = Enum.TouchMovementMode.Thumbstick
end)

-- Grab Roblox's TouchJump controller if accessible so FE2 / custom swim scripts detect holds
local touchJumpController = nil
pcall(function()
	local playerScripts = player:FindFirstChild("PlayerScripts") or player:WaitForChild("PlayerScripts", 2)
	if playerScripts then
		local playerModule = playerScripts:FindFirstChild("PlayerModule")
		if playerModule then
			local controls = require(playerModule):GetControls()
			if controls then
				touchJumpController = controls.touchJumpController
			end
		end
	end
end)

-- --------------------------------------------------------------------
-- PART 1: PING & FPS COUNTER (TOP-LEFT)
-- --------------------------------------------------------------------
local statGui = Instance.new("ScreenGui")
statGui.Name = "StatDisplayGui"
statGui.ResetOnSpawn = false
statGui.DisplayOrder = 999
statGui.Parent = playerGui

local statButton = Instance.new("TextButton")
statButton.Name = "StatButton"
statButton.Size = UDim2.new(0, 125, 0, 20)
statButton.Position = UDim2.new(0, 10, 0, 10)
statButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
statButton.BackgroundTransparency = 0.75
statButton.TextColor3 = Color3.fromRGB(85, 255, 127)
statButton.TextSize = 11
statButton.Font = Enum.Font.SourceSansBold
statButton.TextXAlignment = Enum.TextXAlignment.Center
statButton.Text = "Ping: 0ms | FPS: --"
statButton.AutoButtonColor = false
statButton.Parent = statGui

local statCorner = Instance.new("UICorner")
statCorner.CornerRadius = UDim.new(0, 4)
statCorner.Parent = statButton

local statStroke = Instance.new("UIStroke")
statStroke.Color = Color3.fromRGB(255, 255, 255)
statStroke.Transparency = 0.85
statStroke.Thickness = 1
statStroke.Parent = statButton

local isCounterVisible = true
trackConn(statButton.MouseButton1Click:Connect(function()
	isCounterVisible = not isCounterVisible
	if isCounterVisible then
		statButton.BackgroundTransparency = 0.75
		statButton.TextTransparency = 0
		statStroke.Enabled = true
	else
		statButton.BackgroundTransparency = 1
		statButton.TextTransparency = 1
		statStroke.Enabled = false
	end
end))

local function getPing()
	local success, ping = pcall(function()
		return player:GetNetworkPing() * 1000
	end)
	if success and ping and ping > 0 then return math.round(ping) end
	
	local successStats, statPing = pcall(function()
		return Stats.Network.ServerToClientPing:GetValue()
	end)
	if successStats and statPing then return math.round(statPing) end
	
	return 0
end

local lastUpdate = 0
local frameCounter = 0

trackConn(RunService.RenderStepped:Connect(function(deltaTime)
	if isUnloaded then return end
	frameCounter += 1
	lastUpdate += deltaTime
	
	if lastUpdate >= 0.5 then
		local currentFps = math.round(frameCounter / lastUpdate)
		frameCounter = 0
		lastUpdate = 0
		
		if isCounterVisible then
			local ping = getPing()
			statButton.Text = string.format("Ping: %dms | FPS: %d", ping, currentFps)
			
			if ping < 80 then
				statButton.TextColor3 = Color3.fromRGB(85, 255, 127)
			elseif ping < 150 then
				statButton.TextColor3 = Color3.fromRGB(255, 215, 85)
			else
				statButton.TextColor3 = Color3.fromRGB(255, 85, 85)
			end
		end
	end
end))

-- --------------------------------------------------------------------
-- PART 2: SHIFT LOCK & BOTTOM-LEFT CONTROLS
-- --------------------------------------------------------------------
local shiftLockGui = Instance.new("ScreenGui")
shiftLockGui.Name = "ShiftLockGui"
shiftLockGui.ResetOnSpawn = false
shiftLockGui.DisplayOrder = 9999
shiftLockGui.Parent = playerGui

-- Bottom-Right Shift Lock Button (White Padlock Emoji "🔒")
local shiftLockButton = Instance.new("TextButton")
shiftLockButton.Name = "ShiftLockButton"
shiftLockButton.Size = UDim2.new(0, SHIFTLOCK_SIZE, 0, SHIFTLOCK_SIZE)
shiftLockButton.Position = UDim2.new(1, -CORNER_PADDING_RIGHT, 1, -CORNER_PADDING_BOTTOM)
shiftLockButton.AnchorPoint = Vector2.new(1, 1)
shiftLockButton.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
shiftLockButton.BackgroundTransparency = 0.75
shiftLockButton.Text = "🔒"
shiftLockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
shiftLockButton.TextSize = 22
shiftLockButton.Font = Enum.Font.SourceSansBold
shiftLockButton.Visible = false
shiftLockButton.Parent = shiftLockGui

local lockCorner = Instance.new("UICorner")
lockCorner.CornerRadius = UDim.new(1, 0)
lockCorner.Parent = shiftLockButton

local lockStroke = Instance.new("UIStroke")
lockStroke.Color = Color3.fromRGB(0, 180, 255)
lockStroke.Transparency = 0.4
lockStroke.Thickness = 2.5
lockStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
lockStroke.Parent = shiftLockButton

-- 1. Bottom-Left Master Shift Lock Toggle Button
local masterToggleBtn = Instance.new("TextButton")
masterToggleBtn.Name = "MasterShiftLockToggle"
masterToggleBtn.Size = UDim2.new(0, 50, 0, 28)
masterToggleBtn.Position = UDim2.new(0, 12, 1, -12)
masterToggleBtn.AnchorPoint = Vector2.new(0, 1)
masterToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
masterToggleBtn.BackgroundTransparency = 0.75
masterToggleBtn.Text = "SL: OFF"
masterToggleBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
masterToggleBtn.Font = Enum.Font.SourceSansBold
masterToggleBtn.TextSize = 12
masterToggleBtn.Parent = shiftLockGui

local masterCorner = Instance.new("UICorner")
masterCorner.CornerRadius = UDim.new(0, 6)
masterCorner.Parent = masterToggleBtn

local masterStroke = Instance.new("UIStroke")
masterStroke.Color = Color3.fromRGB(80, 80, 80)
masterStroke.Thickness = 1.5
masterStroke.Parent = masterToggleBtn

-- Forward declaration for fake jump updater
local updateFakeJumpPosition

-- 2. Bottom-Left Jump Position Toggle Button (Cycles 1: LOW -> 2: HIGH -> 3: LEFT)
local jumpToggleBtn = Instance.new("TextButton")
jumpToggleBtn.Name = "JumpPositionToggle"
jumpToggleBtn.Size = UDim2.new(0, 55, 0, 28)
jumpToggleBtn.Position = UDim2.new(0, 68, 1, -12)
jumpToggleBtn.AnchorPoint = Vector2.new(0, 1)
jumpToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
jumpToggleBtn.BackgroundTransparency = 0.75
jumpToggleBtn.Text = "POS: LOW"
jumpToggleBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
jumpToggleBtn.Font = Enum.Font.SourceSansBold
jumpToggleBtn.TextSize = 11
jumpToggleBtn.Parent = shiftLockGui

local jumpCorner = Instance.new("UICorner")
jumpCorner.CornerRadius = UDim.new(0, 6)
jumpCorner.Parent = jumpToggleBtn

local jumpStroke = Instance.new("UIStroke")
jumpStroke.Color = Color3.fromRGB(80, 80, 80)
jumpStroke.Thickness = 1.5
jumpStroke.Parent = jumpToggleBtn

trackConn(jumpToggleBtn.MouseButton1Click:Connect(function()
	jumpMode = jumpMode + 1
	if jumpMode > 3 then
		jumpMode = 1
	end
	
	if jumpMode == 1 then
		jumpToggleBtn.Text = "POS: LOW"
		jumpToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		jumpStroke.Color = Color3.fromRGB(80, 80, 80)
	elseif jumpMode == 2 then
		jumpToggleBtn.Text = "POS: HIGH"
		jumpToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 45, 60)
		jumpStroke.Color = Color3.fromRGB(0, 180, 255)
	elseif jumpMode == 3 then
		jumpToggleBtn.Text = "POS: LEFT"
		jumpToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 60)
		jumpStroke.Color = Color3.fromRGB(180, 0, 255)
	end
	
	if updateFakeJumpPosition then
		updateFakeJumpPosition()
	end
end))

-- Shift Lock Logic
local isShiftLockMasterEnabled = false
local isShiftLockActive = false

local function updateShiftLockStep()
	if isUnloaded or not isShiftLockActive or not isShiftLockMasterEnabled then return end
	local char = player.Character
	local camera = Workspace.CurrentCamera
	if char and camera then
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local isSeated = hum.SeatPart ~= nil or hum:GetState() == Enum.HumanoidStateType.Seated
			
			if not isSeated then
				hum.AutoRotate = false
				local lookVector = camera.CFrame.LookVector
				local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
				if flatLook.Magnitude > 0.001 then
					root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
				end
				
				local isFirstPerson = (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1.0
				if not isFirstPerson then
					camera.CFrame = camera.CFrame * CFrame.new(CAMERA_OFFSET_RIGHT, 0, 0)
				end
			else
				hum.AutoRotate = true
			end
		end
	end
end

local function deactivateShiftLock()
	isShiftLockActive = false
	if shiftLockButton and shiftLockButton.Parent then
		shiftLockButton.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
		shiftLockButton.BackgroundTransparency = 0.75
		lockStroke.Color = Color3.fromRGB(0, 180, 255)
	end
	
	pcall(function() RunService:UnbindFromRenderStep("MobileShiftLockStep") end)
	
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then 
			hum.AutoRotate = true 
			hum.CameraOffset = Vector3.new(0, 0, 0)
		end
	end
end

local function toggleShiftLock()
	if not isShiftLockMasterEnabled then return end
	isShiftLockActive = not isShiftLockActive

	if isShiftLockActive then
		shiftLockButton.BackgroundColor3 = Color3.fromRGB(0, 150, 235)
		shiftLockButton.BackgroundTransparency = 0.45
		lockStroke.Color = Color3.fromRGB(255, 255, 255)
		
		RunService:BindToRenderStep("MobileShiftLockStep", Enum.RenderPriority.Camera.Value + 1, updateShiftLockStep)
	else
		deactivateShiftLock()
	end
end

trackConn(shiftLockButton.MouseButton1Click:Connect(toggleShiftLock))

trackConn(masterToggleBtn.MouseButton1Click:Connect(function()
	isShiftLockMasterEnabled = not isShiftLockMasterEnabled
	if isShiftLockMasterEnabled then
		masterToggleBtn.Text = "SL: ON"
		masterToggleBtn.TextColor3 = Color3.fromRGB(0, 255, 180)
		masterStroke.Color = Color3.fromRGB(0, 255, 180)
		masterToggleBtn.BackgroundColor3 = Color3.fromRGB(10, 35, 30)
		shiftLockButton.Visible = true
	else
		masterToggleBtn.Text = "SL: OFF"
		masterToggleBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
		masterStroke.Color = Color3.fromRGB(80, 80, 80)
		masterToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		shiftLockButton.Visible = false
		deactivateShiftLock()
	end
end))

trackConn(player.CharacterAdded:Connect(function(char)
	task.wait(0.2)
	if isUnloaded then return end
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
	
	if isShiftLockActive and isShiftLockMasterEnabled then
		RunService:BindToRenderStep("MobileShiftLockStep", Enum.RenderPriority.Camera.Value + 1, updateShiftLockStep)
	else
		if hum then hum.AutoRotate = true end
	end
end))

-- --------------------------------------------------------------------
-- PART 3: FE2-COMPATIBLE FAKE JUMP & CLASSIC MOVE JOYSTICK RESIZER
-- --------------------------------------------------------------------
local JUMP_SHEET = "rbxasset://textures/ui/Input/TouchControlsSheetV2.png"
local JUMP_RECT_IDLE = Vector2.new(1, 146)
local JUMP_RECT_PRESSED = Vector2.new(146, 146)
local JUMP_RECT_SIZE = Vector2.new(144, 144)

local fakeJumpButton = Instance.new("ImageButton")
fakeJumpButton.Name = "FakeJumpButton"
fakeJumpButton.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
fakeJumpButton.BackgroundTransparency = 1
fakeJumpButton.Image = JUMP_SHEET
fakeJumpButton.ImageRectOffset = JUMP_RECT_IDLE
fakeJumpButton.ImageRectSize = JUMP_RECT_SIZE
fakeJumpButton.ImageTransparency = 0.25
fakeJumpButton.AutoButtonColor = false
fakeJumpButton.Active = true
fakeJumpButton.ZIndex = 10
fakeJumpButton.Parent = shiftLockGui

updateFakeJumpPosition = function()
	fakeJumpButton.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
	if jumpMode == 1 then
		-- POS: LOW (Right 70, Bottom 25)
		fakeJumpButton.AnchorPoint = Vector2.new(1, 1)
		fakeJumpButton.Position = UDim2.new(1, -70, 1, -25)
	elseif jumpMode == 2 then
		-- POS: HIGH (Right 80, Bottom 240)
		fakeJumpButton.AnchorPoint = Vector2.new(1, 1)
		fakeJumpButton.Position = UDim2.new(1, -80, 1, -240)
	elseif jumpMode == 3 then
		-- POS: LEFT (Left 80, Bottom 240)
		fakeJumpButton.AnchorPoint = Vector2.new(0, 1)
		fakeJumpButton.Position = UDim2.new(0, 80, 1, -240)
	end
end

updateFakeJumpPosition()

-- Relay touch press/release directly to Roblox's TouchJump & real JumpButton
-- so FE2's custom water swimming and normal jumping both work natively
local isJumpHeld = false
local activeJumpInput = nil
local currentRealJumpButton = nil
local currentMockTouch = nil

local function relayJumpInputToRealButton(pressed)
	if touchJumpController then
		pcall(function()
			touchJumpController.isJumping = pressed
		end)
	end

	local realBtn = currentRealJumpButton
	if realBtn and realBtn.Parent and type(firesignal) == "function" then
		if pressed then
			currentMockTouch = {
				UserInputType = Enum.UserInputType.Touch,
				UserInputState = Enum.UserInputState.Begin,
				Position = Vector3.new(0, 0, 0),
				Delta = Vector3.new(0, 0, 0),
				KeyCode = Enum.KeyCode.Unknown,
			}
			pcall(firesignal, realBtn.InputBegan, currentMockTouch)
			pcall(firesignal, realBtn.MouseButton1Down, 0, 0)
			pcall(firesignal, UserInputService.JumpRequest)
		else
			local mock = currentMockTouch or {
				UserInputType = Enum.UserInputType.Touch,
				UserInputState = Enum.UserInputState.End,
				Position = Vector3.new(0, 0, 0),
				Delta = Vector3.new(0, 0, 0),
				KeyCode = Enum.KeyCode.Unknown,
			}
			mock.UserInputState = Enum.UserInputState.End
			pcall(firesignal, realBtn.InputEnded, mock)
			pcall(firesignal, realBtn.MouseButton1Up, 0, 0)
			currentMockTouch = nil
		end
	end
end

local function setJumpPressedState(pressed)
	if isJumpHeld == pressed then return end
	isJumpHeld = pressed

	if pressed then
		fakeJumpButton.ImageRectOffset = JUMP_RECT_PRESSED
		fakeJumpButton.ImageTransparency = 0.05
	else
		fakeJumpButton.ImageRectOffset = JUMP_RECT_IDLE
		fakeJumpButton.ImageTransparency = 0.25
	end

	relayJumpInputToRealButton(pressed)

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Jump = pressed
		end
	end
end

trackConn(fakeJumpButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		if activeJumpInput == nil then
			activeJumpInput = input
			setJumpPressedState(true)
		end
	end
end))

trackConn(UserInputService.TouchEnded:Connect(function(input)
	if input == activeJumpInput then
		activeJumpInput = nil
		setJumpPressedState(false)
	end
end))

trackConn(UserInputService.InputEnded:Connect(function(input)
	if input == activeJumpInput then
		activeJumpInput = nil
		setJumpPressedState(false)
	end
end))

-- Keep Humanoid.Jump & TouchJump synced right after ControlModule runs each frame
RunService:BindToRenderStep("FakeJumpControlOverride", Enum.RenderPriority.Input.Value + 2, function()
	if isUnloaded or not isJumpHeld then return end
	if touchJumpController then
		pcall(function()
			touchJumpController.isJumping = true
		end)
	end
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Jump = true
		end
	end
end)

-- Keep Roblox's real JumpButton in its untouched default spot (so games that position
-- action buttons relative to JumpButton work normally) while hiding it visually
local stealthJumpConnections = {}
local trackedRealJumpButtons = {}

local function stealthRealJumpButton(button)
	if not button or not button:IsA("GuiObject") then return end
	currentRealJumpButton = button
	if stealthJumpConnections[button] then return end
	trackedRealJumpButtons[button] = true

	local function hideOnly()
		if isUnloaded then return end
		button.Active = false
		if button:IsA("ImageButton") or button:IsA("ImageLabel") then
			button.ImageTransparency = 1
		end
		button.BackgroundTransparency = 1
	end

	hideOnly()

	stealthJumpConnections[button] = {
		button:GetPropertyChangedSignal("ImageTransparency"):Connect(hideOnly),
		button:GetPropertyChangedSignal("Active"):Connect(hideOnly),
		button.AncestryChanged:Connect(function(_, parent)
			if not parent and stealthJumpConnections[button] then
				for _, conn in ipairs(stealthJumpConnections[button]) do
					conn:Disconnect()
				end
				stealthJumpConnections[button] = nil
				trackedRealJumpButtons[button] = nil
			end
		end)
	}
end

local function scanAndStealthRealJump()
	if isUnloaded then return end
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("GuiButton")
			and descendant ~= fakeJumpButton
			and (descendant.Name == "JumpButton" or descendant.Name == "Jump")
		then
			stealthRealJumpButton(descendant)
		end
	end
end

-- Classic Move Button (ThumbstickFrame) Resizer
local activeMoveConnections = {}
local trackedMoveFrames = {}
local isDraggingThumbstick = false
local thumbstickTouch = nil

trackConn(UserInputService.TouchEnded:Connect(function(input)
	if input == thumbstickTouch then
		isDraggingThumbstick = false
		thumbstickTouch = nil
	end
end))

local function applyClassicMoveLayout(frame)
	if not frame or not frame:IsA("GuiObject") then return end
	if activeMoveConnections[frame] then return end
	trackedMoveFrames[frame] = true

	-- Save original size & position so re-executing the script restores it cleanly
	if frame:GetAttribute("OrigMoveSizeX") == nil then
		frame:SetAttribute("OrigMoveSizeX", frame.Size.X.Offset)
		frame:SetAttribute("OrigMoveSizeY", frame.Size.Y.Offset)
		frame:SetAttribute("OrigMovePosXS", frame.Position.X.Scale)
		frame:SetAttribute("OrigMovePosXO", frame.Position.X.Offset)
		frame:SetAttribute("OrigMovePosYS", frame.Position.Y.Scale)
		frame:SetAttribute("OrigMovePosYO", frame.Position.Y.Offset)
	end

	local halfSize = math.round(MOVE_BUTTON_SIZE / 2)
	local quarterSize = math.round(MOVE_BUTTON_SIZE / 4)
	local restingPos = UDim2.new(0, MOVE_OFFSET_X, 1, -MOVE_BUTTON_SIZE - MOVE_OFFSET_Y)
	local restingStickPos = UDim2.new(0, quarterSize, 0, quarterSize)

	local isUpdating = false
	local function forceMoveLayout()
		if isUnloaded or isUpdating then return end
		isUpdating = true

		frame.AnchorPoint = Vector2.new(0, 0)
		frame.Size = UDim2.new(0, MOVE_BUTTON_SIZE, 0, MOVE_BUTTON_SIZE)

		local outer = frame:FindFirstChild("OuterImage")
		if outer and outer:IsA("GuiObject") then
			outer.Size = UDim2.new(1, 0, 1, 0)
			outer.Position = UDim2.new(0, 0, 0, 0)
		end

		local stick = frame:FindFirstChild("StickImage")
		if stick and stick:IsA("GuiObject") then
			stick.Size = UDim2.new(0, halfSize, 0, halfSize)
			if not isDraggingThumbstick then
				stick.Position = restingStickPos
			end
		end

		if not isDraggingThumbstick then
			frame.Position = restingPos
		end

		isUpdating = false
	end

	activeMoveConnections[frame] = {
		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and not thumbstickTouch then
				isDraggingThumbstick = true
				thumbstickTouch = input
			end
		end),
		frame:GetPropertyChangedSignal("Size"):Connect(forceMoveLayout),
		frame:GetPropertyChangedSignal("Position"):Connect(function()
			if not isDraggingThumbstick then
				forceMoveLayout()
			end
		end),
		frame.ChildAdded:Connect(function()
			task.defer(forceMoveLayout)
		end),
		frame.AncestryChanged:Connect(function(_, parent)
			if not parent and activeMoveConnections[frame] then
				for _, conn in pairs(activeMoveConnections[frame]) do
					conn:Disconnect()
				end
				activeMoveConnections[frame] = nil
				trackedMoveFrames[frame] = nil
			end
		end)
	}

	local stick = frame:FindFirstChild("StickImage")
	if stick and stick:IsA("GuiObject") then
		table.insert(activeMoveConnections[frame], stick:GetPropertyChangedSignal("Position"):Connect(function()
			if not isDraggingThumbstick then
				forceMoveLayout()
			end
		end))
	end

	forceMoveLayout()
end

local function scanAndApplyMove()
	if isUnloaded then return end
	for _, descendant in pairs(playerGui:GetDescendants()) do
		if descendant.Name == "ThumbstickFrame" and descendant:IsA("GuiObject") then
			applyClassicMoveLayout(descendant)
		end
	end
end

scanAndStealthRealJump()
scanAndApplyMove()

trackConn(playerGui.DescendantAdded:Connect(function(descendant)
	if isUnloaded then return end
	if descendant:IsA("GuiButton")
		and descendant ~= fakeJumpButton
		and (descendant.Name == "JumpButton" or descendant.Name == "Jump")
	then
		task.wait(0.1)
		stealthRealJumpButton(descendant)
	elseif descendant.Name == "ThumbstickFrame" and descendant:IsA("GuiObject") then
		task.wait(0.1)
		applyClassicMoveLayout(descendant)
	end
end))

-- --------------------------------------------------------------------
-- PART 4: TOUCH CONTROL PERSISTENCE FAILSAFE
-- --------------------------------------------------------------------
task.spawn(function()
	while not isUnloaded do
		task.wait(0.5)
		if isUnloaded then break end
		scanAndStealthRealJump()
		scanAndApplyMove()
		
		local touchGui = playerGui:FindFirstChild("TouchGui")
		if touchGui and not touchGui.Enabled then
			touchGui.Enabled = true
		end
	end
end)

-- --------------------------------------------------------------------
-- PART 5: CLEANUP / UNDO HANDLER (RUNS WHEN SCRIPT IS RE-EXECUTED)
-- --------------------------------------------------------------------
env.__CombinedHudCleanup = function()
	isUnloaded = true
	setJumpPressedState(false)
	deactivateShiftLock()

	pcall(function() RunService:UnbindFromRenderStep("FakeJumpControlOverride") end)
	pcall(function() RunService:UnbindFromRenderStep("MobileShiftLockStep") end)

	for _, conn in ipairs(allConnections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(allConnections)

	for _, conns in pairs(stealthJumpConnections) do
		for _, conn in ipairs(conns) do
			pcall(function() conn:Disconnect() end)
		end
	end
	table.clear(stealthJumpConnections)

	for _, conns in pairs(activeMoveConnections) do
		for _, conn in pairs(conns) do
			pcall(function() conn:Disconnect() end)
		end
	end
	table.clear(activeMoveConnections)

	-- Restore Roblox's real JumpButton
	for btn in pairs(trackedRealJumpButtons) do
		if btn and btn.Parent then
			btn.Active = true
			if btn:IsA("ImageButton") or btn:IsA("ImageLabel") then
				btn.ImageTransparency = 0
			end
		end
	end
	table.clear(trackedRealJumpButtons)

	-- Restore Roblox's Classic Move Joystick to original size & position
	for frame in pairs(trackedMoveFrames) do
		if frame and frame.Parent then
			local origSX = frame:GetAttribute("OrigMoveSizeX") or 70
			local origSY = frame:GetAttribute("OrigMoveSizeY") or 70
			local origPXS = frame:GetAttribute("OrigMovePosXS") or 0
			local origPXO = frame:GetAttribute("OrigMovePosXO") or 30
			local origPYS = frame:GetAttribute("OrigMovePosYS") or 1
			local origPYO = frame:GetAttribute("OrigMovePosYO") or -100

			frame.Size = UDim2.new(0, origSX, 0, origSY)
			frame.Position = UDim2.new(origPXS, origPXO, origPYS, origPYO)

			local stick = frame:FindFirstChild("StickImage")
			if stick and stick:IsA("GuiObject") then
				local sHalf = math.round(origSX / 2)
				local sQuarter = math.round(origSX / 4)
				stick.Size = UDim2.new(0, sHalf, 0, sHalf)
				stick.Position = UDim2.new(0, sQuarter, 0, sQuarter)
			end
		end
	end
	table.clear(trackedMoveFrames)

	if statGui then pcall(function() statGui:Destroy() end) end
	if shiftLockGui then pcall(function() shiftLockGui:Destroy() end) end
end
