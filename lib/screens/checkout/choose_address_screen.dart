import 'dart:async';

import 'package:country_pickers/country_pickers.dart';
import 'package:flutter/material.dart';
import 'package:magentoegypt/screens/checkout/widgets/shipping_address.dart';
import 'package:provider/provider.dart';

import '../../common/config.dart';
import '../../common/constants.dart';
import '../../data/boxes.dart';
import '../../generated/l10n.dart';
import '../../models/index.dart'
    show Address, CartModel, City, Country, User, UserModel;
import '../../services/index.dart';
import '../index.dart' show BaseScreen;

class ChooseAddressScreen extends StatefulWidget {
  final void Function(Address?) callback;
  final bool isFromAddrssHistory;

  const ChooseAddressScreen(this.callback, this.isFromAddrssHistory);

  @override
  BaseScreen<ChooseAddressScreen> createState() => _StateChooseAddress();
}

class _StateChooseAddress extends BaseScreen<ChooseAddressScreen> {
  List<Address?> listAddress = [];
  User? user;
  bool isLoading = true;

  // Localization lookups so a saved address shows its governorate and country
  // in the app language instead of the raw stored English (86d3tkj56 #3).
  List<City> _governorates = [];
  final Map<String, String> _countryNames = {};

  @override
  void afterFirstLayout(BuildContext context) {
    getDataFromLocal();
    _loadLocalization();
    final loggedIn = Provider.of<UserModel>(context, listen: false).loggedIn;
    if (loggedIn) {
      getUserInfo().then((_) async {
        // Re-read the box: the call above went to customers/me and refreshed
        // UserBox().addresses via MagentoService.saveDataToLocal(). Without
        // this, listAddress keeps whatever the *first* getDataFromLocal() read
        // — empty on a fresh login — so the address book stayed blank even
        // though the account had saved addresses (86d3rrpqr).
        getDataFromLocal();
        await getDataFromNetwork();
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Pull-to-refresh. Goes to the network deliberately rather than re-reading
  /// UserBox: an address edited on the website must show up here. Mirrors the
  /// logged-in branch of [afterFirstLayout].
  Future<void> _reload() async {
    final loggedIn = Provider.of<UserModel>(context, listen: false).loggedIn;
    if (!loggedIn) return;
    await getUserInfo();
    getDataFromLocal();
    await getDataFromNetwork();
  }

  Future<void> getUserInfo() async {
    final localUser = UserBox().userInfo;
    if (localUser != null) {
      final user = await Services().api.getUserInfo(localUser.cookie);
      if (user != null) {
        user.isSocial = localUser.isSocial ?? false;
        setState(() {
          this.user = user;
        });
      }
    }
  }

  void getDataFromLocal() {
    var list = List<Address>.from(UserBox().addresses ?? <Address>[]);
    listAddress = list;
    setState(() {});
  }

  Future<void> getDataFromNetwork() async {
    try {
      // No `!`: getCustomerInfo returns a null Future on frameworks that don't
      // implement it (Magento included), so force-unwrapping threw here too.
      // See address_mixin.getShippingAddress (86d3r3gpd).
      var result = await Services().api.getCustomerInfo(user!.id);

      final billing = result?['billing'];
      if (billing != null) {
        listAddress.add(billing);
      }
    } catch (err) {
      printLog(err);
    }
  }

  void removeData(int index) {
    var data = UserBox().addresses;
    if (data != null) {
      data.removeAt(index);
      UserBox().addresses = data;
    }
    getDataFromLocal();
  }

  /// Load the governorate list and localized country names used by
  /// [convertToCard] so saved addresses render in the app language.
  Future<void> _loadLocalization() async {
    try {
      final govs =
          await Services().widget.loadCitiesWithCountry(Country(id: 'EG'));
      if (mounted) setState(() => _governorates = govs ?? <City>[]);
    } catch (e) {
      printLog(e);
    }
    final codes = <String>{
      'EG',
      ...listAddress
          .map((a) => a?.country)
          .whereType<String>()
          .where((c) => c.isNotEmpty),
    };
    for (final code in codes) {
      final name = await Services().api.getLocalizedCountryName(code);
      if (name != null && mounted) {
        setState(() => _countryNames[code] = name);
      }
    }
  }

  /// The saved governorate (address.state) is a Magento region name — Arabic
  /// for app-created addresses, English for website-created ones. Resolve it
  /// against the governorate list and show the name in the current language
  /// (86d3tkj56 #3). Falls back to the raw value if it cannot be resolved.
  String? _localizeGovernorate(String? state) {
    if (state == null || state.trim().isEmpty) return state;
    final saved = state.trim().toLowerCase();
    final isArabic = (SettingsBox().languageCode ?? 'en').toLowerCase() == 'ar';
    for (final g in _governorates) {
      if ((g.name ?? '').trim().toLowerCase() == saved ||
          (g.regionName ?? '').trim().toLowerCase() == saved) {
        return isArabic ? (g.name ?? state) : (g.regionName ?? g.name ?? state);
      }
    }
    return state;
  }

  /// Mirrors ShippingAddress.convertToCard: every row is guarded, so a null or
  /// empty field disappears instead of printing the literal text "null".
  Widget convertToCard(BuildContext context, Address address) {
    final s = S.of(context);

    Widget row(String label, String? value) {
      if (value == null || value.isEmpty || value == 'null') {
        return const SizedBox();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$label:  ',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
            Flexible(
              child: Column(
                children: <Widget>[Text(value)],
              ),
            )
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 10.0),
        row(s.streetName, address.street),
        // City = governorate (Magento region, held in address.state) and
        // Zone = district (Magento city, held in address.city). These two were
        // swapped here, so the labels contradicted the form, the order summary
        // and the website.
        row(s.city, _localizeGovernorate(address.state)),
        row(s.zone, address.city),
        // The country is stored as the ISO-2 code ("EG"); render the localized
        // name (مصر) when available, else the country_pickers English name.
        row(s.country,
            _countryNames[address.country] ?? _countryName(address.country)),
        // No zip-code row: checkout does not collect a postcode (it is
        // configured invisible), so it was only ever rendering "null".
        const SizedBox(height: 6.0),
      ],
    );
  }

  /// ISO-2 code -> display name, falling back to whatever we were given.
  String? _countryName(String? code) {
    if (code == null || code.isEmpty) return null;
    try {
      return CountryPickerUtils.getCountryByIsoCode(code).name;
    } catch (_) {
      return code;
    }
  }

  Widget _renderBillingAddress() {
    if (user == null || user!.billing == null) {
      return const SizedBox();
    }
    final userFullName =
        '${user!.billing!.firstName ?? ''} ${user!.billing!.lastName ?? ''}'
            .trim();
    return GestureDetector(
      onTap: () {
        final add = Address(
            firstName: (user!.billing!.firstName?.isNotEmpty ?? false)
                ? user!.billing!.firstName
                : user!.firstName,
            lastName: (user!.billing!.lastName?.isNotEmpty ?? false)
                ? user!.billing!.lastName
                : user!.lastName,
            email: (user!.billing!.email?.isNotEmpty ?? false)
                ? user!.billing!.email
                : user!.email,
            street: user!.billing!.address1,
            country: user!.billing!.country,
            state: user!.billing!.state,
            phoneNumber: user!.billing!.phone,
            city: user!.billing!.city,
            zipCode: user!.billing!.postCode);
        Provider.of<CartModel>(context, listen: false).setAddress(add);
        Navigator.of(context).pop();
        widget.callback(add);
      },
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).primaryColorLight,
            borderRadius: BorderRadius.circular(10)),
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              S.of(context).billingAddress,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(userFullName),
            Text(user!.billing!.phone ?? ''),
            Text(user!.billing!.email ?? ''),
            Text(user!.billing!.address1 ?? ''),
            Text(user!.billing!.city ?? ''),
            Text(user!.billing!.postCode ?? '')
          ],
        ),
      ),
    );
  }

  Widget _renderShippingAddress() {
    if (user == null || user!.shipping == null) return const SizedBox();
    final userFullName =
        '${user!.billing!.firstName ?? ''} ${user!.billing!.lastName ?? ''}'
            .trim();
    return GestureDetector(
      onTap: () {
        final add = Address(
          firstName: (user!.shipping!.firstName?.isNotEmpty ?? false)
              ? user!.shipping!.firstName
              : user!.firstName,
          lastName: (user!.shipping!.lastName?.isNotEmpty ?? false)
              ? user!.shipping!.lastName
              : user!.lastName,
          email: user!.email,
          street: user!.shipping!.address1,
          country: user!.shipping!.country,
          state: user!.shipping!.state,
          city: user!.shipping!.city,
          zipCode: user!.shipping!.postCode,
          phoneNumber: user!.shipping!.phone,
        );
        Provider.of<CartModel>(context, listen: false).setAddress(add);
        Navigator.of(context).pop();
        widget.callback(add);
      },
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).primaryColorLight,
            borderRadius: BorderRadius.circular(10)),
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              S.of(context).shippingAddress,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(userFullName),
            Text(user!.shipping!.address1 ?? ''),
            Text(user!.shipping!.city ?? ''),
            Text(user!.shipping!.postCode ?? '')
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColorLight,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: const Icon(Icons.arrow_back_ios),
        ),
        actions: <Widget>[
          if (widget.isFromAddrssHistory)
            IconButton(
              icon: Icon(
                Icons.add,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShippingAddress(
                      isFromAddrssHistory: true,
                      isFromCheckout: false,
                    ),
                  ),
                ).then((_) async {
                  getDataFromLocal();
                });
              },
            )
        ],
        title: Text(
          S.of(context).selectAddress,
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: SingleChildScrollView(
          // An account with one or two addresses does not fill the viewport, so
          // without this the pull gesture is never reported.
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: <Widget>[
              // Only in the checkout picker. On Magento, User.billing and
              // User.shipping are both built from the SAME default address
              // (user.dart:191-199), so these two cards render identical content
              // under two different headings — and the saved-address list below
              // shows that same address a third time. In the address book that is
              // pure duplication; in checkout they stay, as the quick way to pick
              // the default without scrolling.
              if (!widget.isFromAddrssHistory) ...[
                _renderBillingAddress(),
                _renderShippingAddress(),
              ],
              Column(
                children: [
                  if (listAddress.isEmpty && !isLoading)
                    Center(
                      child: Image.asset(
                        kEmptySearch,
                        width: 120,
                        height: 120,
                      ),
                    ),
                  if (listAddress.isEmpty && isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: kLoadingWidget(context),
                    ),
                  ...List.generate(listAddress.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.all(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: GestureDetector(
                          onTap: () {
                            if (widget.isFromAddrssHistory) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ShippingAddress(
                                      address: listAddress[index],
                                      isFromAddrssHistory: true,
                                      isFromCheckout: false),
                                ),
                              ).then((_) async {
                                getDataFromLocal();
                              });
                            } else {
                              Provider.of<CartModel>(context, listen: false)
                                  .setAddress(listAddress[index]);
                              Navigator.of(context).pop();
                              widget.callback(listAddress[index]);
                            }
                          },
                          child: Container(
                            width: MediaQuery.of(context).size.width,
                            decoration: BoxDecoration(
                                color: Theme.of(context).primaryColorLight),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Icon(
                                      Icons.home,
                                      color: Theme.of(context).primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: convertToCard(
                                        context, listAddress[index]!),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      // saveUserInfo throws on any API failure —
                                      // an expired customer token surfaces as
                                      // "The consumer isn't authorized to access
                                      // self". Uncaught, that was an unhandled
                                      // exception and the row just stayed put
                                      // with no explanation.
                                      try {
                                        await Services().api.saveUserInfo(
                                            listAddress[index]!, true);
                                        getDataFromLocal();
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(e
                                                .toString()
                                                .replaceFirst(
                                                    RegExp(r'^Exception:\s*'),
                                                    '')),
                                          ),
                                        );
                                      }
                                      // removeData(index);
                                    },
                                    child: Icon(
                                      Icons.delete,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
