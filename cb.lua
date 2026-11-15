--!nocheck
--[[
    SleepScript • Counter Blox (Rolve)  v1.7
    ---------------------------------------------------------------
    ESP, бхоп, no air spread, фиксация FOV, третье лицо по бинду,
    небо с пресетами, автобаннихоп.
--]]

local CONFIG = {
    ScriptURL   = "",
    Accent      = Color3.fromRGB(122, 92, 255),
    AccentDark  = Color3.fromRGB(64, 46, 150),
    Keybind     = Enum.KeyCode.RightShift,
    DetectGrace = 20,
    LogOnly     = false,
    Version     = "1.7",
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
local Workspace         = cloneref(workspace)
local lp                = Players.LocalPlayer

if not Drawing then
    return warn("[SleepScript] нет Drawing API — ESP не запустится.")
end

--==============================================================
--  СОСТОЯНИЕ
--==============================================================
local S = {
    paranoid     = false,
    adaptive     = true,
    espEnabled   = false,

    style        = "full",
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
    colorTracer  = Color3.fromRGB(122, 92, 255),

    teamCheck    = true,
    showLocal    = false,
    maxDist      = 600,

    bhop         = false,
    jumpLimit    = 0,
    noAirSpread  = false,

    fovEnabled   = false,
    fovValue     = 90,

    thirdPerson  = false,
    tpDistance   = 12,
    tpBind       = Enum.KeyCode.V,

    watchEnabled = true,
    autoRejoin   = true,
    rejoinDelay  = 1.5,
    banCount     = 0,
    lastReason   = "—",
}

-- флаг «читает наш скрипт», чтобы хуки не подменяли значения нам же
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
--  КАМЕРА / FOV / ТРЕТЬЕ ЛИЦО
--==============================================================
local camera = Workspace.CurrentCamera
local fovOriginal = camera and camera.FieldOfView or 70
local savedCamMode = lp.CameraMode
local savedZoomMin = lp.CameraMinZoomDistance
local savedZoomMax = lp.CameraMaxZoomDistance

-- цель режима и до какого времени её удерживать
local camTarget = savedCamMode
local camHoldUntil = 0
local camRefresh = function() end

local function tpZoom()
    return math.clamp(S.tpDistance, 6, 40)
end

local function applyFov()
    local cam = camera or Workspace.CurrentCamera
    if not cam then return end
    if S.fovEnabled then
        pcall(function() cam.FieldOfView = S.fovValue end)
    else
        pcall(function() cam.FieldOfView = fovOriginal end)
    end
end

local function pushCam()
    pcall(function()
        if S.thirdPerson then
            camTarget = Enum.CameraMode.Classic
            lp.CameraMode = Enum.CameraMode.Classic
            lp.CameraMinZoomDistance = 4
            lp.CameraMaxZoomDistance = tpZoom()
        else
            camTarget = Enum.CameraMode.LockFirstPerson
            lp.CameraMode = Enum.CameraMode.LockFirstPerson
            lp.CameraMinZoomDistance = 0.5
            lp.CameraMaxZoomDistance = 0.5
        end
    end)
end

-- третье лицо держим постоянно, первую персону — ещё 2 секунды после возврата,
-- чтобы игра не успела отбросить режим обратно
local function setCamMode(third)
    S.thirdPerson = third and true or false
    camHoldUntil = third and math.huge or (os.clock() + 2)
    pushCam()
    pcall(camRefresh)
end

track(RunService.RenderStepped:Connect(function()
    local cam = camera or Workspace.CurrentCamera
    if not cam then return end

    if S.fovEnabled then
        if math.abs(cam.FieldOfView - S.fovValue) > 0.4 then
            pcall(function() cam.FieldOfView = S.fovValue end)
        end
    end

    if os.clock() <= camHoldUntil then
        if lp.CameraMode ~= camTarget then
            pcall(function() lp.CameraMode = camTarget end)
        end
        if S.thirdPerson then
            if math.abs(lp.CameraMaxZoomDistance - tpZoom()) > 0.1 then
                pcall(function()
                    lp.CameraMinZoomDistance = 4
                    lp.CameraMaxZoomDistance = tpZoom()
                end)
            end
        elseif lp.CameraMaxZoomDistance > 0.6 then
            pcall(function()
                lp.CameraMinZoomDistance = 0.5
                lp.CameraMaxZoomDistance = 0.5
            end)
        end
    end
end))

track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then
        camera = Workspace.CurrentCamera
        applyFov()
    end
end))

--==============================================================
--  UI
--==============================================================
local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local gui = new("ScreenGui", {
    Name = "SleepScript",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 9999,
}, gethui())

local glow = new("Frame", {
    Size = UDim2.fromOffset(502, 376),
    Position = UDim2.new(0.5, -251, 0.5, -188),
    BackgroundColor3 = CONFIG.Accent,
    BackgroundTransparency = 0.86,
    BorderSizePixel = 0,
    ZIndex = 0,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 20) }, glow)

local main = new("Frame", {
    Size = UDim2.fromOffset(486, 360),
    Position = UDim2.new(0.5, -243, 0.5, -180),
    BackgroundColor3 = Color3.fromRGB(13, 15, 20),
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 1,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, main)
new("UIStroke", { Color = CONFIG.Accent, Thickness = 1, Transparency = 0.5 }, main)

track(main:GetPropertyChangedSignal("Visible"):Connect(function()
    glow.Visible = main.Visible
end))

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = Color3.fromRGB(19, 17, 32),
    BorderSizePixel = 0,
    ZIndex = 2,
}, main)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, header)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16),
    BackgroundColor3 = Color3.fromRGB(19, 17, 32), BorderSizePixel = 0,
}, header)
local grad = new("UIGradient", {
    Color = ColorSequence.new(CONFIG.Accent, CONFIG.AccentDark),
    Rotation = 25,
}, header)
grad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.78),
    NumberSequenceKeypoint.new(1, 1),
})

local title = new("TextLabel", {
    Text = "SleepScript",
    Font = Enum.Font.GothamBold,
    TextSize = 21,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(17, 9),
    Size = UDim2.fromOffset(240, 24),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, header)
new("UIGradient", {
    Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), CONFIG.Accent),
    Rotation = 12,
}, title)

new("TextLabel", {
    Text = "counter blox  •  esp  •  bhop  •  no spread  •  3rd person  •  sky  •  rac watch",
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = Color3.fromRGB(150, 150, 175),
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 33),
    Size = UDim2.fromOffset(380, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, header)

local accentLine = new("Frame", {
    Size = UDim2.new(0, 46, 0, 2),
    Position = UDim2.fromOffset(18, 53),
    BackgroundColor3 = CONFIG.Accent,
    BorderSizePixel = 0,
    ZIndex = 3,
}, header)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, accentLine)
TweenService:Create(accentLine, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
    Size = UDim2.new(0, 96, 0, 2),
}):Play()

local function headerButton(x, symbol, cb)
    local b = new("TextButton", {
        Text = symbol,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(190, 190, 205),
        BackgroundColor3 = Color3.fromRGB(34, 30, 56),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Position = UDim2.new(1, x, 0, 18),
        Size = UDim2.fromOffset(22, 22),
        ZIndex = 4,
    }, header)
    new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.35 }):Play()
    end)
    b.MouseButton1Click:Connect(cb)
    return b
end

headerButton(-58, "—", function() main.Visible = not main.Visible end)
headerButton(-32, "×", function()
    if getgenv().SleepScript then getgenv().SleepScript.Unload() end
end)

local dragging, dragStart, startPos
track(header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end))
track(UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        glow.Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset - 8,
            main.Position.Y.Scale, main.Position.Y.Offset - 8)
    end
end))
track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

local sidebar = new("Frame", {
    Size = UDim2.new(0, 118, 1, -58),
    Position = UDim2.fromOffset(0, 58),
    BackgroundColor3 = Color3.fromRGB(15, 16, 22),
    BorderSizePixel = 0,
}, main)
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, sidebar)

local content = new("Frame", {
    Size = UDim2.new(1, -118, 1, -82),
    Position = UDim2.fromOffset(118, 58),
    BackgroundTransparency = 1,
}, main)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }, content)

local footer = new("Frame", {
    Size = UDim2.new(1, -118, 0, 24),
    Position = UDim2.new(0, 118, 1, -24),
    BackgroundColor3 = Color3.fromRGB(15, 16, 22),
    BorderSizePixel = 0,
}, main)
new("TextLabel", {
    Text = "v" .. CONFIG.Version .. "  •  RightShift — меню",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = Color3.fromRGB(105, 105, 125),
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
        TextColor3 = Color3.fromRGB(150, 150, 170),
        BackgroundColor3 = Color3.fromRGB(22, 23, 32),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 30),
    }, sidebar)
    new("UICorner", { CornerRadius = UDim.new(0, 7) }, b)

    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 0, 14),
        Position = UDim2.new(0, 0, 0.5, -7),
        BackgroundColor3 = CONFIG.Accent,
        BorderSizePixel = 0,
        Visible = false,
    }, b)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)

    tabs[key] = b
    tabBars[key] = bar
    b.MouseEnter:Connect(function()
        if not pages[key].Visible then
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.15 }):Play()
        end
    end)
    b.MouseLeave:Connect(function()
        if not pages[key].Visible then
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.4 }):Play()
        end
    end)
    b.MouseButton1Click:Connect(function()
        for k, p in pairs(pages) do p.Visible = (k == key) end
        for k, t in pairs(tabs) do
            t.TextColor3 = (k == key) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 170)
            t.BackgroundColor3 = (k == key) and CONFIG.AccentDark or Color3.fromRGB(22, 23, 32)
            tabBars[k].Visible = (k == key)
        end
    end)
    return b
end

local function section(parent, text)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Color3.fromRGB(34, 34, 46),
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
        TextColor3 = Color3.fromRGB(212, 212, 225), BackgroundTransparency = 1,
        Size = UDim2.new(1, -44, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
    }, r)
    local pill = new("Frame", {
        Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -34, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(44, 44, 58), BorderSizePixel = 0,
    }, r)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.fromRGB(230, 230, 240), BorderSizePixel = 0,
    }, pill)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

    local state = default
    local function render(instant)
        local info = TweenInfo.new(instant and 0 or 0.14, Enum.EasingStyle.Quad)
        TweenService:Create(knob, info, {
            Position = state and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2),
        }):Play()
        TweenService:Create(pill, info, {
            BackgroundColor3 = state and CONFIG.Accent or Color3.fromRGB(44, 44, 58),
        }):Play()
    end
    render(true)

    local function set(v) state = v; render(); cb(v) end
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
        TextColor3 = Color3.fromRGB(212, 212, 225), BackgroundTransparency = 1,
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
        BackgroundColor3 = Color3.fromRGB(40, 40, 54), BorderSizePixel = 0,
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
        TextColor3 = Color3.fromRGB(235, 235, 245),
        BackgroundColor3 = Color3.fromRGB(30, 30, 42), BorderSizePixel = 0,
        AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30),
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(0, 7) }, b)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = CONFIG.AccentDark }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(30, 30, 42) }):Play()
    end)
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
    local function paint()
        for value, b in pairs(made) do
            b.BackgroundColor3 = (value == current) and CONFIG.AccentDark or Color3.fromRGB(32, 32, 44)
        end
    end
    for i, item in ipairs(items) do
        local b = new("TextButton", {
            Text = item.name,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = item.color or Color3.fromRGB(215, 215, 228),
            BackgroundColor3 = Color3.fromRGB(32, 32, 44),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = i,
        }, grid)
        new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
        made[item.value] = b
        b.MouseButton1Click:Connect(function()
            current = item.value
            paint()
            cb(item.value)
        end)
    end
    paint()
    return grid
end

--==============================================================
--  ESP
--==============================================================
local ESP = { objects = {} }
local FONT = (Drawing.Fonts and Drawing.Fonts.UI) or 2

local function sq(filled)
    local o = Drawing.new("Square")
    o.Filled = filled
    o.Visible = false
    o.Thickness = 1
    return o
end

local function blankRec()
    local rec = {
        box = sq(false),
        fill = sq(true),
        hpBg = sq(true), hp = sq(true),
        name = Drawing.new("Text"), dist = Drawing.new("Text"), hpText = Drawing.new("Text"),
        tracer = Drawing.new("Line"),
        off = Drawing.new("Circle"),
        corners = {}, cross = {}, bones = {},
    }
    rec.name.Center = true; rec.name.Outline = true; rec.name.Font = FONT
    rec.name.OutlineColor = Color3.fromRGB(0, 0, 0)
    rec.dist.Center = true; rec.dist.Outline = true; rec.dist.Font = FONT
    rec.dist.OutlineColor = Color3.fromRGB(0, 0, 0)
    rec.hpText.Center = true; rec.hpText.Outline = true; rec.hpText.Font = FONT
    rec.hpText.OutlineColor = Color3.fromRGB(0, 0, 0)
    rec.tracer.Thickness = 1
    rec.fill.Transparency = 0.85
    rec.off.Thickness = 2
    rec.off.Filled = false
    for i = 1, 8 do rec.corners[i] = sq(false) end
    for i = 1, 4 do rec.cross[i] = sq(false) end
    for i = 1, 15 do
        local l = Drawing.new("Line")
        l.Thickness = 1
        l.Visible = false
        rec.bones[i] = l
    end
    return rec
end

local function hide(rec)
    for k, o in pairs(rec) do
        if k == "bones" or k == "corners" or k == "cross" then
            for _, b in ipairs(o) do b.Visible = false end
        else
            pcall(function() o.Visible = false end)
        end
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
    local entry = { rec = blankRec(), char = nil }
    ESP.objects[player] = entry

    local function onChar(char)
        entry.char = char
        task.spawn(function()
            entry.humanoid = char:WaitForChild("Humanoid", 8)
            entry.root = char:WaitForChild("HumanoidRootPart", 8)
            entry.head = char:WaitForChild("Head", 8)
        end)
    end
    if player.Character then onChar(player.Character) end
    track(player.CharacterAdded:Connect(onChar))
end

local function unbindPlayer(player)
    local entry = ESP.objects[player]
    if not entry then return end
    for _, o in pairs(entry.rec) do
        if type(o) == "table" then
            for _, b in ipairs(o) do pcall(function() b:Remove() end) end
        else
            pcall(function() o:Remove() end)
        end
    end
    ESP.objects[player] = nil
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= lp then bindPlayer(p) end
end
track(Players.PlayerAdded:Connect(function(p) if p ~= lp then bindPlayer(p) end end))
track(Players.PlayerRemoving:Connect(unbindPlayer))

local rayParams = RaycastParams.new()
rayParams.IgnoreWater = true

local visState, visClock = {}, {}
local lastInterval, fpsSmooth = 0.016, 60

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
    if not S.espEnabled or not camera then return end

    fpsSmooth = fpsSmooth * 0.9 + (1 / math.max(dt, 0.001)) * 0.1
    local base = 0.016
    if S.paranoid then
        base = 0.1
    elseif S.adaptive and fpsSmooth < 42 then
        base = 0.034
    end
    lastInterval = base * (0.9 + math.random() * 0.2)

    local now = os.clock()
    local camPos = camera.CFrame.Position
    local vp = camera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2

    for player, entry in pairs(ESP.objects) do
        local rec = entry.rec
        local head, root, hum = entry.head, entry.root, entry.humanoid

        if (player ~= lp or S.showLocal) and head and root and hum
            and hum.Health > 0 and head.Parent and root.Parent then
            local headPos = head.Position
            local dist = (camPos - headPos).Magnitude

            if dist <= S.maxDist and not (S.teamCheck and player.Team == lp.Team and player ~= lp) then
                local sTop, onTop = camera:WorldToViewportPoint(headPos + Vector3.new(0, 1.1, 0))
                local sBot, onBot = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0))
                local onScreen = onTop and onBot and sTop.Z > 0 and sBot.Z > 0 and sBot.Y > sTop.Y

                if onScreen then
                    local h = sBot.Y - sTop.Y
                    local w = h * 0.45
                    local x = sTop.X - w / 2
                    local y = sTop.Y

                    if not visClock[player] or now - visClock[player] > 0.15 then
                        visClock[player] = now
                        rayParams.FilterDescendantsInstances = { entry.char, lp.Character }
                        local hit = Workspace:Raycast(camPos, headPos - camPos, rayParams)
                        visState[player] = (hit == nil or (entry.char and hit.Instance:IsDescendantOf(entry.char)))
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
                        rec.hpBg.Color = Color3.fromRGB(25, 25, 32)
                        rec.hpBg.Visible = true
                        rec.hp.Position = Vector2.new(hx, y + h * (1 - frac))
                        rec.hp.Size = Vector2.new(3, h * frac)
                        rec.hp.Color = Color3.fromRGB(90, 220, 120):Lerp(Color3.fromRGB(230, 70, 70), 1 - frac)
                        rec.hp.Visible = true
                        rec.hpText.Visible = false
                    elseif S.hpMode == "text" then
                        rec.hpBg.Visible = false; rec.hp.Visible = false
                        rec.hpText.Text = tostring(math.floor(hum.Health))
                        rec.hpText.Size = S.textSize
                        rec.hpText.Color = Color3.fromRGB(90, 220, 120):Lerp(Color3.fromRGB(230, 70, 70), 1 - frac)
                        rec.hpText.Position = Vector2.new(x + w / 2, y + h + 3)
                        rec.hpText.Visible = true
                    else
                        rec.hpBg.Visible = false; rec.hp.Visible = false; rec.hpText.Visible = false
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

                    if S.skeleton and entry.char then
                        local list = BONES[hum.RigType]
                        if list then
                            for i, pair in ipairs(list) do
                                local a = entry.char:FindFirstChild(pair[1])
                                local b = entry.char:FindFirstChild(pair[2])
                                local line = rec.bones[i]
                                if a and b and line then
                                    local pa = camera:WorldToViewportPoint(a.Position)
                                    local pb = camera:WorldToViewportPoint(b.Position)
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

                    rec.off.Visible = false
                else
                    hide(rec)
                    if S.offscreen and sTop.Z > 0 then
                        local ox = math.clamp(sTop.X, 30, vp.X - 30)
                        local oy = math.clamp(sTop.Y, 30, vp.Y - 30)
                        rec.off.Position = Vector2.new(ox, oy)
                        rec.off.Radius = 7
                        rec.off.Color = S.colorStatic
                        rec.off.Visible = true
                    end
                end
            else
                hide(rec)
            end
        else
            hide(rec)
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
--  БХОП
--==============================================================
local lastJump = 0
local airJumps = 0

local function myHum()
    local char = lp.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

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

local function holdingJump()
    return UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.ButtonA)
end

local function doJump(auto)
    if not S.bhop then return end
    local now = os.clock()
    if now - lastJump < 0.04 then return end
    if auto and now - lastJump < 0.12 then return end

    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
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
end

track(UIS.JumpRequest:Connect(function() pcall(doJump, false) end))

track(RunService.Stepped:Connect(function()
    local hum = myHum()
    if not hum or hum.Health <= 0 then return end
    if S.bhop and not isAirborne(hum) then
        airJumps = 0
        if holdingJump() then pcall(doJump, true) end
    end
end))

track(lp.CharacterAdded:Connect(function()
    airJumps = 0
    task.delay(0.4, function()
        if S.thirdPerson then pushCam() end
    end)
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
                local hum = myHum()
                if hum and rawequal(self, hum) then
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
            if S.noAirSpread and not selfRead and getnamecallmethod() == "GetState" then
                local hum = myHum()
                if hum and rawequal(self, hum) then
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

local function setAirSpread(on)
    S.noAirSpread = on
    local hum = myHum()
    if hum then
        pcall(function() hum.FloorMaterial = on and Enum.Material.Plastic or Enum.Material.Air end)
    end
end

track(RunService.RenderStepped:Connect(function()
    if not S.noAirSpread then return end
    local hum = myHum()
    if not hum or hum.Health <= 0 then return end
    local st = realState(hum)
    if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping then
        pcall(function() hum.FloorMaterial = Enum.Material.Plastic end)
    end
end))

--==============================================================
--  НЕБО
--==============================================================
local NIGHT = {
    Bk = "rbxassetid://159454299", Dn = "rbxassetid://159454296",
    Ft = "rbxassetid://159454293", Lf = "rbxassetid://159454290",
    Rt = "rbxassetid://159454287", Up = "rbxassetid://159454284",
}

local CLASSIC = {
    Bk = "rbxasset://textures/sky/sky512_bk.tex", Dn = "rbxasset://textures/sky/sky512_dn.tex",
    Ft = "rbxasset://textures/sky/sky512_ft.tex", Lf = "rbxasset://textures/sky/sky512_lf.tex",
    Rt = "rbxasset://textures/sky/sky512_rt.tex", Up = "rbxasset://textures/sky/sky512_up.tex",
}

local SKY = {
    mode = "off", stars = 0, fog = 600, clock = 1,
    tint = Color3.fromRGB(0, 0, 0), ambient = Color3.fromRGB(0, 0, 0),
    outdoor = Color3.fromRGB(0, 0, 0), brightness = 1,
}

local PRESETS = {
    night    = { set = NIGHT,   clock = 1,    stars = 800,  fog = 700,  tint = Color3.fromRGB(0, 0, 0),        ambient = Color3.fromRGB(12, 12, 20),   outdoor = Color3.fromRGB(20, 20, 32),   brightness = 1.0 },
    space    = { set = NIGHT,   clock = 0,    stars = 3000, fog = 6000, tint = Color3.fromRGB(0, 0, 0),        ambient = Color3.fromRGB(0, 0, 0),      outdoor = Color3.fromRGB(10, 10, 18),   brightness = 0.4 },
    sunset   = { set = NIGHT,   clock = 18.2, stars = 150,  fog = 1500, tint = Color3.fromRGB(60, 30, 24),     ambient = Color3.fromRGB(42, 22, 26),   outdoor = Color3.fromRGB(84, 46, 40),   brightness = 1.2 },
    classic  = { set = CLASSIC, clock = 14,   stars = 0,    fog = 6000, tint = Color3.fromRGB(140, 170, 200),  brightness = 2.0 },
    overcast = { set = CLASSIC, clock = 13,   stars = 0,    fog = 800,  tint = Color3.fromRGB(118, 122, 130),  ambient = Color3.fromRGB(70, 72, 78),   outdoor = Color3.fromRGB(92, 94, 100),  brightness = 1.4 },
    dusk     = { set = CLASSIC, clock = 17.6, stars = 60,   fog = 1800, tint = Color3.fromRGB(70, 55, 80),     ambient = Color3.fromRGB(45, 38, 55),   outdoor = Color3.fromRGB(70, 55, 80),   brightness = 1.1 },
    void     = { set = nil,     clock = 1,    stars = 0,    fog = 600,  tint = Color3.fromRGB(0, 0, 0),        ambient = Color3.fromRGB(0, 0, 0),      outdoor = Color3.fromRGB(0, 0, 0),      brightness = 0.6 },
    inferno  = { set = nil,     clock = 17,   stars = 0,    fog = 420,  tint = Color3.fromRGB(72, 14, 8),      ambient = Color3.fromRGB(44, 12, 8),    outdoor = Color3.fromRGB(62, 20, 12),   brightness = 1.2 },
    ice      = { set = nil,     clock = 10,   stars = 0,    fog = 520,  tint = Color3.fromRGB(150, 180, 205),  ambient = Color3.fromRGB(32, 42, 52),   outdoor = Color3.fromRGB(46, 62, 78),   brightness = 1.4 },
    matrix   = { set = nil,     clock = 2,    stars = 0,    fog = 460,  tint = Color3.fromRGB(6, 42, 12),      ambient = Color3.fromRGB(4, 18, 6),     outdoor = Color3.fromRGB(8, 30, 10),    brightness = 0.9 },
    blood    = { set = nil,     clock = 0,    stars = 0,    fog = 340,  tint = Color3.fromRGB(58, 6, 6),       ambient = Color3.fromRGB(30, 4, 4),     outdoor = Color3.fromRGB(44, 8, 8),     brightness = 0.8 },
    ash      = { set = CLASSIC, clock = 11,   stars = 0,    fog = 900,  tint = Color3.fromRGB(92, 92, 96),     ambient = Color3.fromRGB(58, 58, 62),   outdoor = Color3.fromRGB(78, 78, 82),   brightness = 1.1 },
    neon     = { set = NIGHT,   clock = 0,    stars = 1200, fog = 700,  tint = Color3.fromRGB(48, 6, 60),      ambient = Color3.fromRGB(38, 10, 58),   outdoor = Color3.fromRGB(62, 16, 88),   brightness = 1.6 },
    eclipse  = { set = NIGHT,   clock = 0,    stars = 2200, fog = 300,  tint = Color3.fromRGB(40, 8, 10),      ambient = Color3.fromRGB(18, 4, 6),     outdoor = Color3.fromRGB(28, 6, 8),     brightness = 0.25 },
    fog      = { set = CLASSIC, clock = 12,   stars = 0,    fog = 130,  tint = Color3.fromRGB(170, 175, 182),  ambient = Color3.fromRGB(120, 122, 128), outdoor = Color3.fromRGB(150, 152, 158), brightness = 1.6 },
    radiation= { set = nil,     clock = 12,   stars = 0,    fog = 500,  tint = Color3.fromRGB(56, 92, 10),     ambient = Color3.fromRGB(40, 66, 8),    outdoor = Color3.fromRGB(58, 96, 12),   brightness = 1.3 },
    storm    = { set = CLASSIC, clock = 15,   stars = 0,    fog = 700,  tint = Color3.fromRGB(30, 36, 54),     ambient = Color3.fromRGB(24, 28, 42),   outdoor = Color3.fromRGB(36, 42, 60),   brightness = 0.7 },
    sand     = { set = CLASSIC, clock = 16,   stars = 0,    fog = 1000, tint = Color3.fromRGB(196, 168, 112),  ambient = Color3.fromRGB(120, 102, 68), outdoor = Color3.fromRGB(160, 136, 92), brightness = 1.5 },
    cobalt   = { set = nil,     clock = 3,    stars = 40,   fog = 560,  tint = Color3.fromRGB(8, 26, 76),      ambient = Color3.fromRGB(6, 18, 52),    outdoor = Color3.fromRGB(10, 30, 88),   brightness = 1.0 },
}

local skySaved, ourSky = nil, nil

local function saveLighting()
    if skySaved then return end
    skySaved = {
        sky = Lighting:FindFirstChildOfClass("Sky"),
        ambient = Lighting.Ambient,
        outdoor = Lighting.OutdoorAmbient,
        brightness = Lighting.Brightness,
        fogColor = Lighting.FogColor,
        fogStart = Lighting.FogStart,
        fogEnd = Lighting.FogEnd,
        clock = Lighting.ClockTime,
    }
end

local function restoreLighting()
    if ourSky then pcall(function() ourSky:Destroy() end) ourSky = nil end
    if not skySaved then return end
    local s = skySaved
    skySaved = nil
    if s.sky and s.sky.Parent == nil then pcall(function() s.sky.Parent = Lighting end) end
    pcall(function()
        Lighting.Ambient = s.ambient
        Lighting.OutdoorAmbient = s.outdoor
        Lighting.Brightness = s.brightness
        Lighting.FogColor = s.fogColor
        Lighting.FogStart = s.fogStart
        Lighting.FogEnd = s.fogEnd
        Lighting.ClockTime = s.clock
    end)
end

local function applySky(mode)
    local p = PRESETS[mode]
    SKY.mode = mode
    if not p then
        restoreLighting()
        return
    end

    saveLighting()
    if ourSky then pcall(function() ourSky:Destroy() end) ourSky = nil end

    local gameSky = Lighting:FindFirstChildOfClass("Sky")
    if gameSky and gameSky ~= skySaved.sky then pcall(function() gameSky.Parent = nil end) end
    if skySaved.sky then pcall(function() skySaved.sky.Parent = nil end) end

    SKY.stars = p.stars
    SKY.fog = p.fog
    SKY.clock = p.clock
    SKY.tint = p.tint
    SKY.ambient = p.ambient or skySaved.ambient
    SKY.outdoor = p.outdoor or skySaved.outdoor
    SKY.brightness = p.brightness or skySaved.brightness

    if p.set then
        ourSky = Instance.new("Sky")
        ourSky.SkyboxBk = p.set.Bk
        ourSky.SkyboxDn = p.set.Dn
        ourSky.SkyboxFt = p.set.Ft
        ourSky.SkyboxLf = p.set.Lf
        ourSky.SkyboxRt = p.set.Rt
        ourSky.SkyboxUp = p.set.Up
        ourSky.StarCount = SKY.stars
        ourSky.CelestialBodiesShown = true
        ourSky.SunAngularSize = 11
        ourSky.MoonAngularSize = 14
        ourSky.Parent = Lighting
    end

    Lighting.ClockTime = SKY.clock
    Lighting.Ambient = SKY.ambient
    Lighting.OutdoorAmbient = SKY.outdoor
    Lighting.Brightness = SKY.brightness
    Lighting.FogColor = SKY.tint
    Lighting.FogStart = 0
    Lighting.FogEnd = SKY.fog
end

local function syncSky()
    local p = PRESETS[SKY.mode]
    if not p then return end
    if p.set then
        if not ourSky or not ourSky.Parent then
            applySky(SKY.mode)
            return
        end
        if ourSky.StarCount ~= SKY.stars then ourSky.StarCount = SKY.stars end
    end
    if Lighting.FogEnd ~= SKY.fog then Lighting.FogEnd = SKY.fog end
    if Lighting.FogColor ~= SKY.tint then Lighting.FogColor = SKY.tint end
    if Lighting.Ambient ~= SKY.ambient then Lighting.Ambient = SKY.ambient end
    if math.abs(Lighting.Brightness - SKY.brightness) > 0.01 then Lighting.Brightness = SKY.brightness end
    if math.abs(Lighting.ClockTime - SKY.clock) > 0.05 then Lighting.ClockTime = SKY.clock end
end

track(Lighting.ChildAdded:Connect(function(d)
    if SKY.mode == "off" then return end
    if d:IsA("Sky") and d ~= ourSky then
        task.defer(function()
            if SKY.mode ~= "off" and d.Parent then pcall(function() d.Parent = nil end) end
        end)
    end
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
    notify("RAC: " .. reason .. (CONFIG.LogOnly and " (лог)" or " — хоп"))

    if S.banCount >= 3 and not S.paranoid then
        S.paranoid = true
        notify("3 детекта → паранойя включена")
    end

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
                    onBan(pat, hard)
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
            local pat, hard = matchText(tostring(msg.Message or ""))
            if pat then onBan(pat, hard) end
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
local skyPage    = page("sky");    tabButton("Небо", "sky")
local watchPage  = page("watch");  tabButton("Автобан", "watch")
local miscPage   = page("misc");   tabButton("Прочее", "misc")

section(visualPage, "основа")
toggle(visualPage, "Включить ESP", false, function(v) S.espEnabled = v end)
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
slider(movePage, "Прыжков в воздухе", -1, 10, 0, function(v) S.jumpLimit = v; airJumps = 0 end)

section(movePage, "разброс")
toggle(movePage, "Убрать разброс в полёте", false, function(v) setAirSpread(v) end)

section(movePage, "камера")
local capturing = false
local captureConn = nil
local tpBtn

local function refreshTpBtn()
    if not tpBtn then return end
    tpBtn.Text = (S.thirdPerson and "Третье лицо: ВКЛ" or "Третье лицо: ВЫКЛ") .. "   [" .. S.tpBind.Name .. "]"
    tpBtn.BackgroundColor3 = S.thirdPerson and CONFIG.AccentDark or Color3.fromRGB(30, 30, 42)
end
camRefresh = refreshTpBtn

local function stopCapture()
    capturing = false
    if captureConn then
        pcall(function() captureConn:Disconnect() end)
        captureConn = nil
    end
    refreshTpBtn()
end

local function startCapture()
    if capturing then
        stopCapture()
        return
    end
    capturing = true
    tpBtn.Text = "Нажми клавишу… (клик — отмена)"
    local token = os.clock()
    captureConn = UIS.InputBegan:Connect(function(i, processed)
        if not capturing then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            stopCapture()
            return
        end
        if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if processed then return end
        if i.KeyCode == Enum.KeyCode.Unknown then return end
        S.tpBind = i.KeyCode
        stopCapture()
    end)
    task.delay(6, function()
        if capturing and captureConn then
            -- отмена по таймауту, только если бинд всё ещё не выбран
            if S.tpBind == Enum.KeyCode.Unknown then stopCapture() end
        end
    end)
end

tpBtn = button(movePage, "", function()
    setCamMode(not S.thirdPerson)
    notify(S.thirdPerson and "Третье лицо включено" or "Третье лицо выключено")
end)
refreshTpBtn()

button(movePage, "Сменить бинд", startCapture)
button(movePage, "Вернуть первую персону", function()
    stopCapture()
    setCamMode(false)
    notify("Первая персона")
end)

slider(movePage, "Дистанция камеры", 6, 40, 12, function(v)
    S.tpDistance = v
    if S.thirdPerson then pushCam() end
end)

toggle(movePage, "Фиксация FOV", false, function(v)
    if v and camera then fovOriginal = camera.FieldOfView end
    S.fovEnabled = v
    applyFov()
end)
slider(movePage, "FOV", 40, 120, 90, function(v)
    S.fovValue = v
    applyFov()
end)

section(skyPage, "пресеты")
chips(skyPage, {
    { name = "Выкл", value = "off" },
    { name = "Ночь", value = "night" },
    { name = "Космос", value = "space" },
    { name = "Закат", value = "sunset" },
    { name = "Сумерки", value = "dusk" },
    { name = "Классика", value = "classic" },
    { name = "Пасмурно", value = "overcast" },
    { name = "Туман", value = "fog" },
    { name = "Пепел", value = "ash" },
    { name = "Гроза", value = "storm" },
    { name = "Песок", value = "sand" },
    { name = "Затмение", value = "eclipse" },
    { name = "Неон", value = "neon" },
    { name = "Кобальт", value = "cobalt" },
    { name = "Пустота", value = "void" },
    { name = "Инферно", value = "inferno" },
    { name = "Лёд", value = "ice" },
    { name = "Матрица", value = "matrix" },
    { name = "Радиация", value = "radiation" },
    { name = "Кровь", value = "blood" },
}, SKY.mode, function(v) applySky(v) end, 4)

section(skyPage, "настройка")
slider(skyPage, "Звёзды", 0, 5000, 0, function(v)
    SKY.stars = v
    if ourSky then pcall(function() ourSky.StarCount = v end) end
end)
slider(skyPage, "Туман (дистанция)", 100, 8000, 600, function(v) SKY.fog = v; syncSky() end)
slider(skyPage, "Яркость (x10)", 1, 30, 10, function(v) SKY.brightness = v / 10; syncSky() end)
slider(skyPage, "Время суток", 0, 24, 12, function(v) SKY.clock = v; syncSky() end)
button(skyPage, "Сбросить небо", function() applySky("off") end)

section(watchPage, "наблюдение")
toggle(watchPage, "Следить за RAC", true, function(v) S.watchEnabled = v end)
toggle(watchPage, "Автопереподключение", true, function(v) S.autoRejoin = v end)
toggle(watchPage, "Только логировать", false, function(v) CONFIG.LogOnly = v end)
slider(watchPage, "Задержка хопа (0.1с)", 1, 30, 15, function(v) S.rejoinDelay = v / 10 end)

local statusLabel = new("TextLabel", {
    Text = "Детектов: 0\nПоследнее: —",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(160, 160, 180),
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 34),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, watchPage)

section(watchPage, "действия")
button(watchPage, "Проверить детект вручную", function() onBan("manual test", true, true) end)
button(watchPage, "Хопнуть сейчас", function() notify("Хоп…"); rejoin() end)

section(miscPage, "производительность")
toggle(miscPage, "Паранойя (тик 10 Гц)", false, function(v) S.paranoid = v end)
toggle(miscPage, "Адаптивный бюджет", true, function(v) S.adaptive = v end)

section(miscPage, "безопасность")
button(miscPage, "PANIC — выключить всё", function()
    S.espEnabled = false
    S.bhop = false
    setAirSpread(false)
    S.fovEnabled = false
    applyFov()
    stopCapture()
    setCamMode(false)
    notify("Всё выключено")
end)
button(miscPage, "Выгрузить скрипт", function()
    if getgenv().SleepScript then getgenv().SleepScript.Unload() end
end)

--==============================================================
--  СЛУЖЕБНОЕ
--==============================================================
track(RunService.Heartbeat:Connect(function()
    statusLabel.Text = string.format("Детектов: %d\nПоследнее: %s", S.banCount, S.lastReason)
    if S.fovEnabled then pcall(applyFov) end
    if SKY.mode ~= "off" then pcall(syncSky) end
end))

track(UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == CONFIG.Keybind then
        main.Visible = not main.Visible
        return
    end
    if not capturing and input.KeyCode == S.tpBind then
        setCamMode(not S.thirdPerson)
        notify(S.thirdPerson and "Третье лицо включено" or "Третье лицо выключено")
    end
end))

main.Position = UDim2.new(0.5, -243, 0.5, -170)
glow.Position = UDim2.new(0.5, -251, 0.5, -178)
TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -243, 0.5, -180),
}):Play()
TweenService:Create(glow, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -251, 0.5, -188),
}):Play()

pages.visual.Visible = true
tabs.visual.TextColor3 = Color3.fromRGB(255, 255, 255)
tabs.visual.BackgroundColor3 = CONFIG.AccentDark
tabBars.visual.Visible = true

--==============================================================
--  ВЫГРУЗКА
--==============================================================
local function unload()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for player in pairs(ESP.objects) do unbindPlayer(player) end
    if captureConn then pcall(function() captureConn:Disconnect() end) end
    if hookedIndex and origIndex then pcall(function() hookmetamethod(game, "__index", origIndex) end) end
    if hookedNamecall and origNamecall then pcall(function() hookmetamethod(game, "__namecall", origNamecall) end) end
    local hum = myHum()
    if hum then pcall(function() hum.FloorMaterial = Enum.Material.Air end) end
    pcall(function()
        lp.CameraMode = savedCamMode
        lp.CameraMinZoomDistance = savedZoomMin
        lp.CameraMaxZoomDistance = savedZoomMax
    end)
    if camera then pcall(function() camera.FieldOfView = fovOriginal end) end
    pcall(restoreLighting)
    pcall(function() gui:Destroy() end)
    getgenv().SleepScript = nil
end

getgenv().SleepScript = { Unload = unload, Settings = S }
notify("SleepScript загружен. RightShift — меню")
if not (hookedIndex or hookedNamecall) then
    notify("Хуки недоступны — работает только запись свойства")
end
logFile("loaded on " .. game.JobId)

end)

if not booted then
    warn("[SleepScript] ошибка запуска: " .. tostring(bootErr))
end
