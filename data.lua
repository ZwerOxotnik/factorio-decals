decals_mod = {}


---@param _data table
---@return table
decals_mod.add_decal = function(_data)
	local prototype = table.deepcopy(_data)
	prototype.mipmap_count = prototype.mipmap_count or nil -- specific weird (old) bug
	-- TODO: improve check of types
	if prototype.type:find("entity") or prototype.type:find("unit") then
		if prototype.selectable_in_game == nil then
			prototype.selectable_in_game = false
		end
		if prototype.create_ghost_on_death == nil then
			prototype.create_ghost_on_death = false
		end
		if prototype.count_as_rock_for_filtered_deconstruction == nil then
			prototype.count_as_rock_for_filtered_deconstruction = true
		end
		prototype.render_layer = prototype.render_layer or "lower-object-above-shadow"
	end

	data:extend({prototype})

	return prototype
end


for k, _data in pairs(require("decal_list")) do
	---@diagnostic disable-next-line: redundant-parameter
	decals_mod.add_decal(_data, k)
end
