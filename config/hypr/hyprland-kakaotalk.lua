-- KakaoTalk (ARM64EC Wine, ~/.local/bin/kakaotalk).
-- Opaque main window: its ARGB surface otherwise lets windows behind show through.
o.window({ class = "^kakaotalk\\.exe$", xwayland = true }, {
  tag = "-default-opacity",
  opacity = "1 1",
  force_rgbx = true,
})
-- Hide Wine's untitled explorer.exe helper window (from minpeter/omarchy-kakaotalk).
o.window({ class = "^explorer\\.exe$", title = "^$", xwayland = true, float = true }, {
  tag = "-default-opacity",
  opacity = "0 0",
  border_size = 0,
  no_shadow = true,
  no_focus = true,
})

-- Ctrl+V in KakaoTalk sends files copied in a file manager as attachments: KakaoTalk itself
-- pastes only their paths. Bound only while a KakaoTalk window is focused; kakaotalk-paste
-- passes a normal Ctrl+V on when the clipboard holds no files.
local kakao_paste_bind = nil

local function kakao_paste_update()
  local window = hl.get_active_window()
  local in_kakao = window ~= nil and window.class == "kakaotalk.exe"
  if in_kakao and not kakao_paste_bind then
    kakao_paste_bind = hl.bind("CTRL + V",
      hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/kakaotalk-paste"),
      { description = "KakaoTalk: paste copied files as attachments" })
  elseif not in_kakao and kakao_paste_bind then
    kakao_paste_bind:unbind()
    kakao_paste_bind = nil
  end
end

hl.on("window.active", kakao_paste_update)
kakao_paste_update()

-- Typing in KakaoTalk still lets stray trackpad taps through, which moves the caret or clicks
-- other chat windows. While a KakaoTalk window is focused, each key press turns tap-to-click off
-- until 700 ms after the last key; physical clicks keep working.
local kakao_tap_generation = 0
local kakao_tap_blocked = false

local function kakao_tap_set(enabled)
  hl.config({ input = { touchpad = { tap_to_click = enabled } } })
  kakao_tap_blocked = not enabled
end

hl.on("input.keyboard.key", function()
  local window = hl.get_active_window()
  if window == nil or window.class ~= "kakaotalk.exe" then
    return
  end
  kakao_tap_generation = kakao_tap_generation + 1
  local generation = kakao_tap_generation
  if not kakao_tap_blocked then
    kakao_tap_set(false)
  end
  hl.timer(function()
    if generation == kakao_tap_generation and kakao_tap_blocked then
      kakao_tap_set(true)
    end
  end, { timeout = 700, type = "oneshot" })
end)
