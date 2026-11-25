import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/errors/app_error_message.dart';
import '../../../core/notifications/in_app_notification_banner.dart';
import '../../../data/api/api_repository.dart';

/// 결석 사유 첨부 파일 하나
class AbsenceFile {
  const AbsenceFile({required this.id, required this.name, this.contentType});

  final int id;
  final String name;
  final String? contentType;

  bool get isPdf =>
      contentType == 'application/pdf' || name.toLowerCase().endsWith('.pdf');
  bool get isImage =>
      contentType?.startsWith('image/') == true ||
      RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(name);

  factory AbsenceFile.fromJson(Map<String, dynamic> json) {
    final id = json['file_id'] ?? json['id'];
    return AbsenceFile(
      id: id is int ? id : int.parse(id.toString()),
      name: json['file_name'] as String? ?? '첨부 파일',
      contentType: json['content_type'] as String?,
    );
  }

  static List<AbsenceFile> listFrom(Object? value) => value is List
      ? [
          for (final item in value)
            AbsenceFile.fromJson(Map<String, dynamic>.from(item as Map)),
        ]
      : const [];
}

/// 관리자: 첨부 파일(사진·PDF) 열어 보기
Future<void> openAbsenceFile(BuildContext context, AbsenceFile file) async {
  File? cached;
  try {
    final bytes = await ApiRepository.instance.getAdminAttendanceFile(file.id);
    final dir = await getTemporaryDirectory();
    final safeName = file.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    cached = File(
      '${dir.path}${Platform.pathSeparator}absence_${file.id}_$safeName',
    );
    await cached.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    final shown = cached;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 520,
          height: 600,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: file.isImage
                    ? InteractiveViewer(
                        child: Image.file(shown, fit: BoxFit.contain),
                      )
                    : file.isPdf
                    ? SfPdfViewer.file(shown)
                    : const Center(child: Text('미리볼 수 없는 파일 형식입니다.')),
              ),
            ],
          ),
        ),
      ),
    );
  } catch (error) {
    InAppNotificationBanner.showMessage(
      AppErrorMessage.from(error, fallback: '첨부 파일을 열지 못했습니다.'),
    );
  } finally {
    if (cached != null && await cached.exists()) await cached.delete();
  }
}

/// 첨부 파일 칩 목록 (눌러서 보기)
class AbsenceFileChips extends StatelessWidget {
  const AbsenceFileChips({super.key, required this.files});

  final List<AbsenceFile> files;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final file in files)
        ActionChip(
          avatar: Icon(
            file.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            size: 18,
          ),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(file.name, overflow: TextOverflow.ellipsis),
          ),
          onPressed: () => openAbsenceFile(context, file),
        ),
    ],
  );
}

/// 관리자 알림에서 결석 알림을 누르면: 학생·날짜·사유·첨부를 보여 주는 시트
Future<void> showAbsenceDetailSheet(
  BuildContext context, {
  required int attendanceId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _AbsenceDetailSheet(attendanceId: attendanceId),
);

class _AbsenceDetailSheet extends StatefulWidget {
  const _AbsenceDetailSheet({required this.attendanceId});

  final int attendanceId;

  @override
  State<_AbsenceDetailSheet> createState() => _AbsenceDetailSheetState();
}

class _AbsenceDetailSheetState extends State<_AbsenceDetailSheet> {
  late Future<Map<String, dynamic>> _detail = ApiRepository.instance
      .getAdminAttendanceDetail(widget.attendanceId);

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  void _reload() => setState(() {
    _detail = ApiRepository.instance.getAdminAttendanceDetail(
      widget.attendanceId,
    );
  });

  String _date(Object? raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return '-';
    return '${date.year}년 ${date.month}월 ${date.day}일 (${_weekdays[date.weekday - 1]})';
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppErrorMessage.from(
                      snapshot.error!,
                      fallback: '결석 정보를 불러오지 못했습니다.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final d = snapshot.data!;
        final student = d['student'] is Map
            ? Map<String, dynamic>.from(d['student'] as Map)
            : const <String, dynamic>{};
        final bus = d['bus'] is Map
            ? Map<String, dynamic>.from(d['bus'] as Map)
            : const <String, dynamic>{};
        final absent = d['is_absent'] == true;
        final files = AbsenceFile.listFrom(d['files']);
        final reasonLabel = d['reason_label'] as String?;
        final memo = (d['reason_memo'] as String?)?.trim();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.event_busy_rounded, color: colors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${student['name'] ?? '학생'} 결석',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(absent ? '결석' : '취소됨'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (!absent)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '학부모가 이 결석을 취소했어요. 이 날은 탑승 예정이에요.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              const Divider(height: 24),
              _row(context, '날짜', _date(d['date'])),
              _row(
                context,
                '학생',
                [
                  student['name'] ?? '-',
                  ?student['class_name'],
                ].join(' · '),
              ),
              _row(
                context,
                '버스',
                bus.isEmpty
                    ? '배정 없음'
                    : [bus['name'], ?bus['plate_no']].join(' · '),
              ),
              if (absent) ...[
                _row(context, '사유', reasonLabel ?? '선택 안 함'),
                _row(
                  context,
                  '메모',
                  memo == null || memo.isEmpty ? '없음' : memo,
                ),
                const SizedBox(height: 8),
                Text(
                  '첨부 파일 ${files.length}개',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                if (files.isEmpty)
                  const Text('첨부한 파일이 없어요.')
                else
                  AbsenceFileChips(files: files),
              ],
            ],
          ),
        );
      },
    );
  }
}
