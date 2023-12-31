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


for mod_name in pairs(mods) do
	local is_ok, decal_list = pcall(require, string.format("__%s__/decal_list", mod_name))
	if is_ok and type(decal_list) == "table" then
		for k, _data in pairs(decal_list) do
			if type(_data) == "table"
				and type(_data.type) == "string"
				and type(_data.name) == "string"
			then
				if _data.filename:sub(1,1) ~= "_" and _data.filename:sub(2,2) ~= "_" then
					_data.filename = string.format("__%s__/%s", mod_name, _data.filename)
				end
				---@diagnostic disable-next-line: redundant-parameter
				decals_mod.add_decal(_data, k)
			end
		end
	end
end
