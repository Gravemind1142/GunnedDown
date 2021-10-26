local RunService = game:GetService("RunService")

local Knit = require(game.ReplicatedStorage.Modules.Knit)
local Signal = require(Knit.Util.Signal)
local RagdollController = Knit.CreateController({Name = "RagdollController"})

local EnemyController

require(game.ReplicatedStorage.Modules.RagdollHandler)

local player = game.Players.LocalPlayer

local hRootPart
local humanoid
local character

local lastY = -9999
local lastAirborne = -9999
local canUnragdoll = true

local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = { character }
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = true

player.CharacterAdded:Connect(function(char)
	RagdollController.Ragdolled = false
	character = char
	raycastParams.FilterDescendantsInstances = { character }
	
	local hrp = char:WaitForChild("HumanoidRootPart",5)
	if not hrp then return end
	local hum = char:WaitForChild("Humanoid",5)
	if not hum then return end
	
	hRootPart = hrp
	humanoid = hum
end)

RagdollController.TotalFell = 0
RagdollController.Ragdolled = false
RagdollController.Changed = Signal.new()

function RagdollController:Ragdoll(enabled)
	if not (humanoid and character) then return end
	if not enabled and not canUnragdoll then return end
	
	RagdollController.Ragdolled = enabled
	
	humanoid:ChangeState(enabled and Enum.HumanoidStateType.Physics or Enum.HumanoidStateType.GettingUp)
	character.Animate.Disabled = enabled

	if enabled then
		lastAirborne = os.clock()
		for _,v in pairs(humanoid:GetPlayingAnimationTracks()) do
			v:Stop(0)
		end
	end
	
	RagdollController.Changed:Fire()
end

function RagdollController:KnitStart()
	EnemyController = Knit.GetController("EnemyController")
	
	RunService.Heartbeat:Connect(function()
		if hRootPart then
			-- unragdoll after 3 seconds on being on the ground
			if not workspace:Raycast(hRootPart.Position,Vector3.new(0,-6,0),raycastParams) then
				lastAirborne = os.clock()
			end

			if os.clock() - lastAirborne > 3 and RagdollController.Ragdolled then
				RagdollController:Ragdoll(false)
			end

			if hRootPart.Position.Y > lastY then
				lastY = hRootPart.Position.Y
			else
				if hRootPart.Position.Y < lastY - 20 then
					RagdollController.TotalFell += lastY - hRootPart.Position.Y
					
					EnemyController.CurrentKnockback = 0
					lastY = hRootPart.Position.Y
				end
			end
		end
	end)
end

return RagdollController
