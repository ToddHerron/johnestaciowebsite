import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';

/// Builds a downloadable HTML report for a dry-run of the Works schema migration.
/// The report includes per-document before/after top-level fields and lightweight
/// previews for details.
class WorksMigrationReporter {
  final CollectionReference<Map<String, dynamic>> _worksCollection;

  WorksMigrationReporter({FirebaseFirestore? firestore})
      : _worksCollection = (firestore ?? FirebaseFirestore.instance).collection('works');

  Future<String> buildReportHtml() async {
    final snapshot = await _worksCollection.get();
    final now = DateTime.now().toUtc().toIso8601String();

    int processed = 0;
    int wouldUpdate = 0;
    int skipped = 0;
    int errors = 0;

    String esc(Object? s) {
      final str = (s ?? '').toString();
      return str
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&#39;');
    }

    String boolChip(bool v) => v ? '<span class="chip ok">true</span>' : '<span class="chip">false</span>';

    final sb = StringBuffer();
    sb.writeln('<!doctype html>');
    sb.writeln('<html lang="en"><head><meta charset="utf-8">');
    sb.writeln('<meta name="viewport" content="width=device-width, initial-scale=1">');
    sb.writeln('<title>Works Migration Dry-run Report</title>');
    sb.writeln('<style>');
    sb.writeln('body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,sans-serif;background:#fff;color:#333;margin:24px;}');
    sb.writeln('h1{font-size:20px;margin:0 0 12px;} h2{font-size:16px;margin:16px 0 8px;} h3{font-size:14px;margin:12px 0 6px;}');
    sb.writeln('.doc{border:1px solid #e3e3e3;border-radius:8px;margin:12px 0;overflow:hidden;}');
    sb.writeln('.hdr{background:#fafafa;border-bottom:1px solid #eaeaea;padding:10px 12px;display:flex;gap:8px;align-items:center;justify-content:space-between;}');
    sb.writeln('.meta{color:#666;font-size:12px;} .summary{background:#fff8e6;border:1px solid #ffe5b4;padding:8px 12px;border-radius:6px;}');
    sb.writeln('.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px;}');
    sb.writeln('.card{background:#fff;border:1px solid #eee;border-radius:6px;padding:10px;}');
    sb.writeln('.chips{display:flex;flex-wrap:wrap;gap:6px;margin:6px 0;}');
    sb.writeln('.chip{display:inline-block;border:1px solid #ccc;border-radius:999px;padding:2px 8px;font-size:12px;color:#555;background:#f7f7f7;} .ok{border-color:#b6e3b6;background:#eaf9ea;color:#1b7f1b;} .warn{border-color:#ffd1a3;background:#fff3e6;color:#a04a00;}');
    sb.writeln('table{border-collapse:collapse;width:100%;font-size:12px;} th,td{border:1px solid #eee;padding:6px;vertical-align:top;} th{background:#fafafa;text-align:left;}');
    sb.writeln('.preview-img{max-width:240px;max-height:180px;border:1px solid #eee;border-radius:4px;}');
    sb.writeln('.muted{color:#888;} .mono{font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;}');
    sb.writeln('</style></head><body>');

    sb.writeln('<h1>Works Migration Dry-run Report</h1>');
    sb.writeln('<div class="meta">Generated at $now (UTC)</div>');

    for (final doc in snapshot.docs) {
      processed++;
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final before = Map<String, dynamic>.from(data);
        final after = <String, dynamic>{}..addAll(before);

        // Defaults for top-level fields
        final hadStatus = after.containsKey('currentStatus') && after['currentStatus'] is String;
        final hadVisible = after.containsKey('isVisible');
        final hadOrder = after['order'] is int;

        if (!hadStatus) after['currentStatus'] = WorkStatus.published.name;
        if (!hadVisible) after['isVisible'] = true;
        if (!hadOrder) after['order'] = processed - 1; // stable fallback by iteration

        // Normalize details + compute flags
        bool hasPdf = false, hasAudio = false, hasEmbed = false, hasLink = false, hasImage = false, hasRequest = false;
        if (after['details'] is List) {
          final details = List<Map<String, dynamic>>.from(
            (after['details'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)),
          );
          for (int di = 0; di < details.length; di++) {
            final norm = _normalizeDetailMapForReport(details[di], index: di);
            details[di] = norm.map;
            switch (norm.typeName) {
              case 'DetailType.pdf': hasPdf = true; break;
              case 'DetailType.audio': hasAudio = true; break;
              case 'DetailType.embed': hasEmbed = true; break;
              case 'DetailType.link': hasLink = true; break;
              case 'DetailType.image': hasImage = true; break;
              case 'DetailType.request': hasRequest = true; break;
            }
          }
          after['details'] = details;
        }
        after['hasPdf'] = hasPdf;
        after['hasAudio'] = hasAudio;
        after['hasEmbed'] = hasEmbed;
        after['hasLink'] = hasLink;
        after['hasImage'] = hasImage;
        after['hasRequest'] = hasRequest;

        // Determine if this document would be updated
        bool changed = false;
        for (final key in <String>['currentStatus','isVisible','order','details','hasPdf','hasAudio','hasEmbed','hasLink','hasImage','hasRequest']) {
          final b = before[key];
          final a = after[key];
          if ('$b' != '$a') { changed = true; break; }
        }
        if (changed) {
          wouldUpdate++;
        } else {
          skipped++;
        }

        // Render doc card
        final title = (before['title'] ?? '[Title Missing]').toString();
        sb.writeln('<div class="doc">');
        sb.writeln('<div class="hdr"><div><strong>${esc(title)}</strong> <span class="muted">#${esc(doc.id)}</span></div>');
        sb.writeln('<div class="chips">');
        sb.writeln('<span class="chip ${changed ? 'warn' : ''}">${changed ? 'Would Update' : 'No Change'}</span>');
        sb.writeln('<span class="chip">order: ${esc(after['order'])}</span>');
        sb.writeln('</div></div>');

        // Before/After top-level
        sb.writeln('<div class="grid">');
        sb.writeln('<div class="card"><h3>Top-level (Before)</h3>');
        sb.writeln('<div class="chips">');
        sb.writeln('<span class="chip">currentStatus: ${esc(before['currentStatus'])}</span>');
        sb.writeln('<span class="chip">isVisible: ${esc(before['isVisible'])}</span>');
        sb.writeln('<span class="chip">order: ${esc(before['order'])}</span>');
        sb.writeln('</div>');
        sb.writeln('<div class="chips">');
        sb.writeln('<span class="chip">hasPdf: ${esc(before['hasPdf'])}</span>');
        sb.writeln('<span class="chip">hasAudio: ${esc(before['hasAudio'])}</span>');
        sb.writeln('<span class="chip">hasEmbed: ${esc(before['hasEmbed'])}</span>');
        sb.writeln('<span class="chip">hasLink: ${esc(before['hasLink'])}</span>');
        sb.writeln('<span class="chip">hasImage: ${esc(before['hasImage'])}</span>');
        sb.writeln('<span class="chip">hasRequest: ${esc(before['hasRequest'])}</span>');
        sb.writeln('</div></div>');

        sb.writeln('<div class="card"><h3>Top-level (After)</h3>');
        sb.writeln('<div class="chips">');
        sb.writeln('<span class="chip">currentStatus: ${esc(after['currentStatus'])}</span>');
        sb.writeln('<span class="chip">isVisible: ${esc(after['isVisible'])}</span>');
        sb.writeln('<span class="chip">order: ${esc(after['order'])}</span>');
        sb.writeln('</div>');
        sb.writeln('<div class="chips">');
        sb.writeln('<span class="chip">hasPdf: ${boolChip(after['hasPdf']==true)}</span>');
        sb.writeln('<span class="chip">hasAudio: ${boolChip(after['hasAudio']==true)}</span>');
        sb.writeln('<span class="chip">hasEmbed: ${boolChip(after['hasEmbed']==true)}</span>');
        sb.writeln('<span class="chip">hasLink: ${boolChip(after['hasLink']==true)}</span>');
        sb.writeln('<span class="chip">hasImage: ${boolChip(after['hasImage']==true)}</span>');
        sb.writeln('<span class="chip">hasRequest: ${boolChip(after['hasRequest']==true)}</span>');
        sb.writeln('</div></div>');
        sb.writeln('</div>');

        // Details table + previews
        final afterDetails = (after['details'] is List)
            ? List<Map<String, dynamic>>.from((after['details'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e as Map)))
            : <Map<String, dynamic>>[];
        sb.writeln('<div class="card"><h3>Details (After)</h3>');
        sb.writeln('<table><thead><tr><th>#</th><th>Type</th><th>Display</th><th>Button</th><th>Text</th><th>Content</th><th>Preview</th></tr></thead><tbody>');
        for (int i = 0; i < afterDetails.length; i++) {
          final d = afterDetails[i];
          final type = d['detailType'];
          final display = d['displayType'];
          final btnStyle = d['buttonStyle'];
          final btnText = d['buttonText'];
          final content = d['content'];
          final storagePath = d['storagePath'];

          // Decide preview
          String preview = '';
          if (type == 'DetailType.image' && content is String && content.startsWith('http')) {
            preview = '<img class="preview-img" src="${esc(content)}" alt="image" />';
          } else if (type == 'DetailType.link' && content is String && (content.startsWith('http://') || content.startsWith('https://'))) {
            preview = '<a class="mono" href="${esc(content)}" target="_blank" rel="noopener">${esc(content)}</a>';
          } else if (type == 'DetailType.pdf' && content is String) {
            preview = '<span class="mono">PDF: ${esc(content)}</span>';
          } else if (type == 'DetailType.audio' && content is List) {
            preview = '<span class="mono">Audio clips: ${content.length}</span>';
          } else if (type == 'DetailType.embed' && content is String) {
            preview = '<span class="mono">Embed code</span>';
          } else if (type == 'DetailType.richText') {
            preview = '<span class="muted">Rich Text</span>';
          } else if (type == 'DetailType.request') {
            preview = '<span class="muted">Request Scores link</span>';
          } else if (storagePath is String && storagePath.isNotEmpty) {
            preview = '<span class="mono">storage: ${esc(storagePath)}</span>';
          }

          sb.writeln('<tr>');
          sb.writeln('<td>${i + 1}</td>');
          sb.writeln('<td>${esc(type)}</td>');
          sb.writeln('<td>${esc(display)}</td>');
          sb.writeln('<td>${esc(btnStyle)}</td>');
          sb.writeln('<td>${esc(btnText)}</td>');
          sb.writeln('<td class="mono">${esc(content)}</td>');
          sb.writeln('<td>$preview</td>');
          sb.writeln('</tr>');
        }
        sb.writeln('</tbody></table></div>');

        sb.writeln('</div>');
      } catch (e) {
        errors++;
      }
    }

    // Summary at top
    sb.writeln('<div class="summary"><strong>Summary</strong><br>Processed: $processed &nbsp; Would Update: $wouldUpdate &nbsp; Unchanged: $skipped &nbsp; Errors: $errors</div>');
    sb.writeln('</body></html>');

    return sb.toString();
  }
}

class _NormalizedDetailResultForReport {
  final Map<String, dynamic> map;
  final bool changed;
  final String typeName;
  _NormalizedDetailResultForReport({required this.map, required this.changed, required this.typeName});
}

_NormalizedDetailResultForReport _normalizeDetailMapForReport(Map<String, dynamic> d, {required int index}) {
  bool changed = false;
  final out = Map<String, dynamic>.from(d);

  // id
  final idValue = out['id'];
  if (idValue == null || (idValue is String && idValue.isEmpty)) {
    out['id'] = FirebaseFirestore.instance.collection('tmp').doc().id;
    changed = true;
  }

  // order
  if (out['order'] == null || out['order'] is! int) {
    out['order'] = index;
    changed = true;
  }

  String prefixEnum(String prefix, dynamic value, List<String> allowed) {
    final raw = value?.toString() ?? '';
    if (raw.startsWith('$prefix.')) return raw;
    if (allowed.contains(raw)) return '$prefix.$raw';
    return raw.isEmpty ? '' : raw; // unknown; leave as-is to avoid destructive change
  }

  // displayType
  final displayRaw = out['displayType'];
  final displayNorm = prefixEnum('DisplayType', displayRaw, const ['button', 'inline']);
  if (displayNorm.isNotEmpty && displayNorm != displayRaw) {
    out['displayType'] = displayNorm;
    changed = true;
  }

  // buttonStyle
  final buttonRaw = out['buttonStyle'];
  final buttonNorm = prefixEnum('ButtonStyle', buttonRaw, const ['primary', 'secondary']);
  if (buttonNorm.isNotEmpty && buttonNorm != buttonRaw) {
    out['buttonStyle'] = buttonNorm;
    changed = true;
  }

  // detailType
  final detailRaw = out['detailType'];
  final detailNorm = prefixEnum('DetailType', detailRaw, const ['pdf', 'audio', 'link', 'embed', 'richText', 'request', 'image']);
  if (detailNorm.isNotEmpty && detailNorm != detailRaw) {
    out['detailType'] = detailNorm;
    changed = true;
  }

  // buttonText fallbacks to avoid corrupted flags in reader
  final disp = out['displayType']?.toString() ?? '';
  String btnText = (out['buttonText'] ?? '').toString();
  if (disp == 'DisplayType.button' && btnText.isEmpty) {
    out['buttonText'] = '[Button Text Missing]';
    changed = true;
  } else if (disp == 'DisplayType.inline' && btnText.isEmpty) {
    out['buttonText'] = '[Title Missing]';
    changed = true;
  }

  // Normalize width/height numeric to double or null
  if (out['width'] != null && out['width'] is! num) {
    out.remove('width');
    changed = true;
  }
  if (out['height'] != null && out['height'] is! num) {
    out.remove('height');
    changed = true;
  }

  final typeName = (out['detailType'] ?? '').toString();
  return _NormalizedDetailResultForReport(map: out, changed: changed, typeName: typeName);
}
