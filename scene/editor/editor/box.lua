local undo = require("src.undo")

return function(editor)
  editor.addBox = function(comment, index)
    if index then
      table.insert(editor.project.boxes, index, comment)
    else
      table.insert(editor.project.boxes, comment)
      index = #editor.project.boxes
    end
    editor.project.dirty = true
    return editor.removeBox, index
  end

  editor.removeBox = function(index)
    local comment = editor.project.boxes[index]
    table.remove(editor.project.boxes, index)
    editor.project.dirty = true
    return editor.addBox, comment, index
  end
end