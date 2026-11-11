import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_project_app/core/errors/app_error_message.dart';

void main() {
  const fallback = '작업을 완료하지 못했습니다. 다시 시도해 주세요.';

  test('로그인 인증 오류는 사용자용 안내로 변환한다', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/auth/login'),
      response: Response(
        requestOptions: RequestOptions(path: '/auth/login'),
        statusCode: 401,
        data: {'detail': 'sensitive server diagnostic'},
      ),
    );

    expect(
      AppErrorMessage.from(error, fallback: fallback, isLogin: true),
      '이메일 또는 비밀번호를 확인해 주세요.',
    );
    expect(
      AppErrorMessage.from(error, fallback: fallback),
      '로그인이 만료되었습니다. 다시 로그인해 주세요.',
    );
  });

  test('504와 네트워크 오류는 재시도 가능한 안내로 변환한다', () {
    final timeout = DioException(
      requestOptions: RequestOptions(path: '/'),
      response: Response(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 504,
      ),
    );
    final connection = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.connectionError,
    );

    expect(
      AppErrorMessage.from(timeout, fallback: fallback),
      '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해 주세요.',
    );
    expect(
      AppErrorMessage.from(connection, fallback: fallback),
      '인터넷 연결을 확인한 후 다시 시도해 주세요.',
    );
  });

  test('알 수 없는 오류에서는 기술 상세 대신 작업별 대체 문구를 사용한다', () {
    expect(
      AppErrorMessage.from(
        StateError('internal implementation detail'),
        fallback: fallback,
      ),
      fallback,
    );
  });
}
