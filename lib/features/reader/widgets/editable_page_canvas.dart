import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../editable_text_box.dart';

class EditablePageCanvas extends StatelessWidget {
  const EditablePageCanvas({
    super.key,
    required this.pageIndex,
    required this.metrics,
    required this.image,
    required this.boxes,
    required this.selectedId,
    required this.onSelect,
    required this.onChanged,
    this.canvasKey,
  });

  final int pageIndex;
  final PdfPageMetrics metrics;
  final ui.Image? image;
  final List<PdfEditableBox> boxes;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onChanged;
  final Key? canvasKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final scale = maxW / metrics.width;
        final displayH = metrics.height * scale;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Page ${pageIndex + 1}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => onSelect(null),
              child: Container(
                key: canvasKey,
                width: maxW,
                height: displayH,
                decoration: BoxDecoration(
                  color: AppColors.pdfPaper,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // Pinch / pan zoom while placing text.
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  panEnabled: selectedId == null,
                  scaleEnabled: selectedId == null,
                  boundaryMargin: const EdgeInsets.all(64),
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: maxW,
                    height: displayH,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        if (image != null)
                          Positioned.fill(
                            child: RawImage(
                              image: image,
                              fit: BoxFit.fill,
                            ),
                          )
                        else
                          const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        for (final box in (() {
                          final ordered = List<PdfEditableBox>.from(boxes);
                          if (selectedId != null) {
                            ordered.sort((a, b) {
                              if (a.id == selectedId) return 1;
                              if (b.id == selectedId) return -1;
                              return 0;
                            });
                          }
                          return ordered;
                        })())
                          _TextBoxOverlay(
                            key: ValueKey(box.id),
                            box: box,
                            scale: scale,
                            pageWidth: metrics.width,
                            pageHeight: metrics.height,
                            selected: box.id == selectedId,
                            onSelect: () => onSelect(box.id),
                            onChanged: onChanged,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TextBoxOverlay extends StatefulWidget {
  const _TextBoxOverlay({
    super.key,
    required this.box,
    required this.scale,
    required this.pageWidth,
    required this.pageHeight,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
  });

  final PdfEditableBox box;
  final double scale;
  final double pageWidth;
  final double pageHeight;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onChanged;

  @override
  State<_TextBoxOverlay> createState() => _TextBoxOverlayState();
}

class _TextBoxOverlayState extends State<_TextBoxOverlay> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);
    _focus = FocusNode();
    _focus.addListener(() {
      if (_focus.hasFocus) widget.onSelect();
      if (mounted) setState(() {});
    });
    if (widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _TextBoxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Never assign controller.text while focused — that jumps the caret.
    if (!_focus.hasFocus && _controller.text != widget.box.text) {
      _controller.value = TextEditingValue(
        text: widget.box.text,
        selection: TextSelection.collapsed(offset: widget.box.text.length),
      );
    }
    if (oldWidget.selected && !widget.selected && _focus.hasFocus) {
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _moveNewBox(Offset layoutDelta) {
    final box = widget.box;
    final s = widget.scale;
    if (s <= 0) return;
    final next = box.bounds.shift(
      Offset(layoutDelta.dx / s, layoutDelta.dy / s),
    );
    final maxX = math.max(0.0, widget.pageWidth - next.width);
    final maxY = math.max(0.0, widget.pageHeight - next.height);
    box.bounds = Rect.fromLTWH(
      next.left.clamp(0.0, maxX),
      next.top.clamp(0.0, maxY),
      next.width,
      next.height,
    );
    setState(() {});
    widget.onChanged();
  }

  TextStyle _textStyle(double fontSize) {
    final box = widget.box;
    return TextStyle(
      fontSize: fontSize,
      height: 1.15,
      color: box.color,
      fontWeight: box.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: box.italic ? FontStyle.italic : FontStyle.normal,
      fontFamily: 'Helvetica',
      fontFamilyFallback: const [
        'Roboto',
        'Noto Sans',
        'Arial',
        'sans-serif',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    final s = widget.scale;
    final slot = box.bounds;

    final fontSize = (box.displayFontSize * s).clamp(5.0, 96.0);
    final width = math.max(slot.width * s, 8.0);
    final height = math.max(slot.height * s, 8.0);
    final left = slot.left * s;
    final top = slot.top * s;

    final isEditing = widget.selected;
    final style = _textStyle(fontSize);

    final field = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(8, 4, 36, 4),
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          maxLines: null,
          expands: true,
          readOnly: false,
          cursorColor: box.color,
          textAlign: TextAlign.left,
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
          enableInteractiveSelection: true,
          strutStyle: StrutStyle(
            fontSize: fontSize,
            height: 1.15,
            leading: 0,
            forceStrutHeight: true,
          ),
          style: style,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            fillColor: Colors.transparent,
            hintText: 'Type here',
            hintStyle: style.copyWith(
              color: box.color.withValues(alpha: 0.4),
            ),
            contentPadding: const EdgeInsets.fromLTRB(8, 4, 36, 4),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onTap: () {
            widget.onSelect();
          },
          onChanged: (v) {
            box.text = v;
            widget.onChanged();
          },
        ),
      ),
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          ClipRect(
            child: ColoredBox(
              color: AppColors.pdfPaper,
              child: field,
            ),
          ),
          if (!_focus.hasFocus)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.onSelect();
                  _focus.requestFocus();
                },
                onPanStart: (_) {
                  widget.onSelect();
                },
                onPanUpdate: (details) => _moveNewBox(details.delta),
              ),
            ),
          Positioned(
            right: 0,
            top: 0,
            child: _buildDragHandle(),
          ),
          if (isEditing)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.lightAccent,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSelect,
      onPanStart: (_) {
        widget.onSelect();
      },
      onPanUpdate: (details) => _moveNewBox(details.delta),
      child: Container(
        width: 28,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.selected
              ? AppColors.lightAccent
              : AppColors.lightAccent.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: const Icon(
          Icons.drag_indicator,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}
