local color = { }

color.getDeterministicColor = function(str)
  str = str and str:lower() or ""
  local color = { }
  for index = 1, 3 do
    local c = str:sub(index, index)
    c = c ~= "" and c or "a"
    local byte = c:byte() - 97
    if byte > 25 or byte < 0 then byte = 0 end
    table.insert(color, byte / 25)
  end
  return color
end

return color