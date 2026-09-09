import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:otp/otp.dart';
import 'db_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isActivated = prefs.getBool('is_activated') ?? false;

  runApp(MaterialApp(
    title: "Kent's Repertory",
    debugShowCheckedModeBanner: false,
    theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
    home: isActivated ? const RepertorySearchScreen() : const OtpActivationScreen(),
  ));
}

class OtpActivationScreen extends StatefulWidget {
  const OtpActivationScreen({Key? key}) : super(key: key);

  @override
  State<OtpActivationScreen> createState() => _OtpActivationScreenState();
}

class _OtpActivationScreenState extends State<OtpActivationScreen> {
  final TextEditingController _otpInput = TextEditingController();
  String _errorText = '';
  static const String _secretKey = "JBSWY3DPEHPK3PXP";

  bool _validateOtp(String code) {
    String cleanCode = code.trim();
    if (cleanCode.length != 6) return false;

    int now = DateTime.now().millisecondsSinceEpoch;

    // Check current, previous, and next 30-second window to tolerate slight clock drift
    for (int offset in [-30000, 0, 30000]) {
      String generated = OTP.generateTOTPCodeString(
        _secretKey,
        now + offset,
        interval: 30,
        length: 6,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      if (cleanCode == generated) return true;
    }
    return false;
  }

  void _submit() async {
    if (_validateOtp(_otpInput.text)) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_activated', true);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RepertorySearchScreen()),
      );
    } else {
      setState(() => _errorText = "Invalid or expired key. Please check current OTP.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("First-Time Setup")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.vpn_key_rounded, size: 70, color: Colors.teal),
              const SizedBox(height: 16),
              const Text(
                "App Activation Required",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter the 6-digit dynamic code from Google Authenticator to activate offline repertory storage.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _otpInput,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, letterSpacing: 6, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "000000",
                  counterText: "",
                ),
              ),
              if (_errorText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_errorText, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: _submit,
                  child: const Text("Activate Once", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class RepertorySearchScreen extends StatefulWidget {
  const RepertorySearchScreen({Key? key}) : super(key: key);

  @override
  State<RepertorySearchScreen> createState() => _RepertorySearchScreenState();
}

class _RepertorySearchScreenState extends State<RepertorySearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  List<RubricResult> _rubricResults = [];
  bool _searching = false;

  void _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _rubricResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    final results = await RepertoryEngine.searchSymptom(query);
    setState(() {
      _rubricResults = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kent Repertory Search"), elevation: 1),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: "Enter symptom (e.g. 'Burning pain in head morning')...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _rubricResults.isEmpty
                    ? Center(
                        child: Text(
                          _queryController.text.isEmpty
                              ? "Type clinical symptom to search hierarchy"
                              : "No matching rubrics found.",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _rubricResults.length,
                        itemBuilder: (context, i) {
                          final item = _rubricResults[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                      children: [
                                        TextSpan(
                                          text: item.fullPath,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        TextSpan(
                                          text: " = ${item.pageNumber}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.teal.shade800,
                                            fontSize: 17,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  RichText(
                                    text: TextSpan(
                                      children: item.remedies.map((rem) {
                                        TextStyle gradeStyle;
                                        switch (rem.grade) {
                                          case 3:
                                            gradeStyle = const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Colors.redAccent,
                                              fontSize: 14,
                                            );
                                            break;
                                          case 2:
                                            gradeStyle = const TextStyle(
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueAccent,
                                              fontSize: 14,
                                            );
                                            break;
                                          default:
                                            gradeStyle = const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 13,
                                            );
                                        }
                                        return TextSpan(
                                          text: "${rem.abbrev}  ",
                                          style: gradeStyle,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
