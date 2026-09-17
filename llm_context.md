# SpiceHut Admin - LLM Context Document

This document provides a complete, high-level overview of the entire SpiceHut Admin codebase. It is designed to instantly onboard any incoming LLM or developer to the project's architecture, technologies, file structure, and core workflows without needing to scan the entire repository.

---

## 1. Project Overview
SpiceHut Admin is a full-stack Point of Sale (POS) and restaurant management application. 
- **Frontend**: Built with Flutter (Dart).
- **Backend**: Built with Node.js (Express), MongoDB (Mongoose), and Socket.IO for real-time capabilities.
- **Goal**: Manage incoming orders, in-house dine-in tables, menu items, users, and print physical slips to LAN-connected receipt printers.

---

## 2. Frontend Architecture (Flutter)
The frontend is primarily housed in the `lib/` directory and follows a feature-first service-oriented architecture.

### Directory Structure & Responsibilities:
- **`lib/main.dart`**: Entry point. Handles initial routing priority: Age Verification -> Privacy Policy -> Permissions -> Sign In.
- **`lib/screens/`**: Contains the UI views.
  - `sign_in_screen.dart`: JWT-based authentication.
  - `dashboard_screen.dart`: Overview and navigation.
  - `incoming_orders_screen.dart`: Real-time queue of new orders.
  - `in_house_orders_screen.dart`: Table and floorplan management for dine-in.
  - `on_call_orders_screen.dart`: Management for call-in orders.
  - `order_history_screen.dart`: Past orders.
  - `menu_management_screen.dart`: CRUD operations for the menu.
  - `user_management_screen.dart`: Admin user management.
  - `analytics_screen.dart`: Sales and performance data.
  - `age_verification_screen.dart` & `privacy_policy_modal.dart` & `permissions_screen.dart`: Compliance and setup screens.
- **`lib/services/`**: Core business logic and integrations.
  - `api_service.dart`: HTTP client wrapping REST calls to the backend.
  - `auth_service.dart`: Handles JWT tokens and user sessions.
  - `order_notification_service.dart`: Manages Socket.IO connections for real-time order updates.
  - `printer_service.dart`: Uses ESC/POS commands to send bytes over raw TCP sockets directly to LAN receipt printers (Kitchen and Bill roles). **Note: Printer fallback logic (routing kitchen slips to the bill printer on failure) is currently NOT implemented.**
  - `analytics_report_service.dart`: Processes and formats analytics data.
  - `logger_service.dart`: Internal logging.
- **`lib/storage/`**: Local storage logic.
  - `printer_storage.dart`: Saves IP addresses of printers per branch locally.
- **`lib/widgets/`**: Reusable components (`printer_status_chip.dart`, `spice_level_picker_dialog.dart`, etc.).
- **`lib/models/`**: Data classes (e.g., `menu_item.dart`).

---

## 3. Backend Architecture (Node.js)
The backend is housed in the `backend/` directory.

### Core Structure:
- **`backend/server.js`**: A massive monolithic file (~148KB) containing the Express setup, MongoDB connection logic, Mongoose schemas, Socket.IO event emitters, and all REST endpoints.
- **Technologies**: Express, Mongoose (MongoDB), Socket.io, JWT (jsonwebtoken), bcryptjs.
- **Seeding Scripts**: Various scripts (`seed-tables.js`, `seed-canmore-order.js`, etc.) exist to populate the database with initial data or mock orders for different branch locations.

### Key API Endpoints (from `server.js`):
*Authentication & Users*
- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET / POST / PUT /api/users` 
- `DELETE /api/admin-users/:userId`

*Orders (Takeout, Delivery, On-Call)*
- `GET / POST /api/orders`
- `PATCH /api/orders/:orderId`
- `GET /api/orders/history`
- `POST /api/orders/refresh-incoming`

*In-House (Dine-in) Orders*
- `GET / POST /api/inhouse-orders`
- `GET /api/inhouse-orders-active`
- `GET /api/inhouse-orders/:orderToken`
- `PATCH /api/inhouse-orders/:orderToken`
- `GET /api/inhouse-orders/:orderToken/bill`
- `POST /api/inhouse-orders/:orderToken/void`
- `GET / PATCH /api/void-codes` (Security feature for voiding items)

*Tables & Floorplan*
- `GET / POST /api/tables`
- `PUT / DELETE /api/tables/:tableId`
- `GET / PATCH /api/tables/floorplan`
- `GET /api/tables/locations`

*Menu Management*
- `GET / POST /api/menu`
- `PUT / DELETE /api/menu/:itemId`

*Dashboard & Analytics*
- `GET /api/dashboard/stats`
- `GET /api/analytics`
- `GET /api/analytics/inhouse`
- `GET /api/analytics/report`

---

## 4. Key Workflows & Data Flows
1. **Real-time Order Syncing**: When a new order is created, the backend emits a Socket.IO event. The frontend (`OrderNotificationService`) listens to these events and dynamically updates `incoming_orders_screen.dart` without requiring a manual refresh.
2. **In-House Flow**: Staff can open a table (`in_house_orders_screen.dart`), add items, set spice levels, fire items to the kitchen, and eventually print the bill. Voiding items requires a specific 4-digit void code configured by admins.
3. **Printing**: The `PrinterService` attempts to connect to local IP addresses on port 9100. It constructs raw ESC/POS byte buffers (via `flutter_esc_pos_utils`) and writes them directly to the socket. It attempts to print to both the Kitchen and the Bill printers concurrently (`printKitchenAndBillInParallel`).
4. **Multi-Branch Support**: Orders and configurations (like Printer IPs) are often scoped to specific branches (e.g., Canmore, Tofino, Port Alberni).

## 5. Known Issues / Missing Features
- **Printer Fallback Missing**: The current `PrinterService` lacks the logic to automatically route a kitchen slip to the front bill printer if the kitchen printer is offline or fails to connect.
- **Monolithic Backend**: `server.js` contains all schemas, routes, and logic, which may make scaling and navigating the backend difficult in the future.
