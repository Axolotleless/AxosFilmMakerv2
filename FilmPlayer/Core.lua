local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer
for _ = 1, 300 do
    if lp then
        break
    end
    task.wait(0.1)
    lp = Players.LocalPlayer
end
local playerGui = lp:WaitForChild("PlayerGui")
local PK, Player, KFS, AFP = _G.AFMCodec, _G.AFMEngine, _G.AFMKFS, _G.AFP
for _ = 1, 300 do
    if PK and Player and KFS and AFP then
        break
    end
    task.wait(0.1)
    PK, Player, KFS, AFP = _G.AFMCodec, _G.AFMEngine, _G.AFMKFS, _G.AFP
end
if not (PK and Player and KFS and AFP) then
    warn("bruh")
    return
end
local old = playerGui:FindFirstChild("AFMPlayerUI")
if old then
    old:Destroy()
end
local gui = Instance.new("ScreenGui")
gui.Name = "AFMPlayerUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = playerGui
local touch = UserInputService.TouchEnabled
local GB, GM = Enum.Font.GothamBold, Enum.Font.GothamMedium
local C = {
BG = Color3.fromRGB(18, 20, 26),
PANEL = Color3.fromRGB(28, 31, 40),
PANEL2 = Color3.fromRGB(36, 40, 52),
BTN = Color3.fromRGB(44, 49, 62),
ACCENT = Color3.fromRGB(86, 140, 255),
GOOD = Color3.fromRGB(40, 150, 80),
BAD = Color3.fromRGB(170, 55, 55),
TEXT = Color3.fromRGB(236, 239, 245),
DIM = Color3.fromRGB(150, 158, 175),
LINE = Color3.fromRGB(60, 66, 84),
}
local BH = touch and 34 or 26
local TS = touch and 15 or 13
local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        o[k] = v
    end
    o.Parent = parent
    return o
end
local logLines = {}
local logLabel
local toast = make("TextLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(460, 30), BackgroundColor3 = C.PANEL, BorderSizePixel = 0, Text = "", TextColor3 = C.TEXT, Font = GM, TextSize = TS, Visible = false, ZIndex = 200}, gui)
make("UIStroke", {Color = C.LINE, Thickness = 1}, toast)
make("UISizeConstraint", {MaxSize = Vector2.new(9999, 9999)}, toast)
local toastId = 0
local function say(text, secs)
    toastId = toastId + 1
    local id = toastId
    toast.Text = tostring(text)
    toast.Visible = true
    logLines[#logLines + 1] = tostring(text)
    if #logLines > 200 then
        table.remove(logLines, 1)
    end
    if logLabel then
        logLabel.Text = table.concat(logLines, "\n")
    end
    task.delay(secs or 5, function()
        if toastId == id then
            toast.Visible = false
        end
    end)
end
local sel = nil
local targetModel = nil
local targetMode = "film"
local pickKind = "touch"
local pickOnce = false
local wins = {}
local refresh = {}
local function newWin(key, title, x, y, w, h)
    local vp = gui.AbsoluteSize
    local ww = math.min(w, vp.X - 16)
    local hh = math.min(h, vp.Y - 140)
    local f = make("Frame", {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(ww, hh), BackgroundColor3 = C.PANEL, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 20}, gui)
    make("UIStroke", {Color = C.LINE, Thickness = 1}, f)
    local tb = make("TextButton", {Size = UDim2.new(1, -BH, 0, BH), BackgroundColor3 = C.PANEL2, BorderSizePixel = 0, Text = "  " .. title, TextColor3 = C.TEXT, Font = GB, TextSize = TS, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, ZIndex = 21}, f)
    local xb = make("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(BH, BH), BackgroundColor3 = C.BAD, BorderSizePixel = 0, Text = "X", TextColor3 = C.TEXT, Font = GB, TextSize = TS, ZIndex = 21}, f)
    xb.MouseButton1Click:Connect(function()
        f.Visible = false
    end)
    local body = make("ScrollingFrame", {Position = UDim2.fromOffset(0, BH), Size = UDim2.new(1, 0, 1, -BH), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21}, f)
    make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, body)
    make("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, body)
    local drag, off = false, Vector2.new()
    tb.InputBegan:Connect(function(i)
        local t = i.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            drag = true
            off = Vector2.new(i.Position.X, i.Position.Y) - f.AbsolutePosition
            f.ZIndex = 20
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local p = Vector2.new(i.Position.X, i.Position.Y) - off
            f.Position = UDim2.fromOffset(p.X, p.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        local t = i.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            drag = false
        end
    end)
    wins[key] = f
    return f, body
end
local order = 0
local function nextOrder()
    order = order + 1
    return order
end
local function btn(parent, text, cb, color)
    local b = make("TextButton", {Size = UDim2.new(1, 0, 0, BH), BackgroundColor3 = color or C.BTN, BorderSizePixel = 0, Text = text, TextColor3 = C.TEXT, Font = GM, TextSize = TS, AutoButtonColor = true, LayoutOrder = nextOrder(), ZIndex = 22}, parent)
    if cb then
        b.MouseButton1Click:Connect(cb)
    end
    return b
end
local function label(parent, text, color)
    return make("TextLabel", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = text, TextColor3 = color or C.DIM, Font = GM, TextSize = TS, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = nextOrder(), ZIndex = 22}, parent)
end
local function input(parent, placeholder)
    local t = make("TextBox", {Size = UDim2.new(1, 0, 0, BH), BackgroundColor3 = C.PANEL2, BorderSizePixel = 0, Text = "", PlaceholderText = placeholder, PlaceholderColor3 = C.DIM, TextColor3 = C.TEXT, Font = GM, TextSize = TS, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(), ZIndex = 22}, parent)
    make("UIPadding", {PaddingLeft = UDim.new(0, 8)}, t)
    return t
end
local function clearList(frame)
    for _, c in ipairs(frame:GetChildren()) do
        if c:IsA("GuiObject") then
            c:Destroy()
        end
    end
end
local function section(parent, text)
    local l = label(parent, text, C.TEXT)
    l.Font = GB
    return l
end
local function listHolder(parent)
    local h = make("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder(), ZIndex = 22}, parent)
    make("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, h)
    return h
end
local RELAY_PLACE_ID = 95963476979579
local function packetFor(name)
    local entry = AFP.library[name]
    if not entry then
        return nil
    end
    if entry.packet then
        return entry.packet
    end
    local pk = PK.encode(entry.data, entry.name)
    entry.packet = pk
    return pk
end
local function sendToRelay()
    if not sel then
        say("Pick something in the Library first.")
        return
    end
    local pk = packetFor(sel)
    if not pk then
        say("Could not pack that item.")
        return
    end
    say("Teleporting to Relay...", 20)
    local ok = pcall(function()
        TeleportService:Teleport(RELAY_PLACE_ID, lp, pk)
    end)
    if not ok then
        local ok2, err2 = pcall(function()
            local opts = Instance.new("TeleportOptions")
            opts:SetTeleportData(pk)
            TeleportService:TeleportAsync(RELAY_PLACE_ID, {lp}, opts)
        end)
        if not ok2 then
            say("This game does not let scripts teleport: " .. tostring(err2), 10)
        end
    end
end
TeleportService.TeleportInitFailed:Connect(function(plr, result, message)
    if plr == lp then
        say("Teleport failed: " .. tostring(message), 8)
    end
end)
local function targetText()
    if targetMode == "film" then
        return "Film rigs (the rigs saved in the film)"
    elseif targetMode == "self" then
        return "My character"
    end
    return "Model: " .. (targetModel and targetModel.Name or "none")
end
local function activeTarget()
    if targetMode == "self" then
        return lp.Character
    elseif targetMode == "model" then
        return targetModel
    end
    return nil
end
local function selectItem(name)
    sel = name
    for _, fn in pairs(refresh) do
        fn()
    end
end
local function addItem(source, name)
    local entry, why = AFP.add(source, name)
    if not entry then
        say("Could not add: " .. tostring(why), 8)
        return nil
    end
    say("Added " .. entry.name .. " (" .. (entry.kind == "kfs" and "KeyframeSequence" or "film") .. ")")
    selectItem(entry.name)
    return entry
end
local libF, libB = newWin("lib", "LIBRARY", 12, 52, 300, 420)
local itemF, itemB = newWin("item", "ITEM", 324, 52, 290, 460)
local tgtF, tgtB = newWin("tgt", "TARGET", 12, 90, 280, 260)
local trgF, trgB = newWin("trg", "TRIGGERS", 300, 70, 300, 480)
local logF, logB = newWin("log", "LOG", 12, 110, 340, 260)
order = 0
btn(libB, "Scan for KeyframeSequences", function()
    local n = AFP.importScan()
    say("Found " .. n .. " KeyframeSequence" .. (n == 1 and "" or "s"))
    selectItem(sel)
end)
local pasteBox = input(libB, "paste packet text here")
btn(libB, "Load pasted packet", function()
    local text = pasteBox.Text
    if #text < 8 then
        say("Paste a packet first.")
        return
    end
    say("Decoding...", 20)
    local data, rep = PK.decodeLoose(text, function(m)
        print("AFP> " .. tostring(m))
    end)
    if not data then
        say("Could not open it: " .. tostring(rep), 8)
        return
    end
    if type(rep) == "table" and rep.repaired then
        say("The packet was damaged and has been repaired")
    end
    pasteBox.Text = ""
    addItem(data)
end)
section(libB, "ITEMS")
local libList = listHolder(libB)
refresh.lib = function()
    clearList(libList)
    if #AFP.order == 0 then
        label(libList, "Nothing loaded yet. Scan for KeyframeSequences, paste a packet, or arrive from Relay.")
    end
    for _, name in ipairs(AFP.order) do
        local e = AFP.library[name]
        local tag = e.kind == "kfs" and "KFS " or "FILM "
        local b = make("TextButton", {Size = UDim2.new(1, 0, 0, BH), BackgroundColor3 = name == sel and C.ACCENT or C.BTN, BorderSizePixel = 0, Text = " " .. tag .. name, TextColor3 = C.TEXT, Font = GM, TextSize = TS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22}, libList)
        b.MouseButton1Click:Connect(function()
            selectItem(name)
        end)
    end
end
order = 0
local itemInfo = label(itemB, "")
btn(itemB, "Play with film rigs and camera", function()
    if not sel then
        return
    end
    local ok, why = AFP.play(sel, {camera = true})
    if not ok then
        say("Could not play: " .. tostring(why), 8)
    end
end, C.GOOD)
btn(itemB, "Play on target", function()
    local tg = activeTarget()
    if not sel or not tg then
        say("Choose a target model first (Target window).")
        return
    end
    local ok, why = AFP.play(sel, {target = tg, camera = true})
    if not ok then
        say("Could not play: " .. tostring(why), 8)
    end
end)
btn(itemB, "Play on target, no camera", function()
    local tg = activeTarget()
    if not sel or not tg then
        say("Choose a target model first (Target window).")
        return
    end
    local ok, why = AFP.play(sel, {target = tg, camera = false})
    if not ok then
        say("Could not play: " .. tostring(why), 8)
    end
end)
btn(itemB, "Animate target (emote, Animator)", function()
    local tg = activeTarget() or lp.Character
    if not sel or not tg then
        say("No target and no character.")
        return
    end
    local track, why = AFP.animate(tg, sel, {looped = false})
    if not track then
        say("Could not animate: " .. tostring(why), 8)
    else
        say("Playing as an animation on " .. tg.Name)
    end
end)
local sceneB, vfxB
sceneB = btn(itemB, "Scene and lighting: on", function()
    Player.options.scene = not Player.options.scene
    sceneB.Text = "Scene and lighting: " .. (Player.options.scene and "on" or "off")
    sceneB.BackgroundColor3 = Player.options.scene and C.ACCENT or C.BTN
end, C.ACCENT)
vfxB = btn(itemB, "Effects (VFX): on", function()
    Player.options.vfx = not Player.options.vfx
    vfxB.Text = "Effects (VFX): " .. (Player.options.vfx and "on" or "off")
    vfxB.BackgroundColor3 = Player.options.vfx and C.ACCENT or C.BTN
end, C.ACCENT)
btn(itemB, "Stop", function()
    AFP.stop()
end, C.BAD)
section(itemB, "SHARE")
btn(itemB, "Make KeyframeSequence (on the camera)", function()
    if not sel then
        return
    end
    local ks, why = AFP.exportKFS(sel)
    if ks then
        say("Created CurrentCamera." .. ks.Name .. ", ready to copy into a rig or the animation editor")
    else
        say("Could not export: " .. tostring(why), 8)
    end
end)
btn(itemB, "Send to Relay", sendToRelay)
btn(itemB, "Remove from library", function()
    if sel then
        AFP.remove(sel)
        sel = AFP.order[1]
        selectItem(sel)
    end
end)
refresh.item = function()
    local e = sel and AFP.library[sel]
    if not e then
        itemInfo.Text = "No item selected."
        return
    end
    local k = AFP.sequence(sel)
    local s = k and KFS.summary(k) or {bones = 0, keys = 0, cam = 0, markers = 0}
    local film = e.data and e.data.film or {}
    itemInfo.Text = string.format("%s\nType: %s\nLength: %.1fs at %d fps\nBones: %d, keys: %d\nCamera keys: %d, markers: %d\nFilm rigs: %d, animated props: %d\nScene items: %d", e.name, e.kind == "kfs" and "KeyframeSequence" or "Film file", tonumber(film.dur) or 0, tonumber(film.fps) or 30, s.bones, s.keys, s.cam, s.markers, type(film.rigs) == "table" and #film.rigs or 0, type(film.objs) == "table" and #film.objs or 0, e.data and type(e.data.scene) == "table" and #e.data.scene or 0)
end
order = 0
local tgtInfo = label(tgtB, "")
btn(tgtB, "Film rigs (default)", function()
    targetMode = "film"
    targetModel = nil
    refresh.tgt()
end)
btn(tgtB, "My character", function()
    targetMode = "self"
    refresh.tgt()
end)
local picking = false
btn(tgtB, "Pick a model (then click it in the world)", function()
    picking = true
    say("Click any rig or model in the world.", 8)
end)
label(tgtB, "Playing on a target moves that model's joints with the film. Your own character is only changed on your screen.")
refresh.tgt = function()
    tgtInfo.Text = "Current target:\n" .. targetText()
end
local mouse = lp:GetMouse()
mouse.Button1Down:Connect(function()
    if not picking then
        return
    end
    picking = false
    local hit = mouse.Target
    local m = hit and (hit:FindFirstAncestorOfClass("Model") or (hit:IsA("Model") and hit))
    if m then
        for _ = 1, 8 do
            local up = m.Parent and m.Parent:IsA("Model") and m.Parent ~= workspace and m.Parent or nil
            if m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildOfClass("AnimationController") or not up then
                break
            end
            m = up
        end
        targetModel = m
        targetMode = "model"
        say("Target: " .. m.Name)
        refresh.tgt()
    else
        say("That was not part of a model.")
    end
end)
order = 0
local KINDS = {"touch", "proximity", "camera", "key", "chat", "time"}
local HELP = {
touch = "Part path in workspace, for example Map.Door",
proximity = "Part path, then distance, for example Map.Door,12",
camera = "type or subject. Fires when another script takes the camera",
key = "Key name, for example E",
chat = "Chat message that starts it",
time = "Seconds to wait before it starts",
}
local kindBtn
local paramBox
local trgInfo = label(trgB, "")
kindBtn = btn(trgB, "Kind: touch", function()
    local i = 1
    for n, k in ipairs(KINDS) do
        if k == pickKind then
            i = n
        end
    end
    pickKind = KINDS[i % #KINDS + 1]
    kindBtn.Text = "Kind: " .. pickKind
    trgInfo.Text = "Plays the selected item when this happens.\n" .. HELP[pickKind]
    paramBox.PlaceholderText = HELP[pickKind]
end)
paramBox = input(trgB, HELP.touch)
local onceBtn
onceBtn = btn(trgB, "Only once: off", function()
    pickOnce = not pickOnce
    onceBtn.Text = "Only once: " .. (pickOnce and "on" or "off")
    onceBtn.BackgroundColor3 = pickOnce and C.ACCENT or C.BTN
end)
local function resolve(path)
    local cur = workspace
    for part in string.gmatch(path, "[^%.]+") do
        cur = cur and cur:FindFirstChild(part)
    end
    if cur == workspace then
        return nil
    end
    return cur
end
btn(trgB, "Add trigger for selected item", function()
    if not sel then
        say("Pick an item in the Library first.")
        return
    end
    local p = paramBox.Text
    local spec = {kind = pickKind, play = sel, once = pickOnce, name = pickKind .. ": " .. sel, cooldown = 1}
    local tg = activeTarget()
    if tg then
        spec.target = tg
    end
    if pickKind == "touch" or pickKind == "proximity" then
        local path, dist = string.match(p, "^([^,]+),?%s*(%d*)$")
        local part = path and resolve(path)
        if not part or not part:IsA("BasePart") then
            say("Could not find that part in workspace.")
            return
        end
        spec.part = part
        spec.distance = tonumber(dist) or 12
    elseif pickKind == "camera" then
        spec.watch = p == "subject" and "subject" or "type"
    elseif pickKind == "key" then
        if not pcall(function()
            return Enum.KeyCode[p]
        end) or p == "" then
        say("Unknown key name.")
        return
    end
    spec.key = p
elseif pickKind == "chat" then
    spec.text = p
elseif pickKind == "time" then
    spec.after = tonumber(p) or 1
end
local h, why = AFP.trigger(spec)
if h then
    say("Trigger added: " .. spec.name)
    refresh.trg()
else
    say("Could not add: " .. tostring(why))
end
end, C.GOOD)
section(trgB, "ACTIVE TRIGGERS")
local trgList = listHolder(trgB)
refresh.trg = function()
    clearList(trgList)
    if #AFP.triggers == 0 then
        label(trgList, "No triggers yet.")
    end
    for _, spec in ipairs(AFP.triggers) do
        local b = make("TextButton", {Size = UDim2.new(1, 0, 0, BH), BackgroundColor3 = C.BTN, BorderSizePixel = 0, Text = " X  " .. spec.name, TextColor3 = C.TEXT, Font = GM, TextSize = TS, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22}, trgList)
        b.MouseButton1Click:Connect(function()
            spec.Destroy()
            refresh.trg()
        end)
    end
end
trgInfo.Text = "Plays the selected item when this happens.\n" .. HELP.touch
order = 0
logLabel = label(logB, table.concat(logLines, "\n"))
btn(logB, "Clear", function()
    logLines = {}
    logLabel.Text = ""
end)
local barH = BH + 8
local bar = make("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, barH * 2 + 6), BackgroundColor3 = C.BG, BorderSizePixel = 0, Active = true, ZIndex = 100}, gui)
make("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.LINE, BorderSizePixel = 0, ZIndex = 101}, bar)
local row1 = make("Frame", {Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, barH), BackgroundTransparency = 1, ZIndex = 101}, bar)
local row2 = make("Frame", {Position = UDim2.fromOffset(0, barH + 3), Size = UDim2.new(1, 0, 0, barH), BackgroundTransparency = 1, ZIndex = 101}, bar)
for _, r in ipairs({row1, row2}) do
    make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, r)
    make("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, r)
end
local bo = 0
local function bbtn(parent, text, w, cb)
    bo = bo + 1
    local b = make("TextButton", {Size = UDim2.fromOffset(w, BH), BackgroundColor3 = C.BTN, BorderSizePixel = 0, Text = text, TextColor3 = C.TEXT, Font = GM, TextSize = TS, LayoutOrder = bo, ZIndex = 102}, parent)
    if cb then
        b.MouseButton1Click:Connect(cb)
    end
    return b
end
local function bdiv(parent)
    bo = bo + 1
    make("Frame", {Size = UDim2.fromOffset(1, BH - 8), BackgroundColor3 = C.LINE, BorderSizePixel = 0, LayoutOrder = bo, ZIndex = 102}, parent)
end
local function toggleWin(key)
    local w = wins[key]
    w.Visible = not w.Visible
    if w.Visible then
        for _, fn in pairs(refresh) do
            fn()
        end
    end
end
local btnW = touch and 84 or 72
bbtn(row1, "Library", btnW, function()
    toggleWin("lib")
end)
bbtn(row1, "Item", btnW, function()
    toggleWin("item")
end)
bbtn(row1, "Target", btnW, function()
    toggleWin("tgt")
end)
bbtn(row1, "Triggers", btnW + 10, function()
    toggleWin("trg")
end)
bbtn(row1, "Log", btnW - 20, function()
    toggleWin("log")
end)
bdiv(row1)
bbtn(row1, "Relay", btnW, sendToRelay)
bbtn(row1, "Hide", btnW - 14, function()
    bar.Visible = false
    say("Press H to bring the bar back", 4)
end)
local playB = bbtn(row2, "Play", btnW - 10, function()
    if Player.playing then
        Player.pause()
    else
        Player.play()
    end
end)
bbtn(row2, "Start", btnW - 16, function()
    Player.seek(0)
end)
local fixed = (btnW - 10) + (btnW - 16) + (btnW - 26) * 3 + (touch and 90 or 80) + 6 * 4 + 12
bo = bo + 1
local track = make("TextButton", {Size = UDim2.new(1, -fixed, 0, BH), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = bo, ZIndex = 102}, row2)
local rail = make("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.BTN, BorderSizePixel = 0, ZIndex = 102}, track)
local fill = make("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.ACCENT, BorderSizePixel = 0, ZIndex = 103}, rail)
bo = bo + 1
local timeL = make("TextLabel", {Size = UDim2.fromOffset(touch and 90 or 80, BH), BackgroundTransparency = 1, Text = "0.0 / 0.0", TextColor3 = C.DIM, Font = GM, TextSize = TS - 1, LayoutOrder = bo, ZIndex = 102}, row2)
local loopB = bbtn(row2, "Loop", btnW - 26, function()
    Player.loop = not Player.loop
end)
local speedB = bbtn(row2, "1x", btnW - 26, nil)
local camB = bbtn(row2, "Cam", btnW - 26, function()
    Player.setCamera(not Player.camOn)
end)
local speeds = {0.25, 0.5, 1, 2}
local si = 3
speedB.MouseButton1Click:Connect(function()
    si = si % #speeds + 1
    Player.speed = speeds[si]
end)
local dragging = false
local function seekFrom(x)
    local w = track.AbsoluteSize.X
    if w > 0 then
        Player.seek(math.clamp((x - track.AbsolutePosition.X) / w, 0, 1) * Player.dur)
    end
end
track.InputBegan:Connect(function(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        dragging = true
        seekFrom(i.Position.X)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        seekFrom(i.Position.X)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    local t = i.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputBegan:Connect(function(i, processed)
    if not processed and i.KeyCode == Enum.KeyCode.H then
        bar.Visible = true
    end
end)
local prevTick = Player.onTick
Player.onTick = function()
    if prevTick then
        prevTick()
    end
    playB.Text = Player.playing and "Pause" or "Play"
    timeL.Text = string.format("%.1f / %.1f", Player.t, Player.dur)
    fill.Size = UDim2.fromScale(Player.dur > 0 and math.clamp(Player.t / Player.dur, 0, 1) or 0, 1)
    loopB.BackgroundColor3 = Player.loop and C.ACCENT or C.BTN
    camB.BackgroundColor3 = Player.camOn and C.ACCENT or C.BTN
    speedB.Text = (Player.speed == 0.25 and "1/4x") or (Player.speed == 0.5 and "1/2x") or (Player.speed .. "x")
end
AFP.on("marker", function(n, v)
    say("Marker: " .. tostring(n) .. (v ~= "" and (" = " .. tostring(v)) or ""), 3)
end)
AFP.on("trigger", function(n)
    say("Trigger fired: " .. tostring(n), 3)
end)
AFP.on("added", function()
    if refresh.lib then
        refresh.lib()
    end
end)
local function openPacket(pk)
    say("Decoding film...", 30)
    local entry = addItem(pk)
    if not entry then
        return false
    end
    local ok, why = AFP.play(entry.name, {autoplay = false})
    if not ok then
        say("Could not load: " .. tostring(why), 8)
        return false
    end
    Player.packet = pk
    return true
end
local modCount = 0
local function addButton(text, fn)
    modCount = modCount + 1
    local b = bbtn(row1, text, btnW + 10, function()
        local ok, err = pcall(fn)
        if not ok then
            say("Mod button " .. text .. ": " .. tostring(err), 8)
        end
    end)
    b.LayoutOrder = 100 + modCount
    return b
end
local winCount = 0
local function addWindow(title, w, h, build)
    winCount = winCount + 1
    local key = "mod" .. winCount
    local f, body = newWin(key, string.upper(title), 40 + winCount * 24, 80 + winCount * 18, w or 280, h or 300)
    local kit = {btn = btn, label = label, input = input, section = section, say = say, colors = C}
    order = 0
    local ok, err = pcall(build, body, kit, f)
    if not ok then
        say("Mod window " .. title .. ": " .. tostring(err), 8)
    end
    local b = addButton(title, function()
        toggleWin(key)
    end)
    return f, b
end
_G.AFMPlayer = {addButton = addButton, addWindow = addWindow, addRefresh = function(fn)
    refresh["mod" .. tostring(fn)] = fn
end, open = openPacket, player = Player, codec = PK, kfs = KFS, afp = AFP, sendBack = sendToRelay, say = say}
for _, fn in pairs(refresh) do
    fn()
end
local pk
pcall(function()
    local td = TeleportService:GetLocalPlayerTeleportData()
    if type(td) == "table" and td.afm == 1 then
        pk = td
    end
end)
if not pk and type(_G.AFM_PACKET) == "table" then
    pk = _G.AFM_PACKET
end
if pk then
    task.spawn(function()
        if openPacket(pk) then
            wins.item.Visible = true
            refresh.item()
        end
    end)
else
    wins.lib.Visible = true
    say("AFP ready. Open Library to scan for KeyframeSequences or paste a packet.", 8)
end
