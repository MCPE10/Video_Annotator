# Video Annotator Flutter App

An iOS Flutter application for recording videos and adding annotations with various drawing tools. Perfect for educational content, tutorials, and video analysis.

## Features

### 🎥 Video Recording
- Record videos using device camera
- Automatic video file management
- Support for both front and back cameras

### ✏️ Annotation Tools
- **Freehand Drawing**: Draw freely on video frames
- **Line Tool**: Draw straight lines with live preview
- **Circle Tool**: Draw circles with adjustable radius
- **Multiple Colors**: Choose from red, blue, green, and orange
- **Stroke Width**: Adjustable line thickness

### 🎨 Drawing Features
- Real-time drawing preview
- Multiple drawing segments support
- Stroke and fill styles for circles
- Color selection with visual indicators

### 📁 Video Gallery
- Browse all recorded videos
- Sort by creation date (oldest to newest)
- Video file management (rename, delete)
- Bulk delete functionality
- File size and modification date display
- Annotation indicator for videos with drawings

### 💾 Save Options
- Save video with annotations
- Save video without annotations
- Automatic annotation file management
- JSON-based annotation storage

## Screenshots

*Add screenshots of your app here*

## Getting Started

### Prerequisites
- Flutter SDK (3.0 or higher)
- iOS development tools (for iOS builds)
- Android Studio (for Android builds)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/video_annotator_flutter.git
   cd video_annotator_flutter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### iOS Setup
```bash
cd ios
pod install
cd ..
flutter run
```

## Usage

### Recording a Video
1. Tap "Record New Video" on the home screen
2. Grant camera permissions when prompted
3. Tap the record button to start recording
4. Tap again to stop recording
5. Choose to annotate or go to gallery

### Adding Annotations
1. Open a video from the gallery
2. Use the drawing tools at the bottom:
   - **Pencil icon**: Freehand drawing
   - **Line icon**: Straight line tool
   - **Circle icon**: Circle drawing tool
3. Select a color from the color palette
4. Draw on the video frame
5. Tap "Save" to save with annotations

### Managing Videos
- **Rename**: Long press a video and select "Rename"
- **Delete**: Long press a video and select "Delete"
- **Delete All**: Use the trash icon in the app bar
- **View Details**: Tap on a video to see file information

## Technical Details

### Dependencies
- `camera`: Video recording functionality
- `video_player`: Video playback
- `path_provider`: File system access
- `video_compress`: Video compression
- `flutter_drawing_board`: Drawing capabilities

### Architecture
- **Main Screen**: Navigation hub
- **Recording Screen**: Camera interface and video capture
- **Annotation Screen**: Video playback with drawing overlay
- **Gallery Screen**: Video management and browsing

### Data Storage
- Videos stored in device's temporary directory
- Annotations saved as JSON files alongside videos
- Automatic file naming and organization

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Camera plugin contributors
- Video player plugin maintainers
- Drawing board plugin developers

## Support

If you encounter any issues or have questions, please open an issue on GitHub.
