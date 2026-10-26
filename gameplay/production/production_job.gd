class_name ProductionJob
extends RefCounted
## Satu batch (GDD idle 4.3, v3.1 18.1). x3/x5 tetap SATU job besar.
##
## Tahap: ORDERED (bahan dibayar, mixer dipesan) -> MIXING ->
## MIX_DONE_WAITING_PICKUP -> CARRIED_TO_OVEN -> BAKING ->
## BAKE_DONE_WAITING_PICKUP -> CARRIED_TO_DISPLAY -> (job selesai). Mixer dan
## oven yang selesai menahan isinya tanpa batas waktu (GDD idle 4.3, 4.6).
## Loyang yang tidak muat di petak mana pun diparkir di Meja Tunggu
## (TRAY_ON_TABLE, GDD idle 4.7); adonan hanya ke sana saat serah terima darurat.

const ORDERED: StringName = &"ORDERED"
const MIXING: StringName = &"MIXING"
const MIX_DONE_WAITING_PICKUP: StringName = &"MIX_DONE_WAITING_PICKUP"
const CARRIED_TO_OVEN: StringName = &"CARRIED_TO_OVEN"
const BAKING: StringName = &"BAKING"
const BAKE_DONE_WAITING_PICKUP: StringName = &"BAKE_DONE_WAITING_PICKUP"
const CARRIED_TO_DISPLAY: StringName = &"CARRIED_TO_DISPLAY"
const DOUGH_ON_TABLE: StringName = &"DOUGH_ON_TABLE"
const TRAY_ON_TABLE: StringName = &"TRAY_ON_TABLE"
const STAGES: Array[StringName] = [ORDERED, MIXING, MIX_DONE_WAITING_PICKUP, CARRIED_TO_OVEN, BAKING,
	BAKE_DONE_WAITING_PICKUP, CARRIED_TO_DISPLAY, DOUGH_ON_TABLE, TRAY_ON_TABLE]

var job_id: int = 0
var recipe_id: StringName
var batch_multiplier: int = 1
var quantity_output: int = 0
var stage: StringName = ORDERED
## Biaya bahan yang sudah dibayar saat batch dimulai (GDD idle 4.4).
var ingredient_cost_kr: float = 0.0
var mixer_id: int = -1
## Oven tempat adonan dipanggang. Sebelum BAKING berarti oven yang dipesan
## pekerja yang sedang mengantar adonan ini (`ProductionManager.oven_reserved`).
var oven_id: int = -1
## Petak rak tujuan batch ini (GDD idle 4.3).
var target_display: int = -1
var target_slot: int = -1
var created_at: float = 0.0
## Siapa yang memulai tahap sekarang.
var stage_started_by: StringName = &""
var stage_duration: float = 0.0
var stage_elapsed: float = 0.0
## Unit yang masih di loyang yang sedang dibawa atau diparkir.
var carried_units: int = 0
## Aktor yang sedang membawa mangkuk/loyang job ini.
var carrier_id: StringName = &""
## Pekerja yang sedang menuju alat untuk langkah berikutnya job ini.
var claimed_by: StringName = &""
var produced_at: float = 0.0
## Urutan ditaruh di meja (tampilan & pemutus seri).
var table_seq: int = 0


func recipe() -> RecipeDefinition:
	return DataRegistry.recipe(recipe_id)


func progress() -> float:
	if stage_duration <= 0.0:
		return 0.0
	return clampf(stage_elapsed / stage_duration, 0.0, 1.0)


func is_waiting_oven_pickup() -> bool:
	return stage == BAKE_DONE_WAITING_PICKUP


func is_on_table() -> bool:
	return stage == DOUGH_ON_TABLE or stage == TRAY_ON_TABLE


func to_dict() -> Dictionary:
	return {
		"job_id": job_id, "recipe_id": String(recipe_id), "batch_multiplier": batch_multiplier,
		"quantity_output": quantity_output, "stage": String(stage), "ingredient_cost_kr": ingredient_cost_kr,
		"mixer_id": mixer_id, "oven_id": oven_id, "target_display": target_display, "target_slot": target_slot,
		"created_at": created_at, "stage_started_by": String(stage_started_by), "stage_duration": stage_duration,
		"stage_elapsed": stage_elapsed, "carried_units": carried_units, "carrier_id": String(carrier_id),
		"claimed_by": String(claimed_by), "produced_at": produced_at, "table_seq": table_seq,
	}


static func from_dict(d: Dictionary) -> ProductionJob:
	var j := ProductionJob.new()
	j.job_id = int(d.get("job_id", 0))
	j.recipe_id = StringName(str(d.get("recipe_id", "")))
	j.batch_multiplier = int(d.get("batch_multiplier", 1))
	j.quantity_output = int(d.get("quantity_output", 0))
	j.stage = StringName(str(d.get("stage", ORDERED)))
	j.ingredient_cost_kr = float(d.get("ingredient_cost_kr", 0.0))
	j.mixer_id = int(d.get("mixer_id", -1))
	j.oven_id = int(d.get("oven_id", -1))
	j.target_display = int(d.get("target_display", -1))
	j.target_slot = int(d.get("target_slot", -1))
	j.created_at = float(d.get("created_at", 0.0))
	j.stage_started_by = StringName(str(d.get("stage_started_by", "")))
	j.stage_duration = float(d.get("stage_duration", 0.0))
	j.stage_elapsed = float(d.get("stage_elapsed", 0.0))
	j.carried_units = int(d.get("carried_units", 0))
	j.carrier_id = StringName(str(d.get("carrier_id", "")))
	j.claimed_by = StringName(str(d.get("claimed_by", "")))
	j.produced_at = float(d.get("produced_at", 0.0))
	j.table_seq = int(d.get("table_seq", 0))
	return j
