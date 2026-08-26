class StickyBannerConfig {
  const StickyBannerConfig({
    this.enable = false,
    this.data,
  });

  final bool enable;
  final dynamic data;

  factory StickyBannerConfig.fromJson(Map<String, dynamic> json) =>
      StickyBannerConfig(
        enable: json['enable'] ?? false,
        data: json['data'] ?? {},
      );

  Map<String, dynamic> toJson() => {
        'enable': enable,
        'data': data,
      };
}
