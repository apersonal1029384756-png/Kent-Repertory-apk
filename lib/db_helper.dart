import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class RemedyGrade {
  final String abbrev;
  final int grade;

  RemedyGrade({required this.abbrev, required this.grade});
}

class RubricResult {
  final int id;
  final String fullPath;
  final int pageNumber;
  final List<RemedyGrade> remedies;

  RubricResult({
    required this.id,
    required this.fullPath,
    required this.pageNumber,
    required this.remedies,
  });
}

class RepertoryEngine {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    Directory docDir = await getApplicationDocumentsDirectory();
    String dbPath = join(docDir.path, "kent_repertory.db");

    if (!await File(dbPath).exists()) {
      ByteData data = await rootBundle.load(urlContext.join('assets', 'kent_repertory.db'));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }
    return await openDatabase(dbPath);
  }

  static final Map<String, String> _builtInSynonyms = {
    'headache': 'pain head',
    'dizziness': 'vertigo',
    'piles': 'hæmorrhoids',
    'runny nose': 'coryza',
    'loose stool': 'diarrhœa',
    'heartburn': 'stomach eructations',
    'vomiting': 'stomach nausea',
  };

  static Future<List<String>> fetchOnlineSynonyms(String word) async {
    try {
      final res = await http
          .get(Uri.parse('https://api.datamuse.com/words?rel_syn=$word'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.take(2).map((e) => e['word'].toString().toLowerCase()).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<String>> tokenizeKeywords(String query) async {
    String clean = query.toLowerCase();
    _builtInSynonyms.forEach((k, v) {
      if (clean.contains(k)) clean = clean.replaceAll(k, v);
    });

    final stopWords = {'in', 'the', 'of', 'and', 'at', 'on', 'with', 'to', 'for', 'from', 'a', 'an'};
    List<String> rawTokens = clean
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !stopWords.contains(w))
        .toList();

    List<String> resolvedKeywords = [];
    for (String token in rawTokens) {
      resolvedKeywords.add(token);
      if (token.length > 4) {
        List<String> onlineSyns = await fetchOnlineSynonyms(token);
        resolvedKeywords.addAll(onlineSyns);
      }
    }
    return resolvedKeywords.toSet().toList();
  }

  static Future<List<RubricResult>> searchSymptom(String rawQuery) async {
    final db = await database;
    List<String> keywords = await tokenizeKeywords(rawQuery);
    if (keywords.isEmpty) return [];

    List<String> whereClauses = [];
    List<String> whereArgs = [];
    for (String token in keywords) {
      whereClauses.add("r.full_path LIKE ?");
      whereArgs.add("%$token%");
    }

    String sql = '''
      SELECT 
        r.id as rubric_id, 
        r.full_path, 
        r.page_number,
        rem.abbreviation,
        rr.grade
      FROM rubrics r
      LEFT JOIN rubric_remedies rr ON r.id = rr.rubric_id
      LEFT JOIN remedies rem ON rr.remedy_id = rem.id
      WHERE ${whereClauses.join(" AND ")}
      ORDER BY r.page_number ASC, r.id ASC
      LIMIT 120
    ''';

    List<Map<String, dynamic>> rows = await db.rawQuery(sql, whereArgs);

    Map<int, RubricResult> mappedResults = {};
    for (var row in rows) {
      int id = row['rubric_id'];
      if (!mappedResults.containsKey(id)) {
        mappedResults[id] = RubricResult(
          id: id,
          fullPath: row['full_path'] ?? '',
          pageNumber: row['page_number'] ?? 0,
          remedies: [],
        );
      }
      if (row['abbreviation'] != null) {
        mappedResults[id]!.remedies.add(RemedyGrade(
          abbrev: row['abbreviation'],
          grade: row['grade'] ?? 1,
        ));
      }
    }
    return mappedResults.values.toList();
  }
}
