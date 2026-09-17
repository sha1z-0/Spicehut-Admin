# In-House Table Management Backend - Implementation Guide

## 🎯 Overview

Complete backend implementation for location-based in-house table management with MongoDB collections isolated per restaurant location.

---

## 📦 Database Architecture

### Collection Strategy
**Pattern:** `tables_<LocationName>`

**Example Collections:**
- `tables_Comox`
- `tables_PortAlberni`
- `tables_Canbook`
- `tables_CampbellRiver`
- `tables_Courtenay`
- `tables_FortSaskatchewan`
- `tables_Victoria`
- `tables_Vancouver`
- `tables_Kelowna`
- `tables_Kamloops`

### Document Structure

Each collection contains a single **floor plan document** with embedded sections and tables:

```json
{
  "type": "floorplan",
  "branchId": "Comox",
  "branchName": "Comox",
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
          "currentOrder": [],
          "assignedWaiter": null,
          "billTotal": null,
          "lastModified": "2026-01-19T..."
        }
      ]
    }
  ],
  "lastSynced": "2026-01-19T...",
  "updatedBy": "admin@example.com",
  "updatedAt": "2026-01-19T..."
}
```

### Table Status Values
- `available` - Green
- `occupied` - Red  
- `reserved` - Blue

### Table Shapes
- `circle`
- `square`
- `rectangle`

### Section Types
- `main_hall`
- `outdoor`
- `vip_room`
- `private_dining`

---

## 🔌 API Endpoints

### Base URL
`http://localhost:4000/api`

### Authentication
All endpoints require JWT token in header:
```
Authorization: Bearer <token>
```

---

### 1. **GET** `/tables/floorplan`

**Fetch floor plan and all tables for a location**

**Query Parameters:**
- `branch` or `location` (optional for admin, ignored for branch admin)

**Response:**
```json
{
  "success": true,
  "data": {
    "branchId": "Comox",
    "branchName": "Comox",
    "sections": [...],
    "lastSynced": "2026-01-19T..."
  },
  "location": "Comox"
}
```

**Permissions:**
- **Admin:** Can request any location
- **Branch Admin:** Only their assigned branch

---

### 2. **PATCH** `/tables/floorplan`

**Save/Update floor plan for a location**

**Request Body:**
```json
{
  "branchId": "Comox",
  "sections": [
    {
      "id": "main_hall",
      "name": "Main Hall",
      "type": "main_hall",
      "tables": [...]
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "message": "Floor plan saved successfully",
  "data": {...}
}
```

**Permissions:**
- **Admin:** Can save any location
- **Branch Admin:** Only their assigned branch

---

### 3. **GET** `/tables`

**Fetch all tables across all sections for a location**

**Query Parameters:**
- `branch` or `location` (optional for admin)

**Response:**
```json
{
  "success": true,
  "data": [...all tables with sectionName and sectionType...],
  "location": "Comox",
  "totalTables": 26
}
```

---

### 4. **PUT** `/tables/:tableId`

**Update a specific table's status/order/bill**

**URL Parameter:**
- `tableId` - Table ID to update

**Request Body:**
```json
{
  "location": "Comox",
  "sectionId": "main_hall",
  "updateData": {
    "_id": "t_main_hall_1",
    "name": "T1",
    "status": "occupied",
    "currentOrder": [...],
    "billTotal": 45.50,
    ...
  }
}
```

**Permissions:**
- **Admin:** Can update any location
- **Branch Admin:** Only their branch

---

### 5. **POST** `/tables`

**Add a new table to a section**

**Request Body:**
```json
{
  "location": "Comox",
  "sectionId": "main_hall",
  "table": {
    "name": "T27",
    "number": 27,
    "capacity": 4,
    "posX": 100,
    "posY": 100,
    "width": 80,
    "height": 80,
    "shape": "circle",
    ...
  }
}
```

**Permissions:**
- **Admin only**

---

### 6. **DELETE** `/tables/:tableId`

**Remove a table**

**URL Parameter:**
- `tableId` - Table ID to delete

**Query Parameters:**
- `location` - Location name
- `sectionId` - Section ID

**Example:**
```
DELETE /api/tables/t_main_hall_5?location=Comox&sectionId=main_hall
```

**Permissions:**
- **Admin only**

---

### 7. **GET** `/tables/locations`

**Get list of all valid locations**

**Response:**
```json
{
  "success": true,
  "locations": [
    "Comox",
    "PortAlberni",
    "Canbook",
    ...
  ]
}
```

---

## 🔒 Security & Validation

### Location Validation
```javascript
const VALID_LOCATIONS = [
  'Comox', 'PortAlberni', 'Canbook',
  'Campbell River', 'Courtenay', 'Fort Saskatchewan',
  'Victoria', 'Vancouver', 'Kelowna', 'Kamloops'
];
```

### Dynamic Collection Resolution
```javascript
function getTableCollectionName(location) {
  // Normalizes spaces: "Port Alberni" → "PortAlberni"
  const normalizedLocation = location.replace(/\s+/g, '');
  
  // Validates against VALID_LOCATIONS
  if (!isValid) {
    throw new Error('Invalid location');
  }
  
  return `tables_${normalizedLocation}`;
}
```

### Permission Checks
- ✅ JWT token verification on all endpoints
- ✅ Role-based access (admin vs branchAdmin)
- ✅ Branch isolation for branch admins
- ✅ Admin-only operations for create/delete

---

## 🌱 Database Seeding

### Seed Tables for All Locations

**Run:**
```bash
cd backend
npm run seed:tables
```

**What it does:**
- Creates floor plan documents for all 10 locations
- Generates 4 sections per location (Main Hall, Outdoor, VIP, Private Dining)
- Creates 26 sample tables per location
- Skips locations that already have data

**Output:**
```
✅ Comox: Created floor plan with 4 sections and 26 tables
✅ PortAlberni: Created floor plan with 4 sections and 26 tables
...
```

---

## 📱 Flutter Integration

### Fetch Floor Plan
```dart
final response = await ApiService.get('/tables/floorplan?location=$_userBranch');
final data = response['data'];
```

### Save Floor Plan
```dart
await ApiService.patch('/tables/floorplan', {
  'branchId': _userBranch,
  'sections': _floorPlan.sections.map((s) => {
    'id': s.id,
    'name': s.name,
    'type': s.type.toString().split('.').last,
    'tables': s.tables.map((t) => t.toJson()).toList(),
  }).toList(),
});
```

---

## 🔄 Data Flow

### Save Operation
1. User edits floor plan in Flutter app
2. User clicks "Save" button
3. Flutter calls `PATCH /api/tables/floorplan`
4. Backend validates location and permissions
5. Backend resolves collection name (`tables_Comox`)
6. Backend upserts floor plan document
7. Success response returned

### Load Operation
1. Flutter screen initializes
2. Fetches user's branch from AuthService
3. Calls `GET /api/tables/floorplan?location=Comox`
4. Backend validates permissions
5. Backend resolves collection (`tables_Comox`)
6. Backend fetches floor plan document
7. Flutter parses and displays tables

---

## 🛡️ Data Isolation Guarantees

✅ **Collection-level isolation:** Each location has its own MongoDB collection

✅ **No cross-location queries:** Collection name is resolved dynamically per request

✅ **Permission enforcement:** Branch admins can only access their assigned location

✅ **Validation:** Invalid location names are rejected before database access

✅ **Audit trail:** `updatedBy` and `updatedAt` fields track changes

---

## 🧪 Testing

### Test Flow
1. Start backend: `npm run dev`
2. Seed data: `npm run seed:tables`
3. Login as branch admin (e.g., `comox@spicehut.com`)
4. Open In-House Orders screen
5. Verify tables load for Comox only
6. Try editing and saving floor plan
7. Verify data persists in `tables_Comox` collection

### MongoDB Verification
```javascript
// Check collection exists
use spicehut_admin

// List all table collections
show collections

// Query Comox tables
db.tables_Comox.find({ type: 'floorplan' }).pretty()

// Query PortAlberni tables
db.tables_PortAlberni.find({ type: 'floorplan' }).pretty()
```

---

## 📊 Collection Summary

| Location | Collection Name | Sections | Tables |
|----------|----------------|----------|--------|
| Comox | `tables_Comox` | 4 | 26 |
| Port Alberni | `tables_PortAlberni` | 4 | 26 |
| Canbook | `tables_Canbook` | 4 | 26 |
| Campbell River | `tables_CampbellRiver` | 4 | 26 |
| Courtenay | `tables_Courtenay` | 4 | 26 |
| Fort Saskatchewan | `tables_FortSaskatchewan` | 4 | 26 |
| Victoria | `tables_Victoria` | 4 | 26 |
| Vancouver | `tables_Vancouver` | 4 | 26 |
| Kelowna | `tables_Kelowna` | 4 | 26 |
| Kamloops | `tables_Kamloops` | 4 | 26 |

---

## ✅ Implementation Checklist

- [x] Dynamic collection resolver with validation
- [x] GET endpoint for fetching floor plans
- [x] PATCH endpoint for saving floor plans
- [x] GET endpoint for listing all tables
- [x] PUT endpoint for updating individual tables
- [x] POST endpoint for adding new tables
- [x] DELETE endpoint for removing tables
- [x] Location validation and error handling
- [x] Permission checks (admin vs branchAdmin)
- [x] Data isolation per location
- [x] Seed script for initial data
- [x] Flutter screen integration
- [x] Documentation

---

## 🚀 Next Steps

1. Run seed script to populate data
2. Test with different user roles
3. Verify data isolation between locations
4. Add real-time order management features
5. Implement bill calculation logic
6. Add waiter assignment functionality

---

**Status:** ✅ Fully Implemented & Ready for Testing
