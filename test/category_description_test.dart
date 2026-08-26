// The L3 category page shows the category's own description — the SEO box the
// website renders under the category title.
//
// Magento stores it as PageBuilder markup: the authored HTML is *escaped* text
// inside a `data-content-type="html"` node, carries inline styles, and drives
// its own "Read More" from a <script> the app can't run. The parser has to dig
// the prose out of that and drop everything else, so this pins the shape the
// store actually sends (verbatim structure from category 145, Jackets & Coats)
// rather than tidy HTML.

import 'package:flutter_test/flutter_test.dart';
import 'package:magentoegypt/screens/products/widgets/category_description.dart';

/// Trimmed verbatim payload of `GET V1/categories/145` -> custom_attributes
/// -> description on the English store view.
const _seoBox = r'''
<div data-content-type="html" data-appearance="default" data-element="main">&lt;div id="locafy-seo-box-3" style="max-width:900px; margin:40px auto; font-family:Arial, sans-serif;"&gt;

    &lt;div id="locafy-wrapper-3" style="background:#ececec; padding:25px 30px; border-radius:8px;"&gt;

        &lt;h2 style="font-size:20px; font-weight:700; margin:0 0 10px 0; color:#222;"&gt;
            Jackets &amp; Coats for Every Occasion
        &lt;/h2&gt;

        &lt;div style="font-size:14px; color:#555; margin-top:4px;"&gt;
            Outerwear • Local Brands • Everyday Essentials
        &lt;/div&gt;

        &lt;div id="locafy-readmore-3" style="cursor:pointer; color:#004aff;"&gt;
            Read More
        &lt;/div&gt;

        &lt;!-- COLLAPSIBLE CONTENT --&gt;
        &lt;div id="locafy-content-3" style="display:none; padding-top:10px;"&gt;

            &lt;p style="font-size:15px; margin-bottom:16px;"&gt;
                Locafy&rsquo;s Jackets &amp; Coats line will help you stay fashionable and ready for any season.
            &lt;/p&gt;

            &lt;h3 style="font-size:18px; font-weight:700;"&gt;Frequently Asked Questions&lt;/h3&gt;

            &lt;p style="font-size:15px; font-weight:600;"&gt;
                1. Can I exchange a jacket for a different size?
            &lt;/p&gt;

            &lt;p style="font-size:15px; margin-bottom:0;"&gt;
                Want to know more? Browse our
                &lt;a href="/eg-en/faqs-english" style="color:#004aff;"&gt;FAQs&lt;/a&gt;
                to see how easy it is to shop or sell with us.
            &lt;/p&gt;

        &lt;/div&gt;

    &lt;/div&gt;

&lt;/div&gt;

&lt;script&gt;
document.addEventListener("DOMContentLoaded", function () {
    var toggle = document.getElementById("locafy-readmore-3");
    toggle.addEventListener("click", function () { content.style.display = "block"; });
});
&lt;/script&gt;
</div>
''';

/// What an L1/L2 node carries instead: a PageBuilder banner — a <style> block
/// and markup, with no prose worth showing under the category title.
const _bannerOnly = r'''
<div data-content-type="html" data-appearance="default" data-element="main">&lt;style&gt;#html-body [data-pb-style=XD27L7O]{display:none}
.category-banner { margin:0 auto; max-width:1280px; }&lt;/style&gt;
&lt;div class="category-banner"&gt;&lt;img src="/media/wysiwyg/womenswear.jpg" alt="" /&gt;&lt;/div&gt;
</div>
''';

/// The L3 shape (category 144, Menswear > Clothing): a PageBuilder tile grid
/// linking the subcategories, and only *then* the SEO box. Stored unescaped
/// here — both variants occur in the catalogue.
const _l3TileGridThenSeoBox = '''
<div data-content-type="html" data-element="main">
  <style>#html-body [data-pb-style=JKQKXKN]{display:none}</style>
  <div class="category-tiles">
    <a href="/eg-en/loca-men/clothing/t-shirt.html"><img src="/media/a.jpg" alt="" /><p>SHIRTS & T-SHIRTS</p></a>
    <a href="/eg-en/loca-men/clothing/pants.html"><img src="/media/b.jpg" alt="" /><p>PANTS</p></a>
    <a href="/eg-en/loca-men/clothing/jeans.html"><img src="/media/c.jpg" alt="" /><p>JEANS</p></a>
  </div>
</div>
<div data-content-type="html" data-element="main">
  <div id="locafy-seo-box" style="max-width:900px;">
    <div id="locafy-wrapper" style="background:#ececec;">
      <h2 style="font-size:20px;">Menswear Clothing on Locafy</h2>
      <div style="font-size:14px;">Quality • Local Brands • Everyday Essentials</div>
      <div id="locafy-readmore">Read More</div>
      <div id="locafy-content" style="display:none;">
        <p>Locafy brings together everyday menswear from trusted Egyptian brands.</p>
      </div>
    </div>
  </div>
</div>
''';

/// The current template (category 270, KIDSWEAR > BOYS): card chrome, tagline,
/// a <button> trigger, inline links, a boxed "learn more" link, and an FAQ
/// group behind a top rule. The card design is driven off these parts.
const _currentTemplate = '''
<div data-content-type="html" data-element="main">
  <div id="locafy-seo-box-kboys" style="max-width: 920px;">
    <div id="locafy-wrapper-kboys" style="background:#ffffff; border:1px solid #e5e7eb;">
      <div style="height: 6px; background: linear-gradient(90deg, #004aff 0%, #4f7cff 100%);"></div>
      <div style="padding: 28px 32px;">
        <h2 style="font-size:28px; font-weight:700;">Boys' Clothing on Locafy !!!</h2>
        <div style="font-size:15px; color:#6b7280;">Practical Wear • School • Playtime • Local Egyptian Brands</div>
        <button id="locafy-readmore-kboys" type="button" style="background:#004aff;">Read More</button>
        <div id="locafy-content-kboys" style="max-height: 0;">
          <div style="padding-top: 22px;">
            <p style="font-size:15px;">
              Each piece is designed for school days. You can also browse all
              <a href="/eg-en/kidswear.html" style="color:#004aff; font-weight:600;">
                kidswear categories
              </a>
              to build a complete wardrobe.
            </p>
            <h3 style="font-size:20px; font-weight:700;">Start Shopping or Selling</h3>
            <p style="font-size:15px;">
              <a href="/eg-en/why-sell-on-locafy-en" style="background:#f3f6ff; color:#004aff; padding:10px 14px; border-radius:10px;">
                Learn more about selling on Locafy
              </a>
            </p>
            <h3 style="font-size:20px; font-weight:700;">FAQs</h3>
            <div style="border-top: 1px solid #e5e7eb; padding-top:16px;">
              <p style="font-size:15px; font-weight:700; color:#111827;">Can I return boys' clothing if it does not fit?</p>
              <p style="font-size:15px; color:#374151;">Yes. Unworn items can be returned within 14 days.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
''';

/// What an L3 description actually holds (category 270, KIDSWEAR > BOYS):
/// THREE PageBuilder blocks — the SEO copy box, a seasonal promo split, and a
/// strip of round subcategory tiles. Class names are per category, so the
/// parser has to recognise these by shape.
const _threeBlocks = '''
<div data-content-type="html" data-element="main">
  <div id="locafy-seo-box-kboys">
    <div id="locafy-wrapper-kboys">
      <h2>Boys' Clothing on Locafy !!!</h2>
      <div>Practical Wear • School • Playtime</div>
      <button id="locafy-readmore-kboys">Read More</button>
      <div id="locafy-content-kboys"><p>Building your child's wardrobe is easier.</p></div>
    </div>
  </div>
</div>
<div data-content-type="html" data-element="main">
  <section class="locafy-boys-season-split">
    <div class="locafy-boys-season-wrap">
      <div class="locafy-boys-season-head">
        <div class="locafy-boys-season-kicker">Boys Seasonal Collection</div>
        <h2 class="locafy-boys-season-heading">Discover Boys Summer &amp; Winter Styles</h2>
        <p class="locafy-boys-season-subtitle">Shop standout seasonal looks for boys.</p>
      </div>
      <div class="locafy-boys-season-grid">
        <div class="locafy-boys-season-card">
          <a href="/eg-en/kidswear/discover/boys-summer.html" class="locafy-boys-season-link" aria-label="Shop Boys Summer"></a>
          <img src="/media/wysiwyg/boyssummer.jpeg" alt="Boys Summer Collection" />
          <div class="locafy-boys-season-overlay">
            <div class="locafy-boys-season-content">
              <div class="locafy-boys-season-badge">New Season</div>
              <h2 class="locafy-boys-season-title">Boys Summer</h2>
              <p class="locafy-boys-season-text">Fresh shirts and lightweight styles.</p>
              <div class="locafy-boys-season-actions">
                <div class="locafy-boys-season-cta">Shop Now <span>→</span></div>
                <div class="locafy-boys-season-chip">Light &amp; Breathable</div>
              </div>
            </div>
          </div>
        </div>
        <div class="locafy-boys-season-card">
          <a href="/eg-en/kidswear/discover/boys-winter.html" class="locafy-boys-season-link"></a>
          <img src="/media/wysiwyg/winterboy.jpg" alt="Winter Boys Collection" />
          <div class="locafy-boys-season-overlay">
            <div class="locafy-boys-season-content">
              <div class="locafy-boys-season-badge">Cold Weather Edit</div>
              <h2 class="locafy-boys-season-title">Winter Boys</h2>
              <p class="locafy-boys-season-text">Layered looks and cozy essentials.</p>
              <div class="locafy-boys-season-actions">
                <div class="locafy-boys-season-cta">Explore Now <span>→</span></div>
                <div class="locafy-boys-season-chip">Warm &amp; Stylish</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</div>
<div data-content-type="html" data-element="main">
  <div class="subcategories-section">
    <div class="subcategories-scroll">
      <div class="subcategory-scroll-item">
        <a href="/eg-en/kidswear/discover/outwear-boy.html"><img src="/media/wysiwyg/outwearboy.jpg" alt="Outwear"><p>Outwear</p></a>
      </div>
      <div class="subcategory-scroll-item">
        <a href="/eg-en/kidswear/discover/homewear-boy.html"><img src="/media/wysiwyg/homewearboy.jpg" alt="Homewear"><p>Homewear</p></a>
      </div>
      <div class="subcategory-scroll-item">
        <a href="/eg-en/kidswear/discover/footwear-boy.html"><img src="/media/wysiwyg/footwearboy.jpg" alt="Footwear"><p>Footwear</p></a>
      </div>
    </div>
  </div>
</div>
''';

void main() {
  group('description links resolve to a category path', () {
    const host = 'https://testing.locafy.market';

    test('a storefront link loses its store view and .html', () {
      // What the copy actually contains.
      expect(storefrontPathOf('/eg-en/kidswear.html', host: host), 'kidswear');
      expect(
          storefrontPathOf('/eg-ar/kidswear/boys/t-shirts-shirts.html',
              host: host),
          'kidswear/boys/t-shirts-shirts');
      // A CMS page has no .html and still yields a path — it simply won't
      // match a category, and the caller opens the page.
      expect(storefrontPathOf('/eg-en/why-sell-on-locafy-en', host: host),
          'why-sell-on-locafy-en');
    });

    test('absolute URLs on our own host resolve the same way', () {
      expect(
          storefrontPathOf('$host/eg-en/kidswear/discover/boys-summer.html?utm=x#top',
              host: host),
          'kidswear/discover/boys-summer');
    });

    test('anything not ours is left to open as a link', () {
      expect(storefrontPathOf('https://instagram.com/locafy', host: host), isNull);
      expect(storefrontPathOf('mailto:hi@locafy.market', host: host), isNull);
      expect(storefrontPathOf('tel:+201000000000', host: host), isNull);
      expect(storefrontPathOf('/eg-en/', host: host), isNull);
      expect(storefrontPathOf('   ', host: host), isNull);
    });

    test('a path without a store view prefix is kept whole', () {
      // Only an xx-yy segment is treated as the store view, so a real
      // top-level category is not mistaken for one and eaten.
      expect(storefrontPathOf('/kidswear/boys.html', host: host),
          'kidswear/boys');
      expect(storefrontPathOf('/t-shirts-shirts.html', host: host),
          't-shirts-shirts');
    });
  });

  group('all three description blocks', () {
    final sections = parseCategoryDescription(_threeBlocks);

    test('every block becomes a section, in the order the store holds them',
        () {
      expect(sections, hasLength(3));
      expect(sections[0].isTextOnly, isTrue);
      expect(sections[0].blocks.first.text, "Boys' Clothing on Locafy !!!");
      expect(sections[1].cards, hasLength(2));
      expect(sections[2].cards, hasLength(3));
    });

    test('the promo section keeps the heading that introduces it', () {
      final head = sections[1].blocks.map((b) => b.text).toList();

      expect(head, contains('Boys Seasonal Collection'));
      expect(head, contains('Discover Boys Summer & Winter Styles'));
      expect(head, contains('Shop standout seasonal looks for boys.'));
      // That heading belongs to the promo row, not to the copy card above it.
      expect(sections[0].blocks.map((b) => b.text),
          isNot(contains('Discover Boys Summer & Winter Styles')));
    });

    test('a promo card splits into badge, title, blurb and buttons', () {
      final summer = sections[1].cards.first;

      expect(summer.image, '/media/wysiwyg/boyssummer.jpeg');
      expect(summer.href, '/eg-en/kidswear/discover/boys-summer.html');
      expect(summer.badge, 'New Season');
      expect(summer.title, 'Boys Summer');
      expect(summer.body, 'Fresh shirts and lightweight styles.');
      // "Shop Now <span>→</span>" is one button, not two lines.
      expect(summer.actions, ['Shop Now →', 'Light & Breathable']);
    });

    test('image-with-caption cards are the round tile strip', () {
      expect(sections[1].isTileStrip, isFalse);
      expect(sections[2].isTileStrip, isTrue);

      final tile = sections[2].cards.first;
      expect(tile.title, 'Outwear');
      expect(tile.image, '/media/wysiwyg/outwearboy.jpg');
      expect(tile.href, '/eg-en/kidswear/discover/outwear-boy.html');
    });

    test('a description with only copy yields just the one section', () {
      final sections = parseCategoryDescription(_seoBox);

      expect(sections, hasLength(1));
      expect(sections.single.cards, isEmpty);
    });
  });

  group('category description card parts', () {
    final blocks = parseCategoryDescriptionCopy(_currentTemplate);

    test('title and tagline lead the card, above the toggle', () {
      expect(blocks.first.isTitle, isTrue);
      expect(blocks.first.text, "Boys' Clothing on Locafy !!!");
      expect(blocks[1].isTagline, isTrue);
      expect(blocks[1].text,
          'Practical Wear • School • Playtime • Local Egyptian Brands');
    });

    test('the <button> trigger is dropped — the card supplies its own', () {
      expect(blocks.map((b) => b.text), isNot(contains('Read More')));
    });

    test('an inline link keeps its place in the sentence and its href', () {
      final paragraph = blocks.firstWhere((b) => b.text.contains('kidswear'));

      expect(paragraph.text,
          'Each piece is designed for school days. You can also browse all kidswear categories to build a complete wardrobe.');
      final link = paragraph.spans.firstWhere((s) => s.href != null);
      expect(link.text, 'kidswear categories');
      expect(link.href, '/eg-en/kidswear.html');
    });

    test('a paragraph that is one boxed link becomes the callout', () {
      final callout = blocks.firstWhere((b) => b.isCallout);

      expect(callout.text, 'Learn more about selling on Locafy');
      expect(callout.spans.single.href, '/eg-en/why-sell-on-locafy-en');
      // A plain inline link must NOT be promoted to a callout.
      expect(blocks.where((b) => b.isCallout), hasLength(1));
    });

    test('the FAQ group keeps its rule, and questions stay bold', () {
      final dividerAt = blocks.indexWhere((b) => b.isDivider);
      expect(dividerAt, greaterThan(0));

      final question = blocks[dividerAt + 1];
      expect(question.isQuestion, isTrue);
      expect(question.text, "Can I return boys' clothing if it does not fit?");
      // The answer under it is ordinary body copy.
      expect(blocks[dividerAt + 2].isQuestion, isFalse);
    });
  });

  group('category description parsing', () {
    test('an L3 description starts at the SEO box, not the tile grid', () {
      final blocks = parseCategoryDescriptionCopy(_l3TileGridThenSeoBox);

      // The tile labels are the subcategory strip the page already shows; as
      // paragraphs they would read as a stray list of shouty one-word lines.
      expect(blocks.map((b) => b.text), isNot(contains('PANTS')));
      expect(blocks.map((b) => b.text), isNot(contains('SHIRTS & T-SHIRTS')));

      expect(blocks.first.isTitle, isTrue);
      expect(blocks.first.text, 'Menswear Clothing on Locafy');
      expect(blocks.last.text,
          'Locafy brings together everyday menswear from trusted Egyptian brands.');
    });

    test('digs the prose out of the escaped PageBuilder wrapper', () {
      final blocks = parseCategoryDescriptionCopy(_seoBox);

      expect(blocks, isNotEmpty);
      expect(blocks.first.isTitle, isTrue);
      // Entities are escaped twice over (&amp; inside escaped markup); the
      // heading must read as prose, not as "Jackets &amp; Coats".
      expect(blocks.first.text, 'Jackets & Coats for Every Occasion');

      final paragraphs = blocks.where((b) => !b.isTitle && !b.isHeading && !b.isTagline).toList();
      expect(paragraphs.first.text,
          startsWith('Locafy’s Jackets & Coats line will help you'));
      // An <a> inside a paragraph keeps its label inline rather than dropping
      // the sentence or leaking the href.
      expect(paragraphs.last.text,
          'Want to know more? Browse our FAQs to see how easy it is to shop or sell with us.');

      expect(blocks.any((b) => b.isHeading), isTrue);
    });

    test('drops the JS-driven read-more trigger and the script behind it', () {
      final texts = parseCategoryDescriptionCopy(_seoBox).map((b) => b.text);

      // The trigger is a <div> the app replaces with its own expander, and the
      // <script> would otherwise render as a wall of code.
      expect(texts, isNot(contains('Read More')));
      expect(texts.any((t) => t.contains('addEventListener')), isFalse);
    });

    test('a banner-only description renders nothing rather than raw CSS', () {
      // The whole widget hides on an empty result, which is what should happen
      // on the L1/L2 nodes that carry a banner instead of copy.
      expect(parseCategoryDescriptionCopy(_bannerOnly), isEmpty);
    });

    test('plain HTML with no PageBuilder wrapper still parses', () {
      final blocks = parseCategoryDescriptionCopy(
          '<h2>Sneakers</h2><p>Shop local Egyptian brands.</p>');

      expect(blocks.map((b) => b.text).toList(),
          ['Sneakers', 'Shop local Egyptian brands.']);
    });

    test('an empty or broken description is not an error', () {
      expect(parseCategoryDescriptionCopy(''), isEmpty);
      expect(parseCategoryDescriptionCopy('   '), isEmpty);
      expect(parseCategoryDescriptionCopy('<p></p><div></div>'), isEmpty);
    });
  });
}
