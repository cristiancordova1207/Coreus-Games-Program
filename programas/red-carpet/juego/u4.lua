-- Sala de fotos aparte, sin vallas, modo noche del Minimalista, rotación de escenarios con checks, cambio con flash, bots con su @
local H = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local SSS, RS = game.ServerScriptService, game.ReplicatedStorage
local mapa = workspace.MapaActivo
local map = mapa.RedCarpet
local function sub(script, old, new)
	local s = script.Source
	local i, j = s:find(old, 1, true)
	assert(i, "no encontrado: " .. old:sub(1, 50))
	script.Source = s:sub(1, i - 1) .. new .. s:sub(j + 1)
end
local function cut(script, from, to) -- quita desde `from` hasta justo antes de `to`
	local s = script.Source
	local i = s:find(from, 1, true)
	assert(i, "no encontrado: " .. from:sub(1, 50))
	local j = s:find(to, i, true)
	assert(j, "no encontrado: " .. to:sub(1, 50))
	script.Source = s:sub(1, i - 1) .. s:sub(j)
end

-- ---------- sala de fotos, lejos del mapa ----------
local old = mapa:FindFirstChild("EstudioFotos")
if old then old:Destroy() end
local oldF = workspace:FindFirstChild("SesionFotos")
if oldF then oldF:Destroy() end
local room = Instance.new("Model")
room.Name = "EstudioFotos"
local O = Vector3.new(600, 0, 0)
local function P(name, size, pos, color, mat, props)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, CFrame.new(O + pos), color, mat or Enum.Material.SmoothPlastic
	p.Anchored, p.TopSurface, p.BottomSurface, p.CastShadow = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth, false
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = room
	return p
end
local rgb = Color3.fromRGB
local WALL, FLOOR, RED, GOLD = rgb(24, 20, 34), rgb(32, 28, 42), rgb(165, 10, 20), rgb(255, 205, 110)
P("Suelo", Vector3.new(60, 1, 50), Vector3.new(0, -0.5, 12), FLOOR)
P("Techo", Vector3.new(60, 1, 50), Vector3.new(0, 20.5, 12), WALL)
P("Pared", Vector3.new(1, 21, 50), Vector3.new(-30.5, 10, 12), WALL)
P("Pared", Vector3.new(1, 21, 50), Vector3.new(30.5, 10, 12), WALL)
P("Pared", Vector3.new(60, 21, 1), Vector3.new(0, 10, 37.5), WALL)
local fondo = P("Fondo", Vector3.new(60, 21, 1), Vector3.new(0, 10, -8.5), rgb(120, 8, 18), Enum.Material.Fabric)
local sg = Instance.new("SurfaceGui")
sg.Face, sg.SizingMode, sg.PixelsPerStud, sg.LightInfluence, sg.Parent = Enum.NormalId.Back, Enum.SurfaceGuiSizingMode.PixelsPerStud, 12, 1, fondo
local g = Instance.new("UIGridLayout")
g.CellSize, g.CellPadding, g.Parent = UDim2.fromScale(1 / 6, 1 / 7), UDim2.new(), sg
for i = 1, 42 do
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.Font, l.TextScaled, l.TextColor3, l.Text = 1, Enum.Font.GothamBlack, true, i % 2 == 0 and GOLD or rgb(255, 245, 235), i % 2 == 0 and "★ STAR" or "RED CARPET"
	l.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0), UDim.new(0.3, 0), UDim.new(0.3, 0)
	pad.Parent = l
end
local c = P("Alfombra", Vector3.new(0.2, 14, 14), Vector3.new(0, 0.05, 0), RED, Enum.Material.Fabric, { Shape = Enum.PartType.Cylinder })
c.CFrame = CFrame.new(O + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
local spot = P("Spot", Vector3.one, Vector3.zero, GOLD, nil, { Transparency = 1, CanCollide = false, CanQuery = false })
-- luces del techo
for _, x in ipairs({ -18, 0, 18 }) do
	for _, z in ipairs({ -2, 14, 30 }) do
		local t = P("Luz", Vector3.new(7, 0.3, 2.4), Vector3.new(x, 19.9, z), rgb(190, 186, 176), Enum.Material.Neon)
		local s = Instance.new("SpotLight")
		s.Face, s.Angle, s.Range, s.Brightness, s.Parent = Enum.NormalId.Bottom, 100, 30, 0.7, t
	end
end
for _, s in ipairs({ -1, 1 }) do
	P("Tira", Vector3.new(0.4, 18, 0.4), Vector3.new(s * 29.7, 10, -7.7), GOLD, Enum.Material.Neon)
	P("Tira", Vector3.new(0.4, 0.4, 45), Vector3.new(s * 29.7, 0.3, 14.5), GOLD, Enum.Material.Neon)
end
room.PrimaryPart = spot
room.Parent = mapa
task.wait()
-- fotógrafos en gradas, repartidos delante de él
local fold = Instance.new("Folder")
fold.Name = "SesionFotos"
local src = RS.RCModels.Fotografos:GetChildren()
local ROWS = { { r = 9, n = 9, y = 0 }, { r = 11.8, n = 11, y = 0.9 }, { r = 14.6, n = 13, y = 1.8 }, { r = 17.4, n = 15, y = 2.7 } }
local k, total = 0, 0
for ri, row in ipairs(ROWS) do
	for i = 1, row.n do
		k += 1
		local a = math.rad(-82 + (i - 1) * 164 / (row.n - 1))
		local pos = O + Vector3.new(math.sin(a) * row.r, row.y, math.cos(a) * row.r)
		local f = src[k % #src + 1]:Clone()
		f:SetAttribute("Fila", ri)
		f:PivotTo(CFrame.lookAt(pos, Vector3.new(O.X, row.y, O.Z)))
		local low = math.huge -- el pivote está en el torso: los pies, sobre la grada
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("BasePart") then low = math.min(low, d.Position.Y - d.Size.Y / 2) end
		end
		f:PivotTo(f:GetPivot() + Vector3.new(0, row.y - low, 0))
		if ri <= 3 then CS:AddTag(f, "RCFig") end -- la última fila no se anima: casi no se ve y cuesta menos
		f.Parent = fold
		total += 1
		if row.y > 0 then
			local b = Instance.new("Part")
			b.Name, b.Size, b.Anchored, b.Color, b.Material, b.CastShadow = "Grada", Vector3.new(3.4, row.y, 3), true, rgb(46, 40, 60), Enum.Material.SmoothPlastic, false
			b.CFrame = CFrame.lookAt(pos - Vector3.new(0, row.y / 2, 0), Vector3.new(O.X, row.y / 2, O.Z))
			b.Parent = room
		end
	end
	task.wait()
end
fold.Parent = workspace

-- ---------- la cámara principal, de cara a la alfombra: en vertical se ve entera ----------
map.Camara.Position = Vector3.new(0, 8, 37)
map.MiraCamara.Position = Vector3.new(0, 2.5, -32)

-- ---------- luces del modo noche ----------
for _, d in ipairs(map.Extras:GetDescendants()) do
	if d:IsA("Light") and d.Name == "LuzNoche" then d:Destroy() end
	if d:IsA("BasePart") and d.Name == "PuntoNoche" then d:Destroy() end
end
for _, d in ipairs(map.Extras:GetChildren()) do
	if d.Name == "Globo" then
		local l = Instance.new("PointLight")
		l.Name, l.Range, l.Brightness, l.Color, l.Enabled, l.Parent = "LuzNoche", 28, 0.5, rgb(255, 225, 180), false, d
	end
end
for z = -96, 48, 24 do
	local p = Instance.new("Part")
	p.Name, p.Size, p.Anchored, p.Transparency, p.CanCollide, p.CanQuery, p.CFrame = "PuntoNoche", Vector3.one, true, 1, false, false, CFrame.new(0, 26, z)
	local l = Instance.new("SpotLight")
	l.Name, l.Face, l.Angle, l.Range, l.Brightness, l.Enabled, l.Parent = "LuzNoche", Enum.NormalId.Bottom, 80, 32, 0.55, false, p
	p.Parent = map.Extras
end

-- ---------- Config ----------
local cfg = RS.TikAvatars.Config
sub(cfg, [[{ id = "seto", name = "Seto", emoji = "🌿" }, { id = "cinta", name = "Cinta", emoji = "🎀" },]], [[{ id = "seto", name = "Seto", emoji = "🌿" }, { id = "cinta", name = "Cinta", emoji = "🎀" }, { id = "ninguna", name = "Sin vallas", emoji = "🚫" },]])
sub(cfg, "C.MARKS = {", [[C.NIGHT = { { id = "dia", name = "De día", emoji = "☀️" }, { id = "noche", name = "De noche", emoji = "🌙" } }
C.ROT_TIMES = { 0, 1, 2, 5, 10 } -- minutos entre escenarios; 0 = no rotan
C.MARKS = {]])

-- ---------- RedCarpetShow ----------
local show = SSS.RedCarpetShow
-- sala de fotos
sub(show, "-- Quien regaló sale en medio de la alfombra, posa y los fotógrafos le rodean disparando. RedCarpetFx hace poses, flashes y\n-- el destello de pantalla; CameraController corta entre fotógrafos. Los que caminan se ocultan al pasar por su lado.",
	"-- Quien regaló sale en una sala aparte (MapaActivo.EstudioFotos), llena de fotógrafos que están siempre allí: en la alfombra no\n-- aparece nada. RedCarpetFx hace poses, flashes y el destello de pantalla; CameraController corta entre planos.")
sub(show, "local spot = Vector3.new(GIANT_SPOT.X, y, GIANT_SPOT.Z)\n\troot.CFrame = CFrame.lookAt(spot, spot + Vector3.zAxis)\n\twalkSeq += 1\n\tlocal id = \"p\"",
	"local studio = workspace.MapaActivo.EstudioFotos.Spot.Position\n\tlocal spot = Vector3.new(studio.X, y, studio.Z)\n\troot.CFrame = CFrame.lookAt(spot, spot + Vector3.zAxis)\n\twalkSeq += 1\n\tlocal id = \"p\"")
cut(show, "\t-- los fotógrafos, repartidos en un abanico delante de él", "\tworkspace:SetAttribute(\"PhotoCine\", id)\n\ttask.wait(seconds)")
sub(show, "\tsesion:ClearAllChildren()\n\tif bb then bb:Destroy() end", "\tif bb then bb:Destroy() end")
-- cielo reutilizable y modo noche
sub(show, [[	for _, s in ipairs(Lighting:GetChildren()) do if s:IsA("Sky") then s:Destroy() end end
	local skySrc = game:GetService("ServerStorage").Iluminacion:FindFirstChild(a("Sky") or "Wylo")
	local sky = skySrc and skySrc:FindFirstChildOfClass("Sky")
	if sky then
		local c = sky:Clone()
		if a("Stars") then c.StarCount, c.CelestialBodiesShown = 5000, false end
		c.Parent = Lighting
	end
]], [[	setSky(a("Sky") or "Wylo", a("Stars"))
]])
sub(show, [[local function applyFloor()]], [[local function setSky(name, stars)
	for _, s in ipairs(Lighting:GetChildren()) do if s:IsA("Sky") then s:Destroy() end end
	local skySrc = game:GetService("ServerStorage").Iluminacion:FindFirstChild(name)
	local sky = skySrc and skySrc:FindFirstChildOfClass("Sky")
	if sky then
		local c = sky:Clone()
		if stars then c.StarCount, c.CelestialBodiesShown = 5000, false end
		c.Parent = Lighting
	end
end
local function applyNight() -- solo el escenario principal tiene modo noche
	local a = function(k) return currentEnv:GetAttribute(k) end
	local night = workspace:GetAttribute("Noche") == "noche" and a("Id") == "minimal"
	if night or currentEnv:GetAttribute("Noche") then
		Lighting.ClockTime, Lighting.Brightness = night and 0 or a("ClockTime"), night and 0.9 or a("Brightness")
		Lighting.Ambient = night and Color3.fromRGB(78, 84, 118) or a("Ambient")
		Lighting.OutdoorAmbient = night and Color3.fromRGB(70, 76, 110) or a("OutdoorAmbient")
		Lighting.GlobalShadows, Lighting.ExposureCompensation = night or a("Shadows") == true, night and 0.1 or a("Exposure") or 0
		setSky(night and "Noche" or a("Sky") or "Wylo", night or a("Stars"))
		currentEnv:SetAttribute("Noche", night or nil)
	end
	for _, d in ipairs(extras:GetDescendants()) do
		if d:IsA("Light") and d.Name == "LuzNoche" then d.Enabled = night end
	end
end
local function applyFloor()]])
sub(show, "\tapplyFloor()\n\tapplyBarrier()\n\tapplyExtras()\nend", "\tapplyFloor()\n\tapplyBarrier()\n\tapplyExtras()\n\tapplyNight()\nend")
-- sin vallas
sub(show, [[	if id == "auto" then id = currentEnv:GetAttribute("Valla") or "cuerda" end
]], [[	if id == "auto" then id = currentEnv:GetAttribute("Valla") or "cuerda" end
	if id == "ninguna" then
		if currentValla then currentValla.Parent = VALLAS end
		currentValla = nil
		return
	end
]])
-- cambio de escenario con flash + rotación
sub(show, "applyStyle(workspace:GetAttribute(\"Estilo\") or DEFAULT_STYLE)\n", [[applyStyle(workspace:GetAttribute("Estilo") or DEFAULT_STYLE)
-- el mapa cambia con la pantalla en blanco (RedCarpetFx hace el flash)
local flashN = 0
local function changeStyle(name)
	local env = STYLES[name] or STYLES[DEFAULT_STYLE]
	if env == currentEnv then return end
	flashN += 1
	workspace:SetAttribute("StyleFlash", flashN)
	task.wait(0.3)
	applyStyle(name)
end
-- rotación: cada EnvEvery minutos pasa al siguiente con check (EnvOff = JSON {id = true} de los que no rotan)
local function rotOff()
	local ok, t = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), workspace:GetAttribute("EnvOff") or "{}")
	return ok and t or {}
end
_G.fsRot = function(id, every)
	local off = rotOff()
	if id then off[id] = not off[id] or nil end
	if tonumber(every) then workspace:SetAttribute("EnvEvery", tonumber(every)) end
	local list = {}
	for k in pairs(off) do table.insert(list, k) end
	workspace:SetAttribute("EnvOff", #list > 0 and game:GetService("HttpService"):JSONEncode(off) or "{}")
end
task.spawn(function()
	local Envs = require(game.ReplicatedStorage.TikAvatars.Config).ENVS
	local last = os.clock()
	while task.wait(1) do
		local every = workspace:GetAttribute("EnvEvery") or 0
		local due = every > 0 and os.clock() - last - every * 60
		if not due or due < 0 then
			if every <= 0 then last = os.clock() end
		else
			local a = function(k) return (workspace:GetAttribute(k) or "") ~= "" end
			-- no corta nada: espera al cinemático hasta 30 s; el gigante, las fotos, el baile y la fiesta los espera siempre
			if not (a("PhotoCine") or a("GiantCine") or a("MegaShow") or workspace:GetAttribute("Party") or (a("Cinematic") and due < 30)) then
				local off, list, cur = rotOff(), {}, workspace:GetAttribute("Estilo")
				for _, e in ipairs(Envs) do if not off[e.id] then table.insert(list, e.id) end end
				local at = table.find(list, cur) or 0
				local nxt = list[at % math.max(#list, 1) + 1]
				last = os.clock()
				if nxt and nxt ~= cur then changeStyle(nxt) end
			end
		end
	end
end)
]])
sub(show, "if s.menu or (s.style ~= programStyle and not (programStyle == nil and menuPicked)) then applyStyle(s.style) end", "if s.menu or (s.style ~= programStyle and not (programStyle == nil and menuPicked)) then task.spawn(changeStyle, s.style) end")
sub(show, "\t\t\tapplyStyle(partyStyle)", "\t\t\ttask.spawn(changeStyle, partyStyle)")
sub(show, [[if workspace:GetAttribute("Estilo") == partyStyle then applyStyle(partyPrev) end]], [[if workspace:GetAttribute("Estilo") == partyStyle then task.spawn(changeStyle, partyPrev) end]])
sub(show, [[	pick(s, "marks", "Cuadros", Cfg.MARKS, applyMarks)
]], [[	pick(s, "marks", "Cuadros", Cfg.MARKS, applyMarks)
	pick(s, "night", "Noche", Cfg.NIGHT, applyNight)
	if type(s.rot) == "table" then -- igual que pick: lo del programa no deshace lo elegido en el menú salvo que lo cambies allí
		local sig = game:GetService("HttpService"):JSONEncode(s.rot)
		if sig ~= fromProgram.rot and not (fromProgram.rot == nil and fromMenu.rot) then
			local off = {}
			for _, id in ipairs(type(s.rot.off) == "table" and s.rot.off or {}) do off[tostring(id)] = true end
			workspace:SetAttribute("EnvEvery", tonumber(s.rot.every) or 0)
			workspace:SetAttribute("EnvOff", next(off) and game:GetService("HttpService"):JSONEncode(off) or "{}")
		end
		fromProgram.rot = sig
	end
]])
sub(show, "_G.fsRot = function(id, every)\n", "_G.fsRot = function(id, every)\n\tif _G.fsRotMenu then _G.fsRotMenu() end\n")
sub(show, "local fromProgram, fromMenu = {}, {}\n", "local fromProgram, fromMenu = {}, {}\n_G.fsRotMenu = function() fromMenu.rot = true end\n")
-- bots con su @ de TikTok
sub(show, [[tag(model, isBot(nick) and fakeNick(model.Name) or nick, 1)]], [[tag(model, isBot(nick) and (opt.bn or fakeNick(model.Name)) or nick, 1)]])
sub(show, [[job.model, job.cine, job.hearts, job.nick = anyFiller(), false, false, ""]], [[job.model, job.cine, job.hearts, job.nick, job.opt = anyFiller(), false, false, "", nil]])
-- ---------- TikTokReader ----------
sub(SSS.TikTokReader, [[local opt = (e.v or e.fg) and { vip = e.v == true, fs = tonumber(e.fs), fg = tonumber(e.fg) } or nil]],
	[[local opt = (e.v or e.fg or e.b) and { vip = e.v == true, fs = tonumber(e.fs), fg = tonumber(e.fg), bn = type(e.b) == "string" and e.b:sub(1, 24) or nil } or nil]])
-- ---------- GameControl ----------
sub(SSS.GameControl, [[elseif action == "marks" and type(value) == "string" then]], [[elseif action == "night" and type(value) == "string" then
		if _G.fsStage then _G.fsStage({ night = value, menu = true }) end
	elseif action == "rotenv" and type(value) == "string" then
		if _G.fsRot then _G.fsRot(value) end
	elseif action == "rotevery" and tonumber(value) then
		if _G.fsRot then _G.fsRot(nil, tonumber(value)) end
	elseif action == "marks" and type(value) == "string" then]])
-- ---------- menú ----------
local mn = game.StarterPlayer.StarterPlayerScripts.TikMenuClient
sub(mn, [[local textBtn, textLbl = btn(pages.Escena, "✔ Poner texto", GREEN, 8,]], [[title(pages.Escena, "MINIMALISTA: DÍA O NOCHE", 26)
local nightBtns = {}
local nig = grid(pages.Escena, 27, 36)
for i, m in ipairs(C.NIGHT) do nightBtns[m.id] = btn(nig, m.emoji .. " " .. m.name, BLUE, i, function() Control:FireServer("night", m.id) end) end
title(pages.Escena, "ESCENARIOS QUE ROTAN", 28)
local rotBtns, rotLbls = {}, {}
local rog = grid(pages.Escena, 29, 36)
for i, e in ipairs(C.ENVS) do rotBtns[e.id], rotLbls[e.id] = btn(rog, e.name, BLUE, i, function() Control:FireServer("rotenv", e.id) end) end
title(pages.Escena, "CAMBIAR DE ESCENARIO CADA", 30)
local everyBtns = {}
local evg = grid(pages.Escena, 31, 36, 3)
for i, m in ipairs(C.ROT_TIMES) do everyBtns[m] = btn(evg, m == 0 and "Nunca" or m .. " min", BLUE, i, function() Control:FireServer("rotevery", m) end) end
local textBtn, textLbl = btn(pages.Escena, "✔ Poner texto", GREEN, 8,]])
sub(mn, [[	for id, b in pairs(marksBtns) do K.recolor(b, (workspace:GetAttribute("Cuadros") or "si") == id and GREEN or BLUE) end]],
[[	for id, b in pairs(marksBtns) do K.recolor(b, (workspace:GetAttribute("Cuadros") or "si") == id and GREEN or BLUE) end
	for id, b in pairs(nightBtns) do K.recolor(b, (workspace:GetAttribute("Noche") or "dia") == id and GREEN or BLUE) end
	local envOff = workspace:GetAttribute("EnvOff") or "{}"
	for _, e in ipairs(C.ENVS) do
		local on = not envOff:find('"' .. e.id .. '"', 1, true)
		K.recolor(rotBtns[e.id], on and GREEN or BLUE)
		rotLbls[e.id].Text = (on and "☑ " or "☐ ") .. L(e.name)
	end
	for m, b in pairs(everyBtns) do K.recolor(b, (workspace:GetAttribute("EnvEvery") or 0) == m and GREEN or BLUE) end]])
-- ---------- cliente ----------
for _, d in ipairs(game.StarterPlayer.StarterPlayerScripts:GetDescendants()) do
	if d:IsA("LuaSourceContainer") and (d.Name == "CameraController" or d.Name == "RedCarpetFx") then
		d.Source = H:GetAsync("http://127.0.0.1:5099/" .. d.Name .. ".lua?t=" .. os.clock(), true)
	end
end
return "ok, fotografos=" .. total .. " piezas sala=" .. #room:GetDescendants()
