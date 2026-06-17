--!strict
--!optimize 2
--!native

--[[
	Signal.luau

	Public API:
	- Module returns CreateSignal().
	- CreateSignal returns a typed signal with Connect and Fire methods.
]]

export type Connection<Parameters...> = {
	Connected: boolean,
	Disconnect: (Connection<Parameters...>) -> (),
}

export type Signal<Parameters...> = {
	Connect: (Signal<Parameters...>, (Parameters...) -> ()) -> Connection<Parameters...>,
	Fire: (Signal<Parameters...>, Parameters...) -> (),
}

type ConnectionState<Parameters...> = {
	Signal: SignalState<Parameters...>?,
	Previous: ConnectionState<Parameters...>?,
	Next: ConnectionState<Parameters...>?,
	Callback: ((Parameters...) -> ())?,
	Connected: boolean,
	Disconnect: (Connection<Parameters...>) -> (),
}

type SignalState<Parameters...> = {
	Head: ConnectionState<Parameters...>?,
	Tail: ConnectionState<Parameters...>?,
	Connect: (SignalState<Parameters...>, (Parameters...) -> ()) -> Connection<Parameters...>,
	Fire: (SignalState<Parameters...>, Parameters...) -> (),
}

type CreateSignal = <Parameters...>() -> Signal<Parameters...>

const FreeThreads: { thread } = {}

const function ReusableThreadCall<Parameters...>(
	callback: (Parameters...) -> (),
	callbackThread: thread,
	...: Parameters...
)
	callback(...)
	table.insert(FreeThreads, callbackThread)
end

const function ReusableThread()
	while true do
		ReusableThreadCall(coroutine.yield())
	end
end

const function Disconnect<Parameters...>(connection: Connection<Parameters...>)
	const signalConnection = connection :: ConnectionState<Parameters...>
	if not signalConnection.Connected then
		return
	end

	signalConnection.Connected = false

	const signal = signalConnection.Signal
	if not signal then
		return
	end

	const previousConnection = signalConnection.Previous
	const nextConnection = signalConnection.Next

	if previousConnection then
		previousConnection.Next = nextConnection
	else
		signal.Tail = nextConnection
	end

	if nextConnection then
		nextConnection.Previous = previousConnection
	else
		signal.Head = previousConnection
	end

	signalConnection.Signal = nil
	signalConnection.Previous = nil
	signalConnection.Next = nil
	signalConnection.Callback = nil
end

const function Connect<Parameters...>(
	signal: SignalState<Parameters...>,
	callback: (Parameters...) -> ()
): Connection<Parameters...>
	const headConnection = signal.Head
	const connection: ConnectionState<Parameters...> = {
		Signal = signal,
		Previous = headConnection,
		Next = nil,
		Callback = callback,
		Connected = true,
		Disconnect = Disconnect,
	}

	if headConnection then
		headConnection.Next = connection
	else
		signal.Tail = connection
	end

	signal.Head = connection

	return connection :: Connection<Parameters...>
end

const function Fire<Parameters...>(signal: SignalState<Parameters...>, ...: Parameters...)
	local connection = signal.Tail

	while connection do
		const callback = connection.Callback
		if connection.Connected and callback then
			const freeThreadCount = #FreeThreads
			local callbackThread: thread
			if freeThreadCount == 0 then
				callbackThread = coroutine.create(ReusableThread)
				coroutine.resume(callbackThread)
			else
				callbackThread = FreeThreads[freeThreadCount]
				FreeThreads[freeThreadCount] = nil
			end
			task.defer(callbackThread, callback, callbackThread, ...)
		end

		connection = connection.Next
	end
end

const function CreateSignal<Parameters...>(): Signal<Parameters...>
	const signal: SignalState<Parameters...> = {
		Head = nil,
		Tail = nil,
		Connect = Connect,
		Fire = Fire,
	}

	return signal :: Signal<Parameters...>
end

return CreateSignal :: CreateSignal
