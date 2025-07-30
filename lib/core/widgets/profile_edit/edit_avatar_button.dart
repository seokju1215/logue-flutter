import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:my_logue/core/widgets/dialogs/avatar_bottom_sheet.dart';

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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) => AvatarBottomSheet(
        onPhotoLibraryTap: _requestPhotoLibraryPermission,
        onDeleteTap: _deleteAvatar,
      ),
    );
  }

  Future<void> _deleteAvatar() async {
    try {
      setState(() => _isUploading = true);
      
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('사용자 정보를 찾을 수 없습니다.');

      // 프로필에서 avatar_url을 'basic'으로 변경
      await supabase.from('profiles').update({
        'avatar_url': 'basic',
      }).eq('id', userId);

      widget.onAvatarChanged('basic');
      _showSnackBar('프로필 사진이 삭제되었습니다.', AppColors.blue500);
    } catch (e) {
      debugPrint('❌ 프로필 사진 삭제 실패: $e');
      _showSnackBar('프로필 사진 삭제에 실패했습니다.', AppColors.red500);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _requestPhotoLibraryPermission() async {
    try {
      if (Platform.isIOS) {
        // iOS에서는 image_picker가 직접 권한을 처리하도록 함
        _pickImage(ImageSource.gallery);
      } else {
        // Android 13+ (API 33+)
        if (Platform.isAndroid) {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          final sdkInt = androidInfo.version.sdkInt;
          
          if (sdkInt >= 33) {
            // Android 13+ 에서는 READ_MEDIA_IMAGES 권한 사용
            final photosStatus = await Permission.photos.status;
            if (photosStatus.isDenied) {
              final result = await Permission.photos.request();
              if (result.isGranted) {
                _pickImage(ImageSource.gallery);
              } else {
                _showSnackBar('사진 접근 권한이 필요합니다.', AppColors.red500);
              }
            } else if (photosStatus.isGranted) {
              _pickImage(ImageSource.gallery);
            } else {
              _showSnackBar('사진 접근 권한이 필요합니다.', AppColors.red500);
            }
          } else {
            // Android 12 이하에서는 storage 권한 사용
            final storageStatus = await Permission.storage.status;
            if (storageStatus.isDenied) {
              final result = await Permission.storage.request();
              if (result.isGranted) {
                _pickImage(ImageSource.gallery);
              } else {
                _showSnackBar('저장소 접근 권한이 필요합니다.', AppColors.red500);
        }
            } else if (storageStatus.isGranted) {
              _pickImage(ImageSource.gallery);
            } else {
              _showSnackBar('저장소 접근 권한이 필요합니다.', AppColors.red500);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('📸 권한 요청 중 오류: $e');
      _pickImage(ImageSource.gallery);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      debugPrint('📸 이미지 선택 시작 - source: $source');

      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        // iOS에서 이미지 형식 문제 해결
        requestFullMetadata: false,
        // iOS에서 이미지 처리 개선
        preferredCameraDevice: CameraDevice.rear,
      );

      debugPrint('📸 선택된 이미지: ${picked?.path}');
      if (picked == null) {
        debugPrint('📸 이미지 선택 취소됨');
        return;
      }

      // 이미지 파일 존재 확인
      final file = File(picked.path);
      if (!await file.exists()) {
        debugPrint('📸 이미지 파일이 존재하지 않음: ${picked.path}');
        _showSnackBar('이미지 파일을 찾을 수 없습니다.', AppColors.red500);
        return;
      }

      // 이미지 파일 읽기 시도
      Uint8List fileBytes;
      try {
        // XFile에서 직접 읽기 시도
        fileBytes = await picked.readAsBytes();
        debugPrint('📸 XFile 읽기 성공: ${fileBytes.length} bytes');
      } catch (e) {
        debugPrint('📸 XFile 읽기 실패: $e');
        _showSnackBar('이미지 파일을 읽을 수 없습니다. 다른 이미지를 선택해주세요.', AppColors.red500);
        return;
      }

      final fileName = p.basename(picked.path);
      debugPrint('📸 파일 크기: ${fileBytes.length} bytes');

      if (fileBytes.length == 0) {
        debugPrint('📸 이미지 파일이 비어있음');
        _showSnackBar('이미지 파일이 비어있습니다.', AppColors.red500);
        return;
      }

      if (fileBytes.length > 5 * 1024 * 1024) {
        debugPrint('📸 파일 크기 초과: ${fileBytes.length} bytes');
        _showSnackBar('이미지 크기가 너무 큽니다. 5MB 이하의 이미지를 선택해주세요.', AppColors.red500);
        return;
      }

      setState(() => _isUploading = true);

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      debugPrint('📸 사용자 ID: $userId');
      if (userId == null) throw Exception('사용자 정보를 찾을 수 없습니다.');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last.toLowerCase();
      final uniqueFileName = 'avatar_$timestamp.$extension';
      final storagePath = 'avatars/$userId/$uniqueFileName';
      debugPrint('📸 저장 경로: $storagePath');

      debugPrint('📸 Supabase 업로드 시작');
      await supabase.storage.from('avatars').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: 'image/$extension',
        ),
      );
      debugPrint('📸 Supabase 업로드 완료');

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);
      debugPrint('📸 공개 URL: $publicUrl');
      widget.onAvatarChanged(publicUrl);
    } catch (e) {
      debugPrint('🔥 프로필 이미지 업로드 실패: $e');

        String errorMessage = '프로필 이미지 변경에 실패했습니다.';
      
      if (e.toString().contains('invalid_image')) {
        errorMessage = '이미지 파일이 손상되었거나 지원되지 않는 형식입니다.';
      } else if (e.toString().contains('NSItemProviderErrorDomain')) {
        errorMessage = '이미지 로딩 중 오류가 발생했습니다. 다른 이미지를 선택해주세요.';
      } else if (e.toString().contains('permission')) {
        errorMessage = '이미지 접근 권한이 필요합니다.';
        } else if (e.toString().contains('network')) {
          errorMessage = '네트워크 연결을 확인해주세요.';
        } else if (e.toString().contains('storage')) {
          errorMessage = '저장소 접근에 실패했습니다.';
        }
      
      _showSnackBar(errorMessage, AppColors.red500);
    } finally {
      if (mounted) setState(() => _isUploading = false);
      }
    }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
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