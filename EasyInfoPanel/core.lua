--[[
    ============================================================================
    FPS & MS Monitor
    Copyright (c) 2021-2026 Pytilix
    All rights reserved.

    This Add-on and its source code are proprietary. 
    Unauthorized copying, modification, or distribution of this file, 
    via any medium, is strictly prohibited.
    
    The source code is provided for personal use and educational purposes 
    only, as per Blizzard's UI Add-On Development Policy.
    ============================================================================
--]]

local AddonName = "Easy-Info-Panel"
local f = CreateFrame("Frame", "EasyInfoPanelFrame", UIParent)

-- 1. DATABASE
local defaults = {
    point = "TOP", xOfs = 0, yOfs = -20, fontSize = 14,
    showFPS = true, showMS = true, showDurability = true, 
    showBags = true, showClock = true, showGold = true, showCoords = true,
}

local sessionGold = 0

-- 2. COLOR LOGIC HELPERS
local function Colorize(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, text)
end

local function GetStatusColor(val, low, high, reverse)
    if reverse then -- Für MS (höher ist schlechter)
        if val < low then return 0, 1, 0 end -- Grün
        if val < high then return 1, 0.8, 0 end -- Gelb
        return 1, 0, 0 -- Rot
    else -- Für FPS/Durability (höher ist besser)
        if val >= high then return 0, 1, 0 end 
        if val >= low then return 1, 0.8, 0 end 
        return 1, 0, 0 
    end
end

-- 3. UTILS
local function GetFreeBagSlots()
    local free, total = 0, 0
    for i = 0, 4 do
        local slots = (C_Container and C_Container.GetContainerNumSlots(i)) or GetContainerNumSlots(i)
        local freeSlots = (C_Container and C_Container.GetContainerNumFreeSlots(i)) or GetContainerNumFreeSlots(i)
        if slots then total = total + slots end
        if freeSlots then free = free + freeSlots end
    end
    return free, total
end

-- 4. OPTIONS WINDOW
local opt = CreateFrame("Frame", "EasyInfoPanel_Options", UIParent, "BackdropTemplate")
opt:SetSize(220, 420)
opt:SetPoint("CENTER")
opt:SetFrameStrata("DIALOG")
opt:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 16, insets = {left=5,right=5,top=5,bottom=5}})
opt:SetBackdropColor(0,0,0,0.9)
opt:Hide()
tinsert(UISpecialFrames, "EasyInfoPanel_Options")

local title = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -15)
title:SetText("Easy Info Panel")

local function CreateRow(parent, label, yOff, key)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    cb:SetSize(20, 20)
    cb:SetPoint("TOPLEFT", 35, yOff)
    cb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    cb:SetBackdropColor(0.15, 0.15, 0.15, 1)
    cb:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    local chk = cb:CreateTexture(nil, "OVERLAY")
    chk:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    chk:SetPoint("CENTER", 0, 0)
    chk:SetSize(24, 24)
    cb:SetCheckedTexture(chk)
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", cb, "RIGHT", 10, 0)
    t:SetText(label)
    cb:SetScript("OnClick", function(self) EasyInfoPanelDB[key] = self:GetChecked() end)
    cb:SetScript("OnShow", function(self) self:SetChecked(EasyInfoPanelDB[key]) end)
end

local rows = {{"FPS", "showFPS"}, {"Latency", "showMS"}, {"Coords", "showCoords"}, {"Durability", "showDurability"}, {"Bags", "showBags"}, {"Gold", "showGold"}, {"Clock", "showClock"}}
for i, r in ipairs(rows) do CreateRow(opt, r[1], -50 - (i*30), r[2]) end

local res = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate") 
res:SetSize(140, 25) res:SetPoint("BOTTOM", 0, 50) res:SetText("Reset Position") 
res:SetScript("OnClick", function() EasyInfoPanelDB.point, EasyInfoPanelDB.xOfs, EasyInfoPanelDB.yOfs = "TOP", 0, -20 f:ClearAllPoints() f:SetPoint("TOP", UIParent, "TOP", 0, -20) end)

local cls = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate") 
cls:SetSize(100, 25) cls:SetPoint("BOTTOM", 0, 20) cls:SetText("Close") 
cls:SetScript("OnClick", function() opt:Hide() end)

-- 5. INITIALIZATION & UPDATE
local function Init()
    if not EasyInfoPanelDB then EasyInfoPanelDB = {} end
    for k, v in pairs(defaults) do if EasyInfoPanelDB[k] == nil then EasyInfoPanelDB[k] = v end end
    sessionGold = GetMoney()
    
    f:SetSize(1, 20) f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
    f:SetPoint(EasyInfoPanelDB.point, UIParent, EasyInfoPanelDB.point, EasyInfoPanelDB.xOfs, EasyInfoPanelDB.yOfs)
    f.text = f:CreateFontString(nil, "OVERLAY") 
    f.text:SetPoint("CENTER", f)
    
    f:SetScript("OnMouseDown", function(self) if IsAltKeyDown() then self:StartMoving() end end)
    f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() local p, _, _, x, y = self:GetPoint() EasyInfoPanelDB.point, EasyInfoPanelDB.xOfs, EasyInfoPanelDB.yOfs = p, x, y end)

    f:SetScript("OnUpdate", function(self, elapsed)
        self.t = (self.t or 0) + elapsed
        if self.t > 0.2 then
            local db = EasyInfoPanelDB
            f.text:SetFont(STANDARD_TEXT_FONT, db.fontSize, "THINOUTLINE")
            local p = {}
            
            if db.showFPS then 
                local fps = floor(GetFramerate())
                table.insert(p, Colorize(fps .. " fps", GetStatusColor(fps, 30, 50))) 
            end
            
            if db.showMS then 
                local _, _, _, ms = GetNetStats()
                table.insert(p, Colorize((ms or 0) .. " ms", GetStatusColor(ms or 0, 100, 250, true))) 
            end
            
            if db.showCoords then 
                local m = C_Map.GetBestMapForUnit("player")
                local x, y = 0, 0
                if m then local pos = C_Map.GetPlayerMapPosition(m, "player") if pos then x,y = pos.x*100, pos.y*100 end end
                table.insert(p, Colorize(string.format("%.1f, %.1f", x, y), 1, 0.82, 0)) 
            end
            
            if db.showDurability then 
                local cur, tot = 0, 0 for i=1,18 do local d,m=GetInventoryItemDurability(i) if d and m then cur,tot=cur+d,tot+m end end
                local pct = (tot > 0) and floor((cur/tot)*100) or 100
                table.insert(p, Colorize(pct .. "% Dur", GetStatusColor(pct, 25, 70))) 
            end
            
            -- BAGS (Weiß > 10, Gelb 5-10, Rot < 5)
            if db.showBags then 
                local free, total = GetFreeBagSlots()
                local r, g, b = 1, 1, 1 -- Standard Weiß
                if free < 5 then r, g, b = 1, 0, 0 -- Rot
                elseif free <= 10 then r, g, b = 1, 0.8, 0 end -- Gelb
                table.insert(p, Colorize(free .. "/" .. total .. " Bags", r, g, b)) 
            end
            
            if db.showGold then table.insert(p, "S: " .. GetCoinTextureString(abs(GetMoney() - sessionGold))) end
            if db.showClock then table.insert(p, string.format("%02d:%02d", GetGameTime())) end
            
            f.text:SetText(table.concat(p, "  |  "))
            f:SetSize(f.text:GetStringWidth() + 20, 20)
            self.t = 0
        end
    end)
end

SLASH_EIP1 = "/eip"
SlashCmdList["EIP"] = function() if opt:IsShown() then opt:Hide() else opt:Show() end end
local l = CreateFrame("Frame")
l:RegisterEvent("PLAYER_LOGIN")
l:SetScript("OnEvent", Init)