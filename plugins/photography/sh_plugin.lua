local PLUGIN = PLUGIN

PLUGIN.name = "Photography"
PLUGIN.author = "Windswept"
PLUGIN.description = "A comprehensive photography system featuring working cameras, film, photos, and albums."

ix.photo = ix.photo or {}

ix.util.Include("libs/sh_photo.lua")
ix.util.Include("sv_plugin.lua")
