import 'package:flutter/material.dart';

import '../../data/mock/mock_repository.dart';
import '../../widgets/primary_button.dart';
import 'dropoff_capture_screen.dart';

/// ③ 승차 촬영: POST /trips/{id}/boarding-photo → YOLO 승차 인원
class BoardingCaptureScreen extends StatefulWidget {
  const BoardingCaptureScreen({super.key});

  @override
  State<BoardingCaptureScreen> createState() => _BoardingCaptureScreenState();
}

class _BoardingCaptureScreenState extends State<BoardingCaptureScreen> {
  bool _loading = false;
  int? _count;

  Future<void> _capture() async {
    setState(() => _loading = true);
    final count = await MockRepository.instance.uploadBoardingPhoto();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _count = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('승차 촬영')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _count == null
                    ? const Icon(Icons.photo_camera, size: 96, color: Colors.grey)
                    : Text('YOLO 승차 인원: $_count명',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
            if (_count == null)
              PrimaryButton(label: '📷 승차 촬영', loading: _loading, onPressed: _capture)
            else
              PrimaryButton(
                label: '종점으로 이동',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DropoffCaptureScreen()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
