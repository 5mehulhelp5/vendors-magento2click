// ignore_for_file: always_declare_return_types

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:magentoegypt/core/colors.dart';

class AnimatedSpinner extends StatefulWidget {
  const AnimatedSpinner({Key? key}) : super(key: key);

  @override
  State<AnimatedSpinner> createState() => _AnimatedSpinnerState();
}

class _AnimatedSpinnerState extends State<AnimatedSpinner>
    with TickerProviderStateMixin {
  AnimationController? anim;

  @override
  void initState() {
    super.initState();

    anim =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  dispose() {
    anim!.dispose(); // you need this
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    anim!.forward();
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0)
          .animate(CurvedAnimation(parent: anim!, curve: Curves.easeInOut)),
      child: SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0.0, 0.25), end: const Offset(0.0, 0.0))
            .animate(CurvedAnimation(parent: anim!, curve: Curves.easeInOut)),
        child: Center(
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.kPrimaryBlue.withOpacity(0.7),
                  ),
                  backgroundColor: AppColors.kPrimaryRed.withOpacity(0.3),
                ),
              ),
              Opacity(
                opacity: 0.8,
                child: Image.asset('assets/images/ajstore-icon.png',
                    width: 30, height: 30, fit: BoxFit.contain),
              )
            ],
          ),
        ),
      ),
    );
  }
}

