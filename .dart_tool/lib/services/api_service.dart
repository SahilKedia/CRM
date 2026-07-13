import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import '../config/app_config.dart';
import 'dart:convert';                // for jsonEncode
import 'auth_service.dart';           // or wherever AuthSession is defined

class ApiService {
  // Single source of truth for the server address lives in
  // lib/config/app_config.dart — update the IP there, not here.
  static const String baseUrl = AppConfig.apiBaseUrl;

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: false,
        validateStatus: (status) {
          return status != null && status < 500;
        },
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptor for logging and error handling
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🌐 Full URL: ${options.uri}');
          print('📤 Headers: ${options.headers}');
          if (options.data != null) {
            print('📤 Data: ${options.data}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('📥 Response: ${response.statusCode} ${response.statusMessage}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print('❌ Dio Error: ${e.message}');
          print('❌ Response: ${e.response?.data}');
          print('❌ Status Code: ${e.response?.statusCode}');
          return handler.next(e);
        },
      ),
    );
  }

  // Get token from secure storage
  Future<String?> _getToken() async {
    try {
      return await _storage.read(key: 'token');
    } catch (e) {
      print('❌ Error reading token: $e');
      return null;
    }
  }

  // Set token to secure storage
  Future<void> setToken(String token) async {
    try {
      await _storage.write(key: 'token', value: token);
      print('✅ Token stored successfully');
    } catch (e) {
      print('❌ Error storing token: $e');
    }
  }

  // Clear token
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: 'token');
      print('✅ Token cleared');
    } catch (e) {
      print('❌ Error clearing token: $e');
    }
  }

  // Logout method
  Future<void> logout() async {
    try {
      await clearToken();
      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  // ============ AUTH METHODS ============

  // Login method
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('🔑 Attempting login for: $email');

      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      print('📥 Login response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map<String, dynamic>) {
          final responseData = response.data as Map<String, dynamic>;

          if (responseData['token'] != null) {
            await setToken(responseData['token']);
          }

          return responseData;
        } else {
          return {
            'success': false,
            'message': 'Invalid response format from server',
          };
        }
      } else {
        if (response.data is Map<String, dynamic>) {
          return response.data as Map<String, dynamic>;
        } else {
          return {
            'success': false,
            'message': 'Server error: ${response.statusCode}',
          };
        }
      }
    } on DioException catch (e) {
      print('❌ Dio Exception: ${e.message}');

      String errorMessage = 'Login failed';

      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout. Please check your internet.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Server not responding. Please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.response != null && e.response!.data is Map<String, dynamic>) {
        errorMessage = e.response!.data['message'] ??
            'Server error: ${e.response!.statusCode}';
      }

      return {
        'success': false,
        'message': errorMessage,
        'statusCode': e.response?.statusCode,
      };
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  // Admin signup — matches POST /api/auth/signup on the backend
  // (name, email, password, phone, branch, role)
  Future<Map<String, dynamic>> signup(Map<String, dynamic> signupData) async {
    try {
      print('📝 Attempting signup for: ${signupData['email']}');

      final response = await _dio.post(
        '/auth/signup',
        data: signupData,
      );

      if (response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;

        // Some backends log the admin in immediately on signup — store the
        // token if one comes back so the rest of the app stays consistent.
        if (responseData['token'] != null) {
          await setToken(responseData['token']);
        }

        return responseData;
      }

      return {
        'success': false,
        'message': 'Invalid response format from server',
      };
    } on DioException catch (e) {
      print('❌ Dio Exception: ${e.message}');

      String errorMessage = 'Signup failed';

      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout. Please check your internet.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Server not responding. Please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.response != null && e.response!.data is Map<String, dynamic>) {
        errorMessage = e.response!.data['message'] ??
            'Server error: ${e.response!.statusCode}';
      }

      return {
        'success': false,
        'message': errorMessage,
        'statusCode': e.response?.statusCode,
      };
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: ${e.toString()}',
      };
    }
  }

  // Send OTP for employee login
  Future<Map<String, dynamic>> employeeSendOtp(String email) async {
    try {
      final response = await _dio.post(
        '/auth/employee/send-otp',
        data: {'email': email},
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'Failed to send OTP',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Verify OTP for employee login
  Future<Map<String, dynamic>> employeeVerifyOtp(String email, String otp) async {
    try {
      final response = await _dio.post(
        '/auth/employee/verify-otp',
        data: {
          'email': email,
          'otp': otp,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true && responseData['token'] != null) {
          await setToken(responseData['token']);
        }

        return responseData;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['message'] ?? 'OTP verification failed',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Verify OTP for employee login (duplicate method - consider removing)
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await _dio.post(
        '/employee/verify-otp',
        data: {
          'email': email,
          'otp': otp,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true && responseData['token'] != null) {
          await setToken(responseData['token']);
        }

        return responseData;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'OTP verification failed',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ============ EMPLOYEE METHODS ============

  // Create Employee
  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> employeeData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final response = await _dio.post(
        '/employees',
        data: employeeData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');

      if (e.response?.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      }

      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Network error occurred',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Get all employees
  Future<Map<String, dynamic>> getEmployees({String? branch}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
          'data': [],
        };
      }

      String endpoint = '/employees';
      if (branch != null && branch.isNotEmpty) {
        endpoint += '?branch=$branch';
      }

      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
          'data': [],
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to fetch employees',
        'data': [],
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
        'data': [],
      };
    }
  }

  // Update Employee
  Future<Map<String, dynamic>> updateEmployee(String id, Map<String, dynamic> employeeData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final response = await _dio.put(
        '/employees/$id',
        data: employeeData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to update employee',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Delete Employee
  Future<Map<String, dynamic>> deleteEmployee(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final response = await _dio.delete(
        '/employees/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to delete employee',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ==================BRANCH METHODS=================

  // Get all branches
  Future<dynamic> getBranches() async {
    try {
      final token = await _getToken();

      final response = await _dio.get(
        '/branches',
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
          'data': [],
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to fetch branches',
        'data': [],
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
        'data': [],
      };
    }
  }

  // Add branch
  Future<Map<String, dynamic>> addBranch(Map<String, dynamic> branchData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final response = await _dio.post(
        '/branches',
        data: branchData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to add branch',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Update branch
  Future<Map<String, dynamic>> updateBranch(String id, Map<String, dynamic> branchData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final response = await _dio.put(
        '/branches/$id',
        data: branchData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to update branch',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Delete branch
  Future<Map<String, dynamic>> deleteBranch(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final response = await _dio.delete(
        '/branches/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to delete branch',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ============ CUSTOMER METHODS ============

  // Get all customers
  Future<Map<String, dynamic>> getCustomers() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
          'data': [],
        };
      }

      final response = await _dio.get(
        '/customers',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
          'data': [],
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to fetch customers',
        'data': [],
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
        'data': [],
      };
    }
  }

  // Get customer by ID - ONLY ONE VERSION (using Dio)
  Future<Map<String, dynamic>> getCustomerById(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final response = await _dio.get(
        '/customers/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to fetch customer',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Create customer with images (gold, diamond, polki) — this is the FIRST
  // visit for a brand-new customer.
  Future<Map<String, dynamic>> createCustomerWithImages(
    Map<String, dynamic> customerData,
    List<File> goldImages,
    List<File> diamondImages,
    List<File> polkiImages, {
    File? customerImage,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      // Debug: Print all customer data before sending
      print('🔍 DEBUG: Customer Data Keys: ${customerData.keys}');
      print('🔍 DEBUG: Name: ${customerData['name']}');
      print('🔍 DEBUG: Assigned To: ${customerData['assignedTo']}');

      // Validate required fields
      if (customerData['name'] == null || customerData['name'].toString().isEmpty) {
        return {
          'success': false,
          'message': 'Customer name is required',
        };
      }

      if (customerData['assignedTo'] == null || customerData['assignedTo'].toString().isEmpty) {
        return {
          'success': false,
          'message': 'Assigned employee is required',
        };
      }

      // Create FormData
      final formData = FormData();

      final Map<String, String> fieldMapping = {
        'name': customerData['name']?.toString() ?? '',
        'email': customerData['email']?.toString() ?? '',
        'phone': customerData['phone']?.toString() ?? '',
        'address': customerData['address']?.toString() ?? '',
        'branch': customerData['branch']?.toString() ?? '',
        'visitDate': customerData['visitDate']?.toString() ?? '',
        'purposeOfVisit': customerData['purposeOfVisit']?.toString() ?? '',
        'gold': customerData['gold']?.toString() ?? '',
        'diamond': customerData['diamond']?.toString() ?? '',
        'polki': customerData['polki']?.toString() ?? '',
        'requirement': customerData['requirement']?.toString() ?? '',
        'approval': customerData['approval']?.toString() ?? 'false',
        'whoAttend': customerData['whoAttend']?.toString() ?? '',
        'assignedTo': customerData['assignedTo']?.toString() ?? '',
        'helper': customerData['helper']?.toString() ?? '',
        'reminderDate': customerData['reminderDate']?.toString() ?? '',
        'reminderMessage': customerData['reminderMessage']?.toString() ?? '',
        'media': customerData['media']?.toString() ?? '',
        'conclusion': customerData['conclusion']?.toString() ?? 'Pending',
        'notes': customerData['notes']?.toString() ?? '',
        'birthday': customerData['birthday']?.toString() ?? '',
        'anniversary': customerData['anniversary']?.toString() ?? '',
        'profession': customerData['profession']?.toString() ?? '',
        'community': customerData['community']?.toString() ?? '',
        'referenceNote': customerData['referenceNote']?.toString() ?? '',
        'referredBy': customerData['referredBy']?.toString() ?? '',
      };

      // Add all fields to form data
      fieldMapping.forEach((key, value) {
        if (value.isNotEmpty) {
          formData.fields.add(MapEntry(key, value));
          print('📝 Adding field: $key = $value');
        }
      });

      // Add gold images
      for (int i = 0; i < goldImages.length; i++) {
        final file = goldImages[i];
        final fileName = 'gold_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        formData.files.add(
          MapEntry(
            'goldImages',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
            ),
          ),
        );
        print('📸 Added gold image: $fileName');
      }

      // Add diamond images
      for (int i = 0; i < diamondImages.length; i++) {
        final file = diamondImages[i];
        final fileName = 'diamond_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        formData.files.add(
          MapEntry(
            'diamondImages',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
            ),
          ),
        );
        print('📸 Added diamond image: $fileName');
      }

      // Add polki images
      for (int i = 0; i < polkiImages.length; i++) {
        final file = polkiImages[i];
        final fileName = 'polki_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        formData.files.add(
          MapEntry(
            'polkiImages',
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
            ),
          ),
        );
        print('📸 Added polki image: $fileName');
      }
if (customerImage != null) {
        formData.files.add(
          MapEntry(
            'customerImage',
            await MultipartFile.fromFile(
              customerImage.path,
              filename: 'customer_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          ),
        );
        print('📸 Added customer profile image');
      }
      print('📤 Sending form data with ${goldImages.length} gold, ${diamondImages.length} diamond, ${polkiImages.length} polki images');
      print('📤 Total fields: ${formData.fields.length}');
      print('📤 Total files: ${formData.files.length}');

      final response = await _dio.post(
        '/customers',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Data: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      print('❌ Error Type: ${e.type}');
      print('❌ Error Message: ${e.message}');

      String errorMessage = 'Failed to create customer';
      if (e.response?.data != null) {
        if (e.response!.data is Map<String, dynamic>) {
          errorMessage = e.response!.data['message'] ?? errorMessage;
        } else if (e.response!.data is String) {
          errorMessage = e.response!.data;
        }
      }

      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // 👇 NEW: Adds a NEW visit to an EXISTING (repeat) customer - ONLY ONE VERSION (using Dio)
  Future<Map<String, dynamic>> addVisitToCustomer(
    String customerId,
    Map<String, dynamic> visitData,
    List<File> goldImages,
    List<File> diamondImages,
    List<File> polkiImages,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final formData = FormData();

      final Map<String, String> fieldMapping = {
        'purposeOfVisit': visitData['purposeOfVisit']?.toString() ?? '',
        'gold': visitData['gold']?.toString() ?? '',
        'diamond': visitData['diamond']?.toString() ?? '',
        'polki': visitData['polki']?.toString() ?? '',
        'requirement': visitData['requirement']?.toString() ?? '',
        'approval': visitData['approval']?.toString() ?? 'false',
        'conclusion': visitData['conclusion']?.toString() ?? 'Pending',
        'whoAttend': visitData['whoAttend']?.toString() ?? '',
        'helper': visitData['helper']?.toString() ?? '',
        'visitDate': visitData['visitDate']?.toString() ?? '',
      };

      fieldMapping.forEach((key, value) {
        if (value.isNotEmpty) {
          formData.fields.add(MapEntry(key, value));
          print('📝 Adding visit field: $key = $value');
        }
      });

      for (int i = 0; i < goldImages.length; i++) {
        final file = goldImages[i];
        formData.files.add(
          MapEntry(
            'goldImages',
            await MultipartFile.fromFile(
              file.path,
              filename: 'gold_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            ),
          ),
        );
      }

      for (int i = 0; i < diamondImages.length; i++) {
        final file = diamondImages[i];
        formData.files.add(
          MapEntry(
            'diamondImages',
            await MultipartFile.fromFile(
              file.path,
              filename: 'diamond_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            ),
          ),
        );
      }

      for (int i = 0; i < polkiImages.length; i++) {
        final file = polkiImages[i];
        formData.files.add(
          MapEntry(
            'polkiImages',
            await MultipartFile.fromFile(
              file.path,
              filename: 'polki_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            ),
          ),
        );
      }

      print('📤 Sending new visit for customer $customerId');

      final response = await _dio.post(
        '/customers/$customerId/visits',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Data: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      String errorMessage = 'Failed to add visit';
      if (e.response?.data != null) {
        if (e.response!.data is Map<String, dynamic>) {
          errorMessage = e.response!.data['message'] ?? errorMessage;
        } else if (e.response!.data is String) {
          errorMessage = e.response!.data;
        }
      }
      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
Future<Map<String, dynamic>> updateVisit(
  String customerId,
  int visitNumber,
  Map<String, dynamic> visitData,
  List<File> newGoldImages,
  List<File> newDiamondImages,
  List<File> newPolkiImages, {
  List<String> removeGoldImages = const [],
  List<String> removeDiamondImages = const [],
  List<String> removePolkiImages = const [],
}) async {
  try {
    final token = await _getToken(); 
    final formMap = <String, dynamic>{};

    visitData.forEach((key, value) {
      if (value != null) formMap[key] = value.toString();
    });

    if (removeGoldImages.isNotEmpty) {
      formMap['removeGoldImages'] = jsonEncode(removeGoldImages);
    }
    if (removeDiamondImages.isNotEmpty) {
      formMap['removeDiamondImages'] = jsonEncode(removeDiamondImages);
    }
    if (removePolkiImages.isNotEmpty) {
      formMap['removePolkiImages'] = jsonEncode(removePolkiImages);
    }

    final formData = FormData.fromMap(formMap);

    for (final img in newGoldImages) {
      formData.files.add(MapEntry(
        'goldImages',
        await MultipartFile.fromFile(img.path, filename: img.path.split('/').last),
      ));
    }
    for (final img in newDiamondImages) {
      formData.files.add(MapEntry(
        'diamondImages',
        await MultipartFile.fromFile(img.path, filename: img.path.split('/').last),
      ));
    }
    for (final img in newPolkiImages) {
      formData.files.add(MapEntry(
        'polkiImages',
        await MultipartFile.fromFile(img.path, filename: img.path.split('/').last),
      ));
    }

    final response = await _dio.put(
      // '$baseUrl/customers/$customerId/visits/$visitNumber',
      '/customers/$customerId/visits/$visitNumber',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return response.data is Map<String, dynamic>
        ? response.data
        : {'success': false, 'message': 'Unexpected response'};
  } on DioException catch (e) {
    return {
      'success': false,
      'message': e.response?.data?['message'] ?? 'Failed to update visit',
    };
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}
  // Update customer — profile-level edits only (name, phone, birthday,
  // anniversary, profession, etc). Use addVisitToCustomer for a new
  // purchase visit so earlier visit history is preserved.
  // Future<Map<String, dynamic>> updateCustomer(String id, Map<String, dynamic> customerData) async {
  //   try {
  //      final token = await _getToken(); 
  //     if (token == null) {
  //       return {
  //         'success': false,
  //         'message': 'Authentication required. Please login again.',
  //       };
  //     }

  //     final response = await _dio.put(
  //       '/customers/$id',
  //       data: customerData,
  //       options: Options(
  //         headers: {
  //           'Authorization': 'Bearer $token',
  //         },
  //       ),
  //     );
  Future<Map<String, dynamic>> updateCustomer(
    String id,
    Map<String, dynamic> customerData, {
    File? customerImage,
  }) async {
    try {
       final token = await _getToken(); 
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      dynamic requestData = customerData;
      String contentType = 'application/json';

      if (customerImage != null) {
        final formData = FormData.fromMap(
          customerData.map((key, value) => MapEntry(key, value?.toString() ?? '')),
        );
        formData.files.add(
          MapEntry(
            'customerImage',
            await MultipartFile.fromFile(
              customerImage.path,
              filename: 'customer_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          ),
        );
        requestData = formData;
        contentType = 'multipart/form-data';
      }

      final response = await _dio.put(
        '/customers/$id',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': contentType,
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to update customer',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Delete customer
  Future<Map<String, dynamic>> deleteCustomer(String id) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final response = await _dio.delete(
        '/customers/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to delete customer',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Mark a specific visit's reminder as completed
  // Matches backend: PUT /api/customers/:id/visits/:visitNumber/reminder/complete
  Future<Map<String, dynamic>> completeVisitReminder(
    String customerId,
    int visitNumber,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required. Please login again.',
        };
      }

      final response = await _dio.put(
        '/customers/$customerId/visits/$visitNumber/reminder/complete',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
        };
      }
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to complete reminder',
      };
    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // ============ REVIEW METHODS ============

  // Get all reviews with optional filters
  Future<Map<String, dynamic>> getReviews({String? status, String? search}) async {
    try {
      final token = await _getToken();

      Map<String, dynamic> queryParams = {};
      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      print('🔍 Fetching feedback with params: $queryParams');

      final response = await _dio.get(
        '/feedback',
        queryParameters: queryParams,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      print('📥 Feedback response: ${response.statusCode}');

      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': false, 'message': 'Invalid response', 'data': []};
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      if (e.response?.statusCode == 401) {
        return {'success': false, 'message': 'Session expired', 'unauthorized': true};
      }
      return {'success': false, 'message': e.response?.data?['message'] ?? 'Failed to fetch feedback', 'data': []};
    } catch (e) {
      print('❌ Error: $e');
      return {'success': false, 'message': e.toString(), 'data': []};
    }
  }

  // Get review stats
  Future<Map<String, dynamic>> getReviewStats() async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '/feedback/stats',
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': false, 'message': 'Invalid response'};
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {'success': false, 'message': e.response?.data?['message'] ?? 'Failed to fetch stats'};
    } catch (e) {
      print('❌ Error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Update review status
  Future<Map<String, dynamic>> updateReviewStatus(String id, String status) async {
    try {
      final token = await _getToken();
      final response = await _dio.put(
        '/feedback/$id/status',
        data: {'status': status},
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': false, 'message': 'Invalid response'};
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {'success': false, 'message': e.response?.data?['message'] ?? 'Failed to update status'};
    } catch (e) {
      print('❌ Error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Delete review
  Future<Map<String, dynamic>> deleteReview(String id) async {
    try {
      final token = await _getToken();
      final response = await _dio.delete(
        '/feedback/$id',
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': false, 'message': 'Invalid response'};
    } on DioException catch (e) {
      print('❌ Dio Error: ${e.response?.data}');
      return {'success': false, 'message': e.response?.data?['message'] ?? 'Failed to delete review'};
    } catch (e) {
      print('❌ Error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
// Get all admins
Future<Map<String, dynamic>> getAdmins() async {
  try {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'Authentication required'};
    }
    final response = await _dio.get(
      '/admins',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    } else {
      return {'success': false, 'message': 'Invalid response'};
    }
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

// Update admin
Future<Map<String, dynamic>> updateAdmin(String id, Map<String, dynamic> data) async {
  try {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'Authentication required'};
    }
    final response = await _dio.put(
      '/admins/$id',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data is Map<String, dynamic>
        ? response.data
        : {'success': false, 'message': 'Invalid response'};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}

// Delete admin
Future<Map<String, dynamic>> deleteAdmin(String id) async {
  try {
    final token = await _getToken();
    if (token == null) {
      return {'success': false, 'message': 'Authentication required'};
    }
    final response = await _dio.delete(
      '/admins/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data is Map<String, dynamic>
        ? response.data
        : {'success': false, 'message': 'Invalid response'};
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}


// ============ IMAGE URL HELPER ============

// Converts a relative path (e.g. "uploads/customers/xxx.jpg") or an old
// full URL saved before the backend fix into a working image URL.
static String getImageUrl(String path) {
  if (path.isEmpty) return '';

  // Already a full URL (old records saved before the backend fix)
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }

  // Strip any leading slash to avoid double slashes when joining
  final cleanPath = path.startsWith('/') ? path.substring(1) : path;

  // path already contains "uploads/customers/...", so join with serverUrl
  return '${AppConfig.serverUrl}/$cleanPath';
}
  // ============ NOTIFICATION METHODS ============

  // Get notifications with pagination
  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? isRead,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication required',
          'data': {'notifications': [], 'pagination': {'unreadCount': 0}},
        };
      }

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (type != null) queryParams['type'] = type;
      if (isRead != null) queryParams['isRead'] = isRead;

      final response = await _dio.get(
        '/notifications',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Invalid response format',
          'data': {'notifications': [], 'pagination': {'unreadCount': 0}},
        };
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return {
        'success': false,
        'message': e.toString(),
        'data': {'notifications': [], 'pagination': {'unreadCount': 0}},
      };
    }
  }

  // Mark notification as read
  Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await _dio.put(
        '/notifications/$notificationId/read',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Mark all notifications as read
  Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await _dio.put(
        '/notifications/mark-all-read',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Mark notification as delivered
  Future<Map<String, dynamic>> markNotificationAsDelivered(String notificationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await _dio.put(
        '/notifications/$notificationId/deliver',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      print('❌ Error marking notification as delivered: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Delete notification
  Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await _dio.delete(
        '/notifications/$notificationId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      print('❌ Error deleting notification: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Check if user is authenticated (token exists and is valid)
  Future<bool> isAuthenticated() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // Create a new notification
  Future<Map<String, dynamic>> createNotification({
    required String customerId,
    required String type,
    required String title,
    required String message,
    required String date,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      print('📤 Creating notification: $title for customer $customerId');

      final response = await _dio.post(
        '/notifications/create',
        data: {
          'customerId': customerId,
          'type': type,
          'title': title,
          'message': message,
          'date': date,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      print('📥 Create notification response: ${response.data}');

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        return {'success': false, 'message': 'Invalid response format'};
      }
    } catch (e) {
      print('❌ Error creating notification: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
    // In api_service.dart
// In api_service.dart, inside the ApiService class
 // Add this method inside the ApiService class

   Future<Map<String, dynamic>> deleteVisit(String customerId, int visitNumber) async {
  try {
    final token = await _getToken();
    if (token == null) {
      return {
        'success': false,
        'message': 'Authentication required. Please login again.',
      };
    }

    final response = await _dio.delete(
      '/customers/$customerId/visits/$visitNumber',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    // Log the raw response for debugging
    print('📥 DELETE visit response status: ${response.statusCode}');
    print('📥 DELETE visit response data type: ${response.data.runtimeType}');
    print('📥 DELETE visit response data: ${response.data}');

    // If the response is a Map, return it
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    } else {
      // Handle non-Map responses (e.g., plain string, HTML, etc.)
      return {
        'success': false,
        'message': 'Unexpected response format: ${response.data}',
        'rawData': response.data,
      };
    }
  } on DioException catch (e) {
    print('❌ Dio Error: ${e.response?.data}');
    print('❌ Status Code: ${e.response?.statusCode}');
    return {
      'success': false,
      'message': e.response?.data['message'] ?? 'Failed to delete visit',
      'statusCode': e.response?.statusCode,
    };
  } catch (e) {
    print('❌ Error: $e');
    return {
      'success': false,
      'message': e.toString(),
    };
  }
}

Future<List<String>> getDistinctProfessions() async {
  try {
    final token = await _getToken();
    if (token == null) return [];

    final response = await _dio.get(
      '/customers/distinct/professions',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    if (response.data is Map<String, dynamic> &&
        response.data['success'] == true) {
      final data = response.data['data'] as List?;
      return data?.map((e) => e.toString()).toList() ?? [];
    }
    return [];
  } catch (e) {
    print('❌ Error fetching professions: $e');
    return [];
  }
}

Future<List<String>> getDistinctCommunities() async {
  try {
    final token = await _getToken();
    if (token == null) return [];

    final response = await _dio.get(
      '/customers/distinct/communities',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    if (response.data is Map<String, dynamic> &&
        response.data['success'] == true) {
      final data = response.data['data'] as List?;
      return data?.map((e) => e.toString()).toList() ?? [];
    }
    return [];
  } catch (e) {
    print('❌ Error fetching communities: $e');
    return [];
  }
}
}