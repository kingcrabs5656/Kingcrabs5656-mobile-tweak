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

local HttpService = game:GetService("HttpService")
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
-- CONFIGURATION & SCRIPT DEFAULTS
-- --------------------------------------------------------------------
local CONFIG_FILE_NAME = "CombinedHudConfig.json"
local MIN_CONTROL_SIZE = 50
local MAX_CONTROL_SIZE = 180

local SCRIPT_DEFAULT_JUMP_SIZE = 110
local SCRIPT_DEFAULT_MOVE_SIZE = 100
local SCRIPT_DEFAULT_JUMP_MODE = 1
local SCRIPT_DEFAULT_SHIFTLOCK = false
local SCRIPT_DEFAULT_SHOW_STATS = true

local MOVE_OFFSET_X = 55         -- Distance from left edge for classic move joystick
local MOVE_OFFSET_Y = 55         -- Distance from bottom edge for classic move joystick
local SHIFTLOCK_SIZE = 50        -- Size of Shift Lock button in pixels
local CORNER_PADDING_RIGHT = 12  -- Distance from literal right edge for Shift Lock
local CORNER_PADDING_BOTTOM = 12 -- Distance from literal bottom edge for Shift Lock
local CAMERA_OFFSET_RIGHT = 1.75 -- Right shoulder camera offset (in studs)

local currentJumpSize = SCRIPT_DEFAULT_JUMP_SIZE
local currentMoveSize = SCRIPT_DEFAULT_MOVE_SIZE
-- 3-State Jump Position Mode: 1 = LOW (Right), 2 = HIGH (Right), 3 = LEFT (Left)
local jumpMode = SCRIPT_DEFAULT_JUMP_MODE
local isShiftLockMasterEnabled = SCRIPT_DEFAULT_SHIFTLOCK
local isStatsEnabled = SCRIPT_DEFAULT_SHOW_STATS
local isUsingNativeJump = false
local isMoveAtNativeDefault = false

local function getRobloxDefaultControlSize()
	local cam = Workspace.CurrentCamera
	if cam and cam.ViewportSize.X > 0 and cam.ViewportSize.Y > 0 then
		local minAxis = math.min(cam.ViewportSize.X, cam.ViewportSize.Y)
		return (minAxis <= 500) and 70 or 120
	end
	return 70
end

local function loadSavedConfig()
	local data = nil

	if type(isfile) == "function" and type(readfile) == "function" then
		local okExists, exists = pcall(isfile, CONFIG_FILE_NAME)
		if okExists and exists then
			local okRead, raw = pcall(readfile, CONFIG_FILE_NAME)
			if okRead and type(raw) == "string" then
				local okDecode, decoded = pcall(function()
					return HttpService:JSONDecode(raw)
				end)
				if okDecode and type(decoded) == "table" then
					data = decoded
				end
			end
		end
	end

	if not data and type(env.__CombinedHudSavedConfig) == "table" then
		data = env.__CombinedHudSavedConfig
	end

	if data then
		if type(data.jumpMode) == "number" then
			jumpMode = math.clamp(math.round(data.jumpMode), 1, 3)
		end
		if type(data.jumpSize) == "number" then
			currentJumpSize = math.clamp(math.round(data.jumpSize), MIN_CONTROL_SIZE, MAX_CONTROL_SIZE)
		end
		if type(data.moveSize) == "number" then
			currentMoveSize = math.clamp(math.round(data.moveSize), MIN_CONTROL_SIZE, MAX_CONTROL_SIZE)
		end
		if type(data.shiftLockEnabled) == "boolean" then
			isShiftLockMasterEnabled = data.shiftLockEnabled
		end
		if type(data.showStats) == "boolean" then
			isStatsEnabled = data.showStats
		end
		if type(data.useNativeJump) == "boolean" then
			isUsingNativeJump = data.useNativeJump
		end
		if type(data.moveAtNativeDefault) == "boolean" then
			isMoveAtNativeDefault = data.moveAtNativeDefault
		end
	end
end

local function saveCurrentConfig()
	local payload = {
		jumpMode = jumpMode,
		jumpSize = currentJumpSize,
		moveSize = currentMoveSize,
		shiftLockEnabled = isShiftLockMasterEnabled,
		showStats = isStatsEnabled,
		useNativeJump = isUsingNativeJump,
		moveAtNativeDefault = isMoveAtNativeDefault,
	}
	env.__CombinedHudSavedConfig = payload

	if type(writefile) == "function" then
		pcall(function()
			writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(payload))
		end)
	end
end

loadSavedConfig()

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
statGui.Enabled = isStatsEnabled
statGui.Parent = playerGui

local statLabel = Instance.new("TextLabel")
statLabel.Name = "StatLabel"
statLabel.Size = UDim2.new(0, 128, 0, 22)
statLabel.Position = UDim2.new(0, 10, 0, 10)
statLabel.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
statLabel.BackgroundTransparency = 0.45
statLabel.TextColor3 = Color3.fromRGB(145, 225, 175)
statLabel.TextSize = 11
statLabel.Font = Enum.Font.GothamMedium
statLabel.TextXAlignment = Enum.TextXAlignment.Center
statLabel.Text = "Ping: 0ms | FPS: --"
statLabel.Active = false
statLabel.Parent = statGui

local statCorner = Instance.new("UICorner")
statCorner.CornerRadius = UDim.new(0, 5)
statCorner.Parent = statLabel

local statStroke = Instance.new("UIStroke")
statStroke.Color = Color3.fromRGB(255, 255, 255)
statStroke.Transparency = 0.88
statStroke.Thickness = 1
statStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
statStroke.Parent = statLabel

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
	if isUnloaded or not isStatsEnabled then return end
	frameCounter += 1
	lastUpdate += deltaTime
	
	if lastUpdate >= 0.5 then
		local currentFps = math.round(frameCounter / lastUpdate)
		frameCounter = 0
		lastUpdate = 0
		
		local ping = getPing()
		statLabel.Text = string.format("Ping: %dms | FPS: %d", ping, currentFps)
		
		if ping < 80 then
			statLabel.TextColor3 = Color3.fromRGB(145, 225, 175)
		elseif ping < 150 then
			statLabel.TextColor3 = Color3.fromRGB(235, 205, 130)
		else
			statLabel.TextColor3 = Color3.fromRGB(235, 135, 135)
		end
	end
end))

-- --------------------------------------------------------------------
-- PART 2: SHIFT LOCK, MENU & SETTINGS PANEL
-- --------------------------------------------------------------------
local shiftLockGui = Instance.new("ScreenGui")
shiftLockGui.Name = "ShiftLockGui"
shiftLockGui.ResetOnSpawn = false
shiftLockGui.DisplayOrder = 9999
shiftLockGui.Parent = playerGui

-- Bottom-Right Shift Lock Button (Clean neutral dark style)
local shiftLockButton = Instance.new("TextButton")
shiftLockButton.Name = "ShiftLockButton"
shiftLockButton.Size = UDim2.new(0, SHIFTLOCK_SIZE, 0, SHIFTLOCK_SIZE)
shiftLockButton.Position = UDim2.new(1, -CORNER_PADDING_RIGHT, 1, -CORNER_PADDING_BOTTOM)
shiftLockButton.AnchorPoint = Vector2.new(1, 1)
shiftLockButton.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
shiftLockButton.BackgroundTransparency = 0.65
shiftLockButton.Text = "🔒"
shiftLockButton.TextColor3 = Color3.fromRGB(235, 238, 242)
shiftLockButton.TextSize = 22
shiftLockButton.Font = Enum.Font.GothamBold
shiftLockButton.AutoButtonColor = false
shiftLockButton.Visible = isShiftLockMasterEnabled
shiftLockButton.Parent = shiftLockGui

local lockCorner = Instance.new("UICorner")
lockCorner.CornerRadius = UDim.new(1, 0)
lockCorner.Parent = shiftLockButton

-- Forward declarations for live layout updaters
local updateFakeJumpPosition
local refreshAllMoveLayouts
local refreshAllRealJumpButtons
local setJumpPressedState
local currentRealJumpButton = nil
local trackedMoveFrames = {}

-- Bottom-Left MENU Toggle Button
local menuToggleBtn = Instance.new("TextButton")
menuToggleBtn.Name = "HudMenuToggle"
menuToggleBtn.Size = UDim2.new(0, 56, 0, 28)
menuToggleBtn.Position = UDim2.new(0, 12, 1, -12)
menuToggleBtn.AnchorPoint = Vector2.new(0, 1)
menuToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
menuToggleBtn.BackgroundTransparency = 0.45
menuToggleBtn.Text = "MENU"
menuToggleBtn.TextColor3 = Color3.fromRGB(225, 230, 236)
menuToggleBtn.Font = Enum.Font.GothamBold
menuToggleBtn.TextSize = 11
menuToggleBtn.AutoButtonColor = false
menuToggleBtn.Parent = shiftLockGui

local menuBtnCorner = Instance.new("UICorner")
menuBtnCorner.CornerRadius = UDim.new(0, 6)
menuBtnCorner.Parent = menuToggleBtn

local menuBtnStroke = Instance.new("UIStroke")
menuBtnStroke.Color = Color3.fromRGB(70, 78, 90)
menuBtnStroke.Thickness = 1.2
menuBtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
menuBtnStroke.Parent = menuToggleBtn

-- Floating Settings Menu Panel (Opens above bottom-left MENU button)
local menuFrame = Instance.new("Frame")
menuFrame.Name = "HudSettingsMenu"
menuFrame.Size = UDim2.new(0, 240, 0, 280)
menuFrame.Position = UDim2.new(0, 12, 1, -46)
menuFrame.AnchorPoint = Vector2.new(0, 1)
menuFrame.BackgroundColor3 = Color3.fromRGB(18, 21, 26)
menuFrame.BackgroundTransparency = 0.08
menuFrame.Active = true
menuFrame.Visible = false
menuFrame.ZIndex = 50
menuFrame.Parent = shiftLockGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 8)
menuCorner.Parent = menuFrame

local menuStroke = Instance.new("UIStroke")
menuStroke.Color = Color3.fromRGB(62, 72, 86)
menuStroke.Thickness = 1.2
menuStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
menuStroke.Parent = menuFrame

-- Menu Header
local menuTitle = Instance.new("TextLabel")
menuTitle.Name = "Title"
menuTitle.Size = UDim2.new(1, -40, 0, 26)
menuTitle.Position = UDim2.new(0, 10, 0, 4)
menuTitle.BackgroundTransparency = 1
menuTitle.Text = "HUD SETTINGS"
menuTitle.TextColor3 = Color3.fromRGB(230, 235, 242)
menuTitle.Font = Enum.Font.GothamBold
menuTitle.TextSize = 12
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.ZIndex = 51
menuTitle.Parent = menuFrame

local closeMenuBtn = Instance.new("TextButton")
closeMenuBtn.Name = "CloseButton"
closeMenuBtn.Size = UDim2.new(0, 22, 0, 22)
closeMenuBtn.Position = UDim2.new(1, -6, 0, 6)
closeMenuBtn.AnchorPoint = Vector2.new(1, 0)
closeMenuBtn.BackgroundColor3 = Color3.fromRGB(32, 37, 45)
closeMenuBtn.Text = "X"
closeMenuBtn.TextColor3 = Color3.fromRGB(195, 202, 212)
closeMenuBtn.Font = Enum.Font.GothamBold
closeMenuBtn.TextSize = 11
closeMenuBtn.AutoButtonColor = false
closeMenuBtn.ZIndex = 51
closeMenuBtn.Parent = menuFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = closeMenuBtn

local headerDivider = Instance.new("Frame")
headerDivider.Size = UDim2.new(1, -20, 0, 1)
headerDivider.Position = UDim2.new(0, 10, 0, 32)
headerDivider.BackgroundColor3 = Color3.fromRGB(48, 56, 68)
headerDivider.BorderSizePixel = 0
headerDivider.ZIndex = 51
headerDivider.Parent = menuFrame

local cancelAllConfirmations -- Forward declaration

local function setMenuOpen(open)
	menuFrame.Visible = open
	if not open and cancelAllConfirmations then
		cancelAllConfirmations()
	end
	if open then
		menuToggleBtn.BackgroundColor3 = Color3.fromRGB(34, 42, 54)
		menuToggleBtn.TextColor3 = Color3.fromRGB(245, 248, 252)
		menuBtnStroke.Color = Color3.fromRGB(115, 130, 150)
	else
		menuToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
		menuToggleBtn.TextColor3 = Color3.fromRGB(225, 230, 236)
		menuBtnStroke.Color = Color3.fromRGB(70, 78, 90)
	end
end

trackConn(menuToggleBtn.MouseButton1Click:Connect(function()
	setMenuOpen(not menuFrame.Visible)
end))

trackConn(closeMenuBtn.MouseButton1Click:Connect(function()
	setMenuOpen(false)
end))

-- Inside Menu Row 1: Master Shift Lock Toggle (SL)
local slRowLabel = Instance.new("TextLabel")
slRowLabel.Size = UDim2.new(0, 110, 0, 26)
slRowLabel.Position = UDim2.new(0, 10, 0, 38)
slRowLabel.BackgroundTransparency = 1
slRowLabel.Text = "Shift Lock"
slRowLabel.TextColor3 = Color3.fromRGB(205, 212, 220)
slRowLabel.Font = Enum.Font.GothamMedium
slRowLabel.TextSize = 12
slRowLabel.TextXAlignment = Enum.TextXAlignment.Left
slRowLabel.ZIndex = 51
slRowLabel.Parent = menuFrame

local masterToggleBtn = Instance.new("TextButton")
masterToggleBtn.Name = "MasterShiftLockToggle"
masterToggleBtn.Size = UDim2.new(0, 95, 0, 24)
masterToggleBtn.Position = UDim2.new(1, -10, 0, 39)
masterToggleBtn.AnchorPoint = Vector2.new(1, 0)
masterToggleBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
masterToggleBtn.Text = "SL: OFF"
masterToggleBtn.TextColor3 = Color3.fromRGB(175, 182, 192)
masterToggleBtn.Font = Enum.Font.GothamBold
masterToggleBtn.TextSize = 11
masterToggleBtn.AutoButtonColor = false
masterToggleBtn.ZIndex = 51
masterToggleBtn.Parent = menuFrame

local masterCorner = Instance.new("UICorner")
masterCorner.CornerRadius = UDim.new(0, 5)
masterCorner.Parent = masterToggleBtn

local masterStroke = Instance.new("UIStroke")
masterStroke.Color = Color3.fromRGB(70, 78, 90)
masterStroke.Thickness = 1.2
masterStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
masterStroke.Parent = masterToggleBtn

local function refreshShiftLockMasterVisual()
	if isShiftLockMasterEnabled then
		masterToggleBtn.Text = "SL: ON"
		masterToggleBtn.TextColor3 = Color3.fromRGB(145, 225, 185)
		masterStroke.Color = Color3.fromRGB(75, 145, 115)
		masterToggleBtn.BackgroundColor3 = Color3.fromRGB(24, 46, 38)
		shiftLockButton.Visible = true
	else
		masterToggleBtn.Text = "SL: OFF"
		masterToggleBtn.TextColor3 = Color3.fromRGB(175, 182, 192)
		masterStroke.Color = Color3.fromRGB(70, 78, 90)
		masterToggleBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
		shiftLockButton.Visible = false
	end
end

refreshShiftLockMasterVisual()

-- Inside Menu Row 2: FPS / Ping Counter Toggle
local statsRowLabel = Instance.new("TextLabel")
statsRowLabel.Size = UDim2.new(0, 110, 0, 26)
statsRowLabel.Position = UDim2.new(0, 10, 0, 70)
statsRowLabel.BackgroundTransparency = 1
statsRowLabel.Text = "FPS / Ping"
statsRowLabel.TextColor3 = Color3.fromRGB(205, 212, 220)
statsRowLabel.Font = Enum.Font.GothamMedium
statsRowLabel.TextSize = 12
statsRowLabel.TextXAlignment = Enum.TextXAlignment.Left
statsRowLabel.ZIndex = 51
statsRowLabel.Parent = menuFrame

local statsToggleBtn = Instance.new("TextButton")
statsToggleBtn.Name = "StatsToggleButton"
statsToggleBtn.Size = UDim2.new(0, 95, 0, 24)
statsToggleBtn.Position = UDim2.new(1, -10, 0, 71)
statsToggleBtn.AnchorPoint = Vector2.new(1, 0)
statsToggleBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
statsToggleBtn.Text = "STATS: ON"
statsToggleBtn.TextColor3 = Color3.fromRGB(145, 225, 185)
statsToggleBtn.Font = Enum.Font.GothamBold
statsToggleBtn.TextSize = 11
statsToggleBtn.AutoButtonColor = false
statsToggleBtn.ZIndex = 51
statsToggleBtn.Parent = menuFrame

local statsToggleCorner = Instance.new("UICorner")
statsToggleCorner.CornerRadius = UDim.new(0, 5)
statsToggleCorner.Parent = statsToggleBtn

local statsToggleStroke = Instance.new("UIStroke")
statsToggleStroke.Color = Color3.fromRGB(70, 78, 90)
statsToggleStroke.Thickness = 1.2
statsToggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
statsToggleStroke.Parent = statsToggleBtn

local function refreshStatsToggleVisual()
	statGui.Enabled = isStatsEnabled
	if isStatsEnabled then
		statsToggleBtn.Text = "STATS: ON"
		statsToggleBtn.TextColor3 = Color3.fromRGB(145, 225, 185)
		statsToggleStroke.Color = Color3.fromRGB(75, 145, 115)
		statsToggleBtn.BackgroundColor3 = Color3.fromRGB(24, 46, 38)
	else
		statsToggleBtn.Text = "STATS: OFF"
		statsToggleBtn.TextColor3 = Color3.fromRGB(175, 182, 192)
		statsToggleStroke.Color = Color3.fromRGB(70, 78, 90)
		statsToggleBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	end
end

refreshStatsToggleVisual()

trackConn(statsToggleBtn.MouseButton1Click:Connect(function()
	isStatsEnabled = not isStatsEnabled
	refreshStatsToggleVisual()
end))

-- Inside Menu Row 3: Jump Position Selector
local posRowLabel = Instance.new("TextLabel")
posRowLabel.Size = UDim2.new(0, 110, 0, 26)
posRowLabel.Position = UDim2.new(0, 10, 0, 102)
posRowLabel.BackgroundTransparency = 1
posRowLabel.Text = "Jump Position"
posRowLabel.TextColor3 = Color3.fromRGB(205, 212, 220)
posRowLabel.Font = Enum.Font.GothamMedium
posRowLabel.TextSize = 12
posRowLabel.TextXAlignment = Enum.TextXAlignment.Left
posRowLabel.ZIndex = 51
posRowLabel.Parent = menuFrame

local jumpPosBtn = Instance.new("TextButton")
jumpPosBtn.Name = "JumpPositionButton"
jumpPosBtn.Size = UDim2.new(0, 95, 0, 24)
jumpPosBtn.Position = UDim2.new(1, -10, 0, 103)
jumpPosBtn.AnchorPoint = Vector2.new(1, 0)
jumpPosBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
jumpPosBtn.Text = "POS: LOW"
jumpPosBtn.TextColor3 = Color3.fromRGB(220, 226, 234)
jumpPosBtn.Font = Enum.Font.GothamBold
jumpPosBtn.TextSize = 11
jumpPosBtn.AutoButtonColor = false
jumpPosBtn.ZIndex = 51
jumpPosBtn.Parent = menuFrame

local jumpPosCorner = Instance.new("UICorner")
jumpPosCorner.CornerRadius = UDim.new(0, 5)
jumpPosCorner.Parent = jumpPosBtn

local jumpPosStroke = Instance.new("UIStroke")
jumpPosStroke.Color = Color3.fromRGB(70, 78, 90)
jumpPosStroke.Thickness = 1.2
jumpPosStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
jumpPosStroke.Parent = jumpPosBtn

local function refreshJumpPosButtonVisual()
	if jumpMode == 1 then
		jumpPosBtn.Text = "POS: LOW"
		jumpPosBtn.TextColor3 = Color3.fromRGB(220, 226, 234)
		jumpPosBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
		jumpPosStroke.Color = Color3.fromRGB(70, 78, 90)
	elseif jumpMode == 2 then
		jumpPosBtn.Text = "POS: HIGH"
		jumpPosBtn.TextColor3 = Color3.fromRGB(150, 205, 240)
		jumpPosBtn.BackgroundColor3 = Color3.fromRGB(26, 40, 56)
		jumpPosStroke.Color = Color3.fromRGB(75, 125, 165)
	elseif jumpMode == 3 then
		jumpPosBtn.Text = "POS: LEFT"
		jumpPosBtn.TextColor3 = Color3.fromRGB(200, 170, 235)
		jumpPosBtn.BackgroundColor3 = Color3.fromRGB(42, 30, 54)
		jumpPosStroke.Color = Color3.fromRGB(120, 90, 155)
	end
end

refreshJumpPosButtonVisual()

trackConn(jumpPosBtn.MouseButton1Click:Connect(function()
	jumpMode += 1
	if jumpMode > 3 then
		jumpMode = 1
	end
	refreshJumpPosButtonVisual()
	isUsingNativeJump = false
	if updateFakeJumpPosition then
		updateFakeJumpPosition()
	end
	if refreshAllRealJumpButtons then
		refreshAllRealJumpButtons()
	end
end))

-- Helper to create smooth touch/mouse sliders inside the menu
local function createMenuSlider(yPos, titleText, minVal, maxVal, initialVal, accentColor, textAccentColor, onValueChanged)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -20, 0, 42)
	container.Position = UDim2.new(0, 10, 0, yPos)
	container.BackgroundTransparency = 1
	container.ZIndex = 51
	container.Parent = menuFrame

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.65, 0, 0, 18)
	titleLbl.Position = UDim2.new(0, 0, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = titleText
	titleLbl.TextColor3 = Color3.fromRGB(205, 212, 220)
	titleLbl.Font = Enum.Font.GothamMedium
	titleLbl.TextSize = 12
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 52
	titleLbl.Parent = container

	local valueLbl = Instance.new("TextLabel")
	valueLbl.Size = UDim2.new(0.35, 0, 0, 18)
	valueLbl.Position = UDim2.new(1, 0, 0, 0)
	valueLbl.AnchorPoint = Vector2.new(1, 0)
	valueLbl.BackgroundTransparency = 1
	valueLbl.Text = tostring(initialVal) .. "px"
	valueLbl.TextColor3 = textAccentColor
	valueLbl.Font = Enum.Font.GothamBold
	valueLbl.TextSize = 11
	valueLbl.TextXAlignment = Enum.TextXAlignment.Right
	valueLbl.ZIndex = 52
	valueLbl.Parent = container

	-- Larger invisible hit-box so mobile fingers can grab the slider easily
	local hitArea = Instance.new("TextButton")
	hitArea.Size = UDim2.new(1, 0, 0, 24)
	hitArea.Position = UDim2.new(0, 0, 0, 18)
	hitArea.BackgroundTransparency = 1
	hitArea.Text = ""
	hitArea.AutoButtonColor = false
	hitArea.Active = true
	hitArea.ZIndex = 53
	hitArea.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0.5, 0)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.BackgroundColor3 = Color3.fromRGB(38, 44, 54)
	track.BorderSizePixel = 0
	track.ZIndex = 52
	track.Parent = hitArea

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = accentColor
	fill.BorderSizePixel = 0
	fill.ZIndex = 53
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(235, 240, 246)
	knob.BorderSizePixel = 0
	knob.ZIndex = 54
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local activeDragInput = nil

	local function setSliderValue(newVal, silent)
		local clamped = math.clamp(math.round(newVal), minVal, maxVal)
		local alpha = (clamped - minVal) / (maxVal - minVal)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLbl.Text = tostring(clamped) .. "px"
		if not silent and onValueChanged then
			onValueChanged(clamped)
		end
	end

	local function updateFromScreenX(screenX)
		local absPos = track.AbsolutePosition.X
		local absSize = track.AbsoluteSize.X
		if absSize <= 0 then return end
		local alpha = math.clamp((screenX - absPos) / absSize, 0, 1)
		local rawVal = minVal + alpha * (maxVal - minVal)
		setSliderValue(rawVal, false)
	end

	trackConn(hitArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			activeDragInput = input
			updateFromScreenX(input.Position.X)
		end
	end))

	trackConn(UserInputService.InputChanged:Connect(function(input)
		if activeDragInput and input == activeDragInput then
			updateFromScreenX(input.Position.X)
		end
	end))

	trackConn(UserInputService.InputEnded:Connect(function(input)
		if activeDragInput and input == activeDragInput then
			activeDragInput = nil
		end
	end))

	trackConn(UserInputService.TouchEnded:Connect(function(input)
		if activeDragInput and input == activeDragInput then
			activeDragInput = nil
		end
	end))

	setSliderValue(initialVal, true)
	return setSliderValue
end

-- Inside Menu Row 4: Jump Size Slider
local setJumpSlider = createMenuSlider(
	136,
	"Jump Size",
	MIN_CONTROL_SIZE,
	MAX_CONTROL_SIZE,
	currentJumpSize,
	Color3.fromRGB(75, 165, 225),
	Color3.fromRGB(155, 205, 238),
	function(newSize)
		currentJumpSize = newSize
		isUsingNativeJump = false
		if updateFakeJumpPosition then
			updateFakeJumpPosition()
		end
		if refreshAllRealJumpButtons then
			refreshAllRealJumpButtons()
		end
	end
)

-- Inside Menu Row 5: Joystick Size Slider
local setMoveSlider = createMenuSlider(
	184,
	"Joystick Size",
	MIN_CONTROL_SIZE,
	MAX_CONTROL_SIZE,
	currentMoveSize,
	Color3.fromRGB(85, 195, 135),
	Color3.fromRGB(150, 220, 180),
	function(newSize)
		currentMoveSize = newSize
		isMoveAtNativeDefault = false
		if refreshAllMoveLayouts then
			refreshAllMoveLayouts()
		end
	end
)

-- Inside Menu Bottom Row: Default, Reset & Save Buttons (with "Are you sure?" confirmation)
local defaultBtn = Instance.new("TextButton")
defaultBtn.Name = "DefaultSizeButton"
defaultBtn.Size = UDim2.new(0, 70, 0, 28)
defaultBtn.Position = UDim2.new(0, 10, 1, -10)
defaultBtn.AnchorPoint = Vector2.new(0, 1)
defaultBtn.BackgroundColor3 = Color3.fromRGB(34, 39, 48)
defaultBtn.Text = "Default"
defaultBtn.TextColor3 = Color3.fromRGB(220, 226, 234)
defaultBtn.Font = Enum.Font.GothamBold
defaultBtn.TextSize = 11
defaultBtn.AutoButtonColor = false
defaultBtn.ZIndex = 52
defaultBtn.Parent = menuFrame

local defaultCorner = Instance.new("UICorner")
defaultCorner.CornerRadius = UDim.new(0, 6)
defaultCorner.Parent = defaultBtn

local defaultStroke = Instance.new("UIStroke")
defaultStroke.Color = Color3.fromRGB(72, 80, 92)
defaultStroke.Thickness = 1.2
defaultStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
defaultStroke.Parent = defaultBtn

local resetBtn = Instance.new("TextButton")
resetBtn.Name = "ResetScriptButton"
resetBtn.Size = UDim2.new(0, 70, 0, 28)
resetBtn.Position = UDim2.new(0, 85, 1, -10)
resetBtn.AnchorPoint = Vector2.new(0, 1)
resetBtn.BackgroundColor3 = Color3.fromRGB(52, 30, 34)
resetBtn.Text = "Reset"
resetBtn.TextColor3 = Color3.fromRGB(235, 155, 155)
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 11
resetBtn.AutoButtonColor = false
resetBtn.ZIndex = 52
resetBtn.Parent = menuFrame

local resetCorner = Instance.new("UICorner")
resetCorner.CornerRadius = UDim.new(0, 6)
resetCorner.Parent = resetBtn

local resetStroke = Instance.new("UIStroke")
resetStroke.Color = Color3.fromRGB(130, 68, 75)
resetStroke.Thickness = 1.2
resetStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
resetStroke.Parent = resetBtn

local saveBtn = Instance.new("TextButton")
saveBtn.Name = "SaveConfigButton"
saveBtn.Size = UDim2.new(0, 70, 0, 28)
saveBtn.Position = UDim2.new(0, 160, 1, -10)
saveBtn.AnchorPoint = Vector2.new(0, 1)
saveBtn.BackgroundColor3 = Color3.fromRGB(24, 52, 40)
saveBtn.Text = "Save"
saveBtn.TextColor3 = Color3.fromRGB(145, 225, 180)
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 11
saveBtn.AutoButtonColor = false
saveBtn.ZIndex = 52
saveBtn.Parent = menuFrame

local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0, 6)
saveCorner.Parent = saveBtn

local saveStroke = Instance.new("UIStroke")
saveStroke.Color = Color3.fromRGB(58, 135, 98)
saveStroke.Thickness = 1.2
saveStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
saveStroke.Parent = saveBtn

local confirmResetCallbacks = {}

cancelAllConfirmations = function()
	for _, resetFn in ipairs(confirmResetCallbacks) do
		resetFn()
	end
end

local function bindTwoStepConfirm(cfg)
	local btn = cfg.button
	local stroke = cfg.stroke
	local isConfirming = false
	local stateToken = 0

	local function restoreNormal()
		isConfirming = false
		if btn and btn.Parent then
			btn.Text = cfg.normalText
			btn.TextSize = 11
			btn.BackgroundColor3 = cfg.normalBg
			btn.TextColor3 = cfg.normalTextColor
		end
		if stroke and stroke.Parent then
			stroke.Color = cfg.normalStrokeColor
		end
	end

	table.insert(confirmResetCallbacks, function()
		if isConfirming then
			stateToken += 1
			restoreNormal()
		end
	end)

	trackConn(btn.MouseButton1Click:Connect(function()
		if not isConfirming then
			cancelAllConfirmations()
			isConfirming = true
			stateToken += 1
			local myToken = stateToken

			btn.Text = "Are you sure?"
			btn.TextSize = 9
			btn.BackgroundColor3 = cfg.confirmBg
			btn.TextColor3 = cfg.confirmTextColor
			stroke.Color = cfg.confirmStrokeColor

			task.delay(3.0, function()
				if isUnloaded or stateToken ~= myToken or not isConfirming then return end
				restoreNormal()
			end)
		else
			isConfirming = false
			stateToken += 1
			local myToken = stateToken

			if cfg.onConfirm then
				cfg.onConfirm()
			end

			btn.Text = cfg.doneText
			btn.TextSize = 11
			btn.BackgroundColor3 = cfg.doneBg
			btn.TextColor3 = cfg.doneTextColor
			stroke.Color = cfg.normalStrokeColor

			task.delay(1.2, function()
				if isUnloaded or stateToken ~= myToken or isConfirming then return end
				restoreNormal()
			end)
		end
	end))
end

local function getDefaultJumpSize()
	if currentRealJumpButton and currentRealJumpButton:GetAttribute("OrigJumpSizeXO") and currentRealJumpButton:GetAttribute("OrigJumpSizeXO") > 0 then
		return math.clamp(currentRealJumpButton:GetAttribute("OrigJumpSizeXO"), MIN_CONTROL_SIZE, MAX_CONTROL_SIZE)
	end
	return getRobloxDefaultControlSize()
end

local function getDefaultMoveSize()
	for frame in pairs(trackedMoveFrames) do
		if frame and frame:GetAttribute("OrigMoveSizeX") and frame:GetAttribute("OrigMoveSizeX") > 0 then
			return math.clamp(frame:GetAttribute("OrigMoveSizeX"), MIN_CONTROL_SIZE, MAX_CONTROL_SIZE)
		end
	end
	return getRobloxDefaultControlSize()
end

-- Shift Lock Logic
local isShiftLockActive = false
local isShiftLockBound = false

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
		elseif hum then
			hum.AutoRotate = true
		end
	end
end

local function bindShiftLockStep()
	if isShiftLockBound then return end
	isShiftLockBound = true
	RunService:BindToRenderStep("MobileShiftLockStep", Enum.RenderPriority.Camera.Value + 1, updateShiftLockStep)
end

local function unbindShiftLockStep()
	if not isShiftLockBound then return end
	isShiftLockBound = false
	pcall(function()
		RunService:UnbindFromRenderStep("MobileShiftLockStep")
	end)
end

local function deactivateShiftLock()
	isShiftLockActive = false
	if shiftLockButton and shiftLockButton.Parent then
		shiftLockButton.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
		shiftLockButton.BackgroundTransparency = 0.65
	end
	
	unbindShiftLockStep()
	
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
		shiftLockButton.BackgroundColor3 = Color3.fromRGB(58, 64, 74)
		shiftLockButton.BackgroundTransparency = 0.35
		
		bindShiftLockStep()
	else
		deactivateShiftLock()
	end
end

trackConn(shiftLockButton.MouseButton1Click:Connect(toggleShiftLock))

trackConn(masterToggleBtn.MouseButton1Click:Connect(function()
	isShiftLockMasterEnabled = not isShiftLockMasterEnabled
	refreshShiftLockMasterVisual()
	if not isShiftLockMasterEnabled then
		deactivateShiftLock()
	end
end))

-- Bind Default Button ("Are you sure?" -> removes fake jump button, restores Roblox's native jump & move sizes)
bindTwoStepConfirm({
	button = defaultBtn,
	stroke = defaultStroke,
	normalText = "Default",
	normalBg = Color3.fromRGB(34, 39, 48),
	normalTextColor = Color3.fromRGB(220, 226, 234),
	normalStrokeColor = Color3.fromRGB(72, 80, 92),
	confirmBg = Color3.fromRGB(64, 54, 28),
	confirmTextColor = Color3.fromRGB(245, 222, 155),
	confirmStrokeColor = Color3.fromRGB(155, 130, 62),
	doneText = "Restored!",
	doneBg = Color3.fromRGB(48, 56, 70),
	doneTextColor = Color3.fromRGB(245, 248, 252),
	onConfirm = function()
		if setJumpPressedState then
			setJumpPressedState(false)
		end
		isUsingNativeJump = true
		isMoveAtNativeDefault = true

		local defJump = getDefaultJumpSize()
		local defMove = getDefaultMoveSize()
		currentJumpSize = defJump
		currentMoveSize = defMove

		setJumpSlider(defJump, true)
		setMoveSlider(defMove, true)

		if updateFakeJumpPosition then
			updateFakeJumpPosition()
		end
		if refreshAllRealJumpButtons then
			refreshAllRealJumpButtons()
		end
		if refreshAllMoveLayouts then
			refreshAllMoveLayouts()
		end
	end,
})

-- Bind Reset Button ("Are you sure?" -> restores every setting back to the script's defaults)
bindTwoStepConfirm({
	button = resetBtn,
	stroke = resetStroke,
	normalText = "Reset",
	normalBg = Color3.fromRGB(52, 30, 34),
	normalTextColor = Color3.fromRGB(235, 155, 155),
	normalStrokeColor = Color3.fromRGB(130, 68, 75),
	confirmBg = Color3.fromRGB(88, 36, 42),
	confirmTextColor = Color3.fromRGB(250, 210, 210),
	confirmStrokeColor = Color3.fromRGB(185, 85, 95),
	doneText = "Reset!",
	doneBg = Color3.fromRGB(76, 38, 44),
	doneTextColor = Color3.fromRGB(245, 230, 230),
	onConfirm = function()
		isShiftLockMasterEnabled = SCRIPT_DEFAULT_SHIFTLOCK
		refreshShiftLockMasterVisual()
		if not isShiftLockMasterEnabled then
			deactivateShiftLock()
		end

		isStatsEnabled = SCRIPT_DEFAULT_SHOW_STATS
		refreshStatsToggleVisual()

		isUsingNativeJump = false
		isMoveAtNativeDefault = false

		jumpMode = SCRIPT_DEFAULT_JUMP_MODE
		refreshJumpPosButtonVisual()

		currentJumpSize = SCRIPT_DEFAULT_JUMP_SIZE
		currentMoveSize = SCRIPT_DEFAULT_MOVE_SIZE
		setJumpSlider(SCRIPT_DEFAULT_JUMP_SIZE, true)
		setMoveSlider(SCRIPT_DEFAULT_MOVE_SIZE, true)

		if updateFakeJumpPosition then
			updateFakeJumpPosition()
		end
		if refreshAllRealJumpButtons then
			refreshAllRealJumpButtons()
		end
		if refreshAllMoveLayouts then
			refreshAllMoveLayouts()
		end
	end,
})

-- Bind Save Button ("Are you sure?" -> writes current settings to disk & session memory)
bindTwoStepConfirm({
	button = saveBtn,
	stroke = saveStroke,
	normalText = "Save",
	normalBg = Color3.fromRGB(24, 52, 40),
	normalTextColor = Color3.fromRGB(145, 225, 180),
	normalStrokeColor = Color3.fromRGB(58, 135, 98),
	confirmBg = Color3.fromRGB(32, 74, 55),
	confirmTextColor = Color3.fromRGB(215, 248, 228),
	confirmStrokeColor = Color3.fromRGB(85, 175, 130),
	doneText = "Saved!",
	doneBg = Color3.fromRGB(34, 76, 58),
	doneTextColor = Color3.fromRGB(235, 248, 240),
	onConfirm = function()
		saveCurrentConfig()
	end,
})

trackConn(player.CharacterAdded:Connect(function(char)
	task.wait(0.2)
	if isUnloaded then return end
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
	
	if isShiftLockActive and isShiftLockMasterEnabled then
		bindShiftLockStep()
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
fakeJumpButton.Size = UDim2.new(0, currentJumpSize, 0, currentJumpSize)
fakeJumpButton.BackgroundTransparency = 1
fakeJumpButton.Image = JUMP_SHEET
fakeJumpButton.ImageRectOffset = JUMP_RECT_IDLE
fakeJumpButton.ImageRectSize = JUMP_RECT_SIZE
fakeJumpButton.ImageTransparency = 0.25
fakeJumpButton.AutoButtonColor = false
fakeJumpButton.Active = true
fakeJumpButton.Visible = not isUsingNativeJump
fakeJumpButton.ZIndex = 10
fakeJumpButton.Parent = shiftLockGui

updateFakeJumpPosition = function()
	fakeJumpButton.Visible = not isUsingNativeJump
	fakeJumpButton.Size = UDim2.new(0, currentJumpSize, 0, currentJumpSize)
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
local isJumpHeld = false
local activeJumpInput = nil
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

setJumpPressedState = function(pressed)
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
	if isUsingNativeJump then return end
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
	if isUnloaded or isUsingNativeJump or not isJumpHeld then return end
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

-- Park Roblox's real JumpButton off-screen with 0x0 size when FakeJump is active so tapping
-- the bottom-right corner never triggers ghost jumps, and restore it when Default is active
local stealthJumpConnections = {}
local trackedRealJumpButtons = {}
local realJumpRefreshers = {}

refreshAllRealJumpButtons = function()
	for _, refreshFn in pairs(realJumpRefreshers) do
		refreshFn()
	end
end

local function restoreRealJumpToNative(button)
	if not button or not button.Parent then return end
	local defSize = getRobloxDefaultControlSize()
	local origSXS = button:GetAttribute("OrigJumpSizeXS") or 0
	local origSXO = button:GetAttribute("OrigJumpSizeXO")
	if not origSXO or origSXO <= 0 then origSXO = defSize end
	local origSYS = button:GetAttribute("OrigJumpSizeYS") or 0
	local origSYO = button:GetAttribute("OrigJumpSizeYO")
	if not origSYO or origSYO <= 0 then origSYO = defSize end

	local origPXS = button:GetAttribute("OrigJumpPosXS") or 1
	local origPXO = button:GetAttribute("OrigJumpPosXO") or -(defSize + 30)
	local origPYS = button:GetAttribute("OrigJumpPosYS") or 1
	local origPYO = button:GetAttribute("OrigJumpPosYO") or -(defSize + 20)
	local origAX = button:GetAttribute("OrigJumpAnchorX") or 0
	local origAY = button:GetAttribute("OrigJumpAnchorY") or 0

	button.AnchorPoint = Vector2.new(origAX, origAY)
	button.Size = UDim2.new(origSXS, origSXO, origSYS, origSYO)
	button.Position = UDim2.new(origPXS, origPXO, origPYS, origPYO)
	button.Active = true
	if button:IsA("ImageButton") or button:IsA("ImageLabel") then
		button.ImageTransparency = 0
	end
end

local function stealthRealJumpButton(button)
	if not button or not button:IsA("GuiObject") then return end
	currentRealJumpButton = button
	if stealthJumpConnections[button] then
		if realJumpRefreshers[button] then
			realJumpRefreshers[button]()
		end
		return
	end
	trackedRealJumpButtons[button] = true

	-- Save Roblox's original JumpButton layout before parking it off-screen
	if button:GetAttribute("OrigJumpSizeXO") == nil and button.Size.X.Offset > 0 then
		button:SetAttribute("OrigJumpSizeXS", button.Size.X.Scale)
		button:SetAttribute("OrigJumpSizeXO", button.Size.X.Offset)
		button:SetAttribute("OrigJumpSizeYS", button.Size.Y.Scale)
		button:SetAttribute("OrigJumpSizeYO", button.Size.Y.Offset)
		button:SetAttribute("OrigJumpPosXS", button.Position.X.Scale)
		button:SetAttribute("OrigJumpPosXO", button.Position.X.Offset)
		button:SetAttribute("OrigJumpPosYS", button.Position.Y.Scale)
		button:SetAttribute("OrigJumpPosYO", button.Position.Y.Offset)
		button:SetAttribute("OrigJumpAnchorX", button.AnchorPoint.X)
		button:SetAttribute("OrigJumpAnchorY", button.AnchorPoint.Y)
	end

	local isUpdatingRealJump = false
	local function applyRealJumpState()
		if isUnloaded or isUpdatingRealJump then return end
		isUpdatingRealJump = true

		if isUsingNativeJump then
			restoreRealJumpToNative(button)
		else
			button.Active = false
			if button:IsA("ImageButton") or button:IsA("ImageLabel") then
				button.ImageTransparency = 1
			end
			button.BackgroundTransparency = 1
			button.Size = UDim2.new(0, 0, 0, 0)
			button.Position = UDim2.new(5, 0, 5, 0)
		end

		isUpdatingRealJump = false
	end

	realJumpRefreshers[button] = applyRealJumpState
	applyRealJumpState()

	stealthJumpConnections[button] = {
		button:GetPropertyChangedSignal("ImageTransparency"):Connect(applyRealJumpState),
		button:GetPropertyChangedSignal("Active"):Connect(applyRealJumpState),
		button:GetPropertyChangedSignal("Size"):Connect(applyRealJumpState),
		button:GetPropertyChangedSignal("Position"):Connect(applyRealJumpState),
		button.AncestryChanged:Connect(function(_, parent)
			if not parent and stealthJumpConnections[button] then
				for _, conn in ipairs(stealthJumpConnections[button]) do
					conn:Disconnect()
				end
				stealthJumpConnections[button] = nil
				realJumpRefreshers[button] = nil
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

-- Classic Move Button (ThumbstickFrame) Resizer (DynamicThumbstickFrame is left untouched)
local activeMoveConnections = {}
local moveLayoutRefreshers = {}
local isDraggingThumbstick = false
local thumbstickTouch = nil

refreshAllMoveLayouts = function()
	for _, refreshFn in pairs(moveLayoutRefreshers) do
		refreshFn()
	end
end

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

	-- Save original size & position so Default button & cleanup restore it cleanly
	if frame:GetAttribute("OrigMoveSizeX") == nil then
		frame:SetAttribute("OrigMoveSizeX", frame.Size.X.Offset)
		frame:SetAttribute("OrigMoveSizeY", frame.Size.Y.Offset)
		frame:SetAttribute("OrigMovePosXS", frame.Position.X.Scale)
		frame:SetAttribute("OrigMovePosXO", frame.Position.X.Offset)
		frame:SetAttribute("OrigMovePosYS", frame.Position.Y.Scale)
		frame:SetAttribute("OrigMovePosYO", frame.Position.Y.Offset)
	end

	local isUpdating = false
	local function forceMoveLayout()
		if isUnloaded or isUpdating then return end
		isUpdating = true

		local targetSize = currentMoveSize
		local halfSize = math.round(targetSize / 2)
		local quarterSize = math.round(targetSize / 4)

		local restingPos
		if isMoveAtNativeDefault then
			local origPXS = frame:GetAttribute("OrigMovePosXS") or 0
			local origPXO = frame:GetAttribute("OrigMovePosXO") or 30
			local origPYS = frame:GetAttribute("OrigMovePosYS") or 1
			local origPYO = frame:GetAttribute("OrigMovePosYO") or -100
			restingPos = UDim2.new(origPXS, origPXO, origPYS, origPYO)
		else
			restingPos = UDim2.new(0, MOVE_OFFSET_X, 1, -targetSize - MOVE_OFFSET_Y)
		end

		local restingStickPos = UDim2.new(0, quarterSize, 0, quarterSize)

		frame.AnchorPoint = Vector2.new(0, 0)
		frame.Size = UDim2.new(0, targetSize, 0, targetSize)

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

	moveLayoutRefreshers[frame] = forceMoveLayout

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
				moveLayoutRefreshers[frame] = nil
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
	unbindShiftLockStep()

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
	table.clear(realJumpRefreshers)

	for _, conns in pairs(activeMoveConnections) do
		for _, conn in pairs(conns) do
			pcall(function() conn:Disconnect() end)
		end
	end
	table.clear(activeMoveConnections)
	table.clear(moveLayoutRefreshers)

	-- Restore Roblox's real JumpButton
	for btn in pairs(trackedRealJumpButtons) do
		restoreRealJumpToNative(btn)
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
