import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/token_storage.dart';
import '../config/env.dart';

String _newRequestId() {
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(
    36,
  );
  final random = Random.secure().nextInt(0x7fffffff).toRadixString(36);
  return '$timestamp-$random';
}

typedef TermsRequiredHandler = Future<bool> Function(DioException error);

/// 모든 API 호출의 공통 클라이언트 (JWT 자동 첨부)
class ApiClient {
  ApiClient._() {
    dio = _buildDio();
  }
  static final ApiClient instance = ApiClient._();

  late final Dio dio;

  Dio _buildDio() =>
      Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 15),
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              options.headers['X-Request-ID'] =
                  options.headers['X-Request-ID'] ?? _newRequestId();
              if (options.extra['skipAuth'] == true) {
                options.headers.remove('Authorization');
                handler.next(options);
                return;
              }
              final token = await TokenStorage.read();
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
            onResponse: (response, handler) {
              if (kDebugMode) {
                final requestId =
                    response.requestOptions.headers['X-Request-ID'] ??
                    'unknown';
                debugPrint(
                  'API 응답: ${response.requestOptions.method} '
                  '${response.requestOptions.path} HTTP ${response.statusCode} '
                  'request_id=$requestId',
                );
              }
              handler.next(response);
            },
            onError: (error, handler) async {
              if (kDebugMode) {
                final requestId =
                    error.requestOptions.headers['X-Request-ID'] ?? 'unknown';
                debugPrint(
                  'API 오류: ${error.requestOptions.method} '
                  '${error.requestOptions.path} '
                  'HTTP ${error.response?.statusCode ?? 'none'} '
                  'type=${error.type.name} request_id=$requestId',
                );
              }

              if (!_isTermsRequired(error) ||
                  error.requestOptions.extra['skipTermsRequired'] == true ||
                  error.requestOptions.extra['termsRequiredRetried'] == true ||
                  _termsRequiredHandler == null) {
                handler.next(error);
                return;
              }

              try {
                final accepted = await _termsRequiredHandler!(error);
                if (!accepted) {
                  handler.next(error);
                  return;
                }
                final options = error.requestOptions;
                options.extra['termsRequiredRetried'] = true;
                handler.resolve(await dio.fetch<dynamic>(options));
              } on DioException catch (retryError) {
                handler.reject(retryError);
              } catch (retryError) {
                handler.reject(
                  DioException(
                    requestOptions: error.requestOptions,
                    error: retryError,
                  ),
                );
              }
            },
          ),
        );

  Object? _termsRequiredOwner;
  TermsRequiredHandler? _termsRequiredHandler;

  void registerTermsRequiredHandler(
    Object owner,
    TermsRequiredHandler handler,
  ) {
    _termsRequiredOwner = owner;
    _termsRequiredHandler = handler;
  }

  void unregisterTermsRequiredHandler(Object owner) {
    if (!identical(_termsRequiredOwner, owner)) return;
    _termsRequiredOwner = null;
    _termsRequiredHandler = null;
  }

  static bool _isTermsRequired(DioException error) {
    if (error.response?.statusCode != 403) return false;
    final data = error.response?.data;
    return data is Map && data['detail'] == 'TERMS_REQUIRED';
  }
}
