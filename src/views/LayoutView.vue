<script setup>
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const auth = useAuthStore()

function logout() {
  auth.logout()
  router.push('/login')
}
</script>

<template>
  <el-container style="min-height: 100vh">
    <el-header style="display: flex; align-items: center; justify-content: space-between; background: #fff; border-bottom: 1px solid #e4e7ed;">
      <span style="font-weight: 600; font-size: 16px;">Rekap Gaji ASN</span>
      <div style="display: flex; align-items: center; gap: 12px;">
        <span style="font-size: 13px; color: #606266;">{{ auth.user?.username }}</span>
        <el-tag size="small" :type="auth.isSuperadmin ? 'danger' : 'info'">
          {{ auth.isSuperadmin ? 'Superadmin' : 'User' }}
        </el-tag>
        <el-button size="small" @click="logout">Logout</el-button>
      </div>
    </el-header>
    <el-main style="background: #f0f2f5;">
      <router-view />
    </el-main>
  </el-container>
</template>
