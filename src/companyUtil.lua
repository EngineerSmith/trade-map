local lustache = require("libs.lustache")

local companyConstructorPattern = "\nconst%s-%S+%s-=%s-Company.constructor%(\"(%S+)\",%s-\"(%S+)\"%)"
local companyConstructorPattern_noAbbreviation = "\nconst%s-%S+%s-=%s-Company.constructor%(\"(%S+)\"%)"
--
local agreementPattern = "\nconst%s-%S+%s-=%s-Agreement.constructor%(%S+,%s-\"(%S+)\"%)%s-%.setTask%((%b[])%)%s-%.setReward%((%b[])%)%s-%.create%(%)"
local agreementPatternRecurrence = "\nconst%s-%S+%s-=%s-Agreement.constructor%(%S+,%s-\"(%S+)\"%)%s-%.setTask%((%b[])%)%s-%.setReward%((%b[])%)%s-%.setRecurrence%((%d)%)%s-%.create%(%)"

local findPattern = function(text, pattern, outTable)
  local touched = false
  -- Check all new lines of given text for match
  for var1, var2 in text:gmatch(pattern) do
    table.insert(outTable, var1)
    table.insert(outTable, var2)
    touched = true
  end
  return touched
end

local companyUtil = {
  companyTemplate = love.filesystem.read("templates/company.mustache")
}

companyUtil.scriptToCompany = function(script, company)
  local dirty = false
  -- Company Constructor
  local out = { }
  if not findPattern(script, companyConstructorPattern, out) and not findPattern(script, companyConstructorPattern_noAbbreviation, out) then
    return nil, "Could not find company constructor"
  end
  if company.name ~= out[1] then
    company.name = out[1]
    dirty = true
  end
  local abb = out[2] or out [1]
  if company.abbreviation ~= abb then
    company.abbreviation = abb
    dirty = true
  end
  -- Agreements
  company.agreement = { }
  for name, task, reward in script:gmatch(agreementPattern) do
    table.insert(company.agreement, {
      name = name,
      task = task,
      reward = reward
    })
  end
  for name, task, reward, recurrence in script:gmatch(agreementPatternRecurrence) do
    table.insert(company.agreement, {
      name = name,
      task = task,
      reward = reward,
      recurrence = recurrence
    })
  end

  table.sort(company.agreement, function(a, b) return a.name < b.name end)
  --
  return dirty
end

companyUtil.companyToScript = function(company, hasSeal)
  return lustache:render(companyUtil.companyTemplate, {
    company = company,
    hasSeal = hasSeal
    })
end

return companyUtil