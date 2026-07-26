import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _githubUser = 'TharushaAkash';
  static const String _githubRepo = 'ScheduleMate';
  static const String _apiUrl = 'https://api.github.com/repos/$_githubUser/$_githubRepo/releases/latest';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String latestVersionTag = data['tag_name']; // e.g., 'v1.0.1' or '1.0.1'
        
        // Remove 'v' prefix if it exists to compare versions properly
        final latestVersion = latestVersionTag.replaceAll('v', '');
        
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewVersionAvailable(currentVersion, latestVersion)) {
          final String releaseTitle = data['name'] ?? 'New version available';
          final String downloadUrl = 'https://sourceforge.net/projects/schedulemate/files/v$latestVersion/ScheduleMate_v$latestVersion.apk/download';
          
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, releaseTitle, downloadUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  static bool _isNewVersionAvailable(String current, String latest) {
    try {
      final List<int> currentParts = current.split('.').map(int.parse).toList();
      final List<int> latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < currentParts.length && i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (e) {
      // If parsing fails, just do a string comparison
      return latest.compareTo(current) > 0;
    }
  }

  static void _showUpdateDialog(BuildContext context, String latestVersion, String releaseTitle, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('✨ New Update Available!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version ($latestVersion) of ScheduleMate is available!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '🚀 $releaseTitle',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Would you like to download it now?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse(downloadUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}
