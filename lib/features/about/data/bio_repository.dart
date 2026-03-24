import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:john_estacio_website/core/cache/app_cache.dart';
import 'package:john_estacio_website/features/about/domain/models/bio_model.dart';

class BioRepository {
  final DocumentReference _bioDocRef;

  BioRepository({FirebaseFirestore? firestore})
      : _bioDocRef = (firestore ?? FirebaseFirestore.instance).collection('pages').doc('bio');

  Future<BioPageModel> getBioPage() async {
    const key = 'bio_page';
    return AppCache.instance.getOrFetch<BioPageModel>(key, () async {
      final docSnapshot = await _bioDocRef.get();
      if (docSnapshot.exists) {
        return BioPageModel.fromFirestore(docSnapshot);
      } else {
        return BioPageModel(
          bio100Words: {'ops': [{'insert': 'Not available.\n'}]},
          bio250Words: {'ops': [{'insert': 'Not available.\n'}]},
          bio450Words: {'ops': [{'insert': 'Not available.\n'}]},
          bio850Words: {'ops': [{'insert': 'Not available.\n'}]},
          cvContent: {'ops': [{'insert': 'Not available.\n'}]},
        );
      }
    });
  }

  Future<void> updateBioPage(Map<String, dynamic> data) async {
    await _bioDocRef.set(data, SetOptions(merge: true));
    AppCache.instance.invalidate('bio_page');
  }
}