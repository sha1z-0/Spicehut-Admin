# Progress Report (Frontend, Backend, Database)

Date: January 20, 2026

## Scope Summary
Work completed across Flutter frontend, Express/MongoDB backend, and data consistency for User Management, RBAC, branch handling, in‑house tables stability, and UI access controls.

---

## ✅ Backend (Express + MongoDB)
### User Management (adminusers collection)
- **Routes added/updated** in [backend/server.js](backend/server.js):
  - `POST /api/users` (admin only): create Manager/Staff with **branch + branches** validation, staffRole validation, email uniqueness.
  - `GET /api/users` (admin or manager):
    - Admin: all users, optional `branch` filter.
    - Manager: only own branch.
    - Staff: forbidden.
  - `PUT /api/users/:id` (admin only): **name** and optional **staffRole** only. **Activation updates deprecated** (isActive rejected).
  - `DELETE /api/admin-users/:userId` (admin only): permanent delete; prevents self‑delete (403), returns 404 if not found.

### Auth & RBAC
- `requireAuth` validates JWT and checks `isActive`.
- `requireRole(['admin'])` for privileged routes.
- **Role normalization**:
  - `superAdmin` → `admin`
  - `branchAdmin` → `manager`
- **Branch normalization** (Nanaimo → Fort Saskatchewan) applied to:
  - `/api/branches` response
  - `/api/users` filter/response
  - user JWT / login response

### Analytics
- `/api/analytics` now blocks staff (403) and uses normalized role.

### Floor Plan Stability
- Fixed `ReferenceError: updateData is not defined` in `/api/tables/floorplan` GET.

---

## ✅ Frontend (Flutter)
### Auth / Role
- `UserRole` expanded to include `staff` in [lib/services/auth_service.dart](lib/services/auth_service.dart).
- Login maps backend roles to `admin`, `manager`, `staff`.

### User Management UI
- Added `branch` field to AdminUser model.
- Create user payload now sends:
  - `branch` and `branches: [branch]` (explicit branch enforcement)
- Disable/Enable removed. **Delete** added with confirmation.
- Delete calls `DELETE /admin-users/:id`.

### Menu Management (frontend)
- Admin‑only access enforced in [lib/screens/menu_management_screen.dart](lib/screens/menu_management_screen.dart).
- Non‑admin redirected to Dashboard with Access Denied Snackbar.

### Drawer / Navigation Restrictions
- **Admin‑only**: Menu Management, User Management, Analytics, Dashboard.
- **Staff allowed screens only**: Incoming Orders, Order History, In‑House Tables, Printer Setup.

Implementation updated in drawers across:
- [lib/screens/dashboard_screen.dart](lib/screens/dashboard_screen.dart)
- [lib/screens/incoming_orders_screen.dart](lib/screens/incoming_orders_screen.dart)
- [lib/screens/order_history_screen.dart](lib/screens/order_history_screen.dart)
- [lib/screens/analytics_screen.dart](lib/screens/analytics_screen.dart)
- [lib/screens/user_management_screen.dart](lib/screens/user_management_screen.dart)

### Analytics UI
- Staff redirected away from Analytics to Incoming Orders.

### In‑House Tables UI
- Prevented “Bad state: No element” by:
  - Guarding empty sections in `_getCurrentSection()`
  - Empty‑state UI when no sections

---

## ✅ Database & Schema Consistency
- Collection: **adminusers** (existing).
- Aligned fields between backend & frontend:
  - `name`, `email`, `password`, `role`, `staffRole?`, `branch?`, `branches`, `isActive`, `lastLogin`, `createdAt`, `updatedAt`.
- Backend AdminUser schema updated to include `staffRole`, `branch`, `branches`, role enums.

---

## ✅ Known Fixes Applied
1. **User list 404**
   - Cause: old server process did not include `/api/users` route.
   - Fix: restart backend (ensure correct working directory).
2. **User delete 404**
   - Cause: stale server not loaded with `/api/admin-users/:id` route.
   - Fix: restart backend.
3. **In‑House Tables crash**
   - Cause: backend floorplan GET used undefined `updateData`.
   - Fix: removed usage + frontend empty‑state guard.
4. **Nanaimo → Fort Saskatchewan**
   - Backend normalization ensures dropdowns/list display Fort Saskatchewan.

---

## ✅ Remaining Items / TODOs
- **Staff access enforcement** on additional screens if any remain (verify non‑drawer deep links).
- Ensure backend is running current version (routes exist).
- Possibly add backend guard for dashboard data if staff access must be blocked at API level.

---

## ✅ Current API Contracts (Key)
### User Management
- `POST /api/users` (admin)
  - body: `name`, `email`, `password`, `role`, `branch`, `branches`, `staffRole?`, `isActive`
- `GET /api/users` (admin/manager)
  - optional `branch` query
- `PUT /api/users/:id` (admin)
  - body: `name`, optional `staffRole`
- `DELETE /api/admin-users/:id` (admin)

### Analytics
- `GET /api/analytics?period=day|month|year&branch=...` (admin/manager only)

---

## ✅ How to Resume Next Session
1. Start backend:
   - `node server.js` from `backend/`
2. Start Flutter app:
   - `flutter run -d chrome`
3. Verify staff access:
   - Only Incoming Orders, Order History, In‑House Tables, Printer Setup visible.
4. Verify delete user:
   - Admin delete should succeed and update list.
5. Verify branches:
   - Dropdowns show Fort Saskatchewan instead of Nanaimo.

---

## Files Modified (Key)
- [backend/server.js](backend/server.js)
- [backend/models/AdminUser.ts](backend/models/AdminUser.ts)
- [lib/services/auth_service.dart](lib/services/auth_service.dart)
- [lib/screens/user_management_screen.dart](lib/screens/user_management_screen.dart)
- [lib/screens/menu_management_screen.dart](lib/screens/menu_management_screen.dart)
- [lib/screens/dashboard_screen.dart](lib/screens/dashboard_screen.dart)
- [lib/screens/incoming_orders_screen.dart](lib/screens/incoming_orders_screen.dart)
- [lib/screens/order_history_screen.dart](lib/screens/order_history_screen.dart)
- [lib/screens/analytics_screen.dart](lib/screens/analytics_screen.dart)
- [lib/screens/in_house_orders_screen.dart](lib/screens/in_house_orders_screen.dart)

---

## Notes
- Backend role normalization is critical for legacy values (`superAdmin`, `branchAdmin`).
- Branch normalization maps `Nanaimo` → `Fort Saskatchewan` at API layer (no DB migration performed).
- User delete is **permanent** and blocks self‑delete.
