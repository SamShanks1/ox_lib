local glm = require 'glm'
local zones = {}

local function getTriangles(polygon)
	local X = {}
	X[1], X[2] = polygon.projectToAxis(polygon, vec(1, 0, 0))

	local points = {}
	local sides = {}
	local triangles = {}

	for i = 1, #polygon do
		sides[i] = {polygon[i], polygon[i + 1] or polygon[1]}
		points[polygon[i]] = {side = i, intersects = {}, v = polygon[i], uses = 0}
	end

	for i = 1, #polygon do
		for j = 1, #X do
			local extremePoint = vec(X[j], polygon[i].yz)
			if polygon[i].x ~= extremePoint.x then
				for l = 1, #polygon do
					local bool, d, d2 = glm.segment.intersectsSegment(polygon[i], extremePoint, polygon[l], polygon[l + 1] or polygon[1])
					if d > 0.001 and d < 0.999 and d2 > 0.001 and d2 < 0.999 then
						local intersect = glm.segment.getPoint(polygon[i], extremePoint, d)
						local valid = polygon.contains(polygon, (polygon[i] + intersect) / 2)
						if valid then
							for m = 1, #polygon do
								local bool, d, d2 = glm.segment.intersectsSegment(polygon[i], intersect, polygon[m], polygon[m + 1] or polygon[1])
								if d > 0.001 and d < 0.999 and d2 > 0.001 and d2 < 0.999 then
									valid = false
									break
								end
							end
						end
						if valid then
							points[intersect] = {side = l, vertex = polygon[i], v = intersect, uses = 0}
							points[polygon[i]].intersects[#points[polygon[i]].intersects + 1] = intersect

							sides[l][#sides[l] + 1] = intersect
						end
					end
				end
			end
		end
	end

	function up(a, b)
		return a.y > b.y
	end

	function down(a, b)
		return a.y < b.y
	end

	function makeTriangles(t)
		if t.c and t.d then
			triangles[#triangles + 1] = {a = t.a, b = t.b, c = t.c}
			triangles[#triangles + 1] = {a = t.b, b = t.c, c = t.d}
			for k, v in pairs(t) do
				points[v].uses += 1
			end
		else
			triangles[#triangles + 1] = {a = t.a, b = t.b or t.c, c = t.d or t.c}
			for k, v in pairs(t) do
				points[v].uses += 2
			end
		end
	end

	for i = 1, #sides do
		local side = sides[i]
		local direction = side[1].y - side[2].y
		if direction > 0 then
			direction = up
		else
			direction = down
		end
		table.sort(side, direction)
		for j = 1, #side - 1 do
			local a, b = side[j], side[j + 1]
			local c = points[a].vertex or points[a].intersects[1]
			local d = points[b].vertex or points[b].intersects[1]
			if points[a].uses < 2 then
				if c and d then
					if points[c].side ~= points[d].side then
						local c2
						if points[a].vertex then
							if points[a].v == points[c].intersects[1] and points[c].intersects?[2] then
								c2 = points[c].intersects[2]
							else
								c2 = points[c].intersects[1]
							end
						else
							c2 = points[a].intersects[2]
						end
						local c2Point = points[c2]
						if c2Point and c2Point.side == points[d].side then
							c = c2
						else
							if points[b].vertex then
								if points[b].v == points[d].intersects[1] and points[d].intersects?[2] then
									d = points[d].intersects[2]
								elseif b ~= points[d].intersects[1] then
									d = points[d].intersects[1]
								end
							elseif points[b].intersects[2] then
								d = points[b].intersects[2]
							end
						end
					end
				elseif c then
					if points[b].side ~= points[c].side then
						local c2
						if points[c].intersects?[2] then
							c2 = points[c].intersects[2]
						elseif points[a].intersects?[2] then
							c2 = points[a].intersects[2]
						end
						local c2Point = points[c2]
						if c2Point then
							if c2Point.side == points[b].side or (c2Point.side - #sides + 1) == points[b].side then
								c = c2
							end
						end
					end
				elseif d then
					if points[a].side ~= points[d].side then
						local d2
						if points[d].intersects?[2] then
							d2 = points[d].intersects[2]
						elseif points[b].intersects?[2] then
							d2 = points[b].intersects[2]
						end
						local d2Point = points[d2]
						if d2Point then
							if d2Point.side == points[a].side or (d2Point.side - #sides + 1) == points[a].side then
								d = d2
							end
						end
					end
				end
				makeTriangles({a = a, b = b, c = c, d = d})
			end
		end
	end
	return triangles
end

local function removeZone(self)
	zones[self.id] = nil
end

local function debug(self)
	local polygon = self.polygon
	local polyCount = #self.polygon

	if polygon.isConvex(polygon) then
		for i = 2, polyCount - 1 do
			DrawPoly(polygon[1], polygon[i], polygon[i + 1], 255, 0, 0, 50)
			DrawPoly(polygon[i], polygon[1], polygon[i + 1], 255, 0, 0, 50)
		end
	else
		self.triangles = self.triangles or getTriangles(polygon)
		for i = 1, #self.triangles do
			DrawPoly(self.triangles[i].a, self.triangles[i].b, self.triangles[i].c, 255, 0, 0, 50)
			DrawPoly(self.triangles[i].b, self.triangles[i].a, self.triangles[i].c, 255, 0, 0, 50)
		end
    end
end

local inside = {}
local insideCount
local tick

CreateThread(function()
	while true do
		Wait(300)
		local coords = GetEntityCoords(cache.ped)
		table.wipe(inside)
		insideCount = 0

		for _, zone in pairs(zones) do
			local contains = zone.polygon:contains(coords, zone.thickness)

			if contains then
				if zone.inside then
					insideCount += 1
					inside[insideCount] = zone
				end

				if zone.onEnter and not zone.insideZone then
					zone.insideZone = true
					zone:onEnter()
				end
			elseif zone.insideZone then
				zone.insideZone = nil
				if zone.onExit then
					zone:onExit()
				end
			elseif zone.debug then
				insideCount += 1
				inside[insideCount] = zone
			end
		end

		if not tick then
			if insideCount > 0 then
				tick = SetInterval(function()
					for i = 1, insideCount do
						local zone = inside[i]

						if zone.insideZone then
							zone:inside()
						end

						if zone.debug then
							zone:debug()
						end
					end
				end)
			end
		elseif insideCount == 0 then
			tick = ClearInterval(tick)
		end
	end
end)

local DrawLine = DrawLine

local function debugBox(self)
	if not self.debugCoords then
		self.debugCoords = {
			self.centroid + vec3(self.size.x, self.size.y, self.thickness) * self.rotation,
			self.centroid + vec3(-self.size.x, self.size.y, self.thickness) * self.rotation,
			self.centroid + vec3(-self.size.x, -self.size.y, self.thickness) * self.rotation,
			self.centroid + vec3(self.size.x, -self.size.y, self.thickness) * self.rotation,
			self.centroid - vec3(self.size.x, self.size.y, self.thickness) * self.rotation,
			self.centroid - vec3(-self.size.x, self.size.y, self.thickness) * self.rotation,
			self.centroid - vec3(-self.size.x, -self.size.y, self.thickness) * self.rotation,
			self.centroid - vec3(self.size.x, -self.size.y, self.thickness) * self.rotation,
		}
	end

	DrawLine(self.debugCoords[1], self.debugCoords[2], 255, 0, 0, 150)
	DrawLine(self.debugCoords[2], self.debugCoords[3], 255, 0, 0, 150)
	DrawLine(self.debugCoords[3], self.debugCoords[4], 255, 0, 0, 150)
	DrawLine(self.debugCoords[4], self.debugCoords[1], 255, 0, 0, 150)

	DrawLine(self.debugCoords[5], self.debugCoords[6], 255, 0, 0, 150)
	DrawLine(self.debugCoords[6], self.debugCoords[7], 255, 0, 0, 150)
	DrawLine(self.debugCoords[7], self.debugCoords[8], 255, 0, 0, 150)
	DrawLine(self.debugCoords[8], self.debugCoords[5], 255, 0, 0, 150)

	DrawLine(self.debugCoords[1], self.debugCoords[7], 255, 0, 0, 150)
	DrawLine(self.debugCoords[2], self.debugCoords[8], 255, 0, 0, 150)
	DrawLine(self.debugCoords[3], self.debugCoords[5], 255, 0, 0, 150)
	DrawLine(self.debugCoords[4], self.debugCoords[6], 255, 0, 0, 150)
end

local glm_polygon_contains = glm.polygon.contains

local function contains(self, coords)
	return glm_polygon_contains(self.polygon, coords)
end

return {
	poly = function(data)
		data.id = #zones + 1
		data.thickness = data.thickness or 2
		data.polygon = glm.polygon.new(data.points)
		data.remove = removeZone
		data.centroid = data.polygon:centroid()
		data.debug = data.debug and debug
		data.contains = contains

		zones[data.id] = data
		return data
	end,

	box = function(data)
		data.id = #zones + 1
		data.thickness = data.size.z or 2
		data.rotation = quat(data.rotation or 0, vec3(0, 0, 1))
		data.polygon = (data.rotation * glm.polygon.new({
			vec3(data.size.x, data.size.y, 0),
			vec3(-data.size.x, data.size.y, 0),
			vec3(-data.size.x, -data.size.y, 0),
			vec3(data.size.x, -data.size.y, 0),
		}) + data.centroid)
		data.remove = removeZone
		data.debug = data.debug and debugBox
		data.contains = contains

		zones[data.id] = data
		return data
	end
}