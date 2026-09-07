import 'dart:async';
import 'dart:io' show Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/analytics/meta_events_service.dart';
import 'package:fairytrail/api/edit_profile_props.dart';
import 'package:fairytrail/api/location.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/trail_book.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/billing/revenue_cat_service.dart';
import 'package:fairytrail/components/trail_book/postcard_purchase_sheet.dart';
import 'package:fairytrail/components/trail_book/trail_book_postcard_card.dart';
import 'package:fairytrail/config/billing_config.dart';
import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/screens/trail_book/postcard_success_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SendPostcardScreen extends StatefulWidget {
  const SendPostcardScreen({
    super.key,
    required this.profileId,
    required this.name,
    this.profilePhotoUrl,
    this.path = 'explore',
  });

  final int profileId;
  final String name;
  final String? profilePhotoUrl;
  final String path;

  @override
  State<SendPostcardScreen> createState() => _SendPostcardScreenState();
}

class _SendPostcardScreenState extends State<SendPostcardScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _anonymous = false;
  bool _loading = false;
  bool _locationLoading = true;
  List<StoreProduct> _products = const [];
  int _credits = 0;
  String _senderLocation = '';
  String _senderName = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = AuthScope.of(context);
      final meta = auth.profileMeta;
      setState(() {
        _credits = meta?.totalPostcards ?? 0;
        _senderName = auth.user?.name ?? 'You';
      });
      _loadProducts();
      _loadSenderLocation();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadSenderLocation() async {
    if (mounted) setState(() => _locationLoading = true);

    List<CountryDto> countries = const [];
    String profileCountry = '';
    try {
      final props = await getEditProfileProps();
      countries = props.countries;
      profileCountry = props.profile?.country?.country.trim() ?? '';
    } catch (e, st) {
      debugPrint('[Postcards] Profile props load failed: $e\n$st');
    }

    // Prefer live GPS so postcard art matches where the sender is now.
    final fromGps = await _detectCountryFromGps(countries);
    if (!mounted) return;
    if (fromGps != null && fromGps.isNotEmpty) {
      setState(() {
        _senderLocation = fromGps;
        _locationLoading = false;
      });
      return;
    }

    if (profileCountry.isNotEmpty) {
      debugPrint(
        '[Postcards] GPS unavailable — falling back to profile country',
      );
      setState(() {
        _senderLocation = profileCountry;
        _locationLoading = false;
      });
      return;
    }

    debugPrint(
      '[Postcards] Location unresolved — showing default postcard art',
    );
    setState(() {
      _senderLocation = '';
      _locationLoading = false;
    });
  }

  /// Asks for location permission, then resolves country from GPS.
  /// Returns null when permission fails or country cannot be detected
  /// (caller shows the generic default postcard art).
  Future<String?> _detectCountryFromGps(List<CountryDto> countries) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final outcome = await LocationService.shareCurrentLocation();
      if (!mounted) return null;

      if (outcome.isSuccess) {
        final name = await _countryNameFromGps(countries);
        if (name == null || name.isEmpty) {
          debugPrint(
            '[Postcards] GPS ok but country lookup failed — using default art',
          );
        }
        return name;
      }

      debugPrint(
        '[Postcards] Location share failed: ${outcome.result}'
        '${outcome.errorMessage != null ? ' (${outcome.errorMessage})' : ''}',
      );

      final needsPermission =
          outcome.result == LocationShareResult.permissionDenied ||
          outcome.result == LocationShareResult.permissionPermanentlyDenied;
      if (!needsPermission) return null;

      final permanentlyDenied =
          outcome.result == LocationShareResult.permissionPermanentlyDenied;
      final open = await AppDialog.confirm(
        context,
        title: 'Location access',
        message:
            'Allow location so we can show a postcard from your country. '
            'If you skip this, a generic postcard will be used.',
        confirmLabel: permanentlyDenied ? 'Open Settings' : 'Try again',
        cancelLabel: 'Use default',
      );
      if (!mounted || !open) {
        debugPrint(
          '[Postcards] User skipped location permission — using default art',
        );
        return null;
      }

      if (permanentlyDenied) {
        await LocationService.openAppSettings();
        debugPrint(
          '[Postcards] Opened settings after permanent deny — using default art',
        );
        return null;
      }
      // Soft deny — loop once more to re-request permission.
    }
    debugPrint(
      '[Postcards] Location permission still denied — using default art',
    );
    return null;
  }

  Future<String?> _countryNameFromGps(List<CountryDto> countries) async {
    try {
      double? lat;
      double? lng;
      final stored = await LocalStorage.instance.getLocation();
      if (stored != null) {
        final rawLat = stored['latitude'];
        final rawLng = stored['longitude'];
        if (rawLat is num && rawLng is num) {
          lat = rawLat.toDouble();
          lng = rawLng.toDouble();
        }
      }
      if (lat == null || lng == null) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.lowest,
            timeLimit: Duration(seconds: 20),
          ),
        );
        lat = position.latitude;
        lng = position.longitude;
      }

      final countryId = await postCountryIdFromCoordinates(
        latitude: lat,
        longitude: lng,
      );
      if (countryId == null) {
        debugPrint('[Postcards] country-id API returned null for ($lat, $lng)');
        return null;
      }

      for (final c in countries) {
        if (c.id == countryId) {
          final name = c.country.trim();
          if (name.isNotEmpty) return name;
        }
      }

      // Profile props failed earlier — reload countries once.
      if (countries.isEmpty) {
        final props = await getEditProfileProps();
        for (final c in props.countries) {
          if (c.id == countryId) {
            final name = c.country.trim();
            if (name.isNotEmpty) return name;
          }
        }
      }

      debugPrint(
        '[Postcards] No country name for id=$countryId — using default art',
      );
    } catch (e, st) {
      debugPrint('[Postcards] GPS country failed: $e\n$st');
    }
    return null;
  }

  Future<void> _loadProducts() async {
    try {
      final products = await RevenueCatService.instance.getPostcardProducts();
      if (products.isEmpty) {
        unawaited(
          track('error_get_offerings', {
            'error': 'Postcard products not found',
            'offering': BillingConfig.postcardsOfferingId,
            'from': 'send_postcard',
            'platform': Platform.isIOS ? 'ios' : 'android',
          }),
        );
      }
      if (mounted) setState(() => _products = products);
    } catch (e) {
      debugPrint('[Postcards] offerings failed: $e');
      unawaited(
        track('error_get_offerings', {
          'error': e.toString(),
          'offering': BillingConfig.postcardsOfferingId,
          'from': 'send_postcard',
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
    }
  }

  Future<void> _onSend() async {
    final text = _controller.text.trim();
    if (text.length < 15) {
      await AppDialog.show(
        context,
        title: 'Write more',
        message: 'Postcards are valuable! Write something meaningful.',
      );
      return;
    }

    if (_credits <= 0) {
      await _purchaseThenSend();
      return;
    }
    await _sendNote();
  }

  Future<void> _purchaseThenSend() async {
    if (_products.isEmpty) {
      await _loadProducts();
    }
    if (!mounted) return;
    if (_products.isEmpty) {
      await AppDialog.show(
        context,
        title: 'Unavailable',
        message: 'Postcard packs could not be loaded. Please try again.',
      );
      return;
    }

    final productId = await showPostcardPurchaseSheet(
      context,
      products: _products,
    );
    if (productId == null || !mounted) return;

    StoreProduct? product;
    for (final p in _products) {
      if (p.identifier == productId) product = p;
    }
    if (product == null) return;

    final userId = AuthScope.of(context).user?.id;
    setState(() => _loading = true);
    try {
      final result = await RevenueCatService.instance.purchaseStoreProduct(
        product,
      );
      final tx = result.storeTransaction;

      final update = await updatePostcardsCredits(
        transaction: {
          'transactionIdentifier': tx.transactionIdentifier,
          'transactionDate': tx.purchaseDate,
          'transactionAmount': product.price,
          'transactionCurrency': product.currencyCode,
          'transactionStatus': 'completed',
          'method_of_payment': Platform.isIOS ? 'apple_pay' : 'google_pay',
          'transaction_type': 'postcards_purchase',
        },
        productIdentifier: product.identifier,
        location: _senderLocation,
      );

      if (!update.success) {
        throw StateError('Failed to credit postcards');
      }
      unawaited(AnalyticsService.instance.logEvent('paid_postcard'));
      unawaited(
        MetaEventsService.instance.logPurchaseFromStoreProduct(
          customEventName: 'purchased_postcards',
          contentType: 'postcard',
          product: product,
          transaction: tx,
          userId: userId,
          extra: {'product_identifier': product.identifier},
        ),
      );
      if (!mounted) return;
      setState(() => _credits = update.totalPostcards);
      await _sendNote();
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        AppToast.show(context, message: e.message ?? 'Purchase failed');
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: serverErrorText(e));
        setState(() => _loading = false);
      }
    }
  }

  Future<String> _resolveSenderLocation() async {
    if (_locationLoading) {
      // Wait briefly for in-flight load; otherwise send with whatever we have.
      for (var i = 0; i < 40 && _locationLoading && mounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    return _senderLocation;
  }

  Future<void> _sendNote() async {
    setState(() => _loading = true);
    final auth = AuthScope.of(context);
    try {
      final senderLocation = await _resolveSenderLocation();
      final message = _controller.text.trim();
      await sendPostcard(
        receiverId: widget.profileId,
        message: message,
        isAnonymous: _anonymous,
        senderLocation: senderLocation,
      );
      unawaited(
        AnalyticsService.instance.logEvent('postcard_sent', {
          'receiverId': widget.profileId,
          'message': message,
          'isAnonymous': _anonymous ? 1 : 0,
          'type': 'postcard',
          'senderLocation': senderLocation,
        }),
      );
      try {
        await auth.refreshMe();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PostcardSuccessScreen(path: widget.path),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final status = e is ApiException ? e.statusCode : null;
      if (status == 403) {
        await AppDialog.show(
          context,
          title: 'Something went wrong',
          message: 'Please try again later.',
        );
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        AppToast.show(context, message: serverErrorText(e));
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.profilePhotoUrl;
    final previewName = _anonymous ? 'Anonymous' : _senderName;
    final message = _controller.text.trim();
    final count = _controller.text.characters.length;
    final secondary = AppColors.textSecondaryOf(context);
    final screenSize = MediaQuery.sizeOf(context);
    // Fixed postcard size (~50% screen height), never stretch to fill.
    var cardHeight = screenSize.height * 0.45;
    var cardWidth = cardHeight * 10 / 14;
    final maxCardWidth = screenSize.width - 40; // horizontal page padding
    if (cardWidth > maxCardWidth) {
      cardWidth = maxCardWidth;
      cardHeight = cardWidth * 14 / 10;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Write a postcard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AppText(
                  '$_credits left',
                  variant: AppTextVariant.label,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: photo != null && photo.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: photo,
                                      fit: BoxFit.cover,
                                    )
                                  : ColoredBox(
                                      color: AppColors.surfaceOf(context),
                                      child: const Icon(Icons.person, size: 20),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  'Sending to',
                                  variant: AppTextVariant.caption,
                                  color: secondary,
                                ),
                                const SizedBox(height: 2),
                                AppText(
                                  widget.name,
                                  variant: AppTextVariant.title,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        key: const ValueKey('postcard-preview'),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: PostcardVisual(
                            message: message,
                            senderName: previewName.isEmpty
                                ? 'You'
                                : previewName,
                            location: _senderLocation,
                            compact: true,
                            scrollMessage: true,
                            locationLoading: _locationLoading,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Stack(
                        key: const ValueKey('postcard-message-input'),
                        children: [
                          TextField(
                            key: const ValueKey('postcard-message-field'),
                            controller: _controller,
                            focusNode: _focus,
                            onTapOutside: (_) => _focus.unfocus(),
                            minLines: 3,
                            maxLines: 5,
                            maxLength: 155,
                            textCapitalization: TextCapitalization.sentences,
                            scrollPadding: const EdgeInsets.only(bottom: 100),
                            buildCounter:
                                (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => null,
                            decoration: InputDecoration(
                              hintText: 'Write something meaningful…',
                              isDense: true,
                              contentPadding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                48,
                                28,
                              ),
                              filled: true,
                              fillColor: AppColors.surfaceOf(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.borderOf(context),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.borderOf(context),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 10,
                            child: AppText(
                              '$count/155',
                              variant: AppTextVariant.caption,
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _anonymous = !_anonymous),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _anonymous,
                      activeColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() => _anonymous = v ?? false),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: AppText(
                        'Send anonymously',
                        variant: AppTextVariant.body,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Continue',
                isLoading: _loading,
                onPressed: () {
                  HapticsService.medium();
                  _onSend();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
