import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class EditAvatarButton extends StatefulWidget {
  final String avatarUrl;
  final void Function(String) onAvatarChanged;

  const EditAvatarButton({
    super.key,
    required this.avatarUrl,
    required this.onAvatarChanged,
  });

  @override
  State<EditAvatarButton> createState() => _EditAvatarButtonState();
}

class _EditAvatarButtonState extends State<EditAvatarButton> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _showImageSourceDialog() async {
    debugPrint('📸 이미지 선택 시작');
    _pickImage(ImageSource.gallery);
  }

  Future<bool> _requestGalleryPermission() async {
    try {
      if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (status.isGranted) return true;
        if (status.isPermanentlyDenied) {
          if (mounted) openAppSettings();
        }
        return false;
      } else {
        // Android
        final status = await Permission.storage.request();
        if (status.isGranted) return true;
        if (status.isPermanentlyDenied) {
          if (mounted) openAppSettings();
        }
        return false;
      }
    } catch (e) {
      debugPrint('📸 권한 요청 중 오류: $e');
      return false;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      debugPrint('📸 이미지 선택 - source: $source');

      final hasPermission = await _requestGalleryPermission();
      debugPrint('📸 권한 확인 결과: $hasPermission');

      if (!hasPermission) {
        debugPrint('📸 권한이 허용되지 않음');
        return;
      }

      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      debugPrint('📸 선택된 이미지: ${picked?.path}');
      if (picked == null) {
        debugPrint('📸 이미지 선택 취소됨');
        return;
      }

      final fileBytes = await picked.readAsBytes();
      final fileName = p.basename(picked.path);
      debugPrint('📸 파일 크기: ${fileBytes.length} bytes');

      if (fileBytes.length > 5 * 1024 * 1024) {
        debugPrint('📸 파일 크기 초과: ${fileBytes.length} bytes');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지 크기가 너무 큽니다. 5MB 이하의 이미지를 선택해주세요.'),
              backgroundColor: AppColors.red500,
            ),
          );
        }
        return;
      }

      setState(() => _isUploading = true);

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last.toLowerCase();
      final uniqueFileName = 'avatar_$timestamp.$extension';
      final storagePath = 'avatars/$userId/$uniqueFileName';

      await supabase.storage.from('avatars').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: 'image/$extension',
        ),
      );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);
      debugPrint('📸 프로필 이미지 업로드 성공: $publicUrl');

      widget.onAvatarChanged(publicUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필 이미지가 변경되었습니다.'),
            backgroundColor: AppColors.blue500,
          ),
        );
      }
    } catch (e) {
      debugPrint('🔥 프로필 이미지 업로드 실패: $e');

      if (mounted) {
        String errorMessage = '프로필 이미지 변경에 실패했습니다.';
        if (e.toString().contains('permission')) {
          errorMessage = '접근 권한이 필요합니다.';
        } else if (e.toString().contains('network')) {
          errorMessage = '네트워크 연결을 확인해주세요.';
        } else if (e.toString().contains('storage')) {
          errorMessage = '저장소 접근에 실패했습니다.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.red500,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBasic = widget.avatarUrl == 'basic';

    return GestureDetector(
      onTap: _isUploading ? null : _showImageSourceDialog,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white,
              backgroundImage: isBasic ? null : NetworkImage(widget.avatarUrl),
              child: isBasic
                  ? ClipOval(
                child: Image.asset(
                  'assets/basic_avatar.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              )
                  : null,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white,
              child: _isUploading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.camera_alt_outlined, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}