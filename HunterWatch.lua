-- HunterWatch.lua
-- Tracks Lock and Load (buff icon check) and active trap procs on PLAYER
-- Logic mirrors the MM Hunter Lock and Load macro

local ADDON_NAME = "HunterWatch"

-- ============================================================
-- CONSTANTS
-- ============================================================
local LNL_ICON = "Interface\\Icons\\ability_hunter_lockandload"

-- Trap procs detected on PLAYER debuffs (same as macro)
local TRAP_PROCS = {
    { label = "Searing",     match = "Searing",    icon = "Interface\\Icons\\spell_fire_selfdestruct",  color = {1.0, 0.4, 0.1} },
    { label = "Black Arrow", match = "BlackArrow",  icon = "Interface\\Icons\\ability_hunter_darkarrow", color = {0.6, 0.2, 1.0} },
    { label = "Poison",      match = "Poison",      icon = "Interface\\Icons\\ability_poisonsting",      color = {0.3, 1.0, 0.3} },
}

-- ============================================================
-- MAIN FRAME
-- ============================================================
local f = CreateFrame("Frame", "HunterWatchFrame", UIParent)
f:SetWidth(200)
f:SetHeight(60)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)

f:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
f:SetBackdropColor(0.04, 0.04, 0.07, 0.88)
f:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.9)

-- ============================================================
-- HELPER: create one icon slot
-- ============================================================
local function MakeIconSlot(parent, x, y, size)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetWidth(size)
    slot:SetHeight(size)
    slot:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)

    -- black bg
    local bg2 = slot:CreateTexture(nil, "BACKGROUND")
    bg2:SetAllPoints(slot)
    bg2:SetTexture(0.0, 0.0, 0.0, 1)

    -- icon
    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     slot, "TOPLEFT",     1, -1)
    icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    icon:SetTexture("")

    -- dim overlay
    local dim = slot:CreateTexture(nil, "OVERLAY")
    dim:SetAllPoints(slot)
    dim:SetTexture(0, 0, 0, 0.65)

    -- glow
    local glow = slot:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT",     slot, "TOPLEFT",     -4,  4)
    glow:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT",  4, -4)
    glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)

    -- label
    local label = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", slot, "BOTTOM", 0, -1)
    label:SetTextColor(0.5, 0.5, 0.5)

    slot.icon        = icon
    slot.dim         = dim
    slot.glow        = glow
    slot.label       = label
    slot.active      = false
    slot._glowAlpha  = 0
    slot._glowDir    = 1
    return slot
end

-- ============================================================
-- BUILD LAYOUT
-- ============================================================
local ICON_BIG   = 40
local ICON_SMALL = 32
local PAD        = 6

-- LnL slot (bigger, left)
local lnlSlot = MakeIconSlot(f, 10, 10, ICON_BIG)
lnlSlot.icon:SetTexture(LNL_ICON)
lnlSlot.label:SetText("LnL")

-- divider
local div = f:CreateTexture(nil, "ARTWORK")
div:SetWidth(1)
div:SetPoint("TOPLEFT",    f, "TOPLEFT", 10 + ICON_BIG + PAD, -(10 - 4))
div:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 10 + ICON_BIG + PAD, -(10 + ICON_BIG - 4))
div:SetTexture(0.3, 0.3, 0.38, 0.8)

-- Trap slots
local trapSlots = {}
local trapStartX = 10 + ICON_BIG + PAD*2 + 2
local trapY = 10 + (ICON_BIG - ICON_SMALL) / 2  -- vertically center smaller icons
for idx, trap in ipairs(TRAP_PROCS) do
    local x = trapStartX + (idx - 1) * (ICON_SMALL + PAD)
    local slot = MakeIconSlot(f, x, trapY, ICON_SMALL)
    slot.icon:SetTexture(trap.icon)
    slot.label:SetText(trap.label)
    slot.color = trap.color
    trapSlots[idx] = slot
end

-- Fit frame width
local totalW = trapStartX + #TRAP_PROCS * (ICON_SMALL + PAD) + PAD
f:SetWidth(totalW)
f:SetHeight(ICON_BIG + 10 + 16)  -- icon + top pad + label room

-- ============================================================
-- ACTIVATE / DEACTIVATE
-- ============================================================
local function SetActive(slot, active, r, g, b)
    slot.active = active
    if active then
        slot.dim:SetAlpha(0)
        slot.label:SetTextColor(r or 1, g or 1, b or 1)
        slot._glowAlpha = 0
        slot._glowDir   = 1
    else
        slot.dim:SetAlpha(0.65)
        slot.glow:SetAlpha(0)
        slot._glowAlpha = 0
        slot.label:SetTextColor(0.45, 0.45, 0.45)
    end
end

-- ============================================================
-- SCAN
-- ============================================================
local lnlActive  = false
local trapActive = { false, false, false }

local function Scan()
    -- Lock and Load: UnitBuff returns icon path in vanilla — match icon string
    local newLnL = false
    local i = 1
    while true do
        local b = UnitBuff("player", i)
        if not b then break end
        if b == LNL_ICON then
            newLnL = true
            break
        end
        i = i + 1
    end

    -- Trap procs on player debuffs (strfind, same as macro)
    local newTrap = { false, false, false }
    i = 1
    while true do
        local b = UnitDebuff("player", i)
        if not b then break end
        for idx, trap in ipairs(TRAP_PROCS) do
            if strfind(b, trap.match) then
                newTrap[idx] = true
            end
        end
        i = i + 1
    end

    -- Update LnL
    if newLnL ~= lnlActive then
        lnlActive = newLnL
        SetActive(lnlSlot, lnlActive, 1.0, 0.85, 0.0)
        if lnlActive then
            f:SetBackdropBorderColor(1.0, 0.85, 0.0, 1.0)
        else
            f:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.9)
        end
    end

    -- Update trap slots
    for idx, trap in ipairs(TRAP_PROCS) do
        if newTrap[idx] ~= trapActive[idx] then
            trapActive[idx] = newTrap[idx]
            local c = trapSlots[idx].color
            SetActive(trapSlots[idx], newTrap[idx], c[1], c[2], c[3])
        end
    end
end

-- ============================================================
-- ONUPDATE: throttled scan + pulse
-- ============================================================
local elapsed = 0
f:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 0.1 then
        elapsed = 0
        Scan()
    end

    local function Pulse(slot)
        if not slot.active then return end
        slot._glowAlpha = slot._glowAlpha + slot._glowDir * 0.025
        if slot._glowAlpha >= 0.35 then
            slot._glowAlpha = 0.35; slot._glowDir = -1
        elseif slot._glowAlpha <= 0 then
            slot._glowAlpha = 0;    slot._glowDir = 1
        end
        slot.glow:SetAlpha(slot._glowAlpha)
    end

    Pulse(lnlSlot)
    for _, s in ipairs(trapSlots) do Pulse(s) end
end)

-- ============================================================
-- EVENTS
-- ============================================================
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UNIT_AURA")
f:SetScript("OnEvent", Scan)

-- ============================================================
-- SLASH COMMANDS
-- ============================================================
SLASH_HUNTERWATCH1 = "/hw"
SlashCmdList["HUNTERWATCH"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "reset" then
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Position reset.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Drag to move. /hw reset to recenter.")
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch|r loaded.")
