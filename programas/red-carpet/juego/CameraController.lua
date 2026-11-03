-- Cámara del directo (atributo del jugador CamMode):
--   PRESETS (boceto por defecto, centro, cerca, izquierda, derecha, alta) fijas, quietas
--   "follow"   sigue de frente al último que camina
--   "libre"    se mueve con WASD + Q/E, gira con clic derecho, Shift = rápido
--   "off"      cámara normal de Roblox
-- Cinemático (workspace.Cinematic = WalkId): un director corta entre tomas distintas cada vez: frente, lateral, espalda,
-- suelo, cenital, paparazzi, dron, helicóptero (de lejos con zoom enorme) y cámaras de seguridad. Nunca el mismo orden y no
-- siempre las mismas: a veces no hay helicóptero, a veces no hay seguridad. Al acabar vuelve suave a donde estaba.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local CS = game:GetService("CollectionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
if player:GetAttribute("CamMode") == nil then player:SetAttribute("CamMode", "boceto") end

local map = workspace:WaitForChild("MapaActivo"):WaitForChild("RedCarpet")
local CAM, LOOK = map:WaitForChild("Camara").Position, map:WaitForChild("MiraCamara").Position
local CCTV = map:WaitForChild("Seguridad")
local BLEND = 0.8
local PRESETS = { -- posición, a dónde mira, FOV
	boceto = { CAM, LOOK, 70 },       -- el círculo morado del boceto: desde un lado de la gente hacia la alfombra
	centro = { Vector3.new(0, 7, 42), Vector3.new(0, 5, -60), 58 },
	cerca = { Vector3.new(0, 4.5, 26), Vector3.new(0, 3, -10), 60 },
	izquierda = { Vector3.new(-9, 6.5, 40), Vector3.new(2, 3, -30), 62 },
	derecha = { Vector3.new(9, 6.5, 40), Vector3.new(-2, 3, -30), 62 },
	alta = { Vector3.new(0, 30, 48), Vector3.new(0, 0, -30), 62 },
	salida = { Vector3.new(-5, 7, 30), Vector3.new(0, 4, 60), 60 }, -- la puerta del final
}

-- zoom de las cámaras fijas: rueda del ratón (sin el cursor sobre el menú) o botones del menú, atributo CamZoom del jugador
local zoomNow = 1
if player:GetAttribute("CamZoom") == nil then player:SetAttribute("CamZoom", 1) end
UIS.InputChanged:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
	local mode = player:GetAttribute("CamMode")
	if mode == "off" then return end
	player:SetAttribute("CamZoom", math.clamp((player:GetAttribute("CamZoom") or 1) * (input.Position.Z > 0 and 1.12 or 1 / 1.12), 0.6, 6))
end)
local function Z(f) return math.clamp(f / zoomNow, 5, 100) end

-- cámara libre
local FREE_SPEED = 16
local freePos, yaw, pitch = nil, 0, 0
local keys = {}
local FREE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Space }
local function freeAction(_, state, input)
	keys[input.KeyCode] = state == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink -- que el personaje (invisible) no camine
end
local function setFree(on)
	table.clear(keys)
	if on then
		CAS:BindActionAtPriority("CamaraLibre", freeAction, false, Enum.ContextActionPriority.High.Value, table.unpack(FREE_KEYS))
		freePos = camera.CFrame.Position -- empieza desde donde está la cámara
		local x, y = camera.CFrame:ToOrientation()
		pitch, yaw = x, y
	else
		CAS:UnbindAction("CamaraLibre")
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
end
local function freeStep(dt)
	if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		local d = UIS:GetMouseDelta()
		yaw -= d.X * 0.004
		pitch = math.clamp(pitch - d.Y * 0.004, -1.4, 1.4)
	else
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
	local rot = CFrame.fromOrientation(pitch, yaw, 0)
	local k = function(c) return keys[c] and 1 or 0 end
	local move = Vector3.new(k(Enum.KeyCode.D) - k(Enum.KeyCode.A), k(Enum.KeyCode.E) - k(Enum.KeyCode.Q), k(Enum.KeyCode.S) - k(Enum.KeyCode.W))
	local speed = FREE_SPEED * (UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1)
	freePos += rot:VectorToWorldSpace(move) * speed * dt
	return CFrame.new(freePos) * rot
end

local dof = Instance.new("DepthOfFieldEffect")
dof.Name = "Cinematico"; dof.Enabled = false; dof.FarIntensity = 0.45; dof.FocusDistance = 13; dof.InFocusRadius = 7; dof.NearIntensity = 0
dof.Parent = Lighting
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "CinematicoTinte"; tint.Enabled = false; tint.TintColor = Color3.fromRGB(235, 240, 255); tint.Contrast = 0.08
tint.Parent = Lighting
local cctvFx = Instance.new("ColorCorrectionEffect")
cctvFx.Name = "SeguridadTinte"; cctvFx.Enabled = false; cctvFx.Saturation = -0.85; cctvFx.Contrast = 0.22; cctvFx.Brightness = 0.02; cctvFx.TintColor = Color3.fromRGB(205, 235, 215)
cctvFx.Parent = Lighting

-- ---------- pantallas superpuestas: seguridad y helicóptero ----------
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder, gui.Enabled = "CamaraHud", false, true, 5, false
gui.Parent = player:WaitForChild("PlayerGui")
local function lab(parent, txt, pos, anchor, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.Font, l.Text, l.TextColor3 = 1, Enum.Font.Code, txt, color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency, l.TextScaled, l.Size, l.Position, l.AnchorPoint = 0.4, true, size, pos, anchor or Vector2.zero
	l.Parent = parent
	return l
end
local secHud = Instance.new("Frame")
secHud.BackgroundTransparency, secHud.Size, secHud.Parent = 1, UDim2.fromScale(1, 1), gui
local camLbl = lab(secHud, "CAM 01", UDim2.fromScale(0.03, 0.04), nil, UDim2.fromScale(0.26, 0.05))
camLbl.TextXAlignment = Enum.TextXAlignment.Left
local recLbl = lab(secHud, "● REC", UDim2.fromScale(0.97, 0.04), Vector2.new(1, 0), UDim2.fromScale(0.16, 0.05), Color3.fromRGB(255, 60, 60))
recLbl.TextXAlignment = Enum.TextXAlignment.Right
local timeLbl = lab(secHud, "", UDim2.fromScale(0.03, 0.93), nil, UDim2.fromScale(0.4, 0.04))
timeLbl.TextXAlignment = Enum.TextXAlignment.Left
local zoomLbl = lab(secHud, "x1.0", UDim2.fromScale(0.97, 0.93), Vector2.new(1, 0), UDim2.fromScale(0.16, 0.04))
zoomLbl.TextXAlignment = Enum.TextXAlignment.Right
for i = 0, 35 do -- líneas de la imagen de vigilancia
	local f = Instance.new("Frame")
	f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel = Color3.new(0, 0, 0), 0.88, 0
	f.Size, f.Position, f.Parent = UDim2.new(1, 0, 0, 2), UDim2.fromScale(0, i / 36), secHud
end
local box = Instance.new("Frame") -- recuadro de seguimiento
box.BackgroundTransparency, box.AnchorPoint, box.Position, box.Size, box.Parent = 1, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.24, 0.48), secHud
local boxS = Instance.new("UIStroke")
boxS.Color, boxS.Thickness, boxS.Transparency, boxS.Parent = Color3.fromRGB(120, 255, 150), 1.5, 0.25, box
local heliHud = Instance.new("Frame")
heliHud.BackgroundTransparency, heliHud.Size, heliHud.Parent = 1, UDim2.fromScale(1, 1), gui
for _, e in ipairs({ { 0, Vector2.zero }, { 1, Vector2.new(0, 1) } }) do
	local bar = Instance.new("Frame") -- franjas de cine
	bar.BackgroundColor3, bar.BorderSizePixel, bar.Size, bar.AnchorPoint, bar.Position = Color3.new(), 0, UDim2.fromScale(1, 0.1), e[2], UDim2.fromScale(0, e[1])
	bar.Parent = heliHud
end
local heliLbl = lab(heliHud, "AERIAL LIVE", UDim2.fromScale(0.03, 0.115), nil, UDim2.fromScale(0.26, 0.04), Color3.fromRGB(255, 225, 150))
heliLbl.TextXAlignment = Enum.TextXAlignment.Left
local cross = lab(heliHud, "+", UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), UDim2.fromScale(0.05, 0.08), Color3.fromRGB(255, 225, 150))
cross.TextTransparency = 0.45

local function setHud(kind)
	gui.Enabled = kind ~= nil
	secHud.Visible, heliHud.Visible = kind == "seguridad", kind == "heli"
	cctvFx.Enabled = kind == "seguridad"
	workspace:SetAttribute("CamaraHud", kind or "")
end

local function setInvisible()
	local character = player.Character
	if not character then return end
	for _, o in ipairs(character:GetDescendants()) do
		if o:IsA("BasePart") then o.LocalTransparencyModifier = 1 end
		if o:IsA("Decal") then o.Transparency = 1 end
	end
end
player.CharacterAdded:Connect(function() task.wait(1) setInvisible() end)
player:GetAttributeChangedSignal("Invisible"):Connect(setInvisible)

local function byAttr(attr, value)
	local f = workspace:FindFirstChild("Avatares")
	if not value or value == "" or not f then return nil end
	for _, m in ipairs(f:GetChildren()) do
		if m:GetAttribute(attr) == value then return m:FindFirstChild("HumanoidRootPart") end
	end
end
local function byId(id) return byAttr("WalkId", id) end
local function giantRoot() return byAttr("GiantId", workspace:GetAttribute("GiantCine")) end
local function photoRoot() return byAttr("PhotoId", workspace:GetAttribute("PhotoCine")) end
local function bodyHeight(root)
	local _, size = root.Parent:GetBoundingBox()
	return math.clamp(size.Y, 2.5, 30)
end

-- ---------- los paparazzi que tapan la toma se ocultan solo para esta cámara ----------
local hiddenFigs = {}
local function hideNear(pos, radius)
	for fig in pairs(hiddenFigs) do
		for _, p in ipairs(fig:GetDescendants()) do if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end end
	end
	table.clear(hiddenFigs)
	if not pos then return end
	for _, fig in ipairs(CS:GetTagged("RCFig")) do
		local t = fig.PrimaryPart
		if t and fig:IsDescendantOf(workspace) and (t.Position - pos).Magnitude < radius then
			hiddenFigs[fig] = true
			for _, p in ipairs(fig:GetDescendants()) do if p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end end
		end
	end
end

-- ---------- el director ----------
local rng = Random.new()
local function clampX(v, m) return Vector3.new(math.clamp(v.X, -m, m), v.Y, v.Z) end
local function pick(t) return t[rng:NextInteger(1, #t)] end
local SHOT = {}
function SHOT.frente(s, root, t)
	local H = bodyHeight(root)
	local a = math.rad(s.side * 28) * math.sin(t * 0.7 + s.seed)
	local d = math.max(8, H * 2.1)
	local p = root.Position
	local c = clampX(p + CFrame.Angles(0, a, 0):VectorToWorldSpace(Vector3.zAxis) * d + Vector3.new(0, H * 0.18, 0), 8.6)
	return CFrame.lookAt(c, p + Vector3.new(0, H * 0.06, 0)), 52, d
end
function SHOT.lado(s, root, t)
	local H = bodyHeight(root)
	local p = root.Position
	local c = Vector3.new(s.side * 8.7, p.Y + H * 0.1, p.Z + 2.5 + t * 0.2)
	return CFrame.lookAt(c, p + Vector3.new(0, H * 0.04, 0)), 56, (c - p).Magnitude
end
function SHOT.espalda(s, root, t)
	local H = bodyHeight(root)
	local p = root.Position
	local c = clampX(p + Vector3.new(s.side * 2.5, H * 0.55, -math.max(8, H * 2)), 8.6)
	return CFrame.lookAt(c, p + Vector3.new(0, H * 0.25, 9)), 60, 9
end
function SHOT.suelo(s, root, t)
	local H = bodyHeight(root)
	local p = root.Position
	local c = clampX(p + Vector3.new(s.side * 2.2, 0, math.max(6.5, H * 1.7)), 8.6)
	c = Vector3.new(c.X, 0.45, c.Z)
	return CFrame.lookAt(c, p + Vector3.new(0, H * 0.28, 0)), 64, 7
end
function SHOT.cenital(s, root, t)
	local p = root.Position
	local cf = CFrame.new(p + Vector3.new(0, 24 - t * 1.2, 0.01)) * CFrame.Angles(-math.pi / 2, 0, s.seed + t * 0.14 * s.side)
	return cf, 44, 22
end
function SHOT.paparazzi(s, root, t, dt)
	local H = bodyHeight(root)
	s.z = (s.z or (root.Position.Z + 9)) + (root.Position.Z + 3 - (s.z or root.Position.Z + 9)) * math.min(1, dt * 0.9)
	local shake = Vector3.new(math.noise(t * 2.1, s.seed) * 0.35, math.noise(t * 2.4, s.seed + 9) * 0.3, 0)
	local c = Vector3.new(s.side * 11.8, 5.2, s.z) + shake
	return CFrame.lookAt(c, root.Position + Vector3.new(0, H * 0.1, 0) + shake * 0.4), 34, (c - root.Position).Magnitude
end
function SHOT.dron(s, root, t)
	local H = bodyHeight(root)
	local p = root.Position
	local a = s.seed + t * 0.65 * s.side
	local r = 15 + t * 1.5
	local c = p + Vector3.new(math.sin(a) * math.min(r, 9), 8 + t * 2, math.cos(a) * r)
	return CFrame.lookAt(c, p + Vector3.new(0, H * 0.1, 0)), 54, r
end
-- de muy lejos y muy alto, como un helicóptero con teleobjetivo: empieza abierto y hace un zoom increíble hasta el personaje
function SHOT.heli(s, root, t, dt)
	local H = bodyHeight(root)
	local interior = workspace:GetAttribute("Interior") == true
	s.h = s.h or (interior and 28 or rng:NextNumber(85, 135))
	s.dx = s.dx or (interior and rng:NextNumber(4, 8) or rng:NextNumber(10, 28)) * s.side
	s.dz = s.dz or (interior and 58 or rng:NextNumber(60, 120)) * s.front
	local p = root.Position
	-- el helicóptero se mueve despacio con su propio retraso; la vista va con vibración
	s.pos = s.pos or Vector3.new(s.dx, s.h, math.max(p.Z + s.dz, -98))
	s.pos += Vector3.new(s.side * dt * 1.4, 0, dt * 7)
	local d = (s.pos - p).Magnitude
	local close = 2 * math.deg(math.atan(H * 1.6 / 2 / d))
	local k = math.clamp((t - s.wide) / s.zoom, 0, 1)
	k = k * k * (3 - 2 * k)
	local fov = 62 + (close - 62) * k
	local amp = 0.08 + (d / 100) * 0.05
	local aim = p + Vector3.new(math.noise(t * 1.6, s.seed) * amp * 3, H * 0.04 + math.noise(t * 1.9, s.seed + 5) * amp * 3, 0)
	return CFrame.lookAt(s.pos, aim), math.max(1.5, fov), d, "heli"
end
-- cámara de seguridad real del mapa: gira a saltos, hace zoom digital por pasos
function SHOT.seguridad(s, root, t, dt)
	local H = bodyHeight(root)
	if not s.cam then
		local list = {}
		for _, g in ipairs(CCTV:GetChildren()) do
			local o = g:FindFirstChild("Ojo")
			if o then
				-- solo cámaras que le ven: ni el público ni el propio poste cuentan, un muro del escenario sí
				local ray = RaycastParams.new()
				ray.FilterType = Enum.RaycastFilterType.Exclude
				ray.FilterDescendantsInstances = { CCTV, workspace:FindFirstChild("Avatares"), map:FindFirstChild("Paparazzi"), map:FindFirstChild("Prensa") }
				local clear = not workspace:Raycast(o.Position, root.Position - o.Position, ray)
				if clear then table.insert(list, { o = o, d = (o.Position - root.Position).Magnitude, n = o:GetAttribute("Num") }) end
			end
		end
		if #list == 0 then -- ninguna le ve: la más cercana
			for _, g in ipairs(CCTV:GetChildren()) do
				local o = g:FindFirstChild("Ojo")
				if o then table.insert(list, { o = o, d = (o.Position - root.Position).Magnitude, n = o:GetAttribute("Num") }) end
			end
		end
		-- cualquiera de las que le ven, cerca o lejos; la anterior solo si no hay otra
		s.cam = list[rng:NextInteger(1, #list)]
		for _ = 1, 4 do
			if s.cam.n ~= CCTV:GetAttribute("Ultima") then break end
			s.cam = list[rng:NextInteger(1, #list)]
		end
		CCTV:SetAttribute("Ultima", s.cam.n)
		s.aim = root.Position
		s.next = 0
	end
	local pos = s.cam.o.Position
	if t >= s.next then -- servo: alcanza al personaje a tirones
		s.next = t + 0.09
		s.aim = s.aim:Lerp(root.Position + Vector3.new(0, H * 0.1, 0), 0.5)
	end
	local d = (pos - root.Position).Magnitude
	local close = 2 * math.deg(math.atan(H * 1.9 / 2 / d))
	local step = math.clamp(math.floor(t / 0.9), 0, 3) / 3
	local fov = 62 + (close - 62) * step
	camLbl.Text = "CAM 0" .. s.cam.n .. "  ·  RED CARPET"
	zoomLbl.Text = string.format("x%.1f", 62 / fov)
	timeLbl.Text = os.date("%d/%m/%Y  %H:%M:%S")
	recLbl.TextTransparency = (os.clock() % 1 < 0.5) and 0 or 0.8
	return CFrame.lookAt(pos, s.aim), fov, d, "seguridad"
end

local function newShot(name)
	return { name = name, side = rng:NextInteger(0, 1) * 2 - 1, front = rng:NextNumber() < 0.75 and 1 or -1, seed = rng:NextNumber(0, 6.28), t0 = os.clock(),
		wide = rng:NextNumber(0.5, 1.1), zoom = rng:NextNumber(1.4, 2.4) }
end
-- plan: entre 3 y 5 tomas; helicóptero y seguridad no salen siempre, y tampoco el orden se repite
local lastPlan = ""
local function makePlan(total)
	local dyn = workspace:GetAttribute("DynCamOff") ~= true
	if not dyn then return { { name = "frente", dur = total } } end
	for _ = 1, 8 do
		local bag = { "frente", "lado", "espalda", "suelo", "cenital", "paparazzi", "dron" }
		local plan, used = {}, 0
		local specials = {}
		if rng:NextNumber() < 0.6 then table.insert(specials, { name = "heli", dur = rng:NextNumber(3.6, 4.8) }) end
		if rng:NextNumber() < 0.5 then table.insert(specials, { name = "seguridad", dur = rng:NextNumber(3.2, 4.2) }) end
		for _, s in ipairs(specials) do table.insert(plan, s) used += s.dur end
		while used < total do
			local n = table.remove(bag, rng:NextInteger(1, #bag))
			local d = rng:NextNumber(2.2, 3.6)
			table.insert(plan, { name = n, dur = d })
			used += d
			if #bag == 0 then break end
		end
		for i = #plan, 2, -1 do local j = rng:NextInteger(1, i) plan[i], plan[j] = plan[j], plan[i] end
		if plan[1].name == "heli" or plan[1].name == "seguridad" then -- que entre viéndole la cara
			table.insert(plan, 1, { name = pick({ "frente", "lado" }), dur = 2.2 })
		end
		local sig = ""
		for _, p in ipairs(plan) do sig ..= p.name .. "," end
		if sig ~= lastPlan then lastPlan = sig return plan end
	end
	return { { name = "frente", dur = total } }
end

-- sesión de fotos: cortes rápidos entre los fotógrafos que le rodean
local photoShots = { "hombro", "orbita", "suelo", "hombro", "cara", "orbita" }
local function photoShot(root, t, n)
	local p, H = root.Position, bodyHeight(root)
	local kind = photoShots[n % #photoShots + 1]
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	if kind == "hombro" then -- por encima del hombro de un fotógrafo
		local f = workspace:FindFirstChild("SesionFotos")
		local list = f and f:GetChildren() or {}
		local m = #list > 0 and list[n % #list + 1]
		if m and m.PrimaryPart then
			local q = m.PrimaryPart.CFrame
			local c = q * CFrame.new(1.8, 2.3, 3.9)
			return CFrame.lookAt(c.Position, p + Vector3.new(0, H * 0.12, 0)), 46
		end
	elseif kind == "suelo" then
		return CFrame.lookAt(p + look * 7 + right * 2 + Vector3.new(0, -p.Y + 0.5, 0), p + Vector3.new(0, H * 0.25, 0)), 60
	elseif kind == "cara" then
		return CFrame.lookAt(p + look * (H * 0.9) + right * 0.6 + Vector3.new(0, H * 0.3, 0), p + Vector3.new(0, H * 0.3, 0)), 42
	end
	local a = t * 0.8 + n
	return CFrame.lookAt(p + Vector3.new(math.sin(a) * 11, 3.2, math.cos(a) * 11), p + Vector3.new(0, H * 0.08, 0)), 50
end

-- modo fiesta: planos que van cambiando
local PARTY_SHOT = 3.5
local PARTY_SHOTS = {
	{ Vector3.new(0, 2, 8), Vector3.new(0, 7, -40), 62 },
	"fiestero",
	{ Vector3.new(-9, 16, -2), Vector3.new(0, 1, -40), 60 },
	"orbita",
	"fiestero",
	{ Vector3.new(9, 16, -2), Vector3.new(0, 1, -40), 60 },
	{ Vector3.new(0, 34, -6), Vector3.new(0, 0, -36), 72 },
}
local function fiestero(n)
	local f = workspace:FindFirstChild("Fiesteros")
	local list = f and f:GetChildren() or {}
	if #list == 0 then return nil end
	return list[n % #list + 1]:FindFirstChild("HumanoidRootPart")
end

local blend, target, lastMode, shotKey, giantStart = 1, nil, nil, nil, 0
local plan, planI, shot, megaCut, photoN, photoCut, photoHide = nil, 0, nil, false, 0, 0, 0
local function nextShot()
	planI += 1
	if not plan or planI > #plan then plan, planI = makePlan(5), 1 end
	shot = newShot(plan[planI].name)
	shot.dur = plan[planI].dur
	hideNear((shot.name == "paparazzi" or shot.name == "lado") and Vector3.new(shot.side * 12, 5, 0) or nil, 0)
	setHud(nil)
end

RunService.RenderStepped:Connect(function(dt)
	local mode = player:GetAttribute("CamMode")
	if mode ~= lastMode then
		if lastMode == "libre" or mode == "libre" then setFree(mode == "libre") end
		if lastMode then blend = 0 end -- al cambiar de posición, pasa suave
		lastMode = mode
	end
	if (workspace:GetAttribute("MegaShow") or "") ~= "" then -- manda MegaShowClient; sin el desenfoque del cinemático
		megaCut, dof.Enabled, tint.Enabled = true, false, false
		setHud(nil)
		hideNear(nil)
		return
	end
	local root = byId(workspace:GetAttribute("Cinematic"))
	local giant = giantRoot()
	local photo = photoRoot()
	local party = workspace:GetAttribute("Party") == true
	local tick = math.floor(os.clock() / PARTY_SHOT)
	local pshot = party and tick % #PARTY_SHOTS + 1 or 0
	local key = photo and "foto" or giant and "g" or root and "c" or party and ("p" .. pshot) or "m"
	if key ~= shotKey then -- cambia de plano: transición suave
		if shotKey then blend = 0 end
		if key == "g" or key == "foto" then giantStart = os.clock() photoN, photoCut = 0, os.clock() end
		shotKey = key
		if key ~= "c" then setHud(nil) hideNear(nil) end
	end
	local anyCine = root ~= nil or giant ~= nil or photo ~= nil
	dof.Enabled, tint.Enabled = anyCine, anyCine
	if mode == "off" and not anyCine and not party then
		if camera.CameraType ~= Enum.CameraType.Custom then camera.CameraType = Enum.CameraType.Custom end
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	if root ~= target then -- empieza o termina un cinemático
		target, blend = root, root and 1 or 0
		if root then
			plan, planI = makePlan(root.Parent:GetAttribute("CineDur") or 12.5), 0
			nextShot()
		else
			plan, shot = nil, nil
			setHud(nil)
			hideNear(nil)
		end
	end
	blend = megaCut and 1 or math.min(1, blend + dt / BLEND)
	megaCut = false
	local desired, fov, focus
	if photo then
		if os.clock() - photoCut > 1.35 then photoN += 1 photoCut = os.clock() blend = 1 end
		desired, fov = photoShot(photo, os.clock() - giantStart, photoN)
		dof.FocusDistance = (desired.Position - photo.Position).Magnitude
		-- los fotógrafos pegados a la cámara no tapan la toma
		local sesion = workspace:FindFirstChild("SesionFotos")
		if sesion and os.clock() - photoHide > 0.2 then
			photoHide = os.clock()
			for _, m in ipairs(sesion:GetChildren()) do
				local near = (m:GetPivot().Position * Vector3.new(1, 0, 1) - desired.Position * Vector3.new(1, 0, 1)).Magnitude < 9
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then d.LocalTransparencyModifier = near and 1 or 0 end
				end
			end
		end
	elseif giant then
		-- gira despacio alrededor del gigante, empezando de frente
		local a = (os.clock() - giantStart) * 0.45
		local p = giant.Position
		local H = bodyHeight(giant)
		local c = p + Vector3.new(math.sin(a) * H * 1.5, H * 0.25, math.cos(a) * H * 1.5)
		desired, fov = CFrame.lookAt(c, p + Vector3.new(0, H * 0.15, 0)), 62
		dof.FocusDistance = H * 1.5
	elseif root then
		if shot and os.clock() - shot.t0 > shot.dur then nextShot() end
		local kind
		desired, fov, focus, kind = SHOT[shot.name](shot, root, os.clock() - shot.t0, dt)
		setHud(kind)
		dof.Enabled, dof.FocusDistance = kind == nil, focus or 13
		tint.Enabled = kind ~= "seguridad"
		blend = 1 -- corte seco entre tomas
	elseif party then
		local s = PARTY_SHOTS[pshot]
		local fr = s == "fiestero" and fiestero(math.floor(tick / #PARTY_SHOTS) * 2 + (pshot == 2 and 0 or 1))
		if fr then
			local t = os.clock() % PARTY_SHOT
			local p = fr.Position
			local c = p + fr.CFrame.LookVector * (9 - t * 0.6) + fr.CFrame.RightVector * 2.5 + Vector3.new(0, 1.2, 0)
			desired, fov = CFrame.lookAt(c, p + Vector3.new(0, 0.8, 0)), 52
		elseif s == "orbita" or s == "fiestero" then
			local a = os.clock() * 0.5
			desired, fov = CFrame.lookAt(Vector3.new(math.sin(a) * 8.5, 7, -26 + math.cos(a) * 26), Vector3.new(0, 2, -26)), 65
		else
			desired, fov = CFrame.lookAt(s[1], s[2]), s[3]
		end
		if mode == "libre" then freeStep(dt) end
	elseif mode == "libre" then
		desired, fov = freeStep(dt), Z(70) -- durante el cinemático no se mueve: al acabar vuelve aquí
	elseif type(mode) == "string" and mode:sub(1, 4) == "slot" and typeof(player:GetAttribute("CamSlot" .. mode:sub(5))) == "CFrame" then
		desired, fov = player:GetAttribute("CamSlot" .. mode:sub(5)), Z(70)
	elseif PRESETS[mode] then
		local p = PRESETS[mode]
		desired, fov = CFrame.lookAt(p[1], p[2]), Z(p[3])
	else
		fov = Z(70)
		local w = mode == "follow" and byId(workspace:GetAttribute("LatestWalker"))
		if w then
			local p = w.Position
			desired = CFrame.lookAt(Vector3.new(p.X * 0.5, 7, math.clamp(p.Z + 18, -80, CAM.Z)), p + Vector3.new(0, 1.5, 0))
		else
			desired = CFrame.lookAt(CAM, LOOK)
		end
	end
	zoomNow += ((player:GetAttribute("CamZoom") or 1) - zoomNow) * math.min(1, dt * 9)
	if blend < 1 then
		local k = blend * blend
		camera.CFrame = camera.CFrame:Lerp(desired, k)
		camera.FieldOfView += (fov - camera.FieldOfView) * k
	else
		camera.CFrame, camera.FieldOfView = desired, fov
	end
	-- oculta a los paparazzi pegados a la cámara en las tomas a pie de valla
	if shot and root and (shot.name == "paparazzi" or shot.name == "lado") then
		if not shot.hideAt or os.clock() - shot.hideAt > 0.5 then
			shot.hideAt = os.clock()
			hideNear(camera.CFrame.Position, 7)
		end
	end
end)
