import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/api/api_repository.dart';
import '../data/models/child_location.dart';

/// 입력하는 동안 주소 후보를 자동으로 보여 주는 입력창.
class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.onEdited,
    this.labelText = '주소',
    this.hintText = '도로명 주소를 입력하면 후보가 표시됩니다.',
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final ValueChanged<AddressCandidate> onSelected;

  /// 사용자가 직접 글자를 고쳤을 때 (후보 선택으로 인한 변경은 제외).
  final VoidCallback? onEdited;
  final String labelText;
  final String hintText;
  final int maxLines;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  static const _debounce = Duration(milliseconds: 400);

  Timer? _timer;
  CancelToken? _cancelToken;
  int _requestId = 0;
  List<AddressCandidate> _candidates = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onEdited?.call();
    _timer?.cancel();
    _cancelToken?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _candidates = const [];
        _loading = false;
        _searched = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _timer = Timer(_debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    final token = CancelToken();
    _cancelToken = token;
    try {
      final result = await ApiRepository.instance.searchAddressCandidates(
        query,
        cancelToken: token,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _candidates = result;
        _searched = true;
        _loading = false;
      });
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || !mounted || requestId != _requestId) {
        return;
      }
      _fail();
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      _fail();
    }
  }

  void _fail() {
    setState(() {
      _candidates = const [];
      _searched = false;
      _loading = false;
      _error = '주소를 검색하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    });
  }

  void _select(AddressCandidate candidate) {
    _timer?.cancel();
    _cancelToken?.cancel();
    _requestId++;
    widget.controller.text = candidate.address;
    widget.controller.selection = TextSelection.collapsed(
      offset: candidate.address.length,
    );
    setState(() {
      _candidates = const [];
      _searched = false;
      _loading = false;
    });
    widget.onSelected(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: TextStyle(color: colors.error)),
          )
        else if (_searched && !_loading && _candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '검색 결과가 없습니다. 도로명 또는 지번 주소로 다시 입력해 주세요.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
          ),
        if (_candidates.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 6),
            child: Column(
              children: [
                for (final candidate in _candidates)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      candidate.name != null
                          ? Icons.business_outlined
                          : Icons.place_outlined,
                    ),
                    title: Text(candidate.name ?? candidate.address),
                    subtitle: candidate.name != null
                        ? Text(candidate.address)
                        : candidate.jibunAddress != null &&
                              candidate.jibunAddress != candidate.address
                        ? Text(candidate.jibunAddress!)
                        : null,
                    onTap: () => _select(candidate),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
