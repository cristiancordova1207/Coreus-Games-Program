-- Alfombra más estrecha (17 -> 13), opción de quitar los cuadros, cámara de seguridad suave
local H = game:GetService("HttpService")
local SSS, RS, SS = game.ServerScriptService, game.ReplicatedStorage, game.ServerStorage
local map = workspace.MapaActivo.RedCarpet
local function sub(script, old, new)
	local s = script.Source
	local i, j = s:find(old, 1, true)
	assert(i, "no encontrado: " .. old:sub(1, 50))
	script.Source = s:sub(1, i - 1) .. new .. s:sub(j + 1)
end

-- ---------- la alfombra pierde 2 por lado y todo lo que la bordea se acerca lo mismo ----------
local D = 2
map.Alfombra.Size = Vector3.new(13, map.Alfombra.Size.Y, map.Alfombra.Size.Z)
local function shift(o)
	local x = o:GetPivot().Position.X
	o:PivotTo(o:GetPivot() + Vector3.new(x > 0 and -D or D, 0, 0))
end
for _, c in ipairs(map:GetChildren()) do if c.Name == "Borde" then shift(c) end end
for _, row in ipairs(map.Paparazzi:GetChildren()) do
	for _, f in ipairs(row:GetChildren()) do shift(f) end
	task.wait()
end
for _, c in ipairs(map.Prensa:GetChildren()) do shift(c) end
shift(map.Seguridad.CCTV14)
shift(map.Seguridad.CCTV15)
for _, v in ipairs(SS.VallasRC:GetChildren()) do
	for _, c in ipairs(v:GetChildren()) do shift(c) end
	task.wait()
end
-- focos de suelo y jardineras de cada escenario, pegados a la valla
local moved = 0
for _, env in ipairs(SS.EscenariosRC:GetChildren()) do
	for _, d in ipairs(env:GetChildren()) do
		if d:IsA("BasePart") or d:IsA("Model") then
			local p = d:GetPivot().Position
			local size = d:IsA("Model") and d:GetExtentsSize() or d.Size
			if p.Y < 3 and math.abs(p.X) > 8 and math.abs(p.X) < 11 and size.X < 3 then shift(d) moved += 1 end
		end
	end
	task.wait()
end
-- el público que queda pegado a la cámara principal tapa la alfombra (mismo criterio de antes)
local cam, look = map.Camara.Position, map.MiraCamara.Position
local dir = (look - cam).Unit
local removed = 0
for _, d in ipairs(map.Paparazzi:GetDescendants()) do
	if d:IsA("Model") and d.Name == "Paparazzo" and d.PrimaryPart then
		local to = d.PrimaryPart.Position - cam
		if to.Magnitude < 13 or (to.Magnitude < 26 and to.Unit:Dot(dir) > 0.93 and d.PrimaryPart.Position.X < 0) then
			d:Destroy()
			removed += 1
		end
	end
end

-- ---------- scripts ----------
sub(RS.TikAvatars.Config, "C.BARRIERS = {", [[C.MARKS = { { id = "si", name = "Con cuadros", emoji = "🔲" }, { id = "no", name = "Sin cuadros", emoji = "🚫" } }
C.BARRIERS = {]])
local show = SSS.RedCarpetShow
sub(show, "local function applyStyle(name)", [[local function applyMarks()
	local off = workspace:GetAttribute("Cuadros") == "no"
	for _, l in ipairs(marks:GetChildren()) do l.Transparency = off and 1 or 0 end
end
local function applyStyle(name)]])
sub(show, [[	pick(s, "barrier", "Valla", Cfg.BARRIERS, applyBarrier)
]], [[	pick(s, "barrier", "Valla", Cfg.BARRIERS, applyBarrier)
	pick(s, "marks", "Cuadros", Cfg.MARKS, applyMarks)
]])
sub(show, "side * 6.3, 3, z", "side * 5.2, 3, z") -- bailarines de la fiesta, dentro de la alfombra nueva
sub(show, [[workspace:SetAttribute("Estilo", env.Name)]], [[workspace:SetAttribute("Estilo", env:GetAttribute("Id") or env.Name) -- el activo se llama "Entorno"]])
sub(SSS.GameControl, [[elseif action == "barrier" and type(value) == "string" then]], [[elseif action == "marks" and type(value) == "string" then
		if _G.fsStage then _G.fsStage({ marks = value, menu = true }) end
	elseif action == "barrier" and type(value) == "string" then]])
local mn = game.StarterPlayer.StarterPlayerScripts.TikMenuClient
sub(mn, [[local textBtn, textLbl = btn(pages.Escena, "✔ Poner texto", GREEN, 8,]], [[title(pages.Escena, "CUADROS DE LA ALFOMBRA", 24)
local marksBtns = {}
local mkg = grid(pages.Escena, 25, 36)
for i, m in ipairs(C.MARKS) do marksBtns[m.id] = btn(mkg, m.emoji .. " " .. m.name, BLUE, i, function() Control:FireServer("marks", m.id) end) end
local textBtn, textLbl = btn(pages.Escena, "✔ Poner texto", GREEN, 8,]])
sub(mn, [[	for id, b in pairs(barrierBtns) do K.recolor(b, (workspace:GetAttribute("Valla") or "auto") == id and GREEN or BLUE) end]],
[[	for id, b in pairs(barrierBtns) do K.recolor(b, (workspace:GetAttribute("Valla") or "auto") == id and GREEN or BLUE) end
	for id, b in pairs(marksBtns) do K.recolor(b, (workspace:GetAttribute("Cuadros") or "si") == id and GREEN or BLUE) end]])
for _, d in ipairs(game.StarterPlayer.StarterPlayerScripts:GetDescendants()) do
	if d.Name == "CameraController" and d:IsA("LuaSourceContainer") then
		d.Source = H:GetAsync("http://127.0.0.1:5099/CameraController.lua?t=" .. os.clock(), true)
	end
end
return "ok, escenario movidos=" .. moved .. " quitados=" .. removed
