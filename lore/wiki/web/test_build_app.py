"""Check title precedence and local-link classification without building dist."""
import tempfile
from pathlib import Path
from unittest.mock import patch

import build_app as builder


with tempfile.TemporaryDirectory() as temp:
    wiki = Path(temp)
    source = wiki / "gu" / "sample.md"
    source.parent.mkdir()
    with patch.object(builder, "WIKI", wiki):
        for text, title in [
            ("---\nname: Metadata\n---\n# Heading", "Metadata"),
            ("# Heading", "Heading"),
            ("---\nname: Metadata\n---\nNo heading", "sample"),
            ("No heading", "sample"),
        ]:
            source.write_text(text, encoding="utf-8")
            assert builder.render_page(source, {"/gu/sample"}, {})["title"] == title
        source.write_text("# Heading\n[Known](known.md) [Missing](missing.md)", encoding="utf-8")
        page = builder.render_page(source, {"/gu/known"}, {})
        soup = builder.BeautifulSoup(page["html"], "html.parser")
        known, missing = soup.find_all("a")
        assert known["href"] == "#/gu/known" and "unavailable-link" not in known.get("class", [])
        assert missing["href"] == "#/gu/missing" and "unavailable-link" in missing["class"]
        assert missing["title"] == "此目标未收录在知识页面中"
print("PASS title precedence (4 cases) and known/missing local links")
