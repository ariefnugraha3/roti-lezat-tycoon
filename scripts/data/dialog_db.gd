class_name DialogDB
extends RefCounted

## Bank dialog & teks naratif "Roti Lezat Tycoon".
##
## Sumber angka dan kalimat:
##   GDD 3.0.A  — dialog kunjungan pertama Pak Lurah (verbatim)
##   GDD 3.0.C  — Mode Solo "Kerja Sendiri Dulu"
##   GDD 3.0.D  — kunjungan berulang: tetap hangat + 1 tip strategi spesifik
##   GDD 5.3    — "Cara Kerja Resep": emoji reaksi harga
##   GDD 7      — balon pikiran keluhan pelanggan
##   GDD 11.2   — tabel Indikator Mood Toko
##   GDD 11.3   — tabel Panel Sorotan Hari Ini
##   GDD 11.4   — tabel Catatan & Tips dari Pak Lurah
##
## Semua string UI Bahasa Indonesia, identifier bahasa Inggris.

# ---------------------------------------------------------------------------
# Ambang batas
# ---------------------------------------------------------------------------

## GDD 11.2 baris 1: "Laba bersih > 2.000 KR & rating naik".
const PROFIT_AMAZING := 2000.0

## GDD 11.2 baris 3 "Impas / laba sangat kecil" tidak menyebut angka.
## Rentang |laba| <= nilai ini dianggap impas.
const PROFIT_BREAKEVEN_BAND := 100.0

## GDD 11.4 baris 3: "Saldo di bawah 500 KR".
const COINS_LOW := 500.0

## GDD 11.4 baris 2 "Order RotiFood banyak batal" tidak menyebut angka.
## Memakai angka contoh GDD 11.3 ("3 pesanan RotiFood batal") sebagai ambang.
const CANCELLED_MANY := 3

## GDD 11.4 baris 1 "Banyak roti sisa tidak laku" tidak menyebut angka.
const BREAD_LEFT_MANY := 20

## GDD 11.3 baris 7 "Stok gudang hampir habis" tidak menyebut angka.
## Gudang dianggap menipis bila isi <= 15% kapasitas pantry.
const PANTRY_LOW_RATIO := 0.15

## GDD 11.3: "muncul 1–3 kotak Momen Istimewa".
const MAX_HIGHLIGHTS := 3

## GDD 11.3 baris 3 memakai contoh "+180% order online" (GDD 10.2: +150%..+200%).
const RAIN_SURGE_PCT_DEFAULT := 180

# ---------------------------------------------------------------------------
# Warna latar mood — fallback bila autoload Palette belum menyediakan konstanta.
# Seluruh hex diambil dari palet resmi GDD 4.1 / GDD 7.
# ---------------------------------------------------------------------------

## GDD 11.2 "Kuning keemasan" — krim custard GDD 4.1 (#F9D371).
const BG_HEX_AMAZING := "#F9D371"
## GDD 11.2 "Hijau pastel" — pastel hijau mint GDD 4.1 (#B5EAD7).
const BG_HEX_GOOD := "#B5EAD7"
## GDD 11.2 "Krem netral" — krem vanila hangat GDD 4.1 (#F5E6CA).
const BG_HEX_FLAT := "#F5E6CA"
## GDD 11.2 "Oranye hangat" — pendar lampu penghangat etalase GDD 4.1 (#FFAA44).
const BG_HEX_BAD := "#FFAA44"
## GDD 11.2 "Merah muda lembut" — merah muda stroberi GDD 4.1 (#FFB7B2).
const BG_HEX_BAILOUT := "#FFB7B2"

# ---------------------------------------------------------------------------
# Katalog kalimat tetap. Satu sumber kebenaran untuk seluruh fungsi di bawah.
# Kalimat bertanda {} adalah template format (dipakai lewat operator %).
# ---------------------------------------------------------------------------

const LINES := {
	# --- Pak Lurah: kunjungan pertama (GDD 3.0.A, verbatim) ---
	"lurah_bailout_first": "Wah, Nak! Bapak dengar kabarnya usaha rotinya sedang agak seret. Jangan menyerah ya! Pemerintah daerah punya program subsidi UMKM untuk pengusaha kecil berbakat seperti kamu. Ini ada bantuan modal awal. Semangat terus, rotimu enak kok!",

	# --- Pak Lurah: kunjungan berulang (GDD 3.0.D) ---
	# Tetap hangat, masing-masing membawa tepat satu tip strategi spesifik.
	"lurah_bailout_repeat_1": "Halo lagi, Nak! Bapak bawa amplop yang sama, jangan malu ya. Coba fokus bikin Donat Gula dulu, Nak, margin-nya paling oke untuk modal kecil!",
	"lurah_bailout_repeat_2": "Bapak datang lagi, dan Bapak tetap percaya sama kamu. Tip Bapak hari ini: liburkan dulu semua karyawan dan kerjakan toko sendirian. Gaji harian itu yang paling cepat menguras kas.",
	"lurah_bailout_repeat_3": "Sabar ya, Nak, usaha itu memang ada pasang surutnya. Tip Bapak: jangan produksi berlebihan. Roti yang tidak laku sampai sore itu sama saja membuang modal.",
	"lurah_bailout_repeat_4": "Bapak bawakan bantuan lagi, jangan sungkan. Tip Bapak: kalau prakiraan besok hujan, perbanyak stok untuk pesanan RotiFood. Pejalan kaki memang sepi, tapi pesanan ojol justru membanjir.",
	"lurah_bailout_repeat_5": "Tenang saja, Nak, Bapak tidak pernah bosan mampir. Tip Bapak: pasang harga di rentang sweet spot Buku Resep. Kalau kemahalan, pembeli cemberut lalu pergi tanpa belanja.",

	# --- Tip Pak Lurah di Daily Summary (GDD 11.4, teks contoh verbatim) ---
	"tip_bread_left": "Coba kurangi produksi besok, Nak. Bikin sesuai perkiraan pembeli saja.",
	"tip_delivery_cancelled": "Stok harus selalu siap untuk ojol juga loh. Mereka tidak sabaran!",
	"tip_coins_low": "Wah, hampir tipis nih. Fokus bikin Donat Gula dulu ya, margin-nya paling oke!",
	"tip_rating_down": "Kecepatan kasir sangat pengaruh ke rating. Coba upgrade kasir jika bisa.",
	"tip_rain_forecast": "Besok kelihatannya hujan. Persiapkan stok roti lebih banyak untuk ojol ya!",
	"tip_first_day": "Selamat memulai, Nak! Roti Tawar dan Donat Gula itu modal paling hemat.",
	"tip_profit_high": "Wah, hebat sekali! Sudah siap upgrade toko ke level berikutnya belum?",
	"tip_solo_mode": "Tidak apa-apa kerja sendiri dulu. Setiap pengusaha besar pernah ada di posisi ini!",
	# Cadangan bila tidak ada satu pun pemicu GDD 11.4 yang aktif.
	"tip_default": "Toko berjalan normal hari ini, Nak. Pelan-pelan saja, yang penting konsisten!",

	# --- Mood toko (GDD 11.2, kolom Keterangan verbatim) ---
	"mood_amazing": "Hari yang luar biasa! Rotimu laris manis!",
	"mood_good": "Hari yang baik. Terus pertahankan ya!",
	"mood_flat": "Lumayan. Besok coba bikin lebih banyak!",
	"mood_bad": "Hari yang berat. Jangan menyerah, ya!",
	"mood_bailout": "Pak Lurah sedang dalam perjalanan...",

	# --- Sorotan hari ini (GDD 11.3, mengikuti frasa contoh) ---
	"highlight_best_recipe": "%s jadi bintang hari ini! Terjual %d buah.",
	"highlight_vip": "%s mampir! Rating toko melonjak besok.",
	"highlight_rain_surge": "Hujan deras, RotiFood meledak! +%d%% order online.",
	"highlight_delivery_cancelled": "%d pesanan RotiFood batal karena stok habis. Hati-hati!",
	"highlight_burned": "Pelanggan komplain roti gosong. Jaga oven berikutnya!",
	"highlight_staff": "%s bekerja luar biasa hari ini! Produksi roti x%s.",
	"highlight_pantry_low": "Bahan baku menipis! Jangan lupa belanja di Pasar.",
	"highlight_solo_first_day": "Kamu kerja sendiri hari ini. Keren banget, semangat!",
	"highlight_campaign": "Iklan %s masih berjalan (hari ke-%d/%d).",

	# --- Balon pikiran pelanggan (GDD 7) ---
	"thought_antrean_lama": "Antreannya lama sekali...",
	"thought_harga_mahal": "Aduh, harganya mahal banget...",
	"thought_stok_habis": "Yah, rotinya sudah habis...",
	"thought_roti_gosong": "Rotinya kok gosong ya?",
	"thought_default": "Hmm...",
}

## Urutan variasi dialog kunjungan berulang Pak Lurah (GDD 3.0.D).
const LURAH_REPEAT_IDS := [
	"lurah_bailout_repeat_1",
	"lurah_bailout_repeat_2",
	"lurah_bailout_repeat_3",
	"lurah_bailout_repeat_4",
	"lurah_bailout_repeat_5",
]

# ---------------------------------------------------------------------------
# Kontrak data layer (ARCHITECTURE bagian 3): entry() + ids()
# ---------------------------------------------------------------------------

## Ambil satu baris dialog mentah berdasarkan id katalog.
## Kembalikan {} bila id tidak dikenal.
static func entry(id: String) -> Dictionary:
	if not LINES.has(id):
		return {}
	return {
		"id": id,
		"text": String(LINES[id]),
	}


## Seluruh id baris dialog yang tersedia.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for k in LINES:
		out.append(String(k))
	return out


## Teks mentah satu baris katalog; "" bila id tidak dikenal.
static func line(id: String) -> String:
	if not LINES.has(id):
		return ""
	return String(LINES[id])

# ---------------------------------------------------------------------------
# GDD 3.0.A / 3.0.D — dialog kunjungan Pak Lurah
# ---------------------------------------------------------------------------

## Dialog Pak Lurah saat bailout.
## [param times] adalah urutan kunjungan ini (1 = kunjungan pertama).
## Kunjungan pertama memakai dialog GDD 3.0.A persis; kunjungan berikutnya
## memakai variasi hangat GDD 3.0.D yang masing-masing membawa satu tip strategi.
static func lurah_bailout(times: int) -> String:
	if times <= 1:
		return String(LINES["lurah_bailout_first"])
	var idx: int = (times - 2) % LURAH_REPEAT_IDS.size()
	return String(LINES[LURAH_REPEAT_IDS[idx]])

# ---------------------------------------------------------------------------
# GDD 11.4 — Catatan & Tips dari Pak Lurah
# ---------------------------------------------------------------------------

## Satu kalimat tip kontekstual untuk pojok kanan bawah nota Daily Summary.
## Kunci [param ctx]: bread_left, delivery_cancelled, coins, rating_delta,
## forecast, day, profit, solo_mode. Pemicu dievaluasi menurut prioritas:
## onboarding hari pertama > kondisi darurat kas > kegagalan layanan >
## perencanaan besok > perayaan profit.
static func lurah_tip(ctx: Dictionary) -> String:
	var day: int = int(ctx.get("day", 0))
	var solo_mode: bool = bool(ctx.get("solo_mode", false))
	var coins: float = float(ctx.get("coins", 0.0))
	var delivery_cancelled: int = int(ctx.get("delivery_cancelled", 0))
	var rating_delta: float = float(ctx.get("rating_delta", 0.0))
	var bread_left: int = int(ctx.get("bread_left", 0))
	var forecast: String = String(ctx.get("forecast", ""))
	var profit: float = float(ctx.get("profit", 0.0))

	# 1. Hari pertama, saldo awal (GDD 11.4 baris 6) — pesan pembuka wajib menang.
	if day == 1:
		return String(LINES["tip_first_day"])
	# 2. Mode Solo aktif (GDD 11.4 baris 8) — kondisi paling butuh dukungan.
	if solo_mode:
		return String(LINES["tip_solo_mode"])
	# 3. Saldo di bawah 500 KR (GDD 11.4 baris 3).
	if coins < COINS_LOW:
		return String(LINES["tip_coins_low"])
	# 4. Order RotiFood banyak batal (GDD 11.4 baris 2).
	if delivery_cancelled >= CANCELLED_MANY:
		return String(LINES["tip_delivery_cancelled"])
	# 5. Rating toko turun (GDD 11.4 baris 4).
	if rating_delta < 0.0:
		return String(LINES["tip_rating_down"])
	# 6. Banyak roti sisa tidak laku (GDD 11.4 baris 1).
	if bread_left >= BREAD_LEFT_MANY:
		return String(LINES["tip_bread_left"])
	# 7. Prakiraan cuaca hujan besok (GDD 11.4 baris 5).
	if forecast == "hujan":
		return String(LINES["tip_rain_forecast"])
	# 8. Profit sangat tinggi (GDD 11.4 baris 7).
	# GDD 11.4 tidak menyebut angka; memakai ambang "luar biasa" GDD 11.2 (2.000 KR).
	if profit > PROFIT_AMAZING:
		return String(LINES["tip_profit_high"])
	return String(LINES["tip_default"])

# ---------------------------------------------------------------------------
# GDD 11.3 — Panel Sorotan Hari Ini
# ---------------------------------------------------------------------------

## Maksimal 3 "Momen Istimewa", paling menarik lebih dulu.
## Tiap elemen: {icon (emoji tabel GDD 11.3), icon_name (nama IconCanvas), text}.
##
## Kunci [param stats] yang dipakai: best_recipe, best_recipe_count, vip_visited,
## vip_name, weather, delivery_done, delivery_surge_pct, delivery_cancelled,
## burned, burned_sold, best_staff, pantry_total, pantry_capacity,
## campaign_tier, campaign_days_left, solo_first_day.
static func highlights(stats: Dictionary) -> Array:
	var out: Array = []

	var best_recipe: String = String(stats.get("best_recipe", ""))
	var best_recipe_count: int = int(stats.get("best_recipe_count", 0))
	var vip_visited: int = int(stats.get("vip_visited", 0))
	var weather: String = String(stats.get("weather", ""))
	var delivery_done: int = int(stats.get("delivery_done", 0))
	var delivery_cancelled: int = int(stats.get("delivery_cancelled", 0))
	var burned: int = int(stats.get("burned", 0))
	var burned_sold: int = int(stats.get("burned_sold", burned))
	var best_staff: String = String(stats.get("best_staff", ""))
	var pantry_total: int = int(stats.get("pantry_total", -1))
	var pantry_capacity: int = int(stats.get("pantry_capacity", 0))
	var campaign_tier: int = int(stats.get("campaign_tier", 0))
	var campaign_days_left: int = int(stats.get("campaign_days_left", 0))
	var solo_first_day: bool = bool(stats.get("solo_first_day", false))
	var surge_pct: int = int(stats.get("delivery_surge_pct", RAIN_SURGE_PCT_DEFAULT))

	# 1. Hari pertama Mode Solo (GDD 11.3 baris 8) — momen paling langka & emosional.
	if solo_first_day:
		out.append(_hl("🧑‍🍳", "chef", String(LINES["highlight_solo_first_day"])))

	# 2. Pelanggan VIP hadir (GDD 11.3 baris 2).
	if vip_visited > 0:
		var vip_name: String = String(stats.get("vip_name", "Food Vlogger"))
		out.append(_hl("⭐", "star", String(LINES["highlight_vip"]) % [vip_name]))

	# 3. Delivery surge saat hujan (GDD 11.3 baris 3).
	if weather == "hujan" and delivery_done > 0:
		out.append(_hl("🌧️", "rain", String(LINES["highlight_rain_surge"]) % [surge_pct]))

	# 4. Order delivery batal (GDD 11.3 baris 4).
	if delivery_cancelled > 0:
		out.append(_hl("⚠️", "warning", String(LINES["highlight_delivery_cancelled"]) % [delivery_cancelled]))

	# 5. Roti gosong terjual (GDD 11.3 baris 5).
	if burned_sold > 0:
		out.append(_hl("🔥", "fire", String(LINES["highlight_burned"])))

	# 6. Roti terlaris hari ini (GDD 11.3 baris 1).
	if not best_recipe.is_empty() and best_recipe_count > 0:
		var rname: String = _recipe_name(best_recipe)
		out.append(_hl("🏆", "trophy", String(LINES["highlight_best_recipe"]) % [rname, best_recipe_count]))

	# 7. Karyawan sangat produktif (GDD 11.3 baris 6).
	if not best_staff.is_empty():
		var s: Dictionary = _staff_entry(best_staff)
		if not s.is_empty():
			var speed: float = float(s.get("speed", 0.0))
			# Hanya baker yang punya "pengali kecepatan" produksi (GDD 3.2).
			if String(s.get("role", "")) == "baker" and speed > 1.0:
				var sname: String = String(s.get("name", best_staff))
				out.append(_hl("💪", "chef", String(LINES["highlight_staff"]) % [sname, _fmt_speed(speed)]))

	# 8. Stok gudang hampir habis (GDD 11.3 baris 7).
	if pantry_capacity > 0 and pantry_total >= 0:
		if float(pantry_total) <= float(pantry_capacity) * PANTRY_LOW_RATIO:
			out.append(_hl("📦", "box", String(LINES["highlight_pantry_low"])))

	# 9. Kampanye iklan aktif (GDD 11.3 baris 9).
	if campaign_tier > 0:
		var cname: String = _campaign_name(campaign_tier)
		if not cname.is_empty():
			var total: int = maxi(_campaign_duration(), 1)
			var day_no: int = clampi(total - campaign_days_left + 1, 1, total)
			out.append(_hl("📢", "megaphone", String(LINES["highlight_campaign"]) % [cname, day_no, total]))

	if out.size() > MAX_HIGHLIGHTS:
		return out.slice(0, MAX_HIGHLIGHTS)
	return out


static func _hl(icon: String, icon_name: String, text: String) -> Dictionary:
	return {
		"icon": icon,
		"icon_name": icon_name,
		"text": text,
	}

# ---------------------------------------------------------------------------
# GDD 11.2 — Indikator Mood Toko
# ---------------------------------------------------------------------------

## Ekspresi wajah besar di bagian atas kertas nota.
## Kembalikan {emoji, bg_color, text, icon_name} sesuai tabel GDD 11.2.
static func mood(profit: float, rating_delta: float, bailout: bool) -> Dictionary:
	# Baris 5: Saldo 0 KR / bailout terpicu.
	if bailout:
		return {
			"emoji": "🥺",
			"bg_color": _palette_color(
				PackedStringArray(["MOOD_BAILOUT", "MOOD_PINK", "PINK_SOFT", "SOFT_PINK"]),
				Color(BG_HEX_BAILOUT)),
			"text": String(LINES["mood_bailout"]),
			"icon_name": "sad",
		}
	# Baris 1: Laba bersih > 2.000 KR & rating naik.
	if profit > PROFIT_AMAZING and rating_delta > 0.0:
		return {
			"emoji": "🤩",
			"bg_color": _palette_color(
				PackedStringArray(["MOOD_AMAZING", "MOOD_GOLD", "GOLD", "GOLDEN_YELLOW"]),
				Color(BG_HEX_AMAZING)),
			"text": String(LINES["mood_amazing"]),
			"icon_name": "party",
		}
	# Baris 3: Impas / laba sangat kecil.
	if absf(profit) <= PROFIT_BREAKEVEN_BAND:
		return {
			"emoji": "😐",
			"bg_color": _palette_color(
				PackedStringArray(["MOOD_FLAT", "MOOD_NEUTRAL", "CREAM", "CREAM_NEUTRAL"]),
				Color(BG_HEX_FLAT)),
			"text": String(LINES["mood_flat"]),
			"icon_name": "bubble",
		}
	# Baris 2: Laba bersih positif, rating stabil.
	if profit > 0.0:
		return {
			"emoji": "😊",
			"bg_color": _palette_color(
				PackedStringArray(["MOOD_GOOD", "MOOD_GREEN", "GREEN_PASTEL", "PASTEL_GREEN"]),
				Color(BG_HEX_GOOD)),
			"text": String(LINES["mood_good"]),
			"icon_name": "happy",
		}
	# Baris 4: Rugi, tapi masih ada saldo.
	return {
		"emoji": "😟",
		"bg_color": _palette_color(
			PackedStringArray(["MOOD_BAD", "MOOD_ORANGE", "ORANGE_WARM", "WARM_ORANGE"]),
			Color(BG_HEX_BAD)),
		"text": String(LINES["mood_bad"]),
		"icon_name": "sad",
	}

# ---------------------------------------------------------------------------
# GDD 7 — Balon Pikiran Pelanggan (Thought Bubbles)
# ---------------------------------------------------------------------------

## Keluhan singkat di atas kepala pelanggan.
## [param kind]: "antrean_lama", "harga_mahal", "stok_habis", "roti_gosong".
static func customer_thought(kind: String) -> String:
	var id: String = "thought_" + kind
	if LINES.has(id):
		return String(LINES[id])
	return String(LINES["thought_default"])


## Nama ikon IconCanvas yang menyertai balon pikiran (GDD 7).
static func customer_thought_icon(kind: String) -> String:
	match kind:
		"antrean_lama":
			return "hourglass"  # GDD 7: "antrean lama (ikon jam pasir)"
		"harga_mahal":
			return "coin"       # GDD 7: "harga mahal (ikon uang terbang)"
		"stok_habis":
			return "cross"
		"roti_gosong":
			return "fire"
	return "bubble"

# ---------------------------------------------------------------------------
# GDD 5.3 "Cara Kerja Resep" — emoji reaksi slider harga
# ---------------------------------------------------------------------------

## Emoji prediksi reaksi pelanggan terhadap harga jual per buah.
## [param sweet_spot] adalah Vector2(min, maks) dari RecipeDB.sweet_spot_range().
## Terlalu mahal -> wajah cemberut; pas -> senyum puas; murah -> wajah bahagia.
static func price_reaction(price: float, sweet_spot: Vector2) -> String:
	if price > sweet_spot.y:
		return "😤"
	if price < sweet_spot.x:
		return "🤩"
	return "😊"

# ---------------------------------------------------------------------------
# Pembantu internal
# ---------------------------------------------------------------------------

## Nama tampilan resep; jatuh kembali ke id mentah bila resep tidak dikenal.
static func _recipe_name(recipe_id: String) -> String:
	var e: Dictionary = RecipeDB.entry(recipe_id)
	if e.is_empty():
		return recipe_id
	return String(e.get("name", recipe_id))


## Data staf; {} bila id tidak dikenal.
static func _staff_entry(staff_id: String) -> Dictionary:
	return StaffDB.entry(staff_id)


## Nama kampanye pemasaran aktif; "" bila tier tidak dikenal.
static func _campaign_name(tier: int) -> String:
	var e: Dictionary = MarketingDB.entry(tier)
	if e.is_empty():
		return ""
	return String(e.get("name", ""))


## Durasi kampanye dalam hari (GDD 8: masa aktif 5 hari in-game).
static func _campaign_duration() -> int:
	return MarketingDB.DURATION_DAYS


## Format pengali kecepatan baker tanpa nol berlebih: 1.60 -> "1.6", 1.25 -> "1.25".
static func _fmt_speed(v: float) -> String:
	var s: String = "%.2f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


## Cache konstanta warna milik autoload Palette.
static var _palette_consts: Dictionary = {}
static var _palette_probed: bool = false


## Baca peta konstanta dari script autoload "Palette" bila sudah aktif.
## Cache hanya dikunci setelah Palette benar-benar ditemukan, agar pemanggilan
## sangat awal (sebelum autoload siap) tidak mengunci cache kosong selamanya.
static func _palette_constants() -> Dictionary:
	if _palette_probed:
		return _palette_consts
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			var node: Node = tree.root.get_node_or_null(NodePath("Palette"))
			if node != null:
				var scr: Script = node.get_script() as Script
				if scr != null:
					_palette_consts = scr.get_script_constant_map()
					_palette_probed = true
	return _palette_consts


## Ambil warna dari Palette memakai nama konstanta pertama yang cocok.
## Bila Palette belum ada atau tidak punya nama tersebut, pakai hex GDD.
static func _palette_color(keys: PackedStringArray, fallback: Color) -> Color:
	var consts: Dictionary = _palette_constants()
	if not consts.is_empty():
		for k in keys:
			var key: String = String(k)
			if consts.has(key) and consts[key] is Color:
				return consts[key] as Color
	return fallback
