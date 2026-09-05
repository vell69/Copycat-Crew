local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Blocks = require(ReplicatedStorage.Shared.Blocks)
local Data = require(ReplicatedStorage.Shared.Data).server
local Zap = require(script.Parent.Parent.network)

local PlayerService = {}

local GRID_CELL_SIZE = 4

local function getActiveUnits(player: Player): (Folder?, BasePart?)
	if player:GetAttribute("CanBuild") ~= true then
		return nil, nil
	end

	local base = workspace.Bases:FindFirstChild(`Base_{player.UserId}`)
	local units = base and base:FindFirstChild("Units")
	local plot = base and base:FindFirstChild("Plot")
	if
		not base
		or not base:IsA("Model")
		or not units
		or not units:IsA("Folder")
		or not plot
		or not plot:IsA("BasePart")
	then
		return nil, nil
	end

	return units, plot
end

local function getShape(shapeName: string): Enum.PartType?
	local success, shape = pcall(function()
		return Enum.PartType[shapeName]
	end)

	if success and shape then
		return shape
	end

	return nil
end

local function getPlacementCFrame(plot: BasePart, cframe: CFrame): CFrame?
	local localPosition = plot.CFrame:PointToObjectSpace(cframe.Position)
	local x = math.floor((localPosition.X + plot.Size.X * 0.5) / GRID_CELL_SIZE)
	local z = math.floor((localPosition.Z + plot.Size.Z * 0.5) / GRID_CELL_SIZE)
	local layer = math.floor((localPosition.Y - plot.Size.Y * 0.5) / GRID_CELL_SIZE)
	local xCount = math.floor(plot.Size.X / GRID_CELL_SIZE)
	local zCount = math.floor(plot.Size.Z / GRID_CELL_SIZE)

	if x < 0 or x >= xCount or z < 0 or z >= zCount or layer < 0 then
		return nil
	end

	local expectedPosition = plot.CFrame:PointToWorldSpace(
		Vector3.new(
			-plot.Size.X * 0.5 + x * GRID_CELL_SIZE + GRID_CELL_SIZE * 0.5,
			plot.Size.Y * 0.5 + layer * GRID_CELL_SIZE + GRID_CELL_SIZE * 0.5,
			-plot.Size.Z * 0.5 + z * GRID_CELL_SIZE + GRID_CELL_SIZE * 0.5
		)
	)

	if (cframe.Position - expectedPosition).Magnitude > 0.05 then
		return nil
	end

	return CFrame.new(expectedPosition) * cframe.Rotation
end

local function getWorkspacePlayersFolder(): Folder
	local folder = workspace:FindFirstChild("Players")

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Players"
		folder.Parent = workspace
	end

	return folder
end

function PlayerService:Init()
	local function onPlayerAdded(player: Player)
		self:_playerAdded(player)
	end

	local function onPlayerRemoving(player: Player)
		self:_playerRemoving(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player: Player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Zap.PlaceUnit.On(function(player: Player, name: string, shape: string, cframe: CFrame)
		local folder, plot = getActiveUnits(player)
		local block = Blocks[name]
		local shapeType = getShape(shape)
		local placementCFrame = folder and plot and getPlacementCFrame(plot, cframe)
		if not folder or not plot or not block or not shapeType or not placementCFrame then
			return
		end

		for _, existingUnit in folder:GetChildren() do
			if existingUnit:IsA("BasePart") and (existingUnit.Position - placementCFrame.Position).Magnitude < 0.05 then
				return
			end
		end

		local unit = Instance.new("Part")
		unit.Name = name
		unit.Color = block.color
		unit.Size = Vector3.new(4, 4, 4)
		unit.Shape = shapeType
		unit.CFrame = placementCFrame
		unit.Anchored = true
		unit.CanCollide = true
		unit.Parent = folder
		unit:SetAttribute("id", HttpService:GenerateGUID(false))
	end)

	Zap.RemoveUnit.On(function(_player: Player, unitId: string)
		local folder = getActiveUnits(_player)
		if not folder then
			return
		end

		local unit = nil

		for _, _unit in folder:GetChildren() do
			if _unit:GetAttribute("id") == unitId then
				unit = _unit
				break
			end
		end

		if not unit then
			return
		end

		unit:Destroy()
	end)
end

function PlayerService:_playerAdded(player: Player)
	player:SetAttribute("CanBuild", false)
	local playerData = Data.Service:waitForData(player)
	assert(playerData, `[Roll]: failed to fetch {player.Name}'s data`)

	local function characterAdded(character: Model)
		local playersFolder = getWorkspacePlayersFolder()
		character.Parent = playersFolder
	end

	if player.Character then
		characterAdded(player.Character)
	end

	player.CharacterAdded:Connect(characterAdded)
end

function PlayerService:_playerRemoving(player: Player)
	player:SetAttribute("CanBuild", false)
end

return PlayerService
