--!strict
--!optimize 2
--!native

--[[
	Inventory.luau

	Builds and lays out the Pocket inventory panel, scrolling slot grid,
	selection surface, and inventory scroll buttons.
]]

const CreateSlot = require("./Slot")

const SCROLL_BUTTON_BACKGROUND_IMAGE = "rbxasset://textures/ui/Keyboard/close_button_background.png"
const SCROLL_BUTTON_SELECTION_IMAGE = "rbxasset://textures/ui/Keyboard/close_button_selection.png"
const SCROLL_BUTTON_ARROW_IMAGE = "rbxasset://textures/ui/Backpack/ScrollUpArrow.png"
const SCROLL_BUTTON_SIZE = 34
const SCROLL_BUTTON_ICON_SIZE = 30
const SCROLL_BUTTON_ICON_POSITION = UDim2.fromOffset(5, 3)
const SCROLL_BUTTON_EDGE_OFFSET = 3
const SELECTOR_IMAGE = "rbxasset://textures/ui/Keyboard/key_selection_9slice.png"
const SELECTOR_SLICE_CENTER = Rect.new(12, 12, 52, 52)
const BACKGROUND_COLOR = Color3.fromRGB(18, 18, 21)
const BACKGROUND_TRANSPARENCY = 0.08
const CORNER_RADIUS = UDim.new(0, 3)
const CONTENT_TOP_PADDING = 2

type SlotPresenter = CreateSlot.SlotPresenter

type Config = {
	Parent: GuiObject,
	HotbarFrame: GuiObject,
	Presenters: { SlotPresenter },
	IconSize: number,
	IconBuffer: number,
	InventoryHeaderSize: number,
	NumberOfInventoryRows: number,
	NumberOfHotbarSlots: number,
}

export type Inventory = {
	Frame: Frame,
	ScrollingFrame: ScrollingFrame,
	GridFrame: Frame,
	SetOpen: (boolean) -> (),
	UpdateSlots: () -> (),
	UpdateSearchResults: ({ SlotPresenter }) -> (),
	SetSelectorVisible: (boolean) -> (),
	ResetScroll: () -> (),
	ScrollToBottom: () -> (),
}

const function MakeScrollButton(name: string): ImageButton
	const button = Instance.new("ImageButton")
	button.Name = name
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(SCROLL_BUTTON_SIZE, SCROLL_BUTTON_SIZE)
	button.Image = SCROLL_BUTTON_BACKGROUND_IMAGE

	const icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Size = UDim2.fromOffset(SCROLL_BUTTON_ICON_SIZE, SCROLL_BUTTON_ICON_SIZE)
	icon.Position = SCROLL_BUTTON_ICON_POSITION
	icon.Image = SCROLL_BUTTON_ARROW_IMAGE
	icon.Parent = button

	const selection = Instance.new("ImageLabel")
	selection.Name = "Selection"
	selection.BackgroundTransparency = 1
	selection.BorderSizePixel = 0
	selection.Size = UDim2.fromScale(1, 1)
	selection.Image = SCROLL_BUTTON_SELECTION_IMAGE
	selection.Visible = false
	selection.Parent = button
	button.SelectionImageObject = selection

	return button
end

const function Create(config: Config): Inventory
	const slotScrollStep = config.IconBuffer + config.IconSize
	const inventoryFrameWidth = config.HotbarFrame.Size.X.Offset
	const inventoryFrameHeight = (config.HotbarFrame.Size.Y.Offset * config.NumberOfInventoryRows)
		+ config.InventoryHeaderSize

	const inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "Inventory"
	inventoryFrame.BackgroundTransparency = BACKGROUND_TRANSPARENCY
	inventoryFrame.BackgroundColor3 = BACKGROUND_COLOR
	inventoryFrame.BorderSizePixel = 0
	inventoryFrame.Active = true
	inventoryFrame.Size = UDim2.fromOffset(inventoryFrameWidth, inventoryFrameHeight)
	inventoryFrame.Position = UDim2.new(
		0.5,
		-inventoryFrameWidth / 2,
		1,
		config.HotbarFrame.Position.Y.Offset - inventoryFrameHeight
	)
	inventoryFrame.Visible = false
	inventoryFrame.Parent = config.Parent

	const inventoryCorner = Instance.new("UICorner")
	inventoryCorner.Name = "Corner"
	inventoryCorner.CornerRadius = CORNER_RADIUS
	inventoryCorner.Parent = inventoryFrame

	const selector = Instance.new("TextButton")
	selector.Name = "VRInventorySelector"
	selector.Size = UDim2.fromScale(1, 1)
	selector.BackgroundTransparency = 1
	selector.BorderSizePixel = 0
	selector.Text = ""
	selector.Parent = inventoryFrame

	const selectorImage = Instance.new("ImageLabel")
	selectorImage.Name = "Selector"
	selectorImage.BackgroundTransparency = 1
	selectorImage.BorderSizePixel = 0
	selectorImage.Size = UDim2.fromScale(1, 1)
	selectorImage.Image = SELECTOR_IMAGE
	selectorImage.ScaleType = Enum.ScaleType.Slice
	selectorImage.SliceCenter = SELECTOR_SLICE_CENTER
	selectorImage.Visible = false
	selectorImage.Parent = selector
	selector.SelectionImageObject = selectorImage

	const scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = "ScrollingFrame"
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.Selectable = false
	scrollingFrame.Size = UDim2.new(1, scrollingFrame.ScrollBarThickness + 1, 1, -config.InventoryHeaderSize)
	scrollingFrame.Position = UDim2.fromOffset(0, config.InventoryHeaderSize)
	scrollingFrame.Parent = inventoryFrame

	const scrollingFramePadding = Instance.new("UIPadding")
	scrollingFramePadding.Name = "ContentPadding"
	scrollingFramePadding.PaddingLeft = UDim.new(0, config.IconBuffer)
	scrollingFramePadding.PaddingRight = UDim.new(0, config.IconBuffer)
	scrollingFramePadding.PaddingTop = UDim.new(0, CONTENT_TOP_PADDING)
	scrollingFramePadding.PaddingBottom = UDim.new(0, config.IconBuffer)
	scrollingFramePadding.Parent = scrollingFrame

	const gridFrame = Instance.new("Frame")
	gridFrame.Name = "UIGridFrame"
	gridFrame.BackgroundTransparency = 1
	gridFrame.BorderSizePixel = 0
	gridFrame.Selectable = false
	gridFrame.Size = UDim2.fromScale(1, 1)
	gridFrame.Parent = scrollingFrame

	const gridLayout = Instance.new("UIGridLayout")
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.CellSize = UDim2.fromOffset(config.IconSize, config.IconSize)
	gridLayout.CellPadding = UDim2.fromOffset(config.IconBuffer, config.IconBuffer)
	gridLayout.Parent = gridFrame

	const scrollUpButton = MakeScrollButton("ScrollUpButton")
	scrollUpButton.Position = UDim2.new(
		0.5,
		-SCROLL_BUTTON_SIZE / 2,
		0,
		config.InventoryHeaderSize + SCROLL_BUTTON_EDGE_OFFSET
	)
	scrollUpButton.Parent = inventoryFrame

	const scrollDownButton = MakeScrollButton("ScrollDownButton")
	scrollDownButton.Rotation = 180
	scrollDownButton.Position = UDim2.new(
		0.5,
		-SCROLL_BUTTON_SIZE / 2,
		1,
		-SCROLL_BUTTON_SIZE - SCROLL_BUTTON_EDGE_OFFSET
	)
	scrollDownButton.Parent = inventoryFrame

	const function GetMaxCanvasPosition(): number
		return math.max(0, scrollingFrame.CanvasSize.Y.Offset - scrollingFrame.AbsoluteWindowSize.Y)
	end

	const function UpdateScrollButtons()
		const maxCanvasPosition = GetMaxCanvasPosition()
		const canScrollUp = scrollingFrame.CanvasPosition.Y ~= 0
		const canScrollDown = scrollingFrame.CanvasPosition.Y < maxCanvasPosition
		scrollUpButton.Visible = canScrollUp
		scrollDownButton.Visible = canScrollDown
	end

	const function UpdateCanvasSize()
		scrollingFrame.CanvasSize = UDim2.fromOffset(
			0,
			CONTENT_TOP_PADDING + gridLayout.AbsoluteContentSize.Y + config.IconBuffer
		)
		UpdateScrollButtons()
	end

	const function SetOpen(isOpen: boolean)
		inventoryFrame.Visible = isOpen
	end

	const function UpdateSlots()
		for i = config.NumberOfHotbarSlots + 1, #config.Presenters do
			const presenter = config.Presenters[i]
			if presenter then
				const slotFrame = presenter.View.Frame
				slotFrame.Parent = gridFrame
				slotFrame.Name = tostring(presenter.Slot.Index)
				slotFrame.LayoutOrder = presenter.Slot.Index
				slotFrame.Visible = presenter.Slot.Tool ~= nil
			end
		end
		UpdateCanvasSize()
	end

	const function UpdateSearchResults(resultPresenters: { SlotPresenter })
		for i = config.NumberOfHotbarSlots + 1, #config.Presenters do
			const presenter = config.Presenters[i]
			if presenter then
				const slotFrame = presenter.View.Frame
				slotFrame.Visible = false
				slotFrame.Parent = inventoryFrame
			end
		end

		for i = 1, #resultPresenters do
			const presenter = resultPresenters[i]
			const slotFrame = presenter.View.Frame
			slotFrame.Visible = true
			slotFrame.Parent = gridFrame
			slotFrame.Name = tostring(presenter.Slot.Index)
			slotFrame.LayoutOrder = config.NumberOfHotbarSlots + i - 1
		end

		UpdateCanvasSize()
	end

	const function SetSelectorVisible(visible: boolean)
		selectorImage.Visible = visible
	end

	const function ResetScroll()
		scrollingFrame.CanvasPosition = Vector2.zero
	end

	const function ScrollToBottom()
		if not inventoryFrame.Visible then
			return
		end

		const offset = scrollingFrame.CanvasSize.Y.Offset - scrollingFrame.AbsoluteWindowSize.Y
		scrollingFrame.CanvasPosition = Vector2.new(0, math.max(0, offset))
	end

	scrollUpButton.Activated:Connect(function()
		const canvasPosition = scrollingFrame.CanvasPosition
		scrollingFrame.CanvasPosition = Vector2.new(
			canvasPosition.X,
			math.clamp(canvasPosition.Y - slotScrollStep, 0, GetMaxCanvasPosition())
		)
	end)

	scrollDownButton.Activated:Connect(function()
		const canvasPosition = scrollingFrame.CanvasPosition
		scrollingFrame.CanvasPosition = Vector2.new(
			canvasPosition.X,
			math.clamp(canvasPosition.Y + slotScrollStep, 0, GetMaxCanvasPosition())
		)
	end)

	scrollingFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(UpdateScrollButtons)
	scrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(UpdateScrollButtons)

	UpdateCanvasSize()

	return {
		Frame = inventoryFrame,
		ScrollingFrame = scrollingFrame,
		GridFrame = gridFrame,
		SetOpen = SetOpen,
		UpdateSlots = UpdateSlots,
		UpdateSearchResults = UpdateSearchResults,
		SetSelectorVisible = SetSelectorVisible,
		ResetScroll = ResetScroll,
		ScrollToBottom = ScrollToBottom,
	}
end

return Create
