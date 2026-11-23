--!nocheck
--[[
    SleepScript • Counter Blox (Rolve)  v3.7
    ---------------------------------------------------------------
    ESP (реальное время), бхоп, no air spread, фиксация FOV,
    окно статистики, FPS boost, автобан, скинченджер ножей.
    v3.3: земля определяется рейкастом — бхоп не улетает в небо.
    v3.4: скинченджер.
    v3.5: скинченджер через lp.SkinFolder (TFolder/CTFolder).
    v3.6: ключи берутся из SkinFolder, нечёткий поиск, дамп структуры.
    v3.7: исправлен порядок функций, страница всегда отрисовывается.
]]

local CONFIG = {
    ScriptURL   = "",
    Accent      = Color3.fromRGB(126, 96, 255),
    AccentDim   = Color3.fromRGB(52, 40, 104),
    Keybind     = Enum.KeyCode.RightShift,
    DetectGrace = 20,
    LogOnly     = false,
    Version     = "3.7",
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
    textSize     = 13,
    nameMode     = "name",
    showDist     = true,
    distUnit     = "m",
    hpMode       = "bar",
    hpSide       = "left",
    skeleton     = false,
    tracer       = false,

    colorMode    = "static",
    colorStatic  = Color3.fromRGB(235, 235, 245),
    colorHidden  = Color3.fromRGB(150, 150, 165),
    colorTracer  = Color3.fromRGB(126, 96, 255),

    teamCheck    = true,
    showLocal    = false,
    maxDist      = 600,

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

-- земля по рейкасту: не зависит ни от хуков, ни от FloorMaterial, ни от состояния
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.FilterDescendantsInstances = {}
groundParams.IgnoreWater = true

local function grounded()
    local hum = curHum
    if not hum or hum.Health <= 0 then return false end
    local root = hum.RootPart
    if not root or root.Anchored then return false end
    groundParams.FilterDescendantsInstances = { lp.Character }
    return Workspace:Raycast(root.Position, Vector3.new(0, -5.5, 0), groundParams) ~= nil
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

local function textbox(parent, placeholder, cb)
    local box = new("TextBox", {
        Text = "",
        PlaceholderText = placeholder,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(230, 230, 242),
        PlaceholderColor3 = Color3.fromRGB(118, 118, 136),
        BackgroundColor3 = Color3.fromRGB(20, 20, 27),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Size = UDim2.new(1, 0, 0, 28),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(0, 8) }, box)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)
    box.FocusLost:Connect(function(enter)
        if enter then cb(box.Text) end
    end)
    return box
end

local function dumpBox(parent, height)
    local box = new("TextBox", {
        Text = "",
        Font = Enum.Font.Code,
        TextSize = 10,
        TextColor3 = Color3.fromRGB(200, 200, 215),
        BackgroundColor3 = Color3.fromRGB(14, 14, 19),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        MultiLine = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Size = UDim2.new(1, 0, 0, height or 150),
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(0, 8) }, box)
    new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6) }, box)
    return box
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
            TextTruncate = Enum.TextTruncate.AtEnd,
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
    local rec = { all = {}, corners = {}, cross = {}, bones = {} }
    local function add(o) rec.all[#rec.all + 1] = o return o end

    rec.box = add(sq(false))
    rec.hpBg = add(sq(true))
    rec.hp = add(sq(true))
    rec.name = add(Drawing.new("Text"))
    rec.dist = add(Drawing.new("Text"))
    rec.hpText = add(Drawing.new("Text"))
    rec.tracer = add(Drawing.new("Line"))

    for _, t in ipairs({ rec.name, rec.dist, rec.hpText }) do
        t.Center = true
        t.Outline = true
        t.Font = FONT
        t.OutlineColor = Color3.fromRGB(0, 0, 0)
    end
    rec.tracer.Thickness = 1
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
    for i = 1, #rec.all do rec.all[i].Visible = false end
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
    local entry = { rec = newRec(), char = nil, bones = nil }
    ESP.objects[player] = entry

    local function onChar(char)
        entry.char = char
        entry.head = nil
        entry.hum = nil
        entry.root = nil
        entry.bones = nil
    end
    if player.Character then onChar(player.Character) end
    track(player.CharacterAdded:Connect(onChar))
    track(player.CharacterRemoving:Connect(function()
        entry.char = nil
        entry.head = nil
        entry.hum = nil
        entry.root = nil
        entry.bones = nil
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

local function resolveParts(entry)
    local char = entry.char
    if not char or not char.Parent then return nil end

    local head, hum, root = entry.head, entry.hum, entry.root
    if not head or head.Parent ~= char then head = char:FindFirstChild("Head") end
    if not hum or hum.Parent ~= char then hum = char:FindFirstChildOfClass("Humanoid") end
    if not root or root.Parent ~= char then root = char:FindFirstChild("HumanoidRootPart") end
    entry.head, entry.hum, entry.root = head, hum, root
    if not (head and hum and root) then return nil end

    if not entry.bones then
        local list = BONES[hum.RigType]
        local out = {}
        if list then
            for i = 1, #list do
                local a = char:FindFirstChild(list[i][1])
                local b = char:FindFirstChild(list[i][2])
                if a and b then out[#out + 1] = { a, b } end
            end
        end
        entry.bones = out
    end

    return head, hum, root
end

local function frameUpdate()
    if not S.espEnabled or not hasDrawing then return end
    local cam = camera or Workspace.CurrentCamera
    if not cam then return end

    local camPos = cam.CFrame.Position
    local vp = cam.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local myChar = lp.Character
    local now = os.clock()

    for player, entry in pairs(ESP.objects) do
        local rec = entry.rec

        if player == lp and not S.showLocal then
            hide(rec)
            continue
        end

        local head, hum, root = resolveParts(entry)

        if not head or not hum or not root or hum.Health <= 0 then
            hide(rec)
            continue
        end

        local headPos = head.Position
        local dist = (camPos - headPos).Magnitude

        if dist > S.maxDist
            or (S.teamCheck and player ~= lp and player.Team and lp.Team and player.Team == lp.Team) then
            hide(rec)
            continue
        end

        local sTop, onTop = cam:WorldToViewportPoint(headPos + Vector3.new(0, 0.9, 0))
        local sBot, onBot = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 2.4, 0))

        if not (onTop and onBot) or sTop.Z <= 0 or sBot.Z <= 0 or sBot.Y <= sTop.Y then
            hide(rec)
            continue
        end

        local h = sBot.Y - sTop.Y
        local w = h * 0.45
        local x = sTop.X - w / 2
        local y = sTop.Y

        if not visClock[player] or now - visClock[player] > 0.12 then
            visClock[player] = now
            rayParams.FilterDescendantsInstances = { entry.char, myChar }
            local hit = Workspace:Raycast(camPos, headPos - camPos, rayParams)
            visState[player] = (hit == nil or hit.Instance:IsDescendantOf(entry.char))
        end

        local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        local col = colorFor(player, visState[player] ~= false, frac, dist)

        drawBox(rec, x, y, w, h, col)

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

        local bones = entry.bones
        if S.skeleton and bones then
            for i = 1, #bones do
                local line = rec.bones[i]
                if line then
                    local pa = cam:WorldToViewportPoint(bones[i][1].Position)
                    local pb = cam:WorldToViewportPoint(bones[i][2].Position)
                    line.From = Vector2.new(pa.X, pa.Y)
                    line.To = Vector2.new(pb.X, pb.Y)
                    line.Color = col
                    line.Thickness = S.thickness
                    line.Visible = true
                end
            end
            for i = #bones + 1, #rec.bones do rec.bones[i].Visible = false end
        else
            for i = 1, #rec.bones do rec.bones[i].Visible = false end
        end
    end
end

track(RunService.RenderStepped:Connect(function()
    pcall(frameUpdate)
end))

--==============================================================
--  БХОП
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

    local air = isAirborne(hum)
    if air then
        if S.jumpLimit >= 0 and airJumps >= S.jumpLimit then return end
        airJumps += 1
    else
        airJumps = 0
    end
    lastJump = now

    if S.bhopAggro or S.noAirSpread then
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
    if not S.bhop then return end
    local hum = curHum
    if not hum or hum.Health <= 0 then return end
    if grounded() then
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
    if spreadClock < 0.04 then return end
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
--  SKINCHANGER (через lp.SkinFolder)
--==============================================================
local SKIN = {
    enabled   = false,
    autoApply = true,
    knife     = nil,
    skin      = nil,
    pool      = {},
    saved     = {},
    dead      = false,
}

local KNIFE_WORDS = {
    "knife", "karambit", "bayonet", "m9", "butterfly", "flip", "gut", "falchion",
    "bowie", "huntsman", "shadow", "navaja", "stiletto", "ursus", "talon",
    "classic", "skeleton", "nomad", "paracord", "survival", "kukri", "daggers",
    "cleaver", "sickle", "axe", "banana",
}

local FALLBACK = {
    "Banana_Stock",
    "Bayonet_Aequalis", "Bayonet_Banner", "Bayonet_Candy Cane", "Bayonet_Consumed",
    "Bayonet_Cosmos", "Bayonet_Crimson Tiger", "Bayonet_Crow", "Bayonet_Delinquent",
    "Bayonet_Digital", "Bayonet_Easy-Bake", "Bayonet_Egg Shell", "Bayonet_Festive",
    "Bayonet_Frozen Dream", "Bayonet_Geo Blade", "Bayonet_Ghastly", "Bayonet_Goo",
    "Bayonet_Hallows", "Bayonet_Intertwine", "Bayonet_Marbleized", "Bayonet_Mariposa",
    "Bayonet_Naval", "Bayonet_Neonic", "Bayonet_RSL", "Bayonet_Racer", "Bayonet_Sapphire",
    "Bayonet_Silent Night", "Bayonet_Splattered", "Bayonet_Stock", "Bayonet_Topaz",
    "Bayonet_Tropical", "Bayonet_Twitch", "Bayonet_UFO", "Bayonet_Wetland",
    "Bayonet_Worn", "Bayonet_Wrapped",
    "Bearded Axe_Beast", "Bearded Axe_Splattered", "Bearded Axe_Stock",
    "Butterfly Knife_Aurora", "Butterfly Knife_Bloodwidow", "Butterfly Knife_Consumed",
    "Butterfly Knife_Cosmos", "Butterfly Knife_Crimson Tiger", "Butterfly Knife_Crippled Fade",
    "Butterfly Knife_Digital", "Butterfly Knife_Egg Shell", "Butterfly Knife_Freedom",
    "Butterfly Knife_Frozen Dream", "Butterfly Knife_Goo", "Butterfly Knife_Hallows",
    "Butterfly Knife_Icicle", "Butterfly Knife_Inversion", "Butterfly Knife_Jade Dream",
    "Butterfly Knife_Marbleized", "Butterfly Knife_Naval", "Butterfly Knife_Neonic",
    "Butterfly Knife_Reaper", "Butterfly Knife_Ruby", "Butterfly Knife_Scapter",
    "Butterfly Knife_Splattered", "Butterfly Knife_Stock", "Butterfly Knife_Topaz",
    "Butterfly Knife_Tropical", "Butterfly Knife_Twitch", "Butterfly Knife_Wetland",
    "Butterfly Knife_White Boss", "Butterfly Knife_Worn", "Butterfly Knife_Wrapped",
    "Cleaver_Spider", "Cleaver_Splattered", "Cleaver_Stock",
    "Falchion Knife_Bloodwidow", "Falchion Knife_Chosen", "Falchion Knife_Coal",
    "Falchion Knife_Consumed", "Falchion Knife_Cosmos", "Falchion Knife_Crimson Tiger",
    "Falchion Knife_Crippled Fade", "Falchion Knife_Digital", "Falchion Knife_Egg Shell",
    "Falchion Knife_Festive", "Falchion Knife_Freedom", "Falchion Knife_Frozen Dream",
    "Falchion Knife_Goo", "Falchion Knife_Hallows", "Falchion Knife_Inversion",
    "Falchion Knife_Late Night", "Falchion Knife_Marbleized", "Falchion Knife_Naval",
    "Falchion Knife_Neonic", "Falchion Knife_Racer", "Falchion Knife_Ruby",
    "Falchion Knife_Splattered", "Falchion Knife_Stock", "Falchion Knife_Topaz",
    "Falchion Knife_Tropical", "Falchion Knife_Wetland", "Falchion Knife_Worn",
    "Falchion Knife_Wrapped", "Falchion Knife_Zombie",
    "Flip Knife_Stock",
    "Gut Knife_Banner", "Gut Knife_Bloodwidow", "Gut Knife_Consumed", "Gut Knife_Cosmos",
    "Gut Knife_Crimson Tiger", "Gut Knife_Crippled Fade", "Gut Knife_Digital",
    "Gut Knife_Egg Shell", "Gut Knife_Frozen Dream", "Gut Knife_Geo Blade", "Gut Knife_Goo",
    "Gut Knife_Hallows", "Gut Knife_Lurker", "Gut Knife_Marbleized", "Gut Knife_Naval",
    "Gut Knife_Neonic", "Gut Knife_Present", "Gut Knife_Ruby", "Gut Knife_Rusty",
    "Gut Knife_Splattered", "Gut Knife_Stock", "Gut Knife_Topaz", "Gut Knife_Tropical",
    "Gut Knife_Wetland", "Gut Knife_Worn", "Gut Knife_Wrapped",
    "Huntsman Knife_Aurora", "Huntsman Knife_Bloodwidow", "Huntsman Knife_Consumed",
    "Huntsman Knife_Cosmos", "Huntsman Knife_Cozy", "Huntsman Knife_Crimson Tiger",
    "Huntsman Knife_Crippled Fade", "Huntsman Knife_Digital", "Huntsman Knife_Egg Shell",
    "Huntsman Knife_Frozen Dream", "Huntsman Knife_Geo Blade", "Huntsman Knife_Goo",
    "Huntsman Knife_Hallows", "Huntsman Knife_Honor Fade", "Huntsman Knife_Marbleized",
    "Huntsman Knife_Monster", "Huntsman Knife_Naval", "Huntsman Knife_Ruby",
    "Huntsman Knife_Splattered", "Huntsman Knife_Stock", "Huntsman Knife_Tropical",
    "Huntsman Knife_Twitch", "Huntsman Knife_Wetland", "Huntsman Knife_Worn",
    "Huntsman Knife_Wrapped",
    "Karambit_Bloodwidow", "Karambit_Consumed", "Karambit_Cosmos", "Karambit_Crimson Tiger",
    "Karambit_Crippled Fade", "Karambit_Death Wish", "Karambit_Digital", "Karambit_Egg Shell",
    "Karambit_Festive", "Karambit_Frozen Dream", "Karambit_Glossed", "Karambit_Gold",
    "Karambit_Goo", "Karambit_Hallows", "Karambit_Jade Dream", "Karambit_Jester",
    "Karambit_Lantern", "Karambit_Liberty Camo", "Karambit_Marbleized", "Karambit_Naval",
    "Karambit_Neonic", "Karambit_Pizza", "Karambit_Quicktime", "Karambit_Racer",
    "Karambit_Ruby", "Karambit_Scapter", "Karambit_Splattered", "Karambit_Stock",
    "Karambit_Topaz", "Karambit_Tropical", "Karambit_Twitch", "Karambit_Wetland",
    "Karambit_Worn",
    "Sickle_Mummy", "Sickle_Splattered", "Sickle_Stock",
}

local function isKnifeName(name)
    local l = string.lower(tostring(name))
    for i = 1, #KNIFE_WORDS do
        if string.find(l, KNIFE_WORDS[i], 1, true) then return true end
    end
    return false
end

-- ВАЖНО: объявлено до всех функций, которые его используют
local function getEquippedKnife()
    local char = lp.Character
    if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and isKnifeName(t.Name) then return t end
    end
    return nil
end

-- все папки внутри SkinFolder (T/CT или любые другие)
local function skinFolders()
    local out = {}
    local sf = lp:FindFirstChild("SkinFolder")
    if not sf then return out, nil end
    for _, c in ipairs(sf:GetChildren()) do
        if c:IsA("Folder") or c:IsA("Model") or c:IsA("Configuration") then
            out[#out + 1] = c
        end
    end
    return out, sf
end

local function splitSkin(line)
    local weapon, skin = string.match(tostring(line), "^(.-)_(.+)$")
    return weapon, skin
end

local function addSkin(weapon, skin)
    if not weapon or not skin or skin == "" then return end
    if not isKnifeName(weapon) then return end
    SKIN.pool[weapon] = SKIN.pool[weapon] or {}
    SKIN.pool[weapon][skin] = true
end

local function buildPool()
    SKIN.pool = {}

    for _, line in ipairs(FALLBACK) do
        addSkin(splitSkin(line))
    end

    pcall(function()
        local pg = lp:FindFirstChild("PlayerGui")
        local cl = pg and pg:FindFirstChild("Client")
        if not cl then return end
        local env = getsenv(cl)
        local inv = env and env.CurrentInventory
        if type(inv) ~= "table" then return end
        for _, entry in ipairs(inv) do
            local n = (type(entry) == "table" and entry[1]) or (type(entry) == "string" and entry)
            if type(n) == "string" then addSkin(splitSkin(n)) end
        end
    end)

    pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("ModuleScript") and string.find(string.lower(d.Name), "skin", 1, true) then
                local ok, src = pcall(function() return d.Source end)
                if ok and type(src) == "string" then
                    for quoted in string.gmatch(src, '"[^"]+"') do
                        addSkin(splitSkin(string.sub(quoted, 2, -2)))
                    end
                end
            end
        end
    end)
end

-- ключи, которые реально существуют в SkinFolder
local function liveKeys()
    local set = {}
    for _, f in ipairs(skinFolders()) do
        for _, c in ipairs(f:GetChildren()) do
            if isKnifeName(c.Name) then set[c.Name] = true end
        end
    end
    local tool = getEquippedKnife()
    if tool then set[tool.Name] = true end
    return set
end

local function mergedSkins()
    local out = {}
    for _, skins in pairs(SKIN.pool) do
        for s in pairs(skins) do out[s] = true end
    end
    return out
end

-- поиск объекта значения: точное имя, регистр, вложенность, нечёткое совпадение
local function findHolder(folder, weapon)
    local exact = folder:FindFirstChild(weapon)
    if exact then return exact end

    local lw = string.lower(weapon)
    local kids = folder:GetChildren()

    for _, c in ipairs(kids) do
        if string.lower(c.Name) == lw then return c end
    end

    for _, c in ipairs(kids) do
        for _, inner in ipairs(c:GetChildren()) do
            if string.lower(inner.Name) == lw then return inner end
        end
    end

    for _, c in ipairs(kids) do
        local ln = string.lower(c.Name)
        if #ln > 2 and (string.find(ln, lw, 1, true) or string.find(lw, ln, 1, true)) then
            return c
        end
    end

    return nil
end

local function holderValue(holder)
    if holder:IsA("StringValue") then return holder end
    for _, c in ipairs(holder:GetChildren()) do
        if c:IsA("StringValue") then return c end
    end
    return nil
end

local reequipping = false

local function reequip()
    if reequipping then return end
    local hum = curHum
    local tool = getEquippedKnife()
    if not hum or not tool then return end
    reequipping = true
    pcall(function() hum:UnequipTools() end)
    task.delay(0.2, function()
        if tool.Parent and hum and hum.Parent then
            pcall(function() hum:EquipTool(tool) end)
        end
        task.delay(0.4, function() reequipping = false end)
    end)
end

-- ключ: сначала нож в руках, потом выбранный в меню
local function resolveKey()
    local tool = getEquippedKnife()
    if tool then
        for _, f in ipairs(skinFolders()) do
            if findHolder(f, tool.Name) then return tool.Name end
        end
    end
    return SKIN.knife
end

local function setSkin(weapon, skin)
    if not weapon or not skin then return false end
    local hit = 0
    for _, f in ipairs(skinFolders()) do
        local holder = findHolder(f, weapon)
        local value = holder and holderValue(holder)
        if value then
            SKIN.saved[weapon] = SKIN.saved[weapon] or {}
            if SKIN.saved[weapon][f.Name] == nil then
                SKIN.saved[weapon][f.Name] = value.Value
            end
            pcall(function() value.Value = skin end)
            hit += 1
        end
    end
    return hit > 0
end

local function restoreWeapon(weapon)
    local saved = SKIN.saved[weapon]
    if not saved then return end
    SKIN.saved[weapon] = nil
    for _, f in ipairs(skinFolders()) do
        local old = saved[f.Name]
        if old then
            local holder = findHolder(f, weapon)
            local value = holder and holderValue(holder)
            if value then pcall(function() value.Value = old end) end
        end
    end
end

local function restoreAll()
    local weapons = {}
    for weapon in pairs(SKIN.saved) do weapons[#weapons + 1] = weapon end
    for _, weapon in ipairs(weapons) do pcall(restoreWeapon, weapon) end
end

local function apply()
    if not SKIN.skin then return false end
    local key = resolveKey()
    if not key then return false end
    if not setSkin(key, SKIN.skin) then return false end
    reequip()
    return true
end

track(lp.CharacterAdded:Connect(function(char)
    track(char.ChildAdded:Connect(function(c)
        if c:IsA("Tool") and isKnifeName(c.Name) and SKIN.enabled and SKIN.autoApply then
            task.delay(0.3, function()
                if not SKIN.skin then return end
                if setSkin(c.Name, SKIN.skin) then reequip() end
            end)
        end
    end))
end))

local function dumpStructure()
    local lines = {}
    local sf = lp:FindFirstChild("SkinFolder")
    if not sf then
        lines[#lines + 1] = "SkinFolder отсутствует"
        for _, c in ipairs(lp:GetChildren()) do
            lines[#lines + 1] = "lp." .. c.Name .. " [" .. c.ClassName .. "]"
        end
        return table.concat(lines, "\n")
    end
    local function walk(inst, depth)
        if #lines > 160 then return end
        for _, c in ipairs(inst:GetChildren()) do
            if #lines > 160 then return end
            local val = ""
            if c:IsA("ValueBase") then
                local ok, v = pcall(function() return c.Value end)
                val = ok and (" = " .. tostring(v)) or ""
            end
            lines[#lines + 1] = string.rep("  ", depth) .. c.Name .. " [" .. c.ClassName .. "]" .. val
            if depth < 2 then walk(c, depth + 1) end
        end
    end
    walk(sf, 0)
    return table.concat(lines, "\n")
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

local statAccum, fpsAccum = 0, 0
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
local skinPage   = page("skin");   tabButton("Скины", "skin")
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

--====================== СКИНЫ ================================
section(skinPage, "скинченджер")
toggle(skinPage, "Включить скинченджер", false, function(v)
    SKIN.enabled = v
    if v then
        if apply() then
            notify("Скин применён: " .. SKIN.skin)
        else
            notify("Выбери нож и скин")
        end
    else
        restoreAll()
    end
end)
toggle(skinPage, "Авто-применение", true, function(v) SKIN.autoApply = v end)

section(skinPage, "нож (из SkinFolder)")
local knifeHolder = new("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
}, skinPage)

section(skinPage, "скин")
local skinHolder = new("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
}, skinPage)

local skinStatus = new("TextLabel", {
    Text = "Загрузка…",
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = Color3.fromRGB(130, 130, 148),
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 16),
    TextXAlignment = Enum.TextXAlignment.Left,
}, skinPage)

local function clearHolder(holder)
    for _, c in ipairs(holder:GetChildren()) do c:Destroy() end
end

local rebuildSkins

local function hint(parent, text, color)
    new("TextLabel", {
        Text = text,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = color or Color3.fromRGB(150, 150, 168),
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

local function rebuildKnives()
    clearHolder(knifeHolder)
    local items = {}
    for name in pairs(liveKeys()) do
        items[#items + 1] = { name = name, value = name }
    end
    table.sort(items, function(a, b) return a.name < b.name end)
    skinStatus.Text = string.format("Ножей в SkinFolder: %d", #items)
    if #items == 0 then
        hint(knifeHolder, "В SkinFolder нет ножей — жми «Дамп структуры»", Color3.fromRGB(240, 200, 90))
        return
    end
    chips(knifeHolder, items, SKIN.knife, function(v)
        SKIN.knife = v
        SKIN.skin = nil
        rebuildSkins()
        if SKIN.enabled and SKIN.skin then apply() end
    end, 2)
end

function rebuildSkins()
    clearHolder(skinHolder)
    if not SKIN.knife then
        hint(skinHolder, "Сначала выбери нож")
        return
    end
    local skins = SKIN.pool[SKIN.knife]
    local loose = false
    if not skins then
        skins = mergedSkins()
        loose = true
    end
    local items = {}
    for skin in pairs(skins) do items[#items + 1] = { name = skin, value = skin } end
    table.sort(items, function(a, b) return a.name < b.name end)
    if loose then
        hint(skinHolder, "Точного списка нет — показан общий набор", Color3.fromRGB(240, 200, 90))
    end
    if #items == 0 then
        hint(skinHolder, "Список скинов пуст — впиши вручную ниже")
        return
    end
    chips(skinHolder, items, SKIN.skin, function(v)
        SKIN.skin = v
        if not SKIN.enabled then
            notify("Включи скинченджер")
            return
        end
        if apply() then
            notify(v)
        else
            notify("Ствол не найден в SkinFolder")
        end
    end, 3)
end

local function refresh()
    local ok, err = pcall(function()
        buildPool()
        rebuildKnives()
        rebuildSkins()
    end)
    if not ok then
        skinStatus.Text = "Ошибка: " .. tostring(err)
        logFile("skin refresh error: " .. tostring(err))
    end
end

section(skinPage, "ручной ввод")
local manualBox = textbox(skinPage, "суффикс скина, напр. Doppler", function(text)
    text = string.gsub(text or "", "^%s*(.-)%s*$", "%1")
    if text == "" then
        notify("Впиши суффикс скина")
        return
    end
    SKIN.skin = text
    SKIN.enabled = true
    if apply() then
        notify(text)
    else
        notify("Ствол не найден в SkinFolder")
    end
end)

section(skinPage, "действия")
button(skinPage, "Применить", function()
    if not SKIN.skin then notify("Выбери скин") return end
    SKIN.enabled = true
    if apply() then
        notify(SKIN.skin)
    else
        notify("Ствол не найден в SkinFolder")
    end
end)
button(skinPage, "Снять скин", function()
    restoreAll()
    reequip()
    notify("Скин снят")
end)
button(skinPage, "Обновить список", function()
    refresh()
    notify("Обновлено")
end)

section(skinPage, "диагностика")
local dumpOut = dumpBox(skinPage, 150)
button(skinPage, "Дамп структуры", function()
    local text = dumpStructure()
    dumpOut.Text = text
    logFile("DUMP:\n" .. text)
    notify("Дамп готов (в поле и в логе)")
end)

refresh()

task.spawn(function()
    for _ = 1, 40 do
        if SKIN.dead then return end
        if lp:FindFirstChild("SkinFolder") then break end
        task.wait(1)
    end
    refresh()
end)

track(lp.ChildAdded:Connect(function(c)
    if c.Name == "SkinFolder" then
        task.delay(0.6, refresh)
    end
end))

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
    SKIN.dead = true
    restoreAll()
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
