-- HunterWatch.lua  v1.1
-- Large centered proc tracker for MM Hunter
-- Lock and Load + Searing / Black Arrow / Poison trap procs

-- ============================================================
-- CONFIG  (edit these to reposition / resize)
-- ============================================================
local CFG = {
    iconSize    = 64,       -- icon width/height in pixels
    spacing     = 8,        -- gap between icons
    offsetX     = 0,        -- horizontal offset from screen center
    offsetY     = -120,     -- vertical offset (negative = lower half)
    bgAlpha     = 0.0,      -- background alpha (0 = no bg box)
    dimAlpha    = 0.3,      -- how faint inactive icons are (raised from 0.15)
    activeAlpha = 1.0,      -- opacity of active icons
    frameAlpha  = 0.85,     -- overall frame alpha (raised from 0.5)
}

-- ============================================================
-- DETECTION CONSTANTS
-- ============================================================
-- NOTE: In vanilla WoW / TurtleWoW, UnitBuff/UnitDebuff return the
-- TEXTURE PATH, not the spell name.  We must match on texture paths.
--
-- If procs aren't detecting, run:  /hw debug
-- This prints all buff/debuff textures so you can fix the paths below.

local LNL_ICON = "Interface\\Icons\\ability_hunter_lockandload"

local PROCS = {
    {
        label = "LnL",
        unit  = "player",        -- LnL is a buff on YOU
        kind  = "buff",
        match = LNL_ICON,        -- full texture path match
        icon  = LNL_ICON,
        glow  = {1.0, 0.85, 0.0},
    },
    {
        label = "Searing",
        unit  = "target",        -- debuff on TARGET (was "player" - bug)
        kind  = "debuff",
        match = "spell_fire",    -- partial match on texture path
        icon  = "Interface\\Icons\\spell_fire_selfdestruct",
        glow  = {1.0, 0.45, 0.1},
    },
    {
        label = "BlkArrow",
        unit  = "target",        -- debuff on TARGET (was "player" - bug)
        kind  = "debuff",
        match = "darkarrow",     -- partial match on texture path
        icon  = "Interface\\Icons\\ability_hunter_darkarrow",
        glow  = {0.65, 0.2, 1.0},
    },
    {
        label = "Poison",
        unit  = "target",        -- debuff on TARGET (was "player" - bug)
        kind  = "debuff",
        match = "poisonsting",   -- partial match on texture path
        icon  = "Interface\\Icons\\ability_poisonsting",
        glow  = {0.3, 1.0, 0.3},
    },
}

-- ============================================================
-- BUILD MAIN FRAME
-- ============================================================
local S    = CFG.iconSize
local GAP  = CFG.spacing
local N    = table.getn(PROCS)
local totalW = N * S + (N - 1) * GAP
local totalH = S + 16   -- icon + label

local anchor = CreateFrame("Frame", "HunterWatchAnchor", UIParent)
anchor:SetWidth(totalW)
anchor:SetHeight(totalH)
anchor:SetPoint("CENTER", UIParent, "CENTER", CFG.offsetX, CFG.offsetY)
anchor:SetAlpha(CFG.frameAlpha)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetScript("OnDragStart", function() this:StartMoving() end)
anchor:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)

-- Optional subtle bg
if CFG.bgAlpha > 0 then
    anchor:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left=2, right=2, top=2, bottom=2 },
    })
    anchor:SetBackdropColor(0, 0, 0, CFG.bgAlpha)
    anchor:SetBackdropBorderColor(0.2, 0.2, 0.25, CFG.bgAlpha)
end

-- ============================================================
-- BUILD ICON SLOTS
-- ============================================================
local slots = {}

for idx, proc in ipairs(PROCS) do
    local xOff = (idx - 1) * (S + GAP)

    -- slot frame
    local slot = CreateFrame("Frame", nil, anchor)
    slot:SetWidth(S)
    slot:SetHeight(S)
    slot:SetPoint("TOPLEFT", anchor, "TOPLEFT", xOff, 0)

    -- black base (slightly smaller to act as border)
    local base = slot:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints(slot)
    base:SetTexture(0, 0, 0, 0.8)

    -- icon texture
    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     slot, "TOPLEFT",      2, -2)
    icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2,  2)
    icon:SetTexture(proc.icon)
    icon:SetAlpha(CFG.dimAlpha)

    -- desaturate when inactive (greyed out look)
    icon:SetDesaturated(1)

    -- dim overlay
    local dim = slot:CreateTexture(nil, "OVERLAY")
    dim:SetAllPoints(slot)
    dim:SetTexture(0, 0, 0, 0.45)

    -- glow / shine overlay
    local glow = slot:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT",     slot, "TOPLEFT",     -6,  6)
    glow:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT",  6, -6)
    glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)

    -- cooldown-style border
    local border = slot:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT",     slot, "TOPLEFT",      0,  0)
    border:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT",  0,  0)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetAlpha(0)

    -- label below icon
    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", slot, "BOTTOM", 0, -1)
    label:SetText(proc.label)
    label:SetTextColor(0.5, 0.5, 0.5)

    slot.icon   = icon
    slot.dim    = dim
    slot.glow   = glow
    slot.border = border
    slot.label  = label
    slot.proc   = proc
    slot.active = false
    slot._ga    = 0   -- glow alpha
    slot._gd    = 1   -- glow direction

    slots[idx] = slot
end

-- ============================================================
-- ACTIVATE / DEACTIVATE
-- ============================================================
local function SetActive(slot, on)
    if slot.active == on then return end
    slot.active = on
    local r, g, b = slot.proc.glow[1], slot.proc.glow[2], slot.proc.glow[3]

    if on then
        slot.icon:SetAlpha(CFG.activeAlpha)
        slot.icon:SetDesaturated(nil)
        slot.dim:SetAlpha(0)
        slot.border:SetAlpha(0.6)
        slot.label:SetTextColor(r, g, b)
        slot._ga = 0
        slot._gd = 1
    else
        slot.icon:SetAlpha(CFG.dimAlpha)
        slot.icon:SetDesaturated(1)
        slot.dim:SetAlpha(0.45)
        slot.glow:SetAlpha(0)
        slot.border:SetAlpha(0)
        slot._ga = 0
        slot.label:SetTextColor(0.45, 0.45, 0.45)
    end
end

-- ============================================================
-- SCAN  (fixed: checks correct unit, matches texture paths)
-- ============================================================
local state = {}
for i = 1, N do state[i] = false end

local function Scan()
    for idx, proc in ipairs(PROCS) do
        local found = false
        local unit = proc.unit or "player"
        local i = 1
        while true do
            local b
            if proc.kind == "buff" then
                b = UnitBuff(unit, i)
            else
                b = UnitDebuff(unit, i)
            end
            if not b then break end

            -- match: exact match first, then strfind fallback
            if b == proc.match then
                found = true
                break
            elseif strfind(strlower(b), strlower(proc.match)) then
                found = true
                break
            end

            i = i + 1
        end

        if found ~= state[idx] then
            state[idx] = found
            SetActive(slots[idx], found)
        end
    end
end

-- ============================================================
-- ONUPDATE: scan + pulse glow
-- ============================================================
local elapsed = 0
anchor:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 0.1 then
        elapsed = 0
        Scan()
    end

    for _, slot in ipairs(slots) do
        if slot.active then
            slot._ga = slot._ga + slot._gd * 0.03
            if slot._ga >= 0.45 then
                slot._ga = 0.45; slot._gd = -1
            elseif slot._ga <= 0 then
                slot._ga = 0;    slot._gd = 1
            end
            slot.glow:SetAlpha(slot._ga)
        end
    end
end)

-- ============================================================
-- MINIMAP BUTTON
-- ============================================================
local mbtn = CreateFrame("Button", "HunterWatchMinimap", Minimap)
mbtn:SetWidth(31)
mbtn:SetHeight(31)
mbtn:SetFrameStrata("LOW")
mbtn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -2)

-- icon texture (hunter tracking icon, round-friendly)
local mbtnIcon = mbtn:CreateTexture(nil, "BACKGROUND")
mbtnIcon:SetWidth(20)
mbtnIcon:SetHeight(20)
mbtnIcon:SetPoint("CENTER", mbtn, "CENTER", 0, 0)
mbtnIcon:SetTexture("Interface\\Icons\\ability_hunter_lockandload")

-- round border overlay (standard minimap button look)
local mbtnBorder = mbtn:CreateTexture(nil, "OVERLAY")
mbtnBorder:SetWidth(52)
mbtnBorder:SetHeight(52)
mbtnBorder:SetPoint("CENTER", mbtn, "CENTER", 0, 0)
mbtnBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- click toggles the display
mbtn:SetScript("OnClick", function()
    if anchor:IsShown() then
        anchor:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Display hidden.")
    else
        anchor:Show()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Display shown.")
    end
end)

mbtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("HunterWatch")
    GameTooltip:AddLine("Click to toggle display", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Type /hw for options", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)
mbtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- draggable around minimap edge
local minimapAngle = 220
local function UpdateMinimapPosition()
    local rad = math.rad(minimapAngle)
    local x = math.cos(rad) * 80
    local y = math.sin(rad) * 80
    mbtn:ClearAllPoints()
    mbtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
UpdateMinimapPosition()

mbtn:RegisterForDrag("LeftButton")
mbtn:SetMovable(true)
mbtn:SetScript("OnDragStart", function()
    this.dragging = true
end)
mbtn:SetScript("OnDragStop", function()
    this.dragging = false
end)
mbtn:SetScript("OnUpdate", function()
    if this.dragging then
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
        UpdateMinimapPosition()
    end
end)

-- ============================================================
-- EVENTS
-- ============================================================
anchor:RegisterEvent("PLAYER_LOGIN")
anchor:RegisterEvent("UNIT_AURA")
anchor:SetScript("OnEvent", Scan)

-- ============================================================
-- DEBUG: prints all buff/debuff textures so you can verify paths
-- ============================================================
local function DebugDump()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch DEBUG:|r --- Player Buffs ---")
    local i = 1
    while true do
        local b = UnitBuff("player", i)
        if not b then break end
        DEFAULT_CHAT_FRAME:AddMessage("  Buff " .. i .. ": |cffffffff" .. b .. "|r")
        i = i + 1
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch DEBUG:|r --- Target Debuffs ---")
    if UnitExists("target") then
        i = 1
        while true do
            local b = UnitDebuff("target", i)
            if not b then break end
            DEFAULT_CHAT_FRAME:AddMessage("  Debuff " .. i .. ": |cffffffff" .. b .. "|r")
            i = i + 1
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("  (no target selected)")
    end
end

-- ============================================================
-- SLASH
-- ============================================================
SLASH_HUNTERWATCH1 = "/hw"
SlashCmdList["HUNTERWATCH"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "reset" then
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", CFG.offsetX, CFG.offsetY)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Reset to default position.")
    elseif msg == "big" then
        anchor:SetAlpha(1.0)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Full opacity.")
    elseif msg == "half" then
        anchor:SetAlpha(0.5)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r 50% opacity.")
    elseif msg == "debug" then
        DebugDump()
    elseif msg == "show" then
        anchor:Show()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Display shown.")
    elseif msg == "hide" then
        anchor:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Display hidden.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Drag to move. Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw reset  - recenter display")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw show   - show display")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw hide   - hide display")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw big    - full opacity")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw half   - 50% opacity")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw debug  - dump all buff/debuff textures")
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch v1.1|r loaded. Type /hw for help.")
