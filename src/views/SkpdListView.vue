<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { getDb } from '../utils/db'
import { ElMessage, ElMessageBox } from 'element-plus'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const yearId = route.params.yearId
const skpds = ref([])
const filledMonths = ref({}) // { skpd_id: Set<month> }
const loading = ref(false)

const dialogVisible = ref(false)
const isEdit = ref(false)
const formLoading = ref(false)
const form = ref({ id: null, kode: '', nama: '' })

const MONTHS_SHORT = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ags','Sep','Okt','Nov','Des']

async function loadData() {
  loading.value = true
  try {
    const db = await getDb()
    skpds.value = await db.select(
      'SELECT * FROM skpds WHERE fiscal_year_id = ? ORDER BY kode ASC',
      [yearId]
    )
    const filled = await db.select(
      'SELECT skpd_id, month FROM salary_recap WHERE fiscal_year_id = ? GROUP BY skpd_id, month',
      [yearId]
    )
    const map = {}
    for (const row of filled) {
      if (!map[row.skpd_id]) map[row.skpd_id] = new Set()
      map[row.skpd_id].add(row.month)
    }
    filledMonths.value = map
  } finally {
    loading.value = false
  }
}

function isFilled(skpdId, month) {
  return filledMonths.value[skpdId]?.has(month) ?? false
}

function filledCount(skpdId) {
  return filledMonths.value[skpdId]?.size ?? 0
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

onMounted(loadData)
</script>

<template>
  <div style="max-width: 1000px; margin: 40px auto;">
    <el-page-header @back="router.push(`/tahun/${yearId}`)">
      <template #content>Data SKPD</template>
    </el-page-header>

    <el-card style="margin-top: 24px;">
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span>Daftar SKPD</span>
          <el-button v-if="auth.isSuperadmin" type="primary" size="small" @click="openAdd">
            + Tambah SKPD
          </el-button>
        </div>
      </template>

      <el-table :data="skpds" v-loading="loading" stripe style="width: 100%">
        <el-table-column type="index" label="No" width="55" />
        <el-table-column prop="kode" label="Kode" width="130" />
        <el-table-column prop="nama" label="Nama SKPD" min-width="200" />
        <el-table-column label="Progress Bulan" min-width="260">
          <template #default="{ row }">
            <div style="display: flex; align-items: center; gap: 6px;">
              <div style="display: flex; gap: 2px;">
                <el-tooltip
                  v-for="m in 12"
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
                      background: isFilled(row.id, m) ? '#67c23a' : '#dcdfe6',
                      cursor: 'pointer'
                    }"
                    @click="router.push(`/tahun/${yearId}/skpd/${row.id}?bulan=${m}`)"
                  />
                </el-tooltip>
              </div>
              <span style="font-size: 12px; color: #909399;">
                {{ filledCount(row.id) }}/12
              </span>
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
  </div>
</template>
