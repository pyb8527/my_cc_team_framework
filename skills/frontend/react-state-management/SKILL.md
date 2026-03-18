---
name: react-state-management
description: React state management patterns with Zustand, Redux Toolkit, Jotai, and React Query. Covers when to use each solution, best practices, and common anti-patterns to avoid.
---

# React State Management Best Practices

## Decision Guide

```
State type                      → Solution
─────────────────────────────────────────────────────
Server/async state              → TanStack Query (React Query)
Global UI state (simple)        → Zustand
Global UI state (complex/team)  → Redux Toolkit
Atomic/derived state            → Jotai
Local component state           → useState / useReducer
Form state                      → React Hook Form
```

## TanStack Query (Server State)

```typescript
// Setup
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60,      // 1 minute
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

// Query hook
function useUser(userId: number) {
  return useQuery({
    queryKey: ['users', userId],
    queryFn: () => api.getUser(userId),
    enabled: !!userId,
  });
}

// Mutation hook
function useUpdateUser() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: UpdateUserDto) => api.updateUser(data),
    onSuccess: (updatedUser) => {
      // Optimistic update
      queryClient.setQueryData(['users', updatedUser.id], updatedUser);
      // Or invalidate to refetch
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
}

// Usage
function UserProfile({ userId }: { userId: number }) {
  const { data: user, isLoading, error } = useUser(userId);
  const updateUser = useUpdateUser();

  if (isLoading) return <Skeleton />;
  if (error) return <ErrorMessage error={error} />;

  return (
    <form onSubmit={(e) => {
      e.preventDefault();
      updateUser.mutate({ id: userId, name: e.currentTarget.name.value });
    }}>
      ...
    </form>
  );
}
```

## Zustand (Global UI State)

```typescript
// store/useAuthStore.ts
import { create } from 'zustand';
import { persist, devtools } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  // Actions co-located with state
  login: (user: User, token: string) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  devtools(
    persist(
      immer((set) => ({
        user: null,
        token: null,
        isAuthenticated: false,

        login: (user, token) => set((state) => {
          state.user = user;
          state.token = token;
          state.isAuthenticated = true;
        }),

        logout: () => set((state) => {
          state.user = null;
          state.token = null;
          state.isAuthenticated = false;
        }),
      })),
      { name: 'auth-storage', partialize: (s) => ({ token: s.token }) }
    )
  )
);

// Selectors — prevent unnecessary re-renders
export const useUser = () => useAuthStore((s) => s.user);
export const useIsAuthenticated = () => useAuthStore((s) => s.isAuthenticated);
```

## Redux Toolkit (Complex Global State)

```typescript
// features/cart/cartSlice.ts
import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';

// Async thunk
export const fetchCart = createAsyncThunk(
  'cart/fetchCart',
  async (userId: number, { rejectWithValue }) => {
    try {
      return await api.getCart(userId);
    } catch (err) {
      return rejectWithValue(err.message);
    }
  }
);

const cartSlice = createSlice({
  name: 'cart',
  initialState: {
    items: [] as CartItem[],
    status: 'idle' as 'idle' | 'loading' | 'succeeded' | 'failed',
    error: null as string | null,
  },
  reducers: {
    addItem(state, action: PayloadAction<CartItem>) {
      const existing = state.items.find((i) => i.id === action.payload.id);
      if (existing) {
        existing.quantity += 1;
      } else {
        state.items.push(action.payload);
      }
    },
    removeItem(state, action: PayloadAction<number>) {
      state.items = state.items.filter((i) => i.id !== action.payload);
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchCart.pending, (state) => { state.status = 'loading'; })
      .addCase(fetchCart.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.items = action.payload;
      })
      .addCase(fetchCart.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.payload as string;
      });
  },
});

// Memoized selector
export const selectCartTotal = createSelector(
  (state: RootState) => state.cart.items,
  (items) => items.reduce((sum, item) => sum + item.price * item.quantity, 0)
);
```

## Jotai (Atomic State)

```typescript
// atoms/themeAtoms.ts
import { atom, selector } from 'jotai';
import { atomWithStorage } from 'jotai/utils';

export const themeAtom = atomWithStorage<'light' | 'dark'>('theme', 'light');

// Derived atom (computed)
export const isDarkAtom = atom((get) => get(themeAtom) === 'dark');

// Async atom
export const userAtom = atom(async (get) => {
  const userId = get(currentUserIdAtom);
  if (!userId) return null;
  return api.getUser(userId);
});

// Usage
function ThemeToggle() {
  const [theme, setTheme] = useAtom(themeAtom);
  return <button onClick={() => setTheme(t => t === 'light' ? 'dark' : 'light')}>{theme}</button>;
}
```

## Common Anti-Patterns

```typescript
// ❌ Storing server data in Zustand/Redux
const useStore = create(() => ({ users: [], fetchUsers: async () => { ... } }));
// ✅ Use TanStack Query for server data

// ❌ Deriving state in render
function Component() {
  const items = useStore(s => s.items);
  const total = items.reduce(...); // recalculates every render
}
// ✅ Use selector or useMemo
const total = useStore(s => s.items.reduce(...));

// ❌ One massive store
const useAppStore = create(() => ({ user, cart, theme, notifications, ... }));
// ✅ Split by domain
const useAuthStore = create(...);
const useCartStore = create(...);

// ❌ Subscribing to entire store
const state = useStore();
// ✅ Select only what you need
const user = useStore(s => s.user);
```

## State Colocation Rule

```
Keep state as close to where it's used as possible:
  1. useState     — single component
  2. Context      — small subtree (< 5 components, infrequent updates)
  3. Zustand/Jotai— app-wide UI state
  4. TanStack Query— server/async state (always)
  5. Redux Toolkit — large teams, complex state machines, time-travel debugging needed
```
