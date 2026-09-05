local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Zap = require(script.Parent.Parent.network)

local FIRST_ROUND = true

local PityWeights = {}
local RoundService = {}

local function setBuildAccess(player: Player, enabled: boolean)
	player:SetAttribute("CanBuild", enabled)
end

local function chooseRandomBuilder(): Player?
	local totalWeight = 0
	local weights = {}

	for _, player: Player in ipairs(Players:GetPlayers()) do
		local weight = PityWeights[player] or 1
		weights[player] = weight
		totalWeight += weight
	end

	if totalWeight <= 0 then
		return nil
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	local chosen = nil

	for _, player: Player in ipairs(Players:GetPlayers()) do
		cumulative += weights[player]
		if roll <= cumulative then
			chosen = player
			break
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player == chosen then
			PityWeights[player] = 1
		else
			PityWeights[player] = math.min((PityWeights[player] or 1) + 1, 20)
		end
	end

	return chosen
end

local function formatTime(seconds: number): string
	seconds = math.floor(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

local function getGridPosition(unit: Part, plot: BasePart): (number, number, number)
	local localPosition = plot.CFrame:PointToObjectSpace(unit.Position)
	local cellSize = 4
	local x = math.floor((localPosition.X + plot.Size.X * 0.5) / cellSize)
	local z = math.floor((localPosition.Z + plot.Size.Z * 0.5) / cellSize)
	local layer = math.floor((localPosition.Y - plot.Size.Y * 0.5) / cellSize)

	return x, z, layer
end

local function getColorSimilarity(first: Color3, second: Color3): number
	return 1 - math.max(math.abs(first.R - second.R), math.abs(first.G - second.G), math.abs(first.B - second.B))
end

local function getRotationSimilarity(first: CFrame, second: CFrame): number
	local firstComponents = { first:GetComponents() }
	local secondComponents = { second:GetComponents() }
	local similarity = 0

	for index = 4, 12 do
		similarity += 1 - math.min(math.abs(firstComponents[index] - secondComponents[index]) / 2, 1)
	end

	return similarity / 9
end

local function getUnitSimilarity(original: Part, copy: Part, originalPlot: BasePart, copyPlot: BasePart): number
	local originalX, originalZ, originalLayer = getGridPosition(original, originalPlot)
	local copyX, copyZ, copyLayer = getGridPosition(copy, copyPlot)
	local distance = math.abs(originalX - copyX) + math.abs(originalZ - copyZ) + math.abs(originalLayer - copyLayer)
	local positionSimilarity = 1 / (1 + distance)
	local shapeSimilarity = original.Shape == copy.Shape and 1 or 0
	local colorSimilarity = getColorSimilarity(original.Color, copy.Color)
	local originalRotation = originalPlot.CFrame:ToObjectSpace(original.CFrame)
	local copyRotation = copyPlot.CFrame:ToObjectSpace(copy.CFrame)
	local rotationSimilarity = getRotationSimilarity(originalRotation, copyRotation)

	return positionSimilarity * 0.55 + shapeSimilarity * 0.2 + colorSimilarity * 0.2 + rotationSimilarity * 0.05
end

local function scoreBuild(originalBase: Model, copyBase: Model): number
	local originalUnitsFolder = originalBase:FindFirstChild("Units")
	local copyUnitsFolder = copyBase:FindFirstChild("Units")
	local originalPlot = originalBase:FindFirstChild("Plot")
	local copyPlot = copyBase:FindFirstChild("Plot")

	assert(originalUnitsFolder and originalUnitsFolder:IsA("Folder"), "Original base is missing its Units folder")
	assert(copyUnitsFolder and copyUnitsFolder:IsA("Folder"), "Copy base is missing its Units folder")
	assert(originalPlot and originalPlot:IsA("BasePart"), "Original base is missing its Plot")
	assert(copyPlot and copyPlot:IsA("BasePart"), "Copy base is missing its Plot")

	local originalUnits = originalUnitsFolder:GetChildren()
	local copyUnits = copyUnitsFolder:GetChildren()

	if #originalUnits == 0 and #copyUnits == 0 then
		return 100
	elseif #originalUnits == 0 or #copyUnits == 0 then
		return 0
	end

	local availableCopies = {}
	for _, unit in copyUnits do
		if unit:IsA("Part") then
			table.insert(availableCopies, unit)
		end
	end

	local totalSimilarity = 0
	for _, originalUnit in originalUnits do
		if not originalUnit:IsA("Part") then
			continue
		end

		local bestIndex = nil
		local bestSimilarity = 0
		for index, copyUnit in availableCopies do
			local similarity = getUnitSimilarity(originalUnit, copyUnit, originalPlot, copyPlot)
			if similarity > bestSimilarity then
				bestIndex = index
				bestSimilarity = similarity
			end
		end

		if bestIndex then
			totalSimilarity += bestSimilarity
			table.remove(availableCopies, bestIndex)
		end
	end

	return totalSimilarity / math.max(#originalUnits, #copyUnits) * 100
end

function RoundService:Init()
	task.spawn(function()
		while true do
			if not RunService:IsStudio() then
				if #Players:GetPlayers() < Config.Round.REQUIRED_PLAYERS then
					print(`Waiting for more players.`)
					task.wait(1)
					continue
				end
			end

			if FIRST_ROUND then
				FIRST_ROUND = false
				for i = Config.Round.INITIALIZATION_TIME, 1, -1 do
					Zap.UpdateStatus.FireAll({
						primary = `Waiting {formatTime(i)}`,
						secondary = `for proper server initialization.`,
					})
					task.wait(1)
				end
			end

			local trove = Trove.new()

			for i = Config.Round.INTERMISSION_TIME, 1, -1 do
				Zap.UpdateStatus.FireAll({
					primary = `Intermission`,
					secondary = `{formatTime(i)}`,
				})
				task.wait(1)
			end

			Zap.UpdateStatus.FireAll({
				primary = `Choosing a random builder...`,
				secondary = ``,
			})

			local baseTemplate = workspace.Bases:FindFirstChild("Base")
			if not baseTemplate or not baseTemplate:IsA("Model") then
				warn("[RoundService]: Missing clean Base template; skipping round.")
				trove:Destroy()
				task.wait(1)
				continue
			end

			local builder = chooseRandomBuilder()
			if not builder then
				print("No players available to choose from.")
				trove:Destroy()
				continue
			end

			local copiers = Players:GetPlayers()
			if table.find(copiers, builder) then
				table.remove(copiers, table.find(copiers, builder))
			else
				print(`Chosen player {builder.Name} is no longer in the game.`)
				trove:Destroy()
				continue
			end

			local builderCharacter = builder.Character
			if not builderCharacter then
				print(`Failed to define chosen player's character.`)
				trove:Destroy()
				continue
			end

			Zap.UpdateStatus.Fire(builder, {
				primary = `You have been chosen as a builder.`,
				secondary = ``,
			})

			local spawns = baseTemplate.Spawns:GetChildren()
			local randomIndex = math.random(1, #spawns)
			local randomSpawn = spawns[randomIndex]
			builderCharacter:PivotTo(randomSpawn.CFrame)

			local originalBase = baseTemplate
			originalBase.Name = `Base_{builder.UserId}`
			setBuildAccess(builder, true)
			Zap.EnableBuildMode.Fire(builder)

			for i = Config.Round.BUILD_TIME, 1, -1 do
				Zap.UpdateStatus.FireAll({
					primary = `Waiting for the builder to finish`,
					secondary = `{formatTime(i)}`,
				})
				task.wait(1)
			end

			setBuildAccess(builder, false)
			Zap.DisableBuildMode.Fire(builder)
			Zap.UpdateStatus.FireAll({
				primary = `The builder time is up.`,
				secondary = `Now teleporting other players to take a glimpse!`,
			})

			task.wait(3)

			local copierBases: { [Player]: Model } = {}

			for _, player: Player in copiers do
				local character = player.Character
				if not character then
					continue
				end

				character:PivotTo(
					originalBase.Spawns:GetChildren()[math.random(1, #originalBase.Spawns:GetChildren())].CFrame
				)
			end

			for i = Config.Round.GLIMPSE_TIME, 1, -1 do
				Zap.UpdateStatus.FireAll({
					primary = `{formatTime(i)}`,
					secondary = ``,
				})
				task.wait(1)
			end

			Zap.UpdateStatus.FireAll({
				primary = `Glimpse time is over`,
				secondary = `now teleporting players to copy the build!`,
			})

			task.wait(3)

			for _, player: Player in copiers do
				local character = player.Character
				if not character then
					continue
				end

				local base = originalBase:Clone()
				local index = #workspace.Bases:GetChildren() + 1
				local _, size = base:GetBoundingBox()
				local x = (index - 1) * (size.X + Config.Round.BASE_SPACING)

				base.Units:ClearAllChildren()
				base.Parent = workspace.Bases
				base.Name = `Base_{player.UserId}`
				base:PivotTo(base:GetPivot() * CFrame.new(x, 0, 0))
				copierBases[player] = base
				setBuildAccess(player, true)
				character:PivotTo(base.Spawns:GetChildren()[math.random(1, #base.Spawns:GetChildren())].CFrame)
			end

			Zap.EnableBuildMode.FireList(copiers)

			for i = Config.Round.COPYING_TIME, 1, -1 do
				Zap.UpdateStatus.FireAll({
					primary = `{formatTime(i)}`,
					secondary = ``,
				})
				task.wait(1)
			end

			for _, player: Player in copiers do
				setBuildAccess(player, false)
			end
			Zap.DisableBuildMode.FireList(copiers)

			local results = {}

			for player, copyBase in copierBases do
				table.insert(results, {
					playerName = player.DisplayName,
					score = scoreBuild(originalBase, copyBase),
				})
			end

			table.sort(results, function(first, second)
				if first.score == second.score then
					return first.playerName < second.playerName
				end

				return first.score > second.score
			end)

			Zap.UpdateStatus.FireAll({
				primary = `Copying time is over`,
				secondary = `results are in`,
			})

			for rank, result in results do
				print(string.format("[Round Results] #%d %s: %.2f%%", rank, result.playerName, result.score))
			end

			task.wait(8)

			Zap.UpdateStatus.FireAll({ primary = ``, secondary = `` })

			local nextBase = originalBase:Clone()
			nextBase.Name = "Base"
			nextBase.Units:ClearAllChildren()
			workspace.Bases:ClearAllChildren()
			nextBase.Parent = workspace.Bases

			for _, player: Player in Players:GetPlayers() do
				player:LoadCharacterAsync()
			end

			trove:Destroy()
		end
	end)
end

return RoundService
