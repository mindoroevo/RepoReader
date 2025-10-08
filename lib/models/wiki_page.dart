/// Repräsentiert einen gefundenen Wiki-Link (ursprünglich Sidebar-Konzept).
/// [title] ist der angezeigte Text, [path] der normalisierte Dateiname.
class WikiPageLink {
  final String title;
  final String path; // Dateiname, z.B. "Meine-Seite.md"
  WikiPageLink({required this.title, required this.path});
}
