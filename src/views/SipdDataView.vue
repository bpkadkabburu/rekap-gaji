<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getDb } from '../utils/db'

const route = useRoute()
const router = useRouter()

const yearId = Number(route.params.yearId)
const currentYear = ref('')

const skpds = ref([])
const rows = ref([])
const loading = ref(false)

const filterSkpdId = ref(null)
const filterMonth = ref(null)
const filterStatusAsn = ref(null)
const search = ref('')

const currentPage = ref(1)
const pageSize = ref(50)

const MONTHS = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember','THR','Gaji 13']
const STATUS_ASN = { 1: 'PNS', 2: 'PPPK', 3: 'CPNS' }
const TIPE_JABATAN = { 1: 'Struktural', 2: 'Fungsional', 3: 'Fungsional Umum' }
const STATUS_NIKAH = { 1: 'Menikah', 2: 'Belum/Cerai' }

const fmt = (n) => (Number(n) || 0).toLocaleString('id-ID')

const filtered = computed(() => {
  let data = rows.value
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    data = data.filter(r =>
      r.nama_pegawai?.toLowerCase().includes(q) ||
      r.nip_pegawai?.includes(q) ||
      r.nama_jabatan?.toLowerCase().includes(q)
    )
  }
  return data
})

const paginated = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value
  return filtered.value.slice(start, start + pageSize.value)
})

async function loadSkpds() {
  const db = await getDb()
  skpds.value = await db.select(
    'SELECT * FROM skpds WHERE fiscal_year_id = ? ORDER BY kode ASC',
    [yearId]
  )
  const fy = await db.select('SELECT year FROM fiscal_years WHERE id = ?', [yearId])
  if (fy.length) currentYear.value = fy[0].year
}

async function loadData() {
  if (!filterSkpdId.value || !filterMonth.value) {
    rows.value = []
    return
  }
  loading.value = true
  try {
    const db = await getDb()
    let sql = `
      SELECT sp.*, s.nama as skpd_nama, s.kode as skpd_kode
      FROM sipd_pegawai sp
      JOIN skpds s ON s.id = sp.skpd_id
      WHERE sp.fiscal_year_id = ? AND sp.skpd_id = ? AND sp.month = ?
    `
    const params = [yearId, filterSkpdId.value, filterMonth.value]
    if (filterStatusAsn.value) {
      sql += ' AND sp.status_asn = ?'
      params.push(filterStatusAsn.value)
    }
    sql += ' ORDER BY sp.nama_pegawai ASC'
    rows.value = await db.select(sql, params)
  } finally {
    loading.value = false
  }
}

watch([filterSkpdId, filterMonth, filterStatusAsn], () => {
  currentPage.value = 1
  loadData()
})

watch(search, () => { currentPage.value = 1 })

onMounted(async () => {
  await loadSkpds()
})
</script>

<template>
  <div>
    <el-page-header @back="router.push(`/tahun/${yearId}`)">
      <template #content>Data SIPD Pegawai — Tahun {{ currentYear }}</template>
      <template #extra>
        <el-button type="primary" @click="router.push(`/tahun/${yearId}/sipd`)">
          Upload Data Baru
        </el-button>
      </template>
    </el-page-header>

    <!-- Filter -->
    <el-card style="margin-top: 20px;">
      <div style="display: flex; gap: 12px; flex-wrap: wrap; align-items: center;">
        <el-select
          v-model="filterSkpdId"
          placeholder="Pilih SKPD"
          style="width: 300px;"
          filterable
          clearable
        >
          <el-option
            v-for="s in skpds"
            :key="s.id"
            :label="`${s.kode} — ${s.nama}`"
            :value="s.id"
          />
        </el-select>

        <el-select v-model="filterMonth" placeholder="Pilih Bulan" style="width: 160px;" clearable>
          <el-option v-for="(m, i) in MONTHS" :key="i+1" :label="m" :value="i+1" />
        </el-select>

        <el-select v-model="filterStatusAsn" placeholder="Status ASN" style="width: 130px;" clearable>
          <el-option label="PNS" :value="1" />
          <el-option label="PPPK" :value="2" />
          <el-option label="CPNS" :value="3" />
        </el-select>

        <el-input
          v-model="search"
          placeholder="Cari nama / NIP / jabatan..."
          style="width: 260px;"
          clearable
        >
          <template #prefix><el-icon><Search /></el-icon></template>
        </el-input>

        <span v-if="rows.length" style="font-size: 13px; color: #909399; margin-left: auto;">
          {{ filtered.length }} pegawai{{ filtered.length !== rows.length ? ` (dari ${rows.length})` : '' }}
        </span>
      </div>
    </el-card>

    <!-- Hint kalau belum pilih filter -->
    <el-empty
      v-if="!filterSkpdId || !filterMonth"
      description="Pilih SKPD dan bulan untuk melihat data"
      style="margin-top: 60px;"
    />

    <!-- Tabel -->
    <el-card v-else style="margin-top: 16px;">
      <el-table
        :data="paginated"
        v-loading="loading"
        stripe
        border
        size="small"
        style="width: 100%;"
        max-height="calc(100vh - 380px)"
      >
        <el-table-column type="index" label="No" width="50" fixed />
        <el-table-column label="NIP" prop="nip_pegawai" width="170" fixed />
        <el-table-column label="Nama" prop="nama_pegawai" min-width="190" fixed />
        <el-table-column label="Status" width="80">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status_asn === 1 ? 'primary' : row.status_asn === 2 ? 'warning' : 'info'">
              {{ STATUS_ASN[row.status_asn] ?? '-' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="Gol" prop="golongan" width="70" align="center" />
        <el-table-column label="Tipe Jabatan" width="130">
          <template #default="{ row }">{{ TIPE_JABATAN[row.tipe_jabatan] ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="Nama Jabatan" prop="nama_jabatan" min-width="220" />
        <el-table-column label="Masa Kerja" prop="masa_kerja_golongan" width="90" align="center" />
        <el-table-column label="Nikah" width="90">
          <template #default="{ row }">{{ STATUS_NIKAH[row.status_pernikahan] ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="Tanggungan" width="100" align="center">
          <template #default="{ row }">{{ row.jumlah_tanggungan }}</template>
        </el-table-column>

        <el-table-column label="NIK" prop="nik_pegawai" width="170" />
        <el-table-column label="NPWP" prop="npwp_pegawai" width="170" />
        <el-table-column label="Tgl. Lahir" prop="tanggal_lahir" width="110" align="center" />
        <el-table-column label="Eselon" prop="eselon" width="80" align="center" />
        <el-table-column label="Masa Kerja" prop="masa_kerja_golongan" width="95" align="center" />
        <el-table-column label="Alamat" prop="alamat" min-width="200" />
        <el-table-column label="Nikah" width="90">
          <template #default="{ row }">{{ STATUS_NIKAH[row.status_pernikahan] ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="Istri/Suami" width="90" align="center">
          <template #default="{ row }">{{ row.jumlah_istri_suami }}</template>
        </el-table-column>
        <el-table-column label="Anak" width="65" align="center">
          <template #default="{ row }">{{ row.jumlah_anak }}</template>
        </el-table-column>
        <el-table-column label="Tanggungan" width="95" align="center">
          <template #default="{ row }">{{ row.jumlah_tanggungan }}</template>
        </el-table-column>
        <el-table-column label="Pasangan PNS" width="110" align="center">
          <template #default="{ row }">{{ row.pasangan_pns }}</template>
        </el-table-column>
        <el-table-column label="NIP Pasangan" prop="nip_pasangan" width="170" />
        <el-table-column label="Kode Bank" prop="kode_bank" width="90" align="center" />
        <el-table-column label="Bank" prop="nama_bank" width="150" />
        <el-table-column label="No. Rekening" prop="nomor_rekening_bank_pegawai" width="170" />

        <!-- Komponen Gaji -->
        <el-table-column label="Gaji Pokok" width="130" align="right">
          <template #default="{ row }">{{ fmt(row.gaji_pokok) }}</template>
        </el-table-column>
        <el-table-column label="Perhit. Suami/Istri" width="145" align="right">
          <template #default="{ row }">{{ fmt(row.perhitungan_suami_istri) }}</template>
        </el-table-column>
        <el-table-column label="Perhit. Anak" width="120" align="right">
          <template #default="{ row }">{{ fmt(row.perhitungan_anak) }}</template>
        </el-table-column>
        <el-table-column label="Tunj. Keluarga" width="130" align="right">
          <template #default="{ row }">{{ fmt(row.tunjangan_keluarga) }}</template>
        </el-table-column>
        <el-table-column label="Tunj. Jabatan" width="130" align="right">
          <template #default="{ row }">{{ fmt(row.tunjangan_jabatan) }}</template>
        </el-table-column>
        <el-table-column label="Tunj. Fungsional" width="140" align="right">
          <template #default="{ row }">{{ fmt(row.tunjangan_fungsional) }}</template>
        </el-table-column>
        <el-table-column label="Tunj. Fungsional Umum" width="165" align="right">
          <template #default="{ row }">{{ fmt(row.tunjangan_fungsional_umum) }}</template>
        </el-table-column>
        <el-table-column label="Tunj. Beras" width="120" align="right">
          <template #default="{ row }">{{ fmt(row.tunjangan_beras) }}</template>
        </el-table-column>
        <el-table-column label="Tunj. PPh" width="120" align="right">
          <template #default="{ row }">{{ fmt(row.tunjangan_pph) }}</template>
        </el-table-column>
        <el-table-column label="Pembulatan Gaji" width="130" align="right">
          <template #default="{ row }">{{ fmt(row.pembulatan_gaji) }}</template>
        </el-table-column>
        <el-table-column label="Iuran JKes" width="120" align="right">
          <template #default="{ row }">{{ fmt(row.iuran_jaminan_kesehatan) }}</template>
        </el-table-column>
        <el-table-column label="Iuran JKK" width="110" align="right">
          <template #default="{ row }">{{ fmt(row.iuran_jaminan_kecelakaan_kerja) }}</template>
        </el-table-column>
        <el-table-column label="Iuran JKM" width="110" align="right">
          <template #default="{ row }">{{ fmt(row.iuran_jaminan_kematian) }}</template>
        </el-table-column>
        <el-table-column label="Iuran Tapera" width="120" align="right">
          <template #default="{ row }">{{ fmt(row.iuran_simpanan_tapera) }}</template>
        </el-table-column>
        <el-table-column label="Iuran Pensiun" width="125" align="right">
          <template #default="{ row }">{{ fmt(row.iuran_pensiun) }}</template>
        </el-table-column>
        <el-table-column label="Tunj. Papua" width="115" align="right">
          <template #default="{ row }">{{ fmt(row.tunjangan_khusus_papua) }}</template>
        </el-table-column>
        <el-table-column label="Tunj. JHT" width="115" align="right">
          <template #default="{ row }">{{ fmt(row.tunjangan_jaminan_hari_tua) }}</template>
        </el-table-column>
        <el-table-column label="Potongan IWP" width="125" align="right">
          <template #default="{ row }">{{ fmt(row.potongan_iwp) }}</template>
        </el-table-column>
        <el-table-column label="Potongan PPh 21" width="135" align="right">
          <template #default="{ row }">{{ fmt(row.potongan_pph_21) }}</template>
        </el-table-column>
        <el-table-column label="Zakat" width="110" align="right">
          <template #default="{ row }">{{ fmt(row.zakat) }}</template>
        </el-table-column>
        <el-table-column label="Bulog" width="110" align="right">
          <template #default="{ row }">{{ fmt(row.bulog) }}</template>
        </el-table-column>

        <!-- Rekapitulasi -->
        <el-table-column label="Jml Gaji & Tunj." width="150" align="right">
          <template #default="{ row }">
            <span style="font-weight: 600;">{{ fmt(row.jumlah_gaji_dan_tunjangan) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="Jml Potongan" width="130" align="right">
          <template #default="{ row }">
            <span style="color: #f56c6c;">{{ fmt(row.jumlah_potongan) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="Ditransfer" width="130" align="right">
          <template #default="{ row }">
            <span style="color: #67c23a; font-weight: 600;">{{ fmt(row.jumlah_ditransfer) }}</span>
          </template>
        </el-table-column>
      </el-table>

      <div v-if="filtered.length === 0 && !loading" style="padding: 40px; text-align: center; color: #909399;">
        Tidak ada data
      </div>

      <div v-if="filtered.length > 0" style="margin-top: 16px; display: flex; justify-content: flex-end;">
        <el-pagination
          v-model:current-page="currentPage"
          v-model:page-size="pageSize"
          :total="filtered.length"
          :page-sizes="[25, 50, 100, 200]"
          layout="total, sizes, prev, pager, next, jumper"
          background
        />
      </div>
    </el-card>
  </div>
</template>
