import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class StudentToolsScreen extends StatelessWidget {
  final int? applicationId;

  const StudentToolsScreen({super.key, this.applicationId});

  @override
  Widget build(BuildContext context) {
    final isLeader = Api.user?['student_group_role'] != 'member';
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: isLeader ? 'Find members' : 'Find a group'),
                const Tab(text: 'Requests'),
                const Tab(text: 'Waitlist'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _GroupDiscoveryTab(applicationId: applicationId),
                const _StudentRequestsTab(),
                const _StudentWaitlistTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupDiscoveryTab extends StatefulWidget {
  final int? applicationId;

  const _GroupDiscoveryTab({this.applicationId});

  @override
  State<_GroupDiscoveryTab> createState() => _GroupDiscoveryTabState();
}

class _GroupDiscoveryTabState extends State<_GroupDiscoveryTab> {
  final _query = TextEditingController();
  List<dynamic> _results = [];
  bool _leader = true;
  bool _searched = false;
  bool _loading = false;
  final Set<int> _busyIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _leader = Api.user?['student_group_role'] != 'member';
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'Enter a keyword, name, or email to search.';
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = _leader
          ? await Api.availableGroupMembers(query)
          : await Api.availableGroups(query);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(Map<String, dynamic> item) async {
    final id = item['user_id'] as int? ?? item['leader_id'] as int?;
    if (id == null) {
      snack(context, 'Could not identify this student group.', error: true);
      return;
    }
    setState(() => _busyIds.add(id));
    try {
      await Api.createStudentGroupRequest(id);
      if (!mounted) return;
      snack(context, _leader
          ? 'Group request sent.'
          : 'Join request sent to the group leader.');
      setState(() => _results.removeWhere((result) =>
          (result['user_id'] ?? result['leader_id']) == id));
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_leader ? 'Find group members' : 'Find a project group',
              style: context.text2xl.copyWith(
                  color: context.textColor, fontWeight: FontWeight.w800)),
          Text(
            _leader
                ? 'Search students by name, email, project title, or research interest.'
                : 'Search groups by project topic, group leader, or adviser.',
            style: TextStyle(color: context.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: _leader
                        ? 'Topic, student name, or email'
                        : 'Topic, leader name, or email',
                    suffixIcon: IconButton(
                      onPressed: _loading ? null : _search,
                      tooltip: 'Search',
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: context.errorColor())),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                _searched ? 'No matching results found.' : 'Search to see results.',
                style: TextStyle(color: context.textMuted),
              ),
            )
          else
            for (final raw in _results)
              _leader ? _memberCard(Map<String, dynamic>.from(raw as Map)) :
                _groupCard(Map<String, dynamic>.from(raw as Map)),
          if (widget.applicationId != null) ...[
            const SizedBox(height: 16),
            _GroupManagementCard(applicationId: widget.applicationId!),
          ],
        ],
      );

  Widget _memberCard(Map<String, dynamic> member) {
    final id = member['user_id'] as int;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _Avatar(
                  name: '${member['name'] ?? ''}',
                  photo: member['profile_photo'] as String?),
              title: Text('${member['name'] ?? 'Student'}'),
              subtitle: Text('${member['email'] ?? ''}'),
              trailing: Text(
                '${member['matched_by'] ?? 'Match'}',
                style: context.textXs.copyWith(color: context.textMuted),
              ),
            ),
            Text('${member['thesis_title'] ?? ''}',
                style: context.textSm.copyWith(color: context.textColor)),
            if ('${member['research_interests'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Interests: ${member['research_interests']}',
                    style: TextStyle(color: context.textMuted)),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busyIds.contains(id) ? null : () => _request(member),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(_busyIds.contains(id) ? 'Sending…' : 'Request student'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(Map<String, dynamic> group) {
    final id = group['leader_id'] as int;
    final memberCount = group['member_count'] as int? ?? 1;
    final reserved = group['reserved_count'] as int? ?? 0;
    final full = memberCount + reserved >= 4;
    final pending = group['has_pending_request'] == true ||
        group['has_pending_invitation'] == true;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _Avatar(
                  name: '${group['leader_name'] ?? ''}',
                  photo: group['leader_profile_photo'] as String?),
              title: Text('${group['leader_name'] ?? 'Group leader'}'),
              subtitle: Text(
                  '${group['adviser_name'] ?? 'No approved adviser yet'}'),
              trailing: Text('$memberCount/4',
                  style: context.textSm.copyWith(
                      color: context.textMuted, fontWeight: FontWeight.w700)),
            ),
            Text('${group['topic_brief'] ?? ''}',
                style: context.textSm.copyWith(color: context.textColor)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: full || pending || _busyIds.contains(id)
                    ? null
                    : () => _request(group),
                icon: const Icon(Icons.group_add_outlined),
                label: Text(full
                    ? 'Group is full'
                    : pending
                        ? 'Request pending'
                        : _busyIds.contains(id)
                            ? 'Sending…'
                            : 'Request to join'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRequestsTab extends StatefulWidget {
  const _StudentRequestsTab();

  @override
  State<_StudentRequestsTab> createState() => _StudentRequestsTabState();
}

class _StudentRequestsTabState extends State<_StudentRequestsTab> {
  List<dynamic> _applications = [];
  List<dynamic> _groupRequests = [];
  List<dynamic> _invitations = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        Api.applications(),
        Api.studentGroupRequests(),
        Api.groupInvitations(),
      ]);
      if (!mounted) return;
      setState(() {
        _applications = results[0] as List<dynamic>;
        _groupRequests = results[1] as List<dynamic>;
        _invitations = results[2] as List<dynamic>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _respondGroupRequest(
      Map<String, dynamic> request, String decision) async {
    final id = request['request_id'] as int;
    await _run(id, () => Api.decideStudentGroupRequest(id, decision),
        'Group request ${decision == 'approved' ? 'accepted' : 'declined'}.');
  }

  Future<void> _respondInvitation(
      Map<String, dynamic> invitation, bool accept) async {
    final id = invitation['invitation_id'] as int;
    await _run(
      id,
      () => accept
          ? Api.acceptGroupInvitation(id)
          : Api.declineGroupInvitation(id),
      accept ? 'You joined the project group.' : 'Invitation declined.',
    );
  }

  Future<void> _withdraw(Map<String, dynamic> application) async {
    final id = application['application_id'] as int;
    await _run(id, () => Api.withdraw(id), 'Application withdrawn.');
  }

  Future<void> _run(int id, Future<void> Function() action, String message) async {
    setState(() => _busy.add(id));
    try {
      await action();
      await _load();
      if (mounted) snack(context, message);
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Requests & invitations',
              style: context.text2xl.copyWith(
                  color: context.textColor, fontWeight: FontWeight.w800)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: context.errorColor())),
            ),
          const SizedBox(height: 12),
          _sectionTitle(context, 'Adviser applications'),
          if (_applications.isEmpty)
            _empty(context, 'No adviser applications yet.')
          else
            for (final raw in _applications)
              _applicationCard(Map<String, dynamic>.from(raw as Map)),
          const SizedBox(height: 16),
          _sectionTitle(context, 'Group requests'),
          if (_groupRequests.isEmpty)
            _empty(context, 'No group requests yet.')
          else
            for (final raw in _groupRequests)
              _groupRequestCard(Map<String, dynamic>.from(raw as Map)),
          const SizedBox(height: 16),
          _sectionTitle(context, 'Project group invitations'),
          if (_invitations.isEmpty)
            _empty(context, 'No project group invitations.')
          else
            for (final raw in _invitations)
              _invitationCard(Map<String, dynamic>.from(raw as Map)),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: context.textLg.copyWith(
                color: context.textColor, fontWeight: FontWeight.w700)),
      );

  Widget _empty(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(color: context.textMuted)),
      );

  Widget _applicationCard(Map<String, dynamic> application) {
    final id = application['application_id'] as int;
    final pending = application['status'] == 'pending';
    final adviserName = '${application['adviser_name'] ?? 'Adviser'}';
    return Card(
      child: ListTile(
        title: Text(adviserName),
        subtitle: Text('${application['topic_brief'] ?? ''}'),
        trailing: pending
            ? TextButton(
                onPressed: _busy.contains(id) ? null : () => _withdraw(application),
                child: Text(_busy.contains(id) ? 'Withdrawing…' : 'Withdraw'),
              )
            : Chip(label: Text('${application['status']}')),
      ),
    );
  }

  Widget _groupRequestCard(Map<String, dynamic> request) {
    final id = request['request_id'] as int;
    final incoming = request['can_decide'] == true ||
        request['can_decide'] == 1;
    final approved = request['status'] == 'approved';
    final memberRequest = request['requested_by'] == 'member';
    final userId = Api.user?['user_id'];
    final partner = request['other_name'] ??
        (request['leader_id'] == userId
            ? request['member_name']
            : request['leader_name']);
    final description = approved
        ? memberRequest
            ? '$partner joined your group'
            : 'You joined $partner’s group'
        : incoming
            ? memberRequest
                ? '$partner wants to join your group'
                : '$partner invited you to join a group'
            : 'Group request sent to $partner';
    return Card(
      child: ListTile(
        title: Text('$description'),
        subtitle: Text('${request['status']}'),
        trailing: incoming && request['status'] == 'pending'
            ? Wrap(
                children: [
                  IconButton(
                    onPressed: _busy.contains(id)
                        ? null
                        : () => _respondGroupRequest(request, 'approved'),
                    tooltip: 'Accept',
                    icon: const Icon(Icons.check),
                  ),
                  IconButton(
                    onPressed: _busy.contains(id)
                        ? null
                        : () => _respondGroupRequest(request, 'declined'),
                    tooltip: 'Decline',
                    icon: const Icon(Icons.close),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _invitationCard(Map<String, dynamic> invitation) {
    final id = invitation['invitation_id'] as int;
    return Card(
      child: ListTile(
        title: Text('${invitation['invited_by_name']} invited you'),
        subtitle: Text(
            '${invitation['adviser_name'] ?? 'Project group'} · ${invitation['topic_brief'] ?? ''}'),
        trailing: Wrap(
          children: [
            IconButton(
              onPressed:
                  _busy.contains(id) ? null : () => _respondInvitation(invitation, true),
              tooltip: 'Accept invitation',
              icon: const Icon(Icons.check),
            ),
            IconButton(
              onPressed:
                  _busy.contains(id) ? null : () => _respondInvitation(invitation, false),
              tooltip: 'Decline invitation',
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupManagementCard extends StatefulWidget {
  final int applicationId;

  const _GroupManagementCard({required this.applicationId});

  @override
  State<_GroupManagementCard> createState() => _GroupManagementCardState();
}

class _GroupManagementCardState extends State<_GroupManagementCard> {
  List<dynamic> _members = [];
  List<dynamic> _invitations = [];
  List<dynamic> _joinRequests = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  bool get _isLeader => _members.any((raw) {
        final member = Map<String, dynamic>.from(raw as Map);
        final isLeader = member['is_leader'] == true || member['is_leader'] == 1;
        return isLeader && member['student_id'] == Api.user?['user_id'];
      });

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await Api.groupMembers(widget.applicationId);
      var invitations = <dynamic>[];
      var requests = <dynamic>[];
      final currentUserId = Api.user?['user_id'];
      final isLeader = members.any((raw) {
        final member = Map<String, dynamic>.from(raw as Map);
        return (member['is_leader'] == true || member['is_leader'] == 1) &&
            member['student_id'] == currentUserId;
      });
      if (isLeader) {
        final results = await Future.wait<dynamic>([
          Api.groupInvitationsForApplication(widget.applicationId),
          Api.groupJoinRequests(widget.applicationId),
        ]);
        invitations = results[0] as List<dynamic>;
        requests = results[1] as List<dynamic>;
      }
      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = invitations;
        _joinRequests = requests;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _invite() async {
    final email = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite a student'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Student email'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, email.text.trim()),
              child: const Text('Send invitation')),
        ],
      ),
    );
    email.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await Api.inviteGroupMember(widget.applicationId, value);
      await _load();
      if (mounted) snack(context, 'Invitation sent.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _act(
      int id, Future<void> Function() action, String message) async {
    setState(() => _busy.add(id));
    try {
      await action();
      await _load();
      if (mounted) snack(context, message);
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Current project group',
                    style: context.textLg.copyWith(
                        color: context.textColor,
                        fontWeight: FontWeight.w700)),
              ),
              if (_isLeader &&
                  _members.length + _invitations.length + _joinRequests.length <
                      4)
                IconButton(
                  onPressed: _invite,
                  tooltip: 'Invite a student',
                  icon: const Icon(Icons.person_add_alt_1),
                ),
            ],
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: context.errorColor()))
          else if (_members.isEmpty)
            Text('No group members yet.',
                style: TextStyle(color: context.textMuted))
          else
            for (final raw in _members)
              _memberTile(Map<String, dynamic>.from(raw as Map)),
          if (_invitations.isNotEmpty) ...[
            const Divider(),
            const Text('Pending invitations',
                style: TextStyle(fontWeight: FontWeight.w700)),
            for (final raw in _invitations)
              _pendingInvitation(Map<String, dynamic>.from(raw as Map)),
          ],
          if (_joinRequests.isNotEmpty) ...[
            const Divider(),
            const Text('Join requests',
                style: TextStyle(fontWeight: FontWeight.w700)),
            for (final raw in _joinRequests)
              _joinRequest(Map<String, dynamic>.from(raw as Map)),
          ],
          if (_isLeader)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Group capacity: maximum 4 students.',
                  style: context.textXs.copyWith(color: context.textMuted)),
            ),
        ],
      ),
    );
  }

  Widget _memberTile(Map<String, dynamic> member) {
    final groupId = member['group_id'] as int?;
    final isSelf = member['student_id'] == Api.user?['user_id'];
    final isLeader = member['is_leader'] == true || member['is_leader'] == 1;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _Avatar(
          name: '${member['name'] ?? ''}',
          photo: member['profile_photo'] as String?),
      title: Text('${member['name'] ?? 'Student'}'),
      subtitle: Text(isLeader ? 'Group leader' : 'Group member'),
      trailing: _isLeader && !isSelf && groupId != null
          ? IconButton(
              onPressed: _busy.contains(groupId)
                  ? null
                  : () => _act(
                        groupId,
                        () => Api.removeGroupMember(groupId),
                        'Group member removed.',
                      ),
              tooltip: 'Remove member',
              icon: const Icon(Icons.person_remove_outlined),
            )
          : null,
    );
  }

  Widget _pendingInvitation(Map<String, dynamic> invitation) {
    final id = invitation['invitation_id'] as int;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${invitation['student_name'] ?? 'Student'}'),
      subtitle: Text('${invitation['email'] ?? ''}'),
      trailing: IconButton(
        onPressed: _busy.contains(id)
            ? null
            : () => _act(
                  id,
                  () => Api.cancelGroupInvitation(id),
                  'Invitation cancelled.',
                ),
        tooltip: 'Cancel invitation',
        icon: const Icon(Icons.close),
      ),
    );
  }

  Widget _joinRequest(Map<String, dynamic> request) {
    final id = request['request_id'] as int;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${request['student_name'] ?? 'Student'}'),
      subtitle: Text('${request['student_email'] ?? ''}'),
      trailing: Wrap(
        children: [
          IconButton(
            onPressed: _busy.contains(id)
                ? null
                : () => _act(
                      id,
                      () => Api.decideGroupJoinRequest(id, 'approved'),
                      'Student joined the group.',
                    ),
            tooltip: 'Approve request',
            icon: const Icon(Icons.check),
          ),
          IconButton(
            onPressed: _busy.contains(id)
                ? null
                : () => _act(
                      id,
                      () => Api.decideGroupJoinRequest(id, 'declined'),
                      'Join request declined.',
                    ),
            tooltip: 'Decline request',
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _StudentWaitlistTab extends StatefulWidget {
  const _StudentWaitlistTab();

  @override
  State<_StudentWaitlistTab> createState() => _StudentWaitlistTabState();
}

class _StudentWaitlistTabState extends State<_StudentWaitlistTab> {
  List<dynamic> _entries = [];
  List<dynamic> _fullAdvisers = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        Api.myWaitlist(),
        Api.advisers(''),
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<dynamic>;
        _fullAdvisers = (results[1] as List<dynamic>)
            .where((item) => item['slots_left'] == 0)
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _join() async {
    if (Api.user?['student_group_role'] == 'member') {
      snack(context, 'Only group leaders can join an adviser waitlist.',
          error: true);
      return;
    }
    int? adviserId;
    String? topic = Api.user?['thesis_title'] as String?;
    final topicController = TextEditingController(text: topic ?? '');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Join adviser waitlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: adviserId,
                decoration: const InputDecoration(labelText: 'Full adviser'),
                items: _fullAdvisers
                    .map((raw) => Map<String, dynamic>.from(raw as Map))
                    .map((adviser) => DropdownMenuItem<int>(
                          value: adviser['adviser_id'] as int,
                          child: Text('${adviser['name']}',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => adviserId = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: topicController,
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                    labelText: 'Thesis / capstone topic',
                    alignLabelWithHint: true),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: adviserId == null ||
                      topicController.text.trim().length < 10
                  ? null
                  : () => Navigator.pop(dialogContext, adviserId),
              child: const Text('Join waitlist'),
            ),
          ],
        ),
      ),
    );
    topic = topicController.text.trim();
    topicController.dispose();
    if (result == null) return;
    try {
      await Api.joinWaitlist(result, topic ?? '');
      await _load();
      if (mounted) snack(context, 'Added to waitlist.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _cancel(Map<String, dynamic> entry) async {
    final id = entry['waitlist_id'] as int;
    setState(() => _busy.add(id));
    try {
      await Api.cancelWaitlist(id);
      await _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (Api.user?['student_group_role'] == 'member') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Only group leaders can request an adviser waitlist.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('My waitlist',
                    style: context.text2xl.copyWith(
                        color: context.textColor,
                        fontWeight: FontWeight.w800)),
              ),
              IconButton.filled(
                onPressed: _fullAdvisers.isEmpty ? null : _join,
                tooltip: 'Join a waitlist',
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: context.errorColor())),
          if (_fullAdvisers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No advisers are currently full.',
                  style: TextStyle(color: context.textMuted)),
            ),
          if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('You are not on any waitlists.',
                  style: TextStyle(color: context.textMuted)),
            )
          else
            for (final raw in _entries)
              _entryCard(Map<String, dynamic>.from(raw as Map)),
        ],
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final id = entry['waitlist_id'] as int;
    final waiting = entry['status'] == 'waiting';
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: ListTile(
        leading: CircleAvatar(child: Text('#${entry['position'] ?? '-'}')),
        title: Text('${entry['adviser_name'] ?? 'Adviser'}'),
        subtitle: Text('${entry['topic_brief'] ?? ''}\n${entry['status']}'),
        isThreeLine: true,
        trailing: waiting
            ? IconButton(
                onPressed: _busy.contains(id) ? null : () => _cancel(entry),
                tooltip: 'Cancel waitlist entry',
                icon: const Icon(Icons.close),
              )
            : null,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photo;

  const _Avatar({required this.name, this.photo});

  @override
  Widget build(BuildContext context) {
    final image = photo == null || photo!.isEmpty
        ? null
        : photo!.startsWith('http')
            ? photo!
            : '${Api.baseUrl}${photo!.startsWith('/') ? '' : '/'}$photo';
    return CircleAvatar(
      backgroundColor: context.brandPrimary.withValues(alpha: 0.15),
      backgroundImage: image == null ? null : NetworkImage(image),
      child: image == null
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(color: context.brandPrimary))
          : null,
    );
  }
}
