--[[

Minetest Sedimentology Mod

Copyright (c) 2015 Auke Kok, All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library

]]--

-- bugs? questions? Please find this project and me at
--   github.com/sofar
--

local function round(x) return x - x%1 + 0.5 end

local mprops = dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/nodes.lua")

local interval = 1.0
local count = 20
local radius = 100

local stat_considered = 0
local stat_displaced = 0
local stat_degraded = 0

local sealevel = 0
if not minetest.get_mapgen_params == nil then
	sealevel = minetest.get_mapgen_params().water_level
end

local function roll(chance)
	return (math.random() >= chance)
end

local function pos_above(pos)
	return {x = pos.x, y = pos.y + 1, z = pos.z}
end

local function pos_below(pos)
	return {x = pos.x, y = pos.y - 1, z = pos.z}
end

local function pos_is_node(pos)
	return minetest.get_node_or_nil(pos)
end

local function pos_is_ignore(pos)
	return minetest.get_node(pos).name == "ignore"
end

local function node_is_air(node)
	return node.name == "air"
end

local function node_is_plant(node)
	if not node or node.name == "ignore" then
		return false
	end

	local reg = minetest.registered_nodes[node.name]
	if not reg then
		return false
	end
	local drawtype = reg["drawtype"]
	if drawtype == "plantlike" or reg.groups.flora == 1 then
		return true
	end

  local allowed = {
     ["default:leaves"] = true,
     ["default:jungleleaves"] = true,
     ["default:pine_needles"] = true,
     ["default:cactus"] = true,
  }
  return allowed[node.name]
end

local function node_is_water_source(node)
   return node and (node.name == "default:water_source") or false
end

local function node_is_water(node)
   local is_water = { ["default:water_source"]=true, ["default:water_flowing"]=true }
   return node and is_water[node.name] or false
end

local function node_is_lava(node)
   local is_lava = { ["default:lava_source"]=true, ["default:lava_flowing"]=true }
   return node and is_lava[node.name] or false
end

local function node_is_liquid(node)
	if not node or node.name == "ignore" then
		return false
	end

	local reg = minetest.registered_nodes[node.name]
	if not reg then
		return false
	end
	local drawtype = reg["drawtype"]
	return drawtype and ({liquid=true, flowingliquid=true})[drawtype] or false
end

local function scan_for_water(pos, waterfactor)
	local w = waterfactor
	for xx = pos.x - 2,pos.x + 2,1 do
		for yy = pos.y - 2,pos.y + 2,1 do
			for zz = pos.z - 2,pos.z + 2,1 do
				local nn = minetest.get_node({xx, yy, zz})
				if nn.name == "default:water_flowing" then
					return 0.25
				elseif nn.name == "default:water_source" then
					w = 0.125
					break
				end
			end
		end
	end
	return w
end

local function scan_for_vegetation(pos)
	local v = 1.0
	for xx = pos.x - 3,pos.x + 3,1 do
		for yy = pos.y - 3,pos.y + 3,1 do
			for zz = pos.z - 3,pos.z + 3,1 do
				local nn = minetest.get_node({xx, yy, zz})
				if node_is_plant(nn) then
					-- factor distance to plant
					local d = (math.abs(xx - pos.x) + math.abs(yy - pos.y) + math.abs(zz - pos.z)) / 3.0
					-- scale it
					local vv = 0.5 / (4.0 - d)
					-- only take the lowest value
					if (vv < v) then
						v = vv
					end
				end
			end
		end
	end
	return v
end

local function node_is_valid_target_for_displacement(pos)
	local node = minetest.get_node(pos)

  return node_is_liquid(node) or node_is_air(node) or node_is_plant(node) and node or nil
end

-- Drop until cannot fall further.
local function full_drop(pos)
   while node_is_valid_target_for_displacement(pos) do
      pos.y = pos.y - 1
   end
   pos.y = pos.y + 1
   return pos
end

-- (NOTE disadvantage is lots of looking at map.)
-- Walks down to maximum cnt. `h` is fall height.
local function _deposit_walk(x,y,z, props, cnt,h, max_cnt)
   if cnt > max_cnt then return { x=x, y=y, z=z } end

   local function valid(dx,dy,dz)
      return node_is_valid_target_for_displacement{x=x+dx, y=y+dy, z=z+dz} 
   end
   local slope = props.slope or 1

   local step = {{0,0,1},{1,0,0}, {0,0,-1},{-1,0,0}}
   local k,s = math.random(4), 2*math.random(2)-3 -- randomly pick start, direction.
   for _ = 1,4 do
      local cx,cy,cz = unpack(step[1 + k%4])
      if valid(cx,cy,cz) then
         local unfinished = true
         while unfinished do -- Requirement to go down.
            -- Represent minimum slope, or breakage.
            if math.ceil(slope*cnt) < h or (props.break_p and roll(props.break_p)) then
               local tpos = _deposit_walk(x + cx,y + cy,z + cz, props,
                                          cnt + 1, h, max_cnt)
               if tpos then
                  -- If sticky, do the probability, otherwise, drop.
                  return props.sticky and roll(props.sticky) and tpos or
                     full_drop(tpos)
               end
               unfinished = false
            elseif valid(cx,cy-1,cz) then  -- Drop one.
               cy = cy - 1
               h = h + 1
            else
               unfinished = false
            end
         end
      end
      k = k + s
   end
end

local function deposit_walk(pos, props)
   return _deposit_walk(pos.x, pos.y, pos.z, props, 0,0,
                        math.random(props.min_cnt or 2, props.max_cnt or 3))
end

local function sed()
	-- pick a random block in (radius) around (random online player)
	local playerlist = minetest.get_connected_players()
	local playercount = table.getn(playerlist)
	if playercount ~= 0 then
     local randomplayer = playerlist[math.random(playercount)]
     local playerpos = randomplayer:getpos()

     local dx = radius*(2*math.random() - 1)
     local radius_z = math.sqrt(radius^2 - dx^2)
     return sed_on_pos{
        x = math.floor(playerpos.x - dx),
        y = 0,
        z = math.floor(playerpos.z + radius_z*(2*math.random() - 1))
     }
  end
end

local function find_height(pos)
	-- force load map
	local vm = minetest.get_voxel_manip()
	local minp, maxp = vm:read_from_map(
		{x = pos.x - 3, y = pos.y - 100, z = pos.z - 3},
		{x = pos.x + 3, y = pos.y + 100, z = pos.z + 3}
	)

	-- now go find the topmost world block
	repeat
		pos = pos_above(pos)
	until pos_is_ignore(pos)

	-- then find lowest air block
	repeat
		pos = pos_below(pos)
		if not minetest.get_node_or_nil(pos) then
			return
		end
	until not node_is_air(minetest.get_node(pos))

	-- then search under water/lava and any see-through plant stuff
	local underliquid = 0
	while (node_is_liquid(minetest.get_node(pos))) do
		underliquid = underliquid + 1
		pos = pos_below(pos)
		if not minetest.get_node_or_nil(pos) then
			return
		end
	end

	-- protected?
	if minetest.is_protected(pos, "mod:sedimentology") then
		return
	end

  return pos, underliquid
end

local allow_debug = true
local debug_mode

-- TODO `find_height` probes the map, and often subsequently nothing happens.
-- Expensive...

function sed_on_pos(pos)
	stat_considered = stat_considered + 1

  local pos, underliquid = find_height(pos)
  if not pos then return end

	local node = minetest.get_node(pos)

  local props = mprops[node.name] -- Get properties.

	-- do we handle this material?
	if not props then
		return
	end

	-- determine nearby water scaling
	local waterfactor = 0.01
	if underliquid > 0 then
		waterfactor = 0.5
	else
		waterfactor = scan_for_water(pos, waterfactor)
	end

  -- Throw some probabilities together.
  local p_here = waterfactor *
     (underliquid and pos.y <= sealevel and 2.0 * math.pow(0.5, 0.0 - pos.y) or 1)

	if roll(p_here) then
		return
	end

	-- factor in vegetation that slows erosion down (separate because the above prevents.)
	if roll(scan_for_vegetation(pos)) then
		return
	end

	-- displacement - before we erode this material, we check to see if
	-- it's not easier to move the material first. If that fails, we'll
	-- end up degrading the material as calculated

	if debug_mode == "displace" or not roll(props.r) then

		-- walker algorithm here
     local tpos = deposit_walk(pos, props)

		if tpos then
			if minetest.is_protected(tpos, "mod:sedimentology") then
				return
			end
      -- time to displace the node from pos to tpos
      node.name = props.drop_as or node.name -- Change the name if relevant.
      minetest.set_node(tpos, node)
      minetest.sound_play({name = "default_place_node"}, { pos = tpos })
      minetest.get_meta(tpos):from_table(minetest.get_meta(pos):to_table())
      minetest.remove_node(pos)

      stat_displaced = stat_displaced + 1

      -- fix water edges at or below sea level.
      if pos.y > sealevel then
         return
      end

      local function is_water_source(dx,dz)
         return node_is_water_source(minetest.get_node{
                                        x = pos.x + dx, y = pos.y, z = pos.z + dz})
      end
      local function is_air(dx,dz)
         return node_is_air(minetest.get_node{
                               x = pos.x + dx, y = pos.y, z = pos.z + dz})
      end
      if (is_water_source(-1,0) or is_water_source(1,0) or
          is_water_source(0,-1) or is_water_source(0,1)) and
      (is_air(-1,0) or is_air(1,0) or is_air(0,-1) or is_air(0,1)) then
         -- instead of air, leave a water node
         minetest.set_node(pos, { name = "default:water_source"})
      end
      -- done - don't degrade this block further
      return
    end
  end

  -- degrade
  -- compensate speed for grass/dirt cycle

	-- sand only becomes clay under sealevel
	if ((node.name == "default:sand" or node.name == "default:desert_sand") and (underliquid > 0) and pos.y >= 0.0) then
		return
	end

	-- prevent sand-to-clay unless under water
	-- FIXME should account for Biome here too (should be ocean, river, or beach-like)
	if (underliquid < 1) and (node.name == "default:sand" or node.name == "default:desert_sand") then
		return
	end

	-- prevent sand in dirt-dominated areas above water
	if node.name == "default:dirt" and underliquid < 1 then
		-- since we don't have biome information, we'll assume that if there is no sand or
		-- desert sand anywhere nearby, we shouldn't degrade this block further
		local fpos = minetest.find_node_near({x = pos.x, y = pos.y + 1, z = pos.z}, 1,
       {"default:sand", "default:desert_sand"})
		if not fpos then
			return
		end
	end

	if debug_mode ~= "degrade" and roll(props.h) then
		return
	end

	-- finally, determine new material type
	local newmat = "air"

	if table.getn(props.t) > 1 then
		-- multiple possibilities, scan area around for best suitable type
		for i = table.getn(props.t), 2, -1 do
			local fpos = minetest.find_node_near(pos, 5, props.t[i])
			if fpos then
				newmat = props.t[i]
				break
			end
		end
		if newmat == "air" then
			newmat = props.t[1]
		end
	else
		newmat = props.t[1]
	end

	minetest.set_node(pos, {name = newmat})

	stat_degraded = stat_degraded + 1
end

local function sedimentology()
	-- select a random point that is loaded in the game
	for c=1,count,1 do
		sed()
	end
	-- requeue a timer to call again
	minetest.after(interval, sedimentology)
end


local function sed_cmd(name, param)
   local function got_privs()
      return minetest.check_player_privs(name, {server=true})
   end

  local cmd, arg1 = unpack(string.split(param, " "))  -- Do more as needed, of course.

	if cmd == "stats" then
		local output = "Sedimentology mod statistics:" ..
			"\nradius: " .. radius .. ", blocks: " .. count ..
			"\nconsidered: " .. stat_considered ..
			"\ndisplaced: " .. stat_displaced ..
			"\ndegraded: " .. stat_degraded
		return true, output
	elseif cmd == "rate" then
     if not got_privs() then
        return false, "You do not have privileges to execute that command"
     end
     if tonumber(arg1) then
        count = tonumber(arg1)
        return true, "Set blocks changing rate to " .. count
     else
        return true, "Blocks changing rate: " .. count
     end
  elseif cmd == "radius" then
     if not got_privs(name) then
        return false, "You do not have privileges to execute that command"
     end
     if tonumber(arg1) then
        radius = tonumber(arg1)
        return true, "Set radius to " .. radius
     else
        return true, "Radius: " .. radius
     end
  elseif cmd == "hit" then
     if not got_privs() then
        return false, "You do not have privileges to execute that command"
     end
     local pos = minetest.get_player_by_name(name):getpos()
     minetest.sound_play({name = "default_place_node"}, { pos = pos })
     local n = math.max(tonumber(arg1) or 1, 100)
     for _ = 1,n do sed_on_pos(pos) end
  elseif cmd == "debug" then
     if allow_debug then
        debug_mode = arg1
        return true, "set debug_mode: " .. (debug_mode or "nil")
     else
        return false, "Debug is disabled"
     end
	else
     return false, [[/sed [blocks|radius|stats|help|hit]\n" ..
rate      - get or set block count per interval (requires 'server' privs)\n
radius    - change the radius (same privs)
stats     - display operational statistics
hit       - hit an element with sedimentation.(server privs)
            Only has a probability of success]] .. (allow_debug and [[

debug     - Debug modes. `sed debug degrade` for always-degrade and
            `.. displace` for the other one]])
	end
	return true, "Command completed succesfully"
end

minetest.register_chatcommand("sed", {
	params = "stats|...",
	description = "Various action commands for the sedimentology mod",
	func = sed_cmd
})

minetest.after(interval, sedimentology)
print("Initialized Sedimentology")
