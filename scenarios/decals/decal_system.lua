--[[
    Copyright (c) 2023 ZwerOxotnik<zweroxotnik@gmail.com>
    Licensed under the MIT licence.

    Original source: https://mods.factorio.com/mod/decals
]]


local M = {}


--#region Global data
---@type table<string, any>
local mod_data
local players_decal
--#endregion


--#region Constants
local destroy_render = rendering.destroy
local draw_sprite = rendering.draw_sprite
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

local function remove_invalid_data()
	for player_index, decal_id in pairs(players_decal) do
        if not rendering.is_valid(decal_id) then
            players_decal[player_index] = nil
        else
            local player = game.get_player(player_index)
            if not (player and player.valid) then
                destroy_render(decal_id)
                players_decal[player_index] = nil
            end
        end
    end
end


--#endregion


--#region Events


local function delete_player_data(event)
	local player_index = event.player_index

	local decal_id = players_decal[player_index]
    if decal_id then
        destroy_render(decal_id)
        players_decal[player_index] = nil
    end
end


local sprite_data = {
	sprite = "",
    render_layer = "floor",
    target = {x=0, y=0},
    surface = nil
}
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

	local prev_decal_id = players_decal[player_index]
    if prev_decal_id then
        destroy_render(prev_decal_id)
    end

	if not game.is_valid_sprite_path(decal_path) then
		log(string.format("%s is invalid sprite path", decal_path))
		return
	end

	sprite_data.sprite = decal_path
	sprite_data.surface = player.surface
	sprite_data.target = player.position
	players_decal[player_index] = draw_sprite(sprite_data)
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

	-- remove decals
	if script.mod_name == "level" then
		for _, id in pairs(players_decal) do
			rendering.destroy(id)
		end
	else
		rendering.clear(script.mod_name)
	end
	mod_data.players_decal = {}
	players_decal = mod_data.players_decal
end

local function remove_my_decal_command(cmd)
	local player_index = cmd.player_index
	if player_index == 0 then
		log("No support for server")
		return
	end
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	-- remove decals of the player
	local id = players_decal[player_index]
	if id then
		rendering.destroy(id)
		players_decal[player_index] = nil
	end
end

--#endregion


--#region Pre-game stage


local function link_data()
	mod_data = global.decals
	players_decal = mod_data.players_decal
end

local function update_global_data()
	global.decals = global.decals or {}
	mod_data = global.decals
    ---@type table<integer, integer>
	mod_data.players_decal = mod_data.players_decal or {}

	link_data()
	remove_invalid_data()
end


M.on_init = update_global_data
M.on_load = link_data
M.on_configuration_changed = update_global_data

M.events = {
	[defines.events.on_player_removed] = delete_player_data,
}
commands.add_command("decal", {"decals-commands.decal"}, decal_command)
commands.add_command("remove-all-decals", {"decals-commands.remove-all-decals"}, remove_all_decals_command)
commands.add_command("remove-my-decals", {"decals-commands.remove-my-decals"}, remove_my_decal_command)


--#endregion


return M
