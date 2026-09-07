/// Asset for the kindness thank-you illustration based on sender → receiver gender.
///
/// Only `man` / `woman` get a gendered pair image; anything else uses `else`.
String kindnessRatedAsset({
  String? senderProfileType,
  String? receiverProfileType,
}) {
  final sender = senderProfileType?.trim().toLowerCase();
  final receiver = receiverProfileType?.trim().toLowerCase();

  if (sender == 'man' && receiver == 'man') {
    return 'assets/trailBook/kindnessrated-m2m.png';
  }
  if (sender == 'man' && receiver == 'woman') {
    return 'assets/trailBook/kindnessrated-m2w.png';
  }
  if (sender == 'woman' && receiver == 'man') {
    return 'assets/trailBook/kindnessrated-w2m.png';
  }
  if (sender == 'woman' && receiver == 'woman') {
    return 'assets/trailBook/kindnessrated-w2w.png';
  }
  return 'assets/trailBook/kindnessrated-else.png';
}
