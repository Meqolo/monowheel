local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.Packages.Maid)

local FORWARD_ANGULAR_VELOCITY = -30
local REVERSE_ANGULAR_VELOCITY = 3
local ACCELERATION = 6

local MIN_ROTATION = -40
local MAX_ROTATION = 40
local ROTATION_MULTIPLIER = 2
local YAW_DIVIDER_GYRO = 50

local MonowheelServer = {}
MonowheelServer.__index = MonowheelServer

function MonowheelServer.new(model: Model)
	local self = setmetatable({}, MonowheelServer)
	self.model = model
	self.seat = model:FindFirstChildOfClass("VehicleSeat")
	self.maid = Maid.new()
	self.desiredSpeed = 0
	self.actualSpeed = 0
	self.steer = 0
	self.orientation = 0
	self.yawOrientation = 180

	self:_detectEvents()
	self:_heartbeat()

	return self
end

function MonowheelServer:_detectEvents()
	self.maid:AddTask(self.seat:GetPropertyChangedSignal("Throttle"):Connect(function()
		local throttle = self.seat.Throttle
		self.desiredSpeed = if throttle > 0
			then FORWARD_ANGULAR_VELOCITY
			else if throttle < 0 then REVERSE_ANGULAR_VELOCITY else 0
	end))

	self.maid:AddTask(self.seat:GetPropertyChangedSignal("Steer"):Connect(function()
		self.steer = self.seat.Steer
	end))

	self.maid:AddTask(self.seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if self.seat.Occupant then
			local occupant = self.seat.Occupant.Parent:GetDescendants()
			for _, part in pairs(occupant) do
				if part:IsA("BasePart") then
					part.Massless = true
				end
			end
		end
	end))
end

function MonowheelServer:_heartbeat()
	self.maid:AddTask(RunService.Stepped:Connect(function()
		self:_stayUpright()
	end))

	self.maid:AddTask(RunService.Heartbeat:Connect(function(dt)
		--// Handle the vehicle speed
		if self.desiredSpeed > self.actualSpeed then
			self.actualSpeed += ACCELERATION * dt
		else
			self.actualSpeed -= ACCELERATION * dt * 2
		end

		self:_setMotorSpeeds()

		--// Handle the vehicle rotation
		local actualVelocity = self.seat.AssemblyLinearVelocity.Magnitude

		self.orientation -= self.steer * dt * actualVelocity * ROTATION_MULTIPLIER
		self.orientation = math.clamp(self.orientation, MIN_ROTATION, MAX_ROTATION)
	end))
end

function MonowheelServer:_stayUpright()
	self.yawOrientation += self.orientation / YAW_DIVIDER_GYRO

	self.seat.BodyGyro.CFrame = CFrame.new(self.seat.CFrame.Position)
		* CFrame.Angles(0, math.rad(self.yawOrientation), math.rad(self.orientation))
end

function MonowheelServer:_setMotorSpeeds()
	for _, motor in pairs(self.model.Monowheel:GetChildren()) do
		if motor:IsA("HingeConstraint") then
			motor.AngularVelocity = self.actualSpeed
		end
	end

	for _, motor in pairs(self.model.MonowheelSpin:GetChildren()) do
		if motor:IsA("HingeConstraint") then
			motor.AngularVelocity = self.actualSpeed
		end
	end
end

return MonowheelServer
