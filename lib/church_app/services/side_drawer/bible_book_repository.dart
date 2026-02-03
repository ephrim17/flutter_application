import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/models/bible_book_model.dart';

class BibleRepository {
  Future<Map<String, dynamic>> loadBook(String bookKey) async {
    final path = 'assets/bible/$bookKey.json';
    //debugPrint('📖 Loading: $path');

    final raw = await rootBundle.loadString(path);
    //debugPrint('✅ Loaded ${raw.length} chars');

    final Map<String, dynamic> jsonMap = json.decode(raw);
    return jsonMap;
  }
}

final bibleBooks = [
  BibleBook(key: 'Genesis', name: 'ஆதியாகமம்'),
  BibleBook(key: 'exodus', name: 'யாத்திராகமம்'),
  BibleBook(key: 'leviticus', name: 'லேவியராகமம்'),
  BibleBook(key: 'Numbers', name: 'எண்ணாகமம்'),
  BibleBook(key: 'deuteronomy', name: 'உபாகமம்'),
  // add rest slowly
];
