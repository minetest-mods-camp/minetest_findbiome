local S = minetest.get_translator("findbiome")
local mg_name = minetest.get_mapgen_setting("mg_name")
if mg_name == "v6" then
	minetest.log("info", "[findbiome] This mod doesn't work in mapgen v6!")
end

-- Parameters
-------------

-- Resolution of search grid in nodes.
local res = 64
-- Number of points checked in the square search grid (edge * edge).
local checks = 128 * 128

-- End of parameters
--------------------

-- Direction table

local dirs = {
	{x = 0, y = 0, z = 1},
	{x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = -1},
	{x = 1, y = 0, z = 0},
}

function find_biome(pos, biomes)
	pos = vector.round(pos)
	-- Pos: Starting point for biome checks. This also sets the y co-ordinate for all
	-- points checked, so the suitable biomes must be active at this y.

	-- Table of suitable biomes
	local biome_ids = {}
	for i=1, #biomes do
		local id = minetest.get_biome_id(biomes[i])
		if not id then
			return nil, false
		end
		table.insert(biome_ids, id)
	end

	-- Initial variables

	local edge_len = 1
	local edge_dist = 0
	local dir_step = 0
	local dir_ind = 1
	local success = false
	local spawn_pos = {}

	-- Get next position on square search spiral
	local function next_pos()
		if edge_dist == edge_len then
			edge_dist = 0
			dir_ind = dir_ind + 1
			if dir_ind == 5 then
				dir_ind = 1
			end
			dir_step = dir_step + 1
			edge_len = math.floor(dir_step / 2) + 1
		end

		local dir = dirs[dir_ind]
		local move = vector.multiply(dir, res)

		edge_dist = edge_dist + 1

		return vector.add(pos, move)
	end

	-- Position search

	local function search()
		for iter = 1, checks do
			local biome_data = minetest.get_biome_data(pos)
			-- Sometimes biome_data is nil
			local biome = biome_data and biome_data.biome
			for id_ind = 1, #biome_ids do
				local biome_id = biome_ids[id_ind]
				if biome == biome_id then
					local spawn_y = minetest.get_spawn_level(pos.x, pos.z)
					if spawn_y then
						spawn_pos = {x = pos.x, y = spawn_y, z = pos.z}
						-- FIXME: Don't return true when spawn_pos is out of map bounds
						return true
					end
				end
			end

			pos = next_pos()
		end

		return false
	end

	success = search()
	return spawn_pos, success

end

minetest.register_on_mods_loaded(function()
	minetest.register_chatcommand("findbiome", {
		description = S("Find and teleport to biome"),
		params = S("<biome>"),
		privs = { debug = true, teleport = true },
		func = function(name, param)
			local player = minetest.get_player_by_name(name)
			if not player then
				return false, S("No player.")
			end
			local pos = player:get_pos()
			local id = minetest.get_biome_id(param)
			if not id then
				if mg_name == "v6" then
					return false, S("No biome found! Sorry, finding biomes of the v6 mapgen is not supported!")
				else
					return false, S("Biome does not exist!")
				end
			end
			local biome_pos, success = find_biome(pos, {param})
			if success then
				player:set_pos(biome_pos)
				return true, S("Biome found at @1.", minetest.pos_to_string(biome_pos))
			else
				if mg_name == "v6" then
					return false, S("No biome found! Sorry, finding biomes of the v6 mapgen is not supported!")
				else
					return false, S("No biome found!")
				end
			end
		end,
	})

	minetest.register_chatcommand("listbiomes", {
		description = S("List all biomes"),
		params = "",
		privs = { debug = true },
		func = function(name, param)
			local biomes = {}
			local b = 0
			for k,v in pairs(minetest.registered_biomes) do
				table.insert(biomes, k)
				b = b + 1
			end
			if b == 0 then
				if mg_name == "v6" then
					return false, S("This command can't find biomes of the v6 mapgen!")
				else
					return true, S("No biomes.")
				end
			else
				table.sort(biomes)
				for b=1, #biomes do
					minetest.chat_send_player(name, biomes[b])
				end
				return true
			end
		end,
	})
end)
