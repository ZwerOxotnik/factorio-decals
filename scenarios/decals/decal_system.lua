--[[
    Copyright (c) 2023 ZwerOxotnik<zweroxotnik@gmail.com>
    Licensed under the MIT licence.

    Original source: https://mods.factorio.com/mod/decals
]]


local M = {}


--#region Global data
---@type table<string, table>
local mod_data
---@type table<uint, uint64>
local players_decals
--#endregion


--#region Constants
local get_rendered_by_id = rendering.get_object_by_id


---@type table<string, string>
local DECALS_PATH = {}
for mod_name in pairs(script.active_mods) do
	local is_ok, decal_list = pcall(require, string.format("__%s__/decal_list", mod_name))
	if is_ok and type(decal_list) == "table" then
		for name, path in pairs(decal_list) do
			if type(name) == "string" and type(path) == "string" then
				DECALS_PATH[name] = path
			end
		end
	end
end
local is_ok, decal_list = pcall(require, "__level__/decal_list")
if is_ok and type(decal_list) == "table" then
	for name, path in pairs(decal_list) do
		if type(name) == "string" and type(path) == "string" then
			DECALS_PATH[name] = path
		end
	end
end
--#endregion


--#region Utils


---@param s string
local function trim(s)
	return s:match'^%s*(.*%S)' or ''
end


---@return number
local function get_distance(start, stop)
	local xdiff = start.x - stop.x
	local ydiff = start.y - stop.y
	return (xdiff * xdiff + ydiff * ydiff)^0.5
end


---@param local_data table
---@param global_data_name string
---@param receiver table?
---@return boolean
function check_local_and_global_data(local_data, global_data_name, receiver)
	if (type(global_data_name) == "string" and local_data ~= storage.decals[global_data_name]) then
		local message = string.format("!WARNING! Desync has been detected in __%s__ %s. Please report and send log files to %s and try to load your game again or use /sync", script.mod_name, "mod_data[\"" .. global_data_name .. "\"]", "ZwerOxotnik")
		log(message)
		if game and (game.is_multiplayer() == false or receiver) then
			if script.active_mods["EasyAPI"] then
				message = {"EasyAPI.report-desync",
					script.mod_name, "mod_data[\"" .. global_data_name .. "\"]", "ZwerOxotnik"
				}
			end
			receiver = receiver or game
			receiver.print(message)
		end
		return true
	end
	return false
end

---@param receiver table?
M.detect_desync = function(receiver)
	check_local_and_global_data(players_decals, "players_decals", receiver)
end

M.remove_invalid_data = function()
	for _, player in pairs(game.players) do
		if player.valid and not player.connected then
			M.delete_decals_list_gui(player)
		end
	end

	for player_index, decals in pairs(players_decals) do
		local player = game.get_player(player_index)
		local player_decals = players_decals[player_index]
		local is_player_valid = (player and player.valid)
		for i=#decals, 1, -1 do
			local rendered = get_rendered_by_id(decals[i])
			if not is_player_valid then
				rendered.destroy()
			elseif not rendered.valid then
				rendered.destroy()
				table.remove(player_decals, i)
			end
        end
		if not is_player_valid or next(player_decals) == nil then
			players_decals[player_index] = nil
		end
    end
end

M.remove_decals = function()
	if script.mod_name == "level" then
		for player_index, decals in pairs(players_decals) do
			for i=1, #decals do
				local rendered = get_rendered_by_id(decals[i])
				rendered.destroy()
			end
			players_decals[player_index] = {}
		end
	else
		rendering.clear(script.mod_name)
	end
	mod_data.players_decal = {}
	players_decals = mod_data.players_decal
end


---@param player_index integer
function M.remove_all_player_decals(player_index)
	local decals = players_decals[player_index]
	if not decals then return end
	for i=1, #decals do
		local rendered = get_rendered_by_id(decals[i])
		rendered.destroy()
	end
	players_decals[player_index] = nil
end


---@param player LuaPlayer
---@param radius number?
M.remove_player_decals = function(player, radius)
	if radius == nil then
		M.remove_all_player_decals(player.index)
		return
	end

	local player_index = player.index
	local decals = players_decals[player_index]
	if not decals then return end
	local player_surface  = player.surface
	local player_position = player.position
	for i=#decals, 1, -1 do
		local rendered = get_rendered_by_id(decals[i])
		if not rendered.valid then
			table.remove(decals, i)
		elseif player_surface == rendered.surface then
			local render_target = rendered.target
			local distance = get_distance(player_position, render_target.position)
			if distance <= radius then
				rendered.destroy()
				table.remove(decals, i)
			end
		end
	end

	if next(decals) == nil then
		players_decals[player_index] = nil
	end
end


local sprite_data = {
	sprite = "",
    render_layer = "floor",
    target = {x=0, y=0},
    surface = nil
}
---@param player LuaPlayer
---@param decal_path string?
M.draw_decal = function(player, decal_path)
	if not decal_path then return end
	if not helpers.is_valid_sprite_path(decal_path) then
		log(string.format("%s is invalid sprite path", decal_path))
		return
	end

	local player_index = player.index
	local player_decals = players_decals[player_index]
	if player_decals == nil then
		local new_table = {}
		players_decals[player_index] = new_table
		player_decals = new_table
	elseif #player_decals >= 50 then
		local id = table.remove(player_decals, 1)
		local rendered = get_rendered_by_id(id)
		rendered.destroy()
	end

	sprite_data.sprite = decal_path
	sprite_data.surface = player.surface
	sprite_data.target = player.position
	player_decals[#player_decals+1] = rendering.draw_sprite(sprite_data).id
end


---@param player LuaPlayer
M.delete_decals_list_gui = function(player)
	local frame = player.gui.screen.decals_list_frame
	if frame then
		frame.destroy()
	end
end


---@param player LuaPlayer
M.switch_decals_gui = function(player)
	local screen = player.gui.screen
	local main_frame = screen.decals_list_frame
	if main_frame then
		main_frame.destroy()
		return
	end

	main_frame = screen.add{type = "frame", name = "decals_list_frame", direction = "vertical"} --style = "tips_and_tricks_notification_frame"
	main_frame.location = {x = 300, y = 70}
	main_frame.style.maximal_height = 500

	local top_flow = main_frame.add{type = "flow"}
	top_flow.style.horizontal_spacing = 0
	top_flow.add{
		type = "label",
		style = "frame_title",
		caption = {"decals.Decals"},
		ignored_by_interaction = true
	}
	local drag_handler = top_flow.add{type = "empty-widget", name = "drag_handler", style = "draggable_space"}
	drag_handler.drag_target = main_frame
	drag_handler.style.horizontally_stretchable = true
	drag_handler.style.vertically_stretchable   = true
	drag_handler.style.margin = 0
	top_flow.add{
		hovered_sprite = "utility/close_black",
		clicked_sprite = "utility/close_black",
		sprite = "utility/close",
		style = "frame_action_button",
		type = "sprite-button",
		name = "DECALS_MOD_close"
	}

	local scroll_pane = main_frame.add({
		type = "scroll-pane",
		name = "scroll-pane",
		horizontal_scroll_policy = "never"
	})
	local decals_list_table = scroll_pane.add{type = "table", name = "decals_list_table", column_count = 5}
	decals_list_table.style.horizontal_spacing = 0
	decals_list_table.style.vertical_spacing   = 0

	local flow = {type = "flow", name = ""}
	local button = {type = "sprite-button", name = "spawn_decal", tooltip = "", sprite = ""}
	for decal_name, decal_path in pairs(DECALS_PATH) do
		if not helpers.is_valid_sprite_path(decal_path) then
			goto continue
		end
		flow.name = decal_name
		local _flow = decals_list_table.add(flow)
		_flow.style.natural_width  = 0
		_flow.style.natural_height = 0
		_flow.style.horizontally_stretchable = true
		_flow.style.vertically_stretchable = true
		button.tooltip = decal_name
		button.sprite = decal_path
		local button_style = _flow.add(button).style
		button_style.height = 70
		button_style.width  = 70
		:: continue ::
	end
end

--#endregion


--#region Events


---@param event EventData.on_player_removed
M.on_player_removed = function(event)
	M.remove_all_player_decals(event.player_index)
end


---@param event EventData.on_player_joined_game
M.on_player_joined_game = function(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	if #game.connected_players == 1 then
		M.remove_invalid_data()
		M.detect_desync()
	end
end


---@param event EventData.on_player_left_game
M.on_player_left_game = function(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	M.delete_decals_list_gui(player)
end


local GUIS = {
	DECALS_MOD_close = function(element)
		element.parent.parent.destroy()
	end,
	spawn_decal = function(element, player)
		local decal_name = element.parent.name
		M.draw_decal(player, DECALS_PATH[decal_name])
	end,
}
---@param event EventData.on_gui_click
M.on_gui_click = function(event)
	local element = event.element
	if not (element and element.valid) then return end
	local f = GUIS[element.name]
	if f then
		f(element, game.get_player(event.player_index))
	end
end

local function decal_command(cmd)
    local player_index = cmd.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

    local parameter = cmd.parameter
    if parameter then
        parameter = trim(parameter)
    end

    if parameter == nil or #parameter == 0 then
        local names = {}
        for name in pairs(DECALS_PATH) do
            names[#names+1] = name
        end
        player.print({'', {"decals.Decals"}, {"colon"}, " ", table.concat(names, ", ")})
        return
    end

    local decal_path = DECALS_PATH[parameter]
    if decal_path == nil then
        player.print({"decals.wrong-name", parameter})
        return
    end

	M.draw_decal(player, decal_path)
end

local function remove_all_decals_command(cmd)
	local player_index = cmd.player_index
	local player
	if player_index ~= 0 then
		player = game.get_player(player_index)
		if not (player and player.valid) then return end
		if player.admin == false then
			player.print({"command-output.parameters-require-admin"})
			return
		end
	end

	M.remove_decals()
end

local function remove_my_decal_command(cmd)
	local player_index = cmd.player_index
	if player_index == 0 then
		print("This command does nothing via rcon")
		return
	end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	local parameter = cmd.parameter
	local radius
    if parameter then
        parameter = trim(parameter)
		radius = tonumber(parameter)
    end
	if radius and radius <= 0 then
		return
	end

	M.remove_player_decals(player, radius)
end

local function remove_near_decal_command(cmd)
	local player_index = cmd.player_index
	if player_index == 0 then
		print("This command does nothing via rcon")
		return
	end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	local parameter = cmd.parameter
	local radius
    if parameter then
        parameter = trim(parameter)
		radius = tonumber(parameter)
    end
	if radius == nil then
		radius = 15
	elseif radius <= 0 then
		return
	end

	local player_surface = player.surface
	local player_position = player.position
	for _player_index, decals in pairs(players_decals) do
		local _player = game.get_player(_player_index)
		local player_decals = players_decals[_player_index]
		if not (_player and _player.valid) then
			goto continue
		end

		for i=#decals, 1, -1 do
			local rendered = get_rendered_by_id(decals[i])
			if not rendered.valid then
				table.remove(decals, i)
			elseif player_surface == rendered.surface then
				local render_target = rendered.target
				local distance = get_distance(player_position, render_target.position)
				if distance <= radius then
					rendered.destroy()
					table.remove(decals, i)
				end
			end
		end
		if next(player_decals) == nil then
			players_decals[_player_index] = nil
		end
		:: continue ::
    end
end

local function decals_gui_command(cmd)
	local player_index = cmd.player_index
	if player_index == 0 then
		print("This command does nothing via rcon")
		return
	end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	M.switch_decals_gui(player)
end

--#endregion


--#region Pre-game stage


M.link_data = function()
	mod_data = storage.decals
	players_decals = mod_data.players_decals
end

M.update_global_data = function()
	storage.decals = storage.decals or {}
	mod_data = storage.decals
    ---@type table<uint, uint64>
	mod_data.players_decals = mod_data.players_decals or {}

	M.link_data()
	M.remove_invalid_data()
end

M._on_configuration_changed = function(event)
	M.update_global_data()

	local mod_changes = event.mod_changes["decals"]
	if not (mod_changes and mod_changes.old_version) then return end

	local version = tonumber(string.gmatch(mod_changes.old_version, "%d+.%d+")())

	if version < 2.1 then
		if mod_data.players_decal then
			for _, decal_id in pairs(mod_data.players_decal) do
				local rendered = get_rendered_by_id(decal_id)
				rendered.destroy()
			end
			mod_data.players_decal = nil
		end
	end
end

M.set_filters = function()
	if not script.active_mods["EasyAPI"] then
		return
	end

	local EasyAPI_events = remote.call("EasyAPI", "get_events")
	if EasyAPI_events.on_fix_bugs then
		script.on_event(EasyAPI_events.on_fix_bugs, function()
			M.remove_invalid_data()

			M.detect_desync(game)
		end)
	end
	if EasyAPI_events.on_sync then
		script.on_event(EasyAPI_events.on_sync, function()
			M.link_data()
		end)
	end
end

M.on_init = function()
	M.update_global_data()
	M.set_filters()
end
M.on_load = function()
	M.link_data()
	M.set_filters()
end
M.on_configuration_changed = M._on_configuration_changed

M.events = {
	[defines.events.on_player_joined_game] = M.on_player_joined_game,
	[defines.events.on_player_left_game]   = M.on_player_left_game,
	[defines.events.on_player_removed] = M.on_player_removed,
	[defines.events.on_gui_click] = M.on_gui_click,
}
commands.add_command("decal", {"decals-commands.decal"}, decal_command)
commands.add_command("remove-all-decals", {"decals-commands.remove-all-decals"}, remove_all_decals_command)
commands.add_command("remove-my-decals", {"decals-commands.remove-my-decals"}, remove_my_decal_command)
commands.add_command("remove-near-decals", {"decals-commands.remove-near-decals"}, remove_near_decal_command)
commands.add_command("decals-gui", {"decals-commands.decals-gui"}, decals_gui_command)


--#endregion


return M
