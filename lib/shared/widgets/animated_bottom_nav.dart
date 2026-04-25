import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// A frosted glass bottom navigation bar with spring animations on item
/// selection, active indicator animations, and optional badge support.
///
/// Used as the primary navigation widget for the GitHub Store app shell.
class AnimatedBottomNav extends StatefulWidget {
  const AnimatedBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 72,
    this.cornerRadius = 20,
    this.backgroundColor,
    this.frostOpacity = 0.7,
    this.blurSigma = 20,
    this.animationDuration = const Duration(milliseconds: 400),
    this.springDescription = const SpringDescription(
      mass: 1,
      stiffness: 400,
      damping: 30,
    ),
    super.key,
  });

  /// Navigation items to display.
  final List<AnimatedNavItem> items;

  /// Currently selected tab index.
  final int currentIndex;

  /// Called when a tab is tapped.
  final ValueChanged<int> onTap;

  /// Height of the navigation bar.
  final double height;

  /// Corner radius for the top edge.
  final double cornerRadius;

  /// Custom background color (overrides theme-derived).
  final Color? backgroundColor;

  /// Opacity for the frosted glass overlay.
  final double frostOpacity;

  /// Blur sigma for the frosted glass effect.
  final double blurSigma;

  /// Duration for non-spring animations.
  final Duration animationDuration;

  /// Spring description for physics-based animations.
  final SpringDescription springDescription;

  @override
  State<AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<AnimatedBottomNav>
    with TickerProviderStateMixin {
  late final List<AnimationController> _scaleControllers;
  late final List<Animation<double>> _scaleAnimations;
  late final AnimationController _indicatorController;
  late final Animation<double> _indicatorAnimation;
  late final AnimationController _badgeController;
  late final Animation<double> _badgeAnimation;

  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;

    // Scale animation per item
    _scaleControllers = List.generate(
      widget.items.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
        lowerBound: 0,
        upperBound: 1,
      ),
    );

    _scaleAnimations = _scaleControllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut,
      ).drive(Tween<double>(begin: 0.6, end: 1.0));
    }).toList();

    // Initialize current item as fully visible
    if (widget.currentIndex < _scaleControllers.length) {
      _scaleControllers[widget.currentIndex].value = 1.0;
    }

    // Active indicator position animation
    _indicatorController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _indicatorAnimation = CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeOutCubic,
    );

    // Badge pop animation
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0,
      upperBound: 1,
    );
    _badgeAnimation = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticOut,
    );
    _badgeController.value = 1.0;
  }

  @override
  void didUpdateWidget(AnimatedBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateTransition(oldWidget.currentIndex, widget.currentIndex);
    }
    if (oldWidget.items.length != widget.items.length) {
      // Rebuild scale controllers if item count changes
      for (final controller in _scaleControllers) {
        controller.dispose();
      }
      _scaleControllers = List.generate(
        widget.items.length,
        (index) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
          lowerBound: 0,
          upperBound: 1,
        ),
      );
      _scaleAnimations = _scaleControllers.map((controller) {
        return CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        ).drive(Tween<double>(begin: 0.6, end: 1.0));
      }).toList();
      _scaleControllers[widget.currentIndex].value = 1.0;
    }
  }

  @override
  void dispose() {
    for (final controller in _scaleControllers) {
      controller.dispose();
    }
    _indicatorController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  void _animateTransition(int fromIndex, int toIndex) {
    // Spring animate the old item down
    _scaleControllers[fromIndex].animateWith(_createSpring()).then((_) {
      _scaleControllers[fromIndex].value = 0;
    });

    // Spring animate the new item up
    _scaleControllers[toIndex].value = 0;
    _scaleControllers[toIndex].animateWith(_createSpring()).then((_) {
      _scaleControllers[toIndex].value = 1.0;
    });

    // Animate indicator
    _indicatorController.forward(from: 0);

    // Pop badge animation
    _badgeController.forward(from: 0);

    _previousIndex = toIndex;
  }

  SpringSimulation _createSpring() {
    return SpringSimulation(
      widget.springDescription,
      0.0, // start
      1.0, // end
      0.5, // velocity
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ??
        theme.bottomNavigationBarTheme.backgroundColor ??
        (theme.brightness == Brightness.dark
            ? const Color(0xFF0D1117)
            : Colors.white);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor.withOpacity( widget.frostOpacity),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity( 0.3),
            width: 0.5,
          ),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.cornerRadius),
          topRight: Radius.circular(widget.cornerRadius),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.cornerRadius),
          topRight: Radius.circular(widget.cornerRadius),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
          child: Stack(
            children: [
              // Animated active indicator
              AnimatedBuilder(
                animation: _indicatorAnimation,
                builder: (context, child) {
                  return _buildActiveIndicator(theme);
                },
              ),
              // Navigation items
              Row(
                children: List.generate(widget.items.length, (index) {
                  return Expanded(
                    child: _buildNavItem(index, theme),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveIndicator(ThemeData theme) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final itemWidth = 1.0 / widget.items.length;
    final indicatorLeft = widget.currentIndex * itemWidth;
    final indicatorWidth = itemWidth * 0.7;

    final offset = indicatorLeft + (itemWidth - indicatorWidth) / 2;

    return FractionallySizedBox(
      alignment: Alignment(_lerp(
        _previousIndex * 2 - (widget.items.length - 1),
        widget.currentIndex * 2 - (widget.items.length - 1),
        _indicatorAnimation.value,
      ), -1),
      widthFactor: indicatorWidth,
      child: Container(
        height: 4,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity( 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, ThemeData theme) {
    final item = widget.items[index];
    final isSelected = index == widget.currentIndex;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (index != widget.currentIndex) {
          widget.onTap(index);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with scale animation
            SizedBox(
              height: 28,
              width: 28,
              child: AnimatedBuilder(
                animation: _scaleAnimations[index],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimations[index].value,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          size: 24,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        // Badge
                        if (item.badge != null)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: AnimatedBuilder(
                              animation: _badgeAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _badgeAnimation.value,
                                  child: _buildBadge(item.badge!, theme),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            // Label
            AnimatedDefaultTextStyle(
              duration: widget.animationDuration,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                letterSpacing: isSelected ? 0.3 : 0,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(AnimatedNavBadge badge, ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: badge is NumericBadge ? 5 : 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: badge.color ?? theme.colorScheme.error,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: (badge.color ?? theme.colorScheme.error).withOpacity( 0.4),
            blurRadius: 4,
          ),
        ],
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Center(
        child: badge is NumericBadge
            ? Text(
                badge.count > 99 ? '99+' : badge.count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              )
            : null,
      ),
    );
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

/// Data class for a single navigation item.
class AnimatedNavItem {
  const AnimatedNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });

  /// Icon shown when the tab is inactive.
  final IconData icon;

  /// Icon shown when the tab is active.
  final IconData activeIcon;

  /// Label text displayed below the icon.
  final String label;

  /// Optional badge to display on the icon.
  final AnimatedNavBadge? badge;
}

/// Base class for badge types on navigation items.
abstract class AnimatedNavBadge {
  const AnimatedNavBadge({this.color});
  final Color? color;
}

/// A badge showing a numeric count.
class NumericBadge extends AnimatedNavBadge {
  const NumericBadge(this.count, {super.color});
  final int count;
}

/// A simple dot badge (no number).
class DotBadge extends AnimatedNavBadge {
  const DotBadge({super.color});
}


