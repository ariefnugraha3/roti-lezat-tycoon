class_name DummyMonetizationProvider
extends MonetizationProvider
## Toko uji (GDD idle 22.2): iklan dan pembelian tiruan selama plugin Google
## Play Billing dan AdMob belum dipasang (`monetization.dummy_store`). Tidak ada
## uang yang ditarik dan tidak ada jaringan. GameRoot mendengarkan
## Monetization.dummy_ad_requested / dummy_purchase_requested dan menampilkan
## layar tiruannya (DummyAdScreen, konfirmasi Test store); tanpa pendengar
## (alat ukur headless) keduanya langsung berhasil pada frame berikutnya.


func id() -> StringName:
	return &"dummy"


func ads_ready() -> bool:
	return true


func show_rewarded(done: Callable) -> void:
	if Monetization.dummy_ad_requested.get_connections().is_empty():
		done.call_deferred(true)
	else:
		Monetization.dummy_ad_requested.emit(done)


func store_ready() -> bool:
	return true


## Harga tiruan dari katalog (`price_usd`).
func product_price(product: StringName) -> String:
	var p: Dictionary = PremiumManager.product(product)
	return "$" + Tx.dec(float(p.get("price_usd", 0.0)), 2) if not p.is_empty() else ""


func buy(product: StringName, done: Callable) -> void:
	if Monetization.dummy_purchase_requested.get_connections().is_empty():
		done.call_deferred(true)
	else:
		Monetization.dummy_purchase_requested.emit(product, done)


## Toko uji tidak punya akun: yang dimiliki adalah hak beli perangkat ini.
func restore_purchases(done: Callable) -> void:
	done.call(Monetization.owned.duplicate())
