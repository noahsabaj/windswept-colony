--[[
	Battering Ram

	A heavy breaching tool used by Security to execute warrants and force entry.
	Can be illegally procured for unauthorized use.
]]--

ITEM.name = "Battering Ram"
ITEM.description = "A heavy steel breaching tool used to force entry through locked doors. Standard issue for Security personnel executing warrants."
ITEM.model = "models/props_c17/tools/toolbox01.mdl"
ITEM.class = "ix_batteringram"
ITEM.width = 2
ITEM.height = 1
ITEM.category = "Equipment"

-- ============================================================================
-- CLIENT VISUALS
-- ============================================================================

if CLIENT then
	function ITEM:PaintOver(item, w, h)
		if item:GetData("equipped") then
			surface.SetDrawColor(110, 255, 110, 200)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end
end

-- ============================================================================
-- ITEM FUNCTIONS
-- ============================================================================

ITEM.functions.Equip = {
	name = "Equip",
	tip = "Hold the battering ram in your hands.",
	icon = "icon16/shield.png",
	OnRun = function(item)
		local client = item.player

		if not IsValid(client) then
			return false
		end

		-- Unequip any existing battering ram from this player
		if client.ixBatteringRamItem and client.ixBatteringRamItem ~= item then
			local oldItem = client.ixBatteringRamItem
			oldItem:SetData("equipped", nil)
		end

		-- Strip existing battering ram SWEP if any
		if client:HasWeapon("ix_batteringram") then
			client:StripWeapon("ix_batteringram")
		end

		-- Give the SWEP
		local weapon = client:Give("ix_batteringram")
		if IsValid(weapon) then
			weapon.ixItem = item
			client:SelectWeapon("ix_batteringram")
		end

		client.ixBatteringRamItem = item
		item:SetData("equipped", true)

		return false
	end,
	OnCanRun = function(item)
		-- Can't equip if on ground
		if IsValid(item.entity) then return false end
		-- Can't equip if already equipped
		if item:GetData("equipped") then return false end

		return true
	end
}

ITEM.functions.Unequip = {
	name = "Unequip",
	tip = "Put the battering ram away.",
	icon = "icon16/shield_delete.png",
	OnRun = function(item)
		local client = item.player

		if not IsValid(client) then
			return false
		end

		-- Remove SWEP
		if client:HasWeapon("ix_batteringram") then
			client:StripWeapon("ix_batteringram")
		end

		client.ixBatteringRamItem = nil
		item:SetData("equipped", nil)

		return false
	end,
	OnCanRun = function(item)
		return item:GetData("equipped") == true
	end
}

-- ============================================================================
-- HOOKS
-- ============================================================================

-- Unequip when dropped
function ITEM.postHooks.drop(item, result)
	if item:GetData("equipped") then
		local client = item:GetOwner()
		if IsValid(client) then
			if client:HasWeapon("ix_batteringram") then
				client:StripWeapon("ix_batteringram")
			end
			client.ixBatteringRamItem = nil
		end
		item:SetData("equipped", nil)
	end
end

-- Handle transfer
function ITEM:OnTransferred(oldInventory, newInventory)
	if self:GetData("equipped") then
		local oldOwner = oldInventory and oldInventory.GetOwner and oldInventory:GetOwner()
		if IsValid(oldOwner) then
			if oldOwner:HasWeapon("ix_batteringram") then
				oldOwner:StripWeapon("ix_batteringram")
			end
			oldOwner.ixBatteringRamItem = nil
		end
		self:SetData("equipped", nil)
	end
end

-- Can't transfer while equipped
function ITEM:CanTransfer(oldInventory, newInventory)
	if newInventory and self:GetData("equipped") then
		return false
	end
	return true
end

-- Restore equipped state on character load
function ITEM:OnLoadout()
	if self:GetData("equipped") then
		local client = self.player
		if not IsValid(client) then return end

		local weapon = client:Give("ix_batteringram", true)
		if IsValid(weapon) then
			weapon.ixItem = self
			client.ixBatteringRamItem = self
		end
	end
end
