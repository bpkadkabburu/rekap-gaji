-- Users
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('superadmin', 'user')),
    created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

-- Fiscal Years
CREATE TABLE IF NOT EXISTS fiscal_years (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    year INTEGER NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
);

-- SKPDs per Fiscal Year
CREATE TABLE IF NOT EXISTS skpds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fiscal_year_id INTEGER NOT NULL,
    kode TEXT NOT NULL,
    nama TEXT NOT NULL,
    has_pejabat_negara INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    FOREIGN KEY (fiscal_year_id) REFERENCES fiscal_years(id),
    UNIQUE(fiscal_year_id, kode)
);

-- Salary Recap
CREATE TABLE IF NOT EXISTS salary_recap (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    skpd_id INTEGER NOT NULL,
    fiscal_year_id INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 12),
    employee_type TEXT NOT NULL CHECK(employee_type IN ('PNS', 'PPPK', 'KDH_WKDH')),

    -- Komponen aktif
    gaji_pokok INTEGER NOT NULL DEFAULT 0,
    tunjangan_istri INTEGER NOT NULL DEFAULT 0,
    tunjangan_anak INTEGER NOT NULL DEFAULT 0,
    tunjangan_jabatan INTEGER NOT NULL DEFAULT 0,
    tunjangan_fungsional INTEGER NOT NULL DEFAULT 0,
    tunjangan_fungsional_khusus INTEGER NOT NULL DEFAULT 0,
    tunjangan_fungsional_umum INTEGER NOT NULL DEFAULT 0,
    tunjangan_beras INTEGER NOT NULL DEFAULT 0,
    tunjangan_pph INTEGER NOT NULL DEFAULT 0,
    tunjangan_bpjs INTEGER NOT NULL DEFAULT 0,
    tunjangan_jkk INTEGER NOT NULL DEFAULT 0,
    tunjangan_jkm INTEGER NOT NULL DEFAULT 0,
    pembulatan INTEGER NOT NULL DEFAULT 0,

    -- Locked 0 (ada di DB, belum dipakai)
    tunjangan_tkd INTEGER NOT NULL DEFAULT 0,
    tunjangan_terpencil INTEGER NOT NULL DEFAULT 0,
    tapera INTEGER NOT NULL DEFAULT 0,
    jaminan_hari_tua INTEGER NOT NULL DEFAULT 0,
    tunjangan_khusus INTEGER NOT NULL DEFAULT 0,
    zakat INTEGER NOT NULL DEFAULT 0,

    created_by INTEGER,
    updated_by INTEGER,
    created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),

    FOREIGN KEY (skpd_id) REFERENCES skpds(id),
    FOREIGN KEY (fiscal_year_id) REFERENCES fiscal_years(id),
    FOREIGN KEY (created_by) REFERENCES users(id),
    FOREIGN KEY (updated_by) REFERENCES users(id),
    UNIQUE(skpd_id, fiscal_year_id, month, employee_type)
);

-- Default superadmin (password: admin123 - harus diganti setelah login pertama)
INSERT OR IGNORE INTO users (username, password_hash, role)
VALUES ('admin', 'admin123', 'superadmin');
