# Panduan Universal Stabilitas Godot di Android, Optimasi HP Spek Rendah, dan Rilis Google Play Store

Dokumen ini adalah **cetak biru (*blueprint*) standar dan daftar pengaman (*guardrails*)** yang dirancang untuk **proyek game Godot 4 apa pun** yang menargetkan **Android** (mulai dari HP *entry-level* RAM kecil/"HP kentang" hingga HP layar *high-refresh-rate* `90/120 Hz` dan rilis **Google Play Store**).

Dokumen ini ditulis sedemikian rupa agar **AI mana pun bisa langsung mengaudit, menerapkan, memverifikasi, dan mem-build project Godot ke Android tanpa melakukan kesalahan klasik**, meski tidak memiliki konteks histori debugging sebelumnya.

> [!NOTE]
> Jika proyek tempat Anda bekerja sudah memiliki aturan spesifik tambahan (misalnya `AGENTS.md`, `CLAUDE.md`, GDD, atau validator rilis proyek tersebut), **jadikan aturan khusus proyek itu sebagai otoritas utama**, lalu terapkan standar universal di dokumen ini untuk seluruh aspek Android, rendering mobile, audio, performa, build, dan rilis.

---

## Ringkasan Cepat untuk AI (Baca Sebelum Mulai Kerja)

1. **Jangan percaya hasil PC Desktop atau `--headless` saja.** Bug fatal di Android—seperti kebocoran memori GPU OpenGL ES 3 (`glGenFramebuffers`), *native segfault* `AudioTrack`, *shader compile stutter*, keterbatasan *Scoped Storage*, dan *thermal throttling*—**sering hanya muncul di perangkat Android fisik atau emulator**.
2. **Jangan menonaktifkan atau melonggarkan tes otomatis** demi mengejar status lulus palsu.
3. **Jangan pernah menyimpan file keystore atau password signing ke dalam repositori Git** (`export_presets.cfg`, skrip, atau dokumentasi).
4. **Jalankan setiap audit di Bagian B secara berurutan** sebelum menyentuh kode, sebelum export APK/AAB, dan sebelum menyatakan tugas selesai di Bagian D.

---

## BAGIAN A — YANG WAJIB DIPERHATIKAN (Akar Masalah Crash & Aturan Keras Engine)

Setiap bagian di bawah memakai pola: **Gejala -> Akar Penyebab -> Cara Audit -> Aturan & Solusi Wajib**.

---

### A.1 Rendering & GPU: Crash Out-of-Memory FBO GLES3 (`SIGABRT` / Scudo Error)

#### Gejala Nyata di HP
- Game berjalan mulus saat startup dan awal gameplay, lalu setelah **2–4 menit** bermain mendadak **freeze dan force close** (sering lebih cepat pada layar `90 Hz`/`120 Hz`).
- Pada rekaman crash Android (`SYSTEM_TOMBSTONE` / `dumpsys dropbox`), proses mati dengan sinyal **`SIGABRT`** di `GLThread`, disertai pesan seperti:
  `Scudo ERROR: internal map failure (error desc=Out of memory)` dan jumlah *virtual memory area* (VMA) membludak hingga menabrak batas `vm.max_map_count` kernel Linux Android.
- Pada `adb shell dumpsys meminfo`, angka **`Native Heap`** terus naik konstan tiap detik (`+MB/detik`) hingga aplikasi mati.

#### Akar Penyebab Teknis (`gl_compatibility` / OpenGL ES 3)
1. Pada renderer **Compatibility (`gl_compatibility` / GLES3)** Godot 4.x (terkonfirmasi nyata di Godot 4.7.2 pada GPU mobile seperti Adreno/Mali), fitur yang mengaktifkan *internal 3D post-processing buffer* (`use_internal_buffer = true`)—seperti `WorldEnvironment.environment.adjustment_enabled = true`, efek *post-processing*, atau `scaling_3d_scale < 1.0`—berinteraksi dengan `msaa_3d` aktif.
2. Pada driver GPU Android yang mendukung ekstensi `GL_EXT_multisampled_render_to_texture`, cabang kode C++ alokasi buffer GLES3 (`RenderSceneBuffersGLES3::_check_render_buffers()`) dapat gagal menandai kepemilikan tekstur warna MSAA, sehingga terus-menerus memanggil `glGenFramebuffers` **setiap frame** tanpa membebaskan FBO lama.
3. Pada layar 120 Hz, kebocoran ratusan FBO OpenGL per detik memakan habis pemetaan memori virtual Android dalam hitungan menit.

#### Cara Audit di Project Godot Target
1. Buka `project.godot` dan periksa bagian `[rendering]`:
   - Apa `renderer/rendering_method.mobile` yang dipakai?
   - Apakah `anti_aliasing/quality/msaa_3d.mobile` ada dan bernilai `0`?
2. Cari di seluruh folder skrip (`.gd`) dan scene (`.tscn`, `.tres`):
   - Kata kunci `msaa_3d` (termasuk semua `SubViewport`).
   - Kata kunci `adjustment_enabled`, `glow_enabled`, `scaling_3d_scale`, `Environment`.

#### Aturan Wajib & Implementasi
1. **Kunci MSAA 3D mobile mati secara permanen di `project.godot`:**
   ```ini
   [rendering]
   renderer/rendering_method="gl_compatibility"
   renderer/rendering_method.mobile="gl_compatibility"
   textures/vram_compression/import_etc2_astc=true
   anti_aliasing/quality/msaa_3d.mobile=0
   ```
2. **Kunci `msaa_3d` di skrip pengaturan kualitas grafis (jika game punya menu Settings):**
   Pemeriksaan platform mobile **HARUS diletakkan di baris pertama** sebelum membaca preset kualitas (`Low`/`Medium`/`High`/`Auto`) agar pengguna di HP tidak bisa memicu bug ini lewat menu Settings:
   ```gdscript
   static func effective_msaa_3d(preset_msaa: int) -> Viewport.MSAA:
   	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
   		return Viewport.MSAA_DISABLED
   	# Jika game juga menargetkan browser HP (mobile WebGL), kembalikan MSAA_DISABLED juga di sana.
   	match clampi(preset_msaa, 0, 2):
   		1: return Viewport.MSAA_2X
   		2: return Viewport.MSAA_4X
   		_: return Viewport.MSAA_DISABLED
   ```
3. **Periksa seluruh `SubViewport`:**
   **DILARANG** membiarkan `msaa_3d != Viewport.MSAA_DISABLED` pada `SubViewport` mana pun yang ikut ter-export ke APK/AAB (misalnya pratinjau karakter, kartu skor 3D, atau mini-viewport kamera).
4. **Kompensasi Visual 2D tanpa MSAA 3D:**
   Untuk objek 2D yang digambar manual lewat `_draw()`, aktifkan parameter `antialiased = true` pada `draw_line()`, `draw_arc()`, `draw_circle()`, dan `draw_polyline()` (dengan lebar positif) agar UI dan ikon tetap tajam di layar PPI tinggi tanpa menyentuh MSAA 3D.

---

### A.2 Audio Native Android: `SIGSEGV` di `AudioTrack`, Bus Audio, & Main-Thread Hitches

#### Gejala & Akar Penyebab
1. **Crash `SIGSEGV` (`SEGV_ACCERR`) di thread `AudioTrack` (`libgodot_android.so`):**
   Terjadi ketika game memakai `AudioStreamWAV` yang dibuat atau dimodifikasi manual dalam buffer PCM (`PackedByteArray`), terutama musik/ambience panjang yang di-loop. Mixer interpolasi audio Godot membaca beberapa sampel melewati `loop_end` atau ujung buffer; di desktop memori tetangga kebetulan masih valid, sedangkan di Android buffer besar sering berhenti tepat di depan halaman pelindung memori (*guard page*).
2. **Audio Bisu / Rusak di Export Mobile atau Web (`AudioServer.add_bus()`):**
   Menggunakan `AudioServer.add_bus()` di runtime dapat menggeser urutan bus internal platform tertentu (misalnya menyisipkan bus di depan `Master`).
3. **Loading Membeku Lama di HP Kentang:**
   Sintesis audio prosedural atau dekompresi puluhan SFX/musik sekaligus di dalam `_ready()` memblokir *main thread* hingga puluhan detik pada CPU mobile/emulator.

#### Aturan Wajib & Implementasi
1. **Selalu tambahkan *Tail Padding* (`TAIL_PAD = 16` sampel) pada `AudioStreamWAV` buatan skrip:**
   Jika Anda membangun PCM secara prosedural dalam script:
   - Alokasikan buffer berukuran **`(jumlah_sampel_asli + 16)` sampel** (untuk 16-bit mono, dikali `2` byte).
   - **Jika looping (`AudioStreamWAV.LOOP_FORWARD`):** salin `16` sampel awal ke bagian ekor sesudah `jumlah_sampel_asli` agar interpolasi di sambungan loop tetap mulus dan aman dari *guard page*.
   - **Jika tidak looping:** isi `16` sampel ekor dengan `0` (keheningan).
   - **Tetapkan `stream.loop_end = jumlah_sampel_asli`** (jangan masukkan `TAIL_PAD` ke dalam `loop_end`, agar panjang durasi/irama tidak berubah).
   ```gdscript
   const TAIL_PAD: int = 16

   static func make_pcm16_wav(samples: PackedFloat32Array, mix_rate: int, looping: bool) -> AudioStreamWAV:
   	var n: int = samples.size()
   	var pcm := PackedByteArray()
   	pcm.resize((n + TAIL_PAD) * 2)
   	for i in n:
   		var v: int = clampi(int(round(samples[i] * 32767.0)), -32768, 32767)
   		pcm.encode_s16(i * 2, v)
   	for p in TAIL_PAD:
   		var src_idx: int = (p % n) if (looping and n > 0) else -1
   		var v_pad: int = clampi(int(round(samples[src_idx] * 32767.0)), -32768, 32767) if src_idx >= 0 else 0
   		pcm.encode_s16((n + p) * 2, v_pad)
   	var s := AudioStreamWAV.new()
   	s.format = AudioStreamWAV.FORMAT_16_BITS
   	s.mix_rate = mix_rate
   	s.stereo = false
   	s.data = pcm
   	if looping:
   		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
   		s.loop_begin = 0
   		s.loop_end = n
   	return s
   ```
2. **Gunakan `AudioServer.set_bus_count()` alih-alih `AudioServer.add_bus()`** saat membuat bus audio via kode.
3. **Hemat CPU/RAM & Hindari Stutter Audio:**
   - Untuk ambience berfrekuensi rendah atau audio prosedural berat, pertimbangkan `11025 Hz` (separuh biaya CPU/RAM dari `22050 Hz`).
   - Jika audio dibangkitkan lewat kode saat startup, lakukan perakitan **bertahap per frame (*time-sliced budget*)** di balik layar loading/splash, atau simpan hasil jadinya sebagai cache disk di `user://` dengan **hash kode sumber generator + versi engine** pada nama file cache (supaya otomatis di-regenerate jika resep audio berubah).

---

### A.3 Tombol Back Android (`NOTIFICATION_WM_GO_BACK_REQUEST`), Layer Modal, & Exit Confirmation

Di Android, menekan tombol Back fisik, tombol navigasi segitiga, atau menggeser tepi layar (*predictive back gesture*) memicu notifikasi engine `NOTIFICATION_WM_GO_BACK_REQUEST`, **bukan** input keyboard biasa.

#### Kesalahan Umum AI
- Membiarkan `config/quit_on_go_back=true` -> Pemain tidak sengaja menggeser tepi layar langsung keluar dari game tanpa konfirmasi dan progres terakhir bisa hilang.
- Membuka popup konfirmasi keluar, tetapi layer Splash/Menu berada di `CanvasLayer.layer` lebih tinggi (misalnya `50` vs `20`) -> Popup muncul secara tak terlihat di belakang splash, tombolnya tidak bisa diklik, dan aplikasi tampak hang!
- Handler `gui_input` di Splash Screen ikut menutup splash saat pemain menekan Back atau saat mengetuk di luar popup konfirmasi.

#### Aturan Wajib & Kontrak UX Mobile
1. **Matikan auto-quit di `project.godot` dan perkuat di skrip boot:**
   ```ini
   [application]
   config/quit_on_go_back=false
   ```
   ```gdscript
   func _ready() -> void:
   	ProjectSettings.set_setting("application/config/quit_on_go_back", false)
   	get_tree().set_quit_on_go_back(false)
   ```
2. **Tangani `NOTIFICATION_WM_GO_BACK_REQUEST` dengan hirarki prioritas yang tegas:**
   ```gdscript
   func _notification(what: int) -> void:
   	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
   		_handle_back_request()
   	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
   		_save_before_exit()
   ```
   Urutan logika `_handle_back_request()`:
   - **Tahap 1:** Jika sedang transisi loading/cutscene non-skippable -> **abaikan (`return`)**.
   - **Tahap 2:** Jika ada popup, dialog konfirmasi, bottom sheet, menu Pause, atau sub-halaman aktif -> **tutup/mundurkan lapisan paling atas dahulu** (`modal_stack.back() -> bool`) dan `return`. Termasuk jika `ConfirmDialog` keluar sedang terbuka: menekan Back lagi harus membatalkan/menutup dialog tersebut!
   - **Tahap 3:** Jika sedang dalam mode khusus (misalnya mode edit/dekorasi/build) -> biarkan mode itu membatalkan aksi pegang/keluar dari mode edit terlebih dahulu.
   - **Tahap 4 (Tidak ada modal di atas):**
     - Di **Web** (`OS.has_feature("web")`): browser tidak mengizinkan tab menutup dirinya sendiri; buka menu Pause saat bermain alih-alih `quit()`.
     - Di **Android / Desktop**: panggil fungsi `confirm_exit()` untuk menampilkan dialog konfirmasi keluar (*"Keluar dari game?"*). Jika pemain memilih **Ya/Confirm**, panggil `save_now()` lalu `get_tree().quit()`.
3. **Aturan Layering Mutlak (`CanvasLayer.layer`):**
   - Pastikan hierarki `layer` selalu konsisten:
     - Dunia 2D/3D utama (`layer 0`) < HUD normal (`layer ~10`) <= Layar Splash/Start (`layer <= 15`) < **Overlay Modal / Dialog Konfirmasi (`layer >= 20`)** < Loading Screen & Toast Kritis (`layer >= 25`).
   - Pastikan dialog konfirmasi exit bertipe *overlay/blocking* sehingga ketukan di sekitarnya tidak menembus ke UI/Splash di bawahnya.
   - Pada handler input Splash Screen (`_gui_input` / `_unhandled_input`): selalu tolak event jika ada modal terbuka (`modal_stack.has_top()`), dan **abaikan `KEY_ESCAPE` maupun `KEY_BACK`**.
4. **Pengecualian Layar Error Fatal (`ErrorScreen`):**
   Jika game sedang menampilkan dialog error kritis (misalnya data save rusak/corrupt dengan pilihan *Coba Lagi* atau *Mulai Baru*), menekan Back **tidak boleh** menutup layar error menjadi layar kosong atau menumpuk dialog baru yang membingungkan.

---

### A.4 Optimasi Performa untuk HP Spek Rendah ("HP Kentang")

Aturan berikut memastikan frame rate tetap stabil, penggunaan RAM rendah, dan baterai tidak cepat panas di SoC entry-level (RAM 2–4 GB, GPU Mali/PowerVR/Adreno kelas bawah):

#### 1. Pisahkan Resolusi Render 3D dari Ketajaman UI 2D (`scaling_3d_scale`)
- Banyak HP spek rendah punya layar Full HD+ (`1080×2400`), tetapi kemampuan shader fragmen GPU-nya sangat terbatas.
- Untuk game 3D di Android, atur `scaling_3d_scale` pada viewport dunia 3D antara **`0.70`–`0.85`** untuk preset *Auto* / *Low* di perangkat mobile:
  ```gdscript
  func effective_resolution_scale(user_pct: int, preset_scale: float, is_auto: bool) -> float:
  	var s: float = (float(user_pct) / 100.0) * preset_scale
  	if is_auto and (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")):
  		s = minf(s, 0.85)
  	return clampf(s, 0.5, 1.0)
  ```
- **Dampak:** Skala `0.85` memangkas jumlah piksel shader 3D sekitar `~28%` sambil menjaga seluruh teks, ikon, dan tombol di `CanvasLayer` 2D tetap setajam resolusi native layar.

#### 2. Preset Kualitas yang Benar-Benar Tersambung ke Kode
Jangan membuat menu pilihan kualitas (*Low / Medium / High / Auto*) yang hanya hiasan! Hubungkan setiap knob ke sistem runtime:
- `resolution_scale`: `0.75–0.85` (Low) s.d. `1.0` (High).
- `shadows`: `false` pada Low & Medium (gantikan dengan bayangan disc/blob datar tanpa shader baru), `true` hanya pada High atau desktop.
- `particle_scale`: pengali jumlah partikel efek (misalnya `0.35` Low, `0.7` Medium, `1.0` High).
- `offscreen_or_background_hz`: batasi frekuensi update visual entitas yang jauh dari kamera / lantai lain (misalnya `2 Hz` di Low, `4 Hz` di Medium) alih-alih disinkronkan `60–120 Hz`.

#### 3. Material, Shader Warmup, & Batas Draw Call
- **JANGAN pernah `Material.new()` / `StandardMaterial3D.new()` di tengah gameplay atau per partikel/efek.** Di Godot GLES3, ketika instance terakhir dari kombinasi fitur shader tertentu dibebaskan, shader-nya ikut dihapus—saat muncul lagi, driver OpenGL ES harus mengompilasi ulang shader tersebut dan menyebabkan **stutter parah (0.2–2 detik macet)**.
- **Batasi jumlah kombinasi fitur shader seminimal mungkin** (idealnya di bawah 10–15 kombinasi shader di seluruh game):
  - Gunakan material bersama (*shared material*).
  - Hindari material **Lit + Transparent** (paling berat & lambat dikompilasi di driver mobile); untuk kaca/aura/overlay transparan, gunakan material **Unshaded**.
- **Shader Warmup di layar loading:** Tampilkan sebentar dummy/daftar material atau mesh efek yang akan dipakai di level/toko selama 1–2 frame di balik layar loading (`LoadingScreen`) sebelum tirai dibuka, dan pegang referensi material tersebut (*MaterialKeep*) sepanjang sesi agar driver tidak mengosongkannya.
- **Mesh Merging & Bake:** Gabungkan objek statis (lantai, dinding, prop statis, bagian muka karakter statis) agar mengurangi *draw call*. **DILARANG memanggil `mesh.surface_get_arrays()` di runtime gameplay** karena memaksa sinkronisasi GPU -> CPU *stall*; simpan array CPU saat generasi awal jika perlu digabung belakangan.

#### 4. Anti-Alokasi GC & Anti-Redraw di Loop Per-Frame (`_process` / `_draw`)
Setiap hal berikut wajib diaudit pada skrip yang berjalan tiap frame:
- **Dirty-Check Transform & Kamera:** Di controller kamera dan billboard/marker 3D, simpan parameter/basis terakhir yang sudah diterapkan. Jika fokus kamera, zoom, ukuran viewport, atau basis kamera tidak berubah, **langsung `return` tanpa menghitung trigonometri maupun menulis `global_transform` / `look_at()`**!
- **Cache Resource Partikel (`Mesh`, `Curve`, `Gradient`, `Texture`):** Bangun resource statis partikel sekali saja dan simpan dalam variabel cache (bersihkan saat keluar scene tree di `_exit_tree()`).
- **Zero-Allocation Loop:** Di dalam fungsi per-frame, hindari membuat `Array`/`Dictionary` sementara, menghindari `Callable.bind(...)` berulang, menghindari closure `Array.sort_custom(func...)`, dan menghindari format string (`"%.1f KR" % val`) jika nilai angkanya belum berubah.
- **Kuantisasi Koordinat Proyeksi 3D -> 2D:** Saat memposisikan label HUD / floating chip di atas objek 3D, bulatkan koordinat ke kelipatan `0.5 px` (`roundf(v * 2.0)`) sebelum memeriksa apakah layout perlu disusun ulang (`_layout()`) dan digambar ulang (`queue_redraw()`).
- **Setter Check pada Custom `CanvasItem`:** Pada control yang menggambar manual di `_draw()`, setter warna/ikon/ukuran **harus mengecek `if prop == value: return`** sebelum memanggil `queue_redraw()` dan mengubah `custom_minimum_size`.
- **Throttle Latar Animasi & Efek Diam:** Animasi latar belakang UI cukup pada `10–15 Hz`, dan wajib berhenti penuh (`return`) saat kontrol tidak terlihat (`not is_visible_in_tree()`) atau saat opsi *Reduced Motion* aktif.
- **Jangan rebuild tombol sentuh saat refresh UI:** Untuk chip/kartu yang diperbarui berkala (misalnya 5×/detik), buat node tombolnya sekali saja lalu perbarui teks/statusnya. Menghapus & membangun ulang tombol akan memutus gestur ketukan jari pemain.

#### 5. Bebas Kebocoran Node & Objek (`Orphan Nodes`)
- Setiap skrip tes UI dan transisi layar wajib memeriksa `Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)` sebelum dan sesudah buka-tutup layar.
- Pastikan seluruh `Tween`, `Timer`, atau sinyal yang dibuat dinamis tidak meninggalkan node terlepas dari `SceneTree` tanpa `queue_free()`/`free()`.

---

### A.5 Platform Mobile: Lifecycle, Atomic Save, Storage, Orientasi, & Keamanan Build

#### 1. Lifecycle Aplikasi Android (Minimize, Pindah App, Kunci Layar)
- Pasang pengelola pause berbasis **daftar alasan** (*reference-counted pause reasons*), bukan boolean tunggal `paused = true/false`, supaya modal A menutup modal B tidak ikut melepaskan status pause sistem.
- Tangani seluruh notifikasi fokus/background di satu tempat (mis. autoload):
  ```gdscript
  func _notification(what: int) -> void:
  	match what:
  		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
  			on_focus_lost()   # Push alasan pause lifecycle + LANGSUNG save_now()!
  		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
  			on_focus_gained() # Lepas alasan pause lifecycle (+ hitung offline progress bila ada)
  ```
- Saat `on_focus_lost()`, **wajib langsung menyimpan progres (`save_now()`)**. Android dapat mematikan proses background kapan saja tanpa mengirim peringatan kedua (LMK / *Low Memory Killer*).

#### 2. Atomic Save Anti-Corrupt
Menulis save langsung menimpa file utama sangat berisiko rusak jika HP kehabisan baterai atau dimatikan OS di tengah penulisan. Wajib terapkan pola 4 langkah:
1. Tulis JSON ke file sementara (`profile.tmp`), cek tidak mengandung `NaN`/`INF`.
2. Tutup file sementara, lalu **baca balik & validasi** struktur skema minimumnya sebelum memercayai file tersebut.
3. Jika file utama lama valid, pindahkan menjadi file cadangan (`profile.bak`) agar file backup bagus tidak pernah tertimpa file utama yang rusak.
4. Rename `profile.tmp` menjadi file utama (`profile.json`).

#### 3. Scoped Storage di Android
- Android modern (Android 10+ / API 29+) membatasi penulisan bebas ke folder sistem seperti `Pictures` tanpa izin/API khusus.
- Arahkan penyimpanan save game, cache audio/thumbnail, dan screenshot internal **ke `user://`** (`ProjectSettings.globalize_path("user://...")`) ketika berjalan di `OS.has_feature("android")` atau `OS.has_feature("ios")`.

#### 4. Orientasi, Safe Area, & Target Sentuh
- Kunci orientasi di `project.godot` (`display/window/handheld/orientation=1` untuk Portrait, atau sesuaikan nilai orientasi di Project Settings Editor untuk Landscape) **dan** pastikan preset export Android tidak mengizinkan rotasi liar jika UI didesain untuk satu orientasi.
- Ukuran target ketuk minimum **`48×48` logical px**; tambahkan margin aman untuk *camera cutout/notch* dan *navigation pill* bawah Android.
- Seluruh aksi gameplay harus dapat dijalankan murni dengan sentuhan (*one-tap/drag*), tanpa bergantung pada tombol keyboard atau klik kanan.

#### 5. Toolchain Godot CLI, Gradle, SDK, & Larangan Keamanan Keystore
- **Gunakan scene (`.tscn`), JANGAN pernah `--script`, untuk tes/validasi/probe:** Mode `--script` di CLI Godot tidak memuat Autoload, sehingga menyebabkan error/false-positive.
- **Di Windows:** Selalu pakai binary konsol (`*_console.exe`) agar stdout/stderr terbaca.
- **Jebakan Editor Settings Windows (`editor_settings-*.tres`):** Editor GUI Godot sering menulis ulang path Android SDK/JDK saat editor ditutup. Sebelum export via CLI, verifikasi `export/android/android_sdk_path` dan `export/android/java_sdk_path` (gunakan versi JDK yang cocok dengan versi Godot 4.x proyek—mis. JDK 17/21 sesuai dokumentasi resmi Godot versi tersebut).
- **Gradle Build & `org.gradle.daemon=false` (Windows):** Untuk export `.aab` Play Store (`gradle_build/use_gradle_build=true`), bila Gradle CLI sering menggantung pada mesin CI/Windows, tambahkan `org.gradle.daemon=false` di `android/build/gradle.properties`.
- **ATURAN KEAMANAN KEYSTORE & GIT (MUTLAK):**
  - **JANGAN PERNAH** menaruh path keystore rilis, alias (`keystore/*_user`), atau password (`keystore/*_password`) di dalam `export_presets.cfg`, skrip GDScript, file konfigurasi, atau commit Git!
  - Simpan keystore rilis (`.keystore`/`.jks`) **di luar folder repositori Git** (dengan salinan backup di tempat aman), lalu isi kredensial hanya saat build menggunakan *environment variables*:
    - `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
    - `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
    - `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`
  - Masukkan folder `build/` dan `android/` ke `.gitignore`, dan **jangan pernah commit file `.apk`/`.aab` ke Git**.

---

## BAGIAN B — YANG HARUS DIKERJAKAN (Langkah Eksekusi Berurut untuk AI)

AI harus menjalankan 6 tahap di bawah secara berurut saat menyiapkan project Godot apa pun menuju rilis Android & Play Store.

---

### Tahap 1 — Audit Awal Repository Target

Sebelum menulis satu baris kode pun, jalankan audit cepat berikut:
1. Periksa `project.godot`: cek renderer (`gl_compatibility`), `import_etc2_astc`, `msaa_3d.mobile`, `quit_on_go_back`, dan orientasi layar.
2. Cari seluruh kemunculan `msaa_3d`, `SubViewport`, `adjustment_enabled`, `AudioStreamWAV`, `add_bus`, `NOTIFICATION_WM_GO_BACK_REQUEST`, dan penulisan file di luar `user://`.
3. Periksa semua loop `_process()` dan `_draw()` yang berat: cari pemanggilan `new()`, `.bind()`, `surface_get_arrays()`, `look_at()`, `queue_redraw()` tanpa kondisi perubahan nilai, dan pembuatan `Material` baru per instance.
4. Periksa `export_presets.cfg`: pastikan ada preset **APK Testing** dan preset **Release AAB**, serta **tidak ada secret keystore yang tersimpan** di dalamnya.

---

### Tahap 2 — Terapkan Pengaman Crash Engine & Audio

1. Set `renderer/rendering_method.mobile="gl_compatibility"`, `textures/vram_compression/import_etc2_astc=true`, dan **`anti_aliasing/quality/msaa_3d.mobile=0`** di `project.godot`.
2. Pastikan skrip manajemen kualitas grafis memaksa `Viewport.MSAA_DISABLED` pada perangkat mobile di baris pertama sebelum membaca preset apa pun.
3. Pastikan **tidak ada** `SubViewport` produksi yang memakai `msaa_3d != 0`.
4. Jika game menggunakan audio prosedural (`AudioStreamWAV` manual): pasang `TAIL_PAD = 16` sampel sesudah `loop_end`/ujung data, pakai `AudioServer.set_bus_count()`, dan rakit musik secara *time-sliced* atau dengan cache disk ber-hash.
5. **Tambahkan tes regresi otomatis** (di test runner proyek) yang memverifikasi:
   - `msaa_3d.mobile == 0` dan getter kualitas mobile mengembalikan `Viewport.MSAA_DISABLED`.
   - Tidak ada crash pada buffer audio prosedural (`TAIL_PAD` terpasang dan cache hash konsisten).

---

### Tahap 3 — Implementasikan Tombol Back Android, Lifecycle, & Save Aman

1. Nonaktifkan `quit_on_go_back` di `project.godot` dan di `_ready()` scene utama.
2. Bangun router `NOTIFICATION_WM_GO_BACK_REQUEST` dengan urutan:
   - abaikan saat loading -> tutup modal/sheet/mode edit teratas -> di luar Web tampilkan `ConfirmDialog` keluar game -> di konfirmasi panggil `save_now()` lalu `get_tree().quit()`.
3. Pastikan `CanvasLayer.layer` untuk dialog konfirmasi **lebih tinggi** dari layer Splash/HUD/Menu Utama.
4. Pastikan splash/menu bawah mengabaikan ketukan saat ada dialog konfirmasi di atasnya dan mengabaikan `KEY_ESCAPE`/`KEY_BACK`.
5. Pasang auto-save sinkron + pause pada `NOTIFICATION_APPLICATION_PAUSED` / `FOCUS_OUT` dengan mekanisme penulisan save atomik (`tmp -> verify -> backup -> rename`).
6. Tambahkan tes otomatis untuk alur Back (dari splash/menu awal, saat modal terbuka, saat error screen, dan saat gameplay aktif).

---

### Tahap 4 — Terapkan & Verifikasi Optimasi "HP Kentang"

1. Hubungkan pengelola Settings / opsi kualitas grafis proyek ke runtime:
   - `scaling_3d_scale <= 0.85` pada mobile *Auto* / *Low*.
   - Pengali jumlah partikel (*particle scale*), toggle bayangan, dan pembatas FPS jika disediakan.
2. Tambahkan **Shader Warmup** pada layar loading + *MaterialKeep* untuk seluruh material yang dipakai selama gameplay, dan cek jumlah kombinasi shader agar tetap sekecil mungkin.
3. Hilangkan alokasi per-frame dan redraw/transform update berulang di controller kamera, billboard, partikel, ikon, serta HUD.
4. Lakukan audit `OBJECT_ORPHAN_NODE_COUNT`: buka-tutup setiap modal/layar berkali-kali lewat tes otomatis atau skrip probe dan pastikan jumlah orphan node **tidak bertambah terus**.

---

### Tahap 5 — Konfigurasi Build Android, Signing, & Uji Perangkat Fisik (ADB)

1. **Siapkan Android Build Preset di `export_presets.cfg`:**
   - **Preset Uji APK** (untuk install cepat via USB/emulator):
     - Bisa tanpa Gradle atau dengan Gradle, arsitektur `armeabi-v7a=true`, `arm64-v8a=true`, (`x86_64=true` hanya jika perlu uji di emulator x86_64 PC), seluruh kolom `keystore/*=""` (dikosongkan di file!).
   - **Preset Rilis Play Store AAB:**
     - `gradle_build/use_gradle_build=true`, `gradle_build/export_format=1` (`.aab`).
     - `architectures/armeabi-v7a=true`, `architectures/arm64-v8a=true`, `architectures/x86_64=false`, `architectures/x86=false`.
     - `gradle_build/min_sdk="24"` (atau sesuai kebutuhan minimal proyek) dan `gradle_build/target_sdk` sesuai persyaratan Google Play Console terbaru (mis. `35` ke atas).
     - Kolom `keystore/*=""` **wajib kosong** di `export_presets.cfg`.
2. **Buat Release Keystore Eksternal (sekali seumur hidup aplikasi):**
   - Buat dengan `keytool` (`-validity 10000` agar berlaku > 25 tahun, jauh melewati syarat minimal 2033 Play Store), simpan file `.keystore` dan catatan kredensialnya **di luar repo Git** serta **wajib dibackup**.
   - **Peringatan:** Kehilangan release keystore berarti selamanya tidak bisa mengunggah update aplikasi dengan *package name* tersebut ke Google Play!
3. **Verifikasi di Perangkat Nyata & Emulator (`10+ menit`):**
   - Install APK rilis/uji via ADB (`adb install -r ...`).
   - Mainkan skenario terberat (efek penuh, banyak entitas, transisi layar, minimize lalu resume, tekan tombol Back di berbagai state).
   - Catat nilai `Native Heap` dan `GL mtrack` lewat `dumpsys meminfo` pada menit 1, menit 5, dan menit 10: harus stabil tanpa tren naik konstan.
   - Cek `dumpsys dropbox --print data_app_native_crash`, `data_app_anr`, dan `data_app_crash` — harus kosong dari error aplikasi Anda.

---

### Tahap 6 — Persiapan Final Rilis Google Play Store

1. **Verifikasi Identitas & Versi Paket:**
   - `package/unique_name` unik (format domain terbalik, mis. `com.studio.namagame`) dan konsisten selamanya.
   - **Setiap upload `.aab` baru ke Play Console (Internal/Closed/Production), naikkan `version/code` (`+1`) dan perbarui `version/name`.**
2. **Izin Android (`AndroidManifest` / `export_presets.cfg`):**
   - Minta hanya izin yang benar-benar digunakan!
   - Jika game sepenuhnya offline tanpa iklan/server: pastikan `permissions/internet=false`.
   - Aktifkan `permissions/vibrate=true` hanya jika game memakai `Input.vibrate_handheld()`.
3. **Monetisasi & SDK Pihak Ketiga (Bila Game Memakai Iklan / IAP):**
   - Pasang plugin Android resmi (**AdMob** / mediasi iklan dan **Google Play Billing**).
   - Nyalakan `permissions/internet=true` (dan izin jaringan SDK terkait) **hanya setelah plugin terpasang**.
   - Pastikan gameplay tetap aman/tidak crash jika perangkat offline atau iklan gagal dimuat.
   - Terapkan dialog persetujuan privasi (**UMP / GDPR**) bila diwajibkan regulasi wilayah target.
4. **Kepatuhan Halaman Play Console:**
   - Sediakan **URL Kebijakan Privasi (*Privacy Policy*)** yang bisa diakses publik.
   - Isi formulir **Data Safety** (sesuaikan dengan SDK iklan/billing jika dipakai) dan **Content Rating**.
   - Siapkan aset listing Play Store (ikon 512×512, feature graphic 1024×500, screenshot portrait/landscape dari perangkat/render resolusi tinggi).
5. **Uji Jalur Tertutup Terlebih Dahulu:**
   - Upload `.aab` ke jalur **Internal Testing** di Google Play Console terlebih dahulu, download melalui Google Play Store di HP uji untuk memverifikasi *Play App Signing*, pembelian/iklan uji (jika ada), dan stabilitas akhir sebelum menekan rilis **Production**.

---

## BAGIAN C — Cookbook Perintah Siap Pakai

Ganti variabel di bagian atas sesuai mesin dan proyek tempat Anda bekerja.

### C.1 Windows PowerShell: Build & Uji Godot

```powershell
# Sesuaikan path di bawah ini dengan project dan mesin target
$GODOT = "D:\path\to\Godot_v4.x_console.exe"   # WAJIB binary *_console.exe di Windows
$PACKAGE_ID = "com.example.mygame"
$KEYSTORE_PATH = "C:/Users/$env:USERNAME/AppData/Roaming/Godot/keystores/release.keystore"

# 1. Reimport setelah menambah class_name baru
& $GODOT --headless --path . --import

# 2. Jalankan test runner / script tool proyek sebagai SCENE (.tscn), JANGAN --script
& $GODOT --headless --path . res://<PATH_COMPILE_OR_TEST_SCENE>.tscn

# 3. Export APK Rilis & AAB Play Store (signing lewat env var, BUKAN di export_presets.cfg)
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $KEYSTORE_PATH
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "<ALIAS_KEYSTORE>"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "<PASSWORD_KEYSTORE>"

New-Item -ItemType Directory -Force -Path "build/android" | Out-Null
& $GODOT --headless --path . --export-release "<NAMA_PRESET_APK>" "build/android/app-release.apk"
& $GODOT --headless --path . --export-release "<NAMA_PRESET_AAB>" "build/android/app-release.aab"

# 4. Verifikasi tanda tangan digital APK / AAB (opsional bila apksigner/jarsigner ada)
apksigner verify --verbose "build/android/app-release.apk"
jarsigner -verify -certs "build/android/app-release.aab"
```

### C.2 Linux / macOS Bash: Build & Uji Godot

```bash
GODOT="/path/to/godot"
PACKAGE_ID="com.example.mygame"

"$GODOT" --headless --path . --import
"$GODOT" --headless --path . res://<PATH_TEST_SCENE>.tscn

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/.local/share/godot/keystores/release.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="<ALIAS_KEYSTORE>"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="<PASSWORD_KEYSTORE>"

mkdir -p build/android
"$GODOT" --headless --path . --export-release "<NAMA_PRESET_APK>" "build/android/app-release.apk"
"$GODOT" --headless --path . --export-release "<NAMA_PRESET_AAB>" "build/android/app-release.aab"
```

### C.3 Playbook ADB (Install, Memori, & Forensik Crash HP)

```bash
# 1. Pastikan perangkat terdeteksi
adb start-server
adb devices
# Jika device berstatus 'offline', pulihkan dulu:
adb reconnect offline

# 2. Install APK di atas versi lama (data save tetap aman selama signature keystore sama)
adb install -r build/android/app-release.apk

# 3. Cari activity launcher resmi (jangan pakai monkey karena sering gagal di Godot) lalu jalankan
adb shell cmd package resolve-activity --brief "$PACKAGE_ID"
adb shell am force-stop "$PACKAGE_ID"
adb shell am start -n "$PACKAGE_ID/com.godot.game.GodotAppLauncher"

# 4. Pantau konsumsi memori langsung saat gameplay (amati Native Heap & GL mtrack — harus datar!)
adb shell dumpsys meminfo "$PACKAGE_ID"

# 5. Investigasi crash atau freeze (ANR) yang SUDAH terjadi sebelumnya di HP
adb shell dumpsys dropbox --print data_app_native_crash
adb shell dumpsys dropbox --print data_app_anr
adb shell dumpsys dropbox --print data_app_crash

# 6. Pantau log live Godot, Scudo allocator, dan tombstone native crash
adb logcat -s godot:* DEBUG:* libc:* Scudo:*
```

*(Catatan: jika HP memiliki lebih dari satu perangkat terhubung, tambahkan flag `-s <SERIAL_DEVICE>` pada setiap perintah `adb` di atas).*

---

## BAGIAN D — Checklist "Definition of Done" Universal Sebelum Rilis Android

AI atau developer **tidak boleh** menyatakan tugas Android selesai sebelum seluruh poin berikut terverifikasi:

### Stabilitas & Crash Engine
- [ ] `anti_aliasing/quality/msaa_3d.mobile=0` di `project.godot`, dan fungsi kualitas di skrip memaksa `Viewport.MSAA_DISABLED` untuk semua perangkat mobile.
- [ ] Tidak ada `SubViewport` yang ikut ter-export ke Android dengan `msaa_3d != MSAA_DISABLED`.
- [ ] Seluruh `AudioStreamWAV` buatan skrip memiliki tail padding (`>= 16` sampel sesudah `loop_end`/ujung data) dan memakai `AudioServer.set_bus_count()` (bukan `add_bus()`).

### UX Mobile, Back, Lifecycle, & Save
- [ ] `quit_on_go_back=false`; menekan Back menutup modal/sheet teratas lebih dulu, lalu menampilkan dialog konfirmasi keluar di layer atas (`CanvasLayer` modal/dialog > `CanvasLayer` Splash/Menu), dan menyimpan data sebelum `quit()`.
- [ ] Kehilangan fokus/minimize aplikasi otomatis mem-pause simulasi dan langsung menulis save secara atomik (`tmp -> verify -> backup -> rename`).
- [ ] Seluruh penulisan file runtime di Android memakai `user://` (aman terhadap *Android Scoped Storage*).
- [ ] Orientasi terkunci sesuai desain dan tombol/elemen sentuh mudah ditekan (`>= 48×48` logical px) dengan margin safe-area.

### Performa HP Spek Rendah
- [ ] Game 3D menerapkan penurunan skala render 3D (`scaling_3d_scale <= 0.85` pada preset *Auto*/*Low* mobile) tanpa menurunkan ketajaman UI 2D.
- [ ] Material dibagi pakai ulang, jumlah kombinasi shader minimal, dan material/efek berat sudah dipanaskan (*Shader Warmup*) di balik layar loading.
- [ ] Loop `_process()` dan `_draw()` memiliki *dirty check*, bebas alokasi sampah per frame, dan jumlah `OBJECT_ORPHAN_NODE_COUNT` tidak bocor.

### Build, Keamanan, & Play Store
- [ ] `export_presets.cfg`, skrip, dan riwayat Git **100% bersih** dari path/alias/password keystore maupun file biner `.apk`/`.aab`.
- [ ] Release keystore disimpan dan di-backup di luar repositori Git; export CLI memakai environment variable.
- [ ] Untuk rilis Play Store: `.aab` diekspor via Gradle (`arm64-v8a` + `armeabi-v7a`), `minSdk`/`targetSdk` sesuai kebijakan Google Play terbaru, `version/code` dinaikkan, izin & kebijakan privasi sesuai SDK yang terpasang.
- [ ] Pengujian langsung di HP fisik (atau emulator) minimal `5–10 menit` menghasilkan *Native Heap* stabil tanpa tren naik dan `dumpsys dropbox` bersih dari `native_crash` / `anr`.
