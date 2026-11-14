
local CONFIG = {
    ScriptURL   = "",                                  -- RAW-ссылка на файл (для переинжекта после хопа)
    Accent      = Color3.fromRGB(122, 92, 255),
    AccentDark  = Color3.fromRGB(64, 46, 150),
    Keybind     = Enum.KeyCode.RightShift,
    DetectGrace = 20,
    LogOnly     = false,
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
local Workspace         = cloneref(workspace)
local lp                = Players.LocalPlayer

if not Drawing then
    return warn("[SleepScript] нет Drawing API — ESP не запустится.")
end

local camera = Workspace.CurrentCamera
local fovOriginal = camera and camera.FieldOfView or 70
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then
        camera = Workspace.CurrentCamera
        fovOriginal = camera.FieldOfView
    end
end)

--==============================================================
--  СОСТОЯНИЕ
--==============================================================
local S = {
    paranoid      = false,
    adaptive      = true,
    espEnabled    = false,
    box           = true,
    name          = true,
    health        = true,
    distance      = true,
    tracer        = false,
    skeleton      = false,
    teamCheck     = true,
    showLocal     = false,
    fovCircle     = false,
    fovRadius     = 240,
    aimFov        = true,
    maxDist       = 600,
    fovEnabled    = false,
    fovValue      = 90,
    fovSmooth     = true,
    watchEnabled  = true,
    autoRejoin    = true,
    rejoinDelay   = 1.5,
    banCount      = 0,
    lastReason    = "—",
}

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

local main = new("Frame", {
    Size = UDim2.fromOffset(486, 348),
    Position = UDim2.new(0.5, -243, 0.5, -174),
    BackgroundColor3 = Color3.fromRGB(13, 15, 20),
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, main)
new("UIStroke", { Color = CONFIG.Accent, Thickness = 1, Transparency = 0.55 }, main)

local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = Color3.fromRGB(20, 18, 34),
    BorderSizePixel = 0,
}, main)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, header)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = Color3.fromRGB(20, 18, 34), BorderSizePixel = 0,
}, header)
local grad = new("UIGradient", {
    Color = ColorSequence.new(CONFIG.Accent, CONFIG.AccentDark),
    Rotation = 25,
}, header)
grad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.82),
    NumberSequenceKeypoint.new(1, 1),
})

new("TextLabel", {
    Text = "SleepScript",
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(16, 9),
    Size = UDim2.fromOffset(240, 22),
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

new("TextLabel", {
    Text = "counter blox  •  drawing-only esp  •  rac watch  •  fov",
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = Color3.fromRGB(150, 150, 175),
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(17, 31),
    Size = UDim2.fromOffset(320, 14),
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

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
        Position = UDim2.new(1, x, 0, 16),
        Size = UDim2.fromOffset(22, 22),
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
    end
end))
track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

local sidebar = new("Frame", {
    Size = UDim2.new(0, 116, 1, -54),
    Position = UDim2.fromOffset(0, 54),
    BackgroundColor3 = Color3.fromRGB(16, 17, 23),
    BorderSizePixel = 0,
}, main)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, sidebar)

local content = new("Frame", {
    Size = UDim2.new(1, -116, 1, -54),
    Position = UDim2.fromOffset(116, 54),
    BackgroundTransparency = 1,
}, main)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }, content)

local pages, tabs = {}, {}
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
    tabs[key] = b
    b.MouseButton1Click:Connect(function()
        for k, p in pairs(pages) do p.Visible = (k == key) end
        for k, t in pairs(tabs) do
            t.TextColor3 = (k == key) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 170)
            t.BackgroundColor3 = (k == key) and CONFIG.AccentDark or Color3.fromRGB(22, 23, 32)
        end
    end)
    return b
end

local function section(parent, text)
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
    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 5), Position = UDim2.fromOffset(0, 26),
        BackgroundColor3 = Color3.fromRGB(40, 40, 54), BorderSizePixel = 0,
    }, holder)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = new("Frame", {
        Size = UDim2.fromScale((default - min) / (max - min), 1),
        BackgroundColor3 = CONFIG.Accent, BorderSizePixel = 0,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

    local value = default
    local function apply(px)
        local rel = math.clamp((px - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        value = math.floor(min + rel * (max - min) + 0.5)
        fill.Size = UDim2.fromScale(rel, 1)
        valueLabel.Text = tostring(value)
        cb(value)
    end
    track.InputBegan:Connect(function(i)
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

--==============================================================
--  ESP + FOV
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
        box = sq(false), boxFill = sq(true),
        hpBg = sq(true), hp = sq(true),
        marker = sq(false),
        name = Drawing.new("Text"), dist = Drawing.new("Text"),
        tracer = Drawing.new("Line"),
        bones = {},
    }
    rec.name.Center = true; rec.name.Outline = true; rec.name.Font = FONT
    rec.name.Size = 13; rec.name.OutlineColor = Color3.fromRGB(0, 0, 0)
    rec.dist.Center = true; rec.dist.Outline = true; rec.dist.Font = FONT
    rec.dist.Size = 12; rec.dist.OutlineColor = Color3.fromRGB(0, 0, 0)
    rec.tracer.Thickness = 1
    rec.boxFill.Transparency = 0.9
    rec.marker.Thickness = 2
    rec.marker.Color = CONFIG.Accent
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
        if k == "bones" then
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

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Color = CONFIG.Accent
fovCircle.Transparency = 0.55
fovCircle.Visible = false

local targetMarker = sq(false)
targetMarker.Thickness = 2
targetMarker.Color = CONFIG.Accent

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
local fovRestoring = false

local function accentColor(player, visible)
    if player.Team and player.Team == lp.Team then
        return Color3.fromRGB(120, 210, 255)
    end
    return visible and Color3.fromRGB(235, 235, 245) or Color3.fromRGB(150, 150, 165)
end

local function frameUpdate(dt)
    -- === FOV камеры ===
    if camera then
        if S.fovEnabled then
            fovRestoring = true
            if S.fovSmooth then
                local cur = camera.FieldOfView
                camera.FieldOfView = cur + (S.fovValue - cur) * math.min(dt * 10, 1)
            else
                camera.FieldOfView = S.fovValue
            end
        elseif fovRestoring then
            local cur = camera.FieldOfView
            local nxt = cur + (fovOriginal - cur) * math.min(dt * 10, 1)
            if math.abs(nxt - fovOriginal) < 0.15 then
                camera.FieldOfView = fovOriginal
                fovRestoring = false
            else
                camera.FieldOfView = nxt
            end
        end
    end

    if not S.espEnabled or not camera then
        fovCircle.Visible = false
        targetMarker.Visible = false
        return
    end

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

    if S.fovCircle then
        fovCircle.Position = Vector2.new(cx, cy)
        fovCircle.Radius = S.fovRadius
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end

    local bestPos, bestSize, bestD = nil, nil, S.fovRadius

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

                if onTop and onBot and sTop.Z > 0 and sBot.Z > 0 and sBot.Y > sTop.Y then
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
                    local col = accentColor(player, visState[player] ~= false)

                    if S.box then
                        rec.box.Color = col
                        rec.box.Position = Vector2.new(x, y)
                        rec.box.Size = Vector2.new(w, h)
                        rec.box.Visible = true
                        rec.boxFill.Color = col
                        rec.boxFill.Position = Vector2.new(x, y)
                        rec.boxFill.Size = Vector2.new(w, h)
                        rec.boxFill.Visible = true
                    else
                        rec.box.Visible = false; rec.boxFill.Visible = false
                    end

                    if S.health then
                        local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        rec.hpBg.Position = Vector2.new(x - 6, y)
                        rec.hpBg.Size = Vector2.new(3, h)
                        rec.hpBg.Color = Color3.fromRGB(25, 25, 32)
                        rec.hpBg.Visible = true
                        rec.hp.Position = Vector2.new(x - 6, y + h * (1 - frac))
                        rec.hp.Size = Vector2.new(3, h * frac)
                        rec.hp.Color = Color3.fromRGB(90, 220, 120):Lerp(Color3.fromRGB(230, 70, 70), 1 - frac)
                        rec.hp.Visible = true
                    else
                        rec.hp.Visible = false; rec.hpBg.Visible = false
                    end

                    if S.name then
                        rec.name.Text = player.Name
                        rec.name.Color = col
                        rec.name.Position = Vector2.new(x + w / 2, y - 16)
                        rec.name.Visible = true
                    else
                        rec.name.Visible = false
                    end

                    if S.distance then
                        rec.dist.Text = string.format("%d m", math.floor(dist / 3.5))
                        rec.dist.Color = col
                        rec.dist.Position = Vector2.new(x + w / 2, y + h + 2)
                        rec.dist.Visible = true
                    else
                        rec.dist.Visible = false
                    end

                    if S.tracer then
                        rec.tracer.From = Vector2.new(cx, vp.Y)
                        rec.tracer.To = Vector2.new(x + w / 2, y + h)
                        rec.tracer.Color = col
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
                                    line.Visible = true
                                elseif line then
                                    line.Visible = false
                                end
                            end
                        end
                    else
                        for _, l in ipairs(rec.bones) do l.Visible = false end
                    end

                    if S.aimFov then
                        local px, py = x + w / 2, y + h / 2
                        local d = math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
                        if d < bestD then
                            bestD, bestPos, bestSize = d, Vector2.new(px, py), Vector2.new(w, h)
                        end
                    end
                else
                    hide(rec)
                end
            else
                hide(rec)
            end
        else
            hide(rec)
        end
    end

    if bestPos then
        targetMarker.Position = bestPos - bestSize / 2 - Vector2.new(3, 3)
        targetMarker.Size = bestSize + Vector2.new(6, 6)
        targetMarker.Visible = true
    else
        targetMarker.Visible = false
    end
end

local espAccum = 0
track(RunService.RenderStepped:Connect(function(dt)
    espAccum += dt
    if espAccum < lastInterval then return end
    espAccum = 0
    if S.espEnabled or S.fovEnabled or fovRestoring then
        pcall(frameUpdate, dt)
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
local watchPage  = page("watch");  tabButton("Автобан", "watch")
local miscPage   = page("misc");   tabButton("Прочее", "misc")

section(visualPage, "esp")
toggle(visualPage, "Включить ESP", false, function(v) S.espEnabled = v end)
toggle(visualPage, "Боксы", true, function(v) S.box = v end)
toggle(visualPage, "Ник", true, function(v) S.name = v end)
toggle(visualPage, "Полоска HP", true, function(v) S.health = v end)
toggle(visualPage, "Дистанция", true, function(v) S.distance = v end)
toggle(visualPage, "Трассеры", false, function(v) S.tracer = v end)
toggle(visualPage, "Скелет", false, function(v) S.skeleton = v end)

section(visualPage, "fov")
toggle(visualPage, "Изменить FOV камеры", false, function(v)
    if v then fovOriginal = camera and camera.FieldOfView or 70 end
    S.fovEnabled = v
end)
slider(visualPage, "Значение FOV", 70, 120, 90, function(v) S.fovValue = v end)
toggle(visualPage, "Плавный переход", true, function(v) S.fovSmooth = v end)
toggle(visualPage, "Круг FOV", false, function(v) S.fovCircle = v end)
slider(visualPage, "Радиус FOV", 60, 500, 240, function(v) S.fovRadius = v end)
toggle(visualPage, "Метка цели в FOV", true, function(v) S.aimFov = v end)

section(visualPage, "фильтры")
toggle(visualPage, "Игнорировать союзников", true, function(v) S.teamCheck = v end)
toggle(visualPage, "Показывать себя", false, function(v) S.showLocal = v end)
slider(visualPage, "Макс. дистанция (студы)", 100, 2000, 600, function(v) S.maxDist = v end)

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
    S.fovCircle = false
    S.fovEnabled = false
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
end))

track(UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == CONFIG.Keybind then main.Visible = not main.Visible end
end))

main.Position = UDim2.new(0.5, -243, 0.5, -164)
TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -243, 0.5, -174),
}):Play()

pages.visual.Visible = true
tabs.visual.TextColor3 = Color3.fromRGB(255, 255, 255)
tabs.visual.BackgroundColor3 = CONFIG.AccentDark

--==============================================================
--  ВЫГРУЗКА
--==============================================================
local function unload()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for player in pairs(ESP.objects) do unbindPlayer(player) end
    pcall(function() fovCircle:Remove() end)
    pcall(function() targetMarker:Remove() end)
    if camera then pcall(function() camera.FieldOfView = fovOriginal end) end
    pcall(function() gui:Destroy() end)
    getgenv().SleepScript = nil
end

getgenv().SleepScript = { Unload = unload, Settings = S }
notify("SleepScript загружен. RightShift — меню")
logFile("loaded on " .. game.JobId)

end)

if not booted then
    warn("[SleepScript] ошибка запуска: " .. tostring(bootErr))
end
