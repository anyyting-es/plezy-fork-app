import 'package:flutter/material.dart';
import 'dart:ui';

class PremiumDropdown extends StatefulWidget {
  final List<String> items;
  final String defaultTitle;
  final int initialIndex;
  final int durationMs;
  final Function(int) onSelected;

  final double width;
  final double height;

  const PremiumDropdown({
    super.key,
    required this.items,
    required this.defaultTitle,
    this.initialIndex = 0,
    this.durationMs = 350,
    this.width = 160,
    this.height = 45,
    required this.onSelected,
  });

  @override
  State<PremiumDropdown> createState() => _PremiumDropdownState();
}

class _PremiumDropdownState extends State<PremiumDropdown> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;
  bool _isHovered = false;
  late int _selectedItemIndex;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _selectedItemIndex = widget.initialIndex.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInQuart,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        _removeOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(PremiumDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedItemIndex = widget.initialIndex.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
      });
    }
    if (widget.items != oldWidget.items) {
      if (_isExpanded) _toggle();
    }
    if (widget.durationMs != oldWidget.durationMs) {
      _controller.duration = Duration(milliseconds: widget.durationMs);
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggle() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _controller.reverse();
    } else {
      _showOverlay();
      setState(() => _isExpanded = true);
      _controller.forward();
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.topRight,
            targetAnchor: Alignment.topRight,
            child: TapRegion(
              onTapOutside: (_) {
                if (_isExpanded) _toggle();
              },
              child: Material(
                color: Colors.transparent,
                child: AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, child) {
                    final double calculatedHeight = 65.0 + (widget.items.length * 48.0);
                    final double targetHeight = calculatedHeight > 350.0 ? 350.0 : calculatedHeight;
                    
                    final double currentWidth = widget.width;
                    final double currentHeight = lerpDouble(widget.height, targetHeight, _expandAnimation.value)!;

                    return Container(
                      width: currentWidth,
                      height: currentHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(lerpDouble(10, 16, _expandAnimation.value)!),
                        border: Border.all(color: Colors.white.withOpacity(0.15 + (0.1 * _expandAnimation.value)), width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3 + (0.2 * _expandAnimation.value)),
                            blurRadius: 15 + (15 * _expandAnimation.value),
                            offset: Offset(0, 8 + (7 * _expandAnimation.value)),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(lerpDouble(10, 16, _expandAnimation.value)!),
                        child: Container(
                          color: const Color(0xFF000000), // Solid black
                          child: Stack(
                            children: [
                              // Morphing Header
                              Positioned(
                                top: 0, left: 0, right: 0, height: widget.height,
                                child: GestureDetector(
                                  onTap: _toggle,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.items[_selectedItemIndex].toUpperCase(),
                                            textAlign: TextAlign.left,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                        Transform.rotate(
                                          angle: _expandAnimation.value * 3.14159, // 180 degrees
                                          child: Icon(
                                            _expandAnimation.value > 0.5 ? Icons.close : Icons.keyboard_arrow_down,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_expandAnimation.value > 0.1)
                                Positioned.fill(
                                  top: widget.height,
                                  child: Opacity(
                                    opacity: ((_expandAnimation.value - 0.1) / 0.9).clamp(0.0, 1.0),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      itemCount: widget.items.length,
                                      itemBuilder: (context, index) => _buildStaggeredItem(index),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _selectItem(int index) {
    setState(() {
      _selectedItemIndex = index;
    });
    widget.onSelected(index);
    _toggle();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          if (!_isExpanded) setState(() => _isHovered = true);
        },
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: (1.0 - _expandAnimation.value).clamp(0.0, 1.0),
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _isHovered ? const Color(0xFF151515) : const Color(0xFF0A0A0A),
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
                    boxShadow: _isHovered ? [] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.items[_selectedItemIndex].toUpperCase(),
                              textAlign: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 4), // Matches overlay header
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStaggeredItem(int index) {
    return _DropdownItem(
      label: widget.items[index],
      isSelected: index == _selectedItemIndex,
      animationValue: _controller.value,
      durationMs: widget.durationMs,
      index: index,
      onTap: () => _selectItem(index),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }
}

class _DropdownItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final double animationValue;
  final int durationMs;
  final int index;
  final VoidCallback onTap;

  const _DropdownItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.animationValue,
    required this.durationMs,
    required this.index,
    required this.onTap,
  });

  @override
  State<_DropdownItem> createState() => _DropdownItemState();
}

class _DropdownItemState extends State<_DropdownItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final normalizedIndex = widget.index < 10 ? widget.index : 9;
    final itemInterval = Interval(
      0.3 + (normalizedIndex * 0.05).clamp(0.0, 0.7),
      1.0,
      curve: Curves.easeOutQuart,
    );

    final double opacity = itemInterval.transform(widget.animationValue);
    final double slide = (1.0 - opacity) * 20;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset.zero,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: Duration(milliseconds: (widget.durationMs / 2).toInt()),
            margin: const EdgeInsets.only(bottom: 8),
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _isHovered ? Colors.white.withOpacity(0.08) : Colors.transparent,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onTap,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedPadding(
                    duration: Duration(milliseconds: (widget.durationMs / 2).toInt()),
                    padding: const EdgeInsets.only(left: 16.0, right: 40.0), // Space for checkmark
                    child: AnimatedScale(
                      duration: Duration(milliseconds: (widget.durationMs / 2).toInt()),
                      scale: 1.0,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isSelected || _isHovered ? Colors.white : Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: widget.isSelected || _isHovered ? FontWeight.bold : FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  if (widget.isSelected)
                    const Positioned(
                      right: 16,
                      child: Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}