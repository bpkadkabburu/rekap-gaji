-- Tambah dukungan bulan 13 (THR) dan bulan 14 (Gaji 13)
-- SQLite tidak bisa ALTER TABLE untuk mengubah CHECK constraint,
-- sehingga perlu recreate table.

PRAGMA foreign_keys = OFF;

CREATE TABLE salary_recap_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    skpd_id INTEGER NOT NULL,
    fiscal_year_id INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK(month BETWEEN 1 AND 14),
    employee_type TEXT NOT NULL CHECK(employee_type IN ('PNS', 'PPPK', 'KDH_WKDH')),

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

INSERT INTO salary_recap_new SELECT * FROM salary_recap;
DROP TABLE salary_recap;
ALTER TABLE salary_recap_new RENAME TO salary_recap;

PRAGMA foreign_keys = ON;
