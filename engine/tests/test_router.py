import pytest
from admin.engine.s7_router import match_route

def test_small_model_routes_to_ternary():
    rules = [
        {"id": "r1", "rule_name": "small_model_ternary", "priority": 10,
         "match_model_family": None, "match_task_type": None,
         "match_param_max": 4_000_000_000, "route_to": "ternary",
         "reason": "model_size", "enabled": True},
        {"id": "r2", "rule_name": "large_model_standard", "priority": 20,
         "match_model_family": None, "match_task_type": None,
         "match_param_max": None, "route_to": "standard",
         "reason": "model_size", "enabled": True},
    ]
    result = match_route(rules, task_type=None, model_params=1_000_000_000)
    assert result["path_chosen"] == "ternary"
    assert result["rule_name"] == "small_model_ternary"

def test_code_task_routes_to_standard():
    rules = [
        {"id": "r3", "rule_name": "code_standard", "priority": 15,
         "match_model_family": None, "match_task_type": "code",
         "match_param_max": None, "route_to": "standard",
         "reason": "task_type", "enabled": True},
    ]
    result = match_route(rules, task_type="code", model_params=None)
    assert result["path_chosen"] == "standard"

def test_no_match_defaults_to_standard():
    result = match_route([], task_type=None, model_params=None)
    assert result["path_chosen"] == "standard"
    assert result["reason"] == "default"
