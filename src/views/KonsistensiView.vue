<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getDb } from '../utils/db'

const route = useRoute()
const router = useRouter()

const yearId = Number(route.params.yearId)

const filterMonth = ref(null)
const skpds = ref([])
const manualData = ref({})  // { skpd_id: { PNS: {...}, PPPK: {...} } }
const sipdData = ref({})    // { skpd_id: { PNS: {...}, PPPK: {...}, CPNS: {...} } }
const loading = ref(false)

const MONTHS = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember']
const TYPES = ['PNS', 'PPPK']

const COLUMNS = [
  { key: 'gaji_pokok',               label: 'Gaji Pokok',          total: true  },
  { key: 'tunjangan_istri',          label: 'Tunj. Istri',         total: false },
  { key: 'tunjangan_anak',           label: 'Tunj. Anak',          total: false },
  { key: 'tunjangan_keluarga',       label: 'Tunj. Keluarga',      total: true  },
  { key: 'tunjangan_jabatan',        label: 'Tunj. Jabatan',       total: true  },
  { key: 'tunjangan_fungsional',     label: 'Tunj. Fungsional',    total: true  },
  { key: 'tunjangan_fungsional_umum',label: 'Tunj. Fungs. Umum',  total: true  },
  { key: 'tunjangan_beras',          label: 'Tunj. Beras',         total: true  },
  { key: 'tunjangan_pph',            label: 'Tunj. PPh',           total: true  },
  { key: 'tunjangan_bpjs',           label: 'BPJS Kes',            total: true  },
  { key: 'tunjangan_jkk',            label: 'JKK',                 total: true  },
  { key: 'tunjangan_jkm',            label: 'JKM',                 total: true  },
  { key: 'pembulatan',               label: 'Pembulatan',          total: true  },
]

const fmt = (n) => (Number(n) || 0).toLocaleString('id-ID')

function getVal(skpdId, type, key, source) {
  const map = source === 'manual' ? manualData.value : sipdData.value
  return Number(map[skpdId]?.[type]?.[key]) || 0
}

function grandTotalFor(skpdId, type, source) {
  const map = source === 'manual' ? manualData.value : sipdData.value
  const row = map[skpdId]?.[type]
  if (!row) return 0
  return COLUMNS.filter(c => c.total).reduce((sum, c) => sum + (Number(row[c.key]) || 0), 0)
}

function selisihCol(skpdId, type, key) {
  return getVal(skpdId, type, key, 'manual') - getVal(skpdId, type, key, 'sipd')
}

function selisihGrandTotal(skpdId, type) {
  return grandTotalFor(skpdId, type, 'manual') - grandTotalFor(skpdId, type, 'sipd')
}

// Total selisih PNS + PPPK gabungan per kolom
function totalSelisihCol(skpdId, key) {
  return TYPES.reduce((sum, type) => {
    if (!manualData.value[skpdId]?.[type] && !sipdData.value[skpdId]?.[type]) return sum
    return sum + selisihCol(skpdId, type, key)
  }, 0)
}

function totalSelisihGrand(skpdId) {
  return TYPES.reduce((sum, type) => {
    if (!manualData.value[skpdId]?.[type] && !sipdData.value[skpdId]?.[type]) return sum
    return sum + selisihGrandTotal(skpdId, type)
  }, 0)
}

function selisihColor(val) {
  return val === 0 ? '#67c23a' : '#f56c6c'
}

function hasData(skpdId, type) {
  return !!(manualData.value[skpdId]?.[type] || sipdData.value[skpdId]?.[type])
}

function hasCpns(skpdId) {
  return !!sipdData.value[skpdId]?.CPNS
}

// Hanya tampilkan SKPD yang punya data manual ATAU SIPD
const activeSkpds = computed(() => {
  if (!filterMonth.value) return []
  return skpds.value.filter(s =>
    manualData.value[s.id] || sipdData.value[s.id]
  )
})

async function loadSkpds() {
  const db = await getDb()
  skpds.value = await db.select(
    'SELECT * FROM skpds WHERE fiscal_year_id = ? ORDER BY kode ASC',
    [yearId]
  )
}

async function loadData() {
  if (!filterMonth.value) return
  loading.value = true
  try {
    const db = await getDb()

    // Manual
    const manualRows = await db.select(`
      SELECT
        skpd_id, employee_type,
        gaji_pokok,
        tunjangan_istri,
        tunjangan_anak,
        (tunjangan_istri + tunjangan_anak) AS tunjangan_keluarga,
        tunjangan_jabatan,
        (tunjangan_fungsional + tunjangan_fungsional_khusus) AS tunjangan_fungsional,
        tunjangan_fungsional_umum,
        tunjangan_beras,
        tunjangan_pph,
        tunjangan_bpjs,
        tunjangan_jkk,
        tunjangan_jkm,
        pembulatan
      FROM salary_recap
      WHERE fiscal_year_id = ? AND month = ?
    `, [yearId, filterMonth.value])

    const mMap = {}
    for (const r of manualRows) {
      if (!mMap[r.skpd_id]) mMap[r.skpd_id] = {}
      mMap[r.skpd_id][r.employee_type] = r
    }
    manualData.value = mMap

    // SIPD — semua status_asn (1=PNS, 2=PPPK, 3=CPNS)
    const sipdRows = await db.select(`
      SELECT
        skpd_id, status_asn,
        SUM(gaji_pokok)                      AS gaji_pokok,
        SUM(perhitungan_suami_istri)          AS tunjangan_istri,
        SUM(perhitungan_anak)                 AS tunjangan_anak,
        SUM(tunjangan_keluarga)               AS tunjangan_keluarga,
        SUM(tunjangan_jabatan)                AS tunjangan_jabatan,
        SUM(tunjangan_fungsional)             AS tunjangan_fungsional,
        SUM(tunjangan_fungsional_umum)        AS tunjangan_fungsional_umum,
        SUM(tunjangan_beras)                  AS tunjangan_beras,
        SUM(tunjangan_pph)                    AS tunjangan_pph,
        SUM(iuran_jaminan_kesehatan)          AS tunjangan_bpjs,
        SUM(iuran_jaminan_kecelakaan_kerja)   AS tunjangan_jkk,
        SUM(iuran_jaminan_kematian)           AS tunjangan_jkm,
        SUM(pembulatan_gaji)                  AS pembulatan
      FROM sipd_pegawai
      WHERE fiscal_year_id = ? AND month = ?
      GROUP BY skpd_id, status_asn
    `, [yearId, filterMonth.value])

    const sMap = {}
    const typeMap = { 1: 'PNS', 2: 'PPPK', 3: 'CPNS' }
    for (const r of sipdRows) {
      if (!sMap[r.skpd_id]) sMap[r.skpd_id] = {}
      const type = typeMap[r.status_asn]
      if (type) sMap[r.skpd_id][type] = r
    }
    sipdData.value = sMap

  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await loadSkpds()
})

async function onMonthChange() {
  await loadData()
}
</script>

<template>
  <div>
    <el-page-header @back="router.push(`/tahun/${yearId}`)">
      <template #content>Konsistensi Data — Tahun {{ yearId }}</template>
    </el-page-header>

    <!-- Filter -->
    <el-card style="margin-top: 20px;">
      <div style="display: flex; align-items: center; gap: 12px;">
        <span style="font-size: 13px; color: #606266;">Pilih Bulan:</span>
        <el-select
          v-model="filterMonth"
          placeholder="Pilih bulan"
          style="width: 180px;"
          @change="onMonthChange"
        >
          <el-option v-for="(m, i) in MONTHS" :key="i+1" :label="m" :value="i+1" />
        </el-select>
        <span v-if="filterMonth && !loading" style="font-size: 13px; color: #909399;">
          {{ activeSkpds.length }} SKPD dengan data
        </span>
      </div>
    </el-card>

    <el-empty
      v-if="!filterMonth"
      description="Pilih bulan untuk melihat perbandingan data"
      style="margin-top: 60px;"
    />

    <div v-else v-loading="loading" style="margin-top: 16px;">
      <el-empty
        v-if="!loading && activeSkpds.length === 0"
        description="Tidak ada data di bulan ini"
      />

      <el-card
        v-for="skpd in activeSkpds"
        :key="skpd.id"
        style="margin-bottom: 16px;"
      >
        <template #header>
          <span style="font-weight: 600;">{{ skpd.kode }} — {{ skpd.nama }}</span>
        </template>

        <!-- Satu container scroll horizontal untuk semua baris dalam SKPD ini -->
        <div style="overflow-x: auto;">
          <!-- Hitung lebar total: 110 + 100 + (13 kolom x 130) + 150 = 2050px -->
          <div style="min-width: 2050px;">

            <!-- Header -->
            <table class="k-table">
              <thead>
                <tr>
                  <th style="width: 110px;">Tipe</th>
                  <th style="width: 100px;">Sumber</th>
                  <th v-for="col in COLUMNS" :key="col.key" style="width: 130px; text-align: right;">{{ col.label }}</th>
                  <th style="width: 150px; text-align: right;">Grand Total</th>
                </tr>
              </thead>
            </table>

            <!-- PNS & PPPK -->
            <template v-for="type in TYPES" :key="type">
              <template v-if="hasData(skpd.id, type)">
                <table class="k-table">
                  <tbody>
                    <tr v-for="(src, idx) in ['manual', 'sipd', 'selisih']" :key="src" :class="src === 'selisih' ? 'row-selisih' : ''">
                      <td style="width: 110px; font-weight: 600;">{{ idx === 0 ? type : '' }}</td>
                      <td style="width: 100px;">
                        <span :style="{
                          fontSize: '12px',
                          color: src === 'manual' ? '#409eff' : src === 'sipd' ? '#e6a23c' : '#606266',
                          fontWeight: src === 'selisih' ? '600' : 'normal'
                        }">
                          {{ src === 'manual' ? 'Manual' : src === 'sipd' ? 'SIPD' : 'Selisih' }}
                        </span>
                      </td>
                      <template v-for="col in COLUMNS" :key="col.key">
                        <td style="width: 130px; text-align: right;">
                          <template v-if="src === 'manual'">
                            <span v-if="manualData[skpd.id]?.[type]">{{ fmt(getVal(skpd.id, type, col.key, 'manual')) }}</span>
                            <span v-else style="color: #c0c4cc;">—</span>
                          </template>
                          <template v-else-if="src === 'sipd'">
                            <span v-if="sipdData[skpd.id]?.[type]">{{ fmt(getVal(skpd.id, type, col.key, 'sipd')) }}</span>
                            <span v-else style="color: #c0c4cc;">—</span>
                          </template>
                          <template v-else>
                            <span
                              v-if="manualData[skpd.id]?.[type] && sipdData[skpd.id]?.[type]"
                              :style="{ color: selisihColor(selisihCol(skpd.id, type, col.key)), fontWeight: '600' }"
                            >{{ fmt(selisihCol(skpd.id, type, col.key)) }}</span>
                            <span v-else style="color: #c0c4cc;">—</span>
                          </template>
                        </td>
                      </template>
                      <!-- Grand Total -->
                      <td style="width: 150px; text-align: right;">
                        <template v-if="src === 'manual'">
                          <span v-if="manualData[skpd.id]?.[type]" style="font-weight: 700;">{{ fmt(grandTotalFor(skpd.id, type, 'manual')) }}</span>
                          <span v-else style="color: #c0c4cc;">—</span>
                        </template>
                        <template v-else-if="src === 'sipd'">
                          <span v-if="sipdData[skpd.id]?.[type]" style="font-weight: 700;">{{ fmt(grandTotalFor(skpd.id, type, 'sipd')) }}</span>
                          <span v-else style="color: #c0c4cc;">—</span>
                        </template>
                        <template v-else>
                          <span
                            v-if="manualData[skpd.id]?.[type] && sipdData[skpd.id]?.[type]"
                            :style="{ color: selisihColor(selisihGrandTotal(skpd.id, type)), fontWeight: '700', fontSize: '14px' }"
                          >{{ fmt(selisihGrandTotal(skpd.id, type)) }}</span>
                          <span v-else style="color: #c0c4cc;">—</span>
                        </template>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </template>
            </template>

            <!-- Total Selisih PNS + PPPK -->
            <table class="k-table">
              <tbody>
                <tr class="row-total-selisih">
                  <td style="width: 110px; font-weight: 700; font-size: 12px;">Total Selisih</td>
                  <td style="width: 100px; font-size: 11px; color: #909399;">PNS + PPPK</td>
                  <td v-for="col in COLUMNS" :key="col.key" style="width: 130px; text-align: right;">
                    <span :style="{ color: selisihColor(totalSelisihCol(skpd.id, col.key)), fontWeight: '700' }">
                      {{ fmt(totalSelisihCol(skpd.id, col.key)) }}
                    </span>
                  </td>
                  <td style="width: 150px; text-align: right;">
                    <span :style="{ color: selisihColor(totalSelisihGrand(skpd.id)), fontWeight: '700', fontSize: '14px' }">
                      {{ fmt(totalSelisihGrand(skpd.id)) }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>

            <!-- CPNS -->
            <template v-if="hasCpns(skpd.id)">
              <table class="k-table">
                <tbody>
                  <tr class="row-cpns">
                    <td style="width: 110px; font-weight: 600; color: #909399;">CPNS</td>
                    <td style="width: 100px; font-size: 12px; color: #e6a23c;">SIPD</td>
                    <td v-for="col in COLUMNS" :key="col.key" style="width: 130px; text-align: right;">
                      {{ fmt(getVal(skpd.id, 'CPNS', col.key, 'sipd')) }}
                    </td>
                    <td style="width: 150px; text-align: right; font-weight: 700; color: #909399;">
                      {{ fmt(grandTotalFor(skpd.id, 'CPNS', 'sipd')) }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </template>

          </div>
        </div>

      </el-card>
    </div>
  </div>
</template>

<style scoped>
.k-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.k-table th, .k-table td {
  border: 1px solid #ebeef5;
  padding: 6px 10px;
  white-space: nowrap;
}
.k-table thead th {
  background-color: #f5f7fa;
  font-weight: 600;
  color: #606266;
}
.k-table tbody tr:hover td {
  background-color: #f5f7fa;
}
.row-selisih td {
  background-color: #f5f7fa;
}
.row-total-selisih td {
  background-color: #ecf5ff;
}
.row-cpns td {
  background-color: #fdf6ec;
}
</style>
