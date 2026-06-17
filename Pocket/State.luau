--!strict
--!optimize 2
--!native

--[[
	State.luau

	Owns Pocket slot and tool state without Roblox UI instances. The module
	exposes typed operations for adding, removing, moving, swapping, deleting,
	and checking slot existence.
]]

export type Area = "Hotbar" | "Inventory"

export type SlotRecord = {
	Id: number,
	Index: number,
	Area: Area,
	Tool: Tool?,
}

export type State = {
	Slots: { SlotRecord },
	HasSlot: (number) -> boolean,
	AddTool: (Tool) -> (SlotRecord, boolean),
	AddStarterTool: (Tool) -> (SlotRecord, boolean),
	RemoveTool: (Tool) -> (),
	DeleteEmptyInventorySlot: (number) -> boolean,
	SwapSlots: (number, number) -> boolean,
	MoveHotbarToInventory: (number) -> boolean,
	MoveInventoryToHotbar: (number, number) -> boolean,
	MoveInventoryToLowestHotbar: (number) -> SlotRecord?,
}

const function Create(hotbarSlotCount: number): State
	local nextSlotId = 0
	const slots: { SlotRecord } = {}
	const slotsById: { [number]: SlotRecord } = {}
	const slotsByTool: { [Tool]: SlotRecord } = {}

	const function ClearPreviousToolOwner(tool: Tool, nextSlot: SlotRecord)
		const currentSlot = slotsByTool[tool]
		if currentSlot and currentSlot ~= nextSlot then
			currentSlot.Tool = nil
		end
	end

	const function NewSlot(area: Area, index: number, tool: Tool?): SlotRecord
		nextSlotId += 1
		const slot: SlotRecord = {
			Id = nextSlotId,
			Index = index,
			Area = area,
			Tool = nil,
		}
		slots[index] = slot
		slotsById[slot.Id] = slot
		if tool then
			ClearPreviousToolOwner(tool, slot)
			slot.Tool = tool
			slotsByTool[tool] = slot
		end
		return slot
	end

	const function SetSlotTool(slot: SlotRecord, tool: Tool?)
		const oldTool = slot.Tool
		if oldTool and slotsByTool[oldTool] == slot then
			slotsByTool[oldTool] = nil
		end

		slot.Tool = tool
		if tool then
			ClearPreviousToolOwner(tool, slot)
			slotsByTool[tool] = slot
		end
	end

	const function ReindexFrom(startIndex: number)
		for i = startIndex, #slots do
			const slot = slots[i]
			slot.Index = i
		end
	end

	const function RemoveInventorySlot(slot: SlotRecord)
		const tool = slot.Tool
		if tool and slotsByTool[tool] == slot then
			slotsByTool[tool] = nil
		end

		slot.Tool = nil
		slotsById[slot.Id] = nil
		table.remove(slots, slot.Index)
		ReindexFrom(slot.Index)
	end

	for i = 1, hotbarSlotCount do
		NewSlot("Hotbar", i, nil)
	end

	const function HasSlot(slotId: number): boolean
		return slotsById[slotId] ~= nil
	end

	const function GetLowestEmptyHotbarSlot(): SlotRecord?
		for i = 1, hotbarSlotCount do
			const slot = slots[i]
			if not slot.Tool then
				return slot
			end
		end
		return nil
	end

	const function AddTool(tool: Tool): (SlotRecord, boolean)
		const existingSlot = slotsByTool[tool]
		if existingSlot then
			return existingSlot, false
		end

		const hotbarSlot = GetLowestEmptyHotbarSlot()
		if hotbarSlot then
			SetSlotTool(hotbarSlot, tool)
			return hotbarSlot, true
		end

		return NewSlot("Inventory", #slots + 1, tool), true
	end

	const function AddStarterTool(tool: Tool): (SlotRecord, boolean)
		const existingSlot = slotsByTool[tool]
		if existingSlot then
			return existingSlot, false
		end

		const slot = GetLowestEmptyHotbarSlot() or NewSlot("Inventory", #slots + 1, nil)

		local carriedTool: Tool? = tool
		for i = 1, slot.Index do
			const currentSlot = slots[i]
			const nextTool = currentSlot.Tool
			SetSlotTool(currentSlot, carriedTool)
			carriedTool = nextTool
		end

		return slots[1], true
	end

	const function DeleteEmptyInventorySlot(slotId: number): boolean
		const slot = slotsById[slotId]
		if not slot or slot.Area ~= "Inventory" or slot.Tool then
			return false
		end

		RemoveInventorySlot(slot)
		return true
	end

	const function RemoveTool(tool: Tool)
		const slot = slotsByTool[tool]
		if not slot then
			return
		end

		if slot.Area == "Inventory" then
			RemoveInventorySlot(slot)
		else
			SetSlotTool(slot, nil)
		end
	end

	const function SwapSlots(leftSlotId: number, rightSlotId: number): boolean
		const leftSlot = slotsById[leftSlotId]
		const rightSlot = slotsById[rightSlotId]
		if not leftSlot or not rightSlot or leftSlot.Id == rightSlot.Id then
			return false
		end

		const leftTool = leftSlot.Tool
		const rightTool = rightSlot.Tool
		leftSlot.Tool = rightTool
		rightSlot.Tool = leftTool
		if rightTool then
			slotsByTool[rightTool] = leftSlot
		end
		if leftTool then
			slotsByTool[leftTool] = rightSlot
		end
		return true
	end

	const function MoveHotbarToInventory(slotId: number): boolean
		const slot = slotsById[slotId]
		if not slot or slot.Area ~= "Hotbar" then
			return false
		end

		const tool = slot.Tool
		if not tool then
			return false
		end

		SetSlotTool(slot, nil)
		NewSlot("Inventory", #slots + 1, tool)
		return true
	end

	const function MoveInventoryToHotbarSlot(slot: SlotRecord, hotbarSlot: SlotRecord): SlotRecord?
		const tool = slot.Tool
		if not tool then
			return nil
		end

		const hotbarTool = hotbarSlot.Tool
		SetSlotTool(hotbarSlot, tool)
		if hotbarTool then
			SetSlotTool(slot, hotbarTool)
		else
			RemoveInventorySlot(slot)
		end

		return hotbarSlot
	end

	const function MoveInventoryToHotbar(slotId: number, hotbarIndex: number): boolean
		const slot = slotsById[slotId]
		if not slot or slot.Area ~= "Inventory" then
			return false
		end

		if hotbarIndex < 1 or hotbarIndex > hotbarSlotCount then
			return false
		end

		return MoveInventoryToHotbarSlot(slot, slots[hotbarIndex]) ~= nil
	end

	const function MoveInventoryToLowestHotbar(slotId: number): SlotRecord?
		const slot = slotsById[slotId]
		if not slot or slot.Area ~= "Inventory" then
			return nil
		end

		const hotbarSlot = GetLowestEmptyHotbarSlot()
		if not hotbarSlot then
			return nil
		end

		return MoveInventoryToHotbarSlot(slot, hotbarSlot)
	end

	return {
		Slots = slots,
		HasSlot = HasSlot,
		AddTool = AddTool,
		AddStarterTool = AddStarterTool,
		RemoveTool = RemoveTool,
		DeleteEmptyInventorySlot = DeleteEmptyInventorySlot,
		SwapSlots = SwapSlots,
		MoveHotbarToInventory = MoveHotbarToInventory,
		MoveInventoryToHotbar = MoveInventoryToHotbar,
		MoveInventoryToLowestHotbar = MoveInventoryToLowestHotbar,
	}
end

return Create
