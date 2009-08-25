
MONEYTRAIL = {Locals = {}}

-- locals
local realmName = GetRealmName()
local playerName = UnitName("player")
local playerClass = select(2, UnitClass("player"))
local data -- will contain the data we work with 
local displays = {} -- all our displays
local HookDisplays -- func defined later
local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBObj
local L = MONEYTRAIL.Locals

-- localization

-- English  (default)
if GetLocale() then
	L.total = "Total"
	L.gained = "|cffffffffGained|r"
	L.spent = "|cffffffffSpent|r"
	L.loss = "|cffffffffLoss|r"
	L.profit = "|cffffffffProfit|r"
	L.thissession = "This session"
end

-- Korean
if GetLocale() == "koKR" then
	L.total = "총"
	L.gained = "|cffffffff수입|r"
	L.spent = "|cffffffff소비|r"
	L.loss = "|cffffffff손실|r"
	L.profit = "|cffffffff이익|r"
	L.thissession = "현재 세션"
end

-- local funcs

local classColors = {
	WTF = "|cffa0a0a0"
}
for k, v in pairs(RAID_CLASS_COLORS) do
	classColors[k] = "|cff" .. string.format("%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255)
end

local coloredNames = setmetatable({}, {__index =
	function(self, key)
		if type(key) == "nil" then return nil end
		local class = MoneyTrailDB[realmName][key] and MoneyTrailDB[realmName][key].class
		if class then
			self[key] = classColors[class]  .. key .. "|r"
			return self[key]
		else
			return classColors.WTF .. key .. "|r"
		end
	end
})

local function MoneyString( money, color )
	if type(money) ~= "number" then money = 0 end
	if not color then color = "|cffffffff" end
	local gold = abs(money / 10000)
	local silver = abs(mod(money / 100, 100))
	local copper = abs(mod(money, 100))
	
	if money >= 10000 then
		return string.format( "%s%d|r|cffffd700g|r %s%d|r|cffc7c7cfs|r %s%d|r|cffeda55fc|r", color, gold, color, silver, color, copper)
	elseif money >= 100 then
		return string.format( "%s%d|r|cffc7c7cfs|r %s%d|r|cffeda55fc|r", color, silver, color, copper)	
	else 
		return string.format("%s%d|r|cffeda55fc|r", color, copper )
	end
end

-- the most important func
local function UpdateData()
	local money = GetMoney()
	if money and money ~= data.money then
		if not data.money then data.money = money end
		-- money changed calculate that shit
		local diff = money - data.money
		if diff > 0 then
			data.gained = data.gained + diff
		else
			data.spent = data.spent + -1*diff
		end
		data.diff = data.gained - data.spent
		data.money = money
		if LDBObj then LDBObj.text = MoneyString(money) end
	end
end

-- our addon frame
local addon = CreateFrame("Frame", "MoneyTrail", UIParent)
-- our addon event handler
local function OnEvent(self, event, ...)
	if self[event] then
		self[event](self, event, ...)
	end
end

function addon:ADDON_LOADED(event, name)
	if name == "MoneyTrail" then
		addon:UnregisterEvent("ADDON_LOADED")
		MoneyTrailDB = MoneyTrailDB or {}
		MoneyTrailDB[realmName] = MoneyTrailDB[realmName] or {}
		MoneyTrailDB[realmName][playerName] = MoneyTrailDB[realmName][playerName] or {}
		MoneyTrailDB[realmName][playerName].class = playerClass
		data = MoneyTrailDB[realmName][playerName]
		data.spent = 0
		data.gained = 0
		data.diff = 0
		if LDBObj then LDBObj.text = MoneyString(data.money) end
	end
end

function addon:PLAYER_LOGOUT()
	-- write saved vars
	data.diff = nil
	data.gained = nil
	data.spent = nil
	MoneyTrailDB[realmName][playerName] = data
end

-- PEW is late enough for all addons OnEnables to have been called
function addon:PLAYER_ENTERING_WORLD()
	addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
	HookDisplays()
end

addon.PLAYER_MONEY = UpdateData
addon.PLAYER_LOGIN = UpdateData

-- register our events
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGOUT")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_MONEY")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:SetScript("OnEvent", OnEvent)

local function UpdateTooltip(tooltip)
	UpdateData()
	
	tooltip:AddLine("Money Trail")
	
	if data.gained > 0 or data.spent > 0 then
		tooltip:AddLine(" ")
		tooltip:AddLine(L.thissession)
		tooltip:AddDoubleLine(L.gained, MoneyString(data.gained, "|cff00ff00"))
		tooltip:AddDoubleLine(L.spent, MoneyString(data.spent, "|cffff0000"))
		if data.diff > 0 then
			tooltip:AddDoubleLine(L.profit,MoneyString(data.diff, "|cff00ff00"))
		else
			tooltip:AddDoubleLine(L.loss,MoneyString(-1*data.diff, "|cffff0000"))
		end	
	end
	
	tooltip:AddLine(" ")
	local total = 0
	for pn, d in pairs(MoneyTrailDB[realmName]) do
		total = total + d.money
		tooltip:AddDoubleLine(coloredNames[pn], MoneyString(d.money))
	end
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L.total, MoneyString(total))
end


local function OnEnter(self)
	-- get our display set up
	GameTooltip:SetOwner(self.MoneyTrailAnchor and self.MoneyTrailAnchor or self, 'ANCHOR_TOPRIGHT')
	UpdateTooltip(GameTooltip)
	GameTooltip:Show()
end

local function OnLeave(self)
	GameTooltip:Hide()
end

function HookDisplays()
	-- simple bagframes support
	-- true means multiple frames anr reanchoring
	-- false means single frame
	local BagFrames = {
		["ContainerFrame1MoneyFrame"] = true, -- Blizzard Backpack
		["MerchantMoneyFrame"] = true, -- Blizzard Merchant Frame
		["OneBagFrameMoneyFrame"] = true, -- OneBag
		["BagginsMoneyFrame"] = false, -- Baggins
		["CombuctorFrame1MoneyFrameClick"] = false, -- Combuctor Bag
		["CombuctorFrame2MoneyFrameClick"] = false, -- Combuctor Bank
		["ARKINV_Frame1StatusGold"] = true, -- ArkInventory Bag
		["ARKINV_Frame3StatusGold"] = true, -- ArkInventory Bank
		["BBCont1_1MoneyFrame"] = true, -- BaudBag bag
		["BBCont2_1MoneyFrame"] = true, -- BaudBag bank
		["FBoH_BagViewFrame_1_GoldFrame"] = true, -- FBoH
		["FBoH_BagViewFrame_2_GoldFrame"] = true, -- FBoH
		["BagnonMoney0"] = true, -- Bagnon
		["BagnonMoney1"] = true, -- Bagnon
	}
	if cargBags then
		for _, object in pairs(cargBags.Objects) do
			if object.Money then
				BagFrames[object.Money:GetName()] = true
			end
		end
	end
	for frame, multiple in pairs(BagFrames) do
		if _G[frame] then
			table.insert(displays, _G[frame])
			if multiple then
				table.insert(displays, _G[frame.."CopperButton"])
				table.insert(displays, _G[frame.."SilverButton"])
				table.insert(displays, _G[frame.."GoldButton"])	
				_G[frame.."CopperButton"].MoneyTrailAnchor = _G[frame]
				_G[frame.."SilverButton"].MoneyTrailAnchor = _G[frame]
				_G[frame.."GoldButton"].MoneyTrailAnchor = _G[frame]
			end
		end
	end

	-- 'Hook' the displays
	for k, frame in pairs(displays) do
		frame:EnableMouse(true)
		if frame:GetScript("OnEnter") then frame:HookScript("OnEnter", OnEnter)
		else frame:SetScript("OnEnter", OnEnter) end
		
		if frame:GetScript("OnLeave") then frame:HookScript("OnLeave", OnLeave)
		else frame:SetScript("OnLeave", OnLeave) end
	end
end

-- LDB Plugin
if LDB then
	LDBObj = LDB:NewDataObject("MoneyTrail", {
		type = "data source",
		label = "MoneyTrail",
		text = "0",
		OnTooltipShow = UpdateTooltip,
	})
end
