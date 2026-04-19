<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { getDb } from '../utils/db'
import { ElMessage, ElMessageBox } from 'element-plus'

const router = useRouter()
const auth = useAuthStore()
const years = ref([])
const loading = ref(false)
const adding = ref(false)
const newYear = ref(new Date().getFullYear())

async function loadYears() {
  loading.value = true
  try {
    const db = await getDb()
    years.value = await db.select('SELECT * FROM fiscal_years ORDER BY year DESC')
  } finally {
    loading.value = false
  }
}

async function addYear() {
  try {
    const db = await getDb()
    await db.execute('INSERT INTO fiscal_years (year) VALUES (?)', [newYear.value])
    ElMessage.success(`Tahun ${newYear.value} berhasil ditambahkan`)
    adding.value = false
    await loadYears()
  } catch (e) {
    ElMessage.error('Tahun sudah ada atau gagal ditambahkan')
  }
}

function selectYear(year) {
  router.push(`/tahun/${year.id}`)
}

onMounted(loadYears)
</script>

<template>
  <div>
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
      <h2 style="font-size: 18px;">Pilih Tahun Anggaran</h2>
      <el-button v-if="auth.isSuperadmin" type="primary" @click="adding = true">
        + Tambah Tahun
      </el-button>
    </div>

    <el-dialog v-model="adding" title="Tambah Tahun Anggaran" width="300px">
      <el-input-number v-model="newYear" :min="2020" :max="2099" style="width: 100%" />
      <template #footer>
        <el-button @click="adding = false">Batal</el-button>
        <el-button type="primary" @click="addYear">Simpan</el-button>
      </template>
    </el-dialog>

    <el-skeleton :loading="loading" animated>
      <template #default>
        <el-empty v-if="years.length === 0" description="Belum ada tahun anggaran" />
        <div v-else style="display: flex; flex-direction: column; gap: 12px;">
          <el-card
            v-for="y in years"
            :key="y.id"
            shadow="hover"
            style="cursor: pointer;"
            @click="selectYear(y)"
          >
            <div style="display: flex; align-items: center; justify-content: space-between;">
              <span style="font-size: 22px; font-weight: 700;">{{ y.year }}</span>
              <el-icon><ArrowRight /></el-icon>
            </div>
          </el-card>
        </div>
      </template>
    </el-skeleton>
  </div>
</template>
