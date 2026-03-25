import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class VideoViewer extends StatefulWidget {
  final AssetEntity asset;
  const VideoViewer({super.key, required this.asset});

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;

  Future<void> _initVideo() async {
    final file = await widget.asset.file;
    if (file == null) return;

    _videoController = VideoPlayerController.file(file);
    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: true,
      allowFullScreen: false,
      allowPlaybackSpeedChanging: true,
      zoomAndPan: true,
    );

    setState(() {
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _initialized
        ? Chewie(controller: _chewieController!)
        : Stack(
            alignment: Alignment.center,
            children: [
              FutureBuilder(
                future: widget.asset.thumbnailDataWithSize(
                  const ThumbnailSize(720, 720),
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    );
                  }
                  return const SizedBox();
                },
              ),
              IconButton(
                iconSize: 70,
                onPressed: _initVideo,
                icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              ),
            ],
          );
  }
}
