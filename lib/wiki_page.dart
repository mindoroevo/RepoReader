/// WikiPageLink (Legacy)
/// ====================
/// Repräsentiert einen gefundenen Wiki-Link (ursprünglich Sidebar-Konzept).
/// Hinweis: Dupliziert auch in `models/wiki_page.dart` – zukünftige Zusammenführung empfohlen.
/// [title] ist der angezeigte Text, [path] der normalisierte Dateiname.
class WikiPageLink {
  final String title;
  final String path; // Dateiname, z.B. "Meine-Seite.md"
  WikiPageLink({required this.title, required this.path});
}
