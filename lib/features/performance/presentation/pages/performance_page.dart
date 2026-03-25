import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../components/feedback/empty_state.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../models/performance/performance_entry.dart';
import '../../provider/performance_providers.dart';

class PerformancePage extends ConsumerWidget {
  const PerformancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entries = ref.watch(filteredPerformanceEntriesProvider);

    if (entries.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.gauge,
        title: 'No Performance Data',
        subtitle: 'Connect an app with DevConnect SDK to start profiling',
      );
    }

    final fps = ref.watch(latestFpsProvider);
    final memory = ref.watch(latestMemoryProvider);
    final cpu = ref.watch(latestCpuProvider);
    final jankCount = ref.watch(jankFrameCountProvider);
    final fpsHistory = ref.watch(fpsHistoryProvider);
    final memoryHistory = ref.watch(memoryHistoryProvider);
    final cpuHistory = ref.watch(cpuHistoryProvider);

    return Column(
      children: [
        // Toolbar
        _Toolbar(
          isDark: isDark,
          onClear: () => ref.read(performanceEntriesProvider.notifier).clear(),
        ),
        // Metric cards
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'FPS',
                  value: fps != null ? fps.toStringAsFixed(1) : '--',
                  icon: LucideIcons.monitor,
                  color: _fpsColor(fps),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Memory',
                  value: memory != null
                      ? '${memory.toStringAsFixed(1)} MB'
                      : '--',
                  icon: LucideIcons.memoryStick,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'CPU',
                  value: cpu != null ? '${cpu.toStringAsFixed(1)}%' : '--',
                  icon: LucideIcons.cpu,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Jank Frames',
                  value: '$jankCount',
                  icon: LucideIcons.triangleAlert,
                  color: jankCount > 0
                      ? const Color(0xFFEF4444)
                      : ColorTokens.success,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        // Charts
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Expanded(
                  child: _ChartCard(
                    title: 'FPS',
                    entries: fpsHistory,
                    color: const Color(0xFF10B981),
                    maxY: 120,
                    targetLine: 60,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _ChartCard(
                    title: 'Memory Usage (MB)',
                    entries: memoryHistory,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _ChartCard(
                    title: 'CPU Usage (%)',
                    entries: cpuHistory,
                    color: const Color(0xFFF59E0B),
                    maxY: 100,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _fpsColor(double? fps) {
    if (fps == null) return Colors.grey;
    if (fps >= 55) return const Color(0xFF10B981);
    if (fps >= 30) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

// ---- Toolbar ----

class _Toolbar extends StatelessWidget {
  final bool isDark;
  final VoidCallback onClear;

  const _Toolbar({required this.isDark, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.gauge, size: 16, color: ColorTokens.primary),
          const SizedBox(width: 8),
          Text(
            'Performance Profiling',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          _MiniButton(
            icon: LucideIcons.trash2,
            tooltip: 'Clear',
            isDark: isDark,
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

// ---- Metric Card ----

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Chart Card ----

class _ChartCard extends StatelessWidget {
  final String title;
  final List<PerformanceEntry> entries;
  final Color color;
  final double? maxY;
  final double? targetLine;
  final bool isDark;

  const _ChartCard({
    required this.title,
    required this.entries,
    required this.color,
    this.maxY,
    this.targetLine,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                Text(
                  '${entries.length} samples',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entries.length < 2
                ? Center(
                    child: Text(
                      'Waiting for data...',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: _LineChartPainter(
                      entries: entries,
                      color: color,
                      isDark: isDark,
                      maxY: maxY,
                      targetLine: targetLine,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---- Line Chart Painter ----

class _LineChartPainter extends CustomPainter {
  final List<PerformanceEntry> entries;
  final Color color;
  final bool isDark;
  final double? maxY;
  final double? targetLine;

  _LineChartPainter({
    required this.entries,
    required this.color,
    required this.isDark,
    this.maxY,
    this.targetLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;

    // Take last 100 points max
    final data = entries.length > 100
        ? entries.sublist(entries.length - 100)
        : entries;

    final computedMaxY = maxY ??
        data.fold<double>(0, (m, e) => math.max(m, e.value)) * 1.2;
    if (computedMaxY <= 0) return;

    final w = size.width;
    final h = size.height;
    final stepX = w / (data.length - 1);

    // Grid lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Target line (e.g., 60 FPS)
    if (targetLine != null) {
      final targetY = h - (targetLine! / computedMaxY) * h;
      final targetPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.4)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, targetY), Offset(w, targetY), targetPaint);
    }

    // Build path
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = h - (data[i].value / computedMaxY).clamp(0.0, 1.0) * h;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Fill gradient
    fillPath.lineTo(w, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Latest value dot
    final lastX = (data.length - 1) * stepX;
    final lastY =
        h - (data.last.value / computedMaxY).clamp(0.0, 1.0) * h;

    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(lastX, lastY),
      2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      entries.length != oldDelegate.entries.length ||
      (entries.isNotEmpty &&
          oldDelegate.entries.isNotEmpty &&
          entries.last.value != oldDelegate.entries.last.value);
}

// ---- Mini Button ----

class _MiniButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MiniButton> createState() => _MiniButtonState();
}

class _MiniButtonState extends State<_MiniButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered
                  ? (widget.isDark ? Colors.white70 : Colors.black54)
                  : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }
}
