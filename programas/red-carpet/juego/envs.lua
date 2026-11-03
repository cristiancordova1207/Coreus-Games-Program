-- Escenarios (ServerStorage.EscenariosRC.<id>). El juego clona uno como map.Entorno y aplica sus atributos de luz.
local root = Folder(SS, "EscenariosRC")
local rnd = Random.new(7)
local function Env(id, name, light)
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
-- pancartas entre dos mástiles a ambos lados, de cara a la cámara
local function BannerPairs(m, zs, xc, h, cloth, ink, sym, metal)
	for _, z in ipairs(zs) do
		for _, s in ipairs({ -1, 1 }) do
			local x = s * xc
			GoldPost(m, V3(x - 4, 0, z), h, metal)
			GoldPost(m, V3(x + 4, 0, z), h, metal)
			Banner(m, V3(x, h - 0.6, z), h * 0.5, cloth, ink, sym, s, metal)
		end
		task.wait()
	end
end

-- ========== 1. Minimalista (imagen 2) ==========
do
	local m = Env("minimal", "Minimalista", { Sky = "Wylo", ClockTime = 14, Brightness = 2.6, Ambient = rgb(180, 176, 170), OutdoorAmbient = rgb(190, 188, 182),
		Shadows = true, Exposure = 0, Atmos = 0.12, AtmosColor = rgb(205, 228, 255), Carpet = rgb(172, 10, 22) })
	Floor(m, rgb(232, 230, 224), M.Pavement)
	Stage(m, { curtain = rgb(150, 8, 18) })
	RopeLine(m, GOLD, GOLDD, RED, GOLD)
	FloodLine(m)
	BannerPairs(m, { -86, -52, -18, 16 }, 33, 24, rgb(120, 14, 26), GOLD, "♛")
	-- setos a los lados del arco
	for _, s in ipairs({ -1, 1 }) do
		for i = 0, 10 do
			Ball(m, "Seto", 6 + i % 3, V3(s * (24 + i * 3.4), 3.6, -112 - (i % 2) * 2), rgb(44, 120, 42):Lerp(rgb(26, 80, 28), (i % 3) * 0.2), M.Grass)
		end
	end
	done(m)
end

-- ========== 2. Museo (imagen 3) ==========
do
	local m = Env("museo", "Museo", { Sky = "Wylo", ClockTime = 12, Brightness = 2, Ambient = rgb(200, 188, 170), OutdoorAmbient = rgb(190, 180, 165),
		Shadows = true, Exposure = 0.05, Atmos = 0, Carpet = rgb(172, 10, 22) })
	Floor(m, rgb(222, 216, 206), M.Marble, { Reflectance = 0.12 })
	Stage(m, { curtain = rgb(138, 8, 20), wing = rgb(234, 228, 216), wingMat = M.Marble })
	RopeLine(m, GOLD, GOLDD, RED, GOLD)
	FloodLine(m)
	local cream = rgb(240, 234, 222)
	local H = 34
	for _, s in ipairs({ -1, 1 }) do
		P(m, "Pared", V3(2, 46, 200), CF(s * 44, 23, -30), cream, M.SmoothPlastic)
		P(m, "Friso", V3(3, 3, 200), CF(s * 42.6, H + 1.5, -30), rgb(214, 204, 186), M.Marble)
		P(m, "Zocalo", V3(2.4, 2, 200), CF(s * 42.9, 1, -30), rgb(190, 178, 160), M.Marble)
		for i = 0, 7 do
			local z = -96 + i * 22
			Column(m, V3(s * 33, 0, z), H, 4.2, rgb(244, 240, 232))
			task.wait()
			-- arco entre columnas
			local segs, last = 9, nil
			for k = 0, segs do
				local a = PI * k / segs
				local p = V3(s * 33, H - 8 + math.sin(a) * 9, z + 11 - math.cos(a) * 11)
				if last and i < 7 then Bar(m, "Arco", last, p, 1.5, rgb(238, 232, 220), M.Marble) end
				last = p
			end
			if i < 7 then
				local zc = z + 11
				-- cuadro con marco dorado o estatua, alternando
				if i % 2 == 0 then
					local pz = V3(s * 42.7, 15, zc)
					P(m, "Marco", V3(0.5, 16.5, 12.5), CF(pz), rgb(198, 150, 60), M.Metal)
					local lienzo = P(m, "Lienzo", V3(0.2, 15, 11), CF(pz - V3(s * 0.3, 0, 0)), rgb(70, 50, 40), M.Fabric)
					local g = Instance.new("SurfaceGui")
					g.Face = s < 0 and Enum.NormalId.Right or Enum.NormalId.Left
					g.LightInfluence, g.Parent = 0.7, lienzo
					local fr = Instance.new("Frame")
					fr.Size, fr.BackgroundColor3, fr.Parent = UDim2.fromScale(1, 1), Color3.new(1, 1, 1), g
					local gr = Instance.new("UIGradient")
					local pal = { { rgb(42, 74, 120), rgb(226, 170, 90) }, { rgb(116, 40, 36), rgb(240, 190, 120) }, { rgb(50, 96, 66), rgb(232, 214, 150) }, { rgb(70, 44, 92), rgb(232, 140, 110) } }
					local c = pal[i / 2 + 1]
					gr.Color, gr.Rotation, gr.Parent = ColorSequence.new(c[1], c[2]), 72, fr
				else
					P(m, "Peana", V3(5, 3.6, 5), CF(s * 37.5, 1.8, zc), rgb(240, 236, 226), M.Marble)
					Statue(m, V3(s * 37.5, 2.8, zc), rgb(244, 242, 236), M.Marble)
				end
				-- pancarta colgada de cara al pasillo
				local b = Banner(m, V3(0, 0, 0), 16, rgb(120, 14, 26), GOLD, "♛", s)
				b:PivotTo(CF(s * 39.5, H - 9, zc) * Ang(0, s * PI / 2, 0))
				Plant(m, V3(s * 28.6, 0, z + 5), 1.4, rgb(240, 236, 226))
			end
			-- hiedra colgando
			for k = 1, 9 do
				Ball(m, "Hiedra", rnd:NextNumber(1.2, 2.3), V3(s * (33 + rnd:NextNumber(-2.4, 2.4)), H + 1.5 - k * rnd:NextNumber(0.7, 1.5), z + rnd:NextNumber(-3, 3)),
					rgb(58, 128, 42):Lerp(rgb(30, 86, 30), rnd:NextNumber()), M.Grass)
			end
		end
	end
	-- techo de cristal con nervios
	for i = 0, 12 do
		local z = -118 + i * 16
		local last = nil
		for k = 0, 12 do
			local a = PI * k / 12
			local p = V3(math.cos(a) * 34, H + 3 + math.sin(a) * 14, z)
			if last then Bar(m, "Nervio", last, p, 0.8, rgb(92, 82, 70), M.Metal) end
			last = p
		end
		task.wait()
	end
	local tiles = 12
	for k = 0, tiles - 1 do
		local a0, a1 = PI * k / tiles, PI * (k + 1) / tiles
		local p0, p1 = V3(math.cos(a0) * 34, H + 3 + math.sin(a0) * 14, -30), V3(math.cos(a1) * 34, H + 3 + math.sin(a1) * 14, -30)
		local mid, len = (p0 + p1) / 2, (p1 - p0).Magnitude + 0.2
		P(m, "Cristal", V3(len, 0.2, 192), CF(mid, mid + (p1 - p0)) * Ang(0, PI / 2, 0) * Ang(0, 0, 0), rgb(210, 232, 250), M.Glass, { Transparency = 0.72 }).Size = V3(0.2, 0.2, 0.2)
	end
	-- (paneles ajustados a mano: cada uno ocupa el tramo entre nervios a lo largo de la nave)
	for _, c in ipairs(m:GetChildren()) do
		if c.Name == "Cristal" and c:IsA("BasePart") then c:Destroy() end
	end
	for k = 0, tiles - 1 do
		local a0, a1 = PI * k / tiles, PI * (k + 1) / tiles
		local p0, p1 = V3(math.cos(a0) * 34, H + 3 + math.sin(a0) * 14, -30), V3(math.cos(a1) * 34, H + 3 + math.sin(a1) * 14, -30)
		local across = (p1 - p0)
		local right = across.Unit
		local fwd = V3(0, 0, 1)
		local up = right:Cross(fwd)
		P(m, "Cristal", V3(across.Magnitude + 0.2, 0.2, 192), CFrame.fromMatrix((p0 + p1) / 2, right, up, fwd), rgb(210, 232, 250), M.Glass, { Transparency = 0.72 })
	end
	done(m)
end

-- ========== 3. Gala de cine (imagen 4) ==========
do
	local m = Env("cine", "Gala de cine", { Sky = "Noche", ClockTime = 0, Brightness = 1, Ambient = rgb(118, 104, 120), OutdoorAmbient = rgb(110, 100, 130),
		Shadows = false, Exposure = 0.15, Atmos = 0, Carpet = rgb(165, 10, 20) })
	Floor(m, rgb(30, 28, 32), M.Slate, { Reflectance = 0.06 })
	RopeLine(m, GOLD, GOLDD, RED, GOLD)
	FloodLine(m)
	local dark = rgb(18, 16, 18)
	local fz = -112
	P(m, "Fachada", V3(130, 54, 3), CF(0, 27, fz - 2), dark, M.SmoothPlastic)
	-- puertas doradas
	for _, s in ipairs({ -1, 1 }) do
		P(m, "Puerta", V3(7, 16, 0.4), CF(s * 3.7, 8, fz), rgb(88, 62, 28), M.Metal)
		P(m, "Cristal", V3(5.6, 14, 0.2), CF(s * 3.7, 8.2, fz + 0.3), rgb(40, 34, 28), M.Glass, { Transparency = 0.2 })
		P(m, "Tirador", V3(0.3, 7, 0.3), CF(s * 1.2, 8, fz + 0.6), GOLD, M.Metal)
		P(m, "MarcoPuerta", V3(0.8, 18, 1), CF(s * 7.8, 9, fz), GOLD, M.Metal)
		P(m, "Muro", V3(26, 54, 2), CF(s * 34, 27, -105), dark)
		P(m, "MuroInterior", V3(20, 54, 2), CF(s * 22, 27, -111), dark)
		-- paneles con película
		for _, x in ipairs({ 26, 44 }) do
			local pn = P(m, "Panel", V3(13, 30, 0.4), CF(s * x, 20, -103.7), rgb(26, 22, 18), M.Metal)
			Label(pn, Enum.NormalId.Back, "🎥", GOLD, nil, 22)
			for _, e in ipairs({ { 6.7, 0, 0.3, 30 }, { -6.7, 0, 0.3, 30 }, { 0, 15, 13.5, 0.3 }, { 0, -15, 13.5, 0.3 } }) do
				P(m, "Filo", V3(e[3], e[4], 0.2), CF(s * x + e[1], 20 + e[2], -103.4), GOLD, M.Neon)
			end
		end
		Palm(m, V3(s * 30, 0, -96), 24)
		Palm(m, V3(s * 37, 0, -66), 28)
		Palm(m, V3(s * 35, 0, -30), 24)
		Palm(m, V3(s * 37, 0, 6), 28)
		task.wait()
	end
	P(m, "MarcoPuerta", V3(16, 0.8, 1), CF(0, 18, fz), GOLD, M.Metal)
	-- marquesina redonda con bombillas
	local mqy = 25
	for i = 0, 15 do
		local a = PI * i / 15
		local cx, cz = math.cos(a) * 26, fz + 2 + math.sin(a) * 9
		P(m, "Marquesina", V3(5.6, 5, 1), CF(cx, mqy, cz) * Ang(0, -a + PI / 2, 0), rgb(255, 232, 180), M.Neon)
		P(m, "Vuelo", V3(5.8, 0.8, 11), CF(cx * 0.6, mqy - 3, fz + 2 + math.sin(a) * 5.4) * Ang(0, -a + PI / 2, 0), rgb(36, 30, 24), M.Metal)
		P(m, "Canto", V3(5.8, 0.6, 1.2), CF(cx, mqy + 2.9, cz) * Ang(0, -a + PI / 2, 0), GOLD, M.Metal)
		P(m, "Canto", V3(5.8, 0.6, 1.2), CF(cx, mqy - 2.9, cz) * Ang(0, -a + PI / 2, 0), GOLD, M.Metal)
		for k = -1, 1 do
			local q = CF(cx, mqy - 3.6, cz) * Ang(0, -a + PI / 2, 0) * CF(k * 1.7, 0, 0)
			local b = Ball(m, "Bombilla", 0.75, q.Position, rgb(255, 240, 200), M.Neon)
		end
	end
	local glow = P(m, "LuzMarquesina", V3(1, 1, 1), CF(0, 20, fz + 10), CREAM, M.SmoothPlastic, { Transparency = 1 })
	Light(glow, 60, 3, rgb(255, 215, 150))
	-- bobina de cine arriba
	local rc = V3(0, 44, fz + 0.4)
	P(m, "Bobina", V3(1, 20, 20), CF(rc) * Ang(0, PI / 2, 0), GOLD, M.Metal, { Shape = Enum.PartType.Cylinder })
	P(m, "BobinaInt", V3(1.1, 16, 16), CF(rc + V3(0, 0, 0.1)) * Ang(0, PI / 2, 0), rgb(22, 18, 14), M.Metal, { Shape = Enum.PartType.Cylinder })
	P(m, "Centro", V3(1.3, 4, 4), CF(rc + V3(0, 0, 0.2)) * Ang(0, PI / 2, 0), GOLD, M.Metal, { Shape = Enum.PartType.Cylinder })
	for i = 0, 5 do
		local a = i * PI / 3
		P(m, "Radio", V3(1.3, 3.8, 3.8), CF(rc + V3(math.cos(a) * 5.6, math.sin(a) * 5.6, 0.2)) * Ang(0, PI / 2, 0), GOLD, M.Metal, { Shape = Enum.PartType.Cylinder })
	end
	-- reflectores al cielo (los gira el cliente: atributo Barre)
	for i, x in ipairs({ -54, -32, 32, 54 }) do
		local base = P(m, "Reflector", V3(3, 3, 3), CF(x, 54, fz - 2), rgb(30, 30, 34), M.Metal)
		base:SetAttribute("Barre", i)
		local a0 = Instance.new("Attachment") a0.Parent = base
		local tip = P(m, "PuntaHaz", V3(1, 1, 1), CF(x, 170, fz - 40), WHITE, M.SmoothPlastic, { Transparency = 1 })
		local a1 = Instance.new("Attachment") a1.Parent = tip
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1, b.Width0, b.Width1, b.LightEmission, b.FaceCamera = a0, a1, 3, 18, 1, true
		b.Color = ColorSequence.new(rgb(190, 215, 255))
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		b.Parent = base
	end
	done(m)
end

-- ========== 4. Espacio ==========
do
	local m = Env("espacio", "Espacio", { Sky = "Noche", ClockTime = 0, Brightness = 0.6, Ambient = rgb(120, 118, 170), OutdoorAmbient = rgb(112, 118, 180),
		Shadows = false, Exposure = 0.1, Atmos = 0, Stars = true, Carpet = rgb(170, 14, 40), Marks = rgb(120, 225, 255) })
	-- plataforma de cristal flotando
	local plat = P(m, "SueloVisual", V3(66, 1, 196), CF(0, -0.52, -28), rgb(18, 22, 48), M.Glass, { Reflectance = 0.1 })
	for _, s in ipairs({ -1, 1 }) do
		P(m, "BordeNeon", V3(0.5, 0.5, 196), CF(s * 33, -0.1, -28), rgb(80, 210, 255), M.Neon)
		P(m, "Faldon", V3(1, 8, 196), CF(s * 33, -4.5, -28), rgb(28, 30, 60), M.Metal)
	end
	for i = 0, 24 do
		P(m, "Rejilla", V3(66, 0.04, 0.16), CF(0, -0.01, -124 + i * 8), rgb(70, 110, 220), M.Neon)
	end
	for i = -4, 4 do
		P(m, "Rejilla", V3(0.16, 0.04, 196), CF(i * 8, -0.01, -28), rgb(70, 110, 220), M.Neon)
	end
	Stage(m, { curtain = rgb(66, 34, 150), wing = rgb(26, 26, 58), wingLed = rgb(90, 220, 255), archCols = { rgb(120, 225, 255), rgb(140, 100, 255), rgb(120, 225, 255) },
		statue = rgb(210, 225, 255), statueLight = rgb(140, 190, 255) })
	GlassLine(m, rgb(70, 190, 255), rgb(30, 32, 58))
	FloodLine(m, rgb(150, 215, 255))
	-- planetas y anillos
	local function planet(pos, d, a, b, ring, spin)
		local g = Group(m, "Planeta")
		local pl = Ball(g, "Esfera", d, pos, a, M.SmoothPlastic)
		pl:SetAttribute("Gira", spin or 0.03)
		Ball(g, "Halo", d * 1.05, pos, b, M.Neon, { Transparency = 0.86 })
		for i = 1, 5 do -- bandas
			local h = pos + V3(0, (i - 3) * d * 0.14, 0)
			local r = math.sqrt(math.max(0.01, (d / 2) ^ 2 - (h.Y - pos.Y) ^ 2))
			P(g, "Banda", V3(d * 0.05, r * 2.012, r * 2.012), CF(h) * Ang(0, 0, PI / 2), a:Lerp(b, i % 2 == 0 and 0.55 or 0.25), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
		end
		if ring then
			local rg = Group(g, "Anillo")
			local n = 44
			for i = 0, n - 1 do
				local t = i * PI * 2 / n
				local rr = d * 0.86
				local cf = CF(pos) * Ang(math.rad(18), 0, math.rad(12)) * CF(math.cos(t) * rr, 0, math.sin(t) * rr) * Ang(0, -t, 0)
				P(rg, "Tramo", V3(d * 0.22, 0.4, rr * PI * 2 / n + 0.8), cf, b:Lerp(a, (i % 3) * 0.2), M.Neon, { Transparency = 0.25 })
			end
		end
		task.wait()
	end
	planet(V3(-140, 95, -240), 150, rgb(216, 118, 74), rgb(255, 196, 120), true)
	planet(V3(170, 60, -170), 90, rgb(70, 110, 220), rgb(130, 220, 255), false)
	planet(V3(-120, 26, 40), 46, rgb(150, 80, 200), rgb(255, 120, 220), true)
	planet(V3(110, 130, -320), 60, rgb(230, 230, 240), rgb(200, 210, 255), false)
	-- asteroides que giran despacio
	local belt = Group(m, "Asteroides")
	for i = 1, 56 do
		local s = i % 2 == 0 and 1 or -1
		local p = V3(s * rnd:NextNumber(46, 130), rnd:NextNumber(-30, 60), rnd:NextNumber(-170, 70))
		local a = P(belt, "Roca", V3(rnd:NextNumber(2, 8), rnd:NextNumber(2, 7), rnd:NextNumber(2, 8)), CF(p) * Ang(rnd:NextNumber(0, 6), rnd:NextNumber(0, 6), rnd:NextNumber(0, 6)),
			rgb(84, 76, 88):Lerp(rgb(130, 120, 130), rnd:NextNumber()), M.Rock)
		a:SetAttribute("Roca", rnd:NextNumber(0.1, 0.6))
	end
	-- nebulosas
	for i = 1, 10 do
		local s = i % 2 == 0 and 1 or -1
		Ball(m, "Nebulosa", rnd:NextNumber(70, 150), V3(s * rnd:NextNumber(100, 260), rnd:NextNumber(0, 140), rnd:NextNumber(-340, -40)),
			(i % 3 == 0 and rgb(255, 90, 200)) or (i % 3 == 1 and rgb(110, 90, 255)) or rgb(70, 190, 255), M.Neon, { Transparency = 0.93 })
	end
	-- aros flotantes sobre la alfombra
	for i = 0, 3 do
		local z = -74 + i * 30
		local n, r = 34, 15
		for k = 0, n - 1 do
			local t = PI * 2 * k / n
			P(m, "Aro", V3(r * PI * 2 / n + 0.3, 0.32, 0.32), CF(math.cos(t) * r, 15 + math.sin(t) * r, z) * Ang(0, 0, t + PI / 2), rgb(90, 200, 255):Lerp(rgb(170, 110, 255), (i % 2)), M.Neon)
		end
		task.wait()
	end
	done(m)
end

-- ========== 5. Pasarela con focos y butacas (la foto de la pasarela morada) ==========
do
	local m = Env("pasarela", "Pasarela", { Sky = "Noche", ClockTime = 0, Brightness = 0.5, Ambient = rgb(176, 160, 196), OutdoorAmbient = rgb(150, 136, 180),
		Shadows = false, Exposure = 0.1, Atmos = 0, Carpet = rgb(245, 243, 248), Marks = rgb(255, 255, 255), CarpetMat = "SmoothPlastic" })
	local purple, wall = rgb(70, 56, 92), rgb(96, 80, 120)
	Floor(m, rgb(46, 40, 60), M.SmoothPlastic, { Reflectance = 0.08 })
	RopeLine(m, rgb(232, 230, 240), rgb(170, 165, 190), rgb(190, 150, 255), rgb(232, 230, 240))
	for _, s in ipairs({ -1, 1 }) do
		P(m, "Pared", V3(2, 50, 210), CF(s * 62, 25, -28), wall)
		-- luces chispeantes en el borde de la pasarela
		for i = 0, 22 do
			local z = -98 + i * 7
			local b = Ball(m, "Chispa", 0.5, V3(s * 8.4, 0.28, z), WHITE, M.Neon)
			if i % 3 == 0 then Light(b, 9, 1.4, rgb(255, 240, 255)) end
			CS:AddTag(b, "RCSpark")
		end
		-- gradas con butacas y público
		for row = 0, 4 do
			local x, y = s * (27 + row * 5.2), row * 1.6
			P(m, "Grada", V3(5.2, 0.8 + y, 150), CF(x, (0.8 + y) / 2, -24), rgb(58, 48, 78))
			for i = 0, 22 do
				local z = -96 + i * 6.4
				local seat = CF(x, y + 0.8, z)
				local turn = Ang(0, s < 0 and -PI / 2 or PI / 2, 0)
				P(m, "Asiento", V3(3.4, 1.1, 3), seat * turn * CF(0, 0.75, 0), rgb(150, 132, 190), M.Fabric)
				P(m, "Respaldo", V3(3.4, 3.8, 0.8), seat * turn * CF(0, 2.2, 1.5), rgb(136, 118, 178), M.Fabric)
				if (i + row) % 3 ~= 0 then -- público sentado
					local col = Color3.fromHSV(rnd:NextNumber(), 0.55, 0.85)
					local skin = ({ rgb(255, 224, 189), rgb(224, 172, 128), rgb(140, 92, 62) })[rnd:NextInteger(1, 3)]
					P(m, "Cuerpo", V3(1.9, 2, 1), seat * turn * CF(0, 2.3, 0.45), col)
					P(m, "Cabeza", V3(1.15, 1.15, 1.15), seat * turn * CF(0, 3.9, 0.45), skin)
				end
			end
			task.wait()
		end
	end
	P(m, "Fondo", V3(124, 50, 2), CF(0, 25, -122), wall)
	P(m, "Techo", V3(126, 2, 214), CF(0, 51, -28), rgb(30, 26, 42))
	-- panel con logo
	local panel = P(m, "Logo", V3(46, 30, 1), CF(0, 15.5, -106), rgb(232, 228, 240), M.SmoothPlastic)
	Light(panel, 34, 1.2, rgb(235, 225, 255), "SurfaceLight").Face = Enum.NormalId.Back
	local aro = Group(m, "AroLogo")
	local pz = -105.4
	for i = 0, 35 do
		local t = i * PI / 18
		P(aro, "Tramo", V3(2.35, 1, 0.4), CF(math.cos(t) * 8.6, 16 + math.sin(t) * 8.6, pz) * Ang(0, 0, t + PI / 2), purple)
	end
	local lg = P(m, "LogoTxt", V3(13, 11, 0.2), CF(0, 16, pz), purple, M.SmoothPlastic, { Transparency = 1 })
	Label(lg, Enum.NormalId.Back, "RC", purple, nil, 30)
	for _, s in ipairs({ -1, 1 }) do
		P(m, "Muro", V3(35, 34, 2), CF(s * 42, 17, -105), rgb(82, 68, 104))
		P(m, "Tapa", V3(6, 1, 12), CF(s * 26, 0.4, -106), rgb(46, 40, 60))
	end
	-- estructura de focos (truss) con haces de luz
	local function truss(a, b)
		local dir = (b - a)
		local n = math.floor(dir.Magnitude / 4)
		for _, o in ipairs({ V3(0, 0.9, 0.9), V3(0, -0.9, 0.9), V3(0, 0.9, -0.9), V3(0, -0.9, -0.9) }) do
			local off = math.abs(dir.Z) > math.abs(dir.X) and V3(o.Z, o.Y, 0) or o
			Bar(m, "Tubo", a + off, b + off, 0.3, rgb(120, 122, 134), M.Metal)
		end
		for i = 0, n do
			local p = a + dir * (i / n)
			local off = math.abs(dir.Z) > math.abs(dir.X) and V3(0.9, 0, 0) or V3(0, 0, 0.9)
			Bar(m, "Diag", p + off + V3(0, 0.9, 0), p - off - V3(0, 0.9, 0), 0.14, rgb(120, 122, 134), M.Metal)
		end
	end
	local function spot(pos, aim)
		local g = Group(m, "Foco")
		local cf = CF(pos, aim)
		Bar(g, "Cuerpo", (cf * CF(0, 0, 0.8)).Position, (cf * CF(0, 0, -1.2)).Position, 1.9, rgb(22, 22, 26), M.Metal)
		local lens = Bar(g, "Cristal", (cf * CF(0, 0, -1.2)).Position, (cf * CF(0, 0, -1.28)).Position, 1.6, rgb(255, 250, 235), M.Neon)
		P(g, "Horquilla", V3(0.2, 1.8, 0.2), CF(pos + V3(0, 1.3, 0)), rgb(40, 40, 46), M.Metal)
		local a0 = Instance.new("Attachment") a0.Parent = lens
		local tip = P(g, "Punta", V3(1, 1, 1), CF(aim), WHITE, M.SmoothPlastic, { Transparency = 1 })
		local a1 = Instance.new("Attachment") a1.Parent = tip
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1, b.Width0, b.Width1, b.LightEmission, b.FaceCamera, b.Segments = a0, a1, 1.6, 9, 0.6, true, 6
		b.Color = ColorSequence.new(rgb(255, 245, 255))
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) })
		b.Parent = lens
		local sp = P(g, "Luz", V3(1, 1, 1), CF(aim + V3(0, 7, 0)), WHITE, M.SmoothPlastic, { Transparency = 1 })
		Light(sp, 15, 1.1, rgb(255, 245, 250))
	end
	for _, s in ipairs({ -1, 1 }) do truss(V3(s * 13, 34, -102), V3(s * 13, 34, 48)) end
	for i = 0, 6 do
		local z = -98 + i * 24
		truss(V3(-13, 34, z), V3(13, 34, z))
		task.wait()
		for _, x in ipairs({ -8, 0, 8 }) do spot(V3(x, 31.2, z), V3(x * 0.55, 0.1, z + 8)) end
	end
	done(m)
end
