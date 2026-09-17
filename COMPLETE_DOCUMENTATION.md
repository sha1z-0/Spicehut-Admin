# SpiceHut Admin System - Complete Documentation

**Version:** 1.0.0 | **Updated:** January 19, 2026

---

## 🏗️ Architecture Overview

**Frontend:** Flutter (Android/iOS/Web/Windows)  
**Backend:** Next.js + Node.js  
**Database:** MongoDB Atlas  
**Locations:** 10 branches | **Screens:** 9 | **API Endpoints:** 16+

---

## 🚀 Quick Start Commands

### Terminal 1: Backend
```bash
cd d:\Hamzaappp\Flutter\ App\ Admin\ Side\backend
npm start
# Expected: Server running at http://localhost:4000
```

### Terminal 2: Frontend
```bash
cd d:\Hamzaappp\Flutter\ App\ Admin\ Side
flutter run -d chrome
```

---

## 🔐 Test Credentials

| Role | Email | Password | Access |
|------|-------|----------|--------|
| Super Admin | `superadmin@spicehut.com` | Provided in backend | All branches |
| Manager | `admin.comox@spicehut.com` | Provided in backend | Comox only |

---

## 📱 Main Screens

1. **Sign In** - Email/password authentication with JWT
2. **Dashboard** - Stats, recent orders, quick actions
3. **Incoming Orders** - Real-time orders (15s polling), accept/reject/print
4. **Order History** - Filter by day/month/year, analytics charts
5. **Analytics** - Income tracking, period toggle, top items
6. **In-House Orders** - Table management, order capture, bill printing
7. **Menu Management** - Admin-only CRUD for menu items (image picker)
8. **User Management** - Admin-only staff/manager creation with email/password
9. **Printer Setup** - Setup guide for thermal printers (Android/iOS)

---

## 🔌 API Endpoints

### Authentication
- `POST /auth/login` - Login with email/password → returns JWT token

### Orders
- `GET /orders` - Fetch orders (branch-filtered, status filterable)
- `PATCH /orders/{id}` - Update order status (accept/reject)

### Users
- `GET /users` - Fetch users (branch-filtered)
- `POST /users` - Create user (admin-only, with email/password)
- `PUT /users/{id}` - Update user (name, isActive)
- `PATCH /users/{id}` - Update user (isActive status toggle)
- `DELETE /users/{id}` - Delete user

### Menu
- `GET /menu` - Fetch menu items
- `POST /menu` - Create item (admin-only)
- `PUT /menu/{id}` - Update item
- `DELETE /menu/{id}` - Delete item

### Tables
- `GET /tables` - Fetch in-house tables
- `POST /tables` - Create table (admin-only)
- `PATCH /tables/{id}` - Update table (order, bill, reset)
- `DELETE /tables/{id}` - Delete table

### Analytics
- `GET /analytics?period=weekly|monthly|yearly` - Income/sales data

### Branches
- `GET /branches` - Fetch all branches (admin-only)

---

## 📊 Database Schema

### Admin Users
```json
{
  "_id": "ObjectId",
  "name": "String",
  "email": "String",
  "password": "HashedString",
  "role": "admin|manager|staff",
  "staffRole": "waiter|cashier|kitchen|delivery",
  "branches": ["BranchNames"],
  "isActive": Boolean,
  "createdAt": "DateTime",
  "updatedAt": "DateTime"
}
```

### Orders
```json
{
  "_id": "ObjectId",
  "orderNumber": "String",
  "items": [{"name", "price", "quantity", "category"}],
  "totalAmount": "Number",
  "status": "pending|accepted|rejected",
  "branch": "String",
  "createdAt": "DateTime"
}
```

### Menu Items
```json
{
  "_id": "ObjectId",
  "name": "String",
  "description": "String",
  "price": "Number",
  "category": "String",
  "imageUrl": "String",
  "isActive": Boolean
}
```

### In-House Tables
```json
{
  "_id": "ObjectId",
  "number": "Number",
  "seats": "Number",
  "status": "available|occupied|billPending",
  "bill": {"amount": "Number", "items": []},
  "branch": "String"
}
```

---

## ⚙️ Configuration

### API Base URL (api_service.dart)
```dart
// Local development
static const String baseUrl = 'http://localhost:4000/api';

// Android Emulator
'http://10.0.2.2:4000/api'

// Physical Device (use your PC IP)
'http://192.168.x.x:4000/api'
```

### Environment (.env.local)
```
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/spicehutDB
JWT_SECRET=your-secret-key
NODE_ENV=development
```

---

## 🎨 Design System

- **Primary Color:** Orange (#FF7A00)
- **Theme:** Material 3
- **Icons:** Material Icons
- **Typography:** Responsive text scaling
- **Spacing:** 12-16px padding, consistent gaps
- **Buttons:** Orange primary, gray secondary, danger red

---

## 📋 File Structure

```
Flutter App Admin Side/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── sign_in_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── incoming_orders_screen.dart
│   │   ├── order_history_screen.dart
│   │   ├── analytics_screen.dart
│   │   ├── in_house_orders_screen.dart
│   │   ├── menu_management_screen.dart
│   │   ├── user_management_screen.dart
│   │   └── privacy_policy_modal.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── auth_service.dart
│   │   └── printing_service.dart
│   ├── models/
│   │   └── menu_item.dart
│   └── widgets/
│       └── printer_setup_guide_modal.dart
├── backend/
│   ├── server.js
│   ├── models/
│   │   └── AdminUser.ts
│   └── .env.local
├── assets/
│   ├── logo/spicehut_logo.png
│   └── sounds/ringtone.mp3
└── pubspec.yaml
```

---

## 🔧 Key Features & Implementation

### Authentication Flow
1. User enters email/password on login screen
2. POST to `/auth/login` returns JWT token
3. Token stored in SharedPreferences
4. JWT injected in all API requests via Authorization header
5. Logout clears token, redirects to login

### Real-Time Orders
- Polls `/orders?status=incoming` every 15 seconds
- Plays ringtone when new orders arrive (audioplayers package)
- Auto-rejects orders after 15 minutes
- Accept/Reject buttons trigger status updates

### Order History Analytics
- Dual filtering: date range (day/month/year) + time of day (Morning/Afternoon/Evening/Night)
- BarChart visualization with fl_chart
- Admin-only delete functionality
- Order details in bottom sheet

### User Management (New)
- Admin-only screen with role guards
- Create users with: name, email, password, role (manager/staff), staff sub-role
- Branch assignment from dropdown
- Enable/Disable workflow (soft delete, not hard delete)
- Edit dialog for name and status changes
- Color-coded role badges (orange=admin, blue=manager, green=staff)

### In-House Tables
- Grid view of tables (3 columns, responsive)
- Take Order: multi-select items, save to table bill
- Print Bill: display items, total, then reset table
- Admin can add/remove tables, managers see assigned tables only

### Menu Management
- List view with admin edit/delete buttons
- Create/Edit dialog with image picker (stores file path)
- Category-based display

### Printer Integration
- Static setup guide modal (Android: 4 steps, iOS: 5 steps)
- Accessible from all main screens via sidebar
- Informational only (real printing not yet implemented)

---

## 🛡️ Security

- **JWT Authentication:** HS256 algorithm
- **Password Hashing:** bcrypt (backend)
- **Authorization:** Role-based guards (admin-only screens)
- **CORS:** Configured for localhost development
- **Token Expiration:** 24 hours

---

## 🐛 Known Issues & Fixes

1. **BuildContext across async gaps:** All async operations now guarded with `if (mounted)` before accessing context
2. **Schema updates:** User model updated to use name/email/password instead of PIN
3. **PATCH method:** Added to MockApi for user/order status updates
4. **Unused imports:** Removed from screens without drawers

---

## 📝 Development Workflow

### Before Making Changes
1. Read recent changes in this doc
2. Check current branch/environment

### After Making Changes
1. Update this documentation (edit relevant section)
2. Test on emulator/device
3. Run `flutter analyze` for lint issues
4. Commit with descriptive message

---

## 🚀 Deployment Checklist

- [ ] `flutter clean && flutter pub get`
- [ ] No lint/syntax errors: `flutter analyze`
- [ ] All screens compile without errors
- [ ] Backend running at correct port (4000)
- [ ] MongoDB connection verified
- [ ] Test credentials work
- [ ] All main features tested on device

---

## 📞 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Connection refused" | Check backend running (`npm start`), verify baseUrl in api_service.dart |
| "Login fails" | Verify credentials in backend database, check MongoDB connection |
| "White screen" | Check Android manifest has internet permission, try `flutter clean` |
| "Image picker crashes" | Ensure permissions set in AndroidManifest.xml and Info.plist |
| "Orders not loading" | Check branch parameter, verify user role/branch assignment |
| "Printer setup unavailable" | Verify import in screen, check drawer building code |

---

## 📚 Additional Resources

- Flutter Docs: https://flutter.dev
- Next.js Docs: https://nextjs.org
- MongoDB Docs: https://docs.mongodb.com
- JWT Intro: https://jwt.io

---

**Last Updated:** January 19, 2026  
**Maintained By:** Development Team  
**Status:** Active & Production Ready
