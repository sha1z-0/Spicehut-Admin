# 📊 Data Structure & Response Examples

## Order Object Structure

### Stored in MongoDB
```json
{
  "_id": "507f1f77bcf86cd799439011",
  "orderId": "ORDER-COMOX-001",
  "customerName": "John Smith",
  "customerEmail": "john@example.com",
  "customerPhone": "250-555-0101",
  "items": [
    {
      "name": "Butter Chicken",
      "quantity": 2,
      "price": 16.99
    },
    {
      "name": "Naan",
      "quantity": 2,
      "price": 3.99
    }
  ],
  "totalAmount": 41.96,
  "status": "pending",
  "branch": "Comox",
  "createdAt": "2026-01-17T12:00:00.000Z",
  "updatedAt": "2026-01-17T12:00:00.000Z"
}
```

### Returned by API
```json
{
  "success": true,
  "data": [
    {
      "_id": "507f1f77bcf86cd799439011",
      "orderId": "ORDER-COMOX-001",
      "customerName": "John Smith",
      "customerEmail": "john@example.com",
      "customerPhone": "250-555-0101",
      "items": [
        {
          "name": "Butter Chicken",
          "quantity": 2,
          "price": 16.99
        },
        {
          "name": "Naan",
          "quantity": 2,
          "price": 3.99
        }
      ],
      "totalAmount": 41.96,
      "status": "pending",
      "branch": "Comox",
      "createdAt": "2026-01-17T12:00:00.000Z"
    }
  ],
  "branch": "Comox",
  "collectionName": "ordersComox"
}
```

---

## Admin User Object Structure

### Stored in MongoDB
```json
{
  "_id": "696b9f586515141ab25ec01b",
  "email": "admin.comox@spicehut.com",
  "password": "$2a$10$ZFUc6AX5utFqTG9D6mWr/OxRPLJmNBNLaH45JaATPjj.CHuAljNGW",
  "name": "Comox Admin",
  "role": "branchAdmin",
  "branch": "Comox",
  "branches": [],
  "isActive": true,
  "lastLogin": "2026-01-17T14:40:24.061Z",
  "createdAt": "2026-01-17T14:40:24.061Z",
  "updatedAt": "2026-01-17T14:40:24.063Z"
}
```

### Returned by Login API
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhZG1pbklkIjoiNjk2YjlmNTg2NTE1MTQxYWIyNWVjMDFiIiwiZW1haWwiOiJhZG1pbi5jb21veEBzcGljZWh1dC5jb20iLCJyb2xlIjoiYnJhbmNoQWRtaW4iLCJicmFuY2giOiJDb21veCIsImJyYW5jaGVzIjpbXSwiaWF0IjoxNzY4NjYxMDQ0LCJleHAiOjE3Njg3NDc0NDR9.cCAIrpIbONOedEAbJ7idU5o5iR-Gh-FSvI9Pc3A-Ii4",
  "admin": {
    "adminId": "696b9f586515141ab25ec01b",
    "email": "admin.comox@spicehut.com",
    "name": "Comox Admin",
    "role": "branchAdmin",
    "branch": "Comox",
    "branches": []
  }
}
```

---

## JWT Token Decoded

### Header
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

### Payload
```json
{
  "adminId": "696b9f586515141ab25ec01b",
  "email": "admin.comox@spicehut.com",
  "role": "branchAdmin",
  "branch": "Comox",
  "branches": [],
  "iat": 1768661044,
  "exp": 1768747444
}
```

### Signature
```
HMAC256(
  base64UrlEncode(header) + "." +
  base64UrlEncode(payload),
  JWT_SECRET
)
```

---

## Response Examples

### 1. Login Request

**Request:**
```bash
POST http://localhost:4000/api/auth/login
Content-Type: application/json

{
  "email": "admin.comox@spicehut.com",
  "password": "ComoxAdmin@123"
}
```

**Response (Success):**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "admin": {
    "adminId": "696b9f586515141ab25ec01b",
    "email": "admin.comox@spicehut.com",
    "name": "Comox Admin",
    "role": "branchAdmin",
    "branch": "Comox",
    "branches": []
  }
}
```

**Response (Invalid Credentials):**
```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

---

### 2. Get Orders Request

**Request:**
```bash
GET http://localhost:4000/api/orders
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (Success - Comox Admin):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "507f1f77bcf86cd799439011",
      "orderId": "ORDER-COMOX-001",
      "customerName": "John Smith",
      "customerEmail": "john@example.com",
      "customerPhone": "250-555-0101",
      "items": [
        {
          "name": "Butter Chicken",
          "quantity": 2,
          "price": 16.99
        },
        {
          "name": "Naan",
          "quantity": 2,
          "price": 3.99
        }
      ],
      "totalAmount": 41.96,
      "status": "pending",
      "branch": "Comox",
      "createdAt": "2026-01-17T12:00:00.000Z"
    },
    {
      "_id": "507f1f77bcf86cd799439012",
      "orderId": "ORDER-COMOX-002",
      "customerName": "Sarah Johnson",
      "customerEmail": "sarah@example.com",
      "customerPhone": "250-555-0102",
      "items": [
        {
          "name": "Tikka Masala",
          "quantity": 1,
          "price": 18.99
        },
        {
          "name": "Basmati Rice",
          "quantity": 1,
          "price": 4.99
        },
        {
          "name": "Raita",
          "quantity": 1,
          "price": 3.99
        }
      ],
      "totalAmount": 27.97,
      "status": "completed",
      "branch": "Comox",
      "createdAt": "2026-01-16T12:00:00.000Z"
    },
    {
      "_id": "507f1f77bcf86cd799439013",
      "orderId": "ORDER-COMOX-003",
      "customerName": "Mike Wilson",
      "customerEmail": "mike@example.com",
      "customerPhone": "250-555-0103",
      "items": [
        {
          "name": "Biryani",
          "quantity": 3,
          "price": 14.99
        }
      ],
      "totalAmount": 44.97,
      "status": "in-progress",
      "branch": "Comox",
      "createdAt": "2026-01-17T09:00:00.000Z"
    }
  ],
  "branch": "Comox",
  "collectionName": "ordersComox"
}
```

**Response (No Token):**
```json
{
  "success": false,
  "message": "No token provided"
}
```

**Response (Invalid Token):**
```json
{
  "success": false,
  "message": "Invalid token"
}
```

---

### 3. Health Check Request

**Request:**
```bash
GET http://localhost:4000/api/health
```

**Response:**
```json
{
  "status": "OK",
  "message": "SpiceHut Admin Backend is running"
}
```

---

## Error Response Format

### Missing Required Fields
```json
{
  "success": false,
  "message": "Email and password required"
}
```

### Server Error
```json
{
  "success": false,
  "message": "Server error"
}
```

### Authentication Error
```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

---

## Flutter Integration Examples

### Storing JWT Token
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('jwt_token', token);
```

### Retrieving JWT Token
```dart
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('jwt_token');
```

### Adding Token to Headers
```dart
Map<String, String> headers = {
  'Content-Type': 'application/json',
};
if (token != null) {
  headers['Authorization'] = 'Bearer $token';
}
```

### Making Request with Token
```dart
final response = await http.get(
  Uri.parse('http://localhost:4000/api/orders'),
  headers: {
    'Authorization': 'Bearer $token'
  },
);
```

### Parsing Order Response
```dart
final response = await ApiService.get('/orders');

// Handle response format
List<dynamic> ordersList = [];
if (response is Map && response.containsKey('data')) {
  ordersList = response['data'];
} else if (response is List) {
  ordersList = response;
}

// Map to Order objects
final orders = ordersList.map((json) {
  return Order(
    id: json['_id'] ?? '',
    orderNumber: json['orderId'] ?? '',
    customerName: json['customerName'] ?? '',
    totalAmount: json['totalAmount'] ?? 0.0,
    status: json['status'] ?? 'pending',
    items: json['items'] ?? [],
    createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
  );
}).toList();
```

---

## Data Types & Fields

### Order Fields
| Field | Type | Required | Example |
|-------|------|----------|---------|
| _id | ObjectId | Yes | "507f1f77bcf86cd799439011" |
| orderId | String | Yes | "ORDER-COMOX-001" |
| customerName | String | Yes | "John Smith" |
| customerEmail | String | Yes | "john@example.com" |
| customerPhone | String | Yes | "250-555-0101" |
| items | Array | Yes | [{ name, quantity, price }] |
| totalAmount | Number | Yes | 41.96 |
| status | String | Yes | "pending", "completed", "in-progress" |
| branch | String | Yes | "Comox" |
| createdAt | Date | Yes | "2026-01-17T12:00:00.000Z" |
| updatedAt | Date | Yes | "2026-01-17T12:00:00.000Z" |

### Admin User Fields
| Field | Type | Required | Example |
|-------|------|----------|---------|
| _id | ObjectId | Yes | "696b9f586515141ab25ec01b" |
| email | String | Yes | "admin.comox@spicehut.com" |
| password | String | Yes | "$2a$10$ZFUc..." (hashed) |
| name | String | Yes | "Comox Admin" |
| role | String | Yes | "superAdmin", "branchAdmin" |
| branch | String | No* | "Comox" (*required for branchAdmin) |
| branches | Array | No | ["Comox", "Port Alberni"] (for superAdmin) |
| isActive | Boolean | Yes | true |
| lastLogin | Date | No | "2026-01-17T14:40:24.061Z" |
| createdAt | Date | Yes | "2026-01-17T14:40:24.061Z" |

### Order Item Fields
| Field | Type | Required | Example |
|-------|------|----------|---------|
| name | String | Yes | "Butter Chicken" |
| quantity | Number | Yes | 2 |
| price | Number | Yes | 16.99 |
| description | String | No | "Tender chicken in creamy sauce" |
| imageUrl | String | No | "https://..." |

---

## Status Values

### Order Status
- `pending` - Order placed, awaiting acceptance
- `in-progress` - Order being prepared
- `completed` - Order ready/delivered
- `cancelled` - Order cancelled

### User Role
- `superAdmin` - Can access all branches
- `branchAdmin` - Can only access assigned branch

---

## Database Schema Summary

### Collections in spicehutDB

1. **adminUsers**
   - Indexes: email (unique)
   - Records: 3 (2 branchAdmin, 1 superAdmin)

2. **ordersComox**
   - Indexes: orderId, status, createdAt
   - Records: 3

3. **ordersPortAlberni**
   - Indexes: orderId, status, createdAt
   - Records: 3

4. **ordersFortSaskatchewan**
   - Indexes: orderId, status, createdAt
   - Records: 3

5. **tablesComox** (placeholder for future)
6. **tablesPortAlberni** (placeholder for future)
7. **tablesFortSaskatchewan** (placeholder for future)

8. **menu** (shared)

---

## Timestamp Formats

All timestamps use ISO 8601 format:
```
2026-01-17T12:00:00.000Z
```

Parsed in Dart:
```dart
final dateTime = DateTime.parse('2026-01-17T12:00:00.000Z');
```

Or with tryParse for safety:
```dart
final dateTime = DateTime.tryParse('2026-01-17T12:00:00.000Z') ?? DateTime.now();
```

---

## Sample Data Summary

### Total Records
- 3 Admin Users
- 9 Orders (3 per branch)
- 3 Branches

### Orders by Status
- 3 Pending
- 3 Completed
- 3 In-Progress

### Total Revenue
```
Comox: $41.96 + $27.97 + $44.97 = $114.90
Port Alberni: $45.96 + $19.92 + $40.96 = $106.84
Fort Saskatchewan: $51.96 + $21.98 + $36.95 = $110.89
TOTAL: $332.63
```

---

## Quick Reference

### Login Any Admin
```json
{
  "email": "admin.comox@spicehut.com",
  "password": "ComoxAdmin@123"
}
```

### Get Orders
```bash
GET /api/orders
Authorization: Bearer <JWT_TOKEN>
```

### Response Has
```json
{
  "success": true,
  "data": [...orders],
  "branch": "Comox",
  "collectionName": "ordersComox"
}
```

### Use This in Flutter
```dart
final response = await ApiService.get('/orders');
final orders = response['data']; // Extract data array
```

