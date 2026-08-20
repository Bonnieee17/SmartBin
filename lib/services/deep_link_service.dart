import 'dart:async';
import 'dart:html' as html; // Only works for Web, which user is currently using
import 'package:flutter/foundation.dart';

class DeepLinkData {
  final String? type;
  final int? points;
  final String? binId;
  final String? voucher;
  final int? cost;
  
  DeepLinkData({this.type, this.points, this.binId, this.voucher, this.cost});
  
  bool get isDisposal => type != null && points != null && binId != null;
  bool get isVoucher => voucher != null && cost != null;
}

class DeepLinkService {
  // Store a pending claim so it can be triggered only after login
  static DeepLinkData? _pendingClaim;
  static DeepLinkData? get pendingClaim => _pendingClaim;

  // Use a StreamController so the Home screen can listen for events while active
  static final _onLinkDetected = StreamController<DeepLinkData>.broadcast();
  static Stream<DeepLinkData> get onLinkDetected => _onLinkDetected.stream;

  static void checkInitialLink() {
    if (!kIsWeb) return;

    final uri = Uri.parse(html.window.location.href);
    _parseUri(uri);
  }

  static void clearPendingClaim() {
    _pendingClaim = null;
  }

  static void _parseUri(Uri uri) {
    // Expected formats: 
    // 1. Disposal: ?type=Bottle&pts=10&bin=SB1
    // 2. Voucher:  ?voucher=Printing&cost=100
    
    final type = uri.queryParameters['type'];
    final pts = int.tryParse(uri.queryParameters['pts'] ?? '');
    final bin = uri.queryParameters['bin'];
    
    final voucher = uri.queryParameters['voucher'];
    final cost = int.tryParse(uri.queryParameters['cost'] ?? '');

    if ((type != null && pts != null && bin != null) || (voucher != null && cost != null)) {
      final data = DeepLinkData(
        type: type,
        points: pts,
        binId: bin,
        voucher: voucher,
        cost: cost,
      );
      
      _pendingClaim = data;
      _onLinkDetected.add(data);
      
      // Clear URL parameters so they don't trigger again on refresh
      html.window.history.replaceState({}, '', html.window.location.pathname);
    }
  }
}
