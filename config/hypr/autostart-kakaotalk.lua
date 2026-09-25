-- Lets KakaoTalk (Wine) paste PNG screenshots: while a KakaoTalk window is focused, puts the image
-- on the Windows clipboard inside the Wine prefix. Never hand large image data to XWayland: it breaks Hyprland's XWM.
o.launch_on_start(os.getenv("HOME") .. "/.local/bin/kakaotalk-clipbridge")

-- KakaoTalk icon in the bar (StatusNotifierItem, pinned via omarchy.tray in shell.json); click shows KakaoTalk.
o.launch_on_start(os.getenv("HOME") .. "/.local/bin/kakaotalk-tray")

-- Not used: xembedsniproxy (XEmbed tray -> bar) stole keyboard input from KakaoTalk chat windows.
