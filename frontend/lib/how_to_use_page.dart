import 'package:flutter/material.dart';

class HowToUsePage extends StatelessWidget {
  const HowToUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E342E),
        title: const Text('📘 How to Use', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: const [
            Text(
              'Welcome to Finance GPT!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4E342E)),
            ),
            SizedBox(height: 16),
            Text(
              '💡 General Instructions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Select a use case from the home page: Summarization, Q&A, Classification, or Compliance.'),
            Text('2. Choose a model for the selected use case (e.g., Gemini, T5, etc.).'),
            Text('3. Upload a PDF or paste plain text as input.'),
            Text('4. Submit the input to view results instantly.'),
            SizedBox(height: 20),

            Text(
              '📄 Summarization:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('• Purpose: Get short, detailed, or financial-only summaries from documents.'),
            Text('• Input: Upload a financial PDF or paste text.'),
            Text('• Choose summary type after uploading.'),
            SizedBox(height: 20),

            Text(
              '❓ Q&A:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('• Purpose: Ask questions about your document content.'),
            Text('• Input: Upload PDF or paste text.'),
            Text('• After upload, type your question and submit to get answers.'),
            SizedBox(height: 20),

            Text(
              '🗂️ Classification:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('• Purpose: Detect the type of document (e.g., invoice, claim, etc.).'),
            Text('• Input: Upload PDF or paste any document text.'),
            Text('• The model classifies and gives back the category.'),
            SizedBox(height: 20),

            Text(
              '✅ Compliance:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('• Purpose: Check if travel or business claims follow policy.'),
            Text('• Input: Upload claim PDF or paste claim description as text.'),
            Text('• Output includes compliance status (Compliant/Non-Compliant), matched policy, and reason.'),
            SizedBox(height: 20),

            Text(
              '📚 History:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('• Access your past interactions anytime from the top-right profile menu.'),
            Text('• You can revisit previous summaries, Q&A, classification, or compliance results.'),
            SizedBox(height: 20),

            Text(
              '🙋 Need Help?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('• Use the robot icon on the home page to learn about models and what they are best for.'),
            Text('• For any confusion, revisit this page from the top-right profile menu.'),
          ],
        ),
      ),
    );
  }
}
