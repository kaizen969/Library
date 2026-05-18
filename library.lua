--[[
  Speed Hub X - 5.0 (Optimized + Glassmorphism + Responsive + Tab Search)
  Reworked from the original Speed Hub X library.

  Key improvements:
    * Glassmorphism look (high background transparency, soft strokes,
      gradient highlight, drop shadow) like the reference screenshot.
    * Fully responsive: auto-scales the window with UIScale based on the
      viewport size so it looks correct on phones, tablets and PC.
    * Window auto-clamps inside the screen and is re-clamped when the
      viewport changes (rotation / resize).
    * New Tab search bar at the top of the sidebar: type to filter tabs
      live (matches the original dropdown search behavior).
    * Performance: shared TweenInfos, fewer redundant `Connect` calls,
      cached lookups, and lighter ripple effect.
    * Cleaner code: single `MakeDraggable`, single `Round`, etc.
--]]

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local VirtualUser        = game:GetService("VirtualUser")
local CoreGui            = game:GetService("CoreGui")

local Player             = Players.LocalPlayer

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------
local Custom = {}
Custom.ColorRGB = Color3.fromRGB(250, 7, 7) -- accent

-- shared tween infos (avoid recreating each call)
local TI_FAST   = TweenInfo.new(0.15, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TI_MED    = TweenInfo.new(0.25, Enum.EasingStyle.Quad,  Enum.EasingDirection.InOut)
local TI_BACK   = TweenInfo.new(0.35, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)

function Custom:Create(className, props, parent)
    local inst = Instance.new(className)
    for k, v in pairs(props) do
        inst[k] = v
    end
    if parent then inst.Parent = parent end
    return inst
end

-- Get the safest GUI parent (executor first, fallback to CoreGui)
local function GetGuiParent()
    if RunService:IsStudio() then
        return Player:WaitForChild("PlayerGui")
    end
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2, cr = pcall(function() return cloneref and cloneref(CoreGui) end)
    if ok2 and cr then return cr end
    return CoreGui
end

-- Anti-AFK
function Custom:EnabledAFK()
    Player.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end
Custom:EnabledAFK()

-- Apply glassmorphism style to any frame: soft border + subtle gradient highlight
local function ApplyGlass(frame, opts)
    opts = opts or {}
    Custom:Create("UIStroke", {
        Color        = opts.StrokeColor or Color3.fromRGB(255, 255, 255),
        Transparency = opts.StrokeTransparency or 0.85,
        Thickness    = opts.Thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, frame)
    if opts.NoGradient ~= true then
        Custom:Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1,    Color3.fromRGB(160, 160, 160)),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,   0.85),
                NumberSequenceKeypoint.new(1,   1),
            }),
            Rotation = 90,
        }, frame)
    end
end

-- Lightweight ripple
local function CircleClick(Button, X, Y)
    task.spawn(function()
        Button.ClipsDescendants = true

        local Circle = Custom:Create("ImageLabel", {
            Image = "rbxassetid://106471194043211",
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ImageTransparency = 0.85,
            BackgroundTransparency = 1,
            ZIndex = 10,
            Name = "Circle",
        }, Button)

        local NewX = X - Button.AbsolutePosition.X
        local NewY = Y - Button.AbsolutePosition.Y
        Circle.Position = UDim2.new(0, NewX, 0, NewY)

        local Size = math.max(Button.AbsoluteSize.X, Button.AbsoluteSize.Y) * 1.4
        local tween = TweenService:Create(Circle,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Size = UDim2.new(0, Size, 0, Size),
                Position = UDim2.new(0.5, -Size/2, 0.5, -Size/2),
                ImageTransparency = 1,
            })
        tween:Play()
        tween.Completed:Connect(function()
            Circle:Destroy()
        end)
    end)
end

-- Single shared draggable. Clamps inside viewport.
local function MakeDraggable(handle, target, screenGui)
    local dragging, dragStart, startPos = false, nil, nil

    local function clampToScreen()
        local vp = screenGui.AbsoluteSize
        local sz = target.AbsoluteSize
        local pos = target.Position
        local newX = math.clamp(pos.X.Offset, 0, math.max(0, vp.X - sz.X))
        local newY = math.clamp(pos.Y.Offset, 0, math.max(0, vp.Y - sz.Y))
        target.Position = UDim2.new(pos.X.Scale, newX, pos.Y.Scale, newY)
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    clampToScreen()
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if dragging
        and (input.UserInputType == Enum.UserInputType.MouseMovement
          or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    return clampToScreen
end

------------------------------------------------------------------
-- Reopen / Minimize button (draggable)
------------------------------------------------------------------
local function CreateReopenButton()
    local ScreenGui = Custom:Create("ScreenGui", {
        Name             = "SpeedHubX_Reopen",
        ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn     = false,
        IgnoreGuiInset   = true,
    }, GetGuiParent())

    local Btn = Custom:Create("ImageButton", {
        BackgroundColor3       = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Position               = UDim2.new(0.05, 0, 0.07, 0),
        Size                   = UDim2.new(0, 52, 0, 52),
        Image                  = "rbxassetid://136890595976124",
        Visible                = false,
    }, ScreenGui)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 12) }, Btn)
    ApplyGlass(Btn, { StrokeTransparency = 0.6 })

    MakeDraggable(Btn, Btn, ScreenGui)
    return Btn
end
local Open_Close = CreateReopenButton()

------------------------------------------------------------------
-- Library
------------------------------------------------------------------
local Speed_Library, Notification = {}, {}
Speed_Library.Unloaded = false

------------------------------------------------------------------
-- Notifications
------------------------------------------------------------------
function Speed_Library:SetNotification(Config)
    local Title       = Config[1] or Config.Title       or ""
    local Description = Config[2] or Config.Description or ""
    local Content     = Config[3] or Config.Content     or ""
    local Time        = Config[5] or Config.Time        or 0.5
    local Delay       = Config[6] or Config.Delay       or 5

    local Gui = Custom:Create("ScreenGui", {
        Name             = "SpeedHubX_Notify",
        ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn     = false,
        IgnoreGuiInset   = true,
    }, GetGuiParent())

    local Layout = Custom:Create("Frame", {
        AnchorPoint            = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        Position               = UDim2.new(1, -20, 1, -20),
        Size                   = UDim2.new(0, 300, 1, 0),
        Name                   = "NotificationLayout",
    }, Gui)

    Layout.ChildRemoved:Connect(function()
        local Count = 0
        for _, v in ipairs(Layout:GetChildren()) do
            local NewPOS = UDim2.new(0, 0, 1, -((v.Size.Y.Offset + 10) * Count))
            TweenService:Create(v, TI_MED, { Position = NewPOS }):Play()
            Count = Count + 1
        end
    end)

    local _Count = 0
    for _, v in ipairs(Layout:GetChildren()) do
        _Count = -(v.Position.Y.Offset) + v.Size.Y.Offset + 10
    end

    local Holder = Custom:Create("Frame", {
        BorderSizePixel        = 0,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 0, 80),
        Name                   = "NotificationFrame",
        AnchorPoint            = Vector2.new(0, 1),
        Position               = UDim2.new(0, 0, 1, -_Count),
    }, Layout)

    local Card = Custom:Create("Frame", {
        BackgroundColor3       = Color3.fromRGB(15, 15, 18),
        BackgroundTransparency = 0.25,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 400, 0, 0),
        Size                   = UDim2.new(1, 0, 1, 0),
        Name                   = "Card",
    }, Holder)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 10) }, Card)
    ApplyGlass(Card, { StrokeTransparency = 0.7 })

    local Top = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 0, 32),
    }, Card)

    local TitleLbl = Custom:Create("TextLabel", {
        Font                   = Enum.Font.GothamBold,
        Text                   = Title,
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextSize               = 14,
        TextXAlignment         = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, -40, 1, 0),
        Position               = UDim2.new(0, 12, 0, 0),
    }, Top)

    Custom:Create("TextLabel", {
        Font                   = Enum.Font.GothamBold,
        Text                   = Description,
        TextColor3             = Custom.ColorRGB,
        TextSize               = 13,
        TextXAlignment         = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, -(TitleLbl.TextBounds.X + 60), 1, 0),
        Position               = UDim2.new(0, 12 + TitleLbl.TextBounds.X + 6, 0, 0),
    }, Top)

    local Close = Custom:Create("TextButton", {
        Font                   = Enum.Font.GothamBold,
        Text                   = "X",
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextSize               = 16,
        AnchorPoint            = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position               = UDim2.new(1, -8, 0.5, 0),
        Size                   = UDim2.new(0, 22, 0, 22),
    }, Top)

    local Body = Custom:Create("TextLabel", {
        Font                   = Enum.Font.Gotham,
        Text                   = Content,
        TextColor3             = Color3.fromRGB(180, 180, 180),
        TextSize               = 12,
        TextWrapped            = true,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextYAlignment         = Enum.TextYAlignment.Top,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 12, 0, 30),
        Size                   = UDim2.new(1, -24, 0, 14),
    }, Card)

    Body.Size = UDim2.new(1, -24, 0, 14 + (14 * (Body.TextBounds.X // math.max(1, Body.AbsoluteSize.X))))
    Holder.Size = UDim2.new(1, 0, 0, math.max(56, Body.AbsoluteSize.Y + 38))

    local Closed = false
    function Notification:Close()
        if Closed then return end
        Closed = true
        TweenService:Create(Card, TweenInfo.new(Time, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            { Position = UDim2.new(0, 400, 0, 0) }):Play()
        task.wait(Time / 1.2)
        Holder:Destroy()
    end

    Close.Activated:Connect(function() Notification:Close() end)
    TweenService:Create(Card, TweenInfo.new(Time, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 0, 0, 0) }):Play()

    task.delay(Delay, function() Notification:Close() end)
    return Notification
end

------------------------------------------------------------------
-- Window
------------------------------------------------------------------
function Speed_Library:CreateWindow(Config)
    local Title       = Config[1] or Config.Title       or ""
    local Description = Config[2] or Config.Description or ""
    local TabWidth    = Config[3] or Config["Tab Width"] or 130
    local SizeUi      = Config[4] or Config.SizeUi or UDim2.fromOffset(560, 330)

    local Gui = Custom:Create("ScreenGui", {
        Name             = "SpeedHubX_Main",
        ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn     = false,
        IgnoreGuiInset   = true,
    }, GetGuiParent())

    -------------------------------------------------------------
    -- Responsive scaling
    -------------------------------------------------------------
    local UI_W, UI_H = SizeUi.X.Offset, SizeUi.Y.Offset
    local Scale = Custom:Create("UIScale", { Scale = 1 }, Gui)

    local Holder = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Size                   = UDim2.new(0, UI_W, 0, UI_H),
        Position               = UDim2.new(0, 40, 0, 40),
        Name                   = "Holder",
    }, Gui)

    local function ApplyResponsiveScale()
        local vp = Gui.AbsoluteSize
        if vp.X <= 0 or vp.Y <= 0 then return end
        -- Fit window inside viewport with margins.
        local margin = 24
        local maxW   = math.max(220, vp.X - margin * 2)
        local maxH   = math.max(160, vp.Y - margin * 2)
        local scale  = math.min(1, maxW / UI_W, maxH / UI_H)
        -- Smaller minimum scale so it never disappears
        scale = math.max(scale, 0.5)
        Scale.Scale = scale

        -- Re-clamp position
        local sz = Vector2.new(UI_W * scale, UI_H * scale)
        local p  = Holder.Position
        local nx = math.clamp(p.X.Offset, 0, math.max(0, vp.X - sz.X))
        local ny = math.clamp(p.Y.Offset, 0, math.max(0, vp.Y - sz.Y))
        Holder.Position = UDim2.new(0, nx, 0, ny)
    end
    Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ApplyResponsiveScale)

    -------------------------------------------------------------
    -- Drop shadow + Main glass card
    -------------------------------------------------------------
    local Shadow = Custom:Create("ImageLabel", {
        Image                  = "rbxassetid://6014261993",
        ImageColor3            = Color3.fromRGB(0, 0, 0),
        ImageTransparency      = 0.55,
        ScaleType              = Enum.ScaleType.Slice,
        SliceCenter            = Rect.new(49, 49, 450, 450),
        AnchorPoint            = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position               = UDim2.new(0.5, 0, 0.5, 4),
        Size                   = UDim2.new(1, 40, 1, 40),
        ZIndex                 = 0,
        Name                   = "Shadow",
    }, Holder)

    local Main = Custom:Create("Frame", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        BackgroundColor3       = Color3.fromRGB(12, 12, 14),
        BackgroundTransparency = 0.35, -- glass
        BorderSizePixel        = 0,
        Position               = UDim2.new(0.5, 0, 0.5, 0),
        Size                   = UDim2.new(1, 0, 1, 0),
        Name                   = "Main",
    }, Holder)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 10) }, Main)
    ApplyGlass(Main, { StrokeTransparency = 0.7, Thickness = 1.4 })

    -------------------------------------------------------------
    -- Top bar
    -------------------------------------------------------------
    local Top = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 0, 36),
        Name                   = "Top",
    }, Main)

    local TitleLbl = Custom:Create("TextLabel", {
        Font                   = Enum.Font.GothamBold,
        Text                   = Title,
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextSize               = 14,
        TextXAlignment         = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, -100, 1, 0),
        Position               = UDim2.new(0, 12, 0, 0),
    }, Top)

    local DescLbl = Custom:Create("TextLabel", {
        Font                   = Enum.Font.GothamBold,
        Text                   = Description,
        TextColor3             = Custom.ColorRGB,
        TextSize               = 13,
        TextXAlignment         = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, -(TitleLbl.TextBounds.X + 110), 1, 0),
        Position               = UDim2.new(0, TitleLbl.TextBounds.X + 18, 0, 0),
    }, Top)

    local Close = Custom:Create("TextButton", {
        Font                   = Enum.Font.GothamBold,
        Text                   = "X",
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextSize               = 16,
        AnchorPoint            = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position               = UDim2.new(1, -8, 0.5, 0),
        Size                   = UDim2.new(0, 26, 0, 26),
    }, Top)

    local Min = Custom:Create("TextButton", {
        Font                   = Enum.Font.GothamBold,
        Text                   = "-",
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextSize               = 18,
        AnchorPoint            = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position               = UDim2.new(1, -38, 0.5, 0),
        Size                   = UDim2.new(0, 26, 0, 26),
    }, Top)

    -- Top divider
    Custom:Create("Frame", {
        AnchorPoint            = Vector2.new(0.5, 0),
        BackgroundColor3       = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.85,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0.5, 0, 0, 36),
        Size                   = UDim2.new(1, 0, 0, 1),
    }, Main)

    -------------------------------------------------------------
    -- Sidebar (Tabs) with search
    -------------------------------------------------------------
    local SearchHeight = 28
    local SidebarTopY  = 46

    local LayersTab = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 8, 0, SidebarTopY),
        Size                   = UDim2.new(0, TabWidth, 1, -(SidebarTopY + 8)),
        Name                   = "LayersTab",
    }, Main)

    -- Tab Search bar
    local SearchFrame = Custom:Create("Frame", {
        BackgroundColor3       = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.9,
        BorderSizePixel        = 0,
        Size                   = UDim2.new(1, 0, 0, SearchHeight),
        Name                   = "SearchFrame",
    }, LayersTab)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, SearchFrame)
    ApplyGlass(SearchFrame, { StrokeTransparency = 0.85, NoGradient = true })

    Custom:Create("ImageLabel", {
        Image                  = "rbxassetid://10747384394", -- search icon
        ImageColor3            = Color3.fromRGB(200, 200, 200),
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 6, 0.5, -7),
        Size                   = UDim2.new(0, 14, 0, 14),
    }, SearchFrame)

    local TabSearch = Custom:Create("TextBox", {
        Font                   = Enum.Font.Gotham,
        PlaceholderText        = "Search",
        PlaceholderColor3      = Color3.fromRGB(150, 150, 150),
        Text                   = "",
        TextColor3             = Color3.fromRGB(240, 240, 240),
        TextSize               = 12,
        TextXAlignment         = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 24, 0, 0),
        Size                   = UDim2.new(1, -28, 1, 0),
        ClearTextOnFocus       = false,
    }, SearchFrame)

    -- Scroll list of tabs (under search)
    local ScrollTab = Custom:Create("ScrollingFrame", {
        CanvasSize             = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness     = 0,
        Active                 = true,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 0, 0, SearchHeight + 6),
        Size                   = UDim2.new(1, 0, 1, -(SearchHeight + 6)),
        Name                   = "ScrollTab",
    }, LayersTab)
    Custom:Create("UIListLayout", {
        Padding   = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, ScrollTab)

    local function UpdateSizeTabs()
        local total = 0
        for _, v in ipairs(ScrollTab:GetChildren()) do
            if v:IsA("Frame") and v.Visible then
                total = total + 4 + v.Size.Y.Offset
            end
        end
        ScrollTab.CanvasSize = UDim2.new(0, 0, 0, total)
    end
    ScrollTab.ChildAdded:Connect(UpdateSizeTabs)
    ScrollTab.ChildRemoved:Connect(UpdateSizeTabs)

    -- Live filter for tabs
    TabSearch:GetPropertyChangedSignal("Text"):Connect(function()
        local q = string.lower(TabSearch.Text)
        for _, tab in ipairs(ScrollTab:GetChildren()) do
            if tab:IsA("Frame") and tab.Name == "Tab" then
                local nameLbl = tab:FindFirstChild("TabName")
                if q == "" then
                    tab.Visible = true
                else
                    tab.Visible = nameLbl
                        and string.find(string.lower(nameLbl.Text), q, 1, true) ~= nil
                        or false
                end
            end
        end
        UpdateSizeTabs()
    end)

    -------------------------------------------------------------
    -- Content area
    -------------------------------------------------------------
    local Layers = Custom:Create("Frame", {
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, TabWidth + 16, 0, 46),
        Size                   = UDim2.new(1, -(TabWidth + 24), 1, -54),
        Name                   = "Layers",
    }, Main)

    local NameTab = Custom:Create("TextLabel", {
        Font                   = Enum.Font.GothamBold,
        Text                   = "",
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextSize               = 22,
        TextWrapped            = true,
        TextXAlignment         = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 0, 28),
        Name                   = "NameTab",
    }, Layers)

    local LayersReal = Custom:Create("Frame", {
        AnchorPoint            = Vector2.new(0, 1),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ClipsDescendants       = true,
        Position               = UDim2.new(0, 0, 1, 0),
        Size                   = UDim2.new(1, 0, 1, -32),
        Name                   = "LayersReal",
    }, Layers)

    local LayersFolder = Custom:Create("Folder", { Name = "LayersFolder" }, LayersReal)
    local LayersPageLayout = Custom:Create("UIPageLayout", {
        SortOrder        = Enum.SortOrder.LayoutOrder,
        TweenTime        = 0.4,
        EasingDirection  = Enum.EasingDirection.InOut,
        EasingStyle      = Enum.EasingStyle.Quad,
    }, LayersFolder)

    -------------------------------------------------------------
    -- Min / Close / Reopen
    -------------------------------------------------------------
    Min.Activated:Connect(function()
        CircleClick(Min, Player:GetMouse().X, Player:GetMouse().Y)
        Holder.Visible = false
        if not Open_Close.Visible then Open_Close.Visible = true end
    end)
    Open_Close.Activated:Connect(function()
        Holder.Visible = true
        Open_Close.Visible = false
    end)
    Close.Activated:Connect(function()
        CircleClick(Close, Player:GetMouse().X, Player:GetMouse().Y)
        if Gui then Gui:Destroy() end
        Speed_Library.Unloaded = true
    end)

    MakeDraggable(Top, Holder, Gui)

    -------------------------------------------------------------
    -- Dropdown blur layer
    -------------------------------------------------------------
    local MoreBlur = Custom:Create("Frame", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        BackgroundColor3       = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ClipsDescendants       = true,
        Position               = UDim2.new(0.5, 0, 0.5, 0),
        Size                   = UDim2.new(1, 0, 1, 0),
        Visible                = false,
        Name                   = "MoreBlur",
    }, Main)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 10) }, MoreBlur)

    local CloseDropdownBtn = Custom:Create("TextButton", {
        Font                   = Enum.Font.SourceSans,
        Text                   = "",
        TextColor3             = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 1, 0),
        Name                   = "ConnectButton",
    }, MoreBlur)

    local DropdownSelect = Custom:Create("Frame", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        BackgroundColor3       = Color3.fromRGB(20, 20, 22),
        BackgroundTransparency = 0.15,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0.5, 0, 0.5, 0),
        Size                   = UDim2.new(0, 220, 0, 220),
        Name                   = "DropdownSelect",
        ClipsDescendants       = true,
    }, MoreBlur)
    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, DropdownSelect)
    ApplyGlass(DropdownSelect, { StrokeTransparency = 0.7 })

    CloseDropdownBtn.Activated:Connect(function()
        if MoreBlur.Visible then
            TweenService:Create(MoreBlur, TI_FAST, { BackgroundTransparency = 1 }):Play()
            task.wait(0.15)
            MoreBlur.Visible = false
        end
    end)

    local DropdownFolder    = Custom:Create("Folder", { Name = "DropdownFolder" }, DropdownSelect)
    local DropPageLayout    = Custom:Create("UIPageLayout", {
        EasingDirection = Enum.EasingDirection.InOut,
        EasingStyle     = Enum.EasingStyle.Quad,
        TweenTime       = 0.01,
        SortOrder       = Enum.SortOrder.LayoutOrder,
    }, DropdownFolder)

    -------------------------------------------------------------
    -- Tabs
    -------------------------------------------------------------
    local Tabs = {}
    local CountTab = 0
    local CountDropdown = 0
    function Tabs:CreateTab(Config)
        local _Name = Config[1] or Config.Name or ""
        local Icon  = Config[2] or Config.Icon or ""

        local ScrolLayers = Custom:Create("ScrollingFrame", {
            ScrollBarThickness     = 0,
            Active                 = true,
            LayoutOrder            = CountTab,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            Size                   = UDim2.new(1, 0, 1, 0),
            Name                   = "ScrolLayers",
        }, LayersFolder)
        Custom:Create("UIListLayout", {
            Padding   = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, ScrolLayers)

        local Tab = Custom:Create("Frame", {
            BackgroundColor3       = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = CountTab == 0 and 0.9 or 1,
            BorderSizePixel        = 0,
            LayoutOrder            = CountTab,
            Size                   = UDim2.new(1, 0, 0, 32),
            Name                   = "Tab",
        }, ScrollTab)
        Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, Tab)

        local TabButton = Custom:Create("TextButton", {
            Font                   = Enum.Font.GothamBold,
            Text                   = "",
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 1, 0),
            Name                   = "TabButton",
        }, Tab)

        Custom:Create("TextLabel", {
            Font                   = Enum.Font.GothamBold,
            Text                   = _Name,
            TextColor3             = Color3.fromRGB(235, 235, 235),
            TextSize               = 13,
            TextXAlignment         = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, -32, 1, 0),
            Position               = UDim2.new(0, 32, 0, 0),
            Name                   = "TabName",
        }, Tab)

        Custom:Create("ImageLabel", {
            Image                  = Icon,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0, 9, 0.5, -8),
            Size                   = UDim2.new(0, 16, 0, 16),
            Name                   = "FeatureImg",
        }, Tab)

        if CountTab == 0 then
            LayersPageLayout:JumpToIndex(0)
            NameTab.Text = _Name
            local Choose = Custom:Create("Frame", {
                BackgroundColor3 = Custom.ColorRGB,
                BorderSizePixel  = 0,
                Position         = UDim2.new(0, 2, 0, 10),
                Size             = UDim2.new(0, 2, 0, 12),
                Name             = "ChooseFrame",
            }, Tab)
            Custom:Create("UICorner", {}, Choose)
        end

        TabButton.Activated:Connect(function()
            CircleClick(TabButton, Player:GetMouse().X, Player:GetMouse().Y)
            local FrameChoose
            for _, s in ipairs(ScrollTab:GetChildren()) do
                local c = s:FindFirstChild("ChooseFrame")
                if c then FrameChoose = c break end
            end

            if FrameChoose and Tab.LayoutOrder ~= LayersPageLayout.CurrentPage.LayoutOrder then
                for _, t in ipairs(ScrollTab:GetChildren()) do
                    if t.Name == "Tab" then
                        TweenService:Create(t, TI_FAST, { BackgroundTransparency = 1 }):Play()
                    end
                end
                TweenService:Create(Tab, TI_MED, { BackgroundTransparency = 0.9 }):Play()
                FrameChoose.Parent = Tab
                FrameChoose.Position = UDim2.new(0, 2, 0, 10)

                LayersPageLayout:JumpToIndex(Tab.LayoutOrder)
                NameTab.Text = _Name
            end
        end)

        --------------------------------------------------------
        -- Sections
        --------------------------------------------------------
        local Sections, CountSection = {}, 0
        function Sections:AddSection(Title, OpenSection)
            Title       = Title or ""
            OpenSection = OpenSection or false

            local Section = Custom:Create("Frame", {
                BackgroundTransparency = 1,
                BorderSizePixel        = 0,
                ClipsDescendants       = true,
                LayoutOrder            = CountSection,
                Size                   = UDim2.new(1, 0, 0, 32),
                Name                   = "Section",
            }, ScrolLayers)

            local SectionReal = Custom:Create("Frame", {
                AnchorPoint            = Vector2.new(0.5, 0),
                BackgroundColor3       = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 0.92,
                BorderSizePixel        = 0,
                Position               = UDim2.new(0.5, 0, 0, 0),
                Size                   = UDim2.new(1, 0, 0, 32),
                Name                   = "SectionReal",
            }, Section)
            Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, SectionReal)
            ApplyGlass(SectionReal, { StrokeTransparency = 0.9, NoGradient = true })

            local SectionButton = Custom:Create("TextButton", {
                Font                   = Enum.Font.SourceSans,
                Text                   = "",
                BackgroundTransparency = 1,
                Size                   = UDim2.new(1, 0, 1, 0),
                Name                   = "SectionButton",
            }, SectionReal)

            local FeatureFrame = Custom:Create("Frame", {
                AnchorPoint            = Vector2.new(1, 0.5),
                BackgroundTransparency = 1,
                Position               = UDim2.new(1, -8, 0.5, 0),
                Size                   = UDim2.new(0, 18, 0, 18),
            }, SectionReal)

            local FeatureImg = Custom:Create("ImageLabel", {
                Image                  = "rbxassetid://125609963478878",
                AnchorPoint            = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Position               = UDim2.new(0.5, 0, 0.5, 0),
                Rotation               = -90,
                Size                   = UDim2.new(1, 6, 1, 6),
            }, FeatureFrame)

            Custom:Create("TextLabel", {
                Font                   = Enum.Font.GothamBold,
                Text                   = Title,
                TextColor3             = Color3.fromRGB(230, 230, 230),
                TextSize               = 13,
                TextXAlignment         = Enum.TextXAlignment.Left,
                AnchorPoint            = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Position               = UDim2.new(0, 12, 0.5, 0),
                Size                   = UDim2.new(1, -50, 0, 13),
            }, SectionReal)

            local SectionDecideFrame = Custom:Create("Frame", {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                AnchorPoint      = Vector2.new(0.5, 0),
                Position         = UDim2.new(0.5, 0, 0, 35),
                Size             = UDim2.new(0, 0, 0, 2),
                BorderSizePixel  = 0,
                Name             = "SectionDecideFrame",
            }, Section)
            Custom:Create("UICorner", {}, SectionDecideFrame)
            Custom:Create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0,   Color3.fromRGB(20, 20, 20)),
                    ColorSequenceKeypoint.new(0.5, Custom.ColorRGB),
                    ColorSequenceKeypoint.new(1,   Color3.fromRGB(20, 20, 20)),
                }),
            }, SectionDecideFrame)

            local SectionAdd = Custom:Create("Frame", {
                AnchorPoint            = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                BorderSizePixel        = 0,
                ClipsDescendants       = true,
                Position               = UDim2.new(0.5, 0, 0, 40),
                Size                   = UDim2.new(1, 0, 0, 0),
                Name                   = "SectionAdd",
            }, Section)
            Custom:Create("UIListLayout", {
                Padding   = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, SectionAdd)

            local function UpdateSizeScroll()
                local OffsetY = 0
                for _, child in ipairs(ScrolLayers:GetChildren()) do
                    if child:IsA("Frame") then
                        OffsetY = OffsetY + 4 + child.Size.Y.Offset
                    end
                end
                ScrolLayers.CanvasSize = UDim2.new(0, 0, 0, OffsetY)
            end

            local function UpdateSizeSection()
                if OpenSection then
                    local h = 40
                    for _, v in ipairs(SectionAdd:GetChildren()) do
                        if v:IsA("GuiObject") then
                            h = h + v.Size.Y.Offset + 4
                        end
                    end
                    TweenService:Create(FeatureImg,         TI_FAST, { Rotation = 90 }):Play()
                    TweenService:Create(Section,            TI_FAST, { Size = UDim2.new(1, 0, 0, h) }):Play()
                    TweenService:Create(SectionAdd,         TI_FAST, { Size = UDim2.new(1, 0, 0, h - 40) }):Play()
                    TweenService:Create(SectionDecideFrame, TI_FAST, { Size = UDim2.new(1, 0, 0, 2) }):Play()
                    task.wait(0.25)
                    UpdateSizeScroll()
                end
            end

            local function ToggleSection()
                CircleClick(SectionButton, Player:GetMouse().X, Player:GetMouse().Y)
                if OpenSection then
                    TweenService:Create(FeatureImg,         TI_FAST, { Rotation = -90 }):Play()
                    TweenService:Create(Section,            TI_FAST, { Size = UDim2.new(1, 0, 0, 32) }):Play()
                    TweenService:Create(SectionDecideFrame, TI_FAST, { Size = UDim2.new(0, 0, 0, 2) }):Play()
                    OpenSection = false
                    task.wait(0.15)
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

            ----------------------------------------------------
            -- Items (Paragraph / Separator / Line / Button /
            --        Toggle / Slider / Input / Dropdown)
            ----------------------------------------------------
            local Item, ItemCount = {}, 0

            local function NewBaseRow(name)
                local row = Custom:Create("Frame", {
                    BackgroundColor3       = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 0.92,
                    BorderSizePixel        = 0,
                    LayoutOrder            = ItemCount,
                    Size                   = UDim2.new(1, 0, 0, 36),
                    Name                   = name,
                }, SectionAdd)
                Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
                ApplyGlass(row, { StrokeTransparency = 0.92, NoGradient = true })
                return row
            end

            function Item:AddParagraph(Config)
                local Title   = Config[1] or Config.Title   or ""
                local Content = Config[2] or Config.Content or ""
                local Funcs   = {}

                local row = NewBaseRow("Paragraph")
                local TitleLbl = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.GothamBold,
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(231, 231, 231),
                    TextSize               = 13,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 10),
                    Size                   = UDim2.new(1, -20, 0, 13),
                }, row)

                local ContentLbl = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.Gotham,
                    Text                   = Content,
                    TextColor3             = Color3.fromRGB(220, 220, 220),
                    TextSize               = 12,
                    TextTransparency       = 0.4,
                    TextWrapped            = true,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 24),
                    Size                   = UDim2.new(1, -20, 0, 13),
                }, row)

                local function Resize()
                    ContentLbl.TextWrapped = false
                    local lines = math.max(1, math.ceil(ContentLbl.TextBounds.X / math.max(1, ContentLbl.AbsoluteSize.X)))
                    ContentLbl.Size = UDim2.new(1, -20, 0, 13 * lines)
                    row.Size        = UDim2.new(1, 0, 0, ContentLbl.AbsoluteSize.Y + 32)
                    ContentLbl.TextWrapped = true
                    UpdateSizeSection()
                end
                Resize()
                ContentLbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Resize)

                function Funcs:Set(c)
                    TitleLbl.Text   = c[1] or c.Title   or TitleLbl.Text
                    ContentLbl.Text = c[2] or c.Content or ContentLbl.Text
                    Resize()
                end
                ItemCount += 1
                return Funcs
            end

            function Item:AddSeperator(Config)
                local Title = Config[1] or Config.Title or ""
                local row   = NewBaseRow("Seperator")
                row.Size    = UDim2.new(1, 0, 0, 26)

                local Lbl = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.GothamBold,
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(231, 231, 231),
                    TextSize               = 13,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 0),
                    Size                   = UDim2.new(1, -16, 1, 0),
                }, row)

                ItemCount += 1
                return {
                    Set = function(_, c) Lbl.Text = c[1] or c.Title or Lbl.Text end
                }
            end

            function Item:AddLine()
                local Line = Custom:Create("Frame", {
                    BackgroundColor3       = Color3.fromRGB(120, 120, 120),
                    BackgroundTransparency = 0.5,
                    BorderSizePixel        = 0,
                    LayoutOrder            = ItemCount,
                    Size                   = UDim2.new(1, 0, 0, 2),
                    Name                   = "Line",
                }, SectionAdd)
                Custom:Create("UICorner", { CornerRadius = UDim.new(0, 1) }, Line)
                ItemCount += 1
                return {}
            end

            function Item:AddButton(Config)
                local Title    = Config[1] or Config.Title    or ""
                local Content  = Config[2] or Config.Content  or ""
                local Icon     = Config[3] or Config.Icon     or "rbxassetid://7734010488"
                local Callback = Config[4] or Config.Callback or function() end

                local row = NewBaseRow("Button")
                Custom:Create("TextLabel", {
                    Font                   = Enum.Font.GothamBold,
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(231, 231, 231),
                    TextSize               = 13,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 10),
                    Size                   = UDim2.new(1, -100, 0, 13),
                }, row)
                local ContentLbl = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.Gotham,
                    Text                   = Content,
                    TextColor3             = Color3.fromRGB(220, 220, 220),
                    TextSize               = 12,
                    TextTransparency       = 0.4,
                    TextWrapped            = true,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 24),
                    Size                   = UDim2.new(1, -100, 0, 13),
                }, row)

                local function Resize()
                    ContentLbl.TextWrapped = false
                    local lines = math.max(1, math.ceil(ContentLbl.TextBounds.X / math.max(1, ContentLbl.AbsoluteSize.X)))
                    ContentLbl.Size = UDim2.new(1, -100, 0, 13 * lines)
                    row.Size        = UDim2.new(1, 0, 0, ContentLbl.AbsoluteSize.Y + 32)
                    ContentLbl.TextWrapped = true
                    UpdateSizeSection()
                end
                Resize()
                ContentLbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Resize)

                local Btn = Custom:Create("TextButton", {
                    Font                   = Enum.Font.SourceSans,
                    Text                   = "",
                    BackgroundTransparency = 1,
                    Size                   = UDim2.new(1, 0, 1, 0),
                }, row)

                local IconHolder = Custom:Create("Frame", {
                    AnchorPoint            = Vector2.new(1, 0.5),
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(1, -15, 0.5, 0),
                    Size                   = UDim2.new(0, 24, 0, 24),
                }, row)
                Custom:Create("ImageLabel", {
                    Image                  = Icon,
                    AnchorPoint            = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0.5, 0, 0.5, 0),
                    Size                   = UDim2.new(1, 0, 1, 0),
                }, IconHolder)

                Btn.Activated:Connect(function()
                    CircleClick(Btn, Player:GetMouse().X, Player:GetMouse().Y)
                    Callback()
                end)
                ItemCount += 1
                return {}
            end

            function Item:AddToggle(Config)
                local Title    = Config[1] or Config.Title    or ""
                local Content  = Config[2] or Config.Content  or ""
                local Default  = Config[3] or Config.Default  or false
                local Callback = Config[4] or Config.Callback or function() end
                local Funcs    = { Value = Default }

                local row = NewBaseRow("Toggle")
                local TitleLbl = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.GothamBold,
                    Text                   = Title,
                    TextSize               = 13,
                    TextColor3             = Color3.fromRGB(231, 231, 231),
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 10),
                    Size                   = UDim2.new(1, -100, 0, 13),
                }, row)
                local ContentLbl = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.Gotham,
                    Text                   = Content,
                    TextSize               = 12,
                    TextColor3             = Color3.fromRGB(220, 220, 220),
                    TextTransparency       = 0.4,
                    TextWrapped            = true,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 24),
                    Size                   = UDim2.new(1, -100, 0, 13),
                }, row)

                local function Resize()
                    ContentLbl.TextWrapped = false
                    local lines = math.max(1, math.ceil(ContentLbl.TextBounds.X / math.max(1, ContentLbl.AbsoluteSize.X)))
                    ContentLbl.Size = UDim2.new(1, -100, 0, 13 * lines)
                    row.Size        = UDim2.new(1, 0, 0, ContentLbl.AbsoluteSize.Y + 32)
                    ContentLbl.TextWrapped = true
                    UpdateSizeSection()
                end
                Resize()
                ContentLbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Resize)

                local Btn = Custom:Create("TextButton", {
                    Font                   = Enum.Font.SourceSans,
                    Text                   = "",
                    BackgroundTransparency = 1,
                    Size                   = UDim2.new(1, 0, 1, 0),
                }, row)

                local Frame = Custom:Create("Frame", {
                    AnchorPoint            = Vector2.new(1, 0.5),
                    BackgroundColor3       = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 0.9,
                    BorderSizePixel        = 0,
                    Position               = UDim2.new(1, -15, 0.5, 0),
                    Size                   = UDim2.new(0, 32, 0, 16),
                }, row)
                Custom:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, Frame)
                local Stroke = Custom:Create("UIStroke", {
                    Color        = Color3.fromRGB(255, 255, 255),
                    Thickness    = 1.5,
                    Transparency = 0.85,
                }, Frame)

                local Circle = Custom:Create("Frame", {
                    BackgroundColor3 = Color3.fromRGB(230, 230, 230),
                    BorderSizePixel  = 0,
                    Position         = UDim2.new(0, 1, 0.5, -7),
                    Size             = UDim2.new(0, 14, 0, 14),
                }, Frame)
                Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, Circle)

                local function Animate(on)
                    local title  = on and Custom.ColorRGB or Color3.fromRGB(231, 231, 231)
                    local cpos   = on and UDim2.new(1, -15, 0.5, -7) or UDim2.new(0, 1, 0.5, -7)
                    local sCol   = on and Custom.ColorRGB or Color3.fromRGB(255, 255, 255)
                    local sTr    = on and 0 or 0.85
                    local fCol   = on and Custom.ColorRGB or Color3.fromRGB(255, 255, 255)
                    local fTr    = on and 0.1 or 0.9
                    TweenService:Create(TitleLbl, TI_FAST, { TextColor3 = title }):Play()
                    TweenService:Create(Circle,   TI_FAST, { Position = cpos }):Play()
                    TweenService:Create(Stroke,   TI_FAST, { Color = sCol, Transparency = sTr }):Play()
                    TweenService:Create(Frame,    TI_FAST, { BackgroundColor3 = fCol, BackgroundTransparency = fTr }):Play()
                end

                Btn.Activated:Connect(function()
                    CircleClick(Btn, Player:GetMouse().X, Player:GetMouse().Y)
                    Funcs.Value = not Funcs.Value
                    Funcs:Set(Funcs.Value)
                end)
                function Funcs:Set(v)
                    Funcs.Value = v
                    Callback(v)
                    Animate(v)
                end
                Funcs:Set(Funcs.Value)

                ItemCount += 1
                return Funcs
            end

            local function Round(n, f)
                local r = math.floor(n / f + (math.sign(n) * 0.5)) * f
                if r < 0 then r = r + f end
                return r
            end

            function Item:AddSlider(Config)
                local Title     = Config[1] or Config.Title     or ""
                local Content   = Config[2] or Config.Content   or ""
                local Increment = Config[3] or Config.Increment or 1
                local Min       = Config[4] or Config.Min       or 0
                local Max       = Config[5] or Config.Max       or 100
                local Default   = Config[6] or Config.Default   or 50
                local Callback  = Config[7] or Config.Callback  or function() end
                local Funcs     = { Value = Default }

                local row = NewBaseRow("Slider")
                Custom:Create("TextLabel", {
                    Font                   = Enum.Font.GothamBold,
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(230, 230, 230),
                    TextSize               = 13,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 10),
                    Size                   = UDim2.new(1, -180, 0, 13),
                }, row)
                local ContentLbl = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.Gotham,
                    Text                   = Content,
                    TextColor3             = Color3.fromRGB(220, 220, 220),
                    TextSize               = 12,
                    TextTransparency       = 0.4,
                    TextWrapped            = true,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 24),
                    Size                   = UDim2.new(1, -180, 0, 13),
                }, row)

                local function Resize()
                    ContentLbl.TextWrapped = false
                    local lines = math.max(1, math.ceil(ContentLbl.TextBounds.X / math.max(1, ContentLbl.AbsoluteSize.X)))
                    ContentLbl.Size = UDim2.new(1, -180, 0, 13 * lines)
                    row.Size        = UDim2.new(1, 0, 0, ContentLbl.AbsoluteSize.Y + 32)
                    ContentLbl.TextWrapped = true
                    UpdateSizeSection()
                end
                Resize()
                ContentLbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Resize)

                local InputBox = Custom:Create("Frame", {
                    AnchorPoint      = Vector2.new(0, 0.5),
                    BackgroundColor3 = Custom.ColorRGB,
                    BorderSizePixel  = 0,
                    Position         = UDim2.new(1, -155, 0.5, 0),
                    Size             = UDim2.new(0, 28, 0, 20),
                }, row)
                Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, InputBox)

                local TextBox = Custom:Create("TextBox", {
                    Font                   = Enum.Font.GothamBold,
                    Text                   = tostring(Default),
                    TextColor3             = Color3.fromRGB(255, 255, 255),
                    TextSize               = 13,
                    BackgroundTransparency = 1,
                    Size                   = UDim2.new(1, 0, 1, 0),
                }, InputBox)

                local Track = Custom:Create("Frame", {
                    AnchorPoint            = Vector2.new(1, 0.5),
                    BackgroundColor3       = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 0.7,
                    BorderSizePixel        = 0,
                    Position               = UDim2.new(1, -20, 0.5, 0),
                    Size                   = UDim2.new(0, 100, 0, 4),
                }, row)
                Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, Track)

                local Fill = Custom:Create("Frame", {
                    AnchorPoint      = Vector2.new(0, 0.5),
                    BackgroundColor3 = Custom.ColorRGB,
                    BorderSizePixel  = 0,
                    Position         = UDim2.new(0, 0, 0.5, 0),
                    Size             = UDim2.new(0, 0, 1, 0),
                }, Track)
                Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, Fill)

                local Knob = Custom:Create("Frame", {
                    AnchorPoint      = Vector2.new(1, 0.5),
                    BackgroundColor3 = Custom.ColorRGB,
                    BorderSizePixel  = 0,
                    Position         = UDim2.new(1, 4, 0.5, 0),
                    Size             = UDim2.new(0, 10, 0, 10),
                }, Fill)
                Custom:Create("UICorner", { CornerRadius = UDim.new(1, 0) }, Knob)

                local Dragging = false
                function Funcs:Set(v)
                    v = math.clamp(Round(v, Increment), Min, Max)
                    Funcs.Value = v
                    TextBox.Text = tostring(v)
                    TweenService:Create(Fill, TI_FAST, { Size = UDim2.fromScale((v - Min) / (Max - Min), 1) }):Play()
                end

                Track.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1
                    or i.UserInputType == Enum.UserInputType.Touch then
                        Dragging = true
                    end
                end)
                Track.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1
                    or i.UserInputType == Enum.UserInputType.Touch then
                        Dragging = false
                        Callback(Funcs.Value)
                    end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if Dragging
                    and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then
                        local s = math.clamp((i.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                        Funcs:Set(Min + (Max - Min) * s)
                    end
                end)
                TextBox.FocusLost:Connect(function()
                    local n = tonumber((TextBox.Text:gsub("[^%d.-]", ""))) or 0
                    Funcs:Set(n)
                    Callback(Funcs.Value)
                end)

                Funcs:Set(Default)
                Callback(Funcs.Value)
                ItemCount += 1
                return Funcs
            end

            function Item:AddInput(Config)
                local Title    = Config[1] or Config.Title    or ""
                local Content  = Config[2] or Config.Content  or ""
                local Default  = Config[3] or Config.Default  or ""
                local Callback = Config[4] or Config.Callback or function() end
                local Funcs    = { Value = Default }

                local row = NewBaseRow("Input")
                Custom:Create("TextLabel", {
                    Font                   = Enum.Font.GothamBold,
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(230, 230, 230),
                    TextSize               = 13,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 10),
                    Size                   = UDim2.new(1, -180, 0, 13),
                }, row)
                local ContentLbl = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.Gotham,
                    Text                   = Content,
                    TextColor3             = Color3.fromRGB(220, 220, 220),
                    TextSize               = 12,
                    TextTransparency       = 0.4,
                    TextWrapped            = true,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 24),
                    Size                   = UDim2.new(1, -180, 0, 13),
                }, row)
                local function Resize()
                    ContentLbl.TextWrapped = false
                    local lines = math.max(1, math.ceil(ContentLbl.TextBounds.X / math.max(1, ContentLbl.AbsoluteSize.X)))
                    ContentLbl.Size = UDim2.new(1, -180, 0, 13 * lines)
                    row.Size        = UDim2.new(1, 0, 0, ContentLbl.AbsoluteSize.Y + 32)
                    ContentLbl.TextWrapped = true
                    UpdateSizeSection()
                end
                Resize()
                ContentLbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Resize)

                local InputFrame = Custom:Create("Frame", {
                    AnchorPoint            = Vector2.new(1, 0.5),
                    BackgroundColor3       = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 0.92,
                    BorderSizePixel        = 0,
                    ClipsDescendants       = true,
                    Position               = UDim2.new(1, -8, 0.5, 0),
                    Size                   = UDim2.new(0, 150, 0, 28),
                }, row)
                Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, InputFrame)
                ApplyGlass(InputFrame, { StrokeTransparency = 0.85, NoGradient = true })

                local TextBox = Custom:Create("TextBox", {
                    Font                   = Enum.Font.Gotham,
                    PlaceholderText        = "Write your input there",
                    PlaceholderColor3      = Color3.fromRGB(140, 140, 140),
                    Text                   = "",
                    TextColor3             = Color3.fromRGB(255, 255, 255),
                    TextSize               = 12,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    AnchorPoint            = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 8, 0.5, 0),
                    Size                   = UDim2.new(1, -16, 1, -8),
                }, InputFrame)

                function Funcs:Set(v)
                    TextBox.Text = v
                    Funcs.Value  = v
                    Callback(v)
                end
                TextBox.FocusLost:Connect(function() Funcs:Set(TextBox.Text) end)
                Funcs:Set(Default)
                ItemCount += 1
                return Funcs
            end

            function Item:AddDropdown(Config)
                local Title    = Config[1] or Config.Title    or ""
                local Content  = Config[2] or Config.Content  or ""
                local Multi    = Config[3] or Config.Multi    or false
                local Options  = Config[4] or Config.Options  or {}
                local Default  = Config[5] or Config.Default  or {}
                local Callback = Config[6] or Config.Callback or function() end
                local Funcs    = { Value = Default, Options = Options }

                local row = NewBaseRow("Dropdown")
                local Btn = Custom:Create("TextButton", {
                    Font                   = Enum.Font.SourceSans,
                    Text                   = "",
                    BackgroundTransparency = 1,
                    Size                   = UDim2.new(1, 0, 1, 0),
                }, row)

                Custom:Create("TextLabel", {
                    Font                   = Enum.Font.GothamBold,
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(230, 230, 230),
                    TextSize               = 13,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 10),
                    Size                   = UDim2.new(1, -180, 0, 13),
                }, row)
                local ContentLbl = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.Gotham,
                    Text                   = Content,
                    TextColor3             = Color3.fromRGB(220, 220, 220),
                    TextSize               = 12,
                    TextTransparency       = 0.4,
                    TextWrapped            = true,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Top,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 24),
                    Size                   = UDim2.new(1, -180, 0, 13),
                }, row)
                local function Resize()
                    ContentLbl.TextWrapped = false
                    local lines = math.max(1, math.ceil(ContentLbl.TextBounds.X / math.max(1, ContentLbl.AbsoluteSize.X)))
                    ContentLbl.Size = UDim2.new(1, -180, 0, 13 * lines)
                    row.Size        = UDim2.new(1, 0, 0, ContentLbl.AbsoluteSize.Y + 32)
                    ContentLbl.TextWrapped = true
                    UpdateSizeSection()
                end
                Resize()
                ContentLbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Resize)

                local Pill = Custom:Create("Frame", {
                    AnchorPoint            = Vector2.new(1, 0.5),
                    BackgroundColor3       = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 0.92,
                    BorderSizePixel        = 0,
                    Position               = UDim2.new(1, -8, 0.5, 0),
                    Size                   = UDim2.new(0, 150, 0, 28),
                    LayoutOrder            = CountDropdown,
                }, row)
                Custom:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, Pill)
                ApplyGlass(Pill, { StrokeTransparency = 0.85, NoGradient = true })

                local Sel = Custom:Create("TextLabel", {
                    Font                   = Enum.Font.Gotham,
                    Text                   = "Select Options",
                    TextColor3             = Color3.fromRGB(220, 220, 220),
                    TextSize               = 12,
                    TextTransparency       = 0.2,
                    TextWrapped            = true,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    AnchorPoint            = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 8, 0.5, 0),
                    Size                   = UDim2.new(1, -30, 1, -8),
                }, Pill)
                Custom:Create("ImageLabel", {
                    Image                  = "rbxassetid://90200523188815",
                    ImageColor3            = Color3.fromRGB(231, 231, 231),
                    AnchorPoint            = Vector2.new(1, 0.5),
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(1, 0, 0.5, 0),
                    Size                   = UDim2.new(0, 22, 0, 22),
                }, Pill)

                local ScrollSelect = Custom:Create("ScrollingFrame", {
                    CanvasSize             = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness     = 0,
                    Active                 = true,
                    LayoutOrder            = CountDropdown,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, -10, 1, -10),
                    Position               = UDim2.new(0, 5, 0, 5),
                    Name                   = "ScrollSelect",
                }, DropdownFolder)
                Custom:Create("UIListLayout", {
                    Padding   = UDim.new(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, ScrollSelect)

                local SearchBar = Custom:Create("TextBox", {
                    Font                   = Enum.Font.Gotham,
                    PlaceholderText        = "Search",
                    PlaceholderColor3      = Color3.fromRGB(150, 150, 150),
                    Text                   = "",
                    TextColor3             = Color3.fromRGB(255, 255, 255),
                    TextSize               = 12,
                    BackgroundColor3       = Color3.fromRGB(0, 0, 0),
                    BackgroundTransparency = 0.6,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 0, 22),
                }, ScrollSelect)
                Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, SearchBar)

                Btn.Activated:Connect(function()
                    if not MoreBlur.Visible then
                        MoreBlur.Visible = true
                        DropPageLayout:JumpToIndex(ScrollSelect.LayoutOrder)
                        TweenService:Create(MoreBlur, TI_FAST, { BackgroundTransparency = 0.4 }):Play()
                    end
                end)

                SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
                    local q = string.lower(SearchBar.Text)
                    for _, v in ipairs(ScrollSelect:GetChildren()) do
                        if v:IsA("Frame") and v.Name == "Option" then
                            local lbl = v:FindFirstChild("OptionText")
                            v.Visible = (q == "") or (lbl and string.find(string.lower(lbl.Text), q, 1, true) ~= nil) or false
                        end
                    end
                end)

                local DropCount = 0
                function Funcs:Clear()
                    Funcs.Value, Funcs.Options = {}, {}
                    Sel.Text = "Select Options"
                    for _, c in ipairs(ScrollSelect:GetChildren()) do
                        if c.Name == "Option" then c:Destroy() end
                    end
                end

                function Funcs:Set(v)
                    Funcs.Value = v or Funcs.Value
                    for _, opt in ipairs(ScrollSelect:GetChildren()) do
                        if opt.Name == "Option" then
                            local found = table.find(Funcs.Value, opt.OptionText.Text)
                            local sz = found and UDim2.new(0, 2, 0, 12) or UDim2.new(0, 0, 0, 0)
                            local bg = found and 0.85 or 1
                            TweenService:Create(opt.ChooseFrame, TI_FAST, { Size = sz }):Play()
                            TweenService:Create(opt, TI_FAST, { BackgroundTransparency = bg }):Play()
                        end
                    end
                    local s = table.concat(Funcs.Value, ", ")
                    Sel.Text = s ~= "" and s or "Select Options"
                    Callback(Funcs.Value)
                end

                function Funcs:AddOption(name)
                    name = name or "Option"

                    local Opt = Custom:Create("Frame", {
                        BackgroundColor3       = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderSizePixel        = 0,
                        LayoutOrder            = DropCount,
                        Size                   = UDim2.new(1, 0, 0, 28),
                        Name                   = "Option",
                    }, ScrollSelect)
                    Custom:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Opt)

                    local OptBtn = Custom:Create("TextButton", {
                        Font                   = Enum.Font.GothamBold,
                        Text                   = "",
                        BackgroundTransparency = 1,
                        Size                   = UDim2.new(1, 0, 1, 0),
                        Name                   = "OptionButton",
                    }, Opt)

                    Custom:Create("TextLabel", {
                        Font                   = Enum.Font.Gotham,
                        Text                   = name,
                        TextSize               = 13,
                        TextColor3             = Color3.fromRGB(230, 230, 230),
                        TextXAlignment         = Enum.TextXAlignment.Left,
                        BackgroundTransparency = 1,
                        Position               = UDim2.new(0, 10, 0, 0),
                        Size                   = UDim2.new(1, -16, 1, 0),
                        Name                   = "OptionText",
                    }, Opt)

                    local Choose = Custom:Create("Frame", {
                        AnchorPoint      = Vector2.new(0, 0.5),
                        BackgroundColor3 = Custom.ColorRGB,
                        BorderSizePixel  = 0,
                        Position         = UDim2.new(0, 2, 0.5, 0),
                        Size             = UDim2.new(0, 0, 0, 0),
                        Name             = "ChooseFrame",
                    }, Opt)
                    Custom:Create("UICorner", {}, Choose)

                    OptBtn.Activated:Connect(function()
                        CircleClick(OptBtn, Player:GetMouse().X, Player:GetMouse().Y)
                        local selected = Opt.BackgroundTransparency > 0.95
                        if Multi then
                            if selected then
                                if not table.find(Funcs.Value, name) then
                                    table.insert(Funcs.Value, name)
                                end
                            else
                                for i, val in ipairs(Funcs.Value) do
                                    if val == name then table.remove(Funcs.Value, i) break end
                                end
                            end
                        else
                            Funcs.Value = { name }
                        end
                        Funcs:Set(Funcs.Value)
                    end)

                    local function UpdateCanvas()
                        local h = 0
                        for _, c in ipairs(ScrollSelect:GetChildren()) do
                            if c:IsA("GuiObject") then h = h + c.Size.Y.Offset + 4 end
                        end
                        ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, h)
                    end
                    UpdateCanvas()
                    DropCount += 1
                end

                function Funcs:Refresh(list, sel)
                    list, sel = list or {}, sel or {}
                    Funcs:Clear()
                    for _, n in ipairs(list) do Funcs:AddOption(n) end
                    Funcs.Options = list
                    Funcs:Set(sel)
                end

                Funcs:Refresh(Funcs.Options, Funcs.Value)
                ItemCount    += 1
                CountDropdown += 1
                return Funcs
            end

            ItemCount += 1
            return Item
        end

        CountTab += 1
        return Sections
    end

    -- initial scale
    task.defer(ApplyResponsiveScale)
    return Tabs
end

return Speed_Library
