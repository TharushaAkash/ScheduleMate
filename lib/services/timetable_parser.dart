import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import '../models/timetable_entry.dart';

/// Parses a full-faculty timetable HTML export into [TimetableEntry] objects.
///
/// ASSUMPTION (adjust to match your actual file):
/// The parser expects one or more HTML <table> elements where the FIRST row
/// is a header row containing column names such as:
///   Semester | Group | Sub Group | Day | Start Time | End Time | Module Code |
///   Module Name | Venue | Lecturer
/// Column order does not matter and matching is case-insensitive / tolerant
/// of extra whitespace, because header text is matched by keyword.
///
/// If your university's exported HTML instead uses a day-by-time GRID layout
/// (columns = weekdays, rows = time slots, cells = module code), see
/// `_parseGridFallback` below and adapt the cell-selectors to your file -
/// open the HTML in a text editor first and look at the actual tag/class
/// names, then update the `querySelector` calls accordingly.
class TimetableParser {
  static const _dayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  /// Returns the parsed entries. The UI/Provider will handle combinations.
  static ParsedTimetable parse(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final tables = document.querySelectorAll('table');

    List<TimetableEntry> entries = [];

    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      if (rows.isEmpty) continue;

      List<String> headerCells = [];
      int headerRowIndex = 0;
      for (int i = 0; i < rows.length && i < 10; i++) {
        final cells = rows[i].querySelectorAll('th, td');
        if (cells.length > 4) {
          headerCells = cells.map((e) => e.text.trim().toLowerCase()).toList();
          headerRowIndex = i;
          break;
        }
      }
      
      if (headerCells.isEmpty) continue;

      // Only treat this table as a "flat" data table if we can find a
      // recognisable header row. Otherwise skip (could be a layout table).
      final colIndex = _mapHeaderColumns(headerCells);
      if (colIndex == null) continue;

      for (final row in rows.skip(headerRowIndex + 1)) {
        final cells = row.querySelectorAll('th, td');
        if (cells.length < 4) continue;
        entries.add(_rowToEntry(cells, colIndex));
      }
    }

    // Fallback: nothing matched a flat table -> try the grid heuristic.
    if (entries.isEmpty) {
      entries = _parseGridFallback(document);
    }

    return ParsedTimetable(entries: entries);
  }

  /// Maps required fields to the column index they appear in, based on
  /// keyword matching against the header row text.
  static Map<String, int>? _mapHeaderColumns(List<String> headers) {
    int? find(List<String> keywords, {bool excludeSub = false}) {
      for (int i = 0; i < headers.length; i++) {
        for (final k in keywords) {
          if (headers[i].contains(k)) {
            if (excludeSub && (headers[i].contains('sub') || headers[i].contains('sub-'))) {
              continue;
            }
            return i;
          }
        }
      }
      return null;
    }

    final map = {
      'semester': find(['semester', 'year']),
      'group': find(['group'], excludeSub: true),
      'subgroup': find(['sub group', 'subgroup', 'sub-group']),
      'day': find(['day']),
      'start': find(['start', 'from', 'time']),
      'end': find(['end', 'to']),
      'code': find(['code']),
      'name': find(['module', 'subject', 'course']),
      'venue': find(['venue', 'room', 'hall']),
      'lecturer': find(['lecturer', 'staff', 'instructor']),
    };

    // Minimum viable columns to consider this a valid data table.
    if (map['day'] == null || map['start'] == null || map['name'] == null) {
      return null;
    }
    return map.map((k, v) => MapEntry(k, v ?? -1));
  }

  static TimetableEntry _rowToEntry(
      List<Element> cells, Map<String, int> col) {
    String text(int idx) =>
        (idx >= 0 && idx < cells.length) ? cells[idx].text.trim() : '';

    String startText = col['start']! >= 0 ? text(col['start']!) : '';
    String endText = col['end']! >= 0 ? text(col['end']!) : '';

    // If there's only a single 'Time' column like "08:30 - 10:30"
    if (endText.isEmpty && startText.contains('-')) {
      final parts = startText.split('-');
      startText = parts[0].trim();
      endText = parts[1].trim();
    } else if (endText.isEmpty && startText.contains('to')) {
      final parts = startText.split('to');
      startText = parts[0].trim();
      endText = parts[1].trim();
    }

    String semester = col['semester']! >= 0 ? text(col['semester']!) : '';
    String group = col['group']! >= 0 ? text(col['group']!) : '';
    String subGroup = col['subgroup']! >= 0 ? text(col['subgroup']!) : '';

    return TimetableEntry(
      semester: semester.isEmpty ? 'Default Semester' : semester,
      group: group.isEmpty ? 'Default Group' : group,
      subGroup: subGroup.isEmpty ? 'Default SubGroup' : subGroup,
      day: _normaliseDay(col['day']! >= 0 ? text(col['day']!) : ''),
      startTime: _normaliseTime(startText),
      endTime: _normaliseTime(endText),
      moduleCode: text(col['code']!),
      moduleName: text(col['name']!),
      venue: text(col['venue']!),
      lecturer: text(col['lecturer']!),
    );
  }

  static String _normaliseDay(String raw) {
    final lower = raw.toLowerCase();
    for (final d in _dayNames) {
      if (lower.startsWith(d.substring(0, 3))) {
        return d[0].toUpperCase() + d.substring(1);
      }
    }
    return raw;
  }

  /// Accepts "8.30", "08:30", "8:30 AM" etc. and returns "HH:mm" (24h).
  static String _normaliseTime(String raw) {
    final cleaned = raw.replaceAll('.', ':').trim();
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?')
        .firstMatch(cleaned);
    if (match == null) return raw;
    int hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final meridiem = match.group(3)?.toUpperCase();
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  static List<TimetableEntry> _parseGridFallback(Document document) {
    final entries = <TimetableEntry>[];
    final tables = document.querySelectorAll('table');

    for (final table in tables) {
      final caption = table.querySelector('caption');
      String group = 'Default Group';
      String semester = 'Default Semester';
      if (caption != null) {
        final nameSpan = caption.querySelector('.name');
        if (nameSpan != null) {
          group = nameSpan.text.trim();
          final parts = group.split('.');
          if (parts.length >= 2) {
            semester = '${parts[0]}.${parts[1]}';
          } else {
            semester = group;
          }
        }
      }

      final headerRow = table.querySelector('thead tr') ?? table.querySelector('tr');
      if (headerRow == null) continue;
      final headerCells =
          headerRow.querySelectorAll('th, td').map((e) => e.text.trim()).toList();

      final dayColumns = <int, String>{};
      for (int i = 0; i < headerCells.length; i++) {
        final lower = headerCells[i].toLowerCase();
        for (final d in _dayNames) {
          if (lower.contains(d.substring(0, 3))) {
            dayColumns[i] = d[0].toUpperCase() + d.substring(1);
          }
        }
      }
      if (dayColumns.isEmpty) continue;

      final tbody = table.querySelector('tbody');
      final Iterable<Element> rows;
      if (tbody != null) {
        rows = tbody.children.where((e) => e.localName == 'tr');
      } else {
        rows = table.children.where((e) => e.localName == 'tr').skip(1);
      }
      
      final activeRowspans = <int, int>{};
      for (final k in dayColumns.keys) {
        activeRowspans[k] = 0;
      }
      
      for (final row in rows) {
        if (row.classes.contains('foot')) continue;

        final rowChildren = row.children.where((e) => e.localName == 'th' || e.localName == 'td').toList();
        if (rowChildren.isEmpty) continue;

        final timeRange = rowChildren.first.text.trim();
        final parts = timeRange.split(RegExp(r'-|to'));
        final start = parts.isNotEmpty ? _normaliseTime(parts[0]) : '';
        String end = parts.length > 1 ? _normaliseTime(parts[1]) : '';

        if (end.isEmpty && start.isNotEmpty) {
           try {
             final timeParts = start.split(':');
             int h = int.parse(timeParts[0]);
             int m = int.parse(timeParts[1]);
             h = (h + 1) % 24;
             end = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
           } catch(_) {}
        }

        int cellIdx = 1; // start after time column
        final sortedCols = dayColumns.keys.toList()..sort();
        
        for (final colIdx in sortedCols) {
           if ((activeRowspans[colIdx] ?? 0) > 0) {
             activeRowspans[colIdx] = activeRowspans[colIdx]! - 1;
             continue;
           }

           if (cellIdx >= rowChildren.length) break;

           final cell = rowChildren[cellIdx++];
           final rowspanStr = cell.attributes['rowspan'];
           if (rowspanStr != null) {
              activeRowspans[colIdx] = (int.tryParse(rowspanStr) ?? 1) - 1;
           }
           
           final dayName = dayColumns[colIdx]!;
           final detailedTable = cell.querySelector('table.detailed');
           
          if (detailedTable != null) {
            final detailRows = detailedTable.querySelectorAll('tr');
            if (detailRows.isNotEmpty) {
              int numCols = detailRows[0].querySelectorAll('td.detailed').length;
              for (int c = 0; c < numCols; c++) {
                 String getCellText(int rowIdx) {
                   if (rowIdx >= detailRows.length) return '';
                   final tds = detailRows[rowIdx].querySelectorAll('td.detailed');
                   if (c >= tds.length) return '';
                   return tds[c].text.trim();
                 }

                 String subGroup = getCellText(0);
                 if (subGroup.isEmpty) subGroup = group;
                 
                 String moduleContent = getCellText(1);
                 String lecturer = getCellText(2);
                 String venue = getCellText(3);
                 
                 String moduleCode = '';
                 String moduleName = moduleContent;
                 final codeMatch = RegExp(r'^\((.*?)\)\s*(.*)').firstMatch(moduleContent);
                 if (codeMatch != null) {
                   moduleCode = codeMatch.group(1)!;
                   moduleName = codeMatch.group(2)!;
                 }
                 
                 moduleName = moduleName.replaceAllMapped(
                   RegExp(r'([a-z])(Practical|Lecture|Tutorial|Lab)'), 
                   (m) => '${m.group(1)} ${m.group(2)}'
                 );

                 if (moduleName.isEmpty && moduleCode.isEmpty) continue;

                 entries.add(TimetableEntry(
                   semester: semester,
                   group: group,
                   subGroup: subGroup,
                   day: dayName,
                   startTime: start,
                   endTime: end,
                   moduleCode: moduleCode,
                   moduleName: moduleName,
                   venue: venue,
                   lecturer: lecturer,
                 ));
              }
            }
          } else {
             // Handle cells without table.detailed (often lectures spanning multiple groups)
             String html = cell.innerHtml;
             html = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
             html = html.replaceAll(RegExp(r'<span', caseSensitive: false), ' <span');
             
             final tempDoc = html_parser.parse(html);
             final lines = tempDoc.documentElement!.text.trim().split('\n')
                 .map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                 
             if (lines.isEmpty || lines[0] == '-x-' || lines[0] == '---') continue;
             
             String subGroupFound = group;
             int moduleLineIdx = 0;
             if (!lines[0].startsWith('(')) {
               subGroupFound = lines[0]; // e.g. "Y3.S1.WD.AI.01, Y3.S1.WD.SE.01"
               moduleLineIdx = 1;
             }
             
             String moduleContent = lines.length > moduleLineIdx ? lines[moduleLineIdx] : '';
             String lecturer = lines.length > moduleLineIdx + 1 ? lines[moduleLineIdx + 1] : '';
             String venue = lines.length > moduleLineIdx + 2 ? lines[moduleLineIdx + 2] : '';
             
             String moduleCode = '';
             String moduleName = moduleContent;
             final codeMatch = RegExp(r'^\((.*?)\)\s*(.*)').firstMatch(moduleContent);
             if (codeMatch != null) {
               moduleCode = codeMatch.group(1)!;
               moduleName = codeMatch.group(2)!;
             }
             
             moduleName = moduleName.replaceAllMapped(
               RegExp(r'([a-z])(Practical|Lecture|Tutorial|Lab)'), 
               (m) => '${m.group(1)} ${m.group(2)}'
             );

             if (moduleName.isEmpty && moduleCode.isEmpty) continue;

             entries.add(TimetableEntry(
               semester: semester,
               group: group,
               subGroup: subGroupFound,
               day: dayName,
               startTime: start,
               endTime: end,
               moduleCode: moduleCode,
               moduleName: moduleName,
               venue: venue,
               lecturer: lecturer,
             ));
          }
        } // end of colIdx loop
      } // end of rows loop
    }
    return entries;
  }
}

class ParsedTimetable {
  final List<TimetableEntry> entries;

  ParsedTimetable({required this.entries});

  List<TimetableEntry> filter(String semester, String group, String subGroup) {
    return entries.where((e) {
      if (e.semester != semester || e.group != group) return false;
      
      if (e.subGroup == subGroup || e.subGroup == group) return true;
      
      final subGroupsList = e.subGroup.split(RegExp(r',\s*'));
      return subGroupsList.contains(subGroup) || subGroupsList.contains(group);
    }).toList();
  }
}
