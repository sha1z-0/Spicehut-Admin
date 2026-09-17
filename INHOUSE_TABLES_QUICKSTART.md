# Quick Start Guide - In-House Table Management

## 🚀 Setup & Testing

### Step 1: Start Backend Server
```bash
cd backend
npm run dev
```

Expected output:
```
🚀 SpiceHut Admin Backend running on http://localhost:4000
📊 MongoDB: Connected
🔐 JWT Authentication: Enabled
```

### Step 2: Seed Table Data
```bash
cd backend
npm run seed:tables
```

Expected output:
```
🌱 Starting table seeding for all locations...

✅ Comox: Created floor plan with 4 sections and 26 tables
✅ PortAlberni: Created floor plan with 4 sections and 26 tables
✅ Canbook: Created floor plan with 4 sections and 26 tables
✅ CampbellRiver: Created floor plan with 4 sections and 26 tables
✅ Courtenay: Created floor plan with 4 sections and 26 tables
✅ Fort Saskatchewan: Created floor plan with 4 sections and 26 tables
✅ Victoria: Created floor plan with 4 sections and 26 tables
✅ Vancouver: Created floor plan with 4 sections and 26 tables
✅ Kelowna: Created floor plan with 4 sections and 26 tables
✅ Kamloops: Created floor plan with 4 sections and 26 tables

🎉 Table seeding completed successfully!
```

### Step 3: Login to Flutter App

Use one of these test accounts:

**Admin Account:**
- Email: `admin@spicehut.com`
- Password: `Admin123!`
- Access: All locations

**Branch Admin - Comox:**
- Email: `comox@spicehut.com`
- Password: `Comox123!`
- Access: Comox only

**Branch Admin - Port Alberni:**
- Email: `portalberni@spicehut.com`
- Password: `PortAlberni123!`
- Access: Port Alberni only

### Step 4: Test In-House Orders Screen

1. Navigate to **In-House Orders** from the dashboard
2. You should see:
   - Floor plan sections (Main Hall, Outdoor Patio, VIP Room, Private Dining)
  - Tables with different statuses (available, reserved, occupied)
   - Section tabs at the top

### Step 5: Test Edit Mode (Admin Only)

1. Click the **Edit** icon in the app bar
2. Try:
   - Moving tables (drag and drop)
   - Rotating tables
   - Resizing tables
   - Adding new tables
   - Deleting tables
3. Click **Save** button
4. Verify changes persist after reload

---

## 🧪 API Testing with Postman/Thunder Client

### 1. Login
```http
POST http://localhost:4000/api/auth/login
Content-Type: application/json

{
  "email": "comox@spicehut.com",
  "password": "Comox123!"
}
```

Copy the `token` from response.

### 2. Get Floor Plan
```http
GET http://localhost:4000/api/tables/floorplan?location=Comox
Authorization: Bearer YOUR_TOKEN_HERE
```

### 3. Get All Tables
```http
GET http://localhost:4000/api/tables?location=Comox
Authorization: Bearer YOUR_TOKEN_HERE
```

### 4. Save Floor Plan
```http
PATCH http://localhost:4000/api/tables/floorplan
Authorization: Bearer YOUR_TOKEN_HERE
Content-Type: application/json

{
  "branchId": "Comox",
  "sections": [
    {
      "id": "main_hall",
      "name": "Main Hall",
      "type": "main_hall",
      "tables": [
        {
          "_id": "t_main_hall_1",
          "name": "T1",
          "number": 1,
          "capacity": 4,
          "status": "available",
          "posX": 40,
          "posY": 40,
          "width": 80,
          "height": 80,
          "rotation": 0,
          "shape": "circle",
          "sectionId": "main_hall",
          "currentOrder": []
        }
      ]
    }
  ]
}
```

### 5. Get Valid Locations
```http
GET http://localhost:4000/api/tables/locations
Authorization: Bearer YOUR_TOKEN_HERE
```

---

## 🗄️ MongoDB Verification

### Connect to MongoDB
```bash
mongosh "YOUR_MONGODB_URI"
```

### Check Collections
```javascript
use spicehut_admin
show collections
```

Expected collections:
```
adminusers
appmenuitems
tables_Comox
tables_PortAlberni
tables_Canbook
tables_CampbellRiver
tables_Courtenay
tables_FortSaskatchewan
tables_Victoria
tables_Vancouver
tables_Kelowna
tables_Kamloops
```

### Query Comox Tables
```javascript
db.tables_Comox.find({ type: 'floorplan' }).pretty()
```

### Count Tables in Each Location
```javascript
db.tables_Comox.findOne({ type: 'floorplan' }, { 'sections.tables': 1 })
```

### Delete All Table Data (if needed)
```javascript
db.tables_Comox.deleteMany({})
db.tables_PortAlberni.deleteMany({})
// etc.
```

---

## ✅ Verification Checklist

- [ ] Backend server running on port 4000
- [ ] MongoDB connected successfully
- [ ] 10 collections created (tables_Comox, etc.)
- [ ] Each collection has floor plan document
- [ ] Flutter app loads floor plan from backend
- [ ] Tables display correctly with proper status colors
- [ ] Edit mode works (admin only)
- [ ] Save functionality persists changes
- [ ] Branch admins can only see their location
- [ ] Admin can switch between locations
- [ ] No cross-location data mixing

---

## 🐛 Troubleshooting

### Tables Not Loading
1. Check backend console for errors
2. Verify MongoDB connection
3. Check if floor plan exists: `db.tables_Comox.find()`
4. Run seed script again: `npm run seed:tables`

### Permission Errors
1. Verify JWT token is valid
2. Check user's assigned branch matches location
3. Ensure admin users have proper role

### Save Not Working
1. Check network tab for API errors
2. Verify branchId matches user's location
3. Check backend logs for validation errors

### Wrong Location Data
1. Verify `_userBranch` in Flutter app
2. Check AuthService.getUserLocation()
3. Ensure API call includes correct location parameter

---

## 📞 Support

For issues or questions:
1. Check [INHOUSE_TABLES_BACKEND_DOCUMENTATION.md](INHOUSE_TABLES_BACKEND_DOCUMENTATION.md)
2. Review backend console logs
3. Check MongoDB data directly
4. Verify user permissions and roles

---

**Happy Testing! 🎉**
