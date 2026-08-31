local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServiceTyped = require(ReplicatedStorage.Packages.DataServiceTyped)

return DataServiceTyped({
	template = {
		Money = 0 :: number,
	},

	useMock = true,
})