# ARMSys — Otorisasi Dokumen

Modul pertama ARMSys, dimigrasikan dari ekstraksi modul tanda tangan Apps Script. UI mengikuti referensi dashboard putih, lime, dan teal. Frontend HTML/CSS/JavaScript modules; Supabase Auth, Postgres, dan Storage; deployment GitHub Pages. Tidak memerlukan build bundler. PDF.js dan pdf-lib disertakan lokal beserta lisensinya.

## Jalankan

Node.js 22+: `npm run dev`, kemudian buka http://127.0.0.1:4173. Jalankan `npm run check` untuk pemeriksaan sintaks.

Tanpa konfigurasi Supabase, aplikasi menggunakan data contoh dan IndexedDB lokal. Berkas tidak dikirim ke server dan data demo tidak otomatis diimpor ke akun online.

## Supabase

1. Buat/pilih project Supabase untuk ARMSys.
2. Jalankan `supabase/schema.sql` sekali pada project kosong melalui SQL Editor. Jangan jalankan ulang pada project dengan tabel bernama sama tanpa meninjau migrasi.
3. Buat akun pemilik dan penandatangan melalui Authentication > Users. Verifikasi email pengguna. Untuk tahap awal pendaftaran mandiri tidak disediakan.
4. Isi URL project dan **publishable key** di `public/config.js` untuk preview lokal. Jangan gunakan service_role atau database password di frontend.
5. Login di Pengaturan. Saat mengunggah, isi email akun penandatangan. Hanya akun tersebut yang dapat menandatangani. Pemilik dapat melihat dan mengunduh.

Dokumen dan tanda tangan bersifat privat. RLS membatasi peserta dokumen; signed PDF disimpan di bucket privat dan status hanya diubah melalui RPC terautentikasi. Event created/signed dicatat pada tabel document_events. Tanda tangan berupa gambar pada PDF, bukan sertifikat digital PSrE. Integritas isi PDF hasil belum diverifikasi oleh server.

## GitHub Pages

1. Buat repo `armsys` pada akun GitHub tujuan. Untuk Pages pada paket gratis, gunakan repo public setelah meninjau source yang akan dipublikasikan. Folder source-module tidak termasuk deployment/repo.
2. Upload/commit isi project (termasuk `.github/workflows/pages.yml` dan `public/vendor`) ke branch main.
3. Settings > Pages > Source: GitHub Actions.
4. Settings > Secrets and variables > Actions > Variables: `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY`.
5. Push main atau jalankan workflow Deploy ARMSys. Workflow hanya mempublikasikan folder public.
6. Uji dengan dua akun: owner mengunggah, signer masuk dari tautan dokumen, menandatangani, owner mengunduh hasil. Akun ketiga tidak boleh membaca dokumen.

## Ruang lingkup dan batas migrasi

Berfungsi lokal: dashboard/statistik dari data, pencarian/filter, unggah PDF, tanda tangan/paraf canvas, model tersimpan, preview multipage, penempatan dan ukuran tanda tangan, PDF hasil, ekspor CSV, dan riwayat selesai. Supabase adapter dan RLS disiapkan tetapi harus diuji pada project live setelah akses tersedia.

Belum dimigrasikan dari modul asal: pengiriman email otomatis, otorisasi publik tanpa login, rantai penandatangan, direktori user/company/cluster, template korespondensi, folder Google Drive, dan audit lengkap dari sistem lama. Tidak ada endpoint project asal yang dipanggil. PDF terenkripsi ditolak; halaman berotasi ditolak saat signing agar posisi tidak salah. Normalisasikan rotasi sebelum upload. Jangan menganggap versi ini memiliki seluruh fitur modul Apps Script asal.

Referensi: [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
