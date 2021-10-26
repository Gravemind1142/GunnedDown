local Knit = require(game.ReplicatedStorage.Modules.Knit)
local RemoteSignal = require(Knit.Util.Remote.RemoteSignal)
local MultiplayerService = Knit.CreateService({Name = "MultiplayerService", Client = {}})

local playerCharacterDict = {}

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		playerCharacterDict[player] = character

		character.Humanoid.Died:Connect(function()
			playerCharacterDict[player] = nil
		end)
	end)
end

game.Players.PlayerAdded:Connect(onPlayerAdded)
for _,player in ipairs(game.Players:GetPlayers()) do task.spawn(onPlayerAdded,player) end

local function PartToRegion3(part)
	local Size = part.Size
	local Pos = part.Position
	return Region3.new(Pos-(Size/2),Pos+(Size/2))
end

local function isVector3InRegion3(pos,reg3)
	local reg3Pos = reg3.CFrame.Position
	local reg3Rad = reg3.Size / 2

	if math.abs(pos.X - reg3Pos.X) > reg3Rad.X then
		return false
	elseif math.abs(pos.Y - reg3Pos.Y) > reg3Rad.Y then
		return false
	elseif math.abs(pos.Z - reg3Pos.Z) > reg3Rad.Z then
		return false
	end
	return true
end

local finishZone = PartToRegion3(script.FinishZone)

local startedTimestamp = os.clock()

MultiplayerService.Client.Finished = RemoteSignal.new()
MultiplayerService.Client.RenderShot = RemoteSignal.new()

function MultiplayerService:KnitInit()
	
end

function MultiplayerService:KnitStart()
	self.Client.RenderShot:Connect(function(player,endPos,hitPart)
		self.Client.RenderShot:FireAll(player,endPos,hitPart)
	end)
	
	task.defer(function()
		while task.wait(1) do
			local total = #(game.Players:GetPlayers())
			if total <= 0 then continue end
			
			local count = 0
			for _,character in pairs(playerCharacterDict) do
				if isVector3InRegion3(character.HumanoidRootPart.Position, finishZone) then
					count += 1
				end
			end
			
			if count >= total then
				self.Client.Finished:FireAll(os.clock() - startedTimestamp)
				return
			end
		end
	end)
end

return MultiplayerService