--!strict
--!optimize 2
--!native

--[[
	Dragger.luau

	Owns Pocket slot pointer input, drag thresholding, temporary drag visuals,
	fake inventory placeholders, drop target resolution, double-click timing,
	and equip-release range decisions for the Pocket module.
]]

const UserInputService = game:GetService("UserInputService")

const CreateSlot = require("./Slot")

type SlotPresenter = CreateSlot.SlotPresenter

type Config = {
	InventoryFrame: GuiObject,
	HotbarFrame: GuiObject,
	InventoryGridFrame: GuiObject,
	InventoryScrollingFrame: ScrollingFrame,
	HotbarPresenters: { SlotPresenter },
	HotbarSlotCount: number,
	ClickDragThreshold: number,
	DoubleClickTime: number,
	CanDrag: (SlotPresenter) -> boolean,
	ShouldShowPressed: (SlotPresenter) -> boolean,
	OnClick: (SlotPresenter) -> (),
	OnDoubleClickInventory: (SlotPresenter) -> boolean,
	OnDropOutsideHotbar: (SlotPresenter) -> (),
	OnDropHotbar: (SlotPresenter, SlotPresenter?) -> (),
}

export type Dragger = {
	Register: (SlotPresenter) -> (),
	Unregister: (SlotPresenter) -> (),
	IsDragging: () -> boolean,
}

type DragStartState = {
	Parent: GuiObject,
	ParentZIndex: number,
	FrameZIndex: number,
	Position: UDim2,
	OriginPosition: Vector2,
	OriginSize: Vector2,
	WasScrollingEnabled: boolean,
}

type DragSession = {
	Presenter: SlotPresenter,
	LastUpTime: number,
	StartState: DragStartState?,
	PressInputObject: InputObject?,
	PressInputType: Enum.UserInputType?,
	PressStartPosition: Vector2?,
	DragStartInputPosition: Vector2?,
	FakeSlotFrame: GuiObject?,
	InputBeganConnection: RBXScriptConnection?,
}

const function CheckBounds(guiObject: GuiObject, position: Vector2): boolean
	const absolutePosition = guiObject.AbsolutePosition
	const absoluteSize = guiObject.AbsoluteSize
	return position.X > absolutePosition.X
		and position.X <= absolutePosition.X + absoluteSize.X
		and position.Y > absolutePosition.Y
		and position.Y <= absolutePosition.Y + absoluteSize.Y
end

const function Create(config: Config): Dragger
	local activeSession: DragSession? = nil
	const sessionsBySlotId: { [number]: DragSession } = {}

	const function IsActiveInput(session: DragSession, input: InputObject): boolean
		const inputType = session.PressInputType
		if inputType == Enum.UserInputType.MouseButton1 then
			return input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.MouseButton1
		end

		return input == session.PressInputObject
	end

	const function GetInputSession(input: InputObject): DragSession?
		const session = activeSession
		if session then
			return if IsActiveInput(session, input) then session else nil
		end

		for _, inputSession in sessionsBySlotId do
			if IsActiveInput(inputSession, input) then
				return inputSession
			end
		end
		return nil
	end

	const function MakeFakeSlotFrame(session: DragSession)
		const fakeSlotFrame = Instance.new("Frame")
		fakeSlotFrame.Name = "FakeSlot"
		fakeSlotFrame.LayoutOrder = session.Presenter.View.Frame.LayoutOrder
		fakeSlotFrame.Size = session.Presenter.View.Frame.Size
		fakeSlotFrame.BackgroundTransparency = 1
		fakeSlotFrame.Parent = config.InventoryGridFrame
		session.FakeSlotFrame = fakeSlotFrame
	end

	const function ClearFakeSlotFrame(session: DragSession)
		const fakeSlotFrame = session.FakeSlotFrame
		if fakeSlotFrame then
			fakeSlotFrame:Destroy()
			session.FakeSlotFrame = nil
		end
	end

	const function ClearInputState(session: DragSession)
		session.PressInputObject = nil
		session.PressInputType = nil
		session.PressStartPosition = nil
		session.Presenter.View.SetPressed(false)
	end

	const function RestoreDragState(session: DragSession)
		const startState = session.StartState
		if not startState then
			return
		end

		const presenter = session.Presenter
		const frame = presenter.View.Frame
		session.DragStartInputPosition = nil
		session.StartState = nil

		frame.Position = startState.Position
		frame.Parent = startState.Parent
		startState.Parent.ZIndex = startState.ParentZIndex

		config.InventoryScrollingFrame.ScrollingEnabled = startState.WasScrollingEnabled
		presenter.View.SetTooltipEnabled(true)
		presenter.View.SetZIndex(startState.FrameZIndex)
	end

	const function GetClosestHotbarSlot(position: Vector2): SlotPresenter?
		local closestOffset: number? = nil
		local closestSlot: SlotPresenter? = nil
		for i = 1, config.HotbarSlotCount do
			const hotbarSlot = config.HotbarPresenters[i]
			if hotbarSlot then
				const hotbarFrame = hotbarSlot.View.Frame
				const offset = (hotbarFrame.AbsolutePosition + (hotbarFrame.AbsoluteSize / 2) - position).Magnitude
				if not closestOffset or offset < closestOffset then
					closestOffset = offset
					closestSlot = hotbarSlot
				end
			end
		end
		return closestSlot
	end

	const function BeginDrag(session: DragSession, inputPosition: Vector2)
		const frame = session.Presenter.View.Frame
		const startParent = frame.Parent :: GuiObject
		const startState: DragStartState = {
			Parent = startParent,
			ParentZIndex = startParent.ZIndex,
			FrameZIndex = frame.ZIndex,
			Position = frame.Position,
			OriginPosition = frame.AbsolutePosition,
			OriginSize = frame.AbsoluteSize,
			WasScrollingEnabled = config.InventoryScrollingFrame.ScrollingEnabled,
		}
		session.StartState = startState
		session.DragStartInputPosition = inputPosition
		activeSession = session

		session.Presenter.View.SetZIndex(2)
		startParent.ZIndex = 2

		if startParent == config.InventoryGridFrame then
			session.Presenter.View.SetTooltipEnabled(false)
			config.InventoryScrollingFrame.ScrollingEnabled = false
			const frameAbsolutePosition = frame.AbsolutePosition
			frame.Parent = config.InventoryFrame
			frame.Position = UDim2.fromOffset(
				frameAbsolutePosition.X - config.InventoryFrame.AbsolutePosition.X,
				frameAbsolutePosition.Y - config.InventoryFrame.AbsolutePosition.Y
			)
			startState.Position = frame.Position
			MakeFakeSlotFrame(session)
		end
	end

	const function UpdateDrag(session: DragSession, inputPosition: Vector2)
		if activeSession ~= session then
			return
		end

		const startState = session.StartState :: DragStartState
		const startInputPosition = session.DragStartInputPosition :: Vector2
		const delta = inputPosition - startInputPosition
		session.Presenter.View.Frame.Position = startState.Position + UDim2.fromOffset(delta.X, delta.Y)
	end

	const function FinishDrag(session: DragSession)
		ClearFakeSlotFrame(session)

		const presenter = session.Presenter
		const frame = presenter.View.Frame
		const startState = session.StartState :: DragStartState
		const dropPosition = frame.AbsolutePosition + (frame.AbsoluteSize / 2)
		activeSession = nil

		RestoreDragState(session)

		if not presenter.Slot.Tool then
			return
		end

		const originPosition = startState.OriginPosition
		const originSize = startState.OriginSize
		if
			dropPosition.X > originPosition.X
			and dropPosition.X <= originPosition.X + originSize.X
			and dropPosition.Y > originPosition.Y
			and dropPosition.Y <= originPosition.Y + originSize.Y
		then
			config.OnClick(presenter)
			return
		end

		if CheckBounds(config.InventoryFrame, dropPosition) then
			config.OnDropOutsideHotbar(presenter)
			return
		end

		if CheckBounds(config.HotbarFrame, dropPosition) then
			config.OnDropHotbar(presenter, GetClosestHotbarSlot(dropPosition))
			return
		end

		config.OnDropOutsideHotbar(presenter)
	end

	const function FinishClick(session: DragSession)
		const presenter = session.Presenter
		if presenter.Slot.Area == "Inventory" then
			const now = os.clock()
			if session.LastUpTime > 0 and now - session.LastUpTime < config.DoubleClickTime then
				const handledDoubleClick = config.OnDoubleClickInventory(presenter)
				session.LastUpTime = 0
				if handledDoubleClick then
					return
				end
			else
				session.LastUpTime = now
			end
		end

		config.OnClick(presenter)
	end

	const function ReleaseActiveInput(session: DragSession)
		ClearInputState(session)

		if activeSession == session then
			FinishDrag(session)
		else
			FinishClick(session)
		end
	end

	const function ChangeActiveInput(session: DragSession, input: InputObject)
		const startPosition = session.PressStartPosition
		if not startPosition then
			return
		end

		const inputPosition = Vector2.new(input.Position.X, input.Position.Y)
		if activeSession ~= session then
			const delta = inputPosition - startPosition
			const distanceSquared = (delta.X * delta.X) + (delta.Y * delta.Y)
			if config.CanDrag(session.Presenter) and distanceSquared > config.ClickDragThreshold * config.ClickDragThreshold then
				BeginDrag(session, inputPosition)
			end
		end

		UpdateDrag(session, inputPosition)
	end

	const function Register(presenter: SlotPresenter)
		if sessionsBySlotId[presenter.Slot.Id] then
			return
		end

		const session: DragSession = {
			Presenter = presenter,
			LastUpTime = 0,
			StartState = nil,
			PressInputObject = nil,
			PressInputType = nil,
			PressStartPosition = nil,
			DragStartInputPosition = nil,
			FakeSlotFrame = nil,
			InputBeganConnection = nil,
		}

		sessionsBySlotId[presenter.Slot.Id] = session

		session.InputBeganConnection = presenter.View.Frame.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			session.PressInputObject = input
			session.PressInputType = input.UserInputType
			session.PressStartPosition = Vector2.new(input.Position.X, input.Position.Y)
			session.Presenter.View.SetPressed(config.ShouldShowPressed(session.Presenter))
		end)
	end

	const function Unregister(presenter: SlotPresenter)
		const session = sessionsBySlotId[presenter.Slot.Id]
		if not session then
			return
		end

		ClearFakeSlotFrame(session)
		const inputBeganConnection = session.InputBeganConnection
		if inputBeganConnection then
			inputBeganConnection:Disconnect()
			session.InputBeganConnection = nil
		end

		if activeSession == session then
			RestoreDragState(session)
			activeSession = nil
		end
		ClearInputState(session)
		sessionsBySlotId[presenter.Slot.Id] = nil
	end

	const function IsDragging(): boolean
		return activeSession ~= nil
	end

	UserInputService.InputChanged:Connect(function(input: InputObject)
		const session = GetInputSession(input)
		if session then
			ChangeActiveInput(session, input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		const session = GetInputSession(input)
		if session then
			ReleaseActiveInput(session)
		end
	end)

	return {
		Register = Register,
		Unregister = Unregister,
		IsDragging = IsDragging,
	}
end

return Create
