<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { getDb } from '../utils/db'
import { ElMessage } from 'element-plus'
import * as XLSX from 'xlsx'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const yearId = Number(route.params.yearId)
const currentYear = ref('')

const skpds = ref([])
const loading = ref(false)
const importing = ref(false)

const selectedSkpdId = ref(null)
const selectedMonth = ref(null)
const parsedRows = ref([])
const fileName = ref('')

const MONTHS = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember','THR','Gaji 13']

const STATUS_ASN = { 1: 'PNS', 2: 'PPPK', 3: 'CPNS' }
const TIPE_JABATAN = { 1: 'Struktural', 2: 'Fungsional', 3: 'Fungsional Umum' }
const STATUS_NIKAH = { 1: 'Menikah', 2: 'Belum/Cerai' }

const fmt = (n) => (Number(n) || 0).toLocaleString('id-ID')

// Mapping header Excel → key internal
const COLUMN_MAP = [
  'nip_pegawai', 'nama_pegawai', 'nik_pegawai', 'npwp_pegawai', 'tanggal_lahir',
  'tipe_jabatan', 'nama_jabatan', 'eselon', 'status_asn', 'golongan',
  'masa_kerja_golongan', 'alamat', 'status_pernikahan', 'jumlah_istri_suami',
  'jumlah_anak', 'jumlah_tanggungan', 'pasangan_pns', 'nip_pasangan',
  'kode_bank', 'nama_bank', 'nomor_rekening_bank_pegawai',
  'gaji_pokok', 'perhitungan_suami_istri', 'perhitungan_anak', 'tunjangan_keluarga',
  'tunjangan_jabatan', 'tunjangan_fungsional', 'tunjangan_fungsional_umum',
  'tunjangan_beras', 'tunjangan_pph', 'pembulatan_gaji',
  'iuran_jaminan_kesehatan', 'iuran_jaminan_kecelakaan_kerja', 'iuran_jaminan_kematian',
  'iuran_simpanan_tapera', 'iuran_pensiun', 'tunjangan_khusus_papua',
  'tunjangan_jaminan_hari_tua', 'potongan_iwp', 'potongan_pph_21',
  'zakat', 'bulog',
  'jumlah_gaji_dan_tunjangan', 'jumlah_potongan', 'jumlah_ditransfer'
]

const NUMERIC_FIELDS = new Set([
  'tipe_jabatan','status_asn','status_pernikahan',
  'jumlah_istri_suami','jumlah_anak','jumlah_tanggungan',
  'gaji_pokok','perhitungan_suami_istri','perhitungan_anak','tunjangan_keluarga',
  'tunjangan_jabatan','tunjangan_fungsional','tunjangan_fungsional_umum',
  'tunjangan_beras','tunjangan_pph','pembulatan_gaji',
  'iuran_jaminan_kesehatan','iuran_jaminan_kecelakaan_kerja','iuran_jaminan_kematian',
  'iuran_simpanan_tapera','iuran_pensiun','tunjangan_khusus_papua',
  'tunjangan_jaminan_hari_tua','potongan_iwp','potongan_pph_21',
  'zakat','bulog','jumlah_gaji_dan_tunjangan','jumlah_potongan','jumlah_ditransfer'
])

const canImport = computed(() => selectedSkpdId.value && selectedMonth.value && parsedRows.value.length > 0)

async function loadSkpds() {
  loading.value = true
  try {
    const db = await getDb()
    skpds.value = await db.select(
      'SELECT * FROM skpds WHERE fiscal_year_id = ? ORDER BY kode ASC',
      [yearId]
    )
    const fy = await db.select('SELECT year FROM fiscal_years WHERE id = ?', [yearId])
    if (fy.length) currentYear.value = fy[0].year
  } finally {
    loading.value = false
  }
}

function handleFileChange(uploadFile) {
  const file = uploadFile.raw
  if (!file) return
  fileName.value = file.name
  parsedRows.value = []

  const reader = new FileReader()
  reader.onload = (e) => {
    try {
      const wb = XLSX.read(e.target.result, { type: 'array' })
      const ws = wb.Sheets[wb.SheetNames[0]]
      const raw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' })

      // Cari baris header (yang ada "NIP" atau "Nama") — skip baris keterangan di atas
      let dataStartRow = 0
      for (let i = 0; i < Math.min(raw.length, 10); i++) {
        const row = raw[i]
        if (row.some(cell => String(cell).toLowerCase().includes('nip') || String(cell).toLowerCase().includes('nama pegawai'))) {
          dataStartRow = i + 1
          break
        }
      }

      const rows = []
      for (let i = dataStartRow; i < raw.length; i++) {
        const row = raw[i]
        // Skip baris kosong
        if (!row[0] && !row[1]) continue

        const obj = {}
        COLUMN_MAP.forEach((key, idx) => {
          const val = row[idx] ?? ''
          obj[key] = NUMERIC_FIELDS.has(key) ? (Math.round(Number(val)) || 0) : String(val).trim()
        })
        rows.push(obj)
      }

      parsedRows.value = rows
      ElMessage.success(`${rows.length} baris berhasil dibaca dari file`)
    } catch (err) {
      ElMessage.error('Gagal membaca file: ' + err.message)
    }
  }
  reader.readAsArrayBuffer(file)

  // Cegah el-upload menyimpan file di list-nya
  return false
}

async function doImport() {
  if (!canImport.value) return
  importing.value = true
  try {
    const db = await getDb()
    const fields = COLUMN_MAP
    let inserted = 0, updated = 0

    for (const row of parsedRows.value) {
      const values = fields.map(f => row[f] ?? null)
      const result = await db.execute(`
        INSERT INTO sipd_pegawai
          (skpd_id, fiscal_year_id, month, ${fields.join(', ')}, uploaded_by)
        VALUES
          (?, ?, ?, ${fields.map(() => '?').join(', ')}, ?)
        ON CONFLICT(skpd_id, fiscal_year_id, month, nip_pegawai) DO UPDATE SET
          ${fields.filter(f => f !== 'nip_pegawai').map(f => `${f} = excluded.${f}`).join(', ')},
          uploaded_by = excluded.uploaded_by,
          uploaded_at = datetime('now', 'localtime')
      `, [selectedSkpdId.value, yearId, selectedMonth.value, ...values, auth.user.id])

      if (result.rowsAffected === 1) inserted++
      else updated++
    }

    ElMessage.success(`Import selesai: ${inserted} baru, ${updated} diperbarui`)
    parsedRows.value = []
    fileName.value = ''
  } catch (err) {
    ElMessage.error('Gagal import: ' + err)
  } finally {
    importing.value = false
  }
}

function resetFile() {
  parsedRows.value = []
  fileName.value = ''
}

onMounted(loadSkpds)
</script>

<template>
  <div>
    <el-page-header @back="router.push(`/tahun/${yearId}`)">
      <template #content>Upload Data SIPD — Tahun {{ currentYear }}</template>
    </el-page-header>

    <el-card style="margin-top: 24px;">
      <template #header>
        <span style="font-weight: 600;">Pengaturan Import</span>
      </template>

      <el-form label-width="140px" label-position="right" size="default">
        <el-form-item label="SKPD">
          <el-select
            v-model="selectedSkpdId"
            placeholder="Pilih SKPD"
            style="width: 380px;"
            filterable
          >
            <el-option
              v-for="s in skpds"
              :key="s.id"
              :label="`${s.kode} — ${s.nama}`"
              :value="s.id"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="Bulan">
          <el-select v-model="selectedMonth" placeholder="Pilih bulan" style="width: 200px;">
            <el-option
              v-for="(m, i) in MONTHS"
              :key="i+1"
              :label="m"
              :value="i+1"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="File Excel">
          <div style="display: flex; align-items: center; gap: 12px;">
            <el-upload
              :auto-upload="false"
              :show-file-list="false"
              accept=".xlsx,.xls"
              :on-change="handleFileChange"
            >
              <el-button type="primary" plain>Pilih File (.xlsx / .xls)</el-button>
            </el-upload>
            <span v-if="fileName" style="font-size: 13px; color: #606266;">
              {{ fileName }}
              <el-button link type="danger" size="small" @click="resetFile">✕</el-button>
            </span>
          </div>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- Preview -->
    <el-card v-if="parsedRows.length > 0" style="margin-top: 16px;">
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span style="font-weight: 600;">
            Preview Data
            <el-tag size="small" style="margin-left: 8px;">{{ parsedRows.length }} pegawai</el-tag>
          </span>
          <el-button
            type="primary"
            :loading="importing"
            :disabled="!canImport"
            @click="doImport"
          >
            Import ke Database
          </el-button>
        </div>
      </template>

      <el-table
        :data="parsedRows.slice(0, 50)"
        stripe
        border
        size="small"
        style="width: 100%;"
        max-height="480"
      >
        <el-table-column label="NIP" prop="nip_pegawai" width="160" fixed />
        <el-table-column label="Nama" prop="nama_pegawai" min-width="180" fixed />
        <el-table-column label="Status ASN" width="90">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status_asn === 1 ? 'primary' : row.status_asn === 2 ? 'warning' : 'info'">
              {{ STATUS_ASN[row.status_asn] ?? '-' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="Golongan" prop="golongan" width="90" />
        <el-table-column label="Jabatan" width="100">
          <template #default="{ row }">{{ TIPE_JABATAN[row.tipe_jabatan] ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="Nama Jabatan" prop="nama_jabatan" min-width="200" />
        <el-table-column label="Status Nikah" width="110">
          <template #default="{ row }">{{ STATUS_NIKAH[row.status_pernikahan] ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="Gaji Pokok" width="130" align="right">
          <template #default="{ row }">{{ fmt(row.gaji_pokok) }}</template>
        </el-table-column>
        <el-table-column label="Tunjangan Keluarga" width="150" align="right">
          <template #default="{ row }">{{ fmt(row.tunjangan_keluarga) }}</template>
        </el-table-column>
        <el-table-column label="Jml Gaji & Tunjangan" width="160" align="right">
          <template #default="{ row }">{{ fmt(row.jumlah_gaji_dan_tunjangan) }}</template>
        </el-table-column>
        <el-table-column label="Jml Potongan" width="130" align="right">
          <template #default="{ row }">{{ fmt(row.jumlah_potongan) }}</template>
        </el-table-column>
        <el-table-column label="Ditransfer" width="130" align="right">
          <template #default="{ row }">{{ fmt(row.jumlah_ditransfer) }}</template>
        </el-table-column>
        <el-table-column label="Bank" prop="nama_bank" width="140" />
        <el-table-column label="No. Rekening" prop="nomor_rekening_bank_pegawai" width="160" />
      </el-table>

      <div v-if="parsedRows.length > 50" style="margin-top: 8px; font-size: 12px; color: #909399; text-align: center;">
        Menampilkan 50 dari {{ parsedRows.length }} baris. Semua baris akan diimport.
      </div>
    </el-card>
  </div>
</template>
