import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class PromoPopupService {
  // Replace this with the raw URL to your promo.json file on GitHub or a Gist
  static const String _promoUrl = 'https://raw.githubusercontent.com/TharushaAkash/ScheduleMate/main/promo.json';

  /// Check and show the popup if a new one is available
  static Future<void> checkAndShowPopup(BuildContext context, {Function(int)? onNavigate}) async {
    try {
      final response = await http.get(Uri.parse(_promoUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // If the popup is disabled in the config, don't show it
        if (data['isActive'] != true) return;

        final String popupId = data['id'] ?? 'unknown';
        
        final prefs = await SharedPreferences.getInstance();
        final bool hasSeen = prefs.getBool('popup_seen_$popupId') ?? false;

        if (!hasSeen) {
          // If we haven't seen this specific popup, show it
          if (context.mounted) {
            _showPromoDialog(
              context: context, 
              id: popupId, 
              imageUrl: data['imageUrl'] ?? '', 
              title: data['title'] ?? '', 
              body: data['body'] ?? '', 
              actionUrl: data['actionUrl'] ?? '', 
              buttonText: data['buttonText'] ?? 'Explore',
              onNavigate: onNavigate,
            );
          }
        }
      }
    } catch (e) {
      // Quietly fail if offline or json is broken, we don't want to disrupt the user
      debugPrint('Error fetching promo popup: $e');
    }
  }

  static void _showPromoDialog({
    required BuildContext context,
    required String id,
    required String imageUrl,
    required String title,
    required String body,
    required String actionUrl,
    required String buttonText,
    Function(int)? onNavigate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF1E1E2C) 
                  : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Image Section
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(height: 220, child: Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              _markAsSeen(id);
                              Navigator.of(ctx).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Content Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            _markAsSeen(id);
                            Navigator.of(ctx).pop();
                            
                            if (actionUrl.startsWith('tab://')) {
                              // Handle in-app navigation
                              if (onNavigate != null) {
                                final tabIndex = int.tryParse(actionUrl.replaceAll('tab://', ''));
                                if (tabIndex != null) {
                                  onNavigate(tabIndex);
                                }
                              }
                            } else if (actionUrl.isNotEmpty) {
                              // Handle external links
                              final uri = Uri.parse(actionUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC93D3B), // Dialog-like red color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            buttonText,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      // In case they dismiss by tapping outside the barrier
      _markAsSeen(id);
    });
  }

  static Future<void> _markAsSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('popup_seen_$id', true);
  }
}
