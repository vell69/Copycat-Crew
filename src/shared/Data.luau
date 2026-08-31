local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServiceTyped = require(ReplicatedStorage.Packages.DataServiceTyped)

return DataServiceTyped({
	template = {
		Money = 1000000 :: number,
	},

	useMock = true,
})