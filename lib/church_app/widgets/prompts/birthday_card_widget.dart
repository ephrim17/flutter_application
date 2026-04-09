import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/bible_swipe_verse_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
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
      final pngBytes = await captureBoundaryPng(_globalKey);

      if (pngBytes == null) {
        throw Exception('Unable to capture birthday card image');
      }

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
    final swipeVersesAsync = ref.watch(swipeVersesProvider);
    final user = ref.watch(getCurrentUserProvider).value;
    final width = MediaQuery.of(context).size.width;

    return swipeVersesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(e.toString()),
      data: (verses) {
        final verse =
            verses.isEmpty ? null : verses[Random().nextInt(verses.length)];

        if (verse == null) {
          return Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                context.t(
                  'birthday.card_no_verse',
                  fallback: 'No verse available right now.',
                ),
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '🎉🎂🎁',
                      style: TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.t(
                        'birthday.card_title',
                        fallback: 'BIRTHDAY WISHES',
                      ),
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineLarge!.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                    LightningGradientText(
                      text: user?.name.toUpperCase() ?? "DEAR FRIEND",
                      style:
                          Theme.of(context).textTheme.headlineMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                                letterSpacing: 1.5,
                              ),
                    ),
                    const SizedBox(height: 10),
                    RepaintBoundary(
                      key: _globalKey,
                      child: SizedBox(
                        width: width - 32,
                        child: BirthdayBlessingCard(
                          userName: user?.name ?? 'Dear Friend',
                          verse: verse,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                        child: Text(
                          context.t(
                            'birthday.save_image',
                            fallback: 'Save as Image',
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class BirthdayBlessingCard extends StatelessWidget {
  const BirthdayBlessingCard({
    super.key,
    required this.userName,
    required this.verse,
    this.backgroundImageBytes,
  });

  final String userName;
  final Map<String, String> verse;
  final Uint8List? backgroundImageBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: backgroundImageBytes == null
            ? null
            : DecorationImage(
                image: MemoryImage(backgroundImageBytes!),
                fit: BoxFit.cover,
              ),
        gradient: backgroundImageBytes == null
            ? const LinearGradient(
                colors: [
                  Color(0xFFFF758C),
                  Color(0xFFFF7EB3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1FB54A7A),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backgroundImageBytes == null
                ? [
                    Colors.transparent,
                    Colors.transparent,
                  ]
                : [
                    const Color(0xCC7A175C),
                    const Color(0xD91B2448),
                  ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Celebrating You",
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Happy Birthday",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              userName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    verse['tamil'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    verse['english'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              verse['reference'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

String buildBirthdayPostTitle(String userName, DateTime? dob) {
  final age = birthdayAge(dob);
  if (age == null) {
    return 'Happy Birthday $userName';
  }
  return 'Happy ${_ordinal(age)} Birthday $userName';
}

int? birthdayAge(DateTime? dob) {
  if (dob == null) return null;
  final now = DateTime.now();
  return now.year - dob.year;
}

String _ordinal(int value) {
  final mod100 = value % 100;
  if (mod100 >= 11 && mod100 <= 13) {
    return '${value}th';
  }

  switch (value % 10) {
    case 1:
      return '${value}st';
    case 2:
      return '${value}nd';
    case 3:
      return '${value}rd';
    default:
      return '${value}th';
  }
}

Future<Uint8List?> captureBoundaryPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 3.0,
}) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
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
