import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/admin/app_admin.dart';
import '../../../core/data/social_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/country_picker_field.dart';
import '../../../core/widgets/team_color_picker.dart';
import '../../../core/widgets/grass_form.dart';
import 'bulk_upload_screen.dart';
import '../../../core/utils/form_validators.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../scores/presentation/admin_live_control.dart';
import 'admin_repository.dart';
import 'bulk_upload_screen.dart';
import '../../../core/utils/friendly_error.dart';
import '../profile/presentation/edit_profile_sheet.dart' show showEntityEditSheet, EntityType;

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
    _tabs = TabController(length: 7, vsync: this);
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
            Tab(text: '⭐ PRO Queue'),
          ],
        ),
        Expanded(child: TabBarView(controller: _tabs, children: [
          _OverviewTab(stats: _stats, loading: _statsLoading, onRefresh: _loadStats, tabCtrl: _tabs),
          const _UsersTab(),
          const _CompetitionsTab(),
          _MatchesTab(onRefresh: _loadStats, parentRef: ref),
          const _ContentTab(),
          _NewsTab(onRefresh: _loadStats),
          const _ProQueueTab(),
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
        _ActionCard(Icons.healing_rounded,const Color(0xFF9B6DFF),'Reconcile Identities','Fix entities missing Playify identity',()=>_showReconcileDialog(context)),
        _ActionCard(Icons.emoji_events_rounded,const Color(0xFFFFD700),'Create Competition','Add new league or cup',()=>_showCreateCompetition(context)),
        _ActionCard(Icons.groups_rounded,const Color(0xFF9B6DFF),'Create Team','Add a new club or national team',()=>_showCreateTeam(context,null)),
        _ActionCard(Icons.add_circle_rounded,SportSphereColors.sportGreen,'Schedule Fixture','Add a new match to the calendar',()=>_showCreateMatch(context)),
        _ActionCard(Icons.newspaper_rounded,SportSphereColors.sportOrange,'Post News Article','Publish breaking news or updates',()=>_showNewsCompose(context)),
        _ActionCard(Icons.upload_rounded,const Color(0xFF9B6DFF),'Bulk Upload','Upload teams, players or fixtures from Excel',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BulkUploadScreen(onDone:onRefresh)))),
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
                  else if(v=='role') {
                    _showChangeRole(context,uid,role);
                  }
                  else if(v=='delete') {
                    _confirmDelete(context,uid,name.isNotEmpty?name:handle);
                  }
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
      backgroundColor:GrassForm.sheetBg,
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
      backgroundColor:GrassForm.sheetBg,
      title:const Text('Delete User?',style:TextStyle(color:SportSphereColors.white)),
      content:Text('Permanently delete $name?',style:const TextStyle(color:SportSphereColors.muted)),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        TextButton(onPressed:() async {
          Navigator.pop(ctx);
          // C8 — deleteUser now invokes an Edge Function and rethrows on
          // failure so the operator is warned about half-deleted users.
          try {
            await _repo.deleteUser(uid);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Failed to delete user: $e')),
              );
            }
          }
          _load(_search.text.trim());
        },
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
      Padding(padding:const EdgeInsets.fromLTRB(16,8,16,4),child:Align(alignment:Alignment.centerRight,child:
        FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue,padding:const EdgeInsets.symmetric(horizontal:12,vertical:8)),
          icon:const Icon(Icons.upload_rounded,size:15),label:const Text('Bulk Upload Teams / Players',style:TextStyle(fontSize:11)),
          onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BulkUploadScreen(onDone:_load)))),
      )),
      TabBar(controller:_sub,labelColor:SportSphereColors.white,unselectedLabelColor:SportSphereColors.muted,
        indicatorColor:const Color(0xFFFFD700),labelStyle:const TextStyle(fontSize:11,fontWeight:FontWeight.w700),
        tabs:const[Tab(text:'Competitions'),Tab(text:'Teams'),Tab(text:'Players'),Tab(text:'Coaches')]),
      Expanded(child:_loading?const _Loader():TabBarView(controller:_sub,children:[
        _EList(items:_comps,icon:Icons.emoji_events_rounded,color:const Color(0xFFFFD700),
          addLabel:'Add Competition',onAdd:()=>_showCreateCompetition(context).then((_)=>_load()),
          sub:(c)=>'${c['country']??''}  ·  ${c['type']??''}  ·  ${c['season']??''}',
          entityType:EntityType.competition,
          onEdited:_load,
          onDelete:(id) async {await _repo.deleteCompetition(id);_load();}),
        _EList(items:_teams,icon:Icons.groups_rounded,color:const Color(0xFF9B6DFF),
          addLabel:'Add Team',onAdd:()=>_showCreateTeam(context,_comps).then((_)=>_load()),
          sub:(t)=>'${t['country']??''}  ·  ${t['city']??''}',
          entityType:EntityType.team,
          onEdited:_load,
          onDelete:(id) async {await _repo.deleteTeam(id);_load();}),
        _EList(items:_players,icon:Icons.person_rounded,color:SportSphereColors.sportOrange,
          addLabel:'Add Player',onAdd:()=>_showCreatePlayer(context,_teams).then((_)=>_load()),
          sub:(p)=>'${p['position']??''}  ·  #${p['shirtNumber']??'-'}',
          entityType:EntityType.player,
          onEdited:_load,
          onDelete:(id) async {await _repo.deletePlayer(id);_load();}),
        _EList(items:_coaches,icon:Icons.sports_rounded,color:const Color(0xFF00C896),
          addLabel:'Add Coach',onAdd:()=>_showCreateCoach(context,_teams).then((_)=>_load()),
          sub:(c)=>'${c['role']??''}  ·  ${c['nationality']??''}',
          entityType:EntityType.coach,
          onEdited:_load,
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
  /// Optional — when set, an "Edit" entry appears in the row popup menu and
  /// opens [showEntityEditSheet] prefilled with the row's data.
  final EntityType? entityType;
  /// Called after a successful edit (typically reloads the list).
  final Future<void> Function()? onEdited;
  const _EList({required this.items,required this.icon,required this.color,
      required this.addLabel,required this.onAdd,required this.sub,required this.onDelete,
      this.entityType, this.onEdited});
  @override Widget build(BuildContext context)=>Column(children:[
    _AddBar(addLabel,onAdd),
    Expanded(child:items.isEmpty?const _Empty('Nothing here yet'):ListView.separated(
      padding:const EdgeInsets.fromLTRB(16,0,16,40),itemCount:items.length,separatorBuilder:(_,__)=>const _Div(),
      itemBuilder:(_,i){
        final e=items[i];
        return ListTile(
          contentPadding:const EdgeInsets.symmetric(vertical:4),
          leading:Container(width:36,height:36,decoration:BoxDecoration(shape:BoxShape.circle,color:color.withValues(alpha:0.12)),child:Icon(icon,color:color,size:18)),
          title:Text(e['name']??'',style:const TextStyle(color:SportSphereColors.white,fontWeight:FontWeight.w700,fontSize:13)),
          subtitle:Text(sub(e),style:const TextStyle(color:SportSphereColors.muted,fontSize:11)),
          trailing:PopupMenuButton<String>(
            color:SportSphereColors.surface,
            icon:const Icon(Icons.more_vert_rounded,color:SportSphereColors.muted),
            onSelected:(v) async {
              if(v=='edit' && entityType != null) {
                await showEntityEditSheet(
                  context,
                  entityType: entityType!,
                  entityId: e['id'].toString(),
                  initialData: e,
                );
                if(onEdited != null) await onEdited!();
              } else if(v=='delete') {
                await onDelete(e['id'].toString());
              }
            },
            itemBuilder:(_)=>[
              if(entityType != null)
                const PopupMenuItem(value:'edit',child:Row(children:[
                  Icon(Icons.edit_outlined,color:SportSphereColors.electricBlue,size:18),
                  SizedBox(width:10),
                  Text('Edit',style:TextStyle(color:SportSphereColors.white)),
                ])),
              const PopupMenuItem(value:'delete',child:Row(children:[
                Icon(Icons.delete_outline_rounded,color:SportSphereColors.danger,size:18),
                SizedBox(width:10),
                Text('Delete',style:TextStyle(color:SportSphereColors.danger)),
              ])),
            ],
          ),
        );
      },
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
        // #8.9 — Live Match Control panel itself is owned by Agent S1
        // (lib/features/scores/presentation/admin_live_control.dart).
        // Adding a "push to feed" button there is out of scope for S5.
        // The per-match popup below already offers "Post to Feed" as a fallback.
        Expanded(child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xFFE31B23)),
          icon:const Icon(Icons.sensors_rounded,size:16),label:const Text('Live Control'),
          onPressed:()=>openAdminLiveControl(context,ref).then((_)=>_load()))),
        const SizedBox(width:8),
        Expanded(child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:SportSphereColors.sportGreen),
          icon:const Icon(Icons.add,size:16),label:const Text('Add Fixture'),
          onPressed:()=>_showCreateMatch(context).then((_)=>_load()))),
        const SizedBox(width:8),
        Expanded(child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:SportSphereColors.electricBlue),
          icon:const Icon(Icons.upload_rounded,size:16),label:const Text('Bulk Upload'),
          onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>BulkUploadScreen(onDone:_load)))))
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
                  if(v=='feed') await _showPostMatchToFeed(context,m);
                  if(v=='poll') await _showCreatePollForMatch(context,m).then((_)=>_load());
                  if(v=='pred') await _showCreatePredictionForMatch(context,m).then((_)=>_load());
                },
                itemBuilder:(_)=>[
                  const PopupMenuItem(value:'edit',child:Text('Edit Result',style:TextStyle(color:SportSphereColors.white))),
                  const PopupMenuItem(value:'feed',child:Text('Post to Feed',style:TextStyle(color:SportSphereColors.electricBlue))),
                  const PopupMenuItem(value:'poll',child:Text('Create Poll',style:TextStyle(color:SportSphereColors.sportGreen))),
                  const PopupMenuItem(value:'pred',child:Text('Create Prediction',style:TextStyle(color:SportSphereColors.sportOrange))),
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
      backgroundColor:GrassForm.sheetBg,
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
        itemBuilder:(_,i){final p=_posts[i];final content=(p['content']as String?)??'';final type=p['postType']??'text';
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

// ══ RECONCILE DIALOG ══════════════════════════════════════════════════════════

Future<void> _showReconcileDialog(BuildContext ctx) async {
  showDialog<void>(context: ctx, barrierDismissible: false, builder: (c) => AlertDialog(
    backgroundColor: GrassForm.sheetBg,
    title: const Text('Reconcile Entity Identities', style: TextStyle(color: SportSphereColors.white)),
    content: const Text(
      'Scans all Teams, Players and Leagues.\n\nEntities missing a Playify identity will have one created. Existing identities are not touched.',
      style: TextStyle(color: SportSphereColors.muted, fontSize: 13)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
      TextButton(
        onPressed: () async {
          Navigator.pop(c);
          if (!ctx.mounted) return;
          showDialog<void>(context: ctx, barrierDismissible: false, builder: (_) => const AlertDialog(
            backgroundColor: SportSphereColors.surface,
            content: Row(children: [
              CircularProgressIndicator(color: SportSphereColors.electricBlue),
              SizedBox(width: 16),
              Text('Reconciling...', style: TextStyle(color: SportSphereColors.white)),
            ]),
          ));
          try {
            final report = await _repo.reconcileEntityIdentities();
            if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
            final created = report.where((r) => r['status'] == 'RECONCILED').length;
            final failed  = report.where((r) => r['status'] == 'FAILED').length;
            final healthy = report.where((r) => r['status'] == 'ALREADY_HAS_IDENTITY').length;
            if (ctx.mounted) showDialog<void>(context: ctx, builder: (_) => AlertDialog(
              backgroundColor: GrassForm.sheetBg,
              title: const Text('Done', style: TextStyle(color: SportSphereColors.white)),
              content: Text('Scanned: ${report.length}\nCreated: $created\nHealthy: $healthy\nFailed: $failed',
                  style: const TextStyle(color: SportSphereColors.white, fontSize: 13)),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
            ));
          } catch (e) {
            if (ctx.mounted) {
              Navigator.of(ctx, rootNavigator: true).pop();
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
        child: const Text('Reconcile', style: TextStyle(color: SportSphereColors.sportGreen)),
      ),
    ],
  ));
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
  final email = TextEditingController();
  final password = TextEditingController(text: 'SportSphere2024!');
  final handle = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  String role = 'fan';

  return showDialog<void>(
    context: ctx,
    builder: (_) => StatefulBuilder(
      builder: (c, setL) => AlertDialog(
        backgroundColor: GrassForm.sheetBg,
        title: const Text('Create User', style: TextStyle(color: SportSphereColors.white)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _AdminField(controller: firstName, label: 'First Name *'),
          _AdminField(controller: lastName, label: 'Last Name'),
          _AdminField(controller: handle, label: 'Handle (no spaces, no @)'),
          _AdminField(controller: email, label: 'Email *', keyboardType: TextInputType.emailAddress),
          _AdminField(controller: password, label: 'Password'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: role,
            dropdownColor: GrassForm.sheetBg,
            decoration: const InputDecoration(
              labelText: 'Role',
              labelStyle: TextStyle(color: SportSphereColors.muted),
            ),
            items: ['fan', 'player', 'coach', 'team', 'journalist',
                    'analyst', 'creator', 'scout', 'agent', 'admin']
                .map((r) => DropdownMenuItem(value: r,
                    child: Text(r[0].toUpperCase() + r.substring(1),
                        style: const TextStyle(color: SportSphereColors.white)))).toList(),
            onChanged: (v) => setL(() => role = v ?? role),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (email.text.trim().isEmpty) return;
              try {
                await _repo.createUser(
                  email: email.text.trim(),
                  password: password.text.trim(),
                  handle: handle.text.trim().replaceAll('@', '').replaceAll(' ', '_'),
                  firstName: firstName.text.trim(),
                  lastName: lastName.text.trim(),
                  role: role,
                );
                if (c.mounted) {
                  Navigator.pop(c);
                  ScaffoldMessenger.of(c).showSnackBar(
                    const SnackBar(content: Text('User created successfully')));
                }
              } catch (e) {
                if (c.mounted) ScaffoldMessenger.of(c)
                    .showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}

// ── Create Competition ─────────────────────────────────────────────────────────
Future<void> _showCreateCompetition(BuildContext ctx) {
  final name = TextEditingController();
  final description = TextEditingController();
  final website = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String country = 'Tanzania';
  String season = '2026/27';
  String type = 'league';
  String? logoUrl;
  bool uploading = false;

  return showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => StatefulBuilder(
      builder: (c, setL) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GrassFormHeader(
                  title: 'Create Competition',
                  subtitle: 'League or cup on the SportSphere pitch',
                  icon: Icons.emoji_events_rounded,
                ),
                const SizedBox(height: 16),
                _AdminField(
                  controller: name,
                  label: 'Competition Name *',
                  validator: (v) => FormValidators.required(v, field: 'Competition name'),
                ),
                CountryPickerField(
                  label: 'Country *',
                  value: country,
                  onChanged: (v) => setL(() => country = v),
                ),
                GrassDropdown<String>(
                  label: 'Season *',
                  value: season,
                  icon: Icons.calendar_month_rounded,
                  items: kSeasonOptions
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, style: const TextStyle(color: SportSphereColors.white)),
                          ))
                      .toList(),
                  onChanged: (v) => setL(() => season = v ?? season),
                  validator: (v) => FormValidators.dropdownRequired(v, field: 'season'),
                ),
                GrassDropdown<String>(
                  label: 'Type *',
                  value: type,
                  icon: Icons.category_rounded,
                  items: kCompetitionTypes
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t[0].toUpperCase() + t.substring(1),
                              style: const TextStyle(color: SportSphereColors.white),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setL(() => type = v ?? type),
                  validator: (v) => FormValidators.dropdownRequired(v, field: 'type'),
                ),
                _AdminField(controller: description, label: 'Description', maxLines: 3),
                _AdminField(
                  controller: website,
                  label: 'Website (optional)',
                  keyboardType: TextInputType.url,
                ),
                _UploadButton(
                  url: logoUrl,
                  uploading: uploading,
                  label: 'Upload Logo',
                  onTap: () async {
                    setL(() => uploading = true);
                    final url = await _pickAndUpload(c, folder: 'logos');
                    setL(() {
                      logoUrl = url;
                      uploading = false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: GrassForm.greenBright,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      if (country.trim().isEmpty) {
                        ScaffoldMessenger.of(c).showSnackBar(
                          const SnackBar(content: Text('Select a country')),
                        );
                        return;
                      }
                      try {
                        await _repo.createCompetition(
                          name: name.text.trim(),
                          country: country,
                          season: season,
                          type: type,
                        );
                        if (c.mounted) Navigator.pop(c);
                      } catch (e) {
                        if (c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(
                              SnackBar(content: Text(friendlyError(e))));
                        }
                      }
                    },
                    child: const Text('Create Competition',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showCreateTeam(BuildContext ctx, List<Map<String,dynamic>>? preloaded) async {
  final comps = preloaded ?? await _repo.listCompetitions();
  if (!ctx.mounted) return;
  final name = TextEditingController();
  final shortName = TextEditingController();
  final venue = TextEditingController();
  final founded = TextEditingController();
  final description = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String country = 'Tanzania';
  String? city = 'Dar es Salaam';
  String primaryColor = '#E31B23';
  String? leagueId, logoUrl;
  bool uploading = false;

  showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => StatefulBuilder(
      builder: (c, setL) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GrassFormHeader(
                  title: 'Create Team',
                  subtitle: 'Club colours, country and badge',
                  icon: Icons.groups_rounded,
                ),
                const SizedBox(height: 16),
                _AdminField(
                  controller: name,
                  label: 'Full Club Name *',
                  validator: (v) => FormValidators.required(v, field: 'Club name'),
                ),
                _AdminField(controller: shortName, label: 'Short Name (e.g. SIM, YAN)'),
                CountryPickerField(
                  label: 'Country *',
                  value: country,
                  onChanged: (v) => setL(() => country = v),
                ),
                GrassDropdown<String>(
                  label: 'City *',
                  value: city,
                  icon: Icons.location_city_rounded,
                  items: kCityOptions
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s,
                                style: const TextStyle(
                                    color: SportSphereColors.white)),
                          ))
                      .toList(),
                  onChanged: (v) => setL(() => city = v),
                  validator: (v) =>
                      FormValidators.dropdownRequired(v, field: 'city'),
                ),
                TeamColorPicker(
                    valueHex: primaryColor,
                    onChanged: (v) => setL(() => primaryColor = v)),
                _AdminField(controller: venue, label: 'Stadium / Venue'),
                _AdminField(
                  controller: founded,
                  label: 'Founded Year',
                  keyboardType: TextInputType.number,
                  validator: FormValidators.year,
                ),
                _AdminField(
                    controller: description,
                    label: 'Club Description',
                    maxLines: 3),
                if (comps.isNotEmpty)
                  GrassDropdown<String?>(
                    label: 'Competition (optional)',
                    value: leagueId,
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text('None',
                              style:
                                  TextStyle(color: SportSphereColors.muted))),
                      ...comps.map((comp) => DropdownMenuItem(
                            value: comp['id'].toString(),
                            child: Text(comp['name'].toString(),
                                style: const TextStyle(
                                    color: SportSphereColors.white)),
                          )),
                    ],
                    onChanged: (v) => setL(() => leagueId = v),
                  ),
                _UploadButton(
                  url: logoUrl,
                  uploading: uploading,
                  label: 'Upload Team Logo / Badge',
                  onTap: () async {
                    setL(() => uploading = true);
                    final url = await _pickAndUpload(c, folder: 'logos');
                    setL(() {
                      logoUrl = url;
                      uploading = false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          parseHexColor(primaryColor) ?? GrassForm.greenBright,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      if (country.trim().isEmpty) {
                        ScaffoldMessenger.of(c).showSnackBar(
                          const SnackBar(content: Text('Select a country')),
                        );
                        return;
                      }
                      try {
                        await _repo.createTeam(
                          name: name.text.trim(),
                          country: country,
                          city: (city == null || city == 'Other')
                              ? null
                              : city,
                          leagueId: leagueId,
                          venue: venue.text.trim().isEmpty
                              ? null
                              : venue.text.trim(),
                          foundedYear: int.tryParse(founded.text.trim()),
                          primaryColor: primaryColor,
                          logoUrl: logoUrl,
                        );
                        if (c.mounted) Navigator.pop(c);
                      } catch (e) {
                        if (c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(
                              SnackBar(content: Text(friendlyError(e))));
                        }
                      }
                    },
                    child: const Text('Create Team',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showCreatePlayer(BuildContext ctx, List<Map<String,dynamic>> teams) {
  final name=TextEditingController(),
        shirt=TextEditingController(), height=TextEditingController(),
        weight=TextEditingController(), firstName=TextEditingController(),
        lastName=TextEditingController();
  String position='Forward';
  String nationality='Tanzania';
  String? teamId, photoUrl, dob;
  bool uploading=false;
  String? teamError;

  if (teams.isEmpty) {
    return showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: GrassForm.sheetBg,
        title: const Text('No clubs yet', style: TextStyle(color: SportSphereColors.white)),
        content: const Text(
          'Create a club/team first under Matches → Teams, then add the player and select their current club.',
          style: TextStyle(color: SportSphereColors.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Map<String, dynamic>? selectedTeam() {
    if (teamId == null) return null;
    for (final t in teams) {
      if (t['id']?.toString() == teamId) return t;
    }
    return null;
  }

  return showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => StatefulBuilder(
      builder: (c, setL) {
        final team = selectedTeam();
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GrassFormHeader(
                  title: 'Add Player',
                  subtitle: 'Select current club from existing teams',
                  icon: Icons.sports_rounded,
                ),
                const SizedBox(height: 16),
                // Required: current club
                const Text('Current club / team *',
                    style: TextStyle(
                        color: SportSphereColors.muted, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: teamId,
                  dropdownColor: SportSphereColors.surface,
                  decoration: InputDecoration(
                    labelText: 'Select existing club',
                    labelStyle: const TextStyle(color: SportSphereColors.muted),
                    errorText: teamError,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: SportSphereColors.electricBlue),
                    ),
                  ),
                  items: teams
                      .map((t) => DropdownMenuItem(
                            value: t['id'].toString(),
                            child: Text(
                              '${t['name'] ?? 'Team'}'
                              '${(t['city'] != null && '${t['city']}'.isNotEmpty) ? ' · ${t['city']}' : ''}',
                              style: const TextStyle(
                                  color: SportSphereColors.white, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setL(() {
                    teamId = v;
                    teamError = null;
                  }),
                ),
                if (team != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1626),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${team['name'] ?? ''}',
                            style: const TextStyle(
                                color: SportSphereColors.white,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if ((team['country'] ?? '').toString().isNotEmpty)
                              team['country'],
                            if ((team['city'] ?? '').toString().isNotEmpty)
                              team['city'],
                            if ((team['venue'] ?? '').toString().isNotEmpty)
                              'Stadium: ${team['venue']}',
                          ].whereType<Object>().join(' · '),
                          style: const TextStyle(
                              color: SportSphereColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: _AdminField(
                          controller: firstName, label: 'First Name *')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _AdminField(
                          controller: lastName, label: 'Last Name *')),
                ]),
                _AdminField(controller: name, label: 'Full Name (display)'),
                CountryPickerField(
                    label: 'Nationality',
                    value: nationality,
                    onChanged: (v) => setL(() => nationality = v)),
                Row(children: [
                  Expanded(
                      child: _AdminField(
                          controller: shirt,
                          label: 'Shirt #',
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: DropdownButtonFormField<String>(
                    value: position,
                    dropdownColor: SportSphereColors.surface,
                    decoration: const InputDecoration(
                        labelText: 'Position',
                        labelStyle: TextStyle(color: SportSphereColors.muted)),
                    items: [
                      'Goalkeeper',
                      'Defender',
                      'Midfielder',
                      'Forward',
                      'Winger',
                      'Striker'
                    ]
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p,
                                style: const TextStyle(
                                    color: SportSphereColors.white))))
                        .toList(),
                    onChanged: (v) =>
                        setL(() => position = v ?? position),
                  )),
                ]),
                Row(children: [
                  Expanded(
                      child: _AdminField(
                          controller: height,
                          label: 'Height (cm)',
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _AdminField(
                          controller: weight,
                          label: 'Weight (kg)',
                          keyboardType: TextInputType.number)),
                ]),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      dob == null
                          ? 'Date of Birth (optional)'
                          : 'DOB: $dob',
                      style: TextStyle(
                          color: dob == null
                              ? SportSphereColors.muted
                              : SportSphereColors.white,
                          fontSize: 13)),
                  trailing: const Icon(Icons.calendar_today_rounded,
                      color: SportSphereColors.electricBlue, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: c,
                        initialDate: DateTime(1998, 1, 1),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now());
                    if (d != null) {
                      setL(() => dob =
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
                    }
                  },
                ),
                const SizedBox(height: 8),
                _UploadButton(
                    url: photoUrl,
                    uploading: uploading,
                    label: 'Upload Player Photo',
                    onTap: () async {
                      setL(() => uploading = true);
                      final url =
                          await _pickAndUpload(c, folder: 'players');
                      setL(() {
                        photoUrl = url;
                        uploading = false;
                      });
                    }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: GrassForm.greenBright,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () async {
                      if (teamId == null) {
                        setL(() => teamError =
                            'Select the player’s current club');
                        return;
                      }
                      final fullName =
                          '${firstName.text.trim()} ${lastName.text.trim()}'
                              .trim();
                      if (fullName.isEmpty && name.text.trim().isEmpty) {
                        ScaffoldMessenger.of(c).showSnackBar(
                          const SnackBar(
                              content: Text('Enter the player name')),
                        );
                        return;
                      }
                      try {
                        await _repo.createPlayer(
                          name: name.text.trim().isNotEmpty
                              ? name.text.trim()
                              : fullName,
                          position: position,
                          teamId: teamId,
                          nationality: nationality,
                          shirtNumber: int.tryParse(shirt.text.trim()),
                        );
                        if (c.mounted) Navigator.pop(c);
                      } catch (e) {
                        if (c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(
                              SnackBar(content: Text(friendlyError(e))));
                        }
                      }
                    },
                    child: const Text('Add Player',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _showCreateCoach(BuildContext ctx, List<Map<String,dynamic>> teams) {
  final name=TextEditingController(),
        firstName=TextEditingController(), lastName=TextEditingController();
  String coachRole='head_coach';
  String nationality='Tanzania';
  String? teamId, photoUrl, dob;
  bool uploading=false;

  return showModalBottomSheet<void>(context:ctx, isScrollControlled:true,
    backgroundColor:GrassForm.sheetBg,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    builder:(_)=>StatefulBuilder(builder:(c,setL)=>Padding(
      padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(c).viewInsets.bottom+20),
      child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const GrassFormHeader(title:'Add Coach / Staff', subtitle:'Link staff to a club', icon:Icons.psychology_rounded),
        const SizedBox(height:16),
        Row(children:[
          Expanded(child:_AdminField(controller:firstName, label:'First Name *')),
          const SizedBox(width:10),
          Expanded(child:_AdminField(controller:lastName, label:'Last Name *')),
        ]),
        _AdminField(controller:name, label:'Display Name'),
        CountryPickerField(label:'Nationality', value:nationality, onChanged:(v)=>setL(()=>nationality=v)),
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
          style:FilledButton.styleFrom(backgroundColor:GrassForm.greenBright, padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:() async {
            final fullName = '${firstName.text.trim()} ${lastName.text.trim()}'.trim();
            if(fullName.isEmpty && name.text.trim().isEmpty) return;
            try {
              await _repo.createCoach(
                name:name.text.trim().isNotEmpty?name.text.trim():fullName,
                role:coachRole, teamId:teamId,
                nationality:nationality);
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(friendlyError(e)))); }
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
  // #8.1 — Post to Feed toggle. When true, after createMatch returns its id,
  // we also insert a Post row (postType='match') linking to the new match
  // via the new `matchId` column added by migration 20260824010000.
  bool postToFeed = true;

  showModalBottomSheet<void>(context:ctx, isScrollControlled:true,
    backgroundColor:GrassForm.sheetBg,
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

        // #8.1 — Post to Feed checkbox
        SwitchListTile(
          value: postToFeed,
          onChanged: (v) => setL(() => postToFeed = v),
          title: const Text('Post to Feed',
              style: TextStyle(color: SportSphereColors.white, fontSize: 14)),
          subtitle: const Text(
              'Auto-create a feed Post (type=match) linking to this fixture',
              style: TextStyle(color: SportSphereColors.muted, fontSize: 11)),
          activeColor: SportSphereColors.sportGreen,
          contentPadding: EdgeInsets.zero,
        ),

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
              final matchId = await _repo.createMatch(
                homeTeam:home, awayTeam:away,
                league:leagueCtrl.text.trim(),
                kickoffAt:kickoff,
                venue:venueCtrl.text.trim().isEmpty?null:venueCtrl.text.trim(),
                homeBadge:homeTeam?['logoUrl']?.toString(),
                awayBadge:awayTeam?['logoUrl']?.toString(),
                season:seasonCtrl.text.trim().isEmpty?null:seasonCtrl.text.trim());
              // #8.1 — Optionally push a Post row linked via matchId.
              // #8.7 — No dedicated sub_post / parent_post table exists; the
              // migration 20260824010000 adds `matchId` to Post and Poll, which
              // is the linking mechanism between a fixture and its derived
              // posts (match/poll/prediction). See:
              //   supabase/migrations/20260824010000_fix_all_remaining_db_issues.sql
              if (postToFeed) {
                final uid = Supabase.instance.client.auth.currentUser?.id;
                if (uid != null) {
                  try {
                    await Supabase.instance.client.from('Post').insert({
                      'id': 'post-match-$matchId',
                      'userId': uid,
                      'postType': 'match',
                      'content': '$home vs $away — ${leagueCtrl.text.trim()}',
                      'matchId': matchId, // new column from migration 20260824010000
                      'mediaUrls': const [],
                      'hashtags': const [],
                      'sportTag': 'football',
                      'isBreaking': false,
                      'likeCount': 0,
                      'commentCount': 0,
                      'shareCount': 0,
                      'createdAt': DateTime.now().toIso8601String(),
                      'updatedAt': DateTime.now().toIso8601String(),
                    });
                  } catch (e) {
                    debugPrint('createMatch postToFeed: $e');
                  }
                }
              }
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(friendlyError(e)))); }
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
    backgroundColor:GrassForm.sheetBg,
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
            if(url!=null) setL((){images.add(url);uploading=false;});
            else setL(()=>uploading=false);
          }),
        const SizedBox(height:16),
        SizedBox(width:double.infinity, child:FilledButton(
          style:FilledButton.styleFrom(backgroundColor:GrassForm.greenBright, padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:() async {
            if(titleCtrl.text.trim().isEmpty) return;
            try {
              await _repo.createNews(
                title:titleCtrl.text.trim(), summary:summaryCtrl.text.trim(),
                body:bodyCtrl.text.trim(), category:category,
                source:sourceCtrl.text.trim(), isBreaking:isBreaking,
                imageUrl:images.isNotEmpty?images.first:null);
              if(c.mounted) Navigator.pop(c);
            } catch(e) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(friendlyError(e)))); }
          },
          child:const Text('Publish Article', style:TextStyle(fontWeight:FontWeight.w800)))),
      ])))));
}

// ── Create Post ────────────────────────────────────────────────────────────────
Future<void> _showCreatePost(BuildContext ctx) async {
  final teams = await _repo.listTeams();
  final matches = await _repo.listMatches(limit: 30);
  if (!ctx.mounted) return;
  final textCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String postType = 'text';
  String? teamId;
  bool uploading = false;
  List<String> mediaUrls = [];

  // #8.3 — Poll state (question + dynamic option list + optional match link)
  final pollQuestionCtrl = TextEditingController();
  final List<TextEditingController> pollOptionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];

  // #8.3 — Prediction state (match link + predicted winner + score)
  String? predMatchId;
  String predWinner = 'home';
  final predHomeCtrl = TextEditingController(text: '1');
  final predAwayCtrl = TextEditingController(text: '1');

  // #8.3 — Optional match link for polls (also reused by predictions)
  String? pollMatchId;

  return showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => StatefulBuilder(
      builder: (c, setL) {
        final selectedTeam = teamId == null
            ? null
            : teams.cast<Map<String, dynamic>?>().firstWhere(
                  (t) => t?['id']?.toString() == teamId,
                  orElse: () => null,
                );
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GrassFormHeader(
                    title: 'Create Post',
                    subtitle: 'Announce teams, players, or general updates',
                    icon: Icons.campaign_rounded,
                  ),
                  const SizedBox(height: 14),
                  GrassDropdown<String>(
                    label: 'Post type *',
                    value: postType,
                    items: const [
                      DropdownMenuItem(
                          value: 'text',
                          child: Text('Announcement',
                              style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: 'image',
                          child: Text('Photo post',
                              style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: 'video',
                          child: Text('Video post',
                              style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: 'welcome',
                          child: Text('Welcome team / become a fan',
                              style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: 'poll',
                          child: Text('Poll',
                              style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: 'prediction',
                          child: Text('Prediction',
                              style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (v) => setL(() => postType = v ?? postType),
                  ),
                  if (postType == 'welcome') ...[
                    GrassDropdown<String?>(
                      label: 'Team to promote *',
                      value: teamId,
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: Text('Select team',
                                style: TextStyle(color: Colors.white54))),
                        ...teams.map((t) => DropdownMenuItem(
                              value: t['id'].toString(),
                              child: Text('${t['name']}',
                                  style: const TextStyle(color: Colors.white)),
                            )),
                      ],
                      onChanged: (v) {
                        setL(() {
                          teamId = v;
                          if (v != null && textCtrl.text.trim().isEmpty) {
                            final name = teams
                                .firstWhere((t) => t['id'].toString() == v,
                                    orElse: () => {'name': 'Team'})['name'];
                            textCtrl.text =
                                'Welcoming $name to Playify! Follow and become a fan.';
                          }
                        });
                      },
                      validator: (v) {
                        if (postType == 'welcome' && (v == null || v.isEmpty)) {
                          return 'Select a team';
                        }
                        return null;
                      },
                    ),
                    if (selectedTeam != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Follow / Become Fan will apply to ${selectedTeam['name']}, not the admin account.',
                          style: const TextStyle(
                              color: Color(0xFF76D42B), fontSize: 12),
                        ),
                      ),
                  ],
                  // #8.3 — Poll fields
                  if (postType == 'poll') ...[
                    _AdminField(
                      controller: pollQuestionCtrl,
                      label: 'Question *',
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a question'
                          : null,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 4),
                      child: Text('Options (min 2, max 6)',
                          style: TextStyle(
                              color: SportSphereColors.muted, fontSize: 12)),
                    ),
                    for (var i = 0; i < pollOptionCtrls.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(
                            child: _AdminField(
                              controller: pollOptionCtrls[i],
                              label: 'Option ${i + 1}',
                            ),
                          ),
                          if (pollOptionCtrls.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: SportSphereColors.danger, size: 20),
                              onPressed: () => setL(() {
                                pollOptionCtrls[i].dispose();
                                pollOptionCtrls.removeAt(i);
                              }),
                            ),
                        ]),
                      ),
                    if (pollOptionCtrls.length < 6)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add option'),
                          onPressed: () => setL(() =>
                              pollOptionCtrls.add(TextEditingController())),
                        ),
                      ),
                    if (matches.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        value: pollMatchId,
                        dropdownColor: SportSphereColors.surface,
                        decoration: const InputDecoration(
                            labelText: 'Link to match (optional)',
                            labelStyle:
                                TextStyle(color: SportSphereColors.muted)),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('None',
                                  style: TextStyle(
                                      color: SportSphereColors.muted))),
                          ...matches.map((m) => DropdownMenuItem(
                                value: m['id'].toString(),
                                child: Text(
                                    '${m['homeTeam']} vs ${m['awayTeam']}',
                                    style: const TextStyle(
                                        color: SportSphereColors.white)),
                              )),
                        ],
                        onChanged: (v) => setL(() => pollMatchId = v),
                      ),
                  ],
                  // #8.3 — Prediction fields
                  if (postType == 'prediction') ...[
                    if (matches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                            'No matches available — prediction will be saved without a match link.',
                            style: TextStyle(
                                color: SportSphereColors.muted, fontSize: 12)),
                      )
                    else
                      DropdownButtonFormField<String?>(
                        value: predMatchId,
                        dropdownColor: SportSphereColors.surface,
                        decoration: const InputDecoration(
                            labelText: 'Match *',
                            labelStyle:
                                TextStyle(color: SportSphereColors.muted)),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('Select match',
                                  style: TextStyle(
                                      color: SportSphereColors.muted))),
                          ...matches.map((m) => DropdownMenuItem(
                                value: m['id'].toString(),
                                child: Text(
                                    '${m['homeTeam']} vs ${m['awayTeam']}',
                                    style: const TextStyle(
                                        color: SportSphereColors.white)),
                              )),
                        ],
                        onChanged: (v) => setL(() => predMatchId = v),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 4),
                      child: Text('Predicted winner',
                          style: TextStyle(
                              color: SportSphereColors.muted, fontSize: 12)),
                    ),
                    Wrap(spacing: 8, children: [
                      ChoiceChip(
                        label: const Text('Home'),
                        selected: predWinner == 'home',
                        onSelected: (_) => setL(() => predWinner = 'home'),
                      ),
                      ChoiceChip(
                        label: const Text('Draw'),
                        selected: predWinner == 'draw',
                        onSelected: (_) => setL(() => predWinner = 'draw'),
                      ),
                      ChoiceChip(
                        label: const Text('Away'),
                        selected: predWinner == 'away',
                        onSelected: (_) => setL(() => predWinner = 'away'),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: _AdminField(
                          controller: predHomeCtrl,
                          label: 'Home score',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(':',
                            style: TextStyle(
                                color: SportSphereColors.white,
                                fontSize: 20)),
                      ),
                      Expanded(
                        child: _AdminField(
                          controller: predAwayCtrl,
                          label: 'Away score',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),
                  ],
                  _AdminField(
                    controller: textCtrl,
                    label: postType == 'poll'
                        ? 'Body (optional, shown with the poll)'
                        : postType == 'prediction'
                            ? 'Note (optional)'
                            : 'Content *',
                    maxLines: 5,
                    validator: (v) {
                      if (postType == 'poll' || postType == 'prediction') {
                        return null;
                      }
                      if ((v == null || v.trim().isEmpty) && mediaUrls.isEmpty) {
                        return 'Write something or add media';
                      }
                      return null;
                    },
                  ),
                  if (mediaUrls.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: mediaUrls
                          .map((u) => Chip(
                                label: Text(
                                    u.toLowerCase().contains('.mp4')
                                        ? 'Video'
                                        : 'Photo',
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.2),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () =>
                                    setL(() => mediaUrls.remove(u)),
                              ))
                          .toList(),
                    ),
                  if (mediaUrls.length < 4)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70),
                      icon: uploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_photo_alternate_rounded,
                              size: 16),
                      label: Text(uploading ? 'Uploading…' : 'Add photo / video',
                          style: const TextStyle(fontSize: 12)),
                      onPressed: uploading
                          ? null
                          : () async {
                              setL(() => uploading = true);
                              final url =
                                  await _pickAndUpload(c, folder: 'posts');
                              if (url != null) {
                                setL(() {
                                  mediaUrls.add(url);
                                  uploading = false;
                                  if (postType == 'text') postType = 'image';
                                });
                              } else {
                                setL(() => uploading = false);
                              }
                            },
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: GrassForm.greenBright,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        if (postType == 'welcome' &&
                            (teamId == null || teamId!.isEmpty)) {
                          ScaffoldMessenger.of(c).showSnackBar(
                            const SnackBar(
                                content: Text('Select a team to welcome')),
                          );
                          return;
                        }
                        if (postType == 'poll') {
                          final q = pollQuestionCtrl.text.trim();
                          final opts = pollOptionCtrls
                              .map((ctrl) => ctrl.text.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          if (q.isEmpty) {
                            ScaffoldMessenger.of(c).showSnackBar(
                              const SnackBar(content: Text('Enter a question')),
                            );
                            return;
                          }
                          if (opts.length < 2) {
                            ScaffoldMessenger.of(c).showSnackBar(
                              const SnackBar(
                                  content: Text('Poll needs at least 2 options')),
                            );
                            return;
                          }
                          try {
                            final uid = Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) throw StateError('Sign in required');
                            final ts = DateTime.now().millisecondsSinceEpoch;
                            final postId = 'post-poll-$ts';
                            // #8.3 — Post + Poll row. `matchId` is the new
                            // linking column added by migration 20260824010000.
                            await Supabase.instance.client.from('Post').insert({
                              'id': postId,
                              'userId': uid,
                              'postType': 'poll',
                              'content': q,
                              'mediaUrls': const [],
                              'hashtags': const [],
                              'sportTag': 'football',
                              if (pollMatchId != null) 'matchId': pollMatchId,
                              'likeCount': 0,
                              'commentCount': 0,
                              'shareCount': 0,
                              'createdAt': DateTime.now().toIso8601String(),
                              'updatedAt': DateTime.now().toIso8601String(),
                            });
                            final pollId = 'poll-$ts';
                            await Supabase.instance.client.from('Poll').insert({
                              'id': pollId,
                              'postId': postId,
                              'question': q,
                              'options': opts,
                              'totalVotes': 0,
                              if (pollMatchId != null) 'matchId': pollMatchId,
                              'createdAt': DateTime.now().toIso8601String(),
                            });
                            if (c.mounted) Navigator.pop(c);
                          } catch (e) {
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                SnackBar(content: Text(friendlyError(e))),
                              );
                            }
                          }
                          return;
                        }
                        if (postType == 'prediction') {
                          if (predMatchId == null && matches.isNotEmpty) {
                            ScaffoldMessenger.of(c).showSnackBar(
                              const SnackBar(content: Text('Select a match')),
                            );
                            return;
                          }
                          try {
                            final uid = Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) throw StateError('Sign in required');
                            // Resolve team names from selected match (if any)
                            String homeTeam = '';
                            String awayTeam = '';
                            if (predMatchId != null) {
                              final m = matches.firstWhere(
                                (m) => m['id'].toString() == predMatchId,
                                orElse: () => <String, dynamic>{},
                              );
                              homeTeam = (m['homeTeam'] ?? '').toString();
                              awayTeam = (m['awayTeam'] ?? '').toString();
                            }
                            final ph = int.tryParse(predHomeCtrl.text.trim()) ?? 0;
                            final pa = int.tryParse(predAwayCtrl.text.trim()) ?? 0;
                            final note = textCtrl.text.trim();
                            final content = note.isNotEmpty
                                ? note
                                : 'Prediction: $homeTeam $ph-$pa $awayTeam ($predWinner)';
                            final ts = DateTime.now().millisecondsSinceEpoch;
                            final postId = 'post-pred-$ts';
                            // #8.3 — Post + Prediction row.
                            await Supabase.instance.client.from('Post').insert({
                              'id': postId,
                              'userId': uid,
                              'postType': 'prediction',
                              'content': content,
                              'mediaUrls': const [],
                              'hashtags': const [],
                              'sportTag': 'football',
                              if (predMatchId != null) 'matchId': predMatchId,
                              'likeCount': 0,
                              'commentCount': 0,
                              'shareCount': 0,
                              'createdAt': DateTime.now().toIso8601String(),
                              'updatedAt': DateTime.now().toIso8601String(),
                            });
                            await Supabase.instance.client.from('Prediction').insert({
                              'id': 'pred-$ts',
                              'userId': uid,
                              'matchId': predMatchId,
                              'postId': postId,
                              'homeTeam': homeTeam,
                              'awayTeam': awayTeam,
                              'predictedHome': ph,
                              'predictedAway': pa,
                              'confidence': predWinner,
                              'createdAt': DateTime.now().toIso8601String(),
                            });
                            if (c.mounted) Navigator.pop(c);
                          } catch (e) {
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                SnackBar(content: Text(friendlyError(e))),
                              );
                            }
                          }
                          return;
                        }
                        try {
                          var pt = postType;
                          if (pt == 'text' && mediaUrls.isNotEmpty) {
                            final anyVid = mediaUrls.any((u) =>
                                u.toLowerCase().contains('.mp4') ||
                                u.toLowerCase().contains('/videos/'));
                            pt = anyVid ? 'video' : 'image';
                          }
                          await SocialRepository().createPost(
                            content: textCtrl.text.trim(),
                            postType: pt,
                            mediaUrls: mediaUrls,
                            teamTag: postType == 'welcome' ? teamId : null,
                          );
                          if (c.mounted) Navigator.pop(c);
                        } catch (e) {
                          if (c.mounted) {
                            ScaffoldMessenger.of(c).showSnackBar(
                                SnackBar(content: Text(friendlyError(e))));
                          }
                        }
                      },
                      child: const Text('Publish',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ── Per-match quick actions (#8.6) ────────────────────────────────────────────
// These three helpers are invoked from the per-match popup menu in _MatchesTab.
// They pre-fill match context (teams, league, matchId) so admins can quickly
// push a feed Post / Poll / Prediction linked to a fixture.

/// Push a feed Post (postType='match') linked to an existing Match row.
Future<void> _showPostMatchToFeed(BuildContext ctx, Map<String, dynamic> m) async {
  final bodyCtrl = TextEditingController(
      text: '${m['homeTeam']} vs ${m['awayTeam']} — ${m['league'] ?? ''}');
  bool confirmed = false;
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => StatefulBuilder(
      builder: (c, setL) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Post Match to Feed',
                  style: TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _AdminField(
                controller: bodyCtrl,
                label: 'Body *',
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: SportSphereColors.electricBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: confirmed
                      ? null
                      : () async {
                          setL(() => confirmed = true);
                          try {
                            final uid = Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) throw StateError('Sign in required');
                            final matchId = m['id']?.toString() ?? '';
                            await Supabase.instance.client.from('Post').insert({
                              'id': 'post-match-$matchId',
                              'userId': uid,
                              'postType': 'match',
                              'content': bodyCtrl.text.trim(),
                              'matchId': matchId,
                              'mediaUrls': const [],
                              'hashtags': const [],
                              'sportTag': 'football',
                              'isBreaking': false,
                              'likeCount': 0,
                              'commentCount': 0,
                              'shareCount': 0,
                              'createdAt': DateTime.now().toIso8601String(),
                              'updatedAt': DateTime.now().toIso8601String(),
                            });
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                                  content: Text('Posted to feed')));
                              Navigator.pop(c);
                            }
                          } catch (e) {
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                  SnackBar(content: Text(friendlyError(e))));
                            }
                            setL(() => confirmed = false);
                          }
                        },
                  child: const Text('Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Open a quick poll composer pre-filled with the match's title.
/// Writes both Post (postType=poll) and Poll rows linked via matchId.
Future<void> _showCreatePollForMatch(
    BuildContext ctx, Map<String, dynamic> m) async {
  final qCtrl = TextEditingController(
      text: 'Who wins? ${m['homeTeam']} vs ${m['awayTeam']}');
  final optCtrls = <TextEditingController>[
    TextEditingController(text: '${m['homeTeam'] ?? 'Home'}'),
    TextEditingController(text: '${m['awayTeam'] ?? 'Away'}'),
    TextEditingController(text: 'Draw'),
  ];
  bool posting = false;
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => StatefulBuilder(
      builder: (c, setL) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Poll',
                  style: TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _AdminField(controller: qCtrl, label: 'Question *', maxLines: 2),
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: Text('Options',
                    style: TextStyle(
                        color: SportSphereColors.muted, fontSize: 12)),
              ),
              for (var i = 0; i < optCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: _AdminField(
                          controller: optCtrls[i],
                          label: 'Option ${i + 1}'),
                    ),
                    if (optCtrls.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: SportSphereColors.danger, size: 20),
                        onPressed: () => setL(() {
                          optCtrls[i].dispose();
                          optCtrls.removeAt(i);
                        }),
                      ),
                  ]),
                ),
              if (optCtrls.length < 6)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add option'),
                    onPressed: () =>
                        setL(() => optCtrls.add(TextEditingController())),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: SportSphereColors.sportGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: posting
                      ? null
                      : () async {
                          final q = qCtrl.text.trim();
                          final opts = optCtrls
                              .map((ctrl) => ctrl.text.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          if (q.isEmpty || opts.length < 2) {
                            ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                                content: Text(
                                    'Question and at least 2 options required')));
                            return;
                          }
                          setL(() => posting = true);
                          try {
                            final uid =
                                Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) throw StateError('Sign in required');
                            final matchId = m['id']?.toString();
                            final ts = DateTime.now().millisecondsSinceEpoch;
                            final postId = 'post-poll-match-$ts';
                            await Supabase.instance.client.from('Post').insert({
                              'id': postId,
                              'userId': uid,
                              'postType': 'poll',
                              'content': q,
                              'mediaUrls': const [],
                              'hashtags': const [],
                              'sportTag': 'football',
                              if (matchId != null) 'matchId': matchId,
                              'likeCount': 0,
                              'commentCount': 0,
                              'shareCount': 0,
                              'createdAt': DateTime.now().toIso8601String(),
                              'updatedAt': DateTime.now().toIso8601String(),
                            });
                            await Supabase.instance.client.from('Poll').insert({
                              'id': 'poll-match-$ts',
                              'postId': postId,
                              'question': q,
                              'options': opts,
                              'totalVotes': 0,
                              if (matchId != null) 'matchId': matchId,
                              'createdAt': DateTime.now().toIso8601String(),
                            });
                            if (c.mounted) Navigator.pop(c);
                          } catch (e) {
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                SnackBar(content: Text(friendlyError(e))),
                              );
                            }
                            setL(() => posting = false);
                          }
                        },
                  child: const Text('Publish Poll'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  for (final ctrl in optCtrls) {
    ctrl.dispose();
  }
  qCtrl.dispose();
}

/// Open a quick prediction composer pre-filled with the match's teams.
/// Writes both Post (postType=prediction) and Prediction rows linked via matchId.
Future<void> _showCreatePredictionForMatch(
    BuildContext ctx, Map<String, dynamic> m) async {
  final homeCtrl = TextEditingController(text: '1');
  final awayCtrl = TextEditingController(text: '1');
  String winner = 'home';
  bool posting = false;
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: GrassForm.sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => StatefulBuilder(
      builder: (c, setL) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Predict: ${m['homeTeam']} vs ${m['awayTeam']}',
                style: const TextStyle(
                    color: SportSphereColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _AdminField(
                        controller: homeCtrl,
                        label: '${m['homeTeam'] ?? 'Home'} score',
                        keyboardType: TextInputType.number)),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':',
                        style: TextStyle(
                            color: SportSphereColors.white, fontSize: 20))),
                Expanded(
                    child: _AdminField(
                        controller: awayCtrl,
                        label: '${m['awayTeam'] ?? 'Away'} score',
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: Text('${m['homeTeam'] ?? 'Home'}'),
                  selected: winner == 'home',
                  onSelected: (_) => setL(() => winner = 'home'),
                ),
                ChoiceChip(
                  label: const Text('Draw'),
                  selected: winner == 'draw',
                  onSelected: (_) => setL(() => winner = 'draw'),
                ),
                ChoiceChip(
                  label: Text('${m['awayTeam'] ?? 'Away'}'),
                  selected: winner == 'away',
                  onSelected: (_) => setL(() => winner = 'away'),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: SportSphereColors.sportOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: posting
                      ? null
                      : () async {
                          setL(() => posting = true);
                          try {
                            final uid =
                                Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) throw StateError('Sign in required');
                            final matchId = m['id']?.toString();
                            final homeTeam = (m['homeTeam'] ?? '').toString();
                            final awayTeam = (m['awayTeam'] ?? '').toString();
                            final ph = int.tryParse(homeCtrl.text.trim()) ?? 0;
                            final pa = int.tryParse(awayCtrl.text.trim()) ?? 0;
                            final content =
                                'Prediction: $homeTeam $ph-$pa $awayTeam ($winner)';
                            final ts = DateTime.now().millisecondsSinceEpoch;
                            final postId = 'post-pred-match-$ts';
                            await Supabase.instance.client.from('Post').insert({
                              'id': postId,
                              'userId': uid,
                              'postType': 'prediction',
                              'content': content,
                              'mediaUrls': const [],
                              'hashtags': const [],
                              'sportTag': 'football',
                              if (matchId != null) 'matchId': matchId,
                              'likeCount': 0,
                              'commentCount': 0,
                              'shareCount': 0,
                              'createdAt': DateTime.now().toIso8601String(),
                              'updatedAt': DateTime.now().toIso8601String(),
                            });
                            await Supabase.instance.client
                                .from('Prediction')
                                .insert({
                              'id': 'pred-match-$ts',
                              'userId': uid,
                              'matchId': matchId,
                              'postId': postId,
                              'homeTeam': homeTeam,
                              'awayTeam': awayTeam,
                              'predictedHome': ph,
                              'predictedAway': pa,
                              'confidence': winner,
                              'createdAt': DateTime.now().toIso8601String(),
                            });
                            if (c.mounted) Navigator.pop(c);
                          } catch (e) {
                            if (c.mounted) {
                              ScaffoldMessenger.of(c).showSnackBar(
                                SnackBar(content: Text(friendlyError(e))),
                              );
                            }
                            setL(() => posting = false);
                          }
                        },
                  child: const Text('Publish Prediction'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  homeCtrl.dispose();
  awayCtrl.dispose();
}

// ── Upload Button widget ───────────────────────────────────────────────────────
class _UploadButton extends StatelessWidget {
  final String? url;
  final bool uploading;
  final String label;
  final VoidCallback onTap;
  const _UploadButton({
    required this.url,
    required this.uploading,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GrassUploadTile(
      url: url,
      uploading: uploading,
      label: label,
      onTap: onTap,
    );
  }
}


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
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _AdminField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return GrassTextField(
      controller: controller,
      label: label,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
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

// ══════════════════════════════════════════════════════════════════════════════
// PRO QUEUE TAB
// ══════════════════════════════════════════════════════════════════════════════

class _ProQueueTab extends StatefulWidget {
  const _ProQueueTab();
  @override
  State<_ProQueueTab> createState() => _ProQueueTabState();
}

class _ProQueueTabState extends State<_ProQueueTab> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final sb = Supabase.instance.client;
    final results = <Map<String, dynamic>>[];

    // RoleRequest table (PRO requests from Become Pro sheet)
    try {
      final rows = await sb.from('RoleRequest')
          .select('id, userId, requestedRole, status, notes, createdAt')
          .eq('status', 'pending')
          .order('createdAt', ascending: false)
          .limit(50);
      results.addAll((rows as List).cast<Map<String, dynamic>>()
          .map((r) => {...r, '_source': 'RoleRequest'}));
    } catch (_) {}

    // Claim table (entity claims)
    try {
      final rows = await sb.from('ClaimRequest')
          .select('id, claimantId, profileType, profileName, status, evidenceNotes, createdAt')
          .eq('status', 'pending')
          .order('createdAt', ascending: false)
          .limit(50);
      results.addAll((rows as List).cast<Map<String, dynamic>>()
          .map((r) => {...r, '_source': 'ClaimRequest'}));
    } catch (_) {}

    results.sort((a, b) {
      final aD = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
      final bD = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
      return bD.compareTo(aD);
    });

    if (mounted) setState(() { _requests = results; _loading = false; });
  }

  Future<void> _decide(Map<String, dynamic> req, String status) async {
    final sb = Supabase.instance.client;
    final src = req['_source'] as String;
    final id  = req['id']?.toString() ?? '';
    try {
      if (src == 'RoleRequest') {
        await sb.from('RoleRequest').update({
          'status': status,
          'reviewedAt': DateTime.now().toIso8601String(),
        }).eq('id', id);
        if (status == 'approved') {
          final uid  = req['userId']?.toString() ?? '';
          final role = req['requestedRole']?.toString() ?? '';
          if (uid.isNotEmpty && role.isNotEmpty) {
            await sb.from('profiles').update({'role': role}).eq('id', uid);
            try { await sb.from('User').update({'role': role}).eq('id', uid); } catch (_) {}
          }
        }
      } else {
        await sb.from('ClaimRequest').update({
          'status': status,
          'reviewedAt': DateTime.now().toIso8601String(),
        }).eq('id', id);
      }
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'approved' ? '✓ Approved and role activated' : 'Rejected')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Text('${_requests.length} pending',
              style: const TextStyle(color: SportSphereColors.muted, fontSize: 13)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: SportSphereColors.muted, size: 20),
            onPressed: _load,
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const _Loader()
            : _requests.isEmpty
                ? const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_rounded, color: SportSphereColors.muted, size: 48),
                      SizedBox(height: 12),
                      Text('No pending PRO requests',
                          style: TextStyle(color: SportSphereColors.muted)),
                    ]))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: SportSphereColors.electricBlue,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      itemCount: _requests.length,
                      separatorBuilder: (_, __) => const _Div(),
                      itemBuilder: (_, i) {
                        final r   = _requests[i];
                        final src = r['_source'] as String;
                        final isRole = src == 'RoleRequest';
                        final role   = isRole ? r['requestedRole'] ?? '' : r['profileType'] ?? '';
                        final notes  = isRole ? r['notes'] ?? '' : r['evidenceNotes'] ?? '';
                        final uid    = isRole ? r['userId'] ?? '' : r['claimantId'] ?? '';
                        final created = DateTime.tryParse(r['createdAt']?.toString() ?? '');

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF071422),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              _Chip(role.toString().toUpperCase(), SportSphereColors.electricBlue),
                              const SizedBox(width: 6),
                              _Chip(src, SportSphereColors.muted),
                              const Spacer(),
                              if (created != null)
                                Text('${created.day}/${created.month}/${created.year}',
                                    style: const TextStyle(color: SportSphereColors.muted, fontSize: 11)),
                            ]),
                            const SizedBox(height: 8),
                            Text('User: ${uid.toString().length > 24 ? '${uid.toString().substring(0, 24)}…' : uid}',
                                style: const TextStyle(color: SportSphereColors.muted, fontSize: 12)),
                            if (notes.toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(notes.toString(),
                                  style: const TextStyle(color: SportSphereColors.white, fontSize: 13, height: 1.4)),
                            ],
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: SportSphereColors.danger,
                                  side: BorderSide(color: SportSphereColors.danger.withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _decide(r, 'rejected'),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Reject'),
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: SportSphereColors.sportGreen,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _decide(r, 'approved'),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Approve'),
                              )),
                            ]),
                          ]),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
  );
}
