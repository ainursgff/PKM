import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../halaman/login.dart';
import '../partials/bottom.dart';
import '../partials/flash.dart';

const String videoBase = "http://192.168.1.9:3000/makanan/video/";

class ReelsPage extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int startIndex;
  final Map<String, dynamic>? user;

  const ReelsPage({
    super.key,
    required this.videos,
    required this.startIndex,
    required this.user,
  });

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {

  late PageController controller;
  int currentIndex = 0;
  int selectedIndex = 1;

  @override
  void initState() {
    super.initState();

    currentIndex = widget.startIndex;

    controller = PageController(
      initialPage: widget.startIndex,
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,

      body: PageView.builder(
        controller: controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,

        onPageChanged: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        itemBuilder: (context, index) {

          final data = widget.videos[index];

          return ReelItem(
            data: data,
            isActive: index == currentIndex,
            user: widget.user,
          );
        },
      ),

      bottomNavigationBar: BottomNavSmartCooks(
        selectedIndex: selectedIndex,
        onTap: (i) {

          setState(() {
            selectedIndex = i;
          });

          if (i == 0) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

class ReelItem extends StatefulWidget {

  final Map<String, dynamic> data;
  final bool isActive;
  final Map<String, dynamic>? user;

  const ReelItem({
    super.key,
    required this.data,
    required this.isActive,
    required this.user,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {

  VideoPlayerController? controller;

  bool isLiked = false;
  bool showHeart = false;
  bool showPauseIcon = false;

  bool redirecting = false;

  bool get isLogin => widget.user != null;

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.networkUrl(
      Uri.parse("$videoBase${widget.data['url_video']}"),
    )
      ..initialize().then((_) {

        controller!.setLooping(true);

        if (widget.isActive) {
          controller!.play();
        }

        setState(() {});
      });
  }

  /// REDIRECT LOGIN + PAUSE VIDEO
  void redirectLogin() {

    if(redirecting) return;
    redirecting = true;

    controller?.pause();

    FlashMessage.warning(
      context,
      "Silakan login untuk menyukai video\nMengarahkan ke halaman login..."
    );

    Future.delayed(const Duration(seconds: 2), () {

      if(!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );

    });
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (controller == null) return;

    if (widget.isActive) {
      controller!.play();
    } else {
      controller!.pause();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void togglePlay() {

    if (controller == null) return;

    if (controller!.value.isPlaying) {

      controller!.pause();

      setState(() {
        showPauseIcon = true;
      });

    } else {

      controller!.play();

      setState(() {
        showPauseIcon = false;
      });

    }

    setState(() {});
  }

  void likeAnimation() {

    if(!isLogin){
      redirectLogin();
      return;
    }

    setState(() {
      isLiked = true;
      showHeart = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {

      if (mounted) {
        setState(() {
          showHeart = false;
        });
      }

    });
  }

  void toggleLike() {

    if(!isLogin){
      redirectLogin();
      return;
    }

    setState(() {
      isLiked = !isLiked;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Stack(
      children: [

        Container(color: Colors.black),

        if (controller != null && controller!.value.isInitialized)
          GestureDetector(
            onTap: togglePlay,
            onDoubleTap: likeAnimation,

            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller!.value.size.height,
                  child: VideoPlayer(controller!),
                ),
              ),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),

        if (showHeart)
          const Center(
            child: Icon(
              Icons.favorite,
              color: Colors.white,
              size: 120,
            ),
          ),

        if (showPauseIcon)
          const Center(
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 90,
            ),
          ),

        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 80,

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      widget.data['nama_makanan'] ?? "",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      widget.data['caption'] ?? "",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),

                  ],
                ),
              ),

              const SizedBox(width: 12),

              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  GestureDetector(
                    onTap: toggleLike,

                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: isLiked ? 1.2 : 1,

                      child: Icon(
                        isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isLiked
                            ? Colors.red
                            : Colors.white,
                        size: 34,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "Like",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),

                ],
              ),
            ],
          ),
        ),

      ],
    );
  }
}