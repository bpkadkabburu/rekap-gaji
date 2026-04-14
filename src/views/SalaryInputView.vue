<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { getDb } from '../utils/db'
import { ElMessage } from 'element-plus'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const yearId = Number(route.params.yearId)
const skpdId = Number(route.params.skpdId)

const skpd = ref(null)
const filledData = ref({}) // { 'month_type': true }
const loading = ref(false)

const dialogVisible = ref(false)
const activeTab = ref('PNS')
const selectedMonth = ref(null)
const saving = ref(false)

const MONTHS = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember']

const EMPLOYEE_TYPES = computed(() => {
  const types = ['PNS', 'PPPK']
  if (skpd.value?.has_pejabat_negara) types.push('KDH_WKDH')
  return types
})

function emptyAsn() {
  return {
    gaji_pokok: 0, tunjangan_istri: 0, tunjangan_anak: 0,
    tunjangan_jabatan: 0, tunjangan_fungsional: 0, tunjangan_fungsional_khusus: 0,
    tunjangan_fungsional_umum: 0, tunjangan_beras: 0, tunjangan_pph: 0,
    tunjangan_bpjs: 0, tunjangan_jkk: 0, tunjangan_jkm: 0, pembulatan: 0
  }
}

function emptyKdh() {
  return {
    gaji_pokok: 0, tunjangan_istri: 0, tunjangan_anak: 0,
    tunjangan_jabatan: 0, tunjangan_beras: 0, tunjangan_pph: 0,
    tunjangan_bpjs: 0, tunjangan_jkk: 0, tunjangan_jkm: 0, pembulatan: 0
  }
}

const formData = ref({ PNS: emptyAsn(), PPPK: emptyAsn(), KDH_WKDH: emptyKdh() })

async function loadData() {
  loading.value = true
  try {
    const db = await getDb()
    const skpdResult = await db.select('SELECT * FROM skpds WHERE id = ?', [skpdId])
    skpd.value = skpdResult[0]

    const rows = await db.select(
      'SELECT month, employee_type FROM salary_recap WHERE skpd_id = ? AND fiscal_year_id = ?',
      [skpdId, yearId]
    )
    const map = {}
    for (const r of rows) map[`${r.month}_${r.employee_type}`] = true
    filledData.value = map
  } finally {
    loading.value = false
  }
}

function isFilled(month, type) {
  return !!filledData.value[`${month}_${type}`]
}

async function openMonth(month) {
  selectedMonth.value = month
  activeTab.value = 'PNS'
  formData.value = { PNS: emptyAsn(), PPPK: emptyAsn(), KDH_WKDH: emptyKdh() }

  try {
    const db = await getDb()
    const rows = await db.select(
      'SELECT * FROM salary_recap WHERE skpd_id = ? AND fiscal_year_id = ? AND month = ?',
      [skpdId, yearId, month]
    )
    for (const row of rows) {
      const type = row.employee_type
      if (!formData.value[type]) continue
      Object.keys(formData.value[type]).forEach(k => {
        if (row[k] !== undefined) formData.value[type][k] = row[k]
      })
    }
  } catch (e) {
    ElMessage.error('Gagal memuat data')
  }

  dialogVisible.value = true
}

async function saveMonth() {
  saving.value = true
  try {
    const db = await getDb()
    for (const type of EMPLOYEE_TYPES.value) {
      const d = formData.value[type]
      const fields = Object.keys(d)
      const values = Object.values(d)

      await db.execute(`
        INSERT INTO salary_recap
          (skpd_id, fiscal_year_id, month, employee_type, ${fields.join(', ')}, created_by, updated_by)
        VALUES
          (?, ?, ?, ?, ${fields.map(() => '?').join(', ')}, ?, ?)
        ON CONFLICT(skpd_id, fiscal_year_id, month, employee_type) DO UPDATE SET
          ${fields.map(f => `${f} = excluded.${f}`).join(', ')},
          updated_by = excluded.updated_by
      `, [skpdId, yearId, selectedMonth.value, type, ...values, auth.user.id, auth.user.id])
    }

    // Refresh filled status
    const rows = await db.select(
      'SELECT month, employee_type FROM salary_recap WHERE skpd_id = ? AND fiscal_year_id = ?',
      [skpdId, yearId]
    )
    const map = {}
    for (const r of rows) map[`${r.month}_${r.employee_type}`] = true
    filledData.value = map

    ElMessage.success(`Data ${MONTHS[selectedMonth.value - 1]} berhasil disimpan`)
    dialogVisible.value = false
  } catch (e) {
    ElMessage.error('Gagal menyimpan: ' + e)
  } finally {
    saving.value = false
  }
}

// Computed totals
function total(type) {
  const d = formData.value[type]
  return Object.values(d).reduce((a, b) => a + (Number(b) || 0), 0)
}

function tunjKeluarga(type) {
  const d = formData.value[type]
  return (Number(d.tunjangan_istri) || 0) + (Number(d.tunjangan_anak) || 0)
}

function tunjFungsionalTotal(type) {
  const d = formData.value[type]
  return (Number(d.tunjangan_fungsional) || 0) + (Number(d.tunjangan_fungsional_khusus) || 0)
}

const fmt = (n) => (Number(n) || 0).toLocaleString('id-ID')

// Open month from query param if provided
onMounted(async () => {
  await loadData()
  const bulan = Number(route.query.bulan)
  if (bulan >= 1 && bulan <= 12) openMonth(bulan)
})
</script>

<template>
  <div style="max-width: 960px; margin: 40px auto;">
    <el-page-header @back="router.push(`/tahun/${yearId}/skpd`)">
      <template #content>
        <span v-if="skpd">{{ skpd.kode }} — {{ skpd.nama }}</span>
      </template>
    </el-page-header>

    <div v-loading="loading" style="margin-top: 24px;">
      <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px;">
        <el-card
          v-for="m in 12"
          :key="m"
          shadow="hover"
          style="cursor: pointer;"
          :body-style="{ padding: '16px' }"
          @click="openMonth(m)"
        >
          <div style="font-weight: 600; font-size: 15px; margin-bottom: 8px;">
            {{ MONTHS[m - 1] }}
          </div>
          <div style="display: flex; flex-wrap: wrap; gap: 4px;">
            <el-tag
              v-for="type in EMPLOYEE_TYPES"
              :key="type"
              size="small"
              :type="isFilled(m, type) ? 'success' : 'info'"
            >
              {{ type === 'KDH_WKDH' ? 'KDH' : type }}
              {{ isFilled(m, type) ? '✓' : '–' }}
            </el-tag>
          </div>
        </el-card>
      </div>
    </div>

    <!-- Dialog Form Input -->
    <el-dialog
      v-model="dialogVisible"
      :title="`${MONTHS[selectedMonth - 1]} — ${skpd?.nama ?? ''}`"
      width="680px"
      destroy-on-close
    >
      <el-tabs v-model="activeTab">
        <el-tab-pane
          v-for="type in EMPLOYEE_TYPES"
          :key="type"
          :label="type === 'KDH_WKDH' ? 'KDH/WKDH' : type"
          :name="type"
        >
          <div style="max-height: 60vh; overflow-y: auto; padding-right: 8px;">
            <el-form label-position="right" label-width="230px" size="small">

              <!-- Gaji Pokok -->
              <el-form-item label="Gaji Pokok">
                <el-input-number v-model="formData[type].gaji_pokok" :min="0" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>

              <!-- Tunjangan Keluarga -->
              <el-divider content-position="left" style="margin: 8px 0;">Tunjangan Keluarga</el-divider>
              <el-form-item label="Tunjangan Istri">
                <el-input-number v-model="formData[type].tunjangan_istri" :min="0" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>
              <el-form-item label="Tunjangan Anak">
                <el-input-number v-model="formData[type].tunjangan_anak" :min="0" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>
              <el-form-item label="= Tunjangan Keluarga">
                <span style="color: #409eff; font-weight: 600;">Rp {{ fmt(tunjKeluarga(type)) }}</span>
              </el-form-item>

              <!-- Tunjangan Jabatan -->
              <el-divider content-position="left" style="margin: 8px 0;">Tunjangan Jabatan & Fungsional</el-divider>
              <el-form-item label="Tunjangan Jabatan">
                <el-input-number v-model="formData[type].tunjangan_jabatan" :min="0" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>

              <!-- Fungsional — hanya untuk PNS/PPPK -->
              <template v-if="type !== 'KDH_WKDH'">
                <el-form-item label="Tunjangan Fungsional">
                  <el-input-number v-model="formData[type].tunjangan_fungsional" :min="0" :controls="false" style="width: 100%"
                    :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                    :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
                </el-form-item>
                <el-form-item label="Tunjangan Fungsional Khusus">
                  <el-input-number v-model="formData[type].tunjangan_fungsional_khusus" :min="0" :controls="false" style="width: 100%"
                    :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                    :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
                </el-form-item>
                <el-form-item label="= Total Tunjangan Fungsional">
                  <span style="color: #409eff; font-weight: 600;">Rp {{ fmt(tunjFungsionalTotal(type)) }}</span>
                </el-form-item>
                <el-form-item label="Tunjangan Fungsional Umum">
                  <el-input-number v-model="formData[type].tunjangan_fungsional_umum" :min="0" :controls="false" style="width: 100%"
                    :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                    :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
                </el-form-item>
              </template>

              <!-- Tunjangan lainnya -->
              <el-divider content-position="left" style="margin: 8px 0;">Tunjangan Lainnya</el-divider>
              <el-form-item label="Tunjangan Beras">
                <el-input-number v-model="formData[type].tunjangan_beras" :min="0" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>
              <el-form-item label="Tunjangan PPh/Pajak">
                <el-input-number v-model="formData[type].tunjangan_pph" :min="0" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>

              <!-- Jaminan -->
              <el-divider content-position="left" style="margin: 8px 0;">Jaminan</el-divider>
              <el-form-item label="Iuran Jaminan Kesehatan (BPJS)">
                <el-input-number v-model="formData[type].tunjangan_bpjs" :min="0" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>
              <el-form-item label="Iuran JKK">
                <el-input-number v-model="formData[type].tunjangan_jkk" :min="0" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>
              <el-form-item label="Iuran JKM">
                <el-input-number v-model="formData[type].tunjangan_jkm" :min="0" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>

              <!-- Pembulatan -->
              <el-divider style="margin: 8px 0;" />
              <el-form-item label="Pembulatan">
                <el-input-number v-model="formData[type].pembulatan" :controls="false" style="width: 100%"
                  :formatter="v => v ? Number(v).toLocaleString('id-ID') : '0'"
                  :parser="v => parseInt(v.replace(/\./g, '')) || 0" />
              </el-form-item>

              <!-- Grand Total -->
              <el-form-item label="TOTAL">
                <span style="color: #67c23a; font-weight: 700; font-size: 15px;">
                  Rp {{ fmt(total(type)) }}
                </span>
              </el-form-item>

            </el-form>
          </div>
        </el-tab-pane>
      </el-tabs>

      <template #footer>
        <el-button @click="dialogVisible = false">Batal</el-button>
        <el-button type="primary" :loading="saving" @click="saveMonth">Simpan Semua Tab</el-button>
      </template>
    </el-dialog>
  </div>
</template>
