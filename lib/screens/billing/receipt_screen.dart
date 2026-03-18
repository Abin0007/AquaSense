import 'dart:io';
import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ReceiptScreen extends StatelessWidget {
  final BillingInfo bill;
  final UserData userData;

  const ReceiptScreen({super.key, required this.bill, required this.userData});

  Future<void> _downloadPdfWithPicker(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final pdfBytes = await _generatePdf(PdfPageFormat.a4, bill, userData);
      final fileName = "receipt_${bill.id}.pdf";

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName: fileName,
        bytes: pdfBytes,
      );

      if (outputFile == null) {
        return; // User canceled
      }

      if (!scaffoldMessenger.mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Receipt saved successfully!')),
      );
    } catch (e) {
      if (!scaffoldMessenger.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to download receipt: $e')),
      );
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Preparing to share...')));

    final pdfBytes = await _generatePdf(PdfPageFormat.a4, bill, userData);
    final outputDir = await getTemporaryDirectory();
    final file = File("${outputDir.path}/receipt_${bill.id}.pdf");
    await file.writeAsBytes(pdfBytes);

    final xFile = XFile(file.path, mimeType: 'application/pdf');

    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: 'Here is my payment receipt for AquaSense.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              useActions: false,
              padding: EdgeInsets.zero,
              build: (format) => _generatePdf(format, bill, userData),
              pdfFileName: "receipt_${bill.id}.pdf",
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: const Color(0xFF152D4E),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download'),
                    onPressed: () => _downloadPdfWithPicker(context),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54)
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                    onPressed: () => _sharePdf(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<Uint8List> _generatePdf(
      PdfPageFormat format, BillingInfo bill, UserData userData) async {
    final doc = pw.Document(title: 'AquaSense Receipt');
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsBold();
    final lightFont = await PdfGoogleFonts.poppinsLight();
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/icon/app_icon.png')).buffer.asUint8List(),
    );

    final qrData = '''
AquaSense Payment Verification
---------------------------------
Bill ID: ${bill.id}
Payment ID: ${bill.paymentId ?? 'N/A'}
Amount: Rs. ${bill.amount.toStringAsFixed(2)}
Paid On: ${bill.paidAt != null ? DateFormat('d MMM yyyy, h:mm a').format(bill.paidAt!.toDate()) : 'N/A'}
Billed To: ${userData.name}
''';

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(30),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.cyan, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(logo, boldFont, lightFont),
                pw.SizedBox(height: 30),
                _buildCustomerInfo(userData, font, boldFont),
                pw.SizedBox(height: 30),
                pw.Text('Payment Details',
                    style: pw.TextStyle(font: boldFont, fontSize: 16)),
                pw.Divider(color: PdfColors.grey400),
                _buildDetailsTable(bill, font),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 20),
                _buildTotal(bill, boldFont),
                pw.Spacer(),
                _buildFooter(font, qrData, bill.wasPaidLate),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader(pw.MemoryImage logo, pw.Font boldFont, pw.Font lightFont) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(children: [
          pw.Image(logo, width: 40, height: 40),
          pw.SizedBox(width: 10),
          pw.Text('AquaSense',
              style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.cyan)),
        ]),
        pw.Text('Official Receipt',
            style: pw.TextStyle(font: lightFont, fontSize: 16, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _buildCustomerInfo(
      UserData userData, pw.Font font, pw.Font boldFont) {
    return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BILLED TO', style: pw.TextStyle(font: font, color: PdfColors.grey, fontSize: 10)),
                pw.Text(userData.name, style: pw.TextStyle(font: boldFont, fontSize: 12)),
                pw.Text(userData.email, style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Text('Ward: ${userData.wardId}', style: pw.TextStyle(font: font, fontSize: 10)),
              ])
        ]);
  }

  pw.Table _buildDetailsTable(BillingInfo bill, pw.Font font) {
    final paidOn = bill.paidAt != null
        ? DateFormat('d MMM yyyy, h:mm a').format(bill.paidAt!.toDate())
        : 'N/A';

    final List<List<String>> data = [
      ['Bill Period', DateFormat('MMMM yyyy').format(bill.date.toDate())],
      ['Bill Amount', '₹${bill.amount.toStringAsFixed(2)}'],
      if (bill.fineAmount != null && bill.fineAmount! > 0)
        ['Late Fee / Fine', '₹${bill.fineAmount!.toStringAsFixed(2)}'],
      ['Water Usage', '${bill.reading} m³'],
      ['Payment ID', bill.paymentId ?? 'N/A'],
      ['Paid On', paidOn],
    ];

    return pw.TableHelper.fromTextArray(
      cellStyle: pw.TextStyle(font: font, fontSize: 10),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      headers: ['DESCRIPTION', 'DETAILS'],
      data: data,
      border: null,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan100),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {1: pw.Alignment.centerRight},
    );
  }

  pw.Widget _buildTotal(BillingInfo bill, pw.Font boldFont) {
    final totalPaid = bill.amount + (bill.fineAmount ?? 0.0);
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Container(
            padding:
            const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const pw.BoxDecoration(
                color: PdfColors.green100,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(5))),
            child: pw.Text('PAID',
                style: pw.TextStyle(font: boldFont, color: PdfColors.green800)),
          ),
          pw.Text(
            'Total Paid: ₹${totalPaid.toStringAsFixed(2)}',
            style: pw.TextStyle(font: boldFont, fontSize: 16),
          ),
        ]);
  }

  pw.Widget _buildFooter(pw.Font font, String qrData, bool wasPaidLate) {
    final message = wasPaidLate
        ? 'Payment received. Thank you.'
        : 'Thank you for your timely payment.';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          '$message\nGenerated on ${DateFormat('d MMM yyyy').format(DateTime.now())}',
          style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey),
        ),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: qrData,
          width: 60,
          height: 60,
        ),
      ],
    );
  }
}