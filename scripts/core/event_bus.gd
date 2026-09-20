extends Node
## EventBus -- satu-satunya kanal komunikasi antar sistem simulasi, dunia 3D, dan UI.
##
## Skrip ini didaftarkan sebagai autoload bernama "EventBus" di project.godot,
## sehingga TIDAK memakai "class_name": nama kelas global akan bentrok dengan
## nama singleton autoload pada Godot 4.
##
## Daftar sinyal di bawah ini persis mengikuti docs/ARCHITECTURE.md Seksi 5:
## tidak ada sinyal tambahan dan tidak ada yang dihilangkan.
## Pola pemakaian: EventBus.toast.emit("Roti matang!", "bread")
## dan EventBus.toast.connect(_on_toast).

# --- Siklus hari (GDD Seksi 2) ---

## Fase hari berganti: "prep" | "sell" | "close".
signal phase_changed(phase: String)

## Detak jam in-game, dikirim setiap _process oleh DayCycle.
signal clock_tick(hour: float)

## Hari baru dimulai pada pukul 04:00.
signal day_started(day: int)

## Hari berakhir pada pukul 18:00, membawa ledger untuk Daily Summary.
signal day_ended(ledger: Dictionary)

# --- Kas, gudang, dan etalase ---

## Saldo Koin Roti berubah.
signal coins_changed(coins: float)

## Isi gudang bahan baku berubah.
signal pantry_changed()

## Isi rak display berubah.
signal display_changed()

# --- Produksi (GDD 5.3) ---

## Satu batch masuk ke mixer / oven.
signal production_started(job: Dictionary)

## Satu batch selesai diproses dan siap diangkat.
signal production_finished(job: Dictionary)

## Roti terlambat diangkat lalu gosong.
signal bread_burned(recipe_id: String, count: int)

# --- Pelanggan fisik (GDD "Perilaku Konsumen") ---

## Pelanggan fisik memasuki toko.
signal customer_spawned(c: Dictionary)

## Pelanggan selesai dilayani di kasir.
signal customer_served(c: Dictionary, revenue: float)

## Pelanggan pergi marah (antrean panjang, stok habis, harga mahal).
signal customer_left_angry(c: Dictionary, reason: String)

# --- Pesanan online RotiFood (GDD 3.6) ---

## Notifikasi pesanan baru masuk ke tablet kasir.
signal delivery_order_received(order: Dictionary)

## Roti selesai dikemas ke dalam paper bag.
signal delivery_order_packed(order: Dictionary)

## Paket diserahkan kepada driver ojol, disertai nilai tip.
signal delivery_order_handover(order: Dictionary, tip: float)

## Pesanan dibatalkan otomatis karena kehabisan stok / melewati batas waktu.
signal delivery_order_expired(order: Dictionary)

# --- Reputasi & cuaca (GDD Seksi 9 dan 10) ---

## Rating toko fisik dan/atau rating aplikasi RotiFood berubah.
signal rating_changed(store: float, rotifood: float)

## Cuaca hari ini dan prakiraan besok ditetapkan: "cerah" | "hujan" | "liburan".
signal weather_changed(today: String, forecast: String)

# --- Karyawan (GDD Seksi 3.1-3.5) ---

## Pelamar direkrut menjadi staf toko.
signal staff_hired(staff_id: String)

## Staf diberhentikan.
signal staff_fired(staff_id: String)

## Staf diliburkan sementara atau dipanggil kembali bekerja (Mode Solo).
signal staff_leave_toggled(staff_id: String, on_leave: bool)

# --- Pemasaran (GDD Seksi 8) ---

## Kampanye iklan dimulai (durasi 5 hari).
signal campaign_started(tier: int)

## Kampanye iklan selesai.
signal campaign_ended(tier: int)

# --- Kebangkrutan & bantuan pemerintah (GDD 3.0) ---

## Kunjungan Pak Lurah terpicu; "times" = kunjungan ke berapa.
signal bailout_triggered(times: int)

## Mode Solo menyala atau padam.
signal solo_mode_changed(active: bool)

# --- Pembelian & progresi ---

## Alat atau lokasi ter-upgrade: kind = "mixer" | "oven" | "display" | "location".
signal upgrade_purchased(kind: String, tier: int)

## Resep baru dibeli di Buku Resep.
signal recipe_unlocked(recipe_id: String)

# --- Antarmuka ---

## Permintaan menampilkan pesan toast singkat beserta nama ikon prosedural.
signal toast(text: String, icon: String)

## Permintaan berpindah layar kepada ScreenRouter.
signal screen_requested(screen: String, args: Dictionary)
