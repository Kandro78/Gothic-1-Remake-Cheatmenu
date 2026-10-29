-- G1R_CheatMenu self-test for the 1.9.0 batch 3 features. Never shipped.
-- Copied to the installed mod's Scripts folder; F10 in a loaded game runs it. Results go to
-- UE4SS.log as "[CMTEST] PASS/FAIL ..." and a final "[CMTEST] DONE p/t".
-- Free training, reset skills (the hero's skills and learning points are put back afterwards),
-- spawn definitions and two spawned creatures (killed again), revive of a digger killed here,
-- the translations. Ends in front of the revived digger after a trip away and back, so a
-- screenshot shows whether he stands.

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
    local try, S, Npc, Extra, T = I.try, I.S, I.Npc, I.Extra, I.Training
    local LP_SET, LP_FIELD = "AttributeSet_LevelProgression", "SkillPoints"
    local pc, pawn, state, L, asc, inv, ore
    local function loc(a)
        local l = try(function() return a:K2_GetActorLocation() end)
        return l and { x = l.X, y = l.Y, z = l.Z }
    end
    local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
    local function name(a) return try(function() return a:GetFName():ToString() end) or "?" end
    local function lp() return I.readAttr(LP_SET, LP_FIELD) end
    local function oreCount() return tonumber(try(function() return inv:CountItemsOfClass(ore) end)) end
    local function skillClass(n) return I.scriptClass("GE_Skill_" .. n) end
    local function has(n)
        local cls = skillClass(n)
        return cls and (tonumber(try(function() return asc:GetGameplayEffectCount(cls, nil, true) end)) or 0) > 0
    end
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

    local lp0, had = nil, {}

    add(function()
        pc, pawn, state = I.player()
        if not pawn then out("not in a running game"); steps = {}; return 0 end
        L, asc, inv = I.stateLib(), I.playerASC(pawn, state), I.inventory(pawn, state)
        ore = I.scriptClass("ItMi_Orenugget")
        lp0 = lp()
        for _, n in ipairs(I.SKILLS) do if has(n) then had[#had + 1] = n end end
        out(("start: LP %s, ore %s, skills: %s"):format(tostring(lp0), tostring(oreCount()), table.concat(had, " ")))
        return 0
    end)

    -- 1. free training ------------------------------------------------------------------
    local test = "Sneak"
    add(function()
        if S.train then T.set(false) end
        local prices = T.prices() or {}
        local n = 0
        for _ in pairs(prices) do n = n + 1 end
        check("skill prices read", n >= #I.SKILLS - 2, n .. " of " .. #I.SKILLS)
        local p = prices[test]
        out("Sneak normal price: " .. (p and (p.sp .. " LP, " .. p.ore .. " ore") or "?"))
        if has(test) then I.cheatExtension():EffectRemove("GE_Skill_" .. test) end
        local msg = T.set(true)
        local cdo = skillClass(test):GetCDO()
        check("free training on", S.train and msg == "Free training ON" and cdo.SPCost == 0 and cdo.oreCost == 0,
            msg .. "; Sneak " .. tostring(cdo.SPCost) .. " LP " .. tostring(cdo.oreCost) .. " ore")
        local l0, o0 = lp(), oreCount()
        pcall(function() L:LearnSkill(state, skillClass(test), true, pawn) end) -- the teachers' paid path
        check("paid learning costs nothing", has(test) and lp() == l0 and oreCount() == o0,
            ("has %s, LP %s -> %s, ore %s -> %s"):format(tostring(has(test)), tostring(l0), tostring(lp()), tostring(o0), tostring(oreCount())))
        return 0.8 -- the hold takes its baseline on the next tick
    end)
    add(function()
        I.writeAttr(LP_SET, LP_FIELD, lp() - 5) -- what stat training does
        return 0.8
    end)
    add(function()
        local now = lp()
        check("learning points held", now == S.trainLP and now >= (lp0 or 0) - 0.01, tostring(now))
        I.writeAttr(LP_SET, LP_FIELD, now + 7)
        return 0.8
    end)
    add(function()
        local now = lp()
        check("a raise of learning points kept", now == (S.trainLP or -1) and now > (lp0 or 0), tostring(now))
        local msg = T.set(false)
        local p = (T.prices() or {})[test] or {}
        local cdo = skillClass(test):GetCDO()
        check("free training off restores prices", not S.train and cdo.SPCost == p.sp and cdo.oreCost == p.ore,
            msg .. "; Sneak " .. tostring(cdo.SPCost) .. " LP " .. tostring(cdo.oreCost) .. " ore")
        I.writeAttr(LP_SET, LP_FIELD, lp0)
        return 0.3
    end)

    -- 2. reset skills -------------------------------------------------------------------
    add(function()
        I.learnSkill("Acrobatics")
        local list, expect = {}, 0
        local prices = T.prices() or {}
        for _, n in ipairs(I.SKILLS) do
            if has(n) then list[#list + 1] = n; expect = expect + ((prices[n] or {}).sp or 0) end
        end
        local l0 = lp()
        local msg = T.reset()
        local left = {}
        for _, n in ipairs(I.SKILLS) do if has(n) then left[#left + 1] = n end end
        check("reset skills removes them all", #list >= 2 and #left == 0,
            msg .. "; had " .. table.concat(list, " ") .. "; left " .. table.concat(left, " "))
        check("reset skills refunds learning points", math.abs(lp() - (l0 + expect)) < 0.01,
            ("LP %s -> %s, expected +%s"):format(tostring(l0), tostring(lp()), tostring(expect)))
        -- put the hero back as he was
        for _, n in ipairs(had) do I.learnSkill(n) end
        I.writeAttr(LP_SET, LP_FIELD, lp0)
        local back = {}
        for _, n in ipairs(had) do if not has(n) then back[#back + 1] = n end end
        check("hero's skills put back", #back == 0 and lp() == lp0, "missing: " .. table.concat(back, " ") .. ", LP " .. tostring(lp()))
        return 0.3
    end)

    -- 3. spawn -------------------------------------------------------------------------
    local spawnAt, before = nil, {}
    add(function()
        local missing = {}
        for _, c in ipairs(Npc.CREATURES) do if not Npc.spawnClass(c) then missing[#missing + 1] = c[1] .. "=" .. c[2] end end
        check("every spawn definition found", #missing == 0, #Npc.CREATURES .. " creatures; missing: " .. table.concat(missing, ", "))
        for _, a in ipairs(Npc.characters()) do before[name(a)] = true end
        spawnAt = loc(pawn)
        local m1 = Npc.spawn(Npc.CREATURES[1]) -- meatbug
        local m2 = Npc.spawn(Npc.CREATURES[5]) -- wolf
        check("spawn calls", m1 == "Spawned: Meatbug" and m2 == "Spawned: Wolf", m1 .. " | " .. m2)
        return 4
    end)
    add(function()
        local new = {}
        for _, a in ipairs(Npc.characters()) do
            local at = loc(a)
            if not before[name(a)] and at and dist(at, spawnAt) < 1500 then new[#new + 1] = a end
        end
        local names = {}
        for _, a in ipairs(new) do names[#names + 1] = name(a) end
        local s = table.concat(names, " ")
        check("spawned creatures appear", s:find("Meatbug") and s:find("Wolf"), s)
        for _, a in ipairs(new) do
            if name(a):find("Meatbug") or name(a):find("Wolf") then pcall(function() L:Kill(Npc.stateOf(a), true, pawn) end) end
        end
        return 0.5
    end)

    -- 4. revive -------------------------------------------------------------------------
    local victim, victimState
    add(function()
        local best, bd
        local here = loc(pawn)
        for _, a in ipairs(Npc.characters()) do
            local at = loc(a)
            local st = Npc.stateOf(a)
            if at and name(a):find("_Digger%d") and try(function() return st:IsDead() end) == false then
                local d = dist(here, at)
                if d > 200 and d < 2000 and (not best or d < bd) then best, bd = a, d end
            end
        end
        victim = best
        check("a digger nearby", victim ~= nil, victim and (name(victim) .. " at " .. math.floor(bd) .. " cm"))
        if not victim then return 0 end
        pcall(function() L:Kill(Npc.stateOf(victim), true, pawn) end)
        return 1.5
    end)
    local aimTries = 0
    add(function()
        if not victim then return 0 end
        face(loc(victim))
        local t = Npc.deadTarget()
        if not (t and name(t) == name(victim)) and aimTries < 4 then aimTries = aimTries + 1; return 0.4, true end
        check("dead NPC in view is the one killed", t and name(t) == name(victim), (t and name(t) or "none") .. ", " .. aimTries .. " retries")
        check("living target skips the dead one", not Npc.target() or name(Npc.target()) ~= name(victim))
        out("menu shows: " .. Npc.deadTargetLabel())
        local msg = Npc.reviveTarget()
        local st = Npc.stateOf(victim)
        victimState = st
        check("revive NPC in view", msg:find("^Revived: ") and try(function() return st:IsDead() end) == false,
            msg .. "; health " .. tostring(Extra.healthOf(victim, st)))
        rawset(_G, "__b3home", loc(pawn))
        pcall(function() pawn:K2_TeleportTo({ X = 103662, Y = -58232, Z = 2527 }, { Pitch = 0, Yaw = 0, Roll = 0 }) end)
        return 15
    end)
    add(function()
        local home = rawget(_G, "__b3home")
        if home then pcall(function() pawn:K2_TeleportTo({ X = home.x, Y = home.y, Z = home.z + 50 }, { Pitch = 0, Yaw = 0, Roll = 0 }) end) end
        return 15
    end)
    add(function()
        if not victim then return 0 end
        -- he may be loaded again near by, or be about his daily routine elsewhere in the simulation
        local st = victimState
        out("state " .. tostring(st and try(function() return st:GetFullName() end)))
        local body = st and try(function() return st:GetCharacter() end)
        local at = st and try(function() return st:GetCharacterLocation() end)
        local h = loc(pawn)
        check("revived digger alive after the area reloads", st and try(function() return st:IsDead() end) == false
            and try(function() return st:GetRemovedFromWorld() end) == false,
            st and ("body loaded " .. tostring(I.isValid(body)) .. (at and (", " .. math.floor(math.sqrt((at.X - h.x) ^ 2 + (at.Y - h.y) ^ 2)) .. " cm away") or "")) or "no state")
        if I.isValid(body) then
            local bl = loc(body)
            local yaw = tonumber(try(function() return body:K2_GetActorRotation().Yaw end)) or 0
            local r = math.rad(yaw)
            pcall(function() pawn:K2_TeleportTo({ X = bl.x + math.cos(r) * 250, Y = bl.y + math.sin(r) * 250, Z = bl.z + 30 }, { Pitch = 0, Yaw = yaw + 180, Roll = 0 }) end)
            pcall(function() pc:SetControlRotation({ Pitch = 350, Yaw = yaw + 180, Roll = 0 }) end)
        end
        return 0.3
    end)

    -- 5. translations -------------------------------------------------------------------
    add(function()
        local keys = { "Free training", "Reset skills", "Revive NPC in view", "Spawn creature", "No dead NPC in view",
            "Reviving failed", "Spawning failed", "Free training: skill prices not found" }
        for _, c in ipairs(Npc.CREATURES) do keys[#keys + 1] = c[1] end
        -- kept as they are in some languages, like the vanilla game does
        local same = { Molerat = true, Scavenger = true, Wolf = true, Snapper = true, Razor = true, Lurker = true, Minecrawler = true }
        local orig = I.Lang.code
        for _, code in ipairs({ "de", "fr", "it", "es", "pt", "pl", "ru" }) do
            I.loadLanguage(code)
            local miss = {}
            for _, k in ipairs(keys) do if not I.Lang.exact[k] and not same[k] then miss[#miss + 1] = k end end
            local s1 = I.tr("Spawned: Fire Golem")
            local s2 = I.tr("Skills reset: 3 removed, 25 learning points back")
            local s3 = I.tr("Revived: Digger, stands up once the area reloads")
            local s4 = I.tr("Free training ON")
            check("lang " .. code, #miss == 0 and not s1:find("Spawned") and not s1:find("Fire Golem") and not s2:find("removed")
                and not s3:find("stands up") and s4 ~= "Free training ON",
                (#miss > 0 and ("missing " .. table.concat(miss, ", ") .. "; ") or "") .. s1 .. " | " .. s2 .. " | " .. s3 .. " | " .. s4)
        end
        if orig == "en" then I.Lang.code = "en"; I.Lang.exact = {}; I.Lang.patterns = {} else I.loadLanguage(orig) end
        return 0.2
    end)
    add(function()
        out(("DONE %d/%d"):format(pass, total))
        return 0
    end)
    return steps
end

local I = ...
if I then return build(I) end
