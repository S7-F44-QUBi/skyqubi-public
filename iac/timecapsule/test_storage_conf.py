"""Test that storage.conf.snippet has the exact additionalimagestores config."""
from pathlib import Path
import re

SNIPPET = Path(__file__).parent / "storage.conf.snippet"


def test_snippet_exists():
    assert SNIPPET.is_file()


def test_snippet_declares_overlay_driver():
    text = SNIPPET.read_text()
    assert re.search(r'^driver\s*=\s*"overlay"', text, re.MULTILINE)


def test_snippet_lists_timecapsule_store():
    text = SNIPPET.read_text()
    assert re.search(
        r'additionalimagestores\s*=\s*\[\s*"/s7/timecapsule/registry/store"\s*\]',
        text,
    )


def test_snippet_uses_s7_graphroot():
    text = SNIPPET.read_text()
    assert re.search(
        r'graphroot\s*=\s*"/s7/\.local/share/containers/storage"',
        text,
    )
