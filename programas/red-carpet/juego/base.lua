-- Mapa común: suelo de colisión, alfombra, marcas, puntos del recorrido, cámaras de seguridad, pantalla.
-- La pasarela de Fashion se guarda en ServerStorage (no se borra).
local mapa = workspace.MapaActivo
local old = mapa:FindFirstChild("Pasarela")
if old then
	local keep = SS:FindFirstChild("PasarelaFashion")
	if keep then keep:Destroy() end
	old.Name = "PasarelaFashion"
	old.Parent = SS
end
local prev = mapa:FindFirstChild("RedCarpet")
if prev then prev:Destroy() end
local map = Group(mapa, "RedCarpet")

local floor = P(map, "Suelo", V3(500, 2, 500), CF(0, -1, -30), WHITE, M.SmoothPlastic, { Transparency = 1, CanCollide = true, CanQuery = true })
local Z0, Z1 = -104, 62
local mid, len = (Z0 + Z1) / 2, Z1 - Z0
P(map, "Alfombra", V3(17, 0.2, len), CF(0, -0.07, mid), rgb(172, 10, 22), M.Fabric)
for _, s in ipairs({ -1, 1 }) do
	P(map, "Borde", V3(0.5, 0.22, len), CF(s * 8.55, -0.07, mid), rgb(112, 6, 14), M.Fabric)
end
-- rectángulos de luz (los cuadrados amarillos del boceto), de donde salen hasta la cámara
local marks = Group(map, "Marcas")
local W, H = 8.4, 7.4
for i = 0, 8 do
	local z = -88 + i * 14
	local c = rgb(255, 196, 120)
	P(marks, "Linea", V3(W, 0.03, 0.32), CF(0, 0.05, z - H / 2), c, M.Neon)
	P(marks, "Linea", V3(W, 0.03, 0.32), CF(0, 0.05, z + H / 2), c, M.Neon)
	P(marks, "Linea", V3(0.32, 0.03, H), CF(-W / 2, 0.05, z), c, M.Neon)
	P(marks, "Linea", V3(0.32, 0.03, H), CF(W / 2, 0.05, z), c, M.Neon)
end
-- recorrido
Marker(map, "EntradaI", V3(-21, 0, -108))
Marker(map, "EntradaD", V3(21, 0, -108))
Marker(map, "P1", V3(0, 0, -92))
Marker(map, "P2", V3(0, 0, -6))
Marker(map, "Salida", V3(0, 0, 50))
Marker(map, "Gigante", V3(0, 0, -36))
Marker(map, "Camara", V3(-13.5, 8.2, 31))
Marker(map, "MiraCamara", V3(3.5, 2.2, -26))

-- pantalla (texto / web), encima del arco
local screen = P(map, "Pantalla", V3(30, 7.5, 0.4), CF(0, 37.5, -105), rgb(255, 225, 160), M.SmoothPlastic)
local marco = Group(map, "MarcoPantalla")
P(marco, "Marco", V3(31, 8.5, 0.3), CF(0, 37.5, -105.3), rgb(24, 22, 26), M.Metal)
for _, s in ipairs({ -1, 1 }) do P(marco, "Soporte", V3(0.6, 6, 0.6), CF(s * 12, 31, -105.2), rgb(40, 40, 46), M.Metal) end
Light(screen, 30, 0.6, CREAM, "SurfaceLight").Face = Enum.NormalId.Front
screen.SurfaceLight.Name = "SurfaceLight"
local gui = Instance.new("SurfaceGui")
gui.Name, gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = "Texto", Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 34, 0
gui.Parent = screen
local name = Instance.new("TextLabel")
name.Name, name.BackgroundTransparency, name.TextScaled, name.Text = "Nombre", 1, true, ""
name.AnchorPoint, name.Position, name.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.72), UDim2.fromScale(0.92, 0.4)
name.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
name.TextColor3 = rgb(50, 18, 18)
name.Parent = gui

-- cámaras de seguridad: postes y domos reales; las tomas CCTV salen desde el marcador "Ojo" de cada una
local cctv = Group(map, "Seguridad")
local function bullet(i, base, h, aim)
	local g = Group(cctv, "CCTV" .. i)
	Cyl(g, "Poste", h, 0.7, base + V3(0, h / 2, 0), rgb(46, 48, 54), M.Metal)
	local top = base + V3(0, h, 0)
	local dir = CF(top, aim)
	P(g, "Brazo", V3(0.4, 0.4, 1.8), dir * CF(0, 0, -0.9), rgb(210, 212, 216), M.Metal)
	P(g, "Cuerpo", V3(1.5, 1.4, 3.4), dir * CF(0, 0.2, -2.6), rgb(232, 232, 236), M.SmoothPlastic)
	P(g, "Visera", V3(1.7, 0.16, 3.8), dir * CF(0, 1.0, -2.7), rgb(190, 192, 198), M.SmoothPlastic)
	Cyl(g, "Lente", 0.3, 1, Vector3.zero, rgb(14, 14, 18), M.Glass).CFrame = dir * CF(0, 0.2, -4.42) * Ang(0, PI / 2, 0)
	local led = Ball(g, "Rec", 0.2, (dir * CF(0.5, -0.32, -4.25)).Position, rgb(255, 40, 40), M.Neon)
	led.Name = "Rec"
	local ojo = Marker(g, "Ojo", (dir * CF(0, 0.2, -4.8)).Position)
	ojo:SetAttribute("Num", i)
	return g
end
bullet(1, V3(-26, 0, -60), 15, V3(0, 2, -35))
bullet(2, V3(26, 0, -28), 15, V3(0, 2, -48))
bullet(3, V3(-26, 0, 8), 15, V3(0, 2, -22))
bullet(4, V3(26, 0, 22), 15, V3(0, 2, -8))
bullet(5, V3(-26, 0, -86), 17, V3(0, 2, -70))

-- estado por escenario
map:SetAttribute("Version", 1)
print("base ok", #map:GetDescendants())
