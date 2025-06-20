import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'video_annotation_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

class VideoGalleryScreen extends StatefulWidget {
  const VideoGalleryScreen({super.key});

  @override
  State<VideoGalleryScreen> createState() => _VideoGalleryScreenState();
}

class _VideoGalleryScreenState extends State<VideoGalleryScreen> {
  List<FileSystemEntity> _videos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final directory = await getTemporaryDirectory();
      final videoDir = Directory(path.join(directory.path, 'videos'));
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }

      final List<FileSystemEntity> files = await videoDir.list().toList();
      final List<FileSystemEntity> validVideos = [];

      for (var file in files) {
        if (file is File && 
            file.path.toLowerCase().endsWith('.mp4') && 
            await file.exists()) {
          validVideos.add(file);
        }
      }

      // Sort videos by modification date (oldest first, newest at bottom)
      validVideos.sort((a, b) {
        final aFile = File(a.path);
        final bFile = File(b.path);
        return aFile.lastModifiedSync().compareTo(bFile.lastModifiedSync());
      });

      if (!mounted) return;

      setState(() {
        _videos = validVideos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading videos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteVideo(FileSystemEntity video) async {
    if (!mounted) return;

    try {
      final file = File(video.path);
      if (await file.exists()) {
        await file.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video deleted successfully'),
              duration: Duration(seconds: 2),
            ),
          );
          _loadVideos();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video file not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(FileSystemEntity video) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: Text('Are you sure you want to delete ${path.basename(video.path)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteVideo(video);
    }
  }

  String _getFileNameWithoutExtension(String filePath) {
    final fileName = path.basename(filePath);
    return fileName.substring(0, fileName.lastIndexOf('.'));
  }

  Future<void> _renameVideo(FileSystemEntity video) async {
    if (!mounted) return;

    final oldName = _getFileNameWithoutExtension(video.path);
    final TextEditingController controller = TextEditingController(text: oldName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'New Name',
                hintText: 'Enter new name',
              ),
              controller: controller,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'The .mp4 extension will be added automatically',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      try {
        final oldPath = video.path;
        final newPath = path.join(
          path.dirname(oldPath),
          '$newName.mp4'
        );
        
        // Check if file exists
        final file = File(oldPath);
        if (!await file.exists()) {
          throw Exception('Video file not found');
        }

        // Check if new name already exists
        final newFile = File(newPath);
        if (await newFile.exists()) {
          throw Exception('A file with this name already exists');
        }

        await file.rename(newPath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video renamed successfully'),
              duration: Duration(seconds: 2),
            ),
          );
          _loadVideos();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error renaming video: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  bool _hasAnnotations(String videoPath) {
    final annotationPath = videoPath.replaceAll('.mp4', '_annotations.json');
    return File(annotationPath).existsSync();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _deleteAllVideos() async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Videos'),
        content: const Text('Are you sure you want to delete ALL videos? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        int deletedCount = 0;
        
        for (var video in _videos) {
          final file = File(video.path);
          if (await file.exists()) {
            await file.delete();
            deletedCount++;
            
            // Also delete annotation file if it exists
            final annotationPath = video.path.replaceAll('.mp4', '_annotations.json');
            final annotationFile = File(annotationPath);
            if (await annotationFile.exists()) {
              await annotationFile.delete();
            }
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted $deletedCount videos'),
              duration: Duration(seconds: 2),
            ),
          );
          _loadVideos(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting videos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Gallery'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _deleteAllVideos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVideos,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _videos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.video_library,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No videos found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Record a new video'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _videos.length,
                      itemBuilder: (context, index) {
                        final video = _videos[index];
                        final file = File(video.path);
                        final fileSize = file.lengthSync();
                        final fileName = _getFileNameWithoutExtension(video.path);
                        final modifiedDate = file.lastModifiedSync();

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.video_file,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            title: Text(
                              fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Size: ${_formatFileSize(fileSize)}'),
                                Text(
                                  'Modified: ${modifiedDate.toString().split('.')[0]}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (_hasAnnotations(video.path))
                                  const Text(
                                    '📝 Has annotations',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _renameVideo(video),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _showDeleteConfirmation(video),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () async {
                              if (!file.existsSync()) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Video file not found'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                return;
                              }
                              
                              if (!mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideoAnnotationScreen(
                                    videoPath: video.path,
                                  ),
                                ),
                              );
                              if (mounted) {
                                _loadVideos();
                              }
                            },
                          ),
                        );
                      },
                    ),
    );
  }
} 