import 'package:flutter/material.dart';

import '../../../widgets/common/index.dart' show FluxImage;

class ItemCategory extends StatelessWidget {
  final String? categoryId;
  final String categoryName;
  final String? categoryImage;
  final String? newCategoryId;
  final Function(String?,String?)? onTap;

  const ItemCategory({
    super.key,
    this.categoryId,
    required this.categoryName,
    this.categoryImage,
    this.newCategoryId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var highlightColor = newCategoryId == categoryId
        ? Theme.of(context).colorScheme.secondary.withOpacity(0.2)
        : Colors.transparent;
    return GestureDetector(
      onTap: () => onTap?.call(categoryId,categoryName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: categoryImage != null ? 5 : 10,
          vertical: 4,
        ),
        margin: const EdgeInsets.only(left: 5, top: 10, bottom: 4),
        decoration: BoxDecoration(
          color: highlightColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: categoryImage != null
            ? Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height-300,
                        child: FluxImage(
                          imageUrl: categoryImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height-300,
                      color: Colors.black.withOpacity(0.25),
                      alignment: Alignment.center,
                      child: Text(
                      categoryName.toUpperCase(),
                      maxLines: 2,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black45,
                            offset: Offset(2, 2),
                          ),
                        ],
                      )
                          .apply(
                        fontSizeFactor: 0.7,
                      ),
                      textAlign: TextAlign.center,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),),
                  ],
                ),
              )
            : Center(
                child: Text(
                  categoryName.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
              ),
      ),
    );
  }
}
