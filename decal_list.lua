local data_stage_data = {
	O_O = {
		filename = "__decals__/scenarios/decals/decals/parrot__O_O.png",
		width = 100, height = 90,
	},
	think = {
		filename =  "__decals__/scenarios/decals/decals/parrot_think.png",
		width = 100, height = 99,
	},
	harold = {
		filename = "__decals__/scenarios/decals/decals/harold.png",
		width = 150, height = 136,
	},
	goose = {
		filename = "__decals__/scenarios/decals/decals/goose.png",
		width = 150, height = 93,
	},
	___ = {
		filename = "__decals__/scenarios/decals/decals/___.png",
		width = 110, height = 140,
	},
}

for name, _data in pairs(data_stage_data) do
	_data.type = _data.type or "sprite"
	_data.name = _data.name or (name .. "_decal")
end


if decals_mod then
	return data_stage_data
else
	local control_stage_data = {}
	for name, _data in pairs(data_stage_data) do
		if _data.type == "sprite" then
			control_stage_data[name] = _data.name
		else
			control_stage_data[name] = _data.type .. "/" .. _data.name
		end
	end
	return control_stage_data
end
