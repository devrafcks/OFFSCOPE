--[[
	Registry — tabela de serviços preenchida pelo Main.server.
	Serviços acessam uns aos outros por aqui EM TEMPO DE EXECUÇÃO (nunca no topo do módulo),
	o que evita require circular sem precisar de framework.
]]

local Registry = {} :: { [string]: any }

return Registry
