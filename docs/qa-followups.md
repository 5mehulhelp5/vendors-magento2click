# QA Follow-ups — Locafy Customer App

Blockers found during on-device QA of ClickUp **86d3f2jb6** (branch `claude/clickup-task-rksvlj`).
Both are **pre-existing** (not introduced by the QA-batch code changes) and each blocks further verification.
Device: Redmi (Android 16), staging API `stg.locafy.market`, test account `locafyqatest@gmail.com`.

---

## 0. Strong lead for item 1: `eg-en` REST rejects customer tokens  🔴 Backend

While working ClickUp **86d3g53f8** (checkout page), API probing on staging (2026-07-02) showed:

- `POST /rest/V1/integration/customer/token` (default store) → **works**, and the returned token works
  against `/rest/V1/customers/me`, `/rest/V1/carts/mine`, `/rest/V1/carts/mine/payment-methods` etc.
- The **same token** against the same endpoints under the store-code path the app uses —
  `/rest/eg-en/V1/customers/me`, `/rest/eg-en/V1/carts/mine` — always returns
  `{"message":"Specified request cannot be processed."}`.

The app builds all its REST URLs with the `eg-en` store code, so **every customer-token call the app
makes is failing at the store-view level**, which would fully explain item 1 below (add-to-cart 404 /
quote not found for logged-in customers). Backend should check the `eg-en` store-view webapi
configuration (integration/OAuth consumer availability per website, or a WAF rule scoped to that path).

Also noted while testing checkout parity:
- The website/backend applies **no tax** (`carts/mine/totals` → `tax_amount: 0`); the old in-app 14%
  line came from the app applying raw `taxRates/search` rates locally (now config-gated off).
- Website payment methods for a live quote: `sympl, cashondelivery, online, wallet, fawry_express,
  fawry_cards, fawry_cash` — the app renders the API list unfiltered/unreordered, so it matches.
- Email at checkout is optional on the website. The app now sends a fallback
  `guest<phone-digits>@locafy.market` when the shopper leaves email empty — if the website assigns a
  different default (server-side plugin), share the rule and we'll mirror it exactly.

---

## 1. Add-to-cart fails with backend 404 — checkout fully blocked  🔴 Backend

**Symptom**
Adding any product to the cart as a **logged-in** customer does nothing — the cart stays empty
("سلتك فارغة" / *Your cart is empty*), even though the app shows the "Added to bag" bottom sheet.

**Steps to reproduce**
1. Log in (or register) a customer.
2. Open any product → for a configurable product, select the variant (e.g. Top_size = M, All_color = Black).
3. Tap **Add to cart** or **Buy Now** → tap **Go to the shopping cart**.
4. Cart shows empty.

**Evidence (logcat)**
```
POST https://stg.locafy.market/eg-en/rest/V1/carts/mine/items
E flutter : [ERROR] Unhandled Exception: Not Found
E flutter : #2  CartModelMagento.addProductToCart  (cart_model_magento.dart:260:27)
E flutter : #3  ProductVariantMixin.addToCart       (product_variant_mixin.dart:455:19)
```

**Likely root cause**
`POST /V1/carts/mine/items` returns **404 Not Found** because the customer has **no active quote/cart**.
In Magento, a quote must exist first (create via `POST /V1/carts/mine`, which returns a cart id) before
items can be added. Either the quote isn't being created for (at least newly-registered) accounts on
staging, or the staging quote endpoint is misbehaving.

**Impact**
Checkout is **completely blocked** for logged-in customers. Because no item can enter the cart, none of
the Area F checkout fixes can be exercised or verified on device: *email optional*, *region shows name
(not "SG")*, *14% tax removal*, and *Back-to-Store → clears cart → Home*.

**Suggested actions**
- **Backend (primary):** confirm a quote/cart is created for a fresh customer on staging; verify
  `POST /carts/mine` then `POST /carts/mine/items` succeeds for `locafyqatest@gmail.com`.
- **Frontend (secondary):** ensure the app calls `POST /carts/mine` (create quote) before adding items
  if none exists; and handle the failure — the unhandled exception at `cart_model_magento.dart:260`
  currently still shows the optimistic "Added to bag" sheet, which misleads the user into thinking the
  add succeeded. Surface the error instead.

---

## 2. Account (حسابي) tab renders blank after opening a section WebView  ✅ Fixed

**Update:** both root causes below are fixed on this branch. The account tab now watches
`UserModel` reactively (rebuilds on login/logout instead of needing a tab switch), and the
WebView blank-render issue was a `Provider.of(context, listen: true)` call from `initState()`
(forbidden by Flutter, silently swallowed by this app's global `ErrorWidget.builder`, which
rendered auth-gated WebViews — including the Magento account pages — as an empty box). Fixed by
reading the value with `listen: false` instead. Left below for context.

## 2. (historical) Account (حسابي) tab renders blank after opening a section WebView  🟠 Frontend

**Symptom**
The My-Account tab renders a blank white screen after opening an in-app WebView section and backing out.
Switching tabs does **not** recover it; only a full app restart restores the account content.

**Steps to reproduce**
1. Log in → open the **حسابي** (Account) tab (shows name + section list correctly).
2. Tap a section that opens an in-app WebView, e.g. **معلومات الحساب** (Account Information).
3. Back out.
4. Account tab is now blank. Switch Home ↔ Account — still blank.
5. Force-stop + relaunch the app → account tab shows correctly again.

**Likely root cause**
`lib/screens/settings/settings_screen.dart` uses a mutable `items` list to switch between the account
view and a drilled-in section's item list (`items = section.items`). After navigating into a WebView and
popping, the screen appears left in a state that renders nothing (stale/empty `items`, possibly held by
`AutomaticKeepAliveClientMixin`). Reset the `items` state on tab focus / when returning to the tab.

**Related (same area)**
The in-app **auth WebViews** for the Magento account pages (`/my-account`, Stored Payment Methods,
Newsletter, etc.) render **blank even when authenticated** — the page never displays in the WebView
(guest *or* logged-in). The Area D navigation fix correctly *opens* these pages; the *rendering* is a
separate in-app-WebView issue (session/cookie passing, JS, or a redirect-to-login that renders empty).

**Impact**
Confusing UX (account screen looks empty / requires restart); the WebView-backed account pages show no
content in-app.

**Suggested actions**
- Reset `settings_screen.dart` `items` state when the tab regains focus.
- Investigate why the Magento account pages don't render inside the in-app WebView (verify the auth
  cookie/session is passed and the page isn't silently redirecting to a blank login).

---

*Not a blocker, but noted:* `PlatformException: Failed to load FirebaseOptions from resource … values.xml`
appears on startup — Firebase isn't configured in this build (push/Firebase features off until
`google-services` values are added). App runs fine otherwise.

---

## 3. No Brand / Color / Size / etc. filters on category pages  ✅ Built (needs on-device pass)

**Update (built):** implemented on this branch as the GraphQL-aggregations + REST-filtering hybrid
described below. The listing page now fetches the current category's layered-navigation attributes
from storefront GraphQL `aggregations` (`MagentoService.fetchCategoryFilters`, store `eg_en`/`eg_ar`)
and renders each — Brand, Colour, Size, Gender, Material, Pattern, Sleeve length, Style, Product Type,
Fulfillment Method — as a collapsible multi-select section in the filter panel
(`BackdropMenu.renderCategoryAttributeFilters`), with live option counts. Selections are held in a new
global `CategoryFilterModel` (keyed `attribute_code` → option ids, reset per category) and applied to
the existing REST `mstore/products` list as extra `searchCriteria[filter_groups]` (index ≥ 6): one
group per attribute (cross-attribute **AND**), values comma-joined with `condition_type=in`
(within-attribute **OR**) — the same mechanism `brand`/`category_id` already use, so prices/paging stay
on REST. Active selections show as removable chips in the listing toolbar. Verified the option-id
semantics against GraphQL for category 291 (Navy=766→2, Navy∨Red→4, Brand Dress-on→7, Navy∧Dress-on→2,
all matching aggregation counts). **Still needs one on-device pass** to confirm the custom
`mstore/products` REST endpoint honours the attribute `filter_groups` (strongly expected — `brand`,
an EAV attribute filtered by the same option-id shape, already works there). The original analysis is
kept below for context.

**Context:** ClickUp **86d3g3mea** and **86d3g43qr** ask for the category-page filter list to match
the website's. Category and Price filters already work in the app. The rest (Brand, Colors, and at
deeper category levels also Gender, Size, Material, Style, Product Type) do not.

**Update:** this was previously logged as blocked on the backend (REST has no attribute/aggregation
endpoint — confirmed, `Services().api.getFilterAttributes()`/`getSubAttributes()` are unimplemented
stubs, and guessed REST endpoints 404). That is still true for REST, **but the storefront's GraphQL
endpoint already exposes everything needed**:

```
POST https://stg.locafy.market/graphql
{ products(filter: {category_id: {eq: "291"}}, pageSize: 1) {
    aggregations { attribute_code label count options { label value count } }
} }
```

For category 291 ("Jacket & Coats") this returns aggregations for `price`, `category_id`,
`fulfillment_method`, `gender`, `jacket_coats_producttype` (Product Type), `brand`, `women_style` /
`men_fit_type` (Style), `top_size` (size), `material`, and `all_color` (Color) — i.e. essentially
the exact filter panel shown on the website for that category. This is standard Magento 2
layered-navigation-via-GraphQL and is available today on staging; it was just never checked because
the app only talks to the REST API.

**Why this isn't a quick fix:** the app has no GraphQL client at all today (all product data comes
from REST `mstore/products`). Properly implementing this means:
- Adding a GraphQL call (e.g. via `http`/`graphql_flutter`) to fetch `aggregations` for the current
  category, to populate the filter UI (counts and available options).
- Deciding how the *selected* filters get applied to product results: either (a) also filter the
  product list via GraphQL, or (b) keep listing products via the existing REST endpoint and apply
  selected attribute values as extra REST `filter_groups` (each attribute code as its own filter,
  the way `category_id`/`price` already work) — avoiding a full migration off REST.
- Wiring the existing `FilterAttributeModel`/`FilterAttribute`/`SubAttribute` UI
  (`lib/widgets/backdrop/backdrop_menu.dart`'s `renderAttributes()`) to real data instead of the
  no-op stub, including multi-select state per attribute.

**Suggested actions**
- **Frontend:** scope and build the GraphQL-aggregations + REST-filtering hybrid described above.
  This is a real feature (new API integration + UI wiring), not a bug fix — size it as its own task.

---

## 4. No discount badge / before-price for configurable products — parent `price` attribute is unreliable  🟡 Partially fixed

**Context:** ClickUp **86d3g4mna** asks product grid cards to show Brand, discount %, and
before/after price (matching the website). Brand is now shown (resolved from the `brand` custom
attribute via a new `MagentoService.getBrandLabels()` cache). The discount badge and before/after
price logic was also fixed — `parseProductFromJson()` used to hard-code `onSale = false` for every
**configurable** product (the common case: anything with size/color options), discarding the
correctly-computed special_price/date-range discount detection. That's fixed.

**Remaining gap:** even with that fixed, configurable products in this store's REST data have their
parent-level `price` attribute left at **0** — the real regular price only exists on the *child* SKUs
(confirmed via GraphQL: `products(filter:{sku:{eq:"..."}}) { price_range { minimum_price {
regular_price { value } } } }` returns 1300 for a product whose REST parent `price` is 0). Since the
REST `mstore/products` response has no reliable "regular price" for configurables, this branch was
made defensive: it only shows a discount (badge + strikethrough) when the parent's raw `price` is
actually greater than the discounted price. When it isn't (the common case here), the product just
shows its plain current price — correct, but doesn't satisfy the "before/after price" requirement
for these items.

**Suggested actions**
- **Backend:** either populate the configurable parent's `price` attribute with a real regular price
  in Magento, or expose the indexed regular price (the same one GraphQL's `price_range` already
  computes) via a REST custom attribute so the app doesn't need it duplicated per child SKU.
- **Frontend (if backend can't change):** fetch the true regular price via GraphQL alongside the
  REST product list (adds a second API call per listing) — a heavier alternative, same shape as the
  filter-list gap in item 3 above.

---

## 5. `custom_attributes.minimal_price`/`special_price` from `mstore/products` disagree with the standard Magento price index — deepens item 4  🔴 Backend

**Context:** ClickUp **86d3f2jb6** category price-filter QA. The price range filter itself was a
**frontend bug and is now fixed** (see below) — this item is a **separate, backend-side data
problem** uncovered while verifying that fix on-device.

**The frontend fix (already done, for context):** `MagentoService.fetchProductsByCategory()` used
to put `minPrice` in the same `searchCriteria[filter_groups]` index as `category_id`. Magento OR's
filters within one group, so the query was effectively `(category_id=X OR price>=minPrice) AND
price<=maxPrice`, letting any category item through regardless of price. Fixed by isolating
`minPrice` into its own `filter_groups[5]`. Verified on-device: an exact-count cross-check against
independently-fetched GraphQL `regular_price` data for a whole category matched (55/55, 31/31 across
two separate ranges) — filtering by the raw `price` attribute now works correctly.

**The backend-side issue this surfaced:** the price filter above deliberately targets the raw
`price` EAV attribute (the regular/pre-discount price) — that part is correct and matches what
`searchCriteria` can filter on. But the price **shown to the customer** on the same product card is
computed entirely differently: `parseProductFromJson()` (`lib/frameworks/magento/services/
magento_service.dart:64-167`) overwrites the display price with `custom_attributes.minimal_price` or
`special_price` whenever present, verbatim, with **no arithmetic** applied client-side (confirmed by
re-reading the exact assignment — `product.price = minimalPrice;`, a raw string passthrough). So
whatever number the backend puts in `minimal_price`/`special_price` is exactly what the customer
sees. Comparing that against the storefront's own GraphQL `price_range` for the same SKUs shows the
two disagree, and not by a single consistent factor:

| Product (SKU) | GraphQL `regular_price` | GraphQL `final_price` | REST `mstore/products` display price | Notes |
|---|---|---|---|---|
| Boy Basic Polo Shirt (`dresson-store_200725_46`) | 240 | 168 | **152.88** | = 168 × 0.91 exactly |
| Unisex Winter WaterProof Jacket (cheapest child, e.g. `dresson-store_170925_73`) | 1000 | 700 | **637.00** | = 700 × 0.91 exactly |
| Pack Of 2 Plain Boxers For Boys (`futurefit-store_100925_345/338/324`) | 190 | 161.5 | **178.50** | matches neither 161.5 nor 161.5×0.91 (146.97) nor 190 — a third, unexplained value |

A third data source, the storefront's MageWorx search-autocomplete widget
(`GET /eg-en/mageworx_searchsuiteautocomplete/ajax/index/?q=...`, a separate Magento module,
unrelated to `mstore`), reports `data-price-amount="161.5"` for the same boxers SKU — i.e. it agrees
with GraphQL/the standard price index, not with `mstore/products`. So two independent, standard
Magento-driven surfaces (GraphQL and the MageWorx module) agree with each other; only the custom
`mstore` REST extension's `minimal_price`/`special_price` values disagree, and the size/direction of
the disagreement isn't a fixed formula (a flat 9% extra discount fits two of the three examples
exactly, but not the third) — pointing to **stale or inconsistently-recomputed values in the Mstore
extension's own price resolution**, not a customer-group rule or currency conversion (both were
checked and ruled out client-side — see below).

**Ruled out (verified, not just assumed):**
- **Currency conversion:** the app does have a live multiplicative price path
  (`PriceTools.getPriceValueByCurrency`, `lib/common/tools/price_tools.dart:190-199`, driven by
  `GET rest/V1/directory/currency`) and the grid card does route through it for this Magento config.
  But the live endpoint currently returns `rate: 1` for EGP→EGP, making it a no-op today. Worth
  re-checking if this is ever seen on an account with a non-EGP currency selected.
- **Client-side bug:** every other assignment to `product.price` in the codebase was traced (grep,
  whole repo) — `minimal_price`/`special_price` passthrough is the only write site relevant here, and
  it's unconditional/verbatim. Not a formatting, rounding, or caching artifact.

**Impact:** customers can see a price on a product card that a price-range filter (correctly, per
its own field) would have excluded, and the storefront's own other widgets (MageWorx autocomplete)
can show a different price for the same SKU than the app does. This is the same root-cause class as
item 4 (REST `mstore` data disagreeing with the standard Magento price index) but a distinct, deeper
data point: it's not just the base `price` attribute that's unreliable for configurables — the
*discount* custom attributes (`minimal_price`/`special_price`) the app already trusts for badges and
strikethrough pricing can themselves be stale or wrong, for simple products too.

**Suggested actions**
- **Backend (primary):** audit the Mstore extension's price-resolution code for `minimal_price`/
  `special_price` — check whether it reads from the live `catalog_product_index_price` table (the
  same index GraphQL/MageWorx read) or recomputes independently; check reindex status/mode
  (`bin/magento indexer:status`) for the price indexer on staging; spot-check the three SKUs above
  directly in the database against what `mstore/products` currently returns for them.
- **Backend/Frontend:** once the extension is fixed, no app change should be needed — the app already
  treats `minimal_price`/`special_price` as trustworthy; the bug is in what those attributes contain,
  not how the app consumes them.

**Full price-related API surface (for backend, so a fix doesn't break something else):** this app
talks to Magento REST/AJAX only — **no GraphQL client exists in the app**, despite GraphQL being used
above purely as an external verification tool. There are five independent price code paths, each
hitting a different endpoint/field — a fix to one doesn't automatically cover the others:
1. **Product listing/detail** — `GET mstore/products...` / `GET products/$id` → `price`,
  `custom_attributes.special_price`, `.minimal_price`, `.special_from_date`, `.special_to_date`
  (`magento_service.dart:55-170`, item 4 + item 5 above).
2. **Configurable variation options** — `GET configurable-products/{sku}/children` → child SKU's own
  `price`/`special_price`/date fields (`product_variation.dart:182-260`). Note: a separate,
  pre-existing app-side bug was found here (not a backend issue) — the variation's own computed price
  gets overwritten by the parent product's price one line after being set
  (`magento_service.dart:832`), while its `regularPrice`/`onSale` stay child-derived. Flagged
  separately for a frontend fix; backend doesn't need to do anything about it.
3. **Cart line items** — `GET carts/mine/items` → `price`, `minimal_price` only (no `special_price`
  or date-range fields at all) (`Product.fromShopJson`, `lib/models/entities/product.dart:1606-1631`).
4. **Order line items** — `GET orders/...` → `base_row_total` (a completely different field name,
  order-history/detail only) (`lib/models/order/product_item.dart:218-228`).
5. **Live search autocomplete** — `GET mageworx_searchsuiteautocomplete/ajax/index/?q=...` → an
  **HTML fragment** that the app regex/CSS-selector scrapes for a number (not a JSON price field at
  all) (`Product.fromSearchJson`, `lib/models/entities/product.dart:1803-1841`). Any markup change to
  this module's rendered price block breaks this path silently.

---

## 6. Product page can't show the SELLER name — not exposed by any API  ✅ Resolved (backend delivered + app wired)

**Update (resolved):** the backend shipped module `MagentoEgypt_MarketplaceSeller`, which adds
`extension_attributes.seller_id` / `seller_name` / `seller_shop_url` to the product payload via
plugins on `ProductRepository` (`/rest/V1/products/{sku}`) and the mstore product list
(`/rest/V1/mstore/products`). Verified live on production for SKU `dresson-store_200725_46`:
`seller_id: 465`, `seller_name: "Do DRESS ON"`, `seller_shop_url: …/vendor_shop/dresson-store.html`,
on **both** `eg-en` and `eg-ar`. App side is wired in `MagentoService.parseProductFromJson`:
`product.store` is set from `seller_name`/`seller_shop_url` (id left null so the same-store
related-products block stays off), and the existing `StoreName` "Sold by X" widget on the PDP now
renders it. The historical investigation is kept below for context.

---

**Context:** ClickUp **86d3g53dk** (product page) requires the PDP to show the marketplace seller
("Vendor : Do DRESS ON" on the web PDP) like the website. The app-side wiring already exists
(`StoreName` widget renders "Sold by X" the moment `product.store` is populated), but no API on this
install exposes the seller's display name:

- REST product payloads (`products/{sku}`, `mstore/products`) carry **no seller fields** —
  `extension_attributes` = only category_links / configurable_product_links / website_ids;
  `vendor_code` is a free-text "vendor product code" ("241801", "0066", null), not a name.
- GraphQL `ProductInterface` has no seller/vendor field and there are no seller root queries
  (CedCommerce GraphQL add-on not installed).
- Guessed marketplace REST routes all 404: `mstore/vendors`, `marketplace/sellers`,
  `csmarketplace/sellers`, `mpapi/sellers`, `vendors`, `sellers`, …
- The web PDP's "Vendor : Do DRESS ON" block is rendered **server-side** by the CedCommerce
  csmarketplace module; the display name exists only in HTML.
- Only machine-readable hint: the SKU prefix equals the seller *shop slug*
  (`dresson-store_200725_46` → `/eg-en/vendor_shop/dresson-store.html`), but the slug
  ("dresson-store") ≠ display name ("Do DRESS ON"), so deriving a name from it would show wrong
  names — worse than showing nothing.

### Backend requirements (seller name)

**Goal:** the app must be able to read, per product, the marketplace seller's **display name** (and
ideally shop id + shop URL) from an authenticated API the app already uses.

**Preferred option — extend the product payload.** Add these fields to the product REST responses so
no extra round-trip is needed:

- Endpoints that must include them: `GET /rest/V1/products/{sku}`, `GET /rest/V1/mstore/products`,
  and `GET /rest/V1/mstore/products?...` (list). The list endpoint feeds product cards; the single
  endpoint feeds the PDP.
- Shape (under `extension_attributes`):
  ```json
  "extension_attributes": {
    "seller_id": 42,
    "seller_name": "Do DRESS ON",
    "seller_shop_url": "https://stg.locafy.market/eg-en/vendor_shop/dresson-store.html"
  }
  ```
- `seller_name` is **required** and must be the localized display name shown on the web PDP
  ("Vendor : …"), read from the CedCommerce `ced_csmarketplace_vendor*` tables. `seller_id` and
  `seller_shop_url` are optional but useful (enable "visit store" / same-store products later).
- Must work with the app's integration/access token on the `eg-en` and `eg-ar` store scopes, and be
  localized per store view where the seller name differs by language.

**Acceptable alternative — a dedicated endpoint.** `GET /rest/V1/mstore/products/{sku}/seller`
returning `{ "seller_id", "seller_name", "seller_shop_url" }`. Less preferred because it adds one
request per PDP.

**Acceptance criteria**
- For a known product (e.g. SKU `dresson-store_200725_46`) the API returns
  `seller_name = "Do DRESS ON"` (the exact web PDP value), not the shop slug `dresson-store`.
- Field is present for **all** marketplace products; absent/null only for admin-owned products.
- Verified on both `eg-en` and `eg-ar` scopes with the app's bearer token.

**Frontend follow-up (after the field exists):** one line in `parseProductFromJson` to set
`product.store` from `seller_name`/`seller_shop_url`; the existing `StoreName` "Sold by X" UI then
renders with no further changes. No UI work required.

---

## 7. Product reviews can be READ but not SUBMITTED — no write API  ✅ Resolved (backend delivered + app wired)

**Update (resolved):** the backend added a customer-token review write API. The app uses the clean
route `POST /rest/V1/products/{sku}/reviews` (resource `self`, customer derived server-side —
spoof-proof), body `{ "review": { "nickname", "summary", "text", "ratings":[{"rating_id","value_id"}] } }`,
returning `{ review_id, status:"pending", message }`. Rating value ids come from
`GET /rest/V1/mobiconnect/review/ratingoption` (Quality=1 → option values 1–5, Value=2 → 6–10,
Price=3 → 11–15). Verified live on production: the route returns 401 "A customer token is required to
submit a review." without a customer token (route exists + gated), and ratingoption returns the three
rating dimensions. App side: `MagentoService.createReview` maps the star selection to a `value_id` per
rating dimension and POSTs with the customer token; the PDP Reviews section is flipped to
`allowRating: true` (the submit form shows for logged-in users only). Reviews are moderated → a new
review appears after admin approval (the app already messages "pending approval"). Read path is
unchanged (GraphQL). Needs one on-device pass with a real customer login to confirm end-to-end (the
authenticated POST can't be exercised from here). Historical investigation kept below.

---

**Context:** ClickUp **86d3g53dk** adds a "Reviews" section to the PDP. **Reading** reviews now works
via GraphQL (`products(filter:{sku})... reviews { items { nickname summary text average_rating
created_at } }`) and is shipped on this branch as a **read-only** section. **Submitting** a review
from the app has no usable backend path:

- REST review routes do not exist on this build: `GET/POST /rest/V1/products/{sku}/reviews` and
  `/rest/V1/reviews` all 404 with "Request does not match any route" (the Review Web API added in
  Magento 2.4.3 is not enabled here). So the app's `createReview` has nothing to call.
- GraphQL `createProductReview` mutation exists but requires a **customer GraphQL bearer token**; the
  app authenticates against REST and does not currently hold a customer GraphQL token.
- Store config `allow_guests_to_write_product_reviews = 0`, so guests can't post regardless — only
  logged-in customers.

**Backend requirements (review submission) — pick ONE:**

1. **Enable the REST Review Web API** (simplest for the app): expose
   `POST /rest/V1/products/{sku}/reviews` (or the equivalent authenticated customer endpoint)
   accepting `{ nickname, title/summary, detail/text, rating (1–5 or a ratings map) }` under the
   customer's existing REST token. The app's `createReview` maps straight onto this.
2. **OR** confirm and document that the storefront **GraphQL `createProductReview`** is enabled and
   provide the way to obtain a **customer GraphQL token** for a REST-logged-in user (e.g. accept the
   REST customer token, or a `generateCustomerToken` step the app can call). Then the app submits via
   GraphQL. Also confirm the rating scale (GraphQL uses a rating **metadata id + value id**, not a
   raw 1–5 number — the app needs the product's `create_product_review_rating` metadata).

**Also specify (either option):**
- Whether submitted reviews are **auto-approved** or held for moderation (they currently default to
  *Pending* → a customer's own review won't appear immediately; the app should message this).
- The exact **rating scale/format** expected by the write API (1–5 stars vs 0–100 percent vs
  rating-option value ids).

**Acceptance criteria**
- A logged-in customer can POST a review for a given SKU with the app's available credentials and get
  a success response.
- The submitted review is subsequently returned by the GraphQL `reviews` query the app already reads
  (after approval, if moderation is on).

**Frontend follow-up (after a write API exists):** implement `MagentoService.createReview` against
the chosen endpoint and flip the Reviews section from read-only (`allowRating: false`) to allow
submission for logged-in users.

---

*Related fixes shipped on this branch (same ClickUp task, no backend needed):* the variation price
overwrite flagged in item 5 (path 2) is fixed — configurable children keep their own prices, variant
selection resolves the correct child (correct SKU goes to the cart), the PDP price updates on variant
selection, the short description now renders (parse-side fix), and the "Product Details" / "Reviews"
expandable sections were added (attribute metadata via store-scoped REST; reviews via GraphQL,
read-only pending item 7).

---

## 8. Main-category landing page (86d3g36q4) — two backend data gaps  🟡 Backend (app shipped; cosmetic gaps only)

**Context:** Tapping a MAIN category (Kidswear/Menswear/Womenswear/Newborn) now opens a merchandised
landing page (`lib/screens/categories/category_landing_screen.dart`) with four sections — hero
subcategory banners, New Arrival, On Sale, Featured Brands — matching the website's layout intent.

The website renders this page from a **CMS page-builder block** (category 192 `KIDSWEAR` has
`display_mode = PAGE` and `landing_page = 269`; block `main-Kkidswear-en` is ~49 KB of page-builder
HTML/CSS the app cannot render). Inside that block the product sections are **dynamic Magento
product widgets** (category + newest / on-sale conditions) and the banners/brands are **static links**
to subcategories and vendor shops — i.e. there are **no hand-picked SKUs**. So the app reproduces all
four sections app-side from existing REST (`fetchProductsByCategory` newest / on-sale for the
carousels, `mstore/categories` children for the heroes, `mstore/brands` for the brands) and matches
the web. Two backend **data** gaps keep it from being pixel-faithful:

**8a. Subcategory categories return no `image` in `mstore/categories` → hero banners show placeholders.**
Verified on production: `KIDSWEAR` (192) itself has `image: /media/catalog/category/Artboard_11.png`,
but **every child returns `image: null`** — `GIRLS` (269), `BOYS` (270), `Kids (3-12) Years` (194),
`Baby (0-36) Months` (193), `Teens (13-16)` (195), `What's Hot` (442). The website's hero cards use
hand-set category images (the Boys/Girls photos); the app falls back to a placeholder graphic.
- **Backend fix (preferred):** set the category Image (Catalog → Categories → each subcategory →
  Content → Image) for the subcategories that should appear as hero banners. Once populated,
  `mstore/categories` will return the path and the app renders it with no app change.
- **Frontend fallback (if backend can't):** use the subcategory's first product image as the hero —
  less faithful and one extra request per subcategory.

**8b. `mstore/brands` returns only `{label, value}` — no logo → Featured Brands shows text-only cards.**
Verified on production: `GET /eg-en/rest/V1/mstore/brands` returns 121 entries, each exactly
`{"label": "Junior", "value": "893"}` — no logo/image URL. The website's "Featured Brands" row shows
brand/vendor **logos**; the app can only render brand-name cards.
- **Backend fix:** add a `logo` / `image` URL field to each `mstore/brands` entry (the logos already
  exist as vendor-shop images on the web, e.g. `…/vendor_shop/junior-store.html`). The app's Featured
  Brands cards can then show the logo instead of the name.

**8c. (Context, not a blocker) Centralized curation would need a structured endpoint.**
The app currently derives the hero subcategories (all direct children) and featured brands
(from the category tree) generically. If you later want the *exact* web curation controlled
server-side per category (which subcategories are heroes, which brands are "featured", section
order/visibility), the backend would need to expose that as **structured JSON** — the raw
page-builder CMS block (`landing_page`) is not app-renderable. Not required for the current shipped
version; noted only so the option is on record.

**Summary for backend:** (8a) populate subcategory category images; (8b) add a brand logo URL to
`mstore/brands`. Both are data/response-shape changes with no app rework required — the landing page
is already live and will pick them up automatically.

---

## 9. Review image attachments have no backend path — the camera button uploads into the void  🔴 Backend

**Context:** ClickUp **86d3g53dk** item 10 asks: *"The Camera option should open the camera or image
picker and allow the user to attach an image."*

**App side is done and shipped** (`03109f8`): the camera button opens the asset picker, multi-select
up to 5, thumbnails preview inline, images are compressed and base64-encoded by
`ImageTools.compressAndConvertImagesForUploading` and put on the create-review payload as `images`.
Verified on device.

**The blocker:** there is nowhere to send them and nowhere to read them back. `MagentoService.createReview`
deliberately **drops `data['images']`** before the POST rather than sending a field the route would
reject. So the button looks like it works — attach, submit, success — and the image silently
disappears. Nothing in the stack supports review images today:

1. **Write (REST)** — the app posts to the route delivered in item 7,
   `POST /{store}/rest/V1/products/{sku}/reviews`, body
   `{"review":{"nickname","summary","text","ratings":[{"rating_id","value_id"}]}}`. No image field.
2. **Write (GraphQL)** — `CreateProductReviewInput` introspects to exactly:
   `nickname, ratings, sku, summary, text`.
3. **Read (GraphQL)** — `ProductReview`, which is what the app reads, introspects to exactly:
   `average_rating, created_at, nickname, product, ratings_breakdown, summary, text`.
4. **No web behaviour to match** — the storefront `#review-form` has `nickname`, `title`, `detail`
   and the 3 rating groups. `input[type=file]` count: **0**.
5. **Magento core has no concept of review images** — `review`/`review_detail` carry no media
   columns and there is no media path for them. This needs a custom module, not a config toggle.

**Decision needed first — is this worth building?** The website doesn't do it, so shipping it makes
the app *diverge* from web rather than match it, and it opens an abuse vector (customers uploading
arbitrary images to public product pages). If the answer is no, say so and I'll remove the camera
button (~5 min) and we reply to QA that review images aren't supported on this platform.

**If yes, backend requirements:**

*Storage*
- Table e.g. `locafy_review_image` (`value_id`, `review_id` FK → `review.review_id`, `file`, `position`).
- Files under `pub/media/review/…` via the standard media writer, with a resized thumbnail like catalog media.
- Validation: allowed mime (jpg/png/webp), max file size, max count per review (**app caps at 5**).

*Write* — either shape works, just tell me which and I'll wire it:
- **(a) Extend the existing route** (least app work): accept `"images"` inside the `review` object on
  `POST /V1/products/{sku}/reviews`. The app already produces base64 — currently a comma-separated
  string; a JSON array of base64 strings, or multipart, is equally fine.
- **(b) Separate upload endpoint**, e.g. `POST /V1/products/{sku}/reviews/{reviewId}/images`. Note
  this needs the create route to **return the new `review_id`** so the app can chain the upload —
  item 7's response shape (`{review_id, status, message}`) already has it, so this is viable.
- Images must inherit the review's moderation state (pending until the review is approved).

*Read*
- Expose on `ProductReview` in GraphQL, e.g. `images: [ProductReviewImage] { url }`.
- **App-side cost is ~2 lines**: `Review` already carries `List<String> images`, and the review list
  already renders a horizontal thumbnail strip with a fullscreen gallery on tap
  (`lib/screens/detail/widgets/review.dart`). Only `Review.fromMagentoJson` needs to map the new
  field — `Review.fromJson` already parses an `images` list, so copy that.

*Admin*
- Surface the attached images in the review moderation grid/edit view so a human can see them before
  approving. This is the main reason moderation must stay on.

**Acceptance criteria**
- A logged-in customer can submit a review with 1–5 images and get a success response.
- After admin approval, the GraphQL `reviews` query the app already reads returns those image URLs.
- Rejected/pending reviews do not expose their images publicly.

**Interim risk:** the camera button is **live in the current build**. If QA retests before this
lands, they will attach an image, submit successfully, and the image will never appear on the review.
Worth telling them up front so it isn't re-filed as a new bug.
