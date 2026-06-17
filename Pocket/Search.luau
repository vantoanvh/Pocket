--!strict
--!optimize 2
--!native

--[[
	Search.luau

	Builds the Pocket inventory search UI, ranks inventory slot presenters
	by tool name and tooltip matches, and exposes refresh/input-mode hooks.
]]

const UserInputService = game:GetService("UserInputService")
const VRService = game:GetService("VRService")

const CreateSlot = require("./Slot")

const BACKGROUND_COLOR = Color3.fromRGB(18, 18, 21)
const BACKGROUND_TRANSPARENCY = 0.08
const BORDER_COLOR = Color3.new(1, 1, 1)
const BORDER_TRANSPARENCY = 0.8
const BORDER_THICKNESS = 1
const CORNER_RADIUS = UDim.new(0, 3)
const SEARCH_IMAGE_X = "rbxasset://textures/ui/InspectMenu/x.png"
const SEARCH_BUFFER = 5
const SEARCH_WIDTH = 200
const SEARCH_PLACEHOLDER_TEXT = "Search"
const SEARCH_TEXT_OFFSET = 8
const TEXT_COLOR = Color3.new(1, 1, 1)
const BUILDER_SANS_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json")

type SlotPresenter = CreateSlot.SlotPresenter

type SearchHit = {
	Presenter: SlotPresenter,
	Hits: number,
}

type Config = {
	Parent: GuiObject,
	Presenters: { SlotPresenter },
	NumberOfHotbarSlots: number,
	InventoryHeaderSize: number,
	UpdateInventorySlots: () -> (),
	UpdateSearchResults: ({ SlotPresenter }) -> (),
	ResetInventoryScroll: () -> (),
	ScrollInventoryToBottom: () -> (),
}

export type Search = {
	UpdateSlots: () -> (),
	ScrollToNewInventorySlot: () -> (),
	Reset: () -> (),
	SetOpen: (boolean) -> (),
}

const function CompareSearchHits(left: SearchHit, right: SearchHit): boolean
	if left.Hits == right.Hits then
		return left.Presenter.Slot.Index < right.Presenter.Slot.Index
	end

	return left.Hits > right.Hits
end

const function Create(config: Config): Search
	local viewingResults = false
	const searchTerms: { [string]: boolean } = {}
	const searchHits: { SearchHit } = {}
	const resultPresenters: { SlotPresenter } = {}
	const searchInset = SEARCH_BUFFER * 2
	const searchFrameWidth = SEARCH_WIDTH - searchInset
	const searchFrameHeight = config.InventoryHeaderSize - searchInset
	const searchFrameSize = UDim2.fromOffset(searchFrameWidth, searchFrameHeight)
	const clearButtonSize = searchFrameHeight - searchInset
	const searchBoxWidth = searchFrameWidth - (SEARCH_TEXT_OFFSET * 2) - clearButtonSize

	const searchFrame = Instance.new("Frame")
	searchFrame.Name = "Search"
	searchFrame.BackgroundColor3 = BACKGROUND_COLOR
	searchFrame.BackgroundTransparency = BACKGROUND_TRANSPARENCY
	searchFrame.BorderSizePixel = 0
	searchFrame.Size = searchFrameSize
	searchFrame.Position = UDim2.new(1, -searchFrameWidth - SEARCH_BUFFER, 0, SEARCH_BUFFER)
	searchFrame.Parent = config.Parent

	const searchCorner = Instance.new("UICorner")
	searchCorner.Name = "Corner"
	searchCorner.CornerRadius = CORNER_RADIUS
	searchCorner.Parent = searchFrame

	const searchBorder = Instance.new("UIStroke")
	searchBorder.Name = "Border"
	searchBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	searchBorder.Color = BORDER_COLOR
	searchBorder.Transparency = BORDER_TRANSPARENCY
	searchBorder.Thickness = BORDER_THICKNESS
	searchBorder.Parent = searchFrame

	const searchBox = Instance.new("TextBox")
	searchBox.Name = "TextBox"
	searchBox.BackgroundTransparency = 1
	searchBox.BorderSizePixel = 0
	searchBox.Text = ""
	searchBox.PlaceholderText = SEARCH_PLACEHOLDER_TEXT
	searchBox.ClearTextOnFocus = false
	searchBox.TextSize = 24
	searchBox.FontFace = BUILDER_SANS_FONT
	searchBox.TextColor3 = TEXT_COLOR
	searchBox.TextTruncate = Enum.TextTruncate.AtEnd
	searchBox.TextWrapped = true
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.TextYAlignment = Enum.TextYAlignment.Center
	searchBox.Size = UDim2.new(0, searchBoxWidth, 1, -(SEARCH_TEXT_OFFSET * 2))
	searchBox.Position = UDim2.new(0, SEARCH_TEXT_OFFSET, 0, SEARCH_TEXT_OFFSET)
	searchBox.ZIndex = 2
	searchBox.Parent = searchFrame

	const clearButton = Instance.new("ImageButton")
	clearButton.Name = "Clear"
	clearButton.Image = SEARCH_IMAGE_X
	clearButton.BackgroundTransparency = 1
	clearButton.BorderSizePixel = 0
	clearButton.Size = UDim2.fromOffset(clearButtonSize, clearButtonSize)
	clearButton.Position = UDim2.new(1, -clearButtonSize - SEARCH_BUFFER, 0.5, -clearButtonSize / 2)
	clearButton.ZIndex = 4
	clearButton.Visible = false
	clearButton.Parent = searchFrame

	const function ClearResults()
		if not viewingResults then
			return
		end

		viewingResults = false
		config.UpdateInventorySlots()
	end

	const function Search()
		table.clear(searchTerms)
		table.clear(searchHits)
		table.clear(resultPresenters)

		local termCount = 0
		for word in searchBox.Text:gmatch("%S+") do
			const term = word:lower()
			if not searchTerms[term] then
				searchTerms[term] = true
				termCount += 1
			end
		end

		if termCount == 0 then
			ClearResults()
			return
		end

		for i = config.NumberOfHotbarSlots + 1, #config.Presenters do
			const presenter = config.Presenters[i]
			if presenter then
				const hits = presenter.View.CheckTerms(searchTerms)
				if hits > 0 then
					table.insert(searchHits, {
						Presenter = presenter,
						Hits = hits,
					})
				end
			end
		end

		table.sort(searchHits, CompareSearchHits)
		viewingResults = true

		for dataIndex = 1, #searchHits do
			const data = searchHits[dataIndex]
			resultPresenters[dataIndex] = data.Presenter
		end

		config.ResetInventoryScroll()
		config.UpdateSearchResults(resultPresenters)
	end

	const function UpdateSlots()
		if viewingResults then
			Search()
		else
			config.UpdateInventorySlots()
		end
	end

	const function ScrollToNewInventorySlot()
		if viewingResults then
			return
		end

		config.ScrollInventoryToBottom()
	end

	const function Reset()
		if searchBox.Text == "" then
			ClearResults()
		else
			searchBox.Text = ""
		end
	end

	const function OnSearchTextChanged()
		Search()
		clearButton.Visible = searchBox.Text ~= ""
	end

	const function SetOpen(isNowOpen: boolean)
		clearButton.Modal = isNowOpen
		if not isNowOpen then
			Reset()
		end
	end

	const function UpdateInputMode()
		searchFrame.Visible = UserInputService.PreferredInput ~= Enum.PreferredInput.Gamepad or VRService.VREnabled
	end

	clearButton.Activated:Connect(Reset)
	searchBox:GetPropertyChangedSignal("Text"):Connect(OnSearchTextChanged)

	UpdateInputMode()
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(UpdateInputMode)
	VRService:GetPropertyChangedSignal("VREnabled"):Connect(UpdateInputMode)

	return {
		UpdateSlots = UpdateSlots,
		ScrollToNewInventorySlot = ScrollToNewInventorySlot,
		Reset = Reset,
		SetOpen = SetOpen,
	}
end

return Create
