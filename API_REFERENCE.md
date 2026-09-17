# SpiceHut Admin Backend - Complete API Reference

## Base URL
```
http://localhost:4000/api
```

## Authentication
All endpoints (except `/health`) require JWT token in header:
```
Authorization: Bearer {token}
```

---

## 🔐 Auth Endpoints

### POST /auth/login
Login with email and password

**Request:**
```json
{
  "email": "superadmin@spicehut.com",
  "password": "SuperAdmin@123"
}
```

**Response (200):**
```json
{
  "success": true,
  "token": "eyJhbGc...",
  "admin": {
    "adminId": "507f1f77bcf86cd799439011",
    "email": "superadmin@spicehut.com",
    "name": "Super Admin",
    "role": "admin",
    "branch": null,
    "branches": ["Comox", "Port Alberni", "Fort Saskatchewan", ...]
  }
}
```

**Error Responses:**
- `400`: Missing credentials
- `401`: Invalid credentials

---

## 📦 Orders Endpoints

### GET /orders
Fetch orders for a branch with optional status filtering

**Query Parameters:**
- `branch` (required for admin, ignored for branchAdmin): Branch name
- `status` (optional): `incoming`, `accepted`, or `rejected`

**Examples:**
```bash
# Get all incoming orders (manager)
GET /orders?status=incoming

# Get accepted orders for Comox (admin)
GET /orders?status=accepted&branch=Comox

# Get all orders for Port Alberni
GET /orders?branch=Port%20Alberni
```

**Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "507f1f77bcf86cd799439011",
      "orderNumber": "#001",
      "totalAmount": 50.00,
      "status": "incoming",
      "createdAt": "2024-01-15T10:30:00Z",
      "items": [
        {
          "name": "Cheeseburger",
          "price": 15.00,
          "quantity": 1
        }
      ]
    }
  ],
  "branch": "Comox"
}
```

**Auto-Reject Logic:**
- Orders with `status: incoming` and `createdAt > 15 minutes ago` automatically updated to `status: rejected` on each GET request

---

### POST /orders
Create a new order

**Request Body:**
```json
{
  "branch": "Comox",  // Required for admin, ignored for branchAdmin
  "orderNumber": "#001",
  "totalAmount": 50.00,
  "customerAvatar": "👤",
  "items": [
    {
      "name": "Cheeseburger",
      "description": "With cheese and bacon",
      "price": 15.00,
      "quantity": 1,
      "imageUrl": "https://..."
    }
  ]
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "_id": "507f1f77bcf86cd799439011",
    "orderNumber": "#001",
    "status": "incoming",
    "totalAmount": 50.00,
    "createdAt": "2024-01-15T10:30:00Z",
    "branch": "Comox"
  }
}
```

**Notes:**
- New orders automatically created with `status: incoming`
- CreatedAt timestamp set automatically

---

### PATCH /orders/:orderId
Update order status (accept or reject)

**URL Parameters:**
- `orderId`: MongoDB ObjectId of the order

**Request Body:**
```json
{
  "status": "accepted",  // or "rejected"
  "branch": "Comox"      // Required for admin, ignored for branchAdmin
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "_id": "507f1f77bcf86cd799439011",
    "orderNumber": "#001",
    "status": "accepted",
    "acceptedAt": "2024-01-15T10:35:00Z",
    "updatedAt": "2024-01-15T10:35:00Z",
    "totalAmount": 50.00,
    "branch": "Comox"
  }
}
```

**Side Effects:**
- If status = "accepted":
  - Order timestamp set to `acceptedAt`
  - Document automatically inserted into `analytics{Branch}` collection with:
    ```json
    {
      "orderId": "507f1f77bcf86cd799439011",
      "amount": 50.00,
      "date": "2024-01-15T10:35:00Z",
      "branchName": "Comox",
      "itemCount": 1,
      "createdAt": "2024-01-15T10:35:00Z"
    }
    ```
- If status = "rejected":
  - Order timestamp set to `rejectedAt`
  - No analytics record created

**Error Responses:**
- `400`: Invalid status value
- `404`: Order not found

---

## 📍 Branches Endpoint

### GET /branches
Get available branches for current user

**Response (200):**
```json
{
  "success": true,
  "data": [
    "Comox",
    "Port Alberni",
    "Fort Saskatchewan",
    "Ladysmith",
    "Tofino",
    "Campbell River",
    "Cranbrook",
    "Invermere",
    "Canmore",
    "Lloydminster"
  ]
}
```

**Note:**
- Admin role returns all 10 branches
- branchAdmin role returns only assigned branch

---

## 📊 Analytics Endpoint

### GET /analytics
Fetch aggregated order analytics by time period

**Query Parameters:**
- `branch` (required for admin, ignored for branchAdmin): Branch name
- `period` (optional, default: "day"): `day`, `month`, or `year`

**Examples:**
```bash
# Daily analytics for Comox
GET /analytics?branch=Comox&period=day

# Monthly analytics for manager's branch
GET /analytics?period=month
```

**Response (200) - Daily:**
```json
{
  "success": true,
  "period": "day",
  "branch": "Comox",
  "data": [
    {
      "_id": {
        "year": 2024,
        "month": 1,
        "day": 15
      },
      "totalAmount": 250.50,
      "orderCount": 5
    },
    {
      "_id": {
        "year": 2024,
        "month": 1,
        "day": 16
      },
      "totalAmount": 180.00,
      "orderCount": 3
    }
  ]
}
```

**Response (200) - Monthly:**
```json
{
  "success": true,
  "period": "month",
  "branch": "Comox",
  "data": [
    {
      "_id": {
        "year": 2024,
        "month": 1
      },
      "totalAmount": 5200.50,
      "orderCount": 52
    },
    {
      "_id": {
        "year": 2024,
        "month": 2
      },
      "totalAmount": 4800.00,
      "orderCount": 48
    }
  ]
}
```

**Response (200) - Yearly:**
```json
{
  "success": true,
  "period": "year",
  "branch": "Comox",
  "data": [
    {
      "_id": 2023,
      "totalAmount": 45000.00,
      "orderCount": 450
    },
    {
      "_id": 2024,
      "totalAmount": 22500.00,
      "orderCount": 225
    }
  ]
}
```

**Data Aggregation:**
- Sums `amount` field from `analytics{Branch}` collection
- Counts number of records per period
- Only includes documents with `date` field (accepted orders)

---

## 🍽️ Tables Endpoint

### GET /tables
Fetch tables for a branch

**Query Parameters:**
- `branch` (required for admin, ignored for branchAdmin): Branch name

**Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "507f1f77bcf86cd799439011",
      "tableNumber": 1,
      "seats": 4,
      "status": "available",
      "bill": {
        "amount": 0,
        "items": []
      }
    }
  ]
}
```

---

## 🍕 Menu Endpoint

### GET /menu
Fetch menu items (global, not branch-specific)

**Response (200):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "507f1f77bcf86cd799439011",
      "name": "Cheeseburger",
      "description": "Classic cheeseburger with fries",
      "price": 15.00,
      "category": "Burgers",
      "imageUrl": "https://...",
      "available": true
    }
  ]
}
```

---

## ❤️ Health Check

### GET /health
Check backend status (no auth required)

**Response (200):**
```json
{
  "status": "OK",
  "message": "SpiceHut Admin Backend is running"
}
```

---

## 🔑 Role-Based Access Control

### Admin Role (`admin`)
- Can access data from **any branch**
- Must provide `branch` parameter in requests
- See all 10 branches in `/api/branches`
- Account: `superadmin@spicehut.com`

### Branch Manager Role (`branchAdmin`)
- Can access data from **their assigned branch only**
- `branch` parameter ignored in requests (uses `branch` from JWT)
- See only their assigned branch in `/api/branches`
- Example accounts:
  - `admin.comox@spicehut.com` (Comox branch)
  - `admin.portalberni@spicehut.com` (Port Alberni branch)

---

## 🗂️ MongoDB Collections

### Collections by Branch
For each branch, these collections exist (example: Comox):
- `ordersComox` - All orders with status field
- `analyticsComox` - Accepted orders analytics data
- `tablesComox` - Table inventory and bills

### Global Collections
- `AdminUser` - Admin and manager accounts
- `menu` (optional) - Menu items

---

## 📈 Data Flow Example

1. **Create Order**
   ```
   POST /orders → ordersComox with status: "incoming"
   ```

2. **Accept Order**
   ```
   PATCH /orders/:id → status: "accepted"
   AND automatically insert into analyticsComox
   ```

3. **Query Accepted Orders**
   ```
   GET /orders?status=accepted&branch=Comox
   ```

4. **View Analytics**
   ```
   GET /analytics?branch=Comox&period=day
   → Aggregates data from analyticsComox
   ```

---

## ⚠️ Error Handling

All error responses follow this format:
```json
{
  "success": false,
  "message": "Error description"
}
```

**Common HTTP Status Codes:**
- `200`: Success
- `400`: Bad request (missing/invalid parameters)
- `401`: Unauthorized (missing/invalid token)
- `403`: Forbidden (insufficient permissions)
- `404`: Not found (resource doesn't exist)
- `500`: Server error

---

## 🧪 Testing with cURL

See [TESTING_AND_IMPLEMENTATION.md](./TESTING_AND_IMPLEMENTATION.md) for full testing guide with examples.
