
class SectionItem {
  final String title;
  final String url;

  SectionItem({required this.title, required this.url});
}

class Section {
  final String title;
  final List<SectionItem> items;

  Section({required this.title, required this.items});
}