// constants.dart

/// Offset vremena za produženje kredita (3 minute)
const Duration creditExpiryOffset = Duration(minutes: 3);

/// Ekstrahira ID plana iz productId stringa npr. "store:1-location" -> "1-location"
String extractPlanId(String productId) {
  final parts = productId.split(":");
  return parts.length > 1 ? parts[1] : productId;
}
