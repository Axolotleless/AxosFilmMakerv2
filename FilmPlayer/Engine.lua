local Player = {t = 0, dur = 0, fps = 30, playing = false, speed = 1, loop = false, loaded = false, camOn = true, info = nil, onLoad = nil}
do
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local lp = Players.LocalPlayer
local MAX_KEYS = 400000
local MAX_SCENE = 300
local MAX_FX = 60
local SCENE_OK = {}
for _, c in ipairs({"Part", "Folder", "Model", "Attachment", "PointLight", "SpotLight", "SurfaceLight", "Highlight", "ParticleEmitter", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "Sky", "Sound", "Decal", "Texture", "SpecialMesh", "WedgePart", "CornerWedgePart", "Atmosphere", "BloomEffect", "ColorCorrectionEffect", "BlurEffect", "DepthOfFieldEffect", "SunRaysEffect", "BillboardGui", "SurfaceGui", "Frame", "TextLabel", "ImageLabel", "UICorner", "UIStroke", "UIGradient", "UIListLayout", "UIPadding", "UIAspectRatioConstraint", "ViewportFrame", "Camera", "StringValue"}) do
    SCENE_OK[c] = true
end
local BAD_PROPS = {Parent = true, Name = true, Source = true, ClassName = true, Archivable = true, Script = true}
local folder, state, cc, overlay, barTop, barBot, vigs
local listeners = {}
Player.targets = {}
Player.options = {scene = true, vfx = true}
function Player.on(ev, fn)
    listeners[ev] = listeners[ev] or {}
    local list = listeners[ev]
    list[#list + 1] = fn
    return function()
        for i = 1, #list do
            if list[i] == fn then
                table.remove(list, i)
                return
            end
        end
    end
end
function Player.emit(ev, a, b, c)
    local list = listeners[ev]
    if not list then
        return
    end
    for i = 1, #list do
        local fn = list[i]
        local ok, err = pcall(fn, a, b, c)
        if not ok then
            warn("AFM player listener " .. tostring(ev) .. ": " .. tostring(err))
        end
    end
end
local CAMERA_BIND = "AFMPlayer"
local function cam()
    return workspace.CurrentCamera
end
local function numbers(a, from, to)
    for i = from, to do
        if type(a[i]) ~= "number" or a[i] ~= a[i] then
            return false
        end
    end
    return true
end
local function cfFrom(c)
    if type(c) == "table" and #c == 12 and numbers(c, 1, 12) then
        return CFrame.new(table.unpack(c))
    end
    return nil
end
local function resolvePath(path)
    if type(path) ~= "table" or #path == 0 then
        return nil
    end
    local cur = game
    for i = 1, #path do
        if type(path[i]) ~= "string" then
            return nil
        end
        cur = cur:FindFirstChild(path[i])
        if not cur then
            return nil
        end
    end
    return cur
end
local function dv(a)
    if type(a) ~= "table" then
        return nil
    end
    local k = a[1]
    if k == "n" and type(a[2]) == "number" then
        return a[2]
    elseif k == "b" then
        return a[2] == 1 or a[2] == true
    elseif k == "s" and type(a[2]) == "string" then
        return a[2]
    elseif k == "c3" and numbers(a, 2, 4) then
        return Color3.new(a[2], a[3], a[4])
    elseif k == "v3" and numbers(a, 2, 4) then
        return Vector3.new(a[2], a[3], a[4])
    elseif k == "v2" and numbers(a, 2, 3) then
        return Vector2.new(a[2], a[3])
    elseif k == "cf" and #a == 13 and numbers(a, 2, 13) then
        return CFrame.new(table.unpack(a, 2, 13))
    elseif k == "u2" and numbers(a, 2, 5) then
        return UDim2.new(a[2], a[3], a[4], a[5])
    elseif k == "ud" and numbers(a, 2, 3) then
        return UDim.new(a[2], a[3])
    elseif k == "nr" and numbers(a, 2, 3) then
        return NumberRange.new(a[2], a[3])
    elseif k == "rc" and #a == 5 and numbers(a, 2, 5) then
        return Rect.new(a[2], a[3], a[4], a[5])
    elseif k == "bc" and type(a[2]) == "string" then
        return BrickColor.new(a[2])
    elseif k == "e" and type(a[2]) == "string" and type(a[3]) == "string" then
        local name = string.match(a[2], "Enum%.(%w+)$") or a[2]
        local ok, v = pcall(function()
            return Enum[name][a[3]]
        end)
        return ok and v or nil
    elseif k == "cs" then
        if type(a[2]) == "table" then
            local pts = {}
            for i = 2, math.min(#a, 21) do
                local q = a[i]
                if type(q) == "table" and numbers(q, 1, 4) then
                    pts[#pts + 1] = ColorSequenceKeypoint.new(math.clamp(q[1], 0, 1), Color3.new(q[2], q[3], q[4]))
                end
            end
            if #pts >= 2 then
                table.sort(pts, function(x, y)
                    return x.Time < y.Time
                end)
                pts[1] = ColorSequenceKeypoint.new(0, pts[1].Value)
                pts[#pts] = ColorSequenceKeypoint.new(1, pts[#pts].Value)
                local ok, v = pcall(ColorSequence.new, pts)
                return ok and v or nil
            end
        elseif #a >= 9 and (#a - 1) % 4 == 0 and #a <= 81 and numbers(a, 2, #a) then
            local pts = {}
            for i = 2, #a, 4 do
                pts[#pts + 1] = ColorSequenceKeypoint.new(math.clamp(a[i], 0, 1), Color3.new(a[i + 1], a[i + 2], a[i + 3]))
            end
            table.sort(pts, function(x, y)
                return x.Time < y.Time
            end)
            pts[1] = ColorSequenceKeypoint.new(0, pts[1].Value)
            pts[#pts] = ColorSequenceKeypoint.new(1, pts[#pts].Value)
            local ok, v = pcall(ColorSequence.new, pts)
            return ok and v or nil
        elseif #a == 4 and numbers(a, 2, 4) then
            return ColorSequence.new(Color3.new(a[2], a[3], a[4]))
        end
    elseif k == "ns" then
        if type(a[2]) == "table" then
            local pts = {}
            for i = 2, math.min(#a, 21) do
                local q = a[i]
                if type(q) == "table" and numbers(q, 1, 2) then
                    pts[#pts + 1] = NumberSequenceKeypoint.new(math.clamp(q[1], 0, 1), q[2], tonumber(q[3]) or 0)
                end
            end
            if #pts >= 2 then
                table.sort(pts, function(x, y)
                    return x.Time < y.Time
                end)
                pts[1] = NumberSequenceKeypoint.new(0, pts[1].Value, pts[1].Envelope)
                pts[#pts] = NumberSequenceKeypoint.new(1, pts[#pts].Value, pts[#pts].Envelope)
                local ok, v = pcall(NumberSequence.new, pts)
                return ok and v or nil
            end
        elseif #a >= 7 and (#a - 1) % 3 == 0 and #a <= 61 and numbers(a, 2, #a) then
            local pts = {}
            for i = 2, #a, 3 do
                pts[#pts + 1] = NumberSequenceKeypoint.new(math.clamp(a[i], 0, 1), a[i + 1], a[i + 2])
            end
            table.sort(pts, function(x, y)
                return x.Time < y.Time
            end)
            pts[1] = NumberSequenceKeypoint.new(0, pts[1].Value, pts[1].Envelope)
            pts[#pts] = NumberSequenceKeypoint.new(1, pts[#pts].Value, pts[#pts].Envelope)
            local ok, v = pcall(NumberSequence.new, pts)
            return ok and v or nil
        elseif #a == 2 and type(a[2]) == "number" then
            return NumberSequence.new(a[2])
        end
    end
    return nil
end
local styleCache = {}
local function easeEnum(style, dir)
    local key = tostring(style) .. "|" .. tostring(dir)
    local c = styleCache[key]
    if c == nil then
        local ok, es = pcall(function()
            return Enum.EasingStyle[style]
        end)
        local ok2, ed = pcall(function()
            return Enum.EasingDirection[dir or "Out"]
        end)
        c = (ok and ok2 and es and ed) and {es, ed} or false
        styleCache[key] = c
    end
    return c
end
local function bezier(a, z)
    if type(z) ~= "table" or a <= 0 then
        return a
    end
    if a >= 1 then
        return 1
    end
    local x1, y1, x2, y2 = z[1], z[2], z[3], z[4]
    if not (type(x1) == "number" and type(y1) == "number" and type(x2) == "number" and type(y2) == "number") then
        return a
    end
    local lo, hi, t = 0, 1, a
    for _ = 1, 24 do
        local u = 1 - t
        local x = 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t
        if math.abs(x - a) < 0.00001 then
            break
        end
        if x < a then
            lo = t
        else
            hi = t
        end
        t = (lo + hi) / 2
    end
    local u = 1 - t
    return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t
end
local function ease(a, style, dir, z)
    if style == nil or style == "Linear" then
        return a
    end
    if style == "Constant" then
        return a >= 1 and 1 or 0
    end
    if style == "Bezier" then
        return bezier(a, z)
    end
    local e = easeEnum(style, dir)
    if not e then
        return a
    end
    local ok, v = pcall(function()
        return TweenService:GetValue(a, e[1], e[2])
    end)
    return ok and v or a
end
local function sample(keys, t)
    local n = #keys
    if n == 0 then
        return nil
    end
    if t <= keys[1].time or n == 1 then
        return keys[1], keys[1], 0
    end
    if t >= keys[n].time then
        return keys[n], keys[n], 0
    end
    local lo, hi = 1, n
    for _ = 1, 64 do
        if hi - lo <= 1 then
            break
        end
        local mid = math.floor((lo + hi) / 2)
        if keys[mid].time <= t then
            lo = mid
        else
            hi = mid
        end
    end
    local k1, k2 = keys[lo], keys[hi]
    local span = k2.time - k1.time
    local a = span > 0.000000001 and (t - k1.time) / span or 0
    return k1, k2, ease(a, k2.style, k2.dir, k2.bz)
end
local function lerpVal(a, b, x)
    local ta = typeof(a)
    if ta ~= typeof(b) then
        return a
    end
    if ta == "number" then
        return a + (b - a) * x
    elseif ta == "Color3" or ta == "CFrame" or ta == "Vector3" or ta == "Vector2" or ta == "UDim2" then
        return a:Lerp(b, x)
    elseif ta == "NumberRange" then
        return NumberRange.new(a.Min + (b.Min - a.Min) * x, a.Max + (b.Max - a.Max) * x)
    end
    return x >= 1 and b or a
end
local keyCount = 0
local function buildKeys(list, conv)
    local out = {}
    if type(list) ~= "table" then
        return out
    end
    for _, k in ipairs(list) do
        if type(k) == "table" and type(k.t) == "number" and keyCount < MAX_KEYS then
            local e = conv(k)
            if e ~= nil then
                keyCount = keyCount + 1
                e.time = k.t
                e.style = type(k.s) == "string" and k.s or nil
                e.dir = type(k.d) == "string" and k.d or nil
                e.bz = type(k.z) == "table" and k.z or nil
                out[#out + 1] = e
            end
        end
    end
    table.sort(out, function(a, b)
        return a.time < b.time
    end)
    return out
end
local function newState()
    return {restore = {}, restoreSeen = {}, statics = {}, worldRestored = false, rigs = {}, rigByName = {}, rigByGuid = {}, bones = {}, props = {}, made = {}, fx = {}, screen = {}, camKeys = {}, markers = {}, lastT = 0}
end
local function restoreWorld()
    if not state then
        return
    end
    local list = state.restore
    for i = #list, 1, -1 do
        local r = list[i]
        if r.inst.Parent then
            pcall(function()
                r.inst[r.prop] = r.value
            end)
        end
    end
    state.worldRestored = true
end
local function allowedTarget(inst)
    if typeof(inst) ~= "Instance" or inst == game or inst == workspace then
        return false
    end
    if inst == Lighting or inst:IsDescendantOf(Lighting) then
        return true
    end
    if not inst:IsDescendantOf(workspace) then
        return false
    end
    local cur = inst
    for _ = 1, 40 do
        if not cur or cur == workspace then
            break
        end
        if cur:IsA("Model") and Players:GetPlayerFromCharacter(cur) then
            return false
        end
        cur = cur.Parent
    end
    return true
end
local function remember(inst, prop)
    if not state then
        return
    end
    local seen = state.restoreSeen[inst]
    if not seen then
        seen = {}
        state.restoreSeen[inst] = seen
    end
    if seen[prop] then
        return
    end
    seen[prop] = true
    local ok, v = pcall(function()
        return inst[prop]
    end)
    if ok then
        state.restore[#state.restore + 1] = {inst = inst, prop = prop, value = v}
    end
end
local function destroyAll()
    restoreWorld()
    if folder then
        pcall(function()
            folder:Destroy()
        end)
    end
    folder = nil
    if state then
        for _, inst in pairs(state.made) do
            pcall(function()
                inst:Destroy()
            end)
        end
    end
    state = nil
end
local function ensureFolder()
    if not folder or not folder.Parent then
        folder = Instance.new("Folder")
        folder.Name = "AFMPlay"
        folder.Parent = workspace
    end
    return folder
end
local function makeScreen()
    if overlay then
        return
    end
    cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "AFM_Play_CC"
    cc.Enabled = false
    cc.Parent = Lighting
    overlay = Instance.new("ScreenGui")
    overlay.Name = "AFMPlayOverlay"
    overlay.ResetOnSpawn = false
    overlay.IgnoreGuiInset = true
    overlay.DisplayOrder = 5
    local function frame(props)
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        for k, v in pairs(props) do
            f[k] = v
        end
        f.Parent = overlay
        return f
    end
    barTop = frame({Size = UDim2.new(1, 0, 0, 0)})
    barBot = frame({AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0)})
    vigs = {}
    local function edge(pos, size, anchor, rot)
        local f = frame({Position = pos, Size = size, AnchorPoint = anchor, Visible = false})
        local g = Instance.new("UIGradient")
        g.Rotation = rot
        g.Parent = f
        vigs[#vigs + 1] = f
    end
    edge(UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.3), Vector2.new(0, 0), 90)
    edge(UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.3), Vector2.new(0, 1), -90)
    edge(UDim2.fromScale(0, 0), UDim2.fromScale(0.25, 1), Vector2.new(0, 0), 0)
    edge(UDim2.fromScale(1, 0), UDim2.fromScale(0.25, 1), Vector2.new(1, 0), 180)
    overlay.Parent = lp:WaitForChild("PlayerGui")
end
local function applyScreen(vals)
    if not overlay then
        return
    end
    local fade = math.clamp(vals.fade or 0, 0, 1)
    local flash = math.clamp(vals.flash or 0, 0, 1)
    local bars = math.clamp(vals.bars or 0, 0, 0.4)
    local vig = math.clamp(vals.vig or 0, 0, 1)
    local bright = flash - fade
    cc.Brightness = bright
    cc.Enabled = math.abs(bright) > 0.001
    barTop.Size = UDim2.new(1, 0, bars, 0)
    barBot.Size = UDim2.new(1, 0, bars, 0)
    for _, f in ipairs(vigs) do
        f.Visible = vig > 0.01
        local g = f:FindFirstChildOfClass("UIGradient")
        if g then
            g.Transparency = NumberSequence.new(1 - vig, 1)
        end
    end
end
local function buildScene(list, rigFor)
    local world = workspace:FindFirstChild("AFMWorld")
    if not world then
        world = Instance.new("Folder")
        world.Name = "AFMWorld"
        world.Parent = workspace
    end
    state.world = world
    local creates, props = {}, {}
    for _, it in ipairs(type(list) == "table" and list or {}) do
        if type(it) == "table" and type(it.id) == "string" and type(it.d) == "table" then
            local guid = string.match(it.id, "^s:i([%w]+)|inst$")
            if guid then
                creates[#creates + 1] = {guid = guid, d = it.d}
            else
                props[#props + 1] = it.d
            end
        end
    end
    local function parentOf(spec)
        if type(spec) ~= "table" then
            return world
        end
        if type(spec.g) == "string" then
            return state.made[spec.g]
        end
        local p = resolvePath(spec.p)
        if p then
            return p
        end
        return nil
    end
    local pending = creates
    for _ = 1, 6 do
        local nextPending = {}
        for _, c in ipairs(pending) do
            local cls = c.d.c
            if type(cls) == "string" and SCENE_OK[cls] and (state.madeCount or 0) < MAX_SCENE then
                local par = parentOf(c.d.par)
                if par then
                    local inst = Instance.new(cls)
                    if cls == "Part" then
                        inst.Anchored = true
                        inst.Size = Vector3.new(4, 1, 2)
                    end
                    inst.Name = type(c.d.n) == "string" and string.sub(c.d.n, 1, 60) or cls
                    inst.Parent = par
                    state.made[c.guid] = inst
                    state.madeCount = (state.madeCount or 0) + 1
                else
                    nextPending[#nextPending + 1] = c
                end
            end
        end
        pending = nextPending
        if #pending == 0 then
            break
        end
    end
    for _, c in ipairs(pending) do
        local cls = c.d.c
        if type(cls) == "string" and SCENE_OK[cls] and (state.madeCount or 0) < MAX_SCENE then
            local inst = Instance.new(cls)
            inst.Name = type(c.d.n) == "string" and string.sub(c.d.n, 1, 60) or cls
            inst.Parent = world
            state.made[c.guid] = inst
            state.madeCount = (state.madeCount or 0) + 1
        end
    end
    for _, d in ipairs(props) do
        local made = type(d.g) == "string" and state.made[d.g] or nil
        local inst = made
        if not inst and type(d.p) == "table" and #d.p > 0 then
            local found = resolvePath(d.p)
            if found and allowedTarget(found) then
                inst = found
            end
        end
        if inst and type(d.n) == "string" and not BAD_PROPS[d.n] then
            local v = dv(d.v)
            if v ~= nil then
                if not made then
                    remember(inst, d.n)
                end
                state.statics[#state.statics + 1] = {inst = inst, prop = d.n, value = v}
                pcall(function()
                    if d.n == "Pivot" then
                        if inst:IsA("PVInstance") and typeof(v) == "CFrame" then
                            inst:PivotTo(v)
                        end
                    else
                        inst[d.n] = v
                    end
                end)
            end
        end
    end
end
local function reapplyStatics()
    if not state or not state.worldRestored then
        return
    end
    state.worldRestored = false
    for _, s in ipairs(state.statics) do
        if s.inst.Parent then
            remember(s.inst, s.prop)
            pcall(function()
                if s.prop == "Pivot" then
                    if s.inst:IsA("PVInstance") and typeof(s.value) == "CFrame" then
                        s.inst:PivotTo(s.value)
                    end
                else
                    s.inst[s.prop] = s.value
                end
            end)
        end
    end
end
local function newRig(name, isR15, cf)
    local model
    local tg = Player.targets and (Player.targets[name] or Player.targets["*"])
    if typeof(tg) == "Instance" and tg.Parent then
        return tg, false
    end
    local existing = workspace:FindFirstChild(name, true)
    if existing and existing:IsA("Model") and existing:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(existing) then
        return existing, false
    end
    pcall(function()
        local desc = Players:GetHumanoidDescriptionFromUserId(lp.UserId)
        model = Players:CreateHumanoidModelFromDescription(desc, isR15 and Enum.HumanoidRigType.R15 or Enum.HumanoidRigType.R6)
    end)
    if not model and lp.Character then
        pcall(function()
            lp.Character.Archivable = true
            model = lp.Character:Clone()
        end)
    end
    if not model then
        return nil, false
    end
    model.Name = name
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then
            d:Destroy()
        end
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.PlatformStand = true
    end
    model.Parent = ensureFolder()
    if cf then
        pcall(function()
            model:PivotTo(cf)
        end)
    end
    local rootPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
    if rootPart then
        rootPart.Anchored = true
    end
    return model, true
end
local function findByRel(root, rel)
    local cur = root
    for _, nm in ipairs(rel) do
        if type(nm) ~= "string" then
            return nil
        end
        cur = cur:FindFirstChild(nm)
        if not cur then
            return nil
        end
    end
    return cur
end
local function specModel(js, cf, nm)
    local ok, spec = pcall(function()
        return game:GetService("HttpService"):JSONDecode(js)
    end)
    if not ok or type(spec) ~= "table" or type(spec.p) ~= "table" or #spec.p == 0 or #spec.p > 300 then
        return nil
    end
    local origin = cf or CFrame.new()
    local model = Instance.new("Model")
    model.Name = nm or spec.n or "Rig"
    local parts = {}
    local function v3(t, a, b, c)
        t = type(t) == "table" and t or {}
        return tonumber(t[1]) or a, tonumber(t[2]) or b, tonumber(t[3]) or c
    end
    local function rot(t)
        local x, y, z = v3(t, 0, 0, 0)
        return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
    end
    for i, d in ipairs(spec.p) do
        if type(d) ~= "table" then
            return nil
        end
        local part
        if d.sh == "Wedge" then
            part = Instance.new("WedgePart")
        elseif type(d.ms) == "string" and d.ms ~= "" then
            local okm, mp = pcall(function()
                return game:GetService("AssetService"):CreateMeshPartAsync(d.ms)
            end)
            part = okm and mp or Instance.new("Part")
            if okm and type(d.tx) == "string" and d.tx ~= "" then
                part.TextureID = d.tx
            end
        else
            part = Instance.new("Part")
            if d.sh == "Ball" then
                part.Shape = Enum.PartType.Ball
            elseif d.sh == "Cylinder" then
                part.Shape = Enum.PartType.Cylinder
            end
        end
        part.Name = tostring(d.n)
        local sx, sy, sz = v3(d.s, 1, 1, 1)
        part.Size = Vector3.new(sx, sy, sz)
        local cr, cg, cb = v3(d.c, 163, 162, 165)
        part.Color = Color3.fromRGB(cr, cg, cb)
        part.Transparency = tonumber(d.t) or 0
        part.Material = (d.m and Enum.Material[d.m]) or Enum.Material.SmoothPlastic
        part.CanCollide = false
        part.Anchored = true
        local px, py, pz = v3(d.p, 0, 0, 0)
        part.CFrame = origin * CFrame.new(px, py, pz) * rot(d.r)
        part.Parent = model
        parts[i] = part
        for _, dc in ipairs(type(d.dc) == "table" and d.dc or {}) do
            local o = Instance.new("Decal")
            o.Name = tostring(dc.n)
            o.Texture = tostring(dc.t or "")
            o.Face = Enum.NormalId[dc.f or "Front"] or Enum.NormalId.Front
            o.Transparency = tonumber(dc.tr) or 0
            o.Parent = part
        end
    end
    for i, d in ipairs(spec.p) do
        local q = tonumber(d.q) or 0
        if q > 0 and parts[q] then
            local jx, jy, jz = v3(d.j or d.p, 0, 0, 0)
            local jw = origin * CFrame.new(jx, jy, jz) * rot(d.jr)
            local m = Instance.new("Motor6D")
            m.Name = tostring(d.mn or d.n)
            m.Part0 = parts[q]
            m.Part1 = parts[i]
            m.C0 = parts[q].CFrame:ToObjectSpace(jw)
            m.C1 = parts[i].CFrame:ToObjectSpace(jw)
            m.Parent = parts[i]
        end
    end
    model.PrimaryPart = parts[1]
    if spec.h then
        local hum = Instance.new("Humanoid")
        hum.RigType = spec.rt == "R15" and Enum.HumanoidRigType.R15 or Enum.HumanoidRigType.R6
        hum.PlatformStand = true
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.Parent = model
        Instance.new("Animator").Parent = hum
    end
    return model
end

local function buildRigs(film, rigMeta)
    local meta = {}
    for _, r in ipairs(type(rigMeta) == "table" and rigMeta or {}) do
        if type(r) == "table" and type(r.name) == "string" then
            meta[r.name] = r
        end
    end
    for _, r in ipairs(type(film.rigs) == "table" and film.rigs or {}) do
        if type(r) == "table" and type(r.n) == "string" and type(r.b) == "table" then
            local isR15 = false
            for _, b in ipairs(r.b) do
                local last = type(b.p) == "table" and b.p[#b.p]
                if last == "UpperTorso" or last == "LowerTorso" then
                    isR15 = true
                end
            end
            local m = meta[r.n]
            local cf = m and cfFrom(m.cf) or nil
            local model, created
            local tg = Player.targets and (Player.targets[r.n] or Player.targets["*"])
            if m and type(m.build) == "string" and not (typeof(tg) == "Instance" and tg.Parent) then
                model = specModel(m.build, cf, r.n)
                created = model ~= nil
                if model then
                    model.Parent = ensureFolder()
                end
            end
            if not model then
                model, created = newRig(r.n, isR15, cf)
            end
            if model then
                local entry = {model = model, name = r.n, path = r.p, created = created, bones = {}}
                state.rigs[#state.rigs + 1] = entry
                state.rigByName[r.n] = entry
                if m and type(m.guid) == "string" then
                    state.rigByGuid[m.guid] = entry
                end
                for _, b in ipairs(r.b) do
                    if type(b) == "table" and type(b.p) == "table" then
                        local part = findByRel(model, b.p)
                        if part and part:IsA("BasePart") then
                            local motor
                            if b.m then
                                for _, d in ipairs(model:GetDescendants()) do
                                    if d:IsA("Motor6D") and d.Part1 == part then
                                        motor = d
                                        break
                                    end
                                end
                            end
                            local keys = buildKeys(b.k, function(k)
                                local c = cfFrom(k.c)
                                return c and {pose = c} or nil
                            end)
                            if #keys > 0 and (motor or not b.m) then
                                entry.bones[#entry.bones + 1] = {part = part, motor = motor, keys = keys, base = part.CFrame}
                            end
                        end
                    end
                end
            end
        end
    end
end
local function rigRelative(path)
    if type(path) ~= "table" then
        return nil
    end
    for _, rg in ipairs(state.rigs) do
        local rp = rg.path
        if type(rp) == "table" and #rp > 0 and #path >= #rp then
            local match = true
            for i = 1, #rp do
                if rp[i] ~= path[i] then
                    match = false
                    break
                end
            end
            if match then
                local cur = rg.model
                for i = #rp + 1, #path do
                    cur = cur and cur:FindFirstChild(path[i])
                end
                return cur
            end
        end
    end
    return nil
end
local function buildObjs(film)
    for _, o in ipairs(type(film.objs) == "table" and film.objs or {}) do
        if type(o) == "table" and type(o.props) == "table" then
            local inst = rigRelative(o.p)
            if not inst then
                local found = resolvePath(o.p)
                if found and allowedTarget(found) then
                    inst = found
                end
            end
            if inst then
                for _, pr in ipairs(o.props) do
                    if type(pr) == "table" and type(pr.n) == "string" and not BAD_PROPS[pr.n] then
                        local keys = buildKeys(pr.k, function(k)
                            local v = dv(k.v)
                            return v ~= nil and {value = v} or nil
                        end)
                        if #keys > 0 then
                            remember(inst, pr.n)
                            state.props[#state.props + 1] = {inst = inst, prop = pr.n, keys = keys}
                        end
                    end
                end
            end
        end
    end
end
local function trackList(list)
    local out = {}
    for _, rec in ipairs(type(list) == "table" and list or {}) do
        if type(rec) == "table" and type(rec[1]) == "string" and type(rec[2]) == "table" then
            local keys = {}
            for _, k in ipairs(rec[2]) do
                if type(k) == "table" and type(k[1]) == "number" and keyCount < MAX_KEYS then
                    local v = dv(k[2])
                    if v ~= nil then
                        keyCount = keyCount + 1
                        keys[#keys + 1] = {time = k[1], value = v, style = type(k[3]) == "string" and k[3] or nil, dir = type(k[4]) == "string" and k[4] or nil}
                    end
                end
            end
            table.sort(keys, function(a, b)
                return a.time < b.time
            end)
            if #keys > 0 then
                out[#out + 1] = {prop = rec[1], keys = keys}
            end
        end
    end
    return out
end
local FX_CLASS = {emitter = "ParticleEmitter", beam = "Beam", trail = "Trail", light = "PointLight"}
local function buildVfx(vfx)
    if type(vfx) ~= "table" then
        return
    end
    for _, rec in ipairs(type(vfx.fx) == "table" and vfx.fx or {}) do
        if type(rec) == "table" and FX_CLASS[rec.kind] and #state.fx < MAX_FX then
            local kind = rec.kind
            local need = kind == "beam" and 2 or 1
            local anchors = {}
            for _, ar in ipairs(type(rec.anchors) == "table" and rec.anchors or {}) do
                if type(ar) == "table" and #anchors < need then
                    local a = {cf = cfFrom(ar.cf) or CFrame.new()}
                    if type(ar.follow) == "table" and type(ar.follow[1]) == "string" and type(ar.follow[2]) == "string" then
                        a.follow = {guid = ar.follow[1], bone = ar.follow[2]}
                        a.offset = cfFrom(ar.offset) or CFrame.new()
                    end
                    anchors[#anchors + 1] = a
                end
            end
            for _ = #anchors + 1, need do
                anchors[#anchors + 1] = {cf = CFrame.new(#anchors * 4, 5, 0)}
            end
            local fx = {kind = kind, anchors = anchors, width = math.clamp(tonumber(rec.width) or 1, 0.05, 20)}
            local function part(i)
                local p = Instance.new("Part")
                p.Name = "VFX"
                p.Anchored = true
                p.CanCollide = false
                p.CanQuery = false
                p.CanTouch = false
                p.CastShadow = false
                p.Transparency = 1
                p.Size = Vector3.new(0.5, 0.5, 0.5)
                p.CFrame = anchors[i].cf
                p.Parent = ensureFolder()
                anchors[i].part = p
                return p
            end
            local p1 = part(1)
            local inst
            if kind == "emitter" then
                inst = Instance.new("ParticleEmitter")
                inst.Parent = p1
            elseif kind == "light" then
                inst = Instance.new(rec.lightClass == "SpotLight" and "SpotLight" or "PointLight")
                inst.Parent = p1
            elseif kind == "trail" then
                local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
                a0.Position = Vector3.new(0, fx.width / 2, 0)
                a1.Position = Vector3.new(0, -fx.width / 2, 0)
                a0.Parent, a1.Parent = p1, p1
                inst = Instance.new("Trail")
                inst.Attachment0, inst.Attachment1 = a0, a1
                inst.Parent = p1
            else
                local p2 = part(2)
                local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
                a0.Parent, a1.Parent = p1, p2
                inst = Instance.new("Beam")
                inst.Attachment0, inst.Attachment1 = a0, a1
                inst.Parent = p1
            end
            fx.inst = inst
            for p, enc in pairs(type(rec.props) == "table" and rec.props or {}) do
                if not BAD_PROPS[p] and p ~= "Attachment0" and p ~= "Attachment1" then
                    local v = dv(enc)
                    if v ~= nil then
                        pcall(function()
                            inst[p] = v
                        end)
                    end
                end
            end
            fx.tracks = trackList(rec.tracks)
            fx.bursts = {}
            for _, tr in ipairs(trackList(rec.bursts)) do
                for _, k in ipairs(tr.keys) do
                    if type(k.value) == "number" and k.value > 0 then
                        fx.bursts[#fx.bursts + 1] = {time = k.time, n = math.min(math.floor(k.value), 500)}
                    end
                end
            end
            table.sort(fx.bursts, function(a, b)
                return a.time < b.time
            end)
            state.fx[#state.fx + 1] = fx
        end
    end
    for id, v in pairs(type(vfx.screen) == "table" and vfx.screen or {}) do
        if type(id) == "string" and type(v) == "table" then
            local tracks = trackList(v[2])
            state.screen[id] = {base = tonumber(v[1]) or 0, keys = tracks[1] and tracks[1].keys or {}}
        end
    end
end
local function boneWorld(a)
    if not a.follow then
        return a.cf
    end
    local rg = state.rigByGuid[a.follow.guid]
    if rg then
        local p = rg.model:FindFirstChild(a.follow.bone, true)
        if p and p:IsA("BasePart") then
            return p.CFrame * (a.offset or CFrame.new())
        end
    end
    return a.cf
end
function Player.step(t, playing)
    if not state then
        return
    end
    local prev = state.lastT
    if playing and t >= prev and t - prev < 1 then
        for _, m in ipairs(state.markers) do
            if m.time > prev and m.time <= t then
                Player.emit("marker", m.name, m.value, m.time)
            end
        end
    end
    if #state.camKeys > 0 and Player.camOn then
        local k1, k2, a = sample(state.camKeys, t)
        local c = cam()
        if k1 and c then
            c.CameraType = Enum.CameraType.Scriptable
            if k1 == k2 then
                c.CFrame = k1.pose
                c.FieldOfView = k1.fov or 70
            else
                c.CFrame = k1.pose:Lerp(k2.pose, a)
                c.FieldOfView = (k1.fov or 70) + ((k2.fov or 70) - (k1.fov or 70)) * a
            end
        end
    end
    for _, rg in ipairs(state.rigs) do
        for _, b in ipairs(rg.bones) do
            local k1, k2, a = sample(b.keys, t)
            if k1 then
                local pose = k1 == k2 and k1.pose or k1.pose:Lerp(k2.pose, a)
                if b.motor then
                    b.motor.Transform = pose
                else
                    b.part.CFrame = b.base * pose
                end
            end
        end
    end
    for _, pr in ipairs(state.props) do
        local k1, k2, a = sample(pr.keys, t)
        if k1 and pr.inst.Parent then
            local v = k1 == k2 and k1.value or lerpVal(k1.value, k2.value, a)
            pcall(function()
                pr.inst[pr.prop] = v
            end)
        end
    end
    for _, fx in ipairs(state.fx) do
        for i, a in ipairs(fx.anchors) do
            if a.part then
                a.part.CFrame = boneWorld(a)
            end
        end
        for _, tr in ipairs(fx.tracks) do
            local k1, k2, a = sample(tr.keys, t)
            if k1 then
                local v = k1 == k2 and k1.value or lerpVal(k1.value, k2.value, a)
                pcall(function()
                    fx.inst[tr.prop] = v
                end)
            end
        end
        if fx.kind == "emitter" and playing and t >= prev and t - prev < 1 then
            for _, b in ipairs(fx.bursts) do
                if b.time > prev and b.time <= t then
                    pcall(function()
                        fx.inst:Emit(b.n)
                    end)
                end
            end
        end
    end
    local vals = {}
    for id, sc in pairs(state.screen) do
        local k1, k2, a = sample(sc.keys, t)
        if k1 then
            vals[id] = k1 == k2 and k1.value or lerpVal(k1.value, k2.value, a)
        else
            vals[id] = sc.base
        end
    end
    applyScreen(vals)
    state.lastT = t
end
function Player.clear()
    Player.stop()
    destroyAll()
    if overlay then
        pcall(function()
            overlay:Destroy()
            cc:Destroy()
        end)
        overlay, cc = nil, nil
    end
    local w = workspace:FindFirstChild("AFMWorld")
    if w then
        w:Destroy()
    end
    Player.loaded = false
    Player.t = 0
end
function Player.bindLoop()
    pcall(function()
        RunService:UnbindFromRenderStep(CAMERA_BIND)
    end)
    local last = os.clock()
    RunService:BindToRenderStep(CAMERA_BIND, Enum.RenderPriority.Camera.Value + 20, function()
        local now = os.clock()
        local dt = now - last
        last = now
        if not state then
            return
        end
        if Player.playing then
            Player.t = Player.t + dt * Player.speed
            if Player.t >= Player.dur then
                if Player.loop then
                    Player.t = Player.t % Player.dur
                    state.lastT = Player.t - 0.001
                    Player.emit("loop")
                    for _, fx in ipairs(state.fx) do
                        if fx.kind == "emitter" then
                            pcall(function()
                                fx.inst:Clear()
                            end)
                        end
                    end
                else
                    Player.t = Player.dur
                    Player.playing = false
                    Player.emit("finish")
                end
            end
            Player.step(Player.t, true)
        else
            Player.step(Player.t, false)
        end
        if Player.onTick then
            Player.onTick()
        end
    end)
end
function Player.load(data)
    Player.clear()
    if type(data) ~= "table" or type(data.film) ~= "table" then
        return false, "no film in packet"
    end
    local film = data.film
    keyCount = 0
    state = newState()
    Player.dur = math.clamp(tonumber(film.dur) or 0, 0.1, 3600)
    Player.fps = math.clamp(tonumber(film.fps) or 30, 1, 240)
    Player.loop = film.loop == true
    state.markers = buildKeys(film.markers, function(k)
        return {name = tostring(k.n or "marker"), value = tostring(k.v or "")}
    end)
    state.camKeys = buildKeys(film.cam, function(k)
        local c = cfFrom(k.c)
        return c and {pose = c, fov = math.clamp(tonumber(k.f) or 70, 1, 120)} or nil
    end)
    makeScreen()
    local okAll, err = pcall(function()
        if Player.options.scene ~= false then
            buildScene(data.scene)
        end
        buildRigs(film, data.rigs)
        buildObjs(film)
        if Player.options.vfx ~= false then
            buildVfx(data.vfx)
        end
    end)
    if not okAll then
        warn("AFM player: " .. tostring(err))
    end
    Player.info = {lighting = #state.statics, rigs = #state.rigs, made = state.madeCount or 0, props = #state.props, fx = #state.fx, cam = #state.camKeys, err = (not okAll) and tostring(err) or nil}
    Player.loaded = true
    Player.t = 0
    Player.bindLoop()
    Player.step(0, false)
    if Player.onLoad then
        Player.onLoad()
    end
    Player.emit("load")
    return true
end
function Player.play()
    if not Player.loaded then
        return
    end
    if Player.t >= Player.dur then
        Player.t = 0
        if state then
            state.lastT = -0.001
        end
    end
    reapplyStatics()
    Player.bindLoop()
    Player.playing = true
    Player.emit("play")
end
function Player.pause()
    Player.playing = false
    Player.emit("pause")
end
function Player.seek(t)
    Player.t = math.clamp(t, 0, Player.dur)
    if state then
        state.lastT = Player.t
    end
end
function Player.stop()
    Player.playing = false
    restoreWorld()
    Player.emit("stop")
    pcall(function()
        RunService:UnbindFromRenderStep(CAMERA_BIND)
    end)
    local c = cam()
    if c then
        c.CameraType = Enum.CameraType.Custom
    end
end
function Player.setCamera(on)
    Player.camOn = on
    if not on then
        local c = cam()
        if c then
            c.CameraType = Enum.CameraType.Custom
        end
    end
end
end
_G.AFMEngine = Player
