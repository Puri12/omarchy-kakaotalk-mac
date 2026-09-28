# SPDX-License-Identifier: GPL-3.0-or-later
# Adapted from link_fallback_fonts in https://github.com/chaotic-ground/kakaotalk-on-wine
import sys


def multi_sz(items):
    data = b"".join(s.encode("utf-16-le") + b"\x00\x00" for s in items) + b"\x00\x00"
    return ",".join("%02x" % b for b in data)


# CJK first, then emoji and symbols: without them KakaoTalk draws most emoji and symbols as boxes.
link = multi_sz(["NotoSansCJK-Regular.ttc,Noto Sans CJK KR", "NotoEmoji-Regular.ttf,Noto Emoji",
                 "NotoSansSymbols2-Regular.ttf,Noto Sans Symbols 2", "NotoSansSymbols-Regular.ttf,Noto Sans Symbols"])
bases = ("맑은 고딕", "Malgun Gothic", "굴림", "Gulim", "돋움", "Dotum", "바탕", "Batang",
         "Arial", "Tahoma", "System", "Segoe UI", "Microsoft Sans Serif", "MS Shell Dlg",
         "MS Shell Dlg 2", "MS Sans Serif", "Verdana", "Courier New", "Times New Roman",
         "Lucida Console", "Consolas")
lines = ["Windows Registry Editor Version 5.00", "",
         r"[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink]"]
lines += ['"%s"=hex(7):%s' % (b, link) for b in bases]
# The Korean names below are substituted to Noto Sans CJK KR, and fallback is looked up by the face
# actually used, so the CJK font itself needs the emoji/symbol fallback too.
cjk_link = multi_sz(["NotoEmoji-Regular.ttf,Noto Emoji", "NotoSansSymbols2-Regular.ttf,Noto Sans Symbols 2",
                     "NotoSansSymbols-Regular.ttf,Noto Sans Symbols"])
lines.append('"Noto Sans CJK KR"=hex(7):%s' % cjk_link)
lines += ["", r"[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]"]
lines += ['"%s"="Noto Sans CJK KR"' % f for f in ("맑은 고딕", "굴림", "굴림체", "돋움", "돋움체", "바탕", "바탕체")]
lines.append("")
open(sys.argv[1], "w", encoding="utf-16-le").write("\ufeff" + "\r\n".join(lines))
