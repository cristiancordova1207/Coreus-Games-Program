local H = game:GetService("HttpService")
local function g(f) return H:GetAsync("http://127.0.0.1:5099/" .. f .. "?t=" .. os.clock(), true) end
local SP = game.StarterPlayer.StarterPlayerScripts
SP.CameraController.Source = g("CameraController.lua")
SP.RedCarpetFx.Source = g("RedCarpetFx.lua")
-- el público pegado a la cámara principal tapaba la alfombra
local map = workspace.MapaActivo.RedCarpet
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
return removed
