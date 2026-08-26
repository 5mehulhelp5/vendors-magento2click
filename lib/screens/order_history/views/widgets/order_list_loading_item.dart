import 'dart:math';

import 'package:flutter/material.dart';
import 'package:inspireui/inspireui.dart';
import 'package:provider/provider.dart';

import '../../../../models/app_model.dart';

class OrderListLoadingItem extends StatelessWidget {
  const OrderListLoadingItem({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    var isDarkTheme = Provider.of<AppModel>(context, listen: false).darkTheme;
    // Mirrors the compact order card (86d3tkhgz #5): a date + order-number
    // header over the total/tax/qty/status row — no product image, name or
    // address, and the same short height so the placeholder matches the result.
    return Container(
      width: size.width,
      height: 120,
      margin: const EdgeInsets.only(
          top: 12.0, left: 15.0, right: 15.0, bottom: 8.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14.0, 12.0, 14.0, 8.0),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10.0),
                topRight: Radius.circular(10.0),
              ),
              color: isDarkTheme ? Colors.black87 : Colors.white,
            ),
            child: Row(
              children: [
                Skeleton(
                  height: 12.0,
                  width: Random().nextInt(50) + 90.0,
                ),
                const Spacer(),
                Skeleton(
                  height: 12.0,
                  width: Random().nextInt(30) + 70.0,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10.0),
                  bottomRight: Radius.circular(10.0),
                ),
                color: isDarkTheme ? Colors.black26 : Colors.grey.shade300,
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatusSkeleton(),
                    _StatusSkeleton(),
                    _StatusSkeleton(),
                    _StatusSkeleton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSkeleton extends StatelessWidget {
  const _StatusSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Skeleton(height: 18.0, width: 70.0),
        SizedBox(height: 10),
        Skeleton(height: 14.0, width: 20.0),
      ],
    );
  }
}
