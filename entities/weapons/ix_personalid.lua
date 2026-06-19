--[[
    Personal ID SWEP

    Controls:
    - RMB (when raised): View your own ID card
    - LMB (when raised): Show ID card to player in front of you

    Must be raised (hold R) to use either function.
]]--

AddCSLuaFile()

SWEP.Base = "base_windswept_swep"
SWEP.PrintName = "Personal ID"
SWEP.Purpose = "Display your identification."
SWEP.Instructions = "Raise (R) then: RMB to view, LMB to show to others"

SWEP.ViewModelFOV = 50
SWEP.ViewModel = Model("models/weapons/helios/id_cards/c_idcard.mdl")
SWEP.WorldModel = Model("models/weapons/helios/id_cards/w_idcard.mdl")
SWEP.HoldType = "slam"
SWEP.DrawCrosshair = false

-- ============================================================================
-- NETWORKING
-- ============================================================================

-- Network strings registered in schema/sv_netstrings.lua

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function SWEP:Holster()
    return true
end

-- ============================================================================
-- WORLD MODEL RENDERING
-- ============================================================================

if CLIENT then
    function SWEP:DrawWorldModel()
        ws.constants.DrawWorldModelBone(self, {3, 1, -1}, {{"Right", 90}, {"Up", 180}}, true)
    end
end

-- ============================================================================
-- INPUT HANDLING (CLIENT)
-- ============================================================================

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if CLIENT then
        -- Must be raised to use - reset edge detection when lowered
        if not owner:IsWepRaised() then
            self.wasLMBDown = false
            self.wasRMBDown = false
            return
        end

        local lmb, rmb = ws.constants.ProcessSWEPInput(self)

        if lmb and CurTime() >= (self.nextShowTime or 0) then
            self.nextShowTime = CurTime() + 0.5
            net.Start("wsPersonalIDShowForward")
            net.SendToServer()
        end

        if rmb and CurTime() >= (self.nextViewTime or 0) then
            self.nextViewTime = CurTime() + 0.5
            self:ViewSelfID()
        end
    end
end

-- ============================================================================
-- CLIENT: View Self ID
-- ============================================================================

if CLIENT then
    -- Find the equipped personal_id item from inventory
    -- (self.wsItem is only set server-side, not networked to client)
    function SWEP:GetEquippedItem()
        local client = LocalPlayer()
        local character, inventory = ws.constants.GetCharacterInventory(client)
        if not character or not inventory then return nil end

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
        if IsValid(ws.gui.selfIDCard) then
            ws.gui.selfIDCard:Remove()
        end

        local card = vgui.Create("wsPersonalIDCard")
        card:SetData(data)
        card:SetSelfViewMode()

        ws.gui.selfIDCard = card
    end
end

-- ============================================================================
-- SERVER: Show Forward
-- ============================================================================

if SERVER then
    net.Receive("wsPersonalIDShowForward", function(len, client)
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
        local item = weapon.wsItem
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
            if physical.model and ws.physical.IsFemaleModel(physical.model) then
                sex = "F"
            end

            -- Format date of birth
            local dob = "Unknown"
            if physical.birthMonth and physical.birthDay and physical.age then
                dob = ws.birthdata.FormatDate(physical.birthMonth, physical.birthDay, physical.age)
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
            net.Start("wsShowPersonalID")
                net.WriteTable(data)
            net.Send(target)

            -- Notify the player who showed the ID
            client:NotifyLocalized("idCardShown", target:Name())
        else
            client:NotifyLocalized("idCardNotValid")
        end
    end)
end
