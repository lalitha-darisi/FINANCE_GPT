import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:lottie/lottie.dart';
//import 'package:pdf/widgets.dart' as pw;
//import 'package:pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'user_home_page.dart';
import 'summarization.dart';
import 'q_a.dart';
import 'classification.dart';
import 'compliance.dart';
import 'config.dart';
class ComplianceGeminiPage extends StatefulWidget {
  final File? pdfFile;
  final String selectedModel;
  final String? textInput;
  final String userId;

  const ComplianceGeminiPage({
    Key? key,
    this.pdfFile,
    required this.selectedModel,
    this.textInput,
    required this.userId,
  }) : super(key: key);

  @override
  State<ComplianceGeminiPage> createState() => _ComplianceGeminiPageState();
}

class _ComplianceGeminiPageState extends State<ComplianceGeminiPage> {
  String resultRaw = "";
  List<dynamic> structuredResult = [];
  bool isLoading = false;
  File? pdfFile;
  late TextEditingController _textController;

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
      resultRaw = "";
      structuredResult = [];
    });

    // final uri = Uri.parse("http://127.0.0.1:8000/compliance");
    final uri = Uri.parse("$baseUrl/compliance");

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
        request.fields['model'] = widget.selectedModel;
        request.fields['user_id'] = widget.userId;

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else if (_textController.text.trim().isNotEmpty) {
        final request = http.MultipartRequest('POST', uri);
        request.fields['text'] = _textController.text;
        request.fields['model'] = widget.selectedModel;
        request.fields['user_id'] = widget.userId;

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        setState(() {
          resultRaw = "❌ No valid input provided.";
          isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

       final data = jsonData['results'] ?? jsonData['compliance_summary'];

        if (data is List) {
          setState(() {
            structuredResult = data;
          });
        } else {
          setState(() {
            resultRaw = data.toString();
          });
        }

      } else {
        setState(() {
          resultRaw = "❌ Error ${response.statusCode}:\n${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        resultRaw = "🚨 Failed to connect to backend: $e";
      });
    }

    setState(() {
      isLoading = false;
    });
  }



  String getFileSize(File file) {
    final sizeInBytes = file.lengthSync();
    final sizeInKB = (sizeInBytes / 1024).toStringAsFixed(2);
    return '$sizeInKB KB';
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4E342E),
            foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Stack(
        children: [
          Row(
            children: [
              _buildNavBar(),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "Compliance Check (${widget.selectedModel})",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputSection(),
                            const SizedBox(height: 20),
                            _buildGenerateButton(),
                            const SizedBox(height: 20),
                            if (isLoading)
                              Center(child: Lottie.asset('assets/loading2.json', width: 120)),
                            if (resultRaw.isNotEmpty || structuredResult.isNotEmpty)
                              _buildResultDisplay(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4E342E),
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.verified_user),
        label: const Text("Check Compliance"),
        onPressed: sendToBackend,
      ),
    );
  }

  Widget _buildResultDisplay() {
    if (structuredResult.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: structuredResult.map((item) {
          Color color = item['classification'] == 'Compliant'
              ? Colors.green
              : item['classification'] == 'Non-Compliant'
                  ? Colors.red
                  : Colors.orange;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Claim: ${item['claim']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Text("Classification: "),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(item['classification'], style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text("Reasoning: ${item['reasoning']}"),
                const SizedBox(height: 5),
                const Text("Matched Policies:"),
                ...List<Widget>.from(item['matched_policies'].map((policy) => Row(
                      children: [const Text("• "), Expanded(child: Text(policy))],
                    ))),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SelectableText(resultRaw),
      );
    }
  }

  Widget _buildNavBar() {
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
                MaterialPageRoute(builder: (context) => UserHomePage(userId: widget.userId)),
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
}