import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/constants.dart';
import '../../../common/tools.dart';
import '../../../frameworks/magento/services/magento_service.dart';
import '../../../generated/l10n.dart';
import '../../../models/app_model.dart';
import '../../../models/entities/back_drop_arguments.dart';
import '../../../services/index.dart';
import '../../../widgets/common/flux_image.dart';
import '../../../widgets/common/webview.dart';
import 'category_description_model.dart';

export 'category_description_model.dart';

/// Palette lifted from the authored SEO box so the app matches the website's
/// rendering of the same content.
const _kAccent = Color(0xFF004AFF);
const _kAccentLight = Color(0xFF4F7CFF);
const _kCalloutBg = Color(0xFFF3F6FF);
const _kBorder = Color(0xFFE5E7EB);
const _kHeadingText = Color(0xFF111827);
const _kBodyText = Color(0xFF374151);
const _kMutedText = Color(0xFF6B7280);
const _kKicker = Color(0xFF4B5563);
const _kTileLabel = Color(0xFF0F172A);

/// The category's own description, as the website builds it on an L3 page
/// (`category.level == 3`): a card of SEO copy, a promo section of image
/// cards, and a strip of round subcategory tiles — three PageBuilder blocks,
/// rendered here in the order the catalogue stores them.
///
/// The markup is inline-styled and class-named per category, and its
/// expander is driven by a `<script>` the app can't run, so it is parsed into
/// typed sections (see [parseCategoryDescription]) and re-rendered with
/// Flutter widgets styled to match.
class CategoryDescription extends StatefulWidget {
  final String? categoryId;

  const CategoryDescription({super.key, this.categoryId});

  @override
  State<CategoryDescription> createState() => _CategoryDescriptionState();
}

class _CategoryDescriptionState extends State<CategoryDescription> {
  List<CategoryDescriptionSection> _sections = const [];
  bool _expanded = false;

  /// One recognizer per distinct link, built with the sections and disposed
  /// with the state — building them per frame would leak one a frame.
  final Map<String, TapGestureRecognizer> _linkTaps = {};

  /// Guards against a slow response for a category the user has already
  /// switched away from (the subcategory strip changes category in place).
  String? _pendingId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant CategoryDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _load();
    }
  }

  @override
  void dispose() {
    _disposeLinkTaps();
    super.dispose();
  }

  void _disposeLinkTaps() {
    for (final recognizer in _linkTaps.values) {
      recognizer.dispose();
    }
    _linkTaps.clear();
  }

  Future<void> _load() async {
    final id = widget.categoryId;
    if (id == _pendingId) return;
    _pendingId = id;
    // A rebuild always follows the call sites (first build / category switch),
    // so reset in place rather than asking for another one.
    _sections = const [];
    _expanded = false;
    _disposeLinkTaps();

    final api = Services().api;
    if (id == null || id.isEmpty || api is! MagentoService) return;

    final lang = Provider.of<AppModel>(context, listen: false).langCode;
    final html = await api.fetchCategoryDescription(id, lang: lang);
    if (!mounted || _pendingId != id || html == null) return;
    final sections = parseCategoryDescription(html);
    for (final section in sections) {
      for (final block in section.blocks) {
        for (final span in block.spans) {
          final href = span.href;
          if (href == null || _linkTaps.containsKey(href)) continue;
          _linkTaps[href] =
              TapGestureRecognizer()..onTap = () => _openLink(href);
        }
      }
    }
    _resolvingLinks = _resolveLinks(api, sections, lang);
    setState(() => _sections = sections);
  }

  /// Category links in the copy, keyed by href, once resolved.
  Map<String, CategoryUrlTarget> _linkTargets = const {};
  Future<void>? _resolvingLinks;

  /// Most links in the copy point at categories the app can open itself
  /// (`/eg-en/kidswear/boys.html`). Resolve them all in one lookup as soon as
  /// the description lands, so a tap navigates in-app instead of leaving for
  /// the browser. Whatever doesn't resolve — CMS pages like
  /// "why-sell-on-locafy" — still opens as a page.
  Future<void> _resolveLinks(
    MagentoService api,
    List<CategoryDescriptionSection> sections,
    String? lang,
  ) async {
    final byPath = <String, List<String>>{};
    void collect(String? href) {
      if (href == null) return;
      final path = storefrontPathOf(href, host: kMediaDomain);
      if (path == null) return;
      byPath.putIfAbsent(path, () => []).add(href);
    }

    for (final section in sections) {
      for (final block in section.blocks) {
        for (final span in block.spans) {
          collect(span.href);
        }
      }
      for (final card in section.cards) {
        collect(card.href);
      }
    }
    if (byPath.isEmpty) return;

    final resolved = await api.resolveCategoryUrls(
      byPath.keys,
      lang: lang,
      // A link in this category's own copy points into its own subtree, which
      // is what tells "kidswear/boys/pants" from the seven other "pants".
      preferUnder: widget.categoryId,
    );
    if (!mounted) return;
    final targets = <String, CategoryUrlTarget>{};
    resolved.forEach((path, target) {
      for (final href in byPath[path] ?? const <String>[]) {
        targets[href] = target;
      }
    });
    _linkTargets = targets;
  }

  /// Open a link from the copy or a card: the app's own category page when
  /// the URL is one of ours, otherwise the page itself (CMS content such as
  /// "why sell on Locafy" has no in-app equivalent).
  Future<void> _openLink(String href) async {
    // A tap can land before the lookup returns; it is one request and it
    // started with the description, so waiting on it beats guessing.
    try {
      await _resolvingLinks;
    } catch (_) {
      // Resolution failed — fall through and open the page.
    }
    if (!mounted) return;

    final target = _linkTargets[href];
    if (target != null) {
      Navigator.of(context).pushNamed(
        RouteList.backdrop,
        arguments: BackDropArguments(
          cateId: target.id,
          cateName: target.name,
        ),
      );
      return;
    }

    final url = _absolute(href);
    if (storefrontPathOf(href, host: kMediaDomain) == null) {
      // Somewhere else entirely — hand it to the system.
      Tools.launchURL(url);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebView(url: url)),
    );
  }

  String _absolute(String path) => path.startsWith('http')
      ? path
      : '$kMediaDomain${path.startsWith('/') ? '' : '/'}$path';

  @override
  Widget build(BuildContext context) {
    if (_sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in _sections)
          section.isTextOnly ? _buildCopyCard(section) : _buildMedia(section),
      ],
    );
  }

  // ---------------------------------------------------------------- copy card

  Widget _buildCopyCard(CategoryDescriptionSection section) {
    final blocks = section.blocks;
    final title = blocks.first;
    final rest = blocks.skip(1).toList();
    // The tagline sits with the title above the toggle, like the website; the
    // body starts after it.
    final hasTagline = rest.isNotEmpty && rest.first.isTagline;
    final tagline = hasTagline ? rest.first : null;
    final body = hasTagline ? rest.skip(1).toList() : rest;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The 6px accent bar across the top of the card.
          Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_kAccent, _kAccentLight]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBlock(title),
                if (tagline != null) _buildBlock(tagline),
                if (body.isNotEmpty) _buildToggle(),
                if (_expanded) ...body.map(_buildBlock),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _expanded ? S.of(context).hideDetails : S.of(context).readMore,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(CategoryDescriptionBlock block) {
    switch (block.kind) {
      case CategoryDescriptionKind.title:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _text(
              block,
              const TextStyle(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: _kHeadingText,
              )),
        );
      case CategoryDescriptionKind.tagline:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _text(
              block,
              const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                color: _kMutedText,
              )),
        );
      case CategoryDescriptionKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: _text(
              block,
              const TextStyle(
                fontSize: 18,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: _kHeadingText,
              )),
        );
      case CategoryDescriptionKind.question:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _text(
              block,
              const TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: _kHeadingText,
              )),
        );
      case CategoryDescriptionKind.callout:
        final href = block.spans.first.href;
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: href == null ? null : () => _openLink(href),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _kCalloutBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _text(
                  block,
                  const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kAccent,
                  ),
                  // The whole box is the tap target; a second one inside it
                  // would just be the same destination.
                  plain: true,
                ),
              ),
            ),
          ),
        );
      case CategoryDescriptionKind.divider:
        return const Padding(
          padding: EdgeInsets.only(top: 2, bottom: 16),
          child: Divider(height: 1, thickness: 1, color: _kBorder),
        );
      case CategoryDescriptionKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(color: _kBodyText)),
              Expanded(child: _text(block, _bodyStyle)),
            ],
          ),
        );
      case CategoryDescriptionKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _text(block, _bodyStyle),
        );
    }
  }

  static const _bodyStyle = TextStyle(
    fontSize: 15,
    height: 1.7,
    color: _kBodyText,
  );

  /// Renders a block's runs, styling the linked ones and wiring their taps.
  /// [plain] keeps the link styling but drops the inline tap target, for a
  /// block that is itself one big link.
  Widget _text(CategoryDescriptionBlock block, TextStyle style,
      {bool plain = false, TextAlign? align}) {
    if (block.spans.length == 1 && block.spans.first.href == null) {
      return Text(block.spans.first.text, style: style, textAlign: align);
    }
    return Text.rich(
      TextSpan(
        children: [
          for (final span in block.spans)
            TextSpan(
              text: span.text,
              style: span.href == null
                  ? null
                  : const TextStyle(
                      color: _kAccent,
                      fontWeight: FontWeight.w600,
                    ),
              recognizer:
                  (plain || span.href == null) ? null : _linkTaps[span.href],
            ),
        ],
      ),
      style: style,
      textAlign: align,
    );
  }

  // ------------------------------------------------------------- media blocks

  Widget _buildMedia(CategoryDescriptionSection section) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.blocks.isNotEmpty) _buildSectionHead(section.blocks),
          if (section.isTileStrip)
            _buildTileStrip(section.cards)
          else
            ...section.cards.map(_buildPromoCard),
        ],
      ),
    );
  }

  /// The centred kicker / headline / subtitle that introduces a promo row.
  Widget _buildSectionHead(List<CategoryDescriptionBlock> blocks) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final block in blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: block.isHeading
                  ? _text(
                      block,
                      const TextStyle(
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: _kHeadingText,
                      ),
                      align: TextAlign.center)
                  : block.isTagline
                      ? _text(
                          block,
                          const TextStyle(
                            fontSize: 12,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                            color: _kKicker,
                          ),
                          align: TextAlign.center)
                      : _text(
                          block,
                          const TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: _kMutedText,
                          ),
                          align: TextAlign.center),
            ),
        ],
      ),
    );
  }

  /// Full-bleed image card with the copy laid over the bottom — the website's
  /// seasonal/promo split.
  Widget _buildPromoCard(CategoryDescriptionCard card) {
    final href = card.href;
    final badge = card.badge;
    final body = card.body;
    final actions = card.actions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: href == null ? null : () => _openLink(href),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 380,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (card.image != null)
                  FluxImage(
                    imageUrl: _absolute(card.image!),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.46, 1.0],
                      colors: [
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.26),
                        Colors.black.withOpacity(0.72),
                      ],
                    ),
                  ),
                ),
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  start: 18,
                  end: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (badge != null) _buildBadge(badge),
                      if (card.title != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            card.title!,
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.04,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (body != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.7,
                              color: Colors.white.withOpacity(0.88),
                            ),
                          ),
                        ),
                      if (actions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < actions.length; i++)
                                _buildPill(actions[i], primary: i == 0),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.86),
            ),
          ),
        ),
      ],
    );
  }

  /// The translucent "Shop Now →" button and the chip beside it.
  Widget _buildPill(String text, {required bool primary}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: primary ? 18 : 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(primary ? 0.12 : 0.10),
        border: Border.all(color: Colors.white.withOpacity(primary ? 0.18 : 0.14)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: primary ? 15 : 13,
          fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
          color: Colors.white.withOpacity(primary ? 1 : 0.90),
        ),
      ),
    );
  }

  /// Round subcategory tiles in a horizontal scroller.
  Widget _buildTileStrip(List<CategoryDescriptionCard> cards) {
    const size = 92.0;
    // Circle + gap + two lines of label (12px at 1.3) + the list's own
    // vertical padding. A caption like "TSHIRT & SHIRTS" wraps, so the row has
    // to be tall enough for two lines or the column overflows.
    return SizedBox(
      height: size + 8 + (12 * 1.3 * 2) + 16 + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final card = cards[index];
          final href = card.href;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: href == null ? null : () => _openLink(href),
            child: SizedBox(
              width: size,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: card.image == null
                          ? const SizedBox()
                          : FluxImage(
                              imageUrl: _absolute(card.image!),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (card.title ?? '').toUpperCase(),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w800,
                      color: _kTileLabel,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
