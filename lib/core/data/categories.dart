// lib/core/data/categories.dart

class Category {
  final String name;
  final String iconPath;

  const Category({required this.name, required this.iconPath});
}

const List<Category> gastronomicCategories = [
  Category(name: "Croquetas", iconPath: "assets/icons/iconoTenedor.png"),
  Category(name: "Ensaladilla", iconPath: "assets/icons/iconoTenedorCaraFeliz.png"),
  Category(name: "Tortilla", iconPath: "assets/icons/IconoRedondoTenedor.png"),
  Category(name: "Menú", iconPath: "assets/icons/iconoLibreta.png"), // Añadido
  Category(name: "Plato Estrella", iconPath: "assets/icons/iconoTenedorConEstrella.png"),
  Category(name: "Postres / Helados", iconPath: "assets/icons/iconoEstrellaRosa.png"),
  Category(name: "Decoración / Espacio", iconPath: "assets/icons/iconoCasa.png"), // Añadido
  Category(name: "Atención", iconPath: "assets/icons/iconoCaraSabores.png"),
];