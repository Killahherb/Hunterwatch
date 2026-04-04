-- HunterWatch.lua  v1.2
-- Large centered proc tracker for MM Hunter
-- Lock and Load + Searing / Black Arrow / Poison trap procs

-- ============================================================
-- CONFIG  (edit these to reposition / resize)
-- ============================================================
local CFG = {
    iconSize    = 64,
    spacing     = 8,
    offsetX     = 0,
    offsetY     = -120,
    bgAlpha     = 0.0,
    dimAlpha    = 0.3,
    activeAlpha = 1.0,
    frameAlpha  = 0.85,
    locked      = false,
}

-- ============================================================
-- DETECTION CONSTANTS
-- ============================================================
-- In vanilla / TurtleWoW, UnitBuff/UnitDebuff return TEXTURE PATHS.
-- If procs aren't detecting, run:  /hw debug
-- Then update the "match" strings below to whatever TurtleWoW returns.

local LNL_ICON = "Interface\\Icons\\ability_hunter_lockandload"

local PROCS = {
    {
        label = "LnL",
        unit  = "player",
        kind  = "buff",
        match = LNL_ICON,
        icon  = LNL_ICON,
        glow  = {1.0, 0.85, 0.0},
    },
    {
        label = "Searing",
        unit  = "target",
        kind  = "debuff",
        match = "spell_fire",
        icon  = "Interface\\Icons\\spell_fire_selfdestruct",
        glow  = {1.0, 0.45, 0.1},
    },
    {
        label = "BlkArrow",
        unit  = "target",
        kind  = "debuff",
        match = "darkarrow",
        -- vanilla-safe shadow icon (ability_hunter_darkarrow doesn't exist)
        icon  = "Interface\\Icons\\spell_shadow_painspike",
        glow  = {0.65, 0.2, 1.0},
    },
    {
        label = "Poison",
        unit  = "target",
        kind  = "debuff",
        match = "poison",
        -- vanilla-safe poison icon (ability_poisonsting doesn't exist)
        icon  = "Interface\\Icons\\spell_nature_slowpoison",
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
local totalH = S + 16

local anchor = CreateFrame("Frame", "HunterWatchAnchor", UIParent)
anchor:SetWidth(totalW)
anchor:SetHeight(totalH)
anchor:SetPoint("CENTER", UIParent, "CENTER", CFG.offsetX, CFG.offsetY)
anchor:SetAlpha(CFG.frameAlpha)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetScript("OnDragStart", function()
    if not CFG.locked then this:StartMoving() end
end)
anchor:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

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

    local slot = CreateFrame("Frame", nil, anchor)
    slot:SetWidth(S)
    slot:SetHeight(S)
    slot:SetPoint("TOPLEFT", anchor, "TOPLEFT", xOff, 0)

    local base = slot:CreateTexture(nil, "BACKGROUND")
    base:SetAllPoints(slot)
    base:SetTexture(0, 0, 0, 0.8)

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT",     slot, "TOPLEFT",      2, -2)
    icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2,  2)
    icon:SetTexture(proc.icon)
    icon:SetAlpha(CFG.dimAlpha)
    icon:SetDesaturated(1)

    local dim = slot:CreateTexture(nil, "OVERLAY")
    dim:SetAllPoints(slot)
    dim:SetTexture(0, 0, 0, 0.45)

    local glow = slot:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT",     slot, "TOPLEFT",     -6,  6)
    glow:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT",  6, -6)
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
-- SCAN
-- ============================================================
local scanState = {}
for i = 1, N do scanState[i] = false end

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

            if b == proc.match then
                found = true; break
            elseif strfind(strlower(b), strlower(proc.match)) then
                found = true; break
            end
            i = i + 1
        end

        if found ~= scanState[idx] then
            scanState[idx] = found
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
                slot._ga = 0; slot._gd = 1
            end
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
-- GUI OPTIONS PANEL
-- ============================================================
local gui = CreateFrame("Frame", "HunterWatchOptions", UIParent)
gui:SetWidth(260)
gui:SetHeight(290)
gui:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
gui:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
    insets   = { left=4, right=4, top=4, bottom=4 },
})
gui:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
gui:SetBackdropBorderColor(0.4, 0.4, 0.5, 1)
gui:SetMovable(true)
gui:EnableMouse(true)
gui:RegisterForDrag("LeftButton")
gui:SetScript("OnDragStart", function() this:StartMoving() end)
gui:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
gui:SetFrameStrata("DIALOG")
gui:Hide()

-- Title bar accent
local titleBg = gui:CreateTexture(nil, "ARTWORK")
titleBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
titleBg:SetPoint("TOPLEFT", gui, "TOPLEFT", 4, -4)
titleBg:SetPoint("TOPRIGHT", gui, "TOPRIGHT", -4, -4)
titleBg:SetHeight(24)
titleBg:SetVertexColor(0.1, 0.35, 0.55, 0.9)

local titleText = gui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOP", gui, "TOP", 0, -9)
titleText:SetText("|cff00ccffHunterWatch|r  Options")

-- Close X
local closeBtn = CreateFrame("Button", nil, gui, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", gui, "TOPRIGHT", -2, -2)
closeBtn:SetScript("OnClick", function() gui:Hide() end)

-- ---- Slider helper ----
local function MakeSlider(parent, yOff, label, minVal, maxVal, step, initVal, fmtFunc, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetWidth(220)
    frame:SetHeight(40)
    frame:SetPoint("TOP", parent, "TOP", 0, yOff)

    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    lbl:SetText(label)

    local valText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, frame)
    slider:SetWidth(210)
    slider:SetHeight(16)
    slider:SetPoint("TOP", frame, "TOP", 0, -14)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(initVal)
    slider:SetBackdrop({
        bgFile   = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        edgeSize = 8,
        insets   = { left=3, right=3, top=6, bottom=6 },
    })
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetWidth(32)
    thumb:SetHeight(32)
    slider:SetThumbTexture(thumb)

    valText:SetText(fmtFunc(initVal))

    slider:SetScript("OnValueChanged", function()
        local v = this:GetValue()
        valText:SetText(fmtFunc(v))
        onChange(v)
    end)

    return slider
end

-- ---- Button helper ----
local function MakeButton(parent, yOff, text, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(width)
    btn:SetHeight(22)
    btn:SetPoint("TOP", parent, "TOP", 0, yOff)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

local fmtPct = function(v) return string.format("%.0f%%", v * 100) end
local fmtPx  = function(v) return string.format("%.0fpx", v) end

-- Opacity slider
local opacSlider = MakeSlider(gui, -40, "Display Opacity", 0.1, 1.0, 0.05, CFG.frameAlpha, fmtPct,
    function(v)
        CFG.frameAlpha = v
        anchor:SetAlpha(v)
    end)

-- Inactive brightness slider
local dimSlider = MakeSlider(gui, -90, "Inactive Icon Brightness", 0.0, 0.8, 0.05, CFG.dimAlpha, fmtPct,
    function(v)
        CFG.dimAlpha = v
        for _, slot in ipairs(slots) do
            if not slot.active then
                slot.icon:SetAlpha(v)
            end
        end
    end)

-- Icon size slider
local sizeSlider = MakeSlider(gui, -140, "Icon Size", 32, 96, 4, S, fmtPx,
    function(v)
        local newS = v
        local newTotalW = N * newS + (N - 1) * GAP
        anchor:SetWidth(newTotalW)
        anchor:SetHeight(newS + 16)
        for idx, slot in ipairs(slots) do
            local xOff = (idx - 1) * (newS + GAP)
            slot:SetWidth(newS)
            slot:SetHeight(newS)
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", anchor, "TOPLEFT", xOff, 0)
        end
    end)

-- Lock position button
local lockBtn = MakeButton(gui, -190, CFG.locked and "Unlock Position" or "Lock Position", 140,
    function()
        CFG.locked = not CFG.locked
        if CFG.locked then
            this:SetText("Unlock Position")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Locked.")
        else
            this:SetText("Lock Position")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Unlocked.")
        end
    end)

-- Reset position button
MakeButton(gui, -218, "Reset Position", 140,
    function()
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", CFG.offsetX, CFG.offsetY)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Reset to center.")
    end)

-- Debug dump button
MakeButton(gui, -250, "Debug: Dump Buff/Debuff Textures", 220,
    function()
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
    end)

-- ============================================================
-- MINIMAP BUTTON (round with proper border)
-- ============================================================
local mbtn = CreateFrame("Button", "HunterWatchMinimap", Minimap)
mbtn:SetWidth(31)
mbtn:SetHeight(31)
mbtn:SetFrameStrata("LOW")

-- Icon with trimmed edges so it sits inside the round border
local mbtnIcon = mbtn:CreateTexture(nil, "BACKGROUND")
mbtnIcon:SetWidth(20)
mbtnIcon:SetHeight(20)
mbtnIcon:SetPoint("CENTER", mbtn, "CENTER", 0, 0)
mbtnIcon:SetTexture(LNL_ICON)
mbtnIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- Standard minimap round border
local mbtnBorder = mbtn:CreateTexture(nil, "OVERLAY")
mbtnBorder:SetWidth(52)
mbtnBorder:SetHeight(52)
mbtnBorder:SetPoint("CENTER", mbtn, "CENTER", 0, 0)
mbtnBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Left-click = open GUI  |  Right-click = toggle display
mbtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mbtn:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
        if gui:IsShown() then gui:Hide() else gui:Show() end
    elseif arg1 == "RightButton" then
        if anchor:IsShown() then
            anchor:Hide()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Hidden.")
        else
            anchor:Show()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Shown.")
        end
    end
end)

mbtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("HunterWatch")
    GameTooltip:AddLine("|cffffffffLeft-Click:|r  Options", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffffffffRight-Click:|r Toggle Display", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
mbtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Draggable around minimap edge
local minimapAngle = 220
local function UpdateMinimapPosition()
    local rad = math.rad(minimapAngle)
    mbtn:ClearAllPoints()
    mbtn:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(rad) * 80, math.sin(rad) * 80)
end
UpdateMinimapPosition()

mbtn:RegisterForDrag("LeftButton")
mbtn:SetMovable(true)
mbtn:SetScript("OnDragStart", function() this.dragging = true end)
mbtn:SetScript("OnDragStop",  function() this.dragging = false end)
mbtn:SetScript("OnUpdate", function()
    if this.dragging then
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local s = UIParent:GetEffectiveScale()
        minimapAngle = math.deg(math.atan2(cy/s - my, cx/s - mx))
        UpdateMinimapPosition()
    end
end)

-- ============================================================
-- SLASH COMMANDS
-- ============================================================
SLASH_HUNTERWATCH1 = "/hw"
SlashCmdList["HUNTERWATCH"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "reset" then
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", CFG.offsetX, CFG.offsetY)
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r Reset.")
    elseif msg == "options" or msg == "opt" or msg == "config" then
        if gui:IsShown() then gui:Hide() else gui:Show() end
    elseif msg == "big" then
        anchor:SetAlpha(1.0); opacSlider:SetValue(1.0)
    elseif msg == "half" then
        anchor:SetAlpha(0.5); opacSlider:SetValue(0.5)
    elseif msg == "show" then
        anchor:Show()
    elseif msg == "hide" then
        anchor:Hide()
    elseif msg == "lock" then
        CFG.locked = not CFG.locked
        lockBtn:SetText(CFG.locked and "Unlock Position" or "Lock Position")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch:|r " .. (CFG.locked and "Locked." or "Unlocked."))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch|r commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw options - open settings")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw reset   - recenter")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw show/hide")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw lock    - toggle drag lock")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw big/half - opacity presets")
        DEFAULT_CHAT_FRAME:AddMessage("  /hw debug   - dump textures")
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffHunterWatch v1.2|r loaded. Click minimap icon or type /hw")
