local undo = { 
  list = { },
  redo = { }
}

undo.push = function(func, ...)
  if #undo.redo ~= 0 then
    undo.redo = { }
  end
  table.insert(undo.list, {func, ...})
end

undo.pop = function()
  local i = #undo.list
  if i >= 1 then
    local func = undo.list[i][1]
    local redoTbl = {func(unpack(undo.list[i], 2))}
    if #redoTbl ~= 0 then
      table.insert(undo.redo, redoTbl)
    end
    table.remove(undo.list, i)
    return true
  end
end

undo.redoPop = function()
  local i = #undo.redo
  if i >= 1 then
    local func = undo.redo[i][1]
    local undoTbl = {func(unpack(undo.redo[i], 2))}
    if #undoTbl ~= 0 then
      table.insert(undo.list, undoTbl)
    end
    table.remove(undo.redo, i)
    return true
  end
end

undo.clear = function()
  undo.list = { }
end

return undo