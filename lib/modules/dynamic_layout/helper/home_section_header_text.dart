import 'package:flutter/material.dart';

import 'helper.dart';

class HomeSectionHeaderText extends StatelessWidget {
  final String? headerText;

  final double? verticalMargin;
  final double? horizontalMargin;

  const HomeSectionHeaderText({
    this.headerText,
    Key? key,
    this.verticalMargin = 6.0,
    this.horizontalMargin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    var isDesktop = Layout.isDisplayDesktop(context);

    return SizedBox(
      width: screenSize.width,
      child: Container(
        color: Theme.of(context).colorScheme.background,
        margin: EdgeInsets.only(top: verticalMargin!),
        padding: EdgeInsets.only(
          left: horizontalMargin ?? 16.0,
          top: verticalMargin!,
          right: horizontalMargin ?? 8.0,
          bottom: verticalMargin!,
        ),
        child: Row(
          textBaseline: TextBaseline.alphabetic,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDesktop) ...[
                    const Divider(height: 50, indent: 30, endIndent: 30),
                  ],
                  Text(
                    headerText ?? '',
                    style: isDesktop
                        ? Theme.of(context)
                            .textTheme
                            .headlineSmall!
                            .copyWith(fontWeight: FontWeight.w700)
                        : Theme.of(context).textTheme.titleLarge,
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
