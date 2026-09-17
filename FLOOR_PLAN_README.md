# Restaurant Floor Plan Feature (Combined README)

## Status
- **Production Ready** ✅
- **Completion Date**: January 19, 2026
- **Feature Version**: 2.0

---

## Overview
The In-House Restaurant Floor Plan / Table Mapping feature provides comprehensive floor plan management with table creation, editing, deletion, free-form movement, resizing, and 360-degree rotation. The experience is optimized for high-traffic restaurant environments and supports role-based access control.

---

## Access Control

### Admin & Manager
- ✅ Add new tables
- ✅ Edit existing tables
- ✅ Delete tables (with validation)
- ✅ Full edit mode access

### Waiters & Staff
- 👁️ View-only access
- 👁️ Select tables to take orders
- ❌ Cannot modify floor plan

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    InHouseOrdersScreen                      │
│                   (Main StatefulWidget)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
          ┌─────────▼──────────┐  ┌────▼────────────────┐
          │  AuthService       │  │  APIService        │
          │  - getUserRole()   │  │  - get(/menu)      │
          │  - getUserLocation │  │  - patch(/tables)  │
          └────────────────────┘  └────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
    ┌───▼──────────┐      ┌────▼──────────────┐
    │ TabController│      │ RestaurantFloorPlan
    │ (sections)   │      │ - sections[]
    └──────────────┘      │ - branchId
                          │ - isEditMode
                          └───┬──────────────┘
                              │
                    ┌─────────┴──────────┐
                    │                    │
              ┌─────▼────────┐    ┌──────▼──────────┐
              │ TableSection │    │ TableSection    │
              │ - id         │    │ - id            │
              │ - tables[]   │    │ - tables[]      │
              └──────────────┘    └─────────────────┘
                    │                    │
          ┌─────────▼──────────┐  ┌────▼──────────┐
          │  RestaurantTable   │  │RestaurantTable│
          │  - name            │  │ - name        │
          │  - posX, posY      │  │ - posX, posY  │
          │  - rotation        │  │ - rotation    │
          │  - shape           │  │ - shape       │
          │  - width, height   │  │ - currentOrder
          └────────────────────┘  └───────────────┘
```

---

## State Management Hierarchy

```
_InHouseOrdersScreenState (Root State)
├── RestaurantFloorPlan _floorPlan
│   ├── List<TableSection> sections
│   │   └── List<RestaurantTable> tables
│   │       ├── name: String
│   │       ├── posX, posY: double
│   │       ├── rotation: double (0-360)
│   │       ├── shape: TableShape (enum)
│   │       ├── width, height: double
│   │       └── currentOrder: List<OrderItem>
│   └── isEditMode: bool
├── bool _isLoading
├── bool _isEditMode
├── String? _selectedSectionId
├── List<MenuItem> _menuItems
├── TabController _tabController
└── String? _userBranch, bool _isAdmin

_FloorPlanCanvasState
├── TransformationController _transformationController
├── RestaurantTable? _draggingTable
├── double _rotationStartAngle
└── Offset _rotationStart
```

---

## Data Model

```dart
class RestaurantTable {
  final String id;
  String name;
  int number;
  int capacity;
  TableStatus status;
  double posX;
  double posY;
  double width;
  double height;
  double rotation;      // 0-360 degrees
  TableShape shape;     // circle, square, rectangle
  List<OrderItem> currentOrder;
  String? assignedWaiter;
  double? billTotal;
}

enum TableStatus { available, reserved, occupied }
enum TableShape { circle, square, rectangle }
enum SectionType { main_hall, outdoor, vip_room, private_dining }
```

---

## Feature Summary (At a Glance)

| Feature | View Mode | Edit Mode | Access |
|---------|:---------:|:---------:|--------|
| View Tables | ✅ | ✅ | Everyone |
| Take Orders | ✅ | ✅ | Everyone |
| Create Tables | ❌ | ✅ | Admin/Manager |
| Edit Tables | ❌ | ✅ | Admin/Manager |
| Delete Tables | ❌ | ✅ | Admin/Manager |
| Rotate Tables | ❌ | ✅ | Admin/Manager |
| Resize Tables | ❌ | ✅ | Admin/Manager |
| Move Tables | ❌ | ✅ | Admin/Manager |

---

## Core Workflows

### Create Table
```
1. Click Edit (AppBar)
2. Click + button (bottom-right)
3. Enter: Name, Capacity, Shape
4. Click Create
5. Drag to position, rotate, resize
6. Click Save Layout
```

### Edit Table
```
1. Click Edit (AppBar)
2. Long-press table
3. Modify: Name, Capacity, Shape, Size, Rotation
4. Click Save
5. Click Save Layout
```

### Delete Table
```
1. Click Edit (AppBar)
2. Long-press table
3. Click Delete button
4. Confirm deletion
5. Click Save Layout
```

---

## Validation Rules

### Create Table
- Name required (not empty)
- Capacity: 1–12
- Shape required

### Edit Table
- Width/Height: 30–200px
- Rotation: 0–360°

### Delete Table
- ❌ Cannot delete if table has active orders
- ❌ Cannot delete if occupied

---

## UI/UX Behavior

### View Mode
- Shows table status colors
- Tap table to take orders
- No edit handles visible

### Edit Mode
- Drag handle (table movement)
- Rotation handle (blue circle)
- Resize handle (green circle)
- Rotation angle displayed (e.g., 45°)
- + button for new tables

---

## Rotation & Resize

### Rotation Methods
1. Drag rotation handle (blue circle)
2. Slider in Edit dialog
3. Quick angle buttons (0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°)

### Resize
- Drag green handle (bottom-right)
- Width/Height constrained to 30–200px

---

## Backend Integration

### Endpoints
| Action | Method | Endpoint |
|--------|--------|----------|
| Create | POST | /tables |
| Update | PATCH | /tables/{id} |
| Delete | DELETE | /tables/{id} |
| Save Layout | PATCH | /tables/floorplan |

### Example Payload
```json
{
  "_id": "t_main_hall_1",
  "name": "T1",
  "number": 1,
  "capacity": 4,
  "shape": "circle",
  "posX": 100,
  "posY": 100,
  "width": 80,
  "height": 80,
  "rotation": 0,
  "status": "available"
}
```

---

## Error Handling & Edge Cases
- Cannot delete occupied or active-order tables
- Clear error SnackBars for invalid actions
- Rotation and sizing wrap/constraint enforcement

---

## Performance Notes
- Smooth gesture handling with `Transform.rotate()`
- Handles render only in edit mode
- Optimized for tablets and large screens

---

## Source Code Location
- Main implementation: `lib/screens/in_house_orders_screen.dart`
- Dialogs: `CreateTableDialog`, `EditTableDialog`
- Canvas & table widgets: `FloorPlanCanvas`, `TableWidget`

---

## Quick Troubleshooting
| Issue | Fix |
|------|-----|
| Can't delete table | Clear orders and set status to available |
| Rotation not saving | Click “Save Layout” |
| Layout not reloading | Restart app / check backend connectivity |

---

## Deployment Readiness Checklist
- ✅ No compilation errors
- ✅ Features tested
- ✅ Role-based access verified
- ✅ Backend contracts documented
- ✅ Documentation consolidated

---

## Change Summary
This README consolidates the previous floor plan documentation files into a single reference for product, QA, and development stakeholders.
