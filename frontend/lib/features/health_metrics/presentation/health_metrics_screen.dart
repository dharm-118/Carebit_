import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_client/constants/app_constants.dart';
import 'package:mobile_client/models/health_metric.dart';

import '../../../app/theme/app_theme.dart';

/// Starter health metrics screen.
///
/// This is an initial UI scaffold inspired by the uploaded reference images.
/// In later steps, this screen will:
/// - fetch health metrics from Firestore
/// - display real Fitbit-synced values
/// - show anomaly cards based on stored data
class HealthMetricsScreen extends StatelessWidget {
  const HealthMetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CarebitColors colors = context.carebitColors;

    /// Step 3: Using shared HealthMetric model from mobile_client.
    final List<HealthMetric> placeholderMetrics = <HealthMetric>[
      HealthMetric(
        userId: 'placeholder-user',
        metricType: AppConstants.metricTypeSpo2,
        value: 97,
        unit: '%',
        timestamp: DateTime.now(),
        source: AppConstants.providerFitbit,
        deviceId: 'placeholder-device',
        rawPayload: const <String, dynamic>{},
      ),
      HealthMetric(
        userId: 'placeholder-user',
        metricType: AppConstants.metricTypeBmr,
        value: 1500,
        unit: 'kcal',
        timestamp: DateTime.now(),
        source: AppConstants.providerFitbit,
        deviceId: 'placeholder-device',
        rawPayload: const <String, dynamic>{},
      ),
      HealthMetric(
        userId: 'placeholder-user',
        metricType: AppConstants.metricTypeSteps,
        value: 0,
        unit: 'steps',
        timestamp: DateTime.now(),
        source: AppConstants.providerFitbit,
        deviceId: 'placeholder-device',
        rawPayload: const <String, dynamic>{},
      ),
    ];

    final HealthMetric? oxygenMetric = _findMetric(
      placeholderMetrics,
      AppConstants.metricTypeSpo2,
    );
    final HealthMetric? bmrMetric = _findMetric(
      placeholderMetrics,
      AppConstants.metricTypeBmr,
    );
    final HealthMetric? stepsMetric = _findMetric(
      placeholderMetrics,
      AppConstants.metricTypeSteps,
    );

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 136),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HealthHeader(healthScore: 78),
                  const SizedBox(height: 22),
                  _WeeklySummarySection(colors: colors),
                  const SizedBox(height: 20),
                  _AnomaliesSection(colors: colors),
                  const SizedBox(height: 20),
                  _VitalsSection(
                    colors: colors,
                    theme: theme,
                    oxygenMetric: oxygenMetric,
                    bmrMetric: bmrMetric,
                    stepsMetric: stepsMetric,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _BottomNavigationCard(colors: colors),
            ),
          ],
        ),
      ),
    );
  }
}

HealthMetric? _findMetric(List<HealthMetric> metrics, String metricType) {
  for (final HealthMetric metric in metrics) {
    if (metric.metricType == metricType) {
      return metric;
    }
  }

  return null;
}

class _HealthHeader extends StatelessWidget {
  const _HealthHeader({required this.healthScore});

  final int healthScore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CarebitColors colors = context.carebitColors;
    final Color onPrimary = theme.colorScheme.onPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.gradientStart, colors.gradientEnd],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Text(
                'Health Report',
                style: TextStyle(
                  color: onPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.assignment_rounded, color: onPrimary, size: 22),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mar 16-22, 2026 | Weekly Summary',
            style: TextStyle(
              color: onPrimary.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: onPrimary.withValues(alpha: 0.10),
              border: Border.all(color: onPrimary.withValues(alpha: 0.16)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                _ScoreRing(score: healthScore),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Health Score',
                        style: TextStyle(
                          color: onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+4 from last week | Good',
                        style: TextStyle(
                          color: onPrimary.withValues(alpha: 0.88),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on heart, sleep, activity',
                        style: TextStyle(
                          color: onPrimary.withValues(alpha: 0.74),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 78,
      height: 78,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          progress: score / AppConstants.healthScoreMax,
          onPrimary: theme.colorScheme.onPrimary,
        ),
        child: Center(
          child: Text(
            '$score',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({required this.progress, required this.onPrimary});

  final double progress;
  final Color onPrimary;

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 6.5;
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = onPrimary.withValues(alpha: 0.28);

    final Paint progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        colors: <Color>[onPrimary, onPrimary.withValues(alpha: 0.92)],
      ).createShader(rect);

    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.onPrimary != onPrimary;
  }
}

class _WeeklySummarySection extends StatelessWidget {
  const _WeeklySummarySection({required this.colors});

  final CarebitColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionTitle(text: 'Weekly Summary', colors: colors),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.95,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: <Widget>[
              _SummaryCard(
                label: 'AVG HEART RATE',
                value: '74',
                unit: 'bpm',
                delta: '-3 from last wk',
                deltaColor: colors.danger,
                colors: colors,
              ),
              _SummaryCard(
                label: 'AVG SLEEP',
                value: '7h 18m',
                delta: '-22m from last wk',
                deltaColor: colors.danger,
                colors: colors,
              ),
              _SummaryCard(
                label: 'TOTAL STEPS',
                value: '54,720',
                delta: '+8% from last wk',
                deltaColor: colors.success,
                colors: colors,
              ),
              _SummaryCard(
                label: 'CALS BURNED',
                value: '12,494',
                delta: '+5% from last wk',
                deltaColor: colors.success,
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaColor,
    required this.colors,
    this.unit,
  });

  final String label;
  final String value;
  final String delta;
  final Color deltaColor;
  final CarebitColors colors;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: colors.summaryLabel,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4,
            children: <Widget>[
              Text(
                value,
                style: TextStyle(
                  color: colors.summaryValue,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit!,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            delta,
            style: TextStyle(
              color: deltaColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnomaliesSection extends StatelessWidget {
  const _AnomaliesSection({required this.colors});

  final CarebitColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionTitle(text: 'Anomalies Detected', colors: colors),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.anomalyBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.anomalyBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _AlertIcon(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'High Heart Rate Episode',
                        style: TextStyle(
                          color: colors.anomalyText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Thu Feb 15, 3:42 PM | 142 bpm for 8 min.',
                        style: TextStyle(
                          color: colors.mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Consider consulting your doctor if recurring.',
                        style: TextStyle(
                          color: colors.mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertIcon extends StatelessWidget {
  const _AlertIcon();

  @override
  Widget build(BuildContext context) {
    final CarebitColors colors = context.carebitColors;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.warningBackground,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.warning_amber_rounded,
        color: colors.warningForeground,
        size: 24,
      ),
    );
  }
}

class _VitalsSection extends StatelessWidget {
  const _VitalsSection({
    required this.colors,
    required this.theme,
    required this.oxygenMetric,
    required this.bmrMetric,
    required this.stepsMetric,
  });

  final CarebitColors colors;
  final ThemeData theme;
  final HealthMetric? oxygenMetric;
  final HealthMetric? bmrMetric;
  final HealthMetric? stepsMetric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionTitle(text: 'Today\'s Vitals', colors: colors),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                _VitalRow(
                  icon: Icons.favorite_rounded,
                  title: 'Resting Heart Rate',
                  value: 'No data',
                  iconBackground: colors.softPink,
                  iconColor: colors.heartIcon,
                  colors: colors,
                ),
                const _VitalDivider(),
                _VitalRow(
                  icon: Icons.air_rounded,
                  title: 'Oxygen Level (SpO2)',
                  value: oxygenMetric == null
                      ? 'No data'
                      : '${oxygenMetric!.value.toStringAsFixed(0)}${oxygenMetric!.unit}',
                  iconBackground: colors.softGreen,
                  iconColor: colors.oxygenIcon,
                  colors: colors,
                ),
                const _VitalDivider(),
                _VitalRow(
                  icon: Icons.local_fire_department_rounded,
                  title: 'BMR (Basal Metabolic Rate)',
                  value: bmrMetric == null
                      ? 'No data'
                      : '${bmrMetric!.value.toStringAsFixed(0)} ${bmrMetric!.unit}',
                  iconBackground: colors.softOrange,
                  iconColor: colors.burnIcon,
                  colors: colors,
                ),
                const _VitalDivider(),
                _VitalRow(
                  icon: Icons.directions_walk_rounded,
                  title: 'Steps Today',
                  value: stepsMetric == null || stepsMetric!.value == 0
                      ? 'No steps yet'
                      : stepsMetric!.value.toStringAsFixed(0),
                  iconBackground: colors.softBlue,
                  iconColor: colors.stepsIcon,
                  colors: colors,
                ),
                const _VitalDivider(),
                _VitalRow(
                  icon: Icons.bedtime_rounded,
                  title: 'Sleep',
                  value: 'No data',
                  iconBackground: colors.softPurple,
                  iconColor: colors.sleepIcon,
                  colors: colors,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalRow extends StatelessWidget {
  const _VitalRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.iconBackground,
    required this.colors,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final Color iconBackground;
  final CarebitColors colors;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bool mutedValue = value == 'No data' || value == 'No steps yet';

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, isLast ? 18 : 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Icon(icon, color: iconColor, size: 21)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.brandText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: mutedValue ? colors.vitalValueMuted : colors.summaryValue,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalDivider extends StatelessWidget {
  const _VitalDivider();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
    );
  }
}

class _BottomNavigationCard extends StatelessWidget {
  const _BottomNavigationCard({required this.colors});

  final CarebitColors colors;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.42),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isSelected: false,
            activeColor: colors.gradientStart,
            inactiveColor: colors.navInactive,
          ),
          _NavItem(
            icon: Icons.favorite_rounded,
            label: 'Health',
            isSelected: true,
            activeColor: colors.gradientStart,
            inactiveColor: colors.navInactive,
          ),
          _AddButton(colors: colors),
          _NavItem(
            icon: Icons.notifications_rounded,
            label: 'Alerts',
            isSelected: false,
            activeColor: colors.gradientStart,
            inactiveColor: colors.navInactive,
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            isSelected: false,
            activeColor: colors.gradientStart,
            inactiveColor: colors.navInactive,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final Color color = isSelected ? activeColor : inactiveColor;

    return SizedBox(
      width: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: isSelected ? 1 : 0.64),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.colors});

  final CarebitColors colors;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.gradientStart, colors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.34),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.favorite_rounded,
        color: theme.colorScheme.onPrimary,
        size: 28,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.colors});

  final String text;
  final CarebitColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: colors.brandText,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
