import 'flexible_banner_config.dart';
import 'popup_banner_config.dart';
import 'sticky_banner_config.dart';

class SmartEngagementBannerConfig {
  final PopupBannerConfig popup;
  final FlexibleBannerConfig flexible;
  final StickyBannerConfig sticky;

  SmartEngagementBannerConfig({
    this.popup = const PopupBannerConfig(),
    this.flexible = const FlexibleBannerConfig(),
    this.sticky = const StickyBannerConfig(),
  });

  factory SmartEngagementBannerConfig.fromJson(Map<String, dynamic> json) =>
      SmartEngagementBannerConfig(
        popup: PopupBannerConfig.fromJson(json['popup'] ?? {}),
        flexible: FlexibleBannerConfig.fromJson(json['flexible'] ?? {}),
        sticky: StickyBannerConfig.fromJson(json['sticky'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'popup': popup.toJson(),
        'flexible': flexible.toJson(),
        'sticky': sticky.toJson(),
      };
}
