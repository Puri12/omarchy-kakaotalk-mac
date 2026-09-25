# SPDX-License-Identifier: GPL-3.0-or-later
# Adapted from link_fallback_fonts in https://github.com/chaotic-ground/kakaotalk-on-wine
import sys


def multi_sz(items):
    data = b"".join(s.encode("utf-16-le") + b"\x00\x00" for s in items) + b"\x00\x00"
    return ",".join("%02x" % b for b in data)


link = multi_sz(["NotoSansCJK-Regular.ttc,Noto Sans CJK KR"])
bases = ("맑은 고딕", "Malgun Gothic", "굴림", "Gulim", "돋움", "Dotum", "바탕", "Batang",
         "Arial", "Tahoma", "System", "Segoe UI", "Microsoft Sans Serif", "MS Shell Dlg",
         "MS Shell Dlg 2", "MS Sans Serif", "Verdana", "Courier New", "Times New Roman",
         "Lucida Console", "Consolas")
lines = ["Windows Registry Editor Version 5.00", "",
         r"[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink]"]
lines += ['"%s"=hex(7):%s' % (b, link) for b in bases]
lines += ["", r"[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]"]
lines += ['"%s"="Noto Sans CJK KR"' % f for f in ("맑은 고딕", "굴림", "굴림체", "돋움", "돋움체", "바탕", "바탕체")]
lines.append("")
open(sys.argv[1], "w", encoding="utf-16-le").write("\ufeff" + "\r\n".join(lines))
