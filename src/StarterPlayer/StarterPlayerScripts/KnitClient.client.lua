local Knit = require(game.ReplicatedStorage.Modules.Knit)

-- Load all services:
for _,v in ipairs(game.ReplicatedStorage.Controllers:GetDescendants()) do
	if (v:IsA("ModuleScript")) then
		require(v)
	end
end

Knit.Start():catch(warn)