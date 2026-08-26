import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// The parsed form of a category's `description`.
///
/// Magento stores it as a stack of PageBuilder HTML blocks — for an L3
/// category typically three: the SEO copy box, a promo section of image
/// cards, and a strip of round subcategory tiles. Each is inline-styled and
/// class-named per category ("locafy-boys-season-…"), so the blocks are
/// recognised by SHAPE rather than by class: a text card, a group of sibling
/// elements holding one image each, and the text that introduces them.
class CategoryDescriptionSection {
  /// Copy blocks: the SEO card's text, or the heading/subtitle that
  /// introduces [cards].
  final List<CategoryDescriptionBlock> blocks;

  /// Image cards in this section, in document order. Empty for the SEO card.
  final List<CategoryDescriptionCard> cards;

  const CategoryDescriptionSection({
    this.blocks = const [],
    this.cards = const [],
  });

  bool get isTextOnly => cards.isEmpty;

  /// A group whose every card is just an image with a short caption is the
  /// round-tile strip; anything richer (badge, headline, blurb, buttons) is a
  /// full-bleed promo card.
  bool get isTileStrip =>
      cards.isNotEmpty &&
      cards.every((c) =>
          c.image != null && c.lines.length == 1 && c.lines.first.text.length <= 30);
}

/// One image card: the picture, where it goes, and its text lines tagged with
/// the element they came from, so a renderer can tell a badge from a headline
/// without relying on their order.
class CategoryDescriptionCard {
  final String? image;
  final String? href;
  final List<CategoryDescriptionLine> lines;

  const CategoryDescriptionCard({this.image, this.href, this.lines = const []});

  CategoryDescriptionLine? get _titleLine {
    for (final line in lines) {
      if (line.isHeading) return line;
    }
    return null;
  }

  /// The card's headline — the heading element, or the caption on a tile.
  String? get title => (_titleLine ?? (lines.isEmpty ? null : lines.first))?.text;

  /// Small uppercase label above the headline ("New Season").
  String? get badge {
    final title = _titleLine;
    if (title == null) return null;
    final index = lines.indexOf(title);
    for (var i = 0; i < index; i++) {
      if (lines[i].isPlainLine) return lines[i].text;
    }
    return null;
  }

  /// The blurb under the headline.
  String? get body {
    for (final line in lines) {
      if (line.isParagraph) return line.text;
    }
    return null;
  }

  /// Button-ish lines after the headline ("Shop Now →", "Light & Breathable").
  List<String> get actions {
    final title = _titleLine;
    if (title == null) return const [];
    return lines
        .skip(lines.indexOf(title) + 1)
        .where((l) => l.isPlainLine)
        .map((l) => l.text)
        .toList();
  }
}

class CategoryDescriptionLine {
  final String text;
  final String tag;

  const CategoryDescriptionLine(this.text, this.tag);

  bool get isHeading => tag.length == 2 && tag.startsWith('h');
  bool get isParagraph => tag == 'p';

  /// A bare <div>/<span> line — the badges, CTAs and chips in a promo card.
  bool get isPlainLine => !isHeading && !isParagraph;
}

enum CategoryDescriptionKind {
  title,
  tagline,
  heading,
  paragraph,
  question,
  callout,
  divider,
  bullet,
}

/// A run of text inside a block; [href] marks it as a link.
class CategoryDescriptionSpan {
  final String text;
  final String? href;

  const CategoryDescriptionSpan(this.text, {this.href});
}

class CategoryDescriptionBlock {
  final CategoryDescriptionKind kind;
  final List<CategoryDescriptionSpan> spans;

  const CategoryDescriptionBlock(this.kind, this.spans);

  /// The block's text with the link runs folded back in.
  String get text => spans.map((s) => s.text).join();

  bool get isTitle => kind == CategoryDescriptionKind.title;
  bool get isTagline => kind == CategoryDescriptionKind.tagline;
  bool get isHeading => kind == CategoryDescriptionKind.heading;
  bool get isCallout => kind == CategoryDescriptionKind.callout;
  bool get isDivider => kind == CategoryDescriptionKind.divider;
  bool get isQuestion => kind == CategoryDescriptionKind.question;
}

/// The storefront path a description link points at, stripped down to the
/// `url_path` a category would be stored under — `/eg-en/kidswear/boys.html`
/// and `https://locafy.market/eg-ar/kidswear/boys.html?x=1#top` both become
/// `kidswear/boys`.
///
/// Returns null when the link can't be a category on this store: another
/// host, a mailto/tel, or an empty path. [host] is the store's own origin;
/// pass null to accept any absolute URL's path.
String? storefrontPathOf(String href, {String? host}) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return null;

  Uri? uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return null;
  }
  if (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }
  if (uri.host.isNotEmpty && host != null) {
    final storeHost = Uri.tryParse(host)?.host ?? host;
    if (uri.host != storeHost) return null;
  }

  var path = uri.path;
  if (path.endsWith('.html')) {
    path = path.substring(0, path.length - '.html'.length);
  }
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  // Drop the store-view prefix the website puts on every URL (eg-en, eg-ar).
  if (segments.isNotEmpty && RegExp(r'^[a-z]{2}-[a-z]{2}$').hasMatch(segments.first)) {
    segments.removeAt(0);
  }
  if (segments.isEmpty) return null;
  return segments.join('/');
}

/// Split the stored category HTML into renderable sections.
///
/// PageBuilder keeps some of the authored markup HTML-escaped inside a
/// `data-content-type="html"` node, so the first parse can yield the real
/// markup as *text* — parse that again to get elements.
List<CategoryDescriptionSection> parseCategoryDescription(String html) {
  try {
    final outer = html_parser.parse(html);
    final inner = outer.body?.text ?? '';
    final sections = _collect(outer);
    if (inner.contains('<') && inner.contains('>')) {
      final nested = _collect(html_parser.parse(inner));
      if (nested.isNotEmpty) return nested;
    }
    return sections;
  } catch (_) {
    return const [];
  }
}

/// The SEO card's blocks, for callers that only want the copy.
List<CategoryDescriptionBlock> parseCategoryDescriptionCopy(String html) {
  for (final section in parseCategoryDescription(html)) {
    if (section.isTextOnly && section.blocks.isNotEmpty) return section.blocks;
  }
  return const [];
}

List<CategoryDescriptionSection> _collect(dom.Document document) {
  document.querySelectorAll('style, script').forEach((e) => e.remove());
  final root = document.body ?? document.documentElement;
  if (root == null) return const [];

  final sections = <CategoryDescriptionSection>[];
  final pendingText = <CategoryDescriptionBlock>[];
  _walkSections(root, sections, pendingText);
  if (pendingText.isNotEmpty) {
    sections.add(CategoryDescriptionSection(blocks: List.of(pendingText)));
  }
  return sections.where((s) => s.blocks.isNotEmpty || s.cards.isNotEmpty).toList();
}

void _walkSections(
  dom.Element element,
  List<CategoryDescriptionSection> sections,
  List<CategoryDescriptionBlock> pendingText,
) {
  // Cards are always siblings (a grid row, a scroller), so a group is whatever
  // this level yields.
  final cards = <CategoryDescriptionCard>[];

  for (final child in element.children) {
    final tag = child.localName;
    if (tag == 'style' || tag == 'script' || tag == 'button') continue;
    if (child.id.contains('readmore')) continue;

    // The SEO copy box is its own section, and its text must not be mistaken
    // for a promo section's heading.
    if (child.id.startsWith('locafy-seo-box')) {
      _flush(sections, pendingText, cards);
      final blocks = <CategoryDescriptionBlock>[];
      _walkBlocks(child, blocks);
      if (blocks.isNotEmpty) {
        if (blocks.first.isHeading) {
          blocks[0] = CategoryDescriptionBlock(
              CategoryDescriptionKind.title, blocks.first.spans);
        }
        sections.add(CategoryDescriptionSection(blocks: blocks));
      }
      continue;
    }

    final images = child.querySelectorAll('img');
    if (images.length == 1 &&
        (tag == 'a' || child.querySelector('a[href]') != null)) {
      cards.add(_card(child, images.first));
      continue;
    }

    if (images.isEmpty && _isTextish(child)) {
      _walkBlocks(child, pendingText, singleElement: true);
      continue;
    }

    _walkSections(child, sections, pendingText);
  }

  if (cards.isNotEmpty) {
    sections.add(CategoryDescriptionSection(
      blocks: List.of(pendingText),
      cards: cards,
    ));
    pendingText.clear();
  }
}

void _flush(
  List<CategoryDescriptionSection> sections,
  List<CategoryDescriptionBlock> pendingText,
  List<CategoryDescriptionCard> cards,
) {
  if (cards.isNotEmpty) {
    sections.add(CategoryDescriptionSection(
      blocks: List.of(pendingText),
      cards: List.of(cards),
    ));
    cards.clear();
    pendingText.clear();
  }
}

/// Is this a text element rather than a layout wrapper?
bool _isTextish(dom.Element element) {
  final tag = element.localName ?? '';
  if (const ['h1', 'h2', 'h3', 'h4', 'p', 'li'].contains(tag)) return true;
  return tag == 'div' && element.children.isEmpty && element.text.trim().isNotEmpty;
}

CategoryDescriptionCard _card(dom.Element element, dom.Element image) {
  final link = element.localName == 'a'
      ? element
      : element.querySelector('a[href]');
  final lines = <CategoryDescriptionLine>[];
  _lines(element, lines);
  return CategoryDescriptionCard(
    image: image.attributes['src'],
    href: link?.attributes['href'],
    lines: lines,
  );
}

const _inlineTags = ['span', 'strong', 'em', 'b', 'i', 'u', 'small'];

/// Collect a card's text one visual line per element, keeping the tag so the
/// renderer can tell a badge from a headline.
void _lines(dom.Element element, List<CategoryDescriptionLine> lines) {
  for (final child in element.children) {
    final tag = child.localName ?? '';
    if (tag == 'style' || tag == 'script' || tag == 'img') continue;
    // "Shop Now <span>→</span>" is one line, not two.
    final blockChildren =
        child.children.where((e) => !_inlineTags.contains(e.localName));
    if (blockChildren.isEmpty) {
      final text = child.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isNotEmpty) lines.add(CategoryDescriptionLine(text, tag));
      continue;
    }
    _lines(child, lines);
  }
}

void _walkBlocks(dom.Element element, List<CategoryDescriptionBlock> blocks,
    {bool singleElement = false}) {
  if (singleElement) {
    _addBlock(blocks, _kindOf(element, blocks), element);
    return;
  }
  for (final child in element.children) {
    final tag = child.localName;
    final style = child.attributes['style'] ?? '';
    if (tag == 'style' || tag == 'script' || tag == 'button') continue;
    if (child.id.contains('readmore')) continue;

    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
        _addBlock(blocks, CategoryDescriptionKind.heading, child);
        continue;
      case 'p':
        _addBlock(blocks, _paragraphKind(child), child);
        continue;
      case 'li':
        _addBlock(blocks, CategoryDescriptionKind.bullet, child);
        continue;
      case 'div':
        // The FAQ group is wrapped in a div with a top rule.
        if (style.contains('border-top')) {
          blocks.add(
              const CategoryDescriptionBlock(CategoryDescriptionKind.divider, []));
        }
        if (child.children.isEmpty) {
          _addBlock(blocks, _kindOf(child, blocks), child);
          continue;
        }
        _walkBlocks(child, blocks);
        continue;
      default:
        _walkBlocks(child, blocks);
    }
  }
}

/// A bare text line is the tagline when it still sits above the body copy,
/// and ordinary copy once the body has started.
CategoryDescriptionKind _kindOf(
    dom.Element element, List<CategoryDescriptionBlock> blocks) {
  final tag = element.localName ?? '';
  if (tag.length == 2 && tag.startsWith('h')) {
    return CategoryDescriptionKind.heading;
  }
  if (tag == 'p') return _paragraphKind(element);
  final hasBody = blocks.any((b) => !b.isHeading && !b.isTitle);
  return hasBody
      ? CategoryDescriptionKind.paragraph
      : CategoryDescriptionKind.tagline;
}

/// A paragraph whose whole content is one boxed link is the "learn more"
/// callout; one set in bold is an FAQ question.
CategoryDescriptionKind _paragraphKind(dom.Element p) {
  final links = p.querySelectorAll('a');
  if (links.length == 1 &&
      (links.first.attributes['style'] ?? '').contains('background') &&
      p.text.trim() == links.first.text.trim()) {
    return CategoryDescriptionKind.callout;
  }
  final weight = RegExp(r'font-weight:\s*(\d+)')
      .firstMatch(p.attributes['style'] ?? '')
      ?.group(1);
  if (weight != null && (int.tryParse(weight) ?? 400) >= 600) {
    return CategoryDescriptionKind.question;
  }
  return CategoryDescriptionKind.paragraph;
}

void _addBlock(List<CategoryDescriptionBlock> blocks,
    CategoryDescriptionKind kind, dom.Element element) {
  final spans = _spans(element);
  if (spans.isEmpty) return;
  // A leftover CSS fragment from a truncated PageBuilder style block — not
  // prose, and not something to show a shopper.
  final text = spans.map((s) => s.text).join();
  if (text.contains('{') || text.contains('}')) return;
  blocks.add(CategoryDescriptionBlock(kind, spans));
}

/// Flatten an element into text runs, keeping `<a>` runs separate so they can
/// be styled and tapped.
List<CategoryDescriptionSpan> _spans(dom.Element element) {
  final spans = <CategoryDescriptionSpan>[];

  void visit(dom.Node node, String? href) {
    if (node is dom.Text) {
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
      if (text.trim().isEmpty && spans.isEmpty) return;
      spans.add(CategoryDescriptionSpan(text, href: href));
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName;
    if (tag == 'style' || tag == 'script' || tag == 'button') return;
    final linkHref = tag == 'a' ? (node.attributes['href'] ?? href) : href;
    for (final child in node.nodes) {
      visit(child, linkHref);
    }
  }

  for (final node in element.nodes) {
    visit(node, null);
  }

  // Merge neighbouring runs that share a destination, then trim the ends.
  final merged = <CategoryDescriptionSpan>[];
  for (final span in spans) {
    if (merged.isNotEmpty && merged.last.href == span.href) {
      merged[merged.length - 1] = CategoryDescriptionSpan(
        merged.last.text + span.text,
        href: span.href,
      );
    } else {
      merged.add(span);
    }
  }
  if (merged.isNotEmpty) {
    merged[0] = CategoryDescriptionSpan(merged.first.text.trimLeft(),
        href: merged.first.href);
    merged[merged.length - 1] = CategoryDescriptionSpan(
        merged.last.text.trimRight(),
        href: merged.last.href);
  }
  // Links carry their own padding in the source ("\n  t-shirts\n"); tighten
  // them so the sentence reads as one line.
  for (var i = 0; i < merged.length; i++) {
    if (merged[i].href != null) {
      merged[i] =
          CategoryDescriptionSpan(merged[i].text.trim(), href: merged[i].href);
    }
  }
  return merged.where((s) => s.text.isNotEmpty).toList();
}
