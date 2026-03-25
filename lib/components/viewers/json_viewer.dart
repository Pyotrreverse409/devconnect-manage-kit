import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/color_tokens.dart';

class JsonViewer extends StatelessWidget {
  final dynamic data;
  final bool initiallyExpanded;

  const JsonViewer({
    super.key,
    required this.data,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Text('null', style: Theme.of(context).textTheme.labelMedium);
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JsonNode(
            keyName: null,
            value: data,
            depth: 0,
            initiallyExpanded: initiallyExpanded,
          ),
        ],
      ),
    );
  }
}

class _JsonNode extends StatefulWidget {
  final String? keyName;
  final dynamic value;
  final int depth;
  final bool initiallyExpanded;

  const _JsonNode({
    required this.keyName,
    required this.value,
    required this.depth,
    this.initiallyExpanded = false,
  });

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  late bool _expanded;
  List<_JsonNode>? _cachedChildren;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded && widget.depth < 2;
  }

  @override
  void didUpdateWidget(_JsonNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Invalidate cache if value identity changes
    if (!identical(oldWidget.value, widget.value)) {
      _cachedChildren = null;
    }
  }

  List<_JsonNode> _buildChildren() {
    if (_cachedChildren != null) return _cachedChildren!;

    if (widget.value is Map) {
      _cachedChildren = (widget.value as Map).entries.map((e) {
        return _JsonNode(
          keyName: e.key.toString(),
          value: e.value,
          depth: widget.depth + 1,
        );
      }).toList();
    } else if (widget.value is List) {
      _cachedChildren = (widget.value as List).asMap().entries.map((e) {
        return _JsonNode(
          keyName: '${e.key}',
          value: e.value,
          depth: widget.depth + 1,
        );
      }).toList();
    } else {
      _cachedChildren = [];
    }
    return _cachedChildren!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final indent = widget.depth * 16.0;

    if (widget.value is Map) {
      return _buildExpandable(
        '{${(widget.value as Map).length}}',
        indent,
        isDark,
      );
    }

    if (widget.value is List) {
      return _buildExpandable(
        '[${(widget.value as List).length}]',
        indent,
        isDark,
      );
    }

    // Primitive value
    Color valueColor;
    String displayValue;

    if (widget.value is String) {
      valueColor = isDark ? const Color(0xFF98C379) : const Color(0xFF50A14F);
      displayValue = '"${widget.value}"';
    } else if (widget.value is num) {
      valueColor = isDark ? const Color(0xFFD19A66) : const Color(0xFF986801);
      displayValue = '${widget.value}';
    } else if (widget.value is bool) {
      valueColor = isDark ? const Color(0xFF56B6C2) : const Color(0xFF0184BC);
      displayValue = '${widget.value}';
    } else {
      valueColor = Colors.grey;
      displayValue = 'null';
    }

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: GestureDetector(
        onDoubleTap: () {
          Clipboard.setData(
            ClipboardData(text: widget.value?.toString() ?? 'null'),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.keyName != null) ...[
                Text(
                  '${widget.keyName}: ',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFE06C75)
                        : ColorTokens.primary,
                  ),
                ),
              ],
              Flexible(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandable(String badge, double indent, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 16,
                      color: Colors.grey,
                    ),
                    if (widget.keyName != null) ...[
                      Text(
                        '${widget.keyName}: ',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFE06C75)
                              : ColorTokens.primary,
                        ),
                      ),
                    ],
                    Text(
                      badge,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ..._buildChildren(),
      ],
    );
  }
}

class JsonPrettyViewer extends StatelessWidget {
  final dynamic data;

  const JsonPrettyViewer({super.key, required this.data});

  static final _tokenPattern = RegExp(
    r'("(?:[^"\\]|\\.)*")\s*:'       // key followed by colon
    r'|("(?:[^"\\]|\\.)*")'          // string value
    r'|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)' // number
    r'|(true|false)'                  // boolean
    r'|(null)'                        // null
    r'|([{}\[\]])'                    // brackets
    r'|([,:])'                        // punctuation
  );

  List<TextSpan> _highlight(String source, bool isDark) {
    // Colors — dark
    const dKey = Color(0xFF9CDCFE);
    const dString = Color(0xFFCE9178);
    const dNumber = Color(0xFFB5CEA8);
    const dBool = Color(0xFF569CD6);
    const dNull = Color(0xFF569CD6);
    const dBracket = Color(0xFFFFD700);
    const dPunct = Color(0xFFD4D4D4);
    const dPlain = Color(0xFFD4D4D4);
    // Colors — light
    const lKey = Color(0xFF0451A5);
    const lString = Color(0xFFA31515);
    const lNumber = Color(0xFF098658);
    const lBool = Color(0xFF0000FF);
    const lNull = Color(0xFF0000FF);
    const lBracket = Color(0xFF000000);
    const lPunct = Color(0xFF000000);
    const lPlain = Color(0xFF1F2328);

    final spans = <TextSpan>[];
    int cursor = 0;

    for (final m in _tokenPattern.allMatches(source)) {
      // Text before this match (whitespace / newlines)
      if (m.start > cursor) {
        spans.add(TextSpan(
          text: source.substring(cursor, m.start),
          style: TextStyle(color: isDark ? dPlain : lPlain),
        ));
      }

      Color color;
      if (m.group(1) != null) {
        // Key
        color = isDark ? dKey : lKey;
      } else if (m.group(2) != null) {
        // String value
        color = isDark ? dString : lString;
      } else if (m.group(3) != null) {
        // Number
        color = isDark ? dNumber : lNumber;
      } else if (m.group(4) != null) {
        // Boolean
        color = isDark ? dBool : lBool;
      } else if (m.group(5) != null) {
        // Null
        color = isDark ? dNull : lNull;
      } else if (m.group(6) != null) {
        // Brackets
        color = isDark ? dBracket : lBracket;
      } else {
        // Punctuation
        color = isDark ? dPunct : lPunct;
      }

      final fontWeight =
          (m.group(1) != null) ? FontWeight.w600 : FontWeight.normal;

      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(color: color, fontWeight: fontWeight),
      ));

      cursor = m.end;
    }

    // Trailing text
    if (cursor < source.length) {
      spans.add(TextSpan(
        text: source.substring(cursor),
        style: TextStyle(color: isDark ? dPlain : lPlain),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String formatted;
    try {
      formatted = const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      formatted = data?.toString() ?? 'null';
    }

    final lines = formatted.split('\n');
    final spans = _highlight(formatted, isDark);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252526) : const Color(0xFFF0F0F0),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
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
                Icon(LucideIcons.braces, size: 12,
                    color: isDark ? const Color(0xFFFFD700) : const Color(0xFF0451A5)),
                const SizedBox(width: 6),
                Text(
                  'JSON',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'JetBrains Mono',
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${lines.length} lines',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'JetBrains Mono',
                    color: Colors.grey[500],
                  ),
                ),
                const Spacer(),
                _MiniButton(
                  icon: LucideIcons.copy,
                  tooltip: 'Copy JSON',
                  isDark: isDark,
                  onTap: () =>
                      Clipboard.setData(ClipboardData(text: formatted)),
                ),
              ],
            ),
          ),
          // Code area with line numbers
          Padding(
            padding: const EdgeInsets.all(0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line numbers gutter
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        lines.length,
                        (i) => SizedBox(
                          height: 18,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              height: 1.5,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Code content
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    child: SelectableText.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          height: 1.5,
                        ),
                        children: spans,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 13,
              color: _hovered ? (widget.isDark ? Colors.white70 : Colors.black54) : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }
}
