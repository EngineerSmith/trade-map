local undo = require("src.undo")

local color = {
  1,1,0
}

return function(editor)
  editor.addAction("Add Comment", "c", function(x, y)
    local w, h = 6, 2
    if editor.canPlaceBox(x, y, w, h) then
      editor.project.dirty = true
      undo.push(editor.addBox({
        type = "comment",
        text = "New Comment",
        x = x, y = y,
        w = w, h = h,
        color = color,
        a = .2,
      }))
    end
  end)
end