class BannerImagesModel {
  final String? image1;
  final String? image2;
  final String? image3;
  final String? image4;

  BannerImagesModel({
    this.image1,
    this.image2,
    this.image3,
    this.image4,
  });

  BannerImagesModel.fromJson(Map<String, dynamic> json)
      : image1 = json['image1'] as String?,
        image2 = json['image2'] as String?,
        image3 = json['image3'] as String?,
        image4 = json['image4'] as String?;

  Map<String, dynamic> toJson() =>
      {'image1': image1, 'image2': image2, 'image3': image3, 'image4': image4};
}
