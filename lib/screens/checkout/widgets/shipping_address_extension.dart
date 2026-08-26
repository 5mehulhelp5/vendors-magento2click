part of 'shipping_address.dart';

extension on _ShippingAddressState {
  void updateAddress(Address? newAddress) {
    address = newAddress;
    loadUserInfoFromAddress(newAddress);
    loadAddressFields(address);
  }

  void loadUserInfoFromAddress(Address? address) {
    _textControllers[AddressFieldType.firstName]?.text =
        address?.firstName ?? '';
    _textControllers[AddressFieldType.lastName]?.text = address?.lastName ?? '';
    _textControllers[AddressFieldType.phoneNumber]?.text =
        address?.phoneNumber ?? '';
    _textControllers[AddressFieldType.email]?.text = address?.email ?? '';
    // Seed the national number so phoneValidationError() also works when the
    // user saves without touching the phone field (onInputChanged never fired).
    phoneNumberWithoutCountryCode = _nationalNumber(address?.phoneNumber);
  }

  /// The 10-digit national number the shopper's phone maps to, with the dial
  /// code (+20) AND the local leading 0 removed — a saved address stores the
  /// number in the local `01…` form, so without stripping the 0 it was wrongly
  /// rejected as "10 digits, no leading 0" and blocked checkout (86d3tmxra).
  /// See [MagentoHelper.egyptianNationalNumber] (unit-tested).
  String _nationalNumber(String? phone) =>
      MagentoHelper.egyptianNationalNumber(phone);

  /// Website rule: the national number must be exactly 10 digits and must not
  /// start with 0. Returns the message to show, or null when the number is ok.
  String? phoneValidationError() =>
      phoneErrorFor(phoneNumberWithoutCountryCode);

  /// Same rule applied to an arbitrary stored number (e.g. a saved address).
  String? phoneErrorFor(String? rawPhone) {
    final phone = _nationalNumber(rawPhone).trim();
    if (phone.isEmpty) {
      return S.of(context).enterMobile;
    }
    if (phone.startsWith('0')) {
      return S.of(context).validMobileWithout0;
    }
    if (phone.length != 10) {
      return S.of(context).validMobile;
    }
    return null;
  }

  void loadAddressFields(Address? address) {
    _textControllers[AddressFieldType.country]?.text = address?.country ?? '';
    _textControllers[AddressFieldType.state]?.text = address?.state ?? '';
    _textControllers[AddressFieldType.city]?.text = address?.city ?? '';
    _textControllers[AddressFieldType.apartment]?.text =
        address?.apartment ?? '';
    _textControllers[AddressFieldType.block]?.text = address?.block ?? '';
    _textControllers[AddressFieldType.street]?.text = address?.street ?? '';
    _textControllers[AddressFieldType.zipCode]?.text = address?.zipCode ?? '';
    refresh();
  }

  bool checkToSave() {
    var listAddress = <Address>[];
    var data = UserBox().addresses;
    if (data != null) {
      listAddress.addAll(data);
    }
    for (var local in listAddress) {
      final isNotExistedInLocal = local.city !=
              _textControllers[AddressFieldType.city]?.text ||
          local.street != _textControllers[AddressFieldType.street]?.text ||
          local.zipCode != _textControllers[AddressFieldType.zipCode]?.text ||
          local.state != _textControllers[AddressFieldType.state]?.text;
      if (isNotExistedInLocal) {
        continue;
      }
      showDialog(
        context: context,
        useRootNavigator: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(S.of(context).yourAddressExistYourLocal),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  S.of(context).ok,
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              )
            ],
          );
        },
      );
      return false;
    }
    return true;
  }

  void saveDataToLocal() {
    var listAddress = <Address>[];
    final address = this.address;
    if (address != null) {
      listAddress.add(address);
    }
    var listData = UserBox().addresses;
    if (listData != null) {
      for (var item in listData) {
        listAddress.add(item);
      }
    }
    UserBox().addresses = listAddress;
    FlashHelper.message(
      context,
      message: S.of(context).yourAddressHasBeenSaved,
    );
  }

  String? validateEmail(String email) {
    if (email.isEmail) {
      return null;
    }
    return 'The E-mail Address must be a valid email address.';
  }

  /// Load Shipping beforehand
  void _loadShipping({bool beforehand = true}) {
    Services().widget.loadShippingMethods(
        context, Provider.of<CartModel>(context, listen: false), beforehand);
  }

  /// on tap to Next Button
  void _onNext() {
    {
      if(UserBox().isLoggedIn){
        // No saved address: the inline add-address form is showing
        // (86d3tmxra #1). Validate it and proceed with the entered address —
        // same as a guest; the order save persists it to the address book.
        if(listAddress.isEmpty){
          final phoneError = phoneValidationError();
          if (phoneError != null) {
            _showMessage(phoneError);
          } else if (_formKey.currentState!.validate()) {
            _formKey.currentState!.save();
            Provider.of<CartModel>(context, listen: false).setAddress(address);
            _loadShipping(beforehand: false);
            widget.onNext!();
          }
        }else if(selectIndex == -1)
        {
          FlashHelper.errorMessage(
            context,
            message: "Please select address first",
          );
        }else{
          // A saved address may predate the region rules or have been synced
          // from the website without a district — block those so the order
          // payload never carries an empty region/city, and ask the user to
          // edit it. We do NOT re-validate the phone FORMAT here: checkout
          // accepts any stored form (Magento normalises +20 / 20 / 01…; see the
          // scope note in test/address_phone_format_test.dart). Re-selecting a
          // saved local-format number (01…) was wrongly firing the "10-digit,
          // no leading 0" error and blocking checkout (86d3g53f8). isValid()
          // below already requires a non-empty phone.
          final selected = listAddress[selectIndex];
          if (!(selected?.isValid() ?? false) || selected?.state == 'SG') {
            _showMessage(S.of(context).pleaseUpdateAddress);
            return;
          }
          _loadShipping(beforehand: false);
          widget.onNext!();
        }
      }else{
        final phoneError = phoneValidationError();
        if(phoneError != null){
          _showMessage(phoneError);
        }else if (_formKey.currentState!.validate()) {
          _formKey.currentState!.save();
          Provider.of<CartModel>(context, listen: false).setAddress(address);
          _loadShipping(beforehand: false);
          widget.onNext!();
        }
      }
    }
  }

  Widget renderStateInput() {
    var items = <DropdownMenuItem>[];
    for (var item in states!) {
      items.add(
        DropdownMenuItem(
          value: item.id,
          child: Text(item.name ?? ''),
        ),
      );
    }
    String? value;

    Object? firstState = states!
        .firstWhereOrNull((o) => o.id.toString() == address!.state.toString());

    if (firstState != null) {
      value = address!.state;
    }
    return DropdownButton(
      items: items,
      value: value,
      onChanged: (dynamic val) async {
        address!.state = val;
        final country = Country(id: address!.country);
        final state = CountryState(id: val);
        cities = await Services().widget.loadCities(country, state);
        address!.zipCode = '';
        _textControllers[AddressFieldType.zipCode]?.text = '';
        refresh();
      },
      isExpanded: true,
      itemHeight: 70,
      hint: Text(S.of(context).stateProvince),
    );
  }

  Widget renderCityInput(int index) {
    var items = <DropdownMenuItem>[];
    for (var item in cities!) {
      items.add(
        DropdownMenuItem(
          value: item.id,
          child: Text(item.name!),
        ),
      );
    }
    String? value;

    // This dropdown lists the governorates, which are the store's Magento
    // *regions* — the selection is kept in address.state so the order payload
    // sends it as `region` and the summary shows its name (was showing the
    // dead "SG" default).
    // Trim/case-insensitive, and match either the extension's Arabic
    // `states_name` (o.name) or the Magento core `region_name` (o.regionName):
    // a website-created address stores the English region name, which only
    // matches the latter (86d3tkj56 #2).
    final savedState = address!.state?.trim().toLowerCase() ?? '';
    City? firstCity = savedState.isEmpty
        ? null
        : cities!.firstWhereOrNull(
            (o) =>
                (o.name ?? '').trim().toLowerCase() == savedState ||
                (o.regionName ?? '').trim().toLowerCase() == savedState);

    if (firstCity != null) {
      value = firstCity.id;
    }
    return DropdownButtonFormField<dynamic>(
      // Re-key on country so a country change discards the old
      // FormFieldState (its value would otherwise survive the item reload).
      key: ValueKey('governorate-${address!.country ?? ''}'),
      items: items,
      value: value,
      validator: (val) {
        final config = _configs[index];
        if (config == null) {
          return null;
        }
        return validateField(
            val, config, _fieldPosition[index] ?? AddressFieldType.unknown);
      },
      onChanged: (dynamic val) async {
        City? city = cities!
            .firstWhereOrNull((o) => o.id.toString() == val.toString());
        address!.state = city?.name;
        _textControllers[AddressFieldType.state]?.text = city?.name ?? '';
        address!.city = '';
        address!.block = '';
        _textControllers[AddressFieldType.city]?.text = '';
        _textControllers[AddressFieldType.block]?.text = '';
        if(city != null) {
          final zonesList =
            await Services().widget.loadZones(city);
          if (zonesList != null) {
            zones = zonesList;
          }
        }
        refresh();
      },
      isExpanded: true,
      itemHeight: 70,
      hint: Text(S.of(context).city),
    );
  }

  Widget renderZoneInput(int index) {
    var items = <DropdownMenuItem>[];
    for (var item in zones!) {
      items.add(
        DropdownMenuItem(
          value: item.id,
          child: Text(item.name!),
        ),
      );
    }
    String? value;

    // The zones are the store's Magento *cities* (districts) — the selection
    // is kept in address.city, matching what the website saves on the order.
    final savedZone = address!.city?.trim().toLowerCase() ?? '';
    City? firstCity = savedZone.isEmpty
        ? null
        : zones!.firstWhereOrNull(
            (o) => (o.name ?? '').trim().toLowerCase() == savedZone);

    if (firstCity != null) {
      value = firstCity.id;
    }
    return DropdownButtonFormField<dynamic>(
      // Re-key on the governorate: changing it reloads the zones and must
      // discard the old FormFieldState, otherwise the stale selection passes
      // the required-validator while address.city is already cleared.
      key: ValueKey('zone-${address!.state ?? ''}'),
      items: items,
      value: value,
      validator: (val) {
        final config = _configs[index];
        if (config == null) {
          return null;
        }
        return validateField(
            val, config, _fieldPosition[index] ?? AddressFieldType.unknown);
      },
      onChanged: (dynamic val) async {
        City? city = zones!
            .firstWhereOrNull((o) => o.id.toString() == val.toString());
        address!.city = city?.name;
        _textControllers[AddressFieldType.city]?.text = city?.name ?? '';
        address!.block = '';
        _textControllers[AddressFieldType.block]?.text = '';
      },
      isExpanded: true,
      itemHeight: 70,
      hint: Text(S.of(context).zone),
    );
  }

  void _openCountryPickerDialog() => showDialog(
        context: context,
        useRootNavigator: false,
        builder: (contextBuilder) => countries!.isEmpty
            ? Theme(
                data: Theme.of(context).copyWith(primaryColor: Colors.pink),
                child: SizedBox(
                  height: 500,
                  child: picker.CountryPickerDialog(
                    titlePadding: const EdgeInsets.all(8.0),
                    contentPadding: const EdgeInsets.all(2.0),
                    searchCursorColor: Colors.pinkAccent,
                    searchInputDecoration:
                        const InputDecoration(hintText: 'Search...'),
                    isSearchable: true,
                    title: Text(S.of(context).country),
                    onValuePicked: (picker_country.Country country) async {
                      _textControllers[AddressFieldType.country]?.text =
                          country.isoCode;
                      address!.country = country.isoCode;
                      final c =
                          Country(id: country.isoCode, name: country.name);
                      cities = await Services().widget.loadCitiesWithCountry(c);
                      address!.state = '';
                      address!.city = '';
                      address!.block = '';
                      _textControllers[AddressFieldType.state]?.text = '';
                      _textControllers[AddressFieldType.city]?.text = '';
                      _textControllers[AddressFieldType.block]?.text = '';
                      refresh();
                    },
                    itemBuilder: (country) {
                      return Row(
                        children: <Widget>[
                          picker.CountryPickerUtils.getDefaultFlagImage(
                              country),
                          const SizedBox(width: 8.0),
                          Expanded(child: Text(country.name)),
                        ],
                      );
                    },
                  ),
                ),
              )
            : Dialog(
                child: SingleChildScrollView(
                  child: Column(
                    children: List.generate(
                      countries!.length,
                      (index) {
                        return GestureDetector(
                          onTap: () async {
                            _textControllers[AddressFieldType.country]?.text =
                                countries![index].code!;
                            address!.country = countries![index].id;
                            address!.countryId = countries![index].id;
                            refresh();
                            Navigator.pop(contextBuilder);
                            // states = await Services()
                            //     .widget
                            //     .loadStates(countries![index]);
                            final c =
                            Country(id: countries![index].code, name: countries![index].name);
                            cities = await Services().widget.loadCitiesWithCountry(c);
                            address!.state = '';
                            address!.city = '';
                            address!.block = '';
                            _textControllers[AddressFieldType.state]?.text = '';
                            _textControllers[AddressFieldType.city]?.text = '';
                            _textControllers[AddressFieldType.block]?.text = '';
                            refresh();
                          },
                          child: ListTile(
                            leading: countries![index].icon != null
                                ? SizedBox(
                                    height: 40,
                                    width: 60,
                                    child: FluxImage(
                                      imageUrl: countries![index].icon!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : (countries![index].code != null
                                    ? Image.asset(
                                        picker.CountryPickerUtils
                                            .getFlagImageAssetPath(
                                                countries![index].code!),
                                        height: 40,
                                        width: 60,
                                        fit: BoxFit.fill,
                                        package: 'country_pickers',
                                      )
                                    : const SizedBox(
                                        height: 40,
                                        width: 60,
                                        child: Icon(Icons.streetview),
                                      )),
                            title: Text(countries![index].name!),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
      );

  void onTextFieldSaved(String? value, AddressFieldType type) {
    switch (type) {
      case AddressFieldType.firstName:
        address?.firstName = value;
        break;
      case AddressFieldType.lastName:
        address?.lastName = value;
        break;
      case AddressFieldType.phoneNumber:
        address?.phoneNumber = value;
        break;
      case AddressFieldType.email:
        address?.email = value;
        break;
      case AddressFieldType.country:
        address?.country = value;
        break;
      case AddressFieldType.state:
        address?.state = value;
        break;
      case AddressFieldType.city:
        // When the governorate dropdown could not load, the plain "City"
        // text field takes its place — the typed value is the region.
        if (cities?.isEmpty ?? true) {
          address?.state = value;
          _textControllers[AddressFieldType.state]?.text = value ?? '';
        }
        address?.city = value;
        break;
      case AddressFieldType.apartment:
        address?.apartment = value;
        break;
      case AddressFieldType.block:
        // The plain "Zone" text field only renders when the zones list is
        // empty; under the Magento-aligned semantics the district it holds
        // is the address *city*.
        if (zones?.isEmpty ?? true) {
          address?.city = value;
          address?.block = '';
        } else {
          address?.block = value;
        }
        break;
      case AddressFieldType.street:
        address?.street = value;
        break;
      case AddressFieldType.zipCode:
        address?.zipCode = value?.trim();
        break;

      /// Unsupported.
      case AddressFieldType.searchAddress:
      case AddressFieldType.selectAddress:
      case AddressFieldType.unknown:
      default:
        break;
    }
  }

  String? getFieldLabel(AddressFieldType type) {
    switch (type) {
      case AddressFieldType.firstName:
        return S.of(context).firstName;
      case AddressFieldType.lastName:
        return S.of(context).lastName;
      case AddressFieldType.phoneNumber:
        return S.of(context).phoneNumber;
      case AddressFieldType.email:
        return S.of(context).email;
      case AddressFieldType.country:
        return S.of(context).country;
      case AddressFieldType.state:
        return S.of(context).stateProvince;
      case AddressFieldType.city:
        return S.of(context).city;
      case AddressFieldType.apartment:
        return S.of(context).streetNameApartment;
      case AddressFieldType.block:
        return S.of(context).zone;
      case AddressFieldType.street:
        return S.of(context).streetName;
      case AddressFieldType.zipCode:
        return S.of(context).zipCode;
      case AddressFieldType.searchAddress:
      case AddressFieldType.selectAddress:
      default:
        return null;
    }
  }

  String? validateField(
      String? val, AddressFieldConfig config, AddressFieldType type) {
    // Email is optional at checkout: never block on empty, only validate the
    // format when the user actually typed something.
    if (type == AddressFieldType.email) {
      if (val?.isEmpty ?? true) {
        return null;
      }
      return validateEmail(val!);
    }

    if (!config.required) {
      return null;
    }

    final label = getFieldLabel(type)?.toLowerCase();
    if ((val?.isEmpty ?? true) && label != null) {
      return S.of(context).theFieldIsRequired(label);
    }
    return null;
  }

  TextInputType getKeyboardType(AddressFieldType type) {
    if (type == AddressFieldType.zipCode &&
        kPaymentConfig.enableAlphanumericZipCode) {
      return TextInputType.streetAddress;
    }
    return type.keyboardType;
  }

  Widget _buildBottom() {
    return CommonSafeArea(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hidden while the inline add-address form is shown (no saved
          // address): "Continue" already submits that form, so a second
          // "Add delivery address" button would be redundant (86d3tmxra #1).
          if(UserBox().isLoggedIn &&
              !(widget.isFromCheckout && listAddress.isEmpty))
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).primaryColor,
              ), // Customize the border color here
              borderRadius: BorderRadius.circular(8.0),
            ),
            width: 150,
            height: 40,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero, backgroundColor: Colors.white),
              onPressed: () async {
                if(UserBox().isLoggedIn && widget.isFromCheckout){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ShippingAddress(isFromAddrssHistory: true,isFromCheckout: false,),
                    ),
                  ).then((_) async {
                    getDataFromLocal();
                  });
                }else {
                  // The save path must enforce the same phone rules as the
                  // checkout Next button, otherwise invalid numbers can be
                  // stored on the address book and reused at checkout.
                  final phoneError = phoneValidationError();
                  if (phoneError != null) {
                    _showMessage(phoneError);
                    return;
                  }
                  if (_formKey.currentState!.validate()) {
                    if (!checkToSave()) return;
                    _formKey.currentState!.save();
                    // saveUserInfo rethrows, and this handler is async with no
                    // catch — so a rejected save became an unhandled async
                    // error: no message, and the Navigator.pop below never ran.
                    // The screen simply sat there, which QA reported as
                    // "nothing appears and it doesn't save" (86d3rrpqr).
                    //
                    // Worth surfacing because the save is fragile by design: it
                    // PUTs the customer's WHOLE address book to customers/me and
                    // the write is atomic, so one address the backend dislikes
                    // blocks every later save. That is not hypothetical — the
                    // city validator used to reject digits and punctuation
                    // (rejecting real cities like "6 أكتوبر" and "New Cairo 5"),
                    // fixed backend-side in 86d3ru7vg. Whatever the next such
                    // rejection is, the shopper should see it rather than tap
                    // into silence.
                    try {
                      await Services().api.saveUserInfo(address!, false);
                    } catch (e) {
                      // saveUserInfo already wraps the backend's message via
                      // MagentoHelper.getErrorMessage, so the Exception text is
                      // the human-readable reason — just strip Dart's prefix.
                      _showMessage(
                        e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
                      );
                      return;
                    }
                    if(widget.isFromAddrssHistory){
                      Navigator.pop(context);
                    }else {
                      Provider.of<CartModel>(context, listen: false)
                          .setAddress(address);
                      // saveDataToLocal();
                    }
                  }
                }
              },
              icon: const Icon(
                CupertinoIcons.plus_app,
                size: 20,
              ),
              label: Text(
                UserBox().isLoggedIn ? S.of(context).addDeliveryAddress.toUpperCase():S.of(context).saveAddress.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).primaryColor,
                    ),
              ),
            ),
          ),
          if(!widget.isFromAddrssHistory)
          Container(width: 8),
          if(!widget.isFromAddrssHistory)
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).primaryColor,
                elevation: 0.0,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(
                Icons.local_shipping_outlined,
                size: 18,
              ),
              onPressed: _onNext,
              label: Text(
                (kPaymentConfig.enableShipping
                        ? S.of(context).continueToShipping
                        : kPaymentConfig.enableReview
                            ? S.of(context).continueToReview
                            : S.of(context).continueToPayment)
                    .toUpperCase(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool isFieldReadOnly(int index) {
    final config = _configs[index];
    if (config == null) {
      return false;
    }

    /// Disable edit only when the field has a default value.
    if (!config.editable && config.defaultValue.isNotEmpty) {
      return true;
    }

    return false;
  }
}
