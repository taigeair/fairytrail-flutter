const profileTypeOptions = [
  ('Man', 'man'),
  ('Woman', 'woman'),
  ('Non-binary', 'non-binary'),
];

const mobilityOptions = [
  ('Not Remote', 'non-remote'),
  ('Hybrid', 'hybrid'),
  ('Fully Remote', 'remote'),
];

const sexualityOptions = [
  ('Straight', 'straight'),
  ('Gay', 'gay'),
  ('Lesbian', 'lesbian'),
  ('Bisexual', 'bisexual'),
  ('Asexual', 'asexual'),
  ('Demisexual', 'demisexual'),
  ('Pansexual', 'pansexual'),
  ('Queer', 'queer'),
  ('Questioning', 'questioning'),
  ('Other', 'other'),
];

String? labelForSexuality(String? value) {
  if (value == null || value.isEmpty) return null;
  for (final option in sexualityOptions) {
    if (option.$2 == value) return option.$1;
  }
  return value;
}
