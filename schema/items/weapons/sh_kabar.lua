--[[
    KA-BAR Combat Knife Item
    Melee weapon - uses tfa_ins2_kabar from TFA INS2 Melee pack
]]--

ITEM.base = "base_weapons"
ITEM.name = "KA-BAR"
ITEM.description = "A military combat knife. Standard issue for close-quarters situations."
ITEM.model = Model("models/weapons/tfa_ins2/w_marinebayonet.mdl")
ITEM.class = "tfa_ins2_kabar"
ITEM.weaponCategory = "melee"
ITEM.width = 1
ITEM.height = 2
ITEM.category = "Melee"

ITEM.iconCam = {
    ang = Angle(0, 270, 45),
    fov = 12,
    pos = Vector(0, 200, 0)
}
