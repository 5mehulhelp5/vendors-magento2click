part of '../constants.dart';

/// Filter value
// 100 EGP was too low a ceiling for this store's actual price range
// (products run ~500-2000+ EGP), which made the price slider re-enabled
// for ClickUp 86d3g3mea unable to reach any real product price.
const kMaxPriceFilter = 10000.0;
const kFilterDivision = 100;
