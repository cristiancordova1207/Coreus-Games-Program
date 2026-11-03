-- Más mapa (columnas, farolas, torres, pórtico) y cámaras de seguridad repartidas a distintas distancias y alturas
local map = workspace.MapaActivo.RedCarpet
local ENVS = SS.EscenariosRC
local X = Folder(map, "Extras")

local function Col(pos, h)
	Column(X, pos, h, 3)
	for _, y in ipairs({ 3, h - 2.4 }) do
		Cyl(X, "Anillo", 0.4, 3.5, pos + V3(0, y, 0), GOLD, M.Metal)
	end
	Plant(X, pos + V3(pos.X > 0 and -3.4 or 3.4, 0, 0), 0.8, rgb(40, 40, 46))
end
for _, z in ipairs({ -86, -56, -26, 4 }) do
	Col(V3(-32, 0, z), 22)
	Col(V3(32, 0, z + 12), 22)
end
task.wait()

local function Lamp(pos)
	Cyl(X, "Base", 0.5, 1.8, pos + V3(0, 0.25, 0), rgb(26, 26, 30), M.Metal)
	Cyl(X, "Farola", 11, 0.42, pos + V3(0, 5.8, 0), rgb(26, 26, 30), M.Metal)
	local b = Ball(X, "Globo", 1.7, pos + V3(0, 12, 0), rgb(255, 238, 205), M.Neon)
	Light(b, 18, 0.9)
end
for _, z in ipairs({ -74, -41, -11, 19 }) do
	Lamp(V3(-25, 0, z))
	Lamp(V3(25, 0, z + 6))
end
task.wait()

-- torre de luces lejana
local function Tower(pos, h)
	local dark = rgb(58, 60, 68)
	local w = 2.2
	for _, c in ipairs({ V3(w, 0, w), V3(-w, 0, w), V3(w, 0, -w), V3(-w, 0, -w) }) do
		Bar(X, "Pata", pos + c, pos + c * 0.45 + V3(0, h, 0), 0.34, dark, M.Metal)
	end
	for y = 5, h - 2, 5 do
		local k = 1 - 0.55 * y / h
		P(X, "Aro", V3(w * 2 * k + 0.3, 0.22, w * 2 * k + 0.3), CF(pos + V3(0, y, 0)), dark, M.Metal, { Transparency = 0 })
	end
	local top = pos + V3(0, h + 1.4, 0)
	P(X, "Panel", V3(7, 3.2, 0.6), CF(top, V3(0, top.Y - 6, -30)), dark, M.Metal)
	for i = -1, 1 do
		for j = -1, 1, 2 do
			P(X, "Foco", V3(1.5, 0.9, 0.12), CF(top, V3(0, top.Y - 6, -30)) * CF(i * 2.2, j * 0.7, -0.36), rgb(255, 246, 225), M.Neon)
		end
	end
end
Tower(V3(62, 0, -44), 34)
Tower(V3(-62, 0, -14), 34)
Tower(V3(58, 0, 44), 28)
Tower(V3(-58, 0, 72), 28)
Tower(V3(20, 0, 98), 28)
task.wait()

-- pórtico sobre la alfombra
local function Truss(a, b, h)
	local dark = rgb(38, 40, 46)
	local up, n = V3(0, h, 0), math.floor((b - a).Magnitude / 3)
	Bar(X, "Cercha", a, b, 0.32, dark, M.Metal)
	Bar(X, "Cercha", a + up, b + up, 0.32, dark, M.Metal)
	for i = 0, n - 1 do
		local p, q = a:Lerp(b, i / n), a:Lerp(b, (i + 1) / n)
		Bar(X, "Diagonal", p, q + up, 0.16, dark, M.Metal)
		Bar(X, "Diagonal", q + up, q, 0.16, dark, M.Metal)
	end
end
local GZ = -52
Truss(V3(-25, 26, GZ), V3(25, 26, GZ), 2.6)
for _, s in ipairs({ -1, 1 }) do
	Truss(V3(s * 25, 0, GZ - 1), V3(s * 25, 26, GZ - 1), 0.01)
	Bar(X, "Pata", V3(s * 26.5, 0, GZ), V3(s * 26.5, 28.6, GZ), 0.5, rgb(38, 40, 46), M.Metal)
	P(X, "Zapata", V3(5, 0.5, 5), CF(s * 26, 0.25, GZ), rgb(30, 30, 34), M.Metal)
end
for i = -3, 3, 2 do -- focos colgados
	local x = i * 5
	local cf = CF(V3(x, 24.6, GZ), V3(0, 0, GZ + 16))
	Bar(X, "Foco", cf.Position, (cf * CF(0, 0, -2)).Position, 1.5, rgb(26, 26, 30), M.Metal)
	Cyl(X, "Cristal", 0.1, 1.3, Vector3.zero, rgb(255, 240, 210), M.Neon).CFrame = cf * CF(0, 0, -2.05) * Ang(0, PI / 2, 0)
end
task.wait()

-- ---------- cámaras de seguridad nuevas ----------
local cctv = map.Seguridad
for _, c in ipairs(cctv:GetChildren()) do
	if tonumber(c.Name:match("%d+")) > 5 then c:Destroy() end
end
-- pole = false: cuelga o va sobre algo que ya existe
local function cam(i, top, aim, pole, ext)
	local g = Group(cctv, "CCTV" .. i)
	if pole then Cyl(g, "Poste", top.Y, 0.7, V3(top.X, top.Y / 2, top.Z), rgb(46, 48, 54), M.Metal) end
	local dir = CF(top, aim)
	P(g, "Brazo", V3(0.4, 0.4, 1.8), dir * CF(0, 0, -0.9), rgb(210, 212, 216), M.Metal)
	P(g, "Cuerpo", V3(1.5, 1.4, 3.4), dir * CF(0, 0.2, -2.6), rgb(232, 232, 236))
	P(g, "Visera", V3(1.7, 0.16, 3.8), dir * CF(0, 1, -2.7), rgb(190, 192, 198))
	Cyl(g, "Lente", 0.3, 1, Vector3.zero, rgb(14, 14, 18), M.Glass).CFrame = dir * CF(0, 0.2, -4.42) * Ang(0, PI / 2, 0)
	Ball(g, "Rec", 0.2, (dir * CF(0.5, -0.32, -4.25)).Position, rgb(255, 40, 40), M.Neon)
	Marker(g, "Ojo", (dir * CF(0, 0.2, -4.8)).Position):SetAttribute("Num", i)
	if ext then g:SetAttribute("Ext", true) end
end
-- arriba de columnas
cam(6, V3(32, 22.8, -74), V3(0, 2, -66), false, true)
cam(7, V3(-32, 22.8, -26), V3(0, 2, -32), false, true)
cam(8, V3(32, 22.8, 16), V3(0, 2, 2), false, true)
-- torres lejanas
cam(9, V3(60, 36.5, -44), V3(0, 2, -44), false, true)
cam(10, V3(-60, 36.5, -14), V3(0, 2, -24), false, true)
cam(11, V3(-56, 30.5, 70), V3(0, 2, -12), false, true)
cam(12, V3(20, 30.5, 96), V3(0, 2, 8), false, true)
-- pórtico, mirando a lo largo de la alfombra
cam(13, V3(0, 25.6, GZ + 1), V3(0, 2, -18), false, true)
-- a ras de valla, contrapicado (sirve en todos los escenarios)
cam(14, V3(-11.2, 3.9, -80), V3(0, 3.4, -55), true, false)
cam(15, V3(11.2, 3.9, 8), V3(0, 3.4, -18), true, false)
task.wait()

-- escenarios cerrados o sin suelo: sin lo de fuera
for _, id in ipairs({ "museo", "pasarela", "espacio" }) do ENVS[id]:SetAttribute("NoExtras", true) end

-- muros y edificios grandes tapan la vista de las cámaras de seguridad
local n = 0
for _, env in ipairs(ENVS:GetChildren()) do
	for _, d in ipairs(env:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "SueloVisual" and d.Transparency < 0.5 then
			local s = d.Size
			if math.max(s.X, s.Y, s.Z) > 14 and d.Size.Y > 8 and d.Position.Y > 3 then d.CanQuery = true n += 1 end
		end
	end
	task.wait()
end
local names = {}
for _, c in ipairs(cctv:GetChildren()) do table.insert(names, c.Name) end
return { extras = #X:GetDescendants(), cctv = names, muros = n }
