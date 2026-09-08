import 'package:fairytrail/billing/billing_plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const weekly = BillingPlan(
    duration: 7,
    durationLabel: 1,
    price: 5.99,
    fullPrice: 5.99,
    productId: 'weekly',
    rcPackageId: r'$rc_weekly',
  );
  const monthly = BillingPlan(
    duration: 1,
    durationLabel: 1,
    price: 13.99,
    fullPrice: 13.99,
    productId: 'monthly',
    rcPackageId: r'$rc_monthly',
  );
  const annual = BillingPlan(
    duration: 12,
    durationLabel: 1,
    price: 4.66,
    fullPrice: 55.99,
    productId: 'annual',
    rcPackageId: r'$rc_annual',
  );

  test('normalizes weekly and monthly prices before calculating savings', () {
    expect(
      calculateSavingsPercent(
        plan: monthly,
        totalPrice: 13.99,
        baselinePlan: weekly,
        baselineTotalPrice: 5.99,
      ),
      46,
    );
    expect(
      calculateSavingsPercent(
        plan: annual,
        totalPrice: 55.99,
        baselinePlan: weekly,
        baselineTotalPrice: 5.99,
      ),
      82,
    );
  });

  test('does not show savings for the baseline or invalid prices', () {
    expect(
      calculateSavingsPercent(
        plan: weekly,
        totalPrice: 5.99,
        baselinePlan: weekly,
        baselineTotalPrice: 5.99,
      ),
      isNull,
    );
    expect(
      calculateSavingsPercent(
        plan: monthly,
        totalPrice: 0,
        baselinePlan: weekly,
        baselineTotalPrice: 5.99,
      ),
      isNull,
    );
  });

  test('silverPlansForWeeklyPackage applies A/B package and product ids', () {
    final control = silverPlansForWeeklyPackage(r'$rc_weekly');
    final weeklyControl = control.firstWhere((p) => p.isWeekly);
    expect(weeklyControl.rcPackageId, r'$rc_weekly');

    final variant = silverPlansForWeeklyPackage('weekly_b');
    final weeklyVariant = variant.firstWhere((p) => p.isWeekly);
    expect(weeklyVariant.rcPackageId, 'weekly_b');
    expect(weeklyVariant.productId, isNot(equals(weeklyControl.productId)));
  });
}
