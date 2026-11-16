import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Lahat ng pakikipag-usap sa Python API ay dumadaan dito (parehong API ng web).
class Api {
  // Configure production/mobile deployments with --dart-define=API_BASE_URL=https://api.example.edu
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : (kIsWeb ? 'http://localhost:8001' : 'http://10.0.2.2:8001');
  static String? token;
  static Map<String, dynamic>? user;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final savedBaseUrl = p.getString('base_url');
    baseUrl = _configuredBaseUrl.isNotEmpty
        ? _configuredBaseUrl
        : savedBaseUrl ?? baseUrl;
    token = p.getString('token');
  }

  static Future<void> setBaseUrl(String v) async {
    baseUrl = v.trim().replaceAll(RegExp(r'/+$'), '');
    final p = await SharedPreferences.getInstance();
    await p.setString('base_url', baseUrl);
  }

  static Future<void> setToken(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove('token');
    } else {
      await p.setString('token', t);
    }
  }

  static Future<void> logout() async {
    user = null;
    await setToken(null);
  }

  static String _readError(dynamic data) {
    if (data is Map && data['detail'] is String)
      return data['detail'] as String;
    if (data is Map &&
        data['detail'] is List &&
        (data['detail'] as List).isNotEmpty) {
      final e = (data['detail'] as List).first;
      if (e is Map) {
        final loc = e['loc'] is List && (e['loc'] as List).isNotEmpty
            ? '${(e['loc'] as List).last}'
            : '';
        if (loc == 'password' && e['type'] == 'string_too_short')
          return 'Your password needs at least 8 characters.';
        if (loc == 'email') return 'Enter a valid email address.';
        if (loc == 'topic_brief')
          return 'Describe your topic in at least 10 characters.';
        return '${e['msg']}'.replaceFirst('Value error, ', '');
      }
    }
    return 'Something went wrong. Please try again.';
  }

  static Future<dynamic> _req(String method, String path,
      {Map<String, dynamic>? body,
      Map<String, String>? query,
      bool auth = true}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth && token != null) 'Authorization': 'Bearer $token',
    };
    http.Response res;
    try {
      switch (method) {
        case 'POST':
          res = await http
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          res = await http
              .put(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
          break;
        case 'PATCH':
          res = await http
              .patch(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          res = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        default:
          res = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
      }
    } on TimeoutException {
      throw ApiException(
          'The server is taking too long to respond. Check that the API is running and the server address is correct.');
    } catch (_) {
      throw ApiException(
          'Cannot reach the server. Check the server address and that the API is running.');
    }
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = {};
    }
    if (res.statusCode >= 400) throw ApiException(_readError(data));
    return data;
  }

  // ---- auth
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final d = await _req('POST', '/api/login',
        body: {'email': email, 'password': password}, auth: false);
    await setToken(d['token'] as String);
    user = Map<String, dynamic>.from(d['user'] as Map);
    return user!;
  }

  static Future<Map<String, dynamic>> register(
          String name, String email, String password, String confirm,
          {String role = 'student',
          String studentGroupRole = 'leader',
          String? department,
          String? profilePhoto}) async =>
      Map<String, dynamic>.from(await _req('POST', '/api/register',
          body: {
            'name': name,
            'email': email,
            'password': password,
            'confirm_password': confirm,
            'role': role,
            if (role == 'student') 'student_group_role': studentGroupRole,
            if (role == 'adviser') 'department': department,
            if (profilePhoto != null) 'profile_photo': profilePhoto,
          },
          auth: false) as Map);

  static Future<void> verifyEmail(String token) async {
    await _req('POST', '/api/auth/verify-email',
        body: {'token': token}, auth: false);
  }

  static Future<void> resendVerification(String email) async {
    await _req('POST', '/api/auth/resend-verification',
        body: {'email': email}, auth: false);
  }

  static Future<Map<String, dynamic>> getDevToken(
          String email, String purpose) async =>
      Map<String, dynamic>.from(
        await _req('GET', '/api/auth/dev-token',
            query: {'email': email, 'purpose': purpose}, auth: false) as Map,
      );

  static Future<Map<String, dynamic>> me() async {
    final d = await _req('GET', '/api/me');
    user = Map<String, dynamic>.from(d as Map);
    return user!;
  }

  static Future<void> updateMe(String name, String contact,
      {String? thesisTitle, String? researchInterests}) async {
    final d = await _req('PUT', '/api/me', body: {
      'name': name,
      'contact_number': contact,
      if (thesisTitle != null) 'thesis_title': thesisTitle,
      if (researchInterests != null) 'research_interests': researchInterests,
    });
    user = Map<String, dynamic>.from(d as Map);
  }

  static Future<void> updatePhoto(String base64Image) async {
    final result =
        await _req('POST', '/api/me/photo', body: {'image': base64Image})
            as Map;
    if (user != null) user = {...user!, 'profile_photo': result['photo_url']};
  }

  static Future<void> deletePhoto() async {
    await _req('DELETE', '/api/me/photo');
    if (user != null) user = {...user!, 'profile_photo': null};
  }

  static Future<void> changePassword(
      String current, String newPass, String confirm) async {
    await _req('POST', '/api/me/password', body: {
      'current_password': current,
      'new_password': newPass,
      'confirm_password': confirm
    });
  }

  // ---- advisers / applications
  static Future<List<dynamic>> advisers(String q) async =>
      await _req('GET', '/api/advisers', query: {'q': q}) as List<dynamic>;
  static Future<List<dynamic>> availableAdvisers() async => await advisers('');
  static Future<void> apply(int adviserId, String brief) async =>
      await _req('POST', '/api/applications',
          body: {'adviser_id': adviserId, 'topic_brief': brief});
  static Future<List<dynamic>> applications() async =>
      await _req('GET', '/api/applications') as List<dynamic>;
  static Future<void> withdraw(int id) async =>
      await _req('DELETE', '/api/applications/$id');

  // ---- bookings
  static Future<List<dynamic>> slots(int adviserId, String date) async =>
      await _req('GET', '/api/advisers/$adviserId/slots',
          query: {'start': date, 'end': date}) as List<dynamic>;
  static Future<List<dynamic>> slotsRange(
          int adviserId, String start, String end) async =>
      await _req('GET', '/api/advisers/$adviserId/slots',
          query: {'start': start, 'end': end}) as List<dynamic>;
  // Ang student ay pumipili lang ng petsa/oras. Ang adviser ang magse-set ng online/in-person at location.
  static Future<void> book(
          int adviserId, String date, String start, String notes) async =>
      await _req('POST', '/api/bookings', body: {
        'adviser_id': adviserId,
        'slot_date': date,
        'start_time': start,
        'notes': notes,
      });
  static Future<List<dynamic>> bookings(String start, String end) async =>
      await _req('GET', '/api/bookings', query: {'start': start, 'end': end})
          as List<dynamic>;
  static Future<void> setMeeting(
          int bookingId, String meetingType, String location) async =>
      await _req('PATCH', '/api/bookings/$bookingId/meeting',
          body: {'meeting_type': meetingType, 'location': location});
  static Future<void> acceptMeeting(int bookingId) async =>
      await _req('POST', '/api/bookings/$bookingId/accept-meeting');
  static Future<void> completeBooking(int bookingId) async =>
      await _req('POST', '/api/bookings/$bookingId/complete');
  static Future<void> cancelBooking(int id, String reason) async =>
      await _req('POST', '/api/bookings/$id/cancel', body: {'reason': reason});
  static Future<void> rescheduleBooking(
          int id, String date, String start) async =>
      await _req('POST', '/api/bookings/$id/reschedule',
          body: {'slot_date': date, 'start_time': start});
  static Future<Uint8List> downloadIcs(int bookingId) async =>
      _downloadBytes('/api/bookings/$bookingId/calendar.ics');

  // ---- Sprint 3: matalinong features
  static Future<List<dynamic>> attention() async =>
      await _req('GET', '/api/attention') as List<dynamic>;
  static Future<List<dynamic>> nextSlots(int adviserId) async =>
      await _req('GET', '/api/advisers/$adviserId/next-slots',
          query: {'limit': '6'}) as List<dynamic>;
  static Future<void> rate(int bookingId, int stars, String comment) async =>
      await _req('POST', '/api/bookings/$bookingId/rating',
          body: {'stars': stars, 'comment': comment});

  // ---- status (ano ang dapat ipakita sa UI)
  static Future<Map<String, dynamic>> status() async =>
      Map<String, dynamic>.from(await _req('GET', '/api/status') as Map);

  // ---- adviser and admin workspaces
  static Future<Map<String, dynamic>> analytics() async =>
      Map<String, dynamic>.from(await _req('GET', '/api/analytics') as Map);
  static Future<List<dynamic>> analyticsDetails(String category) async =>
      await _req(
        'GET',
        '/api/analytics/details/${Uri.encodeComponent(category)}',
      ) as List<dynamic>;
  static Future<Map<String, dynamic>> adminUsers({
    String query = '',
    String role = '',
    String status = '',
    int limit = 100,
  }) async =>
      Map<String, dynamic>.from(
        await _req('GET', '/api/admin/users', query: {
          'q': query,
          'role': role,
          'status': status,
          'limit': '$limit',
        }) as Map,
      );
  static Future<void> setUserStatus(int userId, String status) async =>
      await _req('PATCH', '/api/admin/users/$userId/status',
          body: {'status': status});
  static Future<List<dynamic>> adminAuditLogs({int limit = 100}) async =>
      await _req('GET', '/api/admin/audit-logs', query: {'limit': '$limit'})
          as List<dynamic>;
  static Future<List<dynamic>> adminMessageThreads() async =>
      await _req('GET', '/api/admin/messages') as List<dynamic>;
  static Future<Map<String, dynamic>> adminMessages(int applicationId,
          {int? targetMessageId}) async =>
      Map<String, dynamic>.from(
        await _req('GET', '/api/admin/messages/$applicationId', query: {
          if (targetMessageId != null) 'target_message_id': '$targetMessageId',
        }) as Map,
      );
  static Future<void> sendAdminMessage(int applicationId, String body) async =>
      await _req('POST', '/api/admin/messages/$applicationId',
          body: {'body': body});

  // ---- notifications
  static Future<Map<String, dynamic>> notifications({int limit = 30}) async =>
      Map<String, dynamic>.from(
          await _req('GET', '/api/notifications', query: {'limit': '$limit'})
              as Map);
  static Future<void> readOne(int id) async =>
      await _req('POST', '/api/notifications/$id/read');
  static Future<void> readAll() async =>
      await _req('POST', '/api/notifications/read-all');

  // ---- messages
  static Future<List<dynamic>> messages(int applicationId,
          {int limit = 50, int? targetMessageId}) async =>
      await _req('GET', '/api/applications/$applicationId/messages', query: {
        'limit': '$limit',
        if (targetMessageId != null) 'target_message_id': '$targetMessageId',
      }) as List<dynamic>;
  static Future<void> markMessagesRead(
          int applicationId, int throughMessageId) async =>
      await _req(
        'POST',
        '/api/applications/$applicationId/messages/read',
        query: {'through_message_id': '$throughMessageId'},
      );
  static Future<void> updateChatActivity(int applicationId,
          {bool typing = false}) async =>
      await _req(
        'POST',
        '/api/applications/$applicationId/messages/activity',
        body: {'typing': typing},
      );
  static Future<Map<String, dynamic>> chatActivity(int applicationId) async =>
      Map<String, dynamic>.from(await _req(
        'GET',
        '/api/applications/$applicationId/messages/activity',
      ) as Map);
  static Future<void> sendMessage(int applicationId, String body) async =>
      await _req('POST', '/api/applications/$applicationId/messages',
          body: {'body': body});

  // ---- milestones
  static Future<List<dynamic>> milestones(int applicationId) async =>
      await _req('GET', '/api/applications/$applicationId/milestones')
          as List<dynamic>;
  static Future<void> addMilestone(
    int applicationId,
    String title,
    String description,
    String stage,
    String? dueDate,
  ) async =>
      await _req('POST', '/api/applications/$applicationId/milestones', body: {
        'title': title,
        'description': description,
        'stage': stage,
        'due_date': dueDate,
      });
  static Future<void> updateMilestone(
          int id, Map<String, dynamic> changes) async =>
      await _req('PATCH', '/api/milestones/$id', body: changes);
  static Future<void> deleteMilestone(int id) async =>
      await _req('DELETE', '/api/milestones/$id');
  static Future<Map<String, dynamic>> board(int applicationId) async =>
      Map<String, dynamic>.from(
        await _req('GET', '/api/applications/$applicationId/board') as Map,
      );
  static Future<void> addTask(int applicationId, String title,
          String description, String? dueDate) async =>
      await _req('POST', '/api/applications/$applicationId/tasks', body: {
        'title': title,
        'description': description,
        'due_date': dueDate,
      });
  static Future<void> updateTask(int id, Map<String, dynamic> changes) async =>
      await _req('PATCH', '/api/tasks/$id', body: changes);
  static Future<void> deleteTask(int id) async =>
      await _req('DELETE', '/api/tasks/$id');
  static Future<void> decideApplication(int id, String status) async =>
      await _req('PATCH', '/api/applications/$id', body: {'status': status});

  // ---- adviser schedule
  static Future<List<dynamic>> availability() async =>
      await _req('GET', '/api/availability') as List<dynamic>;
  static Future<Map<String, dynamic>> adviserProfile() async =>
      Map<String, dynamic>.from(
          await _req('GET', '/api/adviser/profile') as Map);
  static Future<void> saveAdviserProfile({
    required String department,
    required String specializationTags,
    required String certifications,
    required int maxCapacity,
  }) async =>
      await _req('PUT', '/api/adviser/profile', body: {
        'department': department,
        'specialization_tags': specializationTags,
        'certifications': certifications,
        'max_capacity': maxCapacity,
      });
  static Future<void> addAvailability({
    String? dayOfWeek,
    String? specificDate,
    required String startTime,
    required String endTime,
  }) async =>
      await _req('POST', '/api/availability', body: {
        'day_of_week': dayOfWeek,
        'specific_date': specificDate,
        'start_time': startTime,
        'end_time': endTime,
      });
  static Future<void> updateAvailability(
    int id, {
    String? dayOfWeek,
    String? specificDate,
    required String startTime,
    required String endTime,
  }) async =>
      await _req('PUT', '/api/availability/$id', body: {
        'day_of_week': dayOfWeek,
        'specific_date': specificDate,
        'start_time': startTime,
        'end_time': endTime,
      });
  static Future<void> deleteAvailability(int id) async =>
      await _req('DELETE', '/api/availability/$id');

  static Future<List<dynamic>> availabilityExceptions() async =>
      await _req('GET', '/api/adviser/exceptions') as List<dynamic>;
  static Future<void> addAvailabilityException({
    required String specificDate,
    String? startTime,
    String? endTime,
    String? reason,
    required bool allDay,
  }) async =>
      await _req('POST', '/api/adviser/exceptions', body: {
        'specific_date': specificDate,
        'start_time': allDay ? null : startTime,
        'end_time': allDay ? null : endTime,
        'reason': reason,
        'is_all_day': allDay,
      });
  static Future<void> deleteAvailabilityException(int id) async =>
      await _req('DELETE', '/api/adviser/exceptions/$id');

  static Future<List<dynamic>> adviserWaitlist() async =>
      await _req('GET', '/api/adviser/waitlist') as List<dynamic>;
  static Future<void> notifyWaitlist(int id) async =>
      await _req('POST', '/api/waitlist/$id/notify');

  static Future<List<dynamic>> availableGroupMembers(String query) async =>
      await _req('GET', '/api/group-members', query: {'q': query})
          as List<dynamic>;
  static Future<List<dynamic>> availableGroups(String query) async =>
      await _req('GET', '/api/groups', query: {'q': query}) as List<dynamic>;
  static Future<void> createStudentGroupRequest(int userId) async =>
      await _req('POST', '/api/student-group-requests',
          body: {'user_id': userId});
  static Future<List<dynamic>> studentGroupRequests() async =>
      await _req('GET', '/api/student-group-requests') as List<dynamic>;
  static Future<void> decideStudentGroupRequest(int id, String status) async =>
      await _req('PATCH', '/api/student-group-requests/$id',
          body: {'status': status});
  static Future<List<dynamic>> groupJoinRequests(int applicationId) async =>
      await _req(
        'GET',
        '/api/applications/$applicationId/group-join-requests',
      ) as List<dynamic>;
  static Future<void> decideGroupJoinRequest(int id, String status) async =>
      await _req('PATCH', '/api/group-join-requests/$id',
          body: {'status': status});

  // ---- documents
  static Future<List<dynamic>> documents(int applicationId) async =>
      await _req('GET', '/api/applications/$applicationId/documents')
          as List<dynamic>;
  static Future<void> deleteDocument(int documentId) async =>
      await _req('DELETE', '/api/documents/$documentId');
  static Future<void> uploadDocument(
      int applicationId, String fileName, String base64,
      {int? bookingId, String category = 'todo'}) async {
    final bytes = base64Decode(base64);
    await uploadDocumentBytes(applicationId, fileName, bytes,
        category: category);
  }

  static Future<void> uploadDocumentBytes(
    int applicationId,
    String fileName,
    Uint8List bytes, {
    String category = 'todo',
    int? taskId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/applications/$applicationId/documents'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['category'] = category;
    if (taskId != null) request.fields['task_id'] = '$taskId';
    request.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = {};
    }
    if (response.statusCode >= 400) throw ApiException(_readError(data));
  }

  static Future<void> addTaskComment(
    int taskId,
    String body, {
    String? fileName,
    Uint8List? bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/tasks/$taskId/comments'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['body'] = body;
    if (fileName != null && bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    }
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 45)),
    );
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = {};
    }
    if (response.statusCode >= 400) throw ApiException(_readError(data));
  }

  static Future<Uint8List> downloadDocument(int documentId) async =>
      _downloadBytes('/api/documents/$documentId/download');

  static Future<void> uploadDocumentVersion(
      int documentId, String filename, Uint8List bytes,
      {String? comment}) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/documents/$documentId/versions'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (comment != null && comment.trim().isNotEmpty) {
      request.fields['comment'] = comment.trim();
    }
    request.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 45)),
    );
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = {};
    }
    if (response.statusCode >= 400) throw ApiException(_readError(data));
  }

  static Future<List<dynamic>> documentVersions(int documentId) async =>
      await _req('GET', '/api/documents/$documentId/versions') as List<dynamic>;
  static Future<Uint8List> downloadDocumentVersion(int versionId) async =>
      _downloadBytes('/api/document-versions/$versionId/download');

  static Future<Uint8List> _downloadBytes(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 45));
    if (response.statusCode >= 400) {
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = {};
      }
      throw ApiException(_readError(data));
    }
    return response.bodyBytes;
  }

  static Future<String?> saveDownloadedFile(
      String filename, Uint8List bytes) async {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save document',
      fileName: filename,
      bytes: bytes,
    );
  }

  // ---- waitlist
  static Future<void> joinWaitlist(int adviserId, String brief) async =>
      await _req('POST', '/api/waitlist',
          body: {'adviser_id': adviserId, 'topic_brief': brief});
  static Future<List<dynamic>> myWaitlist() async =>
      await _req('GET', '/api/waitlist/me') as List<dynamic>;
  static Future<void> cancelWaitlist(int waitlistId) async =>
      await _req('POST', '/api/waitlist/$waitlistId/cancel');

  // ---- group invitations
  static Future<void> inviteGroupMember(
          int applicationId, String email) async =>
      await _req('POST', '/api/applications/$applicationId/group-invitations',
          body: {'student_email': email});
  static Future<List<dynamic>> groupMembers(int applicationId) async =>
      await _req('GET', '/api/applications/$applicationId/group')
          as List<dynamic>;
  static Future<List<dynamic>> groupInvitationsForApplication(
          int applicationId) async =>
      await _req('GET', '/api/applications/$applicationId/group-invitations')
          as List<dynamic>;
  static Future<List<dynamic>> groupInvitations() async =>
      await _req('GET', '/api/group-invitations') as List<dynamic>;
  static Future<void> acceptGroupInvitation(int invitationId) async =>
      await _req('POST', '/api/group-invitations/$invitationId/accept');
  static Future<void> declineGroupInvitation(int invitationId) async =>
      await _req('POST', '/api/group-invitations/$invitationId/decline');
  static Future<void> cancelGroupInvitation(int invitationId) async =>
      await _req('DELETE', '/api/group-invitations/$invitationId');
  static Future<void> removeGroupMember(int groupId) async =>
      await _req('DELETE', '/api/group/$groupId');
}
