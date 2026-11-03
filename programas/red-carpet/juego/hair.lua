-- Reúne pelos y gorras reales de avatares para los paparazzi (mallas estáticas con su desfase respecto a la cabeza)
local Players = game:GetService("Players")
local assets = SS:FindFirstChild("RCAssets") or Instance.new("Folder")
assets.Name, assets.Parent = "RCAssets", SS
local hair = Folder(assets, "Pelos")
local names = { "Estrella0685", "Kirkwoohim", "coquinha9608", "Parensaq", "metaeq", "GaelPaws", "gabby_115", "ADavidPlays", "starstarborn",
	"highlyswanted", "Zenuux", "ClayTaki", "Lanaraee", "RenLeaf", "kenami", "BoujeChic", "yekemuu", "Lowrises", "eizelberry", "awluvly",
	"Qorien", "kvssidy", "AngelEthereal", "pinkcamellias", "stvrmi", "Linkmon99", "Tofuu", "KreekCraft", "DVplays", "Telamon" }
local seen, n = {}, 0
for _, name in ipairs(names) do
	local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, name)
	if ok then
		local okD, d = pcall(Players.GetHumanoidDescriptionFromUserId, Players, id)
		local okM, m = false, nil
		if okD then okM, m = pcall(Players.CreateHumanoidModelFromDescription, Players, d, Enum.HumanoidRigType.R15) end
		if okM and m then
			m.Parent = workspace
			task.wait(0.15)
			local head = m:FindFirstChild("Head")
			for _, acc in ipairs(m:GetChildren()) do
				local h = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
				if h and h:IsA("MeshPart") and head and not seen[h.MeshId] then
					local isHair = h:FindFirstChild("HairAttachment") ~= nil
					local isHat = h:FindFirstChild("HatAttachment") ~= nil
					if (isHair or isHat) and h.Size.Magnitude < 4.5 then
						seen[h.MeshId] = true
						local c = h:Clone()
						c:ClearAllChildren()
						c.Name = (isHair and "Pelo" or "Gorra") .. n
						c.Anchored, c.CanCollide, c.CanTouch, c.CanQuery = true, false, false, false
						c:SetAttribute("Off", head.CFrame:ToObjectSpace(h.CFrame))
						c.Parent = hair
						n += 1
					end
				end
			end
			m:Destroy()
		end
	end
	task.wait()
end
print("pelos", n)
return n
