import 'package:flutter/material.dart';
import '../../models/login_models.dart';
import '../../config/constants.dart';

/// Country code selector widget for phone number input
class CountryCodeSelector extends StatelessWidget {
  final String selectedCode;
  final List<CountryCodeEntity> countries;
  final Function(String) onCodeSelected;
  final bool enabled;

  const CountryCodeSelector({
    super.key,
    required this.selectedCode,
    required this.countries,
    required this.onCodeSelected,
    this.enabled = true,
  });

  String _getDisplayCode(String code) {
    if (code.startsWith('00')) {
      return '+${code.substring(2)}';
    }
    return '+$code';
  }

  CountryCodeEntity? _getSelectedCountry() {
    try {
      return countries.firstWhere((country) => country.code == selectedCode);
    } catch (e) {
      return null;
    }
  }

  void _showCountryPicker(BuildContext context) {
    if (!enabled) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CountryPickerBottomSheet(
        countries: countries,
        selectedCode: selectedCode,
        onCodeSelected: onCodeSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCountry = _getSelectedCountry();

    return GestureDetector(
      onTap: enabled ? () => _showCountryPicker(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? Colors.grey : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          color: enabled ? null : Colors.grey[100],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedCountry?.icon != null &&
                selectedCountry!.icon!.isNotEmpty)
              Text(selectedCountry.icon!, style: const TextStyle(fontSize: 20))
            else
              const Icon(Icons.flag, size: 20),
            const SizedBox(width: 8),
            Text(
              _getDisplayCode(selectedCode),
              style: TextStyle(
                fontSize: 16,
                color: enabled ? null : Colors.grey[600],
              ),
            ),
            if (enabled) const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for country selection
class CountryPickerBottomSheet extends StatefulWidget {
  final List<CountryCodeEntity> countries;
  final String selectedCode;
  final Function(String) onCodeSelected;

  const CountryPickerBottomSheet({
    super.key,
    required this.countries,
    required this.selectedCode,
    required this.onCodeSelected,
  });

  @override
  State<CountryPickerBottomSheet> createState() =>
      _CountryPickerBottomSheetState();
}

class _CountryPickerBottomSheetState extends State<CountryPickerBottomSheet> {
  final _searchController = TextEditingController();
  List<CountryCodeEntity> _filteredCountries = [];

  @override
  void initState() {
    super.initState();
    _filteredCountries = widget.countries;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = widget.countries;
      } else {
        _filteredCountries = widget.countries.where((country) {
          final name = country.name?.toLowerCase() ?? '';
          final code = country.code?.toLowerCase() ?? '';
          final pying = country.pying?.toLowerCase() ?? '';

          return name.contains(query) ||
              code.contains(query) ||
              pying.contains(query);
        }).toList();
      }
    });
  }

  String _getDisplayCode(String? code) {
    if (code == null) return '';
    if (code.startsWith('00')) {
      return '+${code.substring(2)}';
    }
    return '+$code';
  }

  void _selectCountry(CountryCodeEntity country) {
    if (country.code != null) {
      widget.onCodeSelected(country.code!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(UIConstants.defaultPadding),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            'Select Country',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search countries...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(UIConstants.borderRadius),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Countries list
          Expanded(
            child: _filteredCountries.isEmpty
                ? const Center(child: Text('No countries found'))
                : ListView.builder(
                    itemCount: _filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = _filteredCountries[index];
                      final isSelected = country.code == widget.selectedCode;

                      return ListTile(
                        leading:
                            country.icon != null && country.icon!.isNotEmpty
                            ? Text(
                                country.icon!,
                                style: const TextStyle(fontSize: 28),
                              )
                            : const Icon(Icons.flag, size: 24),
                        title: Text(
                          country.name ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          _getDisplayCode(country.code),
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey[600],
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).primaryColor,
                              )
                            : null,
                        onTap: () => _selectCountry(country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// Compact country code selector for inline use
class CompactCountryCodeSelector extends StatelessWidget {
  final String selectedCode;
  final List<CountryCodeEntity> countries;
  final Function(String) onCodeSelected;
  final bool enabled;

  const CompactCountryCodeSelector({
    super.key,
    required this.selectedCode,
    required this.countries,
    required this.onCodeSelected,
    this.enabled = true,
  });

  String _getDisplayCode(String code) {
    if (code.startsWith('00')) {
      return '+${code.substring(2)}';
    }
    return '+$code';
  }

  CountryCodeEntity? _getSelectedCountry() {
    try {
      return countries.firstWhere((country) => country.code == selectedCode);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCountry = _getSelectedCountry();

    return InkWell(
      onTap: enabled
          ? () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => CountryPickerBottomSheet(
                  countries: countries,
                  selectedCode: selectedCode,
                  onCodeSelected: onCodeSelected,
                ),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedCountry?.icon != null &&
                selectedCountry!.icon!.isNotEmpty)
              Text(selectedCountry.icon!, style: const TextStyle(fontSize: 14))
            else
              const Icon(Icons.flag, size: 12),
            const SizedBox(width: 4),
            Text(
              _getDisplayCode(selectedCode),
              style: const TextStyle(fontSize: 14),
            ),
            if (enabled) const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }
}
