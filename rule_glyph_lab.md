# Dokumen Desain Pengembangan: Rule Glyph Lab

Dokumen ini merangkum rancangan desain game, mekanik logika, simbol representasi peta, dan pertimbangan teknis untuk fitur pengembangan baru (1 - 7+) di **Rule Glyph Lab**.

---

## 1. Dinding Berat (Heavy Wall / Multi-Push Block)
*Dinding khusus yang memerlukan tenaga dorongan dari lebih dari satu pemain secara bersaman.*

* **Simbol Peta**: 
  * `2` : Blok Berat Level 2 (membutuhkan 2 pemain).
  * `3` : Blok Berat Level 3 (membutuhkan 3 pemain).
  *(Catatan: Karakter `2` dan `3` sebelumnya digunakan untuk Gate Biru/Hijau, kita bisa memetakan ulang Gate ke simbol lain seperti `[` dan `]` jika digunakan).*
* **Mekanika Logika**:
  * Ketika Player A mencoba melangkah ke Blok Berat:
    * Cari arah dorongan (misal: ke kanan, `dx=1, dy=0`).
    * Periksa apakah ada Player B (atau Player C) yang berdiri tepat di belakang Player A secara linier, dan juga sedang menginput gerakan ke arah yang sama.
    * Alternatif logika bergaya PuzzleScript (Push Berantai):
      * Jika Player B mendorong Player A $\rightarrow$ Player A mendorong Blok Berat, total "tenaga dorong" dihitung dari jumlah pemain dalam garis lurus tersebut.
* **Pertimbangan Solver (BFS)**:
  * Solver harus mengevaluasi kombinasi posisi pemain. Transisi gerakan Blok Berat hanya valid jika status state mendeteksi minimal $N$ player aktif berjejer di belakang blok tersebut dalam arah gerakan yang sama.

---

## 2. Portal Teleportasi (Portal Pairs)
*Sepasang portal masuk (IN) dan keluar (OUT) untuk memindahkan player dan glyph secara instan.*

* **Simbol Peta**:
  * `I` : Portal IN (Input)
  * `O` : Portal OUT (Output)
* **Mekanika Logika**:
  * Ketika Player atau Glyph melangkah masuk tepat ke koordinat sel `I`:
    * Koordinat entitas tersebut langsung diubah menjadi koordinat sel `O`.
    * Mainkan efek suara *teleport pop* dan trigger animasi glitzy berkedip pada DOM entitas yang diteleportasikan.
    * Sel `O` harus kosong (tidak ada dinding/closed gate/glyph/player lain) agar teleportasi sukses. Jika sel `O` terblokir, entitas tetap berada di sel `I`.
* **Pertimbangan Solver (BFS)**:
  * Teleportasi adalah transisi instan satu arah yang memicu lompatan state koordinat secara diskrit. Solver langsung memperbarui koordinat entitas dalam salinan status transisi.

---

## 3. Jurang & Penimbun (Chasms & Pit Filling)
*Sel lantai berbahaya yang menghalangi jalan player namun bisa ditimbun dengan mendorong objek ke dalamnya.*

* **Simbol Peta**:
  * `_` (Underscore) : Jurang Kosong (Chasm)
* **Mekanika Logika**:
  * Player tidak dapat berjalan ke sel jurang `_` (jika melangkah ke sana tanpa pelindung, player jatuh/mati).
  * Jika Glyph (Red, Blue, Green) didorong ke sel jurang `_`:
    * Glyph tersebut "jatuh" dan lenyap dari grid (dihapus dari daftar array `glyphs` dan DOM-nya dihapus).
    * Sel jurang tersebut berubah permanen menjadi lantai jalan biasa (`.`).
* **Pertimbangan Solver (BFS)**:
  * Transisi ini mengurangi jumlah glyph aktif di papan dan menyederhanakan hash kunci state (`getStateKey`), yang secara teoritis mempercepat pencarian BFS setelah jurang ditutup.

---

## 5. Pancaran Laser (Obstacle Laser Beams)
*Sinar energi mematikan yang memotong grid dalam garis lurus, menghalangi pergerakan kecuali jika jalurnya diblokir.*

* **Simbol Peta**:
  * `L` : Pemancar Laser Kontinu (Continuous Laser Emitter)
  * `P` : Pemancar Laser Berkala (Pulsing / Delayed Laser Emitter)
* **Mekanika Logika**:
  1. **Laser Kontinu (`L`)**:
     * Selalu aktif memancarkan sinar.
     * Jalur sinar laser menjadi daerah mematikan (`hasLaser: true`) terus-menerus.
     * Hanya bisa dihindari dengan memotong jalurnya menggunakan Glyph atau Blok Berat.
  2. **Laser Berkala (`P`)**:
     * Memiliki pola aktif/nonaktif bergantian berdasarkan jumlah langkah langkah player (contoh: aktif selama 2 langkah player, kemudian nonaktif selama 2 langkah).
     * Ketika nonaktif, sinar laser menghilang dan player bebas melewatinya.
     * Mengharuskan pemain untuk menunggu waktu yang tepat (delay langkah) sebelum melangkah maju.
* **Pertimbangan Solver (BFS)**:
  * Untuk Laser Berkala (`P`), solver harus mencatat sisa langkah timer laser (fase aktif/nonaktif) ke dalam kunci state (`getStateKey`), karena fase laser menentukan validitas sel lintasan laser di langkah berikutnya.
  * Setelah setiap gerakan objek, sistem harus menghitung ulang (raycast) jalur laser untuk memperbarui sel aman/tidak aman sebelum memvalidasi langkah berikutnya.

---

## 6. Aturan Berwaktu (Timed Rules / Rule Decay)
*Aturan konfigurasi yang memiliki batas giliran sebelum kembali ke aturan default (STOP).*

* **Mekanika Logika**:
  * Ketika player mengubah aturan di panel samping (misal: mengaktifkan `blue=SWAP`), aturan tersebut mendapatkan durasi aktif sebanyak $K$ langkah (misal: 3 langkah).
  * Setiap kali player melangkah, timer berkurang 1.
  * Ketika timer mencapai 0, aturan tersebut otomatis ter-reset kembali menjadi default `STOP`.
  * Efek visual: Tampilkan indikator angka timer kecil yang berkedip di samping kartu aturan di UI.
* **Pertimbangan Solver (BFS)**:
  * Solver harus memasukkan sisa timer aturan ke dalam hash kunci state (`getStateKey`), karena dua kondisi dengan posisi player sama tetapi sisa durasi aturan berbeda adalah state yang berbeda.

---

## 7. Lantai Penyalin Aturan (Rule Copy/Paste Floor Cells)
*Lantai anomali yang menyalin dan memancarkan aturan dari glyph yang diletakkan di atasnya.*

* **Simbol Peta**:
  * `S` : Sensor Copy-Rule
* **Mekanika Logika**:
  * Ketika glyph diletakkan/didorong di atas sel sensor `S` (misal: glyph Biru):
    * Sensor mendeteksi tipe glyph tersebut.
    * Sensor secara otomatis memaksa aturan glyph tersebut (misal: Blue) disalin ke warna glyph lain (misal: mengubah aturan Red menjadi sama dengan aturan Blue saat itu).
    * Jika glyph didorong keluar dari sel `S`, penyalinan aturan dibatalkan.
* **Pertimbangan Solver (BFS)**:
  * Ini menciptakan efek reaksi berantai otomatis. Begitu glyph diletakkan di sel `S`, aturan berubah seketika tanpa memerlukan aksi ganti rule manual oleh player.

---

## 8. Saran Tambahan Lainnya yang Menarik

### A. Tombol Inversi Gravitasi (Gravity Flip Button)
* **Mekanik**: Tombol di lantai yang jika diinjak akan membalikkan arah kontrol pergerakan.
* **Efek**: Tombol `UP` memindahkan player ke bawah, tombol `LEFT` memindahkan ke kanan. Memaksa koordinasi otak dan kerja sama tim yang lebih rumit.

### B. Tembok Bergeser (Sliding Tectonic Walls)
* **Mekanik**: Dibandingkan pintu/gate yang hanya membuka dan menutup di tempat, menginjak pressure plate akan menggeser satu baris tembok wall sejauh 1 sel (seperti lempeng tektonik).
* **Fungsi**: Membuka jalur baru sekaligus menutup atau memotong jalur lama, menciptakan labirin dinamis.

### C. Lantai Berjalan (Conveyor Belts / Treadmills)
* **Mekanik**: Sel lantai khusus yang memindahkan entitas (player atau glyph) secara otomatis ke arah aliran tertentu di akhir setiap giliran langkah.
* **Fungsi**: Membuat teka-teki bertema waktu spasial dan koordinasi pergerakan dinamis tanpa menambah langkah resmi.

### D. Portal Identitas Warna (Colored Identity Portals)
* **Mekanik**: Portal keluar (exit) yang dikunci berdasarkan identitas player (contoh: Portal Cyan hanya bisa dimasuki oleh P1, Portal Amber hanya untuk P2).
* **Fungsi**: Memaksa kerja sama pertukaran jalur antar pemain agar masing-masing bisa mencapai pintu keluar yang sesuai dengan warnanya.

### E. Zona Jammer Aturan (Rule Jammer Zones)
* **Mekanik**: Sel-sel grid tertentu yang memancarkan medan elektro-magnetik statik.
* **Fungsi**: Menonaktifkan paksa semua aturan interaksi glyph (seperti SWAP, MERGE, PUSH) menjadi STOP ketika glyph atau player berada di dalam area jammer tersebut.

