Safeguard_PvpFlagTimerWindow = CreateFrame("Frame", "SafeguardReloaded_PvpFlagTimerWindow", UIParent, "BackdropTemplate")

local PFTW = Safeguard_PvpFlagTimerWindow

local Compat = SafeguardReloaded_Compat

function PFTW:Initialize()
  PFTW:SetPoint("TOP")
  PFTW:SetSize(120, 40)
  PFTW:SetBackdrop(Compat.DefaultWindowBackdrop)
  PFTW:SetClampedToScreen(true)
  PFTW:SetMovable(true)
  PFTW:EnableMouse(true)
  PFTW:RegisterForDrag("LeftButton")
  PFTW:SetScript("OnDragStart", function(self, button)
    self:StartMoving()
  end)
  PFTW:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
  end)
  PFTW:Hide()
  
  PFTW.HeaderFs = PFTW:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  PFTW.HeaderFs:SetPoint("TOP", PFTW, "TOP", 0, -5)
  PFTW.HeaderFs:SetText("PvP Flag Timer:")

  PFTW.TimerFs = PFTW:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  PFTW.TimerFs:SetPoint("TOP", PFTW, "TOP", 0, -20)

  C_Timer.After(1, function()
    PFTW:Update()
  end)
end

function PFTW:Update()
  if (not Safeguard_Settings.Options.ShowPvpFlagTimerWindow) then
    PFTW:Hide()
    return
  end

  local pvpTimer = Compat.GetPvpTimer()
  if (pvpTimer >= 300000 or pvpTimer < 0) then
    if (PFTW:IsShown()) then
      PFTW:Hide()
    end
  else
    local minutes = pvpTimer / 60000
    local seconds = (pvpTimer % 60000) / 1000
    PFTW.TimerFs:SetText(string.format("%d:%02d", minutes, seconds))

    if (not PFTW:IsShown()) then
      PFTW:Show()
    end
  end

  C_Timer.After(1, function()
    PFTW:Update()
  end)
end