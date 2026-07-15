import 'package:flutter/material.dart';
import '../../../core/data/categories.dart';
import '../../core/theme/components/category_card.dart'; // Asegúrate de importar el nuevo componente
import '../pages/category_list_page.dart'; // O donde tengas tu lista de categorías

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text("Explorar Sabores"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: gastronomicCategories.length,
          itemBuilder: (context, index) {
            final category = gastronomicCategories[index];
            return CategoryCard(
              category: category,
              onTap: () {
                // Aquí navegas a la lista filtrada por esta categoría
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryListPage(category: category),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}