import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/data/categories.dart';
import 'form_field_containers.dart';
import '../../../core/theme/tokens/app_colors.dart';
import '../../../core/theme/tokens/app_shape.dart';

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
              dropdownColor: AppColors.surface,
              // El menú salía con las esquinas de Material, ajenas a la
              // escala de radios de la app. Es lo único que `DropdownButton`
              // deja tocar de su desplegable: no admite ni borde ni sombra
              // propios, así que sigue siendo la última superficie de la app
              // que no habla su idioma. Anotado; sustituirlo por una hoja
              // inferior es un cambio de comportamiento, no de estilo.
              borderRadius: BorderRadius.circular(AppRadius.md),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
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
