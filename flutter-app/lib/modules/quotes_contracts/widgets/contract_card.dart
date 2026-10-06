import 'package:flutter/material.dart';
import '../models/contract.dart';
import '../theme/qc_theme.dart';
import 'status_badge.dart';

class ContractCard extends StatelessWidget {
  final Contract contract;
  final VoidCallback? onCancel;
  final VoidCallback? onSign;
  final VoidCallback? onTap;

  const ContractCard({
    super.key,
    required this.contract,
    this.onCancel,
    this.onSign,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusStr = contract.status.toLowerCase();
    final isCancelled = statusStr == 'cancelled';
    final isSigned = contract.signedAt != null;
    final canCancel = !isCancelled && statusStr != 'completed';

    final shortId = 'ID: ${contract.id.length >= 6 ? contract.id.substring(0, 6) : contract.id}..';
    final quoteIdStr = contract.quoteId ?? contract.quote?.id;
    final shortQuoteId = quoteIdStr != null
        ? (quoteIdStr.length > 8 ? quoteIdStr.substring(0, 8) : quoteIdStr)
        : null;
    final quoteItemsCount = contract.quote?.items.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: QcTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QcTheme.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Status Badge & Contract ID
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusBadge(status: contract.status),
                    Text(
                      shortId,
                      style: const TextStyle(
                        color: QcTheme.textSubtle,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title (termsSummary or quote scopeSummary)
                Text(
                  contract.termsSummary ?? contract.quote?.scopeSummary ?? 'Minimalist bedroom redesign with furniture, lighting and wall finishing',
                  style: const TextStyle(
                    color: QcTheme.textMain,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Linked Quote Tag & AI Draft Tag (Matching Image 2)
                if (shortQuoteId != null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x1FC48A36),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.description_outlined, size: 13, color: QcTheme.gold),
                            const SizedBox(width: 4),
                            Text(
                              'Quote: $shortQuoteId ($quoteItemsCount items)',
                              style: const TextStyle(
                                color: QcTheme.gold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (contract.quote?.isAiGenerated == true) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x1FC48A36),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x66C48A36), width: 0.8),
                          ),
                          child: const Text(
                            'AI DRAFT',
                            style: TextStyle(
                              color: QcTheme.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  const SizedBox(height: 6),
                ],

                // AMOUNT & SIGNED Row
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AMOUNT',
                            style: TextStyle(
                              color: QcTheme.textSubtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            QcTheme.formatCurrency(contract.totalAmount),
                            style: const TextStyle(
                              color: QcTheme.gold,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SIGNED',
                            style: TextStyle(
                              color: QcTheme.textSubtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSigned ? QcTheme.formatDate(contract.signedAt) : '—',
                            style: TextStyle(
                              color: isSigned ? QcTheme.textMain : QcTheme.textSubtle,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // UPDATED Row
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UPDATED',
                      style: TextStyle(
                        color: QcTheme.textSubtle,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      QcTheme.formatDate(contract.updatedAt ?? contract.createdAt),
                      style: const TextStyle(
                        color: QcTheme.textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF24201D),
                          foregroundColor: QcTheme.textMain,
                          side: const BorderSide(color: QcTheme.borderLight, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: const Text(
                          'View details',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    if (!isSigned && onSign != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onSign,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: QcTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          child: const Text(
                            'Sign',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    if (canCancel) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1414),
                          foregroundColor: const Color(0xFFF87171),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFFF87171),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
