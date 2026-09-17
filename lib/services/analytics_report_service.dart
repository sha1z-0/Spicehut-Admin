import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math' as math;

class AnalyticsReportService {
  static Future<void> generateAndPrintReport({
    required String branchName,
    required Map<String, dynamic> data,
  }) async {
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    final logoBytes = await rootBundle.load('assets/logo/spicehut_logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final counts = (data['counts'] as Map?) ?? {};
    final countsToday = (data['countsToday'] as Map?) ?? {};
    final sales = (data['sales'] as Map?) ?? {};
    final topItems = (data['topItems'] as List?) ?? [];
    final inHouseData = (data['inHouse'] as Map?) ?? {};
    final inHouseTopItems = (inHouseData['topItems'] as List?) ?? [];
    final todayVoidedByUser = (inHouseData['todayVoidedByUser'] as List?) ?? [];
    final monthVoidedByUser = (inHouseData['monthVoidedByUser'] as List?) ?? [];

    final totalOrders = _num(counts['total']);
    final acceptedOrders = _num(counts['accepted']);
    final rejectedOrders = _num(counts['rejected']);
    final completedOrders = _num(counts['completed']);
    final failedOrders = _num(counts['failed']);

    final totalOrdersToday = _num(countsToday['total']);
    final acceptedOrdersToday = _num(countsToday['accepted']);
    final rejectedOrdersToday = _num(countsToday['rejected']);
    final completedOrdersToday = _num(countsToday['completed']);
    final failedOrdersToday = _num(countsToday['failed']);

    final salesToday = _num(sales['today']);
    final salesYesterday = _num(sales['yesterday']);
    final salesThisMonth = _num(sales['month']);
    final salesLastMonth = _num(sales['lastMonth']);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logoImage, width: 64, height: 64),
              pw.SizedBox(height: 8),
              pw.Text(
                'SpiceHut',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Analytics Report - $branchName',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _sectionTitle('Order Summary (Today)'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Metric', 'Value'],
            data: [
              ['Total Orders Received', totalOrdersToday.toStringAsFixed(0)],
              ['Orders Accepted', acceptedOrdersToday.toStringAsFixed(0)],
              ['Orders Rejected', rejectedOrdersToday.toStringAsFixed(0)],
              ['Orders Completed', completedOrdersToday.toStringAsFixed(0)],
              ['Orders Failed', failedOrdersToday.toStringAsFixed(0)],
            ],
          ),
          pw.SizedBox(height: 8),
          _completedFailedDonut(
            completedOrders: completedOrdersToday,
            failedOrders: failedOrdersToday,
          ),
          pw.SizedBox(height: 16),
          pw.NewPage(freeSpace: 220),
          _sectionTitle('Order Summary (Monthly)'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Metric', 'Value'],
            data: [
              ['Total Orders Received', totalOrders.toStringAsFixed(0)],
              ['Orders Accepted', acceptedOrders.toStringAsFixed(0)],
              ['Orders Rejected', rejectedOrders.toStringAsFixed(0)],
              ['Orders Completed', completedOrders.toStringAsFixed(0)],
              ['Orders Failed', failedOrders.toStringAsFixed(0)],
            ],
          ),
          pw.SizedBox(height: 8),
          _completedFailedDonut(
            completedOrders: completedOrders,
            failedOrders: failedOrders,
          ),
          pw.SizedBox(height: 10),
          pw.NewPage(freeSpace: 230),
          _sectionTitle('Sales Performance'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Metric', 'Value'],
            data: [
              ['Total Sales Today', _money(salesToday)],
              ['Total Sales This Month', _money(salesThisMonth)],
            ],
          ),
          pw.SizedBox(height: 6),
          _barComparison(
            title: "Today's vs Yesterday's Sales",
            leftLabel: 'Yesterday',
            leftValue: salesYesterday,
            rightLabel: 'Today',
            rightValue: salesToday,
          ),
          pw.SizedBox(height: 4),
          _barComparison(
            title: 'This Month vs Last Month Sales',
            leftLabel: 'Last Month',
            leftValue: salesLastMonth,
            rightLabel: 'This Month',
            rightValue: salesThisMonth,
          ),
          pw.SizedBox(height: 16),
          pw.NewPage(freeSpace: 160),
          _sectionTitle('Top Ordered Items'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Rank', 'Item Name', 'Orders'],
            data: topItems.take(3).map<List<String>>((item) {
              final map = item as Map<String, dynamic>;
              return [
                (map['rank'] ?? '').toString(),
                (map['name'] ?? 'Unknown').toString(),
                (map['quantity'] ?? 0).toString(),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 24),
          pw.NewPage(freeSpace: 240),
          _sectionTitle('In-House Orders (Today)'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Metric', 'Value'],
            data: [
              ['Total Orders', _num(inHouseData['todayOrders']).toStringAsFixed(0)],
              ['Revenue', _money(_num(inHouseData['todayRevenue']))],
              ['Cash Payments', _money(_num(inHouseData['todayCash']))],
              ['Card Payments', _money(_num(inHouseData['todayCard']))],
              ['Voided Orders', _num(inHouseData['todayVoided']).toStringAsFixed(0)],
              ['Total Tips', _money(_num(inHouseData['todayTips']))],
              ['Cash Tips', _money(_num(inHouseData['todayCashTips']))],
              ['Card Tips', _money(_num(inHouseData['todayCardTips']))],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.NewPage(freeSpace: 240),
          _sectionTitle('In-House Orders (Monthly)'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Metric', 'Value'],
            data: [
              ['Total Orders', _num(inHouseData['monthOrders']).toStringAsFixed(0)],
              ['Revenue', _money(_num(inHouseData['monthRevenue']))],
              ['Cash Payments', _money(_num(inHouseData['monthCash']))],
              ['Card Payments', _money(_num(inHouseData['monthCard']))],
              ['Voided Orders', _num(inHouseData['monthVoided']).toStringAsFixed(0)],
              ['Total Tips', _money(_num(inHouseData['monthTips']))],
              ['Cash Tips', _money(_num(inHouseData['monthCashTips']))],
              ['Card Tips', _money(_num(inHouseData['monthCardTips']))],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.NewPage(freeSpace: 230),
          _sectionTitle('In-House Voided Orders by User'),
          if (monthVoidedByUser.isEmpty)
            pw.Text('No voided orders yet', style: const pw.TextStyle(fontSize: 10))
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headers: const ['User', 'Today', 'Month'],
              data: () {
                final todayMap = <String, int>{};
                for (final row in todayVoidedByUser) {
                  final map = (row as Map).cast<String, dynamic>();
                  final user = (map['user'] ?? 'Unknown').toString();
                  todayMap[user] = _num(map['count']).toInt();
                }

                return monthVoidedByUser.take(10).map<List<String>>((row) {
                  final map = (row as Map).cast<String, dynamic>();
                  final user = (map['user'] ?? 'Unknown').toString();
                  final monthCount = _num(map['count']).toInt();
                  final todayCount = todayMap[user] ?? 0;
                  return [user, todayCount.toString(), monthCount.toString()];
                }).toList();
              }(),
            ),
          pw.SizedBox(height: 16),
          pw.NewPage(freeSpace: 160),
          _sectionTitle('Top In-House Items'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Rank', 'Item Name', 'Orders'],
            data: inHouseTopItems.take(3).map<List<String>>((item) {
              final map = item as Map<String, dynamic>;
              return [
                (map['rank'] ?? '').toString(),
                (map['name'] ?? 'Unknown').toString(),
                (map['quantity'] ?? 0).toString(),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.NewPage(freeSpace: 140),
          _sectionTitle('On-Call Takeaway Orders'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Period', 'Orders', 'Revenue'],
            data: [
              ['Today', _num(inHouseData['todayOnCallTakeaway']).toStringAsFixed(0), _money(_num(inHouseData['todayOnCallTakeawayRevenue']))],
              ['Month', _num(inHouseData['monthOnCallTakeaway']).toStringAsFixed(0), _money(_num(inHouseData['monthOnCallTakeawayRevenue']))],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.NewPage(freeSpace: 140),
          _sectionTitle('On-Call Delivery Orders'),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const ['Period', 'Orders', 'Revenue'],
            data: [
              ['Today', _num(inHouseData['todayOnCallDelivery']).toStringAsFixed(0), _money(_num(inHouseData['todayOnCallDeliveryRevenue']))],
              ['Month', _num(inHouseData['monthOnCallDelivery']).toStringAsFixed(0), _money(_num(inHouseData['monthOnCallDeliveryRevenue']))],
            ],
          ),
        ],
      ),
    );

    final pdfData = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => pdfData);
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _barComparison({
    required String title,
    required String leftLabel,
    required double leftValue,
    required String rightLabel,
    required double rightValue,
  }) {
    final safeLeft = _safeDouble(leftValue);
    final safeRight = _safeDouble(rightValue);
    final double maxValue = safeLeft > safeRight ? safeLeft : safeRight;
    final double safeMax = maxValue > 0 ? maxValue : 1;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 4),
        _barRow(leftLabel, safeLeft, safeMax),
        _barRow(rightLabel, safeRight, safeMax),
      ],
    );
  }

  static pw.Widget _barRow(String label, double value, double maxValue) {
    final safeValue = _safeDouble(value);
    final safeMax = _safeDouble(maxValue, fallback: 1);
    final widthFactor = (safeValue / safeMax).clamp(0.0, 1.0);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Expanded(
            child: pw.Container(
              height: 6,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  height: 6,
                  width: 200 * widthFactor,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(_money(safeValue), style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _completedFailedDonut({
    required double completedOrders,
    required double failedOrders,
  }) {
    final completed = _safeDouble(completedOrders);
    final failed = _safeDouble(failedOrders);
    final total = completed + failed;
    final completedPct = total > 0 ? (completed / total) * 100 : 0;
    final failedPct = total > 0 ? (failed / total) * 100 : 0;

    const size = 130.0;
    const holeSize = 70.0;

    // Build datasets only for non-zero values
    final datasets = <pw.PieDataSet>[];
    if (completed > 0) {
      datasets.add(pw.PieDataSet(
        value: completed,
        color: PdfColors.orange,
        legend: '',
      ));
    }
    if (failed > 0) {
      datasets.add(pw.PieDataSet(
        value: failed,
        color: PdfColors.red,
        legend: '',
      ));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _sectionTitle('Completed vs Failed'),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Container(
            width: size,
            height: size,
            child: total == 0
                ? pw.Center(
                    child: pw.Text(
                      'No data',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                  )
                : pw.Stack(
                    children: [
                      pw.Transform.rotate(
                        angle: math.pi / 2,
                        child: pw.Chart(
                          grid: pw.PieGrid(),
                          datasets: datasets,
                        ),
                      ),
                      pw.Align(
                        alignment: pw.Alignment.center,
                        child: pw.Container(
                          width: holeSize,
                          height: holeSize,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                      ),
                      // Center label when only failed exists
                      if (completed == 0 && failed > 0)
                        pw.Positioned(
                          left: 0,
                          right: 0,
                          top: 30,
                          child: pw.Center(
                            child: pw.Text(
                              '${failedPct.toStringAsFixed(0)}%',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),
                      // Center label when only completed exists
                      if (failed == 0 && completed > 0)
                        pw.Positioned(
                          left: 0,
                          right: 0,
                          top: 30,
                          child: pw.Center(
                            child: pw.Text(
                              '${completedPct.toStringAsFixed(0)}%',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),
                      // Completed label - top position (when both exist)
                      if (completed > 0 && failed > 0)
                        pw.Positioned(
                          top: 15,
                          left: 0,
                          right: 0,
                          child: pw.Center(
                            child: pw.Text(
                              '${completedPct.toStringAsFixed(0)}%',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),
                      // Failed label - bottom position (when both exist)
                      if (completed > 0 && failed > 0)
                        pw.Positioned(
                          bottom: 15,
                          left: 0,
                          right: 0,
                          child: pw.Center(
                            child: pw.Text(
                              '${failedPct.toStringAsFixed(0)}%',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: 160,
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(children: [
                    pw.Container(width: 8, height: 8, decoration: const pw.BoxDecoration(color: PdfColors.orange, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 6),
                    pw.Text('Completed', style: const pw.TextStyle(fontSize: 10)),
                  ]),
                  pw.Text(completed.toStringAsFixed(0), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(children: [
                    pw.Container(width: 8, height: 8, decoration: const pw.BoxDecoration(color: PdfColors.red, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 6),
                    pw.Text('Failed', style: const pw.TextStyle(fontSize: 10)),
                  ]),
                  pw.Text(failed.toStringAsFixed(0), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _money(double value) => '\$${_safeDouble(value).toStringAsFixed(2)}';

  static double _num(dynamic value) {
    if (value is num) return _safeDouble(value.toDouble());
    return 0;
  }

  static double _safeDouble(double value, {double fallback = 0}) {
    if (value.isNaN || value.isInfinite) return fallback;
    return value;
  }
}

