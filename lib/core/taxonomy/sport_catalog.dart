const kAllSports = <String>[
  'football',
  'basketball',
  'athletics',
  'netball',
  'volleyball',
  'rugby',
  'cricket',
  'tennis',
  'boxing',
  'mma',
  'swimming',
  'cycling',
  'hockey',
  'handball',
  'badminton',
  'table_tennis',
  'golf',
  'wrestling',
  'motorsport',
  'esports',
];

String sportLabel(String slug) {
  switch (slug) {
    case 'table_tennis':
      return 'Table tennis';
    case 'mma':
      return 'MMA';
    case 'esports':
      return 'Esports';
    default:
      return slug.replaceAll('_', ' ');
  }
}
