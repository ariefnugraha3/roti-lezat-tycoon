class_name TestMonetizationProvider
extends MonetizationProvider
## Penyedia palsu untuk tes dan alat (GDD idle 22): iklan "ditonton" pada frame
## berikutnya (Monetization.poll) dengan hasil yang dipilih tes, dan toko yang
## selalu berhasil. Mencatat sinyal siklus hidup yang diterimanya.

var ready: bool = true
var store: bool = true
## Hasil iklan berikutnya: true = selesai ditonton.
var succeed: bool = true
var shown: int = 0
var events: Array[StringName] = []
var owned: Array[StringName] = []
var _pending: Callable = Callable()


func id() -> StringName:
	return &"test"


func connected() -> bool:
	return true


func ads_ready() -> bool:
	return ready


func show_rewarded(done: Callable) -> void:
	shown += 1
	_pending = done


## Iklan sedang "tayang" (tes memeriksa pause dan senyap di antaranya).
func showing() -> bool:
	return _pending.is_valid()


func poll() -> void:
	if _pending.is_valid():
		var cb: Callable = _pending
		_pending = Callable()
		cb.call(succeed)


func store_ready() -> bool:
	return store


func product_price(_product: StringName) -> String:
	return "$2.99"


func buy(product: StringName, done: Callable) -> void:
	if not owned.has(product):
		owned.append(product)
	done.call(true)


func restore_purchases(done: Callable) -> void:
	done.call(owned.duplicate())


func lifecycle(event: StringName) -> void:
	events.append(event)
