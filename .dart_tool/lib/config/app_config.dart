/// Single source of truth for the backend server address.
///
/// IMPORTANT:
/// - This must be your computer's LAN IP address (the one running
///   `node server.js`), NOT "localhost"/"127.0.0.1" — a phone or emulator
///   can't reach "localhost" on your laptop.
/// - Run `ipconfig` (Windows) or `ifconfig`/`ip addr` (Mac/Linux) on the
///   machine running the backend to find this IP, then update it below.
/// - Android emulator only: use 10.0.2.2 instead of your LAN IP.
/// - Your phone and the backend machine must be on the SAME Wi-Fi network.
/// - The backend's PORT (see backend/.env, currently 5000) must match below.
///
/// Every service in the app (ApiService, ReviewService, etc.) reads from
/// here. Change the IP in exactly ONE place instead of hunting through
/// every file.
class AppConfig {
  AppConfig._();

  /// Host + port of the backend, no trailing slash.
  static const String serverUrl = 'http://192.168.1.19:5000';
  // static const String serverUrl = 'http://192.168.1.70:5000';

  /// REST API base (everything is mounted under /api on the backend).
  static const String apiBaseUrl = '$serverUrl/api';

  /// Base for static/uploaded files served from /uploads.
  static const String uploadsBaseUrl = '$serverUrl/uploads';
}
