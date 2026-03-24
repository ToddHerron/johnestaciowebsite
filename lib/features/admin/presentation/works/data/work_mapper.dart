import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';

class WorkMapper {
  static Work fromSourceJson(Map<String, dynamic> json) {
    // --- Main Fields ---
    final String title = json['title'] ?? '';
    
    String year = '';
    final dynamic releaseYear = json['releaseYear'];
    if (releaseYear is Timestamp) {
      year = releaseYear.toDate().year.toString();
    } else if (releaseYear is String && releaseYear.isNotEmpty) {
      year = DateTime.parse(releaseYear).year.toString();
    }

    final String instrumentation = json['orchestrationCodes'] ?? '';
    final List<String> categories = (json['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    // --- Details List ---
    var detailsList = <WorkDetail>[];
    if (json['details'] is List) {
      int detailOrder = 0;
      for (var detailJson in json['details']) {
        if (detailJson is Map<String, dynamic>) {
          final detailTitle = detailJson['detailTitle'] ?? '';
          final typeString = detailJson['type']?.toString().toLowerCase();
          final isButton = detailJson['isButton'] ?? false;
          final contentList = detailJson['contentList'] as List<dynamic>? ?? [];
          final rawContent = contentList.isNotEmpty ? contentList[0]['content']?.toString() ?? '' : '';

          if (rawContent.isNotEmpty) {
            DetailType detailType;
            dynamic finalContent;

            switch (typeString) {
              case 'link':
                detailType = DetailType.link;
                finalContent = rawContent;
                break;
              case 'markdown':
                detailType = DetailType.richText;
                // Convert the plain text string into a valid Quill Delta JSON object
                finalContent = {
                  'ops': [
                    {'insert': '$rawContent\n'}
                  ]
                };
                break;
              case 'pdf':
                detailType = DetailType.pdf;
                finalContent = rawContent;
                break;
              case 'embed':
                 detailType = DetailType.embed;
                 finalContent = rawContent;
                 break;
              case 'image':
                detailType = DetailType.image;
                finalContent = rawContent;
                break;
              default:
                continue; // Skip unknown types
            }

            detailsList.add(
              WorkDetail.empty().copyWith(
                order: detailOrder++,
                buttonText: detailTitle,
                content: finalContent,
                detailType: detailType,
                displayType: isButton ? DisplayType.button : DisplayType.inline,
              ),
            );
          }
        }
      }
    }

    return Work.fromSource(
      title: title,
      year: year,
      instrumentation: instrumentation,
      categories: categories,
      details: detailsList,
      subtitle: json['subtitle'] ?? '',
      duration: json['duration'] ?? '',
    );
  }
}

extension WorkDetailCopyWith on WorkDetail {
  WorkDetail copyWith({
    String? id,
    int? order,
    DisplayType? displayType,
    ButtonStyle? buttonStyle,
    String? buttonText,
    DetailType? detailType,
    dynamic content,
    bool? isCorrupted,
    bool? isTitleVisible,
    bool? isVisibleDetailTitle,
    double? width,
    double? height,
    String? storagePath,
  }) {
    return WorkDetail(
      id: id ?? this.id,
      order: order ?? this.order,
      displayType: displayType ?? this.displayType,
      buttonStyle: buttonStyle ?? this.buttonStyle,
      buttonText: buttonText ?? this.buttonText,
      detailType: detailType ?? this.detailType,
      content: content ?? this.content,
      isCorrupted: isCorrupted ?? this.isCorrupted,
      isTitleVisible: isTitleVisible ?? this.isTitleVisible,
      isVisibleDetailTitle: isVisibleDetailTitle ?? this.isVisibleDetailTitle,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}