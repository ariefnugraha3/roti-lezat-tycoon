class_name Palette
extends RefCounted
## Palette -- seluruh warna "Warm, Cozy & Cute" milik Roti Lezat Tycoon.
##
## Satu-satunya sumber warna material dan UI (GDD 32.4). Bukan autoload: GDD 35.2
## menetapkan daftar autoload secara pasti, dan konstanta cukup diakses lewat
## nama kelas.
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
# UI kit "bantal empuk" (pemolesan UI 2026-09-30): muka tombol & garis bibirnya
# ---------------------------------------------------------------------------

## Cokelat kayu tua: garis tepi tombol, bibir panel, dan outline teks judul.
const UI_WOOD_DEEP: Color = Color(0.400000, 0.235294, 0.129412)  # #663C21
## Krem mentega yang lebih pekat: jalur tab, slider, dan bidang cekung.
const UI_CREAM_DEEP: Color = Color(0.952941, 0.890196, 0.764706)  # #F3E3C3
## Madu keemasan: muka tombol utama.
const HONEY: Color = Color(0.964706, 0.647059, 0.200000)  # #F6A533
## Madu gelap: tepi & bibir tombol utama, outline teks di atasnya.
const HONEY_DEEP: Color = Color(0.721569, 0.388235, 0.113725)  # #B8631D
## Matcha pastel: muka tombol konfirmasi / berhasil.
const MATCHA: Color = Color(0.498039, 0.780392, 0.450980)  # #7FC773
## Matcha gelap: tepi & bibir tombol matcha.
const MATCHA_DEEP: Color = Color(0.282353, 0.525490, 0.270588)  # #488645
## Stroberi: muka tombol bahaya.
const STRAWBERRY: Color = Color(0.937255, 0.431373, 0.458824)  # #EF6E75
## Stroberi gelap: tepi & bibir tombol bahaya.
const STRAWBERRY_DEEP: Color = Color(0.674510, 0.227451, 0.282353)  # #AC3A48
## Cokelat susu: bibir tombol & panel krem.
const CREAM_LIP: Color = Color(0.815686, 0.682353, 0.525490)  # #D0AE86

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


## Lingkungan luar toko (GDD 32.5, keputusan maintainer 2026-10-08): perumahan kampung kota Tier 1. Warnanya sedikit diredam supaya toko tetap pusat perhatian.
## Aspal jalan komplek.
const ASPHALT: Color = Color(0.435294, 0.419608, 0.411765)  # #6F6B69
## Tambalan aspal yang lebih baru.
const ASPHALT_PATCH: Color = Color(0.380392, 0.364706, 0.360784)  # #615D5C
## Beton semen (got, teras mobil, tiang).
const CONCRETE: Color = Color(0.827451, 0.796078, 0.745098)  # #D3CBBE
## Beton yang lebih tua dan teduh.
const CONCRETE_DARK: Color = Color(0.678431, 0.643137, 0.592157)  # #ADA497
## Air dan dasar got.
const GUTTER: Color = Color(0.341176, 0.321569, 0.305882)  # #57524E
## Rumput halaman dan tanah lapang.
const GRASS: Color = Color(0.647059, 0.760784, 0.521569)  # #A5C285
## Rumput yang lebih rimbun.
const GRASS_DEEP: Color = Color(0.556863, 0.678431, 0.439216)  # #8EAD70
## Daun pohon.
const LEAF: Color = Color(0.525490, 0.698039, 0.431373)  # #86B26E
## Daun di bagian teduh.
const LEAF_DEEP: Color = Color(0.403922, 0.592157, 0.337255)  # #679756
## Batang pohon.
const TRUNK: Color = Color(0.549020, 0.419608, 0.298039)  # #8C6B4C
## Paving dan keramik halaman.
const PAVING: Color = Color(0.894118, 0.839216, 0.780392)  # #E4D6C7
## Keramik teras.
const TERRACE_TILE: Color = Color(0.933333, 0.882353, 0.803922)  # #EEE1CD
## Genteng tanah liat.
const ROOF_TILE: Color = Color(0.772549, 0.419608, 0.294118)  # #C56B4B
## Genteng di sisi teduh dan bubungan.
const ROOF_TILE_DEEP: Color = Color(0.650980, 0.333333, 0.227451)  # #A6553A
## Cat rumah: krem.
const HOUSE_CREAM: Color = Color(0.949020, 0.909804, 0.839216)  # #F2E8D6
## Cat rumah: hijau mint.
const HOUSE_MINT: Color = Color(0.811765, 0.898039, 0.839216)  # #CFE5D6
## Cat rumah: persik.
const HOUSE_PEACH: Color = Color(0.956863, 0.827451, 0.749020)  # #F4D3BF
## Cat rumah: biru langit.
const HOUSE_SKY: Color = Color(0.823529, 0.878431, 0.925490)  # #D2E0EC
## Cat rumah: kuning mentega.
const HOUSE_BUTTER: Color = Color(0.952941, 0.894118, 0.709804)  # #F3E4B5
## Kaca jendela.
const WINDOW_GLASS: Color = Color(0.623529, 0.698039, 0.749020)  # #9FB2BF
## Kusen dan pintu kayu.
const DOOR_WOOD: Color = Color(0.607843, 0.423529, 0.282353)  # #9B6C48
## Pagar besi.
const IRON_FENCE: Color = Color(0.309804, 0.360784, 0.333333)  # #4F5C55
## Kabel listrik.
const CABLE: Color = Color(0.239216, 0.223529, 0.215686)  # #3D3937
## Toren air jingga.
const WATER_TANK: Color = Color(0.898039, 0.549020, 0.239216)  # #E58C3D
## Toren air biru.
const WATER_TANK_BLUE: Color = Color(0.419608, 0.592157, 0.768627)  # #6B97C4
## Ban dan jok motor.
const TIRE: Color = Color(0.200000, 0.188235, 0.180392)  # #33302E


## Lingkungan luar toko Tier 2 (GDD 32.5): pertokoan ruko. Papan nama sedikit lebih cerah dari cat rumah supaya terbaca sebagai pertokoan, tetapi tetap diredam.
## Pintu gulung ruko.
const SHUTTER: Color = Color(0.811765, 0.796078, 0.768627)  # #CFCBC4
## Garis lipatan pintu gulung.
const SHUTTER_LINE: Color = Color(0.662745, 0.643137, 0.611765)  # #A9A49C
## Bagian dalam toko yang gelap di balik pintu yang terbuka.
const SHOP_INTERIOR: Color = Color(0.419608, 0.341176, 0.278431)  # #6B5747
## Marka jalan.
const ROAD_PAINT: Color = Color(0.933333, 0.913725, 0.862745)  # #EEE9DC
## Atap seng kios.
const ZINC_ROOF: Color = Color(0.662745, 0.690196, 0.701961)  # #A9B0B3


## Lingkungan luar toko Tier 3 (GDD 32.5): jalan raya kota.
## Ubin pemandu kuning di trotoar.
const TACTILE: Color = Color(0.901961, 0.776471, 0.325490)  # #E6C653


## Lingkungan luar toko Tier 4 (GDD 32.5): kawasan premium.
## Granit pelataran dan trotoar.
const GRANITE: Color = Color(0.784314, 0.772549, 0.752941)  # #C8C5C0
## Granit terang.
const GRANITE_LIGHT: Color = Color(0.878431, 0.866667, 0.847059)  # #E0DDD8
## Kuningan (tiang tali, lis toko, plakat).
const BRASS: Color = Color(0.788235, 0.639216, 0.309804)  # #C9A34F
## Bunga tabebuya merah muda.
const BLOSSOM: Color = Color(0.949020, 0.662745, 0.768627)  # #F2A9C4
## Bunga tabebuya di bagian teduh.
const BLOSSOM_DEEP: Color = Color(0.870588, 0.529412, 0.670588)  # #DE87AB
## Air kolam air mancur.
const WATER: Color = Color(0.654902, 0.831373, 0.886275)  # #A7D4E2


## Lingkungan luar toko Tier 5 (GDD 32.5): alun-alun kota bergaya heritage.
## Batu andesit alun-alun.
const STONE: Color = Color(0.662745, 0.647059, 0.619608)  # #A9A59E
## Batu andesit terang.
const STONE_LIGHT: Color = Color(0.776471, 0.760784, 0.729412)  # #C6C2BA
## Dinding gedung kolonial.
const COLONIAL_WHITE: Color = Color(0.952941, 0.929412, 0.878431)  # #F3EDE0
## Daun jendela dan pintu kolonial.
const COLONIAL_GREEN: Color = Color(0.305882, 0.541176, 0.415686)  # #4E8A6A
## Cat muka ruko: abu-abu hangat.
const RUKO_GREY: Color = Color(0.862745, 0.843137, 0.807843)  # #DCD7CE
## Cat muka ruko: hijau sage.
const RUKO_SAGE: Color = Color(0.803922, 0.850980, 0.776471)  # #CDD9C6
## Cat muka ruko: pasir.
const RUKO_SAND: Color = Color(0.917647, 0.850980, 0.749020)  # #EAD9BF
## Cat muka ruko: merah muda pucat.
const RUKO_BLUSH: Color = Color(0.937255, 0.815686, 0.772549)  # #EFD0C5
## Cat muka ruko: ungu muda.
const RUKO_LILAC: Color = Color(0.866667, 0.835294, 0.901961)  # #DDD5E6
## Papan nama: merah bata.
const SIGN_RED: Color = Color(0.850980, 0.427451, 0.372549)  # #D96D5F
## Papan nama: biru.
const SIGN_BLUE: Color = Color(0.423529, 0.584314, 0.776471)  # #6C95C6
## Papan nama: hijau.
const SIGN_GREEN: Color = Color(0.368627, 0.643137, 0.494118)  # #5EA47E
## Papan nama: kuning.
const SIGN_YELLOW: Color = Color(0.937255, 0.776471, 0.360784)  # #EFC65C
## Papan nama: ungu.
const SIGN_PURPLE: Color = Color(0.607843, 0.521569, 0.760784)  # #9B85C2
## Papan nama: jingga.
const SIGN_ORANGE: Color = Color(0.925490, 0.607843, 0.321569)  # #EC9B52


## Gradasi warna panggang: t = 0 adonan pucat mentah, t = 0.6 cokelat keemasan
## matang sempurna, t = 1 hitam gosong berjelaga (GDD 4.2).
static func bake_shade(t: float) -> Color:
	var k: float = clampf(t, 0.0, 1.0)
	if k <= BAKE_PERFECT_T:
		return RAW_DOUGH.lerp(GOLDEN_CRUST, k / BAKE_PERFECT_T)
	return GOLDEN_CRUST.lerp(BURNT_BLACK, (k - BAKE_PERFECT_T) / (1.0 - BAKE_PERFECT_T))


## Warna celemek staf menurut peran ("cashier" / "baker") dan tier keahlian 1..5.
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
