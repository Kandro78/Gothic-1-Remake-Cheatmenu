-- G1R_CheatMenu self-test for the 1.9.0 batch 2 features. Never shipped.
-- Copied to the installed mod's Scripts folder; F10 in a loaded game runs it. Results go to
-- UE4SS.log as "[CMTEST] PASS/FAIL ..." and a final "[CMTEST] DONE p/t".
-- Each F10 runs the next phase. A: names, pickpocketing, NPC in view (heal, kill), invisibility
-- and camp attitude, teleport to people; ends in front of the nearest chest (press F by hand: the
-- lockpicking game should open). B: unlocks the chest in view (F should open it now). C: goes to
-- the nearest locked door (F: lockpicking). D: unlocks the door in view (F should open it).

local PHASES = { "A", "B", "C", "D" }
local phaseIndex = (rawget(_G, "__b2phase") or 0) % #PHASES + 1
rawset(_G, "__b2phase", phaseIndex)
local PHASE = PHASES[phaseIndex]

local function build(I)
    local steps = {}
    local function add(fn) steps[#steps + 1] = fn end
    local pass, total = 0, 0
    local function out(m) I.log("[CMTEST] " .. m) end
    local function check(name, ok, info)
        total = total + 1
        if ok then pass = pass + 1 end
        out((ok and "PASS " or "FAIL ") .. name .. (info and (" -- " .. tostring(info)) or ""))
    end
    local try, S, Npc, Extra = I.try, I.S, I.Npc, I.Extra
    local pc, pawn, state, L
    local function loc(a)
        local l = try(function() return a:K2_GetActorLocation() end)
        return l and { x = l.X, y = l.Y, z = l.Z }
    end
    local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
    local function name(a) return try(function() return a:GetFName():ToString() end) or "?" end
    local function perceptionOf(a)
        local cls = StaticFindObject("/Script/G1R.CharacterPerceptionComponent")
        local c = cls and try(function() return a:GetComponentByClass(cls) end)
        return c and I.isValid(c) and c or nil
    end
    -- turn the camera onto a point: yaw from the hero, pitch from the camera
    local function face(at)
        local h = loc(pawn)
        local yaw = math.deg(math.atan(at.y - h.y, at.x - h.x))
        pcall(function() pc:SetControlRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }) end)
        local cam = try(function() return pc.PlayerCameraManager:GetCameraLocation() end)
        if cam then
            local dxy = math.sqrt((at.x - cam.X) ^ 2 + (at.y - cam.Y) ^ 2)
            local pitch = math.deg(math.atan(at.z - cam.Z, dxy))
            pcall(function() pc:SetControlRotation({ Pitch = pitch < 0 and pitch + 360 or pitch, Yaw = yaw, Roll = 0 }) end)
        end
    end
    local known = {}
    for _, group in pairs(Npc.PEOPLE) do for _, p in ipairs(group) do known[#known + 1] = p end end
    local function personOf(a)
        for _, p in ipairs(known) do if Npc.isPerson(a, p[2]) then return p end end
        return nil
    end
    local function hostilePerceivers()
        local c = perceptionOf(pawn)
        local arr = c and try(function() return c:GetHostileCharactersPerceivingMe(3000) end)
        return arr and tonumber(try(function() return #arr end)) or -1
    end

    local start, victim, orig

    add(function()
        local _
        pc, pawn, state = I.player()
        if not pawn then out("not in a running game"); steps = {}; return 0 end
        L = I.stateLib()
        start = loc(pawn)
        out(("start at %.0f %.0f %.0f"):format(start.x, start.y, start.z))
        return 0
    end)

    if PHASE == "A" then
    -- 1. names ---------------------------------------------------------------------------
    add(function()
        local chars = Npc.characters()
        local matched, unmatched = {}, {}
        for _, a in ipairs(chars) do
            local p = personOf(a)
            if p then matched[#matched + 1] = p[1] .. "<-" .. Npc.displayName(a)
            else unmatched[#unmatched + 1] = Npc.displayName(a) end
        end
        check("characters loaded", #chars > 5, #chars)
        check("people from the list found among them", #matched > 0, table.concat(matched, ", "))
        out("not in the list: " .. table.concat(unmatched, ", "))
        local bad = 0
        for _, a in ipairs(chars) do if Npc.displayName(a) == "?" then bad = bad + 1 end end
        check("every character gets a name", bad == 0, bad .. " without")
        return 0
    end)

    -- 2. pickpocketing ---------------------------------------------------------------------
    add(function()
        local before = I.readAttr("AttributeSet_Pickpocketing", "PickPocketing")
        Npc.setPickpocket(true)
        local on = I.readAttr("AttributeSet_Pickpocketing", "PickPocketing")
        check("pickpocketing raised", on == 100, tostring(before) .. " -> " .. tostring(on))
        Npc.setPickpocket(false)
        local off = I.readAttr("AttributeSet_Pickpocketing", "PickPocketing")
        check("pickpocketing restored", off == before, off)
        return 0
    end)

    -- 3. NPC in view: heal ------------------------------------------------------------------
    add(function()
        local best, bd
        local here = loc(pawn)
        for _, a in ipairs(Npc.characters()) do
            local at = loc(a)
            local hp = Extra.healthOf(a, Npc.stateOf(a))
            if at and hp and hp > 0 and not personOf(a) then
                local d = dist(here, at)
                if d > 300 and d < 2000 and (not best or d < bd) then best, bd = a, d end
            end
        end
        victim = best
        check("an unnamed NPC nearby", victim ~= nil, victim and (Npc.displayName(victim) .. " at " .. math.floor(bd) .. " cm"))
        if victim then face(loc(victim)) end
        return 0.6
    end)
    local aimTries = 0
    add(function()
        if not victim then return 0 end
        face(loc(victim))
        local t = Npc.target()
        if not (t and name(t) == name(victim)) and aimTries < 4 then aimTries = aimTries + 1; return 0.4, true end
        check("NPC in view is the one faced", t and name(t) == name(victim), (t and name(t) or "none") .. ", " .. aimTries .. " retries")
        out("menu shows: " .. Npc.targetLabel())
        local set = Extra.healthSetOf(victim, Npc.stateOf(victim))
        local max = tonumber(try(function() return set.MaxHealth.CurrentValue end))
        pcall(function() set.Health = { BaseValue = max - 10, CurrentValue = max - 10 } end)
        local msg = Npc.healTarget()
        local hp = Extra.healthOf(victim, Npc.stateOf(victim))
        check("heal NPC in view", hp == max, msg .. " (" .. tostring(hp) .. "/" .. tostring(max) .. ")")
        return 0
    end)

    -- 4. invisible + camp attitude -----------------------------------------------------------
    add(function()
        I.setGodMode(true)
        out("hostile perceivers before: " .. hostilePerceivers())
        local near = {}
        for _, a in ipairs(Npc.characters()) do
            local c = perceptionOf(a)
            local aw = c and try(function() return c:GetAwarenessToCharacter(pawn, 1) end)
            if aw then near[#near + 1] = Npc.displayName(a) .. "=" .. string.format("%.2f", aw) end
            if #near >= 6 then break end
        end
        out("sight awareness before: " .. table.concat(near, " "))
        local msg = Npc.setInvisible(true)
        local asc = I.playerASC(pawn, state)
        local tag = { TagName = FName("State.Invisible") }
        check("invisible switched on", S.invisible == true, msg)
        out("invisible tag on hero: " .. tostring(try(function() return asc:HasMatchingGameplayTag(tag) end))
            .. ", count " .. tostring(try(function() return asc:GetGameplayTagCount(tag) end)))
        return 1
    end)
    add(function()
        local maxAw, n = 0, 0
        for _, a in ipairs(Npc.characters()) do
            local c = perceptionOf(a)
            for sense = 1, 3 do
                local aw = c and tonumber(try(function() return c:GetAwarenessToCharacter(pawn, sense) end))
                if aw then n = n + 1; if aw > maxAw then maxAw = aw end end
            end
        end
        out(("NPC awareness of hero while invisible: %d readings, max %.2f"):format(n, maxAw))
        -- remember what the Old Camp people thought of the hero
        orig = {}
        for _, a in ipairs(Npc.characters()) do
            local st = Npc.stateOf(a)
            local camp = name(a):match("^Character_(%u+)_")
            if st and (camp == "OC" or camp == "OM") then
                orig[name(a)] = tonumber(try(function() return L:GetRelationshipTowards(st, state, pawn) end))
            end
        end
        local cnt = 0; for _ in pairs(orig) do cnt = cnt + 1 end
        out("Old Camp people loaded: " .. cnt)
        local msg = Npc.shiftAttitude(Npc.CAMPS[1], 1) -- Normal -> Friendly
        check("Old Camp set friendly", Npc.attitude("old") == 2, msg)
        check("no hostile attitude any more", #Npc.ATTITUDES == 2, table.concat(Npc.ATTITUDES, " "))
        return 1.5
    end)
    add(function()
        local ok, bad = 0, {}
        for _, a in ipairs(Npc.characters()) do
            if orig[name(a)] then
                local st = Npc.stateOf(a)
                local r = tonumber(try(function() return L:GetRelationshipTowards(st, state, pawn) end))
                if r == 5 then ok = ok + 1 else bad[#bad + 1] = Npc.displayName(a) .. "=" .. tostring(r) end
            end
        end
        check("Old Camp people friendly", ok > 0 and #bad == 0, ok .. " friendly; not: " .. table.concat(bad, " "))
        return 1
    end)
    add(function()
        Npc.setInvisible(false)
        local msg = Npc.shiftAttitude(Npc.CAMPS[1], 1) -- Friendly -> Normal
        check("Old Camp set back to normal", Npc.attitude("old") == 1, msg)
        return 1.5
    end)
    add(function()
        local ok, bad = 0, {}
        for _, a in ipairs(Npc.characters()) do
            local want = orig[name(a)]
            if want then
                local st = Npc.stateOf(a)
                local r = tonumber(try(function() return L:GetRelationshipTowards(st, state, pawn) end))
                if r == want then ok = ok + 1 else bad[#bad + 1] = Npc.displayName(a) .. "=" .. tostring(r) .. "/" .. tostring(want) end
            end
        end
        check("Old Camp relationships restored", ok > 0 and #bad == 0, ok .. " restored; wrong: " .. table.concat(bad, " "))
        local left = {}
        for k, v in pairs(S.campOrig or {}) do left[#left + 1] = k:match("[^.]+$") .. " tries " .. tostring(v.tries) end
        check("nothing left to restore", #left == 0, table.concat(left, ", "))
        -- does a restore leave a permanent relationship behind, and would Unknown (0) clear it?
        for _, a in ipairs(Npc.characters()) do
            local want = orig[name(a)]
            local st = Npc.stateOf(a)
            if want and st then
                local function perm() return tostring(try(function() return L:HasPermanentRelationshipTowards(st, state, want, pawn) end)) end
                out(("pinning probe %s: relation %s, permanent %s"):format(Npc.displayName(a),
                    tostring(try(function() return L:GetRelationshipTowards(st, state, pawn) end)), perm()))
                pcall(function() L:SetRelationshipTowards(st, state, 0, pawn) end)
                out(("pinning probe after Unknown: relation %s, permanent %s"):format(
                    tostring(try(function() return L:GetRelationshipTowards(st, state, pawn) end)), perm()))
                pcall(function() L:SetRelationshipTowards(st, state, want, pawn) end)
                break
            end
        end
        I.healFully()
        return 4
    end)
    add(function()
        out("hostile perceivers after normal: " .. hostilePerceivers())
        I.setGodMode(false)
        return 0
    end)

    -- 5. kill NPC in view --------------------------------------------------------------------
    add(function()
        if not victim then return 0 end
        face(loc(victim))
        return 0.6
    end)
    add(function()
        if not victim then return 0 end
        face(loc(victim))
        local msg = Npc.killTarget()
        out(msg)
        return 1.5
    end)
    add(function()
        if not victim then return 0 end
        local hp = Extra.healthOf(victim, Npc.stateOf(victim))
        local dead = try(function() return Npc.stateOf(victim):IsDead() end)
        check("kill NPC in view", (hp and hp <= 0) or dead == true, "health " .. tostring(hp) .. ", IsDead " .. tostring(dead))
        local t = Npc.target()
        check("dead NPC no longer targeted", not t or name(t) ~= name(victim), t and name(t) or "none")
        return 0
    end)

    -- 6. teleport to people ------------------------------------------------------------------
    local function person(key)
        for _, p in ipairs(known) do if p[2] == key then return p end end
    end
    local function nearPerson(key, label)
        local here = loc(pawn)
        for _, a in ipairs(Npc.characters()) do
            if Npc.isPerson(a, key) then
                local d = dist(here, loc(a))
                check(label, d < 400, ("%s at %.0f cm"):format(Npc.displayName(a), d))
                return
            end
        end
        check(label, false, key .. " not loaded; hero at " .. math.floor(here.x) .. " " .. math.floor(here.y))
    end
    add(function()
        out(Npc.go(person("milten")))
        return 5
    end)
    add(function() nearPerson("milten", "teleport to a loaded person (Milten)"); return 0 end)
    add(function()
        out(Npc.go(person("graham")))
        return 12
    end)
    add(function() nearPerson("graham", "teleport to a person far away (Graham)"); return 0 end)
    add(function()
        out(Npc.go(person("thorus")))
        return 12
    end)
    add(function() nearPerson("thorus", "teleport to a person far away (Thorus)"); return 0 end)

    -- 7. back to the start, in front of the nearest chest -------------------------------------
    add(function()
        pcall(function() pawn:K2_TeleportTo({ X = start.x, Y = start.y, Z = start.z + 50 }, { Pitch = 0, Yaw = 0, Roll = 0 }) end)
        return 6
    end)
    end

    -- chest (A, B) or door (C, D): the target is kept in _G between the F10 presses
    local wantDoor = PHASE == "C" or PHASE == "D"
    local function lockName(a) return try(function() return a.m_InteractiveComponent.m_InteractItem.m_Lock:ToString() end) end
    add(function()
        if PHASE == "A" or PHASE == "C" then
            local here, best, bd = loc(pawn), nil, nil
            for _, a in ipairs(I.actorsOfClass("/Script/G1R.InteractiveObjectActor")) do
                local cn = try(function() return a:GetClass():GetFName():ToString() end) or ""
                local at = loc(a)
                local ln = lockName(a)
                local fits = wantDoor and cn:find("Door") or (not wantDoor and cn:find("Chest"))
                if fits and at and ln and ln ~= "None" then
                    local d = dist(here, at)
                    if d < 4000 and (not best or d < bd) then best, bd = a, d end
                end
            end
            rawset(_G, "__b2target", best)
            check("a locked " .. (wantDoor and "door" or "chest") .. " nearby", best ~= nil,
                best and (name(best) .. " (" .. tostring(try(function() return best.m_FreepointName:ToString() end)) .. ", " .. lockName(best) .. ") at " .. math.floor(bd) .. " cm"))
            if not best then return 0 end
            local at = loc(best)
            local yaw = math.rad(tonumber(try(function() return best:K2_GetActorRotation().Yaw end)) or 0)
            local moved
            for _, side in ipairs({ 0, 180, 90, -90 }) do
                local r = yaw + math.rad(side)
                for _, lift in ipairs({ 100, 150, 200 }) do
                    local spot = { X = at.x + math.cos(r) * 130, Y = at.y + math.sin(r) * 130, Z = at.z + lift }
                    if try(function() return pawn:K2_TeleportTo(spot, { Pitch = 0, Yaw = math.deg(r) + 180, Roll = 0 }) end) then
                        moved = side .. "/" .. lift; break
                    end
                end
                if moved then break end
            end
            out("placed at it: " .. tostring(moved) .. ", now " .. math.floor(dist(loc(pawn), at)) .. " cm away")
            return 1.5
        end
        return 0
    end)
    add(function()
        local target = rawget(_G, "__b2target")
        if not (target and I.isValid(target)) then return 0 end
        face(loc(target))
        return 0.5
    end)
    add(function()
        local target = rawget(_G, "__b2target")
        if not (target and I.isValid(target)) then out("no target"); return 0 end
        local inView = Npc.lockInView()
        check((wantDoor and "door" or "chest") .. " in view found", inView and name(inView) == name(target), inView and name(inView) or "none")
        if PHASE == "B" or PHASE == "D" then
            local msg = Npc.unlockInView()
            local names = {}
            local picks = FindFirstOf("LockPickSubsystem")
            pcall(function() picks.m_UnlockedActors:ForEach(function(e) names[#names + 1] = tostring(try(function() return e:get():ToString() end)) end) end)
            local fp = try(function() return target.m_FreepointName:ToString() end)
            local listed = false
            for _, n in ipairs(names) do if n == fp then listed = true end end
            check("unlock " .. (wantDoor and "door" or "chest") .. " in view", msg == (wantDoor and "Door unlocked" or "Chest unlocked") and listed,
                msg .. "; unlocked set: " .. table.concat(names, " "))
        end
        return 0
    end)
    add(function()
        out(("DONE phase %s %d/%d"):format(PHASE, pass, total))
        return 0
    end)
    return steps
end

local I = ...
if I then return build(I) end
