print('model "multi reactor v2.3" prototype 👢')
local _JEncode,_Trig,_Beep,NW=JSONEncode,TriggerPort,Beep,Network
local _system, _ram, twait = {}, {}, task.wait
_system.startTime = tick()

local targetTemp=--[[temp the reactor will aim for]] 950
local tempTolerance=--[[size of acceptable difference from `targetTemp`]] 1/6
local refuelWhen=--[[replace fuel when lower than this percentage, from 1(full) to 0(empty)]] .75
local portNetwork=--[[port id that all reactor cores use]] 1




local meltdownTemp=--[[self explanatory. doubt this needs to be changed.]] 1200
_system.DebugMode =--[[print output stuff?]] true
--[[spaghetti 🍝😋]]
local function GPart(NetworkOBJ1: NetworkPeer, ClassName: string): Instance
	return NetworkOBJ1:GetPart(ClassName)
end
local function GParts(NetworkOBJ2: NetworkPeer, ClassName: string)
	local A: {Instance} =NetworkOBJ2:GetParts(ClassName)
	return A
end
local function GPort(NetworkOBJ3: NetworkPeer, PortID: number): Instance
	return NetworkOBJ3:GetPort(PortID)
end
local function GPorts(NetworkOBJ4: NetworkPeer, PortID: number)
	local A: {Instance} =NetworkOBJ4:GetPorts(PortID)
	return A
end
local function JEncode(Data: any, repr: boolean?)
	if repr then
		return require('repr')(Data)
	end
	return _JEncode(Data)
end
local function Trig(Port: IntValue)
	_Trig(Port)
end
local function Beep(Pitch: number)
	_Beep(Pitch)return Pitch
end
local function cnfg(object: BasePart?|{BasePart}?, configuration: {[string]: ValueBase})
	local fails, err = pcall(function()object:Configure(configuration)end)
	if not err then
		return string.format('configured %s-10:%s to %s', object.ClassName, object.GUID, JEncode(configuration, 1))
	end
	fails = 0
	for _,part in object do
		local _,errr = pcall(function()part:Configure(configuration)end)
		if not errr then
			fails += 1
		end
	end
	return string.format('configured %i-4 parts to %s', #object - fails, JEncode(configuration))
end
local function Baap(logaPitch: number)
	return Beep(.1 * math.log(logaPitch + .5) / math.log(2))
end
local function Brint(...: any?)
	if _system.DebugMode then
		for N, data in {...} do
			print(data)
			Baap((N * 2)/#{...})
		end
	end
	return{...}
end

local function runAll(portNum: number, portIn: Instance)
	Brint(string.format('%i: startup 1 %s', portNum, tick() - _system.startTime), portIn.GUID)
	local reactor = GPart(portIn,'Reactor')
	local polysilicon = GPart(portIn,'Polysilicon')
	local dispenser = GPart(portIn,'Dispenser')

	local honestReaction
	local rodsActive = -1
	--[[
	local fuelRods = -1
	local tempCalc = function()return(fuelRods * (10 - rodsActive) -20) /3 end
	]]

	local function setPoly(position: number?, trigger: string?, mode: number?)
		if mode then
			cnfg(polysilicon, {PolysiliconMode = mode, Frequency = position})
			polysilicon:Trigger()
			return
		end
		if position >=0 then
			cnfg(polysilicon, {PolysiliconMode = 0, Frequency = 10})
			polysilicon:Trigger()
			if position < 10 then
				cnfg(polysilicon, {PolysiliconMode = 1, Frequency = 10 - position})
				polysilicon:Trigger()
			end
			rodsActive = math.clamp(position, 0, 10)
		end
		return Brint(string.format('poly[%i]:{ rodPos:%-2i, trigger:%-3s, rodsActive:%-2i, tempReading:%s }',
			portNum, position, trigger, rodsActive, reactor:GetTemp()))[1]
	end

	local function setFuel(amount: number?)
		amount = math.clamp(math.floor(amount), 0,4) or 0
		local req,eject = 0,0
		for fRod, fuelAm in reactor:GetFuel()do
			fRod = fRod - amount -1
			if fRod < 0 and fuelAm <= refuelWhen then
				req+=1
				if fuelAm > 0 then
					eject+=1
				end
			end
			if fRod >= 0 then
				if fuelAm > 0 then
					eject+=1
				end
			end
		end
		if eject > 0 then
			setPoly(eject, 'eject', 2)
		end
		for _=1,math.clamp(req,0,amount) do
			dispenser:Dispense()
		end
		Brint(amount..' requires '..req)
	end

	local function reactional()
		honestReaction:Unbind()

		local currentTemp = reactor:GetTemp()

		if rodsActive == 5
			and currentTemp > targetTemp - tempTolerance
			and currentTemp <= targetTemp +1e-9 then
			setFuel(4)
			setPoly(5, 'idle, '.. tick() - _system.startTime)
			twait(Brint('idle',
				(4*(meltdownTemp-targetTemp)/5)/(20/3)
				)[2])
			honestReaction = reactor.Loop:Connect(reactional)
			return
		end

		if currentTemp < targetTemp - tempTolerance then
			setPoly(math.clamp(3.3* (	(currentTemp - (targetTemp - (20/3)))
				/			(targetTemp - (targetTemp - (20/3)))
				), 0,10), 'underheat')

			setFuel(4- math.clamp(	(currentTemp - (targetTemp - (20/3)))
				/			(targetTemp - (targetTemp - (20/3)))
				,0,1))

			twait(Brint('underheat',math.clamp(
				4*(targetTemp-currentTemp)/(20/3)
					/5
				,0,120))[2])

		elseif currentTemp > targetTemp - tempTolerance
			and currentTemp <= targetTemp +1e-9--[[float tolerance...]]then
			setFuel(4)
			setPoly(5, 'stable')

		elseif currentTemp > targetTemp then
			setPoly(10, 'overheat')
			setFuel(4)
			twait(Brint('overheat',math.clamp((currentTemp-targetTemp)/(20/3),0,10))[2])
		end

		honestReaction = reactor.Loop:Connect(reactional)
		return
	end
	honestReaction = reactor.Loop:Connect(reactional)
	Brint(string.format('%i: startup 2 %s', portNum, tick() - _system.startTime))
end

for N,port in NW:GetSubnet(portNetwork):GetPorts(portNetwork)do
	coroutine.wrap(runAll)(N,NW:GetSubnet(port))
end

--[[ debug microphone
if GetPart('Microphone')then
	GetPart('Microphone').Chatted:Connect(function(plr,msg)
		msg = string.split(msg, ' ')
		if'/c'==msg[1]then
			if'debug'==msg[2]then
				_system.DebugMode = msg[3]
			end
			if tonumber(msg[2])then
				targetTemp = tonumber(msg[2])
			end
		end
		print(plr,JEncode(msg))
	end)
end
]]
print('meow. (code init done 🐱)')
wait(1e9)print('uhh...')
