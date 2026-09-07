/// Default BlurHash when a photo hash is missing or fails to decode.
/// Matches RN `fallbackBlurHash` in `mobile/src/constants.tsx`.
const kFallbackBlurHash =
    '|rF?hV%2WCj[ayj[a|j[az_NaeWBj@ayfRayfQfQM{M|azj[azf6fQfQfQIpWXofj[ayj[j[fQayWCoeoeaya}j[ayfQa{oLj?j[WVj[ayayj[fQoff7azayj[ayj[j[ayofayayayj[fQj[ayayj[ayfjj[j[ayjuayj[';

/// Returns a usable BlurHash string — photo hash when present, else the default.
String effectiveBlurHash(String? blurHash) {
  final trimmed = blurHash?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return kFallbackBlurHash;
}
