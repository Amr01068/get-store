import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class StorageVaultItem {
  final File file;
  final String fileName;
  final String appName;
  final String? iconUrl;
  final String? developerName;
  final String sizeString;
  final DateTime modifiedTime;

  StorageVaultItem({
    required this.file,
    required this.fileName,
    required this.appName,
    this.iconUrl,
    this.developerName,
    required this.sizeString,
    required this.modifiedTime,
  });
}

class StorageVaultScreen extends StatefulWidget {
  const StorageVaultScreen({super.key});

  @override
  State<StorageVaultScreen> createState() => _StorageVaultScreenState();
}

class _StorageVaultScreenState extends State<StorageVaultScreen> {
  List<StorageVaultItem> _vaultItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVaultItems();
  }

  Future<void> _loadVaultItems() async {
    setState(() => _isLoading = true);
    try {
      final dir = await getTemporaryDirectory();
      final List<FileSystemEntity> entities = dir.listSync();
      final List<StorageVaultItem> items = [];

      for (var entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
          final stat = await entity.stat();
          final sizeInMb = (stat.size / (1024 * 1024)).toStringAsFixed(1);
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final appId = fileName.replaceAll('.apk', '');
          
          String appName = fileName;
          String? iconUrl;
          String? developerName;

          // Check for JSON sidecar file
          final jsonFile = File('${dir.path}/$appId.json');
          if (await jsonFile.exists()) {
            try {
              final jsonStr = await jsonFile.readAsString();
              final Map<String, dynamic> data = jsonDecode(jsonStr);
              if (data['name'] != null && data['name'].toString().isNotEmpty) {
                appName = data['name'];
              }
              if (data['iconUrl'] != null && data['iconUrl'].toString().isNotEmpty) {
                iconUrl = data['iconUrl'];
              }
              if (data['developerName'] != null && data['developerName'].toString().isNotEmpty) {
                developerName = data['developerName'];
              }
            } catch (_) {}
          }

          items.add(StorageVaultItem(
            file: entity,
            fileName: fileName,
            appName: appName,
            iconUrl: iconUrl,
            developerName: developerName,
            sizeString: '$sizeInMb MB',
            modifiedTime: stat.modified,
          ));
        }
      }

      items.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));

      if (mounted) {
        setState(() {
          _vaultItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteItem(StorageVaultItem item) async {
    try {
      if (await item.file.exists()) {
        await item.file.delete();
      }
      final appId = item.fileName.replaceAll('.apk', '');
      final dir = await getTemporaryDirectory();
      final jsonFile = File('${dir.path}/$appId.json');
      if (await jsonFile.exists()) {
        await jsonFile.delete();
      }

      _loadVaultItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الملف من المخزون بنجاح'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('المخزون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _vaultItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, color: Colors.grey[700], size: 80),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد تطبيقات في المخزون حالياً',
                        style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'التطبيقات التي تقوم بتنزيلها ستظهر هنا لتثبيتها أو حذفها في أي وقت.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vaultItems.length,
                  itemBuilder: (context, index) {
                    final item = _vaultItems[index];
                    final bool hasIcon = item.iconUrl != null && item.iconUrl!.startsWith('http');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: hasIcon
                                ? Image.network(
                                    item.iconUrl!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 52,
                                      height: 52,
                                      color: Colors.teal.withOpacity(0.15),
                                      child: const Icon(Icons.android, color: Colors.tealAccent, size: 28),
                                    ),
                                  )
                                : Container(
                                    width: 52,
                                    height: 52,
                                    color: Colors.teal.withOpacity(0.15),
                                    child: const Icon(Icons.android, color: Colors.tealAccent, size: 28),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.developerName != null && item.developerName!.isNotEmpty
                                      ? '${item.developerName} · ${item.sizeString}'
                                      : 'الحجم: ${item.sizeString}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => OpenFilex.open(item.file.path),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF01875F),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: const Text('تثبيت', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                            onPressed: () => _deleteItem(item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
