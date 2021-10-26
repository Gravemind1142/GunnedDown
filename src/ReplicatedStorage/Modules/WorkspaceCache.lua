WorkspaceCache = {}
WorkspaceCache.__index = WorkspaceCache

local inactivePos = Vector3.new(100000,100000,100000)

function WorkspaceCache.new(instance,parent)
	if not (instance:IsA("BasePart") or instance:IsA("Attachment")) then
		error("Attempt to use illegal instance with WorkspaceCache | ".. instance.ClassName)
	end
    local newWorkspaceCache = {}
    setmetatable(newWorkspaceCache, WorkspaceCache)
	
	newWorkspaceCache.Parent = parent
    newWorkspaceCache.OriginalInstance = instance
	newWorkspaceCache.Instances = {}
	newWorkspaceCache.InactiveInstances = {}
	
	instance.Position = inactivePos
	instance.Parent = newWorkspaceCache.Parent
		
    return newWorkspaceCache
end

function WorkspaceCache:Clear()
	self.OriginalInstance:Destroy()
	self.OriginalInstance = nil
	
	for _,instance in ipairs(self.Instances) do
		instance:Destroy()
	end
	
	self.Instances = {}
end

local function removeInstanceFromTable(instanceTable, instance)
	for i,instanceInTable in ipairs(instanceTable) do
		if instanceInTable == instance then
			table.remove(instanceTable, i)
			return
		end
	end
end

function WorkspaceCache:NewInstance(position, persistance)
	local nextInactiveInstance = self.InactiveInstances[1]
	
	if not nextInactiveInstance then
		local newInstance = self.OriginalInstance:Clone()
		newInstance.Parent = self.Parent
		table.insert(self.Instances,newInstance)
		nextInactiveInstance = newInstance
	else
		removeInstanceFromTable(self.InactiveInstances, nextInactiveInstance)
	end
	
	nextInactiveInstance.Position = position
	
	task.delay(persistance,function()
		nextInactiveInstance.Position = inactivePos
		table.insert(self.InactiveInstances,nextInactiveInstance)
	end)
	
	return nextInactiveInstance
end

return WorkspaceCache