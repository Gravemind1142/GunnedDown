local RunService = game:GetService("RunService")
local Knit = require(game.ReplicatedStorage.Modules.Knit)
local EnemyController = Knit.CreateController({Name = "EnemyController"})

--local gizmo = require(game.ReplicatedStorage.Modules.gizmo)

local EnemyService = Knit.GetService("EnemyService")
local RagdollController
local GunController

local player = game.Players.LocalPlayer

local enemies = {}
-- [id] = enemy

EnemyController.Killed = 0
EnemyController.CurrentKnockback = 1

local BASE_KNOCKBACK = Vector3.new(40,20,40)
local function newForce(dir)
	local v = Instance.new("BodyVelocity")
	v.P = 10000000
	v.MaxForce = Vector3.new(80000,80000,80000)
	v.Velocity = (dir + Vector3.new(0,1,0)) * BASE_KNOCKBACK * EnemyController.CurrentKnockback
	RunService.Stepped:Wait()
	v.Parent = player.Character.HumanoidRootPart
	RunService.Heartbeat:Wait()
	v:Destroy()
end

local function animation(id)
	local n = Instance.new("Animation")
	n.AnimationId = id
	return n
end

local DUMMY_PUNCHLEFT = animation("rbxassetid://7776722672")
local DUMMY_PUNCHRIGHT = animation("rbxassetid://7776732128")

local function waitFor(timeout, func)
	local result = func()
	if result then return result end
	
	local t = os.clock()
	while os.clock() - t > timeout do
		local result = func()
		if result then return result end
		
		task.wait()
	end
	return func()
end

local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = { player.Character }
raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
raycastParams.IgnoreWater = true

player.CharacterAdded:Connect(function(character)
	local parts = {}
	for _,child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(parts,child)
		end
	end
	character.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			table.insert(parts,child)
			raycastParams.FilterDescendantsInstances = parts
		end
	end)
	raycastParams.FilterDescendantsInstances = parts
end)

local function brute(enemy,animator)
	local a1Anims = {
		animator:LoadAnimation(DUMMY_PUNCHLEFT),
		animator:LoadAnimation(DUMMY_PUNCHRIGHT),
	}
	local a1Rays = {
		-- {offset, dir}
		{CFrame.new(2,0,0),CFrame.new(0,0,-3)},
		{CFrame.new(1,0,0),CFrame.new(0,0,-3)},
		{CFrame.new(-1,0,0),CFrame.new(0,0,-3)},
		{CFrame.new(-2,0,0),CFrame.new(0,0,-3)}
	}
	
	function enemy.Attack(attackId, targetHrp)
		local damage = enemy.Attacks[attackId]
		local root = enemy.Character.PrimaryPart
		
		local success = false
		if attackId == 1 then
			root.CFrame = CFrame.new(root.Position, Vector3.new(targetHrp.Position.X, root.Position.Y, targetHrp.Position.Z))
			a1Anims[math.random(1,2)]:Play()
			task.wait(0.15)
			
			if RagdollController.Ragdolled then return end
			if GunController.Rolling then return end
			
			for _,ray in ipairs(a1Rays) do
				local orig = root.CFrame:ToWorldSpace(ray[1])
				local hit = workspace:Raycast(orig.Position, orig:ToWorldSpace(ray[2]).Position - orig.Position, raycastParams)
				--gizmo.drawRay(orig.Position, orig:ToWorldSpace(ray[2]).Position - orig.Position)
				if hit then
					success = true
					break
				end
			end
		end
		
		if success then
			if RagdollController.Ragdolled then return end
			if GunController.Rolling then return end
			EnemyController.CurrentKnockback += damage
			if math.random() < (EnemyController.CurrentKnockback - 1) * 0.7 then
				RagdollController:Ragdoll(true)
			end
			newForce(root.CFrame.LookVector)
		end
	end
end

EnemyService.Spawned:Connect(function(enemy)
	local character = waitFor(5, function() 
		return enemy.Character 
	end)
	if not character then return end
	local animateScript = character:WaitForChild("Animate",5)
	if not animateScript then return end
	local hum = character:WaitForChild("Humanoid",5)
	if not hum then return end
	local animator = hum:WaitForChild("Animator",5)
	if not animator then return end
	
	if enemy.EnemyType == 1 then
		brute(enemy,animator)
	end
	enemies[enemy.ID] = enemy
	
	require(animateScript)
end)

EnemyService.Attacked:Connect(function(enemyId,attackId, targetHrp)
	local enemy = enemies[enemyId]
	if not enemy then return end
	
	task.spawn(enemy.Attack, attackId, targetHrp)
end)

function EnemyController:DamageEnemy(model,headshot)
	for enemyId,enemy in pairs(enemies) do
		if enemy.Character == model then
			
			EnemyService.Damage:Fire(enemyId,headshot)
			
			return
		end
	end
end

function EnemyController:KnitStart()
	RagdollController = Knit.GetController("RagdollController")
	GunController = Knit.GetController("GunController")
	
	EnemyService.Died:Connect(function(enemyId, pos)
		EnemyController.Killed += 1
		
		enemies[enemyId].Character = nil
		enemies[enemyId] = nil

		GunController:RenderDeath(pos)
	end)
end

return EnemyController
