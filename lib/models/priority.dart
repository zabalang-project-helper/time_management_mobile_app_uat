/// Priority levels for tasks
enum Priority {
  low('Low'),
  medium('Medium'),
  high('High');

  final String label;
  const Priority(this.label);

  static Priority fromString(String value) {
    return Priority.values.firstWhere(
      (p) => p.label == value,
      orElse: () => Priority.medium,
    );
  }

  /// Returns color hex for calendar date marking
  int get colorHex {
    switch (this) {
      case Priority.low:
        return 0xFF4CAF50; // Green
      case Priority.medium:
        return 0xFFFFC107; // Yellow/Amber
      case Priority.high:
        return 0xFFF44336; // Red
    }
  }
}
