import 'dart:math' as math;
import 'package:flutter/material.dart';

// Import your node definitions - adjust path as needed
import 'package:flutter/rendering.dart';
import 'renderer.dart';

// ============== SELECTION DATA CLASSES ==============

class SelectionAnchor {
  final String? parentId;
  final String? path;
  final int nodeIndex;
  final int charIndex;

  const SelectionAnchor({
    this.parentId,
    this.path,
    required this.nodeIndex,
    required this.charIndex,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectionAnchor &&
        other.parentId == parentId &&
        other.path == path &&
        other.nodeIndex == nodeIndex &&
        other.charIndex == charIndex;
  }

  @override
  int get hashCode =>
      parentId.hashCode ^
      path.hashCode ^
      nodeIndex.hashCode ^
      charIndex.hashCode;

  SelectionAnchor copyWith({
    String? parentId,
    String? path,
    int? nodeIndex,
    int? charIndex,
  }) {
    return SelectionAnchor(
      parentId: parentId ?? this.parentId,
      path: path ?? this.path,
      nodeIndex: nodeIndex ?? this.nodeIndex,
      charIndex: charIndex ?? this.charIndex,
    );
  }

  bool sameContext(SelectionAnchor other) {
    return parentId == other.parentId && path == other.path;
  }

  int compareTo(SelectionAnchor other) {
    if (!sameContext(other)) return 0;
    if (nodeIndex != other.nodeIndex) {
      return nodeIndex.compareTo(other.nodeIndex);
    }
    return charIndex.compareTo(other.charIndex);
  }
}

class SelectionRange {
  final SelectionAnchor start;
  final SelectionAnchor end;

  const SelectionRange({required this.start, required this.end});

  bool get isEmpty => start == end;
  bool get isValid => start.sameContext(end);

  SelectionRange get normalized {
    if (start.compareTo(end) <= 0) return this;
    return SelectionRange(start: end, end: start);
  }
}

class MathClipboard {
  final List<MathNode> nodes;
  final String? leadingText;
  final String? trailingText;

  const MathClipboard({
    required this.nodes,
    this.leadingText,
    this.trailingText,
  });

  bool get isEmpty =>
      nodes.isEmpty &&
      (leadingText?.isEmpty ?? true) &&
      (trailingText?.isEmpty ?? true);

  static List<MathNode> deepCopyNodes(List<MathNode> nodes) {
    return nodes.map((node) => deepCopyNode(node)).toList();
  }

  static MathNode deepCopyNode(MathNode node) {
    if (node is LiteralNode) {
      return LiteralNode(text: node.text);
    } else if (node is FractionNode) {
      return FractionNode(
        num: deepCopyNodes(node.numerator),
        den: deepCopyNodes(node.denominator),
      );
    } else if (node is ExponentNode) {
      return ExponentNode(
        base: deepCopyNodes(node.base),
        power: deepCopyNodes(node.power),
      );
    } else if (node is LogNode) {
      return LogNode(
        base: deepCopyNodes(node.base),
        argument: deepCopyNodes(node.argument),
        isNaturalLog: node.isNaturalLog,
      );
    } else if (node is TrigNode) {
      return TrigNode(
        function: node.function,
        argument: deepCopyNodes(node.argument),
      );
    } else if (node is RootNode) {
      return RootNode(
        index: deepCopyNodes(node.index),
        radicand: deepCopyNodes(node.radicand),
        isSquareRoot: node.isSquareRoot,
      );
    } else if (node is PermutationNode) {
      return PermutationNode(
        n: deepCopyNodes(node.n),
        r: deepCopyNodes(node.r),
      );
    } else if (node is CombinationNode) {
      return CombinationNode(
        n: deepCopyNodes(node.n),
        r: deepCopyNodes(node.r),
      );
    } else if (node is NewlineNode) {
      return NewlineNode();
    } else if (node is ParenthesisNode) {
      return ParenthesisNode(content: deepCopyNodes(node.content));
    } else if (node is AnsNode) {
      return AnsNode(index: deepCopyNodes(node.index));
    }
    return LiteralNode(text: '');
  }
}

/// Information about selection bounds

/// Combined overlay for selection menu, handles, AND highlight
class SelectionOverlayWidget extends StatefulWidget {
  final MathEditorController controller;
  final GlobalKey containerKey;
  final Offset? cursorLocalPosition;
  final VoidCallback? onCopy;
  final VoidCallback? onCut;
  final VoidCallback? onPaste;
  final VoidCallback onDismiss;

  const SelectionOverlayWidget({
    super.key,
    required this.controller,
    required this.containerKey,
    this.cursorLocalPosition,
    this.onCopy,
    this.onCut,
    this.onPaste,
    required this.onDismiss,
  });

  @override
  State<SelectionOverlayWidget> createState() => _SelectionOverlayWidgetState();
}

class _SelectionOverlayWidgetState extends State<SelectionOverlayWidget> {
  static const double _menuOffset = 12.0;

  void _collectAllNodeIds(MathNode node, Set<String> ids) {
    ids.add(node.id);

    if (node is FractionNode) {
      for (var n in node.numerator) {
        _collectAllNodeIds(n, ids);
      }
      for (var n in node.denominator) {
        _collectAllNodeIds(n, ids);
      }
    } else if (node is ExponentNode) {
      for (var n in node.base) {
        _collectAllNodeIds(n, ids);
      }
      for (var n in node.power) {
        _collectAllNodeIds(n, ids);
      }
    } else if (node is TrigNode) {
      for (var n in node.argument) {
        _collectAllNodeIds(n, ids);
      }
    } else if (node is RootNode) {
      for (var n in node.index) {
        _collectAllNodeIds(n, ids);
      }
      for (var n in node.radicand) {
        _collectAllNodeIds(n, ids);
      }
    } else if (node is LogNode) {
      for (var n in node.base) {
        _collectAllNodeIds(n, ids);
      }
      for (var n in node.argument) {
        _collectAllNodeIds(n, ids);
      }
    } else if (node is ParenthesisNode) {
      for (var n in node.content) {
        _collectAllNodeIds(n, ids);
      }
    } else if (node is PermutationNode) {
      for (var n in node.n) {
        _collectAllNodeIds(n, ids);
      }
      for (var n in node.r) {
        _collectAllNodeIds(n, ids);
      }
    } else if (node is CombinationNode) {
      for (var n in node.n) {
        _collectAllNodeIds(n, ids);
      }
      for (var n in node.r) {
        _collectAllNodeIds(n, ids);
      }
    } else if (node is AnsNode) {
      for (var n in node.index) {
        _collectAllNodeIds(n, ids);
      }
    }
  }

  List<MathNode>? _getSiblingList(String? parentId, String? path) {
    if (parentId == null) {
      return widget.controller.expression;
    }

    final parent = _findNodeById(widget.controller.expression, parentId);
    if (parent == null) return null;

    if (parent is FractionNode) {
      if (path == 'num' || path == 'numerator') return parent.numerator;
      if (path == 'den' || path == 'denominator') return parent.denominator;
    } else if (parent is ExponentNode) {
      if (path == 'base') return parent.base;
      if (path == 'pow' || path == 'power') return parent.power;
    } else if (parent is TrigNode) {
      if (path == 'arg' || path == 'argument') return parent.argument;
    } else if (parent is RootNode) {
      if (path == 'index') return parent.index;
      if (path == 'radicand') return parent.radicand;
    } else if (parent is LogNode) {
      if (path == 'base') return parent.base;
      if (path == 'arg' || path == 'argument') return parent.argument;
    } else if (parent is ParenthesisNode) {
      if (path == 'content') return parent.content;
    } else if (parent is PermutationNode) {
      if (path == 'n') return parent.n;
      if (path == 'r') return parent.r;
    } else if (parent is CombinationNode) {
      if (path == 'n') return parent.n;
      if (path == 'r') return parent.r;
    } else if (parent is AnsNode) {
      if (path == 'index') return parent.index;
    }

    return null;
  }

  MathNode? _findNodeById(List<MathNode> nodes, String id) {
    for (final node in nodes) {
      if (node.id == id) return node;

      MathNode? found;
      if (node is FractionNode) {
        found =
            _findNodeById(node.numerator, id) ??
            _findNodeById(node.denominator, id);
      } else if (node is ExponentNode) {
        found = _findNodeById(node.base, id) ?? _findNodeById(node.power, id);
      } else if (node is TrigNode) {
        found = _findNodeById(node.argument, id);
      } else if (node is RootNode) {
        found =
            _findNodeById(node.index, id) ?? _findNodeById(node.radicand, id);
      } else if (node is LogNode) {
        found =
            _findNodeById(node.base, id) ?? _findNodeById(node.argument, id);
      } else if (node is ParenthesisNode) {
        found = _findNodeById(node.content, id);
      } else if (node is PermutationNode) {
        found = _findNodeById(node.n, id) ?? _findNodeById(node.r, id);
      } else if (node is CombinationNode) {
        found = _findNodeById(node.n, id) ?? _findNodeById(node.r, id);
      } else if (node is AnsNode) {
        found = _findNodeById(node.index, id);
      }

      if (found != null) return found;
    }
    return null;
  }

  Rect? _getFullNodeBounds(MathNode node) {
    Set<String> nodeIds = {};
    _collectAllNodeIds(node, nodeIds);

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (final info in widget.controller.layoutRegistry.values) {
      if (nodeIds.contains(info.node.id)) {
        minX = math.min(minX, info.rect.left);
        maxX = math.max(maxX, info.rect.right);
        minY = math.min(minY, info.rect.top);
        maxY = math.max(maxY, info.rect.bottom);
      }
    }

    if (minX == double.infinity) return null;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  _SelectionInfo? _getSelectionInfo() {
    final selection = widget.controller.selection;
    if (selection == null || selection.isEmpty) return null;

    final containerBox =
        widget.containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) return null;

    final norm = selection.normalized;

    final siblings = _getSiblingList(norm.start.parentId, norm.start.path);
    if (siblings == null) return null;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    double startX = double.infinity;
    double endX = double.negativeInfinity;

    for (
      int i = norm.start.nodeIndex;
      i <= norm.end.nodeIndex && i < siblings.length;
      i++
    ) {
      final node = siblings[i];
      final nodeBounds = _getFullNodeBounds(node);

      if (nodeBounds == null) continue;

      minY = math.min(minY, nodeBounds.top);
      maxY = math.max(maxY, nodeBounds.bottom);

      if (i == norm.start.nodeIndex) {
        if (node is LiteralNode) {
          NodeLayoutInfo? info;
          for (final layoutInfo in widget.controller.layoutRegistry.values) {
            if (layoutInfo.node.id == node.id) {
              info = layoutInfo;
              break;
            }
          }

          if (info != null) {
            final offsetX = _getCursorOffsetUsingRenderParagraph(
              info,
              norm.start.charIndex,
            );
            startX = info.rect.left + offsetX;
          }
        } else {
          startX = nodeBounds.left;
        }
      }

      if (i == norm.end.nodeIndex) {
        if (node is LiteralNode) {
          NodeLayoutInfo? info;
          for (final layoutInfo in widget.controller.layoutRegistry.values) {
            if (layoutInfo.node.id == node.id) {
              info = layoutInfo;
              break;
            }
          }

          if (info != null) {
            final offsetX = _getCursorOffsetUsingRenderParagraph(
              info,
              norm.end.charIndex,
            );
            endX = info.rect.left + offsetX;
          }
        } else {
          endX = nodeBounds.right;
        }
      }

      if (i > norm.start.nodeIndex && i < norm.end.nodeIndex) {
        startX = math.min(startX, nodeBounds.left);
        endX = math.max(endX, nodeBounds.right);
      }
    }

    if (minY == double.infinity || startX == double.infinity) return null;

    if (endX <= startX) {
      endX = startX + 2;
    }

    final globalTopLeft = containerBox.localToGlobal(Offset(startX, minY));
    final globalBottomRight = containerBox.localToGlobal(Offset(endX, maxY));

    return _SelectionInfo(
      bounds: Rect.fromLTRB(
        globalTopLeft.dx,
        globalTopLeft.dy,
        globalBottomRight.dx,
        globalBottomRight.dy,
      ),
    );
  }

  double _getCursorOffsetUsingRenderParagraph(
    NodeLayoutInfo info,
    int charIndex,
  ) {
    final text = info.node.text;

    if (text.isEmpty || charIndex <= 0) return 0.0;

    final displayText = MathTextStyle.toDisplayText(text);
    final displayIndex = MathTextStyle.logicalToDisplayIndex(
      text,
      charIndex,
    ).clamp(0, displayText.length);

    if (info.renderParagraph != null) {
      final offset = info.renderParagraph!.getOffsetForCaret(
        TextPosition(offset: displayIndex),
        Rect.zero,
      );
      return offset.dx;
    }

    final textSpan = TextSpan(
      text: displayText,
      style: MathTextStyle.getStyle(
        info.fontSize,
      ).copyWith(color: Colors.white),
    );
    final renderParagraph = RenderParagraph(
      textSpan,
      textDirection: TextDirection.ltr,
      textScaler: info.textScaler,
    );
    renderParagraph.layout(const BoxConstraints());

    final offset = renderParagraph.getOffsetForCaret(
      TextPosition(offset: displayIndex),
      Rect.zero,
    );
    renderParagraph.dispose();
    return offset.dx;
  }

  void _onHandleDrag(bool isStart, Offset globalPosition) {
    final containerBox =
        widget.containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) return;

    final localPos = containerBox.globalToLocal(globalPosition);

    widget.controller.updateSelectionHandle(isStart, localPos);
    setState(() {});
  }

  /// Get cursor bounds in GLOBAL coordinates (same format as selection bounds)
  Rect? _getCursorGlobalBounds() {
    final containerBox =
        widget.containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null) return null;

    final cursor = widget.controller.cursor;

    // Find the node at cursor position in layout registry
    for (final info in widget.controller.layoutRegistry.values) {
      if (info.parentId == cursor.parentId &&
          info.path == cursor.path &&
          info.index == cursor.index) {
        // Calculate cursor X position within the node
        double cursorX;
        if (info.node.text.isEmpty) {
          cursorX = info.rect.left;
        } else if (info.renderParagraph != null) {
          final displayText = MathTextStyle.toDisplayText(info.node.text);
          final displayIndex = MathTextStyle.logicalToDisplayIndex(
            info.node.text,
            cursor.subIndex,
          ).clamp(0, displayText.length);
          final offset = info.renderParagraph!.getOffsetForCaret(
            TextPosition(offset: displayIndex),
            Rect.zero,
          );
          cursorX = info.rect.left + offset.dx;
        } else {
          final offset = MathTextStyle.getCursorOffset(
            info.node.text,
            cursor.subIndex,
            info.fontSize,
            info.textScaler,
          );
          cursorX = info.rect.left + offset;
        }

        // Convert LOCAL coordinates to GLOBAL coordinates
        final globalTopLeft = containerBox.localToGlobal(
          Offset(cursorX, info.rect.top),
        );
        final globalBottomRight = containerBox.localToGlobal(
          Offset(cursorX + 2, info.rect.bottom),
        );

        return Rect.fromLTRB(
          globalTopLeft.dx,
          globalTopLeft.dy,
          globalBottomRight.dx,
          globalBottomRight.dy,
        );
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectionInfo = _getSelectionInfo();
    final hasSelection = widget.controller.hasSelection;
    final screenSize = MediaQuery.of(context).size;
    final hasClipboard =
        MathEditorController.clipboard != null &&
        !MathEditorController.clipboard!.isEmpty;

    // Calculate menu center position
    double menuCenterX;
    double menuTopY;

    if (hasSelection && selectionInfo != null) {
      menuCenterX = selectionInfo.bounds.center.dx;
      menuTopY = selectionInfo.bounds.top - 55 - _menuOffset;
    } else {
      final cursorBounds = _getCursorGlobalBounds();

      if (cursorBounds != null) {
        menuCenterX = cursorBounds.center.dx;
        menuTopY = cursorBounds.top - 55 - _menuOffset;
      } else {
        menuCenterX = screenSize.width / 2;
        menuTopY = 100;
      }
    }

    // Clamp positions to keep menu on screen
    menuTopY = menuTopY.clamp(8.0, screenSize.height - 100);
    // Keep menu center away from edges (estimate ~80px half-width for menu)
    menuCenterX = menuCenterX.clamp(80.0, screenSize.width - 80.0);

    const double lineWidth = 2.0;
    const double lineHeight = 6.0;
    const double dropSize = 18.0;

    return Stack(
      children: [
        // Tap anywhere to dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Selection highlight
        if (hasSelection && selectionInfo != null)
          Positioned(
            left: selectionInfo.bounds.left,
            top: selectionInfo.bounds.top,
            width: selectionInfo.bounds.width,
            height: selectionInfo.bounds.height,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.yellow.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

        // Selection handles
        if (hasSelection && selectionInfo != null) ...[
          Positioned(
            left: selectionInfo.bounds.left - dropSize,
            top: selectionInfo.bounds.bottom,
            child: _SelectionHandle(
              isStart: true,
              lineWidth: lineWidth,
              lineHeight: lineHeight,
              dropSize: dropSize,
              onDrag: (globalPos) => _onHandleDrag(true, globalPos),
            ),
          ),
          Positioned(
            left: selectionInfo.bounds.right,
            top: selectionInfo.bounds.bottom,
            child: _SelectionHandle(
              isStart: false,
              lineWidth: lineWidth,
              lineHeight: lineHeight,
              dropSize: dropSize,
              onDrag: (globalPos) => _onHandleDrag(false, globalPos),
            ),
          ),
        ],

        // Floating menu - centered on menuCenterX
        Positioned(
          top: menuTopY,
          left: menuCenterX,
          child: FractionalTranslation(
            translation: const Offset(-0.5, 0),
            child: _SelectionMenu(
              onCopy: widget.onCopy,
              onCut: widget.onCut,
              onPaste: hasClipboard ? widget.onPaste : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionInfo {
  final Rect bounds;
  _SelectionInfo({required this.bounds});
}

class _SelectionHandle extends StatelessWidget {
  final bool isStart;
  final double lineWidth;
  final double lineHeight;
  final double dropSize;
  final Function(Offset globalPosition) onDrag;

  const _SelectionHandle({
    required this.isStart,
    required this.lineWidth,
    required this.lineHeight,
    required this.dropSize,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    const double touchPadding = 12.0;

    return GestureDetector(
      onPanStart: (details) {
        onDrag(details.globalPosition);
      },
      onPanUpdate: (details) {
        onDrag(details.globalPosition);
      },
      child: Container(
        width: dropSize + touchPadding,
        height: lineHeight + dropSize + touchPadding,
        color: Colors.transparent,
        child: CustomPaint(
          size: Size(
            dropSize + touchPadding,
            lineHeight + dropSize + touchPadding,
          ),
          painter: _WaterDropHandlePainter(
            isStart: isStart,
            lineWidth: lineWidth,
            lineHeight: lineHeight,
            dropSize: dropSize,
            touchPadding: touchPadding,
          ),
        ),
      ),
    );
  }
}

class _WaterDropHandlePainter extends CustomPainter {
  final bool isStart;
  final double lineWidth;
  final double lineHeight;
  final double dropSize;
  final double touchPadding;

  _WaterDropHandlePainter({
    required this.isStart,
    required this.lineWidth,
    required this.lineHeight,
    required this.dropSize,
    required this.touchPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.yellowAccent
          ..style = PaintingStyle.fill;

    final double r = dropSize / 2;

    if (isStart) {
      final double shapeRight = dropSize;

      final path = Path();
      path.moveTo(shapeRight, 0);
      path.lineTo(shapeRight, r);
      path.arcToPoint(
        Offset(r, 0),
        radius: Radius.circular(r),
        clockwise: true,
        largeArc: true,
      );
      path.lineTo(shapeRight, 0);
      path.close();
      canvas.drawPath(path, paint);
    } else {
      final double shapeLeft = 0.0;
      final double dropCenterX = shapeLeft + r;

      final path = Path();
      path.moveTo(shapeLeft, 0);
      path.lineTo(shapeLeft, r);
      path.arcToPoint(
        Offset(dropCenterX, 0),
        radius: Radius.circular(r),
        clockwise: false,
        largeArc: true,
      );
      path.lineTo(shapeLeft, 0);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterDropHandlePainter oldDelegate) {
    return isStart != oldDelegate.isStart ||
        lineWidth != oldDelegate.lineWidth ||
        lineHeight != oldDelegate.lineHeight ||
        dropSize != oldDelegate.dropSize;
  }
}

class _SelectionMenu extends StatelessWidget {
  final VoidCallback? onCopy;
  final VoidCallback? onCut;
  final VoidCallback? onPaste;

  const _SelectionMenu({this.onCopy, this.onCut, this.onPaste});

  @override
  Widget build(BuildContext context) {
    final hasAnyAction = onCopy != null || onCut != null || onPaste != null;
    if (!hasAnyAction) return const SizedBox.shrink();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xFF2D2D2D),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onCut != null)
              _MenuButton(icon: Icons.cut, label: 'Cut', onTap: onCut!),
            if (onCopy != null) ...[
              if (onCut != null) _MenuDivider(),
              _MenuButton(icon: Icons.copy, label: 'Copy', onTap: onCopy!),
            ],
            if (onPaste != null) ...[
              if (onCopy != null || onCut != null) _MenuDivider(),
              _MenuButton(icon: Icons.paste, label: 'Paste', onTap: onPaste!),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: Colors.grey[600]);
  }
}
