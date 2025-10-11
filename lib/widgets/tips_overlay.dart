import 'dart:async';
import 'package:flutter/material.dart';

class TipTarget {
  final GlobalKey key;
  final String title;
  final String body;
  TipTarget({required this.key, required this.title, required this.body});
}

Future<void> showTipsOverlay(
  BuildContext context, {
  required List<TipTarget> tips,
  String skipLabel = 'Skip',
  String nextLabel = 'Next',
  String doneLabel = 'Done',
}) async {
  if (tips.isEmpty) return;
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  int index = 0;
  late OverlayEntry entry;

  Rect _targetRect() {
    final tKey = tips[index].key;
    if (tKey.currentContext == null) return Rect.zero;
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final targetBox = tKey.currentContext!.findRenderObject() as RenderBox;
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & targetBox.size;
  }

  void rebuild() {
    entry.markNeedsBuild();
  }

  void next() {
    if (index < tips.length - 1) {
      index += 1;
      rebuild();
    } else {
      entry.remove();
    }
  }

  entry = OverlayEntry(builder: (ctx) {
    final rect = _targetRect();
    final size = MediaQuery.of(ctx).size;
    final hole = rect.inflate(8);
    final preferBelow = rect.top < size.height * .55;
    final bubbleTop = preferBelow ? hole.bottom + 12 : null;
    final bubbleBottom = preferBelow ? null : size.height - hole.top + 12;
    final bubbleWidth = size.width - 24;
    return Stack(children: [
      // Dim with hole
      Positioned.fill(
        child: CustomPaint(painter: _DimWithHolePainter(hole: hole)),
      ),
      // Tap-through blocker that advances
      Positioned.fill(
        child: GestureDetector(onTap: next),
      ),
      // Bubble
      Positioned(
        left: 12,
        right: 12,
        top: bubbleTop,
        bottom: bubbleBottom,
        child: Align(
          alignment: preferBelow ? Alignment.topCenter : Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: bubbleWidth),
            child: Material(
              color: Theme.of(ctx).colorScheme.surface,
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tips[index].title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(tips[index].body, style: Theme.of(ctx).textTheme.bodyMedium),
                    const SizedBox(height: 10),
                    Row(children:[
                      TextButton(onPressed: ()=> entry.remove(), child: Text(skipLabel)),
                      const Spacer(),
                      FilledButton(onPressed: next, child: Text(index == tips.length-1 ? doneLabel : nextLabel)),
                    ])
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Stroke around hole for emphasis
      Positioned.fromRect(
        rect: hole,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(ctx).colorScheme.primary, width: 2),
            ),
          ),
        ),
      ),
    ]);
  });

  overlay.insert(entry);
  // give layout a moment to settle for first measurement
  await Future.delayed(const Duration(milliseconds: 50));
  entry.markNeedsBuild();
}

class _DimWithHolePainter extends CustomPainter {
  final Rect hole;
  _DimWithHolePainter({required this.hole});
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    overlay.addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(12)));
    overlay.fillType = PathFillType.evenOdd;
    final paint = Paint()..color = Colors.black.withOpacity(.55);
    canvas.drawPath(overlay, paint);
  }
  @override
  bool shouldRepaint(covariant _DimWithHolePainter oldDelegate) => oldDelegate.hole != hole;
}

