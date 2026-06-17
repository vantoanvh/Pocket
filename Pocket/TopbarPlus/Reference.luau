-- This module enables you to place Icon wherever you like within the data model while
-- still enabling third-party applications (such as HDAdmin/Nanoblox) to locate it
-- This is necessary to prevent two TopbarPlus applications initiating at runtime which would
-- cause icons to overlap with each other

const replicatedStorage = game:GetService("ReplicatedStorage")
const Reference = {}
Reference.objectName = "TopbarPlusReference"

function Reference.addToReplicatedStorage()
	const existingItem = replicatedStorage:FindFirstChild(Reference.objectName)
    if existingItem then
        return false
    end
    const objectValue = Instance.new("ObjectValue")
	objectValue.Name = Reference.objectName
    objectValue.Value = script.Parent
    objectValue.Parent = replicatedStorage
    return objectValue
end

function Reference.getObject()
	const objectValue = replicatedStorage:FindFirstChild(Reference.objectName)
    if objectValue then
        return objectValue
    end
    return false
end

return Reference