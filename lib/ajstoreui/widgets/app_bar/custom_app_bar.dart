import 'package:flutter/material.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';

// ignore: must_be_immutable
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  CustomAppBar(
      {required this.height,
      this.styleType,
      this.leadingWidth,
      this.leading,
      this.title,
      this.centerTitle,
      this.actions});

  double height;

  Style? styleType;

  double? leadingWidth;

  Widget? leading;

  Widget? title;

  bool? centerTitle;

  List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      toolbarHeight: height,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      flexibleSpace: _getStyle(),
      leadingWidth: leadingWidth ?? 0,
      leading: leading,
      title: title,
      titleSpacing: 0,
      centerTitle: centerTitle ?? false,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size(
        size.width,
        height,
      );
  Container? _getStyle() {
    switch (styleType) {
      case Style.bgShadowBlack90019:
        return Container(
          height: getVerticalSize(
            60,
          ),
          width: double.maxFinite,
          decoration: BoxDecoration(
            color: ColorConstant.whiteA700,
            boxShadow: [
              BoxShadow(
                color: ColorConstant.black90019,
                spreadRadius: getHorizontalSize(
                  2,
                ),
                blurRadius: getHorizontalSize(
                  2,
                ),
                offset: const Offset(
                  1,
                  1,
                ),
              ),
            ],
          ),
        );
      case Style.bgShadowBluegray50019_1:
        return Container(
          height: getVerticalSize(
            60,
          ),
          width: double.maxFinite,
          decoration: BoxDecoration(
            color: ColorConstant.whiteA700,
            borderRadius: BorderRadius.circular(
              getHorizontalSize(
                10,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: ColorConstant.blueGray50019,
                spreadRadius: getHorizontalSize(
                  2,
                ),
                blurRadius: getHorizontalSize(
                  2,
                ),
                offset: const Offset(
                  1,
                  1,
                ),
              ),
            ],
          ),
        );
      case Style.bgShadowBluegray50019:
        return Container(
          height: getVerticalSize(
            60,
          ),
          width: double.maxFinite,
          decoration: BoxDecoration(
            color: ColorConstant.whiteA700,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(
                getHorizontalSize(
                  10,
                ),
              ),
              bottomRight: Radius.circular(
                getHorizontalSize(
                  10,
                ),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: ColorConstant.blueGray50019,
                spreadRadius: getHorizontalSize(
                  2,
                ),
                blurRadius: getHorizontalSize(
                  2,
                ),
                offset: const Offset(
                  1,
                  1,
                ),
              ),
            ],
          ),
        );
      default:
        return null;
    }
  }
}

enum Style {
  bgShadowBlack90019,
  bgShadowBluegray50019_1,
  bgShadowBluegray50019,
}
