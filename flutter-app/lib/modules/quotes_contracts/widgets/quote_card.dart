import 'package:flutter/material.dart';
import '../models/quote.dart';
import '../theme/qc_theme.dart';
import 'status_badge.dart';

class QuoteCard extends StatelessWidget {
  final Quote quote;
  final VoidCallback? onEdit;
  final VoidCallback? onSubmit;
  final VoidCallback? onAccept;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const QuoteCard({
    super.key,
    required this.quote,
    this.onEdit,
    this.onSubmit,
    this.onAccept,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusStr = quote.status.toLowerCase();
    final isDraft = statusStr == 'draft';
    final isSubmitted = statusStr == 'submitted' || statusStr == 'clientreview';

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
                // Top row: Status Badge & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusBadge(status: quote.status),
                    Text(
                      QcTheme.formatDate(quote.createdAt ?? DateTime.now(), short: true),
                      style: const TextStyle(
                        color: QcTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title / Scope Summary
                Text(
                  quote.scopeSummary.isEmpty ? 'Untitled Scope' : quote.scopeSummary,
                  style: const TextStyle(
                    color: QcTheme.textMain,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // AI Draft Tag & Fallback Note
                if (quote.isAiGenerated) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: QcTheme.primary, width: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0x1AC48A36),
                    ),
                    child: const Text(
                      'AI DRAFT',
                      style: TextStyle(
                        color: QcTheme.gold,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],

                if (quote.notes != null && quote.notes!.isNotEmpty) ...[
                  Text(
                    quote.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: QcTheme.textSubtle,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  const SizedBox(height: 6),
                ],

                // Divider line
                Container(
                  height: 1,
                  color: QcTheme.borderSubtle,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
                const SizedBox(height: 10),

                // Items & Total info row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ITEMS',
                            style: TextStyle(
                              color: QcTheme.textSubtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            quote.items.length.toString(),
                            style: const TextStyle(
                              color: QcTheme.textMain,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              color: QcTheme.textSubtle,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            QcTheme.formatCurrency(quote.totalCost),
                            style: const TextStyle(
                              color: QcTheme.gold,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action buttons row
                Row(
                  children: [
                    if (isDraft) ...[
                      // Edit Button
                      if (onEdit != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onEdit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: QcTheme.textMain,
                              backgroundColor: const Color(0xFF221E1B),
                              side: const BorderSide(color: QcTheme.borderLight, width: 0.9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Submit Button
                      if (onSubmit != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onSubmit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: QcTheme.textMain,
                              backgroundColor: const Color(0xFF221E1B),
                              side: const BorderSide(color: QcTheme.borderLight, width: 0.9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ] else if (statusStr == 'revisionrequested') ...[
                      if (onEdit != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onEdit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: QcTheme.textMain,
                              backgroundColor: const Color(0xFF221E1B),
                              side: const BorderSide(color: QcTheme.borderLight, width: 0.9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Revise', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ] else if (isSubmitted) ...[
                      // Accept Button
                      if (onAccept != null) ...[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QcTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Accept Quote', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ] else ...[
                      // View details for accepted/other
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: QcTheme.textMain,
                            backgroundColor: const Color(0xFF221E1B),
                            side: const BorderSide(color: QcTheme.borderLight, width: 0.9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('View details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Delete Button (allowed for Draft, RevisionRequested, Submitted)
                    if (onDelete != null && statusStr != 'accepted')
                      Container(
                        width: 44,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1B1C),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF572528), width: 0.9),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE57373)),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          tooltip: 'Delete quote',
                        ),
                      ),
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
