import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:lottie/lottie.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';

class SummarizationT5Page extends StatefulWidget {
  final File? pdfFile;
  final String selectedModel;
  final String? textInput;
  final String userId;

  const SummarizationT5Page({
    super.key,
    this.pdfFile,
    required this.selectedModel,
    this.textInput,
    required this.userId,
  });

  @override
  State<SummarizationT5Page> createState() => _SummarizationT5PageState();
}

class _SummarizationT5PageState extends State<SummarizationT5Page> {
  String summaryType = 'detailed';
  String result = "";
  bool isLoading = false;

  final List<String> summaryTypes = [
    'short',
    'detailed',
    'financial_only',
    'risk_only'
  ];

  Future<void> sendToBackend() async {
    setState(() {
      isLoading = true;
      result = "";
    });

    final uri = Uri.parse("http://127.0.0.1:8000/summarize_t5");

    try {
      http.Response response;

      if (widget.pdfFile != null) {
        final request = http.MultipartRequest('POST', uri);

        final mimeType = lookupMimeType(widget.pdfFile!.path) ?? 'application/pdf';
        final file = await http.MultipartFile.fromPath(
          'file',
          widget.pdfFile!.path,
          contentType: MediaType.parse(mimeType),
        );

        request.files.add(file);
        request.fields['summary_type'] = summaryType;
        request.fields['model'] = widget.selectedModel;

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else if (widget.textInput != null) {
        response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': widget.textInput,
            'summary_type': summaryType,
            'model': widget.selectedModel,
          }),
        );
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
    if (result.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary is empty, nothing to download.')),
      );
      return;
    }

    final pdf = pw.Document();
    final roboto = await pw.Font.ttf(await rootBundle.load('assets/font/static/Roboto-Regular.ttf'));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final paragraphs = result.split(RegExp(r'\n+'));
          return paragraphs.map((para) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Text(
                para,
                style: pw.TextStyle(font: roboto, fontSize: 12),
              ),
            );
          }).toList();
        },
      ),
    );

    try {
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Summary PDF',
        fileName: 'summary.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath == null) return;

      final file = File(outputPath);
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Summary PDF saved to $outputPath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: $e')),
      );
    }
  }

  String getFileSize(File file) {
    final sizeInBytes = file.lengthSync();
    final sizeInKB = (sizeInBytes / 1024).toStringAsFixed(2);
    return '$sizeInKB KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Row(
        children: [
          _buildNavBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          "Summarization (${widget.selectedModel})",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildInputSelection(),
                      const SizedBox(height: 20),
                      if (widget.pdfFile != null || widget.textInput != null) _buildInputDetails(),
                      const SizedBox(height: 20),
                      _buildDropdown(),
                      const SizedBox(height: 20),
                      _buildGenerateButton(),
                      const SizedBox(height: 20),
                      if (isLoading)
                        Center(child: SizedBox(width: 180, height: 180, child: Lottie.asset('assets/loading2.json'))),
                      if (result.isNotEmpty) _buildSummaryDisplay(),
                    ],
                  ),
                  if (result.isNotEmpty)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton(
                        backgroundColor: const Color(0xFF8D6E63),
                        onPressed: downloadSummary,
                        child: const Icon(Icons.download, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      width: 80,
      color: const Color(0xFF4E342E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navIcon(Icons.summarize, "Summarization"),
          const SizedBox(height: 20),
          _navIcon(Icons.question_answer, "Q&A"),
          const SizedBox(height: 20),
          _navIcon(Icons.article, "Classification"),
          const SizedBox(height: 20),
          _navIcon(Icons.verified_user, "Compliance"),
        ],
      ),
    );
  }

  Widget _buildInputSelection() {
    return Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text("Select PDF"),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037)),
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
            if (result != null && result.files.single.path != null) {
              setState(() {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SummarizationT5Page(
                      pdfFile: File(result.files.single.path!),
                      selectedModel: widget.selectedModel,
                      userId: widget.userId,
                    ),
                  ),
                );
              });
            }
          },
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.text_fields),
          label: const Text("Enter Text"),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037)),
          onPressed: () {
            _showTextInputDialog();
          },
        ),
      ],
    );
  }

  void _showTextInputDialog() {
    TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Text to Summarize"),
          content: TextField(
            controller: textController,
            maxLines: 5,
            decoration: const InputDecoration(hintText: "Enter your text here"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SummarizationT5Page(
                        textInput: textController.text.trim(),
                        selectedModel: widget.selectedModel,
                        userId: widget.userId,
                      ),
                    ),
                  );
                }
              },
              child: const Text("Proceed"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputDetails() {
    if (widget.pdfFile != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFD7CCC8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("PDF Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text("File: ${widget.pdfFile!.path.split('/').last}"),
            Text("Size: ${getFileSize(widget.pdfFile!)}"),
          ],
        ),
      );
    } else if (widget.textInput != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFD7CCC8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Text Input Provided", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(widget.textInput!),
          ],
        ),
      );
    } else {
      return const Text("No input provided.");
    }
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: summaryType,
        isExpanded: true,
        underline: Container(),
        items: summaryTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
        onChanged: (val) => setState(() => summaryType = val!),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.auto_fix_high, color: Colors.white),
        label: const Text("Generate Summary", style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5D4037),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: sendToBackend,
      ),
    );
  }

  Widget _buildSummaryDisplay() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Summary:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(result, style: const TextStyle(fontSize: 15), textAlign: TextAlign.justify),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, String label) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label feature coming soon')));
        },
        child: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white,
          child: Icon(icon, color: const Color(0xFF4E342E)),
        ),
      ),
    );
  }
}
