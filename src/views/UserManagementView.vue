<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { getDb } from '../utils/db'
import { ElMessage, ElMessageBox } from 'element-plus'

const router = useRouter()
const auth = useAuthStore()

const users = ref([])
const loading = ref(false)
const dialogVisible = ref(false)
const isEdit = ref(false)
const formLoading = ref(false)

const form = ref({ id: null, username: '', password: '', confirmPassword: '', role: 'user' })

async function loadUsers() {
  loading.value = true
  try {
    const db = await getDb()
    users.value = await db.select('SELECT id, username, role, created_at FROM users ORDER BY id ASC')
  } finally {
    loading.value = false
  }
}

function openAdd() {
  isEdit.value = false
  form.value = { id: null, username: '', password: '', confirmPassword: '', role: 'user' }
  dialogVisible.value = true
}

function openEdit(row) {
  isEdit.value = true
  form.value = { id: row.id, username: row.username, password: '', confirmPassword: '', role: row.role }
  dialogVisible.value = true
}

async function saveUser() {
  if (!form.value.username.trim()) {
    ElMessage.warning('Username wajib diisi')
    return
  }
  if (!isEdit.value && !form.value.password) {
    ElMessage.warning('Password wajib diisi')
    return
  }
  if (form.value.password && form.value.password !== form.value.confirmPassword) {
    ElMessage.warning('Konfirmasi password tidak cocok')
    return
  }

  formLoading.value = true
  try {
    const db = await getDb()
    if (isEdit.value) {
      if (form.value.password) {
        await db.execute(
          'UPDATE users SET username = ?, password_hash = ?, role = ? WHERE id = ?',
          [form.value.username.trim(), form.value.password, form.value.role, form.value.id]
        )
      } else {
        await db.execute(
          'UPDATE users SET username = ?, role = ? WHERE id = ?',
          [form.value.username.trim(), form.value.role, form.value.id]
        )
      }
      // Kalau edit diri sendiri, update session
      if (form.value.id === auth.user.id) {
        auth.login({ ...auth.user, username: form.value.username.trim(), role: form.value.role })
      }
      ElMessage.success('User berhasil diperbarui')
    } else {
      await db.execute(
        'INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)',
        [form.value.username.trim(), form.value.password, form.value.role]
      )
      ElMessage.success('User berhasil ditambahkan')
    }
    dialogVisible.value = false
    await loadUsers()
  } catch {
    ElMessage.error('Username sudah digunakan atau terjadi kesalahan')
  } finally {
    formLoading.value = false
  }
}

async function deleteUser(row) {
  if (row.id === auth.user.id) {
    ElMessage.warning('Tidak bisa menghapus akun sendiri')
    return
  }
  try {
    await ElMessageBox.confirm(
      `Hapus user "${row.username}"?`,
      'Konfirmasi Hapus',
      { type: 'warning', confirmButtonText: 'Hapus', cancelButtonText: 'Batal' }
    )
    const db = await getDb()
    await db.execute('DELETE FROM users WHERE id = ?', [row.id])
    ElMessage.success('User berhasil dihapus')
    await loadUsers()
  } catch {
    // user cancel
  }
}

onMounted(loadUsers)
</script>

<template>
  <div style="max-width: 700px; margin: 40px auto;">
    <el-page-header @back="router.go(-1)">
      <template #content>Kelola User</template>
    </el-page-header>

    <el-card style="margin-top: 24px;">
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span>Daftar User</span>
          <el-button type="primary" size="small" @click="openAdd">+ Tambah User</el-button>
        </div>
      </template>

      <el-table :data="users" v-loading="loading" stripe style="width: 100%">
        <el-table-column type="index" label="No" width="55" />
        <el-table-column prop="username" label="Username" />
        <el-table-column label="Role" width="120">
          <template #default="{ row }">
            <el-tag :type="row.role === 'superadmin' ? 'danger' : 'info'" size="small">
              {{ row.role }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="Aksi" width="150" align="center">
          <template #default="{ row }">
            <el-button size="small" @click="openEdit(row)">Edit</el-button>
            <el-button
              size="small"
              type="danger"
              :disabled="row.id === auth.user.id"
              @click="deleteUser(row)"
            >
              Hapus
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog
      v-model="dialogVisible"
      :title="isEdit ? 'Edit User' : 'Tambah User'"
      width="400px"
      @closed="form = { id: null, username: '', password: '', confirmPassword: '', role: 'user' }"
    >
      <el-form label-position="top">
        <el-form-item label="Username">
          <el-input v-model="form.username" placeholder="Username" />
        </el-form-item>
        <el-form-item :label="isEdit ? 'Password Baru (kosongkan jika tidak diubah)' : 'Password'">
          <el-input v-model="form.password" type="password" placeholder="Password" show-password />
        </el-form-item>
        <el-form-item label="Konfirmasi Password">
          <el-input v-model="form.confirmPassword" type="password" placeholder="Ulangi password" show-password />
        </el-form-item>
        <el-form-item label="Role">
          <el-select v-model="form.role" style="width: 100%">
            <el-option label="User" value="user" />
            <el-option label="Superadmin" value="superadmin" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">Batal</el-button>
        <el-button type="primary" :loading="formLoading" @click="saveUser">Simpan</el-button>
      </template>
    </el-dialog>
  </div>
</template>
