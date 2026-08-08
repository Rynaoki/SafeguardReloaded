-- NotificationFrame.lua
-- Notifications used to go through UIErrorsFrame, which draws flat white text with
-- no outline. Over a bright background -- snow, sand, a lit interior -- that is
-- close to unreadable, and these are the messages a player can least afford to
-- miss. The outline is what fixes that; no backdrop, by preference.
--
-- Deliberately not reusing UIErrorsFrame, because restyling it would also restyle
-- every ordinary game error.
--
-- Messages are managed row by row rather than handed to a MessageFrame. That keeps
-- control over wrapping, which a MessageFrame does not do, so a long mob name in an
-- extra attacks message cannot run off the edge of the screen.

SafeguardReloaded_NotificationFrame = CreateFrame("Frame", "SafeguardReloadedNotificationFrame", UIParent)

local NF = SafeguardReloaded_NotificationFrame

local MAX_ROWS = 4
local TIME_VISIBLE = 3.0
local FADE_DURATION = 1.0
local ROW_SPACING = 3
local MAX_TEXT_WIDTH = 520    -- wrap rather than run off the screen

-- Vertical gap below the game's own error text. Raise this to move the messages
-- further down the screen; 0 puts them directly beneath it.
local GAP_BELOW_ERRORS_FRAME = 0

local function CreateRow(fontName)
  local row = CreateFrame("Frame", nil, NF)

  row.Text = row:CreateFontString(nil, "OVERLAY", fontName)
  row.Text:SetPoint("CENTER", row, "CENTER", 0, 0)
  row.Text:SetJustifyH("CENTER")
  if (row.Text.SetWordWrap) then row.Text:SetWordWrap(true) end

  row.FadeOut = row:CreateAnimationGroup()
  local fade = row.FadeOut:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0)
  fade:SetDuration(FADE_DURATION)
  fade:SetStartDelay(TIME_VISIBLE)

  row.FadeOut:SetScript("OnFinished", function()
    NF:ReleaseRow(row)
  end)

  row:Hide()

  return row
end

function NF:Initialize()
  if (self.Initialized) then return end

  local font = CreateFont("SafeguardReloadedNotificationFont")
  local fontPath, fontSize = GameFontNormalLarge:GetFont()
  font:SetFont(fontPath, fontSize, "OUTLINE")
  font:SetTextColor(1, 1, 1)
  font:SetShadowColor(0, 0, 0, 1)
  font:SetShadowOffset(1, -1)

  self:SetSize(1, 1)
  self:SetFrameStrata("HIGH")

  -- Anchored under the game's own error text so the two never overlap, and so the
  -- frame follows along if another addon has moved UIErrorsFrame.
  if (UIErrorsFrame) then
    self:SetPoint("TOP", UIErrorsFrame, "BOTTOM", 0, -GAP_BELOW_ERRORS_FRAME)
  else
    self:SetPoint("TOP", UIParent, "TOP", 0, -200)
  end

  self.Rows = {}
  for i = 1, MAX_ROWS do
    self.Rows[i] = CreateRow("SafeguardReloadedNotificationFont")
  end

  -- Display order, newest first.
  self.Order = {}
  self.Initialized = true
end

function NF:AcquireRow()
  for i = 1, #self.Rows do
    local row = self.Rows[i]
    if (not row.Active) then
      table.insert(self.Order, 1, row)
      return row
    end
  end

  -- Every row is showing something. Recycle the oldest rather than drop the new
  -- message, which is the one the player still needs to see.
  local oldest = table.remove(self.Order)
  oldest.FadeOut:Stop()
  table.insert(self.Order, 1, oldest)

  return oldest
end

function NF:ReleaseRow(row)
  row.Active = false
  row:Hide()

  for i = #self.Order, 1, -1 do
    if (self.Order[i] == row) then table.remove(self.Order, i) end
  end

  self:Layout()
end

function NF:Layout()
  local offsetY = 0
  local widestRow = 1

  for i = 1, #self.Order do
    local row = self.Order[i]
    row:ClearAllPoints()
    row:SetPoint("TOP", self, "TOP", 0, -offsetY)

    offsetY = offsetY + row:GetHeight() + ROW_SPACING
    widestRow = math.max(widestRow, row:GetWidth())
  end

  self:SetSize(widestRow, math.max(offsetY, 1))
end

function NF:ShowNotification(text)
  if (not self.Initialized) then self:Initialize() end

  local row = self:AcquireRow()

  -- Width 0 lets the font string report its natural width; constrain it only when
  -- the text would otherwise run off the screen, and let it wrap instead.
  row.Text:SetWidth(0)
  row.Text:SetText(text)

  local textWidth = row.Text:GetStringWidth()
  if (textWidth > MAX_TEXT_WIDTH) then
    textWidth = MAX_TEXT_WIDTH
    row.Text:SetWidth(MAX_TEXT_WIDTH)
  end

  row:SetSize(textWidth, row.Text:GetStringHeight())

  row.Active = true
  row.FadeOut:Stop()
  row:SetAlpha(1)
  row:Show()
  row.FadeOut:Play()

  self:Layout()
end
