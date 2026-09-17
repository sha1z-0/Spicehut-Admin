import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/menu_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/dialog_utils.dart';
import '../utils/external_links.dart';
import 'dashboard_screen.dart';
import 'order_history_screen.dart';
import 'analytics_screen.dart';
import 'in_house_orders_screen.dart';
import 'on_call_orders_screen.dart';
import 'user_management_screen.dart';
import 'incoming_orders_screen.dart';
import 'sign_in_screen.dart';
import '../widgets/printer_setup_guide_modal.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  List<MenuItem> _items = [];
  bool _isLoading = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final role = await AuthService().getUserRole();
    setState(() {
      _isAdmin = role == UserRole.admin;
    });

    if (!_isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: Admins only')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
      return;
    }

    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.get('/menu');
      final list = data is Map && data['data'] is List
          ? data['data'] as List
          : (data is List ? data : []);

      setState(() {
        _items = list
            .map((json) => MenuItem(
                  id: json['_id'],
                  name: json['name'],
                  description: json['description'] ?? '',
                  price: (json['price'] as num).toDouble(),
                  category: json['category'],
                  imageUrl: json['imageUrl'] ?? '',
                ))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading menu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showItemDialog({MenuItem? item}) {
    final nameController = TextEditingController(text: item?.name);
    final descController = TextEditingController(text: item?.description);
    final priceController = TextEditingController(text: item?.price.toString());
    final categoryController =
        TextEditingController(text: item?.category ?? 'Main');
    File? selectedImage;
    bool isAlcoholItem = item?.isAlcohol ?? false;

    DialogUtils.showAnimatedDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Add Menu Item' : 'Edit Menu Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description')),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category')),
                const SizedBox(height: 10),
                CheckboxListTile(
                  title: const Text('Alcohol Item (PST applies)'),
                  subtitle: const Text('Check this for beer, wine, or spirits'),
                  value: isAlcoholItem,
                  onChanged: (val) {
                    setDialogState(() {
                      isAlcoholItem = val ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: const Color(0xFFFF7A00),
                ),
                const SizedBox(height: 10),
                // Image picker
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      setDialogState(() {
                        selectedImage = File(pickedFile.path);
                      });
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(selectedImage!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo,
                                  color: Colors.grey, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to select image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newDesc = descController.text.trim();
                final newPrice = double.tryParse(priceController.text) ?? 0.0;
                final newCat = categoryController.text.trim();

                if (newName.isNotEmpty && newPrice > 0) {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    // In mock mode, we just store the image path; in real mode, upload to backend
                    final imageUrl = selectedImage != null ? selectedImage!.path : (item?.imageUrl ?? '');
                    
                    if (item == null) {
                      await ApiService.post('/menu', {
                        'name': newName,
                        'description': newDesc,
                        'price': newPrice,
                        'category': newCat,
                        'imageUrl': imageUrl,
                        'isAlcohol': isAlcoholItem,
                      });
                    } else {
                      await ApiService.put('/menu/${item.id}', {
                        'name': newName,
                        'description': newDesc,
                        'price': newPrice,
                        'category': newCat,
                        'imageUrl': imageUrl,
                        'isAlcohol': isAlcoholItem,
                      });
                    }
                    if (mounted) navigator.pop();
                    _loadItems();
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                          SnackBar(content: Text('Error saving: $e')));
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteItem(String id) {
    DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Delete Item?',
      message: 'Are you sure you want to delete this menu item?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await ApiService.delete('/menu/$id');
          _loadItems();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting: $e')),
            );
          }
        }
      }
    });
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
          'Menu Management',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      drawer: Drawer(
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
                    Navigator.push(
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
                _buildMenuItem(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
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
                    Navigator.push(
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
                // Menu Management
                _buildMenuItem(
                  icon: Icons.restaurant_menu,
                  label: 'Menu Management',
                  isSelected: true,
                  onTap: () {},
                ),
                // User Management
                _buildMenuItem(
                  icon: Icons.people,
                  label: 'User Management',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserManagementScreen(),
                      ),
                    );
                  },
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
      ),
      floatingActionButton: _isAdmin ? FloatingActionButton(
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add),
      ) : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_items.isEmpty
              ? const Center(child: Text('No items or loading...'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          color: Colors.orange[100],
                          child:
                              const Icon(Icons.fastfood, color: Colors.orange),
                        ),
                        title: Text(item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.category} • \$${item.price.toStringAsFixed(2)}'),
                            if (item.isAlcohol)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[100],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.amber),
                                  ),
                                  child: const Text('🍺 Alcohol (PST applies)', style: TextStyle(fontSize: 10, color: Colors.brown)),
                                ),
                              ),
                          ],
                        ),
                        trailing: _isAdmin ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showItemDialog(item: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(item.id),
                            ),
                          ],
                        ) : null,
                      ),
                    );
                  },
                )),
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
}
