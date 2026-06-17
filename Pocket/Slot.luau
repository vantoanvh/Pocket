--!strict
--!optimize 2
--!native

--[[
	Slot.luau

	Builds one Pocket slot view and exposes typed view-only operations for tool
	display, tooltip text, hotkey label, equipped stroke, interaction stroke,
	and slot frame geometry.
]]

const CreateState = require("./State")

const SELECTOR_IMAGE = "rbxasset://textures/ui/Keyboard/key_selection_9slice.png"
const SELECTOR_SLICE_CENTER = Rect.new(12, 12, 52, 52)
const BACKGROUND_COLOR = Color3.fromRGB(18, 18, 21)
const ACTIVE_COLOR = Color3.fromRGB(49, 49, 49)
const EQUIP_COLOR = Color3.fromRGB(0, 162, 255)
const EQUIP_THICKNESS = 0.1
const PRESS_THICKNESS = 2
const LOCKED_TRANSPARENCY = 0.08
const BORDER_COLOR = Color3.new(1, 1, 1)
const CORNER_RADIUS = UDim.new(0, 5)
const TEXT_COLOR = Color3.new(1, 1, 1)
const TOOLTIP_BACKGROUND_COLOR = Color3.fromRGB(18, 18, 21)
const TOOLTIP_BACKGROUND_TRANSPARENCY = 0.08
const TOOLTIP_BUFFER = 6
const TOOLTIP_HEIGHT = 16
const TOOLTIP_OFFSET = -25
const TOOLTIP_CORNER_RADIUS = UDim.new(0, 3)
const BUILDER_SANS_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json")

type Area = CreateState.Area
type SlotRecord = CreateState.SlotRecord

export type Slot = {
	Frame: TextButton,
	SetZIndex: (number) -> (),
	SetTool: (Tool?) -> (),
	SetActiveVisual: (boolean) -> (),
	SetEquipped: (boolean) -> (),
	SetPressed: (boolean) -> (),
	SetSwapSelected: (boolean) -> (),
	SetTooltipEnabled: (boolean) -> (),
	SetHotkeyVisible: (boolean) -> (),
	CheckTerms: ({ [string]: boolean }) -> number,
}

export type SlotPresenter = {
	Slot: SlotRecord,
	View: Slot,
}

type Config = {
	IconSize: number,
	TextSize: number,
	SlotArea: Area,
	SlotIndex: number,
	HotbarSlotCount: number,
}

const function Create(config: Config): Slot
	local activeVisual = false
	local pressed = false
	local swapSelected = false
	local tooltipEnabled = true
	local toolNameSearchText = ""
	local toolTipSearchText = ""

	const slotFrame = Instance.new("TextButton")
	slotFrame.Name = "Slot"
	slotFrame.BackgroundColor3 = BACKGROUND_COLOR
	slotFrame.BorderColor3 = BORDER_COLOR
	slotFrame.BorderSizePixel = 0
	slotFrame.Text = ""
	slotFrame.AutoButtonColor = false
	slotFrame.TextSize = config.TextSize
	slotFrame.Size = UDim2.fromOffset(config.IconSize, config.IconSize)
	slotFrame.Active = true
	slotFrame.BackgroundTransparency = LOCKED_TRANSPARENCY

	const slotCorner = Instance.new("UICorner")
	slotCorner.Name = "Corner"
	slotCorner.CornerRadius = CORNER_RADIUS
	slotCorner.Parent = slotFrame

	const stateFrame = Instance.new("Frame")
	stateFrame.Name = "State"
	stateFrame.BackgroundTransparency = 1
	stateFrame.BorderSizePixel = 0
	stateFrame.Size = UDim2.fromScale(1, 1)
	stateFrame.ZIndex = 4
	stateFrame.Parent = slotFrame

	const equippedStroke = Instance.new("UIStroke")
	equippedStroke.Name = "EquippedStroke"
	equippedStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	equippedStroke.Color = EQUIP_COLOR
	equippedStroke.Enabled = false
	equippedStroke.Thickness = config.IconSize * EQUIP_THICKNESS
	equippedStroke.LineJoinMode = Enum.LineJoinMode.Miter
	equippedStroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	equippedStroke.Parent = stateFrame

	const pressedStroke = Instance.new("UIStroke")
	pressedStroke.Name = "PressedStroke"
	pressedStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pressedStroke.Color = BORDER_COLOR
	pressedStroke.Enabled = false
	pressedStroke.Thickness = PRESS_THICKNESS
	pressedStroke.LineJoinMode = Enum.LineJoinMode.Miter
	pressedStroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	pressedStroke.Parent = stateFrame

	const selectionObjectClipper = Instance.new("Frame")
	selectionObjectClipper.Name = "SelectionObjectClipper"
	selectionObjectClipper.BackgroundTransparency = 1
	selectionObjectClipper.BorderSizePixel = 0
	selectionObjectClipper.Size = UDim2.fromScale(1, 1)
	selectionObjectClipper.Visible = false
	selectionObjectClipper.Parent = slotFrame

	const selectionObject = Instance.new("ImageLabel")
	selectionObject.Name = "Selector"
	selectionObject.BackgroundTransparency = 1
	selectionObject.BorderSizePixel = 0
	selectionObject.Size = UDim2.fromScale(1, 1)
	selectionObject.Image = SELECTOR_IMAGE
	selectionObject.ScaleType = Enum.ScaleType.Slice
	selectionObject.SliceCenter = SELECTOR_SLICE_CENTER
	selectionObject.Parent = selectionObjectClipper
	slotFrame.SelectionImageObject = selectionObjectClipper

	const toolIcon = Instance.new("ImageLabel")
	toolIcon.Name = "Icon"
	toolIcon.BackgroundTransparency = 1
	toolIcon.BorderSizePixel = 0
	toolIcon.Size = UDim2.fromScale(0.8, 0.8)
	toolIcon.Position = UDim2.fromScale(0.1, 0.1)
	toolIcon.Parent = slotFrame

	const toolName = Instance.new("TextLabel")
	toolName.Name = "ToolName"
	toolName.BackgroundTransparency = 1
	toolName.BorderSizePixel = 0
	toolName.Text = ""
	toolName.TextSize = config.TextSize
	toolName.FontFace = BUILDER_SANS_FONT
	toolName.TextColor3 = TEXT_COLOR
	toolName.TextWrapped = true
	toolName.Size = UDim2.new(1, -2, 1, -2)
	toolName.Position = UDim2.fromOffset(1, 1)
	toolName.Parent = slotFrame

	const toolTip = Instance.new("TextLabel")
	toolTip.Name = "ToolTip"
	toolTip.BackgroundColor3 = TOOLTIP_BACKGROUND_COLOR
	toolTip.BackgroundTransparency = TOOLTIP_BACKGROUND_TRANSPARENCY
	toolTip.BorderSizePixel = 0
	toolTip.Text = ""
	toolTip.TextSize = config.TextSize
	toolTip.FontFace = BUILDER_SANS_FONT
	toolTip.TextColor3 = TEXT_COLOR
	toolTip.TextWrapped = false
	toolTip.TextYAlignment = Enum.TextYAlignment.Top
	toolTip.AnchorPoint = Vector2.new(0.5, 0)
	toolTip.AutomaticSize = Enum.AutomaticSize.X
	toolTip.Position = UDim2.new(0.5, 0, 0, TOOLTIP_OFFSET)
	toolTip.Size = UDim2.fromOffset(0, TOOLTIP_HEIGHT)
	toolTip.Visible = false
	toolTip.Parent = slotFrame

	const toolTipCorner = Instance.new("UICorner")
	toolTipCorner.Name = "Corner"
	toolTipCorner.CornerRadius = TOOLTIP_CORNER_RADIUS
	toolTipCorner.Parent = toolTip

	const toolTipPadding = Instance.new("UIPadding")
	toolTipPadding.PaddingLeft = UDim.new(0, TOOLTIP_BUFFER / 2)
	toolTipPadding.PaddingRight = UDim.new(0, TOOLTIP_BUFFER / 2)
	toolTipPadding.Parent = toolTip

	slotFrame.MouseEnter:Connect(function()
		if tooltipEnabled and toolTip.Text ~= "" then
			toolTip.Visible = true
		end
	end)

	slotFrame.MouseLeave:Connect(function()
		toolTip.Visible = false
	end)

	local slotNumber: TextLabel? = nil
	if config.SlotArea == "Hotbar" and (config.SlotIndex < 10 or config.SlotIndex == config.HotbarSlotCount) then
		const hotkeyText = if config.SlotIndex < 10 then tostring(config.SlotIndex) else "0"
		const hotkeyNumber = Instance.new("TextLabel")
		hotkeyNumber.Name = "Number"
		hotkeyNumber.BackgroundTransparency = 1
		hotkeyNumber.BorderSizePixel = 0
		hotkeyNumber.Text = hotkeyText
		hotkeyNumber.TextSize = config.TextSize
		hotkeyNumber.FontFace = BUILDER_SANS_FONT
		hotkeyNumber.TextColor3 = TEXT_COLOR
		hotkeyNumber.TextWrapped = true
		hotkeyNumber.Size = UDim2.fromScale(0.15, 0.15)
		hotkeyNumber.Visible = false
		hotkeyNumber.Parent = slotFrame
		slotNumber = hotkeyNumber
	end

	const function UpdateFading()
		slotFrame.BackgroundTransparency = if activeVisual then 0 else LOCKED_TRANSPARENCY
		slotFrame.BackgroundColor3 = if activeVisual then ACTIVE_COLOR else BACKGROUND_COLOR
	end

	const function SetZIndex(zIndex: number)
		slotFrame.ZIndex = zIndex
		toolIcon.ZIndex = zIndex
		toolName.ZIndex = zIndex
		if slotNumber then
			slotNumber.ZIndex = zIndex
		end
	end

	const function SetTool(tool: Tool?)
		if tool then
			const icon = tool.TextureId
			toolIcon.Image = icon
			toolName.Visible = icon == ""
			toolName.Text = tool.Name
			toolNameSearchText = string.lower(tool.Name)
			toolTip.Text = tool.ToolTip
			toolTipSearchText = string.lower(tool.ToolTip)
		else
			toolIcon.Image = ""
			toolName.Text = ""
			toolNameSearchText = ""
			toolTip.Text = ""
			toolTipSearchText = ""
			toolTip.Visible = false
		end
	end

	const function SetActiveVisual(isActive: boolean)
		activeVisual = isActive
		UpdateFading()
	end

	const function SetEquipped(isEquipped: boolean)
		equippedStroke.Enabled = isEquipped
	end

	const function SetPressed(isPressed: boolean)
		pressed = isPressed
		pressedStroke.Enabled = pressed or swapSelected
	end

	const function SetSwapSelected(isSelected: boolean)
		swapSelected = isSelected
		pressedStroke.Enabled = pressed or swapSelected
	end

	const function SetTooltipEnabled(isEnabled: boolean)
		tooltipEnabled = isEnabled
		if not isEnabled then
			toolTip.Visible = false
		end
	end

	const function SetHotkeyVisible(visible: boolean)
		if slotNumber then
			slotNumber.Visible = visible
		end
	end

	const function CheckTerms(terms: { [string]: boolean })
		local hits = 0

		for term in terms do
			local toolNameStart = 1
			while true do
				const foundStart, foundEnd = string.find(toolNameSearchText, term, toolNameStart, true)
				if not foundStart or not foundEnd then
					break
				end
				hits += 1
				toolNameStart = foundEnd + 1
			end

			local toolTipStart = 1
			while true do
				const foundStart, foundEnd = string.find(toolTipSearchText, term, toolTipStart, true)
				if not foundStart or not foundEnd then
					break
				end
				hits += 1
				toolTipStart = foundEnd + 1
			end
		end

		return hits
	end

	return {
		Frame = slotFrame,
		SetZIndex = SetZIndex,
		SetTool = SetTool,
		SetActiveVisual = SetActiveVisual,
		SetEquipped = SetEquipped,
		SetPressed = SetPressed,
		SetSwapSelected = SetSwapSelected,
		SetTooltipEnabled = SetTooltipEnabled,
		SetHotkeyVisible = SetHotkeyVisible,
		CheckTerms = CheckTerms,
	}
end

return Create
