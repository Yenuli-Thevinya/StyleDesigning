import 'package:flutter/material.dart';
import '../models/quote.dart';
import '../theme/qc_theme.dart';
import 'status_badge.dart';

class QuoteDetailBottomSheet extends StatelessWidget {
  final Quote quote;
  final Function(String action, String? feedback)? onStage2Decision;
  final Function(String format)? onExport;

  const QuoteDetailBottomSheet({
    super.key,
    required this.quote,
    this.onStage2Decision,
    this.onExport,
  });

  static Future<void> show(
    BuildContext context, {
    required Quote quote,
    Function(String action, String? feedback)? onStage2Decision,
    Function(String format)? onExport,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuoteDetailBottomSheet(
        quote: quote,
        onStage2Decision: onStage2Decision,
        onExport: onExport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusStr = quote.status.toLowerCase();
    final isReleased = statusStr == 'stage1released' || statusStr == 'clientreview' || statusStr == 'submitted';
    final currentVer = quote.currentVersion;

    return Container(
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: QcTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: QcTheme.border, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: QcTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Quote Specification', style: QcTheme.serifTitle(fontSize: 20)),
                                const SizedBox(width: 8),
                                StatusBadge(status: quote.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              quote.scopeSummary,
                              style: const TextStyle(color: QcTheme.textMain, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            if (currentVer != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Version ${currentVer.versionNumber} • Updated by ${currentVer.authorRole}',
                                style: const TextStyle(color: QcTheme.gold, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: QcTheme.textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (quote.notes != null && quote.notes!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: QcTheme.surfaceSunken,
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(left: BorderSide(color: QcTheme.primary, width: 3.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SPECIFICATION NOTES:', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(quote.notes!, style: const TextStyle(color: QcTheme.textMuted, fontSize: 12.5, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quotation Engine Computed Breakdown
                  if (currentVer != null) ...[
                    const Text('Quotation Engine Breakdown', style: TextStyle(color: QcTheme.textMain, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: QcTheme.surfaceSunken,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: QcTheme.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          _buildCostRow('Materials Subtotal', currentVer.materialsSubtotal),
                          _buildCostRow('Labor Subtotal', currentVer.laborSubtotal),
                          _buildCostRow('Design Fee (10%)', currentVer.designFee),
                          _buildCostRow('Contingency (5%)', currentVer.contingencyAmount),
                          _buildCostRow('Tax / VAT (8%)', currentVer.taxAmount),
                          const Divider(color: QcTheme.borderSubtle, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Quote Cost:', style: TextStyle(color: QcTheme.textMain, fontSize: 13, fontWeight: FontWeight.w700)),
                              Text(
                                QcTheme.formatCurrency(currentVer.totalCost),
                                style: const TextStyle(color: QcTheme.gold, fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Line Items section
                  const Text('Itemized Line Items', style: TextStyle(color: QcTheme.textMain, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: QcTheme.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: QcTheme.border),
                    ),
                    child: Column(
                      children: [
                        ...((currentVer?.items ?? []).isNotEmpty
                            ? currentVer!.items.map((item) => _buildItemTile(item.description, item.category, item.quantity, item.unitCost, item.lineTotal))
                            : quote.items.map((item) => _buildItemTile(item.description, item.category, item.quantity, item.unitCost, item.calculatedTotal))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prior Version History if multiple versions exist
                  if (quote.versions.length > 1) ...[
                    const Text('Prior Version History', style: TextStyle(color: QcTheme.textMain, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...quote.versions.where((v) => v.versionNumber != currentVer?.versionNumber).map((v) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: QcTheme.surfaceSunken,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: QcTheme.borderSubtle),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Version ${v.versionNumber} (${v.authorRole})', style: const TextStyle(color: QcTheme.textMuted, fontSize: 12)),
                          Text(QcTheme.formatCurrency(v.totalCost), style: const TextStyle(color: QcTheme.textMain, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],

                  // Export & Action Buttons
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download, size: 16),
                        label: const Text('Export CSV'),
                        onPressed: onExport != null ? () => onExport!('csv') : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: QcTheme.textMain,
                          side: const BorderSide(color: QcTheme.borderLight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('Export PDF'),
                        onPressed: onExport != null ? () => onExport!('pdf') : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: QcTheme.textMain,
                          side: const BorderSide(color: QcTheme.borderLight),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stage 2 Client Decision Actions
                  if (isReleased && onStage2Decision != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onStage2Decision!('Approve', null);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QcTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Approve Quote', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onStage2Decision!('RequestChanges', 'Client requested scope adjustments.');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: QcTheme.textMain,
                              backgroundColor: QcTheme.surfaceSunken,
                              side: const BorderSide(color: QcTheme.borderLight),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Request Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.thumb_down_outlined, color: Colors.redAccent),
                          tooltip: 'Reject Proposal',
                          onPressed: () {
                            Navigator.of(context).pop();
                            onStage2Decision!('Reject', 'Declined by client.');
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String title, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: QcTheme.textMuted, fontSize: 12)),
          Text(QcTheme.formatCurrency(amount), style: const TextStyle(color: QcTheme.textMain, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildItemTile(String desc, String category, int qty, double unitCost, double total) {
    final catColor = QcTheme.getCategoryColor(category);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: QcTheme.borderSubtle))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(category, style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: const TextStyle(color: QcTheme.textMain, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Qty: $qty × ${QcTheme.formatCurrency(unitCost)}',
                  style: const TextStyle(color: QcTheme.textSubtle, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            QcTheme.formatCurrency(total),
            style: const TextStyle(color: QcTheme.textMain, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
