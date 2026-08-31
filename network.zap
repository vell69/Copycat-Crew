opt server_output = "src/server/network.luau"
opt client_output = "src/client/network.luau"

-- [[EVENTS]]

event PlaceUnit = {
	from: Client,
	type: Reliable,
	call: ManyAsync,
	data: (name: string.utf8, cframe: CFrame)
}