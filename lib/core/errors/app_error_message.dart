import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AppErrorMessage {
  AppErrorMessage._();

  static String from(
    Object error, {
    required String fallback,
    bool isLogin = false,
  }) {
    if (kDebugMode) {
      final diagnostic = error is DioException
          ? '${error.runtimeType}, type: ${error.type}, HTTP: ${error.response?.statusCode ?? 'none'}'
          : error.runtimeType.toString();
      debugPrint('앱 오류 분류: $diagnostic');
    }

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return switch (statusCode) {
          400 => '요청 내용을 확인한 후 다시 시도해 주세요.',
          401 =>
            isLogin ? '이메일 또는 비밀번호를 확인해 주세요.' : '로그인이 만료되었습니다. 다시 로그인해 주세요.',
          403 => '이 작업을 수행할 권한이 없습니다.',
          404 => '요청한 정보를 찾을 수 없습니다.',
          408 || 504 => '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해 주세요.',
          409 => '정보가 변경되었습니다. 새로고침한 후 다시 시도해 주세요.',
          422 => '입력한 내용을 확인해 주세요.',
          429 => '요청이 많아 처리할 수 없습니다. 잠시 후 다시 시도해 주세요.',
          >= 500 => '서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.',
          _ => fallback,
        };
      }

      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해 주세요.',
        DioExceptionType.connectionError => '인터넷 연결을 확인한 후 다시 시도해 주세요.',
        DioExceptionType.cancel => '요청이 취소되었습니다. 다시 시도해 주세요.',
        _ => fallback,
      };
    }

    if (error is SocketException) {
      return '인터넷 연결을 확인한 후 다시 시도해 주세요.';
    }

    return fallback;
  }
}
