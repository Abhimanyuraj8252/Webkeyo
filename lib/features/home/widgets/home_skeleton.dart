/// Skeleton / shimmer placeholders — shown while a list is genuinely
/// loading (async read), never as a timed fake. The project list reads
/// from the already-open Hive box (instant), so its skeleton is the
/// loading branch of the async load in HomeScreen; the trending row
/// and the streak header load from disk / Hive asynchronously for real.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants.dart';

/// One grey shimmering box.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppConstants.radiusSmall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(
          duration: const Duration(milliseconds: 1200),
        );
  }
}

/// Skeleton for the project list — three fake project cards.
class ProjectListSkeleton extends StatelessWidget {
  const ProjectListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
        child: Row(
          children: [
            const ShimmerBox(width: 44, height: 44, radius: 12),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: 14,
                  ),
                  const SizedBox(height: 8),
                  ShimmerBox(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a horizontal row (templates / trending).
class HorizontalRowSkeleton extends StatelessWidget {
  const HorizontalRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(right: AppConstants.paddingSmall),
          child: ShimmerBox(width: 160, height: 110, radius: 16),
        ),
      ),
    );
  }
}
