import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth/auth_provider.dart';
import 'models/quote.dart';
import 'models/contract.dart';
import 'services/quotes_contracts_service.dart';
import 'theme/qc_theme.dart';
import 'widgets/quote_card.dart';
import 'widgets/contract_card.dart';
import 'widgets/ai_draft_bottom_sheet.dart';
import 'widgets/quote_form_bottom_sheet.dart';
import 'widgets/quote_detail_bottom_sheet.dart';
import 'widgets/contract_detail_bottom_sheet.dart';

class QuotesContractsPage extends ConsumerStatefulWidget {
  const QuotesContractsPage({super.key});

  @override
  ConsumerState<QuotesContractsPage> createState() => _QuotesContractsPageState();
}

class _QuotesContractsPageState extends ConsumerState<QuotesContractsPage> with SingleTickerProviderStateMixin {
  final _service = QuotesContractsService();

  // Quotes state
  List<Quote> _quotes = [];
  bool _isLoadingQuotes = true;
  String? _quotesError;
  String _quoteStatusFilter = 'All statuses';
  final _quoteSearchController = TextEditingController();

  // Contracts state
  List<Contract> _contracts = [];
  List<Quote> _pendingQuotes = [];
  bool _isLoadingContracts = true;
  String? _contractsError;
  String _contractStatusFilter = 'All statuses';
  String _selectedTab = 'quotes';

  static const List<String> quoteStatusOptions = [
    'All statuses',
    'Draft',
    'Submitted',
    'ClientReview',
    'Accepted',
    'Rejected',
  ];

  static const List<String> contractStatusOptions = [
    'All statuses',
    'Active',
    'Draft',
    'PendingSignature',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    final isDesigner = ref.read(authProvider).isDesigner;
    _selectedTab = isDesigner ? 'contracts' : 'quotes';
    _loadQuotes();
    _loadContracts();
  }

  @override
  void dispose() {
    _quoteSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _isLoadingQuotes = true;
      _quotesError = null;
    });

    try {
      final list = await _service.listQuotes(
        status: _quoteStatusFilter == 'All statuses' ? null : _quoteStatusFilter,
        search: _quoteSearchController.text.trim().isEmpty ? null : _quoteSearchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _quotes = list;
          _isLoadingQuotes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _quotesError = e.toString();
          _isLoadingQuotes = false;
        });
      }
    }
  }

  Future<void> _loadContracts() async {
    setState(() {
      _isLoadingContracts = true;
      _contractsError = null;
    });

    try {
      final list = await _service.listContracts(
        status: _contractStatusFilter == 'All statuses' ? null : _contractStatusFilter,
      );
      final pendingQuotesList = await _service.listQuotes(status: 'Submitted');

      if (mounted) {
        setState(() {
          _contracts = list;
          _pendingQuotes = pendingQuotesList.where((q) => !list.any((c) => c.quoteId == q.id)).toList();
          _isLoadingContracts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _contractsError = e.toString();
          _isLoadingContracts = false;
        });
      }
    }
  }

  // Quote Handlers
  void _openAiDraft() {
    AiDraftBottomSheet.show(
      context,
      onDraftCreated: (newQuote) {
        _loadQuotes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI quote created for ${newQuote.scopeSummary}!'),
            backgroundColor: QcTheme.primary,
          ),
        );
      },
      onOpenInEditor: (draftQuote) {
        _openNewQuote(quoteToEdit: draftQuote);
      },
    );
  }

  void _openNewQuote({Quote? quoteToEdit}) {
    QuoteFormBottomSheet.show(
      context,
      initialQuote: quoteToEdit,
      onQuoteSaved: (saved) {
        _loadQuotes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(quoteToEdit != null ? 'Quote updated!' : 'Quote created!'),
            backgroundColor: QcTheme.primary,
          ),
        );
      },
    );
  }

  Future<void> _handleSubmitQuote(Quote q) async {
    try {
      await _service.updateQuoteStatus(q.id, 'Submitted');
      _loadQuotes();
      _loadContracts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote submitted! Contract created for designer review.'),
            backgroundColor: QcTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit quote: $e'), backgroundColor: QcTheme.danger),
        );
      }
    }
  }

  Future<void> _handleAdvanceQuote(Quote q) async {
    final status = q.status.toLowerCase();
    String nextStatus;
    if (status == 'draft') {
      nextStatus = 'Submitted';
    } else if (status == 'submitted') {
      nextStatus = 'ClientReview';
    } else {
      nextStatus = 'Accepted';
    }

    if (nextStatus == 'Accepted') {
      await _handleAcceptQuote(q);
      return;
    }

    try {
      await _service.updateQuoteStatus(q.id, nextStatus);
      _loadQuotes();
      _loadContracts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quote moved to $nextStatus'), backgroundColor: QcTheme.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: QcTheme.danger),
        );
      }
    }
  }

  Future<void> _handleAcceptQuote(Quote q) async {
    try {
      final contract = await _service.acceptQuote(q.id);
      _loadQuotes();
      _loadContracts();
      if (mounted) {
        final shortContractId = contract?.id != null && contract!.id.length > 8 ? contract.id.substring(0, 8) : (contract?.id ?? '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quote accepted! Contract #$shortContractId generated.'),
            backgroundColor: QcTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting quote: $e'), backgroundColor: QcTheme.danger),
        );
      }
    }
  }

  Future<void> _handleRejectQuote(Quote q, String? reason) async {
    try {
      await _service.updateQuoteStatus(q.id, 'Rejected');
      _loadQuotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote rejected'), backgroundColor: QcTheme.surfaceSunken),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject quote: $e'), backgroundColor: QcTheme.danger),
        );
      }
    }
  }

  Future<void> _handleDeleteQuote(Quote q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QcTheme.surface,
        title: const Text('Delete Quote?', style: TextStyle(color: QcTheme.textMain)),
        content: Text('Delete "${q.scopeSummary}"? This cannot be undone.', style: const TextStyle(color: QcTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: QcTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: QcTheme.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteQuote(q.id);
      _loadQuotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote deleted'), backgroundColor: QcTheme.surfaceSunken),
        );
      }
    }
  }

  // Contract Handlers
  Future<void> _handleSignContract(Contract c) async {
    try {
      await _service.signContract(c.id);
      _loadContracts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract signed and active!'), backgroundColor: QcTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign contract: $e'), backgroundColor: QcTheme.danger),
        );
      }
    }
  }

  Future<void> _handleCancelContract(Contract c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QcTheme.surface,
        title: const Text('Cancel Contract?', style: TextStyle(color: QcTheme.textMain)),
        content: Text('Cancel contract #${c.id}? It will be kept for history but marked Cancelled.', style: const TextStyle(color: QcTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Active', style: TextStyle(color: QcTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: QcTheme.danger),
            child: const Text('Cancel Contract', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.cancelContract(c.id);
      _loadContracts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract marked as Cancelled'), backgroundColor: QcTheme.surfaceSunken),
        );
      }
    }
  }

  void _openServerSettingsDialog() {
    final urlController = TextEditingController(text: _service.baseUrl);
    bool isTesting = false;
    String? testResult;
    bool? isSuccess;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.only(top: 16, left: 20, right: 20, bottom: bottomInset + 20),
            decoration: const BoxDecoration(
              color: QcTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: QcTheme.border, width: 1.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: QcTheme.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Backend Connection',
                      style: TextStyle(color: QcTheme.textMain, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: QcTheme.textMuted, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Set the API base URL matching your current run target (emulator, web, or physical device).',
                  style: TextStyle(color: QcTheme.textSubtle, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text('QUICK PRESETS', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      backgroundColor: const Color(0xFF2E2721),
                      label: const Text('Android Emulator', style: TextStyle(color: QcTheme.gold, fontSize: 11)),
                      onPressed: () {
                        setModalState(() {
                          urlController.text = QuotesContractsService.emulatorBaseUrl;
                          testResult = null;
                        });
                      },
                    ),
                    ActionChip(
                      backgroundColor: const Color(0xFF2E2721),
                      label: const Text('Localhost (Web/Desktop)', style: TextStyle(color: QcTheme.gold, fontSize: 11)),
                      onPressed: () {
                        setModalState(() {
                          urlController.text = QuotesContractsService.localhostBaseUrl;
                          testResult = null;
                        });
                      },
                    ),
                    ActionChip(
                      backgroundColor: const Color(0xFF2E2721),
                      label: const Text('Wi-Fi LAN (Physical Phone)', style: TextStyle(color: QcTheme.gold, fontSize: 11)),
                      onPressed: () {
                        setModalState(() {
                          urlController.text = QuotesContractsService.lanBaseUrl;
                          testResult = null;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('API BASE URL', style: TextStyle(color: QcTheme.textSubtle, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: QcTheme.textMain, fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: QcTheme.surfaceSunken,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: QcTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: QcTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: QcTheme.primary)),
                  ),
                ),
                const SizedBox(height: 12),
                if (testResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSuccess == true ? const Color(0x1F10B981) : const Color(0x1FEF4444),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSuccess == true ? const Color(0x6610B981) : const Color(0x66EF4444)),
                    ),
                    child: Row(
                      children: [
                        Icon(isSuccess == true ? Icons.check_circle : Icons.error, color: isSuccess == true ? const Color(0xFF34D399) : const Color(0xFFF87171), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(testResult!, style: TextStyle(color: isSuccess == true ? const Color(0xFF34D399) : const Color(0xFFF87171), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isTesting ? null : () async {
                          setModalState(() {
                            isTesting = true;
                            testResult = 'Testing connection...';
                            isSuccess = null;
                          });
                          _service.setBaseUrl(urlController.text);
                          final ok = await _service.checkConnection();
                          setModalState(() {
                            isTesting = false;
                            isSuccess = ok;
                            testResult = ok
                                ? 'Connected to backend successfully!'
                                : 'Failed to reach backend. Make sure "dotnet run" is started.';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: QcTheme.gold,
                          side: const BorderSide(color: QcTheme.borderLight),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(isTesting ? 'Testing...' : 'Test Ping'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _service.setBaseUrl(urlController.text);
                          Navigator.of(ctx).pop();
                          _loadQuotes();
                          _loadContracts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Connected to: ${_service.baseUrl}'),
                              backgroundColor: QcTheme.primary,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QcTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save & Reload', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDesigner = authState.isDesigner;
    final isClient = authState.isClient;

    // Consistency with web app:
    // Designer is locked to Contracts Studio
    // Client is locked to Quotes Portal
    // Admin/Guest can toggle via Tab Switcher
    final effectiveTab = isDesigner ? 'contracts' : (isClient ? 'quotes' : _selectedTab);

    return Scaffold(
      backgroundColor: QcTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(isDesigner: isDesigner, isClient: isClient),

            // Show Tab Switcher ONLY if neither Designer nor Client (Admin/Guest)
            if (!isDesigner && !isClient)
              _buildTabSwitcher(),

            // Main Content Area
            Expanded(
              child: effectiveTab == 'contracts' ? _buildContractsTab() : _buildQuotesTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: QcTheme.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: QcTheme.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTab = 'quotes');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 'quotes' ? const Color(0xFF2E261E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedTab == 'quotes' ? const Color(0xFFC48A36) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 16,
                      color: _selectedTab == 'quotes' ? QcTheme.gold : QcTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Quotes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTab == 'quotes' ? FontWeight.w700 : FontWeight.w500,
                        color: _selectedTab == 'quotes' ? QcTheme.gold : QcTheme.textMuted,
                      ),
                    ),
                    if (_quotes.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _selectedTab == 'quotes' ? const Color(0x33C48A36) : const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_quotes.length}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == 'quotes' ? QcTheme.gold : QcTheme.textSubtle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTab = 'contracts');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 'contracts' ? const Color(0xFF2E261E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedTab == 'contracts' ? const Color(0xFFC48A36) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 16,
                      color: _selectedTab == 'contracts' ? QcTheme.gold : QcTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Contracts',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTab == 'contracts' ? FontWeight.w700 : FontWeight.w500,
                        color: _selectedTab == 'contracts' ? QcTheme.gold : QcTheme.textMuted,
                      ),
                    ),
                    if (_contracts.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _selectedTab == 'contracts' ? const Color(0x33C48A36) : const Color(0x1FFFFFFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_contracts.length}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _selectedTab == 'contracts' ? QcTheme.gold : QcTheme.textSubtle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar({required bool isDesigner, required bool isClient}) {
    String roleLabel = 'GUEST';
    if (isDesigner) {
      roleLabel = 'DESIGNER';
    } else if (isClient) {
      roleLabel = 'CLIENT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: QcTheme.bg,
        border: Border(bottom: BorderSide(color: QcTheme.borderSubtle, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: QcTheme.textMuted, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              // Rounded tile logo avatar 'S'
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF24201D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: QcTheme.borderLight, width: 1),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: QcTheme.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'StyleSync',
                    style: TextStyle(
                      color: QcTheme.textMain,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    roleLabel,
                    style: const TextStyle(
                      color: QcTheme.textSubtle,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Role Badge matching web app:
          // Designer -> Contracts Dashboard badge
          // Client -> Quotes Dashboard badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDesigner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x2EC48A36),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x66C48A36)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, size: 14, color: QcTheme.gold),
                      SizedBox(width: 4),
                      Text(
                        'Contracts Dashboard',
                        style: TextStyle(color: QcTheme.gold, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                )
              else if (isClient)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x2EC48A36),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x66C48A36)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 14, color: QcTheme.gold),
                      SizedBox(width: 4),
                      Text(
                        'Quotes Dashboard',
                        style: TextStyle(color: QcTheme.gold, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.dns_outlined, color: QcTheme.gold, size: 20),
                onPressed: _openServerSettingsDialog,
                tooltip: 'Backend Connection Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= QUOTES TAB =================
  Widget _buildQuotesTab() {
    return RefreshIndicator(
      onRefresh: _loadQuotes,
      color: QcTheme.primary,
      backgroundColor: QcTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Header: "Quotes Portal" title & subtitle matching web
          Text('Quotes Portal', style: QcTheme.serifTitle(fontSize: 30)),
          const SizedBox(height: 4),
          const Text(
            'Review itemized cost breakdowns, scope estimation, and accept or reject quotes.',
            style: TextStyle(
              color: QcTheme.textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Generate with AI & + New quote
          Row(
            children: [
              // Generate with AI
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: QcTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4DC48A36),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _openAiDraft,
                    icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                    label: const Text(
                      'Generate with AI',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // + New quote
              Expanded(
                flex: 5,
                child: OutlinedButton.icon(
                  onPressed: () => _openNewQuote(),
                  icon: const Icon(Icons.add, size: 16, color: QcTheme.textMain),
                  label: const Text(
                    'New quote',
                    style: TextStyle(
                      color: QcTheme.textMain,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: QcTheme.surfaceSunken,
                    side: const BorderSide(color: QcTheme.borderLight, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search and Filter Row
          Row(
            children: [
              // Search input
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: QcTheme.surfaceSunken,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: QcTheme.border, width: 1),
                  ),
                  child: TextField(
                    controller: _quoteSearchController,
                    onSubmitted: (_) => _loadQuotes(),
                    style: const TextStyle(color: QcTheme.textMain, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search quotes...',
                      hintStyle: const TextStyle(color: QcTheme.textSubtle, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: QcTheme.textSubtle, size: 18),
                      suffixIcon: _quoteSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: QcTheme.textSubtle, size: 16),
                              onPressed: () {
                                _quoteSearchController.clear();
                                _loadQuotes();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status Dropdown
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: QcTheme.surfaceSunken,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: QcTheme.border, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _quoteStatusFilter,
                      isExpanded: true,
                      dropdownColor: QcTheme.surfaceSunken,
                      icon: const Icon(Icons.keyboard_arrow_down, color: QcTheme.textMuted, size: 18),
                      items: quoteStatusOptions.map((st) {
                        return DropdownMenuItem(
                          value: st,
                          child: Text(
                            st,
                            style: const TextStyle(color: QcTheme.textMain, fontSize: 12.5),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _quoteStatusFilter = val);
                          _loadQuotes();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Quotes list view
          if (_isLoadingQuotes) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: QcTheme.primary),
              ),
            ),
          ] else if (_quotesError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x2EEF4444),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x66EF4444)),
              ),
              child: Column(
                children: [
                  Text(_quotesError!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadQuotes,
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                    label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ] else if (_quotes.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 48, color: QcTheme.borderLight),
                  const SizedBox(height: 12),
                  const Text('No quotes found', style: TextStyle(color: QcTheme.textMain, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Create a new quote or generate one with the AI Agent.', style: TextStyle(color: QcTheme.textSubtle, fontSize: 13)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openAiDraft,
                    icon: const Icon(Icons.auto_awesome, size: 15, color: Colors.white),
                    label: const Text('Draft with AI', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: QcTheme.primary),
                  ),
                ],
              ),
            ),
          ] else ...[
            ..._quotes.map((quote) => QuoteCard(
              quote: quote,
              onTap: () => QuoteDetailBottomSheet.show(
                context,
                quote: quote,
                onStage2Decision: (action, feedback) {
                  if (action == 'Approve') {
                    _handleAcceptQuote(quote);
                  } else if (action == 'Reject') {
                    _handleRejectQuote(quote, feedback);
                  } else {
                    _handleAdvanceQuote(quote);
                  }
                },
              ),
              onEdit: () => _openNewQuote(quoteToEdit: quote),
              onSubmit: () => _handleSubmitQuote(quote),
              onAccept: () => _handleAcceptQuote(quote),
              onDelete: () => _handleDeleteQuote(quote),
            )),
          ],
        ],
      ),
    );
  }

  // ================= CONTRACTS TAB (Image 2) =================
  Widget _buildContractsTab() {
    return RefreshIndicator(
      onRefresh: _loadContracts,
      color: QcTheme.primary,
      backgroundColor: QcTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Header: "Contracts Dashboard" title & subtitle
          Text('Contracts Dashboard', style: QcTheme.serifTitle(fontSize: 30)),
          const SizedBox(height: 4),
          const Text(
            'Review agreements, track signatures, and inspect submitted quote specifications.',
            style: TextStyle(
              color: QcTheme.textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Filter Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: QcTheme.surfaceSunken,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: QcTheme.border, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _contractStatusFilter,
                      isExpanded: true,
                      dropdownColor: QcTheme.surfaceSunken,
                      icon: const Icon(Icons.keyboard_arrow_down, color: QcTheme.textMuted, size: 18),
                      items: contractStatusOptions.map((st) {
                        return DropdownMenuItem(
                          value: st,
                          child: Text(
                            st,
                            style: const TextStyle(color: QcTheme.textMain, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _contractStatusFilter = val);
                          _loadContracts();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Contracts list view
          if (_isLoadingContracts) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: QcTheme.primary),
              ),
            ),
          ] else if (_contractsError != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x2EEF4444),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x66EF4444)),
              ),
              child: Column(
                children: [
                  Text(_contractsError!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadContracts,
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                    label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ] else if (_contracts.isEmpty && _pendingQuotes.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.verified_outlined, size: 48, color: QcTheme.borderLight),
                  SizedBox(height: 12),
                  Text('No contracts or pending quotes yet', style: TextStyle(color: QcTheme.textMain, fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('When a client submits a quote, it will appear here for you to accept and convert into a contract.', textAlign: TextAlign.center, style: TextStyle(color: QcTheme.textSubtle, fontSize: 13)),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ] else ...[
            if (_pendingQuotes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8, top: 8),
                child: Text('Pending Quotes', style: TextStyle(color: QcTheme.textMain, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              ..._pendingQuotes.map((quote) => QuoteCard(
                quote: quote,
                onTap: () => QuoteDetailBottomSheet.show(
                  context,
                  quote: quote,
                  onStage2Decision: (action, feedback) {
                    if (action == 'Approve') {
                      _handleAcceptQuote(quote);
                    } else if (action == 'Reject') {
                      _handleRejectQuote(quote, feedback);
                    } else {
                      _handleAdvanceQuote(quote);
                    }
                  },
                ),
                onEdit: null,
                onSubmit: () => _handleAcceptQuote(quote),
                onDelete: null,
              )),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, top: 16),
                child: Text('Active Contracts', style: TextStyle(color: QcTheme.textMain, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
            ..._contracts.map((contract) => ContractCard(
              contract: contract,
              onTap: () => ContractDetailBottomSheet.show(
                context,
                contract: contract,
                onSign: () => _handleSignContract(contract),
                onCancel: () => _handleCancelContract(contract),
              ),
              onSign: () => _handleSignContract(contract),
              onCancel: () => _handleCancelContract(contract),
            )),
          ],
        ],
      ),
    );
  }
}
