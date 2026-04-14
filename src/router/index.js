import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/LoginView.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/',
    component: () => import('../views/LayoutView.vue'),
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        name: 'SelectYear',
        component: () => import('../views/SelectYearView.vue')
      },
      {
        path: 'tahun/:yearId',
        name: 'Dashboard',
        component: () => import('../views/DashboardView.vue')
      },
      {
        path: 'tahun/:yearId/skpd',
        name: 'SkpdList',
        component: () => import('../views/SkpdListView.vue'),
        meta: {}
      },
      {
        path: 'tahun/:yearId/skpd/:skpdId',
        name: 'SalaryInput',
        component: () => import('../views/SalaryInputView.vue')
      },
      {
        path: 'users',
        name: 'UserManagement',
        component: () => import('../views/UserManagementView.vue'),
        meta: { requiresSuperadmin: true }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes
})

router.beforeEach((to) => {
  const auth = useAuthStore()

  if (to.meta.requiresAuth !== false && !auth.isLoggedIn) {
    return { name: 'Login' }
  }

  if (to.meta.requiresSuperadmin && auth.user?.role !== 'superadmin') {
    return { name: 'Dashboard', params: to.params }
  }
})

export default router
