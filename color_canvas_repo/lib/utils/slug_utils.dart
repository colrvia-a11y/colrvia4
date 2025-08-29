class SlugUtils {
  /// Returns a brand key in the format 'brand_<normalized_name>'
  /// Normalizes by converting to lowercase and replacing spaces/hyphens with underscores
  static String brandKey(String name) {
    String normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[-\s]+'), '_')  // Replace hyphens and spaces with underscores
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')  // Remove all other punctuation
        .replaceAll(RegExp(r'_+'), '_')  // Collapse multiple underscores to one
        .replaceAll(RegExp(r'^_+|_+$'), '');  // Remove leading/trailing underscores
    
    return 'brand_$normalized';
  }

  /// Returns a brand slug for display purposes (lowercase words joined by hyphens)
  static String brandSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[-\s]+'), '-')  // Replace hyphens and spaces with single hyphen
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')  // Remove all other punctuation
        .replaceAll(RegExp(r'-+'), '-')  // Collapse multiple hyphens to one
        .replaceAll(RegExp(r'^-+|-+$'), '');  // Remove leading/trailing hyphens
  }
}