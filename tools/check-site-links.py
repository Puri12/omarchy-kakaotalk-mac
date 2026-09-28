#!/usr/bin/env python3
"""Check that relative links in site HTML resolve to files and valid anchors."""

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


SITE = Path("site")


class PageParser(HTMLParser):
    """Collect element IDs and href/src targets from one HTML page."""

    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if "id" in attributes:
            self.ids.add(attributes["id"])
        for name in ("href", "src"):
            if name in attributes:
                self.links.append(attributes[name])

    handle_startendtag = handle_starttag


pages = {}
for page in sorted(SITE.glob("*.html")):
    parser = PageParser()
    parser.feed(page.read_text(encoding="utf-8"))
    pages[page.resolve()] = parser

broken = []
for page_path, parser in pages.items():
    for target in parser.links:
        parsed = urlsplit(target)
        if parsed.scheme or parsed.netloc or target.startswith("//"):
            continue
        relative_path = unquote(parsed.path)
        if not relative_path:
            target_path = page_path
        else:
            target_path = (page_path.parent / relative_path).resolve()
        if not target_path.is_file():
            broken.append(f"{page_path.relative_to(Path.cwd())}: {target}")
            continue
        if parsed.fragment:
            if target_path in pages:
                target_parser = pages[target_path]
            elif target_path.suffix.lower() == ".html":
                target_parser = PageParser()
                target_parser.feed(target_path.read_text(encoding="utf-8"))
            else:
                continue
            if unquote(parsed.fragment) not in target_parser.ids:
                broken.append(f"{page_path.relative_to(Path.cwd())}: {target}")

if broken:
    for link in broken:
        print(link)
    raise SystemExit(1)

print("site links OK")
