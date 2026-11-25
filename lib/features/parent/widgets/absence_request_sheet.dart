import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/app_colors.dart';

/// 결석 신청 시트에서 고른 내용 (사유·첨부는 모두 선택)
class AbsenceRequest {
  const AbsenceRequest({this.reasonType, this.memo, this.files = const []});

  final String? reasonType;
  final String? memo;
  final List<XFile> files;
}

/// 서버·출석·결석 관리 화면과 같은 사유 코드
const absenceReasonTypes = <String, String>{
  'SICK': '질병',
  'FIELD_TRIP': '현장체험',
  'FAMILY': '가족 사유',
  'OTHER': '기타',
};

// 서버(routers/attendance_file.py) 규칙: 3개까지, 5MB 이하, JPG·PNG·PDF
const _maxFiles = 3;
const _maxFileBytes = 5 * 1024 * 1024;

/// 홈의 '결석 신청'·날짜 버튼에서 여는 시트: 사유 고르기, 메모, 사진·파일 첨부
Future<AbsenceRequest?> showAbsenceRequestSheet(
  BuildContext context, {
  required String childName,
  required String dateLabel,
  String? limitNote,
}) => showModalBottomSheet<AbsenceRequest>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.appColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) =>
      _AbsenceRequestSheet(
        childName: childName,
        dateLabel: dateLabel,
        limitNote: limitNote,
      ),
);

class _AbsenceRequestSheet extends StatefulWidget {
  const _AbsenceRequestSheet({
    required this.childName,
    required this.dateLabel,
    this.limitNote,
  });

  final String childName;
  final String dateLabel;

  /// 예) 이번 달 결석 2번 남음 (한 달 최대 4번)
  final String? limitNote;

  @override
  State<_AbsenceRequestSheet> createState() => _AbsenceRequestSheetState();
}

class _AbsenceRequestSheetState extends State<_AbsenceRequestSheet> {
  final _memo = TextEditingController();
  final List<XFile> _files = [];
  String? _reasonType;
  String? _fileError;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  bool _allowed(String name) =>
      RegExp(r'\.(jpe?g|png|pdf)$', caseSensitive: false).hasMatch(name);

  Future<void> _addFiles(List<XFile> picked) async {
    final errors = <String>[];
    for (final file in picked) {
      if (_files.length >= _maxFiles) {
        errors.add('첨부는 $_maxFiles개까지 할 수 있어요');
        break;
      }
      if (!_allowed(file.name)) {
        errors.add('${file.name}: JPG·PNG 사진이나 PDF만 첨부할 수 있어요');
        continue;
      }
      if (await File(file.path).length() > _maxFileBytes) {
        errors.add('${file.name}: 5MB 이하만 첨부할 수 있어요');
        continue;
      }
      _files.add(file);
    }
    if (mounted) {
      setState(() => _fileError = errors.isEmpty ? null : errors.join('\n'));
    }
  }

  // 사진은 긴 변 1600px JPEG 로 줄여서 가져온다 → 5MB 제한·HEIC 걱정 없음
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;
      final name = photo.name.toLowerCase();
      final asJpeg = name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png')
          ? photo
          : XFile(photo.path, name: '${photo.name.split('.').first}.jpg');
      await _addFiles([asJpeg]);
    } catch (_) {
      if (mounted) {
        setState(
          () => _fileError = source == ImageSource.camera
              ? '카메라를 열지 못했어요'
              : '사진을 고르지 못했어요',
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (result == null) return;
      await _addFiles([
        for (final file in result.files)
          if (file.path != null) XFile(file.path!, name: file.name),
      ]);
    } catch (_) {
      if (mounted) setState(() => _fileError = '파일을 고르지 못했어요');
    }
  }

  void _submit() {
    final memo = _memo.text.trim();
    Navigator.pop(
      context,
      AbsenceRequest(
        reasonType: _reasonType,
        memo: memo.isEmpty ? null : memo,
        files: List.of(_files),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.childName} · ${widget.dateLabel} 결석 신청',
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '사유와 첨부는 선택이에요. 그대로 신청해도 돼요.',
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
          ),
          if (widget.limitNote != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.limitNote!,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '결석 사유',
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in absenceReasonTypes.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _reasonType == entry.key,
                  selectedColor: AppColors.primary,
                  checkmarkColor: AppColors.onPrimary,
                  labelStyle: _reasonType == entry.key
                      ? const TextStyle(color: AppColors.onPrimary)
                      : null,
                  onSelected: (selected) => setState(
                    () => _reasonType = selected ? entry.key : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memo,
            minLines: 2,
            maxLines: 4,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '예) 열이 나서 병원에 가요',
              filled: true,
              fillColor: context.appColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.appColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.appColors.border),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '첨부 (진단서·체험학습 신청서 등)',
                  style: TextStyle(
                    color: context.appColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '사진 찍기',
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton(
                tooltip: '앨범에서 사진',
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
              ),
              IconButton(
                tooltip: 'PDF 파일',
                onPressed: _pickFiles,
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
            ],
          ),
          if (_files.isEmpty)
            Text(
              '사진이나 PDF를 3개까지 붙일 수 있어요 (5MB 이하)',
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final file in _files)
                  InputChip(
                    avatar: Icon(
                      file.name.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      size: 18,
                    ),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(file.name, overflow: TextOverflow.ellipsis),
                    ),
                    onDeleted: () => setState(() => _files.remove(file)),
                  ),
              ],
            ),
          if (_fileError != null) ...[
            const SizedBox(height: 6),
            Text(
              _fileError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appColors.textPrimary,
                      side: BorderSide(color: context.appColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('결석 신청'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
