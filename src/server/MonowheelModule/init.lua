local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.Packages.Maid)

local FORWARD_ANGULAR_VELOCITY = 30
local REVERSE_ANGULAR_VELOCITY = -3
local ACCELERATION = 6

local MIN_ROTATION = -40
local MAX_ROTATION = 40
local ORIENTATION_OFFSET = 90

local YAW_DIVIDER = 6
local MIN_YAW = -30
local MAX_YAW = 30

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
	self.yawOrientation = 0

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
end

function MonowheelServer:_heartbeat()
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

		self.orientation += self.steer * dt * actualVelocity
		self.yawOrientation += self.steer * dt * actualVelocity
		self.orientation = math.clamp(self.orientation, MIN_ROTATION, MAX_ROTATION)
		self:_setRotation()
	end))
end

function MonowheelServer:_setRotation()
	self.seat.OrientationAttachment.Orientation = Vector3.new(0, 0, self.orientation + ORIENTATION_OFFSET)
	if self.seat.AssemblyLinearVelocity.Magnitude > 5 then
		self.model.WheelHinge.HingeConstraint.TargetAngle = math.clamp(
			self.orientation / (self.seat.AssemblyLinearVelocity.Magnitude / YAW_DIVIDER),
			MIN_YAW,
			MAX_YAW
		)
	end
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
