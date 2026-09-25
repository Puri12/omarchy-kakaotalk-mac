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
