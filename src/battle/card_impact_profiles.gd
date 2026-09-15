extends RefCounted
## Visual motif and source foley are chosen together; damage magnitude stays independent.
const PROFILES := {
	"metal": {"color":"ffd28c", "motif":"slash", "sound":"sword_hit"},
	"arrow": {"color":"cbe9a1", "motif":"pierce", "sound":"sword_hit"},
	"fire": {"color":"ff7538", "motif":"burst", "sound":"spell_hit"},
	"ice": {"color":"93e4ff", "motif":"shards", "sound":"ice_hit"},
	"lightning": {"color":"d0b0ff", "motif":"bolt", "sound":"lightning_hit"},
	"shadow": {"color":"9868e7", "motif":"implosion", "sound":"shadow_hit"},
	"poison": {"color":"a1c85a", "motif":"implosion", "sound":"shadow_hit"},
	"bone": {"color":"e4d6b9", "motif":"shards", "sound":"unit_death"},
	"blood": {"color":"d03e65", "motif":"slash", "sound":"shadow_hit"},
	"holy": {"color":"ffe6a2", "motif":"halo", "sound":"heal"},
	"wind": {"color":"b3f5dc", "motif":"pierce", "sound":"sword_hit"},
	"stone": {"color":"c3aa86", "motif":"burst", "sound":"heavy_hit"},
}
static func key(card: Dictionary) -> String:
	var profile := String(card.get("impact_profile", ""))
	return "impact_" + profile if PROFILES.has(profile) else ""
static func get_profile(key: String) -> Dictionary:
	return PROFILES.get(key.trim_prefix("impact_"), {}) if key.begins_with("impact_") else {}
