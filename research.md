# Laporan Rekayasa Keamanan dan Privasi: Aplikasi Pemutar Musik Lokal (Offline) Berbasis Flutter

Aplikasi pemutar musik yang beroperasi sepenuhnya secara luring (*offline*) memiliki karakteristik vektor serangan (*attack surface*) yang berbeda dari aplikasi berbasis *cloud*. Ancaman utama bukan berasal dari eksfiltrasi jaringan jarak jauh (*remote code execution via network*), melainkan dari:

1. Akses penyimpanan yang berlebihan (*over-privileged storage access*).
2. Manipulasi komponen sistem melalui *Inter-Process Communication* (IPC).
3. Berkas media berbahaya (*malformed audio payload*) yang dapat memicu *buffer overflow* atau *denial-of-service* pada lapisan native decoder.


4. Kebocoran data privasi lokal melalui *logcat* atau *shared storage*.

Laporan ini menyajikan panduan implementasi keamanan menyeluruh untuk aplikasi pemutar musik lokal Flutter yang menargetkan platform Android.

---

## 1. Prinsip Hak Akses Minimal dan Arsitektur Scoped Storage

Pada sistem Android modern (Android 10 hingga Android 14+), paradigma *Scoped Storage* membatasi akses aplikasi ke direktori publik. Aplikasi pemutar musik lokal tidak boleh meminta izin penyimpanan penuh yang tidak proporsional.

### Hindari `MANAGE_EXTERNAL_STORAGE`

Izin `MANAGE_EXTERNAL_STORAGE` (*All Files Access*) memberikan hak baca dan tulis ke seluruh sistem berkas pengguna (dokumen, unduhan, foto, basis data aplikasi lain). Menggunakan izin ini untuk pemutar musik lokal merupakan pelanggaran prinsip *Least Privilege*, meningkatkan risiko privasi pengguna, dan memicu penolakan otomatis dalam peninjauan Google Play Store.

### Gunakan Izin Granular Sesuai API Level

Implementasikan konfigurasi izin bertingkat (*tiered permissions*) pada `AndroidManifest.xml`:

```xml
<!-- Android 12L (API 32) ke bawah -->
<uses-permission 
    android:name="android.permission.READ_EXTERNAL_STORAGE" 
    android:maxSdkVersion="32" />

<!-- Android 13 (API 33) ke atas -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />

```

### Akses Terkelola via `MediaStore API`

Hindari pemindaian rekursif manual ke direktori akar (seperti `Directory('/storage/emulated/0').listSync()`). Pemindaian mentah lambat, boros baterai, dan melanggar aturan sandbox Android.

Gunakan antarmuka `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` (misalnya melalui pustaka seperti `on_audio_query` di Flutter). `MediaStore` menyediakan indeks metadata audio yang telah diverifikasi oleh subsistem Android, sehingga aplikasi hanya membaca entri audio tanpa menyentuh file privat lain milik pengguna.

---

## 2. Pengamanan Komponen Native Android dan IPC (Inter-Process Communication)

Karena pemutar musik memanfaatkan layanan latar belakang (*Foreground Service*) dan antarmuka notifikasi sistem, aplikasi secara intensif berinteraksi dengan komponen sistem Android melalui *Intent* dan *BroadcastReceiver*.

### Proteksi Immutabilitas `PendingIntent`

Tombol pengendali pada notifikasi (*play*, *pause*, *skip*) memanfaatkan `PendingIntent`. Pada Android 12 (API level 31 ke atas), semua `PendingIntent` wajib dideklarasikan dengan flag `FLAG_IMMUTABLE`:

```kotlin
val pendingIntent = PendingIntent.getActivity(
    context,
    requestCode,
    intent,
    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
)

```

*Mengapa ini krusial:* Tanpa `FLAG_IMMUTABLE`, aplikasi pihak ketiga yang berjalan di perangkat yang sama dapat mengisi atau memodifikasi parameter Intent (`PendingIntent Hijacking`) untuk memicu aksi tak terotorisasi di dalam aplikasi pemutar musik.

### Isolasi Komponen Manifest (`android:exported`)

Setiap komponen di `AndroidManifest.xml` harus diatur aksesibilitasnya secara eksplisit:

* **Komponen Internal (`android:exported="false"`):** Semua `Activity`, `Service`, atau `BroadcastReceiver` internal yang tidak memerlukan interaksi dari aplikasi lain wajib disetel `false` untuk mencegah pemanggilan ilegal (*arbitrary execution*).
* **Komponen Terbuka untuk Sistem:** Komponen yang wajib diakses oleh subsistem media Android (seperti `MediaButtonReceiver` atau service dari `audio_service`) harus disetel `android:exported="true"`, tetapi wajib dilengkapi dengan pembatasan filter aksi media resmi:



```xml
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
</service>

<receiver
    android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON" />
    </intent-filter>
</receiver>

```

---

## 3. Validasi Berkas, Mitigasi Path Traversal, dan Parsing Metadata

Aplikasi musik offline memproses berkas yang diimpor dari berbagai sumber (unduhan internet pengguna, transfer Bluetooth, atau flashdisk OTG). Berkas-berkas ini harus diperlakukan sebagai masukan tidak tepercaya (*untrusted input*).

### Mitigasi Path Traversal (`../`)

Jika aplikasi mengizinkan penambahan folder lagu kustom melalui *Storage Access Framework* (SAF) atau pengimporan berkas individual, selalu normalisasi path sebelum mengaksesnya:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;

bool isPathSafe(String basePath, String targetPath) {
  final canonicalBase = Directory(basePath).resolveSymbolicLinksSync();
  final canonicalTarget = File(targetPath).resolveSymbolicLinksSync();
  
  // Pastikan path target berada di bawah hierarki direktori yang diizinkan
  return p.isWithin(canonicalBase, canonicalTarget);
}

```

Pemeriksaan ini mencegah serangan traversal yang mengelabui aplikasi untuk mengakses atau menimpa berkas pada direktori privat aplikasi (`/data/data/<package_name>/databases/`).

### Verifikasi Format Berkas dan Magic Bytes

Jangan hanya mengandalkan ekstensi berkas (`.mp3`, `.flac`, `.wav`). Berkas executable berbahaya atau skrip berbahaya dapat diubah namanya menjadi `.mp3`. Periksa beberapa byte awal (*magic numbers*) sebelum menginstruksikan decoder:

| Format Audio | Magic Bytes / Header |
| --- | --- |
| **MP3 (dengan tag ID3v2)** | `49 44 33` (`ID3`) |
| **MP3 (tanpa header ID3)** | `FF FB` atau `FF F3` (MPEG Audio Sync) |
| **FLAC** | `66 4C 61 43` (`fLaC`) |
| **WAV / RIFF** | `52 49 46 46` (`RIFF`) |
| **Ogg / Vorbis / Opus** | `4F 67 67 53` (`OggS`) |

### Penanganan Ekstraksi Sampul Album (*Album Art Decompression Bomb*)

Tag ID3v2 sering kali memuat gambar sampul album (*APIC frame*). Berkas audio yang rusak atau dirancang jahat dapat memuat:

1. Gambar berukuran resolusi raksasa (misal $10.000 \times 10.000$ piksel) yang memicu *Out-Of-Memory* (OOM) saat didekode ke bitmap ARGB.
2. Header byte gambar yang korup, yang dapat memicu *crash* tak tertangani pada native image decoder Android/Skia.

**Pencegahan:**

* Batasi alokasi ukuran *byte stream* saat mengekstrak APIC frame (misalnya tolak frame gambar yang melebihi batas 5 MB).
* Selalu gunakan decoding terikat (*bounded decoding*) dengan properti `cacheWidth` dan `cacheHeight` di Flutter agar bitmap didekode sesuai ukuran tampilan UI, bukan ukuran asli berkas gambar.
* Bungkus rutin ekstraksi metadata dalam blok penanganan eksepsi (`try-catch`) yang ketat untuk mengisolasi kegagalan parsing.

---

## 4. Keamanan Data Lokal (*Data-at-Rest*) dan Database Sandboxing

Aplikasi pemutar musik menyimpan data operasional seperti: daftar putar kustom (*custom playlists*), riwayat lagu (*play history*), konfigurasi equalizer, dan cache thumbnail.

### Lokasi Penyimpanan Sandbox

Simpan basis data lokal (SQLite/sqflite, Hive, atau Isar) murni di direktori dokumen privat aplikasi:

* Gunakan `getApplicationDocumentsDirectory()` atau `getDatabasesPath()`.
* **Jangan pernah** menaruh database aplikasi di shared external storage (seperti `/sdcard/Music/app_database.db`), karena berkas tersebut dapat dibaca atau dimodifikasi oleh aplikasi pihak ketiga tanpa sepengetahuan pengguna.



### Pencegahan SQL Injection

Jika menggunakan SQLite (`sqflite`), hindari penggabungan string mentah (*string concatenation*) pada query:

```dart
// RENTAN terhadap SQL Injection
await db.rawQuery("SELECT * FROM tracks WHERE title = '" + userInput + "'");

// AMAN (Parameterized Query)
await db.rawQuery("SELECT * FROM tracks WHERE title = ?", [userInput]);

```

### Sanitasi Teks Tampilan

Sanitasi metadata lagu (judul, artis, album) sebelum ditampilkan ke antarmuka atau notifikasi. Metadata yang memuat karakter kontrol tersembunyi (seperti karakter *Right-to-Left Override* `U+202E` atau teks format string berlebihan) dapat menyebabkan *UI rendering glitch* atau *crash* pada parser layout teks bawaan OS.

---

## 5. Arsitektur Zero-Network dan Audit Dependensi

Kelebihan utama dari pemutar musik lokal adalah kemampuan untuk beroperasi sepenuhnya secara terisolasi dari internet. Memanfaatkan status ini memberikan privasi penuh kepada pengguna.

### Hapus Total Izin Internet

Pastikan baris berikut **tidak ada** di `AndroidManifest.xml`:

```xml
<!-- PASTIKAN BARIS INI DIHAPUS DARI MANIFEST -->
<uses-permission android:name="android.permission.INTERNET" />

```

Tanpa izin ini, kernel Android secara fisik memblokir soket jaringan untuk seluruh proses aplikasi. Bahkan jika terdapat pustaka pihak ketiga yang memiliki celah keamanan (*vulnerable SDK*), data pengguna tidak dapat dikirim ke server luar.

### Audit Transitif Permission (*Manifest Merge Check*)

Beberapa pustaka Flutter menyertakan izin internet secara implisit di manifes internal mereka. Setelah melakukan build rilis, periksa hasil penggabungan manifes di:
`android/app/build/outputs/logs/manifest-merger-release-report.txt`

Pastikan tidak ada entri `android.permission.INTERNET` yang disuntikkan secara otomatis oleh library dependensi. Jika ada pustaka yang menyuntikkannya, singkirkan izin tersebut secara paksa di manifes utama aplikasi:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    
    <uses-permission 
        android:name="android.permission.INTERNET" 
        tools:node="remove" />
</manifest>

```

---

## 6. Hardening Kode Rilis dan Log Sanitization

### Obfuscation dan Minification (R8 / ProGuard)

Konfigurasikan `android/app/build.gradle` untuk mengaktifkan obfuscation pada lapisan native Java/Kotlin:

```groovy
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}

```

Langkah ini mempersulit upaya rekayasa balik (*reverse engineering*) dan membersihkan sisa kode yang tidak terpakai dari pustaka pihak ketiga.

### Sanitasi Informasi Debugging

Dalam mode produksi (*release build*):

* Nonaktifkan semua pemanggilan `print()`, `debugPrint()`, dan pesan log native.
* Jangan pernah mencetak struktur path file audio pengguna, judul lagu, atau isi basis data ke sistem `adb logcat`. Pada perangkat Android lama atau perangkat yang telah di-*root*, logcat dapat disadap oleh proses lain untuk memetakan aktivitas pribadi pengguna.

---

## Ringkasan Checklist Keamanan Produksi

| Domain Keamanan | Praktik yang Direkomendasikan | Status Implementasi |
| --- | --- | --- |
| **Izin Penyimpanan** | Hanya gunakan `READ_MEDIA_AUDIO` (API 33+) & `READ_EXTERNAL_STORAGE` (API $\le$ 32). Tolak `MANAGE_EXTERNAL_STORAGE`.

 | Wajib |
| **Penyedia Media** | Ambil daftar lagu melalui `MediaStore API`, bukan pemindaian folder mentah.

 | Wajib |
| **IPC & Intents** | Tambahkan flag `FLAG_IMMUTABLE` pada semua `PendingIntent`. | Wajib |
| **Manifest Components** | Setel `android:exported="false"` pada semua komponen kecuali service/receiver media resmi.

 | Wajib |
| **File Traversal** | Validasi dan batasi path input menggunakan `resolveSymbolicLinksSync()`. | Rekomendasi Tinggi |
| **Validasi Berkas** | Cek header format audio (magic bytes) sebelum memproses streaming media. | Rekomendasi |
| **Parsing Metadata** | Batasi ukuran cover art yang diekstrak dan isolasi blok parsing dengan *try-catch*. | Wajib |
| **Basis Data Lokal** | Simpan di sandbox internal (`app documents dir`) dan gunakan *parameterized queries*. | Wajib |
| **Akses Jaringan** | Hapus izin `INTERNET` dan pasang filter `tools:node="remove"`. | Wajib (Offline) |
| **Build Hardening** | Aktifkan R8/ProGuard minification dan bersihkan seluruh logcat runtime. | Wajib |