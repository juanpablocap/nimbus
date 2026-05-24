# Nimbus — MVP Project List

## Estado actual

- [x] Monorepo + pnpm workspaces
- [x] GitHub repo
- [x] Documentación fundacional (architecture, conventions, roadmap, permissions, db, stack, vision, goal)
- [x] Admin dashboard inicializado (Next.js 16 + React 19 + Tailwind 4)
- [x] Layout shell (sidebar, topbar, theme toggle, design tokens)

---

## FASE 1 — Foundation (Backend)

Lo que necesitás antes de escribir una línea de UI funcional.

### 1.1 Supabase Setup ✅
- [x] Crear proyecto en Supabase Cloud
- [x] Configurar variables de entorno (.env.local para admin)
- [x] Instalar Supabase client en admin (`@supabase/supabase-js`)
- [x] Crear cliente Supabase compartido (`lib/supabase.ts`)

### 1.2 Schema de Base de Datos ✅
- [x] Tabla `communities` (tenant principal)
- [x] Tabla `profiles` (datos de usuario extendidos, vinculado a auth.users)
- [x] Tabla `properties` (lotes/casas/departamentos)
- [x] Tabla `resident_properties` (relación N:N residente ↔ propiedad)
- [x] Tabla `roles` + `permissions` + `role_permissions` (RBAC dinámico)
- [x] Tabla `user_roles` (asignación de roles por comunidad)
- [x] Tabla `visits` (visitas temporales con QR)
- [x] Tabla `access_logs` (registro de entradas/salidas)
- [x] Tabla `news` (novedades/anuncios comunitarios)
- [x] Seed data: comunidad "Barrio Los Álamos", 3 roles default, 21 permisos

### 1.3 Row Level Security (RLS) ✅
- [x] RLS en todas las tablas tenant-aware (`community_id`)
- [x] Helper functions: `get_user_community_id()`, `user_has_permission()`
- [x] Políticas para admin (CRUD completo en su comunidad)
- [x] Políticas para resident (lectura propia, CRUD visitas propias)
- [x] Políticas para guard (lectura visitas activas, escritura access_logs)

### 1.4 Autenticación ✅
- [x] Configurar auth en Supabase (email + password)
- [x] Flujo de login en admin dashboard
- [x] AuthProvider context con protección de rutas
- [x] Redirect a login si no autenticado
- [x] Datos del usuario logueado en topbar + logout

---

## FASE 2 — Admin Dashboard (MVP funcional)

### 2.1 Dashboard Home ✅
- [x] Stats reales: total residentes, propiedades, visitas activas, entradas hoy
- [x] Lista de accesos recientes (últimas 10 entradas)
- [x] Lista de últimas novedades publicadas

### 2.2 Gestión de Propiedades ✅
- [x] Listado de propiedades (tabla con búsqueda)
- [x] Crear propiedad (modal: nombre, tipo, dirección)
- [x] Editar propiedad
- [x] Eliminar propiedad

### 2.3 Gestión de Residentes ✅
- [x] Listado de residentes (tabla con búsqueda)
- [x] Crear residente (API route con service_role: crea auth user + profile + role + property)
- [x] Editar datos de residente
- [x] Activar/desactivar residente

### 2.4 Gestión de Novedades ✅
- [x] Listado de novedades (cards)
- [x] Crear novedad (título, cuerpo)
- [x] Editar novedad
- [x] Publicar/despublicar toggle
- [x] Eliminar novedad

### 2.5 Logs de Acceso ✅
- [x] Listado de accesos con filtro por fecha

### 2.6 Visitas (read-only) ✅
- [x] Listado de visitas con filtro por estado (active/used/expired/cancelled)

---

## FASE 3 — QR System + Edge Functions

### 3.1 Edge Functions ⏳ (código listo, falta deploy)
- [x] `_shared/qr-jwt.ts` — Firma y verificación JWT (HMAC-SHA256)
- [x] `_shared/supabase.ts` — Clientes admin y user para Edge Functions
- [x] `_shared/cors.ts` — Headers CORS y helpers de respuesta
- [x] `generate-qr/index.ts` — Genera token firmado para una visita
- [x] `validate-qr/index.ts` — Valida token QR (firma, expiración, usos, estado, comunidad)
- [x] `confirm-access/index.ts` — Aprueba entrada, crea access_log, incrementa usos
- [ ] **Deploy** a Supabase (requiere CLI: `supabase functions deploy`)
- [ ] **Set secret** QR_JWT_SECRET en Supabase

### 3.2 Documentación ✅
- [x] `docs/edge-functions.md` — Arquitectura, endpoints, payloads, deployment

---

## FASE 4 — App Mobile (Flutter) — MVP

### 4.1 Setup ⏳ (código listo, falta Flutter SDK)
- [x] Estructura de proyecto en `apps/mobile/`
- [x] `pubspec.yaml` con todas las dependencias
- [x] Configuración Supabase client
- [x] Estructura de carpetas (features, core, shared)
- [ ] **Ejecutar** `flutter pub get` (requiere macOS 14+ con Flutter SDK)

### 4.2 Auth
- [x] Pantalla de login (email + password)
- [x] AuthProvider con Riverpod
- [x] Redirect automático si no autenticado

### 4.3 Residente — Features
- [x] Home con resumen (visitas activas, novedades recientes, quick actions)
- [x] Crear visita (nombre, documento, propiedad, tipo, max uses, expiración, notas)
- [x] Generar QR dinámico (llama a Edge Function + qr_flutter)
- [x] Compartir QR por WhatsApp / mensaje (share_plus)
- [x] Listar mis visitas (con filter chips: active/used/expired/all)
- [x] Cancelar visita
- [x] Feed de novedades comunitarias (con relative time)
- [x] Perfil y configuración (info, propiedades, sign out)

### 4.4 Guardia — Features
- [x] Escáner de QR (mobile_scanner con overlay)
- [x] Validación de QR → mostrar datos de visita + residente + propiedad
- [x] Aprobar entrada (llama a confirm-access Edge Function)
- [x] Resultado visual (✅ valid / ❌ invalid con razón)
- [x] "Scan Another" para siguiente visitante

### 4.5 Navegación
- [x] GoRouter con auth redirect
- [x] Bottom nav shell (Home, Visits, Scan, News, Profile)
- [x] Deep linking a visit detail

### 4.6 Documentación ✅
- [x] `docs/mobile-app.md` — Arquitectura, estructura, flujos, dependencias

---

## FASE 5 — Pulido y Lanzamiento

### 5.1 Testing
- [ ] Testing manual del flujo completo: admin crea propiedad → invita residente → residente crea visita → guardia valida QR
- [ ] Testing en dispositivos reales (iOS + Android)
- [ ] Edge cases: QR expirado, visita cancelada, residente desactivado

### 5.2 Deploy
- [ ] Deploy Edge Functions a Supabase
- [ ] Admin dashboard: deploy en Vercel
- [ ] App mobile: build de release iOS (TestFlight)
- [ ] App mobile: build de release Android (APK / Play Internal Testing)

### 5.3 Piloto
- [ ] Conseguir 1 comunidad piloto
- [ ] Onboarding: cargar propiedades y residentes
- [ ] Feedback loop: iteración rápida sobre problemas reales

---

## Orden de ejecución recomendado

```
FASE 1 (Foundation)     → 1.1 ✅ → 1.2 ✅ → 1.3 ✅ → 1.4 ✅
                              ↓
FASE 2 (Admin)          → 2.2 ✅ → 2.3 ✅ → 2.4 ✅ → 2.1 ✅ → 2.5 ✅ → 2.6 ✅
                              ↓
FASE 3 (QR + Edge Fn)   → 3.1 ⏳ (code done, deploy pending)
                              ↓
FASE 4 (Mobile)         → 4.1 ⏳ → 4.2 ✅ → 4.3 ✅ → 4.4 ✅ → 4.5 ✅
                              ↓
FASE 5 (Lanzamiento)    → 5.1 → 5.2 → 5.3
```

---

## Próximos pasos inmediatos

1. **Deploy Edge Functions** → necesita Supabase CLI (`npx supabase functions deploy`)
2. **Probar Flutter app** → necesita MacBook nuevo con macOS 14+
3. **Test flujo completo** end-to-end
4. **Deploy admin a Vercel**

---

## Fuera del MVP (documentado pero no se toca)

- Incidentes y reportes
- Gestión de vehículos
- Empleados domésticos / permisos recurrentes
- Analytics avanzado
- Amenities / reservas
- Pagos / expensas
- Marketplace
- IoT / smart gates / CCTV
- AI monitoring
- EV / energía
- Push notifications (Firebase Cloud Messaging)
- Magic link / OTP auth
- Registro manual de entrada (sin QR)
- Onboarding flow para primer login

