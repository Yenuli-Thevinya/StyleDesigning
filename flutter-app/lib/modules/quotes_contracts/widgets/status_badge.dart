import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isLarge;

  const StatusBadge({
    super.key,
    required this.status,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    Color border;

    String displayStatus = status.isEmpty ? 'Draft' : status;
    final normalized = status.toLowerCase();

    if (normalized == 'stage1pending') {
      displayStatus = 'Submitted';
    } else if (normalized == 'stage1released' || normalized == 'clientreview') {
      displayStatus = 'Client Review';
    } else if (normalized == 'stage2approved') {
      displayStatus = 'Accepted';
    } else if (normalized == 'pendingsignature') {
      displayStatus = 'Pending Signature';
    } else if (normalized == 'revisionrequested' || normalized == 'stage2changesrequested' || normalized == 'stage1revisionrequested') {
      displayStatus = 'Revision Requested';
    }

    switch (normalized) {
      case 'active':
      case 'accepted':
      case 'completed':
      case 'stage2approved':
        bg = const Color(0x2E10B981);
        text = const Color(0xFF34D399);
        border = const Color(0x6610B981);
        break;
      case 'cancelled':
      case 'rejected':
      case 'stage1rejected':
      case 'stage2rejected':
        bg = const Color(0x2EEF4444);
        text = const Color(0xFFF87171);
        border = const Color(0x66EF4444);
        break;
      case 'submitted':
      case 'clientreview':
      case 'stage1pending':
      case 'stage1released':
      case 'pendingsignature':
        bg = const Color(0x2EC48A36);
        text = const Color(0xFFE8A849);
        border = const Color(0x66C48A36);
        break;
      case 'revisionrequested':
      case 'stage2changesrequested':
      case 'stage1revisionrequested':
        bg = const Color(0x2E3B82F6);
        text = const Color(0xFF60A5FA);
        border = const Color(0x663B82F6);
        break;
      case 'draft':
      default:
        bg = const Color(0xFF26211D);
        text = const Color(0xFFD6CEC6);
        border = const Color(0xFF3D352E);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 9,
        vertical: isLarge ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: text,
          fontSize: isLarge ? 12 : 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
