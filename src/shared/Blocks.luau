export type BlockData = {
	name: string,
	color: Color3,
}

return {
	["Red"] = {
		name = "Red Block",
		color = Color3.fromRGB(196, 40, 28),
	},

	["Blue"] = {
		name = "Blue Block",
		color = Color3.fromRGB(4, 175, 236),
	},

	["Green"] = {
		name = "Green Block",
		color = Color3.fromRGB(75, 151, 75),
	},

	["Yellow"] = {
		name = "Yellow Block",
		color = Color3.fromRGB(255, 255, 0),
	},

	["Orange"] = {
		name = "Orange Block",
		color = Color3.fromRGB(255, 221, 2),
	},

	["Purple"] = {
		name = "Purple Block",
		color = Color3.fromRGB(98, 37, 209),
	},
} :: { [string]: BlockData }
