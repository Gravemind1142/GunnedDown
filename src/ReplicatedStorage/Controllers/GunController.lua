local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WorkspaceCache = require(game.ReplicatedStorage.Modules.WorkspaceCache)

local Knit = require(game.ReplicatedStorage.Modules.Knit)
local Signal = require(Knit.Util.Signal)
local GunController = Knit.CreateController({Name = "GunController"})

local MultiplayerService = Knit.GetService("MultiplayerService")

local RagdollController
local EnemyController

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local gunModel = script.Gun

------------------------------------------------------------------------

local lastShot = os.clock()
local lastMove = os.clock()

local holdAnim = Instance.new("Animation")
holdAnim.AnimationId = "rbxassetid://7776061579"
local recoilAnim = Instance.new("Animation")
recoilAnim.AnimationId = "rbxassetid://7776139790"
local reloadAnim = Instance.new("Animation")
reloadAnim.AnimationId = "rbxassetid://7836959155"
local rollAnim = Instance.new("Animation")
rollAnim.AnimationId = "rbxassetid://7839085758"

local holdAnimTrack
local recoilAnimTrack
local reloadAnimTrack
local rollAnimTrack

local hum
local hrp
local gun

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = false

local function onCharacterAdded(character)
	hum = character:WaitForChild("Humanoid",5)
	if not hum then return end
	hrp = character:WaitForChild("HumanoidRootPart",5)
	if not hrp then return end
	local hand = character:WaitForChild("RightHand",5)
	if not hand then return end
	local animator = hum:WaitForChild("Animator",5)
	if not animator then return end
	
	raycastParams.FilterDescendantsInstances = {character}
	
	holdAnimTrack = animator:LoadAnimation(holdAnim)
	recoilAnimTrack = animator:LoadAnimation(recoilAnim)
	reloadAnimTrack = animator:LoadAnimation(reloadAnim)
	rollAnimTrack = animator:LoadAnimation(rollAnim)
	
	gun = gunModel:Clone()
	local root = gun.Root
	local part = gun.GunPart
	root.CFrame = hand.CFrame
	local w = Instance.new("WeldConstraint",root)
	w.Part0 = root
	w.Part1 = hand
	gun.Parent = character
	
	holdAnimTrack:Play()
	
	hum.Died:Connect(function()
		part.CanCollide = true
		w:Destroy()
		
		holdAnimTrack = nil
		recoilAnimTrack = nil
		reloadAnimTrack = nil
		
		hum = nil
		gun = nil
		hrp = nil
	end)
	
	lastShot = os.clock()
end

if player.Character then task.defer(onCharacterAdded,player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

------------------------------------------------------------------------

local function getHumanoidFromPart(part)
	local character = part:FindFirstAncestorWhichIsA("Model")
	if not character then return end
	
	local hum = character:FindFirstChildWhichIsA("Humanoid")
	return hum
end

local startAttachmentCache do
	local startAttachment = Instance.new("Attachment")
	script.Beam:Clone().Parent = startAttachment
	startAttachment.Beam.Attachment0 = startAttachment
	
	startAttachmentCache = WorkspaceCache.new(startAttachment,game.Workspace.Terrain)
end

local endNormalAttachmentCache do
	local endAttachment = Instance.new("Attachment")
	for _,child in ipairs(script.HitEffects.Normal:GetChildren()) do
		child:Clone().Parent = endAttachment
	end
	
	endNormalAttachmentCache = WorkspaceCache.new(endAttachment,game.Workspace.Terrain)
end

local endHumanoidAttachmentCache do
	local endAttachment = Instance.new("Attachment")
	for _,child in ipairs(script.HitEffects.Humanoid:GetChildren()) do
		child:Clone().Parent = endAttachment
	end

	endHumanoidAttachmentCache = WorkspaceCache.new(endAttachment,game.Workspace.Terrain)
end

function GunController:RenderDeath(pos)
	local attach = endHumanoidAttachmentCache:NewInstance(pos, 0.05)
	for _,child in ipairs(attach:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child:Emit(child.Rate * 10)
		end
	end
end

function GunController:RenderShot(gunModel,endPos,hitPart)
	local gunPart = gunModel:FindFirstChild("GunPart")
	if not gunPart then return end
	local shootAttachment = gunPart:FindFirstChild("Shoot")
	if not shootAttachment then return end
	
	for _,child in ipairs(shootAttachment:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child:Emit(child.Rate)
		end
	end
	
	shootAttachment.SpotLight.Enabled = true
	shootAttachment.Sound:Play()
	
	local startAttach = startAttachmentCache:NewInstance(shootAttachment.WorldPosition, 0.1)
	local endAttach
	if hitPart then
		if getHumanoidFromPart(hitPart) then
			endAttach = endHumanoidAttachmentCache:NewInstance(endPos, 0.1)
		end
	end
	if not endAttach then
		endAttach = endNormalAttachmentCache:NewInstance(endPos, 0.1)
	end
	
	startAttach.Beam.Attachment1 = endAttach
	for _,child in ipairs(endAttach:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child:Emit(child.Rate)
		end
	end
	
	task.delay(0.05,function()
		shootAttachment.SpotLight.Enabled = false
		startAttach.Beam.Attachment1 = nil
	end)
end

MultiplayerService.RenderShot:Connect(function(plr,endPos,hitPart)
	if player == plr then return end
	local gunModel = plr.Character.Gun
	GunController:RenderShot(gunModel,endPos,hitPart)
end)

------------------------------------------------------------------------

local maxBullets = 17
GunController.BulletsLeft = 17

local reloadTime = 3
GunController.Reloading = false

local inacuracyTime = 1 / 0.5 -- 0.5 seconds of not shooting/walking to be accurate

local devFactor = 16/100 -- deviate 16 studs every 100 studs

GunController.ReloadStart = Signal.new()
GunController.ReloadEnd = Signal.new()

GunController.Holstered = false
GunController.Rolling = false

function GunController:CalculateInacuracy()
	local factor = math.max(lastShot,lastMove)
	local scale = math.clamp(
		1 - (inacuracyTime * (os.clock() - factor)), 
		0, 1)
	return scale
end

local function reload()
	if not (hum and hrp and gun) then return end
	if hum.Health <= 0 then return end
	if RagdollController.Ragdolled then return end
	if GunController.BulletsLeft == maxBullets then return end
	if GunController.Reloading then return end
	
	GunController.Reloading = true
	GunController.ReloadStart:Fire()
	
	task.delay(1,gun.GunPart.Reload.Play,gun.GunPart.Reload)
	reloadAnimTrack:Play()
	
	lastShot = os.clock()
	
	task.delay(reloadTime, function()
		GunController.BulletsLeft = maxBullets
		GunController.Reloading = false
		GunController.ReloadEnd:Fire()
	end)
end

local function shoot(actionName, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then return end
	if not (hum and hrp) then return end
	if hum.Health <= 0 then return end
	if RagdollController.Ragdolled then return end
	if GunController.Rolling then return end
	
	if GunController.BulletsLeft <= 0 then
		reload() 
		return
	end
	
	local headPos = hrp.Position + Vector3.new(0,2,0)
	local mousePos = mouse.Hit.Position
	local inacuracy = GunController:CalculateInacuracy()
	
	local dir = mousePos - headPos
	local normal = Vector3.new(-dir.Z,0,dir.X).Unit
	local dev = devFactor * dir.Magnitude
	local newDir = dir + (normal * (2 * math.random() - 1) * dev * inacuracy)
	
	local result = workspace:Raycast(headPos, newDir.Unit * 100,raycastParams)
	local hitPart,hitPos = nil, headPos + (newDir.Unit * 100)
	if result then
		hitPart = result.Instance
		hitPos = result.Position
		
		local hum = getHumanoidFromPart(hitPart)
		if hum then
			EnemyController:DamageEnemy(hum.Parent, hitPart.Name == "Head")
		end
	end
	
	GunController.BulletsLeft -= 1
	lastShot = os.clock()
	
	GunController:RenderShot(gun,hitPos,hitPart)
	MultiplayerService.RenderShot:Fire(hitPos,hitPart)
	
	if holdAnimTrack then holdAnimTrack:Play() end
	if recoilAnimTrack then recoilAnimTrack:Play() end
	GunController.Holstered = false
end

local ROLL_SPEED = Vector3.new(35,0,35)
local function newForce(dir,duration)
	local v = Instance.new("BodyVelocity")
	v.P = 10000000
	v.MaxForce = Vector3.new(80000,80000,80000)
	v.Velocity = dir * ROLL_SPEED
	RunService.Stepped:Wait()
	v.Parent = hrp
	task.delay(duration,function()
		v:Destroy()
	end)
end

local function roll(actionName, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then return end
	if not (hum and hrp) then return end
	if hum.Health <= 0 then return end
	if RagdollController.Ragdolled then return end
	if GunController.Rolling then return end
	
	GunController.Rolling = true
	hum.WalkSpeed = 0
	hum.JumpHeight = 0
	newForce(hrp.CFrame.LookVector,0.5)
	
	rollAnimTrack:Play()
	
	task.delay(0.6,function()
		rollAnimTrack:Stop()
		hum.WalkSpeed = 16
		hum.JumpHeight = 7
	end)
	
	task.delay(1.3,function()
		GunController.Rolling = false
	end)
end

RunService.Heartbeat:Connect(function()
	if hum then
		if hum.MoveDirection ~= Vector3.new() then
			lastMove = os.clock()
		end
	end
end)

function GunController:KnitStart()
	RagdollController = Knit.GetController("RagdollController")
	EnemyController = Knit.GetController("EnemyController")
	
	RagdollController.Changed:Connect(function()
		if RagdollController.Ragdolled then
			if gun then gun.GunPart.Reload:Stop() end
		else
			if holdAnimTrack then holdAnimTrack:Play() end
			lastMove = os.clock()
			GunController.Holstered = false
		end
	end)
	
	task.defer(function()
		while task.wait(0.5) do
			if os.clock() - lastShot > 5 then
				if holdAnimTrack then holdAnimTrack:Stop() end
				GunController.Holstered = true
			end
		end
	end)
	
	ContextActionService:BindAction("Shoot", shoot, false, Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction("Roll", roll, false, Enum.KeyCode.Space)
	ContextActionService:BindAction("Reload", function(actionName, inputState, inputObject)
		if inputState ~= Enum.UserInputState.Begin then return end
		reload()
		end, false, Enum.KeyCode.R)
end

return GunController