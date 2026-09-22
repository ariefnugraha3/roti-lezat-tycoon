class_name OpeningDB
## Skenario tiga hari pembukaan — hari ajar "jangan sampai gosong".
##
## Hari 1-3 TIDAK diundi. Permintaannya ditulis di sini secara pasti, dan gudang
## diisi PAS sebanyak itu: tidak ada satu butir pun cadangan. Satu loyang yang
## dibiarkan gosong di oven berarti ada pembeli atau pesanan RotiFood yang tidak
## kebagian hari itu — itulah pelajaran yang diajarkan tiga hari ini, dan itu
## tidak bisa diajarkan oleh hari yang permintaannya acak.
##
## ATURAN YANG TIDAK BOLEH DILANGGAR (dijaga tools/data_audit.gd):
##   total roti yang diminta == batches x yield_count resep hari itu
## Kelebihan satu butir membuat hari itu bisa diselesaikan sambil menggosongkan
## roti; kekurangan satu butir membuatnya mustahil diselesaikan sempurna.
##
## Satu hari memakai SATU resep saja. Dengan dua resep, pembeli yang mengambil
## roti "yang salah" dari rak (CustomerSim mengambil apa pun yang tersedia bila
## favoritnya habis) akan membuat hitungan per resep meleset walau totalnya pas.
##
## Sesudah hari ke-3 permainan kembali ke arus acak biasa (GDD 9.1 & 3.6).

## Hari pertama yang terjadwal. Hari di bawah ini adalah INDEKS + 1.
const FIRST_DAY: int = 1

## Susunan tiap hari:
##   recipe_id  : resep tunggal yang dipanggang hari itu (wajib resep starter)
##   batches    : jumlah batch yang bahannya disediakan — inilah "pas"-nya
##   walk_ins   : [{hour, archetype, count}] pembeli fisik, urut jam kedatangan
##   deliveries : [{hour, count}] pesanan RotiFood; isinya resep hari itu
const DAYS: Array[Dictionary] = [
	# ---------------------------------------------------------------- Hari 1
	# 6 batch x 6 = 36 roti. Pembeli sabar semua (anak sekolah, emak arisan,
	# si galau) supaya hari pertama mengajar ritme, bukan menghukum kelambatan.
	{
		"recipe_id": "roti_tawar_polos",
		"batches": 6,
		"walk_ins": [
			{"hour": 8.5, "archetype": "anak_sekolah", "count": 2},
			{"hour": 9.25, "archetype": "anak_sekolah", "count": 2},
			{"hour": 10.0, "archetype": "emak_arisan", "count": 6},
			{"hour": 11.0, "archetype": "anak_sekolah", "count": 2},
			{"hour": 12.0, "archetype": "si_galau", "count": 2},
			{"hour": 13.5, "archetype": "emak_arisan", "count": 8},
			{"hour": 15.0, "archetype": "anak_sekolah", "count": 2},
			{"hour": 16.5, "archetype": "pekerja_kantoran", "count": 2},
		],
		"deliveries": [
			{"hour": 9.75, "count": 4},
			{"hour": 14.0, "count": 6},
		],
	},
	# ---------------------------------------------------------------- Hari 2
	# 7 batch x 6 = 42 roti, tiga pesanan ojol, dan pekerja kantoran di jam
	# sibuk pagi: mulai ada yang kesabarannya pendek (18 detik).
	{
		"recipe_id": "roti_goreng_polos",
		"batches": 7,
		"walk_ins": [
			{"hour": 8.33, "archetype": "pekerja_kantoran", "count": 2},
			{"hour": 9.0, "archetype": "anak_sekolah", "count": 2},
			{"hour": 9.67, "archetype": "emak_arisan", "count": 7},
			{"hour": 10.5, "archetype": "anak_sekolah", "count": 2},
			{"hour": 11.5, "archetype": "si_galau", "count": 2},
			{"hour": 12.5, "archetype": "emak_arisan", "count": 9},
			{"hour": 14.0, "archetype": "anak_sekolah", "count": 2},
			{"hour": 15.5, "archetype": "pekerja_kantoran", "count": 2},
			{"hour": 16.67, "archetype": "anak_sekolah", "count": 2},
		],
		"deliveries": [
			{"hour": 9.33, "count": 5},
			{"hour": 12.0, "count": 3},
			{"hour": 15.0, "count": 4},
		],
	},
	# ---------------------------------------------------------------- Hari 3
	# 9 batch x 5 = 45 roti. Donat hasilnya lebih sedikit per batch, jadi hari
	# ini mengajarkan bahwa "jumlah batch" dan "jumlah roti" bukan hal yang sama.
	{
		"recipe_id": "donat_gula",
		"batches": 9,
		"walk_ins": [
			{"hour": 8.25, "archetype": "anak_sekolah", "count": 2},
			{"hour": 8.83, "archetype": "pekerja_kantoran", "count": 2},
			{"hour": 9.5, "archetype": "emak_arisan", "count": 8},
			{"hour": 10.33, "archetype": "anak_sekolah", "count": 2},
			{"hour": 11.17, "archetype": "si_galau", "count": 2},
			{"hour": 12.0, "archetype": "emak_arisan", "count": 10},
			{"hour": 13.17, "archetype": "anak_sekolah", "count": 2},
			{"hour": 14.33, "archetype": "pekerja_kantoran", "count": 2},
			{"hour": 15.5, "archetype": "anak_sekolah", "count": 2},
			{"hour": 16.5, "archetype": "si_galau", "count": 2},
		],
		"deliveries": [
			{"hour": 9.0, "count": 4},
			{"hour": 11.67, "count": 3},
			{"hour": 14.67, "count": 4},
		],
	},
]


## Apakah hari ini memakai skenario terjadwal.
static func has_plan(day: int) -> bool:
	return day >= FIRST_DAY and day < FIRST_DAY + DAYS.size()


## Rencana satu hari; {} bila hari itu sudah kembali ke arus acak.
static func plan(day: int) -> Dictionary:
	if not has_plan(day):
		return {}
	return DAYS[day - FIRST_DAY]


## Hari terakhir yang masih terjadwal.
static func last_day() -> int:
	return FIRST_DAY + DAYS.size() - 1


static func recipe_id(day: int) -> String:
	return String(plan(day).get("recipe_id", ""))


static func batches(day: int) -> int:
	return int(plan(day).get("batches", 0))


## Pembeli fisik yang dijadwalkan hari itu (salinan, urut jam).
static func walk_ins(day: int) -> Array:
	return (plan(day).get("walk_ins", []) as Array).duplicate(true)


## Pesanan RotiFood yang dijadwalkan hari itu (salinan, urut jam).
static func deliveries(day: int) -> Array:
	return (plan(day).get("deliveries", []) as Array).duplicate(true)


## Jumlah roti yang DIMINTA hari itu: pembeli fisik + pesanan RotiFood.
static func demand(day: int) -> int:
	var total: int = 0
	for e: Variant in (plan(day).get("walk_ins", []) as Array):
		total += int((e as Dictionary).get("count", 0))
	for d: Variant in (plan(day).get("deliveries", []) as Array):
		total += int((d as Dictionary).get("count", 0))
	return total


## Jumlah roti yang BISA dipanggang dari bahan yang disediakan hari itu.
## Harus sama persis dengan demand() — itu seluruh maksud skenario ini.
static func supply(day: int) -> int:
	var rid: String = recipe_id(day)
	if rid.is_empty():
		return 0
	var rec: Dictionary = RecipeDB.entry(rid)
	if rec.is_empty():
		return 0
	return batches(day) * maxi(1, int(rec.get("yield_count", 1)))


## Isi gudang yang PAS untuk hari itu: bahan resep x jumlah batch.
## Kosong bila hari itu tidak terjadwal.
static func pantry_for(day: int) -> Dictionary:
	var rid: String = recipe_id(day)
	if rid.is_empty():
		return {}
	var rec: Dictionary = RecipeDB.entry(rid)
	if rec.is_empty():
		return {}
	var n: int = batches(day)
	var out: Dictionary = {}
	for k: Variant in (rec.get("ingredients", {}) as Dictionary):
		out[String(k)] = int((rec["ingredients"] as Dictionary)[k]) * n
	return out
