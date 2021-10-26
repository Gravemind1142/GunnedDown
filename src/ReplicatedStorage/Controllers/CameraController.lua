local RunService = game:GetService("RunService")

local Knit = require(game.ReplicatedStorage.Modules.Knit)
local CameraController = Knit.CreateController({Name = "CameraController"})

local RagdollController
local GunController

local pi    = math.pi
local abs   = math.abs
local clamp = math.clamp
local exp   = math.exp
local rad   = math.rad
local sign  = math.sign
local sqrt  = math.sqrt
local tan   = math.tan

local player = game.Players.LocalPlayer
local camera = game.Workspace.CurrentCamera
local mouse = player:GetMouse()

------------------------------------------------------------------------

local fovGoal = 60
local height = 40
local locked = false
local lockTo = CFrame.new()

function CameraController:SetFov(val)
	fovGoal = val
end

function CameraController:SetHeight(val)
	height = val
end

function CameraController:Lock(enabled)
	locked = enabled
end

function CameraController:SetCFrame(val)
	lockTo = val
end

------------------------------------------------------------------------

local Spring = {} do
	Spring.__index = Spring

	function Spring.new(freq, pos)
		local self = setmetatable({}, Spring)
		self.f = freq
		self.p = pos
		self.v = pos*0
		return self
	end

	function Spring:Update(dt, goal)
		local f = self.f*2*pi
		local p0 = self.p
		local v0 = self.v

		local offset = goal - p0
		local decay = exp(-f*dt)

		local p1 = goal + (v0*dt - offset*(f*dt + 1))*decay
		local v1 = (f*dt*(offset*f - v0) + v0)*decay

		self.p = p1
		self.v = v1

		return p1
	end

	function Spring:Reset(pos)
		self.p = pos
		self.v = pos*0
	end
end

local NAV_GAIN = Vector3.new(1, 1, 1)*16
local FOV_GAIN = 300

local POS_STIFFNESS = 0.8
local FOV_STIFFNESS = 4.0

local posGoal = Vector3.new()

local cameraFov = 0

local posSpring = Spring.new(POS_STIFFNESS, Vector3.new())
local fovSpring = Spring.new(FOV_STIFFNESS, 0)

local function GetFocusDistance(cameraFrame)
	local znear = 0.1
	local viewport = camera.ViewportSize
	local projy = 2*tan(cameraFov/2)
	local projx = viewport.x/viewport.y*projy
	local fx = cameraFrame.rightVector
	local fy = cameraFrame.upVector
	local fz = cameraFrame.lookVector

	local minVect = Vector3.new()
	local minDist = 512

	for x = 0, 1, 0.5 do
		for y = 0, 1, 0.5 do
			local cx = (x - 0.5)*projx
			local cy = (y - 0.5)*projy
			local offset = fx*cx - fy*cy + fz
			local origin = cameraFrame.p + offset*znear
			local _, hit = game.Workspace:FindPartOnRay(Ray.new(origin, offset.unit*minDist))
			local dist = (hit - origin).magnitude
			if minDist > dist then
				minDist = dist
				minVect = offset.unit
			end
		end
	end

	return fz:Dot(minVect)*minDist
end

------------------------------------------------------------------------

local offset = 0

RunService:BindToRenderStep("Camera", Enum.RenderPriority.Camera.Value, function(dt)
	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		local hum = player.Character:FindFirstChild("Humanoid")
		if hrp and hum then
			if hum.Health > 0 then
				posGoal = hrp.Position + Vector3.new(0,height,offset) --+ (hrp.CFrame.LookVector * hum.MoveDirection.Magnitude * 10)
			end
		end
	end
	
	local pos = posSpring:Update(dt, posGoal)
	local fov = fovSpring:Update(dt, fovGoal)
	
	local cameraCFrame = CFrame.new(pos, pos - Vector3.new(0,height,offset))
	
	if locked then
		camera.CFrame = lockTo
		camera.Focus = cameraCFrame*CFrame.new(0, 0, -GetFocusDistance(cameraCFrame))
		camera.FieldOfView = fovGoal
	else
		camera.CFrame = cameraCFrame
		camera.Focus = cameraCFrame*CFrame.new(0, 0, -GetFocusDistance(cameraCFrame))
		camera.FieldOfView = fov
	end
end)

function CameraController:KnitStart()
	RagdollController = Knit.GetController("RagdollController")
	GunController = Knit.GetController("GunController")
	
	camera.CameraType = Enum.CameraType.Scriptable
	camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		camera.CameraType = Enum.CameraType.Scriptable
	end)
	
	RunService:BindToRenderStep("CharRot", Enum.RenderPriority.Character.Value, function(dt)
		if player.Character and not RagdollController.Ragdolled and not GunController.Holstered then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			local hum = player.Character:FindFirstChild("Humanoid")
			if hrp and hum then
				if hum.Health > 0 then
					local RootPos, MousePos = hrp.Position, mouse.Hit.Position
					hrp.CFrame = CFrame.new(RootPos, Vector3.new(MousePos.X, RootPos.Y, MousePos.Z))
				end
			end
		end
	end)
end

return CameraController