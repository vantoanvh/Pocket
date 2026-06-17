--!strict
--!optimize 2
--!native

--[[
	Gamepad.luau

	Owns Pocket gamepad connection state, PreferredInput checks, inventory focus
	actions, bumper equip cycling, remove-from-hotbar behavior, swap selection,
	gamepad hint UI, and gamepad hint visibility for the Pocket module.
]]

const ContextActionService = game:GetService("ContextActionService")
const GamepadService = game:GetService("GamepadService")
const GuiService = game:GetService("GuiService")
const TweenService = game:GetService("TweenService")
const UserInputService = game:GetService("UserInputService")
const VRService = game:GetService("VRService")

const CreateSlot = require("./Slot")

const HOTBAR_ACTION = "BackpackHotbarEquip"
const FOCUS_ACTION = "BackpackHasGamepadFocus"
const CLOSE_ACTION = "BackpackCloseInventory"
const REMOVE_ACTION = "BackpackRemoveSlot"
const PULSE_TWEEN_INFO_OUT = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
const PULSE_TWEEN_INFO_IN = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
const PULSE_SIZE_OFFSET = UDim2.fromOffset(10, 10)
const PULSE_POSITION_OFFSET = UDim2.fromOffset(5, 5)
const HINT_PADDING = 25
const HINT_BACKGROUND_COLOR = Color3.fromRGB(18, 18, 21)
const HINT_BACKGROUND_TRANSPARENCY = 0.08
const HINT_CORNER_RADIUS = UDim.new(0, 3)
const HINT_TEXT_COLOR = Color3.new(1, 1, 1)
const BUILDER_SANS_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json")
const BUILDER_SANS_BOLD_FONT = Font.new(BUILDER_SANS_FONT.Family, Enum.FontWeight.Bold, Enum.FontStyle.Normal)

type SlotPresenter = CreateSlot.SlotPresenter

type Config = {
	SelectionRoot: GuiObject,
	HotbarFrame: GuiObject,
	InventoryFrame: GuiObject,
	HotbarPresenters: { SlotPresenter },
	HotbarSlotCount: number,
	IsTenFootInterface: boolean,
	MaxEquipDeltaTime: number,
	SelectSlot: (SlotPresenter) -> (),
	SwapSlots: (SlotPresenter, SlotPresenter) -> (),
	MoveHotbarToInventory: (SlotPresenter) -> (),
	DeleteEmptyInventorySlot: (SlotPresenter) -> boolean,
	IsEquipped: (Tool?) -> boolean,
	UnequipAllTools: () -> (),
	GetLastEquippedPresenter: () -> SlotPresenter?,
	CloseInventory: () -> (),
	SetInventorySelectorVisible: (boolean) -> (),
}

export type Gamepad = {
	ForgetPresenter: (SlotPresenter) -> (),
	HandleSlotActivated: (SlotPresenter) -> (),
	RefreshHotbarAction: () -> (),
	SetInventoryOpen: (boolean) -> (),
}

const function NoOpAction(): Enum.ContextActionResult?
	return nil
end

const function AddHint(parent: GuiObject, iconSize: number, textPadding: UDim, textSize: number, hintImage: string, hintText: string)
	const hintFrame = Instance.new("Frame")
	hintFrame.Name = "HintFrame"
	hintFrame.AutomaticSize = Enum.AutomaticSize.XY
	hintFrame.BackgroundTransparency = 1
	hintFrame.BorderSizePixel = 0
	hintFrame.Parent = parent

	const hintLayout = Instance.new("UIListLayout")
	hintLayout.Name = "Layout"
	hintLayout.FillDirection = Enum.FillDirection.Horizontal
	hintLayout.Padding = textPadding
	hintLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hintLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hintLayout.Parent = hintFrame

	const hintIcon = Instance.new("ImageLabel")
	hintIcon.Name = "HintImage"
	hintIcon.BackgroundTransparency = 1
	hintIcon.BorderSizePixel = 0
	hintIcon.Size = UDim2.fromOffset(iconSize, iconSize)
	hintIcon.Image = hintImage
	hintIcon.Parent = hintFrame

	const hintUI = Instance.new("TextLabel")
	hintUI.Name = "HintText"
	hintUI.AutomaticSize = Enum.AutomaticSize.XY
	hintUI.BackgroundTransparency = 1
	hintUI.BorderSizePixel = 0
	hintUI.TextSize = textSize
	hintUI.Text = hintText
	hintUI.FontFace = BUILDER_SANS_BOLD_FONT
	hintUI.TextColor3 = HINT_TEXT_COLOR
	hintUI.TextWrapped = true
	hintUI.TextXAlignment = Enum.TextXAlignment.Left
	hintUI.TextYAlignment = Enum.TextYAlignment.Center
	hintUI.Parent = hintFrame

	const textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MaxTextSize = textSize
	textSizeConstraint.Parent = hintUI
end

const function IsOppositeBumper(leftInput: InputObject, rightInput: InputObject): boolean
	return (
		leftInput.KeyCode == Enum.KeyCode.ButtonR1
		and rightInput.KeyCode == Enum.KeyCode.ButtonL1
	)
		or (
			leftInput.KeyCode == Enum.KeyCode.ButtonL1
			and rightInput.KeyCode == Enum.KeyCode.ButtonR1
		)
end

const function Create(config: Config): Gamepad
	const hintFrameHeight = if config.IsTenFootInterface then 95 else 60
	const hintIconSize = if config.IsTenFootInterface then 60 else 30
	const hintTextPadding = if config.IsTenFootInterface then UDim.new(0, 20) else UDim.new(0, 12)
	const hintTextSize = if config.IsTenFootInterface then 32 else 19

	local hotbarActionBound = false
	local inventoryActionsBound = false
	local inventoryOpen = false
	local selectedSwapPresenter: SlotPresenter? = nil
	local lastChangeToolInputObject: InputObject? = nil
	local lastChangeToolInputTime: number? = nil
	local changeToolRequest = 0
	local gamepadEnabled = false

	const hintsFrame = Instance.new("Frame")
	hintsFrame.Name = "GamepadHintsFrame"
	hintsFrame.BackgroundTransparency = HINT_BACKGROUND_TRANSPARENCY
	hintsFrame.BackgroundColor3 = HINT_BACKGROUND_COLOR
	hintsFrame.BorderSizePixel = 0
	hintsFrame.Size = UDim2.fromOffset(config.HotbarFrame.Size.X.Offset, hintFrameHeight)
	hintsFrame.Visible = false
	hintsFrame.Parent = config.SelectionRoot

	const hintsLayout = Instance.new("UIListLayout")
	hintsLayout.Name = "Layout"
	hintsLayout.FillDirection = Enum.FillDirection.Horizontal
	hintsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hintsLayout.Padding = UDim.new(0, HINT_PADDING)
	hintsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hintsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hintsLayout.Parent = hintsFrame

	const hintsCorner = Instance.new("UICorner")
	hintsCorner.Name = "Corner"
	hintsCorner.CornerRadius = HINT_CORNER_RADIUS
	hintsCorner.Parent = hintsFrame

	AddHint(
		hintsFrame,
		hintIconSize,
		hintTextPadding,
		hintTextSize,
		UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonX),
		"Remove From Hotbar"
	)
	AddHint(
		hintsFrame,
		hintIconSize,
		hintTextPadding,
		hintTextSize,
		UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonA),
		"Select/Swap"
	)
	AddHint(
		hintsFrame,
		hintIconSize,
		hintTextPadding,
		hintTextSize,
		UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonB),
		"Close Backpack"
	)

	const function HasHotbarTools(): boolean
		for i = 1, config.HotbarSlotCount do
			const presenter = config.HotbarPresenters[i]
			if presenter and presenter.Slot.Tool then
				return true
			end
		end
		return false
	end

	const function ClearSwapSelection()
		const presenter = selectedSwapPresenter
		if presenter then
			presenter.View.SetSwapSelected(false)
			selectedSwapPresenter = nil
		end
		config.SetInventorySelectorVisible(false)
	end

	const function FindSelectedHotbarPresenter(): SlotPresenter?
		const selectedObject = GuiService.SelectedObject
		if not selectedObject then
			return nil
		end

		for i = 1, config.HotbarSlotCount do
			const presenter = config.HotbarPresenters[i]
			if presenter and presenter.View.Frame == selectedObject then
				return presenter
			end
		end

		return nil
	end

	const function FindNextFilledHotbarPresenter(startIndex: number, moveDirection: number): (SlotPresenter?, boolean)
		local hitEdge = false

		for step = 1, config.HotbarSlotCount do
			local slotPosition = startIndex + (moveDirection * step)
			if slotPosition > config.HotbarSlotCount then
				slotPosition -= config.HotbarSlotCount
				hitEdge = true
			elseif slotPosition < 1 then
				slotPosition += config.HotbarSlotCount
				hitEdge = true
			end

			const presenter = config.HotbarPresenters[slotPosition]
			if presenter and presenter.Slot.Tool then
				return presenter, hitEdge
			end
		end

		return nil, hitEdge
	end

	const function SelectFallbackHotbarTool(moveDirection: number)
		const lastEquippedPresenter = config.GetLastEquippedPresenter()
		if lastEquippedPresenter and lastEquippedPresenter.Slot.Tool then
			config.SelectSlot(lastEquippedPresenter)
			return
		end

		const startIndex = if moveDirection == -1 then config.HotbarSlotCount else 1
		const endIndex = if moveDirection == -1 then 1 else config.HotbarSlotCount
		for i = startIndex, endIndex, moveDirection do
			const presenter = config.HotbarPresenters[i]
			if presenter and presenter.Slot.Tool then
				config.SelectSlot(presenter)
				return
			end
		end
	end

	const function ChangeTool(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult?
		if inputState ~= Enum.UserInputState.Begin then
			return nil
		end

		const now = os.clock()
		const previousInputObject = lastChangeToolInputObject
		const previousInputTime = lastChangeToolInputTime
		if
			previousInputObject
			and previousInputTime
			and IsOppositeBumper(previousInputObject, inputObject)
			and now - previousInputTime <= config.MaxEquipDeltaTime
		then
			config.UnequipAllTools()
			lastChangeToolInputObject = inputObject
			lastChangeToolInputTime = now
			return nil
		end

		lastChangeToolInputObject = inputObject
		lastChangeToolInputTime = now
		changeToolRequest += 1
		const request = changeToolRequest

		task.delay(config.MaxEquipDeltaTime, function()
			if request ~= changeToolRequest or lastChangeToolInputObject ~= inputObject or not gamepadEnabled then
				return
			end

			const moveDirection = if inputObject.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1
			for i = 1, config.HotbarSlotCount do
				const presenter = config.HotbarPresenters[i]
				if presenter and config.IsEquipped(presenter.Slot.Tool) then
					const nextPresenter, hitEdge = FindNextFilledHotbarPresenter(i, moveDirection)
					if hitEdge then
						config.UnequipAllTools()
					elseif nextPresenter then
						config.SelectSlot(nextPresenter)
					end
					return
				end
			end

			SelectFallbackHotbarTool(moveDirection)
		end)

		return nil
	end

	const function RemoveHotbarSlot(actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult?
		if inputState ~= Enum.UserInputState.Begin then
			return nil
		end

		const selectedHotbarPresenter = FindSelectedHotbarPresenter()
		if selectedHotbarPresenter and selectedHotbarPresenter.Slot.Tool then
			config.MoveHotbarToInventory(selectedHotbarPresenter)
		end

		return nil
	end

	const function CloseInventoryAction(actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult?
		if inputState ~= Enum.UserInputState.Begin then
			return nil
		end

		if selectedSwapPresenter then
			ClearSwapSelection()
		elseif inventoryOpen then
			config.CloseInventory()
		end

		return nil
	end

	const function UpdateHints()
		const shouldShowHints = gamepadEnabled
			and inventoryOpen
			and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
			and not VRService.VREnabled
		if shouldShowHints then
			hintsFrame.Size = UDim2.new(
				config.HotbarFrame.Size.X.Scale,
				config.HotbarFrame.Size.X.Offset,
				0,
				hintFrameHeight
			)
			hintsFrame.Position = UDim2.new(
				config.HotbarFrame.Position.X.Scale,
				config.HotbarFrame.Position.X.Offset,
				config.InventoryFrame.Position.Y.Scale,
				config.InventoryFrame.Position.Y.Offset - hintFrameHeight
			)
		end
		hintsFrame.Visible = shouldShowHints
	end

	const function RefreshInventoryControl()
		UpdateHints()
		if gamepadEnabled and inventoryOpen then
			if not inventoryActionsBound then
				inventoryActionsBound = true
				ContextActionService:BindAction(FOCUS_ACTION, NoOpAction, false, Enum.UserInputType.Gamepad1)
				ContextActionService:BindAction(CLOSE_ACTION, CloseInventoryAction, false, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonStart)
				ContextActionService:BindAction(REMOVE_ACTION, RemoveHotbarSlot, false, Enum.KeyCode.ButtonX)
				const firstPresenter = config.HotbarPresenters[1]
				GuiService.SelectedObject = if firstPresenter then firstPresenter.View.Frame else nil
			end
		elseif inventoryActionsBound then
			inventoryActionsBound = false
			ContextActionService:UnbindAction(FOCUS_ACTION)
			ContextActionService:UnbindAction(CLOSE_ACTION)
			ContextActionService:UnbindAction(REMOVE_ACTION)
			ClearSwapSelection()

			const selectedObject = GuiService.SelectedObject
			if selectedObject and selectedObject:IsDescendantOf(config.SelectionRoot) then
				GuiService.SelectedObject = nil
			end
		end
	end

	const function RefreshHotbarAction()
		if gamepadEnabled and HasHotbarTools() then
			if not hotbarActionBound then
				hotbarActionBound = true
				ContextActionService:BindAction(
					HOTBAR_ACTION,
					ChangeTool,
					false,
					Enum.KeyCode.ButtonL1,
					Enum.KeyCode.ButtonR1
				)
			end
		elseif hotbarActionBound then
			hotbarActionBound = false
			ContextActionService:UnbindAction(HOTBAR_ACTION)
		end
	end

	const function SetInventoryOpen(isOpen: boolean)
		inventoryOpen = isOpen
		RefreshInventoryControl()
	end

	const function ForgetPresenter(presenter: SlotPresenter)
		if selectedSwapPresenter == presenter then
			ClearSwapSelection()
		end
	end

	const function UpdateInputMode()
		gamepadEnabled = not VRService.VREnabled and UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)
		changeToolRequest += 1
		config.SelectionRoot.SelectionGroup = gamepadEnabled

		RefreshHotbarAction()
		RefreshInventoryControl()
	end

	const function PulseSlot(presenter: SlotPresenter)
		const frame = presenter.View.Frame
		const startSize = frame.Size
		const startPosition = frame.Position
		const growTween = TweenService:Create(
			frame,
			PULSE_TWEEN_INFO_OUT,
			{
				Size = startSize + PULSE_SIZE_OFFSET,
				Position = startPosition - PULSE_POSITION_OFFSET,
			}
		)
		const shrinkTween = TweenService:Create(
			frame,
			PULSE_TWEEN_INFO_IN,
			{
				Size = startSize,
				Position = startPosition,
			}
		)
		growTween.Completed:Once(function()
			shrinkTween:Play()
		end)
		growTween:Play()
	end

	const function DeleteEmptySwappedInventorySlot(presenter: SlotPresenter, fallbackPresenter: SlotPresenter)
		const wasSelected = GuiService.SelectedObject == presenter.View.Frame
		if config.DeleteEmptyInventorySlot(presenter) and wasSelected then
			GuiService.SelectedObject = fallbackPresenter.View.Frame
		end
	end

	const function HandleSlotActivated(presenter: SlotPresenter)
		if presenter.View.Frame == GuiService.SelectedObject and not GamepadService.GamepadCursorEnabled then
			const currentSwapPresenter = selectedSwapPresenter
			if currentSwapPresenter then
				ClearSwapSelection()
				if currentSwapPresenter.Slot.Id ~= presenter.Slot.Id then
					config.SwapSlots(presenter, currentSwapPresenter)
					DeleteEmptySwappedInventorySlot(presenter, currentSwapPresenter)
					DeleteEmptySwappedInventorySlot(currentSwapPresenter, presenter)
				end
			else
				PulseSlot(presenter)
				selectedSwapPresenter = presenter
				presenter.View.SetSwapSelected(true)
				config.SetInventorySelectorVisible(true)
			end
		else
			config.SelectSlot(presenter)
			ClearSwapSelection()
		end
	end

	UserInputService.GamepadConnected:Connect(function(gamepadEnum: Enum.UserInputType)
		if gamepadEnum == Enum.UserInputType.Gamepad1 then
			UpdateInputMode()
		end
	end)

	UserInputService.GamepadDisconnected:Connect(function(gamepadEnum: Enum.UserInputType)
		if gamepadEnum == Enum.UserInputType.Gamepad1 then
			UpdateInputMode()
		end
	end)

	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(UpdateInputMode)
	VRService:GetPropertyChangedSignal("VREnabled"):Connect(UpdateInputMode)

	UpdateInputMode()

	return {
		ForgetPresenter = ForgetPresenter,
		HandleSlotActivated = HandleSlotActivated,
		RefreshHotbarAction = RefreshHotbarAction,
		SetInventoryOpen = SetInventoryOpen,
	}
end

return Create
