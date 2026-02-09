--[[
	Battering Ram SWEP

	Used by Security to breach doors during warrant execution.
	Each door requires 1-6 hits (randomized on first contact) to breach.
	Hit counter resets after 10 minutes of no hits.
	Door restores after 30 minutes.
]]--

AddCSLuaFile()

SWEP.Base = "base_windswept_swep"
SWEP.PrintName = "Battering Ram"
SWEP.Purpose = "Breach doors"

SWEP.Slot = 0
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/c_stunstick.mdl"
SWEP.WorldModel = "models/props_c17/tools/toolbox01.mdl"
SWEP.HoldType = "melee2"

-- Configuration
SWEP.SwingCooldown = 1.5
SWEP.MaxRange = 80

function SWEP:PrimaryAttack()
	if CLIENT then return end

	-- Cooldown check
	if self:GetNextPrimaryFire() > CurTime() then
		return
	end

	self:SetNextPrimaryFire(CurTime() + self.SwingCooldown)

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	-- Swing animation
	owner:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_HITCENTER)

	-- Trace to find door
	local trace = owner:GetEyeTrace()
	local entity = trace.Entity

	-- Range check
	if trace.HitPos:Distance(owner:GetShootPos()) > self.MaxRange then
		-- Miss sound - hitting air
		self:EmitSound("weapons/iceaxe/iceaxe_swing1.wav", 75, 100)
		return
	end

	-- Check if it's a door
	if not IsValid(entity) or not entity:IsDoor() then
		-- Hit something that's not a door
		if trace.Hit then
			self:EmitSound("physics/metal/metal_box_impact_hard1.wav", 80, 100)
		else
			self:EmitSound("weapons/iceaxe/iceaxe_swing1.wav", 75, 100)
		end
		return
	end

	-- Skip brush-based doors (func_door, func_door_rotating)
	-- These have models like "*90", "*57" - BSP brush references that can't be breached
	local model = entity:GetModel() or ""
	if string.sub(model, 1, 1) == "*" then
		self:EmitSound("physics/metal/metal_solid_impact_hard1.wav", 80, 100)
		owner:Notify("This door cannot be breached.")
		return
	end

	-- Only work on our managed Windswept doors
	if not entity.ixIsWindsweptDoor then
		self:EmitSound("physics/metal/metal_solid_impact_hard1.wav", 80, 100)
		owner:Notify("This door cannot be breached.")
		return
	end

	-- Check if door is already blasted
	if entity.ixDummy and IsValid(entity.ixDummy) then
		owner:Notify("This door is already breached.")
		return
	end

	-- Initialize door breach data if not already set
	-- Hit counter persists until door is REPAIRED or DESTROYED - no time-based reset
	if not entity.ixBatteringRamRequired then
		-- Roll required hits (1-6) - this is set once and persists
		entity.ixBatteringRamRequired = math.random(1, 6)
		entity.ixBatteringRamHits = 0
	end

	-- Increment hit counter
	entity.ixBatteringRamHits = (entity.ixBatteringRamHits or 0) + 1

	-- Check if door should be breached
	if entity.ixBatteringRamHits >= entity.ixBatteringRamRequired then
		-- BREACH! Get door material for appropriate sounds
		local config = ix.doors.GetTypeConfig(entity)
		local isWood = config.material == "wood"

		-- Destruction sounds based on material
		if isWood then
			self:EmitSound("physics/wood/wood_crate_break" .. math.random(1, 5) .. ".wav", 100, 80)
			self:EmitSound("physics/wood/wood_plank_break1.wav", 90, 90)
		else
			self:EmitSound("physics/metal/metal_box_break1.wav", 100, 80)
			self:EmitSound("doors/door_metal_medium_open1.wav", 90, 70)
		end

		-- Calculate blast direction (away from player)
		local direction = (entity:GetPos() - owner:GetPos()):GetNormalized()
		direction.z = 0.3 -- Slight upward angle for dramatic effect

		-- Use our custom breach function - PERMANENTLY DESTROYS the door
		ix.doors.BreachDoor(entity, direction * 450)

		-- Reset door tracking
		entity.ixBatteringRamRequired = nil
		entity.ixBatteringRamHits = nil
		entity.ixBatteringRamLastHit = nil

		-- Log the breach
		local character = owner:GetCharacter()
		if character then
			ix.log.Add(owner, "battering_ram_breach", entity:GetClass(), entity:EntIndex())
		end
	else
		-- Hit sound
		self:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 85, math.random(95, 105))
	end
end

function SWEP:SecondaryAttack()
	-- No secondary attack
end

function SWEP:Reload()
	-- No reload
end

function SWEP:Holster()
	return true
end

if CLIENT then
	function SWEP:DrawWorldModel()
		ix.constants.DrawWorldModelBone(self, {5, 3, -2}, {{"Forward", 90}, {"Up", 180}})
	end
end
