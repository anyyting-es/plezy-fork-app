import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../services/api_service.dart';

class FiltersModal extends StatefulWidget {
  final List<String> initialGenres;
  final String initialSort;
  final String initialFormat;
  final String initialStatus;
  final int initialYear;
  final List<(String, String)> sortOptions;
  final List<(String, String)> formatOptions;
  final List<(String, String)> statusOptions;
  final List<(int, String)> yearOptions;
  final Function(List<String> genres, String sort, String format, String status, int year) onFiltersChanged;

  const FiltersModal({
    super.key,
    required this.initialGenres,
    required this.initialSort,
    required this.initialFormat,
    required this.initialStatus,
    required this.initialYear,
    required this.sortOptions,
    required this.formatOptions,
    required this.statusOptions,
    required this.yearOptions,
    required this.onFiltersChanged,
  });

  @override
  State<FiltersModal> createState() => _FiltersModalState();
}

class _FiltersModalState extends State<FiltersModal> {
  late List<String> _genres;
  late String _sort;
  late String _formatFilter;
  late String _statusFilter;
  late int _yearFilter;

  @override
  void initState() {
    super.initState();
    _genres = List.from(widget.initialGenres);
    _sort = widget.initialSort;
    _formatFilter = widget.initialFormat;
    _statusFilter = widget.initialStatus;
    _yearFilter = widget.initialYear;
  }

  void _notifyChanges() {
    widget.onFiltersChanged(_genres, _sort, _formatFilter, _statusFilter, _yearFilter);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modalBg = scheme.surface;
    final modalBorder = scheme.onSurface.withValues(alpha: 0.12);
    final panelBg = scheme.onSurface.withValues(alpha: 0.06);
    final subtleText = scheme.onSurface.withValues(alpha: 0.62);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        border: Border(top: BorderSide(color: modalBorder)),
      ),
      child: Column(
        children: [
          // Cabecera del Modal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Icon(
                  LucideIcons.slidersHorizontal,
                  color: scheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Filtros Avanzados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _genres.clear();
                      _sort = 'TRENDING_DESC';
                      _formatFilter = '';
                      _statusFilter = '';
                      _yearFilter = 0;
                    });
                    _notifyChanges();
                  },
                  child: Text(
                    'Limpiar',
                    style: TextStyle(color: subtleText),
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, color: subtleText),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: modalBorder),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 12),

                // Ordenar por
                const ModalSectionTitle(title: 'ORDENAR POR'),
                ModalDropdown<String>(
                  value: _sort,
                  options: widget.sortOptions,
                  onChanged: (val) {
                    setState(() => _sort = val!);
                    _notifyChanges();
                  },
                ),
                const SizedBox(height: 24),

                // Fila de 2 columnas: Formato y Año
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ModalSectionTitle(title: 'FORMATO'),
                          ModalDropdown<String>(
                            value: _formatFilter,
                            options: widget.formatOptions,
                            onChanged: (val) {
                              setState(() => _formatFilter = val!);
                              _notifyChanges();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ModalSectionTitle(title: 'AÑO'),
                          ModalDropdown<int>(
                            value: _yearFilter,
                            options: widget.yearOptions,
                            onChanged: (val) {
                              setState(() => _yearFilter = val!);
                              _notifyChanges();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Estado
                const ModalSectionTitle(title: 'ESTADO'),
                ModalDropdown<String>(
                  value: _statusFilter,
                  options: widget.statusOptions,
                  onChanged: (val) {
                    setState(() => _statusFilter = val!);
                    _notifyChanges();
                  },
                ),
                const SizedBox(height: 24),

                // Géneros
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ModalSectionTitle(title: 'GÉNEROS'),
                    if (_genres.isNotEmpty)
                      Text(
                        '${_genres.length} seleccionados',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtleText,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ApiService.genreOptions.map((genre) {
                    final selected = _genres.contains(genre);
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _genres.remove(genre);
                          } else {
                            _genres.add(genre);
                          }
                        });
                        _notifyChanges();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.16)
                              : panelBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (selected ? scheme.primary : scheme.onSurface)
                                .withValues(
                              alpha: selected ? 0.35 : 0.12,
                            ),
                          ),
                        ),
                        child: Text(
                          genre,
                          style: TextStyle(
                            color: selected ? scheme.primary : subtleText,
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModalSectionTitle extends StatelessWidget {
  final String title;
  const ModalSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: scheme.onSurface.withValues(alpha: 0.52),
        ),
      ),
    );
  }
}

class ModalDropdown<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;

  const ModalDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedLabel = options.firstWhere((o) => o.$1 == value).$2;

    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.14)),
      ),
      position: PopupMenuPosition.under,
      elevation: 10,
      clipBehavior: Clip.antiAlias,
      itemBuilder: (context) => options.map((option) {
        final isSelected = option.$1 == value;
        return PopupMenuItem<T>(
          value: option.$1,
          height: 44,
          child: Row(
            children: [
              Text(
                option.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? scheme.primary : scheme.onSurface,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(LucideIcons.check, size: 16, color: scheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedLabel,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 18, color: scheme.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
