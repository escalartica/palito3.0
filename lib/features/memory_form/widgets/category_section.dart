import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/categories.dart';
import 'form_field_containers.dart';

/// Selector desplegable de categoría gastronómica del formulario de
/// recuerdo. Al cambiar de categoría, quien escuche [onCategoryChanged]
/// también debe limpiar los datos dinámicos anteriores (los campos
/// específicos por categoría dependen de `DynamicFieldFactory`).
class CategorySection extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const CategorySection({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel("Categoría"),
        const SizedBox(height: 8),
        NeoContainer(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCategory,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
              items: gastronomicCategories.map((cat) {
                return DropdownMenuItem(value: cat.name, child: Text(cat.name));
              }).toList(),
              onChanged: (val) {
                if (val == null || val == selectedCategory) {
                  return;
                }

                onCategoryChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }
}
