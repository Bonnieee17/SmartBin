import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeepLinkData {
  final String? type;
  final int? points;
  final String? binId;
  final String? voucher;
  final int? cost;

  DeepLinkData({
    this.type,
    this.points,
    this.binId,
    this.voucher,
    this.cost,
  });

  bool get isDisposal =>
      type != null && points != null && binId != null;

  bool get isVoucher =>
      voucher != null && cost != null;
}

class DeepLinkService {
  static DeepLinkData? _pendingClaim;
  static DeepLinkData? get pendingClaim => _pendingClaim;

  static final _onLinkDetected = StreamController<DeepLinkData>.broadcast();
  static Stream<DeepLinkData> get onLinkDetected => _onLinkDetected.stream;

  static final _appLinks = AppLinks();

  static void init() {
    // Handle deep links when app is in background/terminated
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _parseUri(uri);
    });

    // Handle deep links when app is in foreground
    _appLinks.uriLinkStream.listen((uri) {
      _parseUri(uri);
    });
  }

  static void clearPendingClaim() {
    _pendingClaim = null;
  }

  static void _parseUri(Uri uri) {
    // Support both https://domain/#/home?type=...
    // and smartbin://claim?type=...
    
    final params = uri.queryParameters.isNotEmpty 
        ? uri.queryParameters 
        : (uri.fragment.contains('?') 
            ? Uri.parse(uri.fragment.substring(uri.fragment.indexOf('?'))).queryParameters 
            : {});

    final type = params['type'];
    final pts = int.tryParse(params['pts'] ?? '');
    final bin = params['bin'];
    final voucher = params['voucher'];
    final cost = int.tryParse(params['cost'] ?? '');

    if ((type != null && pts != null && bin != null) ||
        (voucher != null && cost != null)) {
      final data = DeepLinkData(
        type: type,
        points: pts,
        binId: bin,
        voucher: voucher,
        cost: cost,
      );

      _pendingClaim = data;
      _onLinkDetected.add(data);
    }
  }
}
