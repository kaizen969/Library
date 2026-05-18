--[[
  Speed Hub X — Library v5.1 (Optimized + Glassmorphism + Responsive)
  ------------------------------------------------------------------
  Public API (backwards-compatible):
    Speed_Library:CreateWindow{ Title, Description, "Tab Width", SizeUi }
      :CreateTab{ Name, Icon }
        :AddSection(Title, OpenByDefault)
          :AddParagraph{ Title, Content }
          :AddSeperator{ Title }
          :AddLine()
          :AddButton{ Title, Content, Icon, Callback }
          :AddToggle{ Title, Content, Default, Callback }
          :AddSlider{ Title, Content, Increment, Min, Max, Default, Callback }
          :AddInput{ Title, Content, Default, Callback }
          :AddDropdown{ Title, Content, Multi, Options, Default, Callback }
    Speed_Library:SetNotification{ Title, Description, Content, _, Time, Delay }

  What's new vs 5.0:
    • Fully responsive — auto-scales to viewport, collapsible tab drawer < 520px
    • Glassmorphism — Lighting BlurEffect + layered translucent frames + UIStrokes
    • Tab search bar (live filter on the left rail)
    • Cleaner, ~25% less code, no redundant property writes
    • Fixed broken tab layout on portrait mobile (the rotated/overlap bug)
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local VirtualUser       = game:GetService("VirtualUser")
local CoreGui           = game:GetService("CoreGui")

local Player = Players.LocalPlayer

----------------------------------------------------------------
-- Utilities
----------------------------------------------------------------
local Custom = {}
Custom.ColorRGB = Color3.fromRGB(250, 7, 7)
Custom.Accent   = Color3.fromRGB(250, 7, 7)
Custom.Glass    = Color3.fromRGB(15, 15, 18)

function Custom:Create(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function getParentGui()
	if RunService:IsStudio() then return Player:WaitForChild("PlayerGui") end
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then return hui end
	local ok2, cref = pcall(function() return cloneref and cloneref(CoreGui) end)
	if ok2 and cref then return cref end
	return CoreGui
end

local function isMobile()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize.X < 600
end

function Custom:EnabledAFK()
	Player.Idled:Connect(function()
		VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		task.wait(1)
		VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	end)
end
Custom:EnabledAFK()

----------------------------------------------------------------
-- Glass helper — applies a frosted-glass look to any frame
----------------------------------------------------------------
local function applyGlass(frame, opts)
	opts = opts or {}
	frame.BackgroundColor3 = opts.color or Custom.Glass
	frame.BackgroundTransparency = opts.transparency or 0.25
	frame.BorderSizePixel = 0

	Custom:Create("UICorner", { CornerRadius = UDim.new(0, opts.radius or 10) }, frame)

	Custom:Create("UIStroke", {
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = opts.strokeTransparency or 0.75,
		Thickness = opts.strokeThickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)

	-- diagonal sheen
	if opts.sheen ~= false then
		local g = Custom:Create("UIGradient", {
			Rotation = 135,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(180, 180, 180)),
				ColorSequenceKeypoint.new(1,    Color3.fromRGB(120, 120, 120)),
			},
			Transparency = NumberSequence.new{
				NumberSequenceKeypoint.new(0,   0.85),
				NumberSequenceKeypoint.new(0.5, 0.95),
				NumberSequenceKeypoint.new(1,   0.9),
			},
		}, frame)
		return g
	end
end

----------------------------------------------------------------
-- Ripple
----------------------------------------------------------------
local function ripple(button, x, y)
	task.spawn(function()
		button.ClipsDescendants = true
		local c = Custom:Create("ImageLabel", {
			Image = "rbxassetid://106471194043211",
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ImageTransparency = 0.85,
			BackgroundTransparency = 1,
			ZIndex = 10,
			Name = "Ripple",
		}, button)
		local nx = x - button.AbsolutePosition.X
		local ny = y - button.AbsolutePosition.Y
		c.Position = UDim2.new(0, nx, 0, ny)
		local size = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 1.6
		local t = TweenService:Create(c,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, size, 0, size), Position = UDim2.new(0.5, -size/2, 0.5, -size/2), ImageTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		c:Destroy()
	end)
end

----------------------------------------------------------------
-- Drag helper
----------------------------------------------------------------
local function makeDraggable(handle, target)
	local dragging, dragStart, startPos = false, nil, nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

----------------------------------------------------------------
-- Floating reopen button
----------------------------------------------------------------
local function makeOpenButton()
	local gui = Custom:Create("ScreenGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
	}, getParentGui())

	local btn = Custom:Create("ImageButton", {
		BackgroundColor3 = Custom.Glass,
		BackgroundTransparency = 0.2,
		Position = UDim2.new(0, 12, 0, 80),
		Size = UDim2.new(0, 48, 0, 48),
		Image = "rbxassetid://136890595976124",
		Visible = false,
		AutoButtonColor = false,
	}, gui)

	applyGlass(btn, { radius = 12, transparency = 0.2 })
	makeDraggable(btn, btn)
	return btn
end

----------------------------------------------------------------
-- Speed Library
----------------------------------------------------------------
local Speed_Library = { Unloaded = false }
local Notification  = {}

----------------------------------------------------------------
-- Notifications
----------------------------------------------------------------
function Speed_Library:SetNotification(Config)
	local Title       = Config[1] or Config.Title or ""
	local Description = Config[2] or Config.Description or ""
	local Content     = Config[3] or Config.Content or ""
	local Time        = Config[5] or Config.Time or 0.5
	local Delay       = Config[6] or Config.Delay or 5

	local gui = Custom:Create("ScreenGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
	}, getParentGui())

	local layout = Custom:Create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.new(0, math.min(320, workspace.CurrentCamera.ViewportSize.X - 40), 1, 0),
		Name = "NotificationLayout",
	}, gui)

	layout.ChildRemoved:Connect(function()
		local count = 0
		for _, v in ipairs(layout:GetChildren()) do
			TweenService:Create(v,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Position = UDim2.new(0, 0, 1, -((v.Size.Y.Offset + 12) * count)) }):Play()
			count += 1
		end
	end)

	local stackOffset = 0
	for _, v in ipairs(layout:GetChildren()) do
		stackOffset = stackOffset - v.Position.Y.Offset + v.Size.Y.Offset + 12
	end

	local outer = Custom:Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 150),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -stackOffset),
	}, layout)

	local card = Custom:Create("Frame", {
		Position = UDim2.new(0, 400, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
	}, outer)
	applyGlass(card, { radius = 10, transparency = 0.18 })

	local top = Custom:Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
	}, card)

	local lblTitle = Custom:Create("TextLabel", {
		Font = Enum.Font.GothamBold,
		Text = Title,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
	}, top)

	Custom:Create("TextLabel", {
		Font = Enum.Font.GothamBold,
		Text = Description,
		TextColor3 = Custom.Accent,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, lblTitle.TextBounds.X + 18, 0, 0),
	}, top)

	local close = Custom:Create("TextButton", {
		Font = Enum.Font.GothamBold,
		Text = "✕",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 25, 0, 25),
	}, top)

	local body = Custom:Create("TextLabel", {
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(180, 180, 185),
		TextSize = 12,
		Text = Content,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 32),
		Size = UDim2.new(1, -20, 0, 13),
	}, card)

	body.Size = UDim2.new(1, -20, 0, 13 + (13 * (body.TextBounds.X // body.AbsoluteSize.X)))
	outer.Size = UDim2.new(1, 0, 0, math.max(65, body.AbsoluteSize.Y + 44))

	local closing = false
	function Notification:Close()
		if closing then return end
		closing = true
		TweenService:Create(card,
			TweenInfo.new(Time, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
			{ Position = UDim2.new(0, 400, 0, 0) }):Play()
		task.wait(Time / 1.2)
		outer:Destroy()
	end

	close.Activated:Connect(function() Notification:Close() end)
	TweenService:Create(card,
		TweenInfo.new(Time, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
		{ Position = UDim2.new(0, 0, 0, 0) }):Play()

	task.delay(Delay, function() Notification:Close() end)
	return Notification
end

----------------------------------------------------------------
-- Window
----------------------------------------------------------------
function Speed_Library:CreateWindow(Config)
	local Title       = Config[1] or Config.Title or ""
	local Description = Config[2] or Config.Description or ""
	local TabWidth    = Config[3] or Config["Tab Width"] or 130

	-- Responsive size
	local cam = workspace.CurrentCamera
	local vp  = cam.ViewportSize
	local mobile = vp.X < 600

	local SizeUi
	if Config[4] or Config.SizeUi then
		SizeUi = Config[4] or Config.SizeUi
	elseif mobile then
		SizeUi = UDim2.new(0, math.floor(vp.X * 0.94), 0, math.floor(math.min(vp.Y * 0.7, 480)))
	else
		SizeUi = UDim2.fromOffset(580, 360)
	end

	if mobile then TabWidth = 0 end -- collapsible drawer on mobile

	local gui = Custom:Create("ScreenGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
	}, getParentGui())

	-- Lighting blur (real glass effect behind GUI)
	local blur = Custom:Create("BlurEffect", { Size = 0, Name = "SpeedHubXBlur" }, Lighting)
	TweenService:Create(blur, TweenInfo.new(0.3), { Size = 14 }):Play()

	local holder = Custom:Create("Frame", {
		BackgroundTransparency = 1,
		Size = SizeUi,
		Position = UDim2.new(0.5, -SizeUi.X.Offset/2, 0.5, -SizeUi.Y.Offset/2),
		Name = "Holder",
	}, gui)

	-- Drop shadow
	Custom:Create("ImageLabel", {
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = 0.4,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 60, 1, 60),
		ZIndex = 0,
	}, holder)

	local main = Custom:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Name = "Main",
		ClipsDescendants = true,
	}, holder)
	applyGlass(main, { radius = 14, transparency = 0.22 })

	---------------- Top bar
	local top = Custom:Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Name = "Top",
	}, main)

	local lblTitle = Custom:Create("TextLabel", {
		Font = Enum.Font.GothamBold,
		Text = Title,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
	}, top)

	Custom:Create("TextLabel", {
		Font = Enum.Font.GothamBold,
		Text = Description,
		TextColor3 = Custom.Accent,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(lblTitle.TextBounds.X + 130), 1, 0),
		Position = UDim2.new(0, lblTitle.TextBounds.X + 20, 0, 0),
	}, top)

	local function topBtn(symbol, x)
		return Custom:Create("TextButton", {
			Font = Enum.Font.GothamBold,
			Text = symbol,
			TextColor3 = Color3.fromRGB(230, 230, 230),
			TextSize = 16,
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.9,
			AutoButtonColor = false,
			Position = UDim2.new(1, x, 0.5, 0),
			Size = UDim2.new(0, 26, 0, 26),
		}, top)
	end

	-- Mobile drawer toggle
	local menuBtn
	if mobile then
		menuBtn = Custom:Create("TextButton", {
			Font = Enum.Font.GothamBold,
			Text = "≡",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 20,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.9,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.new(0, 30, 0, 26),
		}, top)
		Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, menuBtn)
		lblTitle.Position = UDim2.new(0, 46, 0, 0)
	end

	local closeBtn = topBtn("✕", -10)
	local minBtn   = topBtn("–", -44)
	for _, b in ipairs({ closeBtn, minBtn }) do
		Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	end

	-- thin divider under top bar
	Custom:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(1, -16, 0, 1),
	}, main)

	---------------- Layers tab (left rail)
	local railWidth = mobile and math.floor(SizeUi.X.Offset * 0.55) or TabWidth
	local layersTab = Custom:Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 50),
		Size = UDim2.new(0, railWidth, 1, -58),
		Name = "LayersTab",
		Visible = not mobile,
		ZIndex = 5,
	}, main)
	if mobile then
		applyGlass(layersTab, { radius = 10, transparency = 0.15 })
		layersTab.ZIndex = 10
	end

	-- Tab search bar (NEW)
	local tabSearch = Custom:Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.92,
		Size = UDim2.new(1, mobile and -16 or 0, 0, 28),
		Position = UDim2.new(0, mobile and 8 or 0, 0, mobile and 8 or 0),
		Name = "TabSearch",
	}, layersTab)
	Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, tabSearch)
	Custom:Create("UIStroke", {
		Color = Color3.fromRGB(255, 255, 255), Transparency = 0.85,
	}, tabSearch)

	Custom:Create("ImageLabel", {
		Image = "rbxassetid://3926305904",
		ImageRectOffset = Vector2.new(964, 324),
		ImageRectSize = Vector2.new(36, 36),
		ImageColor3 = Color3.fromRGB(180, 180, 185),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 0.5, -8),
		Size = UDim2.new(0, 16, 0, 16),
	}, tabSearch)

	local tabSearchBox = Custom:Create("TextBox", {
		Font = Enum.Font.Gotham,
		PlaceholderText = "Search tabs…",
		PlaceholderColor3 = Color3.fromRGB(150, 150, 155),
		Text = "",
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 28, 0, 0),
		Size = UDim2.new(1, -34, 1, 0),
	}, tabSearch)

	local scrollTab = Custom:Create("ScrollingFrame", {
		ScrollBarThickness = 0,
		Active = true,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, mobile and 8 or 0, 0, mobile and 44 or 36),
		Size = UDim2.new(1, mobile and -16 or 0, 1, mobile and -52 or -42),
		Name = "ScrollTab",
		CanvasSize = UDim2.new(0, 0, 0, 0),
	}, layersTab)

	Custom:Create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scrollTab)

	-- Right side (content)
	local layers = Custom:Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, mobile and 12 or (railWidth + 18), 0, 50),
		Size = UDim2.new(1, mobile and -24 or -(railWidth + 26), 1, -58),
		Name = "Layers",
	}, main)

	local nameTab = Custom:Create("TextLabel", {
		Font = Enum.Font.GothamBold,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Name = "NameTab",
	}, layers)

	local layersReal = Custom:Create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 1, -32),
	}, layers)

	local layersFolder = Custom:Create("Folder", { Name = "LayersFolder" }, layersReal)
	local pageLayout = Custom:Create("UIPageLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		TweenTime = 0.4,
		EasingDirection = Enum.EasingDirection.InOut,
		EasingStyle = Enum.EasingStyle.Quad,
	}, layersFolder)

	local function updateTabCanvas()
		local total = 0
		for _, v in ipairs(scrollTab:GetChildren()) do
			if v.Name == "Tab" and v.Visible then total = total + 4 + v.Size.Y.Offset end
		end
		scrollTab.CanvasSize = UDim2.new(0, 0, 0, total)
	end
	scrollTab.ChildAdded:Connect(updateTabCanvas)
	scrollTab.ChildRemoved:Connect(updateTabCanvas)

	-- Tab live search
	tabSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(tabSearchBox.Text)
		for _, t in ipairs(scrollTab:GetChildren()) do
			if t.Name == "Tab" then
				local nm = t:FindFirstChild("TabName")
				t.Visible = q == "" or (nm and string.find(string.lower(nm.Text), q, 1, true) ~= nil)
			end
		end
		updateTabCanvas()
	end)

	---------------- Window controls
	local openBtn = makeOpenButton()
	minBtn.Activated:Connect(function()
		ripple(minBtn, Player:GetMouse().X, Player:GetMouse().Y)
		holder.Visible = false
		blur.Size = 0
		openBtn.Visible = true
	end)
	openBtn.Activated:Connect(function()
		holder.Visible = true
		TweenService:Create(blur, TweenInfo.new(0.25), { Size = 14 }):Play()
		openBtn.Visible = false
	end)
	closeBtn.Activated:Connect(function()
		ripple(closeBtn, Player:GetMouse().X, Player:GetMouse().Y)
		gui:Destroy()
		blur:Destroy()
		Speed_Library.Unloaded = true
	end)

	if menuBtn then
		menuBtn.Activated:Connect(function()
			layersTab.Visible = not layersTab.Visible
		end)
	end

	makeDraggable(top, holder)

	---------------- Shared dropdown overlay (reused by AddDropdown)
	local moreBlur = Custom:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Name = "MoreBlur",
		ZIndex = 50,
	}, main)
	Custom:Create("UICorner", { CornerRadius = UDim.new(0, 14) }, moreBlur)

	local moreClick = Custom:Create("TextButton", {
		Text = "", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), ZIndex = 50,
	}, moreBlur)

	local dropdownPanel = Custom:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, math.min(220, SizeUi.X.Offset - 40), 0, math.min(260, SizeUi.Y.Offset - 80)),
		ClipsDescendants = true,
		ZIndex = 51,
		Name = "DropdownPanel",
	}, moreBlur)
	applyGlass(dropdownPanel, { radius = 10, transparency = 0.1 })

	local dropdownInner = Custom:Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -10, 1, -10),
		ZIndex = 52,
	}, dropdownPanel)

	local dropdownFolder = Custom:Create("Folder", { Name = "DropdownFolder" }, dropdownInner)
	local dropPageLayout = Custom:Create("UIPageLayout", {
		EasingDirection = Enum.EasingDirection.InOut,
		EasingStyle = Enum.EasingStyle.Quad,
		TweenTime = 0.01,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, dropdownFolder)

	moreClick.Activated:Connect(function()
		TweenService:Create(moreBlur, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
		task.wait(0.18)
		moreBlur.Visible = false
	end)

	----------------------------------------------------------------
	-- TABS
	----------------------------------------------------------------
	local Tabs = {}
	local tabCount, dropdownCount = 0, 0

	function Tabs:CreateTab(Config)
		local tabName = Config[1] or Config.Name or ""
		local icon    = Config[2] or Config.Icon or ""

		local page = Custom:Create("ScrollingFrame", {
			ScrollBarThickness = 0,
			Active = true,
			LayoutOrder = tabCount,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Name = "Page",
			CanvasSize = UDim2.new(0, 0, 0, 0),
		}, layersFolder)

		Custom:Create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, page)

		local tab = Custom:Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = tabCount == 0 and 0.88 or 0.97,
			BorderSizePixel = 0,
			LayoutOrder = tabCount,
			Size = UDim2.new(1, 0, 0, 32),
			Name = "Tab",
		}, scrollTab)
		Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, tab)

		local tabBtn = Custom:Create("TextButton", {
			Font = Enum.Font.GothamBold,
			Text = "",
			TextSize = 13,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Name = "TabButton",
			AutoButtonColor = false,
		}, tab)

		Custom:Create("TextLabel", {
			Font = Enum.Font.GothamBold,
			Text = tabName,
			TextColor3 = Color3.fromRGB(245, 245, 245),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -36, 1, 0),
			Position = UDim2.new(0, 32, 0, 0),
			Name = "TabName",
		}, tab)

		if icon ~= "" then
			Custom:Create("ImageLabel", {
				Image = icon,
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 9, 0.5, -8),
				Size = UDim2.new(0, 16, 0, 16),
				Name = "FeatureImg",
			}, tab)
		end

		local indicator
		if tabCount == 0 then
			pageLayout:JumpToIndex(0)
			nameTab.Text = tabName
			indicator = Custom:Create("Frame", {
				BackgroundColor3 = Custom.Accent,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 2, 0.5, -7),
				Size = UDim2.new(0, 2, 0, 14),
				Name = "Indicator",
			}, tab)
			Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, indicator)
		end

		tabBtn.Activated:Connect(function()
			ripple(tabBtn, Player:GetMouse().X, Player:GetMouse().Y)

			-- find current indicator
			local curr
			for _, t in ipairs(scrollTab:GetChildren()) do
				local i = t:FindFirstChild("Indicator")
				if i then curr = i; break end
			end

			if tab.LayoutOrder == pageLayout.CurrentPage.LayoutOrder then return end

			for _, t in ipairs(scrollTab:GetChildren()) do
				if t.Name == "Tab" then
					TweenService:Create(t, TweenInfo.new(0.18),
						{ BackgroundTransparency = 0.97 }):Play()
				end
			end
			TweenService:Create(tab, TweenInfo.new(0.25),
				{ BackgroundTransparency = 0.88 }):Play()

			if curr and curr.Parent ~= tab then
				curr.Parent = tab
				curr.Position = UDim2.new(0, 2, 0.5, -7)
			end

			pageLayout:JumpToIndex(tab.LayoutOrder)
			nameTab.Text = tabName

			if mobile and layersTab.Visible then
				layersTab.Visible = false
			end
		end)

		------------------------------------------------------------
		-- SECTIONS
		------------------------------------------------------------
		local Sections = {}
		local sectionCount = 0

		local function updatePageCanvas()
			local total = 0
			for _, c in ipairs(page:GetChildren()) do
				if c.Name == "Section" then total = total + 4 + c.Size.Y.Offset end
			end
			page.CanvasSize = UDim2.new(0, 0, 0, total)
		end

		function Sections:AddSection(title, openByDefault)
			title = title or ""
			local open = openByDefault or false

			local section = Custom:Create("Frame", {
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				LayoutOrder = sectionCount,
				Size = UDim2.new(1, 0, 0, 32),
				Name = "Section",
			}, page)

			local header = Custom:Create("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.93,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 32),
				Name = "Header",
			}, section)
			Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, header)
			Custom:Create("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255), Transparency = 0.88,
			}, header)

			local headerBtn = Custom:Create("TextButton", {
				Text = "", BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0), AutoButtonColor = false,
			}, header)

			local arrowFrame = Custom:Create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0, 18, 0, 18),
			}, header)
			local arrow = Custom:Create("ImageLabel", {
				Image = "rbxassetid://125609963478878",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Rotation = -90,
				Size = UDim2.new(1, 4, 1, 4),
			}, arrowFrame)

			Custom:Create("TextLabel", {
				Font = Enum.Font.GothamBold,
				Text = title,
				TextColor3 = Color3.fromRGB(230, 230, 230),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.new(1, -40, 0, 14),
			}, header)

			local divider = Custom:Create("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 34),
				Size = UDim2.new(0, 0, 0, 1),
				Name = "Divider",
			}, section)
			Custom:Create("UIGradient", {
				Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0,   Color3.fromRGB(20, 20, 20)),
					ColorSequenceKeypoint.new(0.5, Custom.Accent),
					ColorSequenceKeypoint.new(1,   Color3.fromRGB(20, 20, 20)),
				}
			}, divider)

			local body = Custom:Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.new(0.5, 0, 0, 38),
				Size = UDim2.new(1, 0, 0, 100),
				Name = "Body",
			}, section)
			Custom:Create("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, body)

			local function bodyHeight()
				local h = 0
				for _, c in ipairs(body:GetChildren()) do
					if not c:IsA("UIListLayout") then h = h + c.Size.Y.Offset + 4 end
				end
				return h
			end

			local function refreshSectionSize()
				if open then
					local h = bodyHeight()
					TweenService:Create(arrow, TweenInfo.new(0.15), { Rotation = 90 }):Play()
					TweenService:Create(section, TweenInfo.new(0.15),
						{ Size = UDim2.new(1, 0, 0, 38 + h) }):Play()
					TweenService:Create(body, TweenInfo.new(0.15),
						{ Size = UDim2.new(1, 0, 0, h) }):Play()
					TweenService:Create(divider, TweenInfo.new(0.15),
						{ Size = UDim2.new(1, 0, 0, 1) }):Play()
				else
					TweenService:Create(arrow, TweenInfo.new(0.15), { Rotation = -90 }):Play()
					TweenService:Create(section, TweenInfo.new(0.15),
						{ Size = UDim2.new(1, 0, 0, 32) }):Play()
					TweenService:Create(divider, TweenInfo.new(0.15),
						{ Size = UDim2.new(0, 0, 0, 1) }):Play()
				end
				task.delay(0.16, updatePageCanvas)
			end

			headerBtn.Activated:Connect(function()
				ripple(headerBtn, Player:GetMouse().X, Player:GetMouse().Y)
				open = not open
				refreshSectionSize()
			end)
			body.ChildAdded:Connect(refreshSectionSize)
			body.ChildRemoved:Connect(refreshSectionSize)
			refreshSectionSize()

			------------------------------------------------------------
			-- ITEMS
			------------------------------------------------------------
			local Item = {}
			local itemCount = 0

			local function makeItemFrame(name, height)
				local f = Custom:Create("Frame", {
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.94,
					BorderSizePixel = 0,
					LayoutOrder = itemCount,
					Size = UDim2.new(1, 0, 0, height or 36),
					Name = name,
				}, body)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, f)
				Custom:Create("UIStroke", {
					Color = Color3.fromRGB(255, 255, 255), Transparency = 0.92,
				}, f)
				return f
			end

			local function makeTitleAndContent(parent, title, content, rightPad)
				rightPad = rightPad or 100
				local lblT = Custom:Create("TextLabel", {
					Font = Enum.Font.GothamBold,
					Text = title,
					TextColor3 = Color3.fromRGB(235, 235, 235),
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 8),
					Size = UDim2.new(1, -rightPad, 0, 14),
				}, parent)
				local lblC = Custom:Create("TextLabel", {
					Font = Enum.Font.Gotham,
					Text = content,
					TextColor3 = Color3.fromRGB(180, 180, 185),
					TextSize = 12,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 22),
					Size = UDim2.new(1, -rightPad, 0, 12),
				}, parent)
				return lblT, lblC
			end

			-- Paragraph
			function Item:AddParagraph(Config)
				local title   = Config[1] or Config.Title or ""
				local content = Config[2] or Config.Content or ""
				local f = makeItemFrame("Paragraph", 36)
				local lblT, lblC = makeTitleAndContent(f, title, content, 16)
				local function fit()
					local lines = math.max(1, math.ceil(lblC.TextBounds.X / math.max(lblC.AbsoluteSize.X, 1)))
					lblC.Size = UDim2.new(1, -16, 0, 12 + 12 * lines)
					f.Size = UDim2.new(1, 0, 0, lblC.AbsoluteSize.Y + 32)
					refreshSectionSize()
				end
				task.defer(fit)
				lblC:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
				itemCount += 1
				return {
					Set = function(_, c)
						local t = c[1] or c.Title or ""
						local n = c[2] or c.Content or ""
						lblT.Text, lblC.Text = t, n
						fit()
					end
				}
			end

			-- Separator
			function Item:AddSeperator(Config)
				local title = Config[1] or Config.Title or ""
				local f = Custom:Create("Frame", {
					BackgroundColor3 = Color3.fromRGB(70, 70, 75),
					BackgroundTransparency = 0.2,
					BorderSizePixel = 0,
					LayoutOrder = itemCount,
					Size = UDim2.new(1, 0, 0, 26),
					Name = "Seperator",
				}, body)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, f)
				local lbl = Custom:Create("TextLabel", {
					Font = Enum.Font.GothamBold,
					Text = title,
					TextColor3 = Color3.fromRGB(230, 230, 230),
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 12, 0, 0),
					Size = UDim2.new(1, -16, 1, 0),
				}, f)
				itemCount += 1
				return { Set = function(_, c) lbl.Text = c[1] or c.Title or "" end }
			end

			-- Line
			function Item:AddLine()
				local l = Custom:Create("Frame", {
					BackgroundColor3 = Color3.fromRGB(90, 90, 95),
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					LayoutOrder = itemCount,
					Size = UDim2.new(1, 0, 0, 2),
					Name = "Line",
				}, body)
				Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, l)
				itemCount += 1
				return {}
			end

			-- Button
			function Item:AddButton(Config)
				local title    = Config[1] or Config.Title or ""
				local content  = Config[2] or Config.Content or ""
				local iconId   = Config[3] or Config.Icon or "rbxassetid://7734010488"
				local callback = Config[4] or Config.Callback or function() end

				local f = makeItemFrame("Button", 38)
				local _, lblC = makeTitleAndContent(f, title, content, 60)

				local btn = Custom:Create("TextButton", {
					Text = "", BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0), AutoButtonColor = false,
				}, f)

				local iconFrame = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.new(0, 24, 0, 24),
				}, f)
				Custom:Create("ImageLabel", {
					Image = iconId,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Size = UDim2.new(1, 0, 1, 0),
				}, iconFrame)

				local function fit()
					local lines = math.max(1, math.ceil(lblC.TextBounds.X / math.max(lblC.AbsoluteSize.X, 1)))
					lblC.Size = UDim2.new(1, -60, 0, 12 + 12 * lines)
					f.Size = UDim2.new(1, 0, 0, lblC.AbsoluteSize.Y + 32)
					refreshSectionSize()
				end
				task.defer(fit)
				lblC:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

				btn.Activated:Connect(function()
					ripple(btn, Player:GetMouse().X, Player:GetMouse().Y)
					callback()
				end)

				itemCount += 1
				return {}
			end

			-- Toggle
			function Item:AddToggle(Config)
				local title    = Config[1] or Config.Title or ""
				local content  = Config[2] or Config.Content or ""
				local default  = Config[3] or Config.Default or false
				local callback = Config[4] or Config.Callback or function() end

				local F = { Value = default }
				local f = makeItemFrame("Toggle", 38)
				local lblT, lblC = makeTitleAndContent(f, title, content, 70)

				local btn = Custom:Create("TextButton", {
					Text = "", BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0), AutoButtonColor = false,
				}, f)

				local pill = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.9,
					BorderSizePixel = 0,
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.new(0, 32, 0, 16),
				}, f)
				Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
				local pillStroke = Custom:Create("UIStroke", {
					Color = Color3.fromRGB(255, 255, 255), Transparency = 0.8,
				}, pill)

				local circle = Custom:Create("Frame", {
					BackgroundColor3 = Color3.fromRGB(235, 235, 235),
					BorderSizePixel = 0,
					Size = UDim2.new(0, 14, 0, 14),
					Position = UDim2.new(0, 1, 0.5, -7),
				}, pill)
				Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, circle)

				local function fit()
					local lines = math.max(1, math.ceil(lblC.TextBounds.X / math.max(lblC.AbsoluteSize.X, 1)))
					lblC.Size = UDim2.new(1, -70, 0, 12 + 12 * lines)
					f.Size = UDim2.new(1, 0, 0, lblC.AbsoluteSize.Y + 32)
					refreshSectionSize()
				end
				task.defer(fit)
				lblC:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

				local function animate(on)
					local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
					TweenService:Create(lblT, ti, {
						TextColor3 = on and Custom.Accent or Color3.fromRGB(235, 235, 235)
					}):Play()
					TweenService:Create(circle, ti, {
						Position = on and UDim2.new(1, -15, 0.5, -7) or UDim2.new(0, 1, 0.5, -7)
					}):Play()
					TweenService:Create(pill, ti, {
						BackgroundColor3 = on and Custom.Accent or Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = on and 0.05 or 0.9,
					}):Play()
					TweenService:Create(pillStroke, ti, {
						Color = on and Custom.Accent or Color3.fromRGB(255, 255, 255),
						Transparency = on and 0 or 0.8,
					}):Play()
				end

				function F:Set(v)
					F.Value = v
					callback(v)
					animate(v)
				end
				btn.Activated:Connect(function()
					ripple(btn, Player:GetMouse().X, Player:GetMouse().Y)
					F:Set(not F.Value)
				end)
				F:Set(F.Value)
				itemCount += 1
				return F
			end

			-- Slider
			function Item:AddSlider(Config)
				local title     = Config[1] or Config.Title or ""
				local content   = Config[2] or Config.Content or ""
				local increment = Config[3] or Config.Increment or 1
				local minV      = Config[4] or Config.Min or 0
				local maxV      = Config[5] or Config.Max or 100
				local default   = Config[6] or Config.Default or 50
				local callback  = Config[7] or Config.Callback or function() end

				local F = { Value = default }
				local rightPad = mobile and 130 or 180
				local f = makeItemFrame("Slider", 38)
				local _, lblC = makeTitleAndContent(f, title, content, rightPad)

				local function fit()
					local lines = math.max(1, math.ceil(lblC.TextBounds.X / math.max(lblC.AbsoluteSize.X, 1)))
					lblC.Size = UDim2.new(1, -rightPad, 0, 12 + 12 * lines)
					f.Size = UDim2.new(1, 0, 0, lblC.AbsoluteSize.Y + 32)
					refreshSectionSize()
				end
				task.defer(fit)
				lblC:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

				local input = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Custom.Accent,
					BorderSizePixel = 0,
					Position = UDim2.new(1, -(rightPad - 25), 0.5, 0),
					Size = UDim2.new(0, 30, 0, 20),
				}, f)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, input)
				local box = Custom:Create("TextBox", {
					Font = Enum.Font.GothamBold,
					Text = tostring(default),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 12,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
				}, input)

				local barWidth = mobile and 80 or 100
				local bar = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.8,
					BorderSizePixel = 0,
					Position = UDim2.new(1, -16, 0.5, 0),
					Size = UDim2.new(0, barWidth, 0, 4),
				}, f)
				Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)

				local fill = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Custom.Accent,
					BorderSizePixel = 0,
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.new(0, 0, 1, 0),
				}, bar)
				Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

				local knob = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Custom.Accent,
					BorderSizePixel = 0,
					Position = UDim2.new(1, 4, 0.5, 0),
					Size = UDim2.new(0, 10, 0, 10),
				}, fill)
				Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
				Custom:Create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.6 }, knob)

				local function round(n, step)
					return math.floor(n / step + 0.5) * step
				end

				function F:Set(v)
					v = math.clamp(round(v, increment), minV, maxV)
					F.Value = v
					box.Text = tostring(v)
					TweenService:Create(fill, TweenInfo.new(0.08),
						{ Size = UDim2.fromScale((v - minV) / (maxV - minV), 1) }):Play()
				end

				local dragging = false
				bar.InputBegan:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1
						or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
				end)
				bar.InputEnded:Connect(function(i)
					if i.UserInputType == Enum.UserInputType.MouseButton1
						or i.UserInputType == Enum.UserInputType.Touch then
						dragging = false
						callback(F.Value)
					end
				end)
				UserInputService.InputChanged:Connect(function(i)
					if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
						or i.UserInputType == Enum.UserInputType.Touch) then
						local s = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
						F:Set(minV + (maxV - minV) * s)
					end
				end)
				box.FocusLost:Connect(function()
					local n = tonumber(box.Text)
					F:Set(n or 0); callback(F.Value)
				end)
				F:Set(default); callback(F.Value)
				itemCount += 1
				return F
			end

			-- Input
			function Item:AddInput(Config)
				local title    = Config[1] or Config.Title or ""
				local content  = Config[2] or Config.Content or ""
				local default  = Config[3] or Config.Default or ""
				local callback = Config[4] or Config.Callback or function() end

				local F = { Value = default }
				local rightPad = mobile and 130 or 160
				local f = makeItemFrame("Input", 38)
				local _, lblC = makeTitleAndContent(f, title, content, rightPad)

				local function fit()
					local lines = math.max(1, math.ceil(lblC.TextBounds.X / math.max(lblC.AbsoluteSize.X, 1)))
					lblC.Size = UDim2.new(1, -rightPad, 0, 12 + 12 * lines)
					f.Size = UDim2.new(1, 0, 0, lblC.AbsoluteSize.Y + 32)
					refreshSectionSize()
				end
				task.defer(fit)
				lblC:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

				local box = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.92,
					BorderSizePixel = 0,
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.new(0, mobile and 116 or 140, 0, 26),
					ClipsDescendants = true,
				}, f)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, box)
				Custom:Create("UIStroke", {
					Color = Color3.fromRGB(255, 255, 255), Transparency = 0.85,
				}, box)

				local tb = Custom:Create("TextBox", {
					Font = Enum.Font.Gotham,
					PlaceholderText = "Write your input…",
					PlaceholderColor3 = Color3.fromRGB(140, 140, 145),
					Text = "",
					TextColor3 = Color3.fromRGB(245, 245, 245),
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = false,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 8, 0, 0),
					Size = UDim2.new(1, -16, 1, 0),
				}, box)

				function F:Set(v)
					tb.Text = v; F.Value = v; callback(v)
				end
				tb.FocusLost:Connect(function() F:Set(tb.Text) end)
				F:Set(default)
				itemCount += 1
				return F
			end

			-- Dropdown
			function Item:AddDropdown(Config)
				local title    = Config[1] or Config.Title or ""
				local content  = Config[2] or Config.Content or ""
				local multi    = Config[3] or Config.Multi or false
				local options  = Config[4] or Config.Options or {}
				local default  = Config[5] or Config.Default or {}
				local callback = Config[6] or Config.Callback or function() end

				local F = { Value = default, Options = options }
				local rightPad = mobile and 130 or 160
				local f = makeItemFrame("Dropdown", 38)
				local _, lblC = makeTitleAndContent(f, title, content, rightPad)

				local function fit()
					local lines = math.max(1, math.ceil(lblC.TextBounds.X / math.max(lblC.AbsoluteSize.X, 1)))
					lblC.Size = UDim2.new(1, -rightPad, 0, 12 + 12 * lines)
					f.Size = UDim2.new(1, 0, 0, lblC.AbsoluteSize.Y + 32)
					refreshSectionSize()
				end
				task.defer(fit)
				lblC:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

				local sel = Custom:Create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.92,
					BorderSizePixel = 0,
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.new(0, mobile and 116 or 140, 0, 26),
					LayoutOrder = dropdownCount,
				}, f)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, sel)
				Custom:Create("UIStroke", {
					Color = Color3.fromRGB(255, 255, 255), Transparency = 0.85,
				}, sel)

				local selLbl = Custom:Create("TextLabel", {
					Font = Enum.Font.Gotham,
					Text = "Select Options",
					TextColor3 = Color3.fromRGB(220, 220, 220),
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 8, 0, 0),
					Size = UDim2.new(1, -28, 1, 0),
				}, sel)
				Custom:Create("ImageLabel", {
					Image = "rbxassetid://90200523188815",
					ImageColor3 = Color3.fromRGB(220, 220, 220),
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -4, 0.5, 0),
					Size = UDim2.new(0, 18, 0, 18),
				}, sel)

				local btn = Custom:Create("TextButton", {
					Text = "", BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0), AutoButtonColor = false,
				}, sel)

				-- Per-dropdown options page
				local optionsPage = Custom:Create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0),
					LayoutOrder = dropdownCount,
					Name = "DropdownPage",
				}, dropdownFolder)

				local searchBar = Custom:Create("Frame", {
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.9,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 26),
				}, optionsPage)
				Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, searchBar)
				Custom:Create("UIStroke", {
					Color = Color3.fromRGB(255, 255, 255), Transparency = 0.8,
				}, searchBar)
				local searchBox = Custom:Create("TextBox", {
					Font = Enum.Font.Gotham,
					PlaceholderText = "Search…",
					PlaceholderColor3 = Color3.fromRGB(150, 150, 155),
					Text = "",
					TextColor3 = Color3.fromRGB(240, 240, 240),
					TextSize = 12,
					ClearTextOnFocus = false,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 10, 0, 0),
					Size = UDim2.new(1, -20, 1, 0),
				}, searchBar)

				local optScroll = Custom:Create("ScrollingFrame", {
					ScrollBarThickness = 0,
					Active = true,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 0, 32),
					Size = UDim2.new(1, 0, 1, -32),
					CanvasSize = UDim2.new(0, 0, 0, 0),
				}, optionsPage)
				Custom:Create("UIListLayout", {
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, optScroll)

				btn.Activated:Connect(function()
					moreBlur.Visible = true
					dropPageLayout:JumpToIndex(optionsPage.LayoutOrder)
					moreBlur.BackgroundTransparency = 1
					TweenService:Create(moreBlur, TweenInfo.new(0.18),
						{ BackgroundTransparency = 0.4 }):Play()
				end)

				local function updateOptCanvas()
					local h = 0
					for _, c in ipairs(optScroll:GetChildren()) do
						if c.Name == "Option" and c.Visible then h = h + 4 + c.Size.Y.Offset end
					end
					optScroll.CanvasSize = UDim2.new(0, 0, 0, h)
				end

				searchBox:GetPropertyChangedSignal("Text"):Connect(function()
					local q = string.lower(searchBox.Text)
					for _, o in ipairs(optScroll:GetChildren()) do
						if o.Name == "Option" then
							local t = o:FindFirstChild("OptionText")
							o.Visible = q == "" or (t and string.find(string.lower(t.Text), q, 1, true) ~= nil)
						end
					end
					updateOptCanvas()
				end)

				function F:Clear()
					for _, c in ipairs(optScroll:GetChildren()) do
						if c.Name == "Option" then c:Destroy() end
					end
					F.Value, F.Options = {}, {}
					selLbl.Text = "Select Options"
				end

				function F:Set(v)
					F.Value = v or F.Value
					for _, o in ipairs(optScroll:GetChildren()) do
						if o.Name == "Option" then
							local txt = o:FindFirstChild("OptionText")
							if txt then
								local on = table.find(F.Value, txt.Text) ~= nil
								local mark = o:FindFirstChild("Indicator")
								if mark then
									TweenService:Create(mark, TweenInfo.new(0.15),
										{ Size = on and UDim2.new(0, 2, 0, 14) or UDim2.new(0, 0, 0, 14) }):Play()
								end
								TweenService:Create(o, TweenInfo.new(0.15),
									{ BackgroundTransparency = on and 0.85 or 0.96 }):Play()
							end
						end
					end
					local s = table.concat(F.Value, ", ")
					selLbl.Text = (s ~= "" and s) or "Select Options"
					callback(F.Value)
				end

				function F:AddOption(name)
					name = name or "Option"
					local opt = Custom:Create("Frame", {
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 0.96,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, 28),
						Name = "Option",
					}, optScroll)
					Custom:Create("UICorner", { CornerRadius = UDim.new(0, 5) }, opt)

					local indicator = Custom:Create("Frame", {
						BackgroundColor3 = Custom.Accent,
						BorderSizePixel = 0,
						Position = UDim2.new(0, 4, 0.5, -7),
						Size = UDim2.new(0, 0, 0, 14),
						Name = "Indicator",
					}, opt)
					Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, indicator)

					Custom:Create("TextLabel", {
						Font = Enum.Font.GothamBold,
						Text = name,
						TextColor3 = Color3.fromRGB(230, 230, 230),
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 12, 0, 0),
						Size = UDim2.new(1, -16, 1, 0),
						Name = "OptionText",
					}, opt)

					local optBtn = Custom:Create("TextButton", {
						Text = "", BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 1, 0), AutoButtonColor = false,
					}, opt)

					optBtn.Activated:Connect(function()
						ripple(optBtn, Player:GetMouse().X, Player:GetMouse().Y)
						local has = table.find(F.Value, name) ~= nil
						if multi then
							if has then
								for i, v in ipairs(F.Value) do
									if v == name then table.remove(F.Value, i); break end
								end
							else
								table.insert(F.Value, name)
							end
						else
							F.Value = { name }
						end
						F:Set(F.Value)
					end)
					updateOptCanvas()
				end

				function F:Refresh(list, selecting)
					list = list or {}; selecting = selecting or {}
					F:Clear()
					for _, o in ipairs(list) do F:AddOption(o) end
					F.Options = list
					F:Set(selecting)
				end

				F:Refresh(F.Options, F.Value)
				itemCount += 1
				dropdownCount += 1
				return F
			end

			sectionCount += 1
			updatePageCanvas()
			return Item
		end

		tabCount += 1
		return Sections
	end

	-- Auto-rescale on viewport change (orientation flip etc.)
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if Config[4] or Config.SizeUi then return end
		local v = cam.ViewportSize
		if v.X < 600 then
			holder.Size = UDim2.new(0, math.floor(v.X * 0.94), 0, math.floor(math.min(v.Y * 0.7, 480)))
		else
			holder.Size = UDim2.fromOffset(580, 360)
		end
		holder.Position = UDim2.new(0.5, -holder.Size.X.Offset / 2, 0.5, -holder.Size.Y.Offset / 2)
	end)

	return Tabs
end

return Speed_Library
