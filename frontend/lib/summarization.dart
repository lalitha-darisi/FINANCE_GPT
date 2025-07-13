import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:lottie/lottie.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';

import 'user_home_page.dart';
import 'classification.dart';
import 'q_a.dart';
import 'compliance.dart';

class SummarizationPage extends StatefulWidget {
  final File? pdfFile;
  final String selectedModel;
  final String? textInput;
  final String userId;

  const SummarizationPage({
    Key? key,
    this.pdfFile,
    required this.selectedModel,
    this.textInput,
    required this.userId,
  }) : super(key: key);

  @override
  State<SummarizationPage> createState() => _SummarizationPageState();
}

class _SummarizationPageState extends State<SummarizationPage> {
  String summaryType = 'detailed';
  String result = "";
  bool isLoading = false;
  File? pdfFile;
  late TextEditingController _textController;

  final List<String> summaryTypes = [
    'short',
    'detailed',
    'financial_only',
    'risk_only'
  ];

  @override
  void initState() {
    super.initState();
    pdfFile = widget.pdfFile;
    _textController = TextEditingController(text: widget.textInput);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String getFileSize(File file) {
    final sizeInBytes = file.lengthSync();
    final sizeInKB = (sizeInBytes / 1024).toStringAsFixed(2);
    return '$sizeInKB KB';
  }

  Future<void> pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        pdfFile = File(result.files.single.path!);
        _textController.clear();
      });
    }
  }

  Future<void> sendToBackend() async {
    setState(() {
      isLoading = true;
      result = "";
    });

    final uri = Uri.parse("http://127.0.0.1:8000/summarize");

    try {
      http.Response response;

      if (pdfFile != null) {
        final request = http.MultipartRequest('POST', uri);
        final mimeType = lookupMimeType(pdfFile!.path) ?? 'application/pdf';
        final file = await http.MultipartFile.fromPath(
          'file',
          pdfFile!.path,
          contentType: MediaType.parse(mimeType),
        );
        request.files.add(file);
        request.fields['summary_type'] = summaryType;
        request.fields['model'] = widget.selectedModel;

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else if (_textController.text.trim().isNotEmpty) {
        final request = http.MultipartRequest('POST', uri);
        request.fields['text'] = _textController.text;
        request.fields['summary_type'] = summaryType;
        request.fields['model'] = widget.selectedModel;

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        setState(() {
          result = "❌ No valid input provided.";
          isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          result = jsonData['summary'];
        });
      } else {
        setState(() {
          result = "❌ Error ${response.statusCode}:\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        result = "🚨 Failed to connect to backend: $e";
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> downloadSummary() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context context) => pw.Text(result)));

    String? path = await FilePicker.platform.saveFile(
      dialogTitle: '📄 Save summary as...',
      fileName: 'summary_${widget.selectedModel}.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (path == null) return;

    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("📥 Summary saved to $path")),
    );
  }

  // 🔽 Everything else remains the same...

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFFFF8F0),
    body: Stack(
  children: [
    // 🧱 Main content (Row)
    Row(
      children: [
        _buildSideNav(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  "Summarization (${widget.selectedModel})",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputSection(),
                        const SizedBox(height: 20),
                        _buildDropdown(),
                        const SizedBox(height: 20),
                        _buildGenerateButton(),
                        const SizedBox(height: 20),
                        if (result.isNotEmpty) _buildSummaryDisplay(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),

    // ✅ FULLSCREEN CENTERED LOADER
  //   if (isLoading)
  // Padding(
  //   padding: const EdgeInsets.only(top: 10),
  //   child: Center(
  //     child: Lottie.asset('assets/loading2.json', width: 100),
  //   ),
  // ),


    // ✅ Floating download button
    if (!isLoading && result.isNotEmpty)
      Positioned(
        bottom: 20,
        right: 20,
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF4E342E),
          foregroundColor: Colors.white,
          onPressed: downloadSummary,
          icon: const Icon(Icons.download),
          label: const Text("Download"),
        ),
      ),
  ],
),

  );
}

  Widget _buildSideNav() {
    return Container(
      width: 100,
      color: const Color(0xFF4E342E),
      child: Column(
        children: [
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => UserHomePage(userId: widget.userId),
                ),
              );
            },
            child: const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Icon(Icons.home, color: Color(0xFF4E342E)),
            ),
          ),
          const Spacer(),
          _navIcon(Icons.summarize, "Summarization","summarization"),
          const SizedBox(height: 20),
          _navIcon(Icons.question_answer,"Q&A", "qna"),
          const SizedBox(height: 20),
          _navIcon(Icons.article, "Classification","classification"),
          const SizedBox(height: 20),
          _navIcon(Icons.verified_user, "Compliance","compliance"),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, String label, String useCase) {
  return Tooltip(
    message: label,
    textStyle: const TextStyle(color: Colors.white),
    decoration: BoxDecoration(
      color: Color(0xFF4E342E),
      borderRadius: BorderRadius.circular(8),
    ),
    child: GestureDetector(
      onTap: () => navigateToUseCase(useCase),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white,
        child: Icon(icon, color: const Color(0xFF4E342E)),
      ),
    ),
  );
}


  Future<void> navigateToUseCase(String useCase) async {
  String? newModel = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      List<Map<String, String>> models;

switch (useCase) {
  case 'summarization':
    models = [
      {'name': 'Gemini 1.5 Flash', 'value': 'gemini'},
      {'name': 'T5 Base Model', 'value': 't5'},
    ];
    break;
  case 'qna':
    models = [
      {'name': 'Gemini 1.5 Flash', 'value': 'gemini'},
      {'name': 'T5 Small Model', 'value': 't5_small'},
    ];
    break;
  case 'classification':
    models = [
      {'name': 'Gemini 1.5 Flash', 'value': 'gemini'},
      {'name': 'DistilBERT', 'value': 'distilbert'},
    ];
    break;
  case 'compliance':
    models = [
      {'name': 'Gemini 1.5 Flash', 'value': 'gemini'},
      {'name': 'Tiny LLaMA', 'value': 'tiny_lama'},
    ];
    break;
  default:
    models = [
      {'name': 'Gemini 1.5 Flash', 'value': 'gemini'},
      {'name': 'T5 Small Model', 'value': 't5_small'},
    ];
}

      String sel = models[0]['value']!;

      return StatefulBuilder(
        builder: (context, setState) {
          return Theme(
            data: Theme.of(context).copyWith(
              unselectedWidgetColor: Color(0xFF4E342E),
              radioTheme: RadioThemeData(
                fillColor: MaterialStateColor.resolveWith((states) {
                  return Color(0xFF4E342E);
                }),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select a Model',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var m in models)
                    RadioListTile(
                      title: Text(
                        m['name']!,
                        style: const TextStyle(color: Color(0xFF4E342E)),
                      ),
                      value: m['value'],
                      groupValue: sel,
                      onChanged: (v) => setState(() => sel = v!),
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4E342E),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, sel),
                    child: const Text("Continue"),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (newModel == null) return;

  Widget page;
  switch (useCase) {
    case 'summarization':
      page = SummarizationPage(selectedModel: newModel, userId: widget.userId);
      break;
    case 'classification':
      page = ClassificationPage(selectedModel: newModel, userId: widget.userId);
      break;
    case 'qna':
      page = QAGeminiPage(selectedModel: newModel, userId: widget.userId);
      break;
    case 'compliance':
      page = ComplianceGeminiPage(selectedModel: newModel, userId: widget.userId);
      break;
    default:
      return;
  }

  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => page));
}

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4E342E), // brown
            foregroundColor: Colors.white,           // white text/icon
          ),
          onPressed: pickPDF,
          icon: const Icon(Icons.upload_file),
          label: const Text("Upload PDF"),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _textController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: "Or paste text here",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.brown, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.brown),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color.fromARGB(255, 11, 11, 11)),
            ),
          ),
        ),
        if (pdfFile != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.brown.shade50,
                border: Border.all(color: Colors.brown),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "📄 ${pdfFile!.path.split('/').last}\n💾 Size: ${getFileSize(pdfFile!)}",
                style: const TextStyle(color: Color(0xFF4E342E)),
              ),
            )

      ],
    );
  }

  Widget _buildDropdown() {
    return DropdownButton<String>(
      value: summaryType,
      isExpanded: true,
      underline: Container(),
      items: summaryTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
      onChanged: (val) => setState(() => summaryType = val!),
    );
  }

  Widget _buildGenerateButton() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4E342E), // brown
          foregroundColor: Colors.white,           // white text/icon
        ),
        icon: const Icon(Icons.auto_fix_high),
        label: const Text("Generate Summary"),
        onPressed: sendToBackend,
      ),
      if (isLoading)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: Lottie.asset('assets/loading2.json', width: 100),
          ),
        ),
    ],
  );
}


  Widget _buildSummaryDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Summary:"),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(result),
        ),
      ],
    );
  }
}
