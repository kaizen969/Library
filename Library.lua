--[[
  Speed_Library — shadcn/ui Skin
  Original logic preserved 100%. Only colors / sizes / fonts changed.
  Fixed: getGui() safe for all executors.
]]

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

-- ── Safe GUI parent (no chained `or` to avoid parse errors) ─────────────
local function _gui()
	if RunService:IsStudio() then return Player.PlayerGui end
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	if typeof(cloneref) == "function" then
		local ok, r = pcall(cloneref, game:GetService("CoreGui"))
		if ok and r then return r end
	end
	return game:GetService("CoreGui")
end

-- ── shadcn zinc dark palette ─────────────────────────────────────────────
local BG      = Color3.fromRGB(9,   9,   11)   -- zinc-950
local CARD    = Color3.fromRGB(24,  24,  27)   -- zinc-900
local ELEV    = Color3.fromRGB(32,  32,  36)   -- zinc-850
local BORDER  = Color3.fromRGB(39,  39,  42)   -- zinc-800
local BORDER2 = Color3.fromRGB(63,  63,  70)   -- zinc-700
local FG      = Color3.fromRGB(250, 250, 250)  -- zinc-50
local FG2     = Color3.fromRGB(161, 161, 170)  -- zinc-400
local MUTED   = Color3.fromRGB(113, 113, 122)  -- zinc-500
local ACCENT  = Color3.fromRGB(139, 92,  246)  -- violet-500
local SUCCESS = Color3.fromRGB(34,  197, 94)
local WARN    = Color3.fromRGB(234, 179, 8)
local ERR     = Color3.fromRGB(239, 68,  68)

local Custom = {}
Custom.ColorRGB = ACCENT  -- used by original code throughout

function Custom:Create(Name, Properties, Parent)
	local inst = Instance.new(Name)
	for k, v in pairs(Properties) do inst[k] = v end
	if Parent then inst.Parent = Parent end
	return inst
end

function Custom:EnabledAFK()
	Player.Idled:Connect(function()
		VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
		task.wait(1)
		VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
	end)
end

Custom:EnabledAFK()

-- ── Minimize pill (same logic, new look) ─────────────────────────────────
local function OpenClose()
	local ScreenGui = Custom:Create("ScreenGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn   = false,
	}, _gui())

	local Close_ImageButton = Custom:Create("ImageButton", {
		BackgroundColor3       = CARD,
		BorderColor3           = BORDER,
		BackgroundTransparency = 0,
		Position               = UDim2.new(0.05, 0, 0.06, 0),
		Size                   = UDim2.new(0, 48, 0, 48),
		Image                  = "rbxassetid://136890595976124",
		ImageColor3            = ACCENT,
		ImageTransparency      = 0,
		Visible                = false,
	}, ScreenGui)

	Custom:Create("UICorner", {
		CornerRadius = UDim.new(0, 9999),
	}, Close_ImageButton)

	Custom:Create("UIStroke", {
		Color     = BORDER2,
		Thickness = 1,
	}, Close_ImageButton)

	local dragging, dragStart, startPos = false, nil, nil

	local function UpdateDraggable(input)
		local delta = input.Position - dragStart
		Close_ImageButton.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end

	Close_ImageButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			dragStart = input.Position
			startPos  = Close_ImageButton.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	Close_ImageButton.InputChanged:Connect(function(input)
		if dragging and (
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		) then
			UpdateDraggable(input)
		end
	end)

	return Close_ImageButton
end

local Open_Close = OpenClose()

-- ── Drag utility (unchanged) ─────────────────────────────────────────────
local function MakeDraggable(topbarobject, object)
	local dragging, dragStart, startPos = false, nil, nil

	local function UpdatePos(input)
		local delta = input.Position - dragStart
		object.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end

	topbarobject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = input.Position
			startPos  = object.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	topbarobject.InputChanged:Connect(function(input)
		if dragging and (
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		) then
			UpdatePos(input)
		end
	end)
end

-- ── Ripple click (unchanged logic, updated color) ────────────────────────
function CircleClick(Button, X, Y)
	task.spawn(function()
		Button.ClipsDescendants = true
		local Circle = Instance.new("ImageLabel")
		Circle.Image              = "rbxassetid://106471194043211"
		Circle.ImageColor3        = Color3.fromRGB(255, 255, 255)
		Circle.ImageTransparency  = 0.85
		Circle.BackgroundColor3   = Color3.fromRGB(255, 255, 255)
		Circle.BackgroundTransparency = 1
		Circle.ZIndex             = 10
		Circle.Name               = "Circle"
		Circle.Parent             = Button

		local NewX = X - Button.AbsolutePosition.X
		local NewY = Y - Button.AbsolutePosition.Y
		Circle.Position = UDim2.new(0, NewX, 0, NewY)

		local Size    = math.max(Button.AbsoluteSize.X, Button.AbsoluteSize.Y) * 1.5
		local Time    = 0.45
		local tweenI  = TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local Tween = TweenService:Create(Circle, tweenI, {
			Size     = UDim2.new(0, Size, 0, Size),
			Position = UDim2.new(0.5, -Size/2, 0.5, -Size/2),
			ImageTransparency = 1,
		})
		Tween:Play()
		Tween.Completed:Connect(function() Circle:Destroy() end)
	end)
end

local Speed_Library, Notification = {}, {}
Speed_Library.Unloaded = false

-- ══════════════════════════════════════════════════════════════════════════
--  NOTIFICATION  (same logic, shadcn look)
-- ══════════════════════════════════════════════════════════════════════════
function Speed_Library:SetNotification(Config)
	local Title   = Config[1] or Config.Title       or ""
	local Description = Config[2] or Config.Description or ""
	local Content = Config[3] or Config.Content     or ""
	local Time    = Config[5] or Config.Time        or 0.3
	local Delay   = Config[6] or Config.Delay       or 5

	local NotificationGui = Custom:Create("ScreenGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn   = false,
	}, _gui())

	local NotificationLayout = Custom:Create("Frame", {
		AnchorPoint            = Vector2.new(1, 1),
		BackgroundColor3       = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 0.999,
		BorderColor3           = Color3.fromRGB(0,0,0),
		BorderSizePixel        = 0,
		Position               = UDim2.new(1, -16, 1, -16),
		Size                   = UDim2.new(0, 320, 1, 0),
		Name                   = "NotificationLayout",
	}, NotificationGui)

	local Count = 0

	NotificationLayout.ChildRemoved:Connect(function()
		Count = 0
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		for _, v in ipairs(NotificationLayout:GetChildren()) do
			local NewPOS = UDim2.new(0, 0, 1, -((v.Size.Y.Offset + 12) * Count))
			TweenService:Create(v, tweenInfo, {Position = NewPOS}):Play()
			Count = Count + 1
		end
	end)

	local _Count = 0
	for _, v in ipairs(NotificationLayout:GetChildren()) do
		_Count = -(v.Position.Y.Offset) + v.Size.Y.Offset + 12
	end

	local NotificationFrame = Custom:Create("Frame", {
		BackgroundColor3       = Color3.fromRGB(0,0,0),
		BorderColor3           = Color3.fromRGB(0,0,0),
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, 150),
		Name                   = "NotificationFrame",
		BackgroundTransparency = 1,
		AnchorPoint            = Vector2.new(0, 1),
		Position               = UDim2.new(0, 0, 1, -(_Count)),
	}, NotificationLayout)

	-- shadcn card
	local NotificationFrameReal = Custom:Create("Frame", {
		BackgroundColor3 = CARD,
		BorderColor3     = Color3.fromRGB(0,0,0),
		BorderSizePixel  = 0,
		Position         = UDim2.new(0, 400, 0, 0),
		Size             = UDim2.new(1, 0, 1, 0),
		Name             = "NotificationFrameReal",
	}, NotificationFrame)
	Custom:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, NotificationFrameReal)
	Custom:Create("UIStroke", { Color = BORDER, Thickness = 1 }, NotificationFrameReal)

	-- Accent left bar
	Custom:Create("Frame", {
		BackgroundColor3 = ACCENT,
		BorderSizePixel  = 0,
		Size             = UDim2.new(0, 3, 1, 0),
		Parent           = NotificationFrameReal,
	})

	-- Drop shadow (kept same structure)
	local DropShadowHolder = Custom:Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 1, 0),
		ZIndex                 = 0,
		Name                   = "DropShadowHolder",
		Parent                 = NotificationFrameReal,
	})
	Custom:Create("ImageLabel", {
		Image              = "rbxassetid://1316045217",
		ImageColor3        = Color3.fromRGB(0,0,0),
		ImageTransparency  = 0.6,
		ScaleType          = Enum.ScaleType.Slice,
		SliceCenter        = Rect.new(10, 10, 118, 118),
		AnchorPoint        = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel    = 0,
		Position           = UDim2.new(0.5, 0, 0.5, 0),
		Size               = UDim2.new(1, 47, 1, 47),
		ZIndex             = 0,
		Name               = "DropShadow",
		Parent             = DropShadowHolder,
	})

	local Top = Custom:Create("Frame", {
		BackgroundColor3       = BG,
		BackgroundTransparency = 0,
		BorderColor3           = Color3.fromRGB(0,0,0),
		BorderSizePixel        = 0,
		Size                   = UDim2.new(1, 0, 0, 36),
		Name                   = "Top",
		Parent                 = NotificationFrameReal,
	})

	local TextLabel = Custom:Create("TextLabel", {
		Font               = Enum.Font.GothamBold,
		Text               = Title,
		TextColor3         = FG,
		TextSize           = 13,
		TextXAlignment     = Enum.TextXAlignment.Left,
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Size               = UDim2.new(1, 0, 1, 0),
		Position           = UDim2.new(0, 14, 0, 0),
		Parent             = Top,
	})

	Custom:Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = Top })

	local TextLabel1 = Custom:Create("TextLabel", {
		Font               = Enum.Font.Gotham,
		Text               = Description,
		TextColor3         = ACCENT,
		TextSize           = 12,
		TextXAlignment     = Enum.TextXAlignment.Left,
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Size               = UDim2.new(1, 0, 1, 0),
		Position           = UDim2.new(0, TextLabel.TextBounds.X + 15, 0, 0),
		Parent             = Top,
	})
	Custom:Create("UIStroke", { Color = ACCENT, Thickness = 0.4, Parent = TextLabel1 })

	local Close = Custom:Create("TextButton", {
		Font               = Enum.Font.GothamBold,
		Text               = "×",
		TextColor3         = MUTED,
		TextSize           = 18,
		AnchorPoint        = Vector2.new(1, 0.5),
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Position           = UDim2.new(1, -5, 0.5, 0),
		Size               = UDim2.new(0, 25, 0, 25),
		Name               = "Close",
		Parent             = Top,
	})

	local TextLabel2 = Custom:Create("TextLabel", {
		Font               = Enum.Font.Gotham,
		TextColor3         = FG2,
		TextSize           = 12,
		Text               = Content,
		TextXAlignment     = Enum.TextXAlignment.Left,
		TextYAlignment     = Enum.TextYAlignment.Top,
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Position           = UDim2.new(0, 14, 0, 38),
		Size               = UDim2.new(1, -20, 0, 13),
		Parent             = NotificationFrameReal,
	})

	TextLabel2.Size = UDim2.new(1, -20, 0, 13 + (13 * (TextLabel2.TextBounds.X // TextLabel2.AbsoluteSize.X)))
	TextLabel2.TextWrapped = true

	if TextLabel2.AbsoluteSize.Y < 27 then
		NotificationFrame.Size = UDim2.new(1, 0, 0, 65)
	else
		NotificationFrame.Size = UDim2.new(1, 0, 0, TextLabel2.AbsoluteSize.Y + 40)
	end

	-- Progress bar
	local prog = Custom:Create("Frame", {
		BackgroundColor3 = ACCENT,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0, 1),
		Position         = UDim2.new(0, 0, 1, 0),
		Size             = UDim2.new(1, 0, 0, 2),
		Parent           = NotificationFrameReal,
	})

	local Waitted = false
	function Notification:Close()
		if Waitted then return false end
		Waitted = true
		TweenService:Create(NotificationFrameReal,
			TweenInfo.new(tonumber(Time), Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
			{Position = UDim2.new(0, 400, 0, 0)}
		):Play()
		task.wait(tonumber(Time) / 1.2)
		NotificationFrame:Destroy()
		Waitted = false
	end

	Close.Activated:Connect(function() Notification:Close() end)

	TweenService:Create(NotificationFrameReal,
		TweenInfo.new(tonumber(Time), Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
		{Position = UDim2.new(0, 0, 0, 0)}
	):Play()

	TweenService:Create(prog,
		TweenInfo.new(tonumber(Delay), Enum.EasingStyle.Linear),
		{Size = UDim2.new(0, 0, 0, 2)}
	):Play()

	task.wait(tonumber(Delay))
	Notification:Close()

	return Notification
end

-- ══════════════════════════════════════════════════════════════════════════
--  CREATE WINDOW
-- ══════════════════════════════════════════════════════════════════════════
function Speed_Library:CreateWindow(Config)
	local Title    = Config[1] or Config.Title       or ""
	local Description = Config[2] or Config.Description or ""
	local TabWidth = Config[3] or Config["Tab Width"] or 120
	local SizeUi   = Config[4] or Config.SizeUi      or UDim2.fromOffset(550, 315)

	local Funcs = {}

	local SpeedHubXGui = Custom:Create("ScreenGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn   = false,
	}, _gui())

	local DropShadowHolder = Custom:Create("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel        = 0,
		Size                   = SizeUi,
		ZIndex                 = 0,
		Name                   = "DropShadowHolder",
		Position               = UDim2.new(
			0, (SpeedHubXGui.AbsoluteSize.X // 2 - SizeUi.X.Offset // 2),
			0, (SpeedHubXGui.AbsoluteSize.Y // 2 - SizeUi.Y.Offset // 2)
		),
	}, SpeedHubXGui)

	Custom:Create("ImageLabel", {
		Image              = "rbxassetid://1316045217",
		ImageColor3        = Color3.fromRGB(0,0,0),
		ImageTransparency  = 0.55,
		ScaleType          = Enum.ScaleType.Slice,
		SliceCenter        = Rect.new(10, 10, 118, 118),
		AnchorPoint        = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel    = 0,
		Position           = UDim2.new(0.5, 0, 0.5, 0),
		Size               = UDim2.new(1, 24, 1, 24),
		ZIndex             = 0,
		Name               = "DropShadow",
		Parent             = DropShadowHolder,
	})

	-- Main card
	local Main = Custom:Create("Frame", {
		AnchorPoint        = Vector2.new(0.5, 0.5),
		BackgroundColor3   = CARD,
		BackgroundTransparency = 0,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Position           = UDim2.new(0.5, 0, 0.5, 0),
		Size               = SizeUi,
		Name               = "Main",
		ClipsDescendants   = true,
	}, DropShadowHolder)
	Custom:Create("UICorner", { CornerRadius = UDim.new(0, 10) }, Main)
	Custom:Create("UIStroke",  { Color = BORDER, Thickness = 1 }, Main)

	-- ── Header ───────────────────────────────────────────────────────────
	local Top = Custom:Create("Frame", {
		BackgroundColor3 = BG,
		BorderColor3     = Color3.fromRGB(0,0,0),
		BorderSizePixel  = 0,
		Size             = UDim2.new(1, 0, 0, 38),
		Name             = "Top",
	}, Main)
	Custom:Create("UICorner", { CornerRadius = UDim.new(0, 10) }, Top)
	-- Fill bottom corners
	Custom:Create("Frame", {
		BackgroundColor3 = BG,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0, 1),
		Position         = UDim2.new(0, 0, 1, 0),
		Size             = UDim2.new(1, 0, 0, 10),
		Parent           = Top,
	})
	-- Bottom divider
	Custom:Create("Frame", {
		BackgroundColor3 = BORDER,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(0, 1),
		Position         = UDim2.new(0, 0, 1, 0),
		Size             = UDim2.new(1, 0, 0, 1),
		Parent           = Top,
	})

	-- macOS traffic-light dots
	local dotCols = { ERR, WARN, SUCCESS }
	for i = 1, 3 do
		local d = Custom:Create("Frame", {
			BackgroundColor3 = dotCols[i],
			BorderSizePixel  = 0,
			AnchorPoint      = Vector2.new(0, 0.5),
			Position         = UDim2.new(0, 10 + (i-1)*16, 0.5, 0),
			Size             = UDim2.new(0, 10, 0, 10),
			Parent           = Top,
		})
		Custom:Create("UICorner", { CornerRadius = UDim.new(0, 9999) }, d)
	end

	local TextLabel = Custom:Create("TextLabel", {
		Font               = Enum.Font.GothamBold,
		Text               = Title,
		TextColor3         = FG,
		TextSize           = 13,
		TextXAlignment     = Enum.TextXAlignment.Left,
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Size               = UDim2.new(1, -100, 1, 0),
		Position           = UDim2.new(0, 62, 0, 0),
	}, Top)

	local TextLabel1 = Custom:Create("TextLabel", {
		Font               = Enum.Font.Gotham,
		Text               = Description,
		TextColor3         = FG2,
		TextSize           = 11,
		TextXAlignment     = Enum.TextXAlignment.Left,
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Size               = UDim2.new(1, -(TextLabel.TextBounds.X + 104), 1, 0),
		Position           = UDim2.new(0, TextLabel.TextBounds.X + 67, 0, 0),
	}, Top)

	local Close = Custom:Create("TextButton", {
		Font               = Enum.Font.GothamBold,
		Text               = "×",
		TextColor3         = MUTED,
		TextSize           = 18,
		AnchorPoint        = Vector2.new(1, 0.5),
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Position           = UDim2.new(1, -8, 0.5, 0),
		Size               = UDim2.new(0, 25, 0, 25),
		Name               = "Close",
	}, Top)

	local Min = Custom:Create("TextButton", {
		Font               = Enum.Font.GothamBold,
		Text               = "−",
		TextColor3         = MUTED,
		TextSize           = 18,
		AnchorPoint        = Vector2.new(1, 0.5),
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Position           = UDim2.new(1, -38, 0.5, 0),
		Size               = UDim2.new(0, 25, 0, 25),
		Name               = "Min",
	}, Top)

	-- Hover on header buttons
	for _, b in ipairs({Close, Min}) do
		b.MouseEnter:Connect(function() b.TextColor3 = FG end)
		b.MouseLeave:Connect(function() b.TextColor3 = MUTED end)
	end

	-- ── Tab sidebar ──────────────────────────────────────────────────────
	local LayersTab = Custom:Create("Frame", {
		BackgroundColor3       = BG,
		BackgroundTransparency = 0,
		BorderColor3           = Color3.fromRGB(0,0,0),
		BorderSizePixel        = 0,
		Position               = UDim2.new(0, 0, 0, 39),
		Size                   = UDim2.new(0, TabWidth, 1, -39),
		Name                   = "LayersTab",
	}, Main)

	-- Right border on sidebar
	Custom:Create("Frame", {
		BackgroundColor3 = BORDER,
		BorderSizePixel  = 0,
		AnchorPoint      = Vector2.new(1, 0),
		Position         = UDim2.new(1, 0, 0, 0),
		Size             = UDim2.new(0, 1, 1, 0),
		Parent           = LayersTab,
	})

	-- Divider below header (original DecideFrame)
	Custom:Create("Frame", {
		AnchorPoint      = Vector2.new(0.5, 0),
		BackgroundColor3 = BORDER,
		BackgroundTransparency = 0,
		BorderColor3     = Color3.fromRGB(0,0,0),
		BorderSizePixel  = 0,
		Position         = UDim2.new(0.5, 0, 0, 38),
		Size             = UDim2.new(1, 0, 0, 1),
		Name             = "DecideFrame",
	}, Main)

	-- ── Content area ─────────────────────────────────────────────────────
	local Layers = Custom:Create("Frame", {
		BackgroundColor3       = CARD,
		BackgroundTransparency = 0,
		BorderColor3           = Color3.fromRGB(0,0,0),
		BorderSizePixel        = 0,
		Position               = UDim2.new(0, TabWidth + 1, 0, 39),
		Size                   = UDim2.new(1, -(TabWidth + 1), 1, -39),
		Name                   = "Layers",
	}, Main)

	local NameTab = Custom:Create("TextLabel", {
		Font               = Enum.Font.GothamBold,
		Text               = "",
		TextColor3         = FG,
		TextSize           = 13,
		TextWrapped        = true,
		TextXAlignment     = Enum.TextXAlignment.Left,
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Size               = UDim2.new(1, 0, 0, 30),
		Position           = UDim2.new(0, 10, 0, 0),
		Name               = "NameTab",
	}, Layers)

	local LayersReal = Custom:Create("Frame", {
		AnchorPoint            = Vector2.new(0, 1),
		BackgroundColor3       = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3           = Color3.fromRGB(0,0,0),
		BorderSizePixel        = 0,
		ClipsDescendants       = true,
		Position               = UDim2.new(0, 0, 1, 0),
		Size                   = UDim2.new(1, 0, 1, -33),
		Name                   = "LayersReal",
	}, Layers)

	local LayersFolder = Custom:Create("Folder", { Name = "LayersFolder" }, LayersReal)
	local LayersPageLayout = Custom:Create("UIPageLayout", {
		SortOrder       = Enum.SortOrder.LayoutOrder,
		Name            = "LayersPageLayout",
		TweenTime       = 0.25,
		EasingDirection = Enum.EasingDirection.InOut,
		EasingStyle     = Enum.EasingStyle.Quart,
	}, LayersFolder)

	local ScrollTab = Custom:Create("ScrollingFrame", {
		CanvasSize           = UDim2.new(0, 0, 2.1, 0),
		ScrollBarImageColor3 = BORDER2,
		ScrollBarThickness   = 0,
		Active               = true,
		BackgroundColor3     = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 1,
		BorderColor3         = Color3.fromRGB(0,0,0),
		BorderSizePixel      = 0,
		Size                 = UDim2.new(1, 0, 1, -10),
		Name                 = "ScrollTab",
	}, LayersTab)

	Custom:Create("UIListLayout", {
		Padding   = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, ScrollTab)

	Custom:Create("UIPadding", {
		PaddingLeft  = UDim.new(0, 5),
		PaddingRight = UDim.new(0, 5),
		PaddingTop   = UDim.new(0, 6),
	}, ScrollTab)

	-- UpdateSize (same logic)
	local function UpdateSize()
		local _Total = 0
		for _, v in pairs(ScrollTab:GetChildren()) do
			if v.Name ~= "UIListLayout" and v.Name ~= "UIPadding" then
				_Total = _Total + 3 + v.Size.Y.Offset
			end
		end
		ScrollTab.CanvasSize = UDim2.new(0, 0, 0, _Total)
	end
	ScrollTab.ChildAdded:Connect(UpdateSize)
	ScrollTab.ChildRemoved:Connect(UpdateSize)

	-- ── Dropdown overlay (same structure, restyled) ───────────────────────
	local MoreBlur = Custom:Create("Frame", {
		AnchorPoint            = Vector2.new(1, 1),
		BackgroundColor3       = BG,
		BackgroundTransparency = 1,
		BorderColor3           = Color3.fromRGB(0,0,0),
		BorderSizePixel        = 0,
		ClipsDescendants       = true,
		Position               = UDim2.new(1, 8, 1, 8),
		Size                   = UDim2.new(1, 154, 1, 54),
		Visible                = false,
		Name                   = "MoreBlur",
	}, Layers)
	Custom:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, MoreBlur)

	local ConnectButton = Custom:Create("TextButton", {
		Font               = Enum.Font.SourceSans,
		Text               = "",
		TextColor3         = Color3.fromRGB(0,0,0),
		TextSize           = 14,
		BackgroundColor3   = Color3.fromRGB(255,255,255),
		BackgroundTransparency = 0.999,
		BorderColor3       = Color3.fromRGB(0,0,0),
		BorderSizePixel    = 0,
		Size               = UDim2.new(1, 0, 1, 0),
		Name               = "ConnectButton",
	}, MoreBlur)

	local DropdownSelect = Custom:Create("Frame", {
		AnchorPoint      = Vector2.new(1, 0.5),
		BackgroundColor3 = ELEV,
		BorderColor3     = Color3.fromRGB(0,0,0),
		BorderSizePixel  = 0,
		LayoutOrder      = 1,
		Position         = UDim2.new(1, 172, 0.5, 0),
		Size             = UDim2.new(0, 160, 1, -16),
		ClipsDescendants = true,
		Name             = "DropdownSelect",
	}, MoreBlur)
	Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = DropdownSelect })
	Custom:Create("UIStroke",  { Color = BORDER2, Thickness = 1, Transparency = 0.3, Parent = DropdownSelect })

	ConnectButton.Activated:Connect(function()
		if MoreBlur.Visible then
			local tweenInfo = TweenInfo.new(0.18)
			TweenService:Create(MoreBlur,       tweenInfo, {BackgroundTransparency = 1}):Play()
			TweenService:Create(DropdownSelect, tweenInfo, {Position = UDim2.new(1, 172, 0.5, 0)}):Play()
			task.wait(0.2)
			MoreBlur.Visible = false
		end
	end)

	local DropdownSelectReal = Custom:Create("Frame", {
		AnchorPoint            = Vector2.new(0.5, 0.5),
		BackgroundColor3       = Color3.fromRGB(0,0,0),
		BackgroundTransparency = 1,
		BorderColor3           = Color3.fromRGB(0,0,0),
		BorderSizePixel        = 0,
		Position               = UDim2.new(0.5, 0, 0.5, 0),
		Size                   = UDim2.new(1, -8, 1, -8),
		Name                   = "DropdownSelectReal",
		Parent                 = DropdownSelect,
	})
	local DropdownFolder = Custom:Create("Folder", { Name = "DropdownFolder", Parent = DropdownSelectReal })
	local DropPageLayout = Custom:Create("UIPageLayout", {
		EasingDirection = Enum.EasingDirection.InOut,
		EasingStyle     = Enum.EasingStyle.Quart,
		TweenTime       = 0.01,
		SortOrder       = Enum.SortOrder.LayoutOrder,
		Archivable      = false,
		Name            = "DropPageLayout",
		Parent          = DropdownFolder,
	})

	-- Min / Close / Restore (same logic as original)
	Min.Activated:Connect(function()
		CircleClick(Min, Player:GetMouse().X, Player:GetMouse().Y)
		DropShadowHolder.Visible = false
		if not Open_Close.Visible then Open_Close.Visible = true end
	end)
	Open_Close.Activated:Connect(function()
		DropShadowHolder.Visible = true
		if Open_Close.Visible then Open_Close.Visible = false end
	end)
	Close.Activated:Connect(function()
		CircleClick(Close, Player:GetMouse().X, Player:GetMouse().Y)
		if SpeedHubXGui then SpeedHubXGui:Destroy() end
		if not Speed_Library.Unloaded then Speed_Library.Unloaded = true end
	end)

	DropShadowHolder.Size = UDim2.new(0, 115 + TextLabel.TextBounds.X + 1 + TextLabel1.TextBounds.X, 0, SizeUi.Y.Offset)
	MakeDraggable(Top, DropShadowHolder)

	-- ══════════════════════════════════════════════════════════════════════
	--  TABS
	-- ══════════════════════════════════════════════════════════════════════
	local Tabs = {}
	local CountTab = 0
	local CountDropdown = 0

	function Tabs:CreateTab(Config)
		local _Name = Config[1] or Config.Name or ""
		local Icon  = Config[2] or Config.Icon or ""

		local ScrolLayers = Custom:Create("ScrollingFrame", {
			ScrollBarImageColor3   = BORDER2,
			ScrollBarThickness     = 3,
			Active                 = true,
			LayoutOrder            = CountTab,
			BackgroundColor3       = Color3.fromRGB(255,255,255),
			BackgroundTransparency = 1,
			BorderColor3           = Color3.fromRGB(0,0,0),
			BorderSizePixel        = 0,
			Size                   = UDim2.new(1, 0, 1, 0),
			Name                   = "ScrolLayers",
			Parent                 = LayersFolder,
		})
		Custom:Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ScrolLayers })
		Custom:Create("UIPadding",    { PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8), PaddingTop = UDim.new(0,6), Parent = ScrolLayers })

		-- Tab button in sidebar
		local Tab = Custom:Create("Frame", {
			BackgroundColor3       = CountTab == 0 and ELEV or BG,
			BackgroundTransparency = 0,
			BorderColor3           = Color3.fromRGB(0,0,0),
			BorderSizePixel        = 0,
			LayoutOrder            = CountTab,
			Size                   = UDim2.new(1, 0, 0, 30),
			Name                   = "Tab",
			Parent                 = ScrollTab,
		})
		Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = Tab })

		local TabButton = Custom:Create("TextButton", {
			Font               = Enum.Font.GothamBold,
			Text               = "",
			TextColor3         = FG,
			TextSize           = 13,
			TextXAlignment     = Enum.TextXAlignment.Left,
			BackgroundColor3   = Color3.fromRGB(255,255,255),
			BackgroundTransparency = 1,
			BorderColor3       = Color3.fromRGB(0,0,0),
			BorderSizePixel    = 0,
			Size               = UDim2.new(1, 0, 1, 0),
			Name               = "TabButton",
		}, Tab)

		Custom:Create("TextLabel", {
			Font               = Enum.Font.GothamBold,
			Text               = _Name,
			TextColor3         = CountTab == 0 and FG or FG2,
			TextSize           = 12,
			TextXAlignment     = Enum.TextXAlignment.Left,
			BackgroundColor3   = Color3.fromRGB(255,255,255),
			BackgroundTransparency = 1,
			BorderColor3       = Color3.fromRGB(0,0,0),
			BorderSizePixel    = 0,
			Size               = UDim2.new(1, 0, 1, 0),
			Position           = UDim2.new(0, Icon ~= "" and 28 or 10, 0, 0),
			Name               = "TabName",
		}, Tab)

		Custom:Create("ImageLabel", {
			Image              = Icon,
			ImageColor3        = FG2,
			BackgroundColor3   = Color3.fromRGB(255,255,255),
			BackgroundTransparency = 1,
			BorderColor3       = Color3.fromRGB(0,0,0),
			BorderSizePixel    = 0,
			Position           = UDim2.new(0, 7, 0, 7),
			Size               = UDim2.new(0, 14, 0, 14),
			Name               = "FeatureImg",
		}, Tab)

		if CountTab == 0 then
			LayersPageLayout:JumpToIndex(0)
			NameTab.Text = _Name

			local ChooseFrame = Custom:Create("Frame", {
				BackgroundColor3 = ACCENT,
				BorderColor3     = Color3.fromRGB(0,0,0),
				BorderSizePixel  = 0,
				Position         = UDim2.new(0, 0, 0, 8),
				Size             = UDim2.new(0, 2, 0, 14),
				Name             = "ChooseFrame",
			}, Tab)
			Custom:Create("UIStroke",  { Color = ACCENT, Thickness = 1 }, ChooseFrame)
			Custom:Create("UICorner",  { CornerRadius = UDim.new(0, 9999) }, ChooseFrame)
		end

		-- Tab hover
		TabButton.MouseEnter:Connect(function()
			if Tab.BackgroundColor3 ~= ELEV then
				TweenService:Create(Tab, TweenInfo.new(0.1), { BackgroundColor3 = BORDER }):Play()
			end
		end)
		TabButton.MouseLeave:Connect(function()
			if Tab.BackgroundColor3 ~= ELEV then
				TweenService:Create(Tab, TweenInfo.new(0.1), { BackgroundColor3 = BG }):Play()
			end
		end)

		-- Tab click (same logic as original)
		TabButton.Activated:Connect(function()
			CircleClick(TabButton, Player:GetMouse().X, Player:GetMouse().Y)
			local FrameChoose = nil
			for _, s in pairs(ScrollTab:GetChildren()) do
				for _, v in pairs(s:GetChildren()) do
					if v.Name == "ChooseFrame" then FrameChoose = v; break end
				end
				if FrameChoose then break end
			end

			if FrameChoose and Tab.LayoutOrder ~= LayersPageLayout.CurrentPage.LayoutOrder then
				for _, TabFrame in pairs(ScrollTab:GetChildren()) do
					if TabFrame.Name == "Tab" then
						TweenService:Create(TabFrame, TweenInfo.new(0.15), { BackgroundColor3 = BG }):Play()
						local lbl = TabFrame:FindFirstChild("TabName")
						if lbl then TweenService:Create(lbl, TweenInfo.new(0.15), { TextColor3 = FG2 }):Play() end
					end
				end

				TweenService:Create(Tab, TweenInfo.new(0.2, Enum.EasingStyle.Quart), { BackgroundColor3 = ELEV }):Play()
				local myLbl = Tab:FindFirstChild("TabName")
				if myLbl then TweenService:Create(myLbl, TweenInfo.new(0.15), { TextColor3 = FG }):Play() end

				TweenService:Create(FrameChoose,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ Position = UDim2.new(0, 0, 0, 8 + (32 * Tab.LayoutOrder)) }
				):Play()

				LayersPageLayout:JumpToIndex(Tab.LayoutOrder)
				task.wait(0.05)
				NameTab.Text = _Name

				TweenService:Create(FrameChoose, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Size = UDim2.new(0, 2, 0, 20) }):Play()
				task.wait(0.2)
				TweenService:Create(FrameChoose, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Size = UDim2.new(0, 2, 0, 14) }):Play()
			end
		end)

		-- ── SECTIONS ─────────────────────────────────────────────────────
		local Sections, CountSection = {}, 0

		function Sections:AddSection(Title, OpenSection)
			Title       = Title or ""
			OpenSection = OpenSection or false

			local Section = Custom:Create("Frame", {
				BackgroundColor3       = Color3.fromRGB(255,255,255),
				BackgroundTransparency = 1,
				BorderColor3           = Color3.fromRGB(0,0,0),
				BorderSizePixel        = 0,
				ClipsDescendants       = true,
				LayoutOrder            = CountSection,
				Size                   = UDim2.new(1, 0, 0, 30),
				Name                   = "Section",
			}, ScrolLayers)

			local SectionReal = Custom:Create("Frame", {
				AnchorPoint      = Vector2.new(0.5, 0),
				BackgroundColor3 = BG,
				BackgroundTransparency = 0,
				BorderColor3     = Color3.fromRGB(0,0,0),
				BorderSizePixel  = 0,
				LayoutOrder      = 1,
				Position         = UDim2.new(0.5, 0, 0, 0),
				Size             = UDim2.new(1, 0, 0, 30),
				Name             = "SectionReal",
			}, Section)
			Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, SectionReal)
			Custom:Create("UIStroke",  { Color = BORDER, Thickness = 1 }, SectionReal)

			local SectionButton = Custom:Create("TextButton", {
				Font               = Enum.Font.SourceSans,
				Text               = "",
				TextColor3         = Color3.fromRGB(0,0,0),
				TextSize           = 14,
				BackgroundColor3   = Color3.fromRGB(255,255,255),
				BackgroundTransparency = 1,
				BorderColor3       = Color3.fromRGB(0,0,0),
				BorderSizePixel    = 0,
				Size               = UDim2.new(1, 0, 1, 0),
				Name               = "SectionButton",
			}, SectionReal)

			local FeatureFrame = Custom:Create("Frame", {
				AnchorPoint        = Vector2.new(1, 0.5),
				BackgroundColor3   = Color3.fromRGB(0,0,0),
				BackgroundTransparency = 1,
				BorderColor3       = Color3.fromRGB(0,0,0),
				BorderSizePixel    = 0,
				Position           = UDim2.new(1, -5, 0.5, 0),
				Size               = UDim2.new(0, 20, 0, 20),
				Name               = "FeatureFrame",
			}, SectionReal)
			local FeatureImg = Custom:Create("ImageLabel", {
				Image              = "rbxassetid://125609963478878",
				ImageColor3        = MUTED,
				AnchorPoint        = Vector2.new(0.5, 0.5),
				BackgroundColor3   = Color3.fromRGB(255,255,255),
				BackgroundTransparency = 1,
				BorderColor3       = Color3.fromRGB(0,0,0),
				BorderSizePixel    = 0,
				Position           = UDim2.new(0.5, 0, 0.5, 0),
				Rotation           = -90,
				Size               = UDim2.new(1, 4, 1, 4),
				Name               = "FeatureImg",
			}, FeatureFrame)

			Custom:Create("TextLabel", {
				Font               = Enum.Font.GothamBold,
				Text               = Title,
				TextColor3         = FG2,
				TextSize           = 11,
				TextXAlignment     = Enum.TextXAlignment.Left,
				TextYAlignment     = Enum.TextYAlignment.Top,
				AnchorPoint        = Vector2.new(0, 0.5),
				BackgroundColor3   = Color3.fromRGB(255,255,255),
				BackgroundTransparency = 1,
				BorderColor3       = Color3.fromRGB(0,0,0),
				BorderSizePixel    = 0,
				Position           = UDim2.new(0, 10, 0.5, 0),
				Size               = UDim2.new(1, -50, 0, 13),
				Name               = "SectionTitle",
			}, SectionReal)

			local SectionDecideFrame = Custom:Create("Frame", {
				BackgroundColor3 = ACCENT,
				BorderColor3     = Color3.fromRGB(0,0,0),
				BorderSizePixel  = 0,
				AnchorPoint      = Vector2.new(0.5, 0),
				Position         = UDim2.new(0.5, 0, 0, 33),
				Size             = UDim2.new(0, 0, 0, 1),
				Name             = "SectionDecideFrame",
			}, Section)
			Custom:Create("UICorner", {}, SectionDecideFrame)

			local SectionAdd = Custom:Create("Frame", {
				AnchorPoint            = Vector2.new(0.5, 0),
				BackgroundColor3       = Color3.fromRGB(255,255,255),
				BackgroundTransparency = 1,
				BorderColor3           = Color3.fromRGB(0,0,0),
				BorderSizePixel        = 0,
				ClipsDescendants       = true,
				LayoutOrder            = 1,
				Position               = UDim2.new(0.5, 0, 0, 38),
				Size                   = UDim2.new(1, 0, 0, 100),
				Name                   = "SectionAdd",
			}, Section)
			Custom:Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, SectionAdd)

			local function UpdateSizeScroll()
				local OffsetY = 0
				for _, child in pairs(ScrolLayers:GetChildren()) do
					if child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
						OffsetY = OffsetY + 4 + child.Size.Y.Offset
					end
				end
				ScrolLayers.CanvasSize = UDim2.new(0, 0, 0, OffsetY)
			end

			local function UpdateSizeSection()
				if OpenSection then
					local h = 38
					for _, v in pairs(SectionAdd:GetChildren()) do
						if v.Name ~= "UIListLayout" and v.Name ~= "UICorner" then
							h = h + v.Size.Y.Offset + 4
						end
					end
					TweenService:Create(FeatureFrame,         TweenInfo.new(0.1), {Rotation = 90}):Play()
					TweenService:Create(Section,              TweenInfo.new(0.1), {Size = UDim2.new(1, 0, 0, h)}):Play()
					TweenService:Create(SectionAdd,           TweenInfo.new(0.1), {Size = UDim2.new(1, 0, 0, h-38)}):Play()
					TweenService:Create(SectionDecideFrame,   TweenInfo.new(0.1), {Size = UDim2.new(1, 0, 0, 1)}):Play()
					task.wait(0.5)
					UpdateSizeScroll()
				end
			end

			local function ToggleSection()
				CircleClick(SectionButton, Player:GetMouse().X, Player:GetMouse().Y)
				if OpenSection then
					TweenService:Create(FeatureFrame,       TweenInfo.new(0.1), {Rotation = 0}):Play()
					TweenService:Create(Section,            TweenInfo.new(0.1), {Size = UDim2.new(1, 0, 0, 30)}):Play()
					TweenService:Create(SectionDecideFrame, TweenInfo.new(0.1), {Size = UDim2.new(0, 0, 0, 1)}):Play()
					OpenSection = false
					task.wait(0.1)
					UpdateSizeScroll()
				else
					OpenSection = true
					UpdateSizeSection()
				end
			end

			SectionButton.Activated:Connect(ToggleSection)
			SectionAdd.ChildAdded:Connect(UpdateSizeSection)
			SectionAdd.ChildRemoved:Connect(UpdateSizeSection)
			UpdateSizeScroll()

			-- ── ITEMS ──────────────────────────────────────────────────────
			local Item, ItemCount = {}, 0

			-- Shared helpers
			local function makeRow(layoutOrder, height)
				local row = Custom:Create("Frame", {
					BackgroundColor3 = ELEV,
					BackgroundTransparency = 0,
					BorderSizePixel  = 0,
					LayoutOrder      = layoutOrder,
					Size             = UDim2.new(1, 0, 0, height),
				}, SectionAdd)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
				Custom:Create("UIStroke",  { Color = BORDER, Thickness = 1 }, row)
				return row
			end

			-- AddParagraph
			function Item:AddParagraph(Config)
				local _T = Config[1] or Config.Title   or ""
				local _C = Config[2] or Config.Content or ""
				local SettingFuncs = {}

				local Paragraph = makeRow(ItemCount, 35)
				Paragraph.Name = "Paragraph"

				local ParagraphTitle = Custom:Create("TextLabel", {
					Font               = Enum.Font.GothamBold,
					Text               = _T,
					TextColor3         = FG,
					TextSize           = 12,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Top,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 8),
					Size               = UDim2.new(1, -16, 0, 13),
					Name               = "ParagraphTitle",
				}, Paragraph)

				local ParagraphContent = Custom:Create("TextLabel", {
					Font               = Enum.Font.Gotham,
					Text               = _C,
					TextColor3         = FG2,
					TextSize           = 11,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Bottom,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 22),
					Name               = "ParagraphContent",
				}, Paragraph)

				local function UpdateParagraphSize()
					ParagraphContent.TextWrapped = false
					local lineCount = math.ceil(ParagraphContent.TextBounds.X / math.max(1, ParagraphContent.AbsoluteSize.X))
					ParagraphContent.Size = UDim2.new(1, -16, 0, 12 + (12 * lineCount))
					Paragraph.Size = UDim2.new(1, 0, 0, ParagraphContent.AbsoluteSize.Y + 30)
					ParagraphContent.TextWrapped = true
					UpdateSizeSection()
				end
				UpdateParagraphSize()
				ParagraphContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateParagraphSize)

				function SettingFuncs:Set(C)
					ParagraphTitle.Text   = C[1] or C.Title   or ""
					ParagraphContent.Text = C[2] or C.Content or ""
					UpdateParagraphSize()
				end

				ItemCount += 1
				return SettingFuncs
			end

			-- AddSeperator
			function Item:AddSeperator(Config)
				local _T = Config[1] or Config.Title or ""
				local Sep_Funcs = {}

				local Seperator = Custom:Create("Frame", {
					BackgroundColor3 = BORDER,
					BorderSizePixel  = 0,
					LayoutOrder      = ItemCount,
					Size             = UDim2.new(1, 0, 0, 28),
					Name             = "Seperator",
				}, SectionAdd)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, Seperator)

				local SeperatorTitle = Custom:Create("TextLabel", {
					Font               = Enum.Font.GothamBold,
					Text               = _T,
					TextColor3         = FG2,
					TextSize           = 11,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Center,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 12, 0, 0),
					Size               = UDim2.new(1, -16, 1, 0),
					Name               = "SeperatorTitle",
				}, Seperator)

				function Sep_Funcs:Set(C)
					SeperatorTitle.Text = C[1] or C.Title or ""
				end

				ItemCount += 1
				return Sep_Funcs
			end

			-- AddLine
			function Item:AddLine()
				Custom:Create("Frame", {
					BackgroundColor3 = BORDER,
					BackgroundTransparency = 0,
					BorderSizePixel  = 0,
					LayoutOrder      = ItemCount,
					Size             = UDim2.new(1, 0, 0, 1),
					Name             = "Line",
				}, SectionAdd)
				ItemCount += 1
				return {}
			end

			-- AddButton
			function Item:AddButton(Config)
				local _T  = Config[1] or Config.Title    or ""
				local _C  = Config[2] or Config.Content  or ""
				local _I  = Config[3] or Config.Icon     or "rbxassetid://7734010488"
				local _CB = Config[4] or Config.Callback or function() end
				local Funcs_Button = {}

				local Button = makeRow(ItemCount, 35)
				Button.Name = "Button"

				Custom:Create("TextLabel", {
					Name               = "ButtonTitle",
					Font               = Enum.Font.GothamBold,
					Text               = _T,
					TextColor3         = FG,
					TextSize           = 12,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Top,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 8),
					Size               = UDim2.new(1, -100, 0, 13),
				}, Button)

				local ButtonContent = Custom:Create("TextLabel", {
					Name               = "ButtonContent",
					Font               = Enum.Font.Gotham,
					Text               = _C,
					TextColor3         = FG2,
					TextSize           = 11,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Bottom,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 22),
					Size               = UDim2.new(1, -100, 0, 12),
				}, Button)

				local function UpdateButtonSize()
					local _Height = 12 + (12 * (ButtonContent.TextBounds.X // math.max(1, ButtonContent.AbsoluteSize.X)))
					ButtonContent.Size = UDim2.new(1, -100, 0, _Height)
					Button.Size = UDim2.new(1, 0, 0, ButtonContent.AbsoluteSize.Y + 30)
				end
				ButtonContent.TextWrapped = true
				UpdateButtonSize()
				ButtonContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					ButtonContent.TextWrapped = false
					UpdateButtonSize()
					ButtonContent.TextWrapped = true
					UpdateSizeSection()
				end)

				local ButtonButton = Custom:Create("TextButton", {
					Name               = "ButtonButton",
					Font               = Enum.Font.SourceSans,
					Text               = "",
					TextColor3         = Color3.fromRGB(0,0,0),
					TextSize           = 14,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Size               = UDim2.new(1, 0, 1, 0),
				}, Button)

				Custom:Create("ImageLabel", {
					Name               = "FeatureImg",
					Image              = _I,
					ImageColor3        = FG2,
					AnchorPoint        = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(1, -10, 0.5, 0),
					Size               = UDim2.new(0, 16, 0, 16),
				}, Button)

				ButtonButton.MouseEnter:Connect(function()
					TweenService:Create(Button, TweenInfo.new(0.1), { BackgroundColor3 = BORDER }):Play()
				end)
				ButtonButton.MouseLeave:Connect(function()
					TweenService:Create(Button, TweenInfo.new(0.1), { BackgroundColor3 = ELEV }):Play()
				end)
				ButtonButton.Activated:Connect(function()
					CircleClick(ButtonButton, Player:GetMouse().X, Player:GetMouse().Y)
					_CB()
				end)

				ItemCount += 1
				return Funcs_Button
			end

			-- AddToggle
			function Item:AddToggle(Config)
				local _T  = Config[1] or Config.Title    or ""
				local _C  = Config[2] or Config.Content  or ""
				local _D  = Config[3] or Config.Default  or false
				local _CB = Config[4] or Config.Callback or function() end
				local Funcs_Toggle = {Value = _D}

				local Toggle = makeRow(ItemCount, 35)
				Toggle.Name = "Toggle"

				local ToggleTitle = Custom:Create("TextLabel", {
					Name               = "ToggleTitle",
					Font               = Enum.Font.GothamBold,
					Text               = _T,
					TextSize           = 12,
					TextColor3         = FG,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Top,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 8),
					Size               = UDim2.new(1, -100, 0, 13),
				}, Toggle)

				local ToggleContent = Custom:Create("TextLabel", {
					Name               = "ToggleContent",
					Font               = Enum.Font.Gotham,
					Text               = _C,
					TextSize           = 11,
					TextColor3         = FG2,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Bottom,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 22),
					Size               = UDim2.new(1, -100, 0, 12),
				}, Toggle)

				local function UpdateToggleSize()
					ToggleContent.TextWrapped = false
					local Ratio = ToggleContent.TextBounds.X / math.max(1, ToggleContent.AbsoluteSize.X)
					ToggleContent.Size = UDim2.new(1, -100, 0, 12 + (12 * math.ceil(Ratio)))
					Toggle.Size = UDim2.new(1, 0, 0, ToggleContent.AbsoluteSize.Y + 30)
					ToggleContent.TextWrapped = true
				end
				UpdateToggleSize()
				ToggleContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					UpdateToggleSize()
					UpdateSizeSection()
				end)

				local ToggleButton = Custom:Create("TextButton", {
					Name               = "ToggleButton",
					Font               = Enum.Font.SourceSans,
					Text               = "",
					TextColor3         = Color3.fromRGB(0,0,0),
					TextSize           = 14,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Size               = UDim2.new(1, 0, 1, 0),
				}, Toggle)

				-- shadcn switch
				local track = Custom:Create("Frame", {
					AnchorPoint      = Vector2.new(1, 0.5),
					BackgroundColor3 = _D and ACCENT or BORDER2,
					BorderSizePixel  = 0,
					Position         = UDim2.new(1, -10, 0.5, 0),
					Size             = UDim2.new(0, 40, 0, 22),
					Name             = "FeatureFrame2",
				}, Toggle)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 9999) }, track)

				local thumb = Custom:Create("Frame", {
					AnchorPoint      = Vector2.new(0, 0.5),
					BackgroundColor3 = Color3.fromRGB(255,255,255),
					BorderSizePixel  = 0,
					Position         = _D and UDim2.new(0, 20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
					Size             = UDim2.new(0, 16, 0, 16),
					Name             = "ToggleCircle",
				}, track)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 9999) }, thumb)

				local function ToggleAnimation(isOn)
					local tw = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
					TweenService:Create(track, tw, { BackgroundColor3 = isOn and ACCENT or BORDER2 }):Play()
					TweenService:Create(thumb, tw, { Position = isOn and UDim2.new(0, 20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }):Play()
					TweenService:Create(ToggleTitle, tw, { TextColor3 = isOn and ACCENT or FG }):Play()
				end

				ToggleButton.Activated:Connect(function()
					CircleClick(ToggleButton, Player:GetMouse().X, Player:GetMouse().Y)
					Funcs_Toggle.Value = not Funcs_Toggle.Value
					Funcs_Toggle:Set(Funcs_Toggle.Value)
				end)

				function Funcs_Toggle:Set(Value)
					_CB(Value)
					ToggleAnimation(Value)
				end
				Funcs_Toggle:Set(Funcs_Toggle.Value)

				ItemCount += 1
				return Funcs_Toggle
			end

			-- AddSlider
			function Item:AddSlider(Config)
				local _T   = Config[1] or Config.Title     or ""
				local _C   = Config[2] or Config.Content   or ""
				local _Inc = Config[3] or Config.Increment or 1
				local _Min = Config[4] or Config.Min       or 0
				local _Max = Config[5] or Config.Max       or 100
				local _D   = Config[6] or Config.Default   or 50
				local _CB  = Config[7] or Config.Callback  or function() end
				local Funcs_Slider = {Value = _D}

				local Slider = makeRow(ItemCount, 50)
				Slider.Name = "Slider"

				Custom:Create("TextLabel", {
					Font               = Enum.Font.GothamBold,
					Text               = _T,
					TextColor3         = FG,
					TextSize           = 12,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Top,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 7),
					Size               = UDim2.new(1, -90, 0, 13),
					Name               = "SliderTitle",
				}, Slider)

				local SliderContent = Custom:Create("TextLabel", {
					Font               = Enum.Font.Gotham,
					Text               = _C,
					TextColor3         = FG2,
					TextSize           = 11,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Bottom,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 21),
					Size               = UDim2.new(1, -90, 0, 12),
					Name               = "SliderContent",
				}, Slider)

				local function UpdateSliderSize()
					SliderContent.TextWrapped = false
					SliderContent.Size = UDim2.new(1, -90, 0, 12 + (12 * math.floor(SliderContent.TextBounds.X / math.max(1, SliderContent.AbsoluteSize.X))))
					Slider.Size = UDim2.new(1, 0, 0, SliderContent.AbsoluteSize.Y + 30)
					SliderContent.TextWrapped = true
				end
				SliderContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					UpdateSliderSize()
					UpdateSizeSection()
				end)
				UpdateSliderSize()

				-- Value badge
				local valBadge = Custom:Create("Frame", {
					AnchorPoint      = Vector2.new(1, 0),
					BackgroundColor3 = BORDER,
					BorderSizePixel  = 0,
					Position         = UDim2.new(1, -8, 0, 6),
					Size             = UDim2.new(0, 44, 0, 20),
					Name             = "SliderInput",
				}, Slider)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, valBadge)

				local TextBox = Custom:Create("TextBox", {
					Font               = Enum.Font.GothamBold,
					Text               = tostring(_D),
					TextColor3         = FG,
					TextSize           = 11,
					TextXAlignment     = Enum.TextXAlignment.Center,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Size               = UDim2.new(1, 0, 1, 0),
				}, valBadge)

				-- Track
				local SliderFrame = Custom:Create("Frame", {
					AnchorPoint      = Vector2.new(0, 1),
					BackgroundColor3 = BORDER2,
					BorderSizePixel  = 0,
					Position         = UDim2.new(0, 10, 1, -8),
					Size             = UDim2.new(1, -20, 0, 3),
					Name             = "SliderFrame",
				}, Slider)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 9999) }, SliderFrame)

				local SliderDraggable = Custom:Create("Frame", {
					AnchorPoint      = Vector2.new(0, 0.5),
					BackgroundColor3 = ACCENT,
					BorderSizePixel  = 0,
					Position         = UDim2.new(0, 0, 0.5, 0),
					Size             = UDim2.new(0, 0, 1, 0),
					Name             = "SliderDraggable",
				}, SliderFrame)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 9999) }, SliderDraggable)

				local SliderCircle = Custom:Create("Frame", {
					AnchorPoint      = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(255,255,255),
					BorderSizePixel  = 0,
					Position         = UDim2.new(1, 0, 0.5, 0),
					Size             = UDim2.new(0, 10, 0, 10),
					Name             = "SliderCircle",
				}, SliderDraggable)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 9999) }, SliderCircle)
				Custom:Create("UIStroke",  { Color = ACCENT, Thickness = 1.5 }, SliderCircle)

				local Dragging = false

				local function Round(Number, Factor)
					local Result = math.floor(Number / Factor + (math.sign(Number) * 0.5)) * Factor
					if Result < 0 then Result = Result + Factor end
					return Result
				end

				function Funcs_Slider:Set(Value)
					Value = math.clamp(Round(Value, _Inc), _Min, _Max)
					Funcs_Slider.Value = Value
					TextBox.Text = tostring(Value)
					TweenService:Create(SliderDraggable, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Size = UDim2.fromScale((_Max == _Min) and 0 or (Value-_Min)/(_Max-_Min), 1) }
					):Play()
				end

				SliderFrame.InputBegan:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1
					or Input.UserInputType == Enum.UserInputType.Touch then
						Dragging = true
					end
				end)
				SliderFrame.InputEnded:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1
					or Input.UserInputType == Enum.UserInputType.Touch then
						Dragging = false
						_CB(Funcs_Slider.Value)
					end
				end)

				local _LastX = nil
				UserInputService.InputChanged:Connect(function(Input)
					if Dragging then
						local CurrPosX = Input.Position.X
						if CurrPosX ~= _LastX then
							_LastX = CurrPosX
							local SizeScale = math.clamp(
								(CurrPosX - SliderFrame.AbsolutePosition.X) / SliderFrame.AbsoluteSize.X, 0, 1
							)
							Funcs_Slider:Set(_Min + ((_Max - _Min) * SizeScale))
						end
					end
				end)

				TextBox:GetPropertyChangedSignal("Text"):Connect(function()
					local Valid = TextBox.Text:gsub("[^%d]", "")
					if Valid ~= "" then
						local n = math.min(tonumber(Valid) or 0, _Max)
						TextBox.Text = tostring(n)
					else
						TextBox.Text = "0"
					end
				end)
				TextBox.FocusLost:Connect(function()
					Funcs_Slider:Set(tonumber(TextBox.Text) or 0)
					_CB(Funcs_Slider.Value)
				end)

				Funcs_Slider:Set(tonumber(_D))
				_CB(Funcs_Slider.Value)

				ItemCount += 1
				return Funcs_Slider
			end

			-- AddInput
			function Item:AddInput(Config)
				local _T  = Config[1] or Config.Title    or ""
				local _C  = Config[2] or Config.Content  or ""
				local _D  = Config[3] or Config.Default  or ""
				local _CB = Config[4] or Config.Callback or function() end
				local Funcs_Input = {Value = _D}

				local Input = makeRow(ItemCount, 35)
				Input.Name = "Input"

				Custom:Create("TextLabel", {
					Font               = Enum.Font.GothamBold,
					Text               = _T,
					TextColor3         = FG,
					TextSize           = 12,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Top,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 8),
					Size               = UDim2.new(1, -180, 0, 13),
					Name               = "InputTitle",
				}, Input)

				local InputContent = Custom:Create("TextLabel", {
					Font               = Enum.Font.Gotham,
					Text               = _C,
					TextColor3         = FG2,
					TextSize           = 11,
					TextWrapped        = true,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Bottom,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 22),
					Size               = UDim2.new(1, -180, 0, 12),
					Name               = "InputContent",
					Parent             = Input,
				})

				local function UpdateInputSize()
					local Ratio = InputContent.TextBounds.X / math.max(1, InputContent.AbsoluteSize.X)
					InputContent.Size = UDim2.new(1, -180, 0, 12 + (12 * math.floor(Ratio)))
					Input.Size = UDim2.new(1, 0, 0, InputContent.AbsoluteSize.Y + 30)
				end
				UpdateInputSize()
				InputContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					InputContent.TextWrapped = false
					UpdateInputSize()
					InputContent.TextWrapped = true
					UpdateSizeSection()
				end)

				local InputFrame = Custom:Create("Frame", {
					AnchorPoint        = Vector2.new(1, 0.5),
					BackgroundColor3   = BORDER,
					BorderSizePixel    = 0,
					ClipsDescendants   = true,
					Position           = UDim2.new(1, -8, 0.5, 0),
					Size               = UDim2.new(0, 140, 0, 26),
					Name               = "InputFrame",
				}, Input)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 5) }, InputFrame)
				Custom:Create("UIStroke",  { Color = BORDER2, Thickness = 1 }, InputFrame)

				local InputTextBox = Custom:Create("TextBox", {
					Font               = Enum.Font.Gotham,
					PlaceholderColor3  = MUTED,
					PlaceholderText    = "Type here…",
					Text               = _D,
					TextColor3         = FG,
					TextSize           = 11,
					TextXAlignment     = Enum.TextXAlignment.Left,
					AnchorPoint        = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 6, 0.5, 0),
					Size               = UDim2.new(1, -10, 1, -6),
					Name               = "InputTextBox",
				}, InputFrame)

				InputTextBox.Focused:Connect(function()
					TweenService:Create(InputFrame, TweenInfo.new(0.12), { BackgroundColor3 = ELEV }):Play()
				end)
				InputTextBox.FocusLost:Connect(function()
					TweenService:Create(InputFrame, TweenInfo.new(0.12), { BackgroundColor3 = BORDER }):Play()
					Funcs_Input:Set(InputTextBox.Text)
				end)

				function Funcs_Input:Set(Value)
					InputTextBox.Text = Value
					Funcs_Input.Value = Value
					_CB(Value)
				end
				Funcs_Input:Set(_D)

				ItemCount += 1
				return Funcs_Input
			end

			-- AddDropdown
			function Item:AddDropdown(Config)
				local _T   = Config[1] or Config.Title    or ""
				local _C   = Config[2] or Config.Content  or ""
				local _M   = Config[3] or Config.Multi    or false
				local _Opt = Config[4] or Config.Options  or {}
				local _D   = Config[5] or Config.Default  or {}
				local _CB  = Config[6] or Config.Callback or function() end
				local Funcs_Dropdown = {Value = _D, Options = _Opt}

				local Dropdown = makeRow(ItemCount, 35)
				Dropdown.Name = "Dropdown"

				local DropdownButton = Custom:Create("TextButton", {
					Font               = Enum.Font.SourceSans,
					Text               = "",
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Size               = UDim2.new(1, 0, 1, 0),
					Name               = "ToggleButton",
				}, Dropdown)

				Custom:Create("TextLabel", {
					Font               = Enum.Font.GothamBold,
					Text               = _T,
					TextColor3         = FG,
					TextSize           = 12,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Top,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 8),
					Size               = UDim2.new(1, -180, 0, 13),
					Name               = "DropdownTitle",
					Parent             = Dropdown,
				})

				local DropdownContent = Custom:Create("TextLabel", {
					Font               = Enum.Font.Gotham,
					Text               = _C,
					TextColor3         = FG2,
					TextSize           = 11,
					TextWrapped        = true,
					TextXAlignment     = Enum.TextXAlignment.Left,
					TextYAlignment     = Enum.TextYAlignment.Bottom,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 10, 0, 22),
					Size               = UDim2.new(1, -180, 0, 12),
					Name               = "DropdownContent",
					Parent             = Dropdown,
				})

				DropdownContent.Size = UDim2.new(1, -180, 0, 12 + (12 * (DropdownContent.TextBounds.X // math.max(1, DropdownContent.AbsoluteSize.X))))
				DropdownContent.TextWrapped = true
				Dropdown.Size = UDim2.new(1, 0, 0, DropdownContent.AbsoluteSize.Y + 30)

				DropdownContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					DropdownContent.TextWrapped = false
					DropdownContent.Size = UDim2.new(1, -180, 0, 12 + (12 * (DropdownContent.TextBounds.X // math.max(1, DropdownContent.AbsoluteSize.X))))
					Dropdown.Size = UDim2.new(1, 0, 0, DropdownContent.AbsoluteSize.Y + 30)
					DropdownContent.TextWrapped = true
					UpdateSizeSection()
				end)

				local SelectOptionsFrame = Custom:Create("Frame", {
					AnchorPoint      = Vector2.new(1, 0.5),
					BackgroundColor3 = BORDER,
					BorderSizePixel  = 0,
					Position         = UDim2.new(1, -8, 0.5, 0),
					Size             = UDim2.new(0, 140, 0, 26),
					Name             = "SelectOptionsFrame",
					LayoutOrder      = CountDropdown,
				}, Dropdown)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 5) }, SelectOptionsFrame)
				Custom:Create("UIStroke",  { Color = BORDER2, Thickness = 1 }, SelectOptionsFrame)

				DropdownButton.Activated:Connect(function()
					if not MoreBlur.Visible then
						MoreBlur.Visible = true
						local tweenInfo = TweenInfo.new(0.15)
						DropPageLayout:JumpToIndex(SelectOptionsFrame.LayoutOrder)
						TweenService:Create(MoreBlur,       tweenInfo, {BackgroundTransparency = 0.25}):Play()
						TweenService:Create(DropdownSelect, tweenInfo, {Position = UDim2.new(1, -11, 0.5, 0)}):Play()
					end
				end)

				local OptionSelecting = Custom:Create("TextLabel", {
					Font               = Enum.Font.Gotham,
					Text               = "Select…",
					TextColor3         = MUTED,
					TextSize           = 11,
					TextWrapped        = true,
					TextXAlignment     = Enum.TextXAlignment.Left,
					AnchorPoint        = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(0, 6, 0.5, 0),
					Size               = UDim2.new(1, -28, 1, -6),
					Name               = "OptionSelecting",
					TextTruncate       = Enum.TextTruncate.AtEnd,
				}, SelectOptionsFrame)

				Custom:Create("ImageLabel", {
					Image              = "rbxassetid://90200523188815",
					ImageColor3        = MUTED,
					AnchorPoint        = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Position           = UDim2.new(1, -2, 0.5, 0),
					Size               = UDim2.new(0, 18, 0, 18),
					Name               = "OptionImg",
				}, SelectOptionsFrame)

				local ScrollSelect = Custom:Create("ScrollingFrame", {
					CanvasSize         = UDim2.new(0, 0, 0, 0),
					ScrollBarThickness = 0,
					Active             = true,
					LayoutOrder        = CountDropdown,
					BackgroundTransparency = 1,
					BorderSizePixel    = 0,
					Size               = UDim2.new(1, 0, 1, 0),
					Name               = "ScrollSelect",
				}, DropdownFolder)
				Custom:Create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, ScrollSelect)
				Custom:Create("UIPadding",    { PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,4), PaddingLeft = UDim.new(0,4), PaddingRight = UDim.new(0,4) }, ScrollSelect)

				local SearchBar = Custom:Create("TextBox", {
					Font               = Enum.Font.Gotham,
					PlaceholderText    = "Search…",
					PlaceholderColor3  = MUTED,
					Text               = "",
					TextColor3         = FG,
					TextSize           = 11,
					BackgroundColor3   = BORDER,
					BorderSizePixel    = 0,
					Size               = UDim2.new(1, 0, 0, 24),
					Name               = "SearchBar",
					Parent             = ScrollSelect,
				})
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, SearchBar)

				SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
					local q = SearchBar.Text:lower()
					for _, v in pairs(ScrollSelect:GetChildren()) do
						if v:IsA("Frame") and v.Name == "Option" then
							local ot = v:FindFirstChild("OptionText")
							if ot then v.Visible = string.find(ot.Text:lower(), q) ~= nil end
						end
					end
				end)

				local DropCount = 0

				function Funcs_Dropdown:Clear()
					for _, DropFrame in pairs(ScrollSelect:GetChildren()) do
						if DropFrame.Name == "Option" then
							Funcs_Dropdown.Value   = {}
							Funcs_Dropdown.Options = {}
							OptionSelecting.Text   = "Select…"
							DropFrame:Destroy()
						end
					end
				end

				function Funcs_Dropdown:Set(Value)
					Funcs_Dropdown.Value = Value or Funcs_Dropdown.Value
					for _, Drop in pairs(ScrollSelect:GetChildren()) do
						if Drop.Name ~= "UIListLayout" and Drop.Name ~= "SearchBar" and Drop.Name ~= "UIPadding" then
							local found = table.find(Funcs_Dropdown.Value, Drop.OptionText and Drop.OptionText.Text)
							local tw = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
							if Drop:FindFirstChild("ChooseFrame") then
								TweenService:Create(Drop.ChooseFrame, tw, {
									BackgroundColor3 = found and ACCENT or BORDER,
								}):Play()
							end
							TweenService:Create(Drop, tw, {
								BackgroundColor3 = found and ELEV or CARD,
							}):Play()
						end
					end
					local joined = table.concat(Funcs_Dropdown.Value, ", ")
					OptionSelecting.Text      = joined ~= "" and joined or "Select…"
					OptionSelecting.TextColor3 = joined ~= "" and FG or MUTED
					_CB(Funcs_Dropdown.Value)
				end

				function Funcs_Dropdown:AddOption(OptionName)
					OptionName = OptionName or "Option"
					local Option = Custom:Create("Frame", {
						BackgroundColor3 = CARD,
						BorderSizePixel  = 0,
						LayoutOrder      = DropCount,
						Size             = UDim2.new(1, 0, 0, 28),
						Name             = "Option",
					}, ScrollSelect)
					Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Option)

					local ChooseFrame = Custom:Create("Frame", {
						AnchorPoint      = Vector2.new(0, 0.5),
						BackgroundColor3 = BORDER,
						BorderSizePixel  = 0,
						Position         = UDim2.new(0, 0, 0.5, 0),
						Size             = UDim2.new(0, 2, 0.6, 0),
						Name             = "ChooseFrame",
					}, Option)
					Custom:Create("UICorner", { CornerRadius = UDim.new(0, 9999) }, ChooseFrame)
					Custom:Create("UIStroke",  { Color = BORDER2, Thickness = 0.5, Transparency = 0.999 }, ChooseFrame)

					local OptionText = Custom:Create("TextLabel", {
						Font               = Enum.Font.Gotham,
						Text               = OptionName,
						TextColor3         = FG2,
						TextSize           = 11,
						TextXAlignment     = Enum.TextXAlignment.Left,
						BackgroundTransparency = 1,
						BorderSizePixel    = 0,
						AnchorPoint        = Vector2.new(0, 0.5),
						Position           = UDim2.new(0, 10, 0.5, 0),
						Size               = UDim2.new(1, -14, 0, 14),
						Name               = "OptionText",
					}, Option)

					local OptionButton = Custom:Create("TextButton", {
						Font               = Enum.Font.GothamBold,
						Text               = "",
						BackgroundTransparency = 1,
						BorderSizePixel    = 0,
						Size               = UDim2.new(1, 0, 1, 0),
						Name               = "OptionButton",
					}, Option)

					OptionButton.MouseEnter:Connect(function()
						if Option.BackgroundColor3 ~= ELEV then
							TweenService:Create(Option, TweenInfo.new(0.1), { BackgroundColor3 = BORDER }):Play()
						end
					end)
					OptionButton.MouseLeave:Connect(function()
						if Option.BackgroundColor3 ~= ELEV then
							TweenService:Create(Option, TweenInfo.new(0.1), { BackgroundColor3 = CARD }):Play()
						end
					end)

					OptionButton.Activated:Connect(function()
						CircleClick(OptionButton, Player:GetMouse().X, Player:GetMouse().Y)
						local isSelected = Option.BackgroundColor3 == ELEV
						if _M then
							if not isSelected then
								if not table.find(Funcs_Dropdown.Value, OptionName) then
									table.insert(Funcs_Dropdown.Value, OptionName)
								end
							else
								local idx = table.find(Funcs_Dropdown.Value, OptionName)
								if idx then table.remove(Funcs_Dropdown.Value, idx) end
							end
						else
							Funcs_Dropdown.Value = {OptionName}
						end
						Funcs_Dropdown:Set(Funcs_Dropdown.Value)
					end)

					local h = 28
					for _, child in ipairs(ScrollSelect:GetChildren()) do
						if child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" and child.Name ~= "SearchBar" then
							h = h + 4 + child.Size.Y.Offset
						end
					end
					ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, h + 32)

					DropCount += 1
				end

				function Funcs_Dropdown:Refresh(RefreshList, Selecting)
					RefreshList = RefreshList or {}
					Selecting   = Selecting   or {}
					Funcs_Dropdown:Clear()
					for _, Drop in ipairs(RefreshList) do
						Funcs_Dropdown:AddOption(Drop)
					end
					Funcs_Dropdown.Options = RefreshList
					Funcs_Dropdown:Set(Selecting)
				end

				Funcs_Dropdown:Refresh(Funcs_Dropdown.Options, Funcs_Dropdown.Value)

				ItemCount    += 1
				CountDropdown += 1
				return Funcs_Dropdown
			end

			ItemCount += 1
			return Item
		end -- end AddSection

		CountSection += 1
		CountTab     += 1
		return Sections
	end -- end CreateTab

	return Tabs
end -- end CreateWindow

return Speed_Library
