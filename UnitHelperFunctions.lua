UnitHelperFunctions = {}

local UHF = UnitHelperFunctions

local validUnitIds = { "focus", "focuspet", "mouseover", "mouseoverpet", "pet", "player", "target", "targetpet" }
for i = 1, 40 do
  if i <= 4 then
    validUnitIds[#validUnitIds + 1] = "party" .. i
    validUnitIds[#validUnitIds + 1] = "partypet" .. i
  end
  validUnitIds[#validUnitIds + 1] = "raid" .. i
  validUnitIds[#validUnitIds + 1] = "raidpet" .. i
end
for i = 1, 50 do
  validUnitIds[#validUnitIds + 1] = "nameplate" .. i
end
for i = 1, #validUnitIds do
  validUnitIds[#validUnitIds + 1] = validUnitIds[i] .. "target"
end

function UHF.FindUnitIdAndGuidByUnitName(unitName)
  for i = 1, #validUnitIds do
    if (UnitName(validUnitIds[i]) == unitName) then
	    return validUnitIds[i], UnitGUID(validUnitIds[i])
	  end
  end

  return nil, nil
end

function UHF.FindUnitIdByUnitGuid(unitGuid)
  for i = 1, #validUnitIds do
    if UnitGUID(validUnitIds[i]) == unitGuid then return validUnitIds[i] end
  end

  return nil
end 

function UHF.IsUnitGuidInOurPartyOrRaid(unitGuid)
  for i = 1, #validUnitIds do
    if ((string.match(validUnitIds[i], "party") or string.match(validUnitIds[i], "raid")) and not string.match(validUnitIds[i], "target")) then
      if (UnitGUID(validUnitIds[i]) == unitGuid) then return true end
    end
  end

  return false
end

-- function UHF.IsUnitGuidPlayerOrPlayerPet(unitGuid)
--   if (UnitGUID("player") == unitGuid) then return true end
--   if (UnitGUID("pet") == unitGuid) then return true end
--   return false
-- end

function UHF.FindUnitNameByUnitGuid(unitGuid)
  local unitId = UHF.FindUnitIdByUnitGuid(unitGuid)
  return UnitName(unitId)
end

function UHF.GetPossibleEnemyUnitIds()
  local possibleEnemyUnitIds = {}
  for i = 1, #validUnitIds do
    if (validUnitIds[i]:match("nameplate") or validUnitIds[i]:match("target")) then
      possibleEnemyUnitIds[#possibleEnemyUnitIds + 1] = validUnitIds[i]
    end
  end

  return possibleEnemyUnitIds
end