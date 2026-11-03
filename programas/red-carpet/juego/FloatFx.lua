-- Paseo flotante: el que tiene FloatId camina flotando por la alfombra (lo sube el servidor con HipHeight) rodeado de efectos:
-- alas de luz, orbes con estela, anillos que se expanden por el suelo, haz de luz desde arriba, lluvia de estrellas y pétalos.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local COLORS = { Color3.fromRGB(150, 110, 255), Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 120, 220), Color3.fromRGB(255, 225, 120) }
local cc = Instance.new("ColorCorrectionEffect")
cc.Name, cc.Enabled, cc.Parent = "LevitacionFx", false, Lighting

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	return p
end
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightEmission, e.LightInfluence = 1, 0
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end
local active = {}

local function start(model)
	local root = model:WaitForChild("HumanoidRootPart", 3)
	if not root or active[model] then return end
	local rig = Instance.new("Folder")
	rig.Name = "Levitacion"
	local a = Instance.new("Attachment") a.Parent = root
	local sparks = emitter(a, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 55, Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1, 4),
		SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(COLORS[2], COLORS[3]), Acceleration = Vector3.new(0, -4, 0) })
	local dust = emitter(a, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 22, Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(0.2, 1),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }), Color = ColorSequence.new(COLORS[4]), Acceleration = Vector3.new(0, -3, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180) })
	-- haz de luz desde arriba
	local sky = part({ Name = "Cielo", Size = Vector3.one, Transparency = 1, Parent = rig })
	local s0 = Instance.new("Attachment") s0.Parent = sky
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1, beam.FaceCamera, beam.LightEmission, beam.Width0, beam.Width1, beam.Segments = s0, a, true, 1, 12, 5, 6
	beam.Color = ColorSequence.new(COLORS[1], COLORS[2])
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.92), NumberSequenceKeypoint.new(1, 0.55) })
	beam.Parent = sky
	-- orbes con estela
	local orbs = {}
	for i = 1, 8 do
		local o = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, Color = COLORS[(i - 1) % 4 + 1], Parent = rig })
		local t0, t1 = Instance.new("Attachment"), Instance.new("Attachment")
		t0.Position, t1.Position = Vector3.new(0, 0.28, 0), Vector3.new(0, -0.28, 0)
		t0.Parent, t1.Parent = o, o
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1, tr.Lifetime, tr.LightEmission, tr.FaceCamera = t0, t1, 0.55, 1, true
		tr.Color = ColorSequence.new(o.Color)
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		tr.Parent = o
		orbs[i] = o
	end
	-- alas de luz (plumas que se abren y cierran)
	local wings = {}
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 6 do
			table.insert(wings, { side = side, i = i, p = part({ Size = Vector3.new(0.14, 3.4 - i * 0.28, 0.75), Color = COLORS[2]:Lerp(COLORS[3], i / 6), Transparency = 0.25, Parent = rig }) })
		end
	end
	local glow = Instance.new("PointLight")
	glow.Range, glow.Brightness, glow.Color, glow.Parent = 24, 4, COLORS[1], root
	rig.Parent = workspace
	cc.Enabled = true
	cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = 0, 0, 0, Color3.new(1, 1, 1)
	TweenService:Create(cc, TweenInfo.new(0.8), { Brightness = -0.08, Contrast = 0.2, Saturation = 0.3, TintColor = Color3.fromRGB(232, 218, 255) }):Play()
	active[model] = { root = root, rig = rig, orbs = orbs, wings = wings, sky = sky, glow = glow, att = a, t0 = os.clock(), ringAt = 0, emit = { sparks, dust } }
end
local function stop(model)
	local c = active[model]
	if not c then return end
	active[model] = nil
	for _, e in ipairs(c.emit) do e.Enabled = false end
	if not next(active) then
		TweenService:Create(cc, TweenInfo.new(0.8), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		task.delay(0.85, function() if not next(active) then cc.Enabled = false end end)
	end
	if c.rig then c.rig:Destroy() end
	if c.glow then c.glow:Destroy() end
end
local function ring(c, pos)
	local r = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 2, 2), Transparency = 0.15, Color = COLORS[math.random(4)],
		CFrame = CFrame.new(pos.X, 0.1, pos.Z) * CFrame.Angles(0, 0, math.pi / 2), Parent = c.rig })
	TweenService:Create(r, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.08, 16, 16), Transparency = 1 }):Play()
	game:GetService("Debris"):AddItem(r, 1.2)
end
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for model, c in pairs(active) do
		if not model.Parent or not c.root.Parent then stop(model)
		else
			local t = now - c.t0
			local center = c.root.Position
			for i, o in ipairs(c.orbs) do
				local a = t * 2.6 + i / #c.orbs * math.pi * 2
				local r = 3.3 + math.sin(t * 1.7 + i) * 0.6
				o.Position = center + Vector3.new(math.cos(a) * r, math.sin(t * 3 + i * 1.3) * 2.4, math.sin(a) * r)
			end
			local flap = math.sin(t * 3.2) * 0.3
			local body = c.root.CFrame
			for _, w in ipairs(c.wings) do
				local spread = math.rad(14 + w.i * 15) + flap
				w.p.CFrame = body * CFrame.new(w.side * 0.35, 0.9, 0.75) * CFrame.Angles(0, 0, -w.side * spread) * CFrame.new(0, 1.3 + w.i * 0.14, 0)
			end
			c.sky.Position = center + Vector3.new(0, 44, 0)
			if now - c.ringAt > 0.5 then c.ringAt = now ring(c, center) end
			c.glow.Color = COLORS[1]:Lerp(COLORS[3], (math.sin(t * 3) + 1) / 2)
		end
	end
end)
local function watch(m)
	if not m:IsA("Model") then return end
	m:GetAttributeChangedSignal("FloatId"):Connect(function()
		if m:GetAttribute("FloatId") then task.spawn(start, m) else stop(m) end
	end)
	if m:GetAttribute("FloatId") then task.spawn(start, m) end
end
local f = workspace:WaitForChild("Avatares")
f.ChildAdded:Connect(watch)
f.ChildRemoved:Connect(stop)
for _, m in ipairs(f:GetChildren()) do watch(m) end
