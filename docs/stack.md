# Nimbus — Technology Stack

# Philosophy

Nimbus follows a "boring tech" philosophy.

The project prioritizes:
- stability
- simplicity
- maintainability
- scalability
- developer experience

Avoid unnecessary complexity.

The goal is not to use trendy technologies.
The goal is to build a reliable and scalable product.

---

# Core Stack

## Mobile App

### Flutter

Used for:
- iOS app
- Android app

Reasons:
- single codebase
- native-like performance
- excellent UI consistency
- fast development
- ideal for realtime mobile applications

---

## Admin Dashboard

### Next.js

Used for:
- administration panel
- internal dashboards
- future web portal

Reasons:
- production-ready React framework
- excellent routing and layouts
- optimized performance
- server-side rendering support
- scalable architecture
- modern React ecosystem standard

---

## Backend

### Supabase

Used for:
- authentication
- PostgreSQL database
- realtime subscriptions
- storage
- edge functions

Reasons:
- fast development
- excellent PostgreSQL integration
- built-in auth
- row-level security
- realtime infrastructure
- lower backend complexity

---

## Database

### PostgreSQL

Reasons:
- relational consistency
- strong performance
- excellent scalability
- advanced security support
- ideal for multi-tenant systems
- mature ecosystem

---

# Architecture Style

Nimbus uses:
- monorepo architecture
- modular structure
- shared packages
- shared types
- centralized configuration

---

# Monorepo Structure

```txt
/apps
/packages
/docs
/supabase
