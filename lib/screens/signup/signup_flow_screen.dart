import 'dart:async';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/api/update_user_data.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/billing/revenue_cat_service.dart';
import 'package:fairytrail/explore/explore_warm_prefetch.dart';
import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/screens/signup/signup_draft.dart';
import 'package:fairytrail/screens/signup/steps/signup_about_step.dart';
import 'package:fairytrail/screens/signup/steps/signup_basics_step.dart';
import 'package:fairytrail/screens/signup/steps/signup_destination_step.dart';
import 'package:fairytrail/screens/signup/steps/signup_location_step.dart';
import 'package:fairytrail/screens/signup/steps/signup_motives_step.dart';
import 'package:fairytrail/screens/signup/steps/signup_photos_step.dart';
import 'package:fairytrail/screens/signup/steps/signup_preview_step.dart';
import 'package:fairytrail/screens/profile/silver_free_trial_screen.dart';
import 'package:fairytrail/screens/signup/steps/signup_rate_step.dart';
import 'package:fairytrail/screens/signup/steps/signup_social_proof_step.dart';
import 'package:fairytrail/screens/signup/steps/signup_travel_step.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/device_metadata.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Signup orchestrator. Persisted IDs stay stable when steps move.
/// Story Time uses ID 12 after Rate Us (10), before finalization (11).
class SignupFlowScreen extends StatefulWidget {
  const SignupFlowScreen({super.key});

  @override
  State<SignupFlowScreen> createState() => _SignupFlowScreenState();
}

class _SignupFlowScreenState extends State<SignupFlowScreen> {
  final _upload = BackgroundPhotoUpload.instance;

  int _step = 1;
  bool _ready = false;
  bool _busy = false;
  bool _upgradeOpened = false;
  String? _error;

  // Step 1
  String _name = '';
  String? _profileType;
  int? _age;

  // Step 2 (UI-only)
  Set<String> _motives = {};

  // Step 3 (travel kind UI-only; remote → mobility)
  String? _travelKind;
  bool _isFullyRemote = false;
  String _mobility = 'non-remote';

  // Step 12 (after Rate Us)
  String _storyTime = '';

  // Step 8
  Set<int> _upcomingCountryIds = {};
  bool _openToAllDestinations = false;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.instance.logScreenView('registration_screen'));
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final auth = AuthScope.of(context);
    final remote = RemoteConfigScope.of(context);
    final draft = await SignupDraft.load();
    final savedStep = auth.signupStep ?? 1;

    if (!remote.isReady) {
      try {
        await remote.refresh();
      } catch (_) {
        // Offline / init failure — keep rate step enabled (current default).
      }
    }

    if (!mounted) return;

    final showRateUs = remote.showRateUsOnboarding;
    var step = savedStep.clamp(1, AuthController.signupStepCount);
    // The former Story Time step now resumes at social proof.
    if (step == 4) step = 5;
    // Skip a restored rate step when remote config has it turned off.
    if (!showRateUs && step == 10) {
      step = 12;
    }

    final user = auth.user;
    setState(() {
      _step = step;
      _name = (draft['name'] as String?)?.trim().isNotEmpty == true
          ? (draft['name'] as String).trim()
          : (user?.name ?? '');
      _profileType = (draft['profileType'] as String?)?.isNotEmpty == true
          ? draft['profileType'] as String
          : null;
      _age = (draft['age'] as num?)?.toInt();
      _mobility = (draft['mobility'] as String?)?.isNotEmpty == true
          ? draft['mobility'] as String
          : 'non-remote';
      _isFullyRemote = _mobility == 'remote';
      _storyTime = (draft['storyTime'] as String?) ?? '';
      _travelKind = draft['travelKind'] as String?;
      final motives = draft['motives'];
      if (motives is List) {
        _motives = motives.map((e) => e.toString()).toSet();
      }
      final countries = draft['upcomingCountryIds'];
      if (countries is List) {
        _upcomingCountryIds = countries.map((e) => (e as num).toInt()).toSet();
      }
      _openToAllDestinations = draft['openToAllDestinations'] as bool? ?? false;
      _ready = true;
    });

    if (auth.signupStep == null || auth.signupStep != step) {
      await auth.setSignupStep(step);
    }

    if (step == 11 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openUpgradeThenFinish());
      });
    }
  }

  Future<void> _goTo(int step) async {
    setState(() {
      _step = step;
      _error = null;
      _busy = false;
    });
    await AuthScope.of(context).setSignupStep(step);
  }

  Future<void> _persistBasics() async {
    await SignupDraft.merge({
      'name': _name.trim(),
      'profileType': _profileType ?? '',
      'age': _age,
      'mobility': _mobility,
      'storyTime': _storyTime,
      'motives': _motives.toList(),
      'travelKind': _travelKind,
      'upcomingCountryIds': _upcomingCountryIds.toList(),
      'openToAllDestinations': _openToAllDestinations,
    });
  }

  Future<void> _onBasicsContinue() async {
    if (_age == null || _age! < 18) {
      setState(() => _error = 'You should be at least 18 years old');
      return;
    }

    final label = switch (_profileType) {
      'man' => 'You are a man',
      'woman' => 'You are a woman',
      'non-binary' => 'You are non-binary',
      _ => 'Confirm your profile',
    };

    final confirmed = await AppDialog.confirm(
      context,
      title: label,
      message:
          'This is how you appear on Fairytrail and cannot be changed later',
      confirmLabel: 'Confirm',
    );
    if (!confirmed || !mounted) return;

    await _persistBasics();
    await _goTo(2);
  }

  Future<void> _onMotivesContinue() async {
    await _persistBasics();
    await _goTo(3);
  }

  Future<void> _onTravelContinue() async {
    if (_busy || _profileType == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _mobility = _isFullyRemote ? 'remote' : 'non-remote';
    });

    await _persistBasics();
    if (!mounted) return;

    final auth = AuthScope.of(context);
    final meta = auth.profileMeta;

    // Register once we have name, gender, age, and mobility.
    if (meta == null || !meta.isProfileCompleted) {
      final email = await LocalStorage.instance.getEmail();
      final isEmailValid =
          email != null && email.contains('@') && email.contains('.');

      final request = SignupDraft.toRegistrationRequest(
        await SignupDraft.load(),
        email: isEmailValid ? email : null,
        deviceMetadata: await DeviceMetadata.collect(),
      );

      try {
        await auth.completeRegistration(request);
        // Funnel: started_registration (backend) → completed_basic → …
        unawaited(track('completed_basic'));
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = serverErrorText(e);
          _busy = false;
        });
        return;
      }
    }

    // Persist travel style + motives after profile exists.
    try {
      await updateUserData(
        name: _name.trim(),
        mobility: _mobility,
        // Solo Traveler stays NULL in DB; query treats null as solo_traveller.
        travelStyle: (_travelKind == null || _travelKind == soloTravellerValue)
            ? null
            : _travelKind,
        motives: _motives.toList(),
        skip: true,
      );
      await auth.refreshMe();
    } catch (e) {
      debugPrint('[Signup] update travelStyle/motives failed: $e');
    }

    if (!mounted) return;
    await _goTo(5);
  }

  Future<void> _onAboutContinue() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    await _persistBasics();

    try {
      await updateUserData(
        name: _name.trim(),
        mobility: _mobility,
        storyTime: _storyTime.trim(),
        age: _age,
        skip: true,
      );
    } catch (e) {
      // Story can be edited later; don't block signup.
      debugPrint('[Signup] update story failed: $e');
    }

    if (!mounted) return;
    await _goTo(11);
    await _openUpgradeThenFinish();
  }

  Future<void> _onPhotosContinue() async {
    if (_busy) return;
    setState(() => _busy = true);

    final auth = AuthScope.of(context);
    try {
      final userId = auth.user?.id;
      if (userId != null && userId.isNotEmpty) {
        await LocalStorage.instance.setPhotoUploadCommittedUserId(userId);
      }

      _upload.commit(
        onAttached: () {
          unawaited(auth.refreshMe());
        },
      );
      await auth.markPhotosComplete();
      if (!mounted) return;
      await _goTo(7);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = serverErrorText(e);
        _busy = false;
      });
    }
  }

  Future<void> _onDestinationContinue() async {
    if (_busy) return;
    setState(() => _busy = true);

    await _persistBasics();

    // Anywhere / Open to all → empty list. None or countries → save ids.
    try {
      await updateUserData(
        name: _name.trim(),
        mobility: _mobility,
        storyTime: _storyTime.trim(),
        age: _age,
        upcomingCountries: _openToAllDestinations
            ? const <int>[]
            : _upcomingCountryIds.toList(),
        skip: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = serverErrorText(e);
        _busy = false;
      });
      return;
    }

    if (!mounted) return;
    await _goTo(9);
  }

  Future<void> _onLocationContinue() async {
    setState(() => _busy = true);
    try {
      final auth = AuthScope.of(context);
      await auth.markLocationSet();
      if (!mounted) return;
      // So rate-screen warm prefetch can send firstime before completeSignupFlow.
      await LocalStorage.instance.markPendingSignupFirstExplore();
      if (!mounted) return;
      final remote = RemoteConfigScope.of(context);
      // Profile exists now — refresh so show_free_trial_A/B resolve for this group.
      // Location Continue stays loading until this finishes (no blank pause).
      try {
        await remote.refresh();
      } catch (_) {}
      if (!mounted) return;
      final showRate = remote.showRateUsOnboarding;
      // After profile is complete, before rating / upgrade.
      unawaited(
        track('completed_signup', {
          'name': _name.trim(),
          'profile_type': _profileType ?? 'unknown',
          'age': _age,
          'mobility': _mobility,
          'travel_style': _travelKind ?? soloTravellerValue,
          'motives': _motives.toList(),
          'motives_count': _motives.length,
          'has_story': _storyTime.trim().isNotEmpty,
          'destination_preference': _openToAllDestinations
              ? 'open_to_all'
              : _upcomingCountryIds.isNotEmpty
              ? 'selected'
              : 'none',
          'destination_count': _upcomingCountryIds.length,
          'show_rate_us_onboarding': showRate,
          'show_free_trial': remote.showFreeTrial,
        }),
      );
      if (showRate) {
        await _goTo(10);
      } else {
        // No rate screen — warm People now (prefs → matches → prefetch).
        ExploreWarmPrefetch.instance.start(
          profileMeta: AuthScope.of(context).profileMeta,
        );
        await _goTo(12);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRateContinue() async {
    await _goTo(12);
  }

  /// Optionally show the free-trial offer before finishing signup.
  Future<void> _openUpgradeThenFinish() async {
    if (_upgradeOpened || !mounted) return;
    _upgradeOpened = true;
    var hasUsedFreeTrial = false;
    try {
      hasUsedFreeTrial =
          await RevenueCatService.instance.hasUsedSilverAnnualTrial();
    } catch (e) {
      debugPrint('[Signup] Free-trial eligibility check failed: $e');
    }
    if (!mounted) return;
    if (RemoteConfigScope.of(context).showFreeTrial && !hasUsedFreeTrial) {
      await SilverFreeTrialScreen.open(context, from: 'signup');
    }
    if (!mounted) return;
    await AuthScope.of(context).completeSignupFlow();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: AppLoading());
    }

    return switch (_step) {
      1 => SignupBasicsStep(
        initialName: _name,
        initialProfileType: _profileType,
        initialAge: _age,
        error: _error,
        isLoading: _busy,
        onChanged: ({name, profileType, age}) {
          if (name != null) _name = name;
          if (profileType != null) _profileType = profileType;
          if (age != null) _age = age;
          unawaited(_persistBasics());
        },
        onContinue: _onBasicsContinue,
      ),
      2 => SignupMotivesStep(
        selected: _motives,
        onChanged: (v) {
          setState(() => _motives = v);
          unawaited(_persistBasics());
        },
        onContinue: _onMotivesContinue,
      ),
      3 => SignupTravelStep(
        travelKind: _travelKind,
        isFullyRemote: _isFullyRemote,
        isLoading: _busy,
        error: _error,
        onTravelKindChanged: (v) {
          setState(() => _travelKind = v);
          unawaited(_persistBasics());
        },
        onFullyRemoteChanged: (v) {
          setState(() {
            _isFullyRemote = v;
            _mobility = v ? 'remote' : 'non-remote';
          });
          unawaited(_persistBasics());
        },
        onContinue: _onTravelContinue,
      ),
      5 => SignupSocialProofStep(
        travelStyleLabel: socialProofTextForTravelKind(_travelKind),
        onContinue: () => _goTo(6),
      ),
      6 => SignupPhotosStep(
        isLoading: _busy,
        error: _error,
        onContinue: _onPhotosContinue,
      ),
      7 => SignupPreviewStep(
        name: _name,
        profileType: _profileType ?? '',
        age: _age,
        mobility: _mobility,
        storyTime: _storyTime,
        travelKind: _travelKind,
        onContinue: () => _goTo(8),
      ),
      8 => SignupDestinationStep(
        selectedIds: _upcomingCountryIds,
        openToAll: _openToAllDestinations,
        isLoading: _busy,
        onChanged: (ids) {
          setState(() => _upcomingCountryIds = ids);
          unawaited(_persistBasics());
        },
        onOpenToAllChanged: (value) {
          setState(() {
            _openToAllDestinations = value;
            if (value) _upcomingCountryIds = {};
          });
          unawaited(_persistBasics());
        },
        onContinue: _onDestinationContinue,
      ),
      9 => SignupLocationStep(
        isLoading: _busy,
        onContinue: _onLocationContinue,
      ),
      10 => SignupRateStep(onContinue: _onRateContinue),
      12 => SignupAboutStep(
        initialStory: _storyTime,
        isLoading: _busy,
        error: _error,
        onChanged: (v) {
          _storyTime = v;
          unawaited(_persistBasics());
        },
        onContinue: _onAboutContinue,
        onSkip: () {
          _storyTime = '';
          unawaited(_persistBasics());
          unawaited(_onAboutContinue());
        },
      ),
      11 => const Scaffold(body: AppLoading()),
      _ => SignupBasicsStep(
        initialName: _name,
        initialProfileType: _profileType,
        initialAge: _age,
        onChanged: ({name, profileType, age}) {},
        onContinue: () => _goTo(1),
      ),
    };
  }
}
