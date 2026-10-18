import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show CrossAxisAlignment, TextAlign;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'default_config.dart';
import 'sdui_log.dart';
import 'sdui_types.dart';

/// Contract for fetching SDUI config.
///
/// Split from [HttpSduiService] so tests can substitute a dead, throwing or
/// garbage backend without patching statics or reaching the network. Every
/// implementation must degrade to "return null / empty" on failure — the
/// provider treats a null as "keep what you already have", which is what makes
/// the cache-first guarantee hold.
abstract class SduiService {
  const SduiService();

  /// Fetches the bootstrap payload, or null on any failure.
  Future<Map<String, dynamic>?> fetchBootstrap();

  /// Fetches one validated spec, or null if unreachable or invalid.
  Future<SduiSpec?> fetchScreen(String key);

  /// Fetches all active specs for a role. Returns an empty map on failure.
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'});

  /// Last-known-good bootstrap from disk, or null.
  Future<Map<String, dynamic>?> readBootstrapCache();

  /// Last-known-good spec from disk, or null.
  Future<SduiSpec?> readScreenCache(String key);

  /// Whether the config endpoint is reachable. For diagnostics only.
  Future<bool> probe();

  static const String bootstrapPath = '/api/auth/config/bootstrap/';
  static const String manifestPath = '/api/auth/config/manifest/';
  static String screenPath(String key) => '/api/auth/config/screens/$key/';

  /// Bounded on purpose: SDUI is presentation config and is never worth holding
  /// the app's first frame hostage for.
  static const Duration timeout = Duration(seconds: 3);
  static const int timeoutSeconds = 3;

  /// What the app ships with, independent of any backend.
  static Map<String, SduiSpec> get bakedDefaults => DefaultConfig.specs();
}

/// Fetches SDUI config over HTTP, with every failure mode degrading to "keep
/// what you have".
class HttpSduiService implements SduiService {
  HttpSduiService({ApiService? apiService}) : _api = apiService;

  final ApiService? _api;

  static const String _cacheKey = 'sdui.last_good.v1';
  static const String _bootstrapCacheKey = 'sdui.bootstrap.v1';

  static const Duration _timeout = SduiService.timeout;

  ApiService get _service {
    final svc = _api;
    if (svc == null) {
      throw StateError('SduiService needs an ApiService; construct it with one.');
    }
    return svc;
  }

  /// Fetch the bootstrap payload. Returns `null` on any failure so the caller
  /// keeps its current values.
  @override
  Future<Map<String, dynamic>?> fetchBootstrap() async {
    try {
      final data = await _service
          .get(SduiService.bootstrapPath)
          .timeout(_timeout);
      if (!data.containsKey('schema_version')) {
        SduiLog.add(SduiLogKind.fetchFail, 'bootstrap missing schema_version');
        return null;
      }
      await _writeCache(_bootstrapCacheKey, data);
      SduiLog.add(SduiLogKind.fetchOk, 'bootstrap loaded');
      return data;
    } catch (e) {
      SduiLog.add(SduiLogKind.fetchFail, 'bootstrap failed: $e');
      return null;
    }
  }

  /// Fetch one screen spec. Returns `null` when it cannot be fetched or does
  /// not validate, which is the validation gate: an invalid payload never
  /// replaces a good cached one.
  @override
  Future<SduiSpec?> fetchScreen(String key) async {
    try {
      final data = await _service.get(SduiService.screenPath(key)).timeout(_timeout);
      final spec = SduiParse.trySpec(data);
      if (spec == null) {
        final errors = SduiSpec.fromJson(data).validate();
        SduiLog.add(
          SduiLogKind.validation,
          'rejected invalid spec: ${errors.take(3).join('; ')}',
          key: key,
        );
        return null;
      }
      await _writeScreen(spec);
      SduiLog.add(SduiLogKind.fetchOk, 'screen v${spec.version}', key: key);
      return spec;
    } catch (e) {
      SduiLog.add(SduiLogKind.fetchFail, 'screen fetch failed: $e', key: key);
      return null;
    }
  }

  /// Fetch every active screen for a role in one round trip.
  @override
  Future<Map<String, SduiSpec>> fetchManifest({String role = 'customer'}) async {
    try {
      final data = await _service
          .get(SduiService.manifestPath, queryParams: {'role': role})
          .timeout(_timeout);
      final raw = data['screens'];
      if (raw is! Map) return const {};

      final out = <String, SduiSpec>{};
      for (final entry in raw.entries) {
        final body = entry.value;
        if (body is Map) {
          final spec = SduiParse.trySpec({
            'key': entry.key,
            'version': (body['version'] as num?)?.toInt() ?? 1,
            'schema_version': (data['schema_version'] as num?)?.toInt() ?? 1,
            'root': body['root'],
          });
          if (spec != null) out[entry.key] = spec;
        }
      }
      SduiLog.add(SduiLogKind.fetchOk, 'manifest: ${out.length} screen(s)');
      return out;
    } catch (e) {
      SduiLog.add(SduiLogKind.fetchFail, 'manifest failed: $e');
      return const {};
    }
  }

  // ---------------------------------------------------------------------
  // Persistence
  //
  // Only specs that have already passed validation are written. There is no
  // code path that persists an unvalidated payload, so a corrupt cache cannot
  // be created by this class.
  // ---------------------------------------------------------------------

  Future<void> _writeCache(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      SduiLog.add(SduiLogKind.cacheWrite, 'wrote $key');
    } catch (e) {
      SduiLog.add(SduiLogKind.fetchFail, 'cache write failed: $e');
    }
  }

  Future<void> _writeScreen(SduiSpec spec) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = <String, dynamic>{
        'key': spec.key,
        'version': spec.version,
        'schema_version': spec.schemaVersion,
      };
      // Re-encode the root by round-tripping through the cache envelope so the
      // stored shape always matches what SduiSpec.fromJson expects.
      raw['root'] = _nodeToCache(spec.root);
      await prefs.setString('$_cacheKey.$spec.key', jsonEncode(raw));
      SduiLog.add(SduiLogKind.cacheWrite, 'wrote screen', key: spec.key);
    } catch (e) {
      SduiLog.add(SduiLogKind.fetchFail, 'screen cache write failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> readBootstrapCache() =>
      _readCache(_bootstrapCacheKey);

  @override
  Future<SduiSpec?> readScreenCache(String key) async {
    final data = await _readCache('$_cacheKey.$key');
    if (data == null) return null;
    return SduiParse.trySpec(data);
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      SduiLog.add(SduiLogKind.cacheReadFail, 'read $key failed: $e');
      return null;
    }
  }

  /// Preserve only the fields a cached node needs.
  ///
  /// Reconstructing rather than caching raw JSON keeps the cache tolerant of
  /// schema changes: a field dropped from [SduiNode] simply stops round-tripping
  /// instead of poisoning the cache with an unparseable shape.
  Map<String, dynamic> _nodeToCache(SduiNode node) {
    final out = <String, dynamic>{'type': node.type};
    void putIf(String k, Object? v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      if (v is num && v == 0) return;
      if (v is bool && !v) return;
      if (v is List && v.isEmpty) return;
      if (v is SduiPadding) return;
      if (v is SduiAction) return;
      if (v is SduiBanner) return;
      out[k] = v;
    }

    putIf('id', node.id);
    putIf('title', node.title);
    putIf('subtitle', node.subtitle);
    putIf('text', node.text);
    putIf('label', node.label);
    putIf('name', node.name);
    putIf('description', node.description);
    putIf('price', node.price);
    putIf('image_url', node.imageUrl);
    putIf('kitchen_id', node.kitchenId);
    putIf('dish_id', node.dishId);
    putIf('background_color', node.backgroundColor);
    putIf('color', node.color);
    putIf('style', node.style);
    putIf('variant', node.variant);
    putIf('item_builder_hint', node.itemBuilderHint);

    // Zero-valued numerics are meaningful here (height 0, gap 0), so only skip
    // them where a non-zero default is expected.
    if (node.gap != 0) out['gap'] = node.gap;
    if (node.borderRadius != 0) out['border_radius'] = node.borderRadius;
    if (node.height != 0) out['height'] = node.height;
    if (node.maxLines != 0) out['max_lines'] = node.maxLines;
    if (node.columns != 2) out['columns'] = node.columns;
    if (node.autoplayIntervalMs != 0) {
      out['autoplay_interval_ms'] = node.autoplayIntervalMs;
    }
    if (node.crossAxisAlign != CrossAxisAlignment.start) {
      out['cross_axis_align'] = switch (node.crossAxisAlign) {
        CrossAxisAlignment.center => 'center',
        CrossAxisAlignment.end => 'end',
        CrossAxisAlignment.stretch => 'stretch',
        _ => 'start',
      };
    }
    if (node.align != TextAlign.left) {
      out['align'] = switch (node.align) {
        TextAlign.center => 'center',
        TextAlign.right => 'right',
        TextAlign.justify => 'justify',
        _ => 'left',
      };
    }
    if (node.padding.all != 0 ||
        node.padding.left != 0 ||
        node.padding.top != 0 ||
        node.padding.right != 0 ||
        node.padding.bottom != 0) {
      out['padding'] = {
        if (node.padding.all != 0) 'all': node.padding.all,
        if (node.padding.left != node.padding.all) 'left': node.padding.left,
        if (node.padding.right != node.padding.right) 'right': node.padding.right,
        if (node.padding.top != node.padding.all) 'top': node.padding.top,
        if (node.padding.bottom != node.padding.all) 'bottom': node.padding.bottom,
      };
    }
    if (node.onTap.type != 'none') {
      out['on_tap'] = node.onTap.toJson();
    }
    if (node.action.type != 'none') {
      out['action'] = node.action.toJson();
    }
    if (node.banners.isNotEmpty) {
      out['banners'] = [
        for (final b in node.banners)
          {
            'id': b.id,
            'title': b.title,
            if (b.subtitle.isNotEmpty) 'subtitle': b.subtitle,
            if (b.imageUrl != null && b.imageUrl!.isNotEmpty)
              'image_url': b.imageUrl,
            if (b.action.type != 'none') 'action': b.action.toJson(),
          }
      ];
    }
    if (node.children.isNotEmpty) {
      out['children'] = [for (final c in node.children) _nodeToCache(c)];
    }
    // Booleans whose default is `true` need explicit preservation.
    if (!node.enabled) out['enabled'] = false;
    if (!node.available) out['available'] = false;
    if (!node.showRating) out['show_rating'] = false;
    if (!node.showDistance) out['show_distance'] = false;
    if (node.collapsible) out['collapsible'] = true;

    return out;
  }

  /// Direct fetch used by diagnostics to prove the endpoint is reachable.
  @override
  Future<bool> probe() async {
    try {
      final data = await _service.get(SduiService.bootstrapPath).timeout(_timeout);
      return data['schema_version'] != null;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }
}