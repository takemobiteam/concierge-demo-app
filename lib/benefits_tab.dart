import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// Suggestion-chip categories the concierge understands for OPEN_CHIPS.
const List<String> kChipCategories = ['support', 'default'];

class BenefitsTab extends StatelessWidget {
  final ValueChanged<String> onOpenChips;
  final ValueChanged<String> onOpenPrompt;

  const BenefitsTab({
    super.key,
    required this.onOpenChips,
    required this.onOpenPrompt,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text('Benefits', style: kScreenTitleStyle),
        const SizedBox(height: 24),
        _BenefitsSection(
          title: 'Suggestion chips',
          children: [
            for (final category in kChipCategories)
              MoreRow(
                icon: Icons.chat_bubble_outline,
                label: 'Open "$category" chips',
                subtitle: 'OPEN_CHIPS → $category',
                onTap: () => onOpenChips(category),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _BenefitsSection(
          title: 'Prompt',
          children: [
            MoreRow(
              icon: Icons.send_outlined,
              label: 'Ask "What benefits do I have?"',
              subtitle: 'OPEN_PROMPT',
              onTap: () => onOpenPrompt('what benefits do i have?'),
            ),
          ],
        ),
      ],
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _BenefitsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: kSectionLabelStyle),
        const SizedBox(height: 10),
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          children[i],
        ],
      ],
    );
  }
}
