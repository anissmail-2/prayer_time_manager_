import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme/app_theme.dart';
import '../core/helpers/permission_helper.dart';
import '../core/helpers/analytics_helper.dart';

/// Widget for displaying and managing task attachments
class AttachmentsWidget extends StatefulWidget {
  final List<String> attachmentPaths;
  final Function(List<String>)? onAttachmentsChanged;
  final bool allowEditing;

  const AttachmentsWidget({
    super.key,
    required this.attachmentPaths,
    this.onAttachmentsChanged,
    this.allowEditing = true,
  });

  @override
  State<AttachmentsWidget> createState() => _AttachmentsWidgetState();
}

class _AttachmentsWidgetState extends State<AttachmentsWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  late List<String> _attachments;

  @override
  void initState() {
    super.initState();
    _attachments = List.from(widget.attachmentPaths);
  }

  Future<void> _addPhotoFromCamera() async {
    // Check permission
    if (!await PermissionHelper.hasCameraPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required')),
        );
      }
      return;
    }

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() => _attachments.add(photo.path));
        widget.onAttachmentsChanged?.call(_attachments);
        await AnalyticsHelper.logEvent(
          name: 'attachment_added',
          parameters: {'type': 'camera'},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  Future<void> _addPhotoFromGallery() async {
    // Check permission
    if (!await PermissionHelper.hasGalleryPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery permission required')),
        );
      }
      return;
    }

    try {
      final List<XFile> photos = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photos.isNotEmpty) {
        setState(() {
          _attachments.addAll(photos.map((p) => p.path));
        });
        widget.onAttachmentsChanged?.call(_attachments);
        await AnalyticsHelper.logEvent(
          name: 'attachment_added',
          parameters: {'type': 'gallery', 'count': photos.length},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photos: $e')),
        );
      }
    }
  }

  Future<void> _addFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePaths = result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();

        setState(() {
          _attachments.addAll(filePaths);
        });
        widget.onAttachmentsChanged?.call(_attachments);
        await AnalyticsHelper.logEvent(
          name: 'attachment_added',
          parameters: {'type': 'file', 'count': filePaths.length},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick files: $e')),
        );
      }
    }
  }

  Future<void> _removeAttachment(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Attachment'),
        content: const Text('Remove this attachment from the task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _attachments.removeAt(index));
      widget.onAttachmentsChanged?.call(_attachments);
      await AnalyticsHelper.logEvent(name: 'attachment_removed');
    }
  }

  Future<void> _viewAttachment(String path) async {
    // Show attachment in dialog
    if (_isImage(path)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.file(File(path)),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // For files, show info
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('File'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Path:'),
              Text(
                path,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _addPhotoFromCamera();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _addPhotoFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_file, color: AppTheme.primary),
              title: const Text('Attach File'),
              onTap: () {
                Navigator.pop(context);
                _addFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isImage(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  IconData _getFileIcon(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              Icons.attach_file,
              size: 20,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Attachments',
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            if (_attachments.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_attachments.length}',
                  style: AppTheme.labelSmall.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Attachments grid
        if (_attachments.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _attachments.length,
            itemBuilder: (context, index) {
              final path = _attachments[index];
              return _buildAttachmentThumbnail(path, index);
            },
          ),
          const SizedBox(height: 12),
        ],

        // Add button
        if (widget.allowEditing) ...[
          OutlinedButton.icon(
            onPressed: _showAddOptions,
            icon: const Icon(Icons.add),
            label: const Text('Add Attachment'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentThumbnail(String path, int index) {
    return GestureDetector(
      onTap: () => _viewAttachment(path),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.borderLight,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _isImage(path)
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.broken_image,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        _getFileIcon(path),
                        size: 32,
                        color: AppTheme.primary,
                      ),
                    ),
            ),
          ),
          if (widget.allowEditing)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeAttachment(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
