import 'package:flutter/material.dart';

class CircleButtonText extends StatelessWidget {
  final String text;
  final String? image;
  final Widget? imageWidget;
  final double? radius;
  final Color? color;

  const CircleButtonText(
    this.text, {
    this.image,
    this.imageWidget,
    Key? key,
    this.radius,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ///In this scenario, Row is the appropriate choice for widget positioning.
    ///Align is not suitable due to limitations in RTL language cases.
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          height: radius! * 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius!),
            color: color ?? Theme.of(context).primaryColor,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((image?.isNotEmpty ?? false) || imageWidget != null) ...[
                imageWidget ??
                    Image.asset(
                      image!,
                      width: 25,
                      height: 20,
                      fit: BoxFit.cover,
                    ),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
