local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local buildGui = playerGui:WaitForChild("BuildGui")

local client = script.Parent.Parent
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local Blocks = require(ReplicatedStorage.Shared.Blocks)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Zap = require(client.network)

local GRID_CELL_SIZE = 4
local PREVIEW_TRANSPARENCY = 0.5
local PREVIEW_HIDDEN_TRANSPARENCY = 1

local BuildController = {
	CanBuild = true,
	BuildMode = false,
	InDeleteMode = false,
	SelectedUnit = nil,
	PreviewModel = nil,
	PreviewModelSize = nil,
	Plot = nil,
	CurrentPreviewCell = nil,
	PreviewState = nil,
	PreviewDirty = true,
	PreviewVisible = false,
	PreviewLastCFrame = nil,
	Trove = Trove.new(),
	CellStackCounts = {},
	OccupiedPositions = {},
	DeleteMode = false,
	DeleteTrove = Trove.new(),
	HoveredUnit = nil,
	SelectionBox = nil,
}

function BuildController:ClickBuild()
	self.BuildMode = not self.BuildMode

	if self.BuildMode then
		self:ExitDeleteMode()
		buildGui.Tools.Build.Image = buildGui.Tools.Build.PressedImage
		buildGui.Tools.Delete.Image = "rbxassetid://82271091328799"

		buildGui.ColorBoard.Visible = true
	else
		self:Unbind()
		buildGui.Tools.Build.Image = "rbxassetid://131266569874999"
		buildGui.ColorBoard.Visible = false
	end
end

function BuildController:ClickDelete()
	self.DeleteMode = not self.DeleteMode
	self:Unbind()

	if self.DeleteMode then
		self:EnterDeleteMode()
		buildGui.Tools.Delete.Image = buildGui.Tools.Delete.PressedImage
		buildGui.Tools.Build.Image = "rbxassetid://131266569874999"
		buildGui.ColorBoard.Visible = false
	else
		buildGui.Tools.Delete.Image = "rbxassetid://82271091328799"
	end
end

function BuildController:Init()
	Zap.EnableBuildMode.On(function(plot: Part?)
		self.Plot = plot
		self.CanBuild = true
		buildGui.Enabled = true
	end)

	Zap.DisableBuildMode.On(function()
		self.Plot = nil
		self.CanBuild = false
		buildGui.Enabled = false
	end)

	for _, color: GuiButton in buildGui.ColorBoard.Container:GetChildren() do
		if color:IsA("UIListLayout") then
			continue
		end

		color.MouseButton1Click:Connect(function()
			if not self.CanBuild then
				return
			end

			if self.SelectedUnit ~= nil then
				if self.SelectedUnit == color.Name then
					self:Unbind()
				else
					self:BindBlock(color.Name)
				end
			else
				self:BindBlock(color.Name)
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if not self.CanBuild then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.One then
				self:ClickBuild()
			elseif input.KeyCode == Enum.KeyCode.Two then
				self:ClickDelete()
			end
		end
	end)

	buildGui.Tools.Build.MouseButton1Click:Connect(function()
		if not self.CanBuild then
			return
		end

		self:ClickBuild()
	end)

	buildGui.Tools.Delete.MouseButton1Click:Connect(function()
		if not self.CanBuild then
			return
		end

		self:ClickDelete()
	end)
end

function BuildController:EnterBuildMode() end

function BuildController:ExitBuildMode() end

function BuildController:BindBlock(block: string)
	local template = buildGui.ColorBoard.Container:FindFirstChild(block)
	if template then
		template.UIStroke.Enabled = true
	end

	self:Unbind()

	self.SelectedUnit = block
	self:RefreshOccupiedCells()
	self.PreviewModel = self:CreatePreview(block)

	if self.PreviewModel then
		self.PreviewModelSize = self.PreviewModel.Size
		self.PreviewVisible = false
		self.PreviewDirty = true
	else
		return
	end

	self.Trove:Add(RunService.RenderStepped:Connect(function()
		self:UpdatePreview()
	end))

	self.Trove:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if UserInputService:GetFocusedTextBox() then
				return
			end

			self:TryPlace()
		elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.R then
			print("rotate")
		elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.T then
			print("flip")
		elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.F then
			print("reform")
		end
	end))
end

function BuildController:Unbind()
	if self.SelectedUnit then
		local template = buildGui.ColorBoard.Container:FindFirstChild(self.SelectedUnit)
		if template then
			template.UIStroke.Enabled = false
		end
	end

	self.SelectedUnit = nil
	self.CurrentPreviewCell = nil
	self.CurrentPlot = nil
	self.PreviewModelSize = nil
	self.PreviewDirty = true
	self.PreviewVisible = false
	self.PreviewLastCFrame = nil
	mouse.TargetFilter = nil

	if self.PreviewModel then
		self.PreviewModel:Destroy()
		self.PreviewModel = nil
	end

	self.Trove:Destroy()
	self.Trove = Trove.new()
end

function BuildController:WorldToGrid(worldPosition, base, blockSize)
	local localPos = base.CFrame:PointToObjectSpace(worldPosition)

	local cellSizeX = blockSize.X or GRID_CELL_SIZE
	local cellSizeZ = blockSize.Z or GRID_CELL_SIZE
	local cellSizeY = blockSize.Y or GRID_CELL_SIZE

	local xIndex = math.floor((localPos.X + base.Size.X * 0.5) / cellSizeX)
	local zIndex = math.floor((localPos.Z + base.Size.Z * 0.5) / cellSizeZ)
	local layer = math.floor((localPos.Y - base.Size.Y * 0.5) / cellSizeY)

	return xIndex, zIndex, layer
end

function BuildController:GridToWorld(xIndex, zIndex, layer, base, blockSize)
	local cellSizeX = blockSize.X or GRID_CELL_SIZE
	local cellSizeZ = blockSize.Z or GRID_CELL_SIZE
	local cellSizeY = blockSize.Y or GRID_CELL_SIZE

	local localX = -base.Size.X * 0.5 + (xIndex * cellSizeX) + (cellSizeX * 0.5)
	local localZ = -base.Size.Z * 0.5 + (zIndex * cellSizeZ) + (cellSizeZ * 0.5)
	local localY = base.Size.Y * 0.5 + (layer * cellSizeY) + (cellSizeY * 0.5)

	return base.CFrame * CFrame.new(localX, localY, localZ)
end

function BuildController:RefreshOccupiedCells()
	self.CellStackCounts = {}
	self.OccupiedPositions = {}

	local plot = self.Plot
	if not plot then
		return
	end

	local blockSize = self.PreviewModelSize or Vector3.new(GRID_CELL_SIZE, GRID_CELL_SIZE, GRID_CELL_SIZE)

	for _, placed in ipairs(self.Plot.Parent.Units:GetChildren()) do
		if placed:IsA("Instance") then
			local currentCFrame, _ = placed:GetBoundingBox()
			local x, z, layer = self:WorldToGrid(currentCFrame.Position, plot, blockSize)
			local key = `{x},{z}`

			self.CellStackCounts[key] = (self.CellStackCounts[key] or 0) + 1
			self.OccupiedPositions[`{x},{z},{layer}`] = true
		end
	end
end

function BuildController:CreatePreview(block: string)
	local unit = Instance.new("Part")
	unit.Size = Vector3.new(GRID_CELL_SIZE, GRID_CELL_SIZE, GRID_CELL_SIZE)
	unit.Color = Blocks[block].color
	unit.Anchored = true
	unit.CanCollide = false
	unit.Transparency = PREVIEW_TRANSPARENCY
	unit.Parent = workspace
	mouse.TargetFilter = unit

	return unit
end

function BuildController:UpdatePreview()
	if not self.PreviewModel then
		return
	end

	local plot = self.Plot
	if not plot then
		self.PreviewModel.Transparency = PREVIEW_HIDDEN_TRANSPARENCY
		self.CurrentPreviewCell = nil
		self.PreviewVisible = false
		return
	end

	local blockSize = self.PreviewModelSize
	local mouseX, mouseY = mouse.X, mouse.Y
	local cameraCFrame = camera.CFrame

	if self.PreviewState and not self.PreviewDirty then
		local last = self.PreviewState
		if last.mouseX == mouseX and last.mouseY == mouseY and last.cameraCFrame == cameraCFrame then
			return
		end
	end

	self.PreviewState = {
		mouseX = mouseX,
		mouseY = mouseY,
		cameraCFrame = cameraCFrame,
	}
	self.PreviewDirty = false

	local xIndex, zIndex, targetLayer, targetCFrame = nil, nil, nil, nil

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include

	local filterDescendants = { plot }
	if self.Plot.Parent:FindFirstChild("Units") then
		table.insert(filterDescendants, self.Plot.Parent.Units)
	end

	rayParams.FilterDescendantsInstances = filterDescendants

	local unitRay = camera:ScreenPointToRay(mouseX, mouseY)
	local rayResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rayParams)

	if rayResult then
		local placePosition = rayResult.Position + (rayResult.Normal * ((blockSize.X or GRID_CELL_SIZE) * 0.1))
		local testX, testZ, testLayer = self:WorldToGrid(placePosition, plot, blockSize)
		local cellSizeX = blockSize.X or GRID_CELL_SIZE
		local cellSizeZ = blockSize.Z or GRID_CELL_SIZE
		local xCount = math.floor(plot.Size.X / cellSizeX)
		local zCount = math.floor(plot.Size.Z / cellSizeZ)

		if testX >= 0 and testX < xCount and testZ >= 0 and testZ < zCount and testLayer >= 0 then
			if not self.OccupiedPositions[`{testX},{testZ},{testLayer}`] then
				xIndex = testX
				zIndex = testZ
				targetLayer = testLayer
				targetCFrame = self:GridToWorld(xIndex, zIndex, targetLayer, plot, blockSize)
			end
		end
	end

	if not targetCFrame then
		if self.PreviewVisible then
			self.PreviewModel.Transparency = PREVIEW_HIDDEN_TRANSPARENCY
			self.PreviewVisible = false
		end

		self.CurrentPreviewCell = nil
		return
	end

	if not self.PreviewVisible then
		self.PreviewModel.Transparency = PREVIEW_TRANSPARENCY
		self.PreviewVisible = true
	end

	if not self.PreviewLastCFrame or self.PreviewLastCFrame ~= targetCFrame then
		self.PreviewModel.CFrame = targetCFrame
		self.PreviewLastCFrame = targetCFrame
	end

	self.CurrentPreviewCell = {
		x = xIndex,
		z = zIndex,
		layer = targetLayer,
		cframe = targetCFrame,
	}
end

function BuildController:TryPlace()
	if not self.SelectedUnit or not self.CurrentPreviewCell or not self.Plot then
		return
	end

	local key = `{self.CurrentPreviewCell.x},{self.CurrentPreviewCell.z}`
	self.CellStackCounts[key] = (self.CellStackCounts[key] or 0) + 1
	self.OccupiedPositions[`{self.CurrentPreviewCell.x},{self.CurrentPreviewCell.z},{self.CurrentPreviewCell.layer}`] =
		true

	Zap.PlaceUnit.Fire(self.SelectedUnit, self.CurrentPreviewCell.cframe, self.Plot)

	self.PreviewDirty = true
end

function BuildController:ToggleDeleteMode(bool: boolean)
	if bool then
		self:EnterDeleteMode()
	else
		self:ExitDeleteMode()
	end
end

function BuildController:EnterDeleteMode()
	self:Unbind()
	self.BuildMode = false

	self.SelectionBox = Instance.new("SelectionBox")
	self.SelectionBox.Color3 = Color3.fromRGB(255, 50, 50)
	self.SelectionBox.LineThickness = 0.05
	self.SelectionBox.SurfaceTransparency = 0.75
	self.SelectionBox.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
	self.SelectionBox.Parent = workspace
	self.SelectionBox.Adornee = nil

	self.DeleteTrove:Add(RunService.RenderStepped:Connect(function()
		self:UpdateDeleteHover()
	end))

	self.DeleteTrove:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if UserInputService:GetFocusedTextBox() then
				return
			end

			self:TryDelete()
		end
	end))
end

function BuildController:ExitDeleteMode()
	self.HoveredUnit = nil
	self.DeleteMode = false

	if self.SelectionBox then
		self.SelectionBox:Destroy()
		self.SelectionBox = nil
	end

	self.DeleteTrove:Destroy()
	self.DeleteTrove = Trove.new()
end

function BuildController:UpdateDeleteHover()
	if not self.Plot then
		return
	end

	local unitsFolder = self.Plot.Parent:FindFirstChild("Units")
	if not unitsFolder then
		if self.SelectionBox then
			self.SelectionBox.Adornee = nil
		end

		self.HoveredUnit = nil
		return
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { unitsFolder }

	local mouseX, mouseY = mouse.X, mouse.Y
	local unitRay = camera:ScreenPointToRay(mouseX, mouseY)
	local rayResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, rayParams)

	if rayResult and rayResult.Instance then
		local hitPart = rayResult.Instance
		local block = nil

		local current = hitPart
		while current and current ~= unitsFolder do
			if current.Parent == unitsFolder then
				block = current
				break
			end
			current = current.Parent
		end

		if block and block:IsA("Model") then
			self.HoveredUnit = block
			if self.SelectionBox then
				self.SelectionBox.Adornee = block
			end
			return
		end
	end

	self.HoveredUnit = nil
	if self.SelectionBox then
		self.SelectionBox.Adornee = nil
	end
end

function BuildController:TryDelete()
	if not self.HoveredUnit then
		return
	end

	local unitId = self.HoveredUnit:GetAttribute("id")
	if not unitId then
		warn("[BuildController]: Hovered block has no id attribute")
		return
	end

	local plotBase = self.Plot and self.Plot:FindFirstChild("Base")
	if plotBase and self.PreviewModelSize then
		local blockCFrame, _ = self.HoveredUnit:GetBoundingBox()
		local x, z, layer = self:WorldToGrid(blockCFrame.Position, plotBase, self.PreviewModelSize)

		local key = `{x},{z}`
		if self.CellStackCounts[key] then
			self.CellStackCounts[key] = math.max(0, self.CellStackCounts[key] - 1)
		end
		self.OccupiedPositions[`{x},{z},{layer}`] = nil
	elseif plotBase then
		local defaultSize = Vector3.new(GRID_CELL_SIZE, GRID_CELL_SIZE, GRID_CELL_SIZE)
		local blockCFrame, _ = self.HoveredUnit:GetBoundingBox()
		local x, z, layer = self:WorldToGrid(blockCFrame.Position, plotBase, defaultSize)

		local key = `{x},{z}`
		if self.CellStackCounts[key] then
			self.CellStackCounts[key] = math.max(0, self.CellStackCounts[key] - 1)
		end
		self.OccupiedPositions[`{x},{z},{layer}`] = nil
	end

	if self.SelectionBox then
		self.SelectionBox.Adornee = nil
	end

	--Zap.RemoveUnit.Fire(unitId)

	self.HoveredUnit = nil
end

return BuildController
