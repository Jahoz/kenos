import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Moves a star at RENDER level: the orbital drift updates a paint
/// offset through a [ValueListenable] — no element rebuild, no diff,
/// and with the star's RepaintBoundary below, each frame is a GPU
/// recomposition of a cached raster. The sky orbits at display rate
/// for the price of a layout pass.
class StarShift extends SingleChildRenderObjectWidget {
  const StarShift({required this.shift, super.child, super.key});

  /// Screen-space delta from the star's base position (set by the
  /// layer at build time). Updated by the orbital ticker.
  final ValueListenable<Offset> shift;

  @override
  RenderStarShift createRenderObject(BuildContext context) {
    return RenderStarShift()..source = shift;
  }

  @override
  void updateRenderObject(BuildContext context, RenderStarShift renderObject) {
    renderObject.source = shift;
  }
}

class RenderStarShift extends RenderProxyBox {
  ValueListenable<Offset>? _source;
  Offset _offset = Offset.zero;

  set source(ValueListenable<Offset>? value) {
    if (identical(value, _source)) return;
    _source?.removeListener(_changed);
    _source = value;
    value?.addListener(_changed);
    _changed();
  }

  void _changed() {
    final next = _source?.value ?? Offset.zero;
    if (next == _offset) return;
    _offset = next;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _source?.addListener(_changed);
  }

  @override
  void detach() {
    _source?.removeListener(_changed);
    super.detach();
  }

  @override
  void dispose() {
    // The star left the sky: stop listening before anything (a ticker,
    // a delayed unmount) sets the notifier of a dead render object.
    _source?.removeListener(_changed);
    _source = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    child?.paint(context, offset + _offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child?.hitTest(result, position: position - _offset) ?? false;
  }
}
