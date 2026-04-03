class_name XedatsReflectionBudgetProfile
extends Resource

@export var low_budget: int = 2
@export var medium_budget: int = 4
@export var high_budget: int = 8
@export var default_budget_tier: String = "medium"


func get_budget_cap(tier: String) -> int:
	var normalized_tier: String = tier.strip_edges().to_lower()
	match normalized_tier:
		"low":
			return max(low_budget, 1)
		"medium":
			return max(medium_budget, 1)
		"high":
			return max(high_budget, 1)
		_:
			return get_budget_cap(default_budget_tier)
