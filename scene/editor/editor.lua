local lg, lm = love.graphics, love.mouse

local isCursorSupported = lm.isCursorSupported()
local cursor_sizewe, cursor_sizeall, cursor_ibeam, cursor_hand
if isCursorSupported then
  cursor_sizewe = lm.getSystemCursor("sizewe")
  cursor_sizeall = lm.getSystemCursor("sizeall")
  cursor_ibeam = lm.getSystemCursor("ibeam")
  cursor_hand = lm.getSystemCursor("hand")
end

local sysl = require("libs.SYSL-Text")
local nfs = require("libs.nativefs")
local flux = require("libs.flux")

local settings = require("util.settings")
local fileUtil = require("util.file")
local assets = require("util.assets")

local undo = require("src.undo")

local movingGrid = false

local editor = { 
  gridX = 0, gridY = 0,
  gridScale = 0
}

editor.load = function(project, suit)
  editor.project = project
  editor.suit = suit
end

editor.unload = function()
  editor.project = nil
  if isCursorSupported then
    lm.setCursor(nil)
  end
end

editor.update = function(dt)

end

editor.updateui = function()

end

local drawGrid = function(x, y, tileW, tileH, w, h, scale)
  scale = scale or editor.suit.scale
  scale = scale + editor.gridScale
  lg.push("all")
  lg.setLineWidth(math.min(.8 / (scale * 1.5) - editor.gridScale, .4))
  lg.setColor(.6,.6,.7)

  local scaledW, scaledH = tileW * scale, tileH * scale
  local offsetX, offsetY = x % scaledW, y % scaledH

  x = x > 0 and -x or x
  y = y > 0 and -y or y
  
  for i=-scaledW + offsetX, w, scaledW do
    lg.line(i, y, i, h)
  end
  for i=-scaledH + offsetY, h, scaledH do
    lg.line(x, i, w, i)
  end
  lg.pop()
end

editor.draw = function()
  drawGrid(editor.gridX,editor.gridY, 20,20, lg.getDimensions())
end

editor.drawAboveUI = function()

end

editor.resize = function(_, _)

end

editor.mousepressed = function(x,y, button)
  if button == 1 and not editor.suit:anyHovered() then
    movingGrid = true
    if cursor_sizeall then
      lm.setCursor(cursor_sizeall)
    end
  end
end

editor.mousemoved = function(_, _, dx, dy)
  if movingGrid then
    editor.gridX = editor.gridX + dx
    editor.gridY = editor.gridY + dy
  end
end

editor.mousereleased = function(_,_, button)
  if movingGrid then
    movingGrid = false
    lm.setCursor(nil)
  end
end

editor.wheelmoved = function( _, y)
  editor.gridScale = editor.gridScale + y * 0.05
  if editor.gridScale < -.5 then
    editor.gridScale = -.5
  elseif editor.gridScale > 1.2 then
    editor.gridScale = 1.2
  end
end

return editor 