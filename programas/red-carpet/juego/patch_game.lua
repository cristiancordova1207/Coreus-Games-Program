-- Aplica los cambios a los scripts de Fashion copiados. Falla ruidosamente si un trozo no coincide.
local H = game:GetService("HttpService")
local function g(f) return H:GetAsync("http://127.0.0.1:5099/" .. f .. "?t=" .. os.clock(), true) end
local SS, SP = game.ServerScriptService, game.StarterPlayer.StarterPlayerScripts
local log = {}
local function patcher(script)
	local src = script.Source
	local P = {}
	function P.rep(old, new)
		local a, b = src:find(old, 1, true)
		assert(a, script.Name .. ": no encontrado: " .. old:sub(1, 70))
		src = src:sub(1, a - 1) .. new .. src:sub(b + 1)
	end
	function P.range(from, to, new) -- desde el inicio de `from` hasta justo antes de `to`
		local a = src:find(from, 1, true)
		assert(a, script.Name .. ": sin inicio: " .. from:sub(1, 70))
		local b = src:find(to, a + #from, true)
		assert(b, script.Name .. ": sin fin: " .. to:sub(1, 70))
		src = src:sub(1, a - 1) .. new .. src:sub(b)
	end
	function P.done() script.Source = src table.insert(log, script.Name .. " ok") end
	return P
end

-- ========== reemplazos enteros ==========
SP.CameraController.Source = g("CameraController.lua")
SP.FloatFx.Source = g("FloatFx.lua")
local fx = SP:FindFirstChild("RedCarpetFx") or Instance.new("LocalScript")
fx.Name, fx.Source, fx.Parent = "RedCarpetFx", g("RedCarpetFx.lua"), SP

-- ========== FashionShow -> RedCarpetShow ==========
local show = SS:FindFirstChild("RedCarpetShow") or SS.FashionShow
show.Name = "RedCarpetShow"
local p = patcher(show)
p.range("-- Roblox Fashion Show: el programa", "local Players = game:GetService(\"Players\")", [==[
-- Red Carpet: el programa lleva las colas (cinemático > regalos > normal > relleno) y aquí sólo se dibuja.
--   _G.fsWalk(roblox, tiktok, cine, hearts, relleno, fast, opt) -> camina por la alfombra
--        opt = {fs = seguidores al empezar, fg = seguidores que gana, vip = se saltó la cola, float = flota}
--   _G.fsGiant / _G.fsUniverse / _G.fsParty / _G.fsStage -> como en Fashion
--   _G.fsFloat(roblox, tiktok, _, fs, fg) -> recorre la alfombra flotando, con cámara dinámica
--   _G.fsPhoto(roblox, tiktok, segundos, fs, fg) -> sesión de fotos: fotógrafos a su alrededor y flashes
-- Recorrido: sale tapado detrás de un muro junto al arco y recorre la alfombra hasta pasar la cámara.
]==])
p.range("local map = workspace.MapaActivo:WaitForChild(\"Pasarela\")", "local folder = workspace:FindFirstChild(\"Avatares\")", [==[
local map = workspace.MapaActivo:WaitForChild("RedCarpet")
local P1, P2 = map.P1.Position, map.P2.Position
local ROUTE = { P1, P2, map.Salida.Position } -- la cámara del cinemático va de P1 a P2
local ENTRIES, GIANT_SPOT = { map.EntradaI.Position, map.EntradaD.Position }, map.Gigante.Position
]==])
p.rep("local GIANT_SCALE = 2.6", "local GIANT_SCALE = 3.4")
p.rep("local FLOAT_TIME = 10\n", "local FLOAT_LIFT, FLOAT_SPEED = 3.6, 0.72\nlocal PHOTO_TIME = 7\nlocal PHOTO_R = 8.5\n")

p.range("local function runWalk(model, nick, cine, withHearts, fast, cseq)", "-- Nunca vacía:", [==[
local entrySide = 0
local function routeLength(from)
	local total, last = 0, from
	for _, q in ipairs(ROUTE) do total += (q - last).Magnitude last = q end
	return total
end
local function runWalk(model, nick, cine, withHearts, fast, cseq, opt)
	opt = opt or {}
	walkSeq += 1
	local id = tostring(walkSeq)
	fast = math.clamp(tonumber(fast) or 1, 1, 2)
	local me = cine and { id = id, model = model, cseq = cseq or 0 }
	local hum, root = model.Humanoid, model.HumanoidRootPart
	local y = hum.HipHeight + root.Size.Y / 2
	entrySide = entrySide % #ENTRIES + 1 -- sale una vez de cada lado
	local ENTRY = ENTRIES[entrySide]
	local spawn = Vector3.new(ENTRY.X, y, ENTRY.Z)
	root.CFrame = CFrame.lookAt(spawn, Vector3.new(P1.X, y, P1.Z))
	local speed = WALK_SPEED * fast * (opt.float and FLOAT_SPEED or 1)
	model:SetAttribute("WalkId", id)
	model:SetAttribute("Nick", nick)
	model:SetAttribute("Cine", cine == true)
	model:SetAttribute("CineDur", (P2 - P1).Magnitude / speed)
	if opt.vip then model:SetAttribute("Vip", true) end
	if opt.fg and not workspace:GetAttribute("FameOff") then
		model:SetAttribute("FameStart", tonumber(opt.fs) or 0)
		model:SetAttribute("FameDur", routeLength(spawn) / speed)
		model:SetAttribute("FameGain", tonumber(opt.fg) or 0)
	end
	model.Parent = folder
	pcall(root.SetNetworkOwner, root, nil)
	hum.WalkSpeed = speed
	walking += 1
	setCount()
	if not (isBot(nick) and workspace:GetAttribute("BotNamesOff")) then tag(model, isBot(nick) and fakeNick(model.Name) or nick, 1) end
	local hb = withHearts and hearts(model)
	workspace:SetAttribute("LatestWalker", id)
	if opt.float then
		model:SetAttribute("FloatId", id)
		TweenService:Create(hum, TweenInfo.new(1.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { HipHeight = hum.HipHeight + FLOAT_LIFT }):Play()
		if not play(model, "float") then play(model, "walk", speed / ANIM_REF) end
	else
		play(model, "walk", speed / ANIM_REF)
	end
	for _, p in ipairs(ROUTE) do
		if not model.Parent then break end
		moveTo(model, p)
		if me and p == P1 then table.insert(cineWait, me) cineNext() end
		if p == P2 then cineClose(me) cineEnd(id) end -- la cámara le deja antes de llegar a la cámara fija
	end
	if hb then hb:Destroy() end
	cineClose(me)
	cineEnd(id)
	walking -= 1
	setCount()
	if model.Parent then model:Destroy() end
end

]==])
p.rep("_G.fsWalk = function(username, nick, cine, withHearts, isFiller, fast)", "_G.fsWalk = function(username, nick, cine, withHearts, isFiller, fast, opt)")
p.rep("filler = isFiller, fast = tonumber(fast) or 1 }", "filler = isFiller, fast = tonumber(fast) or 1, opt = opt }")
p.rep("task.spawn(runWalk, job.model, job.nick, job.cine, job.hearts, job.fast, job.cseq)", "task.spawn(runWalk, job.model, job.nick, job.cine, job.hearts, job.fast, job.cseq, job.opt)")
-- saltarse la cola: sale delante de todos en el juego
p.rep("	table.insert(spawnQ, job)\n", "	if opt and opt.vip then table.insert(spawnQ, 1, job) else table.insert(spawnQ, job) end\n")

-- levitación -> paseo flotante + sesión de fotos
p.range("-- ---------- levitación (Capibara) ----------", "-- gigante y levitación: uno detrás de otro", [==[
-- ---------- sesión de fotos ----------
-- Quien regaló sale en medio de la alfombra, posa y los fotógrafos le rodean disparando. RedCarpetFx hace poses, flashes y
-- el destello de pantalla; CameraController corta entre fotógrafos. Los que caminan se ocultan al pasar por su lado.
local sesion = workspace:FindFirstChild("SesionFotos") or Instance.new("Folder")
sesion.Name, sesion.Parent = "SesionFotos", workspace
local function photoShow(username, nick, seconds, fs, fg)
	local model = makeAvatar(username) or anyFiller()
	if not model then return end
	local hum, root = model.Humanoid, model.HumanoidRootPart
	root.Anchored = true
	local y = hum.HipHeight + root.Size.Y / 2
	local spot = Vector3.new(GIANT_SPOT.X, y, GIANT_SPOT.Z)
	root.CFrame = CFrame.lookAt(spot, spot + Vector3.zAxis)
	walkSeq += 1
	local id = "p" .. walkSeq
	model:SetAttribute("PhotoId", id)
	if fg and not workspace:GetAttribute("FameOff") then
		model:SetAttribute("FameStart", tonumber(fs) or 0)
		model:SetAttribute("FameDur", seconds)
		model:SetAttribute("FameGain", tonumber(fg) or 0)
	end
	model.Parent = folder
	local bb = tag(model, nick, 1.1)
	if bb then bb.AlwaysOnTop = true end
	play(model, "idle")
	-- los fotógrafos, repartidos en un abanico delante de él (detrás no: la cámara y el público miran de frente)
	local src = game.ReplicatedStorage.RCModels.Fotografos:GetChildren()
	local n = #src
	for i, s in ipairs(src) do
		local f = s:Clone()
		local a = math.rad(-115 + (i - 1) * 230 / (n - 1))
		local pos = Vector3.new(spot.X + math.sin(a) * PHOTO_R, 0, spot.Z + math.cos(a) * PHOTO_R)
		pos = Vector3.new(math.clamp(pos.X, -7.6, 7.6), 0, pos.Z)
		f:PivotTo(CFrame.lookAt(pos, Vector3.new(spot.X, 0, spot.Z)) * CFrame.new(0, -6, 0))
		f.Parent = sesion
		task.spawn(function() -- salen del suelo uno detrás de otro
			task.wait(i * 0.05)
			local t0, from = os.clock(), f:GetPivot()
			while f.Parent and os.clock() - t0 < 0.35 do
				local k = TweenService:GetValue((os.clock() - t0) / 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				f:PivotTo(from * CFrame.new(0, 6 * k, 0))
				RunService.Heartbeat:Wait()
			end
			if f.Parent then f:PivotTo(from * CFrame.new(0, 6, 0)) end
		end)
	end
	workspace:SetAttribute("PhotoCine", id)
	task.wait(seconds)
	if workspace:GetAttribute("PhotoCine") == id then workspace:SetAttribute("PhotoCine", "") end
	sesion:ClearAllChildren()
	if bb then bb:Destroy() end
	model:Destroy()
end

]==])
p.rep("-- gigante y levitación: uno detrás de otro; esperan", "-- gigante y sesión de fotos: uno detrás de otro; esperan")
p.range("_G.fsFloat = function(username, nick, seconds)", "local universes = {}", [==[
_G.fsPhoto = function(username, nick, seconds, fs, fg)
	runSpecial(photoShow, username, nick, math.clamp(tonumber(seconds) or PHOTO_TIME, 3, 30), fs, fg)
end
-- el paseo flotante es un cinemático más: sale en su turno y la cámara le sigue
_G.fsFloat = function(username, nick, _, fs, fg)
	_G.fsWalk(username, nick, true, false, false, 1, { float = true, fs = fs, fg = fg })
end

]==])
p.rep([[or (workspace:GetAttribute("FloatCine") or "") ~= "" or workspace:GetAttribute("SpecialPending")]], [[or (workspace:GetAttribute("PhotoCine") or "") ~= "" or workspace:GetAttribute("SpecialPending")]])

-- pantalla + escenarios
p.rep("local SITE = \"coreus-games.pages.dev\"", "local SITE = \"coreus-games.pages.dev\"")
p.range("-- estilos del escenario (mismo recorrido, distinta decoración).", "-- el programa manda su estilo en cada desfile", [==[
-- Escenarios (ServerStorage.EscenariosRC). Sólo uno está en el mapa, como "Entorno"; al cambiar se mueven, no se clonan.
local ENVS = game:GetService("ServerStorage"):WaitForChild("EscenariosRC")
local STYLES = {}
for _, e in ipairs(ENVS:GetChildren()) do STYLES[e.Name] = e end
local DEFAULT_STYLE = "minimal"
local carpet, carpetEdges, marks = map.Alfombra, {}, map.Marcas
for _, c in ipairs(map:GetChildren()) do if c.Name == "Borde" then table.insert(carpetEdges, c) end end
local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
local BASE_FX = {}
local currentEnv
local function applyStyle(name)
	local env = STYLES[name] or STYLES[DEFAULT_STYLE]
	workspace:SetAttribute("Estilo", env.Name)
	if currentEnv == env then return end
	if currentEnv then currentEnv.Name = currentEnv:GetAttribute("Id") currentEnv.Parent = ENVS end
	env:SetAttribute("Id", env.Name)
	env.Name = "Entorno"
	env.Parent = map
	currentEnv = env
	local a = function(k) return env:GetAttribute(k) end
	Lighting.ClockTime, Lighting.Brightness = a("ClockTime"), a("Brightness")
	Lighting.Ambient, Lighting.OutdoorAmbient = a("Ambient"), a("OutdoorAmbient")
	Lighting.GlobalShadows, Lighting.ExposureCompensation = a("Shadows") == true, a("Exposure") or 0
	Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.4, 0.3
	Lighting.FogEnd = 100000
	for _, s in ipairs(Lighting:GetChildren()) do if s:IsA("Sky") then s:Destroy() end end
	local skySrc = game:GetService("ServerStorage").Iluminacion:FindFirstChild(a("Sky") or "Wylo")
	local sky = skySrc and skySrc:FindFirstChildOfClass("Sky")
	if sky then
		local c = sky:Clone()
		if a("Stars") then c.StarCount, c.CelestialBodiesShown = 5000, false end
		c.Parent = Lighting
	end
	if atmos then
		atmos.Density = a("Atmos") or 0
		atmos.Haze, atmos.Glare = 0, 0
		if a("AtmosColor") then atmos.Color = a("AtmosColor") end
	end
	workspace:SetAttribute("Interior", a("Interior") == true)
	carpet.Color = a("Carpet") or Color3.fromRGB(172, 10, 22)
	carpet.Material = Enum.Material[a("CarpetMat") or "Fabric"]
	for _, e in ipairs(carpetEdges) do e.Color = carpet.Color:Lerp(Color3.new(), 0.3) e.Material = carpet.Material end
	local mk = a("Marks") or Color3.fromRGB(255, 196, 120)
	for _, l in ipairs(marks:GetChildren()) do l.Color = mk end
	local noScreen = a("NoScreen") == true
	screen.Transparency = noScreen and 1 or 0
	screen.Texto.Enabled = not noScreen
	for _, d in ipairs(map.MarcoPantalla:GetChildren()) do d.Transparency = noScreen and 1 or 0 end
end
applyStyle(workspace:GetAttribute("Estilo") or DEFAULT_STYLE)

]==])

-- bailarines de la fiesta: a los lados de la alfombra
p.range("		-- sitios libres a cada lado: lejos de la decoración", "		for i = 0, #spots - 1 do", [==[
		-- a los lados de la alfombra, y tres más en el centro mirando a la cámara
		local spots = {}
		for _, side in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -50, -30, -10 }) do table.insert(spots, Vector3.new(side * 6.3, 3, z)) end
		end
		local mid = 3
		for _, v in ipairs({ Vector3.new(0, 3, -24), Vector3.new(-3.5, 3, -30), Vector3.new(3.5, 3, -30) }) do table.insert(spots, v) end
]==])
p.rep([[partyPrev = workspace:GetAttribute("Estilo") or "clasico"]], [[partyPrev = workspace:GetAttribute("Estilo") or DEFAULT_STYLE]])
p.rep([[web.TextColor3 = on and Color3.fromRGB(20, 18, 28) or rgb((STYLES[workspace:GetAttribute("Estilo")] or STYLES.clasico).texto)]], [[web.TextColor3 = on and Color3.fromRGB(20, 18, 28) or Color3.fromRGB(40, 16, 16)]])
p.done()

-- ========== PartyClient ==========
local pc = patcher(SP.PartyClient)
pc.rep([[WaitForChild("Pasarela")]], [[WaitForChild("RedCarpet")]])
pc.rep("local CENTER = Vector3.new(0, 0, 16)", "local CENTER = Vector3.new(0, 0, -30)")
pc.rep("local BALL_Y, HIDDEN_Y = 14.5, 19.5", "local BALL_Y, HIDDEN_Y = 21, 46")
pc.rep("Size = Vector3.new(44, 0.2, 56), Transparency = 1, Position = Vector3.new(0, 17.5, 14)", "Size = Vector3.new(50, 0.2, 130), Transparency = 1, Position = Vector3.new(0, 30, -28)")
pc.rep("local top, low = 18,", "local top, low = 48,")
pc.done()

-- ========== TikTokReader: sin cuentas ==========
local tr = patcher(SS.TikTokReader)
tr.range("-- Recibe los eventos del programa \"Roblox Fashion Show\".", "local HttpService = game:GetService(\"HttpService\")", [==[
-- Recibe los eventos del programa "Red Carpet". El programa lleva la cola; aquí sólo se ejecuta:
--   {k="w", n=roblox, u=tiktok, c=cinemático, h=corazones, v=saltó la cola, fs/fg=fama} camina
--   {k="g", n, u, s} gigante · {k="y", n, u} flotando · {k="f", n, u, s} sesión de fotos · {k="p", s} fiesta · {k="t", text, color} pantalla
--  · Roblox Studio (▶ Jugar): lee el programa directamente en 127.0.0.1.
--  · Juego publicado: el programa los publica directo por Open Cloud (MessagingService) en el tema "rc_<UserId>"
--    (automático) y "rc_c<código>" (el código que enseña el menú). {k="ping"} sólo avisa de que el programa sigue ahí.
]==])
tr.range("local API = \"https://dcepxcltgzipkmzpptzn", "workspace:SetAttribute(\"BridgeOnline\", false)", "")
tr.rep([[workspace:SetAttribute("BridgeSub", false) -- suscripción mensual: solo con ella se cambia el texto grande de la pantalla]], [[workspace:SetAttribute("BridgeSub", true) -- sin cuentas: siempre se puede cambiar el texto de la pantalla]])
tr.range("	if e.k == \"lock\" then", "	lastSeen = os.clock()", "")
tr.rep([[	if e.k == "w" and name and _G.fsWalk then task.spawn(_G.fsWalk, name, nick, e.c == true, e.h == true, false, tonumber(e.f))]],
	[[	local opt = (e.v or e.fg) and { vip = e.v == true, fs = tonumber(e.fs), fg = tonumber(e.fg) } or nil
	if e.k == "w" and name and _G.fsWalk then task.spawn(_G.fsWalk, name, nick, e.c == true, e.h == true, false, tonumber(e.f), opt)]])
tr.rep([[elseif e.k == "y" and name and _G.fsFloat then task.spawn(_G.fsFloat, name, nick, e.s) -- Levitación (Capibara)]],
	[[elseif e.k == "y" and name and _G.fsFloat then task.spawn(_G.fsFloat, name, nick, e.s, tonumber(e.fs), tonumber(e.fg))
	elseif e.k == "f" and name and _G.fsPhoto then task.spawn(_G.fsPhoto, name, nick, e.s, tonumber(e.fs), tonumber(e.fg))]])
tr.range("		if not RunService:IsStudio() and os.clock() - lockSeen > 90", "		task.wait(1)\n", "")
tr.rep([[					workspace:SetAttribute("BridgeLocked", data.locked or "")
					workspace:SetAttribute("BridgeSub", data.sub == true)
]], "")
tr.rep([[warn("Roblox Fashion Show: abre el programa (no responde en "]], [[warn("Red Carpet: abre el programa (no responde en "]])
tr.rep([[					if who and data.m ~= nil then workspace:SetAttribute("BridgeSub", data.m == 1) end
]], "")
tr.rep([[warn("Roblox Fashion Show: no se pudo escuchar", topic, err)]], [[warn("Red Carpet: no se pudo escuchar", topic, err)]])
tr.rep([[task.spawn(listen, "rf_c" .. code, "code")]], [[task.spawn(listen, "rc_c" .. code, "code")]])
tr.rep([[task.spawn(listen, "rf_" .. p.UserId, p.UserId)]], [[task.spawn(listen, "rc_" .. p.UserId, p.UserId)]])
tr.range("	-- echar (lo manda el admin desde Stats Fluxy", "end\n\n", "")
tr.rep("lastSeen, lockSeen = 0, 0", "lastSeen = 0")
tr.done()

-- ========== Config ==========
local cfg = patcher(game.ReplicatedStorage.TikAvatars.Config)
cfg.rep("-- Configuración de Roblox Fashion Show (la usan el servidor y el menú)", "-- Configuración de Red Carpet (la usan el servidor y el menú)")
cfg.rep([[-- Programa "Roblox Fashion Show" en tu PC. En Roblox Studio el juego lo lee directo (127.0.0.1);
-- en el juego publicado llega por MessagingService (fashion-api -> Open Cloud), temas rf_<UserId> / rf_c<código>.
C.BRIDGE_URL = "http://127.0.0.1:5088/api/poll"]], [[-- Programa "Red Carpet" en tu PC. En Roblox Studio el juego lo lee directo (127.0.0.1);
-- en el juego publicado llega por MessagingService (Open Cloud), temas rc_<UserId> / rc_c<código>.
C.BRIDGE_URL = "http://127.0.0.1:5093/api/poll"
C.ENVS = {
	{ id = "minimal", name = "Minimalista", emoji = "🤍" }, { id = "museo", name = "Museo", emoji = "🏛️" },
	{ id = "cine", name = "Gala de cine", emoji = "🎬" }, { id = "espacio", name = "Espacio", emoji = "🪐" },
	{ id = "pasarela", name = "Pasarela", emoji = "👠" }, { id = "vegas", name = "Las Vegas", emoji = "🌴" },
	{ id = "jardin", name = "Jardín", emoji = "🌸" }, { id = "ciudad", name = "Ciudad neón", emoji = "🌃" },
}]])
cfg.rep([[C.SITE = "robloxfashion.pages.dev"]], [[C.SITE = "coreus-games.pages.dev"]])
cfg.done()

-- ========== GameControl ==========
local gc = patcher(SS.GameControl)
gc.rep("local TOGGLES = { TagVerified = true, BotsOff = true, BotNamesOff = true }", "local TOGGLES = { TagVerified = true, BotsOff = true, BotNamesOff = true, FameOff = true, DynCamOff = true, FlashesOff = true }")
gc.range("local TEST_MAX = 10", "-- texto grande: solo con suscripción mensual.", [==[
local function take(_, n) return n end -- sin cuentas: las pruebas son libres
]==])
gc.rep([[	elseif action == "universe" then]], [[	elseif action == "float" then
		if _G.fsFloat then task.spawn(_G.fsFloat, rnd(TEST_NAMES), rnd(FANS), nil, math.random(0, 2000), math.random(800, 6000)) end
	elseif action == "photo" then
		if _G.fsPhoto then task.spawn(_G.fsPhoto, rnd(TEST_NAMES), rnd(FANS), 7, math.random(0, 2000), math.random(400, 2000)) end
	elseif action == "skip" then
		if _G.fsWalk then task.spawn(_G.fsWalk, rnd(TEST_NAMES), rnd(FANS), false, false, false, 1, { vip = true, fs = math.random(0, 2000), fg = math.random(200, 1500) }) end
	elseif action == "universe" then]])
gc.rep([[task.spawn(_G.fsWalk, rnd(TEST_NAMES), rnd(FANS), value == "cine", value == "rose") end]], [[task.spawn(_G.fsWalk, rnd(TEST_NAMES), rnd(FANS), value == "cine", value == "rose", false, 1, value ~= "normal" and { fs = math.random(0, 2000), fg = math.random(200, 3000) } or nil) end]])
gc.rep([[(linked() or (p:GetAttribute("PruebasLeft") or 0) > 0)]], [[true]])
gc.done()

-- ========== menú ==========
local mn = patcher(SP.TikMenuClient)
mn.rep([["👗 FASHION SHOW"]], [["🎬 RED CARPET"]])
mn.rep([=[for i, s in ipairs({ { "clasico", "🤍 Clásico" }, { "noche", "🌙 Noche neón" }, { "rosa", "🌸 Rosa" }, { "dorado", "✨ Dorado" }, { "marmol", "🏛️ Mármol" },
	{ "sakura", "🌸 Sakura" }, { "jardin", "🌿 Jardín" }, { "nubes", "☁️ Nubes" }, { "lujo", "👑 Lujo" } }) do
	styleBtns[s[1]] = btn(stg, s[2], BLUE, i, function() Control:FireServer("style", s[1]) end)
end]=], [=[for i, s in ipairs(C.ENVS) do
	styleBtns[s.id] = btn(stg, s.emoji .. " " .. s.name, BLUE, i, function() Control:FireServer("style", s.id) end)
end]=])
mn.rep([[se cambian en el programa Roblox Fashion Show.", 5)]], [[se cambian en el programa Red Carpet.", 5)]])
mn.rep([[for i, c in ipairs({ { "pasarela", "👗 Frontal" }, { "cerca", "🔍 Cerca" },]], [[for i, c in ipairs({ { "boceto", "🎬 Principal" }, { "centro", "⬆️ Centro" }, { "cerca", "🔍 Cerca" },]])
mn.rep([[title(pages["Cámara"], "CÁMARAS GUARDADAS", 5)]], [[local bDyn, lDyn = btn(pages["Cámara"], "", BLUE, 4, function() Control:FireServer("toggle", "DynCamOff") end)
title(pages["Cámara"], "CÁMARAS GUARDADAS", 5)]])
mn.rep([[btn(tg, "👗 Desfile", BLUE, 3, function() Control:FireServer("walk", "normal") end)]], [[btn(tg, "🚶 Caminar", BLUE, 3, function() Control:FireServer("walk", "normal") end)
btn(tg, "✨ Flotando", PURPLE, 8, function() Control:FireServer("float") end)
btn(tg, "📸 Sesión de fotos", ORANGE, 9, function() Control:FireServer("photo") end)
btn(tg, "⚡ Saltar cola", GREEN, 10, function() Control:FireServer("skip") end)]])
mn.rep([[title(T, "PROGRAMA ROBLOX FASHION SHOW", 1)]], [[title(T, "PROGRAMA RED CARPET", 1)]])
mn.rep([[local bBotN, lBotN = btn(pages.Tags, "", BLUE, 7, function() Control:FireServer("toggle", "BotNamesOff") end)]], [[local bBotN, lBotN = btn(pages.Tags, "", BLUE, 7, function() Control:FireServer("toggle", "BotNamesOff") end)
title(pages.Tags, "FAMA", 8)
local bFame, lFame = btn(pages.Tags, "", BLUE, 9, function() Control:FireServer("toggle", "FameOff") end)
local bFlash, lFlash = btn(pages.Tags, "", BLUE, 10, function() Control:FireServer("toggle", "FlashesOff") end)]])
mn.rep([[	onoff(bBotN, lBotN, not workspace:GetAttribute("BotNamesOff"), "🏷️ Nombre de los bots")
]], [[	onoff(bBotN, lBotN, not workspace:GetAttribute("BotNamesOff"), "🏷️ Nombre de los bots")
	onoff(bFame, lFame, not workspace:GetAttribute("FameOff"), "⭐ Sistema de fama")
	onoff(bFlash, lFlash, not workspace:GetAttribute("FlashesOff"), "📸 Flashes")
	onoff(bDyn, lDyn, not workspace:GetAttribute("DynCamOff"), "🎥 Cámaras dinámicas")
]])
mn.rep([[(workspace:GetAttribute("Estilo") or "clasico") == id]], [[(workspace:GetAttribute("Estilo") or "minimal") == id]])
mn.rep([[(player:GetAttribute("CamMode") or "pasarela") == k]], [[(player:GetAttribute("CamMode") or "boceto") == k]])
mn.rep([["BotsOff", "BotNamesOff", "ScreenText" }) do]], [["BotsOff", "BotNamesOff", "ScreenText", "FameOff", "FlashesOff", "DynCamOff" }) do]])
mn.rep([[linkLabel(14, 44, 36).Text = "🔗 " .. L("Conecta el programa Roblox Fashion Show")]], [[linkLabel(14, 44, 36).Text = "🔗 " .. L("Conecta el programa Red Carpet")]])
mn.rep([[L("Abre el programa e inicia sesión: se conecta solo. Si no, ve a 🔗 Conexión, copia el código y pégalo en el programa.")]], [[L("Abre el programa: se conecta solo. Si no, ve a 🔗 Conexión, copia el código y pégalo en el programa.")]])
mn.rep([[linkLabel(138, 36, 22, Color3.fromRGB(255, 210, 120)).Text = L("⚠️ Sin prueba gratuita o suscripción no se puede conectar.")
]], "")
-- sin pruebas limitadas ni carteles de compra
mn.rep([[	local left = player:GetAttribute("PruebasLeft") or 0
]], [[	local left = 1
]])
mn.rep([[	testInfo.Visible = not on
]], [[	testInfo.Visible = false
]])
mn.rep([[lockGui.Enabled = r == "trial_ended" or r == "no_plan" or r == "banned"]], [[lockGui.Enabled = false]])
mn.done()

-- ajustes sueltos del mapa
local map = workspace.MapaActivo.RedCarpet
if map:FindFirstChild("Entorno") then map.Entorno:Destroy() end
map.Pantalla.SurfaceLight.Face = Enum.NormalId.Back
local envs = game.ServerStorage.EscenariosRC
envs.cine:SetAttribute("NoScreen", true)
envs.pasarela:SetAttribute("Interior", true)
envs.pasarela:SetAttribute("NoScreen", true)
envs.museo:SetAttribute("Interior", false)
workspace:SetAttribute("Estilo", "minimal")
workspace:SetAttribute("Mapa", "RedCarpet")
game.StarterPlayer.StarterPlayerScripts.CameraController.Disabled = false
return table.concat(log, ", ")
