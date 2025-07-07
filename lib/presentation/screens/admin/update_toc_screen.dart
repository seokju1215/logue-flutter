import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:logue/data/utils/update_toc_util.dart';

class UpdateTocScreen extends StatefulWidget {
  const UpdateTocScreen({Key? key}) : super(key: key);

  @override
  State<UpdateTocScreen> createState() => _UpdateTocScreenState();
}

class _UpdateTocScreenState extends State<UpdateTocScreen> {
  bool _isUpdating = false;
  int _booksWithoutTocCount = 0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadBooksCount();
  }

  Future<void> _loadBooksCount() async {
    try {
      final count = await UpdateTocUtil.getBooksWithoutTocCount();
      setState(() {
        _booksWithoutTocCount = count;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '목차 없는 책 개수 조회 실패: $e';
      });
    }
  }

  Future<void> _updateAllBooksToc() async {
    setState(() {
      _isUpdating = true;
      _statusMessage = '목차 업데이트 시작...';
    });

    try {
      await UpdateTocUtil.updateAllBooksToc();
      setState(() {
        _statusMessage = '✅ 목차 업데이트 완료!';
      });
      
      // 업데이트 후 개수 다시 조회
      await _loadBooksCount();
    } catch (e) {
      setState(() {
        _statusMessage = '❌ 목차 업데이트 실패: $e';
      });
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('목차 업데이트'),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '목차 업데이트 현황',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '목차가 없는 책: $_booksWithoutTocCount개',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '알라딘 API를 통해 기존 DB의 책들 목차를 업데이트합니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateAllBooksToc,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.black900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUpdating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('업데이트 중...'),
                        ],
                      )
                    : const Text(
                        '모든 책 목차 업데이트',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('✅') 
                      ? Colors.green[50] 
                      : _statusMessage.contains('❌') 
                          ? Colors.red[50] 
                          : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.contains('✅') 
                        ? Colors.green 
                        : _statusMessage.contains('❌') 
                            ? Colors.red 
                            : Colors.blue,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: _statusMessage.contains('✅') 
                        ? Colors.green[800] 
                        : _statusMessage.contains('❌') 
                            ? Colors.red[800] 
                            : Colors.blue[800],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주의사항',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 알라딘 API 호출 제한으로 인해 한 번에 100개씩 처리됩니다.\n'
                      '• 각 책당 200ms 대기하여 API 제한을 준수합니다.\n'
                      '• 업데이트 중에는 앱을 종료하지 마세요.\n'
                      '• 인터넷 연결이 안정적인지 확인하세요.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 