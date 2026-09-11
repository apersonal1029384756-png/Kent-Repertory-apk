import 'package:flutter/material.dart';
import 'package:otp/otp.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db_helper.dart';

final currentTotality = TotalityController();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isActivated = prefs.getBool('is_activated') ?? false;
  runApp(MaterialApp(
    title: 'Kent Repertory for Students',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
    home: isActivated ? const RepertorySearchScreen() : const OtpActivationScreen(),
  ));
}

class TotalityController extends ChangeNotifier {
  final List<RubricResult> _rubrics = [];
  List<RubricResult> get rubrics => List.unmodifiable(_rubrics);
  bool contains(int rubricId) => _rubrics.any((rubric) => rubric.id == rubricId);

  bool add(RubricResult rubric) {
    if (contains(rubric.id)) return false;
    _rubrics.add(rubric);
    notifyListeners();
    return true;
  }

  void remove(int rubricId) {
    _rubrics.removeWhere((rubric) => rubric.id == rubricId);
    notifyListeners();
  }

  void clear() {
    _rubrics.clear();
    notifyListeners();
  }
}

class OtpActivationScreen extends StatefulWidget {
  const OtpActivationScreen({super.key});
  @override
  State<OtpActivationScreen> createState() => _OtpActivationScreenState();
}

class _OtpActivationScreenState extends State<OtpActivationScreen> {
  final _otpInput = TextEditingController();
  String _errorText = '';
  static const _secretKey = 'JBSWY3DPEHPK3PXP';

  bool _validateOtp(String code) {
    if (code.trim().length != 6) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return [-30000, 0, 30000].any((offset) =>
        code.trim() == OTP.generateTOTPCodeString(_secretKey, now + offset, interval: 30, length: 6, algorithm: Algorithm.SHA1, isGoogle: true));
  }

  Future<void> _submit() async {
    if (!_validateOtp(_otpInput.text)) {
      setState(() => _errorText = 'Invalid or expired key. Please check current OTP.');
      return;
    }
    await (await SharedPreferences.getInstance()).setBool('is_activated', true);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RepertorySearchScreen()));
  }

  @override
  void dispose() { _otpInput.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('First-Time Setup')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.vpn_key_rounded, size: 70, color: Colors.teal),
      const SizedBox(height: 16), const Text('App Activation Required', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), const Text('Enter the 6-digit dynamic code from Google Authenticator to activate offline repertory storage.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 24), TextField(controller: _otpInput, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, letterSpacing: 6, fontWeight: FontWeight.bold), decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '000000', counterText: '')),
      if (_errorText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_errorText, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20), SizedBox(width: double.infinity, height: 48, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), onPressed: _submit, child: const Text('Activate Once', style: TextStyle(color: Colors.white, fontSize: 16))))
    ]))),
  );
}

class RepertorySearchScreen extends StatefulWidget {
  const RepertorySearchScreen({super.key});
  @override
  State<RepertorySearchScreen> createState() => _RepertorySearchScreenState();
}

class _RepertorySearchScreenState extends State<RepertorySearchScreen> {
  final _queryController = TextEditingController();
  List<RubricResult> _rubricResults = [];
  bool _searching = false;
  int _searchRequest = 0;

  Future<void> _onSearch(String query) async {
    final request = ++_searchRequest;
    if (query.trim().isEmpty) {
      setState(() { _rubricResults = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    final results = await RepertoryEngine.searchSymptom(query);
    if (!mounted || request != _searchRequest) return;
    setState(() { _rubricResults = results; _searching = false; });
  }

  void _addRubric(RubricResult rubric) {
    final added = currentTotality.add(rubric);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(added ? 'Added to repertorial totality.' : 'That rubric is already in the totality.')));
  }

  @override
  void dispose() { _queryController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kent Repertory for Students'), elevation: 1, actions: [
      AnimatedBuilder(animation: currentTotality, builder: (_, __) => TextButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TotalityScreen())),
        icon: Badge(label: Text('${currentTotality.rubrics.length}'), child: const Icon(Icons.format_list_bulleted, color: Colors.white)),
        label: const Text('Totality', style: TextStyle(color: Colors.white)),
      ))
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(controller: _queryController, onChanged: _onSearch, decoration: InputDecoration(hintText: "Enter symptom (e.g. 'Burning pain in head morning')...", prefixIcon: const Icon(Icons.search), suffixIcon: _queryController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _queryController.clear(); _onSearch(''); }) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))),
      Expanded(child: _searching ? const Center(child: CircularProgressIndicator()) : _rubricResults.isEmpty ? Center(child: Text(_queryController.text.isEmpty ? 'Type a clinical symptom to search the Kent hierarchy.' : 'No matching rubrics found.', style: TextStyle(color: Colors.grey.shade600))) : ListView.builder(itemCount: _rubricResults.length, itemBuilder: (_, index) => _rubricCard(_rubricResults[index])))
    ]),
  );

  Widget _rubricCard(RubricResult item) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    RichText(text: TextSpan(style: const TextStyle(fontSize: 16, color: Colors.black87), children: [TextSpan(text: item.fullPath, style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: ' = ${item.pageNumber}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 17))])),
    const SizedBox(height: 8), const Divider(height: 1), const SizedBox(height: 8),
    RichText(text: TextSpan(children: item.remedies.map((remedy) => TextSpan(text: '${remedy.abbrev}  ', style: _gradeStyle(remedy.grade))).toList())),
    const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: AnimatedBuilder(animation: currentTotality, builder: (_, __) => OutlinedButton.icon(onPressed: currentTotality.contains(item.id) ? null : () => _addRubric(item), icon: Icon(currentTotality.contains(item.id) ? Icons.check : Icons.add), label: Text(currentTotality.contains(item.id) ? 'Added' : 'Add to totality'))))
  ])));

  TextStyle _gradeStyle(int grade) => grade == 3 ? const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 14) : grade == 2 ? const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 14) : const TextStyle(color: Colors.black87, fontSize: 13);
}

class TotalityScreen extends StatelessWidget {
  const TotalityScreen({super.key});

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Clear repertorial totality?'), content: const Text('All selected rubrics will be removed from the current case.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Clear'))]));
    if (confirmed == true) currentTotality.clear();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: currentTotality, builder: (_, __) {
    final rubrics = currentTotality.rubrics;
    return Scaffold(appBar: AppBar(title: const Text('Repertorial Totality'), actions: [if (rubrics.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep_outlined), tooltip: 'Clear totality', onPressed: () => _clear(context))]), body: rubrics.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.playlist_add, size: 56, color: Colors.teal), const SizedBox(height: 12), const Text('No rubrics selected', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Search for a rubric and add it to build the current case.', textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.search), label: const Text('Add Symptom / Rubric'))]))) : Column(children: [Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('${rubrics.length} selected rubric${rubrics.length == 1 ? '' : 's'} — grades will be summed from Kent’s database.', style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: ListView.builder(itemCount: rubrics.length, itemBuilder: (_, index) { final rubric = rubrics[index]; return ListTile(leading: CircleAvatar(child: Text('${index + 1}')), title: Text(rubric.fullPath), subtitle: Text('Page ${rubric.pageNumber}'), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline), tooltip: 'Remove rubric', onPressed: () => currentTotality.remove(rubric.id)); })), Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.add), label: const Text('Add Rubric'))), const SizedBox(width: 12), Expanded(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RepertorizationResultsScreen(rubrics: rubrics))), icon: const Icon(Icons.calculate), label: const Text('Repertorize')))]))]));
  });
}

class RepertorizationResultsScreen extends StatefulWidget {
  final List<RubricResult> rubrics;
  const RepertorizationResultsScreen({super.key, required this.rubrics});
  @override
  State<RepertorizationResultsScreen> createState() => _RepertorizationResultsScreenState();
}

class _RepertorizationResultsScreenState extends State<RepertorizationResultsScreen> {
  late final Future<List<RepertorizationResult>> _results;

  @override
  void initState() {
    super.initState();
    _results = RepertoryEngine.repertorize(widget.rubrics.map((rubric) => rubric.id).toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Repertorial Results')), body: FutureBuilder<List<RepertorizationResult>>(future: _results, builder: (_, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Unable to calculate this totality: ${snapshot.error}', textAlign: TextAlign.center)));
    final results = snapshot.data ?? [];
    if (results.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No remedies cover the selected rubrics. Return to the totality and adjust the case.', textAlign: TextAlign.center)));
    return Column(children: [Padding(padding: const EdgeInsets.all(16), child: Text('Ranked by total marks, then rubrics covered. ${widget.rubrics.length} rubric${widget.rubrics.length == 1 ? '' : 's'} selected.', style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (_, index) { final result = results[index]; return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), child: ListTile(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RemedyDetailScreen(result: result, rubrics: widget.rubrics))), leading: CircleAvatar(child: Text('${index + 1}')), title: Text(result.abbreviation, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${result.totalMarks} marks  •  ${result.rubricsCovered} of ${widget.rubrics.length} rubrics covered'), trailing: const Icon(Icons.chevron_right))); }))]);
  }));
}

class RemedyDetailScreen extends StatefulWidget {
  final RepertorizationResult result;
  final List<RubricResult> rubrics;
  const RemedyDetailScreen({super.key, required this.result, required this.rubrics});
  @override
  State<RemedyDetailScreen> createState() => _RemedyDetailScreenState();
}

class _RemedyDetailScreenState extends State<RemedyDetailScreen> {
  late final Future<List<RubricCoverage>> _coverage;

  @override
  void initState() {
    super.initState();
    _coverage = RepertoryEngine.remedyCoverage(
      remedyId: widget.result.remedyId,
      rubricIds: widget.rubrics.map((rubric) => rubric.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Remedy Detail')), body: FutureBuilder<List<RubricCoverage>>(future: _coverage, builder: (_, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return Center(child: Text('Unable to load remedy coverage: ${snapshot.error}', textAlign: TextAlign.center));
    final coverage = snapshot.data ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [Text(widget.result.abbreviation, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text('${widget.result.totalMarks} marks / ${widget.result.rubricsCovered} of ${widget.rubrics.length} rubrics'), const Divider(height: 32), const Text('Covered selected rubrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 8), ...coverage.map((item) => Card(child: ListTile(leading: const Icon(Icons.check_circle, color: Colors.teal), title: Text(item.fullPath), trailing: Chip(label: Text('${item.grade}'))))), const SizedBox(height: 12), Text('Total: ${widget.result.totalMarks}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]);
  }));
}
