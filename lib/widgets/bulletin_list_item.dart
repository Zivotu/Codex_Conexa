// lib/widgets/bulletin_list_item.dart
import 'package:flutter/material.dart';
import '../models/bulletin.dart';

class BulletinListItem extends StatelessWidget {
  final Bulletin bulletin;
  final VoidCallback? onDelete;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onTap;
  final bool canEdit;
  final bool showLimitedDescription;

  const BulletinListItem({
    super.key,
    required this.bulletin,
    this.onDelete,
    this.onLike,
    this.onDislike,
    this.onComment,
    this.onShare,
    this.onDownload,
    this.onTap,
    required this.canEdit,
    this.showLimitedDescription = false,
  });

  @override
  Widget build(BuildContext context) {
    final truncatedDescription = bulletin.description.length > 150
        ? '${bulletin.description.substring(0, 150)}...'
        : bulletin.description;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                bulletin.imagePaths.isNotEmpty &&
                        bulletin.imagePaths[0].contains('http')
                    ? Image.network(
                        bulletin.imagePaths[0],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/bulletin.png',
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : Image.asset(
                        'assets/images/bulletin.png',
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      bulletin.title.length > 30
                          ? '${bulletin.title.substring(0, 30)}...'
                          : bulletin.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                showLimitedDescription
                    ? truncatedDescription
                    : bulletin.description,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up),
                  onPressed: onLike,
                ),
                Text('${bulletin.likes}'),
                IconButton(
                  icon: const Icon(Icons.thumb_down),
                  onPressed: onDislike,
                ),
                Text('${bulletin.dislikes}'),
                IconButton(
                  icon: const Icon(Icons.comment),
                  onPressed: onComment,
                ),
                Text('${bulletin.comments.length}'),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: onShare,
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: onDownload,
                ),
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
