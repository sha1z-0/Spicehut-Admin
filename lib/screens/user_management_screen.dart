import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../utils/dialog_utils.dart';
import '../utils/external_links.dart';
import 'dashboard_screen.dart';
import 'sign_in_screen.dart';
import 'incoming_orders_screen.dart';
import 'order_history_screen.dart';
import 'analytics_screen.dart';
import 'in_house_orders_screen.dart';
import 'on_call_orders_screen.dart';
import 'menu_management_screen.dart';
import '../widgets/printer_setup_guide_modal.dart';

// User Model
class AdminUser {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin', 'manager', 'staff'
  final String? staffRole; // 'waiter', 'cashier', 'kitchen', 'delivery' (for staff only)
  final String? branch;
  final List<String> branches;
  final bool isActive;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.staffRole,
    this.branch,
    required this.branches,
    required this.isActive,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'staff',
      staffRole: json['staffRole'],
      branch: json['branch'],
      branches: json['branches'] is List ? List<String>.from(json['branches']) : [],
      isActive: json['isActive'] ?? true,
    );
  }
}

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<AdminUser> _users = [];
  bool _isLoading = false;
  String? _selectedBranch;
  List<String> _availableBranches = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final authService = AuthService();
    final role = await authService.getUserRole();

    setState(() {
      _isAdmin = role == UserRole.admin;
    });

    if (!_isAdmin) {
      // Non-admins should not be here, but navigate away just in case
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
      return;
    }

    await _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final data = await ApiService.get('/branches');
      if (data is Map && data.containsKey('data')) {
        final branches = data['data'] as List;
        setState(() {
          _availableBranches = branches.map((b) => b.toString()).toList();
          _selectedBranch =
              _selectedBranch ?? (_availableBranches.isNotEmpty ? _availableBranches.first : null);
        });
        if (_selectedBranch != null) {
          _loadUsers();
        }
      }
    } catch (e) {
      LoggerService.error('Error loading branches', e, null, 'UserManagement');
    }
  }

  Future<void> _loadUsers() async {
    if (_selectedBranch == null) return;

    setState(() => _isLoading = true);
    try {
      final encodedBranch = Uri.encodeComponent(_selectedBranch!);
      final data = await ApiService.get('/users?branch=$encodedBranch');
      List<AdminUser> usersList = [];

      if (data is List) {
        usersList = data.map((json) => AdminUser.fromJson(json)).toList();
      } else if (data is Map && data['data'] is List) {
        usersList = (data['data'] as List).map((json) => AdminUser.fromJson(json)).toList();
      }

      setState(() {
        _users = usersList;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'manager';
    String selectedStaffRole = 'waiter';
    bool obscurePassword = true;

    DialogUtils.showAnimatedDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter user full name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                // Email
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'user@spicehut.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                // Password
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter secure password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setDialogState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Role Selection
                Text(
                  'Role',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedRole,
                    isExpanded: true,
                    underline: const SizedBox(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRole = value ?? 'manager';
                      });
                    },
                    items: const [
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Staff Role (shown only if role = staff)
                if (selectedRole == 'staff') ...[
                  Text(
                    'Staff Role',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedStaffRole,
                      isExpanded: true,
                      underline: const SizedBox(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedStaffRole = value ?? 'waiter';
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
                        DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                        DropdownMenuItem(value: 'kitchen', child: Text('Kitchen Staff')),
                        DropdownMenuItem(value: 'delivery', child: Text('Delivery Staff')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Branch Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Branch: $_selectedBranch',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                if (name.isEmpty || email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields.'),
                    ),
                  );
                  return;
                }

                if (!email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid email address.'),
                    ),
                  );
                  return;
                }

                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters long.'),
                    ),
                  );
                  return;
                }

                try {
                  final payload = {
                    'name': name,
                    'email': email,
                    'password': password,
                    'role': selectedRole,
                    if (selectedRole == 'staff') 'staffRole': selectedStaffRole,
                    'branch': _selectedBranch,
                    'branches': [_selectedBranch],
                    'isActive': true,
                  };

                  await ApiService.post('/users', payload);

                  if (!context.mounted) return;

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User created successfully'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                  _loadUsers();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating user: $e')),
                  );
                }
              },
              child: const Text(
                'Create User',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(AdminUser user) {
    final nameController = TextEditingController(text: user.name);
    String selectedRole = user.role;

    DialogUtils.showAnimatedDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                // Email (read-only)
                Text(
                  'Email',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Role (read-only for safety)
                Text(
                  'Role',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    selectedRole == 'manager' ? 'Manager' : 'Staff',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Role cannot be changed after creation',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: user.isActive ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: user.isActive ? Colors.green[200]! : Colors.red[200]!,
                    ),
                  ),
                  child: Text(
                    user.isActive ? 'User is Active' : 'User is Disabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: user.isActive ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
              ),
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Full name is required')),
                  );
                  return;
                }

                try {
                  final payload = {
                    'name': name,
                  };

                  await ApiService.put('/users/${user.id}', payload);

                  if (!context.mounted) return;

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User updated successfully'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                  _loadUsers();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating user: $e')),
                  );
                }
              },
              child: const Text(
                'Save Changes',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteUser(AdminUser user) {
    DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Delete User?',
      message: 'This will permanently delete "${user.name}".\n\nThis action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ApiService.delete('/admin-users/${user.id}');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User deleted'),
                backgroundColor: Color(0xFF4CAF50),
              ),
            );
            _loadUsers();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting user: $e')),
            );
          }
        }
      }
    });
  }

  Widget _buildRoleBadge(String role, {String? staffRole}) {
    Color bgColor;
    Color textColor;
    String label;

    switch (role) {
      case 'admin':
        bgColor = const Color(0xFFFF7A00).withValues(alpha: 0.2);
        textColor = const Color(0xFFFF7A00);
        label = 'Admin';
        break;
      case 'manager':
        bgColor = const Color(0xFF2196F3).withValues(alpha: 0.2);
        textColor = const Color(0xFF2196F3);
        label = 'Manager';
        break;
      case 'staff':
        bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.2);
        textColor = const Color(0xFF4CAF50);
        label = 'Staff${staffRole != null ? ' - ${_capitalizeFirst(staffRole)}' : ''}';
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey[700]!;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _capitalizeFirst(String s) => s[0].toUpperCase() + s.substring(1);

  Widget _buildUserCard(AdminUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isActive ? Colors.grey[200]! : Colors.red[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: user.role == 'admin'
                      ? const Color(0xFFFF7A00)
                      : user.role == 'manager'
                          ? const Color(0xFF2196F3)
                          : const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    user.role == 'admin'
                        ? Icons.admin_panel_settings
                        : user.role == 'manager'
                            ? Icons.manage_accounts
                            : Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _buildRoleBadge(user.role, staffRole: user.staffRole),
                  ],
                ),
              ),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isActive ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: user.isActive ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Branch info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    user.branches.isNotEmpty ? user.branches.join(', ') : 'No branches',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showEditUserDialog(user),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7A00),
                ),
              ),
              const SizedBox(width: 8),
              if (_isAdmin)
                TextButton.icon(
                  onPressed: () => _confirmDeleteUser(user),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFF5F5F5),
      child: SafeArea(
        child: Container(
          color: const Color(0xFFF5F5F5),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Logo
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/logo/spicehut_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFFF7A00),
                              child: const Icon(
                                Icons.restaurant,
                                color: Colors.white,
                                size: 20,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'SpiceHut',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7A00),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Dashboard
              if (_isAdmin)
                _buildMenuItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
              // Orders Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Online Orders',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A00),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.shopping_bag_outlined,
                label: 'Incoming',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const IncomingOrdersScreen(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                icon: Icons.history,
                label: 'Order History',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderHistoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Analytics Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A00),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_isAdmin)
                _buildMenuItem(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AnalyticsScreen(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
              // Restaurant Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Restaurant Orders',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7A00),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.table_bar,
                label: 'In-House Tables',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InHouseOrdersScreen(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                icon: Icons.phone_in_talk,
                label: 'On Call Orders',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OnCallOrdersScreen(),
                    ),
                  );
                },
              ),
              if (_isAdmin)
                _buildMenuItem(
                  icon: Icons.restaurant_menu,
                  label: 'Menu Management',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MenuManagementScreen(),
                      ),
                    );
                  },
                ),
              // User Management (Admin Only)
              _buildMenuItem(
                icon: Icons.people,
                label: 'User Management',
                isSelected: true,
                onTap: () {},
              ),
              // Printer Setup Guide
              _buildMenuItem(
                icon: Icons.print,
                label: 'Printer Setup',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  DialogUtils.showAnimatedDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => const PrinterSetupGuideModal(),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Log Out
              _buildMenuItem(
                icon: Icons.logout,
                label: 'Log Out',
                isSelected: false,
                textColor: const Color(0xFFFF7A00),
                iconColor: const Color(0xFFFF7A00),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignInScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
              _buildMenuItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                isSelected: false,
                textColor: Colors.grey[600],
                iconColor: Colors.grey[600],
                onTap: () {
                  Navigator.pop(context);
                  ExternalLinks.openPrivacyPolicy();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    Color? textColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFE5D3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? (isSelected ? const Color(0xFFFF7A00) : Colors.grey[600]),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: textColor ?? (isSelected ? const Color(0xFFFF7A00) : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'User Management',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      drawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserDialog,
        backgroundColor: const Color(0xFFFF7A00),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF7A00),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch Selector
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Branch',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedBranch,
                            isExpanded: true,
                            underline: const SizedBox(),
                            onChanged: (String? newBranch) {
                              if (newBranch != null && newBranch != _selectedBranch) {
                                setState(() {
                                  _selectedBranch = newBranch;
                                });
                                _loadUsers();
                              }
                            },
                            items: _availableBranches
                                .map<DropdownMenuItem<String>>((String branch) {
                              return DropdownMenuItem<String>(
                                value: branch,
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16),
                                    const SizedBox(width: 8),
                                    Text(branch),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Users List Header
                  if (_users.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        'Team Members (${_users.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  // Users List
                  if (_users.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No users in this branch',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to create the first user',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _users.map((user) => _buildUserCard(user)).toList(),
                    ),
                ],
              ),
            ),
    );
  }
}
