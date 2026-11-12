import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../data/api/api_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/judge_result.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/fullscreen_image_viewer.dart';
import 'trip_end_screen.dart';

/// ⑤ 판정 결과: 정상 / 미하차 의심 / 재촬영
class JudgeResultScreen extends StatelessWidget {
  final JudgeResult result;

  const JudgeResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final ok = result.isOk;
    final needsCheck = result.isNeedsCheck;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final imageSource = _buildImageProvider();
    final imageHeroTag = result;

    return Scaffold(
      appBar: AppBar(title: const Text('판정 결과 · 종점')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Semantics(
                button: true,
                label: '이미지 미리보기. 탭하여 자세히 보기',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        transitionDuration: const Duration(milliseconds: 420),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 320,
                        ),
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            FullscreenImageViewer(
                              heroTag: imageHeroTag,
                              child: _buildResultImage(imageSource),
                            ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) =>
                                FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOutCubic,
                                  ),
                                  child: child,
                                ),
                      ),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Hero(
                              tag: imageHeroTag,
                              child: _buildResultImage(imageSource),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.zoom_in_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '자세히 보기',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ok
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : needsCheck
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ok
                      ? Theme.of(context).colorScheme.onTertiaryContainer
                      : needsCheck
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            if (result.checkReason != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '이유: ${result.checkReason}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _CountSummary(
                          label: '승차',
                          count: result.boardingCount,
                          icon: Icons.login_rounded,
                        ),
                        _CountSummary(
                          label: '잔류',
                          count: result.remainingCount,
                          icon: Icons.person_outline_rounded,
                          color: result.remainingCount == 0
                              ? AppTheme.ok
                              : AppTheme.danger,
                        ),
                        _CountSummary(
                          label: '하차',
                          count: result.alightedCount,
                          icon: Icons.logout_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (result.guidance != null && result.guidance!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                needsCheck ? '확인 안내' : '기사 안내',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                result.guidance!,
                                softWrap: true,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (result.alertId != null) ...[
              const SizedBox(height: 4),
              _AlertSummaryCard(alertId: result.alertId!),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showAnalysisInfo(context),
                icon: const Icon(Icons.info_outline, size: 20),
                label: const Text('분석 및 동작 방법에 대해'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result.shouldRetake) ...[
                PrimaryButton(
                  label: '재촬영',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: '운행 결과 확인',
                color: ok ? null : (isDarkMode ? Colors.white : Colors.black),
                foregroundColor: ok
                    ? null
                    : (isDarkMode ? Colors.black : Colors.white),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripEndScreen(
                      result: result,
                      busName: Session.currentTripBusName ?? '운행 차량',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Object? _buildImageProvider() {
    if (result.imagePath != null && result.imagePath!.trim().isNotEmpty) {
      final file = File(result.imagePath!);
      if (file.existsSync()) {
        return file;
      }
    }
    if (result.imageUrl != null && result.imageUrl!.trim().isNotEmpty) {
      return result.imageUrl!;
    }
    return null;
  }

  void _showAnalysisInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          decoration: AppTheme.sheetDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '분석 및 동작 방법',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '닫기',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '승차 사진에서 확인한 인원과 종점 사진에서 감지한 잔류 인원을 비교합니다. '
                '하차 인원은 승차 인원에서 잔류 인원을 뺀 값입니다. '
                '잔류 인원이 있으면 차량 내부를 직접 확인한 뒤 재촬영해 주세요.'
                '\n\n분석 및 동작이 정상적으로 작동하지 않으면 관리자에게 문의하여 주시기 바랍니다.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildResultImage(Object? imageSource) {
  if (imageSource is File) {
    return Image.file(
      imageSource,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
    );
  }
  if (imageSource is String) {
    return Image.network(
      imageSource,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.broken_image_outlined, size: 64)),
    );
  }
  return const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_not_supported_outlined, size: 64),
        SizedBox(height: 8),
        Text('분석에 사용한 사진을 표시할 수 없습니다.'),
      ],
    ),
  );
}

class _CountSummary extends StatelessWidget {
  const _CountSummary({
    required this.label,
    required this.count,
    required this.icon,
    this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            '$count명',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 경고의 AI 상황 요약 (alert.llm_summary).
/// 서버는 템플릿 한 줄을 먼저 저장하고, 응답 후 백그라운드에서 LLM 문장(감지 위치·확인할 곳)을
/// 덧붙인다. 그래서 몇 번 다시 불러와 보강된 요약이 오면 바꿔 보여준다.
class _AlertSummaryCard extends StatefulWidget {
  const _AlertSummaryCard({required this.alertId});

  final int alertId;

  @override
  State<_AlertSummaryCard> createState() => _AlertSummaryCardState();
}

class _AlertSummaryCardState extends State<_AlertSummaryCard> {
  static const _retryDelays = [
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 10),
  ];

  String? _summary;
  bool _failed = false;
  bool _enriched = false;
  int _attempt = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final alert = await ApiRepository.instance.getAlertDetail(widget.alertId);
      if (!mounted) return;
      final summary = (alert['llm_summary'] as String?)?.trim();
      setState(() {
        _summary = (summary == null || summary.isEmpty) ? null : summary;
        // LLM 보강이 끝나면 템플릿 첫 줄 뒤에 줄이 더 붙는다.
        _enriched = _summary?.contains('\n') ?? false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('경고 AI 요약 조회 실패: $e');
      if (mounted && _summary == null) setState(() => _failed = true);
    }
    if (!mounted || _enriched || _attempt >= _retryDelays.length) return;
    _timer = Timer(_retryDelays[_attempt++], _load);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed && _summary == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final waiting = !_enriched && _attempt < _retryDelays.length;

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'AI 상황 요약',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (waiting)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _summary ?? 'AI 요약을 불러오는 중입니다.',
                      softWrap: true,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
