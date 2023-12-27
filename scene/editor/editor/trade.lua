local undo = require("src.undo")

return function(editor)
  editor.addAction("Add Trade", "t", function(x, y)
    local w, h = 6, 2
    if editor.canPlaceBox(x, y, w, h) then

      local companyAbb, agreementName = editor.getUnassignedTrade()
      
      if companyAbb then
        editor.project.dirty = true
        editor.project:getInstanceInfo().tradeBoxes[companyAbb][agreementName] = true

        undo.push(editor.addBox({
          type = "trade",
          company = companyAbb,
          agreement = agreementName,
          x = x, y = y,
          w = w, h = h,
        }))
      else
        undo.push(editor.addBox({
          type = "trade",
          company = nil,
          agreement = nil,
          x = x, y = y,
          w = w, h = h,
        }))
      end
    end
  end)
end