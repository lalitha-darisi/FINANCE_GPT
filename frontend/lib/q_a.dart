import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:lottie/lottie.dart';

import 'user_home_page.dart';
import 'summarization.dart';
import 'classification.dart';
import 'compliance.dart';

class QAGeminiPage extends StatefulWidget {
  final String selectedModel;
  final String userId;

  const QAGeminiPage({Key? key, required this.selectedModel, required this.userId}) : super(key: key);

  @override
  State<QAGeminiPage> createState() => _QAGeminiPageState();
}

class _QAGeminiPageState extends State<QAGeminiPage> {
  File? pdfFile;
  String? textInput;
  String question = "";
  List<Map<String, String>> chatHistory = [];
  bool isLoading = false;

  late TextEditingController _textInputController;
  late TextEditingController _questionController;
  String selectedModel = '';

  @override
  void initState() {
    super.initState();
    _textInputController = TextEditingController();
    _questionController = TextEditingController();
    selectedModel = widget.selectedModel;
  }

  @override
  void dispose() {
    _textInputController.dispose();
    _questionController.dispose();
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
        _textInputController.clear();
      });
    }
  }

  Future<void> askQuestion() async {
    if (question.trim().isEmpty) return;
    setState(() {
      chatHistory.add({'role': 'user', 'text': question});
      isLoading = true;
    });

    final uri = Uri.parse("http://127.0.0.1:8000/qa_api");
    try {
      http.Response response;
      if (pdfFile != null) {
        final request = http.MultipartRequest('POST', uri);
        final mimeType = lookupMimeType(pdfFile!.path) ?? 'application/pdf';
        final file = await http.MultipartFile.fromPath(
          'file', pdfFile!.path, contentType: MediaType.parse(mimeType));
        request.files.add(file);
        request.fields['question'] = question;
        request.fields['model'] = selectedModel;
        final streamed = await request.send();
        response = await http.Response.fromStream(streamed);
      } else if (_textInputController.text.trim().isNotEmpty) {
        final request = http.MultipartRequest('POST', uri)
          ..fields['text'] = _textInputController.text
          ..fields['question'] = question
          ..fields['model'] = selectedModel;
        final streamed = await request.send();
        response = await http.Response.fromStream(streamed);
      } else {
        setState(() {
          chatHistory.add({'role': 'bot', 'text': '❌ Please upload a PDF or enter text.'});
        });
        isLoading = false;
        return;
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          chatHistory.add({'role': 'bot', 'text': jsonData['answer'] ?? 'No answer received.'});
        });
      } else {
        setState(() {
          chatHistory.add({'role': 'bot', 'text': '❌ Error ${response.statusCode}: ${response.body}'});
        });
      }
    } catch (e) {
      setState(() {
        chatHistory.add({'role': 'bot', 'text': '🚨 Failed to connect: $e'});
      });
    }

    setState(() {
      isLoading = false;
      question = "";
      _questionController.clear();
    });
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
                  fillColor: MaterialStateColor.resolveWith((states) => Color(0xFF4E342E)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select a Model',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4E342E)),
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
      case 'compliance':
        page = ComplianceGeminiPage(selectedModel: newModel, userId: widget.userId);
        break;
      case 'qna':
      default:
        page = QAGeminiPage(selectedModel: newModel, userId: widget.userId);
    }

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _navIcon(IconData icon, String label, {String? useCase, VoidCallback? onTap}) {
    return Tooltip(
      message: label,
      textStyle: const TextStyle(color: Colors.white),
      decoration: BoxDecoration(
        color: const Color(0xFF4E342E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GestureDetector(
        onTap: onTap ?? () => navigateToUseCase(useCase!),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white,
          child: Icon(icon, color: const Color(0xFF4E342E)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Row(children: [
        Container(
          width: 100,
          color: const Color(0xFF4E342E),
          child: Column(children: [
            const SizedBox(height: 30),
            _navIcon(Icons.home, "Home", onTap: () {
              Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => UserHomePage(userId: widget.userId),
              ));
            }),
            const Spacer(),
            _navIcon(Icons.summarize, "Summarization", useCase: "summarization"),
            const SizedBox(height: 20),
            _navIcon(Icons.question_answer, "Q&A", useCase: "qna"),
            const SizedBox(height: 20),
            _navIcon(Icons.article, "Classification", useCase: "classification"),
            const SizedBox(height: 20),
            _navIcon(Icons.verified_user, "Compliance", useCase: "compliance"),
            const Spacer(),
          ]),
        ),
        Expanded(
          child: Column(children: [
            const SizedBox(height: 20),
            Text("Q&A Chat ($selectedModel)", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                const Text("OR"),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.brown.shade300, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _textInputController,
                    maxLines: 5,
                    onChanged: (val) => textInput = val,
                    decoration: InputDecoration.collapsed(hintText: "Or paste text here"),
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
                  ),
              ]),
            ),
            Expanded(child: _buildChatArea()),
            _buildQuestionInput(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildChatArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        itemCount: chatHistory.length + (isLoading ? 1 : 0),
        itemBuilder: (c, i) {
          if (isLoading && i == chatHistory.length) {
            return Row(children: [
              CircleAvatar(radius: 24, backgroundColor: Colors.white, child: Lottie.asset('assets/robo2.json', width: 40)),
              Lottie.asset('assets/chat.json', width: 50),
            ]);
          }
          final msg = chatHistory[i];
          bool isUser = msg['role'] == 'user';
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFFD7CCC8) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(msg['text']!, style: const TextStyle(fontSize: 15)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionInput() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _questionController,
            decoration: const InputDecoration(hintText: 'Type your question...', border: OutlineInputBorder()),
            onChanged: (val) => question = val,
          ),
        ),
        const SizedBox(width: 10),
       ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF4E342E),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.all(16),
  ),
  onPressed: isLoading ? null : askQuestion,
  child: const Icon(Icons.send),
),

      ]),
    );
  }
}
