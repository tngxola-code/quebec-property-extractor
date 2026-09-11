"""Safe streaming reader. Populated by feature/safe-xml-parser."""

from __future__ import annotations

from lxml import etree

SAFE_PARSER = etree.XMLParser(
    resolve_entities=False,
    no_network=True,
    load_dtd=False,
    dtd_validation=False,
    huge_tree=False,
    recover=False,
)
