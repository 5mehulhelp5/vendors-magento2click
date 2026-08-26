import 'package:flutter/material.dart';
import 'package:magentoegypt/generated/l10n.dart';

class ProductCartButton extends StatefulWidget {
  const ProductCartButton({
    Key? key,
    required this.quantity,
    this.borderRadiusValue = 0,
    required this.increaseQuantityFunction,
    required this.decreaseQuantityFunction,
  }) : super(key: key);

  final int quantity;
  final double borderRadiusValue;
  final VoidCallback increaseQuantityFunction;
  final VoidCallback decreaseQuantityFunction;

  @override
  State<ProductCartButton> createState() => _ProductCartButtonState();
}

class _ProductCartButtonState extends State<ProductCartButton> {
  var _isShowQuantity = false;

  int get _quantity => widget.quantity;

  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant ProductCartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_quantity == 0) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          if (!_isShowQuantity) {
            showQuantity();
          }
        } else {
          if (_isShowQuantity) {
            hideQuantity();
          }
        }
      },
      child: Builder(
        builder: (BuildContext context) {
          final hasFocus = _focusNode.hasFocus;
          return GestureDetector(
              onTap: () {
                if (hasFocus) {
                  _focusNode.unfocus();
                } else {
                  _focusNode.requestFocus();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: _isShowQuantity
                      ? buildSelector()
                      : _quantity == 0
                          ? buildAddButton()
                          : buildQuantity(),
                ),
              ));
        },
      ),
    );
  }

  Widget buildSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6, right: 6),
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColorLight,
        border: Border.all(color: Theme.of(context).colorScheme.secondary),
        borderRadius: BorderRadius.circular(widget.borderRadiusValue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: decreaseQuantity,
            icon: Icon(
              Icons.remove,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ),
          Text('$_quantity'),
          IconButton(
            onPressed: increaseQuantity,
            icon: Icon(
              Icons.add,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAddButton() {
    return ElevatedButton(
        onPressed: () {
          _focusNode.requestFocus();
          increaseQuantity();
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadiusValue),
          ),
          minimumSize: const Size.square(40),
          padding: EdgeInsets.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(S.of(context).addToCart),
        )

        // Icon(
        //   Icons.add,
        //   size: 20,
        //   color: Theme.of(context).colorScheme.background,
        // ),
        );
  }

  Widget buildQuantity() {
    return OutlinedButton(
      onPressed: _focusNode.requestFocus,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.borderRadiusValue),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        side: BorderSide(color: Theme.of(context).primaryColor),
        minimumSize: const Size.square(40),
      ),
      child: Text(
        '$_quantity',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void increaseQuantity() {
    widget.increaseQuantityFunction();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        if (_quantity == 0) {
          hideQuantity();
        }
      }
    });
  }

  void decreaseQuantity() {
    widget.decreaseQuantityFunction();
  }

  void showQuantity() {
    setState(() {
      _isShowQuantity = true;
    });
  }

  void hideQuantity() {
    setState(() {
      _isShowQuantity = false;
    });
  }
}
