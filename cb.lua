

local CONFIG = {
    ScriptURL   = "",
    Accent      = Color3.fromRGB(126, 96, 255),
    AccentDim   = Color3.fromRGB(52, 40, 104),
    Keybind     = Enum.KeyCode.RightShift,
    DetectGrace = 20,
    LogOnly     = false,
    Version     = "3.0",
}

if getgenv().SleepScript then pcall(function() getgenv().SleepScript.Unload() end) end

local booted, bootErr = pcall(function()

local cloneref = cloneref or function(x) return x end
local gethui    = gethui    or function() return game:GetService("CoreGui") end

local Players           = cloneref(game:GetService("Players"))
local RunService        = cloneref(game:GetService("RunService"))
local UIS               = cloneref(game:GetService("UserInputService"))
local TweenService      = cloneref(game:GetService("TweenService"))
local TeleportService   = cloneref(game:GetService("TeleportService"))
local HttpService       = cloneref(game:GetService("HttpService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Lighting          = cloneref(game:GetService("Lighting"))
local Stats             = cloneref(game:GetService("Stats"))
local Workspace         = cloneref(workspace)
local lp                = Players.LocalPlayer

local hasDrawing = Drawing ~= nil and Drawing.new ~= nil

--==============================================================
--  СОСТОЯНИЕ
--==============================================================
local S = {
    espEnabled   = false,
    style        = "corner",
    thickness    = 1,
    cornerSize   = 9,
    fill         = false,
    fillAlpha    = 0.85,
    textSize     = 13,
    nameMode     = "name",
    showDist     = true,
    distUnit     = "m",
    hpMode       = "bar",
    hpSide       = "left",
    skeleton     = false,
    tracer       = false,
    offscreen    = false,

    colorMode    = "static",
    colorStatic  = Color3.fromRGB(235, 235, 245),
    colorHidden  = Color3.fromRGB(150, 150, 165),
    colorTracer  = Color3.fromRGB(126, 96, 255),

    teamCheck    = true,
    showLocal    = false,
    maxDist      = 600,
    adaptive     = true,

    bhop         = false,
    bhopAggro    = false,
    jumpLimit    = 0,
    noAirSpread  = false,

    fovEnabled   = false,
    fovValue     = 90,

    watchEnabled = true,
    autoRejoin   = true,
    rejoinDelay  = 1.5,
    banCount     = 0,
    lastReason   = "—",

    fpsBoost     = false,
    statsWindow  = false,
}

local selfRead = false
local connections = {}
local function track(c) table.insert(connections, c) return c end

local function notify(text, dur)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "SleepScript", Text = text, Duration = dur or 3,
        })
    end)
end

local function logFile(line)
    if not writefile then return end
    pcall(function()
        local prev = isfile and isfile("SleepScript.log") and readfile("SleepScript.log") or ""
        writefile("SleepScript.log", prev .. os.date("[%H:%M:%S] ") .. line .. "\n")
    end)
end

--==============================================================
--  ХУМАНОИД
--==============================================================
local curHum = nil

local function refreshHum()
    local ok, char = pcall(function() return lp.Character end)
    if ok and char then
        curHum = char:FindFirstChildOfClass("Humanoid") or nil
    else
        curHum = nil
    end
end
refreshHum()

track(lp.CharacterAdded:Connect(function()
    curHum = nil
    task.delay(0.2, refreshHum)
end))
track(lp.CharacterRemoving:Connect(function() curHum = nil end))

local function realState(hum)
    if not hum then return nil end
    selfRead = true
    local ok, st = pcall(function() return hum:GetState() end)
    selfRead = false
    if ok then return st end
    return nil
end

local function realFloor(hum)
    if not hum then return nil end
    selfRead = true
    local ok, mat = pcall(function() return hum.FloorMaterial end)
    selfRead = false
    if ok then return mat end
    return nil
end

local function isAirborne(hum)
    if not hum or hum.Health <= 0 then return false end
    local st = realState(hum)
    if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping then
        return true
    end
    return realFloor(hum) == Enum.Material.Air
end

--==============================================================
--  КАМЕРА / FOV
--==============================================================
local camera = Workspace.CurrentCamera
local fovOriginal = camera and camera.FieldOfView or 70

local function applyFov()
    local cam = camera or Workspace.CurrentCamera
    if not cam then return end
    pcall(function() cam.FieldOfView = S.fovEnabled and S.fovValue or fovOriginal end)
end

track(RunService.RenderStepped:Connect(function()
    if not S.fovEnabled then return end
    local cam = camera or Workspace.CurrentCamera
    if not cam then return end
    if math.abs(cam.FieldOfView - S.fovValue) > 0.4 then
        pcall(function() cam.FieldOfView = S.fovValue end)
    end
end))

track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then
        camera = Workspace.CurrentCamera
        applyFov()
    end
end))

--==============================================================
--  UI ХЕЛПЕРЫ
--==============================================================
local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function tw(inst, time, props, style, dir)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local gui = new("ScreenGui", {
    Name = "SleepScript",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 9999,
}, gethui())

-- тень / свечение
local glow = new("Frame", {
    Size = UDim2.fromOffset(508, 372),
    Position = UDim2.new(0.5, -254, 0.5, -186),
    BackgroundColor3 = CONFIG.Accent,
    BackgroundTransparency = 0.9,
    BorderSizePixel = 0,
    ZIndex = 0,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 22) }, glow)

local main = new("Frame", {
    Size = UDim2.fromOffset(492, 356),
    Position = UDim2.new(0.5, -246, 0.5, -178),
    BackgroundColor3 = Color3.fromRGB(9, 9, 12),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 1,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, main)
new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.9, Thickness = 1 }, main)

local mainScale = new("UIScale", { Scale = 0.94 }, main)

track(main:GetPropertyChangedSignal("Visible"):Connect(function()
    glow.Visible = main.Visible
end))

-- открытие
main.BackgroundTransparency = 1
task.spawn(function()
    tw(mainScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
    tw(main, 0.25, { BackgroundTransparency = 0 })
end)

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = Color3.fromRGB(14, 14, 19),
    BorderSizePixel = 0,
    ZIndex = 2,
}, main)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, header)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Color3.fromRGB(14, 14, 19), BorderSizePixel = 0,
}, header)

local topLine = new("Frame", {
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = CONFIG.Accent,
    BorderSizePixel = 0,
    ZIndex = 5,
}, header)
local tlGrad = new("UIGradient", {
    Color = ColorSequence.new(Color3.fromRGB(60, 40, 130), CONFIG.Accent, Color3.fromRGB(60, 40, 130)),
}, topLine)
tlGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.5, 0.1),
    NumberSequenceKeypoint.new(1, 1),
})

new("TextLabel", {
    Text = "Sleep",
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 10),
    Size = UDim2.fromOffset(120, 22),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, header)

new("TextLabel", {
    Text = "counter blox",
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = Color3.fromRGB(120, 120, 138),
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(78, 14),
    Size = UDim2.fromOffset(200, 16),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, header)

new("TextLabel", {
    Text = "v" .. CONFIG.Version,
    Font = Enum.Font.GothamMedium,
    TextSize = 10,
    TextColor3 = CONFIG.Accent,
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 30),
    Size = UDim2.fromOffset(80, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, header)

local function headerButton(x, symbol, cb)
    local b = new("TextButton", {
        Text = symbol,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(170, 170, 188),
        BackgroundColor3 = Color3.fromRGB(24, 24, 32),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Position = UDim2.new(1, x, 0, 15),
        Size = UDim2.fromOffset(24, 24),
        ZIndex = 4,
    }, header)
    new("UICorner", { CornerRadius = UDim.new(0, 7) }, b)
    b.MouseEnter:Connect(function()
        tw(b, 0.14, { BackgroundColor3 = Color3.fromRGB(38, 32, 62), TextColor3 = Color3.fromRGB(255, 255, 255) })
    end)
    b.MouseLeave:Connect(function()
        tw(b, 0.14, { BackgroundColor3 = Color3.fromRGB(24, 24, 32), TextColor3 = Color3.fromRGB(170, 170, 188) })
    end)
    b.MouseButton1Click:Connect(cb)
    return b
end

headerButton(-88, "◉", function()
    S.statsWindow = not S.statsWindow
    local win = gui:FindFirstChild("SleepStats")
    if win then win.Visible = S.statsWindow end
end)

headerButton(-58, "—", function()
    main.Visible = not main.Visible
    if main.Visible then
        mainScale.Scale = 0.94
        tw(mainScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
    end
end)

headerButton(-32, "×", function()
    if getgenv().SleepScript then getgenv().SleepScript.Unload() end
end)

-- перетаскивание
local function makeDraggable(frame, handle)
    local dragging, dragStart, startPos
    track(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end))
    track(UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    track(UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

makeDraggable(main, header)
track(main:GetPropertyChangedSignal("Position"):Connect(function()
    glow.Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset - 8,
        main.Position.Y.Scale, main.Position.Y.Offset - 8)
end))

local sidebar = new("Frame", {
    Size = UDim2.new(0, 116, 1, -54),
    Position = UDim2.fromOffset(0, 54),
    BackgroundColor3 = Color3.fromRGB(11, 11, 15),
    BorderSizePixel = 0,
}, main)
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, sidebar)

local content = new("Frame", {
    Size = UDim2.new(1, -116, 1, -78),
    Position = UDim2.fromOffset(116, 54),
    BackgroundTransparency = 1,
}, main)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }, content)

local footer = new("Frame", {
    Size = UDim2.new(1, -116, 0, 24),
    Position = UDim2.new(0, 116, 1, -24),
    BackgroundColor3 = Color3.fromRGB(11, 11, 15),
    BorderSizePixel = 0,
}, main)
new("TextLabel", {
    Text = "RightShift — меню",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(96, 96, 112),
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 4),
    Size = UDim2.new(1, -24, 0, 16),
    TextXAlignment = Enum.TextXAlignment.Left,
}, footer)

local pages, tabs, tabBars = {}, {}, {}
local function page(name)
    local f = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = CONFIG.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, content)
    new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, f)
    pages[name] = f
    return f
end

local function tabButton(label, key)
    local b = new("TextButton", {
        Text = label,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(140, 140, 158),
        BackgroundColor3 = Color3.fromRGB(18, 18, 24),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 30),
    }, sidebar)
    new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)

    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 0, 0),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = CONFIG.Accent,
        BorderSizePixel = 0,
    }, b)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)

    tabs[key] = b
    tabBars[key] = bar

    b.MouseEnter:Connect(function()
        if not pages[key].Visible then tw(b, 0.14, { BackgroundColor3 = Color3.fromRGB(26, 26, 36) }) end
    end)
    b.MouseLeave:Connect(function()
        if not pages[key].Visible then tw(b, 0.14, { BackgroundColor3 = Color3.fromRGB(18, 18, 24) }) end
    end)
    b.MouseButton1Click:Connect(function()
        for k, p in pairs(pages) do p.Visible = (k == key) end
        for k, t in pairs(tabs) do
            tw(t, 0.16, {
                TextColor3 = (k == key) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 158),
                BackgroundColor3 = (k == key) and Color3.fromRGB(34, 27, 66) or Color3.fromRGB(18, 18, 24),
            })
            local bar = tabBars[k]
            if k == key then
                tw(bar, 0.18, { Size = UDim2.new(0, 3, 0, 16), Position = UDim2.new(0, 0, 0.5, -8) })
            else
                tw(bar, 0.18, { Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, 0, 0.5, 0) })
            end
        end
        local pg = pages[key]
        if pg then
            pg.Position = UDim2.fromOffset(10, 0)
            tw(pg, 0.2, { Position = UDim2.fromOffset(0, 0) })
        end
    end)
    return b
end

local function section(parent, text)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Color3.fromRGB(28, 28, 38),
        BorderSizePixel = 0,
    }, parent)
    return new("TextLabel", {
        Text = string.upper(text),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = CONFIG.Accent,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

local function row(parent)
    return new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, parent)
end

local function toggle(parent, text, default, cb)
    local r = row(parent)
    new("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = Color3.fromRGB(210, 210, 224), BackgroundTransparency = 1,
        Size = UDim2.new(1, -44, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
    }, r)
    local pill = new("Frame", {
        Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -34, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(36, 36, 46), BorderSizePixel = 0,
    }, r)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(215, 215, 228), BorderSizePixel = 0,
    }, pill)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

    local state = default
    local function render(instant)
        local info = TweenInfo.new(instant and 0 or 0.16, Enum.EasingStyle.Quad)
        TweenService:Create(knob, info, {
            Position = state and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2),
        }):Play()
        TweenService:Create(pill, info, {
            BackgroundColor3 = state and CONFIG.Accent or Color3.fromRGB(36, 36, 46),
        }):Play()
    end
    render(true)

    local function set(v)
        if state == v then return end
        state = v
        render()
        cb(v)
    end
    pill.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            set(not state)
        end
    end)
    return { set = set, get = function() return state end }
end

local function slider(parent, text, min, max, default, cb)
    local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, parent)
    new("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = Color3.fromRGB(210, 210, 224), BackgroundTransparency = 1,
        Size = UDim2.new(1, -60, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
    }, holder)
    local valueLabel = new("TextLabel", {
        Text = tostring(default), Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = CONFIG.Accent, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(56, 18), Position = UDim2.new(1, -56, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
    }, holder)
    local trackF = new("Frame", {
        Size = UDim2.new(1, 0, 0, 5), Position = UDim2.fromOffset(0, 26),
        BackgroundColor3 = Color3.fromRGB(32, 32, 42), BorderSizePixel = 0,
    }, holder)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, trackF)
    local fill = new("Frame", {
        Size = UDim2.fromScale((default - min) / (max - min), 1),
        BackgroundColor3 = CONFIG.Accent, BorderSizePixel = 0,
    }, trackF)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

    local value = default
    local function apply(px)
        local rel = math.clamp((px - trackF.AbsolutePosition.X) / trackF.AbsoluteSize.X, 0, 1)
        value = math.floor(min + rel * (max - min) + 0.5)
        fill.Size = UDim2.fromScale(rel, 1)
        valueLabel.Text = tostring(value)
        cb(value)
    end
    trackF.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            apply(i.Position.X)
            local conn
            conn = UIS.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
                    apply(m.Position.X)
                end
            end)
            UIS.InputEnded:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseButton1 or e.UserInputType == Enum.UserInputType.Touch then
                    if conn then conn:Disconnect() end
                end
            end)
        end
    end)
    return { set = function(v) value = v end, get = function() return value end }
end

local function button(parent, text, cb)
    local b = new("TextButton", {
        Text = text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = Color3.fromRGB(232, 232, 244),
        BackgroundColor3 = Color3.fromRGB(22, 22, 30), BorderSizePixel = 0,
        AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30),
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
    b.MouseEnter:Connect(function() tw(b, 0.14, { BackgroundColor3 = CONFIG.AccentDim }) end)
    b.MouseLeave:Connect(function() tw(b, 0.14, { BackgroundColor3 = Color3.fromRGB(22, 22, 30) }) end)
    b.MouseButton1Click:Connect(cb)
    return b
end

local function chips(parent, items, current, cb, perRow)
    local cols = perRow or 4
    local grid = new("Frame", {
        Size = UDim2.new(1, 0, 0, math.ceil(#items / cols) * 26),
        BackgroundTransparency = 1,
    }, parent)
    new("UIGridLayout", {
        CellSize = UDim2.new(1 / cols, -3, 0, 22),
        CellPadding = UDim2.new(0, 3, 0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)
    local made = {}
    local function paint(animate)
        for value, b in pairs(made) do
            local target = (value == current) and CONFIG.AccentDim or Color3.fromRGB(24, 24, 32)
            if animate then tw(b, 0.15, { BackgroundColor3 = target }) else b.BackgroundColor3 = target end
        end
    end
    for i, item in ipairs(items) do
        local b = new("TextButton", {
            Text = item.name,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = item.color or Color3.fromRGB(205, 205, 220),
            BackgroundColor3 = Color3.fromRGB(24, 24, 32),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = i,
        }, grid)
        new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
        made[item.value] = b
        b.MouseEnter:Connect(function()
            if item.value ~= current then tw(b, 0.12, { BackgroundColor3 = Color3.fromRGB(34, 34, 46) }) end
        end)
        b.MouseLeave:Connect(function()
            if item.value ~= current then tw(b, 0.12, { BackgroundColor3 = Color3.fromRGB(24, 24, 32) }) end
        end)
        b.MouseButton1Click:Connect(function()
            current = item.value
            paint(true)
            cb(item.value)
        end)
    end
    paint(false)
    return grid
end

--==============================================================
--  ESP
--==============================================================
local ESP = { objects = {} }
local FONT = (Drawing and Drawing.Fonts and Drawing.Fonts.UI) or 2

local function sq(filled)
    local o = Drawing.new("Square")
    o.Filled = filled
    o.Visible = false
    o.Thickness = 1
    return o
end

local function newRec()
    local rec = { all = {}, bones = {}, corners = {}, cross = {} }
    local function add(o) rec.all[#rec.all + 1] = o return o end

    rec.box = add(sq(false))
    rec.fill = add(sq(true))
    rec.hpBg = add(sq(true))
    rec.hp = add(sq(true))
    rec.name = add(Drawing.new("Text"))
    rec.dist = add(Drawing.new("Text"))
    rec.hpText = add(Drawing.new("Text"))
    rec.tracer = add(Drawing.new("Line"))
    rec.off = add(Drawing.new("Circle"))

    for _, t in ipairs({ rec.name, rec.dist, rec.hpText }) do
        t.Center = true
        t.Outline = true
        t.Font = FONT
        t.OutlineColor = Color3.fromRGB(0, 0, 0)
    end
    rec.tracer.Thickness = 1
    rec.fill.Transparency = 0.85
    rec.off.Thickness = 2
    rec.off.Filled = false
    for i = 1, 8 do rec.corners[i] = add(sq(false)) end
    for i = 1, 4 do rec.cross[i] = add(sq(false)) end
    for i = 1, 15 do
        local l = add(Drawing.new("Line"))
        l.Thickness = 1
        rec.bones[i] = l
    end
    return rec
end

local function hide(rec)
    rec.box.Filled = false
    for _, o in ipairs(rec.all) do
        pcall(function() o.Visible = false end)
    end
end

local BONES = {
    [Enum.HumanoidRigType.R15] = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
    },
    [Enum.HumanoidRigType.R6] = {
        { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
        { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
    },
}

local function bindPlayer(player)
    if ESP.objects[player] then return end
    local entry = { rec = newRec(), char = nil }
    ESP.objects[player] = entry

    local function onChar(char)
        entry.char = char
    end
    if player.Character then onChar(player.Character) end
    track(player.CharacterAdded:Connect(onChar))
    track(player.CharacterRemoving:Connect(function()
        entry.char = nil
        hide(entry.rec)
    end))
end

local function unbindPlayer(player)
    local entry = ESP.objects[player]
    if not entry then return end
    for _, o in ipairs(entry.rec.all) do pcall(function() o:Remove() end) end
    ESP.objects[player] = nil
end

for _, p in ipairs(Players:GetPlayers()) do bindPlayer(p) end
track(Players.PlayerAdded:Connect(bindPlayer))
track(Players.PlayerRemoving:Connect(unbindPlayer))

local rayParams = RaycastParams.new()
rayParams.IgnoreWater = true

local visState, visClock = {}, {}
local lastInterval, fpsSmooth = 1 / 60, 60

local function colorFor(player, visible, frac, dist)
    if not visible then return S.colorHidden end
    local mode = S.colorMode
    if mode == "team" then
        if player.Team then return player.TeamColor.Color end
        return S.colorStatic
    elseif mode == "health" then
        return Color3.fromRGB(230, 70, 70):Lerp(Color3.fromRGB(90, 220, 120), frac)
    elseif mode == "distance" then
        return Color3.fromRGB(90, 220, 120):Lerp(Color3.fromRGB(230, 70, 70), math.clamp(dist / S.maxDist, 0, 1))
    end
    return S.colorStatic
end

local function put(s, x, y, w, h, col)
    s.Color = col
    s.Thickness = S.thickness
    s.Position = Vector2.new(x, y)
    s.Size = Vector2.new(w, h)
    s.Visible = true
end

local function drawBox(rec, x, y, w, h, col)
    local t = S.thickness
    rec.box.Filled = false
    if S.style == "full" then
        put(rec.box, x, y, w, h, col)
        return
    end
    if S.style == "corner" then
        local c = math.clamp(S.cornerSize, 3, math.min(w / 2, h / 2))
        put(rec.corners[1], x, y, c, t, col)
        put(rec.corners[2], x, y, t, c, col)
        put(rec.corners[3], x + w - c, y, c, t, col)
        put(rec.corners[4], x + w - t, y, t, c, col)
        put(rec.corners[5], x, y + h - t, c, t, col)
        put(rec.corners[6], x, y + h - c, t, c, col)
        put(rec.corners[7], x + w - c, y + h - t, c, t, col)
        put(rec.corners[8], x + w - t, y + h - c, t, c, col)
        return
    end
    local cx, cy = x + w / 2, y + h / 2
    local c = math.clamp(S.cornerSize, 4, 20)
    if S.style == "cross" then
        put(rec.cross[1], cx - c / 2, cy - t / 2, c, t, col)
        put(rec.cross[2], cx - t / 2, cy - c / 2, t, c, col)
        put(rec.cross[3], cx - c / 2, cy - t / 2, c, t, col)
        put(rec.cross[4], cx - t / 2, cy - c / 2, t, c, col)
        return
    end
    rec.box.Filled = true
    put(rec.box, cx - 3, cy - 3, 6, 6, col)
    rec.box.Filled = false
end

local function frameUpdate(dt)
    if not S.espEnabled or not hasDrawing then return end
    local cam = camera or Workspace.CurrentCamera
    if not cam then return end

    fpsSmooth = fpsSmooth * 0.9 + (1 / math.max(dt, 0.001)) * 0.1
    local base = 1 / 60
    if S.adaptive and fpsSmooth < 45 then base = 1 / 30 end
    lastInterval = base * (0.92 + math.random() * 0.16)

    local now = os.clock()
    local camPos = cam.CFrame.Position
    local vp = cam.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local myChar = lp.Character

    for player, entry in pairs(ESP.objects) do
        local rec = entry.rec
        local char = entry.char

        if not char or not char.Parent or (player == lp and not S.showLocal) then
            hide(rec)
            continue
        end

        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")

        if not head or not hum or not root or hum.Health <= 0 then
            hide(rec)
            continue
        end

        local headPos = head.Position
        local dist = (camPos - headPos).Magnitude

        if dist > S.maxDist then
            hide(rec)
            continue
        end

        if S.teamCheck and player ~= lp and player.Team and lp.Team and player.Team == lp.Team then
            hide(rec)
            continue
        end

        local sTop, onTop = cam:WorldToViewportPoint(headPos + Vector3.new(0, 0.9, 0))
        local sBot, onBot = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 2.4, 0))
        local onScreen = onTop and onBot and sTop.Z > 0 and sBot.Z > 0 and sBot.Y > sTop.Y

        if not onScreen then
            hide(rec)
            if S.offscreen and sTop.Z > 0 then
                local ox = math.clamp(sTop.X, 30, vp.X - 30)
                local oy = math.clamp(sTop.Y, 30, vp.Y - 30)
                rec.off.Position = Vector2.new(ox, oy)
                rec.off.Radius = 7
                rec.off.Color = S.colorStatic
                rec.off.Visible = true
            end
            continue
        end

        local h = sBot.Y - sTop.Y
        local w = h * 0.45
        local x = sTop.X - w / 2
        local y = sTop.Y

        if not visClock[player] or now - visClock[player] > 0.15 then
            visClock[player] = now
            rayParams.FilterDescendantsInstances = { char, myChar }
            local hit = Workspace:Raycast(camPos, headPos - camPos, rayParams)
            visState[player] = (hit == nil or hit.Instance:IsDescendantOf(char))
        end

        local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        local col = colorFor(player, visState[player] ~= false, frac, dist)

        drawBox(rec, x, y, w, h, col)

        if S.fill and S.style == "full" then
            rec.fill.Color = col
            rec.fill.Transparency = S.fillAlpha
            rec.fill.Position = Vector2.new(x, y)
            rec.fill.Size = Vector2.new(w, h)
            rec.fill.Visible = true
        else
            rec.fill.Visible = false
        end

        if S.hpMode == "bar" then
            local hx = (S.hpSide == "left") and (x - 6) or (x + w + 3)
            rec.hpBg.Position = Vector2.new(hx, y)
            rec.hpBg.Size = Vector2.new(3, h)
            rec.hpBg.Color = Color3.fromRGB(22, 22, 28)
            rec.hpBg.Visible = true
            rec.hp.Position = Vector2.new(hx, y + h * (1 - frac))
            rec.hp.Size = Vector2.new(3, h * frac)
            rec.hp.Color = Color3.fromRGB(90, 220, 120):Lerp(Color3.fromRGB(230, 70, 70), 1 - frac)
            rec.hp.Visible = true
            rec.hpText.Visible = false
        elseif S.hpMode == "text" then
            rec.hpBg.Visible = false
            rec.hp.Visible = false
            rec.hpText.Text = tostring(math.floor(hum.Health))
            rec.hpText.Size = S.textSize
            rec.hpText.Color = Color3.fromRGB(90, 220, 120):Lerp(Color3.fromRGB(230, 70, 70), 1 - frac)
            rec.hpText.Position = Vector2.new(x + w / 2, y + h + 3)
            rec.hpText.Visible = true
        else
            rec.hpBg.Visible = false
            rec.hp.Visible = false
            rec.hpText.Visible = false
        end

        local label
        if S.nameMode == "name" then
            label = player.Name
        elseif S.nameMode == "display" then
            label = player.DisplayName
        elseif S.nameMode == "both" then
            label = player.DisplayName .. " (" .. player.Name .. ")"
        end
        if label then
            rec.name.Text = label
            rec.name.Size = S.textSize
            rec.name.Color = col
            rec.name.Position = Vector2.new(x + w / 2, y - S.textSize - 3)
            rec.name.Visible = true
        else
            rec.name.Visible = false
        end

        if S.showDist then
            if S.distUnit == "m" then
                rec.dist.Text = string.format("%d m", math.floor(dist / 3.5))
            else
                rec.dist.Text = string.format("%d st", math.floor(dist))
            end
            rec.dist.Size = S.textSize - 1
            rec.dist.Color = col
            rec.dist.Position = Vector2.new(x + w / 2, y + h + (S.hpMode == "text" and 17 or 3))
            rec.dist.Visible = true
        else
            rec.dist.Visible = false
        end

        if S.tracer then
            rec.tracer.From = Vector2.new(cx, vp.Y)
            rec.tracer.To = Vector2.new(x + w / 2, y + h)
            rec.tracer.Color = S.colorTracer
            rec.tracer.Thickness = S.thickness
            rec.tracer.Visible = true
        else
            rec.tracer.Visible = false
        end

        if S.skeleton then
            local list = BONES[hum.RigType]
            if list then
                for i, pairParts in ipairs(list) do
                    local a = char:FindFirstChild(pairParts[1])
                    local b = char:FindFirstChild(pairParts[2])
                    local line = rec.bones[i]
                    if a and b and line then
                        local pa = cam:WorldToViewportPoint(a.Position)
                        local pb = cam:WorldToViewportPoint(b.Position)
                        line.From = Vector2.new(pa.X, pa.Y)
                        line.To = Vector2.new(pb.X, pb.Y)
                        line.Color = col
                        line.Thickness = S.thickness
                        line.Visible = true
                    elseif line then
                        line.Visible = false
                    end
                end
            end
        else
            for _, l in ipairs(rec.bones) do l.Visible = false end
        end
    end
end

local espAccum = 0
track(RunService.RenderStepped:Connect(function(dt)
    espAccum += dt
    if espAccum < lastInterval then return end
    espAccum = 0
    pcall(frameUpdate, dt)
end))

--==============================================================
--  БХОП  (не изменялся)
--==============================================================
local lastJump = 0
local airJumps = 0

local function holdingJump()
    return UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.ButtonA)
end

local function doJump(auto)
    if not S.bhop then return end
    local now = os.clock()
    if now - lastJump < 0.04 then return end
    if auto and now - lastJump < 0.12 then return end

    local hum = curHum
    if not hum or hum.Health <= 0 then return end
    local root = hum.RootPart
    if not root or root.Anchored then return end

    if isAirborne(hum) then
        if S.jumpLimit >= 0 and airJumps >= S.jumpLimit then return end
        airJumps += 1
    else
        airJumps = 0
    end
    lastJump = now

    if S.bhopAggro then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        local jp = hum.JumpPower
        if not hum.UseJumpPower then
            jp = math.sqrt(2 * Workspace.Gravity * hum.JumpHeight)
        end
        if jp and jp > 0 then
            local v = root.AssemblyLinearVelocity
            if v.Y < jp * 0.95 then
                root.AssemblyLinearVelocity = Vector3.new(v.X, jp, v.Z)
            end
        end
    else
        pcall(function() hum.Jump = true end)
    end
end

track(UIS.JumpRequest:Connect(function() pcall(doJump, false) end))

track(RunService.Stepped:Connect(function()
    local hum = curHum
    if not hum or hum.Health <= 0 then return end
    if S.bhop and not isAirborne(hum) then
        airJumps = 0
        if holdingJump() then pcall(doJump, true) end
    end
end))

track(lp.CharacterAdded:Connect(function()
    airJumps = 0
end))

--==============================================================
--  NO AIR SPREAD
--==============================================================
local origIndex, origNamecall = nil, nil
local hookedIndex, hookedNamecall = false, false

if typeof(hookmetamethod) == "function" then
    local ok = pcall(function()
        origIndex = hookmetamethod(game, "__index", function(self, key)
            if key == "FloorMaterial" and S.noAirSpread and not selfRead then
                if rawequal(self, curHum) then
                    local real = origIndex(self, key)
                    if real == Enum.Material.Air then
                        return Enum.Material.Plastic
                    end
                    return real
                end
            end
            return origIndex(self, key)
        end)
    end)
    hookedIndex = ok
end

if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
    local ok = pcall(function()
        origNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "GetState" and S.noAirSpread and not selfRead then
                if rawequal(self, curHum) then
                    local st = origNamecall(self, ...)
                    if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping then
                        return Enum.HumanoidStateType.Running
                    end
                    return st
                end
            end
            return origNamecall(self, ...)
        end)
    end)
    hookedNamecall = ok
end

local function restoreSpreadState()
    local hum = curHum
    if hum then
        pcall(function() hum.FloorMaterial = Enum.Material.Air end)
    end
end

local function setAirSpread(on)
    S.noAirSpread = on
    if on then
        refreshHum()
        if not (hookedIndex or hookedNamecall) then
            notify("Хуки недоступны — только запись свойства")
        end
    else
        restoreSpreadState()
    end
end

local spreadClock = 0
track(RunService.RenderStepped:Connect(function(dt)
    if not S.noAirSpread then return end
    spreadClock += dt
    if spreadClock < 0.05 then return end
    spreadClock = 0

    local hum = curHum
    if not hum or hum.Parent == nil then
        refreshHum()
        hum = curHum
    end
    if not hum or hum.Health <= 0 then return end

    local st = realState(hum)
    if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping then
        if realFloor(hum) == Enum.Material.Air then
            pcall(function() hum.FloorMaterial = Enum.Material.Plastic end)
        end
    end
end))

--==============================================================
--  FPS BOOST
--==============================================================
local boost = { on = false, saved = nil }

local function collectFx()
    local out = {}
    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
                or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                if d.Enabled then
                    d.Enabled = false
                    out[#out + 1] = d
                end
            end
        end
        for _, d in ipairs(Lighting:GetChildren()) do
            if d:IsA("PostEffect") and d.Enabled then
                d.Enabled = false
                out[#out + 1] = d
            end
        end
    end)
    return out
end

local function setBoost(on)
    if boost.on == on then return end
    if on then
        boost.saved = {
            quality  = (typeof(settings) == "function") and settings().Rendering.QualityLevel or nil,
            shadows  = Lighting.GlobalShadows,
            fogEnd   = Lighting.FogEnd,
            fogStart = Lighting.FogStart,
            terrain  = Workspace.Terrain and Workspace.Terrain.Decoration or nil,
            fx       = collectFx(),
        }
        if boost.saved.quality then pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end) end
        pcall(function() Lighting.GlobalShadows = false end)
        pcall(function() Lighting.FogStart = 0; Lighting.FogEnd = 1e6 end)
        if Workspace.Terrain then pcall(function() Workspace.Terrain.Decoration = false end) end
        boost.on = true
        S.fpsBoost = true
        notify("FPS Boost включён")
    else
        local s = boost.saved
        boost.saved = nil
        boost.on = false
        S.fpsBoost = false
        if s then
            if s.quality then pcall(function() settings().Rendering.QualityLevel = s.quality end) end
            pcall(function() Lighting.GlobalShadows = s.shadows end)
            pcall(function() Lighting.FogStart = s.fogStart; Lighting.FogEnd = s.fogEnd end)
            if s.terrain ~= nil then pcall(function() Workspace.Terrain.Decoration = s.terrain end) end
            for _, d in ipairs(s.fx) do pcall(function() if d.Parent then d.Enabled = true end end) end
        end
        notify("FPS Boost выключен")
    end
end

--==============================================================
--  ОКНО СТАТИСТИКИ
--==============================================================
local startClock = os.clock()
local statWin = new("Frame", {
    Name = "SleepStats",
    Size = UDim2.fromOffset(196, 168),
    Position = UDim2.new(0.5, 300, 0.5, -180),
    BackgroundColor3 = Color3.fromRGB(10, 10, 14),
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 20,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, statWin)
new("UIStroke", { Color = CONFIG.Accent, Transparency = 0.55, Thickness = 1 }, statWin)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, statWin)

local statHead = new("Frame", {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    ZIndex = 21,
}, statWin)
new("TextLabel", {
    Text = "СТАТИСТИКА",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextColor3 = CONFIG.Accent,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -20, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
}, statHead)
local closeStat = new("TextButton", {
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = Color3.fromRGB(150, 150, 168),
    BackgroundTransparency = 1,
    Size = UDim2.fromOffset(18, 18),
    Position = UDim2.new(1, -18, 0, 0),
    AutoButtonColor = false,
}, statHead)
closeStat.MouseButton1Click:Connect(function()
    S.statsWindow = false
    statWin.Visible = false
end)
makeDraggable(statWin, statHead)

local function statRow(label)
    local r = new("Frame", { Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1 }, statWin)
    new("TextLabel", {
        Text = label, Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = Color3.fromRGB(130, 130, 148), BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
    }, r)
    return new("TextLabel", {
        Text = "—", Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = Color3.fromRGB(235, 235, 245), BackgroundTransparency = 1,
        Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.new(0.6, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
    }, r)
end

local fpsLabel  = statRow("FPS")
local pingLabel = statRow("PING")
local plrLabel  = statRow("ИГРОКИ")
local memLabel  = statRow("ПАМЯТЬ")
local upLabel   = statRow("АПТАЙМ")

new("Frame", {
    Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0,
}, statWin)

local boostToggle = toggle(statWin, "FPS Boost", false, function(v) setBoost(v) end)

local frames, pingMs = 0, 0

local function statTick(dt)
    frames += 1
    if frames >= 1 then end
end

local statAccum, fpsAccum, pingAccum = 0, 0, 0
track(RunService.RenderStepped:Connect(function(dt)
    fpsAccum += dt
    if fpsAccum >= 0.5 then
        local fps = math.floor(1 / math.max(fpsAccum, 0.001))
        fpsAccum = 0
        if S.statsWindow then
            fpsLabel.Text = tostring(fps)
            fpsLabel.TextColor3 = (fps >= 50) and Color3.fromRGB(120, 225, 140)
                or (fps >= 30) and Color3.fromRGB(240, 200, 90)
                or Color3.fromRGB(235, 90, 90)
        end
    end

    if not S.statsWindow then return end
    statAccum += dt
    if statAccum < 0.5 then return end
    statAccum = 0

    local ping
    pcall(function()
        ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if not ping then
        pcall(function() ping = lp:GetNetworkPing() * 1000 end)
    end
    if ping then
        pingLabel.Text = string.format("%d ms", math.floor(ping))
        pingLabel.TextColor3 = (ping < 80) and Color3.fromRGB(120, 225, 140)
            or (ping < 160) and Color3.fromRGB(240, 200, 90)
            or Color3.fromRGB(235, 90, 90)
    end

    plrLabel.Text = string.format("%d/%d", #Players:GetPlayers(), Players.MaxPlayers)

    pcall(function()
        memLabel.Text = string.format("%d MB", math.floor(Stats:GetTotalMemoryUsageMb()))
    end)

    local up = math.floor(os.clock() - startClock)
    upLabel.Text = string.format("%02d:%02d:%02d", math.floor(up / 3600), math.floor(up % 3600 / 60), up % 60)
end))

--==============================================================
--  АВТОБАННИХОП
--==============================================================
local BAN_HARD = {
    "you have been banned", "you've been banned", "banned by rac",
    "kicked by rac", "exploit detected", "cheat detected",
    "anti-cheat", "anticheat", "suspicious activity",
    "remove your exploits", "detected exploiting",
}

local BAN_IGNORE = {
    "accuracy", "tracer", "trace", "rack", "character", "practice",
    "spectate", "spectator", "grenade",
}

local banCooldown, banSeen = 0, {}
local softHits, softUntil = 0, 0
local loadTime = os.clock()
local hopping = false

local function getRandomServer()
    local ok, body = pcall(function()
        return game:HttpGet(
            string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortName=Random&limit=100", game.GameId)
        )
    end)
    if not ok or not body then return nil end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok2 or not data or not data.data or #data.data == 0 then return nil end
    local pool = {}
    for _, srv in ipairs(data.data) do
        if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
            table.insert(pool, srv.id)
        end
    end
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

local function rejoin()
    if hopping then return end
    hopping = true
    if CONFIG.ScriptURL ~= "" and queue_on_teleport then
        pcall(queue_on_teleport, string.format("loadstring(game:HttpGet('%s'))()", CONFIG.ScriptURL))
    end
    local jobId = getRandomServer()
    if jobId then
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        local ok = pcall(function()
            TeleportService:TeleportAsync(game.PlaceId, { lp }, opts)
        end)
        if ok then return end
    end
    pcall(function() TeleportService:Teleport(game.PlaceId, lp) end)
    task.delay(8, function() hopping = false end)
end

local function onBan(reason, hard, force)
    local now = os.clock()
    if not force and (now - loadTime) < CONFIG.DetectGrace then return end
    if now < banCooldown then return end

    if not hard and not force then
        if now > softUntil then softHits = 0 end
        softHits += 1
        softUntil = now + 2
        if softHits < 2 then return end
        softHits = 0
    end

    banCooldown = now + 6
    S.banCount += 1
    S.lastReason = reason
    logFile(string.format("DETECT #%d: %s", S.banCount, reason))
    notify("RAC: " .. reason .. (CONFIG.LogOnly and " (лог)" or ""))

    if S.autoRejoin and not CONFIG.LogOnly then
        task.delay(S.rejoinDelay, rejoin)
    end
end

local function matchText(text)
    local lower = string.lower(text)
    if #lower > 90 then return nil end
    for _, ign in ipairs(BAN_IGNORE) do
        if lower == ign then return nil end
    end
    for _, pat in ipairs(BAN_HARD) do
        if string.find(lower, pat, 1, true) then return pat, true end
    end
    if #lower <= 45 and string.find(lower, "%f[%a]rac%f[%A]") then
        if lower == "rac"
            or string.find(lower, "ban", 1, true)
            or string.find(lower, "kick", 1, true)
            or string.find(lower, "detect", 1, true)
            or string.find(lower, "cheat", 1, true) then
            return "rac", false
        end
    end
    return nil
end

local function scanGui(root)
    if not root then return end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") and d.Visible and #d.Text > 4 then
            local key = string.lower(d.Text)
            if not banSeen[key] then
                local pat, hard = matchText(d.Text)
                if pat then
                    banSeen[key] = true
                    onBan(pat, hard, false)
                end
            end
        end
    end
end

task.spawn(function()
    local ev = ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents", 8)
    if ev and ev:FindFirstChild("OnMessageDoneFiltering") then
        track(ev.OnMessageDoneFiltering.OnClientEvent:Connect(function(msg)
            if not S.watchEnabled or type(msg) ~= "table" then return end
            local txt = tostring(msg.Message or "")
            local pat, hard = matchText(txt)
            if not pat then return end
            onBan(pat, hard, false)
        end))
    end
end)

task.spawn(function()
    while task.wait(0.8) do
        if not S.watchEnabled then continue end
        if #banSeen > 200 then banSeen = {} end
        pcall(scanGui, lp:FindFirstChild("PlayerGui"))
        pcall(scanGui, gethui())
    end
end)

track(lp.AncestryChanged:Connect(function(_, parent)
    if not parent and S.watchEnabled then onBan("localplayer removed", true, true) end
end))

--==============================================================
--  СТРАНИЦЫ
--==============================================================
local visualPage = page("visual"); tabButton("Визуал", "visual")
local movePage   = page("move");   tabButton("Движение", "move")
local watchPage  = page("watch");  tabButton("Автобан", "watch")
local miscPage   = page("misc");   tabButton("Прочее", "misc")

section(visualPage, "основа")
toggle(visualPage, "Включить ESP", false, function(v)
    S.espEnabled = v
    if v and not hasDrawing then notify("Нет Drawing API — ESP не запустится") end
end)
toggle(visualPage, "Игнорировать союзников", true, function(v) S.teamCheck = v end)
toggle(visualPage, "Показывать себя", false, function(v) S.showLocal = v end)
slider(visualPage, "Макс. дистанция (студы)", 100, 2000, 600, function(v) S.maxDist = v end)

section(visualPage, "форма")
chips(visualPage, {
    { name = "Бокс", value = "full" },
    { name = "Уголки", value = "corner" },
    { name = "Крест", value = "cross" },
    { name = "Точка", value = "dot" },
}, S.style, function(v) S.style = v end)
slider(visualPage, "Толщина линий", 1, 4, 1, function(v) S.thickness = v end)
slider(visualPage, "Размер уголков", 4, 24, 9, function(v) S.cornerSize = v end)
toggle(visualPage, "Заливка бокса", false, function(v) S.fill = v end)
slider(visualPage, "Прозрачность заливки", 20, 95, 85, function(v) S.fillAlpha = v / 100 end)

section(visualPage, "текст")
slider(visualPage, "Размер текста", 9, 22, 13, function(v) S.textSize = v end)
chips(visualPage, {
    { name = "Ник", value = "name" },
    { name = "Display", value = "display" },
    { name = "Оба", value = "both" },
    { name = "Нет", value = "off" },
}, S.nameMode, function(v) S.nameMode = v end)
toggle(visualPage, "Дистанция", true, function(v) S.showDist = v end)
chips(visualPage, {
    { name = "Метры", value = "m" },
    { name = "Студы", value = "studs" },
}, S.distUnit, function(v) S.distUnit = v end)

section(visualPage, "здоровье")
chips(visualPage, {
    { name = "Полоска", value = "bar" },
    { name = "Цифры", value = "text" },
    { name = "Нет", value = "off" },
}, S.hpMode, function(v) S.hpMode = v end)
chips(visualPage, {
    { name = "Слева", value = "left" },
    { name = "Справа", value = "right" },
}, S.hpSide, function(v) S.hpSide = v end)

section(visualPage, "доп")
toggle(visualPage, "Скелет", false, function(v) S.skeleton = v end)
toggle(visualPage, "Трассеры", false, function(v) S.tracer = v end)
toggle(visualPage, "Метки за экраном", false, function(v) S.offscreen = v end)

section(visualPage, "цвет")
chips(visualPage, {
    { name = "Свой", value = "static" },
    { name = "Команда", value = "team" },
    { name = "По HP", value = "health" },
    { name = "Дистанция", value = "distance" },
}, S.colorMode, function(v) S.colorMode = v end)

local PALETTE = {
    { name = "Белый", c = Color3.fromRGB(235, 235, 245) },
    { name = "Фиолет", c = Color3.fromRGB(150, 120, 255) },
    { name = "Циан", c = Color3.fromRGB(80, 225, 255) },
    { name = "Лайм", c = Color3.fromRGB(160, 255, 90) },
    { name = "Красный", c = Color3.fromRGB(255, 80, 80) },
    { name = "Оранж", c = Color3.fromRGB(255, 150, 60) },
    { name = "Розовый", c = Color3.fromRGB(255, 110, 210) },
    { name = "Синий", c = Color3.fromRGB(90, 140, 255) },
}
local palItems = {}
for _, p in ipairs(PALETTE) do table.insert(palItems, { name = p.name, value = p.c, color = p.c }) end

section(visualPage, "свой цвет")
chips(visualPage, palItems, S.colorStatic, function(v) S.colorStatic = v end)
section(visualPage, "цвет невидимых")
chips(visualPage, palItems, S.colorHidden, function(v) S.colorHidden = v end)

section(movePage, "бхоп")
toggle(movePage, "Бхоп (держать пробел)", false, function(v) S.bhop = v; airJumps = 0 end)
toggle(movePage, "Агрессивный бхоп (форс + импульс)", false, function(v) S.bhopAggro = v end)
slider(movePage, "Прыжков в воздухе", -1, 10, 0, function(v) S.jumpLimit = v; airJumps = 0 end)

section(movePage, "разброс")
toggle(movePage, "Убрать разброс в полёте", false, function(v) setAirSpread(v) end)

section(movePage, "камера")
toggle(movePage, "Фиксация FOV", false, function(v)
    if v and camera then fovOriginal = camera.FieldOfView end
    S.fovEnabled = v
    applyFov()
end)
slider(movePage, "FOV", 40, 120, 90, function(v)
    S.fovValue = v
    applyFov()
end)

section(watchPage, "наблюдение")
toggle(watchPage, "Следить за RAC", true, function(v) S.watchEnabled = v end)
toggle(watchPage, "Автопереподключение", true, function(v) S.autoRejoin = v end)
toggle(watchPage, "Только логировать", false, function(v) CONFIG.LogOnly = v end)
slider(watchPage, "Задержка хопа (0.1с)", 1, 30, 15, function(v) S.rejoinDelay = v / 10 end)

local statusLabel = new("TextLabel", {
    Text = "Детектов: 0\nПоследнее: —",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(150, 150, 168),
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 34),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, watchPage)

section(watchPage, "действия")
button(watchPage, "Хопнуть сейчас", function() notify("Хоп…"); rejoin() end)

section(miscPage, "служебное")
button(miscPage, "Выгрузить скрипт", function()
    if getgenv().SleepScript then getgenv().SleepScript.Unload() end
end)

--==============================================================
--  СЛУЖЕБНОЕ
--==============================================================
local statusAccum = 0
track(RunService.Heartbeat:Connect(function(dt)
    statusAccum += dt
    if statusAccum < 0.25 then return end
    statusAccum = 0
    statusLabel.Text = string.format("Детектов: %d\nПоследнее: %s", S.banCount, S.lastReason)
end))

track(UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == CONFIG.Keybind then main.Visible = not main.Visible end
end))

pages.visual.Visible = true
tabs.visual.TextColor3 = Color3.fromRGB(255, 255, 255)
tabs.visual.BackgroundColor3 = Color3.fromRGB(34, 27, 66)
tabBars.visual.Size = UDim2.new(0, 3, 0, 16)
tabBars.visual.Position = UDim2.new(0, 0, 0.5, -8)

--==============================================================
--  ВЫГРУЗКА
--==============================================================
local function unload()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for player in pairs(ESP.objects) do unbindPlayer(player) end
    if hookedIndex and origIndex then pcall(function() hookmetamethod(game, "__index", origIndex) end) end
    if hookedNamecall and origNamecall then pcall(function() hookmetamethod(game, "__namecall", origNamecall) end) end
    restoreSpreadState()
    if boost.on then setBoost(false) end
    if camera then pcall(function() camera.FieldOfView = fovOriginal end) end
    pcall(function() gui:Destroy() end)
    getgenv().SleepScript = nil
end

getgenv().SleepScript = { Unload = unload, Settings = S }
notify("SleepScript загружен. RightShift — меню")
logFile("loaded on " .. game.GameId .. " / " .. game.JobId)

end)

if not booted then
    warn("[SleepScript] ошибка запуска: " .. tostring(bootErr))
end
