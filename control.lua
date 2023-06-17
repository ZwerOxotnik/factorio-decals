if script.level.level_name == "decals" then return end


---@type table<string, module>
local modules = {}
---@diagnostic disable-next-line: different-requires
modules.decal_system = require("scenarios/decals/decal_system")


local event_handler
if script.active_mods["zk-lib"] then
	-- Same as Factorio "event_handler", but slightly better performance
	local is_ok, zk_event_handler = pcall(require, "__zk-lib__/static-libs/lualibs/event_handler_vZO.lua")
	if is_ok then
		event_handler = zk_event_handler
	end
end
event_handler = event_handler or require("event_handler")


event_handler.add_libraries(modules)


-- This is a part of "gvv", "Lua API global Variable Viewer" mod. https://mods.factorio.com/mod/gvv
-- It makes possible gvv mod to read sandboxed variables in the map or other mod if following code is inserted at the end of empty line of "control.lua" of each.
if script.active_mods["gvv"] then require("__gvv__.gvv")() end
