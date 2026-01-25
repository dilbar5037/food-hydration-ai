import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  Future<bool> hasNetwork() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasInternet() async {
    try {
      return await hasNetwork();
    } catch (_) {
      return false;
    }
  }
}
