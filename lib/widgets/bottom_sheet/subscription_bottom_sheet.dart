import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/subscription_constants.dart';
import 'package:nursing_quiz_app_6/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class SubscriptionBottomSheet extends StatelessWidget {
  final List<SubscriptionPlan> plans;
  final Function(BuildContext, SubscriptionPlan) onSubscriptionSelected;

  const SubscriptionBottomSheet({
    super.key,
    required this.plans,
    required this.onSubscriptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: themeProvider.currentTheme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildDragHandle(themeProvider),
          _buildHeader(themeProvider),
          _buildSubscriptionList(),
          _buildFeatures(themeProvider),
          _buildDisclaimer(themeProvider),
        ],
      ),
    );
  }

  Widget _buildDragHandle(ThemeProvider themeProvider) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
        color:
            themeProvider.currentTheme.colorScheme.onSurface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.currentTheme.colorScheme.primary
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_open_rounded,
              size: 48,
              color: themeProvider.currentTheme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '프리미엄 구독',
                  style: themeProvider.currentTheme.textTheme.headlineMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '무제한으로 모든 기능을 이용하세요',
                  style:
                      themeProvider.currentTheme.textTheme.titleLarge?.copyWith(
                    color: themeProvider.currentTheme.colorScheme.onSurface
                        .withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: plans.length,
        itemBuilder: (context, index) {
          final plan = plans[index];
          return _SubscriptionCard(
            plan: plan,
            onTap: () => onSubscriptionSelected(context, plan),
          );
        },
      ),
    );
  }

  Widget _buildFeatures(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '구독 혜택',
            style: themeProvider.currentTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const _FeatureItem(text: '무제한 퀴즈 풀이'),
          const _FeatureItem(text: '모든 카테고리 접근'),
          const _FeatureItem(text: '상세한 해설'),
          const _FeatureItem(text: 'AI 맞춤형 복습'),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        '구독은 선택한 기간이 종료되면 자동으로 갱신되며,\n해지하지 않으면 동일한 가격으로 자동 결제됩니다.\n언제든지 AppStore 설정에서 구독을 관리할 수 있습니다.',
        style: themeProvider.currentTheme.textTheme.bodySmall?.copyWith(
          color:
              themeProvider.currentTheme.colorScheme.onSurface.withOpacity(0.6),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onTap;

  const _SubscriptionCard({
    required this.plan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: plan.isPopular
              ? themeProvider.currentTheme.colorScheme.primary
              : themeProvider.currentTheme.colorScheme.outline,
          width: plan.isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.isPopular)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeProvider.currentTheme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '인기',
                      style: TextStyle(
                        color: themeProvider.currentTheme.colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title,
                            style: themeProvider
                                .currentTheme.textTheme.titleLarge
                                ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.description,
                            style: themeProvider
                                .currentTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: themeProvider
                                  .currentTheme.colorScheme.onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (plan.id == SubscriptionIds.yearlyId)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: themeProvider
                                    .currentTheme.colorScheme.primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 16,
                                    color: themeProvider
                                        .currentTheme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '3일 무료 체험 후 결제',
                                    style: themeProvider
                                        .currentTheme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: themeProvider
                                          .currentTheme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          plan.price,
                          style: themeProvider.currentTheme.textTheme.titleLarge
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (plan.savePercent != '0')
                          Text(
                            '${plan.savePercent}% 할인',
                            style: TextStyle(
                              color: themeProvider
                                  .currentTheme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
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

class _FeatureItem extends StatelessWidget {
  final String text;

  const _FeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
}
