class_name XedatsDistanceBandProfile
extends Resource

## Defines per-distance-band gain and event-rate modifiers for texture emitters.
##
## Three bands (near / mid / far) are expressed as multipliers applied at
## binding time when [code]xedats_distance_policy = "texture"[/code] is set
## on the emitter.
##
## Distances are evaluated as the straight-line world-space distance between
## the emitter and the active [XedatsListener3D] at the moment the binding
## enters the scene tree.  All values are evaluated deterministically at
## [code]_ready[/code]; no per-frame updates are performed.
##
## [b]Gain scale role:[/b] Multiplied against the computed
## [code]volume_variation[/code] center gain, then [code]xedats_texture_variance[/code]
## spread is re-applied around the new center.
##
## [b]Event-rate scale role:[/b] Stored as metadata for downstream use
## (e.g. spawn cadence control in a future Group B phase 2 pass).
## The binding itself does not spawn repeating events — that is Group B phase 2.

## Threshold in world units below which the emitter is considered "near".
@export var near_max_distance: float = 8.0

## Threshold in world units below which the emitter is considered "mid"
## (above [member near_max_distance] and below this value).
@export var mid_max_distance: float = 24.0

## Gain scale applied when the listener is in the near band.
@export var near_gain_scale: float = 1.0

## Gain scale applied when the listener is in the mid band.
@export var mid_gain_scale: float = 0.8

## Gain scale applied when the listener is in the far band
## (beyond [member mid_max_distance]).
@export var far_gain_scale: float = 0.5

## Event-rate scale for the near band (1.0 = full density).
@export var near_rate_scale: float = 1.0

## Event-rate scale for the mid band.
@export var mid_rate_scale: float = 0.7

## Event-rate scale for the far band.
@export var far_rate_scale: float = 0.35

## When enabled, distance bands are evaluated in 2D viewport-space
## instead of 3D world-space. Useful for top-down and side-scrolling games.
@export var is_2d: bool = false


## Returns the gain scale for a given raw [param distance] in world units.
func gain_scale_at(distance: float) -> float:
	if distance <= near_max_distance:
		return near_gain_scale
	if distance <= mid_max_distance:
		return mid_gain_scale
	return far_gain_scale


## Returns the event-rate scale for a given raw [param distance] in world units.
func rate_scale_at(distance: float) -> float:
	if distance <= near_max_distance:
		return near_rate_scale
	if distance <= mid_max_distance:
		return mid_rate_scale
	return far_rate_scale


## Returns a string label for the active band at [param distance].
## Values are: [code]"near"[/code], [code]"mid"[/code], [code]"far"[/code].
func band_label_at(distance: float) -> String:
	if distance <= near_max_distance:
		return "near"
	if distance <= mid_max_distance:
		return "mid"
	return "far"
