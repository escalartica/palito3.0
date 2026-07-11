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
  Category(name: "Plato Estrella", iconPath: "assets/icons/iconoTenedorConEstrella.png"),
  Category(name: "Postres / Helados", iconPath: "assets/icons/iconoEstrellaRosa.png"),
  Category(name: "Atención", iconPath: "assets/icons/iconoCaraSabores.png"),
  // Puedes usar el resto para futuras categorías que definamos
];