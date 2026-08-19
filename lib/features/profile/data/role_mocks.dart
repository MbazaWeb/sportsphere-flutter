import 'package:flutter/material.dart';

import '../../shop/models/shop_models.dart';
import '../shared/profile_widgets.dart';
import '../templates/role_profile_model.dart';

RoleProfileModel roleProfileFor(String role, String handle) {
  final factory = _factories[role];
  if (factory != null) return factory(handle);
  return _person(handle: handle, role: role, name: handle, subtitle: role, accent: const Color(0xFF009DFF));
}

typedef _Factory = RoleProfileModel Function(String handle);

final Map<String, _Factory> _factories = {
  'coach': (h) => _person(handle: h, role: 'Coach', name: h == 'traguil' ? 'Sergio Traguil' : _title(h), subtitle: 'Head Coach · Simba SC', accent: const Color(0xFFFF8A00), icon: Icons.sports, bio: 'High-press tactician focused on youth pathways and set-piece structure.', about: const [AboutField('Club', 'Simba SC'), AboutField('Licence', 'CAF A'), AboutField('Appointed', '2024')], stats: const [AboutField('Win %', '61'), AboutField('Trophies', '2')], posts: const [ProfilePost(text: 'Proud of the dressing room after a hard-fought derby.', hashtags: ['#SimbaSC', '#Coaching'], timeAgo: '4h', likes: 2100, comments: 84, shares: 41)]),
  'scout': (h) => _person(handle: h, role: 'Scout', name: _title(h), subtitle: 'Regional scout · East Africa', accent: const Color(0xFF76D42B), icon: Icons.travel_explore_rounded, bio: 'Watching the next wave of talent across the Tanzanian leagues.', about: const [AboutField('Coverage', 'Tanzania · Kenya · Zambia')], stats: const [AboutField('Players tracked', '86')]),
  'agent': (h) => _person(handle: h, role: 'Agent', name: _title(h), subtitle: 'FIFA-licensed player agent', accent: const Color(0xFF22B8FF), icon: Icons.handshake_rounded, bio: 'Representing players across the CAF and European markets.', about: const [AboutField('Licence', 'FIFA Agent')], stats: const [AboutField('Transfers', '11')]),
  'support_staff': (h) => _person(handle: h, role: 'Support Staff', name: _title(h), subtitle: 'Physiotherapist · First team', accent: const Color(0xFF8FA3B8), icon: Icons.health_and_safety_rounded, bio: 'Load management, rehab, and matchday medical cover.', about: const [AboutField('Department', 'Medical')], stats: const [AboutField('Availability', '94%')]),
  'analyst': (h) => _person(handle: h, role: 'Analyst', name: h == 'alikingu' ? 'Ali Kingu' : _title(h), subtitle: 'Performance & tactical analyst', accent: const Color(0xFF009DFF), icon: Icons.analytics_rounded, bio: 'Breaking down pressing triggers and chance quality.', about: const [AboutField('Specialism', 'Opposition analysis')], stats: const [AboutField('Reports', '62')]),
  'commentator': (h) => _person(handle: h, role: 'Commentator', name: _title(h), subtitle: 'Live match commentator', accent: const Color(0xFFFF8A00), icon: Icons.mic_rounded, bio: 'Voice of the derby. Swahili & English commentary.', about: const [AboutField('Languages', 'Swahili, English')], stats: const [AboutField('Matches called', '210')]),
  'journalist': (h) => _person(handle: h, role: 'Journalist', name: _title(h), subtitle: 'Football correspondent', accent: const Color(0xFF22B8FF), icon: Icons.article_rounded, bio: 'Transfer news, match reports, and locker-room access.', about: const [AboutField('Outlet', 'SportSphere Media')], stats: const [AboutField('Stories', '340')]),
  'creator': (h) => _person(handle: h, role: 'Creator', name: _title(h), subtitle: 'Fan content & highlights', accent: const Color(0xFFFF3B61), icon: Icons.videocam_rounded, bio: 'Matchday vlogs and tactical explainers.', about: const [AboutField('Platforms', 'SportSphere · YouTube')], stats: const [AboutField('Views', '1.2M')]),
  'moderator': (h) => _person(handle: h, role: 'Moderator', name: _title(h), subtitle: 'Community safety', accent: const Color(0xFF76D42B), icon: Icons.shield_rounded, bio: 'Keeping SportSphere conversations fair and on-topic.', about: const [AboutField('Scope', 'Football communities')], stats: const [AboutField('Actions', '1,102')]),
  'official': (h) => _person(handle: h, role: 'Official', name: _title(h), subtitle: 'Match official · TFF', accent: const Color(0xFFF7FAFF), icon: Icons.sports_soccer_rounded, bio: 'FIFA-listed referee covering TPL and CAF assignments.', about: const [AboutField('Association', 'TFF')], stats: const [AboutField('Matches', '92')]),
  'academy': (h) => _org(handle: h, role: 'Academy', name: h == 'simba-academy' ? 'Simba Academy' : _title(h), subtitle: 'Youth development', accent: const Color(0xFFE31B23), icon: Icons.school_rounded, bio: 'Pathway from U13 to first team.', membersTitle: 'Prospects', about: const [AboutField('Age groups', 'U13–U21')], members: const [RoleMember(name: 'Iddi Salum', handle: 'iddisalum', subtitle: 'U18 · Midfield')], stats: const [AboutField('Graduates', '41')]),
  'league': (h) => _org(handle: h, role: 'League', name: h == 'tpl' ? 'Tanzania Premier League' : _title(h), subtitle: 'Top-flight football', accent: const Color(0xFF009DFF), icon: Icons.emoji_events_rounded, bio: 'The premier professional league in Tanzania.', membersTitle: 'Clubs', about: const [AboutField('Teams', '16')], members: const [RoleMember(name: 'Simba SC', handle: 'simbasc', subtitle: 'Dar es Salaam', route: '/team/simbasc')], stats: const [AboutField('Matches', '240')]),
  'competition': (h) => _org(handle: h, role: 'Competition', name: _title(h), subtitle: 'Cup competition', accent: const Color(0xFFFFD700), icon: Icons.workspace_premium_rounded, bio: 'Knockout football from last 32 to the final.', membersTitle: 'Stages', about: const [AboutField('Format', 'Knockout')], members: const [RoleMember(name: 'Round of 16', handle: 'r16', subtitle: '8 fixtures')]),
  'organization': (h) => _org(handle: h, role: 'Organization', name: h == 'tff' ? 'Tanzania Football Federation' : _title(h), subtitle: 'National governing body', accent: const Color(0xFF22B8FF), icon: Icons.account_balance_rounded, bio: 'Governing football across Tanzania.', membersTitle: 'Departments', about: const [AboutField('Founded', '1930')], members: const [RoleMember(name: 'National Teams', handle: 'taifa', subtitle: 'Men & Women')]),
  'media_broadcast': (h) => _org(handle: h, role: 'Media / Broadcast', name: _title(h), subtitle: 'Rights holder & studio', accent: const Color(0xFFFF8A00), icon: Icons.live_tv_rounded, bio: 'Live TPL coverage, studio analysis, and highlights.', membersTitle: 'Talent', about: const [AboutField('Rights', 'TPL 2024–27')], members: const [RoleMember(name: 'Studio Desk', handle: 'studio', subtitle: 'Matchday')]),
  'community': (h) => _org(handle: h, role: 'Community', name: _title(h), subtitle: 'Fan community', accent: const Color(0xFF76D42B), icon: Icons.forum_rounded, bio: 'A home for supporters, debate, and watch-alongs.', membersTitle: 'Admins', about: const [AboutField('Members', '18.2K')], members: const [RoleMember(name: 'Community Lead', handle: 'lead', subtitle: 'Moderator')]),
  'business': (h) => _commerce(handle: h, role: 'Business', name: _title(h), subtitle: 'Sports commerce', accent: const Color(0xFF009DFF), bio: 'Retail, hospitality, and club services.'),
  'sponsor': (h) => _commerce(handle: h, role: 'Sponsor', name: _title(h), subtitle: 'Official club sponsor', accent: const Color(0xFFFFD700), icon: Icons.diamond_rounded, bio: 'Partnering clubs with brand activations and kits.'),
  'commercial_partner': (h) => _commerce(handle: h, role: 'Commercial Partner', name: _title(h), subtitle: 'Rights & activations', accent: const Color(0xFF22B8FF), icon: Icons.handshake_rounded, bio: 'Matchday hospitality, sleeve deals, and CSR.'),
  'venue': (h) => _commerce(handle: h, role: 'Venue', name: h == 'mkapa' ? 'Benjamin Mkapa Stadium' : _title(h), subtitle: '60,000-capacity stadium', accent: const Color(0xFFE31B23), icon: Icons.stadium_rounded, bio: 'Home of Tanzanian football nights in Dar es Salaam.', extraAbout: const [AboutField('Capacity', '60,000')]),
};

String _title(String handle) {
  if (handle.isEmpty) return 'Profile';
  return handle.replaceAll('_', ' ').replaceAll('-', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

RoleProfileModel _person({
  required String handle,
  required String role,
  required String name,
  required String subtitle,
  required Color accent,
  IconData icon = Icons.person_rounded,
  String bio = '',
  List<AboutField> about = const [],
  List<AboutField> stats = const [],
  List<ProfilePost> posts = const [],
}) {
  return RoleProfileModel(
    displayName: name, handle: handle, roleLabel: role, accent: accent, subtitle: subtitle, bio: bio,
    location: 'Dar es Salaam, Tanzania', coverIcon: icon,
    headerStats: const [RoleStat('128', 'Posts'), RoleStat('12.4K', 'Followers'), RoleStat('310', 'Following')],
    aboutFields: about, statsRows: stats, posts: posts, shape: RoleShape.person,
  );
}

RoleProfileModel _org({
  required String handle,
  required String role,
  required String name,
  required String subtitle,
  required Color accent,
  IconData icon = Icons.groups_rounded,
  String bio = '',
  String membersTitle = 'Members',
  List<AboutField> about = const [],
  List<RoleMember> members = const [],
  List<AboutField> stats = const [],
}) {
  return RoleProfileModel(
    displayName: name, handle: handle, roleLabel: role, accent: accent, subtitle: subtitle, bio: bio,
    location: 'Tanzania', coverIcon: icon,
    headerStats: const [RoleStat('86', 'Posts'), RoleStat('54K', 'Fans'), RoleStat('40', 'Following')],
    aboutFields: about, members: members, membersTitle: membersTitle, statsRows: stats,
    posts: const [ProfilePost(text: 'Season update is live. Follow for fixtures and statements.', hashtags: ['#SportSphere'], timeAgo: '8h', likes: 420, comments: 19, shares: 11)],
    shape: RoleShape.org,
  );
}

RoleProfileModel _commerce({
  required String handle,
  required String role,
  required String name,
  required String subtitle,
  required Color accent,
  IconData icon = Icons.storefront_rounded,
  String bio = '',
  List<AboutField> extraAbout = const [],
}) {
  return RoleProfileModel(
    displayName: name, handle: handle, roleLabel: role, accent: accent, subtitle: subtitle, bio: bio,
    location: 'Dar es Salaam, Tanzania', coverIcon: icon,
    headerStats: const [RoleStat('42', 'Posts'), RoleStat('9.1K', 'Followers'), RoleStat('18', 'Partners')],
    aboutFields: [AboutField('Category', role), AboutField('Market', 'Tanzania'), ...extraAbout],
    shop: businessShopCatalog(name: name, handle: handle, accent: accent),
    posts: const [ProfilePost(text: 'New hospitality packages and merch drops this week.', hashtags: ['#Shop', '#Matchday'], timeAgo: '2d', likes: 190, comments: 12, shares: 8)],
    shape: RoleShape.commerce,
  );
}
