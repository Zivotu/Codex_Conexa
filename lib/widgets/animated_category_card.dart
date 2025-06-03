import 'package:flutter/material.dart';

class AnimatedCategoryCard extends StatefulWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final Stream<String>? subtitleStream;
  final Future<String>? subtitleFuture;
  final Stream<int>? newItemsCountStream;
  final String? subtitle;
  final IconData? statusIcon;
  final Color? statusColor;
  final bool hasNewNotification;
  final int subtitleMaxLines;

  const AnimatedCategoryCard({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
    this.subtitleStream,
    this.subtitleFuture,
    this.newItemsCountStream,
    this.subtitle,
    this.statusIcon,
    this.statusColor,
    this.hasNewNotification = false,
    this.subtitleMaxLines = 3,
  });

  @override
  _AnimatedCategoryCardState createState() => _AnimatedCategoryCardState();
}

class _AnimatedCategoryCardState extends State<AnimatedCategoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onTap();
  }

  Widget _buildSubtitle() {
    if (widget.subtitleFuture != null) {
      return FutureBuilder<String>(
        future: widget.subtitleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: Colors.white70,
              ),
            );
          } else if (snapshot.hasError) {
            return const Text(
              'Error',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.0,
              ),
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                snapshot.data!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14.0,
                ),
                maxLines: widget.subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }
          return const SizedBox();
        },
      );
    }

    if (widget.subtitleStream != null) {
      return StreamBuilder<String>(
        stream: widget.subtitleStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: Colors.white70,
              ),
            );
          } else if (snapshot.hasError) {
            return const Text(
              'Error',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.0,
              ),
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                snapshot.data!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14.0,
                ),
                maxLines: widget.subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }
          return const SizedBox();
        },
      );
    }

    if (widget.subtitle != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Text(
          widget.subtitle!,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14.0,
          ),
          maxLines: widget.subtitleMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(15.0),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.0),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width / 2 - 16,
                maxHeight: 200,
              ),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                        _buildSubtitle(),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child:
                              Icon(widget.icon, color: Colors.white, size: 48),
                        ),
                      ],
                    ),
                    if (widget.newItemsCountStream != null)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: StreamBuilder<int>(
                          stream: widget.newItemsCountStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data! > 0) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8.0),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4.0,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${snapshot.data}',
                                  style: TextStyle(
                                    color: widget.color,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                            return Container();
                          },
                        ),
                      ),
                    if (widget.hasNewNotification)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.red,
                          child: Icon(
                            Icons.notifications,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    if (widget.statusIcon != null && widget.statusColor != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: widget.statusColor!.withOpacity(0.1),
                          child: Icon(
                            widget.statusIcon,
                            color: widget.statusColor,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
