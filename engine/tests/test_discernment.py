from admin.engine.s7_discernment import compute_discernment

def test_high_agreement_is_fertile():
    tokens = ["The", "cat", "sat"]
    forward_scores = [0.9, 0.85, 0.88]
    reverse_scores = [0.88, 0.82, 0.9]
    results = compute_discernment(tokens, forward_scores, reverse_scores)
    assert all(r["result"] == "FERTILE" for r in results)

def test_low_agreement_is_babel():
    tokens = ["foo", "bar"]
    forward_scores = [0.9, 0.1]
    reverse_scores = [0.1, 0.9]
    results = compute_discernment(tokens, forward_scores, reverse_scores)
    assert all(r["result"] == "BABEL" for r in results)

def test_mixed_discernment():
    tokens = ["good", "bad"]
    forward_scores = [0.8, 0.9]
    reverse_scores = [0.75, 0.1]
    results = compute_discernment(tokens, forward_scores, reverse_scores)
    assert results[0]["result"] == "FERTILE"
    assert results[1]["result"] == "BABEL"

def test_ternary_weights():
    tokens = ["a"]
    forward_scores = [0.95]
    reverse_scores = [0.93]
    results = compute_discernment(tokens, forward_scores, reverse_scores)
    assert results[0]["weight"] == 1

def test_babel_gets_negative_weight():
    tokens = ["x"]
    forward_scores = [0.9]
    reverse_scores = [0.1]
    results = compute_discernment(tokens, forward_scores, reverse_scores)
    assert results[0]["weight"] == -1
