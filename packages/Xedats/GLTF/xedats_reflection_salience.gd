class_name XedatsReflectionSalience
extends RefCounted


static func rank_sources(source_paths: Array[String], source_indices: Array[int]) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for i: int in range(source_paths.size()):
		var source_index: int = i
		if i < source_indices.size():
			source_index = source_indices[i]
		var path: String = source_paths[i]
		ranked.append({
			"path": path,
			"source_index": source_index,
			"salience_score": _score(path, source_index)
		})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("salience_score", 0.0))
		var score_b: float = float(b.get("salience_score", 0.0))
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b

		var index_a: int = int(a.get("source_index", 0))
		var index_b: int = int(b.get("source_index", 0))
		if index_a != index_b:
			return index_a < index_b

		var path_a: String = String(a.get("path", ""))
		var path_b: String = String(b.get("path", ""))
		return path_a < path_b
	)

	return ranked


static func top_paths(ranked_sources: Array[Dictionary], max_count: int) -> Array[String]:
	if max_count <= 0:
		return []

	var capped: Array[String] = []
	var count: int = min(max_count, ranked_sources.size())
	for i: int in range(count):
		capped.append(String(ranked_sources[i].get("path", "")))
	return capped


static func _score(source_path: String, source_index: int) -> float:
	var safe_index: int = max(source_index, 0)
	var index_weight: float = 1.0 / float(safe_index + 1)

	var ext: String = source_path.get_extension().to_lower()
	var format_bonus: float = 0.0
	if ext == "wav":
		format_bonus = 0.1
	elif ext == "ogg":
		format_bonus = 0.08

	return index_weight + format_bonus
