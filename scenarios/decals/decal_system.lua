--[[
    Copyright (c) 2023 ZwerOxotnik<zweroxotnik@gmail.com>
    Licensed under the MIT licence.

    Original source: https://mods.factorio.com/mod/decals
]]


local M = {}


--#region Global data
---@type table<string, integer[]>
local mod_data
local players_decals
--#endregion


--#region Constants
local destroy_render = rendering.destroy
local draw_sprite = rendering.draw_sprite
local get_render_target = rendering.get_target

---@type table<string, string>
local DECALS_PATH = {}
for mod_name in pairs(script.active_mods) do
	local is_ok, decal_list = pcall(require, string.format("__%s__/decal_list", mod_name))
	if is_ok then
		for name, path in pairs(decal_list) do
			DECALS_PATH[name] = path
		end
	end
end
local is_ok, decal_list = pcall(require, "__level__/decal_list")
if is_ok then
	for name, path in pairs(decal_list) do
		DECALS_PATH[name] = path
	end
end
--#endregion


--#region Utils


---@param s string
local function trim(s)
	return s:match'^%s*(.*%S)' or ''
end


---@param local_data table
---@param global_data_name string
---@param receiver table?
---@return boolean
function check_local_and_global_data(local_data, global_data_name, receiver)
	if (type(global_data_name) == "string" and local_data ~= global.decals[global_data_name]) then
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
	for player_index, decals in pairs(players_decals) do
		local player = game.get_player(player_index)
		local player_decals = players_decals[player_index]
		local is_player_valid = (player and player.valid)
		for i=#decals, 1, -1 do
			local decal_id = decals[i]
			if not is_player_valid then
				destroy_render(decal_id)
			elseif not rendering.is_valid(decal_id) then
				destroy_render(decal_id)
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
				rendering.destroy(decals[i])
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
M.remove_player_decals = function(player_index)
	local decals = players_decals[player_index]
	if not decals then return end
	for i=1, #decals do
		rendering.destroy(decals[i])
	end
	players_decals[player_index] = nil
end

local sprite_data = {
	sprite = "",
    render_layer = "floor",
    target = {x=0, y=0},
    surface = nil
}
---@param player LuaPlayer
---@param decal_path string
local function draw_decal(player, decal_path)
	local player_index = player.index
	local player_decals = players_decals[player_index]
	if player_decals == nil then
		local new_table = {}
		players_decals[player_index] = new_table
		player_decals = new_table
	elseif #player_decals >= 50 then
		local id = table.remove(player_decals, 1)
		destroy_render(id)
	end

	sprite_data.sprite = decal_path
	sprite_data.surface = player.surface
	sprite_data.target = player.position
	player_decals[#player_decals+1] = draw_sprite(sprite_data)
end

---@return number
local function get_distance(start, stop)
	local xdiff = start.x - stop.x
	local ydiff = start.y - stop.y
	return (xdiff * xdiff + ydiff * ydiff)^0.5
end

--#endregion


--#region Events


M.delete_player_data = function(event)
	M.remove_player_decals(event.player_index)
end

M.on_player_joined_game = function(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	if #game.connected_players == 1 then
		M.remove_invalid_data()
		M.detect_desync()
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

	if not game.is_valid_sprite_path(decal_path) then
		log(string.format("%s is invalid sprite path", decal_path))
		return
	end

	draw_decal(player, decal_path)
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
		log("No support for server")
		return
	end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	M.remove_player_decals(player_index)
end

local function remove_near_decal_command(cmd)
	local player_index = cmd.player_index
	if player_index == 0 then
		log("No support for server")
		return
	end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	local player_position = player.position
	for _player_index, decals in pairs(players_decals) do
		local _player = game.get_player(_player_index)
		local player_decals = players_decals[_player_index]
		if not (_player and _player.valid) then
			goto continue
		end

		for i=#decals, 1, -1 do
			local decal_id = decals[i]
			if not rendering.is_valid(decal_id) then
				table.remove(decals, i)
			else
				local render_target = get_render_target(decals[i])

				local distance = get_distance(player_position, render_target.position)
				if distance <= 15 then
					destroy_render(decal_id)
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

--#endregion


--#region Pre-game stage


M.link_data = function()
	mod_data = global.decals
	players_decals = mod_data.players_decals
end

M.update_global_data = function()
	global.decals = global.decals or {}
	mod_data = global.decals
    ---@type table<integer, integer>
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
				destroy_render(decal_id)
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
	[defines.events.on_player_removed] = M.delete_player_data,
}
commands.add_command("decal", {"decals-commands.decal"}, decal_command)
commands.add_command("remove-all-decals", {"decals-commands.remove-all-decals"}, remove_all_decals_command)
commands.add_command("remove-my-decals", {"decals-commands.remove-my-decals"}, remove_my_decal_command)
commands.add_command("remove-near-decals", {"decals-commands.remove-near-decals"}, remove_near_decal_command)


--#endregion


return M
