# Nimbus — Permissions System

# Philosophy

Nimbus uses a dynamic RBAC system:
(Role-Based Access Control)

Permissions must:
- remain scalable
- remain explicit
- avoid hardcoded logic
- support future expansion

Authorization is handled server-side.

Frontend checks are only for UX purposes.

---

# Core Principles

## No Hardcoded Roles

Avoid logic like:

```ts id="i9umv3"
if (user.role === 'admin')
