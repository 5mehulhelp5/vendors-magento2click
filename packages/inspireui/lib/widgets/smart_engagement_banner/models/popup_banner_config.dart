class PopupBannerConfig {
  final bool enable;
  final dynamic data;
  final bool alwaysShowUponOpen;
  final String? closePosition;
  final int updatedTime;

  const PopupBannerConfig({
    this.enable = false,
    this.data,
    this.alwaysShowUponOpen = true,
    this.closePosition = 'topRight',
    this.updatedTime = 0,
  });

  factory PopupBannerConfig.fromJson(Map<String, dynamic> json) =>
      PopupBannerConfig(
        enable: json['enable'] ?? false,
        data: json['data'] ?? {},
        alwaysShowUponOpen: json['alwaysShowUponOpen'] ?? true,
        closePosition: json['closePosition'] ?? 'topRight',
        updatedTime: json['updatedTime'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'enable': enable,
        'data': data,
        'alwaysShowUponOpen': alwaysShowUponOpen,
        'closePosition': closePosition,
        'updatedTime': 0,
      };
}
