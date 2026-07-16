import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/announcement.dart';

/// Parses a Moodle (CourseWeb) page's HTML into a list of [Announcement]s.
///
/// CourseWeb's "Announcements" are just a Moodle forum, so this mainly
/// targets the forum discussion-list page (mod/forum/view.php) and the
/// single-discussion page (mod/forum/discuss.php). It tries a few known
/// Moodle markup shapes (older Boost table layout, newer card layout) and
/// falls back to a generic heuristic so it keeps working even if CourseWeb's
/// theme changes slightly.
class AnnouncementParser {
  static List<Announcement> parse(String htmlSource, String sourceUrl) {
    final doc = html_parser.parse(htmlSource);
    final courseLabel = _extractCourseLabel(doc);

    final results = <Announcement>[];
    results.addAll(_parseDiscussionTableRows(doc, sourceUrl, courseLabel));
    if (results.isEmpty) {
      results.addAll(_parseDiscussionCardEntries(doc, sourceUrl, courseLabel));
    }
    if (results.isEmpty) {
      results.addAll(_parseSingleForumPost(doc, sourceUrl, courseLabel));
    }
    if (results.isEmpty) {
      results.addAll(_parseGenericAnnouncementBlock(doc, sourceUrl, courseLabel));
    }
    return results;
  }

  static String _extractCourseLabel(Document doc) {
    final pageHeader = doc.querySelector('.page-header-headings h1') ??
        doc.querySelector('#page-header h1') ??
        doc.querySelector('h1');
    return pageHeader?.text.trim() ?? 'CourseWeb';
  }

  static String _clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Older Boost theme: <tr class="discussion ..."> rows in a table.
  static List<Announcement> _parseDiscussionTableRows(
      Document doc, String sourceUrl, String courseLabel) {
    final rows = doc.querySelectorAll('tr.discussion');
    final list = <Announcement>[];
    for (final row in rows) {
      final titleLink = row.querySelector('.topic a') ?? row.querySelector('td a');
      if (titleLink == null) continue;
      final title = _clean(titleLink.text);
      if (title.isEmpty) continue;

      final author = _clean(
          row.querySelector('.author a')?.text ?? row.querySelector('.author')?.text);
      final dateText = _clean(row.querySelector('.lastpost time')?.text ??
          row.querySelector('.lastpost')?.text ??
          row.querySelector('td:last-child')?.text);

      list.add(Announcement(
        title: title,
        snippet: '',
        author: author,
        dateText: dateText,
        sourceUrl: sourceUrl,
        courseLabel: courseLabel,
        importedAt: DateTime.now(),
      ));
    }
    return list;
  }

  /// Newer Moodle 4.x card-style discussion list.
  static List<Announcement> _parseDiscussionCardEntries(
      Document doc, String sourceUrl, String courseLabel) {
    final entries = doc.querySelectorAll(
        '[data-region="discussion-list-item"], .discussion-list-entry, .discussionlistitem');
    final list = <Announcement>[];
    for (final entry in entries) {
      final titleLink = entry.querySelector('.discussion-subject a') ??
          entry.querySelector('a[href*="discuss.php"]');
      if (titleLink == null) continue;
      final title = _clean(titleLink.text);
      if (title.isEmpty) continue;

      final author = _clean(entry.querySelector('.discussion-author a')?.text ??
          entry.querySelector('[data-region="author"]')?.text);
      final dateText = _clean(entry.querySelector('time')?.text ??
          entry.querySelector('.discussion-lastpost')?.text);
      final snippet = _clean(entry.querySelector('.discussion-preview')?.text);

      list.add(Announcement(
        title: title,
        snippet: snippet,
        author: author,
        dateText: dateText,
        sourceUrl: sourceUrl,
        courseLabel: courseLabel,
        importedAt: DateTime.now(),
      ));
    }
    return list;
  }

  /// A single opened post/discussion page (mod/forum/discuss.php).
  static List<Announcement> _parseSingleForumPost(
      Document doc, String sourceUrl, String courseLabel) {
    final posts = doc.querySelectorAll('.forumpost, article.forumpost');
    final list = <Announcement>[];
    for (final post in posts) {
      final title = _clean(post.querySelector('.subject')?.text);
      final author = _clean(post.querySelector('.author a')?.text ??
          post.querySelector('.author')?.text);
      final dateText = _clean(post.querySelector('time')?.text ??
          post.querySelector('.date')?.text);
      final body = _clean(post.querySelector('.posting')?.text ??
          post.querySelector('.no-overflow')?.text);
      if (title.isEmpty && body.isEmpty) continue;

      list.add(Announcement(
        title: title.isEmpty ? 'Announcement' : title,
        snippet: body.length > 300 ? '${body.substring(0, 300)}…' : body,
        author: author,
        dateText: dateText,
        sourceUrl: sourceUrl,
        courseLabel: courseLabel,
        importedAt: DateTime.now(),
      ));
    }
    return list;
  }

  /// Last-resort fallback: look for any heading mentioning "announcement"
  /// and pull nearby links/list items as entries. Also used for a plain
  /// dashboard page that lists items in an unfamiliar layout.
  static List<Announcement> _parseGenericAnnouncementBlock(
      Document doc, String sourceUrl, String courseLabel) {
    final list = <Announcement>[];
    final headings = doc.querySelectorAll('h2, h3, h4, h5, .card-title, .block-title');
    Element? container;
    for (final h in headings) {
      if (h.text.toLowerCase().contains('announcement')) {
        container = h.parent;
        break;
      }
    }
    container ??= doc.body;
    if (container == null) return list;

    final links = container.querySelectorAll('a');
    for (final a in links) {
      final title = _clean(a.text);
      final href = a.attributes['href'] ?? '';
      if (title.isEmpty || title.length < 4) continue;
      if (!href.contains('discuss.php') && !href.contains('forum')) continue;
      list.add(Announcement(
        title: title,
        snippet: '',
        author: '',
        dateText: '',
        sourceUrl: sourceUrl,
        courseLabel: courseLabel,
        importedAt: DateTime.now(),
      ));
    }
    return list;
  }
}
