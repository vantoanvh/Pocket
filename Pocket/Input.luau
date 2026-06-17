--!strict
--!optimize 2
--!native

--[[
	Input.luau

	Owns keyboard, mouse, touch, and text-box focus input routing for Pocket.
	It maps hotbar keys, escape behavior, and outside-click inventory closing
	to direct callbacks supplied by the Pocket module.
]]

const UserInputService = game:GetService("UserInputService")

const CreateSlot = require("./Slot")

const FULL_HOTBAR_SLOT_COUNT = 10
const ZERO_KEY_VALUE = Enum.KeyCode.Zero.Value

type SlotPresenter = CreateSlot.SlotPresenter

type Config = {
	Presenters: { SlotPresenter },
	HotbarSlotCount: number,
	InventoryFrame: GuiObject,
	HotbarFrame: GuiObject,
	IsOpen: () -> boolean,
	OpenClose: () -> (),
	SelectSlot: (SlotPresenter) -> (),
	ResetSearch: () -> (),
}

const function CheckBounds(guiObject: GuiObject, point: Vector2): boolean
	const position = guiObject.AbsolutePosition
	const size = guiObject.AbsoluteSize
	return point.X > position.X
		and point.X <= position.X + size.X
		and point.Y > position.Y
		and point.Y <= position.Y + size.Y
end

const function GetHotbarIndexFromKeyCode(keyCode: Enum.KeyCode, hotbarSlotCount: number): number?
	if keyCode == Enum.KeyCode.Zero and hotbarSlotCount == FULL_HOTBAR_SLOT_COUNT then
		return hotbarSlotCount
	end

	if keyCode.Value > ZERO_KEY_VALUE and keyCode.Value <= ZERO_KEY_VALUE + hotbarSlotCount then
		return keyCode.Value - ZERO_KEY_VALUE
	end

	return nil
end

const function Create(config: Config)
	local textBoxFocused = false

	const function OnInputBegan(input: InputObject, isProcessed: boolean)
		if input.UserInputType == Enum.UserInputType.Keyboard and not textBoxFocused then
			if input.KeyCode == Enum.KeyCode.Escape then
				if isProcessed then
					config.ResetSearch()
				elseif config.IsOpen() then
					config.OpenClose()
				end
			else
				const selectedHotbarIndex = GetHotbarIndexFromKeyCode(input.KeyCode, config.HotbarSlotCount)
				if selectedHotbarIndex and not isProcessed then
					const presenter = config.Presenters[selectedHotbarIndex]
					if presenter then
						config.SelectSlot(presenter)
					end
				end
			end
		end

		if isProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if config.IsOpen() then
				const inputPosition = Vector2.new(input.Position.X, input.Position.Y)
				if not CheckBounds(config.InventoryFrame, inputPosition) and not CheckBounds(config.HotbarFrame, inputPosition) then
					config.OpenClose()
				end
			end
		end
	end

	UserInputService.InputBegan:Connect(OnInputBegan)
	UserInputService.TextBoxFocused:Connect(function()
		textBoxFocused = true
	end)

	UserInputService.TextBoxFocusReleased:Connect(function()
		textBoxFocused = false
	end)
end

return Create
