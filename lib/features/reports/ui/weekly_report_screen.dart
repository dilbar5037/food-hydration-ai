import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../report_service.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final ReportService _reportService = ReportService();
  bool _isLoading = true;
  String? _errorMessage;
  WeeklyReport? _report;
  late final DateTime _rangeStart;
  late final DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _rangeEnd = DateTime.utc(now.year, now.month, now.day);
    _rangeStart = _rangeEnd.subtract(const Duration(days: 6));
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await _reportService.fetchWeeklyReport();
      if (!mounted) {
        return;
      }
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Failed to load report.';
        _report = WeeklyReport.empty(_rangeStart, _rangeEnd);
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf(WeeklyReport report) async {
    final doc = pw.Document();
    final dateRange =
        '${_formatDate(report.startDate)} - ${_formatDate(report.endDate)}';

    final topFoodsData = report.topFoods.isEmpty
        ? [
            ['No data', '']
          ]
        : report.topFoods
            .map((food) => [food.name, food.count.toString()])
            .toList();

    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Weekly Report',
              style: pw.TextStyle(fontSize: 20),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Date range: $dateRange'),
            pw.SizedBox(height: 16),
            pw.Text('Total Calories: ${report.totalCalories.toStringAsFixed(0)}'),
            pw.Text('Total Water: ${report.totalWaterMl} ml'),
            pw.Text(
              'Avg Calories/Day: ${report.avgCaloriesPerDay.toStringAsFixed(0)}',
            ),
            pw.Text(
              'Avg Water/Day: ${report.avgWaterPerDay.toStringAsFixed(0)} ml',
            ),
            pw.Text(
              'Avg Compliance: ${report.avgCompliance.toStringAsFixed(0)}%',
            ),
            pw.SizedBox(height: 16),
            pw.Text('Top Foods'),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Food', 'Count'],
              data: topFoodsData,
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  String _formatDate(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final report = _report ?? WeeklyReport.empty(_rangeStart, _rangeEnd);
    final dateRange =
        '${_formatDate(report.startDate)} - ${_formatDate(report.endDate)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date Range: $dateRange'),
            const SizedBox(height: 12),
            if (_errorMessage != null) Text(_errorMessage!),
            const SizedBox(height: 8),
            Text('Total Calories: ${report.totalCalories.toStringAsFixed(0)}'),
            Text('Total Water: ${report.totalWaterMl} ml'),
            Text(
              'Avg Calories/Day: ${report.avgCaloriesPerDay.toStringAsFixed(0)}',
            ),
            Text(
              'Avg Water/Day: ${report.avgWaterPerDay.toStringAsFixed(0)} ml',
            ),
            Text(
              'Avg Compliance: ${report.avgCompliance.toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 16),
            Text(
              'Top Foods',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: report.topFoods.isEmpty
                  ? const Text('No data')
                  : ListView.separated(
                      itemCount: report.topFoods.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final food = report.topFoods[index];
                        return ListTile(
                          title: Text(food.name),
                          trailing: Text(food.count.toString()),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : () => _exportPdf(report),
                child: _isLoading
                    ? const Text('Export PDF')
                    : const Text('Export PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
