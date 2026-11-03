-- Puerta del final, recorrido sin paradas y zoom
local map = workspace.MapaActivo.RedCarpet
local old = map:FindFirstChild("PuertaFinal")
if old then old:Destroy() end
local D = Group(map, "PuertaFinal")
local Zd, W, H = 58, 7.4, 11.5
local WALL, DARK = rgb(42, 20, 34), rgb(8, 6, 10)
for _, s in ipairs({ -1, 1 }) do
	P(D, "Muro", V3(26, 20, 1.6), CF(s * (W + 13), 10, Zd), WALL)
	P(D, "Remate", V3(26, 0.4, 1.9), CF(s * (W + 13), 20.1, Zd), GOLD, M.Metal)
	P(D, "Jamba", V3(0.7, H + 0.7, 2), CF(s * (W + 0.1), (H + 0.7) / 2, Zd), GOLD, M.Metal)
	P(D, "Pared", V3(0.5, H, 14), CF(s * (W + 0.5), H / 2, Zd + 7), DARK)
end
P(D, "Dintel", V3(W * 2, 20 - H, 1.6), CF(0, (20 + H) / 2, Zd), WALL)
P(D, "Remate", V3(W * 2, 0.4, 1.9), CF(0, 20.1, Zd), GOLD, M.Metal)
P(D, "Cabecero", V3(W * 2 + 1.5, 0.7, 2), CF(0, H + 0.35, Zd), GOLD, M.Metal)
P(D, "Techo", V3(W * 2, 0.5, 14), CF(0, H, Zd + 7), DARK)
P(D, "Fondo", V3(W * 2, H, 0.5), CF(0, H / 2, Zd + 14), DARK)
P(D, "SueloFondo", V3(W * 2, 0.12, 13), CF(0, 0.08, Zd + 7.4), DARK)
local sign = P(D, "Cartel", V3(15, 2.6, 0.3), CF(0, H + 3.2, Zd - 1), rgb(24, 12, 20))
Label(sign, Enum.NormalId.Front, "✦ BACKSTAGE ✦", CREAM, nil, 30)
for _, s in ipairs({ -1, 1 }) do
	local g = Group(D, s < 0 and "HojaI" or "HojaD")
	local hinge = CF(s * W, 0, Zd)
	local cx = s * W / 2
	P(g, "Hoja", V3(W, H, 0.4), CF(cx, H / 2, Zd), rgb(120, 10, 22), M.Fabric)
	P(g, "Filete", V3(W - 1.2, H - 1.4, 0.08), CF(cx, H / 2, Zd - 0.23), rgb(150, 18, 32), M.Fabric)
	Bar(g, "Tirador", V3(s * 1, 3.4, Zd - 0.45), V3(s * 1, 7, Zd - 0.45), 0.2, GOLD, M.Metal)
	g.WorldPivot = hinge
end
local spot = P(D, "Luz", V3(1, 1, 1), CF(0, H + 1, Zd - 4), CREAM, M.SmoothPlastic, { Transparency = 1 })
Light(spot, 26, 1.4)
map.Salida.Position = V3(0, map.Salida.Position.Y, Zd + 8)

-- ---------- scripts ----------
local function sub(script, old, new)
	local s = script.Source
	local i, j = s:find(old, 1, true)
	assert(i, "no encontrado: " .. old:sub(1, 50))
	script.Source = s:sub(1, i - 1) .. new .. s:sub(j + 1)
end
local show = game.ServerScriptService.RedCarpetShow
-- Humanoid:MoveTo se rinde a los 8 s: el tramo largo se quedaba parado en mitad de la alfombra y se amontonaban
sub(show, [[local t0, limit = os.clock(), ((target - root.Position) * flat).Magnitude / WALK_SPEED + 3
	hum:MoveTo(target)
	while model.Parent and ((target - root.Position) * flat).Magnitude > 1.5 and os.clock() - t0 < limit do
		RunService.Heartbeat:Wait()
	end]], [[local t0, limit = os.clock(), ((target - root.Position) * flat).Magnitude / math.max(hum.WalkSpeed, 1) + 3
	local again = 0
	while model.Parent and ((target - root.Position) * flat).Magnitude > 1.5 and os.clock() - t0 < limit do
		if os.clock() >= again then
			hum:MoveTo(target)
			again = os.clock() + 3
		end
		RunService.Heartbeat:Wait()
	end]])
-- cada uno por su carril, el del cinemático por el centro
sub(show, [[	for _, p in ipairs(ROUTE) do
		if not model.Parent then break end
		moveTo(model, p)]], [[	laneI = laneI % #LANES + 1
	local lane = Vector3.new(cine and 0 or LANES[laneI], 0, 0)
	for _, p in ipairs(ROUTE) do
		if not model.Parent then break end
		moveTo(model, p + lane)]])
sub(show, "local function runWalk(model, nick, cine, withHearts, fast, cseq, opt)", [[local LANES, laneI = { -2.4, 1.2, -0.8, 2.6, -1.6, 0.4 }, 0
local function runWalk(model, nick, cine, withHearts, fast, cseq, opt)]])
sub(show, "-- ---------- modo fiesta ----------", [[-- la puerta del final se abre sola cuando alguien se acerca
task.spawn(function()
	local door = map:WaitForChild("PuertaFinal")
	local I, R = door.HojaI, door.HojaD
	local ci, cr = I:GetPivot(), R:GetPivot()
	local a = 0
	while true do
		task.wait(0.05)
		local near = false
		for _, m in ipairs(folder:GetChildren()) do
			local r = m:FindFirstChild("HumanoidRootPart")
			if r and r.Position.Z > 40 then near = true break end
		end
		local goal = near and 1.75 or 0
		if a ~= goal then
			a = goal > a and math.min(goal, a + 0.14) or math.max(goal, a - 0.1)
			I:PivotTo(ci * CFrame.Angles(0, -a, 0))
			R:PivotTo(cr * CFrame.Angles(0, a, 0))
		end
	end
end)

-- ---------- modo fiesta ----------]])
local mn = game.StarterPlayer.StarterPlayerScripts.TikMenuClient
sub(mn, [[{ "off", "🖱️ Normal" } }) do]], [[{ "salida", "🚪 Puerta" }, { "off", "🖱️ Normal" } }) do]])
sub(mn, [[hint(pages["Cámara"], "Libre: WASD]], [[local zg = grid(pages["Cámara"], 2, 36)
local function zoomBy(k) player:SetAttribute("CamZoom", math.clamp((player:GetAttribute("CamZoom") or 1) * k, 0.6, 6)) end
btn(zg, "➕ Acercar", GREEN, 1, function() zoomBy(1.25) end)
btn(zg, "➖ Alejar", GREEN, 2, function() zoomBy(1 / 1.25) end)
btn(zg, "↩️ Zoom normal", BLUE, 3, function() player:SetAttribute("CamZoom", 1) end)
hint(pages["Cámara"], "Zoom también con la rueda del ratón. Libre: WASD]])
local H2 = game:GetService("HttpService")
game.StarterPlayer.StarterPlayerScripts.CameraController.Source = H2:GetAsync("http://127.0.0.1:5099/CameraController.lua?t=" .. os.clock(), true)
return "ok"
