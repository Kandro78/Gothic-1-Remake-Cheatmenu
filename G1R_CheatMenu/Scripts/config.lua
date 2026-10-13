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

    -- menu position (top-left corner) and size, in UI units of a 1080p screen
    x = 60,
    y = 140,
    width = 480,
    rows = 14,

    -- look: the menu uses the game's own panel background and title ornament. Set to false for
    -- plain flat colors (also the automatic fallback when a texture cannot be found).
    useGameTextures = true,
    -- how solid the dark background is, 0.3 (see-through) to 1 (opaque)
    backgroundOpacity = 0.92,

    -- write extra lines to UE4SS.log
    debug = false,
}
