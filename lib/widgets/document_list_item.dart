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
  final void Function(Bulletin) onTap;
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
    required this.onTap,
    this.canEdit = false,
    this.showLimitedDescription = false,
  });

  @override
  Widget build(BuildContext context) {
    String description = bulletin.description;
    if (showLimitedDescription && description.length > 150) {
      description = '${description.substring(0, 150)}...';
    }

    return Card(
      child: InkWell(
        onTap: () => onTap(bulletin),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bulletin.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(description),
              const SizedBox(height: 4),
              Row(
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
                  Text('${bulletin.comments.length}'), // Number of comments
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
      ),
    );
  }
}
