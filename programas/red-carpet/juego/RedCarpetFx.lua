-- Lo que da vida a la alfombra, todo en el cliente:
--  · flashes de los paparazzi (más cerca del que camina y muchos más en cinemático / sesión de fotos)
--  · los paparazzi giran siguiendo al que pasa y dan un respingo al disparar
--  · saludos variados (a un lado, al otro, beso, signo de paz...) con Motor6D.Transform: valen para cualquier avatar R15
--    (cuadrados, humanoides, pequeños...) sin depender de una animación
--  · fama: contador de seguidores con "+N" encima de los que pagaron su turno
--  · helicóptero con foco, planetas, reflectores y chispas de los escenarios
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local rng = Random.new()
local camera = workspace.CurrentCamera
local avatares = workspace:WaitForChild("Avatares")

-- ---------- flashes ----------
local pool = Instance.new("Folder")
pool.Name, pool.Parent = "Flashes", workspace
local POOL = 16
local bulbs, bulbI = {}, 0
for i = 1, POOL do
	local p = Instance.new("Part")
	p.Name, p.Size, p.Transparency, p.Anchored = "Flash", Vector3.one * 0.1, 1, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Parent = pool
	local star = Instance.new("ParticleEmitter")
	star.Name, star.Texture, star.Enabled, star.LightEmission, star.LightInfluence = "Estrella", "rbxasset://textures/particles/sparkles_main.dds", false, 1, 0
	star.Lifetime, star.Speed = NumberRange.new(0.12, 0.2), NumberRange.new(0)
	star.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(0.35, 4.6), NumberSequenceKeypoint.new(1, 0) })
	star.Color = ColorSequence.new(Color3.fromRGB(235, 240, 255))
	star.Rotation = NumberRange.new(0, 90)
	star.Parent = p
	local glow = star:Clone()
	glow.Name, glow.Texture = "Brillo", "rbxasset://textures/particles/fire_main.dds"
	glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0.4) })
	glow.Transparency = NumberSequence.new(0.2)
	glow.Parent = p
	local l = Instance.new("PointLight")
	l.Range, l.Brightness, l.Color, l.Enabled, l.Shadows = 14, 5, Color3.fromRGB(235, 240, 255), false, false
	l.Parent = p
	bulbs[i] = { p = p, star = star, glow = glow, light = l }
end
local lenses, figs = {}, {}
local function rebuild()
	table.clear(lenses)
	table.clear(figs)
	for _, p in ipairs(CS:GetTagged("RCFlash")) do
		if p:IsDescendantOf(workspace) then table.insert(lenses, p) end
	end
	for _, f in ipairs(CS:GetTagged("RCFig")) do
		if f:IsDescendantOf(workspace) and f.PrimaryPart then
			table.insert(figs, { m = f, base = f:GetPivot(), z = f.PrimaryPart.Position.Z, x = f.PrimaryPart.Position.X, yaw = 0, kick = 0 })
		end
	end
end
rebuild()
task.delay(3, rebuild)
local function fire(pos, big)
	bulbI = bulbI % POOL + 1
	local b = bulbs[bulbI]
	b.p.Position = pos
	b.star:Emit(1)
	b.glow:Emit(1)
	b.light.Brightness = big and 8 or 5
	b.light.Enabled = true
	task.delay(0.07, function() b.light.Enabled = false end)
end
local function focus()
	local id = workspace:GetAttribute("Cinematic")
	if id and id ~= "" then
		for _, m in ipairs(avatares:GetChildren()) do if m:GetAttribute("WalkId") == id then return m, true end end
	end
	local pid = workspace:GetAttribute("PhotoCine")
	if pid and pid ~= "" then
		for _, m in ipairs(avatares:GetChildren()) do if m:GetAttribute("PhotoId") == pid then return m, true end end
	end
	return nil, false
end
local lastFlash = 0
local function flashStep(now)
	if workspace:GetAttribute("FlashesOff") or #lenses == 0 then return end
	local star, cine = focus()
	local rate = cine and 16 or 7 -- flashes por segundo
	if now - lastFlash < 1 / rate then return end
	lastFlash = now
	-- junto a quien camina: elige varias lentes y se queda con una cercana a alguien (o a la estrella)
	local targetZ
	if star and star.PrimaryPart then targetZ = star.PrimaryPart.Position.Z
	else
		local list = avatares:GetChildren()
		local m = #list > 0 and list[rng:NextInteger(1, #list)]
		local r = m and m:FindFirstChild("HumanoidRootPart")
		targetZ = r and r.Position.Z
	end
	local best, bestD = nil, math.huge
	for _ = 1, 7 do
		local l = lenses[rng:NextInteger(1, #lenses)]
		if l.Parent then
			local d = targetZ and math.abs(l.Position.Z - targetZ) or rng:NextNumber()
			d += rng:NextNumber(0, 14)
			if d < bestD then best, bestD = l, d end
		end
	end
	if best then
		fire(best.Position, cine)
		local fig = best:FindFirstAncestor("Paparazzo")
		if fig then fig:SetAttribute("Kick", now) end
	end
end

-- los paparazzi siguen con la cámara al que pasa (solo los que están cerca, para que no pese)
local figI = 0
local function figStep(now)
	if #figs == 0 then return end
	local list = {}
	for _, m in ipairs(avatares:GetChildren()) do
		local r = m:FindFirstChild("HumanoidRootPart")
		if r then table.insert(list, r.Position) end
	end
	for _ = 1, 26 do
		figI = figI % #figs + 1
		local f = figs[figI]
		if f.m.Parent then
			local near
			for _, p in ipairs(list) do
				if math.abs(p.Z - f.z) < 22 and (not near or math.abs(p.Z - f.z) < math.abs(near.Z - f.z)) then near = p end
			end
			local want = 0
			if near then
				local to = (near - f.base.Position) * Vector3.new(1, 0, 1)
				if to.Magnitude > 1 then
					local l = f.base:VectorToObjectSpace(to.Unit)
					want = math.clamp(math.atan2(-l.X, -l.Z), -0.7, 0.7)
				end
			end
			f.yaw += (want - f.yaw) * 0.4
			local kick = f.m:GetAttribute("Kick") or 0
			local k = math.clamp(1 - (now - kick) / 0.2, 0, 1)
			if math.abs(f.yaw) > 0.005 or k > 0 or f.kicked then
				f.m:PivotTo(f.base * CFrame.Angles(0, f.yaw, 0) * CFrame.new(0, k * 0.1, k * 0.12) * CFrame.Angles(k * 0.05, 0, 0))
				f.kicked = k > 0
			end
		end
	end
end

-- ---------- saludos ----------
local ease = function(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local rad = math.rad
local A = CFrame.Angles
-- cada gesto: (t, s = lado 1/-1) -> { articulación = CFrame }. s = 1 mano derecha / mira a su derecha
local function arm(s) return s > 0 and "Right" or "Left" end
local GESTURES = {
	saludo = { dur = 2.2, f = function(t, s)
		local w = math.sin(t * 11) * rad(20)
		return { [arm(s) .. "Shoulder"] = A(0, 0, s * rad(150)) * A(0, 0, w), [arm(s) .. "Elbow"] = A(rad(32), 0, 0),
			Neck = A(rad(4), -s * rad(30), 0), Waist = A(0, -s * rad(14), 0) }
	end },
	saludoBajo = { dur = 1.8, f = function(t, s)
		local w = math.sin(t * 12) * rad(15)
		return { [arm(s) .. "Shoulder"] = A(rad(70), 0, s * rad(58)), [arm(s) .. "Elbow"] = A(rad(68), 0, 0) * A(0, 0, w),
			Neck = A(0, -s * rad(24), 0) }
	end },
	beso = { dur = 1.9, f = function(t, s)
		local out = ease((t - 0.9) / 0.35)
		return { [arm(s) .. "Shoulder"] = A(rad(112 - out * 28), 0, s * rad(-14 + out * 52)), [arm(s) .. "Elbow"] = A(rad(112 * (1 - out)), 0, 0),
			Neck = A(rad(-5), -s * rad(18), s * rad(5)) }
	end },
	paz = { dur = 1.9, f = function(t, s)
		return { [arm(s) .. "Shoulder"] = A(rad(112), 0, s * rad(22)), [arm(s) .. "Elbow"] = A(rad(96), 0, 0),
			Neck = A(0, -s * rad(12), -s * rad(14)), Waist = A(0, 0, -s * rad(5)) }
	end },
	brazos = { dur = 1.8, f = function(t, s)
		local w = math.sin(t * 8) * rad(10)
		return { RightShoulder = A(0, 0, rad(150) + w), LeftShoulder = A(0, 0, -rad(150) - w), RightElbow = A(rad(12), 0, 0), LeftElbow = A(rad(12), 0, 0), Neck = A(rad(-10), 0, 0) }
	end },
	cintura = { dur = 2, f = function(t, s)
		return { [arm(s) .. "Shoulder"] = A(rad(8), 0, s * rad(42)), [arm(s) .. "Elbow"] = A(rad(110), 0, 0),
			Neck = A(rad(-4), -s * rad(26), 0), Waist = A(0, s * rad(10), s * rad(5)) }
	end },
	apuntar = { dur = 1.5, f = function(t, s)
		return { [arm(s) .. "Shoulder"] = A(rad(96), 0, s * rad(14)), [arm(s) .. "Elbow"] = A(rad(6), 0, 0), Neck = A(0, -s * rad(10), 0) }
	end },
	giro = { dur = 1.25, f = function(t, s)
		return { Root = A(0, s * ease(t / 1.25) * math.pi * 2, 0), RightShoulder = A(0, 0, rad(38)), LeftShoulder = A(0, 0, -rad(38)) }
	end },
	pelo = { dur = 1.5, f = function(t, s)
		return { [arm(s) .. "Shoulder"] = A(rad(140), 0, s * rad(36)), [arm(s) .. "Elbow"] = A(rad(112), 0, 0), Neck = A(rad(-12), s * rad(16), s * rad(13)) }
	end },
}
local NAMES = {}
for k in pairs(GESTURES) do table.insert(NAMES, k) end
local POSES = { "cintura", "paz", "beso", "pelo", "apuntar", "brazos", "saludo" } -- sesión de fotos

local walkers = {} -- modelo -> estado
local function joints(m)
	local t = {}
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("Motor6D") then t[d.Name] = d end end
	return t
end
local function nextGesture(st, cine)
	local n
	repeat n = NAMES[rng:NextInteger(1, #NAMES)] until n ~= st.last
	st.last = n
	st.g = GESTURES[n]
	st.gt = os.clock()
	st.side = rng:NextInteger(0, 1) * 2 - 1
end
RunService.Stepped:Connect(function()
	local now = os.clock()
	for m, st in pairs(walkers) do
		if not m.Parent then walkers[m] = nil
		else
			if not st.j or not st.j.RightShoulder then st.j = joints(m) end
			local photo = m:GetAttribute("PhotoId")
			if not st.g and now >= st.next then
				if photo then
					st.pi = (st.pi or 0) + 1
					st.g, st.gt, st.side = GESTURES[POSES[(st.pi - 1) % #POSES + 1]], now, st.pi % 2 * 2 - 1
				else
					nextGesture(st)
				end
			end
			if st.g then
				local t = now - st.gt
				if t >= st.g.dur then
					st.g = nil
					st.next = now + (photo and 0.02 or rng:NextNumber(st.cine and 0.35 or 1.1, st.cine and 1.4 or 3.8))
				else
					local a = ease(t / 0.22) * ease((st.g.dur - t) / 0.26)
					for name, cf in pairs(st.g.f(t, st.side)) do
						local j = st.j[name]
						if j then j.Transform = j.Transform:Lerp(cf, a) end
					end
				end
			end
		end
	end
end)
local function track(m)
	if not m:IsA("Model") or walkers[m] then return end
	if m:GetAttribute("Giant") then return end
	task.wait(0.1)
	walkers[m] = { next = os.clock() + rng:NextNumber(0.4, 2.2), cine = m:GetAttribute("Cine") == true }
end
avatares.ChildAdded:Connect(track)
for _, m in ipairs(avatares:GetChildren()) do task.spawn(track, m) end

-- ---------- fama: seguidores ----------
local function short(n)
	if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
	if n >= 1000 then return string.format("%.1fK", n / 1000) end
	return tostring(math.floor(n))
end
local fameList = {}
local function fameStart(m)
	if not m:IsA("Model") then return end
	for _ = 1, 20 do
		if m:GetAttribute("FameGain") then break end
		task.wait(0.1)
	end
	local gain = m:GetAttribute("FameGain")
	local head = m:FindFirstChild("Head")
	if not gain or not head then return end
	local bb = Instance.new("BillboardGui")
	bb.Name, bb.Size, bb.StudsOffset, bb.LightInfluence, bb.AlwaysOnTop = "Fama", UDim2.new(6, 0, 3.2, 0), Vector3.new(0, 5.6, 0), 0, false
	local pill = Instance.new("Frame")
	pill.AnchorPoint, pill.Position, pill.Size, pill.BackgroundColor3, pill.BackgroundTransparency = Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), UDim2.fromScale(0.72, 0.28), Color3.fromRGB(26, 20, 42), 0.08
	pill.Parent = bb
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = Color3.fromRGB(255, 205, 80), 2, pill
	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency, txt.Size, txt.Font, txt.TextScaled, txt.TextColor3, txt.Text = 1, UDim2.fromScale(0.92, 0.9), Enum.Font.FredokaOne, true, Color3.fromRGB(255, 232, 150), ""
	txt.AnchorPoint, txt.Position, txt.Parent = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), pill
	bb.Parent = head
	fameList[m] = { t0 = os.clock(), start = m:GetAttribute("FameStart") or 0, gain = gain, dur = m:GetAttribute("FameDur") or 20, shown = -1, nextPop = 0, bb = bb, txt = txt, pill = pill }
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = pill
	TweenService:Create(sc, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	fameList[m].scale = sc
end
avatares.ChildAdded:Connect(fameStart)
local function pop(st, amount)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency, l.Font, l.TextScaled, l.TextColor3, l.Text = 1, Enum.Font.FredokaOne, true, Color3.fromRGB(120, 255, 170), "+" .. short(amount)
	l.TextStrokeTransparency, l.TextStrokeColor3 = 0, Color3.fromRGB(10, 50, 30)
	l.AnchorPoint, l.Size, l.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.42, 0.24), UDim2.fromScale(rng:NextNumber(0.2, 0.8), 0.6)
	l.Rotation = rng:NextNumber(-10, 10)
	l.Parent = st.bb
	TweenService:Create(l, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = l.Position - UDim2.fromScale(0, 0.6), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(l, 1)
	if st.scale then
		st.scale.Scale = 1.15
		TweenService:Create(st.scale, TweenInfo.new(0.22), { Scale = 1 }):Play()
	end
end
local function fameStep(now)
	for m, st in pairs(fameList) do
		if not m.Parent or workspace:GetAttribute("FameOff") then
			if st.bb then st.bb:Destroy() end
			fameList[m] = nil
		else
			local k = math.clamp((now - st.t0) / st.dur, 0, 1)
			-- crece cada vez más rápido: cuanto más rato en la alfombra, más seguidores
			local cur = st.start + st.gain * k * k
			if cur ~= st.shown then
				st.txt.Text = "👤 " .. short(cur)
				if now >= st.nextPop and k < 1 then
					st.nextPop = now + 0.42
					local d = math.floor(cur - (st.popAt or st.start))
					if d > 0 then pop(st, d) st.popAt = cur end
				end
				st.shown = cur
			end
		end
	end
end

-- ---------- sesión de fotos: pantalla en blanco a cada disparo y lluvia de flashes ----------
local whiteGui = Instance.new("ScreenGui")
whiteGui.Name, whiteGui.IgnoreGuiInset, whiteGui.ResetOnSpawn, whiteGui.DisplayOrder = "FlashPantalla", true, false, 4
whiteGui.Parent = player:WaitForChild("PlayerGui")
local white = Instance.new("Frame")
white.BackgroundColor3, white.BackgroundTransparency, white.Size, white.Parent = Color3.new(1, 1, 1), 1, UDim2.fromScale(1, 1), whiteGui
local lastShot = 0
local function photoStep(now)
	local id = workspace:GetAttribute("PhotoCine")
	if not id or id == "" then return end
	local s = workspace:FindFirstChild("SesionFotos")
	if now - lastShot < 0.17 or not s then return end
	lastShot = now
	local list = s:GetChildren()
	if #list == 0 then return end
	local m = list[rng:NextInteger(1, #list)]
	for _, d in ipairs(m:GetDescendants()) do
		if d.Name == "Flash" then fire(d.Position, true) break end
	end
	if rng:NextNumber() < 0.3 then
		white.BackgroundTransparency = 0.8
		TweenService:Create(white, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
	end
end

-- ---------- helicóptero con foco durante el cinemático ----------
local heli, beam, heliAngle
local function heliStep(now, dt)
	local star = focus()
	local want = star and star:FindFirstChild("HumanoidRootPart") and workspace:GetAttribute("Interior") ~= true and workspace:GetAttribute("Cinematic") ~= ""
	if want and not heli then
		local src = RS:FindFirstChild("RCModels") and RS.RCModels:FindFirstChild("Helicoptero")
		if src then
			heli = src:Clone()
			heli.Parent = workspace
			heliAngle = rng:NextNumber(0, 6.28)
			local a0 = Instance.new("Attachment")
			a0.Parent = heli.Faro
			local tip = Instance.new("Part")
			tip.Name, tip.Size, tip.Anchored, tip.Transparency, tip.CanCollide, tip.CanQuery = "Punta", Vector3.one, true, 1, false, false
			tip.Parent = heli
			local a1 = Instance.new("Attachment")
			a1.Parent = tip
			beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1, beam.FaceCamera, beam.LightEmission, beam.Width0, beam.Width1, beam.Segments = a0, a1, true, 1, 1, 9, 4
			beam.Color = ColorSequence.new(Color3.fromRGB(255, 245, 215))
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.9) })
			beam.Parent = heli
		end
	elseif not want and heli then
		heli:Destroy()
		heli, beam = nil, nil
	end
	if heli and want then
		local p = star.HumanoidRootPart.Position
		heliAngle += dt * 0.32
		local pos = p + Vector3.new(math.sin(heliAngle) * 40, 66, math.cos(heliAngle) * 40 - 12)
		local dir = (p - pos) * Vector3.new(1, 0, 1)
		local cf = CFrame.lookAt(pos, pos + (dir.Magnitude > 1 and dir.Unit or Vector3.zAxis)) * CFrame.Angles(math.rad(-9), 0, math.rad(6))
		heli:PivotTo(cf)
		for _, pa in ipairs(heli.Rotor:GetChildren()) do
			pa.CFrame = cf * CFrame.new(0, 4.3, 0) * CFrame.Angles(0, now * 26 + (pa.Size.X > 5 and 0 or 0), 0)
		end
		heli.Punta.Position = p
	end
end

-- ---------- escenarios animados ----------
local anim = { rocks = {}, spin = {}, spark = {}, sweep = {} }
local function scanEnv()
	anim = { rocks = {}, spin = {}, spark = {}, sweep = {} }
	local env = workspace.MapaActivo.RedCarpet:FindFirstChild("Entorno")
	if not env then return end
	for _, d in ipairs(env:GetDescendants()) do
		if d:IsA("BasePart") then
			if d:GetAttribute("Roca") then table.insert(anim.rocks, { p = d, v = d:GetAttribute("Roca"), cf = d.CFrame }) end
			if CS:HasTag(d, "RCSpark") then table.insert(anim.spark, { p = d, s = rng:NextNumber(1.5, 4), ph = rng:NextNumber(0, 6) }) end
			if d:GetAttribute("Barre") then table.insert(anim.sweep, d) end
		end
	end
end
workspace:GetAttributeChangedSignal("Estilo"):Connect(function() task.wait(0.3) scanEnv() end)
task.delay(1, scanEnv)
local function envStep(now)
	for _, r in ipairs(anim.rocks) do
		r.p.CFrame = r.cf * CFrame.new(0, math.sin(now * r.v + r.v * 20) * 1.8, 0) * CFrame.Angles(now * r.v * 0.5, now * r.v, 0)
	end
	for _, s in ipairs(anim.spark) do
		local k = (math.sin(now * s.s + s.ph) + 1) / 2
		s.p.Size = Vector3.one * (0.3 + k * 0.5)
		s.p.Transparency = 0.7 - k * 0.7
	end
	for i, b in ipairs(anim.sweep) do
		local tip = b.Parent:GetChildren()
		local beam = b:FindFirstChildOfClass("Beam")
		if beam and beam.Attachment1 then
			local a = math.sin(now * 0.45 + i * 1.7) * 75
			beam.Attachment1.Parent.Position = b.Position + Vector3.new(a, 115, -40)
		end
	end
end

local lastT = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = now - lastT
	lastT = now
	flashStep(now)
	figStep(now)
	fameStep(now)
	photoStep(now)
	heliStep(now, dt)
	envStep(now)
end)
