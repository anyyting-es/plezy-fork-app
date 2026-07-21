import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ListEdit extends StatefulWidget {
  final String title;
  final String? posterUrl;
  final String? logoUrl;
  final int totalSeasons;
  final int totalEpisodes;
  final String? initialStatus;
  final double? initialScore;
  final int? initialProgress;
  final int? initialSeason;
  final Function(Map<String, dynamic>)? onSave;
  final bool minimal;

  const ListEdit({
    super.key,
    required this.title,
    this.posterUrl,
    this.logoUrl,
    this.totalSeasons = 1,
    this.totalEpisodes = 12,
    this.initialStatus,
    this.initialScore,
    this.initialProgress,
    this.initialSeason,
    this.onSave,
    this.minimal = false,
  });

  @override
  State<ListEdit> createState() => _ListEditState();
}

class _ListEditState extends State<ListEdit> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isExpanded = false;
  bool _isHovered = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late String _selectedStatus;
  late double _selectedScore;
  late int _selectedProgress;
  DateTime? _startDate = DateTime.now();
  DateTime? _completionDate;
  int _rewatches = 0;
  double? _hoverScore;
  late int _selectedSeason;
  bool _showAdvanced = false;
  final List<String> _selectedCustomLists = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _selectedStatus = widget.initialStatus ?? 'Viendo';
    _selectedScore = widget.initialScore ?? 0.0;
    _selectedProgress = widget.initialProgress ?? 0;
    _selectedSeason = widget.initialSeason ?? 1;
  }

  void _setOverlayState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _overlayEntry?.markNeedsBuild();
  }

  void _toggle() {
    if (_isExpanded) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_isExpanded) return;
    
    // Listen to parent scroll to close overlay
    final scrollable = Scrollable.of(context);
    if (scrollable != null) {
      scrollable.position.addListener(_hideOverlay);
    }

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    setState(() => _isExpanded = true);
    _controller.forward(from: 0);
  }

  Future<void> _hideOverlay() async {
    if (!_isExpanded) return;

    // Remove scroll listener
    final scrollable = Scrollable.of(context);
    if (scrollable != null) {
      scrollable.position.removeListener(_hideOverlay);
    }

    await _controller.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isExpanded = false);
    }
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset globalOffset = renderBox.localToGlobal(Offset.zero);
    final Size widgetSize = renderBox.size;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideOverlay,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final screenSize = MediaQuery.of(context).size;
                final screenWidth = screenSize.width;
                final isMobile = screenWidth < 720;
                final double targetWidth = isMobile ? (screenWidth - 32).clamp(0.0, 720.0) : 720.0;
                final double targetHeight = isMobile ? 580.0 : 380.0;
                final double scale = 0.98 + (0.02 * _animation.value);
                final double opacity = _animation.value;

                return Center(
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: targetWidth,
                          constraints: BoxConstraints(
                            maxHeight: screenSize.height * 0.85,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Custom Header with Close Button
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: _hideOverlay,
                                      icon: const Icon(LucideIcons.x, color: Colors.white38, size: 20),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                              if (_animation.value > 0.3)
                                Flexible(
                                  child: Opacity(
                                    opacity: ((_animation.value - 0.3) / 0.7).clamp(0.0, 1.0),
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.fromLTRB(isMobile ? 24 : 48, 0, isMobile ? 24 : 48, 24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if (isMobile) ...[
                                            _buildMobileLayout(),
                                          ] else ...[
                                            _buildDesktopLayout(),
                                          ],
                                          const SizedBox(height: 32),
                                          _buildActionButtons(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _save() {
    if (widget.onSave != null) {
      widget.onSave!({
        'status': _selectedStatus,
        'score': _selectedScore,
        'progress': _selectedProgress,
        'startDate': _startDate,
        'completionDate': _completionDate,
        'rewatches': _rewatches,
        'season': _selectedSeason,
      });
    }
    _toggle();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isExpanded ? 0.0 : 1.0,
        child: IconButton(
          onPressed: _toggle,
          icon: const Icon(
            LucideIcons.pencil,
            color: Colors.white,
            size: 22,
          ),
          tooltip: 'Editar lista',
        ),
      ),
    );
  }

  Widget _buildFieldRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: children.map((child) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: child,
        ),
      )).toList(),
    );
  }

  Widget _buildStatusDropdown() {
    final List<String> statusOptions = [
      'Viendo', 'Completado', 'Pausado', 'Planeado', 'Abandonado', 'Repitiendo'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _ListEditDropdown(
          items: statusOptions,
          defaultTitle: 'ESTADO',
          initialIndex: statusOptions.indexOf(_selectedStatus).clamp(0, statusOptions.length - 1),
          durationMs: 400,
          isFullWidth: true,
          onSelected: (int index) {
            _setOverlayState(() => _selectedStatus = statusOptions[index]);
          },
        ),
      ],
    );
  }

  Widget _buildProgressPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progreso',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _NumericInputField(
          value: _selectedProgress,
          max: widget.totalEpisodes,
          onChanged: (val) => _setOverlayState(() => _selectedProgress = val),
        ),
      ],
    );
  }

  Widget _buildRewatchesPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeticiones',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _NumericInputField(
          value: _rewatches,
          onChanged: (val) => _setOverlayState(() => _rewatches = val),
        ),
      ],
    );
  }

  Widget _buildCustomListsPicker() {
    final List<String> availableLists = ['Favoritos', 'Para ver después', 'Completados', 'Dropeados'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mis Listas',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _ListEditDropdown(
          items: availableLists,
          defaultTitle: 'AÑADIR A LISTA',
          isFullWidth: true,
          durationMs: 250,
          onSelected: (int index) {
            final list = availableLists[index];
            _setOverlayState(() {
              if (!_selectedCustomLists.contains(list)) {
                _selectedCustomLists.add(list);
              }
            });
          },
        ),
        if (_selectedCustomLists.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedCustomLists.map((list) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(list, style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _setOverlayState(() => _selectedCustomLists.remove(list)),
                    child: const Icon(LucideIcons.x, size: 12, color: Colors.deepPurpleAccent),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, Function(DateTime?) onDateChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _DateOverlayWrapper(
          date: date,
          onDateChanged: onDateChanged,
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Container(
            height: 60,
            alignment: Alignment.centerLeft,
            child: (widget.logoUrl?.isNotEmpty == true)
                ? Image.network(
                    widget.logoUrl!,
                    height: 55,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, __, ___) => Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  )
                : Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(height: 12),
        MouseRegion(
          onExit: (_) => _setOverlayState(() => _hoverScore = null),
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(5, (index) {
                final starValue = index + 1.0;
                final isLit = (_hoverScore ?? _selectedScore) >= starValue;
                return MouseRegion(
                  onEnter: (_) => _setOverlayState(() => _hoverScore = starValue),
                  child: GestureDetector(
                    onTap: () => _setOverlayState(() => _selectedScore = starValue),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: (_hoverScore == starValue) ? 1.2 : 1.0,
                        child: Icon(
                          isLit ? Icons.star : Icons.star_border,
                          color: isLit ? Colors.amber : Colors.white24,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildFieldRow([
          _buildStatusDropdown(),
          _buildProgressPicker(),
        ]),
        const SizedBox(height: 20),
        _buildFieldRow([
          _buildRewatchesPicker(),
          _buildCustomListsPicker(),
        ]),
        const SizedBox(height: 20),
        InkWell(
          onTap: () => _setOverlayState(() => _showAdvanced = !_showAdvanced),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showAdvanced ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: Colors.white38,
                ),
                const SizedBox(width: 8),
                const Text(
                  'OPCIONES AVANZADAS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: 16),
          _buildDatePicker('Comenzado el', _startDate, (d) => _setOverlayState(() => _startDate = d)),
          const SizedBox(height: 16),
          _buildDatePicker('Finalizado el', _completionDate, (d) => _setOverlayState(() => _completionDate = d)),
        ],
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 80,
          alignment: Alignment.centerLeft,
          child: (widget.logoUrl?.isNotEmpty == true)
              ? Image.network(
                  widget.logoUrl!,
                  height: 75,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (_, __, ___) => Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                )
              : Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        MouseRegion(
          onExit: (_) => _setOverlayState(() => _hoverScore = null),
          child: Row(
            children: List.generate(5, (index) {
              final starValue = index + 1.0;
              final isLit = (_hoverScore ?? _selectedScore) >= starValue;
              return MouseRegion(
                onEnter: (_) => _setOverlayState(() => _hoverScore = starValue),
                child: GestureDetector(
                  onTap: () => _setOverlayState(() => _selectedScore = starValue),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: (_hoverScore == starValue) ? 1.2 : 1.0,
                      child: Icon(
                        isLit ? Icons.star : Icons.star_border,
                        color: isLit ? Colors.amber : Colors.white24,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
        _buildFieldRow([
          _buildStatusDropdown(),
          _buildProgressPicker(),
          _buildRewatchesPicker(),
        ]),
        const SizedBox(height: 20),
        _buildCustomListsPicker(),
        const SizedBox(height: 20),
        InkWell(
          onTap: () => _setOverlayState(() => _showAdvanced = !_showAdvanced),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _showAdvanced ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: Colors.white38,
                ),
                const SizedBox(width: 8),
                const Text(
                  'OPCIONES AVANZADAS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: 20),
          _buildFieldRow([
            _buildDatePicker('Comenzado el', _startDate, (d) => _setOverlayState(() => _startDate = d)),
            _buildDatePicker('Finalizado el', _completionDate, (d) => _setOverlayState(() => _completionDate = d)),
          ]),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _hideOverlay,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_outline, color: Color(0xFFFF8A8A), size: 20),
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}


class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 8) text = text.substring(0, 8);

    if (text.length > 4) {
      int monthPart = int.parse(text.substring(4, text.length > 6 ? 6 : text.length));
      if (text.length == 5 && monthPart > 1) { 
        text = '${text.substring(0, 4)}0$monthPart';
      } else if (text.length >= 6 && monthPart > 12) {
        text = '${text.substring(0, 4)}12${text.substring(6)}';
      } else if (text.length >= 6 && monthPart == 0) {
        text = '${text.substring(0, 4)}01${text.substring(6)}';
      }
    }

    if (text.length > 6) {
      int year = int.parse(text.substring(0, 4));
      int month = int.parse(text.substring(4, 6));
      if (month == 0) month = 1;
      int maxDays = DateTime(year, month + 1, 0).day;
      
      int dayPart = int.parse(text.substring(6));
      if (text.length == 7 && dayPart > 3) {
        text = '${text.substring(0, 6)}0$dayPart';
      } else if (text.length >= 8 && dayPart > maxDays) {
        text = '${text.substring(0, 6)}$maxDays';
      } else if (text.length >= 8 && dayPart == 0) {
         text = '${text.substring(0, 6)}01';
      }
    }

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 4 || i == 6) formatted += ' / ';
      formatted += text[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _DateOverlayWrapper extends StatefulWidget {
  final DateTime? date;
  final Function(DateTime?) onDateChanged;

  const _DateOverlayWrapper({required this.date, required this.onDateChanged});

  @override
  State<_DateOverlayWrapper> createState() => _DateOverlayWrapperState();
}

class _DateOverlayWrapperState extends State<_DateOverlayWrapper> with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  bool _isCalendarMode = false;

  late PageController _yearController;
  late PageController _monthController;
  late PageController _dayController;

  final DateTime _baseDate = DateTime.utc(1950, 1, 1);
  late DateTime _currentDate;

  final List<String> months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

  @override
  void initState() {
    super.initState();
    final initial = widget.date ?? DateTime.now();
    _currentDate = DateTime(initial.year, initial.month, initial.day);
    _updateText();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 275),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
    
    int initYear = _currentDate.year - 1950;
    int initMonth = (_currentDate.year - 1950) * 12 + (_currentDate.month - 1);
    int initDay = DateTime.utc(_currentDate.year, _currentDate.month, _currentDate.day).difference(_baseDate).inDays;

    _yearController = PageController(initialPage: initYear, viewportFraction: 0.31);
    _monthController = PageController(initialPage: initMonth, viewportFraction: 0.31);
    _dayController = PageController(initialPage: initDay, viewportFraction: 0.31);
  }

  void _updateText() {
    _textController.text = '${_currentDate.year} / ${_currentDate.month.toString().padLeft(2, '0')} / ${_currentDate.day.toString().padLeft(2, '0')}';
  }

  void _showOverlay() {
    if (_isOpen) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward();
    setState(() => _isOpen = true);
  }

  void _hideOverlay() async {
    if (!_isOpen) return;
    _focusNode.unfocus();
    await _animController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  void _syncDate({int? yearIndex, int? monthIndex, int? dayIndex, bool updateTextInput = true}) {
    int y = _currentDate.year;
    int m = _currentDate.month;
    int d = _currentDate.day;

    if (dayIndex != null) {
      final newDate = _baseDate.add(Duration(days: dayIndex));
      y = newDate.year;
      m = newDate.month;
      d = newDate.day;
    } else if (monthIndex != null) {
      y = 1950 + (monthIndex ~/ 12);
      m = (monthIndex % 12) + 1;
      d = d.clamp(1, DateTime(y, m + 1, 0).day);
    } else if (yearIndex != null) {
      y = 1950 + yearIndex;
      d = d.clamp(1, DateTime(y, m + 1, 0).day);
    }

    _currentDate = DateTime(y, m, d);
    widget.onDateChanged(_currentDate);
    
    if (updateTextInput) {
      _updateText();
    }

    int targetYearPage = y - 1950;
    int targetMonthPage = (y - 1950) * 12 + m - 1;
    int targetDayPage = DateTime.utc(y, m, d).difference(_baseDate).inDays;

    void updateController(PageController ctrl, int target, bool jump) {
      if (ctrl.hasClients && ctrl.page?.round() != target) {
        if (jump) {
          ctrl.jumpToPage(target);
        } else {
          ctrl.animateToPage(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
        }
      }
    }

    updateController(_yearController, targetYearPage, false);
    updateController(_monthController, targetMonthPage, yearIndex != null);
    updateController(_dayController, targetDayPage, yearIndex != null || monthIndex != null);
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset globalOffset = renderBox.localToGlobal(Offset.zero);
    final Size widgetSize = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              final screenSize = MediaQuery.of(context).size;
              final isMobile = screenSize.width < 720;
              final targetWidth = isMobile ? (screenSize.width - 64).clamp(280.0, 360.0) : 340.0;
              final targetHeight = _isCalendarMode ? 395.0 : 255.0;

              double idealDx = (screenSize.width - targetWidth) / 2 - globalOffset.dx;
              double idealDy = 0;
              if (globalOffset.dy + targetHeight > screenSize.height - 20) {
                idealDy = (screenSize.height - 20) - (globalOffset.dy + targetHeight);
              }
              if (globalOffset.dy + idealDy < 20) {
                idealDy = 20 - globalOffset.dy;
              }

              final double currentDx = lerpDouble(0, idealDx, _expandAnimation.value)!;
              final double currentDy = lerpDouble(0, idealDy, _expandAnimation.value)!;

              return CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(currentDx, currentDy),
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {},
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: lerpDouble(widgetSize.width, targetWidth, _expandAnimation.value),
                      height: lerpDouble(widgetSize.height, targetHeight, _expandAnimation.value),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(lerpDouble(0.1, 0.3, _expandAnimation.value)!), 
                          width: 1,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5 * _expandAnimation.value),
                            blurRadius: 20,
                            offset: Offset(0, 10 * _expandAnimation.value),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _textController,
                                        focusNode: _focusNode,
                                        keyboardType: TextInputType.number,
                                        textAlignVertical: TextAlignVertical.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        onTapOutside: (event) {},
                                        decoration: const InputDecoration(
                                          hintText: 'YYYY / MM / DD',
                                          hintStyle: TextStyle(color: Colors.white24),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.only(bottom: 4),
                                        ),
                                        inputFormatters: [
                                          _DateInputFormatter(),
                                        ],
                                        onChanged: (val) {
                                          String digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                                          if (digits.isEmpty) return;

                                          if (digits.length == 4) {
                                            int y = int.parse(digits);
                                            if (y >= 1950) {
                                              _syncDate(yearIndex: y - 1950, updateTextInput: false);
                                            }
                                          } else if (digits.length == 6) {
                                            int y = int.parse(digits.substring(0, 4));
                                            int m = int.parse(digits.substring(4, 6)).clamp(1, 12);
                                            if (y >= 1950) {
                                              _syncDate(monthIndex: (y - 1950) * 12 + m - 1, updateTextInput: false);
                                            }
                                          } else if (digits.length == 8) {
                                            int y = int.parse(digits.substring(0, 4));
                                            int m = int.parse(digits.substring(4, 6)).clamp(1, 12);
                                            int d = int.parse(digits.substring(6, 8));
                                            if (y >= 1950) {
                                              int maxDay = DateTime(y, m + 1, 0).day;
                                              d = d.clamp(1, maxDay);
                                              int dIdx = DateTime.utc(y, m, d).difference(_baseDate).inDays;
                                              _syncDate(dayIndex: dIdx, updateTextInput: false);
                                            }
                                          }
                                        },
                                        onSubmitted: (_) {
                                          _focusNode.unfocus();
                                          _hideOverlay();
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(_isCalendarMode ? Icons.view_day_outlined : Icons.calendar_today_outlined, color: Colors.white38, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() => _isCalendarMode = !_isCalendarMode);
                                        _overlayEntry?.markNeedsBuild();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (_expandAnimation.value > 0.1)
                                SizedBox(
                                  height: _isCalendarMode ? 350 : 210,
                                  child: Opacity(
                                    opacity: _expandAnimation.value,
                                    child: _isCalendarMode 
                                      ? Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.dark(
                                              primary: Colors.white,
                                              onPrimary: Colors.black,
                                              surface: Colors.black,
                                              onSurface: Colors.white,
                                            ),
                                          ),
                                          child: TooltipVisibility(
                                            visible: false,
                                          child: SizedBox(
                                            width: targetWidth,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: SizedBox(
                                                  width: 330, // Standard width for CalendarDatePicker
                                                  child: CalendarDatePicker(
                                                    initialDate: _currentDate,
                                                    firstDate: DateTime(1950),
                                                    lastDate: DateTime(2100),
                                                    onDateChanged: (picked) {
                                                      int dIdx = DateTime.utc(picked.year, picked.month, picked.day).difference(_baseDate).inDays;
                                                      _syncDate(dayIndex: dIdx);
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            _buildModernRow(
                                              controller: _yearController,
                                              builder: (i, t) => _buildYearLabel(i, t),
                                              onChanged: (i) {
                                                if (1950 + i == _currentDate.year) return;
                                                _syncDate(yearIndex: i);
                                              },
                                            ),
                                            _buildModernRow(
                                              controller: _monthController,
                                              builder: (i, t) => _buildMonthLabel(i, t),
                                              onChanged: (i) {
                                                if (1950 + (i ~/ 12) == _currentDate.year && (i % 12) + 1 == _currentDate.month) return;
                                                _syncDate(monthIndex: i);
                                              },
                                            ),
                                            _buildModernRow(
                                              controller: _dayController,
                                              builder: (i, t) => _buildDayLabel(i, t),
                                              onChanged: (i) {
                                                final temp = _baseDate.add(Duration(days: i));
                                                if (temp.year == _currentDate.year && temp.month == _currentDate.month && temp.day == _currentDate.day) return;
                                                _syncDate(dayIndex: i);
                                              },
                                            ),
                                          ],
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernRow({required PageController controller, required Widget Function(int, double) builder, required Function(int) onChanged}) {
    return SizedBox(
      height: 70,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: PageView.builder(
          controller: controller,
          onPageChanged: onChanged,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            return AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
              double pageValue = 0.0;
              if (controller.position.hasContentDimensions) {
                pageValue = controller.page! - index;
              } else {
                pageValue = (controller.initialPage - index).toDouble();
              }
              
              final double distance = pageValue.abs();
              final double t = (1 - (distance / 1.1)).clamp(0.0, 1.0);
              final double scaleT = math.pow(t, 1.2).toDouble(); 
              final double opacityT = math.pow(t, 1.2).toDouble(); 
              
              final double rotationY = pageValue * 0.4; 
              final double scale = lerpDouble(0.85, 1.2, scaleT)!;

              return GestureDetector(
                onTap: () => controller.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: distance <= 1.05 ? lerpDouble(0.3, 1.0, opacityT)! : 0.0,
                    child: Transform(
                      alignment: FractionalOffset.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012) 
                        ..rotateY(-rotationY), 
                      child: Transform.scale(
                        scale: scale,
                        child: builder(index, t),
                      ),
                    ),
                  ),
                ),
              );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildYearLabel(int index, double t) {
    int year = 1950 + index;
    return Text(
      year.toString(), 
      style: TextStyle(
        color: Colors.white, 
        fontSize: lerpDouble(14, 18, math.pow(t, 2).toDouble()), 
        fontWeight: t > 0.9 ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildMonthLabel(int index, double t) {
    int month = (index % 12) + 1;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          month.toString().padLeft(2, '0'), 
          style: TextStyle(
            color: Colors.white, 
            fontSize: lerpDouble(14, 18, math.pow(t, 2).toDouble()), 
            fontWeight: t > 0.9 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Opacity(
          opacity: math.pow((t - 0.6).clamp(0.0, 1.0) * 2.5, 2).toDouble(), 
          child: Text(months[month - 1], style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
        ),
      ],
    );
  }

  Widget _buildDayLabel(int index, double t) {
    DateTime date = _baseDate.add(Duration(days: index));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          date.day.toString().padLeft(2, '0'), 
          style: TextStyle(
            color: Colors.white, 
            fontSize: lerpDouble(14, 18, math.pow(t, 2).toDouble()), 
            fontWeight: t > 0.9 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Opacity(
          opacity: math.pow((t - 0.6).clamp(0.0, 1.0) * 2.5, 2).toDouble(),
          child: Text(_getDayName(date.weekday), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
        ),
      ],
    );
  }

  String _getDayName(int weekday) {
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return names[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          if (!_isOpen) {
            _showOverlay();
          }
        },
        child: Opacity(
          opacity: _isOpen ? 0 : 1,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AbsorbPointer(
                    child: TextFormField(
                      key: ValueKey(widget.date),
                      initialValue: widget.date == null ? 'Seleccionar' : '${_currentDate.year} / ${_currentDate.month.toString().padLeft(2, '0')} / ${_currentDate.day.toString().padLeft(2, '0')}',
                      readOnly: true,
                      showCursor: false,
                      style: TextStyle(color: widget.date == null ? Colors.white24 : Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.only(bottom: 4),
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }
}

class _NumericInputField extends StatefulWidget {
  final int value;
  final int? max;
  final Function(int) onChanged;

  const _NumericInputField({required this.value, this.max, required this.onChanged});

  @override
  State<_NumericInputField> createState() => _NumericInputFieldState();
}

class _NumericInputFieldState extends State<_NumericInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_NumericInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              textAlignVertical: TextAlignVertical.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.only(bottom: 4),
                suffixText: widget.max != null ? '/ ${widget.max}' : null,
                suffixStyle: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
              onChanged: (val) {
                int n = int.tryParse(val) ?? 0;
                if (widget.max != null && n > widget.max!) {
                  n = widget.max!;
                  _controller.text = n.toString();
                  _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
                }
                widget.onChanged(n);
              },
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  int n = widget.value + 1;
                  if (widget.max != null && n > widget.max!) n = widget.max!;
                  widget.onChanged(n);
                  _controller.text = n.toString();
                },
                child: const Icon(Icons.keyboard_arrow_up, color: Colors.white38, size: 14),
              ),
              GestureDetector(
                onTap: () {
                  if (widget.value > 0) {
                    final n = widget.value - 1;
                    widget.onChanged(n);
                    _controller.text = n.toString();
                  }
                },
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ListEditDropdown extends StatefulWidget {
  final List<String> items;
  final String defaultTitle;
  final int durationMs;
  final Function(int) onSelected;
  final double? width;
  final bool isFullWidth;
  final int initialIndex;

  const _ListEditDropdown({
    required this.items,
    required this.defaultTitle,
    required this.durationMs,
    required this.onSelected,
    this.width,
    this.isFullWidth = false,
    this.initialIndex = 0,
  });

  @override
  State<_ListEditDropdown> createState() => _ListEditDropdownState();
}

class _ListEditDropdownState extends State<_ListEditDropdown> with SingleTickerProviderStateMixin {
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
    _selectedItemIndex = widget.initialIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  void _toggle() {
    if (_isExpanded) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward();
    setState(() => _isExpanded = true);
  }

  void _hideOverlay() async {
    await _controller.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isExpanded = false);
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Size size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 0),
            child: Material(
              color: Colors.transparent,
              child: FadeTransition(
                opacity: _expandAnimation,
                child: ScaleTransition(
                  scale: _expandAnimation,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: widget.isFullWidth ? size.width : (widget.width ?? 160),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header (Original trigger look)
                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.items[_selectedItemIndex],
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: widget.items.length,
                              itemBuilder: (context, index) => _ListEditDropdownItem(
                                label: widget.items[index],
                                isSelected: index == _selectedItemIndex,
                                animationValue: _controller.value,
                                index: index,
                                onTap: () {
                                  setState(() => _selectedItemIndex = index);
                                  widget.onSelected(index);
                                  _toggle();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: _toggle,
          child: Opacity(
            opacity: _isExpanded ? 0 : 1,
            child: Container(
              height: 38,
              width: widget.isFullWidth ? double.infinity : (widget.width ?? 160),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(_isHovered ? 0.15 : 0.08),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(text: widget.items[_selectedItemIndex]),
                          readOnly: true,
                          showCursor: false,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.only(bottom: 4),
                          ),
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _controller.dispose();
    super.dispose();
  }
}

class _ListEditDropdownItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final double animationValue;
  final int index;
  final VoidCallback onTap;

  const _ListEditDropdownItem({
    required this.label,
    required this.isSelected,
    required this.animationValue,
    required this.index,
    required this.onTap,
  });

  @override
  State<_ListEditDropdownItem> createState() => _ListEditDropdownItemState();
}

class _ListEditDropdownItemState extends State<_ListEditDropdownItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _isHovered ? Colors.white.withOpacity(0.08) : (widget.isSelected ? Colors.white.withOpacity(0.04) : Colors.transparent),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isSelected || _isHovered ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (widget.isSelected)
                  const Icon(Icons.check, color: Colors.deepPurpleAccent, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
