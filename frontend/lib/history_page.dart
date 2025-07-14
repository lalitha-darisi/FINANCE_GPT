import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class HistoryPage extends StatefulWidget {
  final String userId;
  const HistoryPage({super.key, required this.userId});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> complianceFuture;
  late Future<List<dynamic>> summarizationFuture;
  late Future<List<dynamic>> classificationFuture;
  late Future<List<dynamic>> qaFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    complianceFuture = fetchHistory('compliance');
    summarizationFuture = fetchHistory('summarization');
    classificationFuture = fetchHistory('classification');
    qaFuture = fetchHistory('qa');
  }

  Future<List<dynamic>> fetchHistory(String useCase) async {
    final endpoint = {
      'compliance': '/api/user/history/${widget.userId}',
      'summarization': '/api/user/history/summarization/${widget.userId}',
      'classification': '/api/user/history/classification/${widget.userId}',
      'qa': '/api/user/history/qa/${widget.userId}',
    }[useCase]!;

    final response = await http.get(Uri.parse('$baseUrl$endpoint'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load $useCase history');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4E342E)),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Card(
      color: Colors.white.withOpacity(0.9),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4E342E),
        title: const Text('Your History'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Compliance'),
            Tab(text: 'Summarization'),
            Tab(text: 'Classification'),
            Tab(text: 'Q&A'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildComplianceTab(),
          _buildSummarizationTab(),
          _buildClassificationTab(),
          _buildQATab(),
        ],
      ),
    );
  }

  Widget _buildComplianceTab() {
    return FutureBuilder<List<dynamic>>(
      future: complianceFuture,
      builder: (context, snapshot) => _buildListView(snapshot, (item) {
        final isCompliant = item['compliant'] == true;
        return _buildCard(children: [
          Row(children: [
            Icon(isCompliant ? Icons.check_circle : Icons.cancel,
                color: isCompliant ? Colors.green : Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item['claim_text'] ?? 'No claim text.', maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 10),
          Text('Matched Policies: ${item['matched_policies']?.length ?? 0}')
        ]);
      }, emptyText: "No compliance history found."),
    );
  }

  Widget _buildSummarizationTab() {
    return FutureBuilder<List<dynamic>>(
      future: summarizationFuture,
      builder: (context, snapshot) => _buildListView(snapshot, (item) {
        return _buildCard(children: [
          _buildSectionTitle("Excerpt"),
          Text(item['input_excerpt'] ?? 'No input excerpt.', maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          _buildSectionTitle("Summary"),
          Text(item['summary'] ?? 'No summary available.', maxLines: 6, overflow: TextOverflow.ellipsis),
        ]);
      }, emptyText: "No summarization history found."),
    );
  }

  Widget _buildClassificationTab() {
    return FutureBuilder<List<dynamic>>(
      future: classificationFuture,
      builder: (context, snapshot) => _buildListView(snapshot, (item) {
        return _buildCard(children: [
          Text("Detected Type: ${item['label'] ?? 'Unknown'}", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(item['masked_text'] ?? 'No masked content.', maxLines: 6, overflow: TextOverflow.ellipsis),
        ]);
      }, emptyText: "No classification history found."),
    );
  }

  Widget _buildQATab() {
    return FutureBuilder<List<dynamic>>(
      future: qaFuture,
      builder: (context, snapshot) => _buildListView(snapshot, (item) {
        return _buildCard(children: [
          _buildSectionTitle("Question"),
          Text(item['question'] ?? 'No question.'),
          const SizedBox(height: 10),
          _buildSectionTitle("Answer"),
          Text(item['answer'] ?? 'No answer.'),
        ]);
      }, emptyText: "No Q&A history found."),
    );
  }

  Widget _buildListView(AsyncSnapshot<List<dynamic>> snapshot, Widget Function(dynamic) itemBuilder, {required String emptyText}) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return Center(child: Text(emptyText));
    } else {
      final items = snapshot.data!;
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, index) => itemBuilder(items[index]),
      );
    }
  }
}
