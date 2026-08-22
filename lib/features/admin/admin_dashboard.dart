import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/admin/app_admin.dart';
import '../../../core/data/social_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../scores/presentation/admin_live_control.dart';
import 'admin_repository.dart';

final _repo = AdminRepository();

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});
  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, int> _stats = {};
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _loadStats();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    final s = await _repo.platformStats();
    if (mounted) setState(() { _stats = s; _statsLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (!AppAdmin.isAdminUser(user)) {
      return const Scaffold(backgroundColor: SportSphereColors.background,
          body: Center(child: Text('Access denied',
              style: TextStyle(color: SportSphereColors.muted))));
    }
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: SportSphereColors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFD700), size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Admin Dashboard',
                style: TextStyle(color: SportSphereColors.white, fontSize: 20, fontWeight: FontWeight.w900))),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: SportSphereColors.muted),
              onPressed: _loadStats,
            ),
          ]),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: SportSphereColors.white,
          unselectedLabelColor: SportSphereColors.muted,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: '📊 Overview'),
            Tab(text: '👥 Users'),
            Tab(text: '🏆 Competitions'),
            Tab(text: '⚽ Matches'),
            Tab(text: '📝 Content'),
            Tab(text: '📰 News'),
          ],
        ),
        Expanded(child: TabBarView(controller: _tabs, children: [
          _OverviewTab(stats: _stats, loading: _statsLoading, onRefresh: _loadStats, tabCtrl: _tabs),
          const _UsersTab(),
          const _CompetitionsTab(),
          _MatchesTab(onRefresh: _loadStats, parentRef: ref),
          const _ContentTab(),
          _NewsTab(onRefresh: _loadStats),
        ])),
      ])),
    );
  }
}

// ══ OVERVIEW ═══════════════════════════════════════════════════════════════════
class _OverviewTab extends ConsumerWidget {
  final Map<String,int> stats; final bool loading;
  final VoidCallback onRefresh; final TabController tabCtrl;
  const _OverviewTab({required this.stats,required this.loading,required this.onRefresh,required this.tabCtrl});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(onRefresh:()async=>onRefresh(),color:SportSphereColors.electricBlue,
      child:ListView(padding:const EdgeInsets.all(16),children:[
        _Label('PLATFORM STATISTICS'), const SizedBox(height:10),
        if(loading) const Center(child:CircularProgressIndicator(color:SportSphereColors.electricBlue,strokeWidth:2))
        else GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,
          mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.55,children:[
            _StatCard('Total Users','${stats['users']??0}',Icons.people_rounded,SportSphereColors.electricBlue),
            _StatCard('Posts','${stats['posts']??0}',Icons.article_rounded,SportSphereColors.sportGreen),
            _StatCard('Matches','${stats['matches']??0}',Icons.sports_soccer_rounded,const Color(0xFFE31B23)),
            _StatCard('Teams','${stats['teams']??0}',Icons.groups_rounded,const Color(0xFF9B6DFF)),
            _StatCard('Players','${stats['players']??0}',Icons.person_rounded,SportSphereColors.sportOrange),
            _StatCard('Coaches','${stats['coaches']??0}',Icons.sports_rounded,const Color(0xFF00C896)),
            _StatCard('Competitions','${stats['competitions']??0}',Icons.emoji_events_rounded,const Color(0xFFFFD700)),
            _StatCard('News','${stats['news']??0}',Icons.newspaper_rounded,SportSphereColors.brightBlue),
        ]),
        const SizedBox(height:24), _Label('QUICK ACTIONS'), const SizedBox(height:10),
        _ActionCard(Icons.sensors_rounded,const Color(0xFFE31B23),'Live Match Control','Update scores, status and minutes live',()=>openAdminLiveControl(context,ref)),
        _ActionCard(Icons.emoji_events_rounded,const Color(0xFFFFD700),'Create Competition','Add new league or cup',()=>_showCreateCompetition(context)),
        _ActionCard(Icons.groups_rounded,const Color(0xFF9B6DFF),'Create Team','Add a new club or national team',()=>_showCreateTeam(context,null)),
        _ActionCard(Icons.add_circle_rounded,SportSphereColors.sportGreen,'Schedule Fixture','Add a new match to the calendar',()=>_showCreateMatch(context)),
        _ActionCard(Icons.newspaper_rounded,SportSphereColors.sportOrange,'Post News Article','Publish breaking news or updates',()=>_showNewsCompose(context)),
        _ActionCard(Icons.person_add_rounded,SportSphereColors.electricBlue,'Create User','Add a new user account',()=>_showCreateUser(context)),
    ]));
  }
}

// ══ USERS ══════════════════════════════════════════════════════════════════════
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override State<_UsersTab> createState() => _UsersTabState();
}
class _UsersTabState extends State<_UsersTab> {
  final _search = TextEditingController();
  List<Map<String,dynamic>> _users=[]; bool _loading=true;
  @override void initState(){super.initState();_load('');}
  Future<void> _load(String q) async {
    setState(()=>_loading=true);
    final rows=await _repo.listUsers(q:q);
    if(mounted) setState((){_users=rows;_loading=false;});
  }
  @override
  Widget build(BuildContext context) {
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,12,16,8),child:Row(children:[
        Expanded(child:_SearchField(controller:_search,hint:'Search users...',onSearch:_load)),
        const SizedBox(width:8),
        FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue),
          icon:const Icon(Icons.add,size:16),label:const Text('New'),
          onPressed:()=>_showCreateUser(context).then((_)=>_load(''))),
      ])),
      Expanded(child:_loading?const _Loader():_users.isEmpty?const _Empty('No users found'):
        ListView.separated(padding:const EdgeInsets.fromLTRB(16,0,16,40),itemCount:_users.length,
          separatorBuilder:(_,__)=>const _Div(),
          itemBuilder:(_,i){
            final u=_users[i];
            final name='${u['first_name']??''} ${u['last_name']??''}'.trim();
            final handle=u['handle']??''; final role=u['role']??'fan'; final verified=u['is_verified']==true;
            return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:4),
              leading:CircleAvatar(backgroundColor:SportSphereColors.electricBlue.withValues(alpha:0.15),
                child:Text(name.isNotEmpty?name[0].toUpperCase():'?',
                    style:const TextStyle(color:SportSphereColors.electricBlue,fontWeight:FontWeight.w800))),
              title:Row(children:[
                Flexible(child:Text(name.isNotEmpty?name:handle,
                    style:const TextStyle(color:SportSphereColors.white,fontWeight:FontWeight.w700,fontSize:14))),
                if(verified)...[const SizedBox(width:4),const Icon(Icons.verified_rounded,color:Color(0xFFFFD700),size:14)],
              ]),
              subtitle:Text('@$handle  ·  $role',style:const TextStyle(color:SportSphereColors.muted,fontSize:12)),
              trailing:PopupMenuButton<String>(
                color:SportSphereColors.surface,
                icon:const Icon(Icons.more_vert_rounded,color:SportSphereColors.muted),
                onSelected:(v) async {
                  final uid=u['id'].toString();
                  if(v=='verify'){await _repo.verifyUser(uid,!verified);_load(_search.text.trim());}
                  else if(v=='role') _showChangeRole(context,uid,role);
                  else if(v=='delete') _confirmDelete(context,uid,name.isNotEmpty?name:handle);
                },
                itemBuilder:(_)=>[
                  PopupMenuItem(value:'verify',child:Text(verified?'Remove Verified':'Verify',style:const TextStyle(color:SportSphereColors.white))),
                  const PopupMenuItem(value:'role',child:Text('Change Role',style:TextStyle(color:SportSphereColors.white))),
                  const PopupMenuItem(value:'delete',child:Text('Delete',style:TextStyle(color:SportSphereColors.danger))),
                ],
              ),
            );
          },
        ),
      ),
    ]);
  }
  void _showChangeRole(BuildContext ctx,String uid,String cur){
    final roles=['fan','player','coach','team','journalist','analyst','creator','scout','agent','moderator','official','admin'];
    String sel=roles.contains(cur)?cur:'fan';
    showDialog<void>(context:ctx,builder:(_)=>StatefulBuilder(builder:(c,setL)=>AlertDialog(
      backgroundColor:SportSphereColors.surface,
      title:const Text('Change Role',style:TextStyle(color:SportSphereColors.white)),
      content:DropdownButton<String>(value:sel,dropdownColor:SportSphereColors.surface,isExpanded:true,
        style:const TextStyle(color:SportSphereColors.white),
        items:roles.map((r)=>DropdownMenuItem(value:r,child:Text(r[0].toUpperCase()+r.substring(1)))).toList(),
        onChanged:(v)=>setL(()=>sel=v??sel)),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),
        TextButton(onPressed:() async {await _repo.updateUserRole(uid,sel);if(c.mounted)Navigator.pop(c);_load(_search.text.trim());},child:const Text('Save')),
      ],
    )));
  }
  void _confirmDelete(BuildContext ctx,String uid,String name){
    showDialog<void>(context:ctx,builder:(_)=>AlertDialog(
      backgroundColor:SportSphereColors.surface,
      title:const Text('Delete User?',style:TextStyle(color:SportSphereColors.white)),
      content:Text('Permanently delete $name?',style:const TextStyle(color:SportSphereColors.muted)),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        TextButton(onPressed:() async {Navigator.pop(ctx);await _repo.deleteUser(uid);_load(_search.text.trim());},
            child:const Text('Delete',style:TextStyle(color:SportSphereColors.danger))),
      ],
    ));
  }
}

// ══ COMPETITIONS ═══════════════════════════════════════════════════════════════
class _CompetitionsTab extends StatefulWidget {
  const _CompetitionsTab();
  @override State<_CompetitionsTab> createState()=>_CompetitionsTabState();
}
class _CompetitionsTabState extends State<_CompetitionsTab> with SingleTickerProviderStateMixin {
  late TabController _sub;
  List<Map<String,dynamic>> _comps=[],_teams=[],_players=[],_coaches=[];
  bool _loading=true;
  @override void initState(){super.initState();_sub=TabController(length:4,vsync:this);_load();}
  @override void dispose(){_sub.dispose();super.dispose();}
  Future<void> _load() async {
    setState(()=>_loading=true);
    final r=await Future.wait([_repo.listCompetitions(),_repo.listTeams(),_repo.listPlayers(),_repo.listCoaches()]);
    if(mounted) setState((){_comps=r[0];_teams=r[1];_players=r[2];_coaches=r[3];_loading=false;});
  }
  @override
  Widget build(BuildContext context) {
    return Column(children:[
      TabBar(controller:_sub,labelColor:SportSphereColors.white,unselectedLabelColor:SportSphereColors.muted,
        indicatorColor:const Color(0xFFFFD700),labelStyle:const TextStyle(fontSize:11,fontWeight:FontWeight.w700),
        tabs:const[Tab(text:'Competitions'),Tab(text:'Teams'),Tab(text:'Players'),Tab(text:'Coaches')]),
      Expanded(child:_loading?const _Loader():TabBarView(controller:_sub,children:[
        _EList(items:_comps,icon:Icons.emoji_events_rounded,color:const Color(0xFFFFD700),
          addLabel:'Add Competition',onAdd:()=>_showCreateCompetition(context).then((_)=>_load()),
          sub:(c)=>'${c['country']??''}  ·  ${c['type']??''}  ·  ${c['season']??''}',
          onDelete:(id) async {await _repo.deleteCompetition(id);_load();}),
        _EList(items:_teams,icon:Icons.groups_rounded,color:const Color(0xFF9B6DFF),
          addLabel:'Add Team',onAdd:()=>_showCreateTeam(context,_comps).then((_)=>_load()),
          sub:(t)=>'${t['country']??''}  ·  ${t['city']??''}',
          onDelete:(id) async {await _repo.deleteTeam(id);_load();}),
        _EList(items:_players,icon:Icons.person_rounded,color:SportSphereColors.sportOrange,
          addLabel:'Add Player',onAdd:()=>_showCreatePlayer(context,_teams).then((_)=>_load()),
          sub:(p)=>'${p['position']??''}  ·  #${p['shirtNumber']??'-'}',
          onDelete:(id) async {await _repo.deletePlayer(id);_load();}),
        _EList(items:_coaches,icon:Icons.sports_rounded,color:const Color(0xFF00C896),
          addLabel:'Add Coach',onAdd:()=>_showCreateCoach(context,_teams).then((_)=>_load()),
          sub:(c)=>'${c['role']??''}  ·  ${c['nationality']??''}',
          onDelete:(id) async {await _repo.deleteCoach(id);_load();}),
      ])),
    ]);
  }
}
class _EList extends StatelessWidget {
  final List<Map<String,dynamic>> items; final IconData icon; final Color color;
  final String addLabel; final VoidCallback onAdd;
  final String Function(Map<String,dynamic>) sub;
  final Future<void> Function(String) onDelete;
  const _EList({required this.items,required this.icon,required this.color,
      required this.addLabel,required this.onAdd,required this.sub,required this.onDelete});
  @override Widget build(BuildContext context)=>Column(children:[
    _AddBar(addLabel,onAdd),
    Expanded(child:items.isEmpty?const _Empty('Nothing here yet'):ListView.separated(
      padding:const EdgeInsets.fromLTRB(16,0,16,40),itemCount:items.length,separatorBuilder:(_,__)=>const _Div(),
      itemBuilder:(_,i){final e=items[i];return ListTile(
        contentPadding:const EdgeInsets.symmetric(vertical:4),
        leading:Container(width:36,height:36,decoration:BoxDecoration(shape:BoxShape.circle,color:color.withValues(alpha:0.12)),child:Icon(icon,color:color,size:18)),
        title:Text(e['name']??'',style:const TextStyle(color:SportSphereColors.white,fontWeight:FontWeight.w700,fontSize:13)),
        subtitle:Text(sub(e),style:const TextStyle(color:SportSphereColors.muted,fontSize:11)),
        trailing:IconButton(icon:const Icon(Icons.delete_outline_rounded,color:SportSphereColors.danger,size:20),onPressed:()=>onDelete(e['id'].toString())),
      );},
    )),
  ]);
}

// ══ MATCHES ════════════════════════════════════════════════════════════════════
class _MatchesTab extends ConsumerStatefulWidget {
  final VoidCallback onRefresh; final WidgetRef parentRef;
  const _MatchesTab({required this.onRefresh,required this.parentRef});
  @override ConsumerState<_MatchesTab> createState()=>_MatchesTabState();
}
class _MatchesTabState extends ConsumerState<_MatchesTab> {
  List<Map<String,dynamic>> _matches=[]; bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {setState(()=>_loading=true);final r=await _repo.listMatches();if(mounted)setState((){_matches=r;_loading=false;});}
  @override Widget build(BuildContext context){
    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,12,16,8),child:Row(children:[
        Expanded(child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xFFE31B23)),
          icon:const Icon(Icons.sensors_rounded,size:16),label:const Text('Live Control'),
          onPressed:()=>openAdminLiveControl(context,ref).then((_)=>_load()))),
        const SizedBox(width:8),
        Expanded(child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:SportSphereColors.sportGreen),
          icon:const Icon(Icons.add,size:16),label:const Text('Add Fixture'),
          onPressed:()=>_showCreateMatch(context).then((_)=>_load()))),
      ])),
      Expanded(child:_loading?const _Loader():_matches.isEmpty?const _Empty('No matches yet'):
        RefreshIndicator(onRefresh:_load,color:SportSphereColors.electricBlue,child:ListView.separated(
          padding:const EdgeInsets.fromLTRB(16,0,16,40),itemCount:_matches.length,separatorBuilder:(_,__)=>const _Div(),
          itemBuilder:(_,i){final m=_matches[i];final st=m['status']??'upcoming';final isLive=st=='live';
            return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:4),
              leading:Container(width:36,height:36,decoration:BoxDecoration(shape:BoxShape.circle,
                  color:(isLive?SportSphereColors.danger:SportSphereColors.muted).withValues(alpha:0.12)),
                  child:Icon(Icons.sports_soccer_rounded,color:isLive?SportSphereColors.danger:SportSphereColors.muted,size:18)),
              title:Text('${m['homeTeam']}  vs  ${m['awayTeam']}',style:const TextStyle(color:SportSphereColors.white,fontWeight:FontWeight.w700,fontSize:13)),
              subtitle:Text('$st  ·  ${m['homeScore']??0}-${m['awayScore']??0}  ·  ${m['league']??''}',style:const TextStyle(color:SportSphereColors.muted,fontSize:11)),
              trailing:PopupMenuButton<String>(color:SportSphereColors.surface,icon:const Icon(Icons.more_vert_rounded,color:SportSphereColors.muted),
                onSelected:(v) async {
                  if(v=='edit') _showEditMatch(context,m);
                  if(v=='delete'){await _repo.deleteMatch(m['id'].toString());_load();}
                },
                itemBuilder:(_)=>[
                  const PopupMenuItem(value:'edit',child:Text('Edit Result',style:TextStyle(color:SportSphereColors.white))),
                  const PopupMenuItem(value:'delete',child:Text('Delete',style:TextStyle(color:SportSphereColors.danger))),
                ],
              ),
            );
          },
        )),
      ),
    ]);
  }
  void _showEditMatch(BuildContext ctx,Map<String,dynamic> m){
    final hCtrl=TextEditingController(text:'${m['homeScore']??0}');
    final aCtrl=TextEditingController(text:'${m['awayScore']??0}');
    final minCtrl=TextEditingController(text:'${m['minute']??0}');
    String status=m['status']??'upcoming';
    final statuses=['upcoming','live','ht','finished','postponed','cancelled'];
    showDialog<void>(context:ctx,builder:(_)=>StatefulBuilder(builder:(c,setL)=>AlertDialog(
      backgroundColor:SportSphereColors.surface,
      title:Text('${m['homeTeam']} vs ${m['awayTeam']}',style:const TextStyle(color:SportSphereColors.white,fontSize:14)),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(value:statuses.contains(status)?status:'upcoming',dropdownColor:SportSphereColors.surface,
          decoration:const InputDecoration(labelText:'Status',labelStyle:TextStyle(color:SportSphereColors.muted)),
          items:statuses.map((s)=>DropdownMenuItem(value:s,child:Text(s,style:const TextStyle(color:SportSphereColors.white)))).toList(),
          onChanged:(v)=>setL(()=>status=v??status)),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child:_AdminField(controller:hCtrl,label:m['homeTeam']??'Home',keyboardType:TextInputType.number)),
          const Padding(padding:EdgeInsets.all(8),child:Text(':',style:TextStyle(color:SportSphereColors.white,fontSize:20))),
          Expanded(child:_AdminField(controller:aCtrl,label:m['awayTeam']??'Away',keyboardType:TextInputType.number)),
        ]),
        _AdminField(controller:minCtrl,label:'Minute',keyboardType:TextInputType.number),
        Wrap(spacing:8,children:[
          ActionChip(label:const Text('+1 Home'),onPressed:()=>setL(()=>hCtrl.text='${(int.tryParse(hCtrl.text)??0)+1}')),
          ActionChip(label:const Text('+1 Away'),onPressed:()=>setL(()=>aCtrl.text='${(int.tryParse(aCtrl.text)??0)+1}')),
          ActionChip(label:const Text('LIVE'),onPressed:()=>setL(()=>status='live')),
          ActionChip(label:const Text('HT'),onPressed:()=>setL(()=>status='ht')),
          ActionChip(label:const Text('FT'),onPressed:()=>setL(()=>status='finished')),
        ]),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),
        TextButton(onPressed:() async {await _repo.updateMatch(id:m['id'].toString(),homeScore:int.tryParse(hCtrl.text),awayScore:int.tryParse(aCtrl.text),status:status,minute:int.tryParse(minCtrl.text));if(c.mounted)Navigator.pop(c);_load();},child:const Text('Save')),
      ],
    )));
  }
}

// ══ CONTENT ════════════════════════════════════════════════════════════════════
class _ContentTab extends StatefulWidget {
  const _ContentTab();
  @override State<_ContentTab> createState()=>_ContentTabState();
}
class _ContentTabState extends State<_ContentTab> {
  List<Map<String,dynamic>> _posts=[]; bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {setState(()=>_loading=true);final r=await _repo.listPosts();if(mounted)setState((){_posts=r;_loading=false;});}
  @override Widget build(BuildContext ctx)=>Column(children:[
    _AddBar('Create Post',()=>_showCreatePost(ctx).then((_)=>_load())),
    Expanded(child:_loading?const _Loader():_posts.isEmpty?const _Empty('No posts yet'):
      RefreshIndicator(onRefresh:_load,color:SportSphereColors.electricBlue,child:ListView.separated(
        padding:const EdgeInsets.fromLTRB(16,0,16,40),itemCount:_posts.length,separatorBuilder:(_,__)=>const _Div(),
        itemBuilder:(_,i){final p=_posts[i];final content=p['content']as String??'';final type=p['postType']??'text';
          return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:4),
            leading:Container(width:36,height:36,decoration:BoxDecoration(shape:BoxShape.circle,color:SportSphereColors.sportGreen.withValues(alpha:0.12)),
                child:Icon(type=='poll'?Icons.poll_rounded:type=='prediction'?Icons.insights_rounded:Icons.article_rounded,color:SportSphereColors.sportGreen,size:18)),
            title:Text(content.length>80?'${content.substring(0,80)}...':content,style:const TextStyle(color:SportSphereColors.white,fontSize:13),maxLines:2),
            subtitle:Text('$type  ·  ♥ ${p['likeCount']??0}  ·  💬 ${p['commentCount']??0}',style:const TextStyle(color:SportSphereColors.muted,fontSize:11)),
            trailing:IconButton(icon:const Icon(Icons.delete_outline_rounded,color:SportSphereColors.danger,size:20),
                onPressed:() async {await _repo.deletePostAdmin(p['id'].toString());_load();}),
          );},
      ))),
  ]);
}

// ══ NEWS ═══════════════════════════════════════════════════════════════════════
class _NewsTab extends StatefulWidget {
  final VoidCallback onRefresh; const _NewsTab({required this.onRefresh});
  @override State<_NewsTab> createState()=>_NewsTabState();
}
class _NewsTabState extends State<_NewsTab> {
  List<Map<String,dynamic>> _articles=[]; bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {setState(()=>_loading=true);final r=await _repo.listNews();if(mounted)setState((){_articles=r;_loading=false;widget.onRefresh();});}
  @override Widget build(BuildContext ctx)=>Column(children:[
    _AddBar('New Article',()=>_showNewsCompose(ctx).then((_)=>_load())),
    Expanded(child:_loading?const _Loader():_articles.isEmpty?const _Empty('No articles yet'):
      RefreshIndicator(onRefresh:_load,color:SportSphereColors.electricBlue,child:ListView.separated(
        padding:const EdgeInsets.fromLTRB(16,0,16,40),itemCount:_articles.length,separatorBuilder:(_,__)=>const _Div(),
        itemBuilder:(_,i){final a=_articles[i];final brk=a['is_breaking']==true||a['category']=='breaking';
          return ListTile(contentPadding:const EdgeInsets.symmetric(vertical:4),
            leading:Container(width:36,height:36,decoration:BoxDecoration(shape:BoxShape.circle,
                color:(brk?SportSphereColors.danger:SportSphereColors.sportOrange).withValues(alpha:0.12)),
                child:Icon(brk?Icons.warning_rounded:Icons.newspaper_rounded,color:brk?SportSphereColors.danger:SportSphereColors.sportOrange,size:18)),
            title:Text(a['title']??'',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:SportSphereColors.white,fontSize:13,fontWeight:FontWeight.w600)),
            subtitle:Text('${a['category']??'updates'}  ·  ${a['source']??'SportSphere'}',style:const TextStyle(color:SportSphereColors.muted,fontSize:11)),
            trailing:IconButton(icon:const Icon(Icons.delete_outline_rounded,color:SportSphereColors.danger,size:20),
                onPressed:() async {await _repo.deleteNews(a['id'].toString());_load();}),
          );},
      ))),
  ]);
}

// ══ SHARED DIALOGS ══════════════════════════════════════════════════════════════

// ══ ADMIN FORMS ════════════════════════════════════════════════════════════════

// ── Image upload helper ────────────────────────────────────────────────────────
Future<String?> _pickAndUpload(BuildContext ctx, {String folder='admin'}) async {
  final picker = ImagePicker();
  final xf = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
  if (xf == null) return null;
  try {
    return await SocialRepository().uploadPickedFile(bucket:'media', folder:folder, file:xf);
  } catch (e) {
    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('Upload failed: $e')));
    return null;
  }
}

// ── Create User ────────────────────────────────────────────────────────────────
Future<void> _showCreateUser(BuildContext ctx) {
  return showDialog<void>(context:ctx, builder:(_)=>AlertDialog(
    backgroundColor:SportSphereColors.surface,
    title:const Text('Create User', style:TextStyle(color:SportSphereColors.white)),
    content:const Text(
      'To create users:\n\nSupabase Dashboard → Authentication → Users → Add User\n\nRequires service role key (not available in app for security).',
      style:TextStyle(color:SportSphereColors.muted, fontSize:13)),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx), child:const Text('OK'))],
  ));
}

// ── Create Competition ─────────────────────────────────────────────────────────
Future<void> _showCreateCompetition(BuildContext ctx) {
  final name=TextEditingController(), country=TextEditingController(text:'Tanzania'),
        season=TextEditingController(text:'2026/27'), description=TextEditingController(),
        website=TextEditingController();
  String type='league';
  String? logoUrl;
  bool uploading=false;

  return showModalBottomSheet<void>(context:ctx, isScrollControlled:true,
    backgroundColor:SportSphereColors.surface,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(_)=>StatefulBuilder(builder:(c,setL)=>Padding(
      padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(c).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Create Competition', style:TextStyle(color:SportSphereColors.white, fontSize:18, fontWeight:FontWeight.w800)),
        const SizedBox(height:16),
        _AdminField(controller:name, label:'Competition Name *'),
        _AdminField(controller:country, label:'Country'),
        _AdminField(controller:season, label:'Season (e.g. 2026/27)'),
        _AdminField(controller:description, label:'Description', maxLines:3),
        _AdminField(controller:website, label:'Website (optional)', keyboardType:TextInputType.url),
        DropdownButtonFormField<String>(value:type, dropdownColor:SportSphereColors.surface,
          decoration:const InputDecoration(labelText:'Type', labelStyle:TextStyle(color:SportSphereColors.muted)),
          items:['league','cup','friendly','international'].map((t)=>DropdownMenuItem(value:t,
              child:Text(t[0].toUpperCase()+t.substring(1), style:const TextStyle(color:SportSphereColors.white)))).toList(),
          onChanged:(v)=>setL(()=>type=v??type)),
        const SizedBox(height:12),
        _UploadButton(url:logoUrl, uploading:uploading, label:'Upload Logo',
          onTap:() async {
            setL(()=>uploading=true);
            final url=await _pickAndUpload(c, folder:'logos');
            setL((){logoUrl=url;uploading=false;});
          }),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue, padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:() async {
            if(name.text.trim().isEmpty) return;
            try {
              await _repo.createCompetition(name:name.text.trim(), country:country.text.trim(),
                season:season.text.trim().isEmpty?null:season.text.trim(), type:type);
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('$e'))); }
          },
          child:const Text('Create Competition', style:TextStyle(fontWeight:FontWeight.w800)))),
      ])))));
}

// ── Create Team ────────────────────────────────────────────────────────────────
Future<void> _showCreateTeam(BuildContext ctx, List<Map<String,dynamic>>? preloaded) async {
  final comps = preloaded ?? await _repo.listCompetitions();
  if (!ctx.mounted) return;
  final name=TextEditingController(), country=TextEditingController(text:'Tanzania'),
        city=TextEditingController(), venue=TextEditingController(),
        founded=TextEditingController(), shortName=TextEditingController(),
        description=TextEditingController();
  String? leagueId, logoUrl;
  bool uploading=false;

  showModalBottomSheet<void>(context:ctx, isScrollControlled:true,
    backgroundColor:SportSphereColors.surface,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(_)=>StatefulBuilder(builder:(c,setL)=>Padding(
      padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(c).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Create Team', style:TextStyle(color:SportSphereColors.white, fontSize:18, fontWeight:FontWeight.w800)),
        const SizedBox(height:16),
        _AdminField(controller:name, label:'Full Club Name *'),
        _AdminField(controller:shortName, label:'Short Name (e.g. SIM, YAN)'),
        _AdminField(controller:country, label:'Country'),
        _AdminField(controller:city, label:'City'),
        _AdminField(controller:venue, label:'Stadium / Venue'),
        _AdminField(controller:founded, label:'Founded Year', keyboardType:TextInputType.number),
        _AdminField(controller:description, label:'Club Description', maxLines:3),
        if(comps.isNotEmpty) DropdownButtonFormField<String?>(value:leagueId,
          dropdownColor:SportSphereColors.surface,
          decoration:const InputDecoration(labelText:'Competition (optional)', labelStyle:TextStyle(color:SportSphereColors.muted)),
          items:[const DropdownMenuItem(value:null,child:Text('None',style:TextStyle(color:SportSphereColors.muted))),
            ...comps.map((comp)=>DropdownMenuItem(value:comp['id'].toString(),child:Text(comp['name'].toString(),style:const TextStyle(color:SportSphereColors.white))))],
          onChanged:(v)=>setL(()=>leagueId=v)),
        const SizedBox(height:12),
        _UploadButton(url:logoUrl, uploading:uploading, label:'Upload Team Logo / Badge',
          onTap:() async {
            setL(()=>uploading=true);
            final url=await _pickAndUpload(c, folder:'logos');
            setL((){logoUrl=url;uploading=false;});
          }),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue, padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:() async {
            if(name.text.trim().isEmpty) return;
            try {
              await _repo.createTeam(name:name.text.trim(), country:country.text.trim(),
                city:city.text.trim().isEmpty?null:city.text.trim(),
                leagueId:leagueId,
                venue:venue.text.trim().isEmpty?null:venue.text.trim(),
                foundedYear:int.tryParse(founded.text.trim()));
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('$e'))); }
          },
          child:const Text('Create Team', style:TextStyle(fontWeight:FontWeight.w800)))),
      ])))));
}

// ── Add Player ─────────────────────────────────────────────────────────────────
Future<void> _showCreatePlayer(BuildContext ctx, List<Map<String,dynamic>> teams) {
  final name=TextEditingController(), nat=TextEditingController(),
        shirt=TextEditingController(), height=TextEditingController(),
        weight=TextEditingController(), firstName=TextEditingController(),
        lastName=TextEditingController();
  String position='Forward';
  String? teamId, photoUrl, dob;
  bool uploading=false;

  return showModalBottomSheet<void>(context:ctx, isScrollControlled:true,
    backgroundColor:SportSphereColors.surface,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(_)=>StatefulBuilder(builder:(c,setL)=>Padding(
      padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(c).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Add Player', style:TextStyle(color:SportSphereColors.white, fontSize:18, fontWeight:FontWeight.w800)),
        const SizedBox(height:16),
        Row(children:[
          Expanded(child:_AdminField(controller:firstName, label:'First Name *')),
          const SizedBox(width:10),
          Expanded(child:_AdminField(controller:lastName, label:'Last Name *')),
        ]),
        _AdminField(controller:name, label:'Full Name (display)'),
        _AdminField(controller:nat, label:'Nationality'),
        Row(children:[
          Expanded(child:_AdminField(controller:shirt, label:'Shirt #', keyboardType:TextInputType.number)),
          const SizedBox(width:10),
          Expanded(child:DropdownButtonFormField<String>(value:position,
            dropdownColor:SportSphereColors.surface,
            decoration:const InputDecoration(labelText:'Position', labelStyle:TextStyle(color:SportSphereColors.muted)),
            items:['Goalkeeper','Defender','Midfielder','Forward','Winger','Striker']
                .map((p)=>DropdownMenuItem(value:p,child:Text(p,style:const TextStyle(color:SportSphereColors.white)))).toList(),
            onChanged:(v)=>setL(()=>position=v??position))),
        ]),
        Row(children:[
          Expanded(child:_AdminField(controller:height, label:'Height (cm)', keyboardType:TextInputType.number)),
          const SizedBox(width:10),
          Expanded(child:_AdminField(controller:weight, label:'Weight (kg)', keyboardType:TextInputType.number)),
        ]),
        ListTile(contentPadding:EdgeInsets.zero,
          title:Text(dob==null?'Date of Birth (optional)':'DOB: $dob',
              style:TextStyle(color:dob==null?SportSphereColors.muted:SportSphereColors.white, fontSize:13)),
          trailing:const Icon(Icons.calendar_today_rounded, color:SportSphereColors.electricBlue, size:18),
          onTap:() async {
            final d=await showDatePicker(context:c,
              initialDate:DateTime(1998,1,1), firstDate:DateTime(1950), lastDate:DateTime.now());
            if(d!=null) setL(()=>dob='${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}');
          }),
        if(teams.isNotEmpty) DropdownButtonFormField<String?>(value:teamId,
          dropdownColor:SportSphereColors.surface,
          decoration:const InputDecoration(labelText:'Team', labelStyle:TextStyle(color:SportSphereColors.muted)),
          items:[const DropdownMenuItem(value:null,child:Text('None',style:TextStyle(color:SportSphereColors.muted))),
            ...teams.map((t)=>DropdownMenuItem(value:t['id'].toString(),child:Text(t['name'].toString(),style:const TextStyle(color:SportSphereColors.white))))],
          onChanged:(v)=>setL(()=>teamId=v)),
        const SizedBox(height:12),
        _UploadButton(url:photoUrl, uploading:uploading, label:'Upload Player Photo',
          onTap:() async {
            setL(()=>uploading=true);
            final url=await _pickAndUpload(c, folder:'players');
            setL((){photoUrl=url;uploading=false;});
          }),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue, padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:() async {
            final fullName = '${firstName.text.trim()} ${lastName.text.trim()}'.trim();
            if(fullName.isEmpty && name.text.trim().isEmpty) return;
            try {
              await _repo.createPlayer(
                name:name.text.trim().isNotEmpty?name.text.trim():fullName,
                position:position, teamId:teamId,
                nationality:nat.text.trim().isEmpty?null:nat.text.trim(),
                shirtNumber:int.tryParse(shirt.text.trim()));
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('$e'))); }
          },
          child:const Text('Add Player', style:TextStyle(fontWeight:FontWeight.w800)))),
      ])))));
}

// ── Add Coach ──────────────────────────────────────────────────────────────────
Future<void> _showCreateCoach(BuildContext ctx, List<Map<String,dynamic>> teams) {
  final name=TextEditingController(), nat=TextEditingController(),
        firstName=TextEditingController(), lastName=TextEditingController();
  String coachRole='head_coach';
  String? teamId, photoUrl, dob;
  bool uploading=false;

  return showModalBottomSheet<void>(context:ctx, isScrollControlled:true,
    backgroundColor:SportSphereColors.surface,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(_)=>StatefulBuilder(builder:(c,setL)=>Padding(
      padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(c).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Add Coach / Staff', style:TextStyle(color:SportSphereColors.white, fontSize:18, fontWeight:FontWeight.w800)),
        const SizedBox(height:16),
        Row(children:[
          Expanded(child:_AdminField(controller:firstName, label:'First Name *')),
          const SizedBox(width:10),
          Expanded(child:_AdminField(controller:lastName, label:'Last Name *')),
        ]),
        _AdminField(controller:name, label:'Display Name'),
        _AdminField(controller:nat, label:'Nationality'),
        DropdownButtonFormField<String>(value:coachRole, dropdownColor:SportSphereColors.surface,
          decoration:const InputDecoration(labelText:'Role', labelStyle:TextStyle(color:SportSphereColors.muted)),
          items:['head_coach','assistant_coach','goalkeeper_coach','fitness_coach',
                 'analyst','scout','physio','technical_director']
              .map((r)=>DropdownMenuItem(value:r, child:Text(r.replaceAll('_',' ').split(' ')
                  .map((w)=>w[0].toUpperCase()+w.substring(1)).join(' '),
                  style:const TextStyle(color:SportSphereColors.white)))).toList(),
          onChanged:(v)=>setL(()=>coachRole=v??coachRole)),
        ListTile(contentPadding:EdgeInsets.zero,
          title:Text(dob==null?'Date of Birth (optional)':'DOB: $dob',
              style:TextStyle(color:dob==null?SportSphereColors.muted:SportSphereColors.white, fontSize:13)),
          trailing:const Icon(Icons.calendar_today_rounded, color:SportSphereColors.electricBlue, size:18),
          onTap:() async {
            final d=await showDatePicker(context:c,
              initialDate:DateTime(1975,1,1), firstDate:DateTime(1940), lastDate:DateTime.now());
            if(d!=null) setL(()=>dob='${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}');
          }),
        if(teams.isNotEmpty) DropdownButtonFormField<String?>(value:teamId,
          dropdownColor:SportSphereColors.surface,
          decoration:const InputDecoration(labelText:'Team', labelStyle:TextStyle(color:SportSphereColors.muted)),
          items:[const DropdownMenuItem(value:null,child:Text('None',style:TextStyle(color:SportSphereColors.muted))),
            ...teams.map((t)=>DropdownMenuItem(value:t['id'].toString(),child:Text(t['name'].toString(),style:const TextStyle(color:SportSphereColors.white))))],
          onChanged:(v)=>setL(()=>teamId=v)),
        const SizedBox(height:12),
        _UploadButton(url:photoUrl, uploading:uploading, label:'Upload Photo',
          onTap:() async {
            setL(()=>uploading=true);
            final url=await _pickAndUpload(c, folder:'coaches');
            setL((){photoUrl=url;uploading=false;});
          }),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue, padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:() async {
            final fullName = '${firstName.text.trim()} ${lastName.text.trim()}'.trim();
            if(fullName.isEmpty && name.text.trim().isEmpty) return;
            try {
              await _repo.createCoach(
                name:name.text.trim().isNotEmpty?name.text.trim():fullName,
                role:coachRole, teamId:teamId,
                nationality:nat.text.trim().isEmpty?null:nat.text.trim());
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('$e'))); }
          },
          child:const Text('Add Coach', style:TextStyle(fontWeight:FontWeight.w800)))),
      ])))));
}

// ── Schedule Match ─────────────────────────────────────────────────────────────
Future<void> _showCreateMatch(BuildContext ctx) async {
  final teams = await _repo.listTeams();
  if (!ctx.mounted) return;

  final leagueCtrl=TextEditingController(text:'Tanzania Premier League'),
        venueCtrl=TextEditingController(), seasonCtrl=TextEditingController(text:'2026/27'),
        refCtrl=TextEditingController(), roundCtrl=TextEditingController();
  DateTime kickoff=DateTime.now().add(const Duration(days:1));
  Map<String,dynamic>? homeTeam, awayTeam;

  showModalBottomSheet<void>(context:ctx, isScrollControlled:true,
    backgroundColor:SportSphereColors.surface,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(_)=>StatefulBuilder(builder:(c,setL)=>Padding(
      padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(c).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Schedule Fixture', style:TextStyle(color:SportSphereColors.white, fontSize:18, fontWeight:FontWeight.w800)),
        const SizedBox(height:16),

        // Team selectors
        if(teams.isNotEmpty) ...[
          DropdownButtonFormField<Map<String,dynamic>?>(value:homeTeam,
            dropdownColor:SportSphereColors.surface,
            decoration:const InputDecoration(labelText:'Home Team *', labelStyle:TextStyle(color:SportSphereColors.muted)),
            items:[const DropdownMenuItem(value:null,child:Text('Select home team',style:TextStyle(color:SportSphereColors.muted))),
              ...teams.map((t)=>DropdownMenuItem(value:t,child:Text(t['name'].toString(),style:const TextStyle(color:SportSphereColors.white))))],
            onChanged:(v)=>setL(()=>homeTeam=v)),
          const SizedBox(height:4),
          DropdownButtonFormField<Map<String,dynamic>?>(value:awayTeam,
            dropdownColor:SportSphereColors.surface,
            decoration:const InputDecoration(labelText:'Away Team *', labelStyle:TextStyle(color:SportSphereColors.muted)),
            items:[const DropdownMenuItem(value:null,child:Text('Select away team',style:TextStyle(color:SportSphereColors.muted))),
              ...teams.map((t)=>DropdownMenuItem(value:t,child:Text(t['name'].toString(),style:const TextStyle(color:SportSphereColors.white))))],
            onChanged:(v)=>setL(()=>awayTeam=v)),
        ] else ...[
          const Text('No teams yet — create teams first in Competitions tab.',
              style:TextStyle(color:SportSphereColors.danger, fontSize:13)),
          const SizedBox(height:8),
        ],

        _AdminField(controller:leagueCtrl, label:'Competition / League'),
        _AdminField(controller:venueCtrl, label:'Venue'),
        Row(children:[
          Expanded(child:_AdminField(controller:seasonCtrl, label:'Season')),
          const SizedBox(width:10),
          Expanded(child:_AdminField(controller:roundCtrl, label:'Round / Matchday', keyboardType:TextInputType.number)),
        ]),
        _AdminField(controller:refCtrl, label:'Referee (optional)'),

        // Kickoff date/time
        ListTile(contentPadding:EdgeInsets.zero,
          title:Text('Kickoff: ${kickoff.day}/${kickoff.month}/${kickoff.year}  ${kickoff.hour}:${kickoff.minute.toString().padLeft(2,"0")}',
              style:const TextStyle(color:SportSphereColors.white, fontSize:13)),
          trailing:const Icon(Icons.calendar_today_rounded, color:SportSphereColors.electricBlue),
          onTap:() async {
            final d=await showDatePicker(context:c,
              initialDate:kickoff,
              firstDate:DateTime.now().subtract(const Duration(days:7)),
              lastDate:DateTime.now().add(const Duration(days:365)));
            if(d==null) return;
            final t=await showTimePicker(context:c, initialTime:TimeOfDay.fromDateTime(kickoff));
            if(t==null) return;
            setL(()=>kickoff=DateTime(d.year,d.month,d.day,t.hour,t.minute));
          }),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:SportSphereColors.sportGreen, padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:() async {
            final home = homeTeam?['name']?.toString() ?? '';
            final away = awayTeam?['name']?.toString() ?? '';
            if(home.isEmpty || away.isEmpty) {
              ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Select both teams')));
              return;
            }
            try {
              await _repo.createMatch(
                homeTeam:home, awayTeam:away,
                league:leagueCtrl.text.trim(),
                kickoffAt:kickoff,
                venue:venueCtrl.text.trim().isEmpty?null:venueCtrl.text.trim(),
                homeBadge:homeTeam?['logoUrl']?.toString(),
                awayBadge:awayTeam?['logoUrl']?.toString(),
                season:seasonCtrl.text.trim().isEmpty?null:seasonCtrl.text.trim());
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('$e'))); }
          },
          child:const Text('Schedule Match', style:TextStyle(fontWeight:FontWeight.w800)))),
      ])))));
}

// ── Publish News ───────────────────────────────────────────────────────────────
Future<void> _showNewsCompose(BuildContext ctx) {
  final titleCtrl=TextEditingController(), summaryCtrl=TextEditingController(),
        bodyCtrl=TextEditingController(), sourceCtrl=TextEditingController(text:'SportSphere');
  String category='updates';
  bool isBreaking=false;
  List<String> images=[];
  bool uploading=false;

  return showModalBottomSheet<void>(context:ctx, isScrollControlled:true,
    backgroundColor:SportSphereColors.surface,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(_)=>StatefulBuilder(builder:(c,setL)=>Padding(
      padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(c).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Publish News Article', style:TextStyle(color:SportSphereColors.white, fontSize:18, fontWeight:FontWeight.w800)),
        const SizedBox(height:16),
        _AdminField(controller:titleCtrl, label:'Headline *'),
        _AdminField(controller:summaryCtrl, label:'Summary / Subtitle'),
        _AdminField(controller:bodyCtrl, label:'Full Article Body', maxLines:8),
        _AdminField(controller:sourceCtrl, label:'Source'),
        DropdownButtonFormField<String>(value:category, dropdownColor:SportSphereColors.surface,
          style:const TextStyle(color:SportSphereColors.white),
          decoration:const InputDecoration(labelText:'Category', labelStyle:TextStyle(color:SportSphereColors.muted)),
          items:const[
            DropdownMenuItem(value:'updates', child:Text('Updates')),
            DropdownMenuItem(value:'breaking', child:Text('Breaking News')),
            DropdownMenuItem(value:'rumors', child:Text('Rumors / Transfer')),
            DropdownMenuItem(value:'results', child:Text('Match Results')),
            DropdownMenuItem(value:'preview', child:Text('Match Preview')),
            DropdownMenuItem(value:'interview', child:Text('Interview')),
          ],
          onChanged:(v)=>setL(()=>category=v??category)),
        SwitchListTile(value:isBreaking, onChanged:(v)=>setL(()=>isBreaking=v),
          title:const Text('Breaking News', style:TextStyle(color:SportSphereColors.white)),
          activeColor:SportSphereColors.danger, contentPadding:EdgeInsets.zero),

        // Images
        if(images.isNotEmpty) Wrap(spacing:8, children:images.map((u)=>Chip(
          label:const Text('Image', style:TextStyle(fontSize:11)),
          backgroundColor:SportSphereColors.sportGreen.withValues(alpha:0.15),
          labelStyle:const TextStyle(color:SportSphereColors.sportGreen),
          deleteIcon:const Icon(Icons.close, size:14, color:SportSphereColors.danger),
          onDeleted:()=>setL(()=>images.remove(u)))).toList()),

        OutlinedButton.icon(
          style:OutlinedButton.styleFrom(foregroundColor:SportSphereColors.muted),
          icon: uploading ? const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2))
                         : const Icon(Icons.photo_rounded, size:16),
          label:Text(uploading?'Uploading...':'Add Image / Photo', style:const TextStyle(fontSize:12)),
          onPressed:uploading?null:() async {
            setL(()=>uploading=true);
            final url=await _pickAndUpload(c, folder:'news');
            if(url!=null) setL((){images.add(url);uploading=false;})
            else setL(()=>uploading=false);
          }),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue, padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:() async {
            if(titleCtrl.text.trim().isEmpty) return;
            try {
              await _repo.createNews(
                title:titleCtrl.text.trim(), summary:summaryCtrl.text.trim(),
                body:bodyCtrl.text.trim(), category:category,
                source:sourceCtrl.text.trim(), isBreaking:isBreaking,
                imageUrl:images.isNotEmpty?images.first:null);
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('$e'))); }
          },
          child:const Text('Publish Article', style:TextStyle(fontWeight:FontWeight.w800)))),
      ])))));
}

// ── Create Post ────────────────────────────────────────────────────────────────
Future<void> _showCreatePost(BuildContext ctx) {
  final textCtrl=TextEditingController();
  String postType='text';
  bool uploading=false;
  List<String> mediaUrls=[];

  return showModalBottomSheet<void>(context:ctx, isScrollControlled:true,
    backgroundColor:SportSphereColors.surface,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(_)=>StatefulBuilder(builder:(c,setL)=>Padding(
      padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(c).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Create Post', style:TextStyle(color:SportSphereColors.white, fontSize:18, fontWeight:FontWeight.w800)),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:postType, dropdownColor:SportSphereColors.surface,
          style:const TextStyle(color:SportSphereColors.white),
          decoration:const InputDecoration(labelText:'Post Type', labelStyle:TextStyle(color:SportSphereColors.muted)),
          items:const[
            DropdownMenuItem(value:'text', child:Text('Text / Announcement')),
            DropdownMenuItem(value:'media', child:Text('Photo / Video')),
          ],
          onChanged:(v)=>setL(()=>postType=v??postType)),
        const SizedBox(height:12),
        _AdminField(controller:textCtrl, label:'Content *', maxLines:6),

        // Media preview + upload
        if(mediaUrls.isNotEmpty) Wrap(spacing:8, children:mediaUrls.map((u)=>Chip(
          label:const Text('Media', style:TextStyle(fontSize:11)),
          backgroundColor:SportSphereColors.sportGreen.withValues(alpha:0.15),
          labelStyle:const TextStyle(color:SportSphereColors.sportGreen),
          deleteIcon:const Icon(Icons.close, size:14, color:SportSphereColors.danger),
          onDeleted:()=>setL(()=>mediaUrls.remove(u)))).toList()),

        if(mediaUrls.length < 4) OutlinedButton.icon(
          style:OutlinedButton.styleFrom(foregroundColor:SportSphereColors.muted),
          icon:uploading?const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2))
                       :const Icon(Icons.add_photo_alternate_rounded, size:16),
          label:Text(uploading?'Uploading...':'Add Photo / Video', style:const TextStyle(fontSize:12)),
          onPressed:uploading?null:() async {
            setL(()=>uploading=true);
            final url=await _pickAndUpload(c, folder:'posts');
            if(url!=null) { setL((){mediaUrls.add(url);uploading=false;postType='media';}) }
            else setL(()=>uploading=false);
          }),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue, padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:() async {
            if(textCtrl.text.trim().isEmpty && mediaUrls.isEmpty) return;
            try {
              await SocialRepository().createPost(
                content:textCtrl.text.trim(), postType:postType, mediaUrls:mediaUrls);
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('$e'))); }
          },
          child:const Text('Post', style:TextStyle(fontWeight:FontWeight.w800)))),
      ])))));
}

// ── Upload Button widget ───────────────────────────────────────────────────────
class _UploadButton extends StatelessWidget {
  final String? url;
  final bool uploading;
  final String label;
  final VoidCallback onTap;
  const _UploadButton({required this.url, required this.uploading,
      required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style:OutlinedButton.styleFrom(foregroundColor:SportSphereColors.muted),
      icon:uploading
          ? const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2))
          : Icon(url!=null?Icons.check_circle_rounded:Icons.upload_rounded,
              size:16, color:url!=null?SportSphereColors.sportGreen:null),
      label:Text(uploading?'Uploading...':(url!=null?'Uploaded ✓':label),
          style:TextStyle(fontSize:12,
              color:url!=null?SportSphereColors.sportGreen:null)),
      onPressed:uploading?null:onTap);
  }
}


// ══ SHARED WIDGETS ══════════════════════════════════════════════════════════════

class _Label extends StatelessWidget {
  final String t; const _Label(this.t);
  @override Widget build(BuildContext context)=>Text(t,style:TextStyle(color:SportSphereColors.muted.withValues(alpha:0.7),fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1.1));
}

class _StatCard extends StatelessWidget {
  final String label,value; final IconData icon; final Color color;
  const _StatCard(this.label,this.value,this.icon,this.color);
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:color.withValues(alpha:0.08),borderRadius:BorderRadius.circular(16),border:Border.all(color:color.withValues(alpha:0.22))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      Icon(icon,color:color,size:22),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(value,style:TextStyle(color:color,fontSize:24,fontWeight:FontWeight.w900,height:1)),
        Text(label,style:const TextStyle(color:SportSphereColors.muted,fontSize:11)),
      ]),
    ]),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final Color color; final String title,subtitle; final VoidCallback onTap;
  const _ActionCard(this.icon,this.color,this.title,this.subtitle,this.onTap);
  @override Widget build(BuildContext context)=>GestureDetector(onTap:onTap,child:Container(
    margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:const Color(0xD0071422),borderRadius:BorderRadius.circular(16),border:Border.all(color:Colors.white.withValues(alpha:0.07))),
    child:Row(children:[
      Container(width:42,height:42,decoration:BoxDecoration(shape:BoxShape.circle,color:color.withValues(alpha:0.12)),child:Icon(icon,color:color,size:20)),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(color:SportSphereColors.white,fontWeight:FontWeight.w700,fontSize:14)),
        Text(subtitle,style:const TextStyle(color:SportSphereColors.muted,fontSize:12)),
      ])),
      Icon(Icons.chevron_right_rounded,color:SportSphereColors.muted.withValues(alpha:0.5)),
    ]),
  ));
}

class _AddBar extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _AddBar(this.label,this.onTap);
  @override Widget build(BuildContext context)=>Padding(
    padding:const EdgeInsets.fromLTRB(16,12,16,8),
    child:SizedBox(width:double.infinity,child:FilledButton.icon(
      style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue),
      icon:const Icon(Icons.add,size:16),label:Text(label),onPressed:onTap)));
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller; final String hint; final Function(String) onSearch;
  const _SearchField({required this.controller,required this.hint,required this.onSearch});
  @override Widget build(BuildContext context)=>TextField(
    controller:controller,style:const TextStyle(color:SportSphereColors.white),
    decoration:InputDecoration(hintText:hint,hintStyle:const TextStyle(color:SportSphereColors.muted),
      prefixIcon:const Icon(Icons.search_rounded,color:SportSphereColors.electricBlue),
      suffixIcon:IconButton(icon:const Icon(Icons.search,color:SportSphereColors.muted),onPressed:()=>onSearch(controller.text.trim())),
      filled:true,fillColor:SportSphereColors.surface,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none)),
    onSubmitted:onSearch);
}

class _AdminField extends StatelessWidget {
  final TextEditingController controller; final String label; final int maxLines; final TextInputType? keyboardType;
  const _AdminField({required this.controller,required this.label,this.maxLines=1,this.keyboardType});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(
    controller:controller,maxLines:maxLines,keyboardType:keyboardType,style:const TextStyle(color:SportSphereColors.white),
    decoration:InputDecoration(labelText:label,labelStyle:const TextStyle(color:SportSphereColors.muted),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide(color:Colors.white.withValues(alpha:0.12))),
      focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:SportSphereColors.electricBlue)))));
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override Widget build(BuildContext ctx)=>const Center(child:CircularProgressIndicator(color:SportSphereColors.electricBlue,strokeWidth:2));
}

class _Empty extends StatelessWidget {
  final String msg; const _Empty(this.msg);
  @override Widget build(BuildContext ctx)=>Center(child:Text(msg,style:const TextStyle(color:SportSphereColors.muted),textAlign:TextAlign.center));
}

class _Div extends StatelessWidget {
  const _Div();
  @override Widget build(BuildContext ctx)=>Divider(height:1,color:Colors.white.withValues(alpha:0.06));
}
