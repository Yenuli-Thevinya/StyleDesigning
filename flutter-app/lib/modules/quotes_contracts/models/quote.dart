import 'quote_item.dart';

class QuoteVersionItem {
  final String id;
  final String description;
  final String category;
  final int quantity;
  final double unitCost;
  final double lineTotal;

  QuoteVersionItem({
    required this.id,
    required this.description,
    required this.category,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
  });

  factory QuoteVersionItem.fromJson(Map<String, dynamic> json) {
    return QuoteVersionItem(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Other',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class QuoteVersion {
  final String id;
  final int versionNumber;
  final String authorId;
  final String authorRole;
  final double materialsSubtotal;
  final double laborSubtotal;
  final double designFee;
  final double contingencyAmount;
  final double taxAmount;
  final double totalCost;
  final String? notes;
  final DateTime createdAt;
  final List<QuoteVersionItem> items;

  QuoteVersion({
    required this.id,
    required this.versionNumber,
    required this.authorId,
    required this.authorRole,
    required this.materialsSubtotal,
    required this.laborSubtotal,
    required this.designFee,
    required this.contingencyAmount,
    required this.taxAmount,
    required this.totalCost,
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  factory QuoteVersion.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return QuoteVersion(
      id: json['id']?.toString() ?? '',
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 1,
      authorId: json['authorId']?.toString() ?? '',
      authorRole: json['authorRole']?.toString() ?? 'Designer',
      materialsSubtotal: (json['materialsSubtotal'] as num?)?.toDouble() ?? 0.0,
      laborSubtotal: (json['laborSubtotal'] as num?)?.toDouble() ?? 0.0,
      designFee: (json['designFee'] as num?)?.toDouble() ?? 0.0,
      contingencyAmount: (json['contingencyAmount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      items: rawItems.map((e) => QuoteVersionItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class Quote {
  final String id;
  final String projectRequestId;
  final String designerId;
  final String scopeSummary;
  final String? notes;
  final bool isAiGenerated;
  final String status;
  final double totalCost;
  final List<QuoteItem> items;
  final QuoteVersion? currentVersion;
  final List<QuoteVersion> versions;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? contractId;

  Quote({
    required this.id,
    required this.projectRequestId,
    required this.designerId,
    required this.scopeSummary,
    this.notes,
    this.isAiGenerated = false,
    this.status = 'Draft',
    required this.totalCost,
    this.items = const [],
    this.currentVersion,
    this.versions = const [],
    this.createdAt,
    this.updatedAt,
    this.contractId,
  });

  static String normalizeStatus(dynamic raw) {
    if (raw == null) return 'Draft';
    final val = raw is Map ? (raw['name'] ?? raw['value'] ?? 'Draft').toString() : raw.toString();
    if (val == 'Stage1Pending') return 'Submitted';
    if (val == 'Stage1Released') return 'ClientReview';
    if (val == 'Stage2Approved') return 'Accepted';
    if (val == 'Stage2ChangesRequested' || val == 'Stage1RevisionRequested') return 'RevisionRequested';
    if (val == 'Stage1Rejected' || val == 'Stage2Rejected') return 'Rejected';
    return val;
  }

  factory Quote.fromJson(Map<String, dynamic> json) {
    final statusStr = normalizeStatus(json['status']);

    final rawItems = json['items'] as List<dynamic>? ?? [];
    final itemsList = <QuoteItem>[];
    for (final item in rawItems) {
      if (item is Map) {
        try {
          itemsList.add(QuoteItem.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          // ignore item parse error
        }
      }
    }

    QuoteVersion? currentVer;
    if (json['currentVersion'] != null && json['currentVersion'] is Map<String, dynamic>) {
      currentVer = QuoteVersion.fromJson(json['currentVersion']);
    }

    final rawVersions = json['versions'] as List<dynamic>? ?? [];
    final versionsList = rawVersions.map((e) => QuoteVersion.fromJson(e as Map<String, dynamic>)).toList();

    double total = (json['totalCost'] is num)
        ? (json['totalCost'] as num).toDouble()
        : double.tryParse(json['totalCost']?.toString() ?? '0') ?? 0.0;

    if (total == 0 && itemsList.isNotEmpty) {
      total = itemsList.fold(0.0, (sum, i) => sum + i.calculatedTotal);
    }

    DateTime? created;
    if (json['createdAt'] != null) {
      created = DateTime.tryParse(json['createdAt'].toString());
    }
    DateTime? updated;
    if (json['updatedAt'] != null) {
      updated = DateTime.tryParse(json['updatedAt'].toString());
    }

    return Quote(
      id: json['id']?.toString() ?? '',
      projectRequestId: json['projectRequestId']?.toString() ?? '',
      designerId: json['designerId']?.toString() ?? '',
      scopeSummary: json['scopeSummary']?.toString() ?? 'Untitled Scope',
      notes: json['notes']?.toString(),
      isAiGenerated: json['isAiGenerated'] == true,
      status: statusStr,
      totalCost: total,
      items: itemsList,
      currentVersion: currentVer,
      versions: versionsList,
      createdAt: created,
      updatedAt: updated,
      contractId: json['contractId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectRequestId': projectRequestId,
      'designerId': designerId,
      'scopeSummary': scopeSummary,
      if (notes != null) 'notes': notes,
      'isAiGenerated': isAiGenerated,
      'status': status,
      'totalCost': totalCost,
      'items': items.map((e) => e.toJson()).toList(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (contractId != null) 'contractId': contractId,
    };
  }

  Quote copyWith({
    String? id,
    String? projectRequestId,
    String? designerId,
    String? scopeSummary,
    String? notes,
    bool? isAiGenerated,
    String? status,
    double? totalCost,
    List<QuoteItem>? items,
    QuoteVersion? currentVersion,
    List<QuoteVersion>? versions,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? contractId,
  }) {
    return Quote(
      id: id ?? this.id,
      projectRequestId: projectRequestId ?? this.projectRequestId,
      designerId: designerId ?? this.designerId,
      scopeSummary: scopeSummary ?? this.scopeSummary,
      notes: notes ?? this.notes,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      status: status ?? this.status,
      totalCost: totalCost ?? this.totalCost,
      items: items ?? this.items,
      currentVersion: currentVersion ?? this.currentVersion,
      versions: versions ?? this.versions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contractId: contractId ?? this.contractId,
    );
  }
}
