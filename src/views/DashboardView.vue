<script setup>
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
</script>

<template>
  <div>
    <el-page-header @back="router.push('/')">
      <template #content>Tahun {{ route.params.yearId }}</template>
    </el-page-header>
    <div style="margin-top: 24px; display: flex; gap: 16px; flex-wrap: wrap;">
      <el-card
        shadow="hover"
        style="cursor: pointer; min-width: 200px;"
        @click="router.push(`/tahun/${route.params.yearId}/skpd`)"
      >
        <el-icon size="32"><OfficeBuilding /></el-icon>
        <div style="margin-top: 8px; font-weight: 600;">Data SKPD</div>
        <div style="font-size: 12px; color: #888;">
          {{ auth.isSuperadmin ? 'Kelola daftar SKPD' : 'Lihat daftar SKPD' }}
        </div>
      </el-card>
      <el-card
        v-if="auth.isSuperadmin"
        shadow="hover"
        style="cursor: pointer; min-width: 200px;"
        @click="router.push(`/tahun/${route.params.yearId}/sipd/data`)"
      >
        <el-icon size="32"><DataLine /></el-icon>
        <div style="margin-top: 8px; font-weight: 600;">Data SIPD</div>
        <div style="font-size: 12px; color: #888;">Lihat data pegawai dari SIPD</div>
      </el-card>
      <el-card
        v-if="auth.isSuperadmin"
        shadow="hover"
        style="cursor: pointer; min-width: 200px;"
        @click="router.push(`/tahun/${route.params.yearId}/sipd`)"
      >
        <el-icon size="32"><Upload /></el-icon>
        <div style="margin-top: 8px; font-weight: 600;">Upload Data SIPD</div>
        <div style="font-size: 12px; color: #888;">Import data pegawai dari SIPD</div>
      </el-card>
      <el-card
        shadow="hover"
        style="cursor: pointer; min-width: 200px;"
        @click="router.push(`/tahun/${route.params.yearId}/konsistensi`)"
      >
        <el-icon size="32"><DataAnalysis /></el-icon>
        <div style="margin-top: 8px; font-weight: 600;">Konsistensi Data</div>
        <div style="font-size: 12px; color: #888;">Bandingkan input manual vs SIPD</div>
      </el-card>
      <el-card
        v-if="auth.isSuperadmin"
        shadow="hover"
        style="cursor: pointer; min-width: 200px;"
        @click="router.push('/users')"
      >
        <el-icon size="32"><User /></el-icon>
        <div style="margin-top: 8px; font-weight: 600;">Kelola User</div>
        <div style="font-size: 12px; color: #888;">Tambah & atur akun pengguna</div>
      </el-card>
    </div>
  </div>
</template>
