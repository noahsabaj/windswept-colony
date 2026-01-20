--[[
    CONFEDERATION FACTION

    Confederation of Earthly Governments (CEG)

    This faction represents the Confederation of Earthly Governments (CEG),
    the interplanetary body that licenses and oversees colonial operations.

    This faction will likely only ever be played during events.
    Some of the event characters are, but not limited to:
        - CEG Inspectors
        - CEG Senators
        - CEG Ambassadors
        - CEG Peacekeepers
        - CEG Secretary-General (the leader of the CEG, kwabaj's character)

    Most players will never see these people, as they'll likely never appear.
    They are the ultimate government of humanity so far.
]]--

FACTION.name = "Confederation"
FACTION.description = "Representatives of the Confederation of Earthly Governments, the interplanetary body that licenses and oversees colonial operations."
FACTION.color = Color(200, 200, 200) -- Light gray
FACTION.isDefault = false

-- Confederation models (more formal appearance)
FACTION.models = {
    "models/player/breen.mdl",
    "models/player/magnusson.mdl",
    "models/player/kleiner.mdl"
}

-- Pay for confederation
FACTION.pay = 200

function FACTION:OnCharacterCreated(client, character)
    -- Starting equipment for confederation
    -- character:GetInventory():Add("ceg_id", 1)
    -- character:GetInventory():Add("datapad", 1)
end

FACTION_CONFEDERATION = FACTION.index