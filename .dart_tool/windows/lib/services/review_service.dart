import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/review_model.dart';
import '../config/app_config.dart';

// NOTE: review_screen.dart currently uses ApiService (not this class) to
// talk to /api/feedback, so this service isn't wired up anywhere right now.
// It's kept here (fixed) in case you switch back to it, but there's no
// need to touch it to fix employee/branch/customer fetching.
class ReviewService {
  // Was hardcoded to a different, stale IP AND duplicated "/api" in every
  // call below (baseUrl already ended in /api, then each request appended
  // another /api/... on top) — both bugs are now fixed.
  static const String baseUrl = AppConfig.apiBaseUrl;


  Future<Map<String, dynamic>> getReviews({String? status, String? branch, String? search}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (status != null && status != 'all') queryParams['status'] = status;
      if (branch != null && branch != 'all') queryParams['branch'] = branch;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/feedback').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> feedbackList = data['data'] ?? [];
          final List<Review> reviews = feedbackList
              .map((item) => Review.fromJson(item))
              .toList();
          
          return {
            'success': true,
            'data': reviews,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch reviews',
          };
        }
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
          'unauthorized': true,
        };
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getReviewStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/feedback/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch stats',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateReviewStatus(String reviewId, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/feedback/$reviewId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to update status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> deleteReview(String reviewId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? prefs.getString('token');
      
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/feedback/$reviewId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to delete review',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}