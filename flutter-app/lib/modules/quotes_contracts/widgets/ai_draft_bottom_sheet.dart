import 'package:flutter/material.dart';
import '../models/quote.dart';
import '../models/quote_item.dart';
import '../services/quotes_contracts_service.dart';
import '../theme/qc_theme.dart';

class AiDraftBottomSheet extends StatefulWidget {
  final Function(Quote newQuote) onDraftCreated;
  final Function(Quote draftQuote)? onOpenInEditor;

  const AiDraftBottomSheet({
    super.key,
    required this.onDraftCreated,
    this.onOpenInEditor,
  });

  static void show(
    BuildContext context, {
    required Function(Quote) onDraftCreated,
    Function(Quote)? onOpenInEditor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiDraftBottomSheet(
        onDraftCreated: onDraftCreated,
        onOpenInEditor: onOpenInEditor,
      ),
    );
  }

  @override
  State<AiDraftBottomSheet> createState() => _AiDraftBottomSheetState();
}

class _AiDraftBottomSheetState extends State<AiDraftBottomSheet> {
  final _service = QuotesContractsService();

  static const List<String> styleOptions = [
    'Modern',
    'Minimalist',
    'Industrial',
    'Luxury',
    'Traditional',
    'Mid Century Modern',
  ];

  static const List<String> roomPresets = [
    'Bedroom',
    'Living room',
    'Master bedroom',
    'Kitchen',
    'Dining room',
    'Home office',
    'Bathroom',
  ];

  static const List<Map<String, dynamic>> budgetPresets = [
    {'label': '150k – 250k', 'min': 150000.0, 'max': 250000.0},
    {'label': '250k – 500k', 'min': 250000.0, 'max': 500000.0},
    {'label': '500k – 1.0M', 'min': 500000.0, 'max': 1000000.0},
    {'label': '1.0M – 2.5M', 'min': 1000000.0, 'max': 2500000.0},
  ];

  static const List<String> preferenceChips = [
    'Warm recessed lighting',
    'Low-profile oak furniture',
    'Custom built-in storage',
    'Natural textures & linen',
    'Matte black accents',
    'Luxury marble countertops',
  ];

  static const List<String> categories = [
    'Design',
    'Labor',
    'Materials',
    'Furniture',
    'Other',
  ];

  // Step state
  String _step = 'configure'; // 'configure' | 'preview'
  bool _isLoading = false;
  String? _errorMessage;

  // Configure inputs
  String _roomType = 'Bedroom';
  final _roomTypeController = TextEditingController(text: 'Bedroom');
  final _roomSizeController = TextEditingController(text: '200');
  final _budgetMinController = TextEditingController(text: '150000');
  final _budgetMaxController = TextEditingController(text: '250000');
  String _selectedStyle = 'Modern';
  final _preferencesController = TextEditingController();

  // Preview data
  late TextEditingController _draftScopeController;
  late TextEditingController _draftNotesController;
  String _draftSource = 'claude';
  List<QuoteItem> _draftItems = [];

  @override
  void initState() {
    super.initState();
    _draftScopeController = TextEditingController();
    _draftNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _roomTypeController.dispose();
    _roomSizeController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _preferencesController.dispose();
    _draftScopeController.dispose();
    _draftNotesController.dispose();
    super.dispose();
  }

  void _addPreference(String chip) {
    final current = _preferencesController.text.trim();
    if (current.isEmpty) {
      _preferencesController.text = chip;
    } else if (!current.contains(chip)) {
      _preferencesController.text = '$current, $chip';
    }
  }

  double get _currentMinBudget => double.tryParse(_budgetMinController.text) ?? 150000;
  double get _currentMaxBudget => double.tryParse(_budgetMaxController.text) ?? 250000;
  double get _currentRoomSize => double.tryParse(_roomSizeController.text) ?? 200;

  double get _previewTotalCost => _draftItems.fold(0.0, (sum, i) => sum + i.calculatedTotal);

  bool get _isWithinBudget {
    final total = _previewTotalCost;
    final maxB = _currentMaxBudget;
    return maxB > 0 ? (total <= maxB && total >= _currentMinBudget * 0.7) : true;
  }

  AiDraftPayload _buildPayload() {
    return AiDraftPayload(
      projectRequestId: generateUuid(),
      designerId: generateUuid(),
      roomType: _roomTypeController.text.trim().isEmpty ? _roomType : _roomTypeController.text.trim(),
      roomSizeSqft: _currentRoomSize,
      budgetMin: _currentMinBudget,
      budgetMax: _currentMaxBudget,
      styleProfile: _selectedStyle,
      styleConfidence: 0.88,
      preferences: _preferencesController.text.trim().isEmpty ? null : _preferencesController.text.trim(),
    );
  }

  // Trigger live AI agent preview
  Future<void> _generatePreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = _buildPayload();
      final preview = await _service.previewQuoteFromAgent(payload);

      setState(() {
        _draftScopeController.text = preview.scopeSummary.isNotEmpty
            ? preview.scopeSummary
            : '$_selectedStyle ${_roomTypeController.text.trim()} Redesign';
        _draftNotesController.text = preview.notes;
        _draftSource = preview.source;
        _draftItems = preview.items.isNotEmpty
            ? List<QuoteItem>.from(preview.items)
            : [
                QuoteItem(
                  description: '$_selectedStyle interior architectural design & concept drawings',
                  category: 'Design',
                  quantity: 1,
                  unitCost: (_currentMinBudget * 0.15),
                ),
                QuoteItem(
                  description: 'Carpentry, painting and custom wall treatment labor',
                  category: 'Labor',
                  quantity: 1,
                  unitCost: (_currentMinBudget * 0.35),
                ),
                QuoteItem(
                  description: 'Premium curated finishes, textures and acoustic materials',
                  category: 'Materials',
                  quantity: 1,
                  unitCost: (_currentMinBudget * 0.30),
                ),
                QuoteItem(
                  description: 'Curated styling accessories and ergonomic furniture',
                  category: 'Furniture',
                  quantity: 1,
                  unitCost: (_currentMinBudget * 0.20),
                ),
              ];
        _step = 'preview';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not generate preview: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Trigger direct draft creation and save to backend
  Future<void> _directDraftAndSave() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = _buildPayload();
      final quote = await _service.draftQuoteFromAgent(payload);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDraftCreated(quote);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to draft quote: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Final approval from Preview step: commit quote to database
  Future<void> _approveAndSavePreview() async {
    if (_draftItems.isEmpty) {
      setState(() => _errorMessage = 'Quote must contain at least one line item.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = QuoteFormPayload(
        projectRequestId: generateUuid(),
        designerId: generateUuid(),
        scopeSummary: _draftScopeController.text.trim().isEmpty
            ? '$_selectedStyle ${_roomTypeController.text.trim()} Redesign'
            : _draftScopeController.text.trim(),
        notes: '${_draftNotesController.text.trim()} (agent source: $_draftSource)',
        isAiGenerated: true,
        items: _draftItems,
      );

      final savedQuote = await _service.createQuote(payload);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDraftCreated(savedQuote);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save quote: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openInEditor() {
    final draftQuote = Quote(
      id: '',
      projectRequestId: generateUuid(),
      designerId: generateUuid(),
      scopeSummary: _draftScopeController.text.trim().isEmpty
          ? '$_selectedStyle ${_roomTypeController.text.trim()} Redesign'
          : _draftScopeController.text.trim(),
      notes: _draftNotesController.text.trim(),
      isAiGenerated: true,
      status: 'Draft',
      totalCost: _previewTotalCost,
      items: _draftItems,
    );

    Navigator.of(context).pop();
    if (widget.onOpenInEditor != null) {
      widget.onOpenInEditor!(draftQuote);
    } else {
      widget.onDraftCreated(draftQuote);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Row(
                children: [
                  if (_step == 'preview')
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: QcTheme.gold, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _step = 'configure'),
                    ),
                  if (_step == 'preview') const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Budget & Scope AI Agent', style: QcTheme.serifTitle(fontSize: 19)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x26C48A36),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x66C48A36), width: 0.8),
                            ),
                            child: const Text(
                              '✨ Student 3 Agent',
                              style: TextStyle(color: QcTheme.gold, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _step == 'configure'
                            ? 'Configure room and client budget to draft itemized scope.'
                            : 'Review, fine-tune and approve line items before saving.',
                        style: const TextStyle(color: QcTheme.textMuted, fontSize: 12),
                      ),
                    ],
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

          // Body
          Expanded(
            child: _step == 'configure' ? _buildConfigureStep() : _buildPreviewStep(),
          ),
        ],
      ),
    );
  }

  // ================= STEP 1: CONFIGURE =================
  Widget _buildConfigureStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Type Presets
          const Text('ROOM TYPE', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: roomPresets.map((r) {
              final isSelected = _roomType == r;
              return ChoiceChip(
                label: Text(r, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : QcTheme.textMain)),
                selected: isSelected,
                selectedColor: QcTheme.primary,
                backgroundColor: QcTheme.surfaceSunken,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _roomType = r;
                      _roomTypeController.text = r;
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roomTypeController,
            style: const TextStyle(color: QcTheme.textMain, fontSize: 13),
            decoration: _inputDecoration('Custom Room Type (e.g. Master Bedroom)'),
          ),
          const SizedBox(height: 14),

          // Room Size & Design Style Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ROOM SIZE (SQ FT)', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _roomSizeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: QcTheme.textMain, fontSize: 13),
                      decoration: _inputDecoration('e.g. 200'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DESIGN STYLE', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: QcTheme.surfaceSunken,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: QcTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStyle,
                          isExpanded: true,
                          dropdownColor: QcTheme.surfaceSunken,
                          icon: const Icon(Icons.keyboard_arrow_down, color: QcTheme.textMuted, size: 18),
                          items: styleOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: QcTheme.textMain, fontSize: 12.5)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedStyle = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Budget Range & Presets
          const Text('BUDGET RANGE (LKR)', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: budgetPresets.map((bp) {
              return ActionChip(
                label: Text(bp['label'] as String, style: const TextStyle(fontSize: 11, color: QcTheme.gold)),
                backgroundColor: const Color(0xFF2B241D),
                onPressed: () {
                  setState(() {
                    _budgetMinController.text = (bp['min'] as double).toStringAsFixed(0);
                    _budgetMaxController.text = (bp['max'] as double).toStringAsFixed(0);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _budgetMinController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: QcTheme.textMain, fontSize: 13),
                  decoration: _inputDecoration('Min Budget (LKR)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _budgetMaxController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: QcTheme.textMain, fontSize: 13),
                  decoration: _inputDecoration('Max Budget (LKR)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Preferences & Chips
          const Text('CLIENT PREFERENCES & SPECIFICATIONS', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: preferenceChips.map((chip) {
              return ActionChip(
                label: Text(chip, style: const TextStyle(fontSize: 11, color: QcTheme.textMuted)),
                backgroundColor: QcTheme.surfaceSunken,
                onPressed: () => _addPreference(chip),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _preferencesController,
            maxLines: 2,
            style: const TextStyle(color: QcTheme.textMain, fontSize: 13),
            decoration: _inputDecoration('e.g. Warm recessed lighting, low-profile oak furniture...'),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _directDraftAndSave,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: QcTheme.textMain,
                    side: const BorderSide(color: QcTheme.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Direct Draft & Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _generatePreview,
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                  label: Text(_isLoading ? 'Analyzing...' : 'Generate Preview', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QcTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ================= STEP 2: PREVIEW =================
  Widget _buildPreviewStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top banner: Agent source & Budget comparison
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: QcTheme.surfaceSunken,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QcTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ESTIMATED TOTAL', style: TextStyle(color: QcTheme.textSubtle, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                          const SizedBox(height: 3),
                          Text(
                            QcTheme.formatCurrency(_previewTotalCost),
                            style: const TextStyle(color: QcTheme.gold, fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isWithinBudget ? const Color(0x2610B981) : const Color(0x26F59E0B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _isWithinBudget ? const Color(0x6610B981) : const Color(0x66F59E0B)),
                        ),
                        child: Text(
                          _isWithinBudget ? '✓ Within Budget' : '⚠ Over Target',
                          style: TextStyle(
                            color: _isWithinBudget ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Editable Scope Summary
                const Text('SCOPE SUMMARY', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                TextField(
                  controller: _draftScopeController,
                  style: const TextStyle(color: QcTheme.textMain, fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: _inputDecoration('Scope summary'),
                ),
                const SizedBox(height: 12),

                // Editable Notes
                const Text('AGENT SPECIFICATION NOTES', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                TextField(
                  controller: _draftNotesController,
                  maxLines: 2,
                  style: const TextStyle(color: QcTheme.textMuted, fontSize: 12.5),
                  decoration: _inputDecoration('Notes'),
                ),
                const SizedBox(height: 16),

                // Itemized Breakdown Header & Add Item
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Itemized Breakdown (${_draftItems.length})', style: const TextStyle(color: QcTheme.textMain, fontSize: 14, fontWeight: FontWeight.w700)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16, color: QcTheme.gold),
                      label: const Text('Add Item', style: TextStyle(color: QcTheme.gold, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        setState(() {
                          _draftItems.add(QuoteItem(
                            description: 'Custom specification item',
                            category: 'Other',
                            quantity: 1,
                            unitCost: 10000,
                          ));
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Items list
                ..._draftItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return _buildItemEditor(idx, item);
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Sticky Footer Actions
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: QcTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _openInEditor,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: QcTheme.textMain,
                    side: const BorderSide(color: QcTheme.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Open in Quote Editor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _approveAndSavePreview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QcTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Approve & Save Draft', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemEditor(int index, QuoteItem item) {
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
              // Category Dropdown
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
                          _draftItems[index] = item.copyWith(category: cat);
                        });
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),
              if (_draftItems.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _draftItems.removeAt(index);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Description
          TextFormField(
            initialValue: item.description,
            style: const TextStyle(color: QcTheme.textMain, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              hintText: 'Item description...',
              hintStyle: TextStyle(color: QcTheme.textSubtle, fontSize: 12),
            ),
            onChanged: (val) {
              _draftItems[index] = item.copyWith(description: val);
            },
          ),
          const Divider(color: QcTheme.borderSubtle, height: 12),
          // Quantity and Unit Cost Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Text('Qty: ', style: TextStyle(color: QcTheme.textSubtle, fontSize: 11)),
                    SizedBox(
                      width: 50,
                      child: TextFormField(
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: QcTheme.textMain, fontSize: 12),
                        decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                        onChanged: (val) {
                          final q = int.tryParse(val) ?? 1;
                          setState(() {
                            _draftItems[index] = item.copyWith(quantity: q > 0 ? q : 1);
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
                            _draftItems[index] = item.copyWith(unitCost: c >= 0 ? c : 0);
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
