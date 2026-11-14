# Panduan Visual 3D dan Kamera (gaya Crumbtown)

Dokumen ini menjelaskan bentuk objek 3D, material, cahaya, dan kamera **Crumbtown: Idle Bakery Tycoon**, supaya game lain bisa dibuat dengan tampilan yang sama. Semua angka diambil dari kode Crumbtown (Godot 4.7, renderer Compatibility) per 2026-11-14.

**Untuk AI yang membaca dokumen ini:** perlakukan setiap aturan bertanda **HARUS** atau **JANGAN** sebagai syarat. Angka adalah nilai yang dipakai, bukan contoh. Satuan dunia adalah meter, sudut dalam derajat, warna dalam hex sRGB. Bila game baru butuh sesuatu yang tidak tercakup di sini, turunkan dari prinsip di Bagian 1 dan tanyakan dulu ke pemilik proyek bila ragu.

---

## 0. Ringkasan cepat (untuk ditempel ke instruksi AI)

```yaml
style: "Warm, Cozy & Cute" - diorama mini low-poly, bulat empuk, warna solid hangat, tanpa tekstur
engine: Godot 4.x, renderer gl_compatibility (WebGL2 / Android kelas bawah)
camera:
  projection: orthographic
  yaw_deg: 45          # mengelilingi sumbu Y dunia
  pitch_deg: 35        # menunduk dari horizontal
  roll_deg: 0
  rotation: dikunci selama bermain
  keep_aspect: KEEP_WIDTH   # camera.size = LEBAR dunia yang terlihat
  visible_width_m: 6.8      # bawaan; zoom 5.6 .. 11.0, langkah 0.6
  distance_m: 30            # tidak berpengaruh ke ukuran (ortografis), cukup jauh dari objek
  near_far: [0.05, 200]
  views_from: sudut depan-kiri ruangan (-X, -Z) memandang ke (+X, +Z)
world:
  tile_m: 0.5               # 1 ubin = 0,5 x 0,5 m
  character_height_m: 0.90  # chibi
  counter_top_m: 0.42       # meja tempat orang berdiri melayani, di bawah garis dada 0,44
  wall_height_m: [1.80, 2.00, 2.05, 2.30, 2.50]   # per tier bangunan
  near_walls: rendah 0.16 m (dinding depan z=0 dan kiri x=0), dinding jauh setinggi penuh
mesh:
  build_from: BoxMesh, CylinderMesh, SphereMesh, TorusMesh, CapsuleMesh, SurfaceTool (rounded slab, lathe)
  tris_per_object: 500..2000
  segments: {sphere: 12x6, cylinder: 10, capsule: 10x4, torus: 12x8, lathe: <=32}
  textures: tidak ada (pola dari geometri dan warna verteks)
material:
  type: StandardMaterial3D, per-pixel, diffuse Lambert, specular SchlickGGX
  roughness: 0.85 (bola/kapsul 0.9), metallic 0 (logam: sedang, tetap kasar)
  vertex_color_use_as_albedo: true (sRGB)
  extras: semua fitur mahal mati; emisi hanya untuk benda yang memang menyala
lighting:
  background: "#F5E6CA" (warna polos)
  ambient: "#FFE3A8" x 0.55
  tonemap: Filmic, white 1.2
  sun: DirectionalLight "#FFE3A8" x 0.95, rotation_deg (-52, -135, 0), shadow OFF
  interior_lamps: OmniLight "#FFAA44" x 0.55, 1 lampu per 9 m2 lantai, range max(3, 0.6 x sisi terpanjang), shadow OFF
  shadows: palsu (cakram gelap transparan di lantai), tanpa shadow map, tanpa SSAO/glow/fog
  msaa_3d: 4x desktop, 2x ponsel
```

---

## 1. Prinsip gaya

1. **Diorama mini yang hangat.** Dunia tampak seperti rumah boneka kecil yang dilihat dari atas sudut: dinding yang dekat kamera dipotong rendah supaya isi ruangan terbaca.
2. **Bulat dan empuk seperti adonan roti.** Bentuk dasar dibulatkan atau dipangkas tepinya; tidak ada sudut tajam yang mencolok. Karakter chibi berkepala besar.
3. **Warna solid hangat, tanpa tekstur gambar.** Setiap bagian punya satu warna. Pola (kotak-kotak, garis, ubin) dibuat dari geometri atau warna verteks, bukan file gambar.
4. **Cahaya keemasan dan lembut.** Tidak ada cahaya neon dingin, bayangan tajam, atau efek layar penuh. Bayangan cukup berupa cakram gelap lembut di lantai.
5. **Low-poly yang rapi.** Jumlah segmen sengaja rendah (bola 12 sisi). Siluet harus terbaca di ukuran layar ponsel, bukan detail kecil.
6. **Semuanya dibuat lewat kode.** JANGAN impor .png, .jpg, .gltf, .fbx, atau .obj. Model dibangun parametrik, jadi satu fungsi bisa menghasilkan varian murah sampai mewah (lihat Bagian 8).

---

## 2. Kamera

### 2.1 Profil kamera (HARUS)

| Properti | Nilai |
|---|---|
| Proyeksi | Ortografis |
| Yaw (mengelilingi sumbu Y) | 45° |
| Pitch (menunduk) | 35° |
| Roll | 0° |
| Rotasi | Dikunci; pemain tidak bisa memutar kamera |
| `keep_aspect` | `KEEP_WIDTH`: `camera.size` adalah lebar dunia yang terlihat, sama di semua ponsel. Layar yang lebih tinggi hanya melihat lebih banyak di atas dan bawah |
| Lebar terlihat bawaan | 6,8 m (zoom 5,6 sampai 11,0 m, langkah 0,6 m) |
| Jarak kamera ke titik fokus | 30 m (pada kamera ortografis jarak tidak mengubah ukuran, hanya harus cukup jauh supaya tidak memotong objek) |
| Near / far | 0,05 / 200 m |

Catatan: pitch 35° **bukan** isometrik piksel-art 2:1 (itu pitch 30°). Satu ubin persegi tampil sebagai belah ketupat dengan rasio lebar : tinggi sekitar 1,74 : 1.

### 2.2 Rumus posisi kamera

```
offset = ( -sin(yaw) * cos(pitch),  sin(pitch),  -cos(yaw) * cos(pitch) ) * 30
camera.position = focus + offset
camera.look_at(focus, UP)
```

Dengan yaw 45° dan pitch 35°: `offset = (-0.579, 0.574, -0.579) * 30`. Kamera berada di sisi **-X, -Z** dari titik fokus dan memandang ke **+X, +Z** sambil menunduk.

Arah dunia di layar:

- Sumbu dunia **+X** mengarah ke **kiri-atas** layar.
- Sumbu dunia **+Z** mengarah ke **kanan-atas** layar.
- Arah kanan layar = dunia (-X, +Z) dinormalisasi.
- Titik (0, 0, 0) sebuah ruangan yang dimulai di sudut asal adalah sudut **paling bawah** di layar (paling dekat kamera).

### 2.3 Ukuran di layar (bingkai potret 720 × 1280 piksel logis)

- Skala: 720 / 6,8 = **105,9 piksel per meter** horizontal.
- Benda tegak memendek dengan faktor cos 35° = 0,819. Karakter 0,90 m tampil sekitar **78 piksel** tingginya (target GDD: 72 sampai 92 piksel).
- Satu ubin 0,5 m tampil sebagai belah ketupat sekitar **75 × 43 piksel**.
- Lantai memendek dengan faktor sin 35° = 0,574 ke arah dalam.

### 2.4 Pembingkaian

- Titik fokus digeser supaya ruangan berada di tengah ruang **di antara bar HUD**, bukan di tengah layar. Di Crumbtown HUD atas 130 piksel dan bawah 170 piksel, jadi kamera turun `(170 - 130) / 2 = 20` piksel (dikonversi ke meter dengan `ortho_size / lebar_viewport`) di sepanjang sumbu Y lokal kamera.
- Ruangan yang muat di layar dibingkai utuh dari titik tengah lantainya dan tidak bergerak.
- Ruangan yang lebih besar dari layar mengikuti karakter pemain dengan pelunakan `lerp(focus, target, min(1, delta * 6))` dan boleh digeser dengan seret. Geseran kembali ke karakter sesudah 2,5 detik tanpa sentuhan.
- Pindah lantai memakai crossfade 0,20 detik ke warna latar, bukan gerakan kamera.
- JANGAN memindahkan kamera untuk kejadian rutin. Sorotan lembut sementara boleh untuk momen penting, dan dimatikan bila Reduced Motion aktif.
- Tap di layar dipetakan ke lantai dengan ray dari kamera ke bidang y = 0 (`project_ray_origin` dan `project_ray_normal`).

### 2.5 Kode Godot 4

```gdscript
const YAW_DEG := 45.0
const PITCH_DEG := 35.0
const WIDTH_M := 6.8

func make_camera(parent: Node3D) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = WIDTH_M
	cam.near = 0.05
	cam.far = 200.0
	parent.add_child(cam)
	cam.current = true
	return cam

func aim(cam: Camera3D, focus: Vector3) -> void:
	var yaw := deg_to_rad(YAW_DEG)
	var pitch := deg_to_rad(PITCH_DEG)
	var offset := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * 30.0
	cam.global_position = focus + offset
	cam.look_at(focus, Vector3.UP)
```

Engine lain: pakai kamera ortografis yang sama, posisikan dengan rumus 2.2, dan atur ukuran ortografis berdasarkan **lebar** (Unity `orthographicSize` adalah setengah **tinggi**, jadi `orthographicSize = (6.8 / aspect) / 2`).

---

## 3. Skala dunia dan grid

- **1 ubin = 0,5 m × 0,5 m.** Posisi gameplay disimpan dalam ubin bilangan bulat; meter hanya dipakai saat membangun dunia 3D.
- Ubin (x, z) menempati `[x * 0.5, (x + 1) * 0.5]` di X dan `[z * 0.5, (z + 1) * 0.5]` di Z. Pusat ubin = `((x + 0.5) * 0.5, (z + 0.5) * 0.5)`.
- Jangkar perabot ada di sudut kiri-bawah footprint-nya. Pada rotasi 90° dan 270° lebar dan dalam footprint ditukar.
- Ukuran ruangan contoh: garasi kecil 6 × 12 ubin (3 × 6 m), toko besar 16 × 16 dan 20 × 20 ubin.
- **Semua ukuran diikat ke karakter chibi 0,90 m.** Meja tempat orang berdiri melayani (meja kasir) HARUS di bawah garis dada karakter 0,44 m (permukaan 0,42 m), supaya orang di baliknya tidak tenggelam.

---

## 4. Bahasa bentuk dan konstruksi mesh

### 4.1 Primitif dan anggaran

| Primitif | Pengaturan | Kira-kira segitiga |
|---|---|---|
| Box | tanpa subdivisi | 12 |
| Cylinder / kerucut | 10 segmen radial, 1 ring | ~40 |
| Sphere | 12 segmen radial × 6 ring | ~144 |
| Torus | 12 ring × 8 segmen | ~192 |
| Capsule | 10 segmen radial × 4 ring | ~160 |
| Rounded slab (balok bertepi pangkas) | 6 sisi + 12 pita rusuk + 8 sudut | 44 |
| Lathe (profil diputar) | 3 sampai 32 segmen | segmen × (titik profil - 1) × 2 |

- Anggaran: **500 sampai 2.000 segitiga per objek rakitan.** JANGAN memakai jumlah segmen bawaan engine (Godot: bola 64 × 32), itu terlalu mahal untuk ponsel kelas bawah.
- **Rounded slab** adalah balok dengan 12 rusuk dipangkas sebesar `bevel` (dibatasi 90% setengah dimensi terkecil). Sisi utamanya tetap rata, sedangkan pita rusuk dan sudutnya dihaluskan bersama sehingga tepinya tampak lembut. Ini tulang punggung perabot, meja, dan roti.
- **Lathe** memutar profil 2D (x = jari-jari, y = tinggi, urut dari bawah ke atas) mengelilingi sumbu Y. Dipakai untuk mangkuk, kubah, lonceng, dan badan karakter. Lipatan profil di bawah 40° dihaluskan; di atasnya dibiarkan patah supaya tepinya tegas.
- Benda bundar (kepala, roti bulat, kenop) memakai bola; batang (kaki meja, baguette) memakai silinder; badan dan lengan memakai kapsul atau lathe.

### 4.2 Aturan bentuk

1. Bentuk dasar sederhana dan sedikit dilebih-lebihkan: tebal, montok, proporsi mainan.
2. Tepi dipangkas atau dibulatkan; hindari lembaran setipis kertas kecuali kaca atau kain.
3. Detail kecil (kenop, paku, pegangan) boleh ada, tetapi siluet utama HARUS terbaca dari jarak kamera bawaan.
4. Pola dibuat dari geometri: tirai dan kanopi kotak-kotak memakai bidang papan catur dengan dua warna verteks, ubin lantai memakai kotak-kotak berwarna.
5. Tulisan di dunia (papan nama) memakai Label3D dengan font bawaan dan garis tepi, bukan tekstur.
6. Setiap model punya satu sisi depan yang tetap. Di Crumbtown karakter menghadap -Z lokal, dan perabot dirakit menghadap +Z lokal lalu diputar ke arah hadapnya saat dipasang (`rotation.y = atan2(arah.x, arah.y)`).
7. Perabot diskalakan seragam supaya muat di footprint-nya dikurangi 0,06 m (0,03 m tiap sisi), dan tingginya paling banyak 1,2 × tinggi nominalnya.

### 4.3 Menggabung mesh statis (MeshBake)

Model yang terdiri dari belasan primitif digabung menjadi **satu mesh berwarna verteks** per material sebelum dipakai di dunia. Warna tiap bagian disimpan di warna verteks, dan material memakai warna verteks sebagai albedo. Bagian yang bergerak (pintu oven, pengaduk, anggota tubuh karakter) dibiarkan sebagai node terpisah dengan pivot di sendinya. Model yang sama dibuat sekali lalu dipakai ulang (cache prototipe).

---

## 5. Material dan warna

### 5.1 Material standar (HARUS)

```gdscript
static func material(color: Color, rough := 0.85, metal := 0.0, emis := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.5
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.emission_enabled = emis != Color.BLACK
	if m.emission_enabled:
		m.emission = emis
	return m
```

- Roughness 0,85 untuk hampir semua permukaan; bola dan kapsul 0,9. Logam (krom, tembaga) memakai metallic sedang dengan roughness tetap lembut.
- JANGAN memakai normal map, rim, clearcoat, SSS, refraksi, AO map, atau tekstur apa pun.
- Emisi hanya untuk benda yang memang bercahaya: bara oven, lampu penghangat etalase (`#FFAA44`), lampu jalan malam.
- Kaca tipis memakai material **unshaded** transparan. JANGAN memakai material transparan yang menerima cahaya: di browser itu shader paling lambat dikompilasi.
- Batasi jumlah kombinasi fitur material (Crumbtown: paling banyak 12). Material dibagi pakai, jangan dibuat baru setiap kali objek muncul.

### 5.2 Palet

Warna diambil dari satu sumber palet. Lingkungan luar (jalan, rumah tetangga) sedikit diredam supaya bangunan utama tetap jadi pusat perhatian.

| Peran | Hex |
|---|---|
| Cahaya matahari keemasan, ambient | `#FFE3A8` |
| Lampu penghangat interior | `#FFAA44` |
| Latar layar / krem vanila | `#F5E6CA` |
| Putih tepung (kain, celemek) | `#FFFBF5` |
| Kerak roti keemasan | `#D9822B` |
| Karamel | `#8C4A1E` |
| Cokelat gelap (garis, kayu tua) | `#5A2E12` |
| Kuning mentega | `#FCE38A` |
| Custard | `#F9D371` |
| Kayu pinus berpelitur | `#C99A62` |
| Ubin terakota | `#C4693D` |
| Stroberi pastel | `#FFB7B2` |
| Mint pastel | `#B5EAD7` |
| Lavender / periwinkle pastel | `#C7CEEA` |
| Pipi merona karakter | `#FF9AA2` |
| Emas aksen | `#F5B301` |
| Bayangan palsu | `rgba(75, 45, 27, 0.30)` |

Aturan warna:

- Nada keseluruhan hangat. Biru dan hijau hanya sebagai pastel lembut atau aksen kecil.
- Kontras dibangun dari terang-gelap, bukan hanya beda warna, supaya status tetap terbaca oleh penderita buta warna.
- Status kematangan atau perubahan bertahap memakai gradasi warna dengan beda terang yang jelas, misalnya adonan mentah `#EFE0B0`, matang `#D9822B`, gosong `#1A1208`.

---

## 6. Cahaya dan lingkungan

### 6.1 Pengaturan bawaan (suasana sore)

```gdscript
func make_environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("F5E6CA")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("FFE3A8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	return we

func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("FFE3A8")
	sun.light_energy = 0.95
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-52.0, -135.0, 0.0)
	return sun
```

- Matahari dengan rotasi (-52°, -135°, 0°) menyinari ke arah +X, +Z sambil turun, **searah dengan pandangan kamera**. Sisi benda yang menghadap kamera selalu terang dan mudah dibaca.
- Lampu interior: OmniLight `#FFAA44`, energi 0,55, satu lampu per 9 m² lantai (minimal satu), jangkauan `max(3, 0.6 × sisi ruangan terpanjang)`, digantung di 0,9 × tinggi dinding, tanpa bayangan.
- **Tanpa shadow map, SSAO, glow, atau fog.** Target render adalah WebGL2 dan ponsel kelas bawah; efek layar penuh adalah hal pertama yang membuat frame turun.
- MSAA 3D: 4× di desktop, 2× di ponsel. Elemen 2D digambar dengan antialiasing sendiri (renderer Compatibility tidak punya MSAA 2D).

### 6.2 Bayangan palsu

- Di bawah karakter: cakram (disc) 14 segmen, jari-jari 0,20 m (lebih besar untuk karakter gemuk), warna `rgba(75, 45, 27, 0.30)` di tengah yang memudar ke alfa 0 di tepi, setinggi 0,004 m di atas lantai, material unshaded transparan.
- Di bawah perabot: cakram yang sama, 24 segmen, alfa tengah 0,42, diskalakan 1,5 × footprint perabot, setinggi 0,006 m.

### 6.3 Siklus siang-malam (opsional)

Hanya warna, energi, dan sudut cahaya yang berubah; material tetap, jadi tidak ada shader baru. Arah horizontal matahari tetap -135°; elevasinya berubah.

| Jam | Matahari (warna, energi, elevasi) | Ambient (warna, energi) | Lampu interior | Latar |
|---|---|---|---|---|
| 05:00 | `#FFB98A` 0,34, 24° | `#E8C3BD` 0,46 | 0,95 | `#E3CDBB` |
| 08:00 | `#FFECD0` 0,92, 48° | `#FCEAD2` 0,56 | 0,55 | `#F6E8CF` |
| 12:00 | `#FFEED4` 0,97, 58° | `#FFECD2` 0,57 | 0,50 | `#F7E9D0` |
| 15:00 | `#FFE3A8` 0,95, 52° | `#FFE3A8` 0,55 | 0,55 | `#F5E6CA` |
| 17:36 | `#FFB276` 0,64, 28° | `#F4C9A8` 0,48 | 0,80 | `#E9CDB2` |
| 18:00 | `#F89C74` 0,44, 20° | `#DCB6B3` 0,45 | 0,95 | `#DCC0B0` |

Di antara titik kunci nilainya diinterpolasi dengan smoothstep. Hujan: matahari × 0,55, ambient × 1,12, lampu × 1,2, dan semua warna dicampur 50% dengan `#E6DDD2`.

---

## 7. Ruangan dan bangunan

- **Potongan rumah boneka:** dinding yang dekat kamera, yaitu dinding depan (z = 0) dan kiri (x = 0), dibangun rendah **0,16 m**. Dinding jauh (belakang dan kanan) setinggi penuh dengan jendela bertirai kotak-kotak pastel.
- Tebal dinding 0,10 m. Sekat rendah antar-zona 0,62 m.
- Tinggi dinding naik sesuai kelas bangunan: 1,80 / 2,00 / 2,05 / 2,30 / 2,50 m.
- Lebar jendela 0,78 m, pusatnya di 0,55 × tinggi dinding.
- Lantai memakai ubin berwarna dengan pola per kelas bangunan (terakota, papan, kotak-kotak). Garis batas zona digambar sebagai pita tipis di lantai.
- Papan nama toko berada di atas pintu dengan kanopi kotak-kotak di atasnya. Sudut kanopi dipilih supaya, dari kamera yaw 45° dan pitch 35°, tepi bawahnya jatuh tepat di atas papan dan tidak pernah menutupi tulisan. Setiap elemen di depan bangunan HARUS dicek dari sudut kamera ini.
- Lingkungan luar (jalan, trotoar, rumah tetangga, pohon, kendaraan mainan) memakai bentuk dan aturan material yang sama, dengan warna sedikit lebih redup.

---

## 8. Perabot dan properti

### 8.1 Ukuran acuan (footprint dalam ubin, tinggi dalam meter)

| Objek | Footprint | Tinggi |
|---|---|---|
| Mixer (kelas 1 sampai 5) | 1×1 → 2×1 | 0,75 → 1,30 |
| Oven | 1×1 → 3×1 | 0,90 → 1,60 |
| Rak etalase | 2×1 → 2×2 | 0,85 → 1,15 |
| Lemari / kulkas | 2×1 → 5×1 | 1,40 → 2,00 |
| Meja penampung | 2×1 | 0,62 |
| Kursi | 1×1 | 0,55 |
| Meja kasir | 2×1 | 0,42 |

### 8.2 Varian parametrik per kelas

Satu fungsi pembuat menerima parameter kelas (tier) dan mengubah material, jumlah bagian, dan proporsi, bukan memuat model lain:

- Kelas 1: kayu pinus dan timah tua, manual, sederhana.
- Kelas 3: baja dan enamel karamel.
- Kelas 5: krom otomatis dengan aksen pastel yang menyala.

### 8.3 Penanda di atas objek

Gelembung tanda seru dan bar progres di atas perabot dibuat dari mesh tipis unshaded. Seluruh grup penanda diputar sekaligus menghadap kamera. JANGAN membuat billboard per lapisan: isi bar akan melenceng dari alurnya.

---

## 9. Karakter chibi

### 9.1 Proporsi (pada tinggi 0,90 m)

| Bagian | Nilai |
|---|---|
| Kepala | ~42% tinggi; elipsoid dengan jari-jari 0,205 × 0,19 × 0,196 m |
| Torso | ~30% |
| Kaki | ~28%; panjang 0,17 m, jari-jari 0,058 m |
| Pinggul | y = 0,25 m, kaki di x = ±0,066 m |
| Leher | y = 0,515 m |
| Bahu / garis dada | y = 0,44 m, x = ±0,142 m |
| Lengan | panjang 0,15 m, jari-jari 0,046 m |
| Garis mata | ~45% tinggi kepala dari dagu (mata besar sedikit di bawah tengah kepala) |

- Mata manik besar gelap, alis kecil, mulut sederhana, dan pipi merona `#FF9AA2`. Ekspresi diganti dengan membentuk ulang mata, alis, dan mulut.
- Poni HARUS berakhir di atas alis, dan tepi topi di atas poni, supaya ekspresi selalu terbaca.
- Tangan dan kaki berupa bentuk bulat; tidak ada jari realistis.
- Torso adalah lathe dari profil pinggul bulat, perut empuk, bahu landai, dan leher pendek. Batas warna (celana, sabuk, baju, leher) dibuat dari pasangan titik profil yang hampir sama sehingga garis warnanya tegas.

### 9.2 Struktur (tanpa skeleton)

```
Character
  Body   (pivot pinggul)  BodyMesh, Apron, ArmL, ArmR (pivot bahu)
  Head   (pivot leher)    HeadMesh (kepala, telinga, pipi, rambut, topi), Face (EyeL, EyeR, BrowL, BrowR, Mouth)
  LegL, LegR (pivot pinggul)
  CarryAnchor             tempat barang yang dibawa
  ShadowBlob              bayangan palsu
```

Semua bentuk statis tiap segmen dijahit jadi satu mesh berwarna verteks: sekitar 12 draw call per karakter, 500 sampai 2.000 segitiga. Karakter menghadap -Z lokal. Variasi (rambut, topi, baju, warna kulit, gemuk/kurus, tinggi) adalah parameter satu fungsi pembuat yang sama.

---

## 10. Animasi prosedural

Tanpa rig dan tanpa file animasi. Gerak dihitung dari gelombang sinus setiap frame, dan reaksi memakai Tween squash & stretch.

| Parameter jalan | Nilai |
|---|---|
| Panjang langkah | 0,7 m; irama = kecepatan di layar / panjang langkah, dibatasi 1,6 sampai 3,6 langkah per detik |
| Ayunan kaki | 0,60 rad |
| Ayunan lengan | 0,45 rad, tertinggal 0,28 rad dari kaki |
| Pantulan badan | 0,022 m, kurva kosinus (tertinggi saat kaki lurus di bawah badan) |
| Anggukan kepala | 0,05 rad; miring kiri-kanan 0,045 rad |
| Goyangan badan | 0,035 rad; celemek 0,032 rad, tertinggal 0,6 rad |
| Peralihan diam dan jalan | sekitar 0,2 detik |

| Parameter diam | Nilai |
|---|---|
| Napas | 1,35 rad/s (sekitar 13 napas per menit) |
| Naik-turun badan | 0,012 m |
| Ayunan lengan santai | 0,05 rad |

Reaksi (senang, ditekan, dibeli) memakai squash & stretch yang kembali ke ukuran semula dengan easing yang sedikit melewati batas (TRANS_BACK), supaya terasa kenyal seperti adonan. Semua gerak yang besar dimatikan bila pemain memilih Reduced Motion.

---

## 11. Performa (target: browser dan ponsel kelas bawah)

- Renderer Compatibility (OpenGL ES 3 / WebGL2).
- Satu objek rakitan: 500 sampai 2.000 segitiga. Satu karakter: sekitar 12 draw call.
- Gabungkan bagian statis jadi satu mesh berwarna verteks (Bagian 4.3) dan pakai ulang prototipe yang sudah dibuat.
- Material dibagi pakai; batasi kombinasi fitur shader. Panaskan (warm up) shader setiap visual yang baru muncul belakangan di balik layar loading.
- Tanpa bayangan nyata dan tanpa efek layar penuh. Partikel memakai CPUParticles.
- JANGAN membaca balik mesh yang sudah diunggah ke GPU (di WebGL itu sinkron dan lambat). Simpan array verteksnya bila perlu digabung.

---

## 12. Daftar periksa untuk AI saat membuat objek baru

1. Tentukan ukurannya dalam meter berdasarkan karakter 0,90 m dan grid 0,5 m.
2. Susun dari primitif di Bagian 4.1 dengan jumlah segmen yang ditetapkan; tepi besar memakai rounded slab.
3. Beri satu warna per bagian dari palet di Bagian 5.2; pakai material di Bagian 5.1.
4. Tentukan sisi depannya dan pastikan sisi itu terbaca dari kamera yaw 45°, pitch 35°.
5. Hitung segitiganya (500 sampai 2.000) dan gabungkan bagian statisnya.
6. Tambahkan bayangan palsu bila objek berdiri di lantai.
7. Bagian yang bergerak diberi node dan pivot sendiri dengan nama tetap, lalu dianimasikan dengan sinus atau Tween.
8. Render di ukuran layar target (720 × 1280 potret) dan cek siluet, warna, dan apakah ada bagian yang menutupi teks atau objek penting dari sudut kamera.

---

## 13. Rujukan kode di repo Crumbtown

| Topik | File |
|---|---|
| Kamera | `gameplay/world/camera_rig.gd`, nilai di `data/catalog/balance.json` bagian `camera` |
| Grid dan skala | `core/grid_math.gd` |
| Primitif dan material | `procedural/meshes/mesh_factory.gd` |
| Penggabung mesh berwarna verteks | `procedural/meshes/mesh_builder.gd`, `procedural/meshes/mesh_bake.gd` |
| Palet | `core/palette.gd` |
| Cahaya dan siklus siang-malam | `procedural/meshes/room_factory.gd` (`_lighting`), `procedural/meshes/equipment_factory.gd` (`build_environment`), `gameplay/world/daylight.gd` |
| Ruangan, dinding, papan nama | `procedural/meshes/room_factory.gd` |
| Perabot | `procedural/meshes/equipment_factory.gd`, ukuran di `data/catalog/equipment.json` |
| Karakter | `procedural/meshes/character_factory.gd` |
| Animasi | `procedural/animation/anim_system.gd` |
| Lingkungan luar dan kendaraan | `procedural/meshes/neighborhood_factory.gd`, `procedural/meshes/traffic_factory.gd` |
| Spesifikasi asal | GDD v3.1 §4 (filosofi visual), §12.2 (rendering), §30 (kamera), §130 (spesifikasi visual emas) |
