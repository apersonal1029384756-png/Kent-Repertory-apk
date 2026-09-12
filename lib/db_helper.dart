import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class RemedyGrade {
  final String abbrev;
  final int grade;

  RemedyGrade({required this.abbrev, required this.grade});
}

class RubricResult {
  final int id;
  final String chapter;
  final String fullPath;
  final int pageNumber;
  final List<RemedyGrade> remedies;

  RubricResult({
    required this.id,
    required this.chapter,
    required this.fullPath,
    required this.pageNumber,
    required this.remedies,
  });
}

class RepertorizationResult {
  final int remedyId;
  final String abbreviation;
  final int totalMarks;
  final int rubricsCovered;
  const RepertorizationResult({required this.remedyId, required this.abbreviation, required this.totalMarks, required this.rubricsCovered});
}

class RubricCoverage {
  final int rubricId;
  final String fullPath;
  final int grade;
  const RubricCoverage({required this.rubricId, required this.fullPath, required this.grade});
}

class RepertoryEngine {
  static Database? _db;
  static const _databaseFileName = 'kent_repertory.db';
  static const _bundledDatabaseVersion = 2;
  static const _storedDatabaseVersionKey = 'kent_repertory_database_version';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docDir.path, _databaseFileName);
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getInt(_storedDatabaseVersionKey) ?? 0;
    if (!await File(dbPath).exists()) {
      await _installBundledDatabase(dbPath);
    } else if (installedVersion < _bundledDatabaseVersion &&
        await _shouldRefreshBundledDatabase(dbPath)) {
      await _installBundledDatabase(dbPath);
    }
    await prefs.setInt(_storedDatabaseVersionKey, _bundledDatabaseVersion);
    return openDatabase(dbPath);
  }

  static Future<bool> _shouldRefreshBundledDatabase(String dbPath) async {
    try {
      final existing = File(dbPath);
      final existingDb = await openDatabase(dbPath, readOnly: true);
      final integrity = await existingDb.rawQuery('PRAGMA integrity_check');
      await existingDb.close();
      if (integrity.isEmpty || integrity.first.values.first != 'ok') return true;
      final asset = await rootBundle.load('assets/kent_repertory.db');
      return await existing.length() != asset.lengthInBytes;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _installBundledDatabase(String dbPath) async {
    final destination = File(dbPath);
    final staged = File('$dbPath.staged');
    if (await staged.exists()) await staged.delete();
    final asset = await rootBundle.load('assets/kent_repertory.db');
    await staged.writeAsBytes(asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes), flush: true);
    final stagedDb = await openDatabase(staged.path, readOnly: true);
    final integrity = await stagedDb.rawQuery('PRAGMA integrity_check');
    await stagedDb.close();
    if (integrity.isEmpty || integrity.first.values.first != 'ok') {
      await staged.delete();
      throw StateError('The bundled Kent repertory database failed integrity validation.');
    }
    if (await destination.exists()) await destination.delete();
    await staged.rename(dbPath);
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
      whereClauses.add("(r.full_path LIKE ? OR c.name LIKE ?)");
      whereArgs.add("%$token%");
      whereArgs.add("%$token%");
    }

    String sql = '''
      SELECT 
        r.id as rubric_id, 
        CASE
          WHEN pc.name IS NOT NULL THEN pc.name || ' → ' || c.name
          ELSE c.name
        END AS chapter,
        r.full_path, 
        r.page_number,
        rem.abbreviation,
        rr.grade
      FROM rubrics r
      INNER JOIN chapters c ON c.id = r.chapter_id
      LEFT JOIN chapters pc ON pc.id = c.parent_chapter_id
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
          chapter: row['chapter'] as String? ?? '',
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

  /// Sums only the actual Kent grades stored for the selected rubric IDs.
  static Future<List<RepertorizationResult>> repertorize(List<int> rubricIds) async {
    if (rubricIds.isEmpty) return [];
    final placeholders = List.filled(rubricIds.length, '?').join(', ');
    final rows = await (await database).rawQuery('''
      SELECT rem.id AS remedy_id, rem.abbreviation AS abbreviation,
             SUM(rr.grade) AS total_marks,
             COUNT(DISTINCT rr.rubric_id) AS rubrics_covered
      FROM rubric_remedies rr INNER JOIN remedies rem ON rem.id = rr.remedy_id
      WHERE rr.rubric_id IN ($placeholders)
      GROUP BY rem.id, rem.abbreviation
      HAVING COUNT(DISTINCT rr.rubric_id) > 0
      ORDER BY total_marks DESC, rubrics_covered DESC, rem.abbreviation ASC
    ''', rubricIds);
    return rows.map((row) => RepertorizationResult(
      remedyId: row['remedy_id'] as int,
      abbreviation: row['abbreviation'] as String,
      totalMarks: (row['total_marks'] as num).toInt(),
      rubricsCovered: (row['rubrics_covered'] as num).toInt(),
    )).toList();
  }

  static Future<List<RubricCoverage>> remedyCoverage({required int remedyId, required List<int> rubricIds}) async {
    if (rubricIds.isEmpty) return [];
    final placeholders = List.filled(rubricIds.length, '?').join(', ');
    final rows = await (await database).rawQuery('''
      SELECT r.id AS rubric_id, r.full_path, rr.grade
      FROM rubric_remedies rr INNER JOIN rubrics r ON r.id = rr.rubric_id
      WHERE rr.remedy_id = ? AND rr.rubric_id IN ($placeholders)
    ''', [remedyId, ...rubricIds]);
    final byId = <int, RubricCoverage>{
      for (final row in rows) row['rubric_id'] as int: RubricCoverage(
        rubricId: row['rubric_id'] as int,
        fullPath: row['full_path'] as String,
        grade: (row['grade'] as num).toInt(),
      ),
    };
    return rubricIds.where(byId.containsKey).map((id) => byId[id]!).toList();
  }
}
