import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart';

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

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final fileBytes = await picked.readAsBytes();
      final fileName = basename(picked.path);

      try {
        setState(() => _isUploading = true);
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) return;

        final path = 'avatars/$userId/$fileName';

        await supabase.storage.from('avatars').uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

        final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);
        debugPrint('📸 실제 공개 URL: $publicUrl');
        widget.onAvatarChanged(publicUrl);
      } catch (e) {
        debugPrint('🔥 업로드 실패: $e');
        if (mounted) {
          print("에러남");
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBasic = widget.avatarUrl == 'basic';

    return Stack(
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
                : IconButton(
              icon: const Icon(Icons.camera_alt_outlined, size: 16),
              onPressed: _pickImage,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ],
    );
  }
}