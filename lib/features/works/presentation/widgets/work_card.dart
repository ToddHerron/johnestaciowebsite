import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:john_estacio_website/core/constants/app_constants.dart';
import 'package:john_estacio_website/core/utils/link_proxy.dart';
import 'package:john_estacio_website/core/utils/file_proxy.dart';
import 'package:john_estacio_website/core/widgets/quill_editor_configs.dart';
import 'package:john_estacio_website/core/widgets/quill_viewer.dart';
import 'package:john_estacio_website/features/discography/presentation/widgets/iframe_view.dart';
import 'package:john_estacio_website/features/performances/data/performances_repository.dart';
import 'package:john_estacio_website/features/performances/domain/models/performance_models.dart' as perf_model;
import 'package:john_estacio_website/features/works/domain/models/work_model.dart' as work_model;
import 'package:john_estacio_website/features/works/presentation/widgets/audio_player_dialog.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/embed_viewer_dialog.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/image_viewer_dialog.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/pdf_viewer_dialog.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/rich_text_viewer_dialog.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/inline_audio_clips_view.dart';
import 'package:john_estacio_website/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

class WorkCard extends StatelessWidget {
  final work_model.Work work;
  final String? highlightQuery;
  // The currently selected categories from the filter chips on WorksPage.
  // If null or empty, no category is specially highlighted.
  final Set<String>? selectedCategories;

  const WorkCard({
    required this.work,
    this.highlightQuery,
    this.selectedCategories,
    super.key,
  });

  List<InlineSpan> _buildHighlightedTitleSpans(String title, String? query) {
    final q = (query ?? '').trim();
    if (q.isEmpty) {
      return [TextSpan(text: title)];
    }

    final lowerTitle = title.toLowerCase();
    final lowerQ = q.toLowerCase();
    final spans = <InlineSpan>[];
    int start = 0;

    while (true) {
      final idx = lowerTitle.indexOf(lowerQ, start);
      if (idx < 0) {
        // remaining normal text
        if (start < title.length) {
          spans.add(TextSpan(text: title.substring(start)));
        }
        break;
      }
      // normal part before match
      if (idx > start) {
        spans.add(TextSpan(text: title.substring(start, idx)));
      }
      // matched part highlighted
      final matchText = title.substring(idx, idx + lowerQ.length);
      spans.add(TextSpan(
        text: matchText,
        style: TextStyle(
          backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.18),
          color: AppTheme.highlightYellow,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = idx + lowerQ.length;
    }

    return spans;
  }

bool _isImageUrl(String url) {
final uri = Uri.tryParse(url);
if (uri == null) {
return false;
}
final path = uri.path.toLowerCase();
return path.endsWith('.jpg') ||
path.endsWith('.jpeg') ||
path.endsWith('.png') ||
path.endsWith('.gif') ||
path.endsWith('.webp');
}

bool _isPdfUrl(String url) {
final uri = Uri.tryParse(url);
if (uri == null) return false;
final path = uri.path.toLowerCase();
return path.endsWith('.pdf');
}

String _proxiedImageUrl(String url) {
if (kIsWeb) {
return '${AppConstants.imageProxyUrl}?url=${Uri.encodeComponent(url)}';
}
return url;
}

double _extractHeightFromEmbed(String html) {
final regex = RegExp(r'height="([^"]+)"', caseSensitive: false);
final match = regex.firstMatch(html);
return double.tryParse(match?.group(1) ?? '315') ?? 315; // Default or parse
}

@override
Widget build(BuildContext context) {
    final String _computedDisplayTitle = work.allowMixedCaseTitle
        ? work.title
        : work.title.toUpperCase();
 final inlineDetails = work.details
.where((d) => d.displayType == work_model.DisplayType.inline)
.toList();
final buttonDetails = work.details
.where((d) => d.displayType != work_model.DisplayType.inline)
.toList();

inlineDetails.sort((a, b) => a.order.compareTo(b.order));
buttonDetails.sort((a, b) => a.order.compareTo(b.order));

final titleStyle = AppTheme.theme.textTheme.headlineSmall;
final newSize = (titleStyle?.fontSize ?? 24) * 1.25;

    return Card(
elevation: 2,
shadowColor: AppTheme.lightGray.withAlpha(128),
margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
child: Padding(
padding: const EdgeInsets.all(24.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
            RichText(
              text: TextSpan(
                style: titleStyle?.copyWith(
                  color: AppTheme.primaryOrange,
                  height: 1.0,
                  fontSize: newSize,
                ),
                children: <InlineSpan>[
                  ..._buildHighlightedTitleSpans(_computedDisplayTitle, highlightQuery),
                  const TextSpan(text: '\u00A0\u00A0\u00A0'),
                  WidgetSpan(
                    child: Transform.translate(
                      offset: const Offset(0, -4),
                      child: Text(
                        '(${work.year})',
                        style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.lightGray,
                        ),
                      ),
                    ),
                  ),
                  if (work.duration.isNotEmpty)
                    WidgetSpan(
                      child: Transform.translate(
                        offset: const Offset(0, -4),
                        child: Text(
                          '\u00A0\u00A0\u00A0${work.duration}',
                          style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.lightGray,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
if (work.subtitle.isNotEmpty)
Text(
work.subtitle,
style: AppTheme.theme.textTheme.titleLarge?.copyWith(
color: AppTheme.primaryOrange,
height: 1.0,
),
),
if (work.instrumentation.isNotEmpty)
Padding(
padding: const EdgeInsets.only(top: 4.0),
child: Text(
work.instrumentation,
style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
color: AppTheme.lightGray,
),
),
),
        // Categories just below orchestration codes
if (work.categories.isNotEmpty)
Padding(
padding: const EdgeInsets.only(top: 6.0),
child: Wrap(
spacing: 8,
runSpacing: 4,
              children: () {
                final selSet = selectedCategories ?? const <String>{};
                final noFilter = selSet.isEmpty;
                final lowerSel = selSet.map((e) => e.toLowerCase()).toSet();

                return work.categories
                    .where((c) => c.trim().isNotEmpty)
                    .map((c) {
                  final isMatch = !noFilter && lowerSel.contains(c.toLowerCase());
                  return Text(
                    c.toUpperCase(),
                    style: AppTheme.theme.textTheme.bodySmall?.copyWith(
                      color: isMatch ? AppTheme.highlightYellow : AppTheme.primaryOrange,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              }(),
),
),
// Upcoming performances for this work
_WorkUpcomingPerformancesSection(workTitle: work.title),
 if (inlineDetails.isNotEmpty) const SizedBox(height: 16),
 ..._buildInlineDetailsWithWrappedImages(context, inlineDetails),
if (buttonDetails.isNotEmpty) const SizedBox(height: 24),
if (buttonDetails.isNotEmpty)
Wrap(
spacing: 12,
runSpacing: 12,
children: buttonDetails
.map((detail) => _buildButtonDetail(context, detail))
.toList(),
),
],
),
),
);
}

void _handleButtonPress(
BuildContext context, work_model.WorkDetail detail) async {
switch (detail.detailType) {
case work_model.DetailType.pdf:
if (detail.content is String) {
showDialog(
context: context,
builder: (_) => PdfViewerDialog(
pdfUrl: detail.content,
storagePath: detail.storagePath,
title: detail.buttonText,
),
);
}
break;
case work_model.DetailType.audio:
if (detail.content is List<work_model.AudioClip>) {
showDialog(
context: context,
builder: (_) => AudioPlayerDialog(
audioClips: detail.content, title: detail.buttonText),
);
}
break;
case work_model.DetailType.link:
if (detail.content is String) {
if (_isImageUrl(detail.content)) {
showDialog(
context: context,
builder: (context) => ImageViewerDialog(
imageUrl: _proxiedImageUrl(detail.content),
width: detail.width,
height: detail.height),
);
} else {
try {
final isPdf = _isPdfUrl(detail.content);
final uri = isPdf
? FileProxy.build(detail.content, filename: detail.buttonText)
: LinkProxy.build(detail.content);
await launchUrl(uri, webOnlyWindowName: '_blank');
} catch (e) {
debugPrint('Could not open link: ${detail.content}. Error: $e');
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Could not open the link: ${detail.content}')),
);
}
}
}
}
break;
case work_model.DetailType.richText:
if (detail.content is Map<String, dynamic>) {
showDialog(
context: context,
builder: (_) => RichTextViewerDialog(
deltaJson: detail.content,
title: detail.buttonText,
),
);
}
break;
case work_model.DetailType.embed:
if (detail.content is String) {
showDialog(
context: context,
builder: (_) => EmbedViewerDialog(
embedCode: detail.content,
title: detail.isTitleVisible ? detail.buttonText : null,
),
);
}
break;
case work_model.DetailType.request:
// Navigate to Request Scores, prepopulated with this work title
final title = work.title;
final qp = Uri(queryParameters: {'work': title}).query;
if (context.mounted) {
GoRouter.of(context).go('/performances/request?$qp');
}
break;
case work_model.DetailType.image:
if (detail.content is String) {
showDialog(
context: context,
builder: (context) => ImageViewerDialog(
imageUrl: detail.content,
width: detail.width,
height: detail.height,
),
);
}
break;
}
}

Widget _buildInlineDetail(
  BuildContext context, work_model.WorkDetail detail) {
  if (detail.detailType == work_model.DetailType.pdf && detail.content is String) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => PdfViewerDialog(
              pdfUrl: detail.content,
              storagePath: detail.storagePath,
              title: detail.buttonText,
            ),
          );
        },
        child: Text(
          detail.buttonText,
          style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryOrange,
          ),
        ),
      ),
    );
  }

  if (detail.detailType == work_model.DetailType.link && !_isImageUrl(detail.content)) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () async {
          try {
            final isPdf = _isPdfUrl(detail.content);
            final uri = isPdf
                ? FileProxy.build(detail.content, filename: detail.buttonText)
                : LinkProxy.build(detail.content);
            await launchUrl(uri, webOnlyWindowName: '_blank');
          } catch (e) {
            debugPrint('Could not open link: ${detail.content}. Error: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not open the link: ${detail.content}')),
              );
            }
          }
        },
        child: Text(
          detail.buttonText,
          style: AppTheme.theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryOrange,
          ),
        ),
      ),
    );
  }

  Widget contentWidget;
  if (detail.detailType == work_model.DetailType.richText && detail.content is Map<String, dynamic>) {
    contentWidget = QuillViewer(deltaJson: detail.content);
  } else if (detail.detailType == work_model.DetailType.link && _isImageUrl(detail.content)) {
    contentWidget = SizedBox(
      width: detail.width,
      height: detail.height,
      child: Image.network(
        _proxiedImageUrl(detail.content),
        errorBuilder: (context, error, stackTrace) {
          return const Text('Could not load image due to web security restrictions.');
        },
      ),
    );
  } else if (detail.detailType == work_model.DetailType.image && detail.content is String) {
    contentWidget = SizedBox(
      width: detail.width,
      height: detail.height,
      child: Image.network(
        detail.content,
        errorBuilder: (context, error, stackTrace) {
          return const Text('Could not load image.');
        },
      ),
    );
  } else if (detail.detailType == work_model.DetailType.audio && detail.content is List<work_model.AudioClip>) {
    contentWidget = InlineAudioClipsView(audioClips: detail.content);
  } else if (detail.detailType == work_model.DetailType.embed && detail.content is String) {
    final height = _extractHeightFromEmbed(detail.content);
    contentWidget = IframeView(htmlContent: detail.content, height: height);
  } else {
    contentWidget = Text(
      detail.content.toString(),
      style: AppTheme.theme.textTheme.bodyLarge,
    );
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (
          detail.displayType == work_model.DisplayType.inline &&
          (detail.isVisibleDetailTitle ?? false) &&
          detail.buttonText.isNotEmpty &&
          detail.buttonText != '[Title Missing]'
        )
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              detail.buttonText,
              style: QuillEditorConfigs.customStyles.h1!.style,
            ),
          ),
        contentWidget,
      ],
    ),
  );
}

  // Build inline details but group consecutive images into a centered Wrap with uniform height
  List<Widget> _buildInlineDetailsWithWrappedImages(
      BuildContext context, List<work_model.WorkDetail> inlineDetails) {
    final widgets = <Widget>[];
    const double uniformImageHeight = 180; // consistent height for all inline gallery images

    bool isInlineImage(work_model.WorkDetail d) {
      final isImageType = d.detailType == work_model.DetailType.image && d.content is String;
      final isLinkImage = d.detailType == work_model.DetailType.link && d.content is String && _isImageUrl(d.content as String);
      return isImageType || isLinkImage;
    }

    String resolveImageUrl(work_model.WorkDetail d) {
      final url = d.content as String;
      // For link images, apply proxy on web similar to single-image logic
      if (d.detailType == work_model.DetailType.link) {
        return _proxiedImageUrl(url);
      }
      return url;
    }

    int i = 0;
    while (i < inlineDetails.length) {
      final d = inlineDetails[i];
      if (isInlineImage(d)) {
        final imageGroup = <work_model.WorkDetail>[];
        while (i < inlineDetails.length && isInlineImage(inlineDetails[i])) {
          imageGroup.add(inlineDetails[i]);
          i++;
        }
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: imageGroup.map((imgDetail) {
                final url = resolveImageUrl(imgDetail);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    url,
                    height: uniformImageHeight,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: uniformImageHeight,
                        width: uniformImageHeight * 1.4,
                        color: AppTheme.darkGray,
                        alignment: Alignment.center,
                        child: const Text(
                          'Image unavailable',
                          style: TextStyle(color: AppTheme.lightGray),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        );
      } else {
        widgets.add(_buildInlineDetail(context, d));
        i++;
      }
    }

    return widgets;
  }

Widget _buildButtonDetail(
BuildContext context, work_model.WorkDetail detail) {
bool isPrimary = detail.buttonStyle == work_model.ButtonStyle.primary;

return ElevatedButton(
onPressed: () => _handleButtonPress(context, detail),
style: ElevatedButton.styleFrom(
backgroundColor: isPrimary ? AppTheme.primaryOrange : AppTheme.darkGray,
foregroundColor: isPrimary ? AppTheme.black : AppTheme.primaryOrange,
side: BorderSide(
color: isPrimary ? AppTheme.black : AppTheme.primaryOrange,
),
padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
textStyle: AppTheme.theme.textTheme.labelLarge,
),
child: Text(detail.buttonText.toUpperCase()),
);
}
}

class _WorkUpcomingPerformancesSection extends StatelessWidget {
const _WorkUpcomingPerformancesSection({required this.workTitle});
final String workTitle;

@override
Widget build(BuildContext context) {
final repo = PerformancesRepository();
return StreamBuilder<List<perf_model.PerformanceRequest>>(
stream: repo.streamUpcomingForWorkTitle(workTitle),
builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting) {
return const SizedBox.shrink();
}
final items = snapshot.data ?? const [];
if (items.isEmpty) return const SizedBox.shrink();

return Padding(
padding: const EdgeInsets.only(top: 12.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Upcoming Performances',
style: AppTheme.theme.textTheme.titleMedium?.copyWith(
color: AppTheme.primaryOrange,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 8),
...items.map((req) => _WorkRequestGroup(req: req)),
],
),
);
},
);
}
}

class _WorkRequestGroup extends StatelessWidget {
const _WorkRequestGroup({required this.req});
final perf_model.PerformanceRequest req;

@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.only(bottom: 12.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
if (req.ensemble.isNotEmpty)
Text(
req.ensemble,
style: AppTheme.theme.textTheme.titleSmall?.copyWith(
color: AppTheme.primaryOrange,
),
),
if (req.conductor.isNotEmpty)
Padding(
padding: const EdgeInsets.only(top: 2.0),
child: Text(
'Conductor: ${req.conductor}',
style: AppTheme.theme.textTheme.bodyMedium?.copyWith(
color: AppTheme.lightGray,
),
),
),
...req.performances
.where((p) => p.dateTime.toDate().toLocal().isAfter(DateTime.now()))
.map((p) => _WorkPerformanceTile(p: p)),
],
),
);
}
}

class _WorkPerformanceTile extends StatelessWidget {
const _WorkPerformanceTile({required this.p});
final perf_model.PerformanceItem p;

@override
Widget build(BuildContext context) {
final dt = p.dateTime.toDate().toLocal();
final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(dt);
final timeStr = DateFormat('h:mm a').format(dt).toLowerCase();
final location = [p.city, p.region, p.country]
.where((e) => e.trim().isNotEmpty)
.join(', ');

return ListTile(
contentPadding: EdgeInsets.zero,
title: Text(p.venueName, style: const TextStyle(color: AppTheme.lightGray)),
subtitle: Text('$location • $dateStr • $timeStr',
style: const TextStyle(color: AppTheme.lightGray)),
trailing: (p.ticketingLink.trim().isNotEmpty && dt.isAfter(DateTime.now()))
? TextButton.icon(
icon: const Icon(Icons.open_in_new, color: AppTheme.lightGray),
label: const Text('FIND TICKETS',
style: TextStyle(color: AppTheme.lightGray)),
onPressed: () async {
try {
final uri = LinkProxy.build(p.ticketingLink.trim());
await launchUrl(uri, webOnlyWindowName: '_blank');
} catch (_) {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Could not open ticketing link')),
);
}
}
},
)
: null,
);
}
}

