-- Parches de scripts: suelo, vallas, extras, menú
local H = game:GetService("HttpService")
local function get(n) return H:GetAsync("http://127.0.0.1:5099/" .. n .. "?t=" .. os.clock(), true) end
local SSS, RS = game.ServerScriptService, game.ReplicatedStorage
local log = {}
local function sub(script, old, new)
	local s = script.Source
	local i, j = s:find(old, 1, true)
	assert(i, "no encontrado: " .. old:sub(1, 50))
	script.Source = s:sub(1, i - 1) .. new .. s:sub(j + 1)
end

-- ---------- Config ----------
local cfg = RS.TikAvatars.Config
sub(cfg, "-- Estilos de las etiquetas con el nombre", [[C.FLOORS = {
	{ id = "auto", name = "Del escenario", emoji = "✨" }, { id = "blanco", name = "Blanco", emoji = "⬜", color = Color3.fromRGB(245, 245, 242) },
	{ id = "negro", name = "Negro", emoji = "⬛", color = Color3.fromRGB(22, 22, 26) }, { id = "gris", name = "Gris", emoji = "🩶", color = Color3.fromRGB(128, 130, 136) },
	{ id = "crema", name = "Crema", emoji = "🍦", color = Color3.fromRGB(240, 226, 196) }, { id = "rosa", name = "Rosa", emoji = "🌸", color = Color3.fromRGB(248, 178, 208) },
	{ id = "azul", name = "Azul", emoji = "🟦", color = Color3.fromRGB(58, 96, 190) }, { id = "verde", name = "Verde", emoji = "🟩", color = Color3.fromRGB(70, 150, 90) },
}
C.BARRIERS = {
	{ id = "auto", name = "Del escenario", emoji = "✨" }, { id = "metal", name = "Metal", emoji = "🚧" }, { id = "cuerda", name = "Terciopelo", emoji = "🎗️" },
	{ id = "evento", name = "Evento", emoji = "⭐" }, { id = "cristal", name = "Cristal", emoji = "🧊" }, { id = "neon", name = "Neón", emoji = "💡" },
	{ id = "seto", name = "Seto", emoji = "🌿" }, { id = "cinta", name = "Cinta", emoji = "🎀" },
}

-- Estilos de las etiquetas con el nombre]])

-- ---------- RedCarpetShow ----------
local show = SSS.RedCarpetShow
sub(show, "local function applyStyle(name)", [[local Cfg = require(game.ReplicatedStorage.TikAvatars.Config)
local SSrv = game:GetService("ServerStorage")
local VALLAS, floorPart, extras = SSrv:WaitForChild("VallasRC"), map:WaitForChild("SueloColor"), map:WaitForChild("Extras")
local extCams = {}
for _, c in ipairs(map.Seguridad:GetChildren()) do if c:GetAttribute("Ext") then table.insert(extCams, c) end end
local hold = Instance.new("Folder")
hold.Name, hold.Parent = "FueraDeEscena", SSrv
local currentValla
local function applyFloor()
	local id = workspace:GetAttribute("FloorColor") or "auto"
	local color
	for _, f in ipairs(Cfg.FLOORS) do if f.id == id then color = f.color end end
	local sv = currentEnv:FindFirstChild("SueloVisual")
	if sv then
		if sv:GetAttribute("T0") == nil then sv:SetAttribute("T0", sv.Transparency) end
		sv.Transparency = color and 1 or sv:GetAttribute("T0")
	end
	floorPart.Transparency = color and 0 or 1
	if color then floorPart.Color = color end
end
local function applyBarrier()
	local id = workspace:GetAttribute("Valla") or "auto"
	if id == "auto" then id = currentEnv:GetAttribute("Valla") or "cuerda" end
	local v = VALLAS:FindFirstChild(id)
	if v == currentValla or not v then return end
	if currentValla then currentValla.Parent = VALLAS end
	v.Parent = map
	currentValla = v
end
local function applyExtras()
	local off = currentEnv:GetAttribute("NoExtras") == true
	extras.Parent = off and hold or map
	for _, c in ipairs(extCams) do c.Parent = off and hold or map.Seguridad end
end
local function applyStyle(name)]])
sub(show, "for _, d in ipairs(map.MarcoPantalla:GetChildren()) do d.Transparency = noScreen and 1 or 0 end\nend", [[for _, d in ipairs(map.MarcoPantalla:GetChildren()) do d.Transparency = noScreen and 1 or 0 end
	applyFloor()
	applyBarrier()
	applyExtras()
end]])
sub(show, "_G.fsStage = function(s)\n", [[local fromProgram, fromMenu = {}, {}
local function pick(s, key, attr, list, fn) -- como el estilo: el programa no deshace lo elegido en el menú salvo que lo cambies allí
	local v = s[key]
	if type(v) ~= "string" then return end
	local ok = false
	for _, o in ipairs(list) do ok = ok or o.id == v end
	if not ok then return end
	if s.menu or (v ~= fromProgram[key] and not (fromProgram[key] == nil and fromMenu[key])) then
		workspace:SetAttribute(attr, v)
		fn()
	end
	if s.menu then fromMenu[key] = true else fromProgram[key] = v end
end
_G.fsStage = function(s)
	pick(s, "floor", "FloorColor", Cfg.FLOORS, applyFloor)
	pick(s, "barrier", "Valla", Cfg.BARRIERS, applyBarrier)
]])

-- ---------- GameControl ----------
sub(SSS.GameControl, [[elseif action == "style" and type(value) == "string" then]], [[elseif action == "floor" and type(value) == "string" then
		if _G.fsStage then _G.fsStage({ floor = value, menu = true }) end
	elseif action == "barrier" and type(value) == "string" then
		if _G.fsStage then _G.fsStage({ barrier = value, menu = true }) end
	elseif action == "style" and type(value) == "string" then]])

-- ---------- menú ----------
local mn = game.StarterPlayer.StarterPlayerScripts.TikMenuClient
sub(mn, [[local textBtn, textLbl = btn(pages.Escena, "✔ Poner texto", GREEN, 8,]], [[title(pages.Escena, "COLOR DEL SUELO", 20)
local floorBtns = {}
local flg = grid(pages.Escena, 21, 36)
for i, f in ipairs(C.FLOORS) do floorBtns[f.id] = btn(flg, f.emoji .. " " .. f.name, BLUE, i, function() Control:FireServer("floor", f.id) end) end
title(pages.Escena, "VALLAS DE LA ALFOMBRA", 22)
local barrierBtns = {}
local bag = grid(pages.Escena, 23, 36)
for i, v in ipairs(C.BARRIERS) do barrierBtns[v.id] = btn(bag, v.emoji .. " " .. v.name, BLUE, i, function() Control:FireServer("barrier", v.id) end) end
local textBtn, textLbl = btn(pages.Escena, "✔ Poner texto", GREEN, 8,]])
sub(mn, [[	for id, b in pairs(styleBtns) do K.recolor(b, (workspace:GetAttribute("Estilo") or "minimal") == id and GREEN or BLUE) end]],
[[	for id, b in pairs(styleBtns) do K.recolor(b, (workspace:GetAttribute("Estilo") or "minimal") == id and GREEN or BLUE) end
	for id, b in pairs(floorBtns) do K.recolor(b, (workspace:GetAttribute("FloorColor") or "auto") == id and GREEN or BLUE) end
	for id, b in pairs(barrierBtns) do K.recolor(b, (workspace:GetAttribute("Valla") or "auto") == id and GREEN or BLUE) end]])

-- ---------- suelo blanco de verdad en el minimalista ----------
local sv = game.ServerStorage.EscenariosRC.minimal.SueloVisual
sv.Color, sv.Material = Color3.fromRGB(245, 245, 242), Enum.Material.SmoothPlastic

-- ---------- cliente ----------
local function find(name)
	for _, d in ipairs(game.StarterPlayer.StarterPlayerScripts:GetDescendants()) do if d.Name == name and d:IsA("LuaSourceContainer") then return d end end
end
find("RedCarpetFx").Source = get("RedCarpetFx.lua")
find("CameraController").Source = get("CameraController.lua")
return "ok"
