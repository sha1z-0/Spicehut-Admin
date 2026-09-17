import express from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import bcryptjs from 'bcryptjs';
import { ObjectId } from 'mongodb';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 4000;
const JWT_SECRET = process.env.JWT_SECRET;

// Validate JWT_SECRET at startup
if (!JWT_SECRET) {
  console.error('❌ FATAL: JWT_SECRET is not set. Set it in .env file');
  process.exit(1);
}
if (JWT_SECRET.length < 32) {
  console.error('❌ FATAL: JWT_SECRET must be at least 32 characters');
  console.error(`   Current length: ${JWT_SECRET.length} characters`);
  process.exit(1);
}
console.log('✅ JWT_SECRET validated');

// Middleware
app.use(express.json());
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.options('*', cors());

// MongoDB Connection State Tracker (for Vercel cold starts)
let mongoConnectionState = 'connecting';

// MongoDB Connection with production options + proper event handling
mongoose.connect(process.env.MONGO_URI, {
  maxPoolSize: 10,
  minPoolSize: 5,
  socketTimeoutMS: 45000,
  serverSelectionTimeoutMS: 5000,
  family: 4,
  retryWrites: true,
  w: 'majority'
})
  .then(() => {
    mongoConnectionState = 'connected';
    console.log('✅ MongoDB Connected');
    console.log(`📊 Database: ${process.env.MONGO_URI?.split('@')[1]?.split('/')[0] || 'Connected'}`);
  })
  .catch(err => {
    mongoConnectionState = 'error';
    console.error('❌ MongoDB Connection Error:', err.message);
    console.error('💡 Check your MONGO_URI environment variable');
    process.exit(1); // Exit if DB connection fails
  });

// Connection Event Handlers (handle Vercel cold starts)
mongoose.connection.on('connected', () => {
  mongoConnectionState = 'connected';
  console.log('✅ Mongoose connected to MongoDB');
});

mongoose.connection.on('disconnected', () => {
  mongoConnectionState = 'disconnected';
  console.warn('⚠️  Mongoose disconnected from MongoDB');
});

mongoose.connection.on('error', (err) => {
  mongoConnectionState = 'error';
  console.error('❌ Mongoose connection error:', err.message);
});

mongoose.connection.on('reconnected', () => {
  mongoConnectionState = 'connected';
  console.log('✅ Mongoose reconnected to MongoDB');
});

// Function to verify actual MongoDB connectivity (not just state)
async function verifyMongoDBConnection() {
  try {
    // Perform a simple ping to verify actual connectivity
    const admin = mongoose.connection.getClient().db('admin');
    await admin.command({ ping: 1 });
    mongoConnectionState = 'connected';
    return true;
  } catch (error) {
    mongoConnectionState = 'disconnected';
    console.warn('⚠️  MongoDB ping failed:', error.message);
    
    // Attempt to reconnect on Vercel cold start
    try {
      await mongoose.connect(process.env.MONGO_URI, {
        maxPoolSize: 10,
        minPoolSize: 5,
        socketTimeoutMS: 45000,
        serverSelectionTimeoutMS: 5000,
        family: 4,
        retryWrites: true,
        w: 'majority'
      });
      mongoConnectionState = 'connected';
      console.log('✅ Reconnected after cold start');
      return true;
    } catch (reconnectError) {
      mongoConnectionState = 'error';
      console.error('❌ Failed to reconnect:', reconnectError.message);
      return false;
    }
  }
}

// Define Admin User Schema (adminusers collection)
const AdminUserSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  password: { type: String, required: true },
  name: { type: String, required: true },
  role: {
    type: String,
    enum: ['admin', 'manager', 'staff', 'superAdmin', 'branchAdmin'],
    default: 'manager'
  },
  staffRole: { type: String }, // 'waiter', 'cashier', 'kitchen', 'delivery'
  branch: { type: String }, // single branch for manager/staff
  branches: { type: [String], default: [] }, // admin or selected branch
  isActive: { type: Boolean, default: true },
  lastLogin: Date,
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

const AdminUser = mongoose.model('AdminUser', AdminUserSchema);

const ROLE_MAP = {
  superAdmin: 'admin',
  branchAdmin: 'manager',
  admin: 'admin',
  manager: 'manager',
  staff: 'staff'
};

const normalizeRole = (role) => ROLE_MAP[role] || role;

const normalizeRoleForUser = (user) => {
  const normalized = normalizeRole(user?.role);
  const hasSingleBranch = !!user?.branch && (!Array.isArray(user?.branches) || user.branches.length === 0);
  if (normalized === 'admin' && hasSingleBranch) {
    return 'manager';
  }
  return normalized;
};

const normalizeBranchName = (branch) => {
  if (!branch || typeof branch !== 'string') return branch;
  const trimmed = branch.trim();
  if (trimmed.toLowerCase() === 'nanaimo') return 'Fort Saskatchewan';
  return trimmed;
};

const ORDER_LOCATION_INPUTS = [
  'Canmore',
  'Comox',
  'Cranbrook',
  'Fort Saskatchewan',
  'Invermere',
  'Ladysmith',
  'Lloydminster',
  'PortAlberni',
  'Tofino',
  'CampbellRiver'
];

const normalizeLocationForCollection = (location) => {
  if (!location || typeof location !== 'string') return location;
  const trimmed = location.trim();
  if (!trimmed) return trimmed;
  const noSpaces = trimmed.replace(/\s+/g, '');
  
  // Map to exact collection name format to match database
  const locationMap = {
    'portalberni': 'PortAlberni',
    'fortsaskatchewan': 'Nanaimo', // Fort Saskatchewan uses ordersNanaimo collection
    'campbellriver': 'CampbellRiver',
    'canmore': 'Canmore',
    'comox': 'Comox',
    'cranbrook': 'Cranbrook',
    'invermere': 'Invermere',
    'ladysmith': 'Ladysmith',
    'lloydminster': 'Lloydminster',
    'tofino': 'Tofino'
  };
  
  const lower = noSpaces.toLowerCase();
  return locationMap[lower] || (lower.charAt(0).toUpperCase() + lower.slice(1));
};

const ORDER_LOCATION_KEYS = new Set(
  ORDER_LOCATION_INPUTS.map(normalizeLocationForCollection)
);

const resolveOrdersCollectionName = (location) => {
  const normalized = normalizeLocationForCollection(location);
  if (!normalized || !ORDER_LOCATION_KEYS.has(normalized)) {
    throw new Error('Invalid location');
  }
  return `orders${normalized}`;
};

const resolveOrdersCollectionNameReport = (location) => {
  const normalized = normalizeLocationForCollection(location);
  if (!normalized || !ORDER_LOCATION_KEYS.has(normalized)) {
    throw new Error('Invalid location');
  }
  return `Orders${normalized}`;
};

const getOrderRoomName = (location) => {
  const normalized = normalizeLocationForCollection(location);
  return normalized ? `orders:${normalized}` : 'orders:unknown';
};

const getUserBranch = (user) => {
  if (user?.branch) return normalizeBranchName(user.branch);
  if (Array.isArray(user?.branches) && user.branches.length > 0) {
    return normalizeBranchName(user.branches[0]);
  }
  return null;
};

const httpServer = http.createServer(app);

// ============================================
// SOCKET.IO CONFIGURATION FOR VERCEL SERVERLESS
// ============================================
// Vercel serverless DOES NOT support persistent WebSocket connections
// Force polling-only to ensure reliability - WebSocket will cause 400 errors
const io = new SocketIOServer(httpServer, {
  // CRITICAL: Only polling works on Vercel serverless
  transports: ['polling'],
  
  // Disable WebSocket upgrade attempts (causes 400 errors on Vercel)
  upgrade: false,
  
  // Polling configuration for Vercel
  pollInterval: 10000,     // Poll every 10 seconds
  pollIntervalMax: 20000,  // Max 20 seconds
  
  // Connection handling
  pingInterval: 25000, // Ping every 25 seconds
  pingTimeout: 60000, // Wait 60 seconds for pong before disconnect
  
  // Buffer and message size
  maxHttpBufferSize: 1e6,  // 1MB max message size
  
  // Path configuration
  path: '/socket.io',
  serveClient: false, // Don't serve Socket.io client library
  
  // CORS - Allow all origins for maximum compatibility
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'OPTIONS'],
    credentials: false,
    allowedHeaders: ['Content-Type', 'Authorization']
  },
  
  // Per-message deflate compression (lighter payloads for polling)
  perMessageDeflate: {
    threshold: 1024 // Only compress messages larger than 1KB
  }
});

// Socket.io connection event handlers
io.on('connection', (socket) => {
  console.log('🔌 Socket.io client connected:', socket.id);
  console.log('   Transport: polling (forced for Vercel compatibility)');
  console.log('   Remote IP:', socket.handshake.address);
  
  // Handle client disconnect
  socket.on('disconnect', (reason) => {
    console.log(`🔌 Socket ${socket.id} disconnected: ${reason}`);
  });
  
  // Handle connection errors
  socket.on('error', (error) => {
    console.error(`🚨 Socket ${socket.id} error:`, error);
  });
  
  // Handle join-branch event (subscribe to location-specific room)
  socket.on('join-branch', ({ location }) => {
    try {
      const roomName = getOrderRoomName(location);
      socket.join(roomName);
      console.log(`📍 Socket ${socket.id} joined room "${roomName}" (location: "${location}")`);
      
      // Acknowledge successful join
      socket.emit('joined-branch', { location, success: true });
    } catch (error) {
      console.warn(`⚠️  Socket join error for ${location}:`, error.message);
      socket.emit('joined-branch', { location, success: false, error: error.message });
    }
  });
  
  // Handle test event (for debugging)
  socket.on('test-event', (data) => {
    console.log('📡 Test event received:', data);
    socket.emit('test-response', { received: true, timestamp: new Date() });
  });
});

// Socket.io server error handler
io.on('error', (error) => {
  console.error('🚨 Socket.io server error:', error);
});

// Log Socket.io startup configuration
console.log('\n⚙️  Socket.io Configuration for Vercel Serverless:');
console.log('   Transport: polling (WebSocket disabled)');
console.log('   Poll Interval: 10s');
console.log('   Max Connections: unlimited');
console.log('   CORS: restricted to known origins');
console.log('   Reliability: HIGH (polling on Vercel is fully supported)\n');

// ============================================
// AUTH ENDPOINTS
// ============================================

// LOGIN
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    console.log('🔐 Login attempt:', { email });

    if (!email || !password) {
      console.log('❌ Missing credentials');
      return res.status(400).json({ success: false, message: 'Email and password required' });
    }

    // Find admin user
    const admin = await AdminUser.findOne({ email: email.toLowerCase() });
    console.log('🔍 Admin found:', admin ? admin.email : 'NOT FOUND');

    if (!admin || !admin.isActive) {
      console.log('❌ Admin not found or inactive');
      return res.status(401).json({ success: false, message: 'Wrong email or password' });
    }

    // Compare password
    console.log('🔑 Comparing passwords...');
    const isPasswordValid = await bcryptjs.compare(password, admin.password);
    console.log('✓ Password valid:', isPasswordValid);

    if (!isPasswordValid) {
      console.log('❌ Password mismatch');
      return res.status(401).json({ success: false, message: 'Wrong email or password' });
    }

    // Update last login
    admin.lastLogin = new Date();
    await admin.save();
    console.log('✅ Login successful for:', admin.email);

    const normalizedRole = normalizeRoleForUser(admin);
    const normalizedBranch = normalizedRole === 'admin' ? null : getUserBranch(admin);

    // Generate JWT token
    const token = jwt.sign(
      {
        adminId: admin._id.toString(),
        email: admin.email,
        role: normalizedRole,
        branch: normalizedBranch,
        branches: admin.branches || []
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      success: true,
      token,
      admin: {
        adminId: admin._id.toString(),
        email: admin.email,
        name: admin.name,
        role: normalizedRole,
        branch: normalizedBranch,
        branches: admin.branches || []
      }
    });

  } catch (error) {
    console.error('❌ Login error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Middleware to verify JWT
const verifyToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.admin = decoded;
    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Invalid token' });
  }
};

// GET CURRENT ADMIN PROFILE
app.get('/api/auth/me', verifyToken, async (req, res) => {
  try {
    const admin = await AdminUser.findById(req.admin.adminId);
    if (!admin || !admin.isActive) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const normalizedRole = normalizeRoleForUser(admin);
    res.json({
      success: true,
      admin: {
        adminId: admin._id.toString(),
        email: admin.email,
        name: admin.name,
        role: normalizedRole,
        branch: getUserBranch(admin),
        branches: admin.branches || []
      }
    });
  } catch (error) {
    console.error('Auth me error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

const requireAuth = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await AdminUser.findById(decoded.adminId);

    if (!user || !user.isActive) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const normalizedRole = normalizeRole(user.role);
    req.currentUser = {
      ...user.toObject(),
      role: normalizedRole,
      branch: getUserBranch(user),
    };
    req.admin = { ...decoded, role: normalizedRole, branch: getUserBranch(user) };
    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Invalid token' });
  }
};

const requireRole = (allowedRoles) => (req, res, next) => {
  const role = req.currentUser?.role;
  if (!role || !allowedRoles.includes(role)) {
    return res.status(403).json({ success: false, message: 'Forbidden' });
  }
  next();
};

// ============================================
// USER MANAGEMENT (adminusers collection)
// ============================================

// Create User (Super Admin only)
app.post('/api/users', requireAuth, requireRole(['admin']), async (req, res) => {
  try {
    const { name, email, password, role, staffRole, branch, branches, isActive } = req.body;

    if (!name || !email || !password || !role) {
      return res.status(400).json({ success: false, message: 'Name, email, password, and role are required' });
    }

    const normalizedRole = normalizeRole(role);
    if (!['manager', 'staff'].includes(normalizedRole)) {
      return res.status(400).json({ success: false, message: 'Only manager or staff can be created' });
    }

    if (!branch || typeof branch !== 'string' || branch.trim() === '') {
      return res.status(400).json({ success: false, message: 'Branch is required' });
    }

    if (!Array.isArray(branches) || branches.length !== 1 || branches[0] !== branch) {
      return res.status(400).json({ success: false, message: 'Branches must contain the selected branch only' });
    }

    if (normalizedRole === 'staff') {
      const allowedStaffRoles = ['waiter', 'cashier', 'kitchen', 'delivery'];
      if (!staffRole || !allowedStaffRoles.includes(staffRole)) {
        return res.status(400).json({ success: false, message: 'Invalid staffRole' });
      }
    }

    const emailLower = email.toLowerCase().trim();
    const existing = await AdminUser.findOne({ email: emailLower });
    if (existing) {
      return res.status(409).json({ success: false, message: 'Email already exists' });
    }

    const hashedPassword = await bcryptjs.hash(password, 10);

    const created = await AdminUser.create({
      name: name.trim(),
      email: emailLower,
      password: hashedPassword,
      role: normalizedRole,
      staffRole: normalizedRole === 'staff' ? staffRole : undefined,
      branch: branch,
      branches: branches,
      isActive: typeof isActive === 'boolean' ? isActive : true,
      createdAt: new Date(),
      updatedAt: new Date()
    });

    const safeUser = created.toObject();
    delete safeUser.password;

    res.status(201).json({ success: true, data: safeUser });
  } catch (error) {
    console.error('Create user error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Fetch Users
app.get('/api/users', requireAuth, async (req, res) => {
  try {
    const role = req.currentUser.role;

    if (role === 'staff') {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    let branchFilter = null;
    if (role === 'admin') {
      if (req.query.branch) {
        branchFilter = normalizeBranchName(req.query.branch);
      }
    } else {
      const userBranch = req.currentUser.branch;
      if (!userBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }
      branchFilter = normalizeBranchName(userBranch);
    }

    const legacyBranch = branchFilter === 'Fort Saskatchewan' ? 'Nanaimo' : null;
    const branchMatch = legacyBranch ? [branchFilter, legacyBranch] : [branchFilter];
    const query = branchFilter
      ? { $or: [{ branch: { $in: branchMatch } }, { branches: { $in: branchMatch } }] }
      : {};

    const users = await AdminUser.find(query).select('-password').sort({ createdAt: -1 });
    const normalizedUsers = users.map((u) => {
      const obj = u.toObject();
      if (obj.branch) obj.branch = normalizeBranchName(obj.branch);
      if (Array.isArray(obj.branches)) {
        obj.branches = obj.branches.map(normalizeBranchName);
      }
      return obj;
    });
    res.json({ success: true, data: normalizedUsers });
  } catch (error) {
    console.error('Fetch users error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Update User (Super Admin only)
app.put('/api/users/:id', requireAuth, requireRole(['admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const { name, isActive, staffRole } = req.body;

    const user = await AdminUser.findById(id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    if (name !== undefined) {
      if (typeof name !== 'string' || name.trim() === '') {
        return res.status(400).json({ success: false, message: 'Name is required' });
      }
      user.name = name.trim();
    }

    if (isActive !== undefined) {
      return res.status(400).json({ success: false, message: 'User activation changes are deprecated' });
    }

    if (staffRole !== undefined) {
      const normalizedRole = normalizeRole(user.role);
      if (normalizedRole !== 'staff') {
        return res.status(400).json({ success: false, message: 'staffRole is only valid for staff users' });
      }
      const allowedStaffRoles = ['waiter', 'cashier', 'kitchen', 'delivery'];
      if (!allowedStaffRoles.includes(staffRole)) {
        return res.status(400).json({ success: false, message: 'Invalid staffRole' });
      }
      user.staffRole = staffRole;
    }

    user.updatedAt = new Date();
    await user.save();

    const safeUser = user.toObject();
    delete safeUser.password;
    res.json({ success: true, data: safeUser });
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Delete User (Super Admin only)
app.delete('/api/admin-users/:userId', requireAuth, requireRole(['admin']), async (req, res) => {
  try {
    const { userId } = req.params;

    if (req.currentUser?._id?.toString() === userId) {
      return res.status(403).json({ success: false, message: 'Cannot delete your own account' });
    }

    const user = await AdminUser.findById(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    await AdminUser.deleteOne({ _id: userId });
    res.json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ============================================
// BRANCH-SPECIFIC DATA ROUTES
// ============================================

// Get Dashboard Stats for Branch (server-side calculation using createdAt)
app.get('/api/dashboard/stats', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const normalizedRole = normalizeRole(role);
    const requestedBranch = req.query.branch;

    let branch;
    if (normalizedRole === 'admin') {
      if (!requestedBranch) {
        return res.status(400).json({ success: false, message: 'Branch parameter required for admin' });
      }
      branch = requestedBranch;
    } else {
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }
      branch = adminBranch;
    }

    const normalizedBranch = normalizeBranchName(branch);
    let ordersCollectionName;
    try {
      ordersCollectionName = resolveOrdersCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(ordersCollectionName);

    // Use server time for today's date range
    const now = new Date();
    const startToday = new Date(now);
    startToday.setHours(0, 0, 0, 0);
    const endToday = new Date(now);
    endToday.setHours(23, 59, 59, 999);

    const [result] = await collection.aggregate([
      {
        $facet: {
          todayTotal: [
            { $match: { createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          todayPending: [
            { $match: { status: 'incoming', createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          todayAccepted: [
            { $match: { status: 'accepted', createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          todayCompleted: [
            { $match: { status: 'completed', createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          todayFailed: [
            { $match: { status: 'failed', createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          todayRevenue: [
            { $match: { status: 'completed', createdAt: { $gte: startToday, $lte: endToday } } },
            { 
              $group: { 
                _id: null, 
                total: { $sum: { $ifNull: ['$orderTotal', '$totalAmount', 0] } } 
              } 
            }
          ]
        }
      }
    ]).toArray();

    const getCount = (arr) => (arr?.[0]?.count ?? 0);
    const getTotal = (arr) => (arr?.[0]?.total ?? 0);

    res.json({
      success: true,
      data: {
        todayOrders: getCount(result?.todayTotal),
        pendingOrders: getCount(result?.todayPending),
        acceptedOrders: getCount(result?.todayAccepted),
        completedOrders: getCount(result?.todayCompleted),
        failedOrders: getCount(result?.todayFailed),
        todayRevenue: getTotal(result?.todayRevenue)
      }
    });
  } catch (error) {
    console.error('Get dashboard stats error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Get Orders for Branch
app.get('/api/orders', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const requestedBranch = req.query.branch; // Admin can request any branch
    const statusFilter = req.query.status; // Filter by status

    let branch;
    if (role === 'admin') {
      // Admin can query any branch via query parameter
      if (!requestedBranch) {
        return res.status(400).json({ success: false, message: 'Branch parameter required for admin' });
      }
      branch = requestedBranch;
    } else {
      // Branch managers use their assigned branch
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }
      branch = adminBranch;
    }

    const normalizedBranch = normalizeBranchName(branch);
    let collectionName;
    try {
      collectionName = resolveOrdersCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }
    
    console.log(`📦 Fetching orders for: incoming request with branch="${branch}" -> normalized="${normalizedBranch}" -> collection="${collectionName}"`);
    
    const collection = mongoose.connection.db.collection(collectionName);
    
    // Build filter
    let filter = {};
    if (statusFilter) {
      filter.status = statusFilter;
    }
    
    const orders = await collection.find(filter).sort({ createdAt: -1 }).toArray();
    
    console.log(`   ✓ Found ${orders.length} orders in ${collectionName}`);

    res.json({ success: true, data: orders, branch: normalizedBranch, collectionName });

  } catch (error) {
    console.error('Get orders error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Get Order History for Branch
app.get('/api/orders/history', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const requestedBranch = req.query.branch;

    let branch;
    if (role === 'admin') {
      if (!requestedBranch) {
        return res.status(400).json({ success: false, message: 'Branch parameter required for admin' });
      }
      branch = requestedBranch;
    } else {
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }
      branch = adminBranch;
    }

    const normalizedBranch = normalizeBranchName(branch);
    let collectionName;
    try {
      collectionName = resolveOrdersCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(collectionName);
    const orders = await collection.find({
      status: { $in: ['accepted', 'rejected', 'completed', 'failed'] }
    }).sort({ createdAt: -1 }).toArray();

    res.json({ success: true, data: orders, branch: normalizedBranch, collectionName });
  } catch (error) {
    console.error('Get order history error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Create Order for Branch
app.post('/api/orders', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const requestedBranch = req.body.branch || req.query.branch;

    let branch;
    if (role === 'admin') {
      if (!requestedBranch) {
        return res.status(400).json({ success: false, message: 'Branch required for admin' });
      }
      branch = requestedBranch;
    } else {
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }
      branch = adminBranch;
    }

    const normalizedBranch = normalizeBranchName(branch);
    let collectionName;
    try {
      collectionName = resolveOrdersCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const { items, totalAmount } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'Items are required' });
    }
    if (typeof totalAmount !== 'number') {
      return res.status(400).json({ success: false, message: 'totalAmount must be a number' });
    }

    const now = new Date();
    const autoRejectAt = new Date(now.getTime() + 15 * 60 * 1000);

    const collection = mongoose.connection.db.collection(collectionName);
    const orderDoc = {
      ...req.body,
      location: normalizedBranch,
      status: 'incoming',
      createdAt: now,
      updatedAt: now,
      autoRejectAt,
      branch: normalizedBranch
    };

    const result = await collection.insertOne(orderDoc);
    const insertedOrder = { _id: result.insertedId, ...orderDoc };

    io.to(getOrderRoomName(normalizedBranch)).emit('order:new', insertedOrder);

    res.json({ success: true, data: insertedOrder });

  } catch (error) {
    console.error('Create order error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Update Order Status (Accept/Reject)
app.patch('/api/orders/:orderId', verifyToken, async (req, res) => {
  try {
    const { orderId } = req.params;
    const { status, branch } = req.body;
    const { role, branch: adminBranch } = req.admin;

    if (!['accepted', 'rejected', 'completed', 'failed'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    let targetBranch = branch;
    if (!targetBranch) {
      if (role === 'admin') {
        return res.status(400).json({ success: false, message: 'Branch required for admin' });
      }
      targetBranch = adminBranch;
    }

    const normalizedBranch = normalizeBranchName(targetBranch);
    let collectionName;
    try {
      collectionName = resolveOrdersCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(collectionName);
    const existingOrder = await collection.findOne({ _id: new ObjectId(orderId) });

    if (!existingOrder) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const currentStatus = existingOrder.status || 'incoming';
    if (currentStatus === status) {
      return res.json({ success: true, data: existingOrder });
    }

    const isValidTransition =
      (currentStatus === 'incoming' && ['accepted', 'rejected'].includes(status)) ||
      (currentStatus === 'accepted' && ['completed', 'failed'].includes(status));

    if (!isValidTransition) {
      return res.status(409).json({
        success: false,
        message: `Invalid status transition from ${currentStatus} to ${status}`
      });
    }

    const now = new Date();
    const updateFields = {
      status,
      updatedAt: now,
      ...(status === 'accepted' && { acceptedAt: now }),
      ...(status === 'rejected' && { rejectedAt: now }),
      ...(status === 'completed' && { completedAt: now }),
      ...(status === 'failed' && { failedAt: now })
    };

    const result = await collection.findOneAndUpdate(
      { _id: new ObjectId(orderId), status: currentStatus },
      { $set: updateFields },
      { returnDocument: 'after' }
    );

    if (!result.value) {
      return res.status(409).json({ success: false, message: 'Order status updated by another user' });
    }

    // If accepted, save to analytics collection
    if (status === 'accepted') {
      try {
        const analyticsCollectionName = `analytics${normalizeLocationForCollection(normalizedBranch)}`;
        const analyticsCollection = mongoose.connection.db.collection(analyticsCollectionName);
        
        await analyticsCollection.insertOne({
          orderId: orderId,
          amount: result.value.totalAmount || 0,
          date: result.value.acceptedAt || new Date(),
          branchName: normalizedBranch,
          itemCount: result.value.items?.length || 0,
          createdAt: new Date()
        });
        console.log(`✅ Analytics record created for order ${orderId}`);
      } catch (analyticsError) {
        console.warn('⚠️ Failed to save analytics:', analyticsError.message);
        // Don't fail the main request if analytics fails
      }
    }

    io.to(getOrderRoomName(normalizedBranch)).emit('order:updated', result.value);

    res.json({ success: true, data: result.value });

  } catch (error) {
    console.error('Update order error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});


// ============================================================================
// FLOOR PLAN ROUTES (must be before parameterized routes)
// ============================================================================

// GET: Fetch floor plan for a specific location
app.get('/api/tables/floorplan', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const requestedBranch = req.query.branch || req.query.location;

    // Determine which branch/location to query
    let location;
    if (role === 'admin') {
      location = requestedBranch || adminBranch;
      if (!location) {
        return res.status(400).json({ 
          success: false, 
          message: 'Location parameter required' 
        });
      }
    } else {
      // Branch admin can only access their own branch
      location = adminBranch;
      if (!location) {
        return res.status(403).json({ 
          success: false, 
          message: 'No branch assigned to your account' 
        });
      }
    }

    // Get location-specific collection
    const collectionName = getTableCollectionName(location);
    const collection = mongoose.connection.db.collection(collectionName);

    // Fetch floor plan document
    const floorPlan = await collection.findOne({ type: 'floorplan' });

    if (!floorPlan) {
      // Return empty floor plan structure if none exists
      return res.json({
        success: true,
        data: {
          branchId: location,
          branchName: location,
          sections: [],
          lastSynced: new Date()
        },
        location
      });
    }

    if (floorPlan.sections) {
      floorPlan.sections.forEach((section) => {
        if (section.tables) {
          section.tables.forEach((table) => {
            table.status = normalizeTableStatus(table.status);
          });
        }
      });
    }

    res.json({
      success: true,
      data: floorPlan,
      location
    });

  } catch (error) {
    console.error('Get floor plan error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message || 'Server error' 
    });
  }
});

// PATCH: Save/Update floor plan for a specific location
app.patch('/api/tables/floorplan', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const { branchId, sections } = req.body;

    console.log('📝 Save floor plan request:', { 
      branchId, 
      sectionsCount: sections?.length, 
      adminRole: role, 
      adminBranch,
      requestBody: JSON.stringify(req.body).substring(0, 200)
    });

    if (!branchId) {
      return res.status(400).json({ 
        success: false, 
        message: 'branchId is required' 
      });
    }

    // Validate permissions
    if (role !== 'admin' && adminBranch !== branchId) {
      console.error('❌ Permission denied:', { 
        adminRole: role, 
        adminBranch, 
        requestedBranchId: branchId,
        match: adminBranch === branchId 
      });
      return res.status(403).json({ 
        success: false, 
        message: `You can only modify your assigned branch. Your branch: "${adminBranch}", Requested: "${branchId}"` 
      });
    }

    // Get location-specific collection
    let collectionName;
    try {
      collectionName = getTableCollectionName(branchId);
      console.log(`✓ Collection name resolved: ${collectionName}`);
    } catch (e) {
      console.error('❌ Collection name error:', e.message);
      return res.status(400).json({ 
        success: false, 
        message: e.message 
      });
    }

    const collection = mongoose.connection.db.collection(collectionName);

    const sanitizedSections = Array.isArray(sections)
      ? sections.map((section) => ({
          ...section,
          tables: Array.isArray(section.tables)
            ? section.tables.map((table) => ({
                ...table,
                status: normalizeTableStatus(table.status)
              }))
            : []
        }))
      : [];

    const floorPlanDoc = {
      type: 'floorplan',
      branchId,
      branchName: branchId,
      sections: sanitizedSections,
      lastSynced: new Date(),
      updatedBy: req.admin.email,
      updatedAt: new Date()
    };

    console.log('💾 Saving floor plan doc:', { branchId, collectionName: collectionName, sectionsCount: sections?.length });

    // Upsert the floor plan document
    const result = await collection.findOneAndUpdate(
      { type: 'floorplan' },
      { $set: floorPlanDoc },
      { upsert: true, returnDocument: 'after' }
    );

    console.log(`✅ Floor plan saved for location: ${branchId} (collection: ${collectionName})`);

    res.json({
      success: true,
      message: 'Floor plan saved successfully',
      data: result.value || floorPlanDoc
    });

  } catch (error) {
    console.error('❌ Save floor plan error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message || 'Server error',
      error: error.toString()
    });
  }
});

// ============================================================================
// TABLE ROUTES (parameterized - must be after specific routes)
// ============================================================================

// Get Available Branches
app.get('/api/branches', verifyToken, async (req, res) => {
  try {
    const { role, branches: adminBranches, branch: adminBranch } = req.admin;
    const normalizedRole = normalizeRole(role);

    let branches = [];
    if (normalizedRole === 'admin') {
      // Admin can see all branches
      branches = adminBranches || ['Comox', 'PortAlberni', 'Ladysmith', 'Tofino', 'CampbellRiver', 'Cranbrook', 'Invermere', 'Canmore', 'Lloydminster', 'Fort Saskatchewan'];
    } else {
      // Branch managers only see their own branch
      if (adminBranch) {
        branches = [adminBranch];
      }
    }

    const normalizedBranches = branches.map(normalizeBranchName);
    res.json({ success: true, data: normalizedBranches });

  } catch (error) {
    console.error('Get branches error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Menu Endpoints (use menuitems collection)
app.get('/api/menu', verifyToken, async (req, res) => {
  try {
    const collection = mongoose.connection.db.collection('appmenuitems');
    const menu = await collection.find({}).toArray();

    res.json({ success: true, data: menu });

  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

app.post('/api/menu', verifyToken, async (req, res) => {
  try {
    const { role } = req.admin;
    if (role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }

    const collection = mongoose.connection.db.collection('appmenuitems');
    const doc = {
      name: req.body.name,
      description: req.body.description || '',
      price: Number(req.body.price) || 0,
      category: req.body.category || 'Main',
      imageUrl: req.body.imageUrl || '',
      isAlcohol: !!req.body.isAlcohol,
      available: req.body.available !== undefined ? !!req.body.available : true,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const result = await collection.insertOne(doc);
    res.json({ success: true, data: { _id: result.insertedId, ...doc } });

  } catch (error) {
    console.error('Create menu item error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

app.put('/api/menu/:itemId', verifyToken, async (req, res) => {
  try {
    const { role } = req.admin;
    if (role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }

    const { itemId } = req.params;
    const { ObjectId } = require('mongodb');
    const collection = mongoose.connection.db.collection('appmenuitems');

    const update = {
      name: req.body.name,
      description: req.body.description || '',
      price: Number(req.body.price) || 0,
      category: req.body.category || 'Main',
      imageUrl: req.body.imageUrl || '',
      isAlcohol: !!req.body.isAlcohol,
      available: req.body.available !== undefined ? !!req.body.available : true,
      updatedAt: new Date()
    };

    const result = await collection.findOneAndUpdate(
      { _id: new ObjectId(itemId) },
      { $set: update },
      { returnDocument: 'after' }
    );

    if (!result.value) {
      return res.status(404).json({ success: false, message: 'Menu item not found' });
    }

    res.json({ success: true, data: result.value });

  } catch (error) {
    console.error('Update menu item error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

app.delete('/api/menu/:itemId', verifyToken, async (req, res) => {
  try {
    const { role } = req.admin;
    if (role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }

    const { itemId } = req.params;
    const collection = mongoose.connection.db.collection('appmenuitems');

    const result = await collection.deleteOne({ _id: new ObjectId(itemId) });
    if (result.deletedCount === 0) {
      return res.status(404).json({ success: false, message: 'Menu item not found' });
    }

    res.json({ success: true, message: 'Menu item deleted' });

  } catch (error) {
    console.error('Delete menu item error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// One-time migration: copy menuitems → appmenuitems
app.post('/api/menu/migrate', verifyToken, async (req, res) => {
  try {
    const { role } = req.admin;
    if (role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin only' });
    }

    const sourceCollection = mongoose.connection.db.collection('menuitems');
    const targetCollection = mongoose.connection.db.collection('appmenuitems');

    const sourceItems = await sourceCollection.find({}).toArray();
    const existingNames = new Set(
      (await targetCollection.find({}, { projection: { name: 1 } }).toArray())
        .map(item => item.name?.toLowerCase())
    );

    let copied = 0;
    for (const item of sourceItems) {
      if (!existingNames.has(item.name?.toLowerCase())) {
        const { _id, ...rest } = item;
        await targetCollection.insertOne({
          ...rest,
          isAlcohol: false, // Default for migrated items
          migratedFrom: 'menuitems',
          migratedAt: new Date()
        });
        copied++;
      }
    }

    // Delete items from appmenuitems that don't exist in menuitems, EXCEPT those not migrated from menuitems
    const sourceNames = new Set(sourceItems.map(i => i.name?.toLowerCase()));
    const appItems = await targetCollection.find({}).toArray();
    let deleted = 0;
    for (const item of appItems) {
      if (item.migratedFrom === 'menuitems' && !sourceNames.has(item.name?.toLowerCase())) {
         await targetCollection.deleteOne({ _id: item._id });
         deleted++;
      }
    }

    res.json({
      success: true,
      message: `Migrated ${copied} items from menuitems to appmenuitems`,
      copied,
      deleted,
      total: sourceItems.length
    });
  } catch (error) {
    console.error('Menu migration error:', error);
    res.status(500).json({ success: false, message: 'Migration failed' });
  }
});

// ============================================
// IN-HOUSE TABLE MANAGEMENT ENDPOINTS
// ============================================

// VALID LOCATIONS - Add more as needed
const VALID_LOCATIONS = [
  'Canmore',
  'Comox',
  'Cranbrook',
  'Fort Saskatchewan',
  'Invermere',
  'Ladysmith',
  'Lloydminster',
  'PortAlberni',
  'Tofino',
  'CampbellRiver'
];

const ALLOWED_TABLE_STATUSES = ['available', 'reserved', 'occupied'];

function normalizeTableStatus(status) {
  if (!status) return 'available';
  if (status === 'awaiting_bill') return 'occupied';
  if (!ALLOWED_TABLE_STATUSES.includes(status)) return 'available';
  return status;
}

// Helper: Get location-specific table collection name
function getTableCollectionName(location) {
  if (!location) {
    throw new Error('Location is required');
  }

  // Normalize location (remove spaces, lowercase for comparison)
  const normalizedInput = location.replace(/\s+/g, '').toLowerCase();
  
  // Find matching location from VALID_LOCATIONS
  const matchedLocation = VALID_LOCATIONS.find(
    validLoc => validLoc.replace(/\s+/g, '').toLowerCase() === normalizedInput
  );

  if (!matchedLocation) {
    throw new Error(`Invalid location: ${location}. Valid locations: ${VALID_LOCATIONS.join(', ')}`);
  }

  // Use the matched location (preserving original casing)
  const collectionName = `tables_${matchedLocation.replace(/\s+/g, '')}`;
  console.log(`   Location match: ${location} → ${matchedLocation} → collection: ${collectionName}`);
  return collectionName;
}

// GET: Fetch all tables across all sections for a location
app.get('/api/tables', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const requestedBranch = req.query.branch || req.query.location;

    let location;
    if (role === 'admin') {
      location = requestedBranch || adminBranch;
      if (!location) {
        return res.status(400).json({ 
          success: false, 
          message: 'Location parameter required' 
        });
      }
    } else {
      location = adminBranch;
      if (!location) {
        return res.status(403).json({ 
          success: false, 
          message: 'No branch assigned' 
        });
      }
    }

    const collectionName = getTableCollectionName(location);
    const collection = mongoose.connection.db.collection(collectionName);

    const floorPlan = await collection.findOne({ type: 'floorplan' });

    // Extract all tables from all sections
    const allTables = [];
    if (floorPlan && floorPlan.sections) {
      floorPlan.sections.forEach(section => {
        if (section.tables) {
          section.tables.forEach(table => {
            allTables.push({
              ...table,
              status: normalizeTableStatus(table.status),
              sectionName: section.name,
              sectionType: section.type
            });
          });
        }
      });
    }

    res.json({
      success: true,
      data: allTables,
      location,
      totalTables: allTables.length
    });

  } catch (error) {
    console.error('Get tables error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message || 'Server error' 
    });
  }
});

// PUT: Update a specific table's status/order/bill
app.put('/api/tables/:tableId', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const { tableId } = req.params;
    const { location, sectionId, updateData } = req.body;

    if (!location || !sectionId) {
      return res.status(400).json({ 
        success: false, 
        message: 'location and sectionId are required' 
      });
    }

    // Validate permissions
    if (role !== 'admin' && adminBranch !== location) {
      return res.status(403).json({ 
        success: false, 
        message: 'You can only modify tables in your assigned branch' 
      });
    }

    const collectionName = getTableCollectionName(location);
    const collection = mongoose.connection.db.collection(collectionName);

    // Sanitize update data - remove undefined values
    const sanitizedUpdateData = {};
    if (updateData) {
      Object.keys(updateData).forEach(key => {
        if (updateData[key] !== undefined) {
          sanitizedUpdateData[key] = updateData[key];
        }
      });
    }

    // Update the specific table within the section
    const result = await collection.findOneAndUpdate(
      { 
        type: 'floorplan',
        'sections.id': sectionId,
        'sections.tables._id': tableId
      },
      { 
        $set: {
          'sections.$[section].tables.$[table]': {
            ...sanitizedUpdateData,
            lastModified: new Date()
          },
          updatedAt: new Date()
        }
      },
      {
        arrayFilters: [
          { 'section.id': sectionId },
          { 'table._id': tableId }
        ],
        returnDocument: 'after'
      }
    );

    if (!result.value) {
      return res.status(404).json({ 
        success: false, 
        message: 'Table not found' 
      });
    }

    res.json({
      success: true,
      message: 'Table updated successfully',
      data: result.value
    });

  } catch (error) {
    console.error('Update table error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message || 'Server error' 
    });
  }
});

// POST: Add new table to a section
app.post('/api/tables', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const { location, sectionId, table } = req.body;

    if (!location || !sectionId || !table) {
      return res.status(400).json({ 
        success: false, 
        message: 'location, sectionId, and table data are required' 
      });
    }

    // Only admins can add tables
    if (role !== 'admin') {
      return res.status(403).json({ 
        success: false, 
        message: 'Only admins can add new tables' 
      });
    }

    const collectionName = getTableCollectionName(location);
    const collection = mongoose.connection.db.collection(collectionName);

    const newTable = {
      ...table,
      _id: table._id || `t_${sectionId}_${Date.now()}`,
      lastModified: new Date()
    };

    const result = await collection.findOneAndUpdate(
      { 
        type: 'floorplan',
        'sections.id': sectionId
      },
      { 
        $push: { 'sections.$.tables': newTable },
        $set: { updatedAt: new Date() }
      },
      { returnDocument: 'after' }
    );

    if (!result.value) {
      return res.status(404).json({ 
        success: false, 
        message: 'Section not found' 
      });
    }

    res.json({
      success: true,
      message: 'Table added successfully',
      data: newTable
    });

  } catch (error) {
    console.error('Add table error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message || 'Server error' 
    });
  }
});

// DELETE: Remove a table
app.delete('/api/tables/:tableId', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const { tableId } = req.params;
    const { location, sectionId } = req.query;

    if (!location || !sectionId) {
      return res.status(400).json({ 
        success: false, 
        message: 'location and sectionId query parameters are required' 
      });
    }

    // Only admins can delete tables
    if (role !== 'admin') {
      return res.status(403).json({ 
        success: false, 
        message: 'Only admins can delete tables' 
      });
    }

    const collectionName = getTableCollectionName(location);
    const collection = mongoose.connection.db.collection(collectionName);

    const result = await collection.findOneAndUpdate(
      { 
        type: 'floorplan',
        'sections.id': sectionId
      },
      { 
        $pull: { 'sections.$.tables': { _id: tableId } },
        $set: { updatedAt: new Date() }
      },
      { returnDocument: 'after' }
    );

    if (!result.value) {
      return res.status(404).json({ 
        success: false, 
        message: 'Table or section not found' 
      });
    }

    res.json({
      success: true,
      message: 'Table deleted successfully'
    });

  } catch (error) {
    console.error('Delete table error:', error);
    res.status(500).json({ 
      success: false, 
      message: error.message || 'Server error' 
    });
  }
});

// GET: List all valid locations
app.get('/api/tables/locations', verifyToken, async (req, res) => {
  try {
    res.json({
      success: true,
      locations: VALID_LOCATIONS
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Server error' 
    });
  }
});

// ============================================================================
// IN-HOUSE ORDERS ENDPOINTS
// ============================================================================

// POST: Create/Save In-House Order (stores in tables collection with unique token)
app.post('/api/inhouse-orders', verifyToken, async (req, res) => {
  try {
    const { branch, location, tableId, tableNumber, items, totalAmount, waiter, orderType, deliveryType, customerName, customerPhone, customerAddress } = req.body;

    console.log('📝 Creating in-house order with:', { branch, location, tableId, tableNumber, itemsCount: items?.length, totalAmount, orderType, deliveryType });

    // Validate required fields
    if (!branch && !location) {
      return res.status(400).json({ success: false, message: 'Branch or location is required' });
    }
    // tableId is only required for regular in-house orders, not for on-call orders
    if (!orderType || orderType !== 'oncall') {
      if (!tableId) {
        return res.status(400).json({ success: false, message: 'tableId is required' });
      }
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'Items are required' });
    }
    if (typeof totalAmount !== 'number') {
      return res.status(400).json({ success: false, message: 'totalAmount must be a number' });
    }

    const normalizedBranch = normalizeBranchName(branch || location);
    let collectionName;
    try {
      collectionName = getTableCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    console.log('✅ Collection name resolved:', collectionName);

    const now = new Date();
    const collection = mongoose.connection.db.collection(collectionName);

    // For on-call orders, skip the existing order check since there's no tableId
    if (orderType === 'oncall') {
      // Generate unique token for this new on-call order
      const orderToken = 'OC-' + Date.now() + '-' + Math.random().toString(36).substring(2, 8).toUpperCase();

      const onCallOrderDoc = {
        orderId: orderToken,
        orderToken: orderToken,
        orderNumber: `#${orderToken}`,
        orderType: 'oncall',
        deliveryType: deliveryType || 'takeaway',
        customerName: customerName || 'Guest',
        customerPhone: customerPhone || '',
        customerAddress: customerAddress || '',
        location: normalizedBranch,
        branch: normalizedBranch,
        items: items.map(item => ({
          name: item.name || '',
          description: item.description || '',
          price: Number(item.price) || 0,
          quantity: Number(item.quantity) || 1,
          imageUrl: item.imageUrl || '',
          spiceLevel: typeof item.spiceLevel === 'string'
            ? item.spiceLevel.trim()
            : (typeof item.spice_level === 'string' ? item.spice_level.trim() : null)
        })),
        totalAmount: Number(totalAmount),
        orderTotal: Number(totalAmount),
        subtotal: Number(totalAmount),
        paymentMethod: 'pending',
        billAmount: 0,
        tip: 0,
        specialInstructions: req.body.specialInstructions || '',
        status: 'pending',
        void: false,
        voidedAt: null,
        billedAt: null,
        completedAt: null,
        createdAt: now,
        updatedAt: now
      };

      const result = await collection.insertOne(onCallOrderDoc);
      const insertedOrder = { _id: result.insertedId, ...onCallOrderDoc };

      console.log('💾 On-call order inserted successfully into', collectionName, 'with ID:', result.insertedId);

      io.to(getOrderRoomName(normalizedBranch)).emit('order:new', insertedOrder);
      console.log('📢 On-call order created with token:', orderToken);

      return res.json({ 
        success: true, 
        data: insertedOrder,
        orderToken: orderToken
      });
    }

    // If there is already an open in-house order for this table, update it
    // instead of creating a new doc. This guarantees only one open order per table.
    const existingOpenOrder = await collection.findOne(
      {
        tableId: String(tableId),
        status: 'open',
        $or: [
          { type: 'inhouse' },
          { type: { $exists: false } },
          { type: null }
        ]
      },
      { sort: { createdAt: -1, updatedAt: -1, _id: -1 } }
    );

    if (existingOpenOrder) {
      const updateExisting = {
        items: items.map(item => ({
          name: item.name || '',
          description: item.description || '',
          price: Number(item.price) || 0,
          quantity: Number(item.quantity) || 1,
          imageUrl: item.imageUrl || '',
          spiceLevel: typeof item.spiceLevel === 'string'
            ? item.spiceLevel.trim()
            : (typeof item.spice_level === 'string' ? item.spice_level.trim() : null)
        })),
        totalAmount: Number(totalAmount),
        orderTotal: Number(totalAmount),
        subtotal: Number(totalAmount),
        assignedWaiter: waiter || existingOpenOrder.assignedWaiter || null,
        type: 'inhouse',
        updatedAt: now
      };

      const updated = await collection.findOneAndUpdate(
        { _id: existingOpenOrder._id },
        { $set: updateExisting },
        { returnDocument: 'after' }
      );

      if (!updated.value) {
        return res.status(500).json({ success: false, message: 'Failed to update existing open order' });
      }

      io.to(getOrderRoomName(normalizedBranch)).emit('order:updated', updated.value);
      return res.json({
        success: true,
        data: updated.value,
        orderToken: updated.value.orderToken
      });
    }

    // Generate unique token for this new order
    const orderToken = 'IN-' + Date.now() + '-' + Math.random().toString(36).substring(2, 8).toUpperCase();

    const inHouseOrderDoc = {
      orderId: orderToken,
      orderToken: orderToken,
      orderNumber: `#${orderToken}`,
      tableId: tableId,
      tableNumber: tableNumber || 0,
      location: normalizedBranch,
      branch: normalizedBranch,
      items: items.map(item => ({
        name: item.name || '',
        description: item.description || '',
        price: Number(item.price) || 0,
        quantity: Number(item.quantity) || 1,
        imageUrl: item.imageUrl || '',
        spiceLevel: typeof item.spiceLevel === 'string'
          ? item.spiceLevel.trim()
          : (typeof item.spice_level === 'string' ? item.spice_level.trim() : null)
      })),
      totalAmount: Number(totalAmount),
      orderTotal: Number(totalAmount),
      subtotal: Number(totalAmount), // Before tax and tip
      type: 'inhouse',
      paymentMethod: 'pending', // pending, cash, card
      billAmount: 0, // Amount billed
      tip: 0, // Tip amount
      assignedWaiter: waiter || null,
      specialInstructions: req.body.specialInstructions || '',
      status: 'open', // open, billed, completed
      void: false,
      voidedAt: null,
      billedAt: null,
      completedAt: null,
      createdAt: now,
      updatedAt: now
    };

    // Insert into tables collection
    const result = await collection.insertOne(inHouseOrderDoc);
    const insertedOrder = { _id: result.insertedId, ...inHouseOrderDoc };

    console.log('💾 Order inserted successfully into', collectionName, 'with ID:', result.insertedId);

    // Emit Socket.IO event to trigger notification in admin app
    io.to(getOrderRoomName(normalizedBranch)).emit('order:new', insertedOrder);
    console.log('📢 In-house order created with token:', orderToken, 'emitted to room:', getOrderRoomName(normalizedBranch));

    res.json({ 
      success: true, 
      data: insertedOrder,
      orderToken: orderToken
    });

  } catch (error) {
    console.error('Create in-house order error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// GET: Fetch In-House Order by Token
app.get('/api/inhouse-orders/:orderToken', verifyToken, async (req, res) => {
  try {
    const { orderToken } = req.params;
    const { branch, location } = req.query;

    if (!branch && !location) {
      return res.status(400).json({ success: false, message: 'Branch or location is required' });
    }

    const normalizedBranch = normalizeBranchName(branch || location);
    let collectionName;
    try {
      collectionName = getTableCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(collectionName);
    const order = await collection.findOne({ orderToken: orderToken });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    res.json({ success: true, data: order });

  } catch (error) {
    console.error('Get in-house order error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// GET: Fetch Active (Open) In-House Order for a Table
// Useful when the floorplan table doc doesn't have currentOrderToken yet.
// Query: ?branch=Comox&tableId=t_main_hall_9
app.get('/api/inhouse-orders-active', verifyToken, async (req, res) => {
  try {
    const { branch, location, tableId } = req.query;

    if (!branch && !location) {
      return res.status(400).json({ success: false, message: 'Branch or location is required' });
    }
    if (!tableId) {
      return res.status(400).json({ success: false, message: 'tableId is required' });
    }

    const normalizedBranch = normalizeBranchName(branch || location);
    let collectionName;
    try {
      collectionName = getTableCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(collectionName);
    const tableIdString = String(tableId);
    const order = await collection.findOne(
      {
        tableId: tableIdString,
        status: 'open',
        $or: [
          { type: 'inhouse' },
          { type: { $exists: false } },
          { type: null }
        ]
      },
      { sort: { createdAt: -1, updatedAt: -1, _id: -1 } }
    );

    if (!order) {
      return res.status(404).json({ success: false, message: 'Active order not found' });
    }

    res.json({ success: true, data: order });
  } catch (error) {
    console.error('Get active in-house order error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// GET: List On-Call Orders (Delivery/Takeaway)
app.get('/api/inhouse-orders', verifyToken, async (req, res) => {
  try {
    const { branch, location, orderType } = req.query;

    if (!branch && !location) {
      return res.status(400).json({ success: false, message: 'Branch or location is required' });
    }

    const normalizedBranch = normalizeBranchName(branch || location);
    let collectionName;
    try {
      collectionName = getTableCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(collectionName);

    // Build filter
    const filter = {};
    if (orderType === 'oncall') {
      filter.orderType = 'oncall';
    }

    // Fetch orders sorted by creation date (newest first)
    const orders = await collection
      .find(filter)
      .sort({ createdAt: -1 })
      .toArray();

    res.json({ success: true, data: orders });
  } catch (error) {
    console.error('Get inhouse orders error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// PATCH: Update In-House Order Status (for billing, completion, etc.)
app.patch('/api/inhouse-orders/:orderToken', verifyToken, async (req, res) => {
  try {
    const { orderToken } = req.params;
    const { branch, location } = req.query;
    const updateData = req.body;

    if (!branch && !location) {
      return res.status(400).json({ success: false, message: 'Branch or location is required' });
    }

    const normalizedBranch = normalizeBranchName(branch || location);
    let collectionName;
    try {
      collectionName = getTableCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(collectionName);
    
    const coerceBoolean = (value) => {
      if (value === true || value === false) return value;
      if (typeof value === 'string') {
        const normalized = value.trim().toLowerCase();
        if (normalized === 'true') return true;
        if (normalized === 'false') return false;
      }
      return undefined;
    };

    const sanitizedUpdateData = {};
    if (updateData.paymentMethod !== undefined && updateData.paymentMethod !== null) {
      const normalizedPaymentMethod = String(updateData.paymentMethod).trim().toLowerCase();
      if (normalizedPaymentMethod) sanitizedUpdateData.paymentMethod = normalizedPaymentMethod;
    }
    if (updateData.totalAmount !== undefined) {
      sanitizedUpdateData.totalAmount = Number(updateData.totalAmount);
      sanitizedUpdateData.orderTotal = Number(updateData.totalAmount);
      sanitizedUpdateData.subtotal = Number(updateData.totalAmount);
    }
    if (Array.isArray(updateData.items)) {
      sanitizedUpdateData.items = updateData.items.map(item => ({
        name: item.name || '',
        description: item.description || '',
        price: Number(item.price) || 0,
        quantity: Number(item.quantity) || 1,
        imageUrl: item.imageUrl || '',
        spiceLevel: typeof item.spiceLevel === 'string'
          ? item.spiceLevel.trim()
          : (typeof item.spice_level === 'string' ? item.spice_level.trim() : null)
      }));
    }
    if (updateData.billAmount !== undefined) sanitizedUpdateData.billAmount = Number(updateData.billAmount);
    if (updateData.tip !== undefined) sanitizedUpdateData.tip = Number(updateData.tip);
    if (updateData.status !== undefined && updateData.status !== null) {
      const normalizedStatus = String(updateData.status).trim().toLowerCase();
      if (normalizedStatus) sanitizedUpdateData.status = normalizedStatus;
    }
    if (updateData.assignedWaiter !== undefined) sanitizedUpdateData.assignedWaiter = updateData.assignedWaiter;
    if (updateData.specialInstructions !== undefined) sanitizedUpdateData.specialInstructions = updateData.specialInstructions;
    const voidValue = coerceBoolean(updateData.void);
    if (voidValue !== undefined) sanitizedUpdateData.void = voidValue;

    // Don't override type - keep the existing type (inhouse or oncall)
    
    // Set timestamp for status change and calculate billAmount when billing
    if (updateData.status === 'billed') {
      sanitizedUpdateData.billedAt = new Date();
      // Calculate billAmount as subtotal + tip when order is billed
      const currentOrder = await collection.findOne({ orderToken: orderToken });
      if (currentOrder) {
        const subtotal = currentOrder.subtotal || 0;
        const tip = (sanitizedUpdateData.tip !== undefined) ? sanitizedUpdateData.tip : (currentOrder.tip || 0);
        sanitizedUpdateData.billAmount = subtotal + tip;
      }
    }
    if (updateData.status === 'completed') sanitizedUpdateData.completedAt = new Date();
    if (voidValue === true) sanitizedUpdateData.voidedAt = new Date();
    
    sanitizedUpdateData.updatedAt = new Date();

    const result = await collection.findOneAndUpdate(
      {
        orderToken: orderToken
      },
      { $set: sanitizedUpdateData },
      { returnDocument: 'after' }
    );

    if (!result.value) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    // Emit Socket.IO event for order update
    io.to(getOrderRoomName(normalizedBranch)).emit('order:updated', result.value);

    res.json({ success: true, data: result.value });

  } catch (error) {
    console.error('Update in-house order error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// GET: Print In-House Bill by Token
app.get('/api/inhouse-orders/:orderToken/bill', verifyToken, async (req, res) => {
  try {
    const { orderToken } = req.params;
    const { branch, location } = req.query;

    if (!branch && !location) {
      return res.status(400).json({ success: false, message: 'Branch or location is required' });
    }

    const normalizedBranch = normalizeBranchName(branch || location);
    let collectionName;
    try {
      collectionName = getTableCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(collectionName);
    const order = await collection.findOne({ orderToken: orderToken });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    // Return bill data ready for printing
    res.json({ 
      success: true, 
      data: {
        orderToken: order.orderToken,
        tableNumber: order.tableNumber,
        tableId: order.tableId,
        items: order.items,
        totalAmount: order.totalAmount,
        subtotal: order.subtotal,
        billAmount: order.billAmount,
        tip: order.tip,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
        paymentMethod: order.paymentMethod,
        status: order.status,
        assignedWaiter: order.assignedWaiter
      }
    });

  } catch (error) {
    console.error('Get bill error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ============================================================================
// VOID CODE MANAGEMENT FOR IN-HOUSE ORDERS
// ============================================================================

// Void Codes Schema - stored in 'voidcodes' collection
// { location: 'Comox', voidCode: 'VOID2468', updatedBy: 'admin@example.com', updatedAt: Date }

// Initialize default void codes for each location
const initializeVoidCodes = async () => {
  try {
    if (mongoose.connection.readyState !== 1) {
      setTimeout(initializeVoidCodes, 5000);
      return;
    }

    const voidCodesCollection = mongoose.connection.db.collection('voidcodes');
    const defaultVoidCodes = [
      { location: 'Canmore', voidCode: 'VOID2468' },
      { location: 'Comox', voidCode: 'VOID3691' },
      { location: 'Cranbrook', voidCode: 'VOID5814' },
      { location: 'Fort Saskatchewan', voidCode: 'VOID7293' },
      { location: 'Invermere', voidCode: 'VOID8520' },
      { location: 'Ladysmith', voidCode: 'VOID1347' },
      { location: 'Lloydminster', voidCode: 'VOID4762' },
      { location: 'PortAlberni', voidCode: 'VOID9158' },
      { location: 'Tofino', voidCode: 'VOID6039' },
      { location: 'CampbellRiver', voidCode: 'VOID2785' }
    ];

    for (const code of defaultVoidCodes) {
      const exists = await voidCodesCollection.findOne({ location: code.location });
      if (!exists) {
        await voidCodesCollection.insertOne({
          ...code,
          createdAt: new Date(),
          updatedAt: new Date()
        });
        console.log(`✓ Initialized void code for ${code.location}`);
      }
    }
  } catch (error) {
    console.error('Error initializing void codes:', error);
  }
};

// GET: Get Void Code for a Location (Admin and Manager only)
app.get('/api/void-codes', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const normalizedRole = normalizeRole(role);
    const requestedLocation = req.query.location;

    // Only admin and manager can view void codes
    if (normalizedRole === 'staff') {
      return res.status(403).json({ success: false, message: 'Forbidden - Staff cannot access void codes' });
    }

    const voidCodesCollection = mongoose.connection.db.collection('voidcodes');

    // Admin can view all locations or a specific one
    if (normalizedRole === 'admin') {
      if (requestedLocation) {
        const normalizedLocation = normalizeBranchName(requestedLocation);
        const voidCode = await voidCodesCollection.findOne({ location: normalizedLocation });
        
        if (!voidCode) {
          return res.status(404).json({ success: false, message: 'Void code not found for this location' });
        }

        return res.json({ 
          success: true, 
          data: {
            location: voidCode.location,
            voidCode: voidCode.voidCode,
            updatedBy: voidCode.updatedBy,
            updatedAt: voidCode.updatedAt
          }
        });
      } else {
        // Return all void codes
        const allCodes = await voidCodesCollection.find({}).toArray();
        return res.json({ 
          success: true, 
          data: allCodes.map(code => ({
            location: code.location,
            voidCode: code.voidCode,
            updatedBy: code.updatedBy,
            updatedAt: code.updatedAt
          }))
        });
      }
    }

    // Manager can only view their own branch
    if (normalizedRole === 'manager') {
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }

      const normalizedBranch = normalizeBranchName(adminBranch);
      const voidCode = await voidCodesCollection.findOne({ location: normalizedBranch });

      if (!voidCode) {
        return res.status(404).json({ success: false, message: 'Void code not found for your location' });
      }

      return res.json({ 
        success: true, 
        data: {
          location: voidCode.location,
          voidCode: voidCode.voidCode,
          updatedBy: voidCode.updatedBy,
          updatedAt: voidCode.updatedAt
        }
      });
    }

    res.status(403).json({ success: false, message: 'Forbidden' });

  } catch (error) {
    console.error('Get void codes error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// PATCH: Update Void Code for a Location (Admin and Manager only)
app.patch('/api/void-codes', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const normalizedRole = normalizeRole(role);
    const { location, voidCode } = req.body;

    // Only admin and manager can update void codes
    if (normalizedRole === 'staff') {
      return res.status(403).json({ success: false, message: 'Forbidden - Staff cannot edit void codes' });
    }

    if (!location || !voidCode) {
      return res.status(400).json({ success: false, message: 'Location and voidCode are required' });
    }

    if (typeof voidCode !== 'string' || voidCode.trim().length < 4) {
      return res.status(400).json({ success: false, message: 'Void code must be at least 4 characters' });
    }

    const normalizedLocation = normalizeBranchName(location);

    // Manager can only update their own branch
    if (normalizedRole === 'manager') {
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }

      const normalizedBranch = normalizeBranchName(adminBranch);
      if (normalizedBranch !== normalizedLocation) {
        return res.status(403).json({ 
          success: false, 
          message: `You can only update void code for your branch: ${normalizedBranch}` 
        });
      }
    }

    // Admin can update any location
    const voidCodesCollection = mongoose.connection.db.collection('voidcodes');
    
    const result = await voidCodesCollection.findOneAndUpdate(
      { location: normalizedLocation },
      { 
        $set: { 
          voidCode: voidCode.trim().toUpperCase(),
          updatedBy: req.admin.email,
          updatedAt: new Date()
        }
      },
      { 
        upsert: true, 
        returnDocument: 'after' 
      }
    );

    res.json({ 
      success: true, 
      message: `Void code updated for ${normalizedLocation}`,
      data: {
        location: result.value.location,
        voidCode: result.value.voidCode,
        updatedBy: result.value.updatedBy,
        updatedAt: result.value.updatedAt
      }
    });

  } catch (error) {
    console.error('Update void code error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// POST: Validate Void Code and Remove Items from In-House Order
app.post('/api/inhouse-orders/:orderToken/void', verifyToken, async (req, res) => {
  try {
    const { orderToken } = req.params;
    const { branch, location, voidCode, itemsToRemove } = req.body;

    // Validate required fields
    if (!branch && !location) {
      return res.status(400).json({ success: false, message: 'Branch or location is required' });
    }
    if (!voidCode) {
      return res.status(400).json({ success: false, message: 'Void code is required' });
    }
    if (!Array.isArray(itemsToRemove) || itemsToRemove.length === 0) {
      return res.status(400).json({ success: false, message: 'Items to remove are required' });
    }

    const normalizedBranch = normalizeBranchName(branch || location);

    // Validate void code against location-specific code
    const voidCodesCollection = mongoose.connection.db.collection('voidcodes');
    const locationVoidCode = await voidCodesCollection.findOne({ location: normalizedBranch });

    if (!locationVoidCode || locationVoidCode.voidCode !== voidCode.trim().toUpperCase()) {
      return res.status(401).json({ success: false, message: 'Invalid void code for this location' });
    }

    let collectionName;
    try {
      collectionName = getTableCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(collectionName);
    const order = await collection.findOne({ orderToken: orderToken });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    // Remove specified items from order
    const remainingItems = order.items.filter(item => {
      const itemSpice = item.spiceLevel ?? item.spice_level ?? null;
      // Check if item should be removed (match by name and price)
      return !itemsToRemove.some(removeItem => {
        const removeSpice = removeItem.spiceLevel ?? removeItem.spice_level ?? null;
        const spiceMatches = removeSpice == null || removeSpice === ''
          ? true
          : removeSpice === itemSpice;

        return removeItem.name === item.name &&
            removeItem.price === item.price &&
            spiceMatches;
      });
    });

    // Calculate new total
    const newTotal = remainingItems.reduce((sum, item) => 
      sum + (item.price * item.quantity), 0
    );

    // Update order with void flag and new items
    const updateData = {
      items: remainingItems,
      totalAmount: newTotal,
      orderTotal: newTotal,
      void: true,
      voidedAt: new Date(),
      voidedBy: req.admin.email,
      voidCode: voidCode,
      updatedAt: new Date()
    };

    const result = await collection.findOneAndUpdate(
      { orderToken: orderToken },
      { $set: updateData },
      { returnDocument: 'after' }
    );

    if (!result.value) {
      return res.status(404).json({ success: false, message: 'Failed to update order' });
    }

    // Emit Socket.IO event for order update
    io.to(getOrderRoomName(normalizedBranch)).emit('order:updated', result.value);

    res.json({ 
      success: true, 
      message: 'Items voided successfully',
      data: result.value
    });

  } catch (error) {
    console.error('Void order items error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});


// Get Analytics Data for Branch
app.get('/api/analytics', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const normalizedRole = normalizeRole(role);
    if (normalizedRole === 'staff') {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }
    const requestedBranch = req.query.branch;
    const period = (req.query.period || 'month').toString().toLowerCase(); // week, month, year

    let branch;
    if (normalizedRole === 'admin') {
      if (!requestedBranch) {
        return res.status(400).json({ success: false, message: 'Branch parameter required for admin' });
      }
      branch = requestedBranch;
    } else {
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }
      branch = adminBranch;
    }

    const normalizedBranch = normalizeBranchName(branch);
    let ordersCollectionName;
    try {
      ordersCollectionName = resolveOrdersCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(ordersCollectionName);

    const now = new Date();
    const startToday = new Date(now);
    startToday.setHours(0, 0, 0, 0);
    const endToday = new Date(now);
    endToday.setHours(23, 59, 59, 999);

    const startMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
    const endMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

    const startWeek = new Date(now);
    startWeek.setHours(0, 0, 0, 0);
    startWeek.setDate(startWeek.getDate() - 6);
    const endWeek = new Date(now);
    endWeek.setHours(23, 59, 59, 999);

    const startYear = new Date(now.getFullYear(), 0, 1, 0, 0, 0, 0);
    const endYear = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);

    const startFiveYears = new Date(now.getFullYear() - 4, 0, 1, 0, 0, 0, 0);
    const endFiveYears = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);

    const [result] = await collection.aggregate([
      {
        $addFields: {
          completedDate: { $ifNull: ['$completedAt', '$updatedAt', '$createdAt'] },
          orderValue: { $ifNull: ['$orderTotal', '$totalAmount', 0] }
        }
      },
      {
        $match: {
          status: 'completed',
          completedDate: { $type: 'date' }
        }
      },
      {
        $facet: {
          today: [
            { $match: { completedDate: { $gte: startToday, $lte: endToday } } },
            { $group: { _id: null, total: { $sum: '$orderValue' } } }
          ],
          month: [
            { $match: { completedDate: { $gte: startMonth, $lte: endMonth } } },
            { $group: { _id: null, total: { $sum: '$orderValue' } } }
          ],
          topItems: [
            { $unwind: '$items' },
            { $match: { items: { $ne: null } } },
            {
              $group: {
                _id: { $ifNull: ['$items.itemId', '$items.name'] },
                name: { $first: '$items.name' },
                quantity: { $sum: { $ifNull: ['$items.quantity', 1] } }
              }
            },
            { $sort: { quantity: -1 } },
            { $limit: 5 }
          ],
          dailyIncome: [
            { $match: { completedDate: { $gte: startMonth, $lte: endMonth } } },
            {
              $group: {
                _id: { $dateToString: { format: '%Y-%m-%d', date: '$completedDate' } },
                income: { $sum: '$orderValue' }
              }
            },
            { $sort: { _id: 1 } }
          ],
          weeklyIncome: [
            { $match: { completedDate: { $gte: startWeek, $lte: endWeek } } },
            {
              $group: {
                _id: { $dateToString: { format: '%Y-%m-%d', date: '$completedDate' } },
                income: { $sum: '$orderValue' }
              }
            },
            { $sort: { _id: 1 } }
          ],
          monthlyIncome: [
            { $match: { completedDate: { $gte: startYear, $lte: endYear } } },
            {
              $group: {
                _id: { $month: '$completedDate' },
                income: { $sum: '$orderValue' }
              }
            },
            { $sort: { _id: 1 } }
          ],
          yearlyIncome: [
            { $match: { completedDate: { $gte: startFiveYears, $lte: endFiveYears } } },
            {
              $group: {
                _id: { $year: '$completedDate' },
                income: { $sum: '$orderValue' }
              }
            },
            { $sort: { _id: 1 } }
          ]
        }
      }
    ]).toArray();

    const todayIncome = result?.today?.[0]?.total ?? 0;
    const monthIncome = result?.month?.[0]?.total ?? 0;
    const topItems = (result?.topItems || []).map((item, index) => ({
      rank: index + 1,
      name: item.name || 'Unknown',
      quantity: item.quantity || 0
    }));
    const dailyIncome = (result?.dailyIncome || []).map((item) => ({
      date: item._id,
      income: item.income || 0
    }));
    const weeklyIncome = (result?.weeklyIncome || []).map((item) => ({
      date: item._id,
      income: item.income || 0
    }));
    const monthlyIncome = (result?.monthlyIncome || []).map((item) => ({
      month: item._id,
      income: item.income || 0
    }));
    const yearlyIncome = (result?.yearlyIncome || []).map((item) => ({
      year: item._id,
      income: item.income || 0
    }));

    let chartData = dailyIncome;
    if (period === 'week') chartData = weeklyIncome;
    if (period === 'month') chartData = monthlyIncome;
    if (period === 'year') chartData = yearlyIncome;

    res.json({
      success: true,
      data: {
        todayIncome,
        monthIncome,
        topItems,
        chartData,
        dailyIncome,
        weeklyIncome,
        monthlyIncome,
        yearlyIncome,
        monthStart: startMonth,
        monthEnd: endMonth,
        weekStart: startWeek,
        weekEnd: endWeek,
        yearStart: startYear,
        yearEnd: endYear,
        fiveYearStart: startFiveYears,
        fiveYearEnd: endFiveYears,
        period
      },
      branch: normalizedBranch
    });

  } catch (error) {
    console.error('Get analytics error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Get In-House Orders Analytics
app.get('/api/analytics/inhouse', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const normalizedRole = normalizeRole(role);
    if (normalizedRole === 'staff') {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    const requestedBranch = req.query.branch;
    let branch;
    if (normalizedRole === 'admin') {
      if (!requestedBranch) {
        return res.status(400).json({ success: false, message: 'Branch parameter required for admin' });
      }
      branch = requestedBranch;
    } else {
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }
      branch = adminBranch;
    }

    const normalizedBranch = normalizeBranchName(branch);
    let tablesCollectionName;
    try {
      tablesCollectionName = getTableCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const now = new Date();
    const startToday = new Date(now);
    startToday.setHours(0, 0, 0, 0);
    const endToday = new Date(now);
    endToday.setHours(23, 59, 59, 999);

    const startMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
    const endMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

    const startYear = new Date(now.getFullYear(), 0, 1, 0, 0, 0, 0);
    const endYear = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);

    const collection = mongoose.connection.db.collection(tablesCollectionName);

    const [result] = await collection.aggregate([
      {
        $facet: {
          todayOrders: [
            { $match: { type: 'inhouse', createdAt: { $gte: startToday, $lte: endToday }, status: { $in: ['billed', 'completed'] } } },
            { $count: 'count' }
          ],
          monthOrders: [
            { $match: { type: 'inhouse', createdAt: { $gte: startMonth, $lte: endMonth }, status: { $in: ['billed', 'completed'] } } },
            { $count: 'count' }
          ],
          todayRevenue: [
            { $match: { type: 'inhouse', createdAt: { $gte: startToday, $lte: endToday }, status: { $in: ['billed', 'completed'] } } },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          monthRevenue: [
            { $match: { type: 'inhouse', createdAt: { $gte: startMonth, $lte: endMonth }, status: { $in: ['billed', 'completed'] } } },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          todayCash: [
            {
              $match: {
                type: 'inhouse',
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'cash'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          monthCash: [
            {
              $match: {
                type: 'inhouse',
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'cash'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          todayCard: [
            {
              $match: {
                type: 'inhouse',
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'card'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          monthCard: [
            {
              $match: {
                type: 'inhouse',
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'card'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          todayVoided: [
            {
              $match: {
                type: 'inhouse',
                void: true,
                $or: [
                  { voidedAt: { $gte: startToday, $lte: endToday } },
                  { voidedAt: { $exists: false }, createdAt: { $gte: startToday, $lte: endToday } },
                  { voidedAt: null, createdAt: { $gte: startToday, $lte: endToday } }
                ]
              }
            },
            { $count: 'count' }
          ],
          monthVoided: [
            {
              $match: {
                type: 'inhouse',
                void: true,
                $or: [
                  { voidedAt: { $gte: startMonth, $lte: endMonth } },
                  { voidedAt: { $exists: false }, createdAt: { $gte: startMonth, $lte: endMonth } },
                  { voidedAt: null, createdAt: { $gte: startMonth, $lte: endMonth } }
                ]
              }
            },
            { $count: 'count' }
          ],
          todayVoidedByUser: [
            {
              $match: {
                type: 'inhouse',
                void: true,
                $or: [
                  { voidedAt: { $gte: startToday, $lte: endToday } },
                  { voidedAt: { $exists: false }, createdAt: { $gte: startToday, $lte: endToday } },
                  { voidedAt: null, createdAt: { $gte: startToday, $lte: endToday } }
                ]
              }
            },
            { $group: { _id: { $ifNull: ['$voidedBy', 'Unknown'] }, count: { $sum: 1 } } },
            { $sort: { count: -1, _id: 1 } },
            { $limit: 20 }
          ],
          monthVoidedByUser: [
            {
              $match: {
                type: 'inhouse',
                void: true,
                $or: [
                  { voidedAt: { $gte: startMonth, $lte: endMonth } },
                  { voidedAt: { $exists: false }, createdAt: { $gte: startMonth, $lte: endMonth } },
                  { voidedAt: null, createdAt: { $gte: startMonth, $lte: endMonth } }
                ]
              }
            },
            { $group: { _id: { $ifNull: ['$voidedBy', 'Unknown'] }, count: { $sum: 1 } } },
            { $sort: { count: -1, _id: 1 } },
            { $limit: 50 }
          ],
          todayTips: [
            { $match: { type: 'inhouse', createdAt: { $gte: startToday, $lte: endToday }, status: { $in: ['billed', 'completed'] } } },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          monthTips: [
            { $match: { type: 'inhouse', createdAt: { $gte: startMonth, $lte: endMonth }, status: { $in: ['billed', 'completed'] } } },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          todayCashTips: [
            {
              $match: {
                type: 'inhouse',
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'cash'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          monthCashTips: [
            {
              $match: {
                type: 'inhouse',
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'cash'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          todayCardTips: [
            {
              $match: {
                type: 'inhouse',
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'card'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          monthCardTips: [
            {
              $match: {
                type: 'inhouse',
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'card'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          topItems: [
            { $match: { type: 'inhouse', status: { $in: ['billed', 'completed'] } } },
            { $unwind: '$items' },
            { $match: { items: { $ne: null } } },
            {
              $group: {
                _id: '$items.name',
                name: { $first: '$items.name' },
                quantity: { $sum: '$items.quantity' }
              }
            },
            { $sort: { quantity: -1 } },
            { $limit: 5 }
          ],
          todayOnCallTakeaway: [
            { $match: { orderType: 'oncall', deliveryType: 'takeaway', createdAt: { $gte: startToday, $lte: endToday }, status: { $in: ['billed', 'completed'] } } },
            { $count: 'count' }
          ],
          monthOnCallTakeaway: [
            { $match: { orderType: 'oncall', deliveryType: 'takeaway', createdAt: { $gte: startMonth, $lte: endMonth }, status: { $in: ['billed', 'completed'] } } },
            { $count: 'count' }
          ],
          todayOnCallDelivery: [
            { $match: { orderType: 'oncall', deliveryType: 'delivery', createdAt: { $gte: startToday, $lte: endToday }, status: { $in: ['billed', 'completed'] } } },
            { $count: 'count' }
          ],
          monthOnCallDelivery: [
            { $match: { orderType: 'oncall', deliveryType: 'delivery', createdAt: { $gte: startMonth, $lte: endMonth }, status: { $in: ['billed', 'completed'] } } },
            { $count: 'count' }
          ],
          todayOnCallTakeawayRevenue: [
            { $match: { orderType: 'oncall', deliveryType: 'takeaway', createdAt: { $gte: startToday, $lte: endToday }, status: { $in: ['billed', 'completed'] } } },
            { $group: { _id: null, total: { $sum: '$totalAmount' } } }
          ],
          monthOnCallTakeawayRevenue: [
            { $match: { orderType: 'oncall', deliveryType: 'takeaway', createdAt: { $gte: startMonth, $lte: endMonth }, status: { $in: ['billed', 'completed'] } } },
            { $group: { _id: null, total: { $sum: '$totalAmount' } } }
          ],
          todayOnCallDeliveryRevenue: [
            { $match: { orderType: 'oncall', deliveryType: 'delivery', createdAt: { $gte: startToday, $lte: endToday }, status: { $in: ['billed', 'completed'] } } },
            { $group: { _id: null, total: { $sum: '$totalAmount' } } }
          ],
          monthOnCallDeliveryRevenue: [
            { $match: { orderType: 'oncall', deliveryType: 'delivery', createdAt: { $gte: startMonth, $lte: endMonth }, status: { $in: ['billed', 'completed'] } } },
            { $group: { _id: null, total: { $sum: '$totalAmount' } } }
          ],
          dailyRevenue: [
            { $match: { type: 'inhouse', createdAt: { $gte: startMonth, $lte: endMonth }, status: { $in: ['billed', 'completed'] } } },
            {
              $group: {
                _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
                revenue: { $sum: '$billAmount' }
              }
            },
            { $sort: { _id: 1 } }
          ],
          monthlyRevenue: [
            { $match: { type: 'inhouse', createdAt: { $gte: startYear, $lte: endYear }, status: { $in: ['billed', 'completed'] } } },
            {
              $group: {
                _id: { $month: '$createdAt' },
                revenue: { $sum: '$billAmount' }
              }
            },
            { $sort: { _id: 1 } }
          ]
        }
      }
    ]).toArray();

    const data = {
      todayOrders: result?.todayOrders?.[0]?.count ?? 0,
      monthOrders: result?.monthOrders?.[0]?.count ?? 0,
      todayRevenue: result?.todayRevenue?.[0]?.total ?? 0,
      monthRevenue: result?.monthRevenue?.[0]?.total ?? 0,
      todayCash: result?.todayCash?.[0]?.total ?? 0,
      monthCash: result?.monthCash?.[0]?.total ?? 0,
      todayCard: result?.todayCard?.[0]?.total ?? 0,
      monthCard: result?.monthCard?.[0]?.total ?? 0,
      todayVoided: result?.todayVoided?.[0]?.count ?? 0,
      monthVoided: result?.monthVoided?.[0]?.count ?? 0,
      todayVoidedByUser: (result?.todayVoidedByUser || []).map((row) => ({
        user: row._id || 'Unknown',
        count: row.count || 0
      })),
      monthVoidedByUser: (result?.monthVoidedByUser || []).map((row) => ({
        user: row._id || 'Unknown',
        count: row.count || 0
      })),
      todayTips: result?.todayTips?.[0]?.total ?? 0,
      monthTips: result?.monthTips?.[0]?.total ?? 0,
      todayCashTips: result?.todayCashTips?.[0]?.total ?? 0,
      monthCashTips: result?.monthCashTips?.[0]?.total ?? 0,
      todayCardTips: result?.todayCardTips?.[0]?.total ?? 0,
      monthCardTips: result?.monthCardTips?.[0]?.total ?? 0,
      topItems: (result?.topItems || []).map((item, index) => ({
        rank: index + 1,
        name: item.name || 'Unknown',
        quantity: item.quantity || 0
      })),
      todayOnCallTakeaway: result?.todayOnCallTakeaway?.[0]?.count ?? 0,
      monthOnCallTakeaway: result?.monthOnCallTakeaway?.[0]?.count ?? 0,
      todayOnCallDelivery: result?.todayOnCallDelivery?.[0]?.count ?? 0,
      monthOnCallDelivery: result?.monthOnCallDelivery?.[0]?.count ?? 0,
      todayOnCallTakeawayRevenue: result?.todayOnCallTakeawayRevenue?.[0]?.total ?? 0,
      monthOnCallTakeawayRevenue: result?.monthOnCallTakeawayRevenue?.[0]?.total ?? 0,
      todayOnCallDeliveryRevenue: result?.todayOnCallDeliveryRevenue?.[0]?.total ?? 0,
      monthOnCallDeliveryRevenue: result?.monthOnCallDeliveryRevenue?.[0]?.total ?? 0,
      dailyRevenue: (result?.dailyRevenue || []).map((item) => ({
        date: item._id,
        revenue: item.revenue || 0
      })),
      monthlyRevenue: (result?.monthlyRevenue || []).map((item) => ({
        month: item._id,
        revenue: item.revenue || 0
      }))
    };

    res.json({
      success: true,
      data,
      branch: normalizedBranch
    });

  } catch (error) {
    console.error('Get in-house analytics error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Get Analytics Report Data for Branch (PDF report)
app.get('/api/analytics/report', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const normalizedRole = normalizeRole(role);
    if (normalizedRole === 'staff') {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    const requestedBranch = req.query.branch;
    let branch;
    if (normalizedRole === 'admin') {
      if (!requestedBranch) {
        return res.status(400).json({ success: false, message: 'Branch parameter required for admin' });
      }
      branch = requestedBranch;
    } else {
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }
      branch = adminBranch;
    }

    const normalizedBranch = normalizeBranchName(branch);
    let ordersCollectionName;
    let tablesCollectionName;
    try {
      ordersCollectionName = resolveOrdersCollectionName(normalizedBranch);
      tablesCollectionName = getTableCollectionName(normalizedBranch);
    } catch (error) {
      return res.status(400).json({ success: false, message: 'Invalid branch location' });
    }

    const collection = mongoose.connection.db.collection(ordersCollectionName);
    const tablesCollection = mongoose.connection.db.collection(tablesCollectionName);

    const now = new Date();
    const startToday = new Date(now);
    startToday.setHours(0, 0, 0, 0);
    const endToday = new Date(now);
    endToday.setHours(23, 59, 59, 999);

    const startYesterday = new Date(startToday);
    startYesterday.setDate(startYesterday.getDate() - 1);
    const endYesterday = new Date(endToday);
    endYesterday.setDate(endYesterday.getDate() - 1);

    const startMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
    const endMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

    const startLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1, 0, 0, 0, 0);
    const endLastMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);

    const dayStartHour = 0;
    const dayEndHour = 18;

    const [result] = await collection.aggregate([
      {
        $addFields: {
          orderValue: { $ifNull: ['$orderTotal', '$totalAmount', 0] }
        }
      },
      {
        $facet: {
          total: [
            { $match: { createdAt: { $gte: startMonth, $lte: endMonth } } },
            { $count: 'count' }
          ],
          accepted: [
            { $match: { status: 'accepted', createdAt: { $gte: startMonth, $lte: endMonth } } },
            { $count: 'count' }
          ],
          rejected: [
            { $match: { status: 'rejected', createdAt: { $gte: startMonth, $lte: endMonth } } },
            { $count: 'count' }
          ],
          completed: [
            { $match: { status: 'completed', createdAt: { $gte: startMonth, $lte: endMonth } } },
            { $count: 'count' }
          ],
          failed: [
            { $match: { status: 'failed', createdAt: { $gte: startMonth, $lte: endMonth } } },
            { $count: 'count' }
          ],
          totalToday: [
            { $match: { createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          acceptedToday: [
            { $match: { status: 'accepted', createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          rejectedToday: [
            { $match: { status: 'rejected', createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          completedToday: [
            { $match: { status: 'completed', createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          failedToday: [
            { $match: { status: 'failed', createdAt: { $gte: startToday, $lte: endToday } } },
            { $count: 'count' }
          ],
          salesToday: [
            {
              $match: {
                status: 'completed',
                createdAt: { $gte: startToday, $lte: endToday }
              }
            },
            { $group: { _id: null, total: { $sum: '$orderValue' } } }
          ],
          salesYesterday: [
            {
              $match: {
                status: 'completed',
                createdAt: { $gte: startYesterday, $lte: endYesterday }
              }
            },
            { $group: { _id: null, total: { $sum: '$orderValue' } } }
          ],
          salesThisMonth: [
            {
              $match: {
                status: 'completed',
                createdAt: { $gte: startMonth, $lte: endMonth }
              }
            },
            { $group: { _id: null, total: { $sum: '$orderValue' } } }
          ],
          salesLastMonth: [
            {
              $match: {
                status: 'completed',
                createdAt: { $gte: startLastMonth, $lte: endLastMonth }
              }
            },
            { $group: { _id: null, total: { $sum: '$orderValue' } } }
          ],
          topItems: [
            { $match: { status: 'completed', createdAt: { $gte: startMonth, $lte: endMonth } } },
            { $unwind: '$items' },
            {
              $group: {
                _id: { $ifNull: ['$items.itemId', '$items.name'] },
                name: { $first: '$items.name' },
                quantity: { $sum: { $ifNull: ['$items.quantity', 1] } }
              }
            },
            { $sort: { quantity: -1 } },
            { $limit: 3 }
          ],
          dayNight: [
            { $match: { createdAt: { $gte: startMonth, $lte: endMonth } } },
            {
              $addFields: {
                hour: { $hour: '$createdAt' }
              }
            },
            {
              $group: {
                _id: {
                  $cond: [
                    { $and: [{ $gte: ['$hour', dayStartHour] }, { $lt: ['$hour', dayEndHour] }] },
                    'day',
                    'night'
                  ]
                },
                count: { $sum: 1 }
              }
            }
          ]
        }
      }
    ]).toArray();

    const getCount = (arr) => (arr?.[0]?.count ?? 0);
    const getTotal = (arr) => (arr?.[0]?.total ?? 0);

    const dayNightMap = (result?.dayNight || []).reduce(
      (acc, item) => {
        acc[item._id] = item.count || 0;
        return acc;
      },
      { day: 0, night: 0 }
    );

    const topItems = (result?.topItems || []).map((item, index) => ({
      rank: index + 1,
      name: item.name || 'Unknown',
      quantity: item.quantity || 0
    }));

    // Fetch in-house orders analytics (startMonth and endMonth already declared above)
    const [inHouseResult] = await tablesCollection.aggregate([
      {
        $facet: {
          todayOrders: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $count: 'count' }
          ],
          monthOrders: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $count: 'count' }
          ],
          todayRevenue: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          monthRevenue: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          todayCash: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'cash'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          monthCash: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'cash'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          todayCard: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'card'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          monthCard: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'card'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$billAmount' } } }
          ],
          todayVoided: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                void: true,
                $or: [
                  { voidedAt: { $gte: startToday, $lte: endToday } },
                  { voidedAt: { $exists: false }, createdAt: { $gte: startToday, $lte: endToday } },
                  { voidedAt: null, createdAt: { $gte: startToday, $lte: endToday } }
                ]
              }
            },
            { $count: 'count' }
          ],
          monthVoided: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                void: true,
                $or: [
                  { voidedAt: { $gte: startMonth, $lte: endMonth } },
                  { voidedAt: { $exists: false }, createdAt: { $gte: startMonth, $lte: endMonth } },
                  { voidedAt: null, createdAt: { $gte: startMonth, $lte: endMonth } }
                ]
              }
            },
            { $count: 'count' }
          ],
          todayVoidedByUser: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                void: true,
                $or: [
                  { voidedAt: { $gte: startToday, $lte: endToday } },
                  { voidedAt: { $exists: false }, createdAt: { $gte: startToday, $lte: endToday } },
                  { voidedAt: null, createdAt: { $gte: startToday, $lte: endToday } }
                ]
              }
            },
            { $group: { _id: { $ifNull: ['$voidedBy', 'Unknown'] }, count: { $sum: 1 } } },
            { $sort: { count: -1, _id: 1 } },
            { $limit: 20 }
          ],
          monthVoidedByUser: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                void: true,
                $or: [
                  { voidedAt: { $gte: startMonth, $lte: endMonth } },
                  { voidedAt: { $exists: false }, createdAt: { $gte: startMonth, $lte: endMonth } },
                  { voidedAt: null, createdAt: { $gte: startMonth, $lte: endMonth } }
                ]
              }
            },
            { $group: { _id: { $ifNull: ['$voidedBy', 'Unknown'] }, count: { $sum: 1 } } },
            { $sort: { count: -1, _id: 1 } },
            { $limit: 50 }
          ],
          todayTips: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          monthTips: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          todayCashTips: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'cash'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          monthCashTips: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'cash'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          todayCardTips: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'card'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          monthCardTips: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] },
                $expr: {
                  $eq: [
                    { $toLower: { $ifNull: ['$paymentMethod', ''] } },
                    'card'
                  ]
                }
              }
            },
            { $group: { _id: null, total: { $sum: '$tip' } } }
          ],
          topInHouseItems: [
            {
              $match: {
                $and: [
                  {
                    $or: [
                      { type: 'inhouse' },
                      { type: { $exists: false } },
                      { type: null }
                    ]
                  },
                  {
                    $or: [
                      { orderType: { $exists: false } },
                      { orderType: null },
                      { orderType: 'inhouse' }
                    ]
                  }
                ],
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $unwind: '$items' },
            { $match: { items: { $ne: null } } },
            {
              $group: {
                _id: '$items.name',
                name: { $first: '$items.name' },
                quantity: { $sum: '$items.quantity' }
              }
            },
            { $sort: { quantity: -1 } },
            { $limit: 3 }
          ],
          todayOnCallTakeaway: [
            {
              $match: {
                orderType: 'oncall',
                deliveryType: 'takeaway',
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $count: 'count' }
          ],
          monthOnCallTakeaway: [
            {
              $match: {
                orderType: 'oncall',
                deliveryType: 'takeaway',
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $count: 'count' }
          ],
          todayOnCallDelivery: [
            {
              $match: {
                orderType: 'oncall',
                deliveryType: 'delivery',
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $count: 'count' }
          ],
          monthOnCallDelivery: [
            {
              $match: {
                orderType: 'oncall',
                deliveryType: 'delivery',
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] }
              }
            },
            { $count: 'count' }
          ],
          todayOnCallTakeawayRevenue: [
            {
              $match: {
                orderType: 'oncall',
                deliveryType: 'takeaway',
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] }
              }
            },
            {
              $addFields: {
                revenueValue: { $ifNull: ['$billAmount', '$totalAmount', 0] }
              }
            },
            { $group: { _id: null, total: { $sum: '$revenueValue' } } }
          ],
          monthOnCallTakeawayRevenue: [
            {
              $match: {
                orderType: 'oncall',
                deliveryType: 'takeaway',
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] }
              }
            },
            {
              $addFields: {
                revenueValue: { $ifNull: ['$billAmount', '$totalAmount', 0] }
              }
            },
            { $group: { _id: null, total: { $sum: '$revenueValue' } } }
          ],
          todayOnCallDeliveryRevenue: [
            {
              $match: {
                orderType: 'oncall',
                deliveryType: 'delivery',
                createdAt: { $gte: startToday, $lte: endToday },
                status: { $in: ['billed', 'completed'] }
              }
            },
            {
              $addFields: {
                revenueValue: { $ifNull: ['$billAmount', '$totalAmount', 0] }
              }
            },
            { $group: { _id: null, total: { $sum: '$revenueValue' } } }
          ],
          monthOnCallDeliveryRevenue: [
            {
              $match: {
                orderType: 'oncall',
                deliveryType: 'delivery',
                createdAt: { $gte: startMonth, $lte: endMonth },
                status: { $in: ['billed', 'completed'] }
              }
            },
            {
              $addFields: {
                revenueValue: { $ifNull: ['$billAmount', '$totalAmount', 0] }
              }
            },
            { $group: { _id: null, total: { $sum: '$revenueValue' } } }
          ]
        }
      }
    ]).toArray();

    const topInHouseItems = (inHouseResult?.topInHouseItems || []).map((item, index) => ({
      rank: index + 1,
      name: item.name || 'Unknown',
      quantity: item.quantity || 0
    }));

    res.json({
      success: true,
      data: {
        branch: normalizedBranch,
        counts: {
          total: getCount(result?.total),
          accepted: getCount(result?.accepted),
          rejected: getCount(result?.rejected),
          completed: getCount(result?.completed),
          failed: getCount(result?.failed)
        },
        countsToday: {
          total: getCount(result?.totalToday),
          accepted: getCount(result?.acceptedToday),
          rejected: getCount(result?.rejectedToday),
          completed: getCount(result?.completedToday),
          failed: getCount(result?.failedToday)
        },
        sales: {
          today: getTotal(result?.salesToday),
          yesterday: getTotal(result?.salesYesterday),
          month: getTotal(result?.salesThisMonth),
          lastMonth: getTotal(result?.salesLastMonth)
        },
        topItems,
        dayNight: {
          dayCount: dayNightMap.day || 0,
          nightCount: dayNightMap.night || 0
        },
        inHouse: {
          todayOrders: getCount(inHouseResult?.todayOrders),
          monthOrders: getCount(inHouseResult?.monthOrders),
          todayRevenue: getTotal(inHouseResult?.todayRevenue),
          monthRevenue: getTotal(inHouseResult?.monthRevenue),
          todayCash: getTotal(inHouseResult?.todayCash),
          monthCash: getTotal(inHouseResult?.monthCash),
          todayCard: getTotal(inHouseResult?.todayCard),
          monthCard: getTotal(inHouseResult?.monthCard),
          todayVoided: getCount(inHouseResult?.todayVoided),
          monthVoided: getCount(inHouseResult?.monthVoided),
          todayVoidedByUser: (inHouseResult?.todayVoidedByUser || []).map((row) => ({
            user: row._id || 'Unknown',
            count: row.count || 0
          })),
          monthVoidedByUser: (inHouseResult?.monthVoidedByUser || []).map((row) => ({
            user: row._id || 'Unknown',
            count: row.count || 0
          })),
          todayTips: getTotal(inHouseResult?.todayTips),
          monthTips: getTotal(inHouseResult?.monthTips),
          todayCashTips: getTotal(inHouseResult?.todayCashTips),
          monthCashTips: getTotal(inHouseResult?.monthCashTips),
          todayCardTips: getTotal(inHouseResult?.todayCardTips),
          monthCardTips: getTotal(inHouseResult?.monthCardTips),
          todayOnCallTakeaway: getCount(inHouseResult?.todayOnCallTakeaway),
          monthOnCallTakeaway: getCount(inHouseResult?.monthOnCallTakeaway),
          todayOnCallDelivery: getCount(inHouseResult?.todayOnCallDelivery),
          monthOnCallDelivery: getCount(inHouseResult?.monthOnCallDelivery),
          todayOnCallTakeawayRevenue: getTotal(inHouseResult?.todayOnCallTakeawayRevenue),
          monthOnCallTakeawayRevenue: getTotal(inHouseResult?.monthOnCallTakeawayRevenue),
          todayOnCallDeliveryRevenue: getTotal(inHouseResult?.todayOnCallDeliveryRevenue),
          monthOnCallDeliveryRevenue: getTotal(inHouseResult?.monthOnCallDeliveryRevenue),
          topItems: topInHouseItems
        }
      }
    });
  } catch (error) {
    console.error('Get analytics report error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Health Check
app.get('/api/health', async (req, res) => {
  // Verify actual MongoDB connectivity (not just state)
  const isMongoDBConnected = await verifyMongoDBConnection();
  
  const health = {
    status: isMongoDBConnected ? 'OK' : 'DEGRADED',
    message: isMongoDBConnected ? 'SpiceHut Admin Backend is running' : 'Backend running but MongoDB disconnected',
    timestamp: new Date(),
    uptime: process.uptime(),
    mongodb: mongoConnectionState,
    environment: process.env.NODE_ENV || 'development'
  };
  
  // Return 200 even if degraded so Vercel doesn't mark it as error
  res.status(isMongoDBConnected ? 200 : 200).json(health);
});

// Force refresh stuck incoming orders (emits to WebSocket clients)
// Useful when change streams aren't working (e.g., standalone MongoDB)
app.post('/api/orders/refresh-incoming', verifyToken, async (req, res) => {
  try {
    const { role, branch: adminBranch } = req.admin;
    const requestedBranch = req.query.branch || req.body.branch;

    let branches = [];
    if (role === 'admin') {
      if (requestedBranch) {
        branches = [requestedBranch];
      } else {
        // Admin without branch param: refresh all
        branches = ORDER_LOCATION_INPUTS;
      }
    } else {
      if (!adminBranch) {
        return res.status(403).json({ success: false, message: 'No branch assigned' });
      }
      branches = [adminBranch];
    }

    let totalEmitted = 0;

    for (const location of branches) {
      const normalizedLocation = normalizeBranchName(location);
      let collectionName;
      try {
        collectionName = resolveOrdersCollectionName(normalizedLocation);
      } catch (error) {
        continue;
      }

      const collection = mongoose.connection.db.collection(collectionName);
      
      // Find all incoming orders  
      const incomingOrders = await collection.find({ status: 'incoming' }).sort({ createdAt: -1 }).toArray();
      
      if (incomingOrders.length > 0) {
        incomingOrders.forEach(order => {
          io.to(getOrderRoomName(normalizedLocation)).emit('order:new', order);
        });
        console.log(`🔄 Refreshed ${incomingOrders.length} incoming orders for ${normalizedLocation}`);
        totalEmitted += incomingOrders.length;
      }
    }

    res.json({ 
      success: true, 
      message: `Refreshed ${totalEmitted} incoming orders to connected clients`,
      ordersEmitted: totalEmitted
    });

  } catch (error) {
    console.error('Refresh orders error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// TEST ENDPOINT - Create test order with socket notification (DEVELOPMENT ONLY)
// This endpoint is disabled in production for security
if (process.env.NODE_ENV !== 'production') {
  app.post('/api/test/order', async (req, res) => {
  try {
    const location = req.body.location || 'Comox';
    const normalizedBranch = location.charAt(0).toUpperCase() + location.slice(1).toLowerCase().replace(/\s+/g, '');
    const collectionName = `orders${normalizedBranch}`;
    
    const collection = mongoose.connection.db.collection(collectionName);
    const now = new Date();
    
    const orderDoc = {
      orderId: 'TEST-' + Date.now(),
      orderNumber: '#TEST' + Math.floor(Math.random() * 9999),
      customerName: req.body.customerName || 'Test Customer',
      customerPhone: req.body.customerPhone || '250-555-0000',
      customerEmail: req.body.customerEmail || 'test@example.com',
      status: 'incoming',
      items: req.body.items || [
        { name: 'Butter Chicken', quantity: 2, price: 16.99 },
        { name: 'Garlic Naan', quantity: 3, price: 3.99 }
      ],
      totalAmount: req.body.totalAmount || 45.95,
      orderTotal: req.body.totalAmount || 45.95,
      location: normalizedBranch,
      branch: normalizedBranch,
      type: 'online',
      paymentMethod: 'card',
      specialInstructions: req.body.specialInstructions || 'Test order',
      createdAt: now,
      updatedAt: now,
      autoRejectAt: new Date(now.getTime() + 15 * 60 * 1000)
    };
    
    const result = await collection.insertOne(orderDoc);
    const insertedOrder = { _id: result.insertedId, ...orderDoc };
    
    // Emit socket event to trigger notification - use same room name as main order creation
    const roomName = getOrderRoomName(normalizedBranch);
    io.to(roomName).emit('order:new', insertedOrder);
    console.log('📢 Test order created and socket event emitted to room:', roomName);
    
    res.json({ success: true, data: insertedOrder, room: roomName });
  } catch (error) {
    console.error('Test order error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
  });
} else {
  // Return 404 for test endpoint in production
  app.post('/api/test/order', (req, res) => {
    res.status(404).json({ 
      success: false, 
      message: 'Test endpoint is disabled in production' 
    });
  });
}

const AUTO_REJECT_WINDOW_MS = 15 * 60 * 1000;
const AUTO_REJECT_INTERVAL_MS = 60 * 1000;

const startAutoRejectWorker = () => {
  setInterval(async () => {
    if (mongoose.connection.readyState !== 1) return;
    const now = new Date();

    for (const location of ORDER_LOCATION_INPUTS) {
      const normalizedLocation = normalizeBranchName(location);
      let collectionName;
      try {
        collectionName = resolveOrdersCollectionName(normalizedLocation);
      } catch (error) {
        continue;
      }

      const collection = mongoose.connection.db.collection(collectionName);
      const expiredOrders = await collection.find({
        status: 'incoming',
        $or: [
          { autoRejectAt: { $lte: now } },
          { autoRejectAt: { $exists: false }, createdAt: { $lte: new Date(now.getTime() - AUTO_REJECT_WINDOW_MS) } }
        ]
      }).toArray();

      if (expiredOrders.length === 0) continue;

      const expiredIds = expiredOrders.map(order => order._id);
      await collection.updateMany(
        { _id: { $in: expiredIds }, status: 'incoming' },
        {
          $set: {
            status: 'rejected',
            updatedAt: now,
            rejectedAt: now,
            rejectionReason: 'Auto-rejected after 15 minutes'
          }
        }
      );

      expiredOrders.forEach((order) => {
        const updatedOrder = {
          ...order,
          status: 'rejected',
          updatedAt: now,
          rejectedAt: now,
          rejectionReason: 'Auto-rejected after 15 minutes'
        };
        io.to(getOrderRoomName(normalizedLocation)).emit('order:updated', updatedOrder);
      });
    }
  }, AUTO_REJECT_INTERVAL_MS);
};

// Start Server
const server = httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🚀 SpiceHut Admin Backend running on http://localhost:${PORT}`);
  console.log(`📊 MongoDB: ${process.env.MONGO_URI?.split('@')[1] || 'Connecting...'}`);
  console.log(`🔐 JWT Authentication: Enabled`);
  console.log(`📡 Environment: ${process.env.NODE_ENV || 'development'}\n`);
});

// Server error handling
server.on('error', (err) => {
  console.error('❌ Server startup error:', err);
  process.exit(1);
});

startAutoRejectWorker();

// MongoDB Change Streams - Watch for new orders inserted directly into DB
const startOrderChangeStreams = () => {
  if (mongoose.connection.readyState !== 1) {
    console.log('⚠️  MongoDB not connected, retrying change streams in 5s...');
    setTimeout(startOrderChangeStreams, 5000);
    return;
  }

  for (const location of ORDER_LOCATION_INPUTS) {
    const normalizedLocation = normalizeBranchName(location);
    let collectionName;
    try {
      collectionName = resolveOrdersCollectionName(normalizedLocation);
    } catch (error) {
      continue;
    }

    const collection = mongoose.connection.db.collection(collectionName);
    
    // Watch for INSERT operations only
    const changeStream = collection.watch([
      { $match: { operationType: 'insert' } }
    ]);

    changeStream.on('change', (change) => {
      if (change.operationType === 'insert') {
        const newOrder = change.fullDocument;
        
        // Only emit for incoming orders
        if (newOrder.status === 'incoming') {
          io.to(getOrderRoomName(normalizedLocation)).emit('order:new', newOrder);
          console.log(`📢 Change stream detected new order in ${collectionName}, emitted to room: ${getOrderRoomName(normalizedLocation)}`);
        }
      }
    });

    changeStream.on('error', (error) => {
      console.error(`❌ Change stream error for ${collectionName}:`, error.message);
      if (error.message.includes('Replica set')) {
        console.warn(`⚠️  IMPORTANT: MongoDB change streams require a Replica Set. Currently using standalone database.`);
        console.warn(`   Some orders inserted directly into DB may not trigger real-time notifications.`);
        console.warn(`   APP WILL STILL WORK: Orders will appear when clients poll (every 15 seconds).`);
      }
    });

    console.log(`👁️  Watching ${collectionName} for new orders...`);
  }
};

// Start change streams after MongoDB connects
// Initialize both void codes and change streams when MongoDB connects
mongoose.connection.once('open', () => {
  console.log('✅ MongoDB Connected - Initializing services...');
  initializeVoidCodes();
  startOrderChangeStreams();
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('\n📴 SIGTERM received. Shutting down gracefully...');
  server.close(() => {
    console.log('✅ HTTP server closed');
    mongoose.connection.close(false, () => {
      console.log('✅ MongoDB connection closed');
      console.log('👋 Goodbye!');
      process.exit(0);
    });
  });
  
  // Force shutdown after 10 seconds
  setTimeout(() => {
    console.error('⚠️  Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
});

process.on('SIGINT', () => {
  console.log('\n📴 SIGINT received. Shutting down gracefully...');
  server.close(() => {
    console.log('✅ HTTP server closed');
    mongoose.connection.close(false, () => {
      console.log('✅ MongoDB connection closed');
      console.log('👋 Goodbye!');
      process.exit(0);
    });
  });
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('🚨 Unhandled Rejection at:', promise);
  console.error('🚨 Reason:', reason);
  // In production, you might want to log this to an error tracking service
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('🚨 Uncaught Exception:', error);
  // Gracefully shutdown
  server.close(() => {
    process.exit(1);
  });
});

// Log Socket.io diagnostics
console.log('\n✅ Socket.io Setup Summary:');
console.log('   ├─ Transport: HTTP Long Polling (Vercel compatible)');
console.log('   ├─ WebSocket: DISABLED (not compatible with serverless)');
console.log('   ├─ Poll Interval: 10 seconds');
console.log('   ├─ Max Message Size: 1MB');
console.log('   ├─ Connection Timeout: 60 seconds');
console.log('   └─ CORS: Restricted to known origins\n');

// Prevent process exit on server errors
server.on('error', (err) => {
  console.error('❌ Server error:', err);
});
