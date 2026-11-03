-- Ayudantes del constructor de Red Carpet (se concatena delante de cada trozo)
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local rgb = Color3.fromRGB
local V3, CF = Vector3.new, CFrame.new
local Ang = CFrame.Angles
local PI = math.pi
local M = Enum.Material
local GOLD, GOLDD, CREAM = rgb(236, 178, 62), rgb(176, 122, 34), rgb(255, 226, 170)
local RED, REDD, BLACK = rgb(165, 12, 22), rgb(96, 6, 14), rgb(24, 24, 28)
local STEEL, WHITE = rgb(160, 164, 172), rgb(242, 240, 234)

local function P(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color or WHITE
	p.Material = mat or M.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if extra then for k, v in pairs(extra) do p[k] = v end end
	p.Parent = parent
	return p
end
-- cilindro de pie (eje Y); Roblox lo tiene en X, por eso el giro
local function Cyl(parent, name, h, d, pos, color, mat, extra)
	local e = extra or {}
	e.Shape = Enum.PartType.Cylinder
	return P(parent, name, V3(h, d, d), CF(pos) * Ang(0, 0, PI / 2), color, mat, e)
end
-- cilindro entre dos puntos
local function Bar(parent, name, a, b, d, color, mat, extra)
	local e = extra or {}
	e.Shape = Enum.PartType.Cylinder
	local len = (b - a).Magnitude
	return P(parent, name, V3(len, d, d), CF((a + b) / 2, b) * Ang(0, PI / 2, 0), color, mat, e)
end
local function Ball(parent, name, d, pos, color, mat, extra)
	local e = extra or {}
	e.Shape = Enum.PartType.Ball
	return P(parent, name, V3(d, d, d), CF(pos), color, mat, e)
end
local function Group(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function Folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then f:Destroy() end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function Light(p, range, bright, color, kind)
	local l = Instance.new(kind or "PointLight")
	l.Range, l.Brightness, l.Color = range, bright, color or CREAM
	l.Shadows = false
	l.Parent = p
	return l
end
local function Label(part, face, text, color, font, res)
	local g = Instance.new("SurfaceGui")
	g.Face, g.SizingMode, g.PixelsPerStud, g.LightInfluence = face, Enum.SurfaceGuiSizingMode.PixelsPerStud, res or 40, 0
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency, t.Size, t.Text, t.TextScaled, t.TextColor3 = 1, UDim2.fromScale(1, 1), text, true, color or GOLD
	t.Font = font or Enum.Font.FredokaOne
	t.Parent = g
	return g
end

-- ---------- vallas ----------
local function Stanchion(parent, pos, metal, metalD, mat)
	local g = Group(parent, "Poste")
	Cyl(g, "Base", 0.18, 2.1, pos + V3(0, 0.09, 0), metalD or metal, mat or M.Metal)
	Cyl(g, "Base2", 0.2, 1.3, pos + V3(0, 0.26, 0), metal, mat or M.Metal)
	Cyl(g, "Tubo", 2.9, 0.5, pos + V3(0, 1.75, 0), metal, mat or M.Metal)
	Cyl(g, "Aro", 0.14, 0.72, pos + V3(0, 3.2, 0), metalD or metal, mat or M.Metal)
	Ball(g, "Bola", 0.82, pos + V3(0, 3.62, 0), metal, mat or M.Metal)
	return g
end
local function Rope(parent, a, b, color, sag, hook)
	local g = Group(parent, "Cuerda")
	local n, last = 8, nil
	for i = 0, n do
		local t = i / n
		local p = a:Lerp(b, t) - V3(0, sag * 4 * t * (1 - t), 0)
		if last then Bar(g, "Tramo", last, p, 0.38, color, M.Fabric) end
		last = p
	end
	Ball(g, "Gancho", 0.42, a, hook or GOLD, M.Metal)
	Ball(g, "Gancho", 0.42, b, hook or GOLD, M.Metal)
end
-- línea de vallas de cuerda a un lado (side = -1/1)
local BARRIER_X, BARRIER_Z0, BARRIER_Z1, BARRIER_STEP = 9.6, -96, 52, 11.5
local function RopeLine(parent, metal, metalD, rope, hook)
	for _, side in ipairs({ -1, 1 }) do
		local z, last = BARRIER_Z0, nil
		while z <= BARRIER_Z1 do
			local pos = V3(side * BARRIER_X, 0, z)
			Stanchion(parent, pos, metal, metalD)
			if last then Rope(parent, last + V3(0, 3.0, 0.28), pos + V3(0, 3.0, -0.28), rope, 1.15, hook) end
			last = pos
			z += BARRIER_STEP
		end
		task.wait()
	end
end
-- vallas de vidrio con LED
local function GlassLine(parent, led, post)
	for _, side in ipairs({ -1, 1 }) do
		local z, last = BARRIER_Z0, nil
		while z <= BARRIER_Z1 do
			local pos = V3(side * BARRIER_X, 0, z)
			Cyl(parent, "Base", 0.25, 1.5, pos + V3(0, 0.12, 0), post, M.Metal)
			P(parent, "Poste", V3(0.5, 3.8, 0.5), CF(pos + V3(0, 2, 0)), post, M.Metal)
			P(parent, "Led", V3(0.56, 3.1, 0.14), CF(pos + V3(0, 2, 0)), led, M.Neon)
			if last then
				local mid, len = (pos + last) / 2, (pos - last).Magnitude - 0.6
				P(parent, "Vidrio", V3(0.08, 3, len), CF(mid + V3(0, 2, 0)), led:Lerp(WHITE, 0.6), M.Glass, { Transparency = 0.72 })
				P(parent, "LedAbajo", V3(0.12, 0.1, len), CF(mid + V3(0, 0.48, 0)), led, M.Neon)
				P(parent, "LedArriba", V3(0.12, 0.08, len), CF(mid + V3(0, 3.5, 0)), led:Lerp(WHITE, 0.3), M.Neon)
			end
			last = pos
			z += BARRIER_STEP
		end
		task.wait()
	end
end
-- jardineras con seto y tira de luz
local function HedgeLine(parent, box, leaf, led)
	for _, side in ipairs({ -1, 1 }) do
		local z = BARRIER_Z0
		while z <= BARRIER_Z1 do
			local pos = V3(side * BARRIER_X, 0, z + 5.2)
			P(parent, "Jardinera", V3(1.9, 1.5, 9.6), CF(pos + V3(0, 0.75, 0)), box)
			P(parent, "Tira", V3(0.1, 0.12, 8.6), CF(pos + V3(-side * 0.96, 0.75, 0)), led, M.Neon)
			for i = -4, 4 do
				for _, dx in ipairs({ -0.35, 0.35 }) do
					Ball(parent, "Hoja", 1.25 + (i % 3) * 0.14, pos + V3(dx, 1.95 + (i % 2) * 0.16, i * 1.05), leaf:Lerp(rgb(30, 90, 20), (i % 3) * 0.14), M.Grass)
				end
			end
			z += 10.4
		end
		task.wait()
	end
end
-- vallas de evento: paneles con corona
local function PanelLine(parent, metal, panel, ink)
	for _, side in ipairs({ -1, 1 }) do
		local z, last = BARRIER_Z0, nil
		while z <= BARRIER_Z1 do
			local pos = V3(side * BARRIER_X, 0, z)
			Stanchion(parent, pos, metal, metal)
			if last then
				local mid, len = (pos + last) / 2, (pos - last).Magnitude - 0.8
				local f = P(parent, "Panel", V3(0.18, 2.3, len), CF(mid + V3(0, 1.75, 0)), panel, M.Fabric)
				P(parent, "Riel", V3(0.26, 0.16, len), CF(mid + V3(0, 3, 0)), metal, M.Metal)
				P(parent, "Riel", V3(0.26, 0.16, len), CF(mid + V3(0, 0.55, 0)), metal, M.Metal)
				Label(f, side < 0 and Enum.NormalId.Right or Enum.NormalId.Left, "♛", ink, nil, 20)
			end
			last = pos
			z += BARRIER_STEP
		end
		task.wait()
	end
end
-- focos de suelo a lo largo de la alfombra
local function FloodLine(parent, color)
	for _, side in ipairs({ -1, 1 }) do
		local z = BARRIER_Z0 + 5.5
		while z <= BARRIER_Z1 do
			local pos = V3(side * 8.9, 0, z)
			local tilt = CF(pos + V3(0, 0.5, 0)) * Ang(0, side > 0 and PI or 0, 0) * Ang(0, 0, math.rad(-38))
			P(parent, "Caja", V3(1.7, 0.9, 1.3), tilt, rgb(34, 34, 38), M.Metal)
			local f = P(parent, "Cristal", V3(0.08, 0.72, 1.1), tilt * CF(0.86, 0, 0), color or CREAM, M.Neon)
			Light(f, 9, 1.2, color or CREAM)
			z += 11.5
		end
	end
end

-- ---------- escenario común ----------
local function Curtain(parent, cf, w, h, color)
	local n = math.floor(w / 1.1)
	for i = 0, n do
		local x = -w / 2 + i * w / n
		local c = i % 2 == 0 and color or color:Lerp(rgb(30, 0, 4), 0.45)
		P(parent, "Pliegue", V3(h, 1.25, 1.25), cf * CF(x, 0, (i % 2) * 0.28) * Ang(0, 0, PI / 2), c, M.Fabric, { Shape = Enum.PartType.Cylinder })
	end
end
local function Statue(parent, pos, color, mat)
	local g = Group(parent, "Estatuilla")
	local col, mt = color or rgb(246, 188, 60), mat or M.Metal
	Cyl(g, "Peana", 1.1, 3.1, pos + V3(0, 0.55, 0), rgb(30, 22, 12), M.Metal)
	Cyl(g, "Pies", 0.8, 1.7, pos + V3(0, 1.5, 0), col, mt)
	Bar(g, "PiernaI", pos + V3(-0.42, 1.8, 0), pos + V3(-0.5, 5.2, 0), 1.0, col, mt)
	Bar(g, "PiernaD", pos + V3(0.42, 1.8, 0), pos + V3(0.5, 5.2, 0), 1.0, col, mt)
	Bar(g, "Cuerpo", pos + V3(0, 4.9, 0), pos + V3(0, 7.9, 0), 2.1, col, mt)
	Ball(g, "Hombros", 2.75, pos + V3(0, 7.8, 0), col, mt)
	Bar(g, "BrazoI", pos + V3(-1.32, 8, 0), pos + V3(-1.05, 5.4, 0.55), 0.78, col, mt)
	Bar(g, "BrazoD", pos + V3(1.32, 8, 0), pos + V3(1.05, 5.4, 0.55), 0.78, col, mt)
	Bar(g, "AntebrazoI", pos + V3(-1.05, 5.4, 0.55), pos + V3(0, 5.7, 1.0), 0.66, col, mt)
	Bar(g, "AntebrazoD", pos + V3(1.05, 5.4, 0.55), pos + V3(0, 5.7, 1.0), 0.66, col, mt)
	Cyl(g, "Cuello", 0.5, 0.8, pos + V3(0, 9.2, 0), col, mt)
	Ball(g, "Cabeza", 1.55, pos + V3(0, 10, 0), col, mt)
	return g
end
-- arco de neón por anillos; devuelve grosor total. Centro en (0, y, z)
local function NeonArch(parent, z, r0, y, cols)
	local rings = cols or { CREAM, GOLD, CREAM }
	for k, col in ipairs(rings) do
		local r = r0 + (k - 1) * 1.7
		local segs, last = 22, nil
		for i = 0, segs do
			local a = PI * i / segs
			local p = V3(math.cos(a) * r, y + math.sin(a) * r, z)
			if last then
				local mid, len = (p + last) / 2, (p - last).Magnitude + 0.1
				P(parent, "Aro", V3(len, 0.6, 0.6), CF(mid, mid + (p - last)) * Ang(0, PI / 2, 0), col, k % 2 == 1 and M.Neon or M.Metal)
			end
			last = p
		end
		for _, s in ipairs({ -1, 1 }) do
			P(parent, "Pata", V3(0.6, y, 0.6), CF(s * r, y / 2, z), col, k % 2 == 1 and M.Neon or M.Metal)
		end
		task.wait()
	end
end
-- escalera + cortina + estatua + arco + muros laterales que tapan la entrada (z -105)
local STAGE_Z = -116
local function Stage(parent, opt)
	opt = opt or {}
	local arch = opt.archR or 16
	local cur = opt.curtain or rgb(150, 8, 18)
	Curtain(parent, CF(0, 15, STAGE_Z - 2), arch * 2 + 6, 30, cur)
	P(parent, "Fondo", V3(arch * 2 + 10, 34, 1), CF(0, 17, STAGE_Z - 4), rgb(24, 8, 10))
	local steps = 7
	for i = 1, steps do
		local z = -104.5 - i * 1.1
		P(parent, "Escalon", V3(26 - i * 0.4, 0.5 * i, 1.15), CF(0, 0.25 * i, z), rgb(148, 10, 20), M.Fabric)
		P(parent, "Filo", V3(26 - i * 0.4, 0.06, 0.08), CF(0, 0.5 * i + 0.01, z + 0.56), GOLD, M.Metal)
	end
	P(parent, "Tarima", V3(24, 3.5, 7), CF(0, 1.75, STAGE_Z + 1.6), rgb(120, 8, 16), M.Fabric)
	local top = 3.5
	local ped = P(parent, "Pedestal", V3(6.5, 2.2, 4.6), CF(0, top + 1.1, STAGE_Z + 1.2), rgb(255, 250, 235), M.Neon)
	Light(ped, 18, 1.6, CREAM)
	Statue(parent, V3(0, top + 2.2, STAGE_Z + 1.2), opt.statue, opt.statueMat)
	local glow = P(parent, "LuzEstatua", V3(1, 1, 1), CF(0, top + 10, STAGE_Z + 3), CREAM, M.SmoothPlastic, { Transparency = 1 })
	Light(glow, 26, 2.2, opt.statueLight or rgb(255, 205, 110))
	NeonArch(parent, -104, arch, 15, opt.archCols)
	for _, s in ipairs({ -1, 1 }) do -- muros que tapan por dónde salen
		local w = opt.wing or rgb(36, 28, 24)
		P(parent, "Muro", V3(26, 30, 2), CF(s * (arch + 5 + 13), 15, -105), w, opt.wingMat or M.SmoothPlastic)
		P(parent, "MuroInterior", V3(arch, 30, 2), CF(s * (arch + 6), 15, -111), w, opt.wingMat or M.SmoothPlastic)
		P(parent, "RemateNeon", V3(26, 0.3, 0.3), CF(s * (arch + 5 + 13), 30.2, -103.9), opt.wingLed or GOLD, M.Neon)
	end
end
-- pancarta con corona u otro símbolo
local function Banner(parent, pos, h, color, ink, sym, side, metal)
	local g = Group(parent, "Pancarta")
	metal = metal or GOLD
	P(g, "Tela", V3(5.2, h, 0.16), CF(pos + V3(0, -h / 2, 0)), color, M.Fabric)
	local tela = g.Tela
	Label(tela, Enum.NormalId.Front, sym or "♛", ink or GOLD, nil, 18)
	Label(tela, Enum.NormalId.Back, sym or "♛", ink or GOLD, nil, 18)
	for i = -1, 1, 2 do -- borde vertical
		P(g, "Filo", V3(0.14, h, 0.2), CF(pos + V3(i * 2.55, -h / 2, 0)), ink or GOLD, M.Metal)
	end
	P(g, "Filo", V3(5.2, 0.14, 0.2), CF(pos + V3(0, -h + 0.05, 0)), ink or GOLD, M.Metal)
	-- punta triangular
	for i = 0, 5 do
		P(g, "Punta", V3(5.2 - i * 0.9, 0.34, 0.16), CF(pos + V3(0, -h - 0.17 - i * 0.34, 0)), color, M.Fabric)
	end
	P(g, "Barra", V3(6.4, 0.32, 0.32), CF(pos + V3(0, 0.2, 0)), metal, M.Metal)
	return g
end
local function GoldPost(parent, pos, h, metal)
	metal = metal or GOLD
	P(parent, "Mastil", V3(1, h, 1), CF(pos + V3(0, h / 2, 0)), metal, M.Metal)
	P(parent, "Base", V3(1.8, 0.7, 1.8), CF(pos + V3(0, 0.35, 0)), metal, M.Metal)
	P(parent, "Remate", V3(1.9, 0.7, 1.9), CF(pos + V3(0, h + 0.35, 0)), metal, M.Metal)
end
local function Plant(parent, pos, scale, pot)
	local s = scale or 1
	Cyl(parent, "Maceta", 2.2 * s, 2.4 * s, pos + V3(0, 1.1 * s, 0), pot or WHITE)
	for i = 1, 11 do
		local a = i * 2.4
		local tilt = math.rad(25 + (i % 4) * 14)
		local o = CF(pos + V3(0, 2.2 * s, 0)) * Ang(0, a, 0) * Ang(tilt, 0, 0)
		P(parent, "Hoja", V3(0.75 * s, 0.08, 3.8 * s), o * CF(0, 0, -1.8 * s), rgb(36, 118 + (i % 3) * 20, 46), M.Grass)
	end
end
local function Palm(parent, pos, h)
	local last = pos
	for i = 1, 6 do
		local p = pos + V3(math.sin(i * 0.25) * 1.2, h * i / 6, 0)
		Bar(parent, "Tronco", last, p, 1.25 - i * 0.07, rgb(112, 80, 48), M.WoodPlanks)
		last = p
	end
	for i = 1, 9 do
		local base = CF(last) * Ang(0, i * PI * 2 / 9, 0)
		for k = 1, 4 do
			local p = base * CF(0, -0.28 * k * k * 0.5, -1.7 * k)
			P(parent, "Palma", V3(1.5 - k * 0.2, 0.1, 2), p * Ang(math.rad(-10 * k), 0, 0), rgb(50, 145, 36):Lerp(rgb(160, 180, 30), k * 0.08), M.Grass)
		end
	end
end
local function Column(parent, pos, h, d, color)
	Cyl(parent, "Fuste", h, d, pos + V3(0, h / 2, 0), color or WHITE, M.Marble)
	P(parent, "Basa", V3(d + 1.1, 1, d + 1.1), CF(pos + V3(0, 0.5, 0)), color or WHITE, M.Marble)
	P(parent, "Capitel", V3(d + 1.1, 1, d + 1.1), CF(pos + V3(0, h, 0)), color or WHITE, M.Marble)
end
local function Marker(parent, name, pos)
	return P(parent, name, V3(1, 1, 1), CF(pos), rgb(255, 0, 255), M.SmoothPlastic, { Transparency = 1 })
end
