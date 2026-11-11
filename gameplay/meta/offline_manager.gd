class_name OfflineManager
extends SimManager
## Penghasilan saat pemain pergi (GDD idle 9.2-9.5). Waktu offline tidak
## disimulasikan: KR/s model (tanpa boost) saat terakhir aktif dikali lama pergi
## (dibatasi `cap_seconds`) dan `efficiency`.
##
## Acuan `last_active_unix` diperbarui setiap save lewat SaveManager
## (`mark_active`), dan dibekukan selama aplikasi/tab di latar (`freeze`)
## supaya save di latar tidak menghapus waktu pergi. `settle` dipanggil GameRoot
## saat profil dimuat dan saat fokus kembali. Simulasi tidak pernah memanggil
## jam dinding, jadi determinisme per seed tetap utuh (GDD idle 15.4).

## Jam unix (detik) saat game terakhir aktif; 0 = belum diketahui.
var last_active_unix: float = 0.0
## KR/s model tanpa boost saat terakhir aktif.
var rate_kr_per_s: float = 0.0
## Penghasilan yang menunggu Collect di popup Selamat Datang:
## {amount, seconds (yang dihitung), away (lama pergi sebenarnya)} atau {}.
var pending: Dictionary = {}
## Tes: jam unix palsu (< 0 = jam sistem).
var now_override: float = -1.0
var _frozen: bool = false


func new_game() -> void:
	last_active_unix = 0.0
	rate_kr_per_s = 0.0
	pending = {}
	_frozen = false


func now_unix() -> float:
	return now_override if now_override >= 0.0 else Time.get_unix_time_from_system()


## Batas lama pergi yang dihitung (detik nyata): 2 jam + upgrade global + perk,
## paling lama 12 jam (GDD idle 9.2), ditambah jam pembelian (Night Manager,
## Baker's Club, GDD idle 22.5) sampai `premium.max_offline_hours`.
func cap_seconds() -> float:
	var hours: float = DataRegistry.idlef("offline.base_cap_hours") + sim.upgrades.global_bonus(&"global_offline_hours") \
		+ sim.prestige.offline_hours_bonus()
	hours = minf(hours, DataRegistry.idlef("offline.max_cap_hours")) + sim.premium.offline_hours()
	return minf(hours, DataRegistry.idlef("premium.max_offline_hours")) * 3600.0


## Bagian KR/s yang didapat saat pergi: 50% + upgrade global + perk, paling
## tinggi 100% (GDD idle 9.2).
func efficiency() -> float:
	if sim.premium.offline_full():
		return DataRegistry.idlef("offline.max_efficiency")
	var e: float = DataRegistry.idlef("offline.base_efficiency") + sim.upgrades.global_bonus(&"global_offline_efficiency") \
		+ sim.prestige.offline_efficiency_bonus()
	return minf(e, DataRegistry.idlef("offline.max_efficiency"))


## Game aktif sekarang: catat jam dan KR/s model tanpa boost. Tidak berbuat apa
## pun selama dibekukan.
func mark_active() -> void:
	if _frozen or sim == null:
		return
	last_active_unix = now_unix()
	rate_kr_per_s = sim.idle_economy.rate(false)


## Aplikasi/tab ke latar: acuan dicatat lalu dibekukan sampai `thaw`.
func freeze() -> void:
	mark_active()
	_frozen = true


func is_frozen() -> bool:
	return _frozen


## Fokus kembali: lepas pembekuan lalu hitung waktu pergi.
func thaw() -> Dictionary:
	_frozen = false
	return settle()


## Penghasilan untuk `away` detik pergi: KR/s tersimpan × min(away, batas) ×
## efisiensi. Mengembalikan {amount, seconds}.
func earnings_for(away: float) -> Dictionary:
	return _earnings(rate_kr_per_s, away)


func _earnings(rate: float, away: float) -> Dictionary:
	var counted: float = clampf(away, 0.0, cap_seconds())
	return {"amount": Money.round_cents(maxf(rate, 0.0) * counted * efficiency()), "seconds": counted}


## Cabang `branch` baru dikunjungi pada jam unix `now` (GDD idle §20 no. 78):
## selama ditinggal sejak `left` ia menabung seperti penghasilan offline, dengan
## KR/s `rate` saat ditinggal dan batas serta efisiensi cabang ini. Aturannya
## sama dengan `settle`: < min_away diabaikan, < popup_min langsung masuk
## (toast), selebihnya menunggu Collect di popup Selamat Datang cabang itu.
## Tabungan cabang sebelumnya sudah masuk saat ditinggal, jadi `pending` kosong.
## Hasil: {} atau {amount, seconds, away, popup, branch}.
func settle_branch(now: float, left: float, rate: float, branch: int) -> Dictionary:
	if left <= 0.0 or now <= left:
		return {}
	var away: float = now - left
	if away < DataRegistry.idlef("offline.min_away_seconds"):
		return {}
	var e: Dictionary = _earnings(rate, away)
	var out: Dictionary = {"amount": float(e["amount"]), "seconds": float(e["seconds"]), "away": away,
		"popup": away >= DataRegistry.idlef("offline.popup_min_seconds"), "branch": branch}
	if bool(out["popup"]):
		pending = {"amount": float(out["amount"]), "seconds": float(out["seconds"]), "away": away, "branch": branch}
	else:
		_credit(float(out["amount"]), float(out["seconds"]))
	return out


## Hitung waktu sejak acuan terakhir (GDD idle 9.3, 9.4) lalu perbarui acuan.
## Hasil: {} bila tidak ada apa-apa; selain itu {amount, seconds, away, popup,
## boosted}. Pergi < min_away diabaikan. Pergi >= popup_min menumpuk ke
## `pending` untuk popup Selamat Datang (dikreditkan lewat `collect`); di
## antaranya KR langsung dikreditkan dan cukup diberi toast. Jam mundur: away =
## 0, acuan direset. Boost iklan ×2 (GDD idle 22.4) berjalan dengan jam nyata:
## detik pergi selama boost masih ada ikut dikali, lalu boostnya dipotong.
func settle() -> Dictionary:
	var now: float = now_unix()
	var last: float = last_active_unix
	var out: Dictionary = {}
	if last > 0.0 and now >= last:
		var away: float = now - last
		if away >= DataRegistry.idlef("offline.min_away_seconds"):
			var e: Dictionary = earnings_for(away)
			var boosted: float = sim.premium.boosted_seconds(float(e["seconds"]))
			var extra: float = Money.round_cents(maxf(rate_kr_per_s, 0.0) * boosted * efficiency() * (sim.premium.ad_boost_mult() - 1.0))
			out = {"amount": float(e["amount"]) + extra, "seconds": float(e["seconds"]), "away": away, "boosted": boosted,
				"popup": away >= DataRegistry.idlef("offline.popup_min_seconds") or not pending.is_empty()}
			if bool(out["popup"]):
				pending = {"amount": float(pending.get("amount", 0.0)) + float(out["amount"]),
					"seconds": float(pending.get("seconds", 0.0)) + float(out["seconds"]),
					"away": float(pending.get("away", 0.0)) + away}
			else:
				_credit(float(out["amount"]), float(out["seconds"]))
		sim.premium.consume_away(away)
	elif last > 0.0:
		GameLogger.warn("OFFLINE", "device clock went backwards by %.0f s; reference reset" % (last - now))
	last_active_unix = now
	rate_kr_per_s = sim.idle_economy.rate(false)
	return out


## Collect di popup Selamat Datang: kreditkan penghasilan yang menunggu.
## Mengembalikan jumlahnya.
## Masukkan penghasilan yang menunggu Collect. `mult` > 1 = hadiah iklan
## Collect ×2 (GDD idle 9.5, 22.3).
func collect(mult: float = 1.0) -> float:
	if pending.is_empty():
		return 0.0
	var amount: float = Money.round_cents(float(pending.get("amount", 0.0)) * maxf(mult, 1.0))
	_credit(amount, float(pending.get("seconds", 0.0)))
	pending = {}
	SaveManager.request_autosave("offline_collect")
	return amount


func _credit(amount: float, seconds: float) -> void:
	if amount > 0.0:
		sim.economy.credit(amount, &"OFFLINE_EARNINGS", &"offline", {"seconds": seconds})
	sim.statistics.note_offline(seconds, amount)
	sim.idle_economy.invalidate()


func capture() -> Dictionary:
	return {"last_active_unix": last_active_unix, "rate_kr_per_s": rate_kr_per_s, "pending": pending.duplicate()}


func restore(d: Dictionary) -> void:
	last_active_unix = maxf(float(d.get("last_active_unix", 0.0)), 0.0)
	rate_kr_per_s = maxf(float(d.get("rate_kr_per_s", 0.0)), 0.0)
	var p: Variant = d.get("pending", {})
	pending = (p as Dictionary).duplicate() if p is Dictionary and float((p as Dictionary).get("amount", 0.0)) >= 0.0 else {}
	if not pending.is_empty() and not pending.has("amount"):
		pending = {}
	_frozen = false
