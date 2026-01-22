--[[
    Personal ID SWEP

    Controls:
    - RMB (when raised): View your own ID card
    - LMB (when raised): Show ID card to player in front of you

    Must be raised (hold R) to use either function.
]]--

AddCSLuaFile()

SWEP.PrintName = "Personal ID"
SWEP.Author = "Windswept"
SWEP.Purpose = "Display your identification."
SWEP.Instructions = "Raise (R) then: RMB to view, LMB to show to others"

SWEP.Spawnable = false
SWEP.Drop = false

SWEP.ViewModelFOV = 50
SWEP.ViewModel = Model("models/weapons/helios/id_cards/c_idcard.mdl")
SWEP.WorldModel = Model("models/weapons/helios/id_cards/w_idcard.mdl")
SWEP.UseHands = true
SWEP.HoldType = "slam"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

-- ============================================================================
-- NETWORKING
-- ============================================================================

if SERVER then
    util.AddNetworkString("ixPersonalIDShowForward")
    util.AddNetworkString("ixPersonalIDViewSelf")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    return true
end

function SWEP:Holster()
    return true
end

-- ============================================================================
-- WORLD MODEL RENDERING
-- ============================================================================

if CLIENT then
    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()

        -- No owner, just draw normally (e.g., dropped weapon)
        if not IsValid(owner) then
            self:DrawModel()
            return
        end

        -- Find the right hand bone
        local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        if not bone then
            self:DrawModel()
            return
        end

        -- Get the bone's position and angle
        local matrix = owner:GetBoneMatrix(bone)
        if not matrix then
            self:DrawModel()
            return
        end

        local pos = matrix:GetTranslation()
        local ang = matrix:GetAngles()

        -- Offset position to place card in hand (tweak these values as needed)
        pos = pos + ang:Forward() * 3 + ang:Right() * 1 + ang:Up() * -1

        -- Rotate to orient the card correctly
        ang:RotateAroundAxis(ang:Right(), 90)
        ang:RotateAroundAxis(ang:Up(), 180)

        self:SetRenderOrigin(pos)
        self:SetRenderAngles(ang)
        self:SetModelScale(1, 0)
        self:DrawModel()
    end
end

-- ============================================================================
-- INPUT HANDLING (CLIENT)
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- Only handle input on CLIENT (server has no input context)
    if CLIENT then
        local isRaised = owner:IsWepRaised()

        -- Handle View Self (RMB) - only when raised
        if isRaised then
            local rmbDown = input.IsMouseDown(MOUSE_RIGHT)

            if rmbDown and not self.wasRMBDown then
                -- RMB just pressed while raised - view own ID
                if not self.nextViewTime or self.nextViewTime <= CurTime() then
                    self.nextViewTime = CurTime() + 0.5
                    self:ViewSelfID()
                end
            end

            self.wasRMBDown = rmbDown
        else
            self.wasRMBDown = false
        end

        -- Handle Show Forward (LMB) - only when raised
        if isRaised then
            local lmbDown = input.IsMouseDown(MOUSE_LEFT)

            if lmbDown and not self.wasLMBDown then
                -- LMB just pressed while raised - show to player in front
                if not self.nextShowTime or self.nextShowTime <= CurTime() then
                    self.nextShowTime = CurTime() + 0.5
                    net.Start("ixPersonalIDShowForward")
                    net.SendToServer()
                end
            end

            self.wasLMBDown = lmbDown
        else
            self.wasLMBDown = false
        end
    end
end

-- Disable default attacks
function SWEP:PrimaryAttack()
    return false
end

function SWEP:SecondaryAttack()
    return false
end

-- ============================================================================
-- CLIENT: View Self ID
-- ============================================================================

if CLIENT then
    -- Find the equipped personal_id item from inventory
    -- (self.ixItem is only set server-side, not networked to client)
    function SWEP:GetEquippedItem()
        local client = LocalPlayer()
        local character = client:GetCharacter()
        if not character then return nil end

        local inventory = character:GetInventory()
        if not inventory then return nil end

        for _, item in pairs(inventory:GetItems()) do
            if item.uniqueID == "personal_id" and item:GetData("equipped") then
                return item
            end
        end

        return nil
    end

    function SWEP:ViewSelfID()
        -- Find the equipped item from inventory
        local item = self:GetEquippedItem()
        if not item then
            LocalPlayer():ChatPrint("No ID card data available.")
            return
        end

        -- Get the ID card data from the item
        local data = item:GetIDCardData()

        -- Remove any existing self-view ID card
        if IsValid(ix.gui.selfIDCard) then
            ix.gui.selfIDCard:Remove()
        end

        local card = vgui.Create("ixPersonalIDCard")
        card:SetData(data)
        card:SetSelfViewMode()

        ix.gui.selfIDCard = card
    end
end

-- ============================================================================
-- SERVER: Show Forward
-- ============================================================================

if SERVER then
    net.Receive("ixPersonalIDShowForward", function(len, client)
        -- Verify client has the weapon equipped
        local weapon = client:GetActiveWeapon()
        if not IsValid(weapon) or weapon:GetClass() ~= "ix_personalid" then
            return
        end

        -- Must be raised
        if not client:IsWepRaised() then
            client:NotifyLocalized("idCardMustRaise")
            return
        end

        -- Get the linked item
        local item = weapon.ixItem
        if not item then
            return
        end

        local physical = item:GetData("physical", {})

        -- Trace to find player in front
        local traceData = {
            start = client:GetShootPos(),
            endpos = client:GetShootPos() + client:GetAimVector() * 128,
            filter = client
        }
        local target = util.TraceLine(traceData).Entity

        if IsValid(target) and target:IsPlayer() then
            -- Determine sex from model
            local sex = "M"
            if physical.model and ix.physical.IsFemaleModel(physical.model) then
                sex = "F"
            end

            -- Format date of birth
            local dob = "Unknown"
            if physical.birthMonth and physical.birthDay and physical.age then
                dob = ix.birthdata.FormatDate(physical.birthMonth, physical.birthDay, physical.age)
            end

            -- Build data table for network
            local data = {
                ownerName = item:GetData("ownerName", "Unknown"),
                id = item:GetData("id", "00000"),
                model = physical.model,
                skin = physical.skin or 0,
                bodygroups = physical.bodygroups,
                sex = sex,
                dob = dob,
                birthLocation = physical.birthLocation or "Unspecified",
                age = physical.age,
                height = physical.height,
                weight = physical.weight,
                build = physical.build,
                eyeColor = physical.eyeColor,
                hairColor = physical.hairColor,
                hairType = physical.hairType,
                hairLength = physical.hairLength,
                skinTone = physical.skinTone
            }

            -- Send to target player (using existing net message)
            net.Start("ixShowPersonalID")
                net.WriteTable(data)
            net.Send(target)

            -- Notify the player who showed the ID
            client:NotifyLocalized("idCardShown", target:Name())
        else
            client:NotifyLocalized("idCardNotValid")
        end
    end)
end
