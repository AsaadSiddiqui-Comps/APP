import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class DocumentThumbnailCard extends StatelessWidget {
  final String title;
  final String modifiedDate;
  final String timeRemaining;
  final VoidCallback onTap;
  final VoidCallback? onMoreOptions;

  const DocumentThumbnailCard({
    Key? key,
    required this.title,
    required this.modifiedDate,
    required this.timeRemaining,
    required this.onTap,
    this.onMoreOptions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2B2A2F) : const Color(0xFFFAF8FC),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: isDark ? const Color(0xFF49454E) : const Color(0xFFE7E0EC),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 70,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6750A4).withOpacity(0.3),
                    const Color(0xFFBB86FC).withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'THUMB',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'NAIL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingMedium),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modifiedDate,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF49454E).withOpacity(0.5)
                          : const Color(0xFFE7E0EC).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      timeRemaining,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            // More options
            if (onMoreOptions != null)
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onMoreOptions,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}
