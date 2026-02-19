import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/daily_verse_providers.dart';
import 'package:flutter_application/church_app/widgets/gradient_title_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BirthDayCard extends ConsumerStatefulWidget {
  const BirthDayCard({super.key});

  @override
  ConsumerState<BirthDayCard> createState() => _BirthDayCardState();
}

class _BirthDayCardState extends ConsumerState<BirthDayCard> {
  final GlobalKey _globalKey = GlobalKey();

  Future<void> _saveAsImage() async {
    try {
      // ✅ Capture parent scaffold context BEFORE pop
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // 📸 Capture image
      final boundary = _globalKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      final pngBytes = byteData!.buffer.asUint8List();

      await Gal.putImageBytes(pngBytes);

      if (!mounted) return;

      // ✅ Close modal
      Navigator.of(context).pop();

      // ✅ Show snackbar using captured messenger
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Saved to gallery 🎉"),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyVerseAsync = ref.watch(dailyVerseProviderLocal);
    final user = ref.watch(getCurrentUserProvider).value;
    final width = MediaQuery.of(context).size.width;

    return dailyVerseAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(e.toString()),
      data: (verse) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // 🎈 Drag handle
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 24),

              // 🎂 Emoji / Icon
              const Text(
                '🎉🎂🎁',
                style: TextStyle(fontSize: 48),
              ),

              const SizedBox(height: 16),

              // 🎁 Title
              Text('BIRTHDAY WISHES',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),

              LightningGradientText(
                  text: user?.name.toUpperCase() ?? "DEAR FRIEND",
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                        letterSpacing: 1.5,
                      )),

              const SizedBox(
                height: 10,
              ),

              Column(
                children: [
                  RepaintBoundary(
                    key: _globalKey,
                    child: Container(
                      width: width - 32,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF758C),
                            Color(0xFFFF7EB3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink,
                            blurRadius: 5,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          /// 🎉 Header
                          const Text(
                            "🎉 Happy Birthday 🎂",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 20),

                          /// Tamil Verse
                          Text(
                            verse['tamil'] ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 14),

                          /// English Verse
                          Text(
                            verse['english'] ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 20),

                          /// Reference
                          Text(
                            verse['reference'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// Save Button
                  SizedBox(
                    width: width - 32,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _saveAsImage,
                      child: const Text(
                        "Save as Image",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),

              // /Spacer(),

              const SizedBox(
                height: 10,
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<bool> alreadyShownToday(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now().toIso8601String().substring(0, 10);

  final saved = prefs.getString(key);
  return saved == today;
}

Future<void> markShownToday(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now().toIso8601String().substring(0, 10);

  await prefs.setString(key, today);
}