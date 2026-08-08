-- NotificationFrame.lua
-- Notifications used to go through UIErrorsFrame, which draws flat white text with
-- no outline. Over a bright background -- snow, sand, a lit interior -- that is
-- close to unreadable, and these are the messages a player can least afford to
-- miss. This is a dedicated frame instead: outlined white text over a dimmed strip
-- that is only visible while a message is on screen.
--
-- Deliberately not reusing UIErrorsFrame, because restyling it would also restyle
-- every ordinary game error.

SafeguardReloaded_NotificationFrame = CreateFrame("MessageFrame", "SafeguardReloadedNotificationFrame", UIParent)

local NF = SafeguardReloaded_NotificationFrame

local FRAME_WIDTH = 560
local FRAME_HEIGHT = 66
local TIME_VISIBLE = 3.0
local FADE_DURATION = 1.0
local BACKDROP_ALPHA = 0.55
local EDGE_FADE_WIDTH = 90

-- Texture:SetGradient took loose colour components before it was changed to take
-- ColorMixin objects, so pick whichever this client understands.
local function SetHorizontalAlphaGradient(texture, startAlpha, endAlpha)
  if (texture.SetGradient and CreateColor) then
    texture:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, startAlpha), CreateColor(0, 0, 0, endAlpha))
    return
  end

  if (texture.SetGradientAlpha) then
    texture:SetGradientAlpha("HORIZONTAL", 0, 0, 0, startAlpha, 0, 0, 0, endAlpha)
    return
  end

  -- No gradient support: a flat strip still beats unreadable text.
  texture:SetColorTexture(0, 0, 0, endAlpha)
end

local function CreateBackdrop()
  local backdrop = CreateFrame("Frame", nil, NF)
  backdrop:SetAllPoints(NF)
  backdrop:SetFrameLevel(math.max(NF:GetFrameLevel() - 1, 0))

  -- Three pieces so the strip fades out sideways instead of ending in a hard edge.
  -- A single rectangle looks like a black box behind two words.
  backdrop.Center = backdrop:CreateTexture(nil, "BACKGROUND")
  backdrop.Center:SetPoint("TOPLEFT", backdrop, "TOPLEFT", EDGE_FADE_WIDTH, 0)
  backdrop.Center:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -EDGE_FADE_WIDTH, 0)
  backdrop.Center:SetColorTexture(0, 0, 0, BACKDROP_ALPHA)

  backdrop.Left = backdrop:CreateTexture(nil, "BACKGROUND")
  backdrop.Left:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
  backdrop.Left:SetPoint("BOTTOMRIGHT", backdrop.Center, "BOTTOMLEFT", 0, 0)
  SetHorizontalAlphaGradient(backdrop.Left, 0, BACKDROP_ALPHA)

  backdrop.Right = backdrop:CreateTexture(nil, "BACKGROUND")
  backdrop.Right:SetPoint("TOPLEFT", backdrop.Center, "TOPRIGHT", 0, 0)
  backdrop.Right:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
  SetHorizontalAlphaGradient(backdrop.Right, BACKDROP_ALPHA, 0)

  backdrop:Hide()

  return backdrop
end

function NF:Initialize()
  if (self.Initialized) then return end

  local font = CreateFont("SafeguardReloadedNotificationFont")
  local fontPath, fontSize = GameFontNormalLarge:GetFont()
  font:SetFont(fontPath, fontSize, "OUTLINE")
  font:SetTextColor(1, 1, 1)
  font:SetShadowColor(0, 0, 0, 1)
  font:SetShadowOffset(1, -1)
  font:SetJustifyH("CENTER")

  self:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  self:SetFrameStrata("HIGH")
  self:SetFontObject(font)
  self:SetJustifyH("CENTER")
  self:SetSpacing(2)
  self:SetInsertMode("TOP")
  self:SetFading(true)
  self:SetTimeVisible(TIME_VISIBLE)
  self:SetFadeDuration(FADE_DURATION)

  -- Anchored under the game's own error text so the two never overlap, and so the
  -- frame follows along if another addon has moved UIErrorsFrame.
  if (UIErrorsFrame) then
    self:SetPoint("TOP", UIErrorsFrame, "BOTTOM", 0, -24)
  else
    self:SetPoint("TOP", UIParent, "TOP", 0, -240)
  end

  self.Backdrop = CreateBackdrop()
  self.VisibleMessages = 0
  self.Initialized = true
end

function NF:ShowNotification(text)
  if (not self.Initialized) then self:Initialize() end

  self:AddMessage(text)

  -- MessageFrame does not report how many messages are still on screen, so track it
  -- here: the backdrop must disappear with the last one rather than linger.
  self.VisibleMessages = self.VisibleMessages + 1
  self.Backdrop:Show()

  C_Timer.After(TIME_VISIBLE + FADE_DURATION, function()
    NF.VisibleMessages = NF.VisibleMessages - 1
    if (NF.VisibleMessages <= 0) then
      NF.VisibleMessages = 0
      NF.Backdrop:Hide()
    end
  end)
end
