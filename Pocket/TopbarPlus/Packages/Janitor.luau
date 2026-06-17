--[[
-------------------------------------
This package was modified by ForeverHD.

PACKAGE MODIFICATIONS:
	1. Added pascalCase aliases for all methods
	2. Modified behaviour of :add so that it takes both objects and promises (previously only objects)
	3. Slight change to how promises are tracked
	4. Added isAnInstanceBeingDestroyed check to line 228
	5. Added 'OriginalTraceback' to help determine where an error was added to the janitor
	6. Likely some additional changes which weren't record here
	7. Removed comments as these were detected by Moonwave
-------------------------------------
--]]



-- Janitor
-- Original by Validark
-- Modifications by pobammer
-- roblox-ts support by OverHash and Validark
-- LinkToInstance fixed by Elttob.

const RunService = game:GetService("RunService")
const Heartbeat = RunService.PostSimulation
const function getPromiseReference()
	return false
end

const IndicesReference = newproxy(true)
getmetatable(IndicesReference).__tostring = function()
	return "IndicesReference"
end

const LinkToInstanceIndex = newproxy(true)
getmetatable(LinkToInstanceIndex).__tostring = function()
	return "LinkToInstanceIndex"
end

const METHOD_NOT_FOUND_ERROR = "Object %s doesn't have method %s, are you sure you want to add it? Traceback: %s"
const NOT_A_PROMISE = "Invalid argument #1 to 'Janitor:AddPromise' (Promise expected, got %s (%s))"

const Janitor = {
	IGNORE_MEMORY_DEBUG = true,
	ClassName = "Janitor";
	__index = {
		CurrentlyCleaning = true;
		[IndicesReference] = nil;
	};
}

const TypeDefaults = {
	["function"] = true;
	["Promise"] = "cancel";
	RBXScriptConnection = "Disconnect";
}

function Janitor.new()
	return setmetatable({
		CurrentlyCleaning = false;
		[IndicesReference] = nil;
	}, Janitor)
end

function Janitor.Is(Object)
	return type(Object) == "table" and getmetatable(Object) == Janitor
end

Janitor.is = Janitor.Is

function Janitor.__index:Add(Object, MethodName, Index)
	if Index then
		self:Remove(Index)

		local This = self[IndicesReference]
		if not This then
			This = {}
			self[IndicesReference] = This
		end

		This[Index] = Object
	end

	local objectType = typeof(Object)
	if objectType == "table" and string.match(tostring(Object), "Promise") then
		objectType = "Promise"
		--local status = Object:getStatus()
		--print("status =", status, status == "Rejected")
	end
	MethodName = MethodName or TypeDefaults[objectType] or "Destroy"
	if type(Object) ~= "function" and not Object[MethodName] then
		warn(string.format(METHOD_NOT_FOUND_ERROR, tostring(Object), tostring(MethodName), debug.traceback(nil, 2)))
	end

	const OriginalTraceback = debug.traceback("")
	self[Object] = {MethodName, OriginalTraceback}
	return Object
end
Janitor.__index.Give = Janitor.__index.Add

-- My version of Promise has PascalCase, but I converted it to use lowerCamelCase for this release since obviously that's important to do.

function Janitor.__index:AddPromise(PromiseObject)
	const Promise = getPromiseReference()
	if Promise then
		if not Promise.is(PromiseObject) then
			error(string.format(NOT_A_PROMISE, typeof(PromiseObject), tostring(PromiseObject)))
		end
		if PromiseObject:getStatus() == Promise.Status.Started then
			const Id = newproxy(false)
			const NewPromise = self:Add(Promise.new(function(Resolve, _, OnCancel)
				if OnCancel(function()
						PromiseObject:cancel()
					end) then
					return
				end

				Resolve(PromiseObject)
			end), "cancel", Id)

			NewPromise:finallyCall(self.Remove, self, Id)
			return NewPromise
		else
			return PromiseObject
		end
	else
		return PromiseObject
	end
end
Janitor.__index.GivePromise = Janitor.__index.AddPromise

-- This will assume whether or not the object is a Promise or a regular object.
function Janitor.__index:AddObject(Object)
	const Id = newproxy(false)
	const Promise = getPromiseReference()
	if Promise and Promise.is(Object) then
		if Object:getStatus() == Promise.Status.Started then
			const NewPromise = self:Add(Promise.resolve(Object), "cancel", Id)
			NewPromise:finallyCall(self.Remove, self, Id)
			return NewPromise, Id
		else
			return Object
		end
	else
		return self:Add(Object, false, Id), Id
	end
end

Janitor.__index.GiveObject = Janitor.__index.AddObject

function Janitor.__index:Remove(Index)
	const This = self[IndicesReference]
	if This then
		const Object = This[Index]

		if Object then
			const ObjectDetail = self[Object]
			const MethodName = ObjectDetail and ObjectDetail[1]

			if MethodName then
				if MethodName == true then
					Object()
				else
					const ObjectMethod = Object[MethodName]
					if ObjectMethod then
						ObjectMethod(Object)
					end
				end

				self[Object] = nil
			end

			This[Index] = nil
		end
	end

	return self
end

function Janitor.__index:Get(Index)
	const This = self[IndicesReference]
	if This then
		return This[Index]
	end
	return nil
end

function Janitor.__index:Cleanup()
	if not self.CurrentlyCleaning then
		self.CurrentlyCleaning = nil
		for Object, ObjectDetail in next, self do
			if Object == IndicesReference then
				continue
			end

			-- Weird decision to rawset directly to the janitor in Agent. This should protect against it though.
			const TypeOf = type(Object)
			if TypeOf == "string" or TypeOf == "number" then
				self[Object] = nil
				continue
			end

			const MethodName = ObjectDetail[1]
			const OriginalTraceback = ObjectDetail[2]
			const function warnUser(warning)
				const cleanupLine = debug.traceback("", 3)--string.gsub(debug.traceback("", 3), "%c", "")
				const addedLine = OriginalTraceback
				warn("-------- Janitor Error --------".."\n"..tostring(warning).."\n"..cleanupLine..""..addedLine)
			end
			if MethodName == true then
				local success, warning = pcall(Object)
				if not success then
					warnUser(warning)
				end
			else
				const ObjectMethod = Object[MethodName]
				if ObjectMethod then
					local success, warning = pcall(ObjectMethod, Object)
					const isAnInstanceBeingDestroyed = typeof(Object) == "Instance" and ObjectMethod == "Destroy"
					if not success and not isAnInstanceBeingDestroyed then
						warnUser(warning)
					end
				end
			end

			self[Object] = nil
		end

		const This = self[IndicesReference]
		if This then
			for Index in next, This do
				This[Index] = nil
			end

			self[IndicesReference] = {}
		end

		self.CurrentlyCleaning = false
	end
end

Janitor.__index.Clean = Janitor.__index.Cleanup

function Janitor.__index:Destroy()
	self:Cleanup()
	--table.clear(self)
	--setmetatable(self, nil)
end

Janitor.__call = Janitor.__index.Cleanup

const Disconnect = {Connected = true}
Disconnect.__index = Disconnect
function Disconnect:Disconnect()
	if self.Connected then
		self.Connected = false
		self.Connection:Disconnect()
	end
end

function Disconnect:__tostring()
	return "Disconnect<" .. tostring(self.Connected) .. ">"
end

function Janitor.__index:LinkToInstance(Object, AllowMultiple)
	local Connection
	const IndexToUse = AllowMultiple and newproxy(false) or LinkToInstanceIndex
	local IsNilParented = Object.Parent == nil
	const ManualDisconnect = setmetatable({}, Disconnect)

	const function ChangedFunction(_DoNotUse, NewParent)
		if ManualDisconnect.Connected then
			_DoNotUse = nil
			IsNilParented = NewParent == nil

			if IsNilParented then
				coroutine.wrap(function()
					Heartbeat:Wait()
					if not ManualDisconnect.Connected then
						return
					elseif not Connection.Connected then
						self:Cleanup()
					else
						while IsNilParented and Connection.Connected and ManualDisconnect.Connected do
							Heartbeat:Wait()
						end

						if ManualDisconnect.Connected and IsNilParented then
							self:Cleanup()
						end
					end
				end)()
			end
		end
	end

	Connection = Object.AncestryChanged:Connect(ChangedFunction)
	ManualDisconnect.Connection = Connection

	if IsNilParented then
		ChangedFunction(nil, Object.Parent)
	end

	Object = nil
	return self:Add(ManualDisconnect, "Disconnect", IndexToUse)
end

function Janitor.__index:LinkToInstances(...)
	const ManualCleanup = Janitor.new()
	for _, Object in {...} do
		ManualCleanup:Add(self:LinkToInstance(Object, true), "Disconnect")
	end

	return ManualCleanup
end

for FunctionName, Function in next, Janitor.__index do
	const NewFunctionName = string.sub(string.lower(FunctionName), 1, 1) .. string.sub(FunctionName, 2)
	Janitor.__index[NewFunctionName] = Function
end

return Janitor
