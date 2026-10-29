-- G1R_CheatMenu self-test for the 1.9.0 batch 1 features. Never shipped.
-- Copied to the installed mod's Scripts folder; F10 in a loaded game runs it. Results go to
-- UE4SS.log as "[CMTEST] PASS/FAIL ..." and a final "[CMTEST] DONE p/t".
-- Returns a list of steps (see the hook at the end of main.lua). A step returns the seconds to wait
-- before the next step, and true as a second value to run again itself.

local FALLS_ONLY = false -- true reruns only the fall tests

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
    local try, S, Extra = I.try, I.S, I.Extra
    local pawn, state, inv, m
    local function count(id)
        local cls = I.scriptClass(id)
        return cls and inv and tonumber(try(function() return inv:CountItemsOfClass(cls) end))
    end
    local function z() return try(function() return pawn:K2_GetActorLocation().Z end) end
    local function hp() return I.readAttr("AttributeSet_Health", "Health") end

    add(function()
        local _
        _, pawn, state = I.player()
        if not pawn then out("not in a running game"); steps = {}; return 0 end
        inv = I.inventory(pawn, state)
        m = try(function() return pawn.CharacterMovement end)
        check("inventory found", inv ~= nil)
        out("arrow count read: " .. tostring(count("ItAm_Arrow")))
        return 0.2
    end)

    -- 1. item lists ---------------------------------------------------------------------
    for _, name in ipairs({ "trophies", "smithing", "alchemy", "plants", "keys", "quest" }) do
        add(function()
            local list = I.Gear.lists[name]
            local ids, missing, unnamed = 0, {}, {}
            for id in list.ids:gmatch("%S+") do
                ids = ids + 1
                local full = list.prefix .. id
                local cls = I.scriptClass(full)
                if not cls then missing[#missing + 1] = full
                else
                    local cdo = try(function() return cls:GetCDO() end)
                    local label = cdo and try(function() return cdo.m_Name:ToString() end)
                    if type(label) ~= "string" or label == "" then unnamed[#unnamed + 1] = full end
                end
            end
            local entries = I.Gear.entries(name)
            check(name .. ": all classes exist", #missing == 0, #missing > 0 and table.concat(missing, " ") or (ids .. " ids"))
            check(name .. ": named entries", #entries > 0, #entries .. " listed; unnamed: " .. table.concat(unnamed, " "))
            if list.distinct then
                local want = ids - #missing - #unnamed
                local labels, dup = {}, nil
                for _, e in ipairs(entries) do
                    if labels[e.label] then dup = e.label end
                    labels[e.label] = true
                end
                check(name .. ": every item listed once", #entries == want and not dup,
                    #entries .. " of " .. want .. (dup and (", duplicate label " .. dup) or ""))
                local shown = {}
                for k = 1, math.min(6, #entries) do shown[k] = entries[k].label end
                out("  " .. table.concat(shown, " | "))
            end
            local page = I.Pages[name]
            if page and page.build then
                page.build()
                local want = #entries + (name == "quest" and 0 or 1)
                check(name .. ": page rows", #page.items == want, #page.items .. " rows, want " .. want)
            else
                check(name .. ": page exists", false)
            end
            local e = entries[1]
            if e then
                local before = count(e.id)
                local msg = I.giveItem(e)
                local after = count(e.id)
                check(name .. ": give " .. e.id, before and after and after - before == e.count,
                    ("%s -> %s (want +%d), '%s'"):format(tostring(before), tostring(after), e.count, tostring(msg)))
            end
            return 0.2
        end)
    end

    -- 2. infinite ammo ------------------------------------------------------------------
    local arrowsBefore
    add(function()
        local cls = I.scriptClass("ItAm_Arrow")
        local n = count("ItAm_Arrow") or 0
        if n >= 20 then
            local ok = pcall(function() inv:RemoveItemOfClass(cls, n - 10) end)
            out("removed arrows: " .. tostring(ok) .. ", now " .. tostring(count("ItAm_Arrow")))
        end
        arrowsBefore = count("ItAm_Arrow")
        out(Extra.setAmmo(true))
        return 2.5
    end)
    add(function()
        local after = count("ItAm_Arrow")
        check("ammo: arrows topped up", after and after >= 50, tostring(arrowsBefore) .. " -> " .. tostring(after))
        check("ammo: bolts topped up", (count("ItAm_Bolt") or 0) >= 50, tostring(count("ItAm_Bolt")))
        out(Extra.setAmmo(false))
        return 0.2
    end)

    -- 3. hero speed ---------------------------------------------------------------------
    add(function()
        out(Extra.shiftHeroSpeed(1)); out(Extra.shiftHeroSpeed(1))
        return 1.5
    end)
    add(function()
        local d = tonumber(try(function() return pawn.CustomTimeDilation end))
        check("speed: dilation 2 kept by the game", d and math.abs(d - 2) < 0.01, tostring(d))
        out(Extra.shiftHeroSpeed(-1)); out(Extra.shiftHeroSpeed(-1)); out(Extra.shiftHeroSpeed(-1))
        return 0.5
    end)
    add(function()
        local d = tonumber(try(function() return pawn.CustomTimeDilation end))
        check("speed: back to 1", d and math.abs(d - 1) < 0.01, tostring(d))
        return 0.2
    end)

    -- 4. jump height --------------------------------------------------------------------
    local base, peaks, z0, peak, samples = nil, {}, nil, nil, 0
    local function jumpSteps(label)
        add(function()
            z0, peak, samples = z(), z(), 0
            pcall(function() pawn:Jump() end)
            return 0.05
        end)
        add(function()
            local zz = z()
            if zz and peak and zz > peak then peak = zz end
            samples = samples + 1
            if samples < 30 then return 0.05, true end
            pcall(function() pawn:StopJumping() end)
            peaks[label] = (peak and z0) and (peak - z0) or nil
            out(("jump %s: %s cm"):format(label, tostring(peaks[label])))
            return 1
        end)
    end
    add(function()
        base = m and tonumber(try(function() return m.JumpZVelocity end))
        out("JumpZVelocity base " .. tostring(base))
        return 0.1
    end)
    jumpSteps("1x")
    add(function()
        out(Extra.shiftJump(1)); out(Extra.shiftJump(1))
        return 1
    end)
    add(function()
        local v = m and tonumber(try(function() return m.JumpZVelocity end))
        check("jump: velocity doubled and kept", base and v and math.abs(v - base * 2) < 1, tostring(base) .. " -> " .. tostring(v))
        return 0.1
    end)
    jumpSteps("2x")
    add(function()
        local h1, h2 = peaks["1x"], peaks["2x"]
        check("jump: higher jump", h1 and h2 and h1 > 5 and h2 > h1 * 1.5, ("1x %s cm, 2x %s cm"):format(tostring(h1), tostring(h2)))
        out(Extra.shiftJump(-1)); out(Extra.shiftJump(-1))
        return 0.5
    end)
    add(function()
        local v = m and tonumber(try(function() return m.JumpZVelocity end))
        check("jump: back to base", base and v and math.abs(v - base) < 1, tostring(v))
        return 0.2
    end)

    -- 5. translations -------------------------------------------------------------------
    add(function()
        local keys = { "No fall damage", "Infinite ammo", "Hero speed", "Jump height", "Jump: movement not found",
            "Animal trophies", "All animal trophies", "Smithing materials", "All smithing materials",
            "Alchemy ingredients", "All alchemy ingredients", "Plants", "All plants", "Keys", "All keys", "Quest items" }
        local orig = I.Lang.code
        for _, code in ipairs({ "de", "fr", "it", "es", "pt", "pl", "ru" }) do
            I.loadLanguage(code)
            local miss = {}
            for _, k in ipairs(keys) do if not I.Lang.exact[k] then miss[#miss + 1] = k end end
            local s1, s2 = I.tr("Hero speed: 2x"), I.tr("No fall damage ON")
            check("lang " .. code, #miss == 0 and s1 ~= "Hero speed: 2x" and s2 ~= "No fall damage ON",
                (#miss > 0 and ("missing " .. table.concat(miss, ", ") .. "; ") or "") .. s1 .. " | " .. s2)
        end
        if orig == "en" then I.Lang.code = "en"; I.Lang.exact = {}; I.Lang.patterns = {} else I.loadLanguage(orig) end
        return 0.2
    end)

    -- 6. no fall damage (last: a failed fall can kill the hero) ---------------------------
    local fallFrom = #steps + 1
    local fallRes, hp0, start, minHp, polls, dead, best = {}, nil, nil, nil, 0, false, nil
    local function fallSteps(label, height)
        add(function()
            if dead then return 0 end
            I.healFully()
            return 0.5
        end)
        add(function()
            hp0 = hp()
            start = try(function() return pawn:K2_GetActorLocation() end)
            if start then
                pcall(function() pawn:K2_SetActorLocation({ X = start.X, Y = start.Y, Z = start.Z + height }, false, {}, true) end)
            end
            minHp, polls = hp0, 0
            return 0.05
        end)
        add(function()
            -- poll so a dip that the menu's after-landing refill hides is still seen
            local h = hp()
            if h and minHp and h < minHp then minHp = h end
            polls = polls + 1
            if polls < 120 and (h or 0) > 0 then return 0.075, true end
            local hp1, z1 = hp(), z()
            out(("fall %s (%d cm): hp %s -> %s (lowest %s), z %s -> %s"):format(label, height, tostring(hp0), tostring(hp1),
                tostring(minHp), tostring(start and start.Z), tostring(z1)))
            fallRes[label] = (hp0 and minHp) and (hp0 - minHp) or nil
            if (hp1 or 0) <= 0 then out("hero died"); dead = true end
            return 0.2
        end)
    end
    add(function()
        if S.god then I.setGodMode(false) end
        return 0.1
    end)
    fallSteps("baseline", 800)
    add(function()
        check("fall: 8 m hurts without the cheat", (fallRes.baseline or 0) > 0, "damage " .. tostring(fallRes.baseline))
        out(Extra.setNoFall(true))
        return 0.5
    end)
    fallSteps("12m", 1200)
    add(function()
        check("no fall: 12 m without damage", fallRes["12m"] == 0, "damage " .. tostring(fallRes["12m"]))
        return 0.2
    end)
    fallSteps("30m", 3000)
    add(function()
        check("no fall: 30 m survived without damage", fallRes["30m"] == 0, "damage " .. tostring(fallRes["30m"]))
        out(Extra.setNoFall(false))
        local cfg = I.libraryObject("CombatConfig")
        local flag = cfg and try(function() return cfg.m_GodMode end)
        check("no fall: god flag back to off after the switch", flag == false, tostring(flag))
        if not dead then I.healFully() end
        out(("DONE %d/%d"):format(pass, total))
        return 0
    end)
    if FALLS_ONLY then
        local kept = { steps[1] }
        for k = fallFrom, #steps do kept[#kept + 1] = steps[k] end
        steps = kept
    end
    return function() return steps end
end

local I = ...
if I then return build(I)() end

-- older hook: runs the returned function as a coroutine. Game calls fail inside a coroutine, so it
-- only installs a plain step runner in its place and then stays suspended.
return function(I2)
    local getSteps = build(I2)
    local i, resumeAt = 1, 0
    rawset(_G, "__g1rcm_test", function()
        if os.clock() < resumeAt then return end
        local steps = getSteps()
        local step = steps[i]
        if not step then rawset(_G, "__g1rcm_test", nil); return end
        local ok, wait, again = pcall(step)
        if not ok then I2.log("[CMTEST] ERROR in step " .. i .. ": " .. tostring(wait)); wait, again = 0, false end
        if not again then i = i + 1 end
        resumeAt = os.clock() + (tonumber(wait) or 0)
    end)
    coroutine.yield()
end
