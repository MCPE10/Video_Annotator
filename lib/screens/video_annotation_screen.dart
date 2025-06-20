import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

enum DrawingMode { freehand, line, circle }

class VideoAnnotationScreen extends StatefulWidget {
  final String videoPath;

  const VideoAnnotationScreen({super.key, required this.videoPath});

  @override
  State<VideoAnnotationScreen> createState() => _VideoAnnotationScreenState();
}

class _VideoAnnotationScreenState extends State<VideoAnnotationScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  List<DrawingPoint?> drawingPoints = [];
  Color selectedColor = Colors.red;
  double strokeWidth = 3.0;
  DrawingMode _drawingMode = DrawingMode.freehand;
  Offset? _lineStart;
  Offset? _circleCenter;
  double? _circleRadius;
  bool _isDrawing = false;
  VoidCallback? _videoListener;
  bool _isSeeking = false;
  double? _seekValue;
  final GlobalKey _videoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          // Don't auto-play the video - let user control it
          _isPlaying = false;
        });
        // Load existing annotations after video is initialized
        _loadExistingAnnotations();
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initializing video: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    _videoListener = () {
      if (mounted && !_isSeeking) {
        setState(() {
          // Check if video has ended
          if (_controller.value.position >= _controller.value.duration) {
            _isPlaying = false;
          }
        });
      }
    };
    _controller.addListener(_videoListener!);
  }

  @override
  void dispose() {
    if (_videoListener != null) {
      _controller.removeListener(_videoListener!);
    }
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  void _selectColor(Color color) {
    setState(() {
      selectedColor = color;
    });
  }

  Future<void> _saveAnnotatedVideo() async {
    // Show dialog to ask user if they want to save with or without annotations
    final saveOption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Video'),
        content: const Text('How would you like to save this video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'without'),
            child: const Text('Without Annotations'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'with'),
            child: const Text('With Annotations'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (saveOption == 'cancel' || saveOption == null) {
      return;
    }

    if (saveOption == 'with') {
      await _saveVideoWithAnnotations();
    } else {
      await _saveVideoWithoutAnnotations();
    }
  }

  Future<void> _saveVideoWithAnnotations() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing video...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Pause video if playing
      if (_controller.value.isPlaying) {
        _controller.pause();
      }

      // Get the temporary directory and create videos subdirectory
      final directory = await getTemporaryDirectory();
      final videoDir = Directory(path.join(directory.path, 'videos'));
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }

      // Find the next available annotated video number
      int annotatedNumber = 1;
      while (await File(path.join(videoDir.path, 'recording_$annotatedNumber.mp4')).exists()) {
        annotatedNumber++;
      }
      
      final outputPath = path.join(videoDir.path, 'recording_$annotatedNumber.mp4');

      // Save the original video
      await File(widget.videoPath).copy(outputPath);
      
      // Save annotation data to a separate file
      final annotationData = _serializeAnnotations();
      final annotationPath = outputPath.replaceAll('.mp4', '_annotations.json');
      
      print('Saving annotations to: $annotationPath');
      print('Annotation data: $annotationData');
      print('Drawing points count: ${drawingPoints.length}');
      
      await File(annotationPath).writeAsString(annotationData);
      
      // Verify the file was created
      final savedFile = File(annotationPath);
      if (await savedFile.exists()) {
        print('Annotation file created successfully');
      } else {
        print('Failed to create annotation file');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved with annotations'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveVideoWithoutAnnotations() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saving video...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Pause video if playing
      if (_controller.value.isPlaying) {
        _controller.pause();
      }

      // Get the temporary directory and create videos subdirectory
      final directory = await getTemporaryDirectory();
      final videoDir = Directory(path.join(directory.path, 'videos'));
      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }

      // Find the next available video number
      int videoNumber = 1;
      while (await File(path.join(videoDir.path, 'recording_$videoNumber.mp4')).exists()) {
        videoNumber++;
      }
      
      final outputPath = path.join(videoDir.path, 'recording_$videoNumber.mp4');

      // Save only the original video without annotations
      await File(widget.videoPath).copy(outputPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved without annotations'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _serializeAnnotations() {
    final List<dynamic> serializedPoints = [];
    
    print('Serializing ${drawingPoints.length} drawing points');
    
    for (int i = 0; i < drawingPoints.length; i++) {
      final point = drawingPoints[i];
      if (point != null) {
        print('Serializing point $i: x=${point.offset.dx}, y=${point.offset.dy}, color=${point.paint.color.value}');
        serializedPoints.add({
          'x': point.offset.dx,
          'y': point.offset.dy,
          'color': point.paint.color.value,
          'strokeWidth': point.paint.strokeWidth,
          'isPreview': point.isPreview,
          'circleRadius': point.circleRadius,
          'style': point.paint.style == PaintingStyle.stroke ? 'stroke' : 'fill',
        });
      } else {
        print('Adding null separator at index $i');
        // Add null marker to separate drawing segments
        serializedPoints.add(null);
      }
    }
    
    final result = jsonEncode(serializedPoints);
    print('Serialization result: $result');
    return result;
  }

  Future<void> _loadExistingAnnotations() async {
    try {
      final annotationPath = widget.videoPath.replaceAll('.mp4', '_annotations.json');
      final annotationFile = File(annotationPath);
      
      print('Looking for annotation file: $annotationPath');
      print('File exists: ${await annotationFile.exists()}');
      
      if (await annotationFile.exists()) {
        final annotationData = await annotationFile.readAsString();
        print('Loaded annotation data: $annotationData');
        
        final loadedPoints = _deserializeAnnotations(annotationData);
        print('Deserialized ${loadedPoints.length} points');
        
        if (mounted) {
          setState(() {
            drawingPoints = loadedPoints;
          });
          print('Annotations loaded into state');
        }
      } else {
        print('No annotation file found');
      }
    } catch (e) {
      print('Error loading annotations: $e');
    }
  }

  List<DrawingPoint?> _deserializeAnnotations(String data) {
    try {
      print('Starting deserialization of data: ${data.substring(0, data.length > 100 ? 100 : data.length)}...');
      
      final List<dynamic> jsonData = jsonDecode(data);
      final List<DrawingPoint?> points = [];
      
      print('Parsed JSON data with ${jsonData.length} items');
      
      for (int i = 0; i < jsonData.length; i++) {
        final item = jsonData[i];
        
        if (item == null) {
          print('Adding null separator at index $i');
          points.add(null);
        } else if (item is Map<String, dynamic>) {
          print('Processing point data: $item');
          
          final x = item['x']?.toDouble();
          final y = item['y']?.toDouble();
          final colorValue = item['color'] as int?;
          final strokeWidth = item['strokeWidth']?.toDouble() ?? 3.0;
          final isPreview = item['isPreview'] as bool? ?? false;
          final circleRadius = item['circleRadius']?.toDouble();
          final style = item['style'] as String?;
          
          if (x != null && y != null && colorValue != null) {
            print('Created point: x=$x, y=$y, color=$colorValue, circleRadius=$circleRadius, style=$style');
            
            final paint = Paint()
              ..color = Color(colorValue)
              ..isAntiAlias = true
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.round;
            
            // Set the paint style based on the saved style
            if (style == 'stroke') {
              paint.style = PaintingStyle.stroke;
            } else {
              paint.style = PaintingStyle.fill;
            }
            
            points.add(
              DrawingPoint(
                Offset(x, y),
                paint,
                isPreview: isPreview,
                circleRadius: circleRadius,
              ),
            );
          } else {
            print('Failed to parse point data: x=$x, y=$y, color=$colorValue');
          }
        } else {
          print('Unexpected item type at index $i: ${item.runtimeType}');
        }
      }
      
      print('Deserialization complete. Total points: ${points.length}');
      return points;
    } catch (e) {
      print('Error deserializing annotations: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Annotation'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _saveAnnotatedVideo,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_controller.value.isInitialized)
                  Center(
                    child: RepaintBoundary(
                      key: _videoKey,
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isDrawing = true;
                      if (_drawingMode == DrawingMode.line) {
                        _lineStart = details.localPosition;
                      } else if (_drawingMode == DrawingMode.circle) {
                        _circleCenter = details.localPosition;
                      } else {
                        drawingPoints.add(
                          DrawingPoint(
                            details.localPosition,
                            Paint()
                              ..color = selectedColor
                              ..isAntiAlias = true
                              ..strokeWidth = strokeWidth
                              ..strokeCap = StrokeCap.round,
                          ),
                        );
                      }
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      if (_drawingMode == DrawingMode.line) {
                        // For line mode, we'll update the preview line
                        if (_lineStart != null) {
                          drawingPoints = drawingPoints.where((point) => point?.isPreview != true).toList();
                          drawingPoints.add(
                            DrawingPoint(
                              _lineStart!,
                              Paint()
                                ..color = selectedColor
                                ..isAntiAlias = true
                                ..strokeWidth = strokeWidth
                                ..strokeCap = StrokeCap.round,
                            ),
                          );
                          drawingPoints.add(
                            DrawingPoint(
                              details.localPosition,
                              Paint()
                                ..color = selectedColor
                                ..isAntiAlias = true
                                ..strokeWidth = strokeWidth
                                ..strokeCap = StrokeCap.round,
                              isPreview: true,
                            ),
                          );
                        }
                      } else if (_drawingMode == DrawingMode.circle) {
                        // For circle mode, update the preview circle
                        if (_circleCenter != null) {
                          drawingPoints = drawingPoints.where((point) => point?.isPreview != true).toList();
                          final radius = (_circleCenter! - details.localPosition).distance;
                          if (radius > 5) { // Only draw if radius is meaningful
                            drawingPoints.add(
                              DrawingPoint(
                                _circleCenter!,
                                Paint()
                                  ..color = selectedColor.withOpacity(0.7) // Slightly transparent for preview
                                  ..isAntiAlias = true
                                  ..strokeWidth = strokeWidth
                                  ..style = PaintingStyle.stroke,
                                isPreview: true,
                                circleRadius: radius,
                              ),
                            );
                          }
                        }
                      } else {
                        drawingPoints.add(
                          DrawingPoint(
                            details.localPosition,
                            Paint()
                              ..color = selectedColor
                              ..isAntiAlias = true
                              ..strokeWidth = strokeWidth
                              ..strokeCap = StrokeCap.round,
                          ),
                        );
                      }
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDrawing = false;
                      if (_drawingMode == DrawingMode.line) {
                        if (_lineStart != null) {
                          // Remove preview line
                          drawingPoints = drawingPoints.where((point) => point?.isPreview != true).toList();
                          // Add final line
                          drawingPoints.add(
                            DrawingPoint(
                              _lineStart!,
                              Paint()
                                ..color = selectedColor
                                ..isAntiAlias = true
                                ..strokeWidth = strokeWidth
                                ..strokeCap = StrokeCap.round,
                            ),
                          );
                          drawingPoints.add(
                            DrawingPoint(
                              details.localPosition,
                              Paint()
                                ..color = selectedColor
                                ..isAntiAlias = true
                                ..strokeWidth = strokeWidth
                                ..strokeCap = StrokeCap.round,
                            ),
                          );
                          _lineStart = null;
                        }
                      } else if (_drawingMode == DrawingMode.circle) {
                        if (_circleCenter != null) {
                          // Remove preview circle
                          drawingPoints = drawingPoints.where((point) => point?.isPreview != true).toList();
                          // Add final circle
                          final radius = (_circleCenter! - details.localPosition).distance;
                          drawingPoints.add(
                            DrawingPoint(
                              _circleCenter!,
                              Paint()
                                ..color = selectedColor
                                ..isAntiAlias = true
                                ..strokeWidth = strokeWidth
                                ..style = PaintingStyle.stroke,
                              circleRadius: radius,
                            ),
                          );
                          _circleCenter = null;
                        }
                      }
                      drawingPoints.add(null);
                    });
                  },
                  child: CustomPaint(
                    painter: _DrawingPainter(drawingPoints),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
          if (_controller.value.isInitialized)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(_formatDuration(_controller.value.position)),
                  Expanded(
                    child: Slider(
                      value: _isSeeking
                          ? (_seekValue ?? _controller.value.position.inMilliseconds.toDouble())
                          : _controller.value.position.inMilliseconds.toDouble(),
                      min: 0.0,
                      max: _controller.value.duration.inMilliseconds.toDouble(),
                      onChangeStart: (value) {
                        setState(() {
                          _isSeeking = true;
                          _seekValue = value;
                        });
                      },
                      onChanged: (value) {
                        setState(() {
                          _seekValue = value;
                        });
                        // Seek video in real-time while dragging
                        _controller.seekTo(Duration(milliseconds: value.toInt()));
                      },
                      onChangeEnd: (value) {
                        setState(() {
                          _isSeeking = false;
                          _seekValue = null;
                        });
                      },
                    ),
                  ),
                  Text(_formatDuration(_controller.value.duration)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Color picker row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _selectColor(Colors.red),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == Colors.red ? Colors.black : Colors.grey,
                            width: selectedColor == Colors.red ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _selectColor(Colors.blue),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == Colors.blue ? Colors.black : Colors.grey,
                            width: selectedColor == Colors.blue ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _selectColor(Colors.green),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == Colors.green ? Colors.black : Colors.grey,
                            width: selectedColor == Colors.green ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _selectColor(Colors.orange),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == Colors.orange ? Colors.black : Colors.grey,
                            width: selectedColor == Colors.orange ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Control buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: _togglePlayPause,
                    ),
                    IconButton(
                      icon: Icon(
                        _drawingMode == DrawingMode.freehand
                            ? Icons.edit
                            : _drawingMode == DrawingMode.line
                                ? Icons.line_axis
                                : Icons.circle,
                      ),
                      onPressed: () {
                        setState(() {
                          _drawingMode = _drawingMode == DrawingMode.freehand
                              ? DrawingMode.line
                              : _drawingMode == DrawingMode.line
                                  ? DrawingMode.circle
                                  : DrawingMode.freehand;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: () {
                        setState(() {
                          if (drawingPoints.isNotEmpty) {
                            drawingPoints.removeLast();
                            while (drawingPoints.isNotEmpty && drawingPoints.last != null) {
                              drawingPoints.removeLast();
                            }
                          }
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          drawingPoints.clear();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
}

class DrawingPoint {
  Offset offset;
  Paint paint;
  bool isPreview;
  double? circleRadius;

  DrawingPoint(this.offset, this.paint, {this.isPreview = false, this.circleRadius});
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> drawingPoints;

  _DrawingPainter(this.drawingPoints);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < drawingPoints.length; i++) {
      if (drawingPoints[i] != null) {
        // Check if this is a circle
        if (drawingPoints[i]!.circleRadius != null) {
          // Draw circle
          canvas.drawCircle(
            drawingPoints[i]!.offset,
            drawingPoints[i]!.circleRadius!,
            drawingPoints[i]!.paint,
          );
        } else if (i < drawingPoints.length - 1 && drawingPoints[i + 1] != null) {
          // Draw line between two points
          canvas.drawLine(
            drawingPoints[i]!.offset,
            drawingPoints[i + 1]!.offset,
            drawingPoints[i]!.paint,
          );
        } else {
          // Draw single point
          canvas.drawPoints(
            PointMode.points,
            [drawingPoints[i]!.offset],
            drawingPoints[i]!.paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 