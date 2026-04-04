-- HunterWatch.lua
-- MM Hunter proc tracker: Lock and Load + trap procs
-- Features: minimap button, config panel, draggable icons

-- ============================================================
-- SAVED CONFIG (persists between sessions)
-- ============================================================
HunterWatchDB = HunterWatchDB or {
    offsetX   = 0,
    offsetY   = -120,
    iconSize  = 64,
    opacity   = 0.85,
    mmAngle   = 45,   -- minimap button angle in degrees
}

local CFG = HunterWatchDB

-- ============================================================
-- DETECTION DATA
-- ============================================================
local LNL_ICON = "Interface\\Icons\\ability_hunter_lockandload"

local PROCS = {
    {
        label = "LnL",
        kind  = "buff",
        match = LNL_ICON,
        icon  = "Interface\\Icons\\ability_hunter_lockandload",
        glow  = {1.0, 0.85, 0.0},
    },
    {
        label = "Searing",
        kind  = "debuff",
        match = "Searing",
        icon  = "Interface\\Icons\\spell_fire_selfdestruct",
        glow  = {1.0, 0.45, 0.1},
    },
    {
        label = "BlkArrow",
        kind  = "debuff",
        match = "Black Arrow",
        icon  = "Interface\\Icons\\ability_hunter_blackarrow",
        glow  = {0.65, 0.2, 1.0},
    },
    {
        label = "Poison",
        kind  = "debuff",
        match = "Poison",
        icon  = "Interface\\Icons\\ability_poisonsting",
        glow  = {0.3, 1.0, 0.3},
    },
}

-- ============================================================
-- MINIMAP BUTTON
-- ============================================================
local mmButton = CreateFrame("Button", "HunterWatchMinimap", Minimap)
mmButton:SetWidth(32)
mmButton:SetHeight(32)
mmButton:SetFrameStrata("MEDIUM")
mmButton:SetFrameLevel(8)

-- circular button texture
local mmIcon = mmButton:CreateTexture(nil, "BACKGROUND")
mmIcon:SetAllPoints(mmButton)
mmIcon:SetTexture("Interface\\Icons\\ability_hunter_lockandload")
mmIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

-- circular border
local mmBorder = mmButton:CreateTexture(nil, "OVERLAY")
mmBorder:SetWidth(54)
mmBorder:SetHeight(54)
mmBorder:SetPoint("CENTER", mmButton, "CENTER", 0, 0)
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Position button on minimap edge by angle
local function UpdateMinimapPos()
    local angle = math.rad(CFG.mmAngle or 45)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    mmButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
UpdateMinimapPos()

-- Drag around minimap edge
mmButton:SetMovable(true)
mmButton:RegisterForDrag("LeftButton")
mmButton:SetScript("OnDragStart", function() this:StartMoving() end)
mmButton:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    -- recalculate angle from final position
    local cx = Minimap:GetLeft() + Minimap:GetWidth()/2
    local cy = Minimap:GetBottom() + Minimap:GetHeight()/2
    local bx = this:GetLeft() + this:GetWidth()/2
    local by = this:GetBottom() + this:GetHeight()/2
    CFG.mmAngle = math.deg(math.atan2(by - cy, bx - cx))
    UpdateMinimapPos()
end)

-- ============================================================
-- CONFIG PANEL
-- ============================================================
local panel = CreateFrame("Frame", "HunterWatchPanel", UIParent)
panel:SetWidth(240)
panel:SetHeight(200)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
panel:Hide()

panel:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets   = { left=4, right=4, top=4, bottom=4 },
})
panel:SetBackdropColor(0.05, 0.05, 0.10, 0.95)
panel:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)

-- Title
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", panel, "TOP", 0, -10)
title:SetText("|cff00ccffHunterWatch|r Settings")

-- Close button
local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
closeBtn:SetScript("OnClick", function() panel:Hide() end)

-- Helper: make a simple label
local function MakeLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    fs:SetText(text)
    fs:SetTextColor(0.8, 0.8, 0.8)
    return fs
end

-- Helper: make a simple slider
local function MakeSlider(parent, label, minV, maxV, step, x, y, w, getter, setter)
    local lbl = MakeLabel(parent, label, x, y)

    local sl = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    sl:SetWidth(w)
    sl:SetHeight(16)
    sl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(y + 18))
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    sl:SetValue(getter())
    getglobal(sl:GetName().."Low"):SetText(minV)
    getglobal(sl:GetName().."High"):SetText(maxV)
    getglobal(sl:GetName().."Text"):SetText("")

    local valLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", x + w + 6, -(y + 20))
    valLabel:SetTextColor(1, 1, 0)
    valLabel:SetText(string.format("%.2f", getter()))

    sl:SetScript("OnValueChanged", function()
        setter(this:GetValue())
        valLabel:SetText(string.format("%.2f", this:GetValue()))
    end)
    return sl
end

-- Opacity slider
MakeSlider(panel, "Opacity", 0.1, 1.0, 0.05, 16, 40, 170,
    function() return CFG.opacity end,
    function(v)
        CFG.opacity = v
        if HunterWatchAnchor then HunterWatchAnchor:SetAlpha(v) end
    end
)

-- Icon size slider
MakeSlider(panel, "Icon Size", 32, 96, 4, 16, 90, 170,
    function() return CFG.iconSize end,
    function(v)
        CFG.iconSize = v
        -- size change requires reload
    end
)

-- Reload note
local reloadNote = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
reloadNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -130)
reloadNote:SetText("|cffaaaaaa(Icon size change needs /reload)|r")

-- Reset position button
local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetBtn:SetWidth(100)
resetBtn:SetHeight(22)
resetBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 14)
resetBtn:SetText("Reset Position")
resetBtn:SetScript("OnClick", function()
    HunterWatchAnchor:ClearAllPoints()
    HunterWatchAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    CFG.offsetX = 0
    CFG.offsetY = -120
end)

-- Toggle lock button
local lockBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
lockBtn:SetWidth(80)
lockBtn:SetHeight(22)
lockBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 14)
lockBtn:SetText("Lock Frame")
local frameLocked = false
lockBtn:SetScript("OnClick", function()
    frameLocked = not frameLocked
    if frameLocked then
        HunterWatchAnchor:EnableMouse(false)
        lockBtn:SetText("Unlock Frame")
    else
        HunterWatchAnchor:EnableMouse(true)
        lockBtn:SetText("Lock Frame")
    end
end)

-- Minimap button click = toggle panel
mmButton:SetScript("OnClick", function()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end)

-- Tooltip on hover
mmButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("|cff00ccffHunterWatch|r")
    GameTooltip:AddLine("Left-click to open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag to move around minimap", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
mmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ============================================================
-- MAIN ICON ANCHOR
-- ============================================================
local S   = CFG.iconSize
local GAP = 8
local N   = table.getn(PROCS)
local totalW = N * S + (N - 1) * GAP

local anchor = CreateFrame("Frame", "HunterWatchAnchor", UIParent)
anchor:SetWidth(totalW)
anchor:SetHeight(S + 18)
anchor:SetPoint("CENTER", UIParent, "CENTER", CFG.offsetX, CFG.offsetY)
anchor:SetAlpha(CFG.opacity)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetScript("OnDragStart", function() this:StartMoving() end)
anchor:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)

-- ============================================================
-- BUILD ICON SLOTS
-- ============================================================
local slots = {}

for idx, proc in ipairs(PROCS) do
    local xOff = (idx - 1) * (S + GAP)

    local slot = CreateFrame("Frame", nil, anchor)
    slot:SetWidth(S)
    slot:SetHeight(S)
    slot:SetPoint("TOPLEFT", anchor, "TOPLEFT", xOff, 0)

    local base = slot:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints(slot)
    base:SetTexture(0, 0, 0, 1)

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     slot, "TOPLEFT",      2, -2)
    icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2,  2)
    icon:SetTexture(proc.icon)
    icon:SetAlpha(0.2)
    icon:SetDesaturated(1)

    local dim = slot:CreateTexture(nil, "OVERLAY")
    dim:SetAllPoints(slot)
    dim:SetTexture(0, 0, 0, 0.6)

    local glow = slot:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT",     slot, "TOPLEFT",     -8,  8)
    glow:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT",  8, -8)
    glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)

    local border = slot:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT",     slot, "TOPLEFT",      0,  0)
    border:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT",  0,  0)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetAlpha(0)

    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", slot, "BOTTOM", 0, -2)
    label:SetText(proc.label)
    label:SetTextColor(0.5, 0.5, 0.5)

    slot.icon   = icon
    slot.dim    = dim
    slot.glow   = glow
    slot.border = border
    slot.label  = label
    slot.proc   = proc
    slot.active = false
    slot._ga    = 0
    slot._gd    = 1

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
        slot.icon:SetAlpha(1.0)
        slot.icon:SetDesaturated(nil)
        slot.dim:SetAlpha(0)
        slot.border:SetAlpha(0.7)
        slot.label:SetTextColor(r, g, b)
        slot._ga = 0; slot._gd = 1
    else
        slot.icon:SetAlpha(0.2)
        slot.icon:SetDesaturated(1)
        slot.dim:SetAlpha(0.6)
        slot.glow:SetAlpha(0)
        slot.border:SetAlpha(0)
        slot._ga = 0
        slot.label:SetTextColor(0.45, 0.45, 0.45)
    end
end

-- ============================================================
-- SCAN
-- ============================================================
local state = {}
for i = 1, N do state[i] = false end

local function Scan()
    for idx, proc in ipairs(PROCS) do
        local found = false
        local i = 1
        while true do
            local b
            if proc.kind == "buff" then
                b = UnitBuff("player", i)
            else
                b = UnitDebuff("player", i)
            end
            if not b then break end
            if proc.kind == "buff" then
                if b == proc.match then found = true; break end
            else
                if strfind(b, proc.match) then found = true; break end
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
-- ONUPDATE
-- ============================================================
local elapsed = 0
anchor:SetScript("OnUpdate", function()
    elapsed = elapsed + arg1
    if elapsed >= 0.1 then elapsed = 0; Scan() end
    for _, slot in ipairs(slots) do
        if slot.active then
            slot._ga = slot._ga + slot._gd * 0.03
            if slot._ga >= 0.5 then slot._ga = 0.5; slot._gd = -1
            elseif slot._ga <= 0 then slot._ga = 0; slot._gd = 1 end
            slot.glow:SetAlpha(slot._ga)
        end
    end
end)

-- ============================================================
-- EVENTS
-- ============================================================
anchor:RegisterEvent("PLAYER_LOGIN")
anchor:RegisterEvent("UNIT_AURA")
anchor:SetScript("OnEvent", Scan)

-- ============================================================
-- SLASH
-- ============================================================
SLASH_HUNTERWATCH1 = "/hw"
SlashCmdList["HUNTERWATCH"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "reset" then
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    elseif msg == "menu" or msg == "" then
        if panel:IsShown() then panel:Hide() else panel:Show() end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r /hw menu | /hw reset")
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch|r loaded. Click the minimap icon or type /hw.")
