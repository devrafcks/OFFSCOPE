-- Maid: junta conexões, instâncias, threads e funções para limpar de uma vez.

export type Maid = {
	Give: <T>(self: Maid, task: T) -> T,
	Clean: (self: Maid) -> (),
	Destroy: (self: Maid) -> (),
}

local Maid = {}
Maid.__index = Maid

function Maid.new(): Maid
	return (setmetatable({ _tasks = {} }, Maid) :: any) :: Maid
end

function Maid:Give(item)
	table.insert(self._tasks, item)
	return item
end

local function cleanup(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for index = #tasks, 1, -1 do
		cleanup(tasks[index])
	end
end

Maid.Destroy = Maid.Clean

return Maid
