import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/permissions_service.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onPermissionsRequested;

  const PermissionsScreen({
    super.key,
    required this.onPermissionsRequested,
  });

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _requestingPermissions = false;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (_requestingPermissions) return;

    setState(() {
      _requestingPermissions = true;
    });

    try {
      final statuses = await PermissionsService.requestAllPermissions();

      final deniedPermissions = statuses.entries
          .where((entry) =>
            entry.value != PermissionStatus.granted &&
            entry.value != PermissionStatus.limited)
          .map((entry) => _permissionLabel(entry.key))
          .toSet()
          .toList();

      if (mounted && deniedPermissions.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Some permissions were denied: ${deniedPermissions.join(', ')}. You can allow them later in Settings.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      if (mounted) {
        widget.onPermissionsRequested();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting permissions: $e')),
        );
        setState(() {
          _requestingPermissions = false;
        });
      }
    }
  }

  String _permissionLabel(dynamic permission) {
    final key = permission.toString();
    if (key.contains('camera')) return 'Camera';
    if (key.contains('photos')) return 'Photos';
    if (key.contains('storage')) return 'Storage';
    return key.split('.').last;
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF7A00),
              Color(0xFFFF9D42),
              Color(0xFFFFA726),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Premium Card Container
                      Container(
                        constraints: const BoxConstraints(maxWidth: 450),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Permission icon with background
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          const Color(0xFFFF7A00).withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.security_rounded,
                                  color: Color(0xFFFF7A00),
                                  size: 64,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Title
                              const Text(
                                'Permissions Required',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: 0.3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),

                              // Description
                              Text(
                                'SpiceHut Admin requests the permissions below to enable core features. After you tap Continue, iOS will show native permission prompts one by one.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                  height: 1.6,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),

                              // Permission list
                              _buildPermissionItem(
                                icon: Icons.camera_alt_rounded,
                                title: 'Camera',
                                description:
                                    'Capture menu and order-related photos',
                              ),
                              const SizedBox(height: 16),
                              _buildPermissionItem(
                                icon: Icons.photo_library_rounded,
                                title: defaultTargetPlatform == TargetPlatform.iOS ? 'Photos' : 'Storage',
                                description: defaultTargetPlatform == TargetPlatform.iOS
                                    ? 'Select and manage images from your photo library'
                                    : 'Access and save files/images used in the app',
                              ),
                              const SizedBox(height: 16),
                              _buildPermissionItem(
                                icon: Icons.wifi,
                                title: 'Local Network',
                                description:
                                    'Required to send print jobs to LAN/Wi-Fi thermal printers',
                              ),
                              const SizedBox(height: 32),

                              // Divider
                              Divider(color: Colors.grey[300]),
                              const SizedBox(height: 24),

                              // Buttons
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _requestingPermissions
                                      ? null
                                      : _requestPermissions,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF7A00),
                                          Color(0xFFFFA726),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF7A00)
                                              .withValues(alpha: 0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: _requestingPermissions
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                                strokeWidth: 3,
                                              ),
                                            )
                                            : const Row(
                                              mainAxisAlignment:
                                                MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_rounded,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                                SizedBox(width: 10),
                                                Text(
                                                  'Continue',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A00).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF7A00).withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7A00).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF7A00),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
