-- Compat.lua
-- Thin shims around game APIs that moved or changed between the client this addon
-- was originally written for and Classic Era 1.15.9.
-- Everything here is defensive: if the modern API is present it is used, otherwise
-- we fall back to the legacy global so the addon keeps working on older clients.

SafeguardReloaded_Compat = {}

local Compat = SafeguardReloaded_Compat

Compat.AddonName = "SafeguardReloaded"

-- *** Console variables ***
-- GetCVar/SetCVar moved into the C_CVar namespace. The globals still exist on
-- 1.15.x but are deprecated, so prefer the namespaced versions.

function Compat.GetCVar(name)
  if (C_CVar and C_CVar.GetCVar) then return C_CVar.GetCVar(name) end
  return GetCVar(name)
end

function Compat.SetCVar(name, value)
  if (C_CVar and C_CVar.SetCVar) then return C_CVar.SetCVar(name, value) end
  return SetCVar(name, value)
end

-- *** Addon metadata ***

function Compat.GetAddOnMetadata(field)
  if (C_AddOns and C_AddOns.GetAddOnMetadata) then
    return C_AddOns.GetAddOnMetadata(Compat.AddonName, field)
  end
  if (GetAddOnMetadata) then return GetAddOnMetadata(Compat.AddonName, field) end
  return nil
end

-- *** Compact raid frames ***
-- The standalone CompactRaidFrameContainer_ApplyToFrames global was replaced by a
-- method on the container mixin. 1.15.x only ships the mixin version.

function Compat.ApplyToRaidFrames(mode, func)
  local container = CompactRaidFrameContainer
  if (not container) then return false end

  if (type(container.ApplyToFrames) == "function") then
    container:ApplyToFrames(mode, func)
    return true
  end

  if (type(CompactRaidFrameContainer_ApplyToFrames) == "function") then
    CompactRaidFrameContainer_ApplyToFrames(container, mode, func)
    return true
  end

  return false
end

function Compat.AreRaidFramesShown()
  return CompactRaidFrameContainer ~= nil and CompactRaidFrameContainer:IsShown()
end

-- *** Group channels ***
-- Picking the wrong channel silently drops the message, so resolve it once here.

function Compat.GetGroupChatChannel()
  if (IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2)) then return "INSTANCE_CHAT" end
  if (IsInRaid and IsInRaid()) then return "RAID" end
  if (IsInGroup and IsInGroup()) then return "PARTY" end
  if (UnitInRaid("player")) then return "RAID" end
  if (UnitInParty("player")) then return "PARTY" end
  return nil
end

-- *** Threat ***
-- Classic Era exposes the threat functions but they return nil for most units
-- because the server does not broadcast threat. Callers already handle nil, we
-- only need to survive the function itself being absent.

function Compat.GetDetailedThreatSituation(unit, mob)
  if (type(UnitDetailedThreatSituation) ~= "function") then return nil end
  if (not UnitExists(mob)) then return nil end
  return UnitDetailedThreatSituation(unit, mob)
end

-- *** PvP flag timer ***

function Compat.GetPvpTimer()
  if (type(GetPVPTimer) ~= "function") then return -1 end
  return GetPVPTimer()
end

-- *** Backdrops ***
-- BACKDROP_TUTORIAL_16_16 is a SharedXML global that is not guaranteed to exist
-- on every client flavour.

Compat.DefaultWindowBackdrop = BACKDROP_TUTORIAL_16_16 or {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileEdge = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

-- *** Settings panel ***
-- Returns the category so the slash command can open it directly. Falling back to
-- InterfaceOptions_AddCategory keeps pre-Dragonflight clients working.

function Compat.RegisterOptionsPanel(frame, name)
  if (Settings and Settings.RegisterCanvasLayoutCategory) then
    local category = Settings.RegisterCanvasLayoutCategory(frame, name)
    category.ID = name
    Settings.RegisterAddOnCategory(category)
    return category
  end

  if (InterfaceOptions_AddCategory) then
    frame.name = name
    InterfaceOptions_AddCategory(frame)
    return nil
  end

  return nil
end

function Compat.OpenOptionsPanel(category, name)
  if (Settings and Settings.OpenToCategory) then
    Settings.OpenToCategory(category and category:GetID() or name)
    return
  end

  if (InterfaceOptionsFrame_OpenToCategory) then
    -- Older clients need this called twice due to a Blizzard bug.
    InterfaceOptionsFrame_OpenToCategory(name)
    InterfaceOptionsFrame_OpenToCategory(name)
  end
end
