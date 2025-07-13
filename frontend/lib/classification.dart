// classification.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:lottie/lottie.dart';
import 'user_home_page.dart';
import 'summarization.dart';
import 'compliance.dart';
import 'q_a.dart';

class ClassificationPage extends StatefulWidget {
  final String selectedModel;
  final String userId;
  final File? pdfFile;
  final String? textInput;

  const ClassificationPage({
    super.key,
    required this.selectedModel,
    required this.userId,
    this.pdfFile,
    this.textInput,
  });

  @override
  State<ClassificationPage> createState() => _ClassificationPageState();
}

class _ClassificationPageState extends State<ClassificationPage> {
  File? pdfFile;
  String? textInput;
  String result = "";
  bool isLoading = false;
  List<dynamic> multiPageResults = [];
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
  String getFileSize(File file) {
    final sizeInBytes = file.lengthSync();
    final sizeInKB = (sizeInBytes / 1024).toStringAsFixed(2);
    return '$sizeInKB KB';
  }

  Future<void> pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
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
      multiPageResults = [];
    });

    final uri = Uri.parse("http://127.0.0.1:8000/classify");

    try {
      http.Response response;

      if (pdfFile != null) {
        final request = http.MultipartRequest('POST', uri);
        request.fields['model'] = widget.selectedModel;
        request.files.add(await http.MultipartFile.fromPath('file', pdfFile!.path));
        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else if (_textController.text.trim().isNotEmpty) {
        response = await http.post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'text': _textController.text, 'model': widget.selectedModel},
        );
      } else {
        setState(() {
          result = "❌ Please provide valid input.";
          isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          if (jsonData.containsKey('results')) {
            multiPageResults = jsonData['results'];
          } else if (jsonData.containsKey('label')) {
            result = "Predicted Label: \${jsonData['label']}";
          } else {
            result = "⚠️ Unexpected response format.";
          }
        });
      } else {
        setState(() {
          result = "❌ Error \${response.statusCode}:\n\${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        result = "🚨 Failed to connect to backend: \$e";
      });
    }

    setState(() {
      isLoading = false;
    });
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
          _navIcon(Icons.summarize, "Summarization", "summarization"),
          const SizedBox(height: 20),
          _navIcon(Icons.question_answer, "Q&A", "qna"),
          const SizedBox(height: 20),
          _navIcon(Icons.article, "Classification", "classification"),
          const SizedBox(height: 20),
          _navIcon(Icons.verified_user, "Compliance", "compliance"),
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
                        title: Text(m['name']!, style: const TextStyle(color: Color(0xFF4E342E))),
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

  Widget _buildGenerateButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4E342E),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check_circle),
          label: const Text("Classify"),
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

  Widget _buildResultDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SelectableText(result, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildGridDisplay() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: multiPageResults.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, index) {
        final page = multiPageResults[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF5D4037)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Page \${page["page"]} - \${page["label"]}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5D4037)),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    page["text_preview"] ?? '',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
              _buildSideNav(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text("Classification (${widget.selectedModel})", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),

                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputSection(),
                              const SizedBox(height: 20),
                              _buildGenerateButton(),
                              const SizedBox(height: 20),
                              if (result.isNotEmpty) _buildResultDisplay(),
                              if (multiPageResults.isNotEmpty) _buildGridDisplay(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
