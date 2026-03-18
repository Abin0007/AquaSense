import 'package:flutter/material.dart';

class ApplyConnectionCard extends StatefulWidget {
  final VoidCallback onTap;

  const ApplyConnectionCard({super.key, required this.onTap});

  @override
  State<ApplyConnectionCard> createState() => _ApplyConnectionCardState();
}

class _ApplyConnectionCardState extends State<ApplyConnectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent
                          .withValues(alpha: 0.3 + (_glowController.value * 0.4)),
                      blurRadius: 10 + (_glowController.value * 10),
                      spreadRadius: 2 + (_glowController.value * 2),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.teal.withAlpha(80),
                    Colors.cyan.withAlpha(60),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25.0),
                border: Border.all(color: Colors.tealAccent.withAlpha(150)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.tealAccent,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Get Started',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Apply for a New Connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap here to begin your application process.',
                    style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Start Application',
                        style: TextStyle(
                          color: Colors.tealAccent.withAlpha(200),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.tealAccent.withAlpha(200),
                        size: 14,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
