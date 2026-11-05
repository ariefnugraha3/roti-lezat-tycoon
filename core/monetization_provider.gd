class_name MonetizationProvider
extends RefCounted
## Penyedia iklan dan toko satu platform (GDD idle 22.2). Kelas dasar ini adalah
## build tanpa monetisasi (desktop, GitHub Pages, itch.io): tidak ada iklan dan
## tidak ada toko. Portal web memakai PortalMonetizationProvider; tes memakai
## TestMonetizationProvider. Penyedia Android (AdMob dan Google Play Billing)
## ditambahkan bersama plugin Android-nya (GDD idle 22.2).


## Nama penyedia untuk log dan tes.
func id() -> StringName:
	return &"none"


## Dipanggil sekali saat Monetization siap.
func setup() -> void:
	pass


## Dipanggil setiap frame (penyedia yang menunggu jawaban SDK).
func poll() -> void:
	pass


## SDK platform siap menerima sinyal siklus hidup.
func connected() -> bool:
	return false


## Iklan berhadiah bisa diminta sekarang.
func ads_ready() -> bool:
	return false


## Tampilkan satu iklan berhadiah; `done(success)` dipanggil tepat sekali, true
## hanya bila iklan ditonton sampai selesai.
func show_rewarded(done: Callable) -> void:
	done.call(false)


## Toko platform tersedia (Supporter Pack bisa dibeli).
func store_ready() -> bool:
	return false


## Harga produk dalam mata uang toko ("" bila belum diketahui).
func product_price(_product: StringName) -> String:
	return ""


## Beli produk; `done(success)` dipanggil tepat sekali.
func buy(_product: StringName, done: Callable) -> void:
	done.call(false)


## Pulihkan pembelian; `done(owned: Array[StringName])`.
func restore_purchases(done: Callable) -> void:
	done.call([] as Array[StringName])


## Sinyal siklus hidup untuk portal: loading_finished, gameplay_start,
## gameplay_stop.
func lifecycle(_event: StringName) -> void:
	pass
