import 'package:flutter/material.dart';
import '../models/quote.dart';
import '../models/quote_item.dart';
import '../services/quotes_contracts_service.dart';
import '../theme/qc_theme.dart';
import 'ai_draft_bottom_sheet.dart';

class QuoteFormBottomSheet extends StatefulWidget {
  final Quote? initialQuote;
  final Function(Quote savedQuote) onQuoteSaved;

  const QuoteFormBottomSheet({
    super.key,
    this.initialQuote,
    required this.onQuoteSaved,
  });

  static void show(
    BuildContext context, {
    Quote? initialQuote,
    required Function(Quote) onQuoteSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuoteFormBottomSheet(
        initialQuote: initialQuote,
        onQuoteSaved: onQuoteSaved,
      ),
    );
  }

  @override
  State<QuoteFormBottomSheet> createState() => _QuoteFormBottomSheetState();
}

class _QuoteFormBottomSheetState extends State<QuoteFormBottomSheet> {
  final _service = QuotesContractsService();
  bool _isLoading = false;
  String? _errorMessage;

  late TextEditingController _summaryController;
  late TextEditingController _notesController;

  static const List<String> categories = [
    'Materials',
    'Labor',
    'Design',
    'Furniture',
    'Other',
  ];

  late List<QuoteItem> _items;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController(text: widget.initialQuote?.scopeSummary ?? '');
    _notesController = TextEditingController(text: widget.initialQuote?.notes ?? '');

    if (widget.initialQuote != null && widget.initialQuote!.items.isNotEmpty) {
      _items = widget.initialQuote!.items
          .map((i) => i.copyWith())
          .toList();
    } else {
      _items = [
        QuoteItem(
          description: '',
          category: 'Materials',
          quantity: 1,
          unitCost: 0.0,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Quotation Engine Calculations (Matching Web Quotation Engine)
  double get _materialsSubtotal {
    return _items
        .where((i) => ['materials', 'furniture', 'other', 'carpentry', 'textiles', 'plumbing']
            .contains(i.category.toLowerCase()))
        .fold(0.0, (sum, i) => sum + i.calculatedTotal);
  }

  double get _laborSubtotal {
    return _items
        .where((i) => ['labor', 'painting', 'electrical', 'installation']
            .contains(i.category.toLowerCase()))
        .fold(0.0, (sum, i) => sum + i.calculatedTotal);
  }

  double get _designFee {
    final direct = _items
        .where((i) => i.category.toLowerCase() == 'design')
        .fold(0.0, (sum, i) => sum + i.calculatedTotal);
    if (direct > 0) return direct;
    return ((_materialsSubtotal + _laborSubtotal) * 0.10 * 100).round() / 100;
  }

  double get _contingencyAmount {
    final sub = _materialsSubtotal + _laborSubtotal + _designFee;
    return (sub * 0.05 * 100).round() / 100;
  }

  double get _taxAmount {
    final taxable = _materialsSubtotal + _laborSubtotal + _designFee + _contingencyAmount;
    return (taxable * 0.08 * 100).round() / 100;
  }

  double get _totalQuotationCost {
    return _materialsSubtotal + _laborSubtotal + _designFee + _contingencyAmount + _taxAmount;
  }

  void _addItem() {
    setState(() {
      _items.add(QuoteItem(
        description: '',
        category: 'Materials',
        quantity: 1,
        unitCost: 0.0,
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items.removeAt(index);
    });
  }

  void _openAiDraft() {
    AiDraftBottomSheet.show(
      context,
      onDraftCreated: (aiQuote) {
        if (aiQuote.id.isNotEmpty) {
          if (mounted) {
            Navigator.pop(context);
            widget.onQuoteSaved(aiQuote);
          }
          return;
        }
        setState(() {
          _summaryController.text = aiQuote.scopeSummary;
          _notesController.text = aiQuote.notes ?? '';
          if (aiQuote.items.isNotEmpty) {
            _items = aiQuote.items.map((i) => i.copyWith()).toList();
          }
          _errorMessage = null;
        });
      },
      onOpenInEditor: (draftQuote) {
        setState(() {
          _summaryController.text = draftQuote.scopeSummary;
          _notesController.text = draftQuote.notes ?? '';
          if (draftQuote.items.isNotEmpty) {
            _items = draftQuote.items.map((i) => i.copyWith()).toList();
          }
          _errorMessage = null;
        });
      },
    );
  }

  Future<void> _saveQuote() async {
    final summary = _summaryController.text.trim();
    if (summary.isEmpty) {
      setState(() => _errorMessage = 'Please provide a scope summary.');
      return;
    }

    final activeItems = _items.where((i) => i.description.trim().isNotEmpty).toList();
    if (activeItems.isEmpty) {
      setState(() => _errorMessage = 'Add at least one line item with a description.');
      return;
    }

    for (final item in activeItems) {
      if (item.quantity < 1) {
        setState(() => _errorMessage = 'Quantity for "${item.description}" must be at least 1.');
        return;
      }
      if (item.unitCost < 0) {
        setState(() => _errorMessage = 'Unit cost for "${item.description}" cannot be negative.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = QuoteFormPayload(
        projectRequestId: widget.initialQuote?.projectRequestId ?? generateUuid(),
        designerId: widget.initialQuote?.designerId ?? generateUuid(),
        scopeSummary: summary,
        notes: _notesController.text.trim(),
        isAiGenerated: widget.initialQuote?.isAiGenerated ?? false,
        items: activeItems,
      );

      Quote saved;
      if (widget.initialQuote == null || widget.initialQuote!.id.isEmpty) {
        saved = await _service.createQuote(payload);
      } else {
        saved = await _service.updateQuote(widget.initialQuote!.id, payload);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onQuoteSaved(saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error saving quote: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialQuote != null && widget.initialQuote!.id.isNotEmpty;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: bottomInset + 16,
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
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: QcTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Revise Quote (Line-Item Editor)' : 'New Quote Proposal',
                    style: QcTheme.serifTitle(fontSize: 19),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Itemized specifications and Quotation Engine calculations.',
                    style: TextStyle(color: QcTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: QcTheme.textMuted, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_errorMessage != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x2EEF4444),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x66EF4444)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          // Scrollable Form Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Agent Banner Shortcut
                  InkWell(
                    onTap: _openAiDraft,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0x1FC48A36),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x66C48A36), width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: QcTheme.gold, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Autofill with AI Budget/Scope Agent', style: TextStyle(color: QcTheme.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                SizedBox(height: 1),
                                Text('Generate room scope and cost estimation in one tap', style: TextStyle(color: QcTheme.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: QcTheme.gold, size: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Scope Summary
                  const Text('SCOPE SUMMARY *', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _summaryController,
                    style: const TextStyle(color: QcTheme.textMain, fontSize: 13.5, fontWeight: FontWeight.w600),
                    decoration: _inputDecoration('e.g. Minimalist living room makeover & custom furniture'),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  const Text('NOTES & SPECIFICATIONS', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    style: const TextStyle(color: QcTheme.textMain, fontSize: 12.5),
                    decoration: _inputDecoration('Optional client notes, finishes, timeline...'),
                  ),
                  const SizedBox(height: 18),

                  // Line Items Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Line Items (${_items.length})', style: const TextStyle(color: QcTheme.textMain, fontSize: 14, fontWeight: FontWeight.w700)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16, color: QcTheme.gold),
                        label: const Text('Add Item', style: TextStyle(color: QcTheme.gold, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        onPressed: _addItem,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Line Items List
                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return _buildLineItemCard(idx, item);
                  }),
                  const SizedBox(height: 14),

                  // Quotation Engine Financial Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: QcTheme.surfaceSunken,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: QcTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calculate_outlined, color: QcTheme.gold, size: 16),
                            SizedBox(width: 6),
                            Text('QUOTATION ENGINE BREAKDOWN', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildBreakdownRow('Materials Subtotal', _materialsSubtotal),
                        _buildBreakdownRow('Labor Subtotal', _laborSubtotal),
                        _buildBreakdownRow('Design Fee (10%)', _designFee),
                        _buildBreakdownRow('Contingency (5%)', _contingencyAmount),
                        _buildBreakdownRow('Tax / VAT (8%)', _taxAmount),
                        const Divider(color: QcTheme.borderSubtle, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimated Total:', style: TextStyle(color: QcTheme.textMain, fontSize: 13.5, fontWeight: FontWeight.w700)),
                            Text(
                              QcTheme.formatCurrency(_totalQuotationCost),
                              style: const TextStyle(color: QcTheme.gold, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Footer Action
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: QcTheme.borderSubtle))),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveQuote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: QcTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        isEditing ? 'Save Changes' : 'Create Quote Proposal',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(int index, QuoteItem item) {
    final catColor = QcTheme.getCategoryColor(item.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QcTheme.surfaceSunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QcTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withAlpha(35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: categories.contains(item.category) ? item.category : 'Other',
                    isDense: true,
                    dropdownColor: QcTheme.surfaceSunken,
                    icon: const Icon(Icons.arrow_drop_down, color: QcTheme.textMuted, size: 16),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: QcTheme.getCategoryColor(c), fontSize: 11, fontWeight: FontWeight.w700)))).toList(),
                    onChanged: (cat) {
                      if (cat != null) {
                        setState(() {
                          _items[index] = item.copyWith(category: cat);
                        });
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeItem(index),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Description input
          TextFormField(
            initialValue: item.description,
            style: const TextStyle(color: QcTheme.textMain, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              hintText: 'Item description (e.g. Custom Walnut Executive Desk)...',
              hintStyle: TextStyle(color: QcTheme.textSubtle, fontSize: 12),
            ),
            onChanged: (val) {
              _items[index] = item.copyWith(description: val);
            },
          ),
          const Divider(color: QcTheme.borderSubtle, height: 12),

          // Quantity, Unit Cost, and Line Total
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Text('Qty: ', style: TextStyle(color: QcTheme.textSubtle, fontSize: 11)),
                    SizedBox(
                      width: 45,
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: QcTheme.textMain, fontSize: 12),
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                        onChanged: (val) {
                          final q = int.tryParse(val) ?? 1;
                          setState(() {
                            _items[index] = item.copyWith(quantity: q > 0 ? q : 1);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Text('Unit: ', style: TextStyle(color: QcTheme.textSubtle, fontSize: 11)),
                    Expanded(
                      child: TextFormField(
                        initialValue: item.unitCost.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: QcTheme.textMain, fontSize: 12),
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                        onChanged: (val) {
                          final c = double.tryParse(val) ?? 0;
                          setState(() {
                            _items[index] = item.copyWith(unitCost: c >= 0 ? c : 0);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                QcTheme.formatCurrency(item.calculatedTotal),
                style: const TextStyle(color: QcTheme.gold, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String title, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: QcTheme.textMuted, fontSize: 12)),
          Text(QcTheme.formatCurrency(amount), style: const TextStyle(color: QcTheme.textMain, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: QcTheme.textSubtle, fontSize: 12.5),
      filled: true,
      fillColor: QcTheme.surfaceSunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: QcTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: QcTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: QcTheme.primary)),
    );
  }
}
