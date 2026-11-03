-- Paparazzi: figuras de bloques (sin Humanoid, baratas) con pelo real y cámara distinta; props de prensa; helicóptero y fotógrafos.
local rs = game:GetService("ReplicatedStorage")
local map = workspace.MapaActivo.RedCarpet
local crowd = Folder(map, "Paparazzi")
local gear = Folder(map, "Prensa")
local rnd = Random.new(21)
local SKIN = { rgb(255, 224, 189), rgb(244, 200, 160), rgb(224, 172, 128), rgb(190, 132, 92), rgb(140, 92, 62), rgb(92, 60, 42), rgb(255, 236, 214) }
local SUIT = { rgb(24, 24, 28), rgb(24, 24, 28), rgb(24, 24, 28), rgb(38, 38, 44), rgb(30, 34, 52), rgb(52, 48, 52), rgb(18, 18, 20) }
local HAIRS = {}
for _, h in ipairs(SS.RCAssets.Pelos:GetChildren()) do if h.Size.Magnitude < 3.7 then table.insert(HAIRS, h) end end

local function tagLens(p) CS:AddTag(p, "RCFlash") end
-- cámaras: `cf` en el centro del cuerpo, mirando a -Z (el frente)
local CAMS = {}
function CAMS.reflex(g, cf)
	P(g, "Cuerpo", V3(1.55, 1, 0.75), cf, rgb(22, 22, 24))
	P(g, "Visor", V3(0.65, 0.36, 0.55), cf * CF(0, 0.66, 0), rgb(32, 32, 36))
	P(g, "Empuñadura", V3(0.42, 0.95, 0.9), cf * CF(0.64, -0.02, -0.08), rgb(14, 14, 16))
	Bar(g, "Objetivo", (cf * CF(0, -0.02, -0.3)).Position, (cf * CF(0, -0.02, -1.05)).Position, 0.86, rgb(26, 26, 30), M.Metal)
	Bar(g, "Aro", (cf * CF(0, -0.02, -0.72)).Position, (cf * CF(0, -0.02, -0.82)).Position, 0.92, rgb(200, 40, 40), M.Metal)
	Bar(g, "Cristal", (cf * CF(0, -0.02, -1.05)).Position, (cf * CF(0, -0.02, -1.1)).Position, 0.62, rgb(90, 130, 200), M.Glass)
	P(g, "BaseFlash", V3(0.46, 0.4, 0.36), cf * CF(0, 1.02, 0), rgb(18, 18, 20))
	P(g, "CabezaFlash", V3(0.86, 0.56, 0.5), cf * CF(0, 1.46, -0.08), rgb(26, 26, 28))
	tagLens(P(g, "Flash", V3(0.76, 0.46, 0.05), cf * CF(0, 1.46, -0.35), rgb(255, 250, 225), M.Neon))
end
function CAMS.tele(g, cf)
	P(g, "Cuerpo", V3(1.45, 1, 0.75), cf, rgb(26, 26, 28))
	P(g, "Visor", V3(0.6, 0.36, 0.5), cf * CF(0, 0.66, 0), rgb(32, 32, 36))
	Bar(g, "Objetivo", (cf * CF(0, 0, -0.3)).Position, (cf * CF(0, 0, -2.3)).Position, 0.92, rgb(232, 230, 222), M.SmoothPlastic)
	Bar(g, "Parasol", (cf * CF(0, 0, -2.2)).Position, (cf * CF(0, 0, -2.75)).Position, 1.12, rgb(30, 30, 32))
	Bar(g, "Aro", (cf * CF(0, 0, -1.1)).Position, (cf * CF(0, 0, -1.28)).Position, 1, rgb(200, 40, 40), M.Metal)
	tagLens(P(g, "Flash", V3(0.72, 0.42, 0.05), cf * CF(0, 1.06, -0.3), rgb(255, 250, 225), M.Neon))
	P(g, "CabezaFlash", V3(0.82, 0.5, 0.44), cf * CF(0, 1.06, -0.06), rgb(24, 24, 26))
end
function CAMS.compacta(g, cf)
	P(g, "Cuerpo", V3(1.5, 0.92, 0.5), cf, rgb(205, 208, 214), M.Metal)
	P(g, "Tapa", V3(1.5, 0.12, 0.5), cf * CF(0, 0.5, 0), rgb(30, 30, 34))
	Bar(g, "Objetivo", (cf * CF(0.1, -0.05, -0.2)).Position, (cf * CF(0.1, -0.05, -0.68)).Position, 0.72, rgb(30, 30, 34), M.Metal)
	Bar(g, "Cristal", (cf * CF(0.1, -0.05, -0.68)).Position, (cf * CF(0.1, -0.05, -0.72)).Position, 0.5, rgb(90, 130, 200), M.Glass)
	tagLens(P(g, "Flash", V3(0.4, 0.22, 0.04), cf * CF(-0.48, 0.28, -0.27), rgb(255, 250, 225), M.Neon))
end
function CAMS.movil(g, cf)
	P(g, "Movil", V3(0.82, 1.55, 0.1), cf, rgb(18, 18, 22))
	P(g, "Pantalla", V3(0.72, 1.42, 0.02), cf * CF(0, 0, 0.06), rgb(150, 210, 255), M.Neon)
	Ball(g, "Lente", 0.17, (cf * CF(-0.22, 0.56, -0.06)).Position, rgb(50, 60, 80), M.Glass)
	tagLens(Ball(g, "Flash", 0.13, (cf * CF(0.0, 0.56, -0.06)).Position, rgb(255, 250, 225), M.Neon))
end
function CAMS.hombro(g, cf) -- de televisión, al hombro
	P(g, "Cuerpo", V3(1.15, 1.3, 3), cf, rgb(32, 32, 36))
	P(g, "Asa", V3(0.2, 0.5, 1.8), cf * CF(0, 0.95, 0), rgb(16, 16, 18))
	P(g, "Visor", V3(0.55, 0.42, 0.9), cf * CF(-0.75, 0.32, 0.4), rgb(20, 20, 22))
	Bar(g, "Objetivo", (cf * CF(0, 0, -1.4)).Position, (cf * CF(0, 0, -2.4)).Position, 1.02, rgb(22, 22, 26), M.Metal)
	Bar(g, "Parasol", (cf * CF(0, 0, -2.3)).Position, (cf * CF(0, 0, -2.75)).Position, 1.28, rgb(16, 16, 18))
	Ball(g, "Rec", 0.2, (cf * CF(0.58, 0.45, -1)).Position, rgb(255, 30, 30), M.Neon)
	tagLens(P(g, "Flash", V3(0.86, 0.5, 0.05), cf * CF(0, 1.32, -0.75), rgb(255, 250, 225), M.Neon))
	P(g, "Luz", V3(0.96, 0.6, 0.4), cf * CF(0, 1.32, -0.5), rgb(22, 22, 24))
end
local KINDS = { "reflex", "reflex", "reflex", "tele", "compacta", "movil", "movil", "hombro" }

local function figure(parent, base, o) -- base = CFrame en los pies mirando a -Z
	local g = Instance.new("Model")
	g.Name = "Paparazzo"
	local skin, suit = o.skin, o.suit
	local at = function(x, y, z) return base * CF(x, y, z) end
	P(g, "PiernaI", V3(0.98, 2, 1), at(-0.5, 1, 0), suit)
	P(g, "PiernaD", V3(0.98, 2, 1), at(0.5, 1, 0), suit)
	P(g, "Torso", V3(2, 2, 1), at(0, 3, 0), suit)
	local head = P(g, "Cabeza", V3(2, 1, 1), at(0, 4.5, 0) , skin, M.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType, mesh.Scale = Enum.MeshType.Head, V3(1.25, 1.25, 1.25)
	mesh.Parent = head
	if o.detail then
		P(g, "Camisa", V3(0.72, 1.45, 0.04), at(0, 3.27, -0.52), rgb(245, 245, 245))
		P(g, "Pajarita", V3(0.6, 0.2, 0.06), at(0, 3.86, -0.55), suit)
		P(g, "ZapatoI", V3(1, 0.34, 1.32), at(-0.5, 0.17, -0.14), rgb(10, 10, 12))
		P(g, "ZapatoD", V3(1, 0.34, 1.32), at(0.5, 0.17, -0.14), rgb(10, 10, 12))
		local face = Instance.new("Decal")
		face.Texture, face.Face = "rbxasset://textures/face.png", Enum.NormalId.Front
		face.Parent = head
	end
	if o.hair then
		local h = o.hair:Clone()
		h.CFrame = head.CFrame * h:GetAttribute("Off")
		h.Parent = g
	end
	local function arm(side, hand)
		local sh = at(side * 1.45, 3.75, 0)
		local dir = (hand.Position - sh.Position)
		local len = dir.Magnitude
		P(g, side < 0 and "BrazoI" or "BrazoD", V3(0.95, 0.95, len), CF(sh.Position + dir / 2, hand.Position), suit)
		P(g, "Mano", V3(0.82, 0.82, 0.82), hand, skin)
	end
	local k = o.kind
	if k == "movil" then
		arm(1, at(0.45, 4.7, -2.15))
		P(g, "BrazoI", V3(1, 2, 1), at(-1.5, 3, 0), suit)
		CAMS.movil(g, at(0.45, 5.15, -2.35))
	elseif k == "hombro" then
		arm(1, at(1.3, 4.1, -1.5))
		arm(-1, at(0.55, 3.75, -2.1))
		CAMS.hombro(g, at(1.15, 4.95, -0.65))
	elseif k == "tele" then
		arm(1, at(0.8, 4.3, -1.65))
		arm(-1, at(-0.05, 3.9, -2.6))
		CAMS.tele(g, at(0.1, 4.6, -1.6))
	else
		arm(1, at(0.95, 4.42, -1.7))
		arm(-1, at(-0.95, 4.42, -1.7))
		CAMS[k](g, at(0, 4.62, -1.75))
	end
	CS:AddTag(g, "RCFig")
	g.PrimaryPart = g.Torso
	g.Parent = parent
	return g
end

local ROWS = { { x = 12.7, dz = 3.15, y = 0, detail = true }, { x = 15.5, dz = 3.15, y = 0.25, detail = true }, { x = 18.3, dz = 4.2, y = 0.5 }, { x = 21, dz = 5.2, y = 0.8 } }
local count = 0
for ri, row in ipairs(ROWS) do
	for _, side in ipairs({ -1, 1 }) do
		local holder = Instance.new("Folder")
		holder.Name = "Fila" .. ri .. (side < 0 and "I" or "D")
		local z = -94 + (ri % 2) * 1.5
		while z < 48 do
			-- los espacios para los equipos grandes de prensa
			local x = side * (row.x + rnd:NextNumber(-0.35, 0.35))
			local pos = V3(x, row.y, z + rnd:NextNumber(-0.3, 0.3))
			local aim = V3(rnd:NextNumber(-4, 4), row.y, z + rnd:NextNumber(-9, 9) - 3)
			figure(holder, CF(pos, aim), {
				skin = SKIN[rnd:NextInteger(1, #SKIN)], suit = SUIT[rnd:NextInteger(1, #SUIT)],
				hair = HAIRS[rnd:NextInteger(1, #HAIRS)], kind = KINDS[rnd:NextInteger(1, #KINDS)], detail = row.detail,
			})
			count += 1
			z += row.dz
		end
		holder.Parent = crowd
		task.wait()
	end
end

-- ---------- equipos de prensa (cine / TV / luces) ----------
local function tripod(g, pos, h)
	local top = pos + V3(0, h, 0)
	for i = 0, 2 do
		local a = i * PI * 2 / 3
		Bar(g, "Pata", top, pos + V3(math.cos(a) * 1.4, 0.05, math.sin(a) * 1.4), 0.17, rgb(30, 30, 34), M.Metal)
	end
	Cyl(g, "Rotula", 0.4, 0.8, top + V3(0, 0.1, 0), rgb(24, 24, 26), M.Metal)
	return top + V3(0, 0.3, 0)
end
local function look(pos, side) -- mirando a la alfombra un poco hacia el fondo
	return CF(pos, V3(0, pos.Y - 0.5, pos.Z - 9))
end
local function tvCam(side, z)
	local g = Group(gear, "CamaraTV")
	local x = side * 11.1
	local top = tripod(g, V3(x, 0, z), 3.6)
	local cf = look(top + V3(0, 0.8, 0))
	P(g, "Cuerpo", V3(1.5, 1.5, 3.5), cf, rgb(36, 36, 40))
	P(g, "Visor", V3(1.2, 0.9, 0.9), cf * CF(0, 1.05, 0.6), rgb(20, 20, 24))
	P(g, "Monitor", V3(1.05, 0.72, 0.05), cf * CF(0, 1.05, 1.08), rgb(120, 190, 255), M.Neon)
	Bar(g, "Objetivo", (cf * CF(0, 0, -1.7)).Position, (cf * CF(0, 0, -3)).Position, 1.15, rgb(22, 22, 26), M.Metal)
	Bar(g, "Parasol", (cf * CF(0, 0, -2.9)).Position, (cf * CF(0, 0, -3.5)).Position, 1.5, rgb(14, 14, 16))
	P(g, "Luz", V3(0.5, 0.5, 0.2), cf * CF(0.1, 1.1, -0.8), rgb(255, 36, 36), M.Neon)
	Bar(g, "Mango", (cf * CF(0.7, -0.6, 1)).Position, (cf * CF(1.3, -0.9, 2.6)).Position, 0.14, rgb(20, 20, 22), M.Metal)
	task.wait()
end
local function filmCam(side, z)
	local g = Group(gear, "CamaraCine")
	local x = side * 11.1
	local top = tripod(g, V3(x, 0, z), 3.4)
	local cf = look(top + V3(0, 0.9, 0))
	P(g, "Cuerpo", V3(1.4, 1.6, 2.4), cf, rgb(28, 28, 30), M.Metal)
	for _, zz in ipairs({ -0.6, 0.95 }) do
		local r = (cf * CF(0, 1.65, zz))
		P(g, "Bobina", V3(0.42, 1.8, 1.8), r * Ang(0, 0, 0), rgb(32, 32, 34), M.Metal, { Shape = Enum.PartType.Cylinder })
		P(g, "Centro", V3(0.5, 0.55, 0.55), r, rgb(230, 190, 90), M.Metal, { Shape = Enum.PartType.Cylinder })
	end
	Bar(g, "Objetivo", (cf * CF(0, 0, -1.1)).Position, (cf * CF(0, 0, -2.1)).Position, 0.85, rgb(20, 20, 22), M.Metal)
	task.wait()
end
local function softbox(side, z)
	local g = Group(gear, "Luz")
	local x = side * 11.2
	local top = tripod(g, V3(x, 0, z), 7.4)
	local cf = look(top + V3(0, 0.7, 0))
	P(g, "Caja", V3(3, 3, 1.1), cf, rgb(22, 22, 24))
	local f = P(g, "Difusor", V3(2.7, 2.7, 0.05), cf * CF(0, 0, -0.56), rgb(255, 246, 225), M.Neon)
	Light(f, 16, 1.4, rgb(255, 240, 210))
end
local function ring(side, z)
	local g = Group(gear, "Aro")
	local x = side * 11.2
	local top = tripod(g, V3(x, 0, z), 4.8)
	local c = top + V3(0, 1.4, 0)
	local cf = look(c)
	for i = 0, 15 do
		local a = i * PI / 8
		P(g, "Led", V3(0.56, 0.2, 0.14), cf * CF(math.cos(a) * 1.25, math.sin(a) * 1.25, 0) * Ang(0, 0, a + PI / 2), rgb(255, 244, 225), M.Neon)
	end
	P(g, "Movil", V3(0.5, 0.95, 0.08), cf, rgb(14, 14, 18))
end
local function boom(side, z)
	local g = Group(gear, "Micro")
	local x = side * 11.1
	local top = tripod(g, V3(x, 0, z), 3.6)
	local tip = V3(side * 6, 7, z - 2)
	Bar(g, "Pertiga", top + V3(side * 1.2, -0.6, 0.3), tip, 0.16, rgb(40, 40, 44), M.Metal)
	local cf = CF(tip, tip + V3(-side, -0.5, -0.2))
	Bar(g, "Pelo", (cf * CF(0, 0, 0.9)).Position, (cf * CF(0, 0, -1.2)).Position, 0.72, rgb(92, 92, 96), M.Fabric)
end
local function jib(side, z)
	local g = Group(gear, "Grua")
	local base = V3(side * 26, 0, z)
	Cyl(g, "Base", 1, 5, base + V3(0, 0.5, 0), rgb(26, 26, 30), M.Metal)
	Cyl(g, "Columna", 9, 1.3, base + V3(0, 5, 0), rgb(40, 40, 46), M.Metal)
	local pivot = base + V3(0, 9.6, 0)
	local tip = V3(side * 9, 16, z - 4)
	local back = pivot + (pivot - tip).Unit * 8
	for _, dy in ipairs({ -0.35, 0.35 }) do
		Bar(g, "Brazo", back + V3(0, dy, 0), tip + V3(0, dy, 0), 0.25, rgb(190, 192, 198), M.Metal)
	end
	for i = 1, 14 do
		local p = back:Lerp(tip, i / 15)
		P(g, "Tirante", V3(0.12, 0.8, 0.12), CF(p), rgb(160, 162, 168), M.Metal)
	end
	P(g, "Contrapeso", V3(2, 2.2, 2), CF(back), rgb(20, 20, 22), M.Metal)
	local cf = CF(tip + V3(0, -1.3, 0), V3(0, 2, z - 12))
	P(g, "Soporte", V3(0.3, 1.3, 0.3), CF(tip + V3(0, -0.6, 0)), rgb(30, 30, 34), M.Metal)
	P(g, "Cuerpo", V3(1.3, 1.4, 2.8), cf, rgb(32, 32, 36))
	Bar(g, "Objetivo", (cf * CF(0, 0, -1.4)).Position, (cf * CF(0, 0, -2.6)).Position, 1, rgb(18, 18, 22), M.Metal)
	Ball(g, "Rec", 0.22, (cf * CF(0.5, 0.75, -0.9)).Position, rgb(255, 30, 30), M.Neon)
end
tvCam(-1, -72) filmCam(1, -66) softbox(-1, -60) tvCam(1, -50) ring(-1, -42) boom(1, -36) filmCam(-1, -24)
softbox(1, -18) tvCam(-1, -6) ring(1, 2) boom(-1, 12) tvCam(1, 18)
jib(-1, -46) jib(1, -14)

-- ---------- modelos que usan los scripts (ReplicatedStorage.RCModels) ----------
local models = Folder(rs, "RCModels")
-- helicóptero
local heli = Group(models, "Helicoptero")
local hc = CF(0, 0, 0)
local body = Ball(heli, "Cuerpo", 1, Vector3.zero, rgb(25, 30, 40), M.SmoothPlastic)
body.Size = V3(6, 6, 11)
P(heli, "Cristal", V3(4.6, 3.2, 3.8), hc * CF(0, 0.6, -3.9), rgb(120, 170, 220), M.Glass, { Transparency = 0.35 })
P(heli, "Cola", V3(1.2, 1.2, 12), hc * CF(0, 0.8, 10), rgb(25, 30, 40))
P(heli, "Aleta", V3(0.3, 4, 2.2), hc * CF(0, 2.4, 15.6), rgb(190, 30, 40))
P(heli, "RotorCola", V3(0.2, 4.6, 0.5), hc * CF(0.5, 1.2, 15.6), rgb(16, 16, 18), M.Metal)
P(heli, "Eje", V3(0.7, 1.8, 0.7), hc * CF(0, 3.4, 0), rgb(30, 30, 34), M.Metal)
local rotor = Group(heli, "Rotor")
P(rotor, "Pala", V3(26, 0.14, 1), hc * CF(0, 4.3, 0), rgb(16, 16, 18), M.Metal)
P(rotor, "Pala", V3(1, 0.14, 26), hc * CF(0, 4.3, 0), rgb(16, 16, 18), M.Metal)
for _, s in ipairs({ -1, 1 }) do
	P(heli, "Patin", V3(0.4, 0.4, 11), hc * CF(s * 2.8, -3.8, 0), rgb(40, 40, 46), M.Metal)
	P(heli, "Tirante", V3(0.3, 1.2, 0.3), hc * CF(s * 2.6, -3.3, -3), rgb(40, 40, 46), M.Metal)
	P(heli, "Tirante", V3(0.3, 1.2, 0.3), hc * CF(s * 2.6, -3.3, 3), rgb(40, 40, 46), M.Metal)
end
Ball(heli, "Camara", 1.5, (hc * CF(0, -3, -3.5)).Position, rgb(14, 14, 18), M.Metal)
local beacon = Ball(heli, "Faro", 0.5, (hc * CF(0, -3.7, -3.9)).Position, rgb(255, 250, 220), M.Neon)
heli.PrimaryPart = body
-- fotógrafos de la sesión de fotos (varios)
local shooters = Folder(models, "Fotografos")
for i, kind in ipairs({ "reflex", "tele", "reflex", "compacta", "hombro", "movil", "reflex", "tele" }) do
	local f = figure(shooters, CF(0, 0, 0), { skin = SKIN[(i * 3) % #SKIN + 1], suit = SUIT[i % #SUIT + 1], hair = HAIRS[(i * 7) % #HAIRS + 1], kind = kind, detail = true })
	f.Name = "Fotografo" .. i
	CS:RemoveTag(f, "RCFig")
end
print("paparazzi", count, "partes", #crowd:GetDescendants(), "prensa", #gear:GetDescendants())
return count .. " figuras, " .. #crowd:GetDescendants() .. " partes"
