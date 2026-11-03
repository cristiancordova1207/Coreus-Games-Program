-- Menos cámaras, suelo de color y vallas elegibles
local map = workspace.MapaActivo.RedCarpet

-- ---------- quitar 2/3 de las cámaras (repartido: delante quedan más) ----------
local KEEP = { Fila1 = 2, Fila2 = 3, Fila3 = 4, Fila4 = 6 }
local total = 0
for _, row in ipairs(map.Paparazzi:GetChildren()) do
	local every = KEEP[row.Name:sub(1, 5)]
	if every then
		local list = row:GetChildren()
		table.sort(list, function(a, b) return a:GetPivot().Position.Z < b:GetPivot().Position.Z end)
		for i, f in ipairs(list) do
			if i % every ~= 0 then f:Destroy() else total += 1 end
		end
		task.wait()
	end
end
local keepPress = { ["CamaraTV -11,-6"] = true, ["CamaraCine 11,-66"] = true, ["Grua -20,-47"] = true, ["Luz 11,-18"] = true, ["Aro -11,-42"] = true }
for _, c in ipairs(map.Prensa:GetChildren()) do
	local p = c:GetPivot().Position
	if not keepPress[string.format("%s %.0f,%.0f", c.Name, p.X, p.Z)] then c:Destroy() end
end

-- ---------- suelo de color: una sola pieza que tapa el del escenario ----------
local old = map:FindFirstChild("SueloColor")
if old then old:Destroy() end
P(map, "SueloColor", V3(620, 0.2, 620), CF(0, -0.12, -20), WHITE, M.SmoothPlastic, { Transparency = 1 })

-- ---------- quitar las vallas sueltas de cada escenario ----------
local ENVS = SS.EscenariosRC
local NAMES = { Poste = 1, Cuerda = 1, Panel = 1, Riel = 1, Led = 1, LedArriba = 1, LedAbajo = 1, Vidrio = 1, Base = 1, Jardinera = 1, Tira = 1, Hoja = 1 }
local gone = {}
for _, env in ipairs(ENVS:GetChildren()) do
	local n = 0
	for _, d in ipairs(env:GetChildren()) do
		if NAMES[d.Name] then
			local p = d:IsA("Model") and d:GetPivot().Position or d.Position
			if math.abs(p.X) > 8.3 and math.abs(p.X) < 11 and p.Z > -97 and p.Z < 54 then d:Destroy() n += 1 end
		end
	end
	gone[env.Name] = n
	task.wait()
end
local DEFAULTS = { minimal = "metal", museo = "cuerda", cine = "cuerda", pasarela = "cinta", espacio = "cristal", vegas = "evento", jardin = "seto", ciudad = "neon" }
for id, v in pairs(DEFAULTS) do
	local e = ENVS:FindFirstChild(id)
	if e then e:SetAttribute("Valla", v) end
end

-- ---------- estilos de valla ----------
-- vallas de seguridad de metal, las de los eventos de verdad
local function MetalLine(parent, metal)
	local step = BARRIER_STEP / 2
	for _, side in ipairs({ -1, 1 }) do
		local z = BARRIER_Z0
		while z + step <= BARRIER_Z1 + 0.1 do
			local a = V3(side * BARRIER_X, 0, z + 0.12)
			local b = V3(side * BARRIER_X, 0, z + step - 0.12)
			Bar(parent, "Riel", a + V3(0, 3.5, 0), b + V3(0, 3.5, 0), 0.26, metal, M.Metal)
			Bar(parent, "Riel", a + V3(0, 0.75, 0), b + V3(0, 0.75, 0), 0.26, metal, M.Metal)
			for _, e in ipairs({ a, b }) do
				Bar(parent, "Marco", e + V3(0, 0.3, 0), e + V3(0, 3.6, 0), 0.26, metal, M.Metal)
				P(parent, "Pie", V3(2.3, 0.14, 0.26), CF(e + V3(0, 0.1, 0)), metal, M.Metal)
			end
			for i = 1, 5 do
				local q = a:Lerp(b, i / 6)
				Bar(parent, "Barra", q + V3(0, 0.75, 0), q + V3(0, 3.5, 0), 0.13, metal, M.Metal)
			end
			z += step
		end
		task.wait()
	end
end
-- postes con cinta retráctil
local function BeltLine(parent, metal, belt)
	for _, side in ipairs({ -1, 1 }) do
		local z, last = BARRIER_Z0, nil
		while z <= BARRIER_Z1 do
			local pos = V3(side * BARRIER_X, 0, z)
			Stanchion(parent, pos, metal, metal)
			if last then
				local len = (pos - last).Magnitude
				P(parent, "Cinta", V3(0.05, 0.5, len), CF((pos + last) / 2 + V3(0, 3.0, 0)), belt, M.Fabric)
			end
			last = pos
			z += BARRIER_STEP
		end
		task.wait()
	end
end

local V = Folder(SS, "VallasRC")
local function make(id, fn)
	local g = Group(V, id)
	fn(g)
	task.wait()
end
make("metal", function(g) MetalLine(g, rgb(176, 180, 188)) end)
make("cuerda", function(g) RopeLine(g, GOLD, GOLDD, RED, GOLD) end)
make("evento", function(g) PanelLine(g, GOLD, rgb(22, 22, 26), GOLD) end)
make("cristal", function(g) GlassLine(g, rgb(150, 220, 255), STEEL) end)
make("neon", function(g) GlassLine(g, rgb(255, 60, 180), rgb(40, 40, 48)) end)
make("seto", function(g) HedgeLine(g, WHITE, rgb(60, 150, 50), CREAM) end)
make("cinta", function(g) BeltLine(g, rgb(30, 30, 34), rgb(170, 14, 26)) end)

local counts = {}
for _, m in ipairs(V:GetChildren()) do counts[m.Name] = #m:GetDescendants() end
local press = {}
for _, c in ipairs(map.Prensa:GetChildren()) do table.insert(press, c.Name) end
return { paparazzi = total, prensa = press, quitado = gone, vallas = counts, minimalSuelo = tostring(ENVS.minimal.SueloVisual.Color) }
