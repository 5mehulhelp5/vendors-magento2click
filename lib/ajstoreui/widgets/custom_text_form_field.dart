import 'package:flutter/material.dart';
import 'package:magentoegypt/ajstoreui/core/app_export.dart';

class CustomTextFormField extends StatelessWidget {
  const CustomTextFormField(
      {super.key,
      this.shape,
      this.padding,
      this.variant,
      this.fontStyle,
      this.alignment,
      this.width,
      this.margin,
      this.controller,
      this.focusNode,
      this.isObscureText = false,
      this.textInputAction = TextInputAction.next,
      this.textInputType = TextInputType.text,
      this.maxLines,
      this.hintText,
      this.prefix,
      this.prefixConstraints,
      this.suffix,
      this.suffixConstraints,
      this.validator});

  final TextFormFieldShape? shape;

  final TextFormFieldPadding? padding;

  final TextFormFieldVariant? variant;

  final TextFormFieldFontStyle? fontStyle;

  final Alignment? alignment;

  final double? width;

  final EdgeInsetsGeometry? margin;

  final TextEditingController? controller;

  final FocusNode? focusNode;

  final bool? isObscureText;

  final TextInputAction? textInputAction;

  final TextInputType? textInputType;

  final int? maxLines;

  final String? hintText;

  final Widget? prefix;

  final BoxConstraints? prefixConstraints;

  final Widget? suffix;

  final BoxConstraints? suffixConstraints;

  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return alignment != null
        ? Align(
            alignment: alignment ?? Alignment.center,
            child: _buildTextFormFieldWidget(),
          )
        : _buildTextFormFieldWidget();
  }

  Container _buildTextFormFieldWidget() {
    return Container(
      width: width ?? double.maxFinite,
      margin: margin,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        style: _setFontStyle(),
        obscureText: isObscureText!,
        textInputAction: textInputAction,
        keyboardType: textInputType,
        maxLines: maxLines ?? 1,
        decoration: _buildDecoration(),
        validator: validator,
      ),
    );
  }

  InputDecoration _buildDecoration() {
    return InputDecoration(
      hintText: hintText ?? '',
      hintStyle: _setFontStyle(),
      border: _setBorderStyle(),
      enabledBorder: _setBorderStyle(),
      focusedBorder: _setBorderStyle(),
      disabledBorder: _setBorderStyle(),
      prefixIcon: prefix,
      prefixIconConstraints: prefixConstraints,
      suffixIcon: suffix,
      suffixIconConstraints: suffixConstraints,
      fillColor: _setFillColor(),
      filled: _setFilled(),
      isDense: true,
      contentPadding: _setPadding(),
    );
  }

  TextStyle _setFontStyle() {
    switch (fontStyle) {
      case TextFormFieldFontStyle.BarlowRegular15:
        return TextStyle(
          color: ColorConstant.black9006c,
          fontSize: getFontSize(
            15,
          ),
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w400,
        );
      case TextFormFieldFontStyle.AvenirArabicMedium16:
        return TextStyle(
          color: ColorConstant.whiteA700,
          fontSize: getFontSize(
            16,
          ),
          fontFamily: 'Avenir Arabic',
          fontWeight: FontWeight.w500,
        );
      case TextFormFieldFontStyle.BarlowMedium15:
        return TextStyle(
          color: ColorConstant.black900,
          fontSize: getFontSize(
            15,
          ),
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w500,
        );
      case TextFormFieldFontStyle.AvenirArabicMedium16WhiteA700:
        return TextStyle(
          color: ColorConstant.whiteA700,
          fontSize: getFontSize(
            16,
          ),
          fontFamily: 'Avenir Arabic',
          fontWeight: FontWeight.w400,
        );
      case TextFormFieldFontStyle.Button:
        return TextStyle(
          color: ColorConstant.red800,
          fontSize: getFontSize(
            16,
          ),
          fontFamily: 'Barlow',
          fontWeight: FontWeight.w500,
        );
      default:
        return TextStyle(
          color: ColorConstant.whiteA700,
          fontSize: getFontSize(
            16,
          ),
          fontFamily: 'Rubik',
          fontWeight: FontWeight.w400,
        );
    }
  }

  BorderRadius _setOutlineBorderRadius() {
    switch (shape) {
      default:
        return BorderRadius.circular(
          getHorizontalSize(
            4.00,
          ),
        );
    }
  }

  InputBorder _setBorderStyle() {
    switch (variant) {
      case TextFormFieldVariant.OutlineBlack90063:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide(
            color: ColorConstant.black90063,
            width: 1,
          ),
        );
      case TextFormFieldVariant.FillBlack90090:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide.none,
        );
      case TextFormFieldVariant.UnderLineGray300:
        return UnderlineInputBorder(
          borderSide: BorderSide(
            color: ColorConstant.gray300,
          ),
        );
      case TextFormFieldVariant.OutlineRed800:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide(
            color: ColorConstant.red800,
            width: 1,
          ),
        );
      case TextFormFieldVariant.White:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide.none,
        );
      case TextFormFieldVariant.None:
        return InputBorder.none;
      default:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide.none,
        );
    }
  }

  Color _setFillColor() {
    switch (variant) {
      case TextFormFieldVariant.FillBlack90090:
        return ColorConstant.black90090;
      case TextFormFieldVariant.OutlineRed800:
        return ColorConstant.whiteA700;
      case TextFormFieldVariant.White:
        return ColorConstant.whiteA700;
      default:
        return ColorConstant.black900;
    }
  }

  bool _setFilled() {
    switch (variant) {
      case TextFormFieldVariant.OutlineBlack90063:
        return false;
      case TextFormFieldVariant.FillBlack90090:
        return true;
      case TextFormFieldVariant.UnderLineGray300:
        return false;
      case TextFormFieldVariant.OutlineRed800:
        return true;
      case TextFormFieldVariant.White:
        return true;
      case TextFormFieldVariant.None:
        return false;
      default:
        return true;
    }
  }

  EdgeInsetsGeometry _setPadding() {
    switch (padding) {
      case TextFormFieldPadding.PaddingAll11:
        return getPadding(
          all: 11,
        );
      case TextFormFieldPadding.PaddingT41:
        return getPadding(
          left: 16,
          top: 41,
          right: 16,
          bottom: 41,
        );
      case TextFormFieldPadding.PaddingT14:
        return getPadding(
          top: 14,
          bottom: 14,
        );
      default:
        return getPadding(
          all: 5,
        );
    }
  }
}

enum TextFormFieldShape {
  RoundedBorder4,
}

enum TextFormFieldPadding {
  PaddingAll5,
  PaddingAll11,
  PaddingT41,
  PaddingT14,
}

enum TextFormFieldVariant {
  None,
  FillBlack900,
  OutlineBlack90063,
  FillBlack90090,
  UnderLineGray300,
  OutlineRed800,
  White,
}

enum TextFormFieldFontStyle {
  RubikRegular16,
  BarlowRegular15,
  AvenirArabicMedium16,
  BarlowMedium15,
  AvenirArabicMedium16WhiteA700,
  Button,
}
