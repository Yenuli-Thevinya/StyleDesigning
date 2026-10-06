import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/quote.dart';
import '../models/contract.dart';
import '../models/quote_item.dart';
import '../../../services/auth/token_storage_service.dart';

String generateUuid() {
  final random = Random();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class QuoteFormPayload {
  final String projectRequestId;
  final String designerId;
  final String scopeSummary;
  final String notes;
  final bool isAiGenerated;
  final List<QuoteItem> items;

  QuoteFormPayload({
    required this.projectRequestId,
    required this.designerId,
    required this.scopeSummary,
    required this.notes,
    required this.isAiGenerated,
    required this.items,
  });
}

class AiDraftPayload {
  final String projectRequestId;
  final String designerId;
  final String roomType;
  final double roomSizeSqft;
  final double budgetMin;
  final double budgetMax;
  final String styleProfile;
  final String? naturalLanguageScope;
  final double styleConfidence;
  final String? preferences;

  AiDraftPayload({
    required this.projectRequestId,
    required this.designerId,
    required this.roomType,
    required this.roomSizeSqft,
    required this.budgetMin,
    required this.budgetMax,
    required this.styleProfile,
    this.naturalLanguageScope,
    this.styleConfidence = 0.88,
    this.preferences,
  });

  Map<String, dynamic> toJson() => {
        'projectRequestId': projectRequestId,
        'designerId': designerId,
        'roomType': roomType,
        'roomSizeSqft': roomSizeSqft,
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'styleProfile': styleProfile,
        if (naturalLanguageScope != null) 'naturalLanguageScope': naturalLanguageScope,
        'styleConfidence': styleConfidence,
        'preferences': preferences,
      };
}

class AgentBudgetScopeResponse {
  final String scopeSummary;
  final List<QuoteItem> items;
  final String notes;
  final double estimatedTotal;
  final bool withinBudget;
  final String source;

  AgentBudgetScopeResponse({
    required this.scopeSummary,
    required this.items,
    required this.notes,
    required this.estimatedTotal,
    required this.withinBudget,
    required this.source,
  });

  factory AgentBudgetScopeResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return AgentBudgetScopeResponse(
      scopeSummary: json['scopeSummary']?.toString() ?? json['scope_summary']?.toString() ?? '',
      items: rawItems
          .map((i) => QuoteItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      notes: json['notes']?.toString() ?? '',
      estimatedTotal: (json['estimatedTotal'] is num)
          ? (json['estimatedTotal'] as num).toDouble()
          : (json['estimated_total'] is num)
              ? (json['estimated_total'] as num).toDouble()
              : double.tryParse(json['estimatedTotal']?.toString() ?? json['estimated_total']?.toString() ?? '0') ?? 0.0,
      withinBudget: json['withinBudget'] == true || json['within_budget'] == true,
      source: json['source']?.toString() ?? 'llm',
    );
  }
}

class QuotesContractsService {
  static final QuotesContractsService _instance = QuotesContractsService._internal();
  factory QuotesContractsService() => _instance;

  QuotesContractsService._internal();

  // Known presets
  static const String emulatorBaseUrl = 'http://10.0.2.2:5000/api';
  static const String localhostBaseUrl = 'http://localhost:5000/api';
  static const String lanBaseUrl = 'http://192.168.8.117:5000/api';

  // Base URL logic: Localhost on web/desktop, 10.0.2.2 on Android emulator
  static String get defaultBaseUrl {
    if (kIsWeb) return localhostBaseUrl;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return emulatorBaseUrl;
      default:
        return localhostBaseUrl;
    }
  }

  String baseUrl = defaultBaseUrl;
  String get _baseUrl => baseUrl;

  void setBaseUrl(String newUrl) {
    var cleaned = newUrl.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    baseUrl = cleaned;
    debugPrint('[QuotesContractsService] Base URL set to: $baseUrl');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await TokenStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Local in-memory caches used as offline fallback
  final List<Quote> _localQuotes = [];
  final List<Contract> _localContracts = [];

  List<Quote> get cachedQuotes => List.unmodifiable(_localQuotes);
  List<Contract> get cachedContracts => List.unmodifiable(_localContracts);

  // Category sanitizer mapping Flutter categories to backend enum
  static String sanitizeCategory(String cat) {
    const valid = [
      'Design',
      'Labor',
      'Materials',
      'Furniture',
      'Carpentry',
      'Electrical',
      'Painting',
      'Plumbing',
      'Textiles',
      'Other',
    ];
    for (final v in valid) {
      if (v.toLowerCase() == cat.trim().toLowerCase()) return v;
    }
    return 'Other';
  }

  // Ensures any ID sent to backend is a valid UUID format
  static String ensureValidGuid([String? val]) {
    if (val == null || val.trim().isEmpty) {
      return generateUuid();
    }
    final trimmed = val.trim();
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(trimmed) && trimmed != '00000000-0000-0000-0000-000000000000') {
      return trimmed;
    }
    return generateUuid();
  }

  // Quick live connection test
  Future<bool> checkConnection() async {
    try {
      final uri = Uri.parse('$_baseUrl/quotes?pageSize=1');
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // ================= QUOTES ENDPOINTS =================

  Future<List<Quote>> listQuotes({String? status, String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'All statuses') {
        queryParams['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$_baseUrl/quotes').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      debugPrint('[QuotesContractsService] Fetching quotes from $uri');
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        List<dynamic> items = [];
        if (decoded is Map && decoded.containsKey('items')) {
          items = (decoded['items'] as List<dynamic>?) ?? [];
        } else if (decoded is List) {
          items = decoded;
        }

        final quotes = <Quote>[];
        for (final item in items) {
          if (item is Map) {
            try {
              quotes.add(Quote.fromJson(Map<String, dynamic>.from(item)));
            } catch (e) {
              debugPrint('[QuotesContractsService] Quote parsing error: $e');
            }
          }
        }

        // Cache the latest server response
        if (status == null || status == 'All statuses') {
          _localQuotes.clear();
          _localQuotes.addAll(quotes);
        }

        return quotes;
      } else {
        debugPrint('[QuotesContractsService] listQuotes server error status: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[QuotesContractsService] listQuotes API error: $e. Returning cached store.');
    }

    // Offline / fallback cache
    var filtered = List<Quote>.from(_localQuotes);
    if (status != null && status.isNotEmpty && status != 'All statuses') {
      filtered = filtered.where((q) => q.status.toLowerCase() == status.toLowerCase()).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim().toLowerCase();
      filtered = filtered.where((q) => q.scopeSummary.toLowerCase().contains(query)).toList();
    }
    return filtered;
  }

  Future<Quote> createQuote(QuoteFormPayload payload) async {
    final projectReqId = ensureValidGuid(payload.projectRequestId);
    final designerId = ensureValidGuid(payload.designerId);

    final reqBody = {
      'projectRequestId': projectReqId,
      'designerId': designerId,
      'scopeSummary': payload.scopeSummary,
      'notes': payload.notes,
      'isAiGenerated': payload.isAiGenerated,
      'items': payload.items.map((i) => {
        'description': i.description,
        'category': sanitizeCategory(i.category),
        'quantity': i.quantity,
        'unitCost': i.unitCost,
      }).toList(),
    };

    final uri = Uri.parse('$_baseUrl/quotes');
    debugPrint('[QuotesContractsService] POST $uri body: ${jsonEncode(reqBody)}');

    final headers = await _getHeaders();
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(reqBody),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      final created = Quote.fromJson(Map<String, dynamic>.from(decoded as Map));
      _localQuotes.insert(0, created);
      return created;
    } else {
      debugPrint('[QuotesContractsService] createQuote failed: ${res.statusCode} ${res.body}');
      throw Exception('Server error (${res.statusCode}): ${res.body}');
    }
  }

  Future<Quote> updateQuote(String id, QuoteFormPayload payload) async {
    final reqBody = {
      'scopeSummary': payload.scopeSummary,
      'notes': payload.notes,
      'items': payload.items.map((i) => {
        'description': i.description,
        'category': sanitizeCategory(i.category),
        'quantity': i.quantity,
        'unitCost': i.unitCost,
      }).toList(),
    };

    final uri = Uri.parse('$_baseUrl/quotes/$id');
    final headers = await _getHeaders();
    final res = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(reqBody),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      final updated = Quote.fromJson(Map<String, dynamic>.from(decoded as Map));
      final idx = _localQuotes.indexWhere((q) => q.id == id);
      if (idx != -1) _localQuotes[idx] = updated;
      return updated;
    } else {
      throw Exception('Failed to update quote (${res.statusCode}): ${res.body}');
    }
  }

  Future<Quote> updateQuoteStatus(String id, String status) async {
    final uri = Uri.parse('$_baseUrl/quotes/$id/status');
    final headers = await _getHeaders();
    final res = await http.patch(
      uri,
      headers: headers,
      body: jsonEncode({'status': status}),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      final updated = Quote.fromJson(Map<String, dynamic>.from(decoded as Map));
      final idx = _localQuotes.indexWhere((q) => q.id == id);
      if (idx != -1) _localQuotes[idx] = updated;
      return updated;
    } else {
      throw Exception('Failed to update quote status (${res.statusCode}): ${res.body}');
    }
  }

  Future<Contract?> acceptQuote(String id, {String? clientId}) async {
    final url = clientId != null
        ? '$_baseUrl/quotes/$id/accept?clientId=$clientId'
        : '$_baseUrl/quotes/$id/accept';
    final headers = await _getHeaders();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      final contract = Contract.fromJson(Map<String, dynamic>.from(decoded as Map));
      _localContracts.insert(0, contract);
      final idx = _localQuotes.indexWhere((q) => q.id == id);
      if (idx != -1) {
        _localQuotes[idx] = _localQuotes[idx].copyWith(status: 'Accepted', updatedAt: DateTime.now(), contractId: contract.id);
      }
      return contract;
    } else {
      throw Exception('Failed to accept quote (${res.statusCode}): ${res.body}');
    }
  }

  Future<void> deleteQuote(String id) async {
    final uri = Uri.parse('$_baseUrl/quotes/$id');
    final headers = await _getHeaders();
    final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 8));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _localQuotes.removeWhere((q) => q.id == id);
    } else {
      throw Exception('Failed to delete quote (${res.statusCode}): ${res.body}');
    }
  }

  // ================= AI AGENT DRAFT ENDPOINTS =================

  Future<AgentBudgetScopeResponse> previewQuoteFromAgent(AiDraftPayload payload) async {
    try {
      final uri = Uri.parse('$_baseUrl/quotes/draft-preview');
      final headers = await _getHeaders();
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(payload.toJson()),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        return AgentBudgetScopeResponse.fromJson(Map<String, dynamic>.from(decoded as Map));
      }
    } catch (e) {
      debugPrint('[QuotesContractsService] previewQuoteFromAgent live API failed: $e. Using mathematical formula.');
    }

    // Deterministic mathematical algorithm mirroring backend budget_scope_agent.py
    final target = (payload.budgetMin + payload.budgetMax) / 2 > 0
        ? (payload.budgetMin + payload.budgetMax) / 2
        : (payload.roomSizeSqft * 800);

    final splits = [
      {'cat': 'Design', 'pct': 0.10, 'desc': 'Design — ${payload.styleProfile.toLowerCase()} ${payload.roomType.toLowerCase()} concept & planning'},
      {'cat': 'Labor', 'pct': 0.30, 'desc': 'Labor — ${payload.styleProfile.toLowerCase()} ${payload.roomType.toLowerCase()} installation & craftsmanship'},
      {'cat': 'Materials', 'pct': 0.35, 'desc': 'Materials — ${payload.styleProfile.toLowerCase()} ${payload.roomType.toLowerCase()} fixtures & finishes'},
      {'cat': 'Furniture', 'pct': 0.25, 'desc': 'Furniture — ${payload.styleProfile.toLowerCase()} ${payload.roomType.toLowerCase()} curated styling'},
    ];

    final items = splits.map((s) {
      final cost = ((target * (s['pct'] as double)) / 100).round() * 100.0;
      return QuoteItem(
        id: null,
        description: s['desc'] as String,
        category: s['cat'] as String,
        quantity: 1,
        unitCost: cost,
        totalCost: cost,
      );
    }).toList();

    final total = items.fold(0.0, (sum, i) => sum + i.calculatedTotal);

    return AgentBudgetScopeResponse(
      scopeSummary: '${payload.styleProfile} ${payload.roomType.toLowerCase()} refresh, ${payload.roomSizeSqft.toStringAsFixed(0)} sq ft.',
      items: items,
      notes: 'Estimate generated using standard category ratios (Design 10%, Labor 30%, Materials 35%, Furniture 25%).',
      estimatedTotal: total,
      withinBudget: payload.budgetMax > 0 ? (total >= payload.budgetMin && total <= payload.budgetMax) : true,
      source: 'fallback',
    );
  }

  Future<Quote> draftQuoteFromAgent(AiDraftPayload payload) async {
    final projectReqId = ensureValidGuid(payload.projectRequestId);
    final designerId = ensureValidGuid(payload.designerId);

    final reqBody = {
      'projectRequestId': projectReqId,
      'designerId': designerId,
      'roomType': payload.roomType,
      'roomSizeSqft': payload.roomSizeSqft,
      'budgetMin': payload.budgetMin,
      'budgetMax': payload.budgetMax,
      'styleProfile': payload.styleProfile,
      'styleConfidence': payload.styleConfidence,
      'preferences': payload.preferences,
    };

    try {
      final uri = Uri.parse('$_baseUrl/quotes/draft-from-agent');
      final headers = await _getHeaders();
      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(reqBody),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final created = Quote.fromJson(Map<String, dynamic>.from(decoded as Map));
        _localQuotes.insert(0, created);
        return created;
      }
    } catch (e) {
      debugPrint('[QuotesContractsService] draftQuoteFromAgent server endpoint failed: $e. Persisting fallback draft to database.');
    }

    // If live AI service is unreachable, compute deterministic preview and SAVE DIRECTLY TO DATABASE
    final preview = await previewQuoteFromAgent(payload);
    return await createQuote(QuoteFormPayload(
      scopeSummary: preview.scopeSummary,
      notes: preview.notes,
      items: preview.items,
      projectRequestId: projectReqId,
      designerId: designerId,
      isAiGenerated: true,
    ));
  }

  // ================= CONTRACTS ENDPOINTS =================

  Future<List<Contract>> listContracts({String? status}) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'All statuses') {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_baseUrl/contracts').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      debugPrint('[QuotesContractsService] Fetching contracts from $uri');
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        List<dynamic> items = [];
        if (decoded is Map && decoded.containsKey('items')) {
          items = (decoded['items'] as List<dynamic>?) ?? [];
        } else if (decoded is List) {
          items = decoded;
        }

        final contracts = <Contract>[];
        for (final item in items) {
          if (item is Map) {
            try {
              contracts.add(Contract.fromJson(Map<String, dynamic>.from(item)));
            } catch (e) {
              debugPrint('[QuotesContractsService] Contract parsing error: $e');
            }
          }
        }

        // Auto-link submitted quotes matching web app behavior
        for (final q in _localQuotes) {
          final s = q.status;
          if (s == 'Submitted' || s == 'ClientReview') {
            if (!contracts.any((c) => c.quoteId == q.id)) {
              final shortId = q.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
              contracts.insert(0, Contract(
                id: 'cnt-${shortId.length >= 4 ? shortId.substring(0, 4) : shortId}',
                quoteId: q.id,
                projectRequestId: q.projectRequestId,
                designerId: q.designerId,
                clientId: 'client-default',
                status: 'PendingSignature',
                totalAmount: q.totalCost,
                termsSummary: q.scopeSummary.isNotEmpty ? q.scopeSummary : 'Interior Design Agreement',
                terms: 'Official StyleSync Binding Agreement for ${q.scopeSummary}. Milestone schedule: 50% advance deposit due upon signing, and 50% balance upon final quality inspection and room handover.',
                createdAt: q.createdAt ?? DateTime.now(),
                updatedAt: q.updatedAt ?? DateTime.now(),
                quote: q,
              ));
            }
          }
        }

        if (status == null || status == 'All statuses') {
          _localContracts.clear();
          _localContracts.addAll(contracts);
        }

        return contracts;
      } else {
        debugPrint('[QuotesContractsService] listContracts server error status: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[QuotesContractsService] listContracts API error: $e. Returning cached store.');
    }

    // Auto-link submitted quotes in offline fallback too
    for (final q in _localQuotes) {
      final s = q.status;
      if (s == 'Submitted' || s == 'ClientReview') {
        if (!_localContracts.any((c) => c.quoteId == q.id)) {
          final shortId = q.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          _localContracts.insert(0, Contract(
            id: 'cnt-${shortId.length >= 4 ? shortId.substring(0, 4) : shortId}',
            quoteId: q.id,
            projectRequestId: q.projectRequestId,
            designerId: q.designerId,
            clientId: 'client-default',
            status: 'PendingSignature',
            totalAmount: q.totalCost,
            termsSummary: q.scopeSummary.isNotEmpty ? q.scopeSummary : 'Interior Design Agreement',
            terms: 'Official StyleSync Binding Agreement for ${q.scopeSummary}. Milestone schedule: 50% advance deposit due upon signing, and 50% balance upon final quality inspection and room handover.',
            createdAt: q.createdAt ?? DateTime.now(),
            updatedAt: q.updatedAt ?? DateTime.now(),
            quote: q,
          ));
        }
      }
    }

    var filtered = List<Contract>.from(_localContracts);
    if (status != null && status.isNotEmpty && status != 'All statuses') {
      filtered = filtered.where((c) => c.status.toLowerCase() == status.toLowerCase()).toList();
    }
    return filtered;
  }

  Future<Contract> signContract(String id) async {
    final uri = Uri.parse('$_baseUrl/contracts/$id/sign');
    final headers = await _getHeaders();
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'signedAt': DateTime.now().toUtc().toIso8601String()}),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      final updated = Contract.fromJson(Map<String, dynamic>.from(decoded as Map));
      final idx = _localContracts.indexWhere((c) => c.id == id);
      if (idx != -1) _localContracts[idx] = updated;
      return updated;
    } else {
      throw Exception('Failed to sign contract (${res.statusCode}): ${res.body}');
    }
  }

  Future<Contract> cancelContract(String id) async {
    final uri = Uri.parse('$_baseUrl/contracts/$id/cancel');
    final headers = await _getHeaders();
    final res = await http.post(uri, headers: headers).timeout(const Duration(seconds: 8));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      final updated = Contract.fromJson(Map<String, dynamic>.from(decoded as Map));
      final idx = _localContracts.indexWhere((c) => c.id == id);
      if (idx != -1) _localContracts[idx] = updated;
      return updated;
    } else {
      throw Exception('Failed to cancel contract (${res.statusCode}): ${res.body}');
    }
  }

  Future<Contract?> getContract(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/contracts/$id');
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        return Contract.fromJson(Map<String, dynamic>.from(decoded as Map));
      }
    } catch (e) {
      debugPrint('[QuotesContractsService] getContract error: $e');
    }
    final idx = _localContracts.indexWhere((c) => c.id == id);
    return idx != -1 ? _localContracts[idx] : null;
  }

  Future<Quote?> getQuote(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/quotes/$id');
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 6));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        return Quote.fromJson(Map<String, dynamic>.from(decoded as Map));
      }
    } catch (e) {
      debugPrint('[QuotesContractsService] getQuote error: $e');
    }
    final idx = _localQuotes.indexWhere((q) => q.id == id);
    return idx != -1 ? _localQuotes[idx] : null;
  }
}
