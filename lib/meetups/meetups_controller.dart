import 'package:fairytrail/api/meetups.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:flutter/foundation.dart';

class MeetupsController extends ChangeNotifier {
  List<MeetupDto> _meetups = [];
  MeetupTermsStatus? _terms;
  bool _loading = false;
  bool _loadingTerms = false;
  String? _error;
  double? _lat;
  double? _lng;

  List<MeetupDto> get meetups => List.unmodifiable(_meetups);
  MeetupTermsStatus? get terms => _terms;
  bool get loading => _loading;
  bool get loadingTerms => _loadingTerms;
  String? get error => _error;
  bool get termsAccepted => _terms?.accepted == true;
  double? get latitude => _lat;
  double? get longitude => _lng;

  Future<void> loadTerms() async {
    _loadingTerms = true;
    notifyListeners();
    try {
      _terms = await fetchMeetupTermsStatus();
      _error = null;
    } on ApiException catch (e) {
      if (e.statusCode == 403 &&
          (e.payload is Map && (e.payload as Map)['code'] == 'meetup_disabled')) {
        _error = 'Meetups are currently unavailable.';
      } else {
        _error = e.message;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingTerms = false;
      notifyListeners();
    }
  }

  Future<bool> acceptTerms() async {
    try {
      _terms = await acceptMeetupTerms();
      notifyListeners();
      return _terms?.accepted == true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadNearby({
    required double latitude,
    required double longitude,
  }) async {
    _lat = latitude;
    _lng = longitude;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _meetups = await fetchNearbyMeetups(
        latitude: latitude,
        longitude: longitude,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403 &&
          e.payload is Map &&
          (e.payload as Map)['code'] == 'terms_required') {
        _terms = MeetupTermsStatus(
          accepted: false,
          termsVersion: _terms?.termsVersion ?? 1,
        );
      }
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void removeLocally(int id) {
    _meetups = _meetups.where((m) => m.id != id).toList();
    notifyListeners();
  }

  void upsert(MeetupDto meetup) {
    final i = _meetups.indexWhere((m) => m.id == meetup.id);
    if (i >= 0) {
      _meetups = [..._meetups]..[i] = meetup;
    } else {
      _meetups = [meetup, ..._meetups];
    }
    notifyListeners();
  }
}
