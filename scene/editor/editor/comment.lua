local color = {
  1,1,0
}

local undo = require("src.undo")
local removeComment, addComment

addComment = function(boxes, comment, index)
  if index then
    table.insert(boxes, index, comment)
  else
    table.insert(boxes, comment)
    index = #boxes
  end
  return removeComment, boxes, index
end

removeComment = function(boxes, index)
  local comment = boxes[index]
  table.remove(boxes, index)
  return addComment, boxes, comment, index
end

return function(editor)
  editor.keyListen["c"] = editor.keyListen["c"] or { }
  table.insert(editor.keyListen["c"], function(_ , x, y)
    local w, h = 6, 2
    if editor.canPlaceBox(x, y, w, h) then
      undo.push(addComment(editor.project.boxes, {
        type = "comment",
        text = "New Comment",
        x = x, y = y,
        w = w, h = h,
        color = color,
        a = .2,
      }))
      print("PLACED")
    else
      print("NOT PLACED")
    end
  end)
end