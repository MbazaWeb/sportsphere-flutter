/// Shared form validators — short, user-facing messages only.
class FormValidators {
  FormValidators._();

  static String? required(String? v, {String field = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    if (!ok) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v, {int min = 6}) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < min) return 'Password must be at least $min characters';
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Confirm your password';
    if (v != original) return 'Passwords do not match';
    return null;
  }

  static String? handle(String? v) {
    if (v == null || v.trim().isEmpty) return 'Username is required';
    final h = v.trim().replaceAll('@', '');
    if (h.length < 3) return 'Username must be at least 3 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(h)) {
      return 'Only letters, numbers and underscore';
    }
    return null;
  }

  static String? phone(String? v, {bool required = false}) {
    if (v == null || v.trim().isEmpty) {
      return required ? 'Phone is required' : null;
    }
    final digits = v.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.length < 9) return 'Enter a valid phone number';
    return null;
  }

  static String? year(String? v, {int min = 1800, int? max}) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    final top = max ?? DateTime.now().year + 1;
    if (n == null || n < min || n > top) return 'Enter a valid year';
    return null;
  }

  static String? positiveInt(String? v, {String field = 'Value', bool required = false}) {
    if (v == null || v.trim().isEmpty) {
      return required ? '$field is required' : null;
    }
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a valid number';
    return null;
  }

  static String? dropdownRequired(String? v, {String field = 'Selection'}) {
    if (v == null || v.trim().isEmpty) return 'Select $field';
    return null;
  }
}

/// Common seasons for competition forms.
const kSeasonOptions = <String>[
  '2024/25',
  '2025/26',
  '2026/27',
  '2027/28',
  '2028/29',
];

/// Competition types.
const kCompetitionTypes = <String>[
  'league',
  'cup',
  'friendly',
  'international',
];

/// Player positions.
const kPlayerPositions = <String>[
  'Goalkeeper',
  'Defender',
  'Midfielder',
  'Forward',
  'Winger',
  'Striker',
];

/// Coach / staff roles.
const kCoachRoles = <String>[
  'head_coach',
  'assistant_coach',
  'goalkeeper_coach',
  'fitness_coach',
  'analyst',
  'scout',
  'physio',
  'technical_director',
];

/// Match status values.
const kMatchStatuses = <String>[
  'upcoming',
  'live',
  'halftime',
  'finished',
  'postponed',
  'cancelled',
];

/// East Africa + popular cities (location / city dropdowns).
const kCityOptions = <String>[
  'Dar es Salaam',
  'Dodoma',
  'Arusha',
  'Mwanza',
  'Mbeya',
  'Morogoro',
  'Tanga',
  'Zanzibar',
  'Moshi',
  'Kigoma',
  'Nairobi',
  'Mombasa',
  'Kisumu',
  'Kampala',
  'Entebbe',
  'Kigali',
  'Bujumbura',
  'Addis Ababa',
  'Johannesburg',
  'Cape Town',
  'Lagos',
  'Accra',
  'Cairo',
  'London',
  'Dubai',
  'Other',
];

/// Post / claim location suggestions.
const kLocationOptions = <String>[
  'Dar es Salaam, Tanzania',
  'National Stadium, DSM',
  'Benjamin Mkapa Stadium',
  'Mkapa Stadium, DSM',
  'Amaan Stadium, Zanzibar',
  'Nairobi, Kenya',
  'Kampala, Uganda',
  'Kigali, Rwanda',
  'Other',
];
