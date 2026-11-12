-- Formatação pt-BR: milhar com ponto, tempo mm:ss, distância em metros.

local Format = {}

function Format.Number(value: number): string
	local negative = value < 0
	local digits = tostring(math.floor(math.abs(value)))
	local out = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return if negative then "-" .. out else out
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- 1 stud ≈ 0,28 m (escala de avatar padrão)
function Format.Meters(studs: number): string
	return string.format("%dm", math.floor(studs * 0.28 + 0.5))
end

function Format.Plural(count: number, singular: string, plural: string): string
	return if count == 1 then `{count} {singular}` else `{count} {plural}`
end

return Format
