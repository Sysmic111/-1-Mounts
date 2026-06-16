local FormatNumber = {}

local Abbreviations = {
	K = 4,
	M = 7,
	B = 10,
	T = 13,
	Qa = 16,
	Qi = 19,
	Sx = 22,
	Sp = 25,
	Oc = 28,
	No = 31,
	Dc = 34,
	Ud = 37,
	Dd = 40,
	Td = 43,
	Qad = 46,
	Qu = 49,
	Sd = 52,
	St = 55,
	O = 58,
	N = 61,
	v = 64,
	Uvg = 67,
	Dvg = 70,
	Tvg = 73,
	Qvg = 76,
	Qiv = 79,
	Sxv = 82,
	Spv = 85,
	Ocv = 88,
	Nov = 91,
	Tg = 94,
	Utg = 97,
	Dtg = 100,
	Ttg = 103,
	Qtg = 106,
	bf = 109,
	bg = 112,
	bh = 115,
	bi = 118,
	bj = 121,
	bk = 124,
	bl = 127,
	bm = 130,
	bn = 133,
	bo = 136,
	bp = 139,
	bq = 142,
	br = 145,
}

local MoneyLib = {}


MoneyLib.Suffixes = {"k","M","B","T","Qa","Qi","Sx","Sp","O","N","de","Ud","DD","tdD","qdD","QnD","sxD","SpD","OcD","NvD","Vgn","UVg","DVg","TVg","qtV","QnV","SeV","SPG","OVG","NVG","TGN","UTG","DTG","tsTG","qtTG","QnTG","ssTG","SpTG","OcTG","NoTG","QdDR","uQDR","dQDR","tQDR","qdQDR","QnQDR","sxQDR","SpQDR","OQDDr","NQDDr","qQGNT","uQGNT","dQGNT","tQGNT","qdQGNT","QnQGNT","sxQGNT","SpQGNT", "OQQGNT","NQQGNT","SXGNTL"}                                              
--

local function shorten(Input)
	local Negative = Input < 0
	Input = math.abs(Input)

	local Paired = false
	for i,v in pairs(MoneyLib.Suffixes) do
		if not (Input >= 10^(3*i)) then
			Input = Input / 10^(3*(i-1))
			local isComplex = (string.find(tostring(Input),".") and string.sub(tostring(Input),4,4) ~= ".")
			Input = string.sub(tostring(Input),1,(isComplex and 4) or 3) .. (MoneyLib.Suffixes[i-1] or "")
			Paired = true
			break;
		end
	end
	if not Paired then
		local Rounded = math.floor(Input)
		Input = tostring(Rounded)
	end

	if Negative then
		return "-"..Input
	end
	return Input
end

function FormatNumber:formatNumberCoins(number)
	local number = math.floor(number)
	local text = string.format("%.0f",number)
	local chosenAbbreviation
	for i, v in pairs(Abbreviations) do
		if #text >= v and #text < (v+3) then
			chosenAbbreviation = i
			break
		end
	end

	if chosenAbbreviation then
		local digits = Abbreviations[chosenAbbreviation]
		local rounded = math.floor(number/10 ^ (digits - 3)) * 10 ^ (digits - 3)

		text = "" .. string.format("%.2f",(rounded / 10 ^ (digits -1))) .. chosenAbbreviation
	else
		text = "" .. string.format("%.0f",number)
	end
	return shorten(number)   --text
end

function FormatNumber:formatNumberDecimals(number)
	local text = string.format("%.0f",number)
	local chosenAbbreviation
	for i, v in pairs(Abbreviations) do
		if #text >= v and #text < (v+3) then
			chosenAbbreviation = i
			break
		end
	end

	if chosenAbbreviation then
		local digits = Abbreviations[chosenAbbreviation]
		local rounded = math.floor(number/10 ^ (digits - 3)) * 10 ^ (digits - 3)

		text = "" .. string.format("%.2f",(rounded / 10 ^ (digits -1))) .. chosenAbbreviation
	else
		text = "" .. string.format("%.2f",number)
	end
	return text
end

function FormatNumber:formatNumberDiamonds(number)
	local text = tostring(math.floor(number))
	local chosenAbbreviation
	for i, v in pairs(Abbreviations) do
		if #text >= v and #text < (v+3) then
			chosenAbbreviation = i
			break
		end
	end

	if chosenAbbreviation then
		local digits = Abbreviations[chosenAbbreviation]
		local rounded = math.floor(number/10 ^ (digits - 2)) * 10 ^ (digits - 2)

		text = string.format("%.1f",rounded / 10 ^ (digits -1)) .. chosenAbbreviation
	else
		text = number
	end
	return text
end

function FormatNumber:formatDateTime(timeTook)

	local hours = math.floor(timeTook / 3600)
	timeTook = timeTook - (hours * 3600)

	local minutes = math.floor(timeTook / 60)
	timeTook = timeTook - (minutes * 60)

	local seconds = math.floor(timeTook)
	timeTook = timeTook - seconds

	return (string.format("%0.2i:%0.2i:%0.2i", hours, minutes, seconds))
end

function FormatNumber:formatDateTimeName(timeTook)

	local days = math.floor(timeTook / 86400)
	timeTook = timeTook - (days * 86400)

	local hours = math.floor(timeTook / 3600)
	timeTook = timeTook - (hours * 3600)

	local minutes = math.floor(timeTook / 60)
	timeTook = timeTook - (minutes * 60)

	local seconds = math.floor(timeTook)
	timeTook = timeTook - seconds

	return (string.format("%dd:%dh:%dm", days, hours, minutes))
end

function FormatNumber:formatNumberWithCommas(number)
	local formatted = tostring(number)
	local count
	repeat
		formatted, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return formatted
end

function FormatNumber:formatTimeRemaining(seconds)
	if seconds < 3600 then
		-- Calcular minutos
		local minutes = math.floor(seconds / 60)
		return minutes .. (minutes == 1 and " minute" or " minutes")
	else
		-- Calcular horas
		local hours = math.floor(seconds / 3600)
		return hours .. (hours == 1 and " hour" or " hours")
	end
end

return FormatNumber
