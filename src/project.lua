local project = { }
project.__index = project

local json = require("util.json")
local file = require("util.file")

local nfs = require("libs.nativefs")

local lfs = love.filesystem

local tradePath = "/server_scripts/base/trading/"

local projectsFile = "projects.json"
local projectFile = tradePath .. "tradeTree/.meta"

local instanceInfo = { }
project.getInstanceInfo = function() return instanceInfo end

project.new = function(path)
  if not nfs.getInfo(path, "directory") then
    return nil, "Could not find the directory at "..tostring(path)
  end
  
  project.addProject(path)

  return project
end

project.getActiveProjects = function()
  if lfs.getInfo(projectsFile, "file") then
    local success, projects = json.decode(projectsFile)
    return projects
  end
end

project.addProject = function(path)
  local projects = project.getActiveProjects() or {}
  local found = false
  for i, project in ipairs(projects) do
    if project.path == path then
      project.time = os.time()
      table.remove(projects, i)
      table.insert(projects, 1, project)
      found = true
    end
  end
  if not found then
    table.insert(projects, 1, {path = path, time = os.time()})
  end
  json.encode(projectsFile, projects)
end

project.loadProject = function(path)
  instanceInfo.path = path
  -- new Project
  if not nfs.getInfo(path..projectFile, "file") then
    print("New project: creating new project profile @ "..path..projectFile)
    love.window.setTitle("Trade Map - "..path)
    return setmetatable({
        dirty = false,
        companies = { },
      }, project)
  else -- existing Project
    print("Pre-existing project: attempting to open project profile")
    local success, self = json.decode(path..projectFile, true)
    if not success then 
      return nil, "A problem appeared trying to load the project metadata.\n"..tostring(self)
    end
    print("Opened project profile")
    love.window.setTitle("Trade Map - "..(self.name))
    self.dirty = false
    setmetatable(self, project)
    self:loadCompanies()
    print("Loaded "..#self.companies.." companies")
    return self
  end
end

project.close = function(self)
  love.window.setTitle("Trade Map")
  return true
end

project.saveProject = function(self)
  if self.dirty then
    self.dirty = nil
    local success, errorMessage = json.encode(instanceInfo.path..projectFile, self, true)
    if not success then
      self.dirty = true
      return errorMessage
    end
    project.addProject(instanceInfo.path)
    self.dirty = false
    return true
  end
end

local pattern_fileStart = "^const%s-%S+%s-=%s-"
local pattern_newLine   = "\nconst%s-%S+%s-=%s-"

local companyConstructorPattern = "Company.constructor%(\"(%S+)\",%s-\"(%S+)\"%)"
local companyConstructorPattern_noAbbreviation = "Company.constructor%(\"(%S+)\"%)"
local agreementPattern = "Agreement.constructor%(%S+,%s-\"(%S+)\"%)"

local findPattern = function(text, pattern, outTable)
  local touched = false
  -- Check first line of given text for match
  local _, _, var1, var2 = text:find(pattern_fileStart .. pattern)
  table.insert(outTable, var1)
  table.insert(outTable, var2)
  touched = var1 ~= nil
  -- Check all new lines of given text for match
  for var1, var2 in text:gmatch(pattern_newLine .. pattern) do
    table.insert(outTable, var1)
    table.insert(outTable, var2)
    touched = true
  end
  return touched
end

project.loadCompanies = function(self)
  if not self.companies then
    self.companies = { }
  end
  local map = { }
  for _, company in ipairs(self.companies) do
    map[company.fileName] = company
  end
  local companyDirectory = instanceInfo.path .. tradePath .. "company/"
  for _, filePath in ipairs(nfs.getDirectoryItems(companyDirectory)) do
    if nfs.getInfo(companyDirectory .. filePath, "file") and file.getFileExtension(filePath) == "js" then
      local fileName = file.getFileName(filePath)
      local company = map[fileName]
      if not company then
        company = {
          fileName = fileName
        }
        table.insert(self.companies, company)
      end
      local out = { }
      local script = nfs.read(companyDirectory..filePath)
      -- [[ company constructor]]
      if not findPattern(script, companyConstructorPattern, out) and not findPattern(script, companyConstructorPattern_noAbbreviation, out) then
        print("Could not find company constructor in: "..companyDirectory..filePath)
        for index, c in ipairs(self.companies) do
          if c == company then
            table.remove(self.companies, index)
            break
          end
        end
        goto continue
      end
      company.name, company.abbreviation = out[1], out[2] or out[1]
      -- [[ agreements constructor ]]
      company.agreements = { }
      findPattern(script, agreementPattern, company.agreements)
      -- Debug
      -- print(company.fileName, company.name, company.abbreviation)
      -- for _, agreement in ipairs(company.agreements) do
      --   print("\t"..agreement)
      -- end
    end
    ::continue::
  end
end

-- project.addSpritesheet = function(self, path, sprites, name, index)
--   local i, j = path:find(self.path, 1, true)
--   if i ~= 1 then
--     return "notinproject"
--   end
--   path = path:sub(j+1):gsub("\\", "/")
--   for _, spritesheet in ipairs(self.spritesheets) do
--     if spritesheet.path == path then
--       return "alreadyadded"
--     end
--   end
--   print("Added new spritesheet", path, (index and "at"..tostring(index) or ""))
--   local spritesheet = {
--     path = path,
--     name = name or file.getFileName(path),
--   }
--   if index then
--     table.insert(self.spritesheets, index, spritesheet)
--   else
--     table.insert(self.spritesheets, spritesheet)
--   end
--   self.dirty = true
--   return nil, path
-- end

-- project.removeSpritesheet = function(self, index)
--   if index < 1 or index > #self.spritesheets then
--     return "invalidindex"
--   end
--   table.remove(self.spritesheets, index)
--   self.dirty = true
-- end

return project