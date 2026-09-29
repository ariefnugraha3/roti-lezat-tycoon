class_name ProductionJob
extends RefCounted
## Satu batch dari Buku Resep (GDD 18.1, 61.4). x3/x5 tetap SATU job besar.

const ORDERED: StringName = &"ORDERED"
const WAITING_FOR_MIXER: StringName = &"WAITING_FOR_MIXER"
const MIXING: StringName = &"MIXING"
const MIX_DONE_WAITING_PICKUP: StringName = &"MIX_DONE_WAITING_PICKUP"
const CARRIED_TO_OVEN: StringName = &"CARRIED_TO_OVEN"
const BAKING: StringName = &"BAKING"
const BAKE_DONE_WAITING_PICKUP: StringName = &"BAKE_DONE_WAITING_PICKUP"
const OVERBAKING: StringName = &"OVERBAKING"
const BURNT: StringName = &"BURNT"
const CARRIED_TO_DISPLAY: StringName = &"CARRIED_TO_DISPLAY"
const PLACEMENT_UI: StringName = &"PLACEMENT_UI"
## Mangkuk adonan / loyang matang yang ditaruh pemain di Meja Tunggu (GDD 5.1.3).
const DOUGH_ON_TABLE: StringName = &"DOUGH_ON_TABLE"
const TRAY_ON_TABLE: StringName = &"TRAY_ON_TABLE"
const ON_DISPLAY: StringName = &"ON_DISPLAY"
const FAILED: StringName = &"FAILED"

var job_id: int = 0
var recipe_id: StringName
var batch_multiplier: int = 1
var quantity_output: int = 0
var stage: StringName = ORDERED
var reserved_ingredients: Dictionary = {}
var ingredient_value_kr: float = 0.0
var mixer_id: int = -1
var oven_id: int = -1
var created_at: float = 0.0
## player atau staff_id pemilik job.
var owner_actor_id: StringName = &"player"
## Siapa yang memulai tahap sekarang (untuk auto-retrieve & kecepatan terkunci).
var stage_started_by: StringName = &""
var stage_duration: float = 0.0
var stage_elapsed: float = 0.0
## Detik sejak READY_PERFECT dimulai (jendela gosong, GDD 62).
var burn_elapsed: float = 0.0
## Auto-retrieve berhasil: timer gosong dibekukan sampai baker mengambil tray.
var protected: bool = false
## Kualitas hasil saat tray diangkat (GDD 19.1 bake_quality).
var bake_quality: float = 1.0
## Unit yang masih di loyang yang sedang dibawa.
var carried_units: int = 0
## Aktor yang sedang membawa mangkuk/loyang job ini.
var carrier_id: StringName = &""
## Klaim staf pada task blackboard (GDD 23.2).
var claimed_by: StringName = &""
var cogs_noted: bool = false
var produced_at: float = 0.0
## Umur yang terkumpul di Meja Tunggu, dalam jam setara roti matang (GDD 19.7.6).
## Tidak di-reset saat diambil lalu ditaruh lagi.
var table_age_hours: float = 0.0
## Urutan ditaruh di meja (tampilan & pemutus seri).
var table_seq: int = 0


func recipe() -> RecipeDefinition:
	return DataRegistry.recipe(recipe_id)


func progress() -> float:
	if stage_duration <= 0.0:
		return 0.0
	return clampf(stage_elapsed / stage_duration, 0.0, 1.0)


func is_waiting_oven_pickup() -> bool:
	return stage == BAKE_DONE_WAITING_PICKUP or stage == OVERBAKING or stage == BURNT


func is_on_table() -> bool:
	return stage == DOUGH_ON_TABLE or stage == TRAY_ON_TABLE


func to_dict() -> Dictionary:
	return {
		"job_id": job_id, "recipe_id": String(recipe_id), "batch_multiplier": batch_multiplier,
		"quantity_output": quantity_output, "stage": String(stage),
		"reserved_ingredients": SimManager.sn_dict_to_json(reserved_ingredients),
		"ingredient_value_kr": ingredient_value_kr, "mixer_id": mixer_id, "oven_id": oven_id,
		"created_at": created_at, "owner_actor_id": String(owner_actor_id),
		"stage_started_by": String(stage_started_by), "stage_duration": stage_duration,
		"stage_elapsed": stage_elapsed, "burn_elapsed": burn_elapsed, "protected": protected,
		"bake_quality": bake_quality, "carried_units": carried_units, "carrier_id": String(carrier_id),
		"claimed_by": String(claimed_by), "cogs_noted": cogs_noted, "produced_at": produced_at,
		"table_age_hours": table_age_hours, "table_seq": table_seq,
	}


static func from_dict(d: Dictionary) -> ProductionJob:
	var j := ProductionJob.new()
	j.job_id = int(d.get("job_id", 0))
	j.recipe_id = StringName(str(d.get("recipe_id", "")))
	j.batch_multiplier = int(d.get("batch_multiplier", 1))
	j.quantity_output = int(d.get("quantity_output", 0))
	j.stage = StringName(str(d.get("stage", ORDERED)))
	j.reserved_ingredients = SimManager.json_to_sn_dict(d.get("reserved_ingredients", {}))
	j.ingredient_value_kr = float(d.get("ingredient_value_kr", 0.0))
	j.mixer_id = int(d.get("mixer_id", -1))
	j.oven_id = int(d.get("oven_id", -1))
	j.created_at = float(d.get("created_at", 0.0))
	j.owner_actor_id = StringName(str(d.get("owner_actor_id", "player")))
	j.stage_started_by = StringName(str(d.get("stage_started_by", "")))
	j.stage_duration = float(d.get("stage_duration", 0.0))
	j.stage_elapsed = float(d.get("stage_elapsed", 0.0))
	j.burn_elapsed = float(d.get("burn_elapsed", 0.0))
	j.protected = bool(d.get("protected", false))
	j.bake_quality = float(d.get("bake_quality", 1.0))
	j.carried_units = int(d.get("carried_units", 0))
	j.carrier_id = StringName(str(d.get("carrier_id", "")))
	j.claimed_by = StringName(str(d.get("claimed_by", "")))
	j.cogs_noted = bool(d.get("cogs_noted", false))
	j.produced_at = float(d.get("produced_at", 0.0))
	j.table_age_hours = float(d.get("table_age_hours", 0.0))
	j.table_seq = int(d.get("table_seq", 0))
	return j
