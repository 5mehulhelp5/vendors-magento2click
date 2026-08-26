import 'package:flutter/material.dart';

import '../../common/constants.dart';
import '../../generated/l10n.dart';
import '../../services/index.dart';

/// Native replacement for the "Newsletter Subscriptions" webview.
///
/// The menu used to open `{store}/eg-en/newsletter/manage/`, which is a
/// session-gated Magento route. The app authenticates with a REST bearer token
/// and holds no storefront PHP session, so that page always bounced to the
/// customer login form (86d3rrtpy).
///
/// The subscription itself is a single boolean the REST API does expose, as
/// `extension_attributes.is_subscribed` on the customer resource, so the row is
/// served natively instead.
class NewsletterSubscriptionScreen extends StatefulWidget {
  const NewsletterSubscriptionScreen({super.key});

  @override
  State<NewsletterSubscriptionScreen> createState() =>
      _NewsletterSubscriptionScreenState();
}

class _NewsletterSubscriptionScreenState
    extends State<NewsletterSubscriptionScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  /// Null means the store doesn't expose the attribute — shown as unavailable,
  /// deliberately not as an unchecked box the shopper could toggle into a
  /// request the backend will never honour.
  bool? _isSubscribed;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await Services().api.getNewsletterSubscription();
      if (!mounted) return;
      setState(() {
        _isSubscribed = value;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _message(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    final previous = _isSubscribed;
    // Move the switch immediately, then reconcile with whatever the server
    // confirms — and roll back if the write fails, so the UI never claims a
    // subscription state the store didn't accept.
    setState(() {
      _isSubscribed = value;
      _isSaving = true;
    });
    try {
      final saved = await Services().api.setNewsletterSubscription(value);
      if (!mounted) return;
      setState(() {
        _isSubscribed = saved ?? value;
        _isSaving = false;
      });
      _showMessage(S.of(context).updateSuccess);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubscribed = previous;
        _isSaving = false;
      });
      _showMessage(_message(e));
    }
  }

  String _message(Object e) {
    // When the store is down or behind a WAF it answers with an HTML error
    // page, so jsonDecode throws a FormatException whose toString() is a parser
    // dump ("Unexpected character (at line 2, character 1) <html><head>").
    // Observed on a real 502 during testing — never show that to a shopper.
    printLog('[Newsletter] $e');
    if (e is FormatException) return S.of(context).somethingWrong;
    return e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColorLight,
        title: Text(
          s.newsletterSubscriptions,
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
      ),
      body: _buildBody(s),
    );
  }

  Widget _buildBody(S s) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _centeredMessage(_error!);
    }
    if (_isSubscribed == null) {
      return _centeredMessage(s.newsletterUnavailable);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: SwitchListTile(
            value: _isSubscribed!,
            // Disabled mid-write so a double tap can't queue two conflicting
            // read-modify-write round trips against the customer resource.
            onChanged: _isSaving ? null : _toggle,
            title: Text(
              s.subscribeToNewsletter,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.newsletterDescription),
            ),
          ),
        ),
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _centeredMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
