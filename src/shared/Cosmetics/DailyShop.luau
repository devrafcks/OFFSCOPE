--!strict

local Config = require(script.Parent.Parent.Config)
local Catalog = require(script.Parent.Catalog)

local DailyShop = {}

function DailyShop.Day(now: number?): number
	return (now or os.time()) // 86400
end

function DailyShop.SecondsUntilReset(now: number?): number
	local t = now or os.time()
	return 86400 - (t % 86400)
end

function DailyShop.Items(day: number?): { string }
	local d = day or DailyShop.Day()
	local rng = Random.new(d * 7919 + Config.DailyShop.Salt)
	local pool = Catalog.ByPool("daily")

	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local picked: { string } = {}
	local perCategory: { [string]: number } = {}
	local hasEpic = false

	for _, item in pool do
		if #picked >= Config.DailyShop.Slots then
			break
		end
		local count = perCategory[item.Category] or 0
		if count < 2 then
			table.insert(picked, item.Id)
			perCategory[item.Category] = count + 1
			if Config.Rarities[item.Rarity].Order >= 4 then
				hasEpic = true
			end
		end
	end

	if not hasEpic and #picked > 0 then
		for _, item in pool do
			if Config.Rarities[item.Rarity].Order >= 4 and not table.find(picked, item.Id) then
				picked[#picked] = item.Id
				break
			end
		end
	end

	return picked
end

function DailyShop.Contains(itemId: string, day: number?): boolean
	return table.find(DailyShop.Items(day), itemId) ~= nil
end

return DailyShop
