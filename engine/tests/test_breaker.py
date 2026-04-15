from admin.engine.s7_breaker import compute_babel_ratio, should_trip

THRESHOLD = 0.70

def test_below_threshold_does_not_trip():
    assert not should_trip(0.50, THRESHOLD)

def test_at_threshold_trips():
    assert should_trip(0.70, THRESHOLD)

def test_above_threshold_trips():
    assert should_trip(0.85, THRESHOLD)

def test_babel_ratio_all_fertile():
    discernment = [{"result": "FERTILE"}] * 10
    assert compute_babel_ratio(discernment) == 0.0

def test_babel_ratio_all_babel():
    discernment = [{"result": "BABEL"}] * 10
    assert compute_babel_ratio(discernment) == 1.0

def test_babel_ratio_mixed():
    discernment = [{"result": "BABEL"}] * 7 + [{"result": "FERTILE"}] * 3
    assert compute_babel_ratio(discernment) == 0.7

def test_babel_ratio_empty():
    assert compute_babel_ratio([]) == 0.0
