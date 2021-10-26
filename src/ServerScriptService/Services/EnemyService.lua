local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")

local Knit = require(game.ReplicatedStorage.Modules.Knit)
local RemoteSignal = require(Knit.Util.Remote.RemoteSignal)
local EnemyService = Knit.CreateService({Name = "EnemyService", Client = {}})

local enemyFolder = Instance.new("Folder",workspace)
enemyFolder.Name = "Enemies"

local enemyCloneFolder = game.ServerStorage.Enemies

local playerCharacterDict = {}
local playerCharactersFolder = Instance.new("Folder",workspace)
playerCharactersFolder.Name = "PlayerCharacters"

local spawnsFolder = game.Workspace.Spawns

--------------------------------------------------------------------------------------

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		task.wait()
		character.Parent = playerCharactersFolder
		playerCharacterDict[player] = character
		
		character.Humanoid.Died:Connect(function()
			playerCharacterDict[player] = nil
		end)
	end)
end

game.Players.PlayerAdded:Connect(onPlayerAdded)
for _,player in ipairs(game.Players:GetPlayers()) do task.spawn(onPlayerAdded,player) end

-- Spawns enemies
-- Kills enemies
-- Sends signal for attack

-- Client:
-- Handles hit detection
-- Sends signal for hits
-- Handles attacks on client
-- Sends signal for successful enemy hits

--[[
local wList = {}
local function visWaypoints(list)
	for _,w in ipairs(wList) do
		w:Destroy()
	end
	
	for _,w in ipairs(list) do
		local p = Instance.new("Part")
		p.Anchored = true
		p.Material = Enum.Material.Neon
		p.Size = Vector3.new(0.2,0.2,0.2)
		p.Position = w.Position
		
		table.insert(wList,p)
		
		p.Parent = workspace
	end
end
]]

local AGRO_RANGE = 200

local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = { enemyFolder, playerCharactersFolder }
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = true

EnemyService.Client.Spawned = RemoteSignal.new()
EnemyService.Client.Died = RemoteSignal.new()
EnemyService.Client.Attacked = RemoteSignal.new()
EnemyService.Client.Damage = RemoteSignal.new()

local enemies = {}
local enemyCount = 0
-- [id] = enemy
local Enemy = {} do
	Enemy.__index = Enemy
	
	local function brute(tbl)
		tbl.Health = 9
		tbl.CurrentAttackCooldown = 0
		tbl.LastAttacked = os.clock()
		tbl.AttackRange = 3

		tbl.Path = PathfindingService:CreatePath({
			AgentRadius = 2.5,
			AgentHeight = 6.5,
			AgentCanJump = false,

			Costs = {
				-- mat = cost
			}
		})

		tbl.Attacks = {
			[1] = {
				Damage = 0.05,
				Cooldown = 1,
				Weight = 1
			},
			WeightSum = 1
		}
		
		local col = Color3.fromHSV(0.0833333, 0.4, math.random(45,255)/255)
		local bColor = tbl.Character["Body Colors"]
		for _,p in ipairs({"HeadColor3","LeftArmColor3","LeftLegColor3","RightArmColor3","RightLegColor3","TorsoColor3"}) do
			bColor[p] = col
		end
		if math.random() < 0.11 then
			game.ServerStorage.Torch:Clone().Parent = tbl.Character
		end
	end
	
	local function prepForClient(tbl)
		local toClient = {}
		toClient.ID = tbl.ID
		toClient.EnemyType = tbl.EnemyType
		toClient.Character = tbl.Character
		
		toClient.Attacks = {}
		for attackId,attack in ipairs(tbl.Attacks) do
			toClient.Attacks[attackId] = attack.Damage
		end
		
		return toClient
	end
	
	function Enemy.new(enemyType,cframe)
		if enemyCount >= 50 then warn("Too many enemies") return end
		
		local new = {}
		
		new.ID = HttpService:GenerateGUID(false)
		new.EnemyType = enemyType
		new.CurrentTarget = nil
		
		local enemyModel
		if enemyType == 1 then -- brute
			enemyModel = enemyCloneFolder.Brute
			new.Character = enemyModel:Clone()
			brute(new)
		end
		new.Humanoid = new.Character.Humanoid
		new.Root = new.Character.PrimaryPart
		-------------------------------------------
		--new.Character.Name = new.Character.Name..enemyCount
		new.Character:SetPrimaryPartCFrame(cframe)
		new.Character.Parent = enemyFolder
		new.Root:SetNetworkOwner(nil)
		
		setmetatable(new,Enemy)
		
		enemies[new.ID] = new
		enemyCount += 1
		
		EnemyService.Client.Spawned:FireAll(prepForClient(new))
		
		return new
	end
	
	local function attack(self)
		if self.LastAttacked + self.CurrentAttackCooldown < os.clock() then
			self.LastAttacked = os.clock()
			
			local chosenAttackId
			local rn = math.random(1,self.Attacks.WeightSum)
			for attackId, attack in ipairs(self.Attacks) do
				if rn <= attack.Weight then
					chosenAttackId = attackId
					break
				end
				rn -= attack.Weight
			end
			self.CurrentAttackCooldown = self.Attacks[chosenAttackId].Cooldown
			
			EnemyService.Client.Attacked:FireAll(self.ID, chosenAttackId, self.CurrentTarget.Character.HumanoidRootPart)
		end
	end
	
	function Enemy:Damage(num)
		self.Health -= num
		if self.Health <= 0 then
			self:Die()
		end
	end
	
	function Enemy:Die()
		local pos = self.Root.Position
		
		self.Health = 0
		self.CurrentTarget = nil
		self.Character:Destroy()
		self.Character = nil
		self.Humaniod = nil
		self.Root = nil
		enemies[self.ID] = nil
		
		enemyCount -= 1
		
		EnemyService.Client.Died:FireAll(self.ID, pos)
	end
	
	function Enemy:Target(player)
		if self.CurrentTarget == player then return end
		self.CurrentTarget = player
		if not player then 
			self.Humanoid:MoveTo(self.Root.Position) 
			return
		end
		
		local pathfindingRunning = false
		
		local waypoints
		local nextWaypointIndex
		local reachedConnection
		local blockedConnection
		
		local function cancelPath(stop)
			if stop then
				self.Humanoid:MoveTo(self.Root.Position)
			end
			pathfindingRunning = false
			if reachedConnection then reachedConnection:Disconnect() end
			if blockedConnection then blockedConnection:Disconnect() end
			reachedConnection = nil
			blockedConnection = nil
		end
				
		local function followPath(destination)
			if pathfindingRunning then return end
			-- Compute the path
			pathfindingRunning = true
			local success, errorMessage = pcall(function()
				self.Path:ComputeAsync(self.Root.Position, destination)
			end)

			if success and self.Path.Status == Enum.PathStatus.Success then
				-- Get the path waypoints
				waypoints = {}
				local i = 1
				for _,v in ipairs(self.Path:GetWaypoints()) do
					waypoints[i] = v
					i += 1
					if i > 8 then break end
				end
				--visWaypoints(waypoints)

				-- Detect if path becomes blocked
				blockedConnection = self.Path.Blocked:Connect(function(blockedWaypointIndex)
					-- Check if the obstacle is further down the path
					if blockedWaypointIndex >= nextWaypointIndex then
						-- Stop detecting path blockage until path is re-computed
						if blockedConnection then blockedConnection:Disconnect() end
						-- Call function to re-compute new path
						pathfindingRunning = false
						followPath(destination)
					end
				end)

				-- Detect when movement to next waypoint is complete
				if not reachedConnection then
					reachedConnection = self.Humanoid.MoveToFinished:Connect(function(reached)
						if reached and nextWaypointIndex < #waypoints then
							-- Increase waypoint index and move to next waypoint
							nextWaypointIndex += 1
							self.Humanoid:MoveTo(waypoints[nextWaypointIndex].Position)
						else
							-- finished
							pathfindingRunning = false
							reachedConnection:Disconnect()
							reachedConnection = nil
							blockedConnection:Disconnect()
							blockedConnection = nil
						end
					end)
				end

				-- Initially move to second waypoint (first waypoint is path start; skip it)
				nextWaypointIndex = 2
				self.Humanoid:MoveTo(waypoints[nextWaypointIndex].Position)
			else
				--warn("Path not computed!", errorMessage)
				pathfindingRunning = false
			end
		end
		
		while self.Health > 0 and self.CurrentTarget do
			if self.CurrentTarget.Character then
				local hrp = self.CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
				local hum = self.CurrentTarget.Character:FindFirstChild("Humanoid")
				if hrp then
					local dir = hrp.Position - self.Root.Position
					
					if dir.Magnitude > AGRO_RANGE then
						cancelPath(true)
						self.CurrentTarget = nil
						return
					end
					
					local hit = workspace:Raycast(self.Root.Position, dir.Unit * math.min(dir.Magnitude,AGRO_RANGE), raycastParams)
					
					if hit then
						followPath(hrp.Position)
					else
						if hum:GetState() == Enum.HumanoidStateType.Physics then -- ragdolled
							if dir.Magnitude < 6 then
								self.Humanoid:Move(-dir)
							else
								self.Humanoid:MoveTo(self.Root.Position)
								self.Root.CFrame = CFrame.new(self.Root.Position, 
									Vector3.new(hrp.Position.X, self.Root.Position.Y, hrp.Position.Z))
							end
							self.CurrentTarget = nil
							return
						end
						
						if dir.Magnitude < self.AttackRange then
							cancelPath(true)
							attack(self)
						else
							cancelPath(false)
							self.Humanoid:MoveTo(hrp.Position)
						end
					end
					
				end
			end
			task.wait(0.1)
		end
		
		self.CurrentTarget = nil
	end
end

function EnemyService:KnitInit()
	self.Client.Damage:Connect(function(player,enemyId,headshot)
		local enemy = enemies[enemyId]
		if enemy then
			enemy:Damage(headshot and 3 or 1)
		end
	end)
end

function EnemyService:KnitStart()
	task.delay(5,function()
		local SPAWN_COOLDOWN = 2
		
		local spawns = {}
		for _,child in ipairs(spawnsFolder:GetChildren()) do
			table.insert(spawns,{
				CFrame = child.CFrame,
				PlayersNeeded = tonumber(string.match(child.Name,"p%s*(%d[.%d]*)")),
				EnemyType = tonumber(string.match(child.Name,"e%s*(%d[.%d]*)")),
				LastSpawned = -9999
			})
			child:Destroy()
		end
		
		while task.wait(0.5) do
			for _,spawnLocation in ipairs(spawns) do
				
				if os.clock() - spawnLocation.LastSpawned > SPAWN_COOLDOWN then
					
					local spawnPos = spawnLocation.CFrame.Position
					
					local pCount = 0
					for player,character in pairs(playerCharacterDict) do
						local hrp = character.HumanoidRootPart
						
						if hrp.Position.Y >= spawnPos.Y - 10 and hrp.Position.Y <= spawnPos.Y + 50 then
							if ((hrp.Position * Vector3.new(1,0,1)) - (spawnPos * Vector3.new(1,0,1))).Magnitude <= 35 then
								pCount += 1
							end
						end
					end
					
					if pCount >= spawnLocation.PlayersNeeded then
						
						Enemy.new(1, spawnLocation.CFrame + Vector3.new(0,6,0))
						
						spawnLocation.LastSpawned = os.clock()
					end
					
				end
				
			end
		end
		
	end)
	
	task.defer(function()
		while task.wait(1) do
			for id,enemy in pairs(enemies) do
				
				local inRange = false
				local closestVal = math.huge
				local closestPlayer
				for player,character in pairs(playerCharacterDict) do
					local hrp = character.HumanoidRootPart
					
					local dir = hrp.Position - enemy.Root.Position
					
					if dir.Magnitude > AGRO_RANGE then
						continue
					end
					inRange = true
					
					local hit = workspace:Raycast(enemy.Root.Position, 
						dir.Unit * math.min(dir.Magnitude,AGRO_RANGE), raycastParams)
					
					if not hit then
						if dir.Magnitude < closestVal then
							closestVal = dir.Magnitude
							closestPlayer = player
						end
					end
				end
				
				if not inRange then
					enemy:Die()
					continue
				end
				
				if closestPlayer or not enemy.CurrentTarget then
					task.defer(enemy.Target,enemy,closestPlayer)
				end
				
			end
		end
	end)
end

return EnemyService