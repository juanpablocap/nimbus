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

### 1.1 Supabase Setup
- [ ] Crear proyecto en Supabase Cloud
- [ ] Configurar variables de entorno (.env.local para admin, .env para mobile)
- [ ] Instalar Supabase client en admin (`@supabase/supabase-js`)
- [ ] Crear cliente Supabase compartido (`lib/supabase.ts`)

### 1.2 Schema de Base de Datos
- [ ] Tabla `communities` (tenant principal)
- [ ] Tabla `profiles` (datos de usuario extendidos, vinculado a auth.users)
- [ ] Tabla `properties` (lotes/casas/departamentos)
- [ ] Tabla `resident_properties` (relación N:N residente ↔ propiedad)
- [ ] Tabla `roles` + `permissions` + `role_permissions` (RBAC dinámico)
- [ ] Tabla `user_roles` (asignación de roles por comunidad)
- [ ] Tabla `visits` (visitas temporales con QR)
- [ ] Tabla `access_logs` (registro de entradas/salidas)
- [ ] Tabla `news` (novedades/anuncios comunitarios)
- [ ] Seed data: crear comunidad de prueba, roles default (admin, resident, guard)

### 1.3 Row Level Security (RLS)
- [ ] RLS en todas las tablas tenant-aware (`community_id`)
- [ ] Políticas para admin (CRUD completo en su comunidad)
- [ ] Políticas para resident (lectura propia, CRUD visitas propias)
- [ ] Políticas para guard (lectura visitas activas, escritura access_logs)

### 1.4 Autenticación
- [ ] Configurar auth en Supabase (email + magic link)
- [ ] Flujo de login en admin dashboard
- [ ] Middleware de protección de rutas en Next.js
- [ ] Redirect a login si no autenticado
- [ ] Mostrar datos del usuario logueado en topbar

---

## FASE 2 — Admin Dashboard (MVP funcional)

Con el backend listo, construir las pantallas del admin.

### 2.1 Dashboard Home
- [ ] Stats reales: total residentes, propiedades, visitas activas, entradas hoy
- [ ] Lista de accesos recientes (últimas 10 entradas)
- [ ] Lista de últimas novedades publicadas

### 2.2 Gestión de Propiedades
- [ ] Listado de propiedades (tabla con búsqueda y filtros)
- [ ] Crear propiedad (formulario: nombre/número, tipo, dirección, etc.)
- [ ] Editar propiedad
- [ ] Eliminar propiedad (soft delete)

### 2.3 Gestión de Residentes
- [ ] Listado de residentes (tabla con búsqueda)
- [ ] Crear residente (invitar por email → crea cuenta en Supabase)
- [ ] Asignar residente a propiedad
- [ ] Editar datos de residente
- [ ] Desactivar residente

### 2.4 Gestión de Novedades
- [ ] Listado de novedades
- [ ] Crear novedad (título, cuerpo, visibilidad)
- [ ] Editar novedad
- [ ] Eliminar novedad

### 2.5 Logs de Acceso
- [ ] Listado de accesos con filtros (fecha, propiedad, tipo)
- [ ] Detalle de acceso (quién, cuándo, validado por quién)

---

## FASE 3 — App Mobile (Flutter) — MVP

Esta es la app principal que usan residentes y guardias.

### 3.1 Setup
- [ ] Crear proyecto Flutter en `apps/mobile/`
- [ ] Configurar Supabase client para Flutter (`supabase_flutter`)
- [ ] Configurar deep links para magic link auth
- [ ] Configurar push notifications (Firebase Cloud Messaging)
- [ ] Estructura de carpetas (features, core, shared)

### 3.2 Auth (Residente + Guardia)
- [ ] Pantalla de login (email + magic link)
- [ ] OTP como alternativa
- [ ] Persistencia de sesión
- [ ] Flujo de onboarding (primera vez → completar perfil)

### 3.3 Residente — Features
- [ ] Home con resumen (visitas activas, novedades recientes)
- [ ] Crear visita (nombre visitante, fecha/hora, tipo: única/recurrente)
- [ ] Generar QR dinámico para visita
- [ ] Compartir QR por WhatsApp / mensaje
- [ ] Listar mis visitas (activas, pasadas, expiradas)
- [ ] Cancelar visita
- [ ] Feed de novedades comunitarias
- [ ] Perfil y configuración

### 3.4 Guardia — Features
- [ ] Home con visitas activas del día
- [ ] Escáner de QR (cámara)
- [ ] Validación de QR → mostrar datos de visita + residente + propiedad
- [ ] Aprobar / rechazar entrada
- [ ] Registro manual de entrada (sin QR)
- [ ] Historial de accesos recientes

### 3.5 QR System
- [ ] Generación de QR con token firmado (JWT o similar)
- [ ] Expiración por tiempo y por uso
- [ ] Validación server-side (Edge Function en Supabase)
- [ ] QR único por visita (no reutilizable)

### 3.6 Notificaciones
- [ ] Push notification al residente cuando su visita entra
- [ ] Push notification al residente cuando su visita es rechazada
- [ ] Notificación de nuevas novedades comunitarias

---

## FASE 4 — Pulido y Lanzamiento

### 4.1 Testing
- [ ] Testing manual del flujo completo: admin crea propiedad → invita residente → residente crea visita → guardia valida QR
- [ ] Testing en dispositivos reales (iOS + Android)
- [ ] Edge cases: QR expirado, visita cancelada, residente desactivado

### 4.2 Deploy
- [ ] Supabase en producción (migrar de dev a prod)
- [ ] Admin dashboard: deploy en Vercel
- [ ] App mobile: build de release iOS (TestFlight)
- [ ] App mobile: build de release Android (APK / Play Internal Testing)

### 4.3 Piloto
- [ ] Conseguir 1 comunidad piloto
- [ ] Onboarding: cargar propiedades y residentes
- [ ] Feedback loop: iteración rápida sobre problemas reales

---

## Orden de ejecución recomendado

```
FASE 1 (Foundation)     → 1.1 → 1.2 → 1.3 → 1.4
                              ↓
FASE 2 (Admin)          → 2.2 → 2.3 → 2.4 → 2.1 → 2.5
                              ↓
FASE 3 (Mobile)         → 3.1 → 3.2 → 3.3 → 3.5 → 3.4 → 3.6
                              ↓
FASE 4 (Lanzamiento)    → 4.1 → 4.2 → 4.3
```

Propiedades antes que residentes (porque un residente se asigna a una propiedad).
El dashboard home (2.1) se hace después porque necesita datos reales.
QR system (3.5) antes de guardia (3.4) porque el guardia depende del escáner.

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
