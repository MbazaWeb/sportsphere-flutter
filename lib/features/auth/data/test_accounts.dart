/// Offline demo accounts for QA — NOT shown on the login UI.
class TestAccount {
  const TestAccount({
    required this.role,
    required this.handle,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.displayNote,
  });

  final String role;
  final String handle;
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String displayNote;
}

const kDemoPassword = 'Test123';

const kTestAccounts = <TestAccount>[
  TestAccount(role: 'fan', handle: 'david', email: 'david@sportsphere.test', password: kDemoPassword, firstName: 'David', lastName: 'Mwamba', displayNote: 'Fan'),
  TestAccount(role: 'player', handle: 'clatouschama', email: 'chama@sportsphere.test', password: kDemoPassword, firstName: 'Clatous', lastName: 'Chama', displayNote: 'Player'),
  TestAccount(role: 'team', handle: 'simbasc', email: 'simba@sportsphere.test', password: kDemoPassword, firstName: 'Simba', lastName: 'SC', displayNote: 'Team'),
  TestAccount(role: 'coach', handle: 'traguil', email: 'coach@sportsphere.test', password: kDemoPassword, firstName: 'Sergio', lastName: 'Traguil', displayNote: 'Coach'),
  TestAccount(role: 'scout', handle: 'scout_east', email: 'scout@sportsphere.test', password: kDemoPassword, firstName: 'Amina', lastName: 'Juma', displayNote: 'Scout'),
  TestAccount(role: 'agent', handle: 'agent_pro', email: 'agent@sportsphere.test', password: kDemoPassword, firstName: 'Joseph', lastName: 'Kariuki', displayNote: 'Agent'),
  TestAccount(role: 'support_staff', handle: 'physio_ss', email: 'physio@sportsphere.test', password: kDemoPassword, firstName: 'Neema', lastName: 'Omary', displayNote: 'Support Staff'),
  TestAccount(role: 'analyst', handle: 'alikingu', email: 'analyst@sportsphere.test', password: kDemoPassword, firstName: 'Ali', lastName: 'Kingu', displayNote: 'Analyst'),
  TestAccount(role: 'commentator', handle: 'voice_tpl', email: 'comms@sportsphere.test', password: kDemoPassword, firstName: 'Brian', lastName: 'Mtei', displayNote: 'Commentator'),
  TestAccount(role: 'journalist', handle: 'pressdesk', email: 'press@sportsphere.test', password: kDemoPassword, firstName: 'Grace', lastName: 'Lyimo', displayNote: 'Journalist'),
  TestAccount(role: 'creator', handle: 'fanclips', email: 'creator@sportsphere.test', password: kDemoPassword, firstName: 'Kelvin', lastName: 'Mushi', displayNote: 'Creator'),
  TestAccount(role: 'moderator', handle: 'mod_ss', email: 'mod@sportsphere.test', password: kDemoPassword, firstName: 'Fatma', lastName: 'Hassan', displayNote: 'Moderator'),
  TestAccount(role: 'official', handle: 'ref_tff', email: 'ref@sportsphere.test', password: kDemoPassword, firstName: 'Peter', lastName: 'Msangi', displayNote: 'Official'),
  TestAccount(role: 'academy', handle: 'simba_academy', email: 'academy@sportsphere.test', password: kDemoPassword, firstName: 'Simba', lastName: 'Academy', displayNote: 'Academy'),
  TestAccount(role: 'league', handle: 'tpl', email: 'tpl@sportsphere.test', password: kDemoPassword, firstName: 'Tanzania', lastName: 'Premier League', displayNote: 'League'),
  TestAccount(role: 'competition', handle: 'mapinduzi_cup', email: 'cup@sportsphere.test', password: kDemoPassword, firstName: 'Mapinduzi', lastName: 'Cup', displayNote: 'Competition'),
  TestAccount(role: 'organization', handle: 'tff', email: 'tff@sportsphere.test', password: kDemoPassword, firstName: 'Tanzania', lastName: 'FF', displayNote: 'Organization'),
  TestAccount(role: 'media_broadcast', handle: 'azam_sports', email: 'media@sportsphere.test', password: kDemoPassword, firstName: 'Azam', lastName: 'Sports', displayNote: 'Media / Broadcast'),
  TestAccount(role: 'community', handle: 'simba_fans', email: 'community@sportsphere.test', password: kDemoPassword, firstName: 'Simba', lastName: 'Fans', displayNote: 'Community'),
  TestAccount(role: 'business', handle: 'ss_retail', email: 'business@sportsphere.test', password: kDemoPassword, firstName: 'Sphere', lastName: 'Retail', displayNote: 'Business'),
  TestAccount(role: 'sponsor', handle: 'nmb_sport', email: 'sponsor@sportsphere.test', password: kDemoPassword, firstName: 'NMB', lastName: 'Sport', displayNote: 'Sponsor'),
  TestAccount(role: 'commercial_partner', handle: 'partner_ss', email: 'partner@sportsphere.test', password: kDemoPassword, firstName: 'Commercial', lastName: 'Partner', displayNote: 'Commercial Partner'),
  TestAccount(role: 'venue', handle: 'mkapa', email: 'venue@sportsphere.test', password: kDemoPassword, firstName: 'Benjamin', lastName: 'Mkapa Stadium', displayNote: 'Venue'),
];

TestAccount? findTestAccount(String identifier, String password) {
  final id = identifier.trim().toLowerCase().replaceFirst('@', '');
  for (final a in kTestAccounts) {
    final okId = a.handle.toLowerCase() == id || a.email.toLowerCase() == id;
    if (okId && a.password == password) return a;
  }
  return null;
}
