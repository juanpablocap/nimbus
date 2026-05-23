# Nimbus — Development Bootstrap

# Current Project Status

Nimbus has been initialized successfully with:

* monorepo architecture
* pnpm workspace
* Next.js admin application
* Git repository
* GitHub remote repository
* SSH authentication
* foundational architecture documentation
* modern Node.js environment

Repository:

```txt
https://github.com/juanpablocap/nimbus
```

---

# Development Environment

# Primary Development Machine

Current development machine:

```txt
MacBook Air
macOS Big Sur
```

Reason:

* compatible with modern Node.js tooling
* compatible with pnpm
* compatible with Next.js
* stable development environment

---

# Secondary Machine

Current secondary machine:

```txt
Older iMac
```

Used for:

* SSH access
* larger display
* documentation
* remote editing
* terminal sessions

---

# Remote Development Workflow

Nimbus development currently works through:

```txt
iMac
  ↓ SSH
MacBook Air
```

Advantages:

* modern tooling
* centralized environment
* simpler maintenance
* easier future migration

---

# Installed Tooling

# Node.js

Installed version:

```txt
Node.js v20 LTS
```

Reason:

* stable
* compatible with Big Sur
* compatible with Next.js ecosystem
* compatible with Supabase tooling

---

# pnpm

Installed globally.

Reason:

* optimized for monorepos
* faster installs
* disk efficient
* modern workspace support

---

# GitHub Authentication

Configured using:

```txt
SSH Keys
```

Advantages:

* avoids password authentication
* secure
* stable
* easier automation

---

# Repository Structure

Current structure:

```txt
nimbus/
├── apps/
│   ├── admin/
│   ├── mobile/
│   └── web/
│
├── packages/
│   ├── auth/
│   ├── config/
│   ├── supabase/
│   ├── types/
│   ├── ui/
│   └── utils/
│
├── docs/
├── scripts/
├── supabase/
│
├── .gitignore
├── package.json
├── pnpm-workspace.yaml
└── README.md
```

---

# Admin Dashboard

Current admin stack:

```txt
Next.js 16
React 19
TypeScript
Tailwind CSS
App Router
```

Reasoning:

## Next.js

Chosen over plain React because:

* production-ready architecture
* App Router
* layouts
* server components
* routing included
* optimized builds
* scalable conventions
* easier deployment
* future SSR support
* better operational structure

Nimbus is an operational platform, not just a frontend SPA.

Next.js fits better long-term.

---

# App Router

Chosen because:

* modern Next.js standard
* nested layouts
* scalable architecture
* better data flow
* cleaner routing

---

# Tailwind CSS

Chosen because:

* fast UI iteration
* consistency
* scalability
* easier design systems
* minimal CSS fragmentation

---

# Architecture Philosophy

Nimbus prioritizes:

* simplicity
* operational clarity
* scalability
* maintainability
* predictable architecture

Avoid:

* overengineering
* unnecessary abstractions
* premature microservices
* feature bloat

---

# Existing Documentation

Currently available inside:

```txt
/docs
```

Files:

```txt
architecture.md
conventions.md
db.md
permissions.md
roadmap.md
```

These define:

* SaaS architecture
* RBAC permissions
* database design
* project conventions
* product roadmap

---

# Current Development Priorities

Priority order:

1. infrastructure
2. internal architecture
3. auth system
4. Supabase integration
5. layout system
6. core operational flows
7. UI polish

Features are intentionally delayed.

---

# Immediate Next Steps

## 1. Organize Admin Source Structure

Inside:

```txt
apps/admin/src
```

Target structure:

```txt
src/
├── app/
├── components/
│   ├── ui/
│   ├── layout/
│   └── shared/
│
├── features/
│   ├── auth/
│   ├── residents/
│   ├── visits/
│   ├── incidents/
│   └── access-control/
│
├── hooks/
├── lib/
├── providers/
├── services/
├── styles/
└── types/
```

---

## 2. Create Nimbus Design Foundation

Define:

* spacing system
* typography
* layout shell
* dark mode
* sidebar
* topbar
* navigation system

---

## 3. Supabase Cloud Setup

Future tasks:

* create Supabase project
* configure authentication
* create schema
* create RLS policies
* configure environments

---

## 4. Mobile App Initialization

Future stack:

```txt
Flutter
Riverpod
GoRouter
Supabase
```

---

# Product Philosophy

Nimbus should feel:

* fast
* lightweight
* premium
* modern
* operationally invisible

The system should help operations flow naturally.

Avoid creating:

* visually noisy interfaces
* legacy-style admin panels
* overly dense screens

---

# Long-Term Technical Vision

Nimbus is designed to evolve into:

* large-scale SaaS platform
* multi-community infrastructure
* smart access ecosystem
* operational platform
* future smart infrastructure hub

Potential future integrations:

* smart gates
* IoT
* CCTV
* EV infrastructure
* energy systems
* AI monitoring

These are intentionally deferred until the core platform is stable.

---

# Important Rule

Before implementing major features:

1. define architecture
2. define flow
3. define permissions
4. define data model
5. define edge cases
6. only then implement

Nimbus should grow intentionally.

