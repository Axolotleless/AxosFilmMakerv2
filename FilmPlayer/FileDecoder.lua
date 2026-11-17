--Axo's Stuff © 2026
--FileDecoder is for Axo's Film Maker's custom "Film File" format
local Player = _G.AFMEngine
local PK = {}
do
local HttpService = game:GetService("HttpService")
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local enc64, dec64 = {}, {}
for i = 1, 64 do
    local c = string.sub(B64, i, i)
    enc64[i - 1] = c
    dec64[string.byte(c)] = i - 1
end
local function b64enc(s)
    local out = {}
    local n = #s
    for i = 1, n, 3 do
        local a, b, c = string.byte(s, i, i + 2)
        local x = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = enc64[math.floor(x / 262144) % 64]
        local c2 = enc64[math.floor(x / 4096) % 64]
        local c3 = b and enc64[math.floor(x / 64) % 64] or "="
        local c4 = c and enc64[x % 64] or "="
        out[#out + 1] = c1 .. c2 .. c3 .. c4
        if #out % 20000 == 0 then
            task.wait()
        end
    end
    return table.concat(out)
end
local function b64dec(s)
    local out = {}
    local n = #s
    for i = 1, n, 4 do
        local a, b, c, d = string.byte(s, i, i + 3)
        local va, vb = dec64[a], dec64[b]
        if not va or not vb then
            return nil
        end
        local vc = c ~= 61 and dec64[c] or nil
        local vd = d ~= 61 and dec64[d] or nil
        if (c ~= 61 and not vc) or (d ~= 61 and not vd) then
            return nil
        end
        local x = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0)
        local o1, o2, o3 = math.floor(x / 65536) % 256, math.floor(x / 256) % 256, x % 256
        if vc and vd then
            out[#out + 1] = string.char(o1, o2, o3)
        elseif vc then
            out[#out + 1] = string.char(o1, o2)
        else
            out[#out + 1] = string.char(o1)
        end
        if #out % 20000 == 0 then
            task.wait()
        end
    end
    return table.concat(out)
end
local function lzw(s)
    local dict, size = {}, 256
    for i = 0, 255 do
        dict[string.char(i)] = i
    end
    local out = {}
    local w = ""
    for i = 1, #s do
        local c = string.sub(s, i, i)
        local wc = w .. c
        if dict[wc] then
            w = wc
        else
            local code = dict[w]
            out[#out + 1] = string.char(math.floor(code / 256), code % 256)
            if size < 65535 then
                dict[wc] = size
                size = size + 1
            end
            w = c
        end
        if i % 60000 == 0 then
            task.wait()
        end
    end
    if w ~= "" then
        local code = dict[w]
        out[#out + 1] = string.char(math.floor(code / 256), code % 256)
    end
    return table.concat(out)
end
local function unlzw(s)
    local n = math.floor(#s / 2)
    if n == 0 then
        return ""
    end
    local dict, size = {}, 256
    for i = 0, 255 do
        dict[i] = string.char(i)
    end
    local function code(i)
        local hi, lo = string.byte(s, i * 2 - 1, i * 2)
        return hi * 256 + lo
    end
    local w = dict[code(1)]
    if not w then
        return nil
    end
    local res = {w}
    for i = 2, n do
        local k = code(i)
        local entry = dict[k]
        if not entry then
            if k == size then
                entry = w .. string.sub(w, 1, 1)
            else
                return nil
            end
        end
        res[#res + 1] = entry
        if size < 65535 then
            dict[size] = w .. string.sub(entry, 1, 1)
            size = size + 1
        end
        w = entry
        if i % 60000 == 0 then
            task.wait()
        end
    end
    return table.concat(res)
end
local function sumOf(s)
    local a, b = 1, 0
    for i = 1, #s, 200 do
        local bytes = {string.byte(s, i, math.min(i + 199, #s))}
        for _, v in ipairs(bytes) do
            a = (a + v) % 65521
            b = (b + a) % 65521
        end
    end
    return b * 65536 + a
end
local function round(v, depth)
    local t = type(v)
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            return 0
        end
        if math.abs(v) < 100000 then
            return math.floor(v * 100000 + 0.5) / 100000
        end
        return v
    elseif t == "table" then
        if depth > 24 then
            return nil
        end
        local out = {}
        for k, x in pairs(v) do
            local r = round(x, depth + 1)
            if r ~= nil then
                out[k] = r
            end
        end
        return out
    elseif t == "string" or t == "boolean" then
        return v
    end
    return nil
end
local function tryJson(js)
    local ok, d = pcall(function()
        return HttpService:JSONDecode(js)
    end)
    if ok and type(d) == "table" then
        return d
    end
    return nil
end
local function shape(d)
    if type(d) ~= "table" then
        return nil
    end
    if type(d.film) == "table" then
        return d
    end
    if type(d.cam) == "table" or type(d.rigs) == "table" or type(d.objs) == "table" then
        return {v = 2, film = d}
    end
    return nil
end
function PK.decodeLoose(pk, log)
    log = log or function() end
    local rep = {steps = {}, repaired = false}
    if type(pk) == "table" then
        local d, err = PK.decode(pk)
        if d then
            return d, rep
        end
        return nil, err, rep
    end
    if type(pk) ~= "string" then
        return nil, "nothing to read", rep
    end
    local t = string.gsub(pk, "^%s+", "")
    t = string.gsub(t, "%s+$", "")
    local d = tryJson(t)
    if d then
        if d.afm == 1 then
            return PK.decodeLoose(d, log)
        end
        local sh = shape(d)
        if sh then
            return sh, rep
        end
    end
    local zz = string.match(t, '"z"%s*:%s*"([A-Za-z0-9%+/=_%-]+)')
    if zz and #zz > 8 then
        local d2, err = PK.decode({afm = 1, v = 1, z = zz, len = tonumber(string.match(t, '"len"%s*:%s*(%d+)')), sum = tonumber(string.match(t, '"sum"%s*:%s*(%d+)')), n = string.match(t, '"n"%s*:%s*"([^"]*)"')})
        if d2 then
            rep.repaired = true
            return d2, rep
        end
        return nil, err, rep
    end
    return nil, "text is not a packet", rep
end
PK.LIMIT_Z = 6000000
PK.LIMIT_JSON = 14000000
PK.b64enc, PK.b64dec, PK.lzw, PK.unlzw, PK.sumOf = b64enc, b64dec, lzw, unlzw, sumOf
function PK.encode(data, name, meta)
    local slim = {v = 2, film = data.film, rigs = data.rigs, scene = data.scene, vfx = data.vfx}
    local ok, js = pcall(function()
        return HttpService:JSONEncode(round(slim, 0))
    end)
    if not ok then
        return nil, "could not encode the project"
    end
    local z = b64enc(lzw(js))
    local pk = {afm = 1, v = 1, n = string.sub(tostring(name or "Film"), 1, 60), len = #js, sum = sumOf(js), z = z}
    for k, v in pairs(meta or {}) do
        if type(v) == "number" then
            pk[k] = v
        end
    end
    return pk
end
function PK.check(pk)
    if type(pk) ~= "table" or pk.afm ~= 1 or pk.v ~= 1 then
        return false, "this is not an AFM packet"
    end
    if type(pk.z) ~= "string" or #pk.z < 8 or #pk.z > PK.LIMIT_Z then
        return false, "packet data is missing or too large"
    end
    if type(pk.len) ~= "number" or pk.len < 2 or pk.len > PK.LIMIT_JSON then
        return false, "packet length is not valid"
    end
    return true
end
function PK.decode(pk)
    local ok, why = PK.check(pk)
    if not ok then
        return nil, why
    end
    local raw = b64dec(pk.z)
    if not raw then
        return nil, "packet is corrupted (text)"
    end
    local js = unlzw(raw)
    if not js or #js ~= pk.len then
        return nil, "packet is corrupted (length)"
    end
    if sumOf(js) ~= pk.sum then
        return nil, "packet is corrupted (checksum)"
    end
    local okJ, data = pcall(function()
        return HttpService:JSONDecode(js)
    end)
    if not okJ or type(data) ~= "table" or type(data.film) ~= "table" then
        return nil, "packet has no film"
    end
    return data
end
function PK.summary(data)
    local film = data.film or {}
    local keys = #(film.cam or {})
    local rigs = type(film.rigs) == "table" and #film.rigs or 0
    for _, r in ipairs(type(film.rigs) == "table" and film.rigs or {}) do
        for _, b in ipairs(type(r.b) == "table" and r.b or {}) do
            keys = keys + #(type(b.k) == "table" and b.k or {})
        end
    end
    local vfx = data.vfx and type(data.vfx.fx) == "table" and #data.vfx.fx or 0
    local scene = type(data.scene) == "table" and #data.scene or 0
    return {name = tostring(film.name or "Film"), dur = tonumber(film.dur) or 0, fps = tonumber(film.fps) or 30, rigs = rigs, objs = type(film.objs) == "table" and #film.objs or 0, vfx = vfx, scene = scene, keys = keys}
end
end
_G.AFMCodec = PK
local KFS = {}
do
local CAM_POSE = "AFM_Camera"
local HIER = {
HumanoidRootPart = nil,
LowerTorso = "HumanoidRootPart",
UpperTorso = "LowerTorso",
Head = "UpperTorso",
LeftUpperArm = "UpperTorso",
LeftLowerArm = "LeftUpperArm",
LeftHand = "LeftLowerArm",
RightUpperArm = "UpperTorso",
RightLowerArm = "RightUpperArm",
RightHand = "RightLowerArm",
LeftUpperLeg = "LowerTorso",
LeftLowerLeg = "LeftUpperLeg",
LeftFoot = "LeftLowerLeg",
RightUpperLeg = "LowerTorso",
RightLowerLeg = "RightUpperLeg",
RightFoot = "RightLowerLeg",
}
local HIER6 = {
Torso = "HumanoidRootPart",
Head = "Torso",
["Left Arm"] = "Torso",
["Right Arm"] = "Torso",
["Left Leg"] = "Torso",
["Right Leg"] = "Torso",
}
local function parentOf(name, r6)
    if r6 then
        return HIER6[name]
    end
    return HIER[name]
end
local function isR6(tracks)
    for _, t in ipairs(tracks) do
        if t.n == "Torso" or t.n == "Left Arm" then
            return true
        end
    end
    return false
end
local STYLE_OUT = {Linear = "Linear", Constant = "Constant", Bounce = "Bounce", Elastic = "Elastic", Bezier = "Linear"}
local function styleOut(s)
    if s == nil then
        return "Linear"
    end
    return STYLE_OUT[s] or "Cubic"
end
local function dirOut(d)
    if d == "In" or d == "Out" or d == "InOut" then
        return d
    end
    return "Out"
end
local function numbers(a)
    if type(a) ~= "table" or #a ~= 12 then
        return false
    end
    for i = 1, 12 do
        if type(a[i]) ~= "number" or a[i] ~= a[i] then
            return false
        end
    end
    return true
end
local function sortedKeys(list)
    table.sort(list, function(a, b)
        return a.t < b.t
    end)
    return list
end
function KFS.fromFilm(data, rigName)
    if type(data) ~= "table" or type(data.film) ~= "table" then
        return nil, "no film"
    end
    local film = data.film
    local out = {name = tostring(film.name or "Film"), dur = tonumber(film.dur) or 0, fps = tonumber(film.fps) or 30, loop = film.loop == true, cam = {}, tracks = {}, markers = {}}
    for _, k in ipairs(type(film.cam) == "table" and film.cam or {}) do
        if type(k) == "table" and type(k.t) == "number" and numbers(k.c) then
            out.cam[#out.cam + 1] = {t = k.t, c = k.c, f = tonumber(k.f) or 70, s = k.s, d = k.d}
        end
    end
    sortedKeys(out.cam)
    local rigs = type(film.rigs) == "table" and film.rigs or {}
    local pick = nil
    for _, r in ipairs(rigs) do
        if type(r) == "table" and type(r.b) == "table" and (rigName == nil or r.n == rigName) then
            pick = r
            break
        end
    end
    if not pick and rigName ~= nil then
        for _, r in ipairs(rigs) do
            if type(r) == "table" and type(r.b) == "table" then
                pick = r
                break
            end
        end
    end
    if pick then
        out.rig = tostring(pick.n)
        for _, b in ipairs(pick.b) do
            if type(b) == "table" and type(b.p) == "table" and b.m and type(b.k) == "table" then
                local nm = b.p[#b.p]
                if type(nm) == "string" then
                    local keys = {}
                    for _, k in ipairs(b.k) do
                        if type(k) == "table" and type(k.t) == "number" and numbers(k.c) then
                            keys[#keys + 1] = {t = k.t, c = k.c, s = k.s, d = k.d}
                        end
                    end
                    if #keys > 0 then
                        out.tracks[#out.tracks + 1] = {n = nm, k = sortedKeys(keys)}
                    end
                end
            end
        end
    end
    local r6 = isR6(out.tracks)
    for _, tr in ipairs(out.tracks) do
        tr.par = parentOf(tr.n, r6)
    end
    for _, m in ipairs(type(film.markers) == "table" and film.markers or {}) do
        if type(m) == "table" and type(m.t) == "number" then
            out.markers[#out.markers + 1] = {t = m.t, n = tostring(m.n or "marker"), v = tostring(m.v or "")}
        end
    end
    return out
end
function KFS.toFilm(kfs, rigName)
    if type(kfs) ~= "table" then
        return nil, "no sequence"
    end
    local name = rigName or kfs.rig or "Rig"
    local film = {name = kfs.name or "Sequence", dur = kfs.dur or 0, fps = kfs.fps or 30, loop = kfs.loop == true, cam = {}, rigs = {}, markers = {}, objs = {}}
    for _, k in ipairs(kfs.cam or {}) do
        film.cam[#film.cam + 1] = {t = k.t, c = k.c, f = k.f or 70, s = k.s, d = k.d}
    end
    local bones = {}
    for _, tr in ipairs(kfs.tracks or {}) do
        local keys = {}
        for _, k in ipairs(tr.k) do
            keys[#keys + 1] = {t = k.t, c = k.c, s = k.s, d = k.d}
        end
        bones[#bones + 1] = {p = {tr.n}, m = true, k = keys}
    end
    if #bones > 0 then
        film.rigs[1] = {n = name, b = bones}
    end
    for _, m in ipairs(kfs.markers or {}) do
        film.markers[#film.markers + 1] = {t = m.t, n = m.n, v = m.v}
    end
    return {v = 2, film = film, rigs = {}}
end
local function enumByName(enum, name, fallback)
    local ok, v = pcall(function()
        return enum[name]
    end)
    if ok and v then
        return v
    end
    return fallback
end
local function cfOf(c)
    return CFrame.new(table.unpack(c))
end
local function comps(cf)
    local t = {cf:GetComponents()}
    for i = 1, 12 do
        if t[i] ~= t[i] then
            return nil
        end
    end
    return t
end
function KFS.toInstance(kfs)
    local ks = Instance.new("KeyframeSequence")
    ks.Name = tostring(kfs.name or "Sequence")
    ks.Loop = kfs.loop == true
    pcall(function()
        ks.Priority = Enum.AnimationPriority.Action
    end)
    local times, timeSet = {}, {}
    local function addTime(t)
        local key = string.format("%.5f", t)
        if not timeSet[key] then
            timeSet[key] = {t = t, tracks = {}, cam = nil, marks = {}}
            times[#times + 1] = timeSet[key]
        end
        return timeSet[key]
    end
    local trackByName = {}
    for _, tr in ipairs(kfs.tracks or {}) do
        trackByName[tr.n] = tr
        for _, k in ipairs(tr.k) do
            addTime(k.t).tracks[tr.n] = k
        end
    end
    for _, k in ipairs(kfs.cam or {}) do
        addTime(k.t).cam = k
    end
    for _, m in ipairs(kfs.markers or {}) do
        local slot = addTime(m.t)
        slot.marks[#slot.marks + 1] = m
    end
    table.sort(times, function(a, b)
        return a.t < b.t
    end)
    local r6 = isR6(kfs.tracks or {})
    for _, slot in ipairs(times) do
        local kf = Instance.new("Keyframe")
        kf.Time = slot.t
        kf.Name = "Keyframe"
        local made = {}
        local function pose(nm, key)
            if made[nm] then
                if key then
                    made[nm].Weight = 1
                    made[nm].CFrame = cfOf(key.c)
                    made[nm].EasingStyle = enumByName(Enum.PoseEasingStyle, styleOut(key.s), Enum.PoseEasingStyle.Linear)
                    made[nm].EasingDirection = enumByName(Enum.PoseEasingDirection, dirOut(key.d), Enum.PoseEasingDirection.Out)
                end
                return made[nm]
            end
            local p = Instance.new("Pose")
            p.Name = nm
            p.Weight = key and 1 or 0
            if key then
                p.CFrame = cfOf(key.c)
                p.EasingStyle = enumByName(Enum.PoseEasingStyle, styleOut(key.s), Enum.PoseEasingStyle.Linear)
                p.EasingDirection = enumByName(Enum.PoseEasingDirection, dirOut(key.d), Enum.PoseEasingDirection.Out)
            end
            made[nm] = p
            local par = parentOf(nm, r6)
            if par then
                p.Parent = pose(par, nil)
            else
                p.Parent = kf
            end
            return p
        end
        if next(slot.tracks) ~= nil and not made.HumanoidRootPart then
            pose("HumanoidRootPart", nil)
        end
        for nm, key in pairs(slot.tracks) do
            pose(nm, key)
        end
        if slot.cam then
            local cp = Instance.new("Pose")
            cp.Name = CAM_POSE
            cp.Weight = 1
            cp.CFrame = cfOf(slot.cam.c)
            cp:SetAttribute("Fov", slot.cam.f or 70)
            cp.Parent = kf
        end
        for _, m in ipairs(slot.marks) do
            local mk = Instance.new("KeyframeMarker")
            mk.Name = m.n
            mk.Value = m.v or ""
            mk.Parent = kf
        end
        kf.Parent = ks
    end
    return ks
end
local function walkPoses(pose, parentName, t, tracks, order, cam)
    for _, c in ipairs(pose:GetChildren()) do
        if c.ClassName == "Pose" then
            local nm = c.Name
            if nm == CAM_POSE then
                local comp = comps(c.CFrame)
                if comp then
                    local fov = 70
                    pcall(function()
                        fov = c:GetAttribute("Fov") or 70
                    end)
                    cam[#cam + 1] = {t = t, c = comp, f = fov}
                end
            else
                if c.Weight > 0 then
                    local comp = comps(c.CFrame)
                    if comp then
                        local tr = tracks[nm]
                        if not tr then
                            tr = {n = nm, par = parentName, k = {}}
                            tracks[nm] = tr
                            order[#order + 1] = tr
                        end
                        local sty, dir = "Linear", "Out"
                        pcall(function()
                            sty = c.EasingStyle.Name
                            dir = c.EasingDirection.Name
                        end)
                        tr.k[#tr.k + 1] = {t = t, c = comp, s = sty ~= "Linear" and sty or nil, d = dir}
                    end
                end
                walkPoses(c, nm, t, tracks, order, cam)
            end
        end
    end
end
function KFS.fromInstance(ks)
    if typeof(ks) ~= "Instance" or ks.ClassName ~= "KeyframeSequence" then
        return nil, "not a KeyframeSequence"
    end
    local out = {name = ks.Name, dur = 0, fps = 30, loop = ks.Loop == true, cam = {}, tracks = {}, markers = {}}
    local tracks, order = {}, {}
    for _, kf in ipairs(ks:GetChildren()) do
        if kf.ClassName == "Keyframe" then
            local t = kf.Time
            if t > out.dur then
                out.dur = t
            end
            walkPoses(kf, nil, t, tracks, order, out.cam)
            for _, m in ipairs(kf:GetChildren()) do
                if m.ClassName == "KeyframeMarker" then
                    out.markers[#out.markers + 1] = {t = t, n = m.Name, v = tostring(m.Value)}
                end
            end
        end
    end
    for _, tr in ipairs(order) do
        sortedKeys(tr.k)
        out.tracks[#out.tracks + 1] = tr
    end
    sortedKeys(out.cam)
    sortedKeys(out.markers)
    if out.dur < 0.1 then
        out.dur = 0.1
    end
    return out
end
function KFS.summary(kfs)
    local keys = 0
    for _, tr in ipairs(kfs.tracks or {}) do
        keys = keys + #tr.k
    end
    return {name = kfs.name, dur = kfs.dur, bones = #(kfs.tracks or {}), keys = keys, cam = #(kfs.cam or {}), markers = #(kfs.markers or {})}
end
function KFS.find(root)
    local found = {}
    local list = {}
    pcall(function()
        list = root:GetDescendants()
    end)
    for _, d in ipairs(list) do
        if d.ClassName == "KeyframeSequence" then
            found[#found + 1] = d
        end
    end
    return found
end
end
_G.AFMKFS = KFS
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KFProvider = game:GetService("KeyframeSequenceProvider")
local lp = Players.LocalPlayer
for _ = 1, 300 do
    if lp then
        break
    end
    task.wait(0.1)
    lp = Players.LocalPlayer
end
for _ = 1, 300 do
    if Player then
        break
    end
    task.wait(0.1)
    Player = _G.AFMEngine
end
if not Player then
    warn("AFM_Engine must be in the game next to AFM_Tools.")
    return
end
local AFP = {library = {}, order = {}, triggers = {}, current = nil, frozen = {}}
local listeners = {}
function AFP.on(ev, fn)
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
AFP.hook = AFP.on
function AFP.emit(ev, a, b, c)
    local list = listeners[ev]
    if not list then
        return
    end
    for i = 1, #list do
        local ok, err = pcall(list[i], a, b, c)
        if not ok then
            warn("AFP hook " .. tostring(ev) .. ": " .. tostring(err))
        end
    end
end
for _, ev in ipairs({"load", "play", "pause", "stop", "finish", "loop", "marker"}) do
    Player.on(ev, function(a, b, c)
        AFP.emit(ev, a, b, c)
    end)
end
local function uniqueName(name)
    local base = tostring(name or "Untitled")
    local n = base
    local i = 1
    for _ = 1, 500 do
        if not AFP.library[n] then
            return n
        end
        i = i + 1
        n = base .. " " .. i
    end
    return n
end
function AFP.add(source, name)
    local entry = {kind = nil, data = nil, kfs = nil}
    if typeof(source) == "Instance" then
        local k, why = KFS.fromInstance(source)
        if not k then
            return nil, why
        end
        entry.kind = "kfs"
        entry.kfs = k
        entry.data = KFS.toFilm(k)
        name = name or k.name
    elseif type(source) == "table" and source.afm == 1 then
        local data, a, b = PK.decodeLoose(source)
        if not data then
            return nil, tostring(a)
        end
        entry.kind = "film"
        entry.data = data
        entry.packet = source
        name = name or (data.film and data.film.name) or source.n
    elseif type(source) == "table" and type(source.film) == "table" then
        entry.kind = "film"
        entry.data = source
        name = name or source.film.name
    elseif type(source) == "table" and type(source.tracks) == "table" then
        entry.kind = "kfs"
        entry.kfs = source
        entry.data = KFS.toFilm(source)
        name = name or source.name
    else
        return nil, "unknown source"
    end
    entry.name = uniqueName(name)
    AFP.library[entry.name] = entry
    AFP.order[#AFP.order + 1] = entry.name
    AFP.emit("added", entry.name, entry.kind)
    return entry
end
function AFP.remove(name)
    if not AFP.library[name] then
        return false
    end
    AFP.library[name] = nil
    for i = 1, #AFP.order do
        if AFP.order[i] == name then
            table.remove(AFP.order, i)
            break
        end
    end
    AFP.emit("removed", name)
    return true
end
function AFP.sequence(name, rigName)
    local entry = AFP.library[name]
    if not entry then
        return nil, "no such item"
    end
    if entry.kfs and (rigName == nil or entry.kfs.rig == rigName or entry.kind == "kfs") then
        return entry.kfs
    end
    local k, why = KFS.fromFilm(entry.data, rigName)
    if k then
        entry.kfs = entry.kfs or k
    end
    return k, why
end
function AFP.scan()
    local out = {}
    local seen = {}
    local roots = {workspace, ReplicatedStorage}
    pcall(function()
        roots[#roots + 1] = lp:FindFirstChildOfClass("Backpack")
    end)
    for _, root in ipairs(roots) do
        for _, ks in ipairs(KFS.find(root)) do
            if not seen[ks] then
                seen[ks] = true
                out[#out + 1] = ks
            end
        end
    end
    return out
end
function AFP.importScan()
    local n = 0
    for _, ks in ipairs(AFP.scan()) do
        local ok = AFP.add(ks)
        if ok then
            n = n + 1
        end
    end
    return n
end
function AFP.exportKFS(name, rigName, parent)
    local k, why = AFP.sequence(name, rigName)
    if not k then
        return nil, why
    end
    local ks = KFS.toInstance(k)
    ks.Parent = parent or workspace.CurrentCamera
    return ks
end
function AFP.character()
    return lp and lp.Character
end
local function freeze(model, on)
    if typeof(model) ~= "Instance" then
        return
    end
    local anim = model:FindFirstChild("Animate")
    if on then
        AFP.frozen[model] = {animate = anim and anim:IsA("LocalScript") and not anim.Disabled}
        if AFP.frozen[model].animate then
            anim.Disabled = true
        end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
                t:Stop(0)
            end
        end
    else
        local st = AFP.frozen[model]
        AFP.frozen[model] = nil
        if st and st.animate and anim then
            anim.Disabled = false
        end
    end
end
function AFP.release()
    for model in pairs(AFP.frozen) do
        freeze(model, false)
    end
end
function AFP.play(name, opts)
    opts = opts or {}
    local entry = AFP.library[name]
    if not entry then
        return false, "no such item"
    end
    Player.targets = {}
    if typeof(opts.target) == "Instance" then
        Player.targets["*"] = opts.target
        if opts.freeze ~= false then
            freeze(opts.target, true)
        end
    end
    if type(opts.targets) == "table" then
        for k, v in pairs(opts.targets) do
            Player.targets[k] = v
        end
    end
    local ok, why = Player.load(entry.data)
    if not ok then
        return false, why
    end
    AFP.current = name
    Player.loop = opts.loop == true or (opts.loop == nil and entry.data.film.loop == true)
    Player.speed = opts.speed or 1
    Player.camOn = opts.camera ~= false
    if not Player.camOn then
        Player.setCamera(false)
    end
    if opts.onDone then
        local off
        off = Player.on("finish", function()
            off()
            opts.onDone()
        end)
    end
    if opts.autoplay ~= false then
        Player.play()
    end
    return true
end
function AFP.stop()
    Player.stop()
    AFP.release()
    AFP.current = nil
end
function AFP.animate(target, name, opts)
    opts = opts or {}
    local k, why = AFP.sequence(name)
    if not k then
        return nil, why
    end
    local ks = KFS.toInstance(k)
    local id
    local okReg = pcall(function()
        id = KFProvider:RegisterKeyframeSequence(ks)
    end)
    if not okReg or not id then
        ks:Destroy()
        return nil, "could not register the sequence"
    end
    local host = target
    if typeof(host) ~= "Instance" then
        host = lp.Character
    end
    local animator = host and (host:FindFirstChildWhichIsA("Animator", true))
    if not animator then
        local ctl = host and (host:FindFirstChildOfClass("Humanoid") or host:FindFirstChildOfClass("AnimationController"))
        if not ctl and host then
            ctl = Instance.new("AnimationController")
            ctl.Parent = host
        end
        if ctl then
            animator = Instance.new("Animator")
            animator.Parent = ctl
        end
    end
    if not animator then
        return nil, "no Animator on the target"
    end
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    local track = animator:LoadAnimation(anim)
    track.Looped = opts.looped == true or (opts.looped == nil and k.loop == true)
    if opts.priority then
        pcall(function()
            track.Priority = Enum.AnimationPriority[opts.priority]
        end)
    end
    track:Play(opts.fade or 0.1, 1, opts.speed or 1)
    for _, m in ipairs(k.markers or {}) do
        pcall(function()
            track:GetMarkerReachedSignal(m.n):Connect(function(v)
                AFP.emit("marker", m.n, v, m.t)
            end)
        end)
    end
    return track
end
local function fire(spec, info)
    local now = os.clock()
    if spec.dead then
        return
    end
    if spec.cooldown and spec.last and now - spec.last < spec.cooldown then
        return
    end
    if Player.playing and not spec.interrupt then
        return
    end
    spec.last = now
    AFP.emit("trigger", spec.name, spec.kind, info)
    if spec.fn then
        pcall(spec.fn, info)
    end
    if spec.play then
        AFP.play(spec.play, {target = spec.target, loop = spec.loop, camera = spec.camera, speed = spec.speed})
    end
    if spec.once then
        spec.dead = true
        for _, c in ipairs(spec.conns) do
            pcall(function()
                c:Disconnect()
            end)
        end
    end
end
function AFP.trigger(spec)
    spec.conns = {}
    spec.name = spec.name or (spec.kind .. " trigger")
    local kind = spec.kind
    if kind == "touch" and typeof(spec.part) == "Instance" then
        spec.conns[#spec.conns + 1] = spec.part.Touched:Connect(function(hit)
            if hit.Parent and Players:GetPlayerFromCharacter(hit.Parent) == lp then
                fire(spec, hit)
            end
        end)
    elseif kind == "proximity" then
        local inside = false
        local acc = 0
        spec.conns[#spec.conns + 1] = RunService.Heartbeat:Connect(function(dt)
            acc = acc + dt
            if acc < 0.15 then
                return
            end
            acc = 0
            local ch = lp.Character
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            local pos = spec.position
            if typeof(spec.part) == "Instance" then
                pos = spec.part.Position
            end
            if root and pos then
                local near = (root.Position - pos).Magnitude <= (spec.distance or 12)
                if near and not inside then
                    fire(spec, root)
                end
                inside = near
            end
        end)
    elseif kind == "camera" then
        local cam = workspace.CurrentCamera
        local watch = spec.watch or "type"
        local prop = watch == "subject" and "CameraSubject" or "CameraType"
        spec.conns[#spec.conns + 1] = cam:GetPropertyChangedSignal(prop):Connect(function()
            if Player.playing then
                return
            end
            if prop == "CameraType" and cam.CameraType ~= (spec.mode or Enum.CameraType.Scriptable) then
                return
            end
            fire(spec, cam)
        end)
    elseif kind == "key" then
        local code = spec.key
        if type(code) == "string" then
            code = Enum.KeyCode[code]
        end
        spec.conns[#spec.conns + 1] = UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == code then
                fire(spec, input)
            end
        end)
    elseif kind == "chat" then
        local ok, c = pcall(function()
            return lp.Chatted:Connect(function(msg)
                if string.lower(msg) == string.lower(spec.text or "") then
                    fire(spec, msg)
                end
            end)
        end)
        if ok then
            spec.conns[#spec.conns + 1] = c
        end
    elseif kind == "time" then
        task.delay(spec.after or 1, function()
            fire(spec, nil)
        end)
    else
        return nil, "unknown trigger kind"
    end
    function spec.Destroy()
        spec.dead = true
        for _, c in ipairs(spec.conns) do
            pcall(function()
                c:Disconnect()
            end)
        end
        for i = 1, #AFP.triggers do
            if AFP.triggers[i] == spec then
                table.remove(AFP.triggers, i)
                break
            end
        end
    end
    AFP.triggers[#AFP.triggers + 1] = spec
    return spec
end
AFP.Player, AFP.Codec, AFP.KFS = Player, PK, KFS
_G.AFP = AFP
