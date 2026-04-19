-- Data Pegawai dari SIPD Penatausahaan
CREATE TABLE IF NOT EXISTS sipd_pegawai (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Konteks upload
    skpd_id INTEGER NOT NULL,
    fiscal_year_id INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),

    -- Identitas pegawai
    nip_pegawai TEXT,
    nama_pegawai TEXT,
    nik_pegawai TEXT,
    npwp_pegawai TEXT,
    tanggal_lahir TEXT,

    -- Jabatan
    tipe_jabatan INTEGER,          -- 1=Struktural, 2=Fungsional, 3=Fungsional Umum
    nama_jabatan TEXT,
    eselon TEXT,
    status_asn INTEGER,            -- 1=PNS, 2=PPPK, 3=CPNS
    golongan TEXT,
    masa_kerja_golongan TEXT,

    -- Data personal
    alamat TEXT,
    status_pernikahan INTEGER,     -- 1=Menikah, 2=Belum/Cerai
    jumlah_istri_suami INTEGER,
    jumlah_anak INTEGER,
    jumlah_tanggungan INTEGER,
    pasangan_pns TEXT,             -- Ya / Tidak
    nip_pasangan TEXT,

    -- Rekening
    kode_bank TEXT,
    nama_bank TEXT,
    nomor_rekening_bank_pegawai TEXT,

    -- Komponen gaji
    gaji_pokok INTEGER DEFAULT 0,
    perhitungan_suami_istri INTEGER DEFAULT 0,
    perhitungan_anak INTEGER DEFAULT 0,
    tunjangan_keluarga INTEGER DEFAULT 0,
    tunjangan_jabatan INTEGER DEFAULT 0,
    tunjangan_fungsional INTEGER DEFAULT 0,
    tunjangan_fungsional_umum INTEGER DEFAULT 0,
    tunjangan_beras INTEGER DEFAULT 0,
    tunjangan_pph INTEGER DEFAULT 0,
    pembulatan_gaji INTEGER DEFAULT 0,

    -- Iuran / potongan
    iuran_jaminan_kesehatan INTEGER DEFAULT 0,
    iuran_jaminan_kecelakaan_kerja INTEGER DEFAULT 0,
    iuran_jaminan_kematian INTEGER DEFAULT 0,
    iuran_simpanan_tapera INTEGER DEFAULT 0,
    iuran_pensiun INTEGER DEFAULT 0,
    tunjangan_khusus_papua INTEGER DEFAULT 0,
    tunjangan_jaminan_hari_tua INTEGER DEFAULT 0,
    potongan_iwp INTEGER DEFAULT 0,
    potongan_pph_21 INTEGER DEFAULT 0,
    zakat INTEGER DEFAULT 0,
    bulog INTEGER DEFAULT 0,

    -- Rekapitulasi
    jumlah_gaji_dan_tunjangan INTEGER DEFAULT 0,
    jumlah_potongan INTEGER DEFAULT 0,
    jumlah_ditransfer INTEGER DEFAULT 0,

    -- Audit
    uploaded_by INTEGER,
    uploaded_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),

    FOREIGN KEY (skpd_id) REFERENCES skpds(id),
    FOREIGN KEY (fiscal_year_id) REFERENCES fiscal_years(id),
    FOREIGN KEY (uploaded_by) REFERENCES users(id),

    -- Satu pegawai satu entri per bulan per SKPD
    UNIQUE(skpd_id, fiscal_year_id, month, nip_pegawai)
);
