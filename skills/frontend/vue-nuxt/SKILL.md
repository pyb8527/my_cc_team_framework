---
name: vue-nuxt
description: Vue 3 and Nuxt 3 best practices including Composition API, composables, Pinia state management, server-side rendering, and production deployment patterns.
---

# Vue 3 & Nuxt 3 Best Practices

## Vue 3 — Composition API

### Component Structure
```vue
<script setup lang="ts">
// 1. Imports
import { ref, computed, onMounted, watch } from 'vue'
import { useUserStore } from '@/stores/user'

// 2. Props & Emits
const props = defineProps<{
  userId: number
  readonly?: boolean
}>()

const emit = defineEmits<{
  saved: [user: User]
  cancelled: []
}>()

// 3. Store / Composables
const userStore = useUserStore()
const { user, isLoading, fetchUser } = useUser(props.userId)

// 4. Local state
const isEditing = ref(false)
const form = reactive({ name: '', email: '' })

// 5. Computed
const isValid = computed(() => form.name.length >= 2 && form.email.includes('@'))

// 6. Watchers
watch(() => user.value, (newUser) => {
  if (newUser) Object.assign(form, { name: newUser.name, email: newUser.email })
}, { immediate: true })

// 7. Lifecycle
onMounted(() => fetchUser())

// 8. Methods
async function handleSave() {
  if (!isValid.value) return
  const saved = await userStore.updateUser(props.userId, form)
  emit('saved', saved)
  isEditing.value = false
}
</script>

<template>
  <div>
    <form v-if="isEditing" @submit.prevent="handleSave">
      <input v-model="form.name" :disabled="readonly" />
      <input v-model="form.email" type="email" :disabled="readonly" />
      <button type="submit" :disabled="!isValid">저장</button>
      <button type="button" @click="emit('cancelled')">취소</button>
    </form>
    <div v-else>
      <p>{{ user?.name }}</p>
      <button v-if="!readonly" @click="isEditing = true">수정</button>
    </div>
  </div>
</template>
```

### Composables Pattern
```typescript
// composables/useUser.ts
export function useUser(userId: MaybeRef<number>) {
  const user = ref<User | null>(null)
  const isLoading = ref(false)
  const error = ref<Error | null>(null)

  async function fetchUser() {
    isLoading.value = true
    error.value = null
    try {
      user.value = await api.getUser(toValue(userId))
    } catch (e) {
      error.value = e as Error
    } finally {
      isLoading.value = false
    }
  }

  // Auto-fetch when userId changes
  watchEffect(() => {
    if (toValue(userId)) fetchUser()
  })

  return { user: readonly(user), isLoading: readonly(isLoading), error: readonly(error), fetchUser }
}
```

## Pinia (State Management)

```typescript
// stores/user.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

// Composition API style (recommended)
export const useUserStore = defineStore('user', () => {
  // State
  const currentUser = ref<User | null>(null)
  const token = ref<string | null>(null)

  // Getters
  const isAuthenticated = computed(() => !!currentUser.value && !!token.value)
  const isAdmin = computed(() => currentUser.value?.role === 'ADMIN')

  // Actions
  async function login(credentials: LoginDto) {
    const { user, accessToken } = await api.login(credentials)
    currentUser.value = user
    token.value = accessToken
  }

  function logout() {
    currentUser.value = null
    token.value = null
  }

  async function updateUser(id: number, data: UpdateUserDto) {
    const updated = await api.updateUser(id, data)
    if (currentUser.value?.id === id) {
      currentUser.value = updated
    }
    return updated
  }

  return { currentUser, token, isAuthenticated, isAdmin, login, logout, updateUser }
}, {
  persist: { paths: ['token'] }  // pinia-plugin-persistedstate
})
```

## Nuxt 3 — App Structure

```
nuxt-app/
├── app.vue                  # Root component
├── nuxt.config.ts           # Nuxt configuration
├── pages/                   # File-based routing
│   ├── index.vue            # /
│   ├── users/
│   │   ├── index.vue        # /users
│   │   └── [id].vue         # /users/:id
│   └── [...slug].vue        # Catch-all
├── layouts/
│   ├── default.vue
│   └── auth.vue
├── components/              # Auto-imported
├── composables/             # Auto-imported
├── stores/                  # Pinia stores
├── server/
│   ├── api/                 # API routes (Nitro)
│   │   └── users/
│   │       └── [id].get.ts  # GET /api/users/:id
│   └── middleware/
├── middleware/              # Route middleware
└── plugins/
```

### Data Fetching (Nuxt)
```vue
<script setup lang="ts">
// useFetch — SSR + client hydration (no double fetch)
const { data: users, pending, error, refresh } = await useFetch('/api/users', {
  query: { page: 1, size: 20 },
  lazy: false,          // await on server
  server: true,         // render on server
  transform: (data) => data.items,
})

// useAsyncData — for complex fetching logic
const { data: user } = await useAsyncData(
  `user-${route.params.id}`,   // cache key
  () => $fetch(`/api/users/${route.params.id}`)
)

// $fetch — client-only (mutations, form submits)
async function submitForm() {
  await $fetch('/api/users', {
    method: 'POST',
    body: formData,
  })
}
</script>
```

### Server API Route
```typescript
// server/api/users/[id].get.ts
export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id')
  const user = await db.user.findUnique({ where: { id: Number(id) } })
  if (!user) throw createError({ statusCode: 404, message: 'User not found' })
  return user
})
```

### Route Middleware
```typescript
// middleware/auth.ts
export default defineNuxtRouteMiddleware((to) => {
  const { isAuthenticated } = useUserStore()
  if (!isAuthenticated) {
    return navigateTo(`/login?redirect=${to.path}`)
  }
})

// pages/dashboard.vue
definePageMeta({ middleware: 'auth', layout: 'dashboard' })
```

### nuxt.config.ts
```typescript
export default defineNuxtConfig({
  modules: [
    '@pinia/nuxt',
    '@pinia-plugin-persistedstate/nuxt',
    '@nuxtjs/tailwindcss',
    '@vueuse/nuxt',
  ],
  runtimeConfig: {
    apiSecret: '',                      // server-only
    public: {
      apiBase: 'http://localhost:8080', // exposed to client
    },
  },
  routeRules: {
    '/api/**': { proxy: { to: 'http://localhost:8080/**' } },
    '/admin/**': { ssr: false },        // SPA mode for admin
  },
})
```

## Best Practices

- Use `<script setup>` — no `setup()` return boilerplate
- Prefer `defineModel()` (Vue 3.4+) over manual v-model props
- Use `shallowRef` for large objects that don't need deep reactivity
- Avoid `reactive()` for primitives — use `ref()` always
- Name composables with `use` prefix and return readonly refs
- Use `v-memo` for expensive list renders that rarely change
- In Nuxt: prefer `useFetch` over `useAsyncData` + `$fetch`
- Use `getCachedData` in `useFetch` to prevent redundant server calls
