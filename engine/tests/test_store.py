import hashlib
from admin.engine.s7_store import build_entry, filter_fertile

def test_filter_fertile_keeps_only_fertile():
    discernment = [
        {"token_index": 0, "result": "FERTILE", "token_value": "good"},
        {"token_index": 1, "result": "BABEL", "token_value": "bad"},
        {"token_index": 2, "result": "FERTILE", "token_value": "ok"},
    ]
    fertile = filter_fertile(discernment)
    assert len(fertile) == 2
    assert all(r["result"] == "FERTILE" for r in fertile)

def test_build_entry_has_required_fields():
    entry = build_entry(content="The cat sat on the mat", plane="semantic", entity_id="e1")
    assert entry["content"] == "The cat sat on the mat"
    assert entry["plane"] == "semantic"
    assert entry["content_hash"] == hashlib.sha256(b"The cat sat on the mat").hexdigest()[:64]
    assert entry["source_system"] == "cws"
    assert "id" in entry

def test_build_entry_defaults():
    entry = build_entry(content="test", plane=None, entity_id=None)
    assert entry["plane"] == "semantic"
