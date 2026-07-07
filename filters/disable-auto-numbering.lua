-- disable-auto-numbering.lua
-- Converts ordered lists into plain text paragraphs with manual numbering.
-- This prevents Word from applying its own auto-numbering styles.

function OrderedList(el)
  local blocks = {}
  local start = el.start or 1
  local style = el.style or "Decimal"

  for i, item in ipairs(el.content) do
    local num = start + i - 1
    local prefix = ""

    if style == "Decimal" then
      prefix = tostring(num) .. ". "
    elseif style == "UpperAlpha" then
      prefix = string.char(64 + ((num - 1) % 26) + 1) .. ". "
    elseif style == "LowerAlpha" then
      prefix = string.char(96 + ((num - 1) % 26) + 1) .. ". "
    elseif style == "UpperRoman" then
      prefix = _to_roman(num) .. ". "
    elseif style == "LowerRoman" then
      prefix = _to_roman(num):lower() .. ". "
    else
      prefix = tostring(num) .. ". "
    end

    -- Get the content of the first block (usually a Plain or Para)
    local item_content = item[1] and item[1].content or {}
    table.insert(blocks, pandoc.Para({pandoc.Str(prefix), table.unpack(item_content)}))
  end

  return blocks
end

-- Simple Roman numeral converter
function _to_roman(n)
  local vals = {100, 90, 50, 40, 10, 9, 5, 4, 1}
  local syms = {"C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"}
  local result = ""
  for i = 1, #vals do
    while n >= vals[i] do
      result = result .. syms[i]
      n = n - vals[i]
    end
  end
  return result
end
