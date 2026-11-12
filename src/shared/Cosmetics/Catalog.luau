--!strict
-- Consultas sobre Config.Cosmetics (só leitura).

local Config = require(script.Parent.Parent.Config)

local Catalog = {}

export type Item = Config.CosmeticDef & { Id: string }

local cache: { [string]: Item } = {}
for id, def in Config.Cosmetics do
	local item = table.clone(def) :: any
	item.Id = id
	cache[id] = item :: Item
end

function Catalog.Get(id: string?): Item?
	if id == nil then
		return nil
	end
	return cache[id]
end

function Catalog.All(): { Item }
	local list = {}
	for _, item in cache do
		table.insert(list, item)
	end
	table.sort(list, Catalog.Compare)
	return list
end

-- Ordena por categoria, raridade e preço — vitrines estáveis em todo cliente.
function Catalog.Compare(a: Item, b: Item): boolean
	if a.Category ~= b.Category then
		return a.Category < b.Category
	end
	local ra = Config.Rarities[a.Rarity].Order
	local rb = Config.Rarities[b.Rarity].Order
	if ra ~= rb then
		return ra < rb
	end
	if (a.PriceCoins or 0) ~= (b.PriceCoins or 0) then
		return (a.PriceCoins or 0) < (b.PriceCoins or 0)
	end
	return a.Id < b.Id
end

function Catalog.ByPool(pool: string): { Item }
	local list = {}
	for _, item in cache do
		if item.Pool == pool then
			table.insert(list, item)
		end
	end
	table.sort(list, Catalog.Compare)
	return list
end

function Catalog.ByCategory(category: string): { Item }
	local list = {}
	for _, item in cache do
		if item.Category == category then
			table.insert(list, item)
		end
	end
	table.sort(list, Catalog.Compare)
	return list
end

function Catalog.IsDefault(id: string): boolean
	local item = cache[id]
	return item ~= nil and item.Pool == "default"
end

-- Item → ProductId (ou nil se não vende por Robux)
function Catalog.ProductIdFor(id: string): number?
	local item = cache[id]
	if item and item.PriceRobux and item.ProductId ~= 0 then
		return item.ProductId
	end
	return nil
end

-- ProductId → itemId (para o ProcessReceipt)
function Catalog.ItemForProduct(productId: number): string?
	if productId == 0 then
		return nil
	end
	for id, item in cache do
		if item.ProductId == productId then
			return id
		end
	end
	return nil
end

return Catalog
