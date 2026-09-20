extends Node
## Palette -- seluruh warna "Warm, Cozy & Cute" milik Roti Lezat Tycoon.
##
## Skrip ini didaftarkan sebagai autoload bernama "Palette" di project.godot,
## sehingga TIDAK memakai "class_name": nama kelas global akan bentrok dengan
## nama singleton autoload pada Godot 4.
##
## Nilai warna ditulis sebagai komponen float 0..1 agar aman dipakai di dalam
## ekspresi konstan; kode heksadesimal asli dari GDD dicatat pada komentar
## di setiap baris supaya tetap mudah ditelusuri.

# ---------------------------------------------------------------------------
# GDD 4.1 -- Warm: pencahayaan golden hour
# ---------------------------------------------------------------------------

## Cahaya matahari sore kuning keemasan yang menerobos jendela kayu.
const GOLDEN_HOUR: Color = Color(1.000000, 0.890196, 0.658824)  # #FFE3A8
## Pendar lampu penghangat etalase.
const WARMER_LAMP: Color = Color(1.000000, 0.666667, 0.266667)  # #FFAA44

# ---------------------------------------------------------------------------
# GDD 4.1 -- Palet kuliner hangat: Golden Crust & Loaf
# ---------------------------------------------------------------------------

## Cokelat panggang keemasan (kulit roti matang sempurna).
const GOLDEN_CRUST: Color = Color(0.850980, 0.509804, 0.168627)  # #D9822B
## Karamel hangat.
const CARAMEL: Color = Color(0.549020, 0.290196, 0.117647)  # #8C4A1E
## Cokelat gelap lembut.
const DARK_CHOCOLATE: Color = Color(0.352941, 0.180392, 0.070588)  # #5A2E12

# ---------------------------------------------------------------------------
# GDD 4.1 -- Butter & Custard
# ---------------------------------------------------------------------------

## Kuning mentega lembut.
const BUTTER_YELLOW: Color = Color(0.988235, 0.890196, 0.541176)  # #FCE38A
## Krim custard.
const CUSTARD: Color = Color(0.976471, 0.827451, 0.443137)  # #F9D371

# ---------------------------------------------------------------------------
# GDD 4.1 -- Flour & Milk Cream
# ---------------------------------------------------------------------------

## Putih gandum lembut.
const FLOUR_WHITE: Color = Color(1.000000, 0.984314, 0.960784)  # #FFFBF5
## Krem vanila hangat.
const VANILLA_CREAM: Color = Color(0.960784, 0.901961, 0.792157)  # #F5E6CA

# ---------------------------------------------------------------------------
# GDD 4.1 -- Cute: pipi merona & palet pastel kostum koki
# ---------------------------------------------------------------------------

## Pipi bulat merona merah muda pada karakter chibi.
const ROSY_CHEEK: Color = Color(1.000000, 0.603922, 0.635294)  # #FF9AA2
## Merah muda stroberi pastel.
const PASTEL_STRAWBERRY: Color = Color(1.000000, 0.717647, 0.698039)  # #FFB7B2
## Biru lavender pastel (periwinkle).
## CATATAN GDD: teks GDD 4.1 melabeli #C7CEEA sebagai "hijau matcha pastel",
## padahal nilai heksadesimalnya adalah biru lavender. Nilai hex dipertahankan
## apa adanya dan nama konstanta mengikuti warna yang sebenarnya.
const PASTEL_PERIWINKLE: Color = Color(0.780392, 0.807843, 0.917647)  # #C7CEEA
## Hijau mint pastel.
## CATATAN GDD: teks GDD 4.1 melabeli #B5EAD7 sebagai "biru langit lembut",
## padahal nilai heksadesimalnya adalah hijau mint. Nilai hex dipertahankan
## apa adanya dan nama konstanta mengikuti warna yang sebenarnya.
const PASTEL_MINT: Color = Color(0.709804, 0.917647, 0.843137)  # #B5EAD7

# ---------------------------------------------------------------------------
# GDD 3.6 -- Seragam kurir RotiFood
# ---------------------------------------------------------------------------

## Hijau toska pastel seragam Driver Ojek Online.
const OJOL_GREEN: Color = Color(0.305882, 0.729412, 0.435294)  # #4EBA6F
## Jas hujan kuning pengganti seragam hijau saat cuaca hujan (GDD 10.2).
const RAINCOAT_YELLOW: Color = Color(1.000000, 0.823529, 0.247059)  # #FFD23F

# ---------------------------------------------------------------------------
# GDD Seksi 7 -- Nuansa palet UI
# ---------------------------------------------------------------------------

## Krem mentega lembut, warna dasar seluruh panel UI.
const UI_CREAM: Color = Color(1.000000, 0.972549, 0.917647)  # #FFF8EA
## Cokelat kayu hangat, warna tinta dan bingkai UI.
const UI_WOOD: Color = Color(0.549020, 0.345098, 0.207843)  # #8C5835

# ---------------------------------------------------------------------------
# Turunan UI (dibangun dari palet di atas)
# ---------------------------------------------------------------------------

## Warna teks utama.
const TEXT: Color = Color(0.352941, 0.180392, 0.070588)  # #5A2E12
## Warna teks sekunder / keterangan.
const TEXT_MUTED: Color = Color(0.611765, 0.482353, 0.368627)  # #9C7B5E
## Latar belakang layar.
const BG: Color = Color(0.960784, 0.901961, 0.792157)  # #F5E6CA
## Panel utama.
const PANEL: Color = Color(1.000000, 0.972549, 0.917647)  # #FFF8EA
## Panel bertingkat / kartu di dalam panel.
const PANEL_ALT: Color = Color(1.000000, 0.984314, 0.960784)  # #FFFBF5
## Status berhasil / profit.
const SUCCESS: Color = Color(0.435294, 0.749020, 0.450980)  # #6FBF73
## Status peringatan.
const WARNING: Color = Color(0.909804, 0.639216, 0.239216)  # #E8A33D
## Status gagal / rugi.
const DANGER: Color = Color(0.894118, 0.388235, 0.415686)  # #E4636A
## Bayangan lembut untuk StyleBoxFlat.
const SHADOW: Color = Color(0.000000, 0.000000, 0.000000, 0.150000)

# ---------------------------------------------------------------------------
# GDD 4.1 (Cozy) -- Interior bernostalgia awal 2000-an
# ---------------------------------------------------------------------------

## Lantai ubin terakota.
const TERRACOTTA: Color = Color(0.768627, 0.411765, 0.239216)  # #C4693D
## Perabot kayu pinus berpelitur hangat.
const PINE_WOOD: Color = Color(0.788235, 0.603922, 0.384314)  # #C99A62
## Kotak pertama tirai jendela bermotif gingham pastel.
const GINGHAM_A: Color = Color(1.000000, 0.717647, 0.698039)  # #FFB7B2
## Kotak kedua tirai jendela bermotif gingham pastel.
const GINGHAM_B: Color = Color(1.000000, 0.984314, 0.960784)  # #FFFBF5
## Kertas nota Daily Summary bergaya parchment (GDD 11.7).
const PARCHMENT: Color = Color(1.000000, 0.972549, 0.917647)  # #FFF8EA
## Papan tulis kapur Pasar Bahan Baku (GDD Seksi 7).
const CHALKBOARD: Color = Color(0.243137, 0.290196, 0.239216)  # #3E4A3D
## Goresan kapur di atas papan tulis.
const CHALK_WHITE: Color = Color(0.949020, 0.949020, 0.909804)  # #F2F2E8
## Bintang rating emas (rating toko & RotiFood).
const GOLD_STAR: Color = Color(0.960784, 0.701961, 0.003922)  # #F5B301

# ---------------------------------------------------------------------------
# GDD 11.2 -- Warna latar Indikator Mood Daily Summary
# ---------------------------------------------------------------------------

## Laba bersih > 2.000 KR & rating naik -- kuning keemasan.
const MOOD_BG_AMAZING: Color = Color(1.000000, 0.878431, 0.541176)  # #FFE08A
## Laba bersih positif, rating stabil -- hijau pastel.
const MOOD_BG_GOOD: Color = Color(0.784314, 0.921569, 0.772549)  # #C8EBC5
## Impas / laba sangat kecil -- krem netral.
const MOOD_BG_NEUTRAL: Color = Color(0.945098, 0.905882, 0.839216)  # #F1E7D6
## Rugi, tapi masih ada saldo -- oranye hangat.
const MOOD_BG_ROUGH: Color = Color(1.000000, 0.788235, 0.627451)  # #FFC9A0
## Saldo 0 KR / bailout terpicu -- merah muda lembut.
const MOOD_BG_BAILOUT: Color = Color(1.000000, 0.839216, 0.862745)  # #FFD6DC

# ---------------------------------------------------------------------------
# GDD 4.2 -- Gradasi suhu kematangan roti
# ---------------------------------------------------------------------------

## Adonan mentah berwarna kuning pucat.
const RAW_DOUGH: Color = Color(0.937255, 0.878431, 0.690196)  # #EFE0B0
## Roti gosong: hitam gelap berjelaga.
const BURNT_BLACK: Color = Color(0.101961, 0.070588, 0.031373)  # #1A1208
## Ambang kematangan sempurna pada kurva bake_shade().
const BAKE_PERFECT_T: float = 0.6

# ---------------------------------------------------------------------------
# GDD 3.4 & 3.5 -- Warna celemek staf per tier
# ---------------------------------------------------------------------------

## Tier 1 (kasir & baker): celemek katun putih polos.
const APRON_WHITE: Color = Color(1.000000, 0.984314, 0.960784)  # #FFFBF5
## Tier 2 kasir: celemek hijau mint pastel.
const APRON_MINT: Color = Color(0.709804, 0.917647, 0.843137)  # #B5EAD7
## Tier 3 kasir: celemek cokelat karamel.
const APRON_CARAMEL: Color = Color(0.549020, 0.290196, 0.117647)  # #8C4A1E
## Tier 4 kasir: celemek biru navy elegan.
const APRON_NAVY: Color = Color(0.180392, 0.247059, 0.419608)  # #2E3F6B
## Tier 5 (kasir & baker): celemek emas koki kepala.
const APRON_GOLD: Color = Color(0.878431, 0.701961, 0.235294)  # #E0B33C
## Tier 2 baker: celemek oranye pastel.
const APRON_ORANGE_PASTEL: Color = Color(1.000000, 0.796078, 0.643137)  # #FFCBA4
## Tier 3 baker: celemek cokelat kopi pekat.
const APRON_COFFEE_BROWN: Color = Color(0.290196, 0.196078, 0.149020)  # #4A3226
## Tier 4 baker: celemek marun elegan.
const APRON_MAROON: Color = Color(0.431373, 0.133333, 0.200000)  # #6E2233


## Gradasi warna panggang: t = 0 adonan pucat mentah, t = 0.6 cokelat keemasan
## matang sempurna, t = 1 hitam gosong berjelaga (GDD 4.2).
static func bake_shade(t: float) -> Color:
	var k: float = clampf(t, 0.0, 1.0)
	if k <= BAKE_PERFECT_T:
		return RAW_DOUGH.lerp(GOLDEN_CRUST, k / BAKE_PERFECT_T)
	return GOLDEN_CRUST.lerp(BURNT_BLACK, (k - BAKE_PERFECT_T) / (1.0 - BAKE_PERFECT_T))


## Warna celemek staf menurut peran ("kasir" / "baker") dan tier keahlian 1..5.
## Mengikuti GDD 3.4 (putih -> cokelat karamel -> emas) serta warna celemek yang
## disebutkan pada roster GDD 3.5.
static func apron_for_tier(role: String, tier: int) -> Color:
	var t: int = clampi(tier, 1, 5)
	if role == "baker":
		var baker_aprons: Array[Color] = [
			APRON_WHITE,
			APRON_ORANGE_PASTEL,
			APRON_COFFEE_BROWN,
			APRON_MAROON,
			APRON_GOLD,
		]
		return baker_aprons[t - 1]
	var kasir_aprons: Array[Color] = [
		APRON_WHITE,
		APRON_MINT,
		APRON_CARAMEL,
		APRON_NAVY,
		APRON_GOLD,
	]
	return kasir_aprons[t - 1]
