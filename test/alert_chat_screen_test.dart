import 'package:dio/dio.dart';
import 'package:final_project_app/core/network/api_client.dart';
import 'package:final_project_app/features/parent/alert_chat_screen.dart';
import 'package:final_project_app/theme/app_colors.dart';
import 'package:final_project_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const greeting =
      '안녕하세요! 통학버스 안전 안내 AI예요.\n경고 알림의 뜻, 결석 신청, 자녀 연결 방법 등을 물어보세요.';
  const serverGreeting = '서버에서 받은 인사';
  const suggestion = '추천 질문을 알려주세요';
  final requests = <RequestOptions>[];

  setUp(() {
    requests.clear();
    final dio = ApiClient.instance.dio;
    final original = dio.interceptors.toList();
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: options.path == '/chat/hello'
                  ? {
                      'reply': serverGreeting,
                      'suggestions': [suggestion],
                    }
                  : {
                      'reply': '봇의 답변입니다.',
                      'suggestions': [suggestion],
                    },
            ),
          );
        },
      ),
    );
    addTearDown(() {
      dio.interceptors.clear();
      dio.interceptors.addAll(original);
    });
  });

  testWidgets('인사와 답변을 말풍선으로 표시하고 추천 질문과 대화 기록을 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AlertChatScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 채팅'), findsOneWidget);
    expect(find.text('챗봇'), findsNothing);
    expect(find.text(greeting), findsOneWidget);
    expect(find.text(serverGreeting), findsNothing);

    Container bubbleFor(String text) {
      return tester.widget<Container>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.constraints?.maxWidth ==
                        tester.view.physicalSize.width /
                            tester.view.devicePixelRatio *
                            0.75,
              ),
            )
            .first,
      );
    }

    final botBubble = bubbleFor(greeting);
    final botDecoration = botBubble.decoration! as BoxDecoration;
    expect(botDecoration.color, AppColors.surface);
    expect(botDecoration.border, Border.all(color: AppColors.border));
    expect(
      botDecoration.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
    );
    expect(
      botBubble.padding,
      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.isCollapsed, isTrue);
    expect(field.decoration!.filled, isFalse);
    expect(field.decoration!.border, InputBorder.none);
    final inputContainer = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final inputDecoration = inputContainer.decoration! as BoxDecoration;
    expect(inputDecoration.color, AppColors.surface);
    expect(inputDecoration.border, Border.all(color: AppColors.border));
    expect(inputDecoration.borderRadius, BorderRadius.circular(24));
    final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(mask.blendMode, BlendMode.dstIn);

    await tester.tap(find.text(suggestion));
    await tester.pumpAndSettle();
    final chatRequest = requests.singleWhere(
      (request) => request.path == '/chat',
    );
    expect(chatRequest.data['message'], suggestion);
    expect(chatRequest.data['history'], [
      {'role': 'bot', 'text': serverGreeting},
    ]);
    expect(find.text('봇의 답변입니다.'), findsOneWidget);
    final userBubble = bubbleFor(suggestion);
    final userDecoration = userBubble.decoration! as BoxDecoration;
    expect(userDecoration.color, AppColors.primary);
    expect(
      userDecoration.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
    );
    final userText = tester.widget<SelectableText>(
      find.descendant(
        of: find.byWidget(userBubble),
        matching: find.byType(SelectableText),
      ),
    );
    expect(userText.style!.color, AppColors.textPrimary);

    await tester.tap(find.byTooltip('새 채팅'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('예'));
    await tester.pumpAndSettle();
    expect(find.text(greeting), findsOneWidget);
    expect(find.text('봇의 답변입니다.'), findsNothing);
    expect(
      requests.where((request) => request.path == '/chat/hello').length,
      2,
    );
  });

  testWidgets('알림에서 전달한 첫 답변은 인사로 바꾸지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AlertChatScreen(
          initialResponse: {'answer': '알림에 대한 답변입니다.'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('알림에 대한 답변입니다.'), findsOneWidget);
    expect(find.text(greeting), findsNothing);
    expect(requests, isEmpty);
  });

  testWidgets('추천 질문은 가로로 스크롤해 선택할 수 있다', (tester) async {
    const lastSuggestion = '마지막 추천 질문을 선택합니다';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AlertChatScreen(
          initialResponse: {
            'answer': '알림 답변',
            'suggestions': [
              '첫 번째로 긴 추천 질문입니다',
              '두 번째로 긴 추천 질문입니다',
              '세 번째로 긴 추천 질문입니다',
              lastSuggestion,
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(ShaderMask),
      matching: find.byType(ListView),
    );
    await tester.drag(list, const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(lastSuggestion));
    await tester.pumpAndSettle();
    expect(
      requests
          .singleWhere((request) => request.path == '/chat')
          .data['message'],
      lastSuggestion,
    );
  });

  testWidgets('어두운 테마에서도 입력과 글자 수 표시를 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const AlertChatScreen()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '가' * 280);
    await tester.pumpAndSettle();
    expect(find.text('280/500'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).style!.color,
      AppColors.textPrimary,
    );
    await tester.tap(find.byTooltip('전송'));
    await tester.pumpAndSettle();
    expect(
      requests
          .singleWhere((request) => request.path == '/chat')
          .data['message'],
      '가' * 280,
    );
  });
}
