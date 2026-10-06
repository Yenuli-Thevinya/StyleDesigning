import 'package:flutter/material.dart';
import '../models/contract.dart';
import '../models/quote.dart';
import '../services/quotes_contracts_service.dart';
import '../theme/qc_theme.dart';
import 'status_badge.dart';

class ContractDetailBottomSheet extends StatefulWidget {
  final Contract contract;
  final VoidCallback? onSign;
  final VoidCallback? onCancel;

  const ContractDetailBottomSheet({
    super.key,
    required this.contract,
    this.onSign,
    this.onCancel,
  });

  static Future<void> show(
    BuildContext context, {
    required Contract contract,
    VoidCallback? onSign,
    VoidCallback? onCancel,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContractDetailBottomSheet(
        contract: contract,
        onSign: onSign,
        onCancel: onCancel,
      ),
    );
  }

  @override
  State<ContractDetailBottomSheet> createState() => _ContractDetailBottomSheetState();
}

class _ContractDetailBottomSheetState extends State<ContractDetailBottomSheet> {
  late Contract _contract;
  Quote? _quote;
  bool _isLoadingQuote = false;

  @override
  void initState() {
    super.initState();
    _contract = widget.contract;
    _quote = widget.contract.quote;

    if ((_quote == null || _quote!.items.isEmpty) && _contract.quoteId != null) {
      _loadLinkedQuote();
    }
  }

  Future<void> _loadLinkedQuote() async {
    setState(() => _isLoadingQuote = true);
    try {
      final fetchedQuote = await QuotesContractsService().getQuote(_contract.quoteId!);
      if (mounted && fetchedQuote != null) {
        setState(() {
          _quote = fetchedQuote;
          _isLoadingQuote = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingQuote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStr = _contract.status.toLowerCase();
    final canCancel = statusStr != 'completed' && statusStr != 'cancelled';
    final isSigned = _contract.signedAt != null;
    final quote = _quote ?? _contract.quote;

    final quoteIdStr = _contract.quoteId ?? quote?.id ?? 'f315971a';
    final shortQuoteId = quoteIdStr.length > 8 ? quoteIdStr.substring(0, 8) : quoteIdStr;
    final projectIdStr = _contract.projectRequestId ?? quote?.projectRequestId ?? '7c88187a-7133-4fd2';

    return Container(
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
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: QcTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Title & Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Contract details',
                        style: QcTheme.serifTitle(fontSize: 24),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF24201D),
                          border: Border.all(color: QcTheme.borderLight, width: 1),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, size: 16, color: QcTheme.textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Status Badge
                  StatusBadge(status: _contract.status, isLarge: true),
                  const SizedBox(height: 8),

                  // Subtitle: Contract ID & Linked quote
                  Text(
                    'Contract ID: ${_contract.id} · Linked quote: $shortQuoteId',
                    style: const TextStyle(
                      color: QcTheme.textMuted,
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2x2 Grid of Overview Cards (Matching Images 3 & 5)
                  Row(
                    children: [
                      // Card 1: AGREED AMOUNT
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: QcTheme.surfaceSunken,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: QcTheme.border, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AGREED AMOUNT',
                                style: TextStyle(
                                  color: QcTheme.textSubtle,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                QcTheme.formatCurrency(_contract.totalAmount),
                                style: const TextStyle(
                                  color: QcTheme.gold,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Card 2: SIGNATURE STATUS
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: QcTheme.surfaceSunken,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: QcTheme.border, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SIGNATURE STATUS',
                                style: TextStyle(
                                  color: QcTheme.textSubtle,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isSigned
                                    ? 'Signed (${QcTheme.formatDate(_contract.signedAt)})'
                                    : 'Pending signature',
                                style: TextStyle(
                                  color: isSigned ? const Color(0xFF34D399) : const Color(0xFFF59E0B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Card 3: PROJECT / REQUEST
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: QcTheme.surfaceSunken,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: QcTheme.border, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PROJECT / REQUEST',
                                style: TextStyle(
                                  color: QcTheme.textSubtle,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                projectIdStr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: QcTheme.textMain,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Card 4: CREATED DATE
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: QcTheme.surfaceSunken,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: QcTheme.border, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CREATED DATE',
                                style: TextStyle(
                                  color: QcTheme.textSubtle,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                QcTheme.formatDate(_contract.createdAt),
                                style: const TextStyle(
                                  color: QcTheme.textMain,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Fully submitted quote details Section Header
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, color: QcTheme.textMain, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Fully submitted quote details',
                        style: QcTheme.serifTitle(fontSize: 18),
                      ),
                      if (_isLoadingQuote) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: QcTheme.gold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Scope of Work & Design Description Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: QcTheme.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: QcTheme.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SCOPE OF WORK & DESIGN DESCRIPTION',
                          style: TextStyle(
                            color: QcTheme.textSubtle,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          quote?.scopeSummary ?? _contract.termsSummary ?? 'Minimalist bedroom redesign with furniture, lighting and wall finishing',
                          style: const TextStyle(
                            color: QcTheme.textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        if (quote?.notes != null && quote!.notes!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x1FC48A36),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFC48A36), width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Designer notes & specifications:',
                                  style: TextStyle(
                                    color: QcTheme.gold,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  quote.notes!,
                                  style: const TextStyle(
                                    color: QcTheme.textMuted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Itemized Quote Items
                  if (quote != null && quote.items.isNotEmpty) ...[
                    ...quote.items.map((it) {
                      final categoryColor = QcTheme.getCategoryColor(it.category);
                      final lineTotal = it.lineTotal > 0 ? it.lineTotal : it.calculatedTotal;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: QcTheme.surfaceSunken,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: QcTheme.border, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Category Pill & Qty
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: categoryColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: categoryColor.withAlpha(100), width: 0.8),
                                  ),
                                  child: Text(
                                    it.category,
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Qty ${it.quantity}',
                                  style: const TextStyle(
                                    color: QcTheme.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Item Name / Description
                            Text(
                              it.description,
                              style: const TextStyle(
                                color: QcTheme.textMain,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 2-Tile Breakdown: UNIT PRICE & LINE TOTAL
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF191614),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: QcTheme.borderSubtle, width: 0.8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'UNIT PRICE',
                                          style: TextStyle(
                                            color: QcTheme.textSubtle,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          QcTheme.formatCurrency(it.unitCost),
                                          style: const TextStyle(
                                            color: QcTheme.textMain,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF191614),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: QcTheme.borderSubtle, width: 0.8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'LINE TOTAL',
                                          style: TextStyle(
                                            color: QcTheme.textSubtle,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          QcTheme.formatCurrency(lineTotal),
                                          style: const TextStyle(
                                            color: QcTheme.textMain,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    // Total Submitted Quote Amount (Matching Image 4)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.centerRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'TOTAL SUBMITTED QUOTE AMOUNT',
                            style: TextStyle(
                              color: QcTheme.textSubtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            QcTheme.formatCurrency(_contract.totalAmount),
                            style: const TextStyle(
                              color: QcTheme.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Legal Terms Section (Matching Image 4)
                  Row(
                    children: [
                      Container(
                        width: 3.5,
                        height: 18,
                        decoration: BoxDecoration(
                          color: QcTheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Contract agreement & legal terms',
                        style: QcTheme.serifTitle(fontSize: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: QcTheme.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: QcTheme.border, width: 1),
                    ),
                    child: Text(
                      _contract.terms ??
                          'Official StyleSync Binding Agreement for ${_contract.termsSummary ?? "Minimalist bedroom redesign with furniture, lighting and wall finishing"}. Payments follow the standard milestone schedule: 50% advance deposit due upon signing, and 50% balance upon final quality inspection and room handover. All work is guaranteed under StyleSync Designer Quality Assurance.',
                      style: const TextStyle(color: QcTheme.textMuted, fontSize: 12, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Sticky Bottom Action Bar (Matching Images 3, 4, 5)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: QcTheme.surface,
              border: Border(top: BorderSide(color: QcTheme.border, width: 1)),
            ),
            child: Row(
              children: [
                if (!isSigned && widget.onSign != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onSign?.call();
                      },
                      icon: const Icon(Icons.draw, size: 16, color: Colors.white),
                      label: const Text(
                        'Sign contract',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QcTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (canCancel) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onCancel?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1414),
                        foregroundColor: const Color(0xFFF87171),
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel contract',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFFF87171),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF24201D),
                    foregroundColor: QcTheme.textMain,
                    side: const BorderSide(color: QcTheme.borderLight, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
