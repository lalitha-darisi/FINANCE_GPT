import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'summarization.dart';
import 'q_a.dart';
import 'classification.dart';
import 'compliance.dart';
import 'login_signup_page.dart';
import 'history_page.dart';

class UserHomePage extends StatefulWidget {
  final String userId;
  const UserHomePage({super.key, required this.userId});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  bool _showChatBubble = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _showChatBubble = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg2.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: PopupMenuButton<String>(
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: const CircleAvatar(
                backgroundImage: AssetImage('assets/user_avatar.jpeg'),
                radius: 20,
              ),
              onSelected: (value) {
                if (value == 'history') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoryPage(userId: widget.userId), // ✅ simplified
                    ),
                  );
                } else if (value == 'logout') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginSignUpPage()),
                  );
                }
              },

              itemBuilder: (context) => const [
                PopupMenuItem(value: 'history', child: Text('View History')),
                PopupMenuItem(value: 'logout', child: Text('Sign Out')),
              ],

            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  const Text(
                    'Welcome to your Document Hub!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4E342E)),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Select a Use Case:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF4E342E)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGlassBox(context, Icons.summarize, 'Summarization', 'Generate concise summaries from documents.'),
                      const SizedBox(width: 20),
                      _buildGlassBox(context, Icons.question_answer, 'Q&A', 'Ask questions & get answers from your files.'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGlassBox(context, Icons.article, 'Classification', 'Categorize documents automatically.'),
                      const SizedBox(width: 20),
                      _buildGlassBox(context, Icons.verified_user, 'Compliance', 'Check documents for policy violations.'),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_showChatBubble)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                    width: 200,
                    child: const Text('Hi! Tap me to know about the models.', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ),
                GestureDetector(
                  onTap: _showRoboModelInfo,
                  child: Lottie.asset('assets/robo2.json', width: 80, height: 80, repeat: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBox(BuildContext context, IconData icon, String label, String description) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          width: 160,
          height: 150,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 78, 52, 46).withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: InkWell(
            onTap: () => _onUseCaseTap(context, label),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 34),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(description, style: const TextStyle(fontSize: 11, color: Colors.white70), textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onUseCaseTap(BuildContext context, String label) async {
    String? selectedModel = await _selectModel(context, label);
    if (selectedModel == null) return;

    if (label == 'Summarization') {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => SummarizationPage(selectedModel: selectedModel, userId: widget.userId),
      ));
    } else if (label == 'Q&A') {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => QAGeminiPage(selectedModel: selectedModel, userId: widget.userId),
      ));
    } else if (label == 'Classification') {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ClassificationPage(selectedModel: selectedModel, userId: widget.userId),
      ));
    } else if (label == 'Compliance') {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ComplianceGeminiPage(selectedModel: selectedModel, userId: widget.userId),
      ));
    }
  }

  Future<String?> _selectModel(BuildContext context, String label) {
    String selectedModel = 'gemini';
    String secondModel;
    String secondModelName;
    Icon secondModelIcon = const Icon(Icons.memory, color: Colors.blueGrey);

    if (label == 'Summarization') {
      secondModel = 't5';
      secondModelName = 'T5 Base Model';
    } else if (label == 'Q&A') {
      secondModel = 't5_small';
      secondModelName = 'T5 Small Model';
    } else if (label == 'Classification') {
      secondModel = 'distilbert';
      secondModelName = 'DistilBERT';
    } else if (label == 'Compliance') {
      secondModel = 'tiny_lama';
      secondModelName = 'Tiny LLaMA';
    } else {
      secondModel = 't5';
      secondModelName = 'T5 Model';
    }

    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select a Model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              RadioListTile(
                activeColor: const Color.fromARGB(255, 78, 52, 46),
                title: Row(children: const [Icon(Icons.stars, color: Color.fromARGB(255, 78, 52, 46)), SizedBox(width: 8), Text('Gemini AI')]),
                value: 'gemini',
                groupValue: selectedModel,
                onChanged: (val) => setState(() => selectedModel = val!),
              ),
              RadioListTile(
                activeColor: const Color.fromARGB(255, 78, 52, 46),
                title: Row(children: [secondModelIcon, const SizedBox(width: 8), Text(secondModelName)]),
                value: secondModel,
                groupValue: selectedModel,
                onChanged: (val) => setState(() => selectedModel = val!),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 78, 52, 46), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, selectedModel),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoboModelInfo() {
  String selectedModel = 'gemini'; // default

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F2),
        title: const Text('🤖 RoboAI: Wanna know about the models?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _radioOption('Gemini AI', 'gemini', selectedModel, (val) {
              setState(() => selectedModel = val ?? 'gemini');
            }),
            _radioOption('T5 Base Model', 't5', selectedModel, (val) {
              setState(() => selectedModel = val ?? 't5');
            }),
            _radioOption('T5 Small Model', 't5_small', selectedModel, (val) {
              setState(() => selectedModel = val?? 't5_small');
            }),
            _radioOption('DistilBERT', 'distilbert', selectedModel, (val) {
              setState(() => selectedModel = val?? 'distilbert');
            }),
            _radioOption('Tiny LLaMA', 'tiny_lama', selectedModel, (val) {
              setState(() => selectedModel = val?? 'tiny_lama');
            }),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color.fromARGB(255, 97, 75, 53)),
            onPressed: () {
              Navigator.pop(context);
              _showModelInfo(selectedModel); // uses updated model
            },
            child: const Text('Tell me more!'),
          ),
        ],
      ),
    ),
  );
}
  Widget _radioOption(
        
      String title,
      String value,
      String selectedModel,
      void Function(String?) onChanged,
    ) {
      return RadioListTile<String>(
        activeColor: const Color.fromARGB(255, 97, 75, 53),
        title: Text(title),
        value: value,
        groupValue: selectedModel,
        onChanged: onChanged, // passes nullable String
      );
    }
      void _showModelInfo(String model) {
      String title;
      String info;

          switch (model) {
            case 'gemini':
              title = '🌟 Gemini 1.5 Flash';
              info = '''
        - Developed by Google DeepMind.
        - Multimodal: Works with text, code, images, and more.
        - Extremely fast and optimized for real-time applications.
        - Large context window: Can understand long documents.
        - Ideal for summarization, Q&A, chatbots, and RAG tasks.
        ''';
              break;

            case 't5':
              title = '🧠 T5 Base Model';
              info = '''
        - Developed by Google.
        - Text-to-Text architecture: Converts all NLP tasks to text form.
        - Good accuracy for summarization, classification, Q&A.
        - Pretrained on C4 dataset (Colossal Clean Crawled Corpus).
        - Offline & open-source compatible.
        ''';
              break;

            case 't5_small':
              title = '📄 T5 Small Model';
              info = '''
        - Light version of T5 (~60M parameters).
        - Fast and efficient, good for small Q&A tasks.
        - Less accurate than base but resource-friendly.
        - Suitable for edge and mobile deployments.
        ''';
              break;

            case 'distilbert':
              title = '📘 DistilBERT';
              info = '''
        - A smaller, faster version of BERT.
        - Retains 97% performance of BERT with 60% fewer parameters.
        - Well-suited for classification and sentiment analysis.
        - Very efficient and good for real-time prediction.
        ''';
              break;

            case 'tiny_lama':
              title = '🦙 Tiny LLaMA';
              info = '''
        - A miniature version of Meta’s LLaMA model.
        - Finetuned for compliance, safety, and policy checks.
        - Lightweight: Suitable for deployment on smaller machines.
        - Strong at understanding structured documents.
        ''';
              break;

            default:
              title = 'Unknown Model';
              info = 'No information available.';
          }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFFFF8F2),
          title: Text(title),
          content: SingleChildScrollView(child: Text(info)),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 97, 75, 53)),
                  label: const Text('Back', style: TextStyle(color: Color.fromARGB(255, 97, 75, 53))),
                  onPressed: () {
                    Navigator.pop(context);
                    _showRoboModelInfo(); // reopen model selection
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: const Color.fromARGB(255, 97, 75, 53)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cool!'),
                ),
          ],
        )
      ],
    ),
  );
}
}

