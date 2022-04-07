local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Monowheel = require(ServerScriptService.MonowheelModule)

for _, vehicle in pairs(Workspace.Monowheels:GetChildren()) do
	Monowheel.new(vehicle)
end
