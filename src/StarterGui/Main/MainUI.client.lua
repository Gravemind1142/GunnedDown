local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")

local Knit = require(game.ReplicatedStorage.Modules.Knit) Knit.OnStart():await()

local MultiplayerService = Knit.GetService("MultiplayerService")

local GunController = Knit.GetController("GunController")
local RagdollController = Knit.GetController("RagdollController")
local EnemyController = Knit.GetController("EnemyController")

local crosshair = script.Parent:WaitForChild("Crosshair")

UserInputService.MouseIconEnabled = false

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health,false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)

local finalFrame = script.Parent:WaitForChild("Final")

local whiteFrame = finalFrame:WaitForChild("Whiteout")
local whiteIn = TweenService:Create(whiteFrame,TweenInfo.new(1,Enum.EasingStyle.Linear),{BackgroundTransparency = 0})
local whiteOut = TweenService:Create(whiteFrame,TweenInfo.new(1,Enum.EasingStyle.Linear),{BackgroundTransparency = 1})

local returnButton = finalFrame:WaitForChild("Return")
local avatarsFrame = finalFrame:WaitForChild("Avatars")

local normalLabels = {
	finalFrame:WaitForChild("Congrats"),
	finalFrame:WaitForChild("Stats"),
	finalFrame:WaitForChild("GunnedDown"),
}
local redLabels = {
	finalFrame:WaitForChild("Mercilessly"),
	finalFrame:WaitForChild("Indigenous"),
}

local statsLabel = finalFrame.Stats

function secondsToClock(n)
	if n <= 0 then
		return "00:00:00";
	else
		local h = string.format("%02.f", math.floor(n/3600));
		local m = string.format("%02.f", math.floor(n/60 - (h*60)));
		local s = string.format("%02.f", math.floor(n - h*3600 - m *60));
		return h..":"..m..":"..s
	end
end

local function final()
	whiteIn:Play()
	task.wait(1)
	finalFrame.BackgroundTransparency = 0
	for _,child in ipairs(normalLabels) do
		child.Visible = true
	end
	
	for _,player in ipairs(game.Players:GetPlayers()) do
		local new = script.Avatar:Clone()
		new.Name = player.Name
		new.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png"
		new.TextLabel.Text = player.Name
		new.Parent = avatarsFrame
	end
	returnButton.Visible = true
	UserInputService.MouseIconEnabled = true
	
	task.wait(1)
	
	whiteOut:Play()
	task.wait(2)
	
	for _,child in ipairs(redLabels) do
		TweenService:Create(child,TweenInfo.new(1,Enum.EasingStyle.Linear),{TextTransparency = 0}):Play()
	end
end

MultiplayerService.Finished:Connect(function(timeTaken)
	statsLabel.Text = "Time taken: <font color=\"#FF0000\">"..secondsToClock(timeTaken)..
		"</font>\n\nTribesmen Shot and Killed: <font color=\"#FF0000\">"..EnemyController.Killed..
		"</font>\n\nDistance fallen: <font color=\"#FF0000\">"..RagdollController.TotalFell..
		"ft</font>"
	
	final()
end)


returnButton.Activated:Connect(function()
	returnButton.Text = "LOADING..."
	TeleportService:Teleport(7768900570,game.Players.LocalPlayer,nil,game.ReplicatedStorage.LoadingScreen)
end)

RunService.RenderStepped:Connect(function()
	local mousePos = UserInputService:GetMouseLocation()

	crosshair.Position = UDim2.new(0,mousePos.X,0,mousePos.Y)
	local s = 30 + (GunController:CalculateInacuracy() * 30)
	crosshair.Size = UDim2.new(0,s,0,s)
end)