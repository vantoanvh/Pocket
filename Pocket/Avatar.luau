--!strict
--!optimize 2
--!native

--[[
	Avatar.luau

	Owns player character and backpack lifecycle wiring for Pocket, including
	starter-tool placement, tool property refresh connections, deferred tool
	removal, and humanoid equip helpers.
]]

const CreateState = require("./State")

type SlotRecord = CreateState.SlotRecord

type Config = {
	Player: Player,
	AddTool: (Tool) -> (SlotRecord, boolean),
	AddStarterTool: (Tool) -> (SlotRecord, boolean),
	RemoveTool: (Tool) -> (),
	ResetState: () -> (),
	Refresh: () -> (),
	ScrollToNewInventorySlot: () -> (),
}

export type Avatar = {
	Start: () -> (),
	IsEquipped: (Tool?) -> boolean,
	IsBackpackTool: (Tool) -> boolean,
	UnequipTools: () -> (),
	EquipTool: (Tool) -> boolean,
}

const function Create(config: Config): Avatar
	local character: Model? = nil
	local humanoid: Humanoid? = nil
	local backpack: Backpack? = nil
	local starterToolFound = false
	local stateVersion = 0

	const characterConnections: { RBXScriptConnection } = {}
	const toolConnectionsByTool: { [Tool]: { RBXScriptConnection } } = {}
	const pendingRemovedTools: { [Tool]: boolean } = {}

	const function IsEquipped(tool: Tool?): boolean
		return tool ~= nil and tool.Parent == character
	end

	const function IsBackpackTool(tool: Tool): boolean
		return tool.Parent == backpack
	end

	const function IsStarterTool(tool: Tool): boolean
		const activeCharacter = character
		if not activeCharacter or tool.Parent ~= activeCharacter then
			return false
		end

		const starterGear = config.Player:FindFirstChild("StarterGear")
		return starterGear ~= nil and starterGear:FindFirstChild(tool.Name) ~= nil
	end

	const function UnequipTools()
		const activeHumanoid = humanoid
		if activeHumanoid then
			activeHumanoid:UnequipTools()
		end
	end

	const function EquipTool(tool: Tool): boolean
		const activeHumanoid = humanoid
		if not activeHumanoid then
			return false
		end

		activeHumanoid:EquipTool(tool)
		return true
	end

	const function DisconnectTool(tool: Tool)
		const connections = toolConnectionsByTool[tool]
		if connections then
			for _, connection in connections do
				connection:Disconnect()
			end
			toolConnectionsByTool[tool] = nil
		end
	end

	const function DisconnectAllTools()
		for tool in toolConnectionsByTool do
			DisconnectTool(tool)
		end
	end

	const function ConnectTool(tool: Tool)
		if toolConnectionsByTool[tool] then
			return
		end

		toolConnectionsByTool[tool] = {
			tool:GetPropertyChangedSignal("TextureId"):Connect(config.Refresh),
			tool:GetPropertyChangedSignal("Name"):Connect(config.Refresh),
			tool:GetPropertyChangedSignal("ToolTip"):Connect(config.Refresh),
		}
	end

	const function OnChildAdded(child: Instance)
		if child:IsA("Humanoid") and child.Parent == character then
			humanoid = child
			return
		end

		if not child:IsA("Tool") then
			return
		end

		const tool = child :: Tool
		local slot: SlotRecord
		local toolAdded = false
		if not starterToolFound and IsStarterTool(tool) then
			slot, toolAdded = config.AddStarterTool(tool)
			if toolAdded then
				starterToolFound = true
				const activeCharacter = character
				const activeBackpack = backpack
				if activeCharacter and activeBackpack then
					for _, characterChild in activeCharacter:GetChildren() do
						if characterChild:IsA("Tool") and (characterChild :: Instance) ~= (tool :: Instance) then
							characterChild.Parent = activeBackpack
						end
					end
				end
			end
		else
			slot, toolAdded = config.AddTool(tool)
		end

		ConnectTool(tool)
		config.Refresh()
		if toolAdded and slot.Area == "Inventory" then
			config.ScrollToNewInventorySlot()
		end
	end

	const function OnChildRemoved(child: Instance)
		if not child:IsA("Tool") then
			return
		end

		const tool = child :: Tool
		const newParent = tool.Parent
		if newParent == character or newParent == backpack then
			config.Refresh()
			return
		end

		if pendingRemovedTools[tool] then
			return
		end

		pendingRemovedTools[tool] = true
		const removalStateVersion = stateVersion
		task.defer(function()
			if removalStateVersion ~= stateVersion then
				return
			end

			pendingRemovedTools[tool] = nil
			const latestParent = tool.Parent
			if latestParent == character or latestParent == backpack then
				config.Refresh()
				return
			end

			config.RemoveTool(tool)
			DisconnectTool(tool)
			config.Refresh()
		end)
	end

	const function OnCharacterAdded(newCharacter: Model)
		for _, connection in characterConnections do
			connection:Disconnect()
		end
		table.clear(characterConnections)
		DisconnectAllTools()
		table.clear(pendingRemovedTools)

		config.ResetState()
		stateVersion += 1
		starterToolFound = false
		character = newCharacter
		humanoid = newCharacter:FindFirstChildOfClass("Humanoid")
		const newBackpack = config.Player:WaitForChild("Backpack") :: Backpack
		backpack = newBackpack

		characterConnections[1] = newCharacter.ChildAdded:Connect(OnChildAdded)
		characterConnections[2] = newCharacter.ChildRemoved:Connect(OnChildRemoved)
		for _, child in newCharacter:GetChildren() do
			OnChildAdded(child)
		end

		characterConnections[3] = newBackpack.ChildAdded:Connect(OnChildAdded)
		characterConnections[4] = newBackpack.ChildRemoved:Connect(OnChildRemoved)
		for _, child in newBackpack:GetChildren() do
			OnChildAdded(child)
		end

		config.Refresh()
	end

	const function Start()
		config.Player.CharacterAdded:Connect(OnCharacterAdded)
		if config.Player.Character then
			OnCharacterAdded(config.Player.Character)
		else
			config.Refresh()
		end
	end

	return {
		Start = Start,
		IsEquipped = IsEquipped,
		IsBackpackTool = IsBackpackTool,
		UnequipTools = UnequipTools,
		EquipTool = EquipTool,
	}
end

return Create
