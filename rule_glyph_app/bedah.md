# BEDAH RULE GLYPH LAB - Audit Menyeluruh Kesiapan Publikasi

**Aplikasi:** Rule Glyph Lab - game puzzle grid berbasis rule/glyph (Flutter)
**Versi:** 1.0.0+1 | **Tanggal audit:** 2026-06-17
**Arsitektur:** Flutter lokal, progress/settings via `shared_preferences`, audio sintetis runtime, multiplayer lokal via TCP socket
**Target deploy:** Android, iOS, web, desktop (folder platform lengkap)
**Skala kode:** 5.155 baris Dart, 15 file Dart, 2 file test, 127 file level JSON (118 solo + 9 coop)
**Catatan QA:** `flutter` dan `dart` tidak tersedia di PATH lingkungan audit, jadi `flutter analyze`, `flutter test`, dan build release belum bisa diverifikasi.

---

## RINGKASAN EKSEKUTIF (untuk Project Manager)

Core produk sudah terbaca jelas: ini game puzzle logika offline dengan campaign solo besar, mode coop lokal, engine grid mandiri, renderer Flutter, progress lokal, opsi kontrol, privacy/terms in-app, dan audio sintetis tanpa asset suara eksternal. Asset level juga cukup banyak: 118 level solo dan 9 level coop.

Namun aplikasi ini **belum siap publikasi/store**. Masalah utamanya bukan ide produk, melainkan gate release dan beberapa bug gameplay/coop yang langsung terlihat dari kode:

1. **Project belum menjadi git repository.** `.gitignore` ada, tetapi `git status` gagal karena folder bukan repo. Tidak ada history, rollback, baseline rilis, atau proteksi nyata terhadap `build/`/`.dart_tool/`.
2. **Identitas store masih default Flutter.** Android masih `com.example.rule_glyph_app`, label Android masih `rule_glyph_app`, README/web manifest masih "A new Flutter project", dan release Android masih ditandatangani debug key.
3. **Multiplayer lokal berisiko gagal di release.** Kode memakai `ServerSocket`/`Socket`, tetapi permission Android `INTERNET` hanya ada di manifest debug/profile, bukan manifest utama. macOS release entitlement juga tidak punya network server entitlement.
4. **Mode 4-player tidak bisa dicapai dari UI.** Tombol bertuliskan "3 / 4 Player Local Net", tetapi `mode == '3/4'` selalu dipetakan ke mode `'3'`. Level 4P ada di asset, tapi tidak reachable.
5. **Ada bug engine yang memengaruhi kebenaran puzzle.** Spike yang awalnya tertutup glyph bisa dilewati tanpa mati, kematian pemain lain oleh laser bisa tidak dilaporkan sebagai death pada hasil move, dan laser vertikal dirender horizontal.
6. **QA belum cukup.** Test hanya smoke test menu + 3 happy-path engine level pertama. Tidak ada test untuk semua asset JSON, laser, spike, conveyor, teleport, coop, network message, persistence, atau responsive UI.

### Vonis kesiapan publikasi

| Aspek | Status | Catatan |
|---|---|---|
| Core game solo | Kuning | Engine dan level banyak, tapi test minim |
| Coop/local multiplayer | Merah | 4P unreachable, permission release bermasalah |
| Release Android/iOS/web | Merah | `com.example`, debug signing, metadata default |
| Version control | Merah | Bukan git repository |
| Level data | Kuning | 127 JSON, 1 mismatch width, validasi belum otomatis |
| UI/UX | Kuning | Visual konsisten, tetapi fixed landscape dan a11y lemah |
| Privacy/legal | Kuning | Teks in-app ada, tetapi belum ada URL/store policy siap pakai |
| QA/CI | Merah | Toolchain tidak tersedia di audit; tidak ada CI |

**Estimasi:** sebelum submit store, butuh 1-3 hari untuk release-engineering, perbaikan multiplayer, QA dasar, dan metadata/legal. Perbaikan engine/test bisa berjalan paralel.

---

## DAFTAR BLOCKER PUBLIKASI

| # | Blocker | Aspek | Ref |
|---|---|---|---|
| B1 | Folder bukan git repository | DevOps | [OPS-C1](#ops-c1) |
| B2 | Android masih `com.example.rule_glyph_app` | Release | [OPS-C2](#ops-c2) |
| B3 | Release Android masih signing debug key | Release | [OPS-C3](#ops-c3) |
| B4 | Flutter/Dart toolchain tidak tersedia; analyze/test/build belum verified | QA | [OPS-C4](#ops-c4) |
| B5 | Android release tidak mendeklarasikan permission network untuk TCP multiplayer | Networking | [NET-C1](#net-c1) |
| B6 | macOS release tidak punya entitlement network server | Networking | [NET-C2](#net-c2) |
| B7 | Mode 4-player unreachable dari UI | Gameplay | [GAME-C1](#game-c1) |
| B8 | Bug spike: player bisa aman di spike yang baru terbuka | Gameplay | [GAME-C2](#game-c2) |
| B9 | Bug laser/death: pemain lain bisa mati tanpa `MoveResult.dead` | Gameplay | [GAME-C3](#game-c3) |
| B10 | README/web metadata masih template Flutter | Store/Brand | [OPS-H1](#ops-h1) |
| B11 | Test coverage tidak mencakup mekanik inti | QA | [QA-H1](#qa-h1) |

---

## 1. GAMEPLAY, ENGINE, DAN LEVEL DATA

> Fondasi engine cukup lengkap untuk puzzle grid: wall, portal, spike, plate/gate, glyph rule STOP/PUSH/SWAP/MERGE, teleport, chasm, laser, conveyor, identity portal, jammer, sensor, undo snapshot, dan level JSON eksternal. Risiko utamanya ada di edge-case engine dan coverage test.

### CRITICAL

<a id="game-c1"></a>
**GAME-C1. Mode 4-player tidak bisa dicapai dari UI**
`main_menu_screen.dart:1064-1066` menampilkan tombol "3 / 4 Player Local Net" dan memanggil `_showMultiplayerDialog('3/4')`. Namun `game_screen.dart:64-68` dan `level_select_screen.dart:49-52` memetakan `3/4` menjadi `'3'`. Akibatnya `LEVELS_BY_MODE['4']` dan 3 file `assets/levels/coop/4p/*.json` tidak pernah dipilih dari UI.
**Fix:** Pisahkan pilihan "3 Player" dan "4 Player", atau tambahkan dialog jumlah pemain yang mengirim mode `'3'` atau `'4'` eksplisit. Progress key juga harus mengikuti mode riil (`max_unlocked_level_idx_4`).

<a id="game-c2"></a>
**GAME-C2. Spike yang baru terbuka bisa diinjak tanpa mati**
`game_engine.dart:349` menyimpan `targetSpikeWasCovered` sebelum glyph dipindahkan. Setelah move, death check di `game_engine.dart:517-521` melewati kematian bila target spike awalnya tertutup, walau glyph sudah terdorong pergi dan spike sekarang terbuka. Ini membuat pemain bisa "menumpang" glyph melewati spike.
**Fix:** Cek state akhir saja: kalau cell akhir `hasSpikes` dan tidak tertutup glyph, pemain mati. Jika desain memang ingin spike aman satu langkah setelah glyph didorong, dokumentasikan dan visualkan sebagai mekanik khusus.

<a id="game-c3"></a>
**GAME-C3. Kematian pemain non-aktif oleh laser bisa tidak dilaporkan sebagai death**
`updateLasers` membunuh semua active player di beam (`game_engine.dart:665-669`), tetapi `tryMove` hanya mengembalikan `dead: true` bila `player` yang sedang bergerak mati (`game_engine.dart:538-540`). Lalu `areAllPlayersFinished` menghitung `p.dead` sebagai selesai (`game_engine.dart:812-823`). Kombinasi ini bisa membuat death pemain lain tidak masuk `_handleDeath`, atau pada edge-case coop justru masuk kondisi win terlebih dahulu (`game_screen.dart:198-204`).
**Fix:** `MoveResult` perlu membawa daftar `deadPlayerIds`, dan `areAllPlayersFinished` jangan menghitung dead sebagai finished untuk kemenangan. Di UI, death harus diprioritaskan sebelum win bila ada pemain mati.

### HIGH

**GAME-H1. Laser vertikal dirender horizontal**
Engine membedakan horizontal/vertical laser (`game_engine.dart:639-659`), tetapi `activeLaserBeams` hanya menyimpan string `"x,y"` (`game_engine.dart:119`) dan `GridBoard._buildLaserBeam` selalu menggambar bar horizontal (`grid_board.dart:424-446`, terutama `width: tileSize`, `height: 4`). Level dengan laser vertikal akan membunuh benar secara engine, tapi tampil salah.
**Fix:** Simpan orientasi beam, misalnya `LaserBeam(x,y,axis)`, atau derive orientasi saat render dari emitter terdekat.

**GAME-H2. Satu level JSON punya mismatch width**
Validasi statis menemukan `assets/levels/coop/2p/2.json:5` `width = 10`, tetapi baris map `assets/levels/coop/2p/2.json:29` (`"#%.b.a.2.X#"`) panjangnya 11. Loader `game_engine.dart` mengabaikan karakter ekstra karena iterasi hanya sampai `width`, jadi masalah ini tersembunyi.
**Fix:** Perbaiki JSON dan tambah test schema untuk semua level: jumlah row == height, panjang semua row == width, player count sesuai mode, minimal satu exit, dan karakter map whitelist.

**GAME-H3. Loader level menelan error dan bisa fallback diam-diam**
`initializeLevels` memakai `while (true)` dan `catch (e)` untuk mendeteksi akhir file (`levels_data.dart:762-792`), lalu outer catch hanya `print` dan fallback ke compiled levels (`levels_data.dart:802-804`). Satu JSON rusak bisa membuat chapter terpotong tanpa UI error.
**Fix:** Bedakan "file tidak ada" dari "JSON invalid". Gunakan manifest daftar level atau generated index, lalu fail fast pada JSON invalid.

**GAME-H4. Source level ganda berpotensi drift**
Level ada di `lib/data/levels_data.dart`, `assets/levels/**/*.json`, dan `assets/levels.json` yang dihasilkan script. `split_json.dart:43` bahkan menyebut `assets/levels.json` boleh dihapus, tetapi file itu masih ada dan tidak dideklarasikan di `pubspec.yaml`. Ini rawan beda antara source of truth dan asset runtime.
**Fix:** Pilih satu source of truth. Untuk rilis, rekomendasi: JSON asset + validator/generator, sementara fallback compiled-in hanya untuk test/dev.

### MEDIUM

- **GAME-M1. `isGameActive` tidak pernah berubah.** `game_engine.dart:122` dicek di UI (`game_screen.dart:151,353`), tetapi tidak pernah diset false saat win/death/out-of-steps. Saat ini dialog/snackbar yang menghentikan alur, bukan state engine.
- **GAME-M2. Move limit coop punya cabang redundant.** `game_screen.dart:113-119` menghitung `hasP2`, tetapi kedua cabang sama-sama `level.movesLimit`.
- **GAME-M3. Finished player masih dirender di board.** `GridBoard` merender semua player dengan `x != -1`; `isPlayerActive` mengabaikan finished player. Ini bisa membuat overlap visual pada portal coop.
- **GAME-M4. Tidak ada solver/solvability check.** Banyak level punya batas langkah ketat, tetapi tidak ada test yang membuktikan level bisa diselesaikan sesuai `movesLimit`.

---

## 2. MULTIPLAYER LOKAL DAN NETWORKING

> Fitur coop memakai TCP lokal mentah: host bind ke `InternetAddress.anyIPv4`, client connect ke IP, pesan JSON newline-delimited. Ini bisa dipakai untuk prototipe LAN, tetapi perlu hardening sebelum menjadi fitur publik.

### CRITICAL

<a id="net-c1"></a>
**NET-C1. Android release kemungkinan tidak bisa multiplayer karena permission network hilang**
`local_network_controller.dart:82-110` memakai `ServerSocket.bind` dan `Socket.connect`. Permission `android.permission.INTERNET` hanya ada di `android/app/src/debug/AndroidManifest.xml:6` dan `android/app/src/profile/AndroidManifest.xml:6`; `android/app/src/main/AndroidManifest.xml` tidak memilikinya. Di release, socket Android umumnya butuh permission ini.
**Fix:** Tambahkan `<uses-permission android:name="android.permission.INTERNET"/>` ke manifest main bila local network mode adalah fitur release. Jika app ingin truly offline tanpa network, hapus mode local net.

<a id="net-c2"></a>
**NET-C2. macOS release tidak punya entitlement network server**
`macos/Runner/DebugProfile.entitlements:9` punya `com.apple.security.network.server`, tetapi `macos/Runner/Release.entitlements` hanya berisi app sandbox. Host mode (`ServerSocket.bind`) berisiko gagal pada build macOS release.
**Fix:** Tambahkan entitlement network server/client yang sesuai ke release, atau disable host/client UI di macOS release.

### HIGH

**NET-H1. "Invite code" sebenarnya IP mentah, tanpa autentikasi**
Host bind ke semua IPv4 (`local_network_controller.dart:87`) dan menerima client pertama tanpa token (`local_network_controller.dart:89-101`). UI menyebut "IP / Invite Code", tetapi yang ditampilkan hanya IP. Di Wi-Fi publik/sekolah, perangkat lain bisa connect duluan.
**Fix:** Generate session code/token singkat, kirim token dalam handshake, dan tolak client tanpa token.

**NET-H2. Peer bisa mengirim pesan valid-JSON yang membuat UI crash**
Deserialize hanya memastikan JSON punya `type` dan `data` map (`local_network_controller.dart:20-25`). Handler UI melakukan cast langsung (`game_screen.dart:279-285`, `300-313`). Peer yang mengirim `{"type":"move","data":{"dx":"x"}}` bisa memicu type error di listener.
**Fix:** Validasi schema per message type sebelum mutasi state; abaikan pesan invalid dan tampilkan status koneksi.

**NET-H3. Tidak ada state sync awal/reconnect**
Host hanya mengirim `join_ack` (`local_network_controller.dart:101`). Tidak ada snapshot level/current state/rules/moves saat client join atau reconnect. Saat koneksi putus, dialog hanya exit (`game_screen.dart:377-385`).
**Fix:** Setelah handshake, host kirim snapshot lengkap: mode, level index, engine snapshot, rules, expiries, movesLeft, protocolVersion.

### MEDIUM

- **NET-M1. Deteksi IP LAN sempit.** `discoverLocalIp` hanya memprioritaskan `192.168.*`, `10.*`, dan `172.16.*` (`local_network_controller.dart:52-64`). Range private `172.17.*` sampai `172.31.*` tidak tercakup.
- **NET-M2. StreamController tidak pernah ditutup.** `shutdown` menutup socket/server (`local_network_controller.dart:167-173`) tetapi tidak close `_messageController` dan `_connectionStateController`. Tambahkan `dispose()`.
- **NET-M3. Local network privacy iOS belum disiapkan.** `ios/Runner/Info.plist` tidak memuat penjelasan local network. Jika iOS release tetap membawa host/join LAN, tambahkan usage description yang jelas.

---

## 3. UI/UX DAN AKSESIBILITAS

> Visual neon/dark konsisten untuk game, dan D-pad + rule panel cocok untuk landscape. Kelemahannya: layout sangat fixed, banyak teks kecil, board tidak punya semantik, dan metadata web justru portrait.

### HIGH

**UX-H1. Board, D-pad, dan rule controls hampir tidak aksesibel screen reader**
Tidak ada pemakaian `Semantics` di `lib/widgets`. D-pad berisi `InkWell` + `Icon` tanpa label (`dpad.dart:44-52`), rules panel memakai `InkWell` custom untuk back/undo/reset/rule button (`rules_panel.dart:47`, `174`, `212`, `300`), dan board adalah `Stack` visual (`grid_board.dart:52-92`). Screen reader tidak mendapat informasi "move up", posisi pemain, rule aktif, gate, atau status laser.
**Fix:** Tambah `Semantics(label/button/enabled/selected)` untuk D-pad dan rule buttons; untuk board, minimal expose status teks ringkas: posisi pemain, moves left, rule aktif, dan pesan hazard.

**UX-H2. Layout fixed landscape rawan overflow di layar kecil/text scaling**
`main.dart:10-16` memaksa landscape + immersive fullscreen. `GameScreen` memakai sidebar fixed `185` px (`game_screen.dart:398`) dan `LevelSelectScreen` sidebar fixed `220` px (`level_select_screen.dart:210`). Banyak font 6.5-12 px di rules panel (`rules_panel.dart:111`, `155`, `200`, `327`). Ini rawan terpotong di ponsel kecil atau saat text scaling besar.
**Fix:** Uji beberapa viewport landscape, text scale 1.3-2.0, dan ubah panel menjadi responsive/scrollable. Hindari font di bawah 11-12 px untuk informasi penting.

**UX-H3. Orientasi web manifest bertentangan dengan app**
App mengunci landscape (`main.dart:10-16`), tetapi `web/manifest.json:9` menyatakan `"orientation": "portrait-primary"`. PWA/web install bisa membuka orientasi yang salah.
**Fix:** Ganti ke `landscape-primary` atau hapus constraint manifest bila web harus fleksibel.

**UX-H4. Privacy/terms hanya in-app, belum siap store**
Teks privacy dan terms ada di `main_menu_screen.dart:847-873`, tetapi belum ada URL privacy policy yang bisa dipakai Play Store/App Store. Teks privacy juga menyebut "fully offline" (`main_menu_screen.dart:853`) sementara app punya local network mode.
**Fix:** Host privacy policy publik. Jelaskan data lokal, mode LAN, tidak ada analytics/cloud, dan permission network untuk multiplayer lokal.

### MEDIUM

- **UX-M1. `setState` setelah await tanpa `mounted` guard.** Contoh: `_loadSettings` (`main_menu_screen.dart:33-39`), `_loadControlSettings` (`game_screen.dart:86-91`), `_loadProgress` (`level_select_screen.dart:59-70`).
- **UX-M2. Opsi opacity tidak dipakai.** `_controlOpacity` dibaca dari prefs (`main_menu_screen.dart:23-39`), tetapi D-pad hanya menerima `scale` (`game_screen.dart:35-37`, `dpad.dart`) dan tidak ada kontrol opacity di game.
- **UX-M3. Banyak dialog custom tanpa focus management eksplisit.** `AlertDialog` membantu sebagian, tetapi BackdropFilter + banyak custom `InkWell` tetap perlu test keyboard/TV/desktop.
- **UX-M4. `SystemUiMode.immersiveSticky` membuat navigasi sistem tersembunyi.** Cocok untuk game, tetapi perlu tombol back/exit yang jelas di semua modal dan test pada Android gesture navigation.

---

## 4. STATE, PERSISTENSI, DAN AUDIO

### HIGH

**ST-H1. Save progress menelan error diam-diam**
`_saveProgress` menulis `max_unlocked_level_idx_${widget.mode}` (`game_screen.dart:208-217`) dan catch hanya komentar `// ignore failures`. Jika storage gagal setelah win, pemain melihat sukses tetapi level berikutnya tidak terbuka.
**Fix:** Kembalikan `Future<bool>` dari save, tampilkan error non-blocking bila gagal, dan retry saat kembali ke level select.

**ST-H2. Progress model hanya "max unlocked", tidak menyimpan sesi berjalan**
Undo stack ada di memori (`game_screen.dart:47`) dan progress hanya tersimpan saat win. Jika app tertutup mid-level, attempt hilang. Untuk puzzle dengan level panjang, ini UX regression.
**Fix:** Persist draft level opsional: level index, engine snapshot, active rules, expiries, movesLeft, undo stack terbatas. Clear saat win/reset manual.

**ST-H3. AudioPlayer cache tidak pernah dispose**
`AudioManager` membuat `AudioPlayer` per sound (`audio_manager.dart:19-24`) dan menyimpannya di singleton, tetapi tidak ada dispose. Ini mungkin tidak besar (jumlah sound kecil), tetapi tetap perlu lifecycle saat app pause/exit.
**Fix:** Tambah `dispose()`/`stopAll()`, panggil dari app lifecycle observer, dan pertimbangkan lazy preload.

### MEDIUM

- **ST-M1. Muted state tidak dipersist.** `AudioManager.isMuted` hanya memori (`audio_manager.dart:8`), sehingga setting mute hilang setelah restart.
- **ST-M2. Reset progress belum menghapus mode 4 riil.** Reset menghapus key `1`, `2`, `3`, dan `3/4` (`main_menu_screen.dart:826-829`), tetapi bila mode 4 diperbaiki ke key `4`, reset juga harus menghapusnya.
- **ST-M3. Tidak ada schema version untuk preferences.** Key progress/control langsung dipakai; saat struktur berubah, migrasi sulit.

---

## 5. BUILD, DEPLOY, BRANDING, DAN COMPLIANCE

### CRITICAL

<a id="ops-c1"></a>
**OPS-C1. Bukan git repository**
`git status` dan `git rev-parse --is-inside-work-tree` gagal dengan "not a git repository". `.gitignore` ada, tetapi belum aktif sebagai proteksi versi. Folder juga berisi `.dart_tool/` dan `build/`, yang harus tetap di luar commit/source bundle.
**Fix:** `git init`, pastikan `.gitignore` bekerja, commit source bersih, dan gunakan remote privat/benar. Jangan commit `build/`, `.dart_tool/`, atau artifact IDE.

<a id="ops-c2"></a>
**OPS-C2. Android applicationId masih `com.example`**
`android/app/build.gradle.kts:8` namespace dan `:19` applicationId masih `com.example.rule_glyph_app`; komentar TODO masih ada di `:18`. Play Store tidak menerima identitas example untuk rilis serius, dan applicationId sulit diganti setelah publish.
**Fix:** Tentukan reverse-DNS final, misalnya `com.nitedreamworks.ruleglyphlab`, lalu rename package Android/Kotlin dan bundle identifier platform lain secara konsisten.

<a id="ops-c3"></a>
**OPS-C3. Release Android masih pakai debug signing**
`android/app/build.gradle.kts:30-32` memakai `signingConfigs.getByName("debug")` untuk build release. Ini blocker Play Store.
**Fix:** Generate upload keystore, simpan aman di luar repo, gitignore `key.properties`/`*.jks`, dan konfigurasi `signingConfigs.release`.

<a id="ops-c4"></a>
**OPS-C4. QA toolchain tidak tersedia di lingkungan audit**
`flutter --version` dan `dart --version` gagal: command not recognized. Maka `flutter analyze`, `flutter test`, dan build release belum bisa dikonfirmasi.
**Fix:** Jalankan di mesin dengan Flutter SDK: `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk/appbundle/web` sesuai target. Tambahkan CI agar gate ini tidak manual.

### HIGH

<a id="ops-h1"></a>
**OPS-H1. README masih template Flutter**
`README.md:1-5` masih `# rule_glyph_app`, "A new Flutter project", dan "Getting Started" bawaan Flutter.
**Fix:** Ganti dengan README produk: deskripsi, mode game, cara run/build/test, struktur level, cara generate/split JSON, privacy model, dan status release.

**OPS-H2. Web metadata masih default**
`web/index.html:21,26,32` dan `web/manifest.json:2-9` masih menyebut `rule_glyph_app`, "A new Flutter project", warna Flutter default, dan portrait orientation.
**Fix:** Update title, description, theme color, icon brand, PWA orientation, OG/Twitter meta, dan favicon.

**OPS-H3. Android label masih `rule_glyph_app`**
`android/app/src/main/AndroidManifest.xml:3` memakai label `rule_glyph_app`. iOS display name sudah lebih baik (`Rule Glyph App`), tetapi brand di UI adalah `RULE GLYPH LAB`.
**Fix:** Konsistenkan nama: "Rule Glyph Lab" di Android, iOS, web manifest, README, store listing, dan app title.

**OPS-H4. Tidak ada CI/CD, LICENSE, atau store asset checklist**
Tidak terlihat folder `.github/`, `.gitlab-ci.yml`, LICENSE, atau docs release. Untuk rilis multi-platform, ini gap operasional.
**Fix:** Tambah CI minimal analyze+test; tambah LICENSE; siapkan screenshot, icon 512/1024, feature graphic, privacy URL, dan release notes.

**OPS-H5. `assets/levels.json` adalah artifact/generator source yang membingungkan**
`bin/generate_json.dart:23-25` membuat `assets/levels.json`; `bin/split_json.dart:43` menyebut boleh dihapus. File ini masih ada (114 KB), tetapi `pubspec.yaml` hanya mendaftarkan subfolder level, bukan `assets/levels.json`.
**Fix:** Hapus dari tree bila bukan source of truth, atau deklarasikan dan gunakan. Dokumentasikan workflow level generation.

### MEDIUM

- **OPS-M1. Tidak ada secret obvious di source non-build.** Pencarian pola `apiKey/private_key/secret/password/token` tidak menemukan credential.
- **OPS-M2. Lint masih baseline default.** `analysis_options.yaml:10-24` hanya include `flutter_lints` tanpa aturan tambahan. Cukup untuk awal, tetapi rilis game akan diuntungkan dari lint lebih ketat.
- **OPS-M3. `version: 1.0.0+1` sudah terlihat release-final.** Untuk app yang masih punya blocker, pertimbangkan turun ke `0.x` sampai QA/store gate hijau, atau disiplin bump build number setiap upload.

---

## 6. TEST COVERAGE DAN QA

> Test yang ada sangat tipis. `test/game_engine_test.dart` hanya memverifikasi load level pertama, wall blocking, dan path victory sederhana. `test/widget_test.dart` hanya memastikan main menu render.

### HIGH

<a id="qa-h1"></a>
**QA-H1. Test tidak mencakup mekanik inti**
`game_engine_test.dart:13-52` hanya happy-path dasar; `widget_test.dart:14-20` hanya smoke test menu. Tidak ada coverage untuk PUSH/SWAP/MERGE, spike, gate/plate, teleport, chasm, laser, conveyor, identity portal, jammer, sensor, undo/restore, coop multi-player, atau level JSON asset.
**Fix:** Tambah unit test engine per mekanik, plus data-driven test untuk semua JSON level.

**QA-H2. Tidak ada test network protocol**
Network message bisa mengubah move/rule/level/reset/undo (`game_screen.dart:276-318`), tetapi tidak ada test valid/invalid message, reconnect, or sync.
**Fix:** Pisahkan protocol handler dari widget state agar bisa dites tanpa UI.

**QA-H3. Tidak ada visual/regression test untuk board**
Bug laser vertikal horizontal tidak tertangkap karena tidak ada widget/golden test untuk board/hazard.
**Fix:** Tambah golden atau screenshot test untuk laser horizontal, laser vertikal, spike tertutup/terbuka, gate open/closed, dan 2P/3P/4P board.

### Test yang perlu ditambah sebelum rilis

- Schema test semua `assets/levels/**/*.json`.
- Test all-level load lewat `initializeLevels`.
- Test mode selection: solo, 2P, 3P, 4P.
- Test spike behavior setelah glyph didorong dari spike.
- Test laser death semua player, bukan hanya mover.
- Test vertical laser rendering.
- Test save progress sukses/gagal.
- Test reset progress semua mode.
- Test network invalid JSON dan invalid typed data.
- Test responsive smoke untuk landscape small phone dan tablet.

---

## CHECKLIST KESIAPAN PUBLIKASI

### Blocker wajib sebelum rilis

- [ ] Init git dan commit source bersih; pastikan `build/` dan `.dart_tool/` tidak ikut
- [ ] Ganti Android `applicationId`/namespace dari `com.example.*`
- [ ] Konfigurasi Android release signing dengan upload keystore
- [ ] Tambah permission/entitlement network release bila local multiplayer dipertahankan
- [ ] Pisahkan UI 3-player dan 4-player; pastikan level 4P reachable
- [ ] Fix spike behavior (GAME-C2)
- [ ] Fix laser/death result untuk semua player (GAME-C3)
- [ ] Jalankan `flutter analyze` dan `flutter test` hijau di toolchain nyata
- [ ] Tambah test schema semua level JSON
- [ ] Update README, web manifest, title, app labels, dan store metadata
- [ ] Host privacy policy publik; sesuaikan wording "offline" dengan local network mode

### Sangat disarankan sebelum launch

- [ ] Fix render laser vertikal
- [ ] Validasi JSON level fail-fast, bukan fallback diam-diam
- [ ] Tambah handshake token untuk local multiplayer
- [ ] Validasi schema semua network message
- [ ] Tambah state sync awal/reconnect untuk coop
- [ ] Tambah semantics untuk D-pad/rule controls/status game
- [ ] Uji layout landscape pada HP kecil, tablet, dan text scale besar
- [ ] Persist mute state dan tangani save progress failure
- [ ] Hapus atau dokumentasikan `assets/levels.json`
- [ ] Tambah CI minimal `flutter analyze` + `flutter test`
- [ ] Tambah LICENSE dan release checklist

### Nice-to-have pasca-launch

- [ ] Save/resume attempt in-progress
- [ ] Golden test board/hazard
- [ ] Solvability tooling atau solver untuk level campaign
- [ ] Better invite UX: QR code/session code untuk LAN
- [ ] In-app changelog dan version display
- [ ] Store screenshots dan trailer singkat

---

## ROADMAP MENUJU PUBLIKASI

**Fase 0 - Source control dan release identity (setengah hari)**
Init git, commit source bersih, pastikan ignore benar, ganti package id/bundle id final, label app final, web metadata final.

**Fase 1 - Multiplayer release gate (setengah sampai 1 hari)**
Tambahkan Android permission/main manifest, macOS release entitlement, iOS local network description bila target iOS, perbaiki mode 3P/4P, dan uji host/join pada build release.

**Fase 2 - Engine correctness (1 hari)**
Fix spike behavior, laser death result, laser vertical rendering, dan tambah unit test untuk mekanik tersebut.

**Fase 3 - QA data dan CI (setengah sampai 1 hari)**
Tambahkan schema validator semua JSON, test all-level load, test mode selection, jalankan analyze/test/build di toolchain Flutter, lalu masukkan ke CI.

**Fase 4 - Store readiness (setengah sampai 1 hari)**
Android signing release, privacy policy URL, README nyata, LICENSE, icon/splash/web/PWA metadata, screenshots, dan release notes.

**Fase 5 - UX/accessibility polish**
Semantics D-pad/rules/status, responsive landscape layout, text scale, save failure UX, mute persistence, dan resume attempt.

---

*Audit ini dibuat dari pembacaan statis terhadap source, konfigurasi platform, asset level, dan test yang ada. Karena Flutter/Dart tidak tersedia di lingkungan audit, hasil analyzer/test/build harus dianggap belum terverifikasi sampai dijalankan di toolchain nyata.*
