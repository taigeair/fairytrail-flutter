# WorkManager (via google_mobile_ads): AGP 9 R8 full mode strips no-arg
# constructors only reached via Class.newInstance(), which crashes startup:
# Failed to create an instance of androidx.work.impl.WorkDatabase
# See https://issuetracker.google.com/issues/243257364
-keep class androidx.work.** { <init>(...); }
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.impl.**

# Stripe: optional push-provisioning / TapAndPay (private Google SDK).
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.google.android.gms.tapandpay.**
