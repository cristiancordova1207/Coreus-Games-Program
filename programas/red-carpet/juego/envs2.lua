local root = SS:WaitForChild("EscenariosRC")
local rnd = Random.new(11)
local function Env(id, name, light)
	local old = root:FindFirstChild(id)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = id
	m:SetAttribute("Titulo", name)
	for k, v in pairs(light) do m:SetAttribute(k, v) end
	return m
end
local function done(m) m.Parent = root print(m.Name, #m:GetDescendants()) task.wait() end
local function Floor(m, color, mat, extra)
	return P(m, "SueloVisual", V3(520, 1, 520), CF(0, -0.52, -30), color, mat or M.SmoothPlastic, extra)
end
-- edificio con ventanas; luz = ventanas encendidas
local function Tower(m, pos, w, h, d, wall, lit, mat)
	P(m, "Torre", V3(w, h, d), CF(pos + V3(0, h / 2, 0)), wall, mat or M.Concrete)
	P(m, "Azotea", V3(w + 1, 1, d + 1), CF(pos + V3(0, h + 0.5, 0)), wall:Lerp(Color3.new(), 0.25), M.Metal)
	local cols, rows = math.floor(w / 4), math.floor(h / 5)
	for r = 1, rows do
		for c = 0, cols - 1 do
			if rnd:NextNumber() < 0.62 then
				P(m, "Ventana", V3(2.4, 2.8, 0.2), CF(pos + V3(-w / 2 + (c + 0.5) * w / cols, r * 5, d / 2 + 0.05)), lit, M.Neon)
			end
		end
	end
	task.wait()
end

-- ========== 6. Las Vegas (la foto de la sesión) ==========
do
	local m = Env("vegas", "Las Vegas", { Sky = "Wylo", ClockTime = 15, Brightness = 2.8, Ambient = rgb(186, 176, 170), OutdoorAmbient = rgb(190, 184, 176),
		Shadows = true, Exposure = 0.05, Atmos = 0.15, AtmosColor = rgb(214, 232, 255), Carpet = rgb(205, 16, 30) })
	Floor(m, rgb(226, 214, 190), M.Pavement)
	Stage(m, { curtain = rgb(170, 12, 26), wing = rgb(245, 238, 225) })
	PanelLine(m, GOLD, rgb(130, 14, 26), GOLD)
	FloodLine(m)
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -92, -64, -36, -8, 20, 46 }) do Palm(m, V3(s * (29 + (z % 5)), 0, z), 22 + (z % 7)) end
	end
	-- hoteles
	Tower(m, V3(-92, 0, -150), 56, 88, 34, rgb(214, 196, 164), rgb(120, 190, 240), M.Concrete)
	Tower(m, V3(-44, 0, -176), 44, 64, 30, rgb(240, 230, 214), rgb(120, 190, 240), M.Concrete)
	Tower(m, V3(84, 0, -168), 50, 72, 34, rgb(140, 190, 230), rgb(240, 250, 255), M.Glass)
	Tower(m, V3(140, 0, -120), 40, 104, 30, rgb(190, 170, 140), rgb(255, 220, 150), M.Concrete)
	Tower(m, V3(-150, 0, -90), 46, 76, 30, rgb(120, 150, 190), rgb(255, 240, 200), M.Glass)
	Tower(m, V3(150, 0, -30), 40, 60, 30, rgb(226, 210, 180), rgb(120, 190, 240), M.Concrete)
	-- torre Eiffel dorada
	local e = Group(m, "TorreEiffel")
	local base, gold = V3(58, 0, -128), rgb(248, 200, 40)
	local levels = { { 0, 18 }, { 22, 9.5 }, { 46, 5 }, { 78, 2.4 }, { 112, 0.7 } }
	for i = 1, #levels - 1 do
		local a, b = levels[i], levels[i + 1]
		for _, dx in ipairs({ -1, 1 }) do
			for _, dz in ipairs({ -1, 1 }) do
				Bar(e, "Pilar", base + V3(dx * a[2], a[1], dz * a[2]), base + V3(dx * b[2], b[1], dz * b[2]), 1.5 - i * 0.15, gold, M.Metal)
			end
		end
		local n = 5
		for k = 0, n - 1 do
			local t, t2 = k / n, (k + 1) / n
			local y, y2, r, r2 = a[1] + (b[1] - a[1]) * t, a[1] + (b[1] - a[1]) * t2, a[2] + (b[2] - a[2]) * t, a[2] + (b[2] - a[2]) * t2
			for j = 0, 3 do
				local c, s2 = ({ 1, -1, -1, 1 })[j + 1], ({ 1, 1, -1, -1 })[j + 1]
				local c2, s3 = ({ -1, -1, 1, 1 })[j + 1], ({ 1, -1, -1, 1 })[j + 1]
				Bar(e, "Celosia", base + V3(c * r, y, s2 * r), base + V3(c2 * r2, y2, s3 * r2), 0.32, gold, M.Metal)
			end
		end
		P(e, "Piso", V3(b[2] * 2 + 3, 1, b[2] * 2 + 3), CF(base + V3(0, b[1], 0)), gold:Lerp(rgb(160, 120, 20), 0.3), M.Metal)
		task.wait()
	end
	Bar(e, "Antena", base + V3(0, 112, 0), base + V3(0, 128, 0), 0.8, gold, M.Metal)
	-- valla publicitaria
	local bb = P(m, "Valla", V3(34, 16, 1), CF(-46, 30, -94) * Ang(0, math.rad(22), 0), rgb(20, 90, 200), M.SmoothPlastic)
	Label(bb, Enum.NormalId.Back, "RED CARPET", WHITE, nil, 20)
	Label(bb, Enum.NormalId.Front, "RED CARPET", WHITE, nil, 20)
	P(m, "ValoPata", V3(1.5, 22, 1.5), CF(-46, 11, -94), rgb(60, 60, 66), M.Metal)
	done(m)
end

-- ========== 7. Jardín ==========
do
	local m = Env("jardin", "Jardín", { Sky = "Wylo", ClockTime = 10.5, Brightness = 2.6, Ambient = rgb(180, 186, 170), OutdoorAmbient = rgb(190, 196, 180),
		Shadows = true, Exposure = 0, Atmos = 0.1, AtmosColor = rgb(225, 240, 225), Carpet = rgb(190, 20, 60), Marks = rgb(255, 225, 235) })
	Floor(m, rgb(96, 170, 74), M.Grass)
	for _, s in ipairs({ -1, 1 }) do P(m, "Sendero", V3(14, 0.1, 190), CF(s * 17.6, 0.0, -28), rgb(232, 222, 198), M.Pavement) end
	Stage(m, { curtain = rgb(232, 120, 165), wing = rgb(64, 130, 58), wingMat = M.Grass, wingLed = rgb(255, 210, 230), statue = rgb(250, 235, 200) })
	HedgeLine(m, WHITE, rgb(60, 150, 50), rgb(255, 225, 170))
	-- árboles en flor y flores
	local function tree(pos, pink)
		Bar(m, "Tronco", pos, pos + V3(0, 10, 0), 1.7, rgb(110, 76, 50), M.Wood)
		for i = 1, 8 do
			local d = rnd:NextNumber(5, 8.5)
			Ball(m, "Copa", d, pos + V3(rnd:NextNumber(-4, 4), 11.5 + rnd:NextNumber(-1, 4), rnd:NextNumber(-4, 4)),
				(pink and rgb(255, 170, 205) or rgb(70, 158, 60)):Lerp(pink and rgb(255, 215, 232) or rgb(44, 120, 44), rnd:NextNumber()), M.Grass)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		for i = 0, 8 do tree(V3(s * (31 + (i % 3) * 3), 0, -96 + i * 19), i % 2 == 0) task.wait() end
		for i = 0, 70 do
			local p = V3(s * rnd:NextNumber(24, 62), 0.45, rnd:NextNumber(-100, 54))
			Bar(m, "Tallo", p - V3(0, 0.45, 0), p, 0.1, rgb(50, 130, 50), M.Grass)
			Ball(m, "Flor", 0.75, p + V3(0, 0.2, 0), Color3.fromHSV(rnd:NextNumber(0.85, 1.13) % 1, 0.65, 1), M.SmoothPlastic)
		end
		-- pérgolas de flores sobre la alfombra (arcos)
	end
	for i = 0, 3 do
		local z = -76 + i * 30
		local segs, last = 18, nil
		for k = 0, segs do
			local a = PI * k / segs
			local p = V3(math.cos(a) * 11, 8 + math.sin(a) * 10, z)
			if last then Bar(m, "Pergola", last, p, 0.5, WHITE, M.Metal) end
			Ball(m, "Flor", 1.5, p + V3(0, rnd:NextNumber(-0.3, 0.3), rnd:NextNumber(-0.5, 0.5)), k % 2 == 0 and rgb(255, 150, 195) or rgb(255, 235, 240), M.SmoothPlastic)
			last = p
		end
		for _, s in ipairs({ -1, 1 }) do P(m, "PataPergola", V3(0.5, 8, 0.5), CF(s * 11, 4, z), WHITE, M.Metal) end
		task.wait()
	end
	-- fuentes
	for _, s in ipairs({ -1, 1 }) do
		local c = V3(s * 46, 0, -30)
		Cyl(m, "Taza", 1.5, 15, c + V3(0, 0.75, 0), rgb(235, 232, 225), M.Marble)
		Cyl(m, "Agua", 0.2, 13.4, c + V3(0, 1.5, 0), rgb(120, 200, 245), M.Glass, { Transparency = 0.2, Reflectance = 0.2 })
		Cyl(m, "Fuste", 5, 1.6, c + V3(0, 3.8, 0), rgb(235, 232, 225), M.Marble)
		local top = Cyl(m, "Copa", 0.6, 5, c + V3(0, 6.4, 0), rgb(235, 232, 225), M.Marble)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate, pe.Lifetime, pe.Speed, pe.SpreadAngle = 40, NumberRange.new(0.8, 1.2), NumberRange.new(9, 12), Vector2.new(14, 14)
		pe.Acceleration, pe.EmissionDirection = V3(0, -22, 0), Enum.NormalId.Right
		pe.Color, pe.Size = ColorSequence.new(rgb(205, 235, 255)), NumberSequence.new(0.4)
		pe.Parent = top
	end
	done(m)
end

-- ========== 8. Ciudad de noche ==========
do
	local m = Env("ciudad", "Ciudad neón", { Sky = "Noche", ClockTime = 0, Brightness = 0.8, Ambient = rgb(120, 110, 165), OutdoorAmbient = rgb(112, 106, 170),
		Shadows = false, Exposure = 0.15, Atmos = 0, Carpet = rgb(170, 12, 60), Marks = rgb(255, 120, 220) })
	Floor(m, rgb(22, 22, 32), M.Slate, { Reflectance = 0.15 })
	Stage(m, { curtain = rgb(120, 20, 110), wing = rgb(26, 22, 44), wingLed = rgb(255, 80, 200), archCols = { rgb(255, 90, 210), rgb(90, 200, 255), rgb(255, 90, 210) }, statue = rgb(255, 220, 240), statueLight = rgb(255, 150, 230) })
	GlassLine(m, rgb(255, 70, 210), rgb(24, 24, 34))
	FloodLine(m, rgb(255, 170, 235))
	local neon = { rgb(255, 80, 200), rgb(80, 210, 255), rgb(255, 210, 90), rgb(160, 110, 255), rgb(90, 255, 180) }
	for _, s in ipairs({ -1, 1 }) do
		for i = 0, 8 do
			local h = rnd:NextInteger(50, 130)
			local w = rnd:NextInteger(22, 34)
			local z = -120 + i * 24
			local x = s * (w / 2 + 34 + rnd:NextNumber(0, 6))
			local col = neon[i % #neon + 1]
			P(m, "Torre", V3(w, h, 22), CF(x, h / 2, z), rgb(24, 24, 38), M.Concrete)
			local inward = s < 0 and w / 2 + 0.1 or -(w / 2 + 0.1)
			for r = 1, math.floor(h / 6) do
				for c = 0, 3 do
					if rnd:NextNumber() < 0.55 then
						P(m, "Ventana", V3(0.2, 2.8, 2.8), CF(x + inward, r * 6, z - 7.5 + c * 5), rnd:NextNumber() < 0.65 and rgb(255, 225, 150) or col, M.Neon)
					end
				end
			end
			P(m, "TiraNeon", V3(0.3, h, 0.5), CF(x + inward, h / 2, z - 10.7), col, M.Neon)
			P(m, "TiraNeon", V3(0.3, h, 0.5), CF(x + inward, h / 2, z + 10.7), col, M.Neon)
			if i % 2 == 0 then
				local sign = P(m, "Cartel", V3(0.6, 9, 18), CF(x + inward * 1.02, 22 + i, z), rgb(12, 10, 20), M.SmoothPlastic)
				Label(sign, s < 0 and Enum.NormalId.Right or Enum.NormalId.Left, ({ "RED CARPET", "STAR", "VIP", "PREMIERE", "FAME" })[i / 2 + 1], col, nil, 18)
			end
			task.wait()
		end
		-- guirnaldas de luces
		for i = 0, 6 do
			local a = V3(s * 30, 16, -94 + i * 22)
			local b = V3(-s * 30, 16, -94 + (i + 0.5) * 22)
			if s < 0 then
				for k = 0, 16 do
					local t = k / 16
					local p = a:Lerp(b, t) - V3(0, 6 * 4 * t * (1 - t), 0)
					Ball(m, "Bombilla", 0.55, p, k % 2 == 0 and rgb(255, 225, 160) or neon[i % #neon + 1], M.Neon)
				end
				for _, q in ipairs({ a, b }) do P(m, "Farola", V3(0.6, 16, 0.6), CF(q.X, 8, q.Z), rgb(30, 30, 40), M.Metal) end
			end
		end
	end
	done(m)
end
local names = {}
for _, c in ipairs(root:GetChildren()) do names[#names + 1] = c.Name .. "=" .. #c:GetDescendants() end
return table.concat(names, " ")
