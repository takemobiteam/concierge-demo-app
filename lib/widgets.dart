import 'package:flutter/material.dart';

import 'theme.dart';

/// A tappable card row, used by the More and Benefits tabs.
class MoreRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const MoreRow({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF24242A)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kAccentColor, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: kRowTitleStyle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: kRowSubtitleStyle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kMutedText),
          ],
        ),
      ),
    );
  }
}

/// A centered label, used for tabs that don't have real content yet.
class PlaceholderTab extends StatelessWidget {
  final String label;
  const PlaceholderTab({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: const TextStyle(color: kMutedText, fontSize: 20)),
    );
  }
}

/// Small pill showing the concierge's active locale.
class LocaleBadge extends StatelessWidget {
  final String locale;
  const LocaleBadge({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccentColor.withValues(alpha: 0.7)),
      ),
      child: Text(
        locale,
        style: const TextStyle(
          color: kAccentColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Helvetica',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
