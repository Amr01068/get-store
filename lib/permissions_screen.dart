import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isRequesting = false;

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);

    try {
      await [
        Permission.storage,
        Permission.notification,
        Permission.requestInstallPackages,
      ].request();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }

    // Save that we have seen the permissions screen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_permissions', true);

    if (!mounted) return;
    
    // Navigate to MainScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon or illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.security_rounded,
                  size: 60,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 40),
              
              // Title
              const Text(
                'نحتاج لبعض الصلاحيات',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Subtitle
              const Text(
                'لتقديم أفضل تجربة وتحميل وتثبيت التطبيقات والألعاب بأمان، يحتاج متجر GET STORE للصلاحيات التالية:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Permissions List
              _buildPermissionItem(
                icon: Icons.folder_open_rounded,
                title: 'صلاحية التخزين',
                description: 'مطلوبة لتحميل وحفظ ملفات التطبيقات (APK) على جهازك.',
              ),
              const SizedBox(height: 20),
              _buildPermissionItem(
                icon: Icons.system_update_alt_rounded,
                title: 'صلاحية التثبيت',
                description: 'مطلوبة للسماح للمتجر بتثبيت التطبيقات بعد اكتمال التحميل.',
              ),
              
              const Spacer(),
              
              // Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: _isRequesting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'منح الصلاحيات والمتابعة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.teal, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
