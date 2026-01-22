--[[
    MINERS UNION

    CMU-RC, Carbon Miners Union-Redrock City
    
    The collective voice of the workers, led by the elected Union President.
    The Union negotiates wages, advocates for safety, organizes strikes,
    and protects workers from exploitation by the Conglomerate.
    
    The Confederation of Earthly Governments officially protects the right
    to unionize - but out here on Zephyrus, rights are only as strong as
    those willing to fight for them.

    According to an agreement made between the EEC and the Miners Union,
    the EEC will only buy coal from members of the miners union. 
    The EEC officially only grants access to the mines for union members.
    This gives the union significant leverage over the Conglomerate, as they control
    the labor force that extracts the colony's primary resource.
    This also opens an opportunity for coal smugglers to secretly mine and sell coal at a
    discounted rate, as they are non-union, and technically shouldn't be mining at all.
    
    The Union President must choose their battles:
    Fight the colonial administration? Fight the Conglomerate?
    Or try to work within the system while it grinds workers to dust?
    
    STRUCTURE:
    - Union President (Elected by Workers)
        - Vice President (Appointed)
        - Secretary (Appointed)
        - Treasurer (Appointed)
        - Shop Stewards (Appointed)
]]--

FACTION.name = "Miners Union"
FACTION.description = "United we bargain, divided we beg. The voice of the workers."
FACTION.color = Color(200, 200, 200) -- Light gray
FACTION.isDefault = false

-- Pay for miners union (if using salary system)
FACTION.pay = 115

FACTION.models = {
    "models/player/group01/male_01.mdl",
    "models/player/group01/male_02.mdl",
    "models/player/group01/male_03.mdl",
    "models/player/group01/male_04.mdl",
    "models/player/group01/female_01.mdl",
    "models/player/group01/female_02.mdl",
    "models/player/group01/female_03.mdl"
}

FACTION_UNION = FACTION.index
