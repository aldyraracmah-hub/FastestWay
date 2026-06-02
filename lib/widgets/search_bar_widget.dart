import 'package:flutter/material.dart';
import '../models/route_info.dart';
import '../services/routing_service.dart';
import '../services/storage_service.dart'; // NEW

/// ── CHANGED vs original ──
/// Shows saved search history when the field is focused but empty.
/// History is loaded from StorageService (saved externally by MapScreen).
class SearchBarWidget extends StatefulWidget {
  final Function(SearchResult) onLocationSelected;
  final String hint;
  final String? initialValue;

  const SearchBarWidget({
    super.key,
    required this.onLocationSelected,
    required this.hint,
    this.initialValue,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _controller = TextEditingController();
  final _focus = FocusNode(); // NEW
  List<SearchResult> _results = [];
  List<SearchHistoryItem> _history = []; // NEW
  bool _loading = false;
  bool _showResults = false;
  bool _showHistory = false; // NEW

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) _controller.text = widget.initialValue!;
    // NEW: load history when focused
    _focus.addListener(() {
      if (_focus.hasFocus && _controller.text.isEmpty) {
        _loadHistory();
      } else if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() { _showHistory = false; _showResults = false; });
        });
      }
    });
  }

  Future<void> _loadHistory() async {
    final h = await StorageService.getSearchHistory();
    if (mounted) setState(() { _history = h; _showHistory = h.isNotEmpty; });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 3) {
      setState(() { _results = []; _showResults = false; });
      if (query.isEmpty) _loadHistory();
      return;
    }
    setState(() { _loading = true; _showHistory = false; });
    final results = await RoutingService.searchPlaces(query);
    if (mounted) {
      setState(() { _results = results; _loading = false; _showResults = results.isNotEmpty; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF252B3D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focus, // NEW
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
              prefixIcon: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: Padding(padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22D3EE))),
                    )
                  : Icon(Icons.search, color: Colors.grey[500], size: 18),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 16, color: Colors.grey[500]),
                      onPressed: () {
                        _controller.clear();
                        setState(() { _results = []; _showResults = false; });
                        _loadHistory();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
            onChanged: _search,
          ),
        ),

        // ── Search results ──
        if (_showResults)
          _ResultsDropdown(
            items: _results.map((r) => _DropdownItem(
              title: r.displayName.split(', ').first,
              subtitle: r.displayName.split(', ').skip(1).take(2).join(', '),
              icon: Icons.location_on,
              iconColor: const Color(0xFF22D3EE),
              onTap: () {
                _controller.text = r.displayName.split(', ').first;
                setState(() => _showResults = false);
                widget.onLocationSelected(r);
              },
            )).toList(),
          ),

        // ── NEW: History dropdown ──
        if (_showHistory && !_showResults)
          _ResultsDropdown(
            header: Row(
              children: [
                Icon(Icons.history, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text('Pencarian terakhir',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await StorageService.clearSearchHistory();
                    setState(() { _history = []; _showHistory = false; });
                  },
                  child: Text('Hapus',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
            items: _history.map((h) => _DropdownItem(
              title: h.displayName.split(', ').first,
              subtitle: h.displayName.split(', ').skip(1).take(2).join(', '),
              icon: Icons.history,
              iconColor: Colors.grey.shade500,
              onTap: () {
                _controller.text = h.displayName.split(', ').first;
                setState(() => _showHistory = false);
                widget.onLocationSelected(SearchResult(
                  displayName: h.displayName,
                  lat: h.lat,
                  lon: h.lon,
                ));
              },
            )).toList(),
          ),
      ],
    );
  }
}

// ── Private helpers ──

class _DropdownItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  _DropdownItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
}

class _ResultsDropdown extends StatelessWidget {
  final List<_DropdownItem> items;
  final Widget? header;

  const _ResultsDropdown({required this.items, this.header});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF252B3D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: header!,
            ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: item.iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 14),
                  ),
                  title: Text(item.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: item.subtitle.isNotEmpty
                      ? Text(item.subtitle,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  onTap: item.onTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}