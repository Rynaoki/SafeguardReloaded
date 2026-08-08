Safeguard_RaidFramesManager = {
  ARaidFrameUpdateIsQueued = nil,
  LastRaidFramesUpdateTimestamp = nil,
}

local RFM = Safeguard_RaidFramesManager

local Compat = SafeguardReloaded_Compat

function RFM:UpdateRaidFrames()
  if (not Compat.AreRaidFramesShown()) then return end

  local now = GetTime()
  if (self.LastRaidFramesUpdateTimestamp and now - self.LastRaidFramesUpdateTimestamp < 1) then
    if (not self.ARaidFrameUpdateIsQueued) then
      C_Timer.After(1 - (now - self.LastRaidFramesUpdateTimestamp), function()
        RFM:UpdateRaidFrames()
      end)
      self.ARaidFrameUpdateIsQueued = true
    end

    return
  end

  self.ARaidFrameUpdateIsQueued = false
  self.LastRaidFramesUpdateTimestamp = now

  -- 1.15.x replaced the CompactRaidFrameContainer_ApplyToFrames global with a
  -- method on the container itself; Compat picks whichever the client provides.
  Compat.ApplyToRaidFrames("normal", function(frame) RFM:UpdateRaidFrame(frame) end)
end

function RFM:UpdateRaidFrame(frame)
  if (not frame.unit) then return end

  local guid = UnitGUID(frame.unit)
  if (not guid) then return end

  if (not frame.SgIconsContainerFrame) then RFM:SetupRaidFrameIcons(frame) end

  if (not Safeguard_PlayerStates[guid] or not Safeguard_Settings.Options.ShowIconsOnRaidFrames) then
    if (frame.SgIconsContainerFrame.ConnectedIcon:IsShown()) then frame.SgIconsContainerFrame.ConnectedIcon:Hide() end
    if (frame.SgIconsContainerFrame.DisconnectedIcon:IsShown()) then frame.SgIconsContainerFrame.DisconnectedIcon:Hide() end
    if (frame.SgIconsContainerFrame.InCombatIcon:IsShown()) then frame.SgIconsContainerFrame.InCombatIcon:Hide() end

    return
  end

  if (not frame.SgIconsContainerFrame:IsShown()) then frame.SgIconsContainerFrame:Show() end

  if (not Safeguard_PlayerStates[guid].ConnectionInfo) then
    if (frame.SgIconsContainerFrame.ConnectedIcon:IsShown()) then frame.SgIconsContainerFrame.ConnectedIcon:Hide() end
    if (frame.SgIconsContainerFrame.DisconnectedIcon:IsShown()) then frame.SgIconsContainerFrame.DisconnectedIcon:Hide() end
  else
    if (Safeguard_PlayerStates[guid].ConnectionInfo.IsConnected) then
      if (not frame.SgIconsContainerFrame.ConnectedIcon:IsShown()) then frame.SgIconsContainerFrame.ConnectedIcon:Show() end
      if (frame.SgIconsContainerFrame.DisconnectedIcon:IsShown()) then frame.SgIconsContainerFrame.DisconnectedIcon:Hide() end
    else
      if (frame.SgIconsContainerFrame.ConnectedIcon:IsShown()) then frame.SgIconsContainerFrame.ConnectedIcon:Hide() end
      if (not frame.SgIconsContainerFrame.DisconnectedIcon:IsShown()) then frame.SgIconsContainerFrame.DisconnectedIcon:Show() end
    end
  end

  if (Safeguard_PlayerStates[guid].IsInCombat) then
    if (not frame.SgIconsContainerFrame.InCombatIcon:IsShown()) then frame.SgIconsContainerFrame.InCombatIcon:Show() end
  else
    if (frame.SgIconsContainerFrame.InCombatIcon:IsShown()) then frame.SgIconsContainerFrame.InCombatIcon:Hide() end
  end
end

-- Builds one small indicator anchored to the raid frame. The tooltip anchors to the
-- icon itself; the previous code anchored to frame.ConnectedIcon and friends, which
-- were never assigned and threw a Lua error on hover.
local function CreateIcon(parent, xOffset, tooltipText, setUpTexture)
  local icon = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
  icon:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -2)
  icon:SetSize(6, 6)

  setUpTexture(icon)

  icon:SetScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, 0)
    GameTooltip:SetText(tooltipText)
    GameTooltip:Show()
  end)

  icon:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  icon:Hide()

  return icon
end

function RFM:SetupRaidFrameIcons(frame)
  local container = CreateFrame("Frame", nil, frame)
  container:SetAllPoints(frame)
  frame.SgIconsContainerFrame = container

  container.ConnectedIcon = CreateIcon(container, 2, "Connected", function(icon)
    icon.Texture = icon:CreateTexture()
    icon.Texture:SetAllPoints()
    icon.Texture:SetColorTexture(0, 1, 0)
  end)

  container.DisconnectedIcon = CreateIcon(container, 2, "Disconnected", function(icon)
    icon.Texture = icon:CreateTexture()
    icon.Texture:SetAllPoints()
    icon.Texture:SetColorTexture(1, 0, 0)
  end)

  container.InCombatIcon = CreateIcon(container, 8, "In Combat", function(icon)
    icon:SetBackdrop({ bgFile = "Interface\\Icons\\ability_warrior_challange" })
  end)
end


