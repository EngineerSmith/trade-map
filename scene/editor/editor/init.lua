local lg, lm, lt = love.graphics, love.mouse, love.timer

local isCursorSupported = lm.isCursorSupported()
local cursor_sizewe, cursor_sizeall, cursor_ibeam, cursor_hand, cursor_sizens, cursor_sizenesw, cursor_sizenwse
if isCursorSupported then
  cursor_sizewe = lm.getSystemCursor("sizewe")
  cursor_sizens = lm.getSystemCursor("sizens")
  cursor_sizenesw = lm.getSystemCursor("sizenesw")
  cursor_sizenwse = lm.getSystemCursor("sizenwse")
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

local movingBox = false
local movingBoxPressed = false
local movingBoxSize = false
local movingBoxSizeDirection = false
local movingBoxSizeRadius = 5
local movingBoxSizeChanged = false

local rightClickMenuShow = false
local rightClickMenuX, rightClickMenuY = 0, 0

local showEditUi = false
local editUiTbl = nil

local editor = { 
  gridX = 0, gridY = 0,
  gridScale = 0,
  keyListen = { },
  keyListenOrder = { },
  tileW = 20, tileH = 20,
  activeBox = nil,
}

editor.addAction = function(actionText, scancode, func, addToRight)
   editor.keyListen[scancode] = {action = actionText, func = func}
   if addToRight ~= false then
    table.insert(editor.keyListenOrder, scancode)
   end
end
require("scene.editor.editor.box")(editor)
require("scene.editor.editor.comment")(editor)
require("scene.editor.editor.trade")(editor)

editor.addAction("Delete", "delete", function() 
    if editor.activeBox then
      local index
      for i, box in ipairs(editor.project.boxes) do
        if box == editor.activeBox then
          index = i
          break
        end
      end
      if index then
        undo.push(editor.removeBox(index))
        editor.activeBox = nil
      end
    end
  end, false)

editor.addAction("Edit", "edit", function()
  if editor.activeBox then
    showEditUi = true
    editUiTbl = { }
    editor.activeBox.forcefocus = true
  end
  end, false)

editor.load = function(project, suit)
  editor.project = project
  editor.suit = suit
  editor.resizeGrid(editor.gridScale)
end

editor.unload = function()
  editor.project = nil
  if isCursorSupported then
    lm.setCursor(nil)
  end
end

editor.update = function(dt)

end

local getFormattedShortcutText = function(scancode, text)
  local formattedText = ""
  if scancode and scancode ~= "" then
    formattedText = ("[%.3s]"):format(scancode:upper())
  end
  local leadingSpaces = 6 - #formattedText -- used to align the text
  formattedText = formattedText .. string.rep(" ", leadingSpaces) .. text
  return formattedText
end

local getCompanyLangName = function(company)
  local name = company.name
  local instanceInfo = editor.project.getInstanceInfo()
  if instanceInfo.lang then
    name = instanceInfo.lang["company.ptdye."..company.abbreviation]
    if not name or name == "" then name = company.name end
  end
  return name
end

editor.updateui = function(x, y)
  local suit = editor.suit
  suit.layout:reset(x, y, 0, 0)
  if showEditUi then
    local box = editor.activeBox

    local wsize = settings._default.client.windowSize
    local tw, th = wsize.width, wsize.height
    local w = tw*.8*suit.scale
    local h = tw*.6*suit.scale
    local x = x + lg.getWidth()/2-w/2
    local y = y + lg.getHeight()/2-h/2
    h = 0
    local padding = 4 * suit.scale
    suit.layout:reset(x, y)

    local type = (box.type or "box"):gsub("^%l", string.upper)
    local l = suit:Label(("Editing %s"):format(type),{noScaleY=true,noScaleX=true,noBox=true}, suit.layout:down(w, lg.getFont():getHeight()))
    suit:Shape(-1, {.6,.6,.6}, {noScaleY=true,noScaleX=true}, suit.layout:down(w, padding))
    suit.layout:padding(padding, padding)
    h = h + l.h + padding*2
    suit.layout:translate(padding, 0)
    local cursorChanged = false
    if box.type == "comment" then
      local i = suit:Input(box, {noScaleY=true,noScaleX=true,font=suit.monoFont}, suit.layout:down(w-padding*2, lg.getFont():getHeight()))
      h = h + lg.getFont():getHeight() + padding
      if cursor_hand and i.hovered then
        lm.setCursor(cursor_hand)
        cursorChanged = true
      elseif i.left then
        lm.setCursor(nil)
      end
      if i.submitted then
        showEditUi = false
      end
    elseif box.type == "trade" then
      local font = suit.monoFont
      local company
      if box.company then
        company = editor.project.getInstanceInfo().abbreviation[box.company]
      end
      -- company
      local title = "Company"
      local titleWidth = font:getWidth(title) + 4
      local titleHeight = font:getHeight()
      suit:Label(title, {noScaleY=true, noScaleX=true,noBox=true, font=font}, suit.layout:down(titleWidth, titleHeight))
      local name, bg
      if company then
        name = getCompanyLangName(company)
        bg = {.3,.3,.3}
      else
        name = "PLEASE SELECT"
        bg = {.7,.2,.2}
      end
      local s = suit:Button(" "..name, {id="boxCompany",noScaleY=true,noScaleX=true,color={bg=bg, fg={.95,.95,.95}},cornerRadius=0,r=0,override=true,align="left",font=font}, suit.layout:right(w-titleWidth-padding*3, titleHeight))
      if cursor_hand and s.hovered then
        lm.setCursor(cursor_hand)
        cursorChanged = true
      elseif s.left then
        lm.setCursor(nil)
      end
      if s.hit then
        editUiTbl.showDropdownCompany = not editUiTbl.showDropdownCompany
        editUiTbl.showDropdownAgreement = false
      end
      h = h + titleHeight + padding
      suit.layout:padding(0,0)
      if editUiTbl.showDropdownCompany then
        local bHeight = 0
        local touched = false
        for i, company in ipairs(editor.project.companies) do
          local hasFreeAgreements = false
          local tradeBoxes = editor.project:getInstanceInfo().tradeBoxes[box.company] or { }
          for _, agreement in ipairs(company.agreement) do
            if tradeBoxes[agreement.name] then
              hasFreeAgreements = true
            end
          end
          if not hasFreeAgreements then
            break
          end
          touched = true
          local bg = i%2 == 0 and {.27,.27,.27} or {.22,.22,.22}
          local name = getCompanyLangName(company)
          local b = suit:Button(" "..name,{noScaleY=true,noScaleX=true,color={bg=bg, fg={.95,.95,.95}},cornerRadius=0,r=0,override=true,align="left",font=font}, suit.layout:down())
          bHeight = bHeight + b.h
          if b.hit then
            box.company = company.abbreviation
            editUiTbl.showDropdownCompany = false
          end
        end
        if not touched then
          local b = suit:Button(" No Company With Free Agreements",{noScaleY=true,noScaleX=true,color={bg={.7,.2,.2}, fg={.95,.95,.95}},cornerRadius=0,r=0,override=true,align="left",font=font}, suit.layout:down())
            bHeight = bHeight + b.h
        end
        suit.layout:translate(0, -bHeight)
      end
      suit.layout:translate(-titleWidth-padding, padding)
      -- agreement
      local title = "Agreement"
      local titleWidth = font:getWidth(title) + 4
      local titleHeight = font:getHeight()
      suit:Label(title, {noScaleY=true, noScaleX=true,noBox=true, font=font}, suit.layout:down(titleWidth+padding, titleHeight))
      local bg = {.7,.2,.2}
      if box.agreement then
        for _, agreement in ipairs(company.agreement) do
          if agreement.name == box.agreement then
            bg = {.3,.3,.3}
            break
          end
        end
      end
      local text = company and (" "..(box.agreement or "PLEASE SELECT")) or "PLEASE SELECT COMPANY"
      local s = suit:Button(text, {id="boxAgreement",noScaleY=true,noScaleX=true,color={bg=bg, fg={.95,.95,.95}},cornerRadius=0,r=0,override=true,align="left",font=font}, suit.layout:right(w-titleWidth-padding*3, titleHeight))
      h = h + titleHeight + padding
      if company then
        if cursor_hand and s.hovered then
          lm.setCursor(cursor_hand)
          cursorChanged = true
        elseif s.left then
          lm.setCursor(nil)
        end
        if s.hit then
          editUiTbl.showDropdownAgreement = not editUiTbl.showDropdownAgreement
          editUiTbl.showDropdownCompany = false
        end
        suit.layout:padding(0,0)
        if editUiTbl.showDropdownAgreement then
          local bHeight = 0
          local tradeBoxes = editor.project:getInstanceInfo().tradeBoxes[box.company]
          local touched = false
          for i, agreement in ipairs(company.agreement) do
            if not tradeBoxes[agreement.name] then
              touched = true
              local bg = i%2 == 0 and {.27,.27,.27} or {.22,.22,.22}
              local b = suit:Button(" "..agreement.name,{noScaleY=true,noScaleX=true,color={bg=bg, fg={.95,.95,.95}},cornerRadius=0,r=0,override=true,align="left",font=font}, suit.layout:down())
              bHeight = bHeight + b.h
              if b.hit then
                box.agreement = agreement.name
                editUiTbl.showDropdownAgreement = false
              end
            end
          end
          if not touched then
            local b = suit:Button(" No Agreements Free",{noScaleY=true,noScaleX=true,color={bg={.7,.2,.2}, fg={.95,.95,.95}},cornerRadius=0,r=0,override=true,align="left",font=font}, suit.layout:down())
            bHeight = bHeight + b.h
          end
          suit.layout:translate(0, -bHeight)
        end
      end
      suit.layout:translate(-titleWidth, padding)
    end
    suit:Shape(-1, {.4,.4,.4}, {noScaleY=true,noScaleX=true,cornerRadius=3}, x, y, w, h)
    suit:Shape(-1, {.6,.6,.6}, {noScaleY=true,noScaleX=true,cornerRadius=3}, x-padding, y-padding, w+padding*2, h+padding*2)
    if cursor_hand and not suit:mouseInRect(x-padding, y-padding, w+padding*2, h+padding*2) then
      lm.setCursor(cursor_hand)
    elseif not cursorChanged then
      lm.setCursor(nil)
    end
  elseif rightClickMenuShow then
    local x, y = rightClickMenuX, rightClickMenuY
    local w = 0
    local setCursor = false
    local font = suit.monoFont
    for _, scancode in ipairs(editor.keyListenOrder) do
      local action = editor.keyListen[scancode].action
      local thisW = font:getWidth(getFormattedShortcutText(scancode, action)) + 4
      if w < thisW then
        w = thisW
      end
    end
    local variableHeight = 0
    local padding = 1 * suit.scale
    -- context
    if editor.activeBox then
      local text = "%s Selected %s"
      local type = (editor.activeBox.type or "box"):gsub("^%l", string.upper)
      local contextActions = {
        getFormattedShortcutText(nil, text:format("Edit", type)),
        getFormattedShortcutText("delete", text:format("Delete", type)),
      }
      for _, action in ipairs(contextActions) do
        local thisW = font:getWidth(action) + 4
        if w < thisW then
          w = thisW
        end
      end
      -- EDIT
      local contextText = contextActions[1]
      local b = suit:Button(contextText, {noScaleY=true,noScaleX=true, font=font, align="left",cornerRadius=3}, x,y+variableHeight, w, font:getHeight())
      variableHeight = variableHeight + b.h + padding
      if cursor_hand and b.entered then
        lm.setCursor(cursor_hand)
        setCursor = true
      elseif b.left and not setCursor then
        lm.setCursor(nil)
      end
      if b.hit then
        editor.keyListen["edit"].func()
        rightClickMenuShow = false
      end
      -- DELETE
      local contextText = contextActions[2]
      local b = suit:Button(contextText, {noScaleY=true,noScaleX=true, font=font, align="left",cornerRadius=3}, x,y+variableHeight, w, font:getHeight())
      variableHeight = variableHeight + b.h + padding*1.5
      if cursor_hand and b.entered then
        lm.setCursor(cursor_hand)
        setCursor = true
      elseif b.left and not setCursor then
        lm.setCursor(nil)
      end
      if b.hit then
        editor.keyListen["delete"].func()
        rightClickMenuShow = false
      end
      -- Add line to seperate context menu from shortcuts
      local s = suit:Shape(-1, {.6,.6,.6},  {noScaleY=true,noScaleX=true}, x-2, y+variableHeight, w+4, 1.5*suit.scale)
      variableHeight = variableHeight + s.h + padding*1.5
    end
    -- shortcut 
    for index, scancode in ipairs(editor.keyListenOrder) do
      local listen = editor.keyListen[scancode]
      local b = suit:Button(getFormattedShortcutText(scancode, listen.action), {noScaleY=true,noScaleX=true, font=font, align="left",cornerRadius=3}, x, y + variableHeight, w, font:getHeight())
      variableHeight = variableHeight + b.h + padding
      if cursor_hand and b.entered then
        lm.setCursor(cursor_hand)
        setCursor = true
      elseif b.left and not setCursor then
        lm.setCursor(nil)
      end
      if b.hit then
        listen.func(editor.convertMouseToGrid(x, y))
        rightClickMenuShow = false
      end
    end
    variableHeight = variableHeight - padding

    suit:Shape(-1, {.4,.4,.4}, {noScaleY=true,noScaleX=true,cornerRadius=3}, x-2,y-2, w+4, variableHeight+4)
    suit:Shape(-1, {.6,.6,.6}, {noScaleY=true,noScaleX=true,cornerRadius=3}, x-4,y-4, w+8, variableHeight+8)
  end
end

local drawGrid = function(x, y, tileW, tileH, viewportW, viewportH, scale)
  lg.setLineWidth(math.min(.8 / (scale * 1.5) - editor.gridScale, .4))
  lg.push("all")
  lg.setColor(.3,.3,.35,1)
  -- Calculate visible grid boundaries, aligning with tile edges
  local startX = math.floor((x - viewportW / 2 / scale) / tileW) * tileW
  local endX = math.ceil((x + viewportW / 2 / scale) / tileW) * tileW
  local startY = math.floor((y - viewportH / 2 / scale) / tileH) * tileH
  local endY = math.ceil((y + viewportH / 2 / scale) / tileH) * tileH

  -- Draw vertical lines at tile edges
  for gridX = startX, endX, tileW do
    local screenX = (gridX - x) * scale + viewportW / 2
    lg.line(screenX, 0, screenX, viewportH)
  end

  -- Draw horizontal lines at tile edges
  for gridY = startY, endY, tileH do
    local screenY = (gridY - y) * scale + viewportH / 2
    lg.line(0, screenY, viewportW, screenY)
  end
  lg.pop()
end

local getBoxGridPosition = function(box)
  local scale = editor.suit.scale + editor.gridScale
  local x, y = editor.gridX, editor.gridY
  local screenX = (box.x * editor.tileW - x) * scale
  local screenY = (box.y * editor.tileH - y) * scale
  local screenW = box.w * editor.tileW * scale
  local screenH = box.h * editor.tileH * scale
  return screenX, screenY, screenW, screenH
  --return box.x * editor.tileW - editoir.gridX, box.y * editor.tileH - editor.gridY, box.w * editor.tileW, box.h * editor.tileH 
end

local getNewPosition = function(screenX, screenY, screenW, screenH, box)
  local scale = editor.suit.scale + editor.gridScale
  local mouseX, mouseY = box.mouseX, box.mouseY
  if movingBoxSizeDirection then
    if movingBoxSizeDirection:find("N") then
      screenH = screenH - (mouseY - screenY)
      screenY = mouseY
    elseif movingBoxSizeDirection:find("S") then
      screenH = screenH + (mouseY - screenY - screenH)
    end
    if movingBoxSizeDirection:find("W") then
      screenW = screenW - (mouseX - screenX)
      screenX = mouseX
    elseif movingBoxSizeDirection:find("E") then
      screenW = screenW + (mouseX - screenX - screenW)
    end
  elseif movingBoxPressed then
    screenX = screenX + mouseX
    screenY = screenY + mouseY
  end
  return screenX, screenY, screenW, screenH
end

local drawBox = function(box, stencil, color)
  local screenX, screenY, screenW, screenH = getBoxGridPosition(box)
  local c = color or box.color or {1,1,1}
  local r, g, b = unpack(c)
  if editor.activeBox == box then
    r, g, b = 1, 0, 0
    if movingBoxSize or movingBoxPressed then
      r, g, b = .7,.7,.7
      screenX, screenY, screenW, screenH = getNewPosition(screenX, screenY, screenW, screenH, box)
    end
  end
  lg.push("all")
  if stencil ~= false then
    lg.setStencilMode("replace", "always", 1)
  end
  lg.setColor(r,g,b, box.a or 0.4)
  lg.rectangle("fill", screenX, screenY, screenW, screenH)
  lg.setColor(r,g,b, 1.0)
  lg.rectangle("line", screenX, screenY, screenW, screenH)
  if stencil ~= false then
    lg.setStencilMode()
  end
  if box == editor.activeBox then
    lg.push("all")
    lg.setStencilMode()
    local r = movingBoxSizeRadius
    lg.circle("fill", screenX, screenY, r) -- NW
    lg.circle("fill", screenX + screenW / 2, screenY, r) -- N
    lg.circle("fill", screenX + screenW, screenY, r) -- NE
    lg.circle("fill", screenX + screenW, screenY + screenH / 2, r) -- E
    lg.circle("fill", screenX + screenW, screenY + screenH, r) -- SE
    lg.circle("fill", screenX + screenW / 2, screenY + screenH, r) -- S
    lg.circle("fill", screenX, screenY + screenH, r) -- SW
    lg.circle("fill", screenX, screenY + screenH / 2, r) -- W
    lg.pop()
  end
  lg.pop()
  return screenX, screenY, screenW, screenH
end

local drawComment = function(comment)
  local scale = editor.suit.scale + editor.gridScale
  lg.setStencilMode("keep", "equal", 0)
  local screenX, screenY = drawBox(comment, false)
  lg.setStencilMode()
  lg.print(" "..tostring(comment.text), editor.monoFont, screenX, screenY,0,scale/editor.monoFontScale)
end

local drawTrade = function(trade)
  local scale = editor.suit.scale + editor.gridScale
  local c
  if trade.company then
    c = editor.project:getInstanceInfo().abbreviation[trade.company].color
  end
  local screenX, screenY, screenW, screenH = drawBox(trade, true, c)

  local font = editor.monoFont
  local scale = scale/editor.monoFontScale

  local company = (trade.company or "UNKNOWN"):upper()
  local agreement = trade.agreement or "UNKNOWN"

  local h = font:getHeight() * scale

  if trade.h >= 2 then
    local w = font:getWidth(company) * scale
    local x, y = screenX + (screenW/2 - w/2), screenY + (screenH/2 - h/2) - h/2
    lg.print(company, font, x, y, 0, scale)
  end

  local w = font:getWidth(agreement) * scale
  local x, y = screenX + (screenW/2 - w/2), screenY + (screenH/2 - h/2) + (trade.h >= 2 and h/2 or 0)
  lg.print(agreement, font, x, y, 0, scale)
end

editor.drawTradeRelationship = function()
  for _, trade in ipairs(editor.project:getInstanceInfo().trades) do
    --{"unlock":["bcfPlates2","bnwRedstone"],"completed":["bcfPlates"]}

  end
end

editor.draw = function()
  local scale = editor.suit.scale + editor.gridScale
  local w, h = lg.getDimensions()
  lg.push("all")
  lg.circle("fill", 0,0, 5)
  drawGrid(editor.gridX, editor.gridY, editor.tileW, editor.tileH, w, h, scale)
  lg.push("all")
  lg.translate(lg.getWidth()/2,lg.getHeight()/2)
  for _, box in ipairs(editor.project.boxes) do
    if box.type == "trade" then
      drawTrade(box)
    elseif box.type ~= "comment" then
      drawBox(box)
    end
  end
  -- comments are stenciled out so they don't blend with the other boxes
  for _, box in ipairs(editor.project.boxes) do
    if box.type == "comment" then
      drawComment(box)
    end
  end
  
  editor.drawTradeRelationship()

  lg.pop()
  lg.pop()
end

editor.drawAboveUI = function()

end

editor.resize = function(_, _)
  rightClickMenuShow = false
  editor.wheelmoved(0,0,0,0)
  editor.resizeGrid(editor.gridScale)
end

editor.resizeGrid = function(gridScale)
  local suit = editor.suit

  local fontSize = 20
  if gridScale <= -0.4 then
    fontSize = 10
  elseif gridScale >= 1 then
    fontSize = 30
  end
  fontSize = math.floor(fontSize * suit.scale)
  editor.monoFontScale = fontSize/(editor.tileH * .75)
  local fontName = "font.mono."..fontSize
  if not assets[fontName] then
    assets[fontName] = lg.newFont(assets._path["font.mono"], fontSize)
  end
  editor.monoFont = assets[fontName]

  local fontSize = math.floor(15 * suit.scale)
  local fontName = "font.mono."..fontSize
  if not assets[fontName] then
    assets[fontName] = lg.newFont(assets._path["font.mono"], fontSize)
  end
  suit.monoFont = assets[fontName]
end

editor.convertMouseToGrid = function(x, y)
  local scale = editor.suit.scale + editor.gridScale
  local w, h = lg.getDimensions()
  local gridX = math.floor((x - w / 2) / scale + editor.gridX)
  local gridY = math.floor((y - h / 2) / scale + editor.gridY)
  local tileX = math.floor(gridX / editor.tileW)
  local tileY = math.floor(gridY / editor.tileH)
  gridX, gridY = (gridX - editor.gridX) * scale, (gridY - editor.gridY) * scale
  return tileX, tileY, gridX, gridY
end

editor.canPlaceBox = function(x, y, w, h)
  for _, box in ipairs(editor.project.boxes) do
    if box.x < x + w     and
       box.x + box.w > x and
       box.y < y + h     and
       box.y + box.h > y then
        return false
    end
  end
  return true
end

editor.getUnassignedTrade = function()
  for _, company in ipairs(editor.project.companies) do
    local tradeBoxes = editor.project:getInstanceInfo().tradeBoxes[company.abbreviation]
    for _, agreement in ipairs(company.agreement) do
      if not tradeBoxes[agreement.name] then
        return company.abbreviation, agreement.name
      end
    end
  end
  return nil
end

editor.isPointInBox = function(x, y)
  local comment
  for _, box in ipairs(editor.project.boxes) do
    if box.x <= x and
       box.x + box.w > x and
       box.y <= y and
       box.y + box.h > y then
      if box.type == "comment" then
        comment = box
      else
        return true, box
      end
    end
  end
  if comment then
    return true, comment
  end
  return false, nil
end

editor.keypressed = function(_, scancode)
  rightClickMenuShow = false
  if not showEditUi then
    local listener = editor.keyListen[scancode]
    if listener then
      listener.func(editor.convertMouseToGrid(lm.getPosition()))
    end
  end
end

local pressedTime, activeBoxSetAt, doubleClickTimer
editor.mousepressed = function(x, y, button)
  if editor.suit:anyHovered() then return end
  
  rightClickMenuShow = false
  showEditUi = false

  if button == 2 then
    rightClickMenuShow = true
    rightClickMenuX, rightClickMenuY = x, y
    return
  end
  if button == 1 then
    local tx, ty, gx, gy = editor.convertMouseToGrid(x, y)
    local box = editor.activeBox
    if box then
      if doubleClickTimer then
        local time = lt.getTime() - doubleClickTimer
        if time < 0.51 then
          local isInBox, box = editor.isPointInBox(tx, ty)
          if box == editor.activeBox then
            editor.keyListen["edit"].func()
            return
          end
        end
        doubleClickTimer = nil
      end
      doubleClickTimer = lt.getTime()
      if movingBoxSizeDirection then
        movingBoxSize = true
        box.mouseX = gx
        box.mouseY = gy
        return
      end
      if movingBox then
        movingBoxPressed = true
        box.mouseX = 0
        box.mouseY = 0
        return
      end
    else
      movingBoxSizeDirection = nil
      movingBox = nil
    end
    local isInBox, box = editor.isPointInBox(tx, ty)
    if isInBox then
      editor.activeBox = box
      activeBoxSetAt = lt.getTime()
      return
    end
    pressedTime = lt.getTime()
  end
  if button == 3 then
    movingGrid = true
  end
  if movingGrid and cursor_sizeall then
    lm.setCursor(cursor_sizeall)
  end
end

local isPointInCircle = function(cx, cy, r, x, y) 
  return (x - cx)^2 + (y - cy)^2 <= r^2
end

editor.mousemoved = function(x, y, dx, dy)
  if editor.suit:anyHovered() then return end
  local scale = editor.suit.scale + editor.gridScale
  if movingGrid then
    editor.gridX = editor.gridX - dx / scale
    editor.gridY = editor.gridY - dy / scale
    return
  end
  if editor.activeBox then
    local tx, ty, gridX, gridY = editor.convertMouseToGrid(x, y)
    local box = editor.activeBox
    -- check if user tried to grab and move the box as one click
    if activeBoxSetAt and lt.getTime() - activeBoxSetAt > .1 then
      activeBoxSetAt = nil
      movingBoxPressed = true
      box.mouseX = 0
      box.mouseY = 0
    end
    -- changing the box size
    if movingBoxSize then
      box.mouseX = gridX
      box.mouseY = gridY
      if isCursorSupported then
        lm.setCursor(movingBoxSizeChanged)
      end
      return
    end
    -- chaning the box position
    if movingBoxPressed then
      box.mouseX = box.mouseX + dx
      box.mouseY = box.mouseY + dy
      if isCursorSupported then
        lm.setCursor(cursor_sizeall)
      end
      return
    end
    -- is hovering on box size change point
    local bx, by, bw, bh = getBoxGridPosition(editor.activeBox)
    local r = movingBoxSizeRadius
    local cardinalPositions = {
      {x = bx,        y = by,        dir = "NW", cursor = cursor_sizenwse},
      {x = bx + bw/2, y = by,        dir = "N",  cursor = cursor_sizens},
      {x = bx + bw,   y = by,        dir = "NE", cursor = cursor_sizenesw},
      {x = bx + bw,   y = by + bh/2, dir = "E",  cursor = cursor_sizewe},
      {x = bx + bw,   y = by + bh,   dir = "SE", cursor = cursor_sizenwse},
      {x = bx + bw/2, y = by + bh,   dir = "S",  cursor = cursor_sizens},
      {x = bx,        y = by + bh,   dir = "SW", cursor = cursor_sizenesw},
      {x = bx,        y = by + bh/2, dir = "W",  cursor = cursor_sizewe}
    }
    for _, cardinal in ipairs(cardinalPositions) do
      if isPointInCircle(cardinal.x, cardinal.y, r, gridX, gridY) then
        movingBoxSizeDirection = cardinal.dir
        movingBoxSizeChanged = cardinal.cursor or true
        break
      end
    end
    if not movingBoxSizeChanged then
      movingBoxSizeDirection = nil
      if not rightClickMenuShow then
        lm.setCursor(nil)
      end
    elseif isCursorSupported then
      doubleClickTimer = nil
      lm.setCursor(movingBoxSizeChanged)
      movingBoxSizeChanged = nil
    end
    if movingBoxSizeDirection then return end
    -- is hovering  to move box
    local isInBox, box = editor.isPointInBox(tx, ty)
    if isInBox and box == editor.activeBox then
      movingBox = true
      lm.setCursor(cursor_sizeall)
    elseif movingBox then
      movingBox = false
      lm.setCursor(nil)
    end
  end
end

editor.mousereleased = function(_, _, button)
  activeBoxSetAt = nil
  if movingGrid then
    movingGrid = false
    lm.setCursor(nil)
  end
  if editor.activeBox then
    local box = editor.activeBox
    local scale = editor.suit.scale + editor.gridScale
    if movingBoxSize then
      local wasX, wasY, wasW, wasH = box.x, box.y, box.w, box.h
      undo.push(function()
          box.x, box.y, box.w, box.h = wasX, wasY, wasW, wasH --todo add redo
        end)
      local sx, sy, sw, sh = getBoxGridPosition(box)
      local gx, gy, gw, gh = getNewPosition(sx, sy, sw, sh, box)
      local dx, dy, dw, dh = gx - sx, gy - sy, gw - sw, gh - sh
      local scaledTileW = editor.tileW * scale
      local scaledTileH = editor.tileH * scale
      local touched = false
      dx, dy = math.floor(dx / scaledTileW), math.floor(dy / scaledTileH)
      dw, dh = math.ceil(dw / scaledTileW), math.ceil(dh / scaledTileH)
      if dx ~= 0 then
          box.x = box.x + dx
          touched = true
      end
      if dy ~= 0 then
        box.y = box.y + dy
        touched = true
      end
      if dw ~= 0 then
        box.w = box.w + dw
        touched = true
      end
      if dh ~= 0 then
        box.h = box.h + dh
        touched = true
      end
      if box.w < 0 then
        box.x = box.x + box.w
        box.w = -box.w
        touched = true
      end
      if box.h < 0 then
        box.y = box.y + box.h
        box.h = -box.h
        touched = true
      end
      if touched then
        editor.project.dirty = true
      end
      box.mouseX = nil
      box.mouseY = nil
      movingBoxSizeChanged = nil
      movingBoxSizeDirection = nil
      movingBoxSize = false
      lm.setCursor(nil)
    end
    if movingBoxPressed then
      local wasX, wasY, wasW, wasH = box.x, box.y, box.w, box.h
      undo.push(function()
          box.x, box.y, box.w, box.h = wasX, wasY, wasW, wasH --todo add redo
        end)
      local sx, sy, sw, sh = getBoxGridPosition(box)
      local gx, gy, gw, gh = getNewPosition(sx, sy, sw, sh, box)
      local dx, dy, dw, dh = gx - sx, gy - sy, gw - sw, gh - sh
      local scaledTileW = editor.tileW * scale
      local scaledTileH = editor.tileH * scale
      dx = math.floor(dx / scaledTileW)
      dy = math.floor(dy / scaledTileH)
      if dx ~= 0 or dy ~= 0 then
        box.x = box.x + dx
        box.y = box.y + dy
        editor.project.dirty = true
      end
      box.mouseX = nil
      box.mouseY = nil
      movingBoxPressed = nil
    end
  end
  if pressedTime and lt.getTime() - pressedTime < 0.1 then
    editor.activeBox = nil
  end
  pressedTime = nil
end

local wheelmovedTime = -100
editor.wheelmoved = function(_, _, _, y)
  if editor.suit:anyHovered() then return end
  local speed = 1
  if lt.getTime() - wheelmovedTime < 0.2 then
    speed = 2 * editor.suit.scale
  end
  editor.gridScale = editor.gridScale + y * 0.05 * speed
  
  local min, max = -.5 * editor.suit.scale, 1.2 * editor.suit.scale

  local touched = false
  if editor.gridScale < min then
    editor.gridScale = min
    touched = true
  elseif editor.gridScale > max then
    editor.gridScale = max
    touched = true
  end
  if not touched then
    editor.resizeGrid(editor.gridScale)
    wheelmovedTime = lt.getTime()
  end
end

return editor