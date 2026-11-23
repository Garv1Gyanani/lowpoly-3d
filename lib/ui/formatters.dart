/// Compact cash formatting for minimalist HUD readouts.
String formatCash(double amount) {
  if (amount >= 1000000) {
    return '\$${(amount / 1000000).toStringAsFixed(2)}M';
  }
  if (amount >= 10000) {
    return '\$${(amount / 1000).toStringAsFixed(1)}K';
  }
  return '\$${amount.floor()}';
}
