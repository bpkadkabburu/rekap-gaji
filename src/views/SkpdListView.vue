<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { getDb } from '../utils/db'
import { ElMessage, ElMessageBox } from 'element-plus'
import * as XLSX from 'xlsx'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const yearId = route.params.yearId
const currentYear = ref('')
const skpds = ref([])
const filledMonths = ref({}) // { skpd_id: { PNS: Set<month>, PPPK: Set<month>, ... } }
const loading = ref(false)

const dialogVisible = ref(false)
const isEdit = ref(false)
const formLoading = ref(false)
const form = ref({ id: null, kode: '', nama: '' })

const MONTHS_SHORT = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ags','Sep','Okt','Nov','Des','THR','G13']
const TOTAL_PERIODS = 14

// --- Upload Excel ---
const uploadDialogVisible = ref(false)
const uploadPreview = ref([])
const uploadLoading = ref(false)
const uploadFileRef = ref(null)

// --- Clone dari tahun sebelumnya ---
const cloneDialogVisible = ref(false)
const cloneLoading = ref(false)
const cloneSourceYearId = ref(null)
const availableYears = ref([]) // [{ id, year, skpd_count }]

async function loadData() {
  loading.value = true
  try {
    const db = await getDb()
    skpds.value = await db.select(
      'SELECT * FROM skpds WHERE fiscal_year_id = ? ORDER BY kode ASC',
      [yearId]
    )
    const fy = await db.select('SELECT year FROM fiscal_years WHERE id = ?', [yearId])
    if (fy.length) currentYear.value = fy[0].year
    const filled = await db.select(
      'SELECT skpd_id, month, employee_type FROM salary_recap WHERE fiscal_year_id = ?',
      [yearId]
    )
    const map = {}
    for (const row of filled) {
      if (!map[row.skpd_id]) map[row.skpd_id] = {}
      if (!map[row.skpd_id][row.employee_type]) map[row.skpd_id][row.employee_type] = new Set()
      map[row.skpd_id][row.employee_type].add(row.month)
    }
    filledMonths.value = map
  } finally {
    loading.value = false
  }
}

const EMPLOYEE_TYPES = ['PNS', 'PPPK']

function isFilled(skpdId, type, month) {
  return filledMonths.value[skpdId]?.[type]?.has(month) ?? false
}

function filledCount(skpdId, type) {
  return filledMonths.value[skpdId]?.[type]?.size ?? 0
}

function openAdd() {
  isEdit.value = false
  form.value = { id: null, kode: '', nama: '' }
  dialogVisible.value = true
}

function openEdit(row) {
  isEdit.value = true
  form.value = { id: row.id, kode: row.kode, nama: row.nama }
  dialogVisible.value = true
}

async function saveSkpd() {
  if (!form.value.kode.trim() || !form.value.nama.trim()) {
    ElMessage.warning('Kode dan nama wajib diisi')
    return
  }
  formLoading.value = true
  try {
    const db = await getDb()
    if (isEdit.value) {
      await db.execute(
        'UPDATE skpds SET kode = ?, nama = ? WHERE id = ?',
        [form.value.kode.trim(), form.value.nama.trim(), form.value.id]
      )
      ElMessage.success('SKPD berhasil diperbarui')
    } else {
      await db.execute(
        'INSERT INTO skpds (fiscal_year_id, kode, nama) VALUES (?, ?, ?)',
        [yearId, form.value.kode.trim(), form.value.nama.trim()]
      )
      ElMessage.success('SKPD berhasil ditambahkan')
    }
    dialogVisible.value = false
    await loadData()
  } catch {
    ElMessage.error('Kode sudah digunakan atau terjadi kesalahan')
  } finally {
    formLoading.value = false
  }
}

async function deleteSkpd(row) {
  try {
    await ElMessageBox.confirm(
      `Hapus SKPD "${row.nama}"? Data rekap gaji terkait juga akan terhapus.`,
      'Konfirmasi Hapus',
      { type: 'warning', confirmButtonText: 'Hapus', cancelButtonText: 'Batal' }
    )
    const db = await getDb()
    await db.execute('DELETE FROM salary_recap WHERE skpd_id = ?', [row.id])
    await db.execute('DELETE FROM skpds WHERE id = ?', [row.id])
    ElMessage.success('SKPD berhasil dihapus')
    await loadData()
  } catch {
    // user cancel
  }
}

// ============================================================
// Upload Excel
// ============================================================

function openUploadDialog() {
  uploadPreview.value = []
  uploadDialogVisible.value = true
}

function handleExcelFile(file) {
  const reader = new FileReader()
  reader.onload = (e) => {
    try {
      const wb = XLSX.read(e.target.result, { type: 'array' })
      const ws = wb.Sheets[wb.SheetNames[0]]
      const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' })

      if (rows.length === 0) {
        ElMessage.error('File Excel kosong')
        return
      }

      // Deteksi header: cari baris yang mengandung kata "kode" dan "nama"
      let dataStartRow = 0
      let kodeCol = 0
      let namaCol = 1

      for (let i = 0; i < Math.min(rows.length, 5); i++) {
        const lower = rows[i].map(c => String(c).toLowerCase().trim())
        const kodeIdx = lower.findIndex(c => c.includes('kode'))
        const namaIdx = lower.findIndex(c => c.includes('nama'))
        if (kodeIdx !== -1 && namaIdx !== -1) {
          kodeCol = kodeIdx
          namaCol = namaIdx
          dataStartRow = i + 1
          break
        }
      }

      const parsed = []
      for (let i = dataStartRow; i < rows.length; i++) {
        const kode = String(rows[i][kodeCol] ?? '').trim()
        const nama = String(rows[i][namaCol] ?? '').trim()
        if (kode && nama) {
          parsed.push({ kode, nama })
        }
      }

      if (parsed.length === 0) {
        ElMessage.error('Tidak ada data yang terbaca. Pastikan kolom Kode dan Nama tersedia.')
        return
      }

      uploadPreview.value = parsed
    } catch {
      ElMessage.error('Gagal membaca file Excel')
    }
  }
  reader.readAsArrayBuffer(file.raw ?? file)
  return false
}

async function doUploadImport() {
  if (uploadPreview.value.length === 0) return
  uploadLoading.value = true
  try {
    const db = await getDb()
    let inserted = 0, skipped = 0
    for (const row of uploadPreview.value) {
      try {
        await db.execute(
          'INSERT INTO skpds (fiscal_year_id, kode, nama) VALUES (?, ?, ?)',
          [yearId, row.kode, row.nama]
        )
        inserted++
      } catch {
        skipped++
      }
    }
    ElMessage.success(`Berhasil import ${inserted} SKPD${skipped > 0 ? `, ${skipped} dilewati (kode duplikat)` : ''}`)
    uploadDialogVisible.value = false
    await loadData()
  } finally {
    uploadLoading.value = false
  }
}

// ============================================================
// Clone dari tahun sebelumnya
// ============================================================

async function openCloneDialog() {
  cloneSourceYearId.value = null
  cloneDialogVisible.value = true
  const db = await getDb()
  // Ambil tahun lain yang punya SKPD, kecuali tahun aktif
  availableYears.value = await db.select(
    `SELECT fy.id, fy.year, COUNT(s.id) as skpd_count
     FROM fiscal_years fy
     JOIN skpds s ON s.fiscal_year_id = fy.id
     WHERE fy.id != ?
     GROUP BY fy.id
     ORDER BY fy.year DESC`,
    [yearId]
  )
}

async function doClone() {
  if (!cloneSourceYearId.value) {
    ElMessage.warning('Pilih tahun sumber terlebih dahulu')
    return
  }
  cloneLoading.value = true
  try {
    const db = await getDb()
    // Copy semua SKPD dari tahun sumber ke tahun ini, abaikan kode yang sudah ada
    await db.execute(
      `INSERT OR IGNORE INTO skpds (fiscal_year_id, kode, nama)
       SELECT ?, kode, nama FROM skpds WHERE fiscal_year_id = ?`,
      [yearId, cloneSourceYearId.value]
    )
    const result = await db.select(
      'SELECT COUNT(*) as total FROM skpds WHERE fiscal_year_id = ?',
      [yearId]
    )
    ElMessage.success(`Berhasil menyalin SKPD. Total sekarang: ${result[0].total} SKPD`)
    cloneDialogVisible.value = false
    await loadData()
  } finally {
    cloneLoading.value = false
  }
}

const selectedSourceYear = computed(() =>
  availableYears.value.find(y => y.id === cloneSourceYearId.value)
)

onMounted(loadData)
</script>

<template>
  <div>
    <el-page-header @back="router.push(`/tahun/${yearId}`)">
      <template #content>Data SKPD — Tahun {{ currentYear }}</template>
    </el-page-header>

    <el-card style="margin-top: 24px;">
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span>Daftar SKPD</span>
          <el-button v-if="auth.isSuperadmin && skpds.length > 0" type="primary" size="small" @click="openAdd">
            + Tambah SKPD
          </el-button>
        </div>
      </template>

      <!-- Empty state -->
      <div
        v-if="!loading && skpds.length === 0 && auth.isSuperadmin"
        style="padding: 40px 20px; text-align: center;"
      >
        <el-icon style="font-size: 48px; color: #c0c4cc; margin-bottom: 16px;"><Document /></el-icon>
        <p style="color: #909399; margin-bottom: 24px; font-size: 14px;">
          Belum ada data SKPD untuk tahun ini.<br>Pilih cara untuk menambahkan daftar SKPD.
        </p>
        <div style="display: flex; justify-content: center; gap: 16px; flex-wrap: wrap;">
          <el-card
            shadow="hover"
            style="width: 220px; cursor: pointer;"
            @click="openUploadDialog"
          >
            <div style="text-align: center; padding: 8px 0;">
              <el-icon style="font-size: 32px; color: #409eff; margin-bottom: 8px;"><Upload /></el-icon>
              <div style="font-weight: 600; margin-bottom: 4px;">Upload Excel</div>
              <div style="font-size: 12px; color: #909399;">Import dari file .xlsx<br>berisi kolom Kode & Nama</div>
            </div>
          </el-card>
          <el-card
            shadow="hover"
            style="width: 220px; cursor: pointer;"
            @click="openCloneDialog"
          >
            <div style="text-align: center; padding: 8px 0;">
              <el-icon style="font-size: 32px; color: #67c23a; margin-bottom: 8px;"><CopyDocument /></el-icon>
              <div style="font-weight: 600; margin-bottom: 4px;">Ambil dari Tahun Lain</div>
              <div style="font-size: 12px; color: #909399;">Salin daftar SKPD<br>dari tahun sebelumnya</div>
            </div>
          </el-card>
          <el-card
            shadow="hover"
            style="width: 220px; cursor: pointer;"
            @click="openAdd"
          >
            <div style="text-align: center; padding: 8px 0;">
              <el-icon style="font-size: 32px; color: #e6a23c; margin-bottom: 8px;"><Plus /></el-icon>
              <div style="font-weight: 600; margin-bottom: 4px;">Tambah Manual</div>
              <div style="font-size: 12px; color: #909399;">Input satu per satu<br>kode dan nama SKPD</div>
            </div>
          </el-card>
        </div>
      </div>

      <el-table v-else :data="skpds" v-loading="loading" stripe style="width: 100%">
        <el-table-column type="index" label="No" width="55" />
        <el-table-column prop="kode" label="Kode" width="130" />
        <el-table-column prop="nama" label="Nama SKPD" min-width="200" />
        <el-table-column label="Progress Bulan" min-width="300">
          <template #default="{ row }">
            <div style="display: flex; flex-direction: column; gap: 4px;">
              <div
                v-for="type in EMPLOYEE_TYPES"
                :key="type"
                style="display: flex; align-items: center; gap: 6px;"
              >
                <span style="font-size: 11px; color: #909399; width: 30px; flex-shrink: 0;">{{ type }}</span>
                <div style="display: flex; gap: 2px;">
                  <el-tooltip
                    v-for="m in TOTAL_PERIODS"
                    :key="m"
                    :content="MONTHS_SHORT[m-1]"
                    placement="top"
                  >
                    <span
                      :style="{
                        display: 'inline-block',
                        width: '14px',
                        height: '14px',
                        borderRadius: '2px',
                        background: isFilled(row.id, type, m) ? '#67c23a' : '#dcdfe6',
                        cursor: 'pointer'
                      }"
                      @click.stop="router.push(`/tahun/${yearId}/skpd/${row.id}?bulan=${m}`)"
                    />
                  </el-tooltip>
                </div>
                <span style="font-size: 11px; color: #909399;">{{ filledCount(row.id, type) }}/{{ TOTAL_PERIODS }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="Aksi" width="160" align="center">
          <template #default="{ row }">
            <el-button size="small" type="primary" @click="router.push(`/tahun/${yearId}/skpd/${row.id}`)">
              Input
            </el-button>
            <template v-if="auth.isSuperadmin">
              <el-button size="small" @click="openEdit(row)">Edit</el-button>
              <el-button size="small" type="danger" @click="deleteSkpd(row)" style="margin-top: 4px;">Hapus</el-button>
            </template>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- Dialog Tambah/Edit SKPD -->
    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? 'Edit SKPD' : 'Tambah SKPD'"
      width="420px"
      @closed="form = { id: null, kode: '', nama: '' }"
    >
      <el-form label-position="top">
        <el-form-item label="Kode SKPD">
          <el-input v-model="form.kode" placeholder="Contoh: 1.01.01" />
        </el-form-item>
        <el-form-item label="Nama SKPD">
          <el-input v-model="form.nama" placeholder="Contoh: Dinas Pendidikan" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">Batal</el-button>
        <el-button type="primary" :loading="formLoading" @click="saveSkpd">Simpan</el-button>
      </template>
    </el-dialog>

    <!-- Dialog Upload Excel -->
    <el-dialog
      v-model="uploadDialogVisible"
      title="Import SKPD dari Excel"
      width="640px"
      @closed="uploadPreview = []"
    >
      <el-alert type="info" :closable="false" style="margin-bottom: 16px;">
        <template #title>
          Format file Excel: dua kolom <strong>Kode</strong> dan <strong>Nama</strong>.
          Header baris pertama boleh ada atau tidak.
        </template>
      </el-alert>

      <el-upload
        drag
        :auto-upload="false"
        accept=".xlsx,.xls"
        :show-file-list="false"
        :on-change="handleExcelFile"
      >
        <el-icon style="font-size: 48px; color: #c0c4cc;"><Upload /></el-icon>
        <div style="margin-top: 8px; font-size: 14px; color: #606266;">
          Klik atau seret file Excel ke sini
        </div>
        <div style="font-size: 12px; color: #909399;">.xlsx / .xls</div>
      </el-upload>

      <div v-if="uploadPreview.length > 0" style="margin-top: 16px;">
        <div style="margin-bottom: 8px; font-size: 13px; color: #606266;">
          Preview: <strong>{{ uploadPreview.length }} SKPD</strong> akan diimport
        </div>
        <el-table :data="uploadPreview.slice(0, 10)" size="small" border style="width: 100%">
          <el-table-column type="index" label="No" width="50" />
          <el-table-column prop="kode" label="Kode" width="140" />
          <el-table-column prop="nama" label="Nama SKPD" />
        </el-table>
        <div v-if="uploadPreview.length > 10" style="margin-top: 6px; font-size: 12px; color: #909399; text-align: center;">
          ...dan {{ uploadPreview.length - 10 }} data lainnya
        </div>
      </div>

      <template #footer>
        <el-button @click="uploadDialogVisible = false">Batal</el-button>
        <el-button
          type="primary"
          :loading="uploadLoading"
          :disabled="uploadPreview.length === 0"
          @click="doUploadImport"
        >
          Import {{ uploadPreview.length > 0 ? `(${uploadPreview.length} SKPD)` : '' }}
        </el-button>
      </template>
    </el-dialog>

    <!-- Dialog Clone dari Tahun Lain -->
    <el-dialog
      v-model="cloneDialogVisible"
      title="Ambil SKPD dari Tahun Lain"
      width="480px"
      @closed="cloneSourceYearId = null"
    >
      <div v-if="availableYears.length === 0" style="text-align: center; padding: 24px; color: #909399;">
        Tidak ada tahun lain yang memiliki data SKPD.
      </div>
      <template v-else>
        <el-form label-position="top">
          <el-form-item label="Pilih tahun sumber">
            <el-select v-model="cloneSourceYearId" placeholder="-- Pilih tahun --" style="width: 100%">
              <el-option
                v-for="y in availableYears"
                :key="y.id"
                :value="y.id"
                :label="`Tahun ${y.year} (${y.skpd_count} SKPD)`"
              />
            </el-select>
          </el-form-item>
        </el-form>
        <el-alert
          v-if="selectedSourceYear"
          type="success"
          :closable="false"
        >
          <template #title>
            Akan menyalin <strong>{{ selectedSourceYear.skpd_count }} SKPD</strong>
            dari tahun <strong>{{ selectedSourceYear.year }}</strong>.
            SKPD dengan kode yang sudah ada akan dilewati.
          </template>
        </el-alert>
      </template>

      <template #footer>
        <el-button @click="cloneDialogVisible = false">Batal</el-button>
        <el-button
          type="primary"
          :loading="cloneLoading"
          :disabled="!cloneSourceYearId"
          @click="doClone"
        >
          Salin SKPD
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>
