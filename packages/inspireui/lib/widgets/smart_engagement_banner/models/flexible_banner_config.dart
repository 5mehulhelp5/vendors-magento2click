class FlexibleBannerConfig {
  const FlexibleBannerConfig({
    this.enable = false,
    this.data,
    this.canDrag = true,
    this.canClose = true,
    this.width = 100,
    this.height = 100,
  });

  final bool enable;
  final dynamic data;
  final bool canDrag;
  final bool canClose;
  final num width;
  final num height;

  factory FlexibleBannerConfig.fromJson(Map<String, dynamic> json) =>
      FlexibleBannerConfig(
        enable: json['enable'] ?? false,
        data: json['data'] ?? {},
        canDrag: json['canDrag'] ?? true,
        canClose: json['canClose'] ?? true,
        width: json['width'] ?? 100.0,
        height: json['height'] ?? 100.0,
      );

  Map<String, dynamic> toJson() => {
        'enable': enable,
        'data': data,
        'canDrag': canDrag,
        'canClose': canClose,
        'width': width,
        'height': height,
      };
}
