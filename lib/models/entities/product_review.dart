class ProductReview {
  int? id;
  String? title;
  String? detail;
  String? nickname;
  List<Ratings>? ratings;
  String? reviewEntity;
  int? reviewType;
  int? reviewStatus;
  String? createdAt;
  int? entityPkValue;
  int? storeId;
  List<int>? stores;

  ProductReview({
    this.id,
    this.title,
    this.detail,
    this.nickname,
    this.ratings,
    this.reviewEntity,
    this.reviewType,
    this.reviewStatus,
    this.createdAt,
    this.entityPkValue,
    this.storeId,
    this.stores,
  });

  ProductReview.fromJson(Map<String, dynamic> json) {
    id = json['id'] as int?;
    title = json['title'] as String?;
    detail = json['detail'] as String?;
    nickname = json['nickname'] as String?;
    ratings = (json['ratings'] as List?)
        ?.map((dynamic e) => Ratings.fromJson(e as Map<String, dynamic>))
        .toList();
    reviewEntity = json['review_entity'] as String?;
    reviewType = json['review_type'] as int?;
    reviewStatus = json['review_status'] as int?;
    createdAt = json['created_at'] as String?;
    entityPkValue = json['entity_pk_value'] as int?;
    storeId = json['store_id'] as int?;
    stores = (json['stores'] as List?)?.map((dynamic e) => e as int).toList();
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json['id'] = id;
    json['title'] = title;
    json['detail'] = detail;
    json['nickname'] = nickname;
    json['ratings'] = ratings?.map((e) => e.toJson()).toList();
    json['review_entity'] = reviewEntity;
    json['review_type'] = reviewType;
    json['review_status'] = reviewStatus;
    json['created_at'] = createdAt;
    json['entity_pk_value'] = entityPkValue;
    json['store_id'] = storeId;
    json['stores'] = stores;
    return json;
  }
}

class Ratings {
  int? voteId;
  int? ratingId;
  String? ratingName;
  int? percent;
  int? value;

  Ratings({
    this.voteId,
    this.ratingId,
    this.ratingName,
    this.percent,
    this.value,
  });

  Ratings.fromJson(Map<String, dynamic> json) {
    voteId = json['vote_id'] as int?;
    ratingId = json['rating_id'] as int?;
    ratingName = json['rating_name'] as String?;
    percent = json['percent'] as int?;
    value = json['value'] as int?;
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json['vote_id'] = voteId;
    json['rating_id'] = ratingId;
    json['rating_name'] = ratingName;
    json['percent'] = percent;
    json['value'] = value;
    return json;
  }
}
