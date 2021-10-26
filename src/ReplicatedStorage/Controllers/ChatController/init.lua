local ChatService = game:GetService("Chat")

local Knit = require(game.ReplicatedStorage.Modules.Knit)
local ChatController = Knit.CreateController({Name = "ChatController"})

local camera = game.Workspace.Camera

local enemiesFolder = game.Workspace:WaitForChild("Enemies")

local bubbleChatSettings = {
	MinimizeDistance = 200,
	MaxDistance = 400,
	UserSpecificSettings = {}
}
local function applySettings()
	ChatService:SetBubbleChatSettings(bubbleChatSettings)
end
applySettings()

local function newNPC(mood,path)
	if mood == 1 then -- neutral
		
	elseif mood == 2 then -- helpful
		bubbleChatSettings.UserSpecificSettings[path] = {
			TextColor3 = Color3.new(0, 1, 0),
			MinimizeDistance = 200,
			MaxDistance = 400
		}
	elseif mood == 3 then -- aggressive
		bubbleChatSettings.UserSpecificSettings[path] = {
			TextColor3 = Color3.new(1, 0, 0),
			MinimizeDistance = 200,
			MaxDistance = 400
		}
	end
	applySettings()
end

newNPC(3,"Workspace.Enemies.Brute.Head")
newNPC(2,"Workspace.FriendlyNPCs.Friendly.Head")

local enemyResponses = {
	"Capture them!",
	
	"Pin them down!",
	"Beat them down!",
	
	"Watch the gun!",
	"Grab the gun!",
	"Grab that gun!",
	
	"Push them back!",
	"Beat them back!",
	
	"Hey, stop!",
	"Stop there!",
	"Come back here!",
	"Get back here!",
}

enemiesFolder.ChildAdded:Connect(function(child)
	if math.random() < 0.4 then
	
		local head = child:WaitForChild("Head",5)
		if head then
			task.delay(2,function()
				if child.Parent then
					ChatService:Chat(head,enemyResponses[math.random(1,#enemyResponses)])
				end
			end)
		end
		
	end
end)

local idleAnimation = Instance.new("Animation")
idleAnimation.AnimationId = "http://www.roblox.com/asset/?id=507766388"

function ChatController:KnitStart()
	local npcFolder = script.FriendlyNPCs
	
	npcFolder.Parent = workspace
	
	for _,child in ipairs(npcFolder:GetChildren()) do
		local lines = require(child.Speech)

		child.Humanoid.Animator:LoadAnimation(idleAnimation):Play()

		local hrp = child.HumanoidRootPart
		if not hrp then return end

		local lastSpoke = -9999

		task.defer(function()
			while task.wait(1) do
				if os.clock() - lastSpoke > 30 then

					if (camera.Focus.Position - hrp.Position).Magnitude < 50 then
						ChatService:Chat(child.Head,lines[math.random(1,#lines)])
						lastSpoke = os.clock()
					end

				end
			end
		end)
	end
end

return ChatController
