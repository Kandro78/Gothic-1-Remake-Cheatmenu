-- G1R_CheatMenu settings. Key names are UE4SS key names (see Mods\shared\Types.lua, table "Key").
-- Changing a key needs a full game restart.
return {
    -- opens / closes the menu
    toggleKeys = { "F7" },

    -- navigation, only active while the menu is open
    upKeys     = { "UP_ARROW", "NUM_EIGHT" },
    downKeys   = { "DOWN_ARROW", "NUM_TWO" },
    leftKeys   = { "LEFT_ARROW", "NUM_FOUR" },   -- decrease a value / remove a skill
    rightKeys  = { "RIGHT_ARROW", "NUM_SIX" },   -- increase a value
    selectKeys = { "RETURN", "NUM_FIVE" },       -- open a page / run a cheat / switch on-off
    backKeys   = { "BACKSPACE", "DECIMAL" },     -- back to the previous page (closes on the first page)

    -- holding Up / Down keeps moving the selection: it starts after repeatDelay seconds and then
    -- moves one row every repeatInterval seconds. false switches it off.
    holdToRepeat   = true,
    repeatDelay    = 0.35,
    repeatInterval = 0.07,

    -- Fly (Player page): the hero flies through walls and ground. W / S move along the camera
    -- (look up to climb), A / D sideways, Page Up / Page Down straight up and down. Single letters
    -- and the names in Mods\shared\Types.lua work here. flySpeed is in cm per second (the game's own
    -- walking speed is about 600).
    flyForwardKeys = { "W" },
    flyBackKeys    = { "S" },
    flyLeftKeys    = { "A" },
    flyRightKeys   = { "D" },
    flyUpKeys      = { "PAGE_UP" },
    flyDownKeys    = { "PAGE_DOWN" },
    flySpeed       = 1500,

    -- menu language: "auto" follows the game's display language (checked each time the menu opens).
    -- To fix it, use "en" English, "de" German, "fr" French, "it" Italian, "es" Spanish,
    -- "pt" Portuguese (Brazil), "pl" Polish or "ru" Russian. The texts of a language are in
    -- Scripts\lang_<code>.lua.
    language = "auto",

    -- menu position (top-left corner) and size, in UI units of a 1080p screen
    x = 60,
    y = 140,
    width = 480,
    rows = 14,

    -- look: the dark panel with the rough edge is Assets\panel.png. Set to false for a plain flat
    -- background (also the automatic fallback when the file cannot be loaded).
    backgroundImage = true,
    -- how solid the background is, 0.3 (see-through) to 1 (opaque)
    backgroundOpacity = 0.92,
    -- the ornamented line under the title is one of the game's own textures; false draws a plain line
    useGameTextures = true,

    -- teleport: after a long-distance teleport the hero floats for about this many seconds while
    -- the surroundings load, then drops to the ground. Raise it if you fall through the world on
    -- arrival; 0 switches it off.
    teleportHoldSeconds = 3,

    -- write extra lines to UE4SS.log
    debug = false,
}
