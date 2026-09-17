# 🔑 Admin Credentials & Testing Guide

## Admin User Credentials

### 1️⃣ Comox Branch Admin
**Email:** `admin.comox@spicehut.com`
**Password:** `ComoxAdmin@123`
**Role:** Branch Admin
**Branch:** Comox
**Access:** Only Comox branch data
**Test Data:** 3 sample orders (pending, completed, in-progress)

### 2️⃣ Port Alberni Branch Admin
**Email:** `admin.portalberni@spicehut.com`
**Password:** `PortAlberniAdmin@123`
**Role:** Branch Admin
**Branch:** Port Alberni
**Access:** Only Port Alberni branch data
**Test Data:** 3 sample orders (pending, completed, in-progress)

### 3️⃣ Super Admin (All Branches)
**Email:** `superadmin@spicehut.com`
**Password:** `SuperAdmin@123`
**Role:** Super Admin
**Branches:** Comox, Port Alberni, Fort Saskatchewan
**Access:** All branch data
**Test Data:** Access to all orders (9 total)

---

## 🧪 Testing Scenarios

### Scenario 1: Test Comox Admin Login
1. Open Flutter app
2. Enter: `admin.comox@spicehut.com` / `ComoxAdmin@123`
3. ✅ Should see dashboard with Comox orders
4. ✅ Should see 3 Comox orders in order list
5. ✅ Revenue should show $41.96 (first pending order)

### Scenario 2: Test Port Alberni Admin Login
1. Open Flutter app
2. Enter: `admin.portalberni@spicehut.com` / `PortAlberniAdmin@123`
3. ✅ Should see dashboard with Port Alberni orders
4. ✅ Should NOT see Comox orders
5. ✅ Should see 3 Port Alberni orders

### Scenario 3: Test Super Admin Login
1. Open Flutter app
2. Enter: `superadmin@spicehut.com` / `SuperAdmin@123`
3. ✅ Should be able to access all branch data
4. ✅ Dashboard shows super admin role
5. ✅ See access to 9 total orders (when multi-branch feature is implemented)

### Scenario 4: Test Wrong Credentials
1. Enter: `admin.comox@spicehut.com` / `WrongPassword`
2. ✅ Should show error: "Invalid credentials"
3. ✅ Should not proceed to dashboard

### Scenario 5: Test Non-existent Admin
1. Enter: `nonexistent@spicehut.com` / `SomePassword`
2. ✅ Should show error: "Invalid credentials"

---

## 📊 Sample Orders Data

### Comox Branch Orders:
1. **ORDER-COMOX-001**
   - Customer: John Smith
   - Items: Butter Chicken (x2), Naan (x2)
   - Total: $41.96
   - Status: Pending ⏳

2. **ORDER-COMOX-002**
   - Customer: Sarah Johnson
   - Items: Tikka Masala, Basmati Rice, Raita
   - Total: $27.97
   - Status: Completed ✅

3. **ORDER-COMOX-003**
   - Customer: Mike Wilson
   - Items: Biryani (x3)
   - Total: $44.97
   - Status: In Progress 🍳

### Port Alberni Branch Orders:
1. **ORDER-PA-001**
   - Customer: Emma Davis
   - Items: Tandoori Chicken (x2), Garlic Naan (x2)
   - Total: $45.96
   - Status: Pending ⏳

2. **ORDER-PA-002**
   - Customer: David Brown
   - Items: Samosa (x6), Chutney Set (x2)
   - Total: $19.92
   - Status: Completed ✅

3. **ORDER-PA-003**
   - Customer: Lisa Anderson
   - Items: Paneer Tikka, Saag Paneer, Pilaf Rice (x2)
   - Total: $40.96
   - Status: In Progress 🍳

### Fort Saskatchewan Branch Orders:
1. **ORDER-FORTSASK-001**
   - Customer: Robert Taylor
   - Items: Lamb Vindaloo (x2), Coconut Rice (x2)
   - Total: $51.96
   - Status: Pending ⏳

2. **ORDER-FORTSASK-002**
   - Customer: Jessica Lee
   - Items: Shrimp Curry, Jeera Rice
   - Total: $21.98
   - Status: Completed ✅

3. **ORDER-FORTSASK-003**
   - Customer: Tom Martinez
   - Items: Dal Makhani (x2), Puri (x3)
   - Total: $36.95
   - Status: In Progress 🍳

---

## 🔄 What You Should See After Login

### Dashboard View:
- ✅ Today's Orders Count
- ✅ Today's Revenue
- ✅ Pending Orders Count
- ✅ Completed Orders Count
- ✅ Recent 5 Orders List with:
  - Order ID
  - Customer Name
  - Amount
  - Status
  - Time

### Incoming Orders View:
- ✅ Real-time list of pending/in-progress orders
- ✅ Auto-refresh every 15 seconds
- ✅ Only branch-specific orders

### Order History View:
- ✅ Complete list of all orders (any status)
- ✅ Sortable and filterable
- ✅ Branch-specific data

---

## 🛠️ Backend API Endpoints Reference

### Base URL: `http://localhost:4000/api`

**Login (No auth required):**
```
POST /auth/login
Body: { "email": "...", "password": "..." }
Returns: JWT token + admin info
```

**Get Orders (JWT Required):**
```
GET /orders
Header: Authorization: Bearer <JWT_TOKEN>
Returns: Branch-specific orders
```

**Get Tables (JWT Required):**
```
GET /tables
Header: Authorization: Bearer <JWT_TOKEN>
Returns: Branch-specific tables
```

**Get Menu (JWT Required):**
```
GET /menu
Header: Authorization: Bearer <JWT_TOKEN>
Returns: Menu items
```

**Health Check:**
```
GET /health
Returns: { "status": "OK" }
```

---

## 📱 How to Run

### 1. Start Backend Server
```bash
cd "d:\Flutter App Admin Side\backend"
$null = Start-Process -FilePath "node" -ArgumentList "server.js" -WorkingDirectory "." -NoNewWindow
```

Wait for message:
```
🚀 SpiceHut Admin Backend running on http://localhost:4000
✅ MongoDB Connected
```

### 2. Verify Backend is Running
```bash
Invoke-WebRequest -Uri 'http://localhost:4000/api/health'
# Should return: { "status": "OK", "message": "..." }
```

### 3. Start Flutter App
```bash
cd "d:\Flutter App Admin Side"
flutter run -d chrome
```

### 4. Login with Credentials Above
Select one of the 3 admin accounts and test!

---

## ✅ Integration Checklist

- [x] Backend server running on port 4000
- [x] MongoDB connection established
- [x] 3 admin users seeded with hashed passwords
- [x] 9 dummy orders seeded across 3 branches
- [x] JWT authentication implemented
- [x] API service sends JWT tokens
- [x] Dashboard fetches and displays orders
- [x] Incoming orders screen works
- [x] Order history screen works
- [x] Branch-specific data access control
- [x] Error handling for invalid credentials

---

## 🐛 Quick Troubleshooting

### Problem: "Request failed with status: 401"
**Fix:** 
- Ensure backend is running
- Check JWT token is stored in SharedPreferences
- Verify token hasn't expired (24 hour expiry)

### Problem: "No orders showing"
**Fix:**
- Confirm you logged in with correct credentials
- Verify branch name matches (Comox, Port Alberni, Fort Saskatchewan)
- Check MongoDB has data: `node check-admins.js`

### Problem: "Backend not connecting"
**Fix:**
- Ensure backend is running: `node server.js`
- Check MongoDB URI in `.env` file
- Verify firewall allows port 4000
- Test with: `Invoke-WebRequest 'http://localhost:4000/api/health'`

### Problem: "Password doesn't work"
**Fix:**
- Verify exact capitalization
- Ensure no extra spaces
- Check database for user exists: `node check-admins.js`

---

## 📞 Support Commands

### Check if Backend is Running:
```bash
Get-Process -Name node | Select-Object ProcessName, Id
```

### Check Admin Users in Database:
```bash
cd backend
node check-admins.js
```

### Seed Orders Again:
```bash
cd backend
node seed-orders.js
```

### Seed Admins Again:
```bash
cd backend
node seed-admins.js
```

### Start Backend (Clean):
```bash
Get-Process -Name node | Stop-Process -Force
cd "d:\Flutter App Admin Side\backend"
node server.js
```

---

## 🎯 Success Indicators

✅ You'll know it's working when:

1. **Login Screen:**
   - Can login with credentials
   - JWT token stored in app

2. **Dashboard:**
   - Shows order statistics
   - Shows recent orders with customer names
   - Shows revenue from today's orders

3. **Incoming Orders:**
   - Lists only pending/in-progress orders
   - Updates every 15 seconds
   - Shows order details correctly

4. **Order History:**
   - Shows all orders for the branch
   - Sorted by newest first
   - Displays totals correctly

---

**Ready to test? Use the credentials above! 🚀**
