import 'dart:async';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/registration/profile_type_selector.dart';
import 'package:fairytrail/components/registration/progress_circles.dart';
import 'package:fairytrail/components/registration/signup_logout_button.dart';
import 'package:fairytrail/config/registration_options.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/device_metadata.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Step 2: create profile details (resumes from local storage).
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _nameFieldKey = GlobalKey();

  String? _profileType;
  String? _mobility = 'non-remote';
  int? _age;
  String? _email;
  bool _isLoading = false;
  String? _error;

  bool get _showAge =>
      _profileType == 'man' ||
      _profileType == 'woman' ||
      _profileType == 'non-binary';

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty &&
      _profileType != null &&
      _mobility != null;

  void _onFieldChanged() {
    setState(() {});
    _persistDraft();
  }

  Future<void> _persistDraft() async {
    final existing = await LocalStorage.instance.getRegistrationData();
    final draft = RegistrationRequest(
      name: _nameController.text.trim(),
      profileType: _profileType ?? '',
      mobility: _mobility ?? 'non-remote',
      storyTime: (existing?['storyTime'] as String?) ?? '',
      email: _email,
      age: _age,
    );
    await LocalStorage.instance.setRegistrationData(draft.toJson());
  }

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.instance.logScreenView('registration_screen'));
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final storage = LocalStorage.instance;
    final email = await storage.getEmail();
    final data = await storage.getRegistrationData();
    if (!mounted) return;

    final user = AuthScope.of(context).user;

    setState(() {
      _email = email;
      if (user != null && user.name.isNotEmpty) {
        _nameController.text = user.name.trim();
      }
      if (data != null) {
        final req = RegistrationRequest.fromJson(data);
        if (req.name.isNotEmpty) _nameController.text = req.name.trim();
        _profileType = req.profileType.isEmpty ? null : req.profileType;
        _mobility = req.mobility.isEmpty ? 'non-remote' : req.mobility;
        _age = req.age;
        if (req.email != null && req.email!.isNotEmpty) _email = req.email;
      }
    });

    // Persist default work style if this is a fresh draft.
    if (data == null || (data['mobility'] as String?)?.isEmpty != false) {
      _persistDraft();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _dismissNameKeyboardOutsideField(PointerDownEvent event) {
    if (!_nameFocusNode.hasFocus) return;

    final renderObject =
        _nameFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderObject != null) {
      final bounds =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (bounds.contains(event.position)) return;
    }

    _finishEditingName();
  }

  void _finishEditingName() {
    final trimmedName = _nameController.text.trim();
    if (trimmedName != _nameController.text) {
      _nameController.value = TextEditingValue(
        text: trimmedName,
        selection: TextSelection.collapsed(offset: trimmedName.length),
      );
      setState(() {});
      _persistDraft();
    }
    _nameFocusNode.unfocus();
  }

  Future<void> _onContinue() async {
    if (!_canContinue || _isLoading) return;
    _finishEditingName();

    int? age;
    if (_showAge) {
      age = _age;
      if (age == null || age < 18 || age > 150) {
        setState(() => _error = 'You should be at least 18 years old');
        return;
      }
    }

    final label = switch (_profileType) {
      'man' => 'You are a man',
      'woman' => 'You are a woman',
      'non-binary' => 'You are non-binary',
      _ => 'Your account is being created',
    };

    final confirmed = await AppDialog.confirm(
      context,
      title: label,
      message:
          'This is how you appear on Fairytrail and cannot be changed later',
      confirmLabel: 'Confirm',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _email;
    final isEmailValid =
        email != null && email.contains('@') && email.contains('.');
    final auth = AuthScope.of(context);
    final existing = await LocalStorage.instance.getRegistrationData();
    if (!mounted) return;

    final request = RegistrationRequest(
      name: _nameController.text.trim(),
      profileType: _profileType!,
      mobility: _mobility!,
      storyTime: (existing?['storyTime'] as String?) ?? '',
      email: isEmailValid ? email : null,
      age: age,
      deviceMetadata: await DeviceMetadata.collect(),
    );

    try {
      await auth.completeRegistration(request);
      // AuthGate → ProfilePhotosScreen
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = serverErrorText(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _dismissNameKeyboardOutsideField,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Create profile'),
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          actions: [SignupLogoutButton(enabled: !_isLoading)],
        ),
        body: AppSafeArea(
          child: Column(
            children: [
              const ProgressCircles(activeStep: 2),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        AppText(
                          _error!,
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                      ],
                      AppTextField(
                        key: _nameFieldKey,
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        label: 'Name',
                        hint: 'Your name',
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => _onFieldChanged(),
                        onSubmitted: (_) => _finishEditingName(),
                      ),
                      const SizedBox(height: 20),
                      ProfileTypeSelector(
                        value: _profileType,
                        onChanged: (v) {
                          setState(() => _profileType = v);
                          _persistDraft();
                        },
                      ),
                      const SizedBox(height: 20),
                      const AppText(
                        'Work flexibility',
                        variant: AppTextVariant.label,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final opt in mobilityOptions)
                            ChoiceChip(
                              label: Text(opt.$1),
                              selected: _mobility == opt.$2,
                              onSelected: (_) {
                                setState(() => _mobility = opt.$2);
                                _persistDraft();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppAgePicker(
                        value: _age,
                        onChanged: (age) {
                          setState(() {
                            _age = age;
                            _error = null;
                          });
                          _persistDraft();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: AppButton(
                  label: 'Continue',
                  isLoading: _isLoading,
                  onPressed: _canContinue ? _onContinue : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
