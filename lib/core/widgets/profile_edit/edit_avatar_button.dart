import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/dialogs/avatar_bottom_sheet.dart';

class EditAvatarButton extends StatefulWidget {
  final String avatarUrl;
  final void Function(String, File?) onAvatarChanged;
  final File? tempImageFile;

  const EditAvatarButton({
    super.key,
    required this.avatarUrl,
    required this.onAvatarChanged,
    this.tempImageFile,
  });

  @override
  State<EditAvatarButton> createState() => _EditAvatarButtonState();
}

class _EditAvatarButtonState extends State<EditAvatarButton> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  File? _tempImageFile; // 임시 이미지 파일 저장

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,            // ✅ 루트 네비게이터 위에 띄워서 BottomNavigationBar까지 덮음
      isScrollControlled: true,          // ✅ 전체 높이/패딩 제어 가능
      backgroundColor: Colors.transparent,
      // barrierColor: Colors.black54,   // 필요하면 반투명 오버레이
      builder: (ctx) {
        // ✅ 불필요한 여백 없이 화면 최하단에서 시작
        return SafeArea(
          top: false,                    // 상단만 보호, 하단은 홈 인디케이터까지 덮을 수 있도록
          // bottom: false,              // 홈 인디케이터까지 완전히 덮고 싶으면 주석 해제
          child: AvatarBottomSheet(
            onPhotoLibraryTap: () => _pickImage(ImageSource.gallery),
            onDeleteTap: _deleteAvatar,
            isDefaultAvatar: widget.avatarUrl == 'basic',
          ),
        );
      },
    );
  }

  Future<void> _deleteAvatar() async {
    try {
      setState(() => _isUploading = true);
      
      // 임시 파일 제거
      _tempImageFile = null;
      
      // 아바타 삭제는 저장 버튼을 눌렀을 때만 데이터베이스에 반영
      widget.onAvatarChanged('basic', null);
    } catch (e) {
      debugPrint('❌ 프로필 사진 삭제 실패: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ✅ Photo Picker 사용으로 권한 요청 불필요
  // Android: Photo Picker (ActivityX 1.7.0+)로 권한 없이 사용자가 선택한 항목만 일회성 접근
  // iOS: image_picker가 자체적으로 권한 처리

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

      // 임시 파일로 저장 (Storage 업로드는 저장 버튼 클릭 시에)
      _tempImageFile = file;
      debugPrint('📸 임시 파일 저장 완료: ${file.path}');
      
      // UI에 즉시 반영 (프론트엔드만)
      widget.onAvatarChanged('temp_${file.path}', file);
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

  ImageProvider? _getBackgroundImage() {
    if (widget.tempImageFile != null) {
      // 임시 파일이 있으면 FileImage 사용
      return FileImage(widget.tempImageFile!);
    } else if (widget.avatarUrl != 'basic' && !widget.avatarUrl.startsWith('temp_')) {
      // 기존 네트워크 이미지
      return NetworkImage(widget.avatarUrl);
    }
    return null;
  }

  Widget? _getChildImage() {
    if (widget.tempImageFile != null) {
      // 임시 파일이 있으면 아무것도 표시하지 않음 (backgroundImage에서 처리)
      return null;
    } else if (widget.avatarUrl == 'basic') {
      // 기본 아바타
      return ClipOval(
        child: Image.asset(
          'assets/basic_avatar.png',
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    }
    return null;
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
              backgroundImage: _getBackgroundImage(),
              child: _getChildImage(),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(// 테두리 두께만큼 패딩
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.black300, // 테두리 색상
                  width: 1,           // 테두리 두께
                ),
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: _isUploading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(
                  Icons.camera_alt_outlined,
                  size: 16,
                  color: AppColors.black900,
                ),
              ),
            )
          ),
        ],
      ),
    );
  }
}