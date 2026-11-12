--!strict
-- Token bucket por chave (ex.: por jogador). Capacidade e recarga vêm do Config.Netcode.RemoteBudgets.

export type RateLimiter = {
	Allow: (self: RateLimiter, key: any, cost: number?) -> boolean,
	Forget: (self: RateLimiter, key: any) -> (),
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	local self = { _capacity = capacity, _refill = refillPerSecond, _buckets = {} }
	return (setmetatable(self, RateLimiter) :: any) :: RateLimiter
end

function RateLimiter:Allow(key: any, cost: number?): boolean
	local now = os.clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { Tokens = self._capacity, Last = now }
		self._buckets[key] = bucket
	end
	bucket.Tokens = math.min(self._capacity, bucket.Tokens + (now - bucket.Last) * self._refill)
	bucket.Last = now
	local price = cost or 1
	if bucket.Tokens >= price then
		bucket.Tokens -= price
		return true
	end
	return false
end

function RateLimiter:Forget(key: any)
	self._buckets[key] = nil
end

return RateLimiter
