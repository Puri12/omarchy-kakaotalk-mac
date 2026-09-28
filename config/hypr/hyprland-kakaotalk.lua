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
