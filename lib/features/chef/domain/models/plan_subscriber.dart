/// One subscriber of one of the chef's plans.
///
/// Deliberately does not live in `meal_plan_model.dart`: this is a read-only
/// projection the chef is allowed to see, not part of the plan aggregate the
/// chef can write. Keeping it separate makes it obvious that there is no
/// `toWriteJson` and no client-side mutation path.
///
/// Field mapping is snake_case because `ChefPlanSubscribersListView` and
/// `ChefSubscribersListView` build plain dicts rather than going through
/// `CamelCaseModelSerializer`. Both views return a subset of these fields —
/// the per-plan view adds `customer_phone`/`end_date`/`address`, the
/// all-plans view adds `plan_id`/`plan_name` — so anything absent here
/// degrades to an empty string rather than throwing.
class PlanSubscriber {
  final String id;
  final String status;
  final String cadence;

  /// What the customer actually paid, as a string.
  ///
  /// String, not double: this is money. Parsing it into a double to format it
  /// for display would introduce binary-float rounding into a rupee amount.
  /// Display code should parse-and-format once, at the edge.
  final String pricePaid;

  final String startDate;
  final String endDate;
  final String customerUid;
  final String customerName;
  final String customerPhone;
  final String address;

  /// Only present on the all-plans view.
  final String planId;
  final String planName;

  const PlanSubscriber({
    required this.id,
    this.status = '',
    this.cadence = '',
    this.pricePaid = '',
    this.startDate = '',
    this.endDate = '',
    this.customerUid = '',
    this.customerName = '',
    this.customerPhone = '',
    this.address = '',
    this.planId = '',
    this.planName = '',
  });

  factory PlanSubscriber.fromMap(Map<String, dynamic> map) {
    return PlanSubscriber(
      id: map['id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      cadence: map['cadence']?.toString() ?? '',
      pricePaid: map['price_paid']?.toString() ?? '',
      startDate: map['start_date']?.toString() ?? '',
      endDate: map['end_date']?.toString() ?? '',
      customerUid: map['customer_uid']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? '',
      customerPhone: map['customer_phone']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      planId: map['plan_id']?.toString() ?? '',
      planName: map['plan_name']?.toString() ?? '',
    );
  }

  /// True for a subscription currently being delivered.
  bool get isActive => status.toLowerCase() == 'active';

  /// Name to show, falling back to the uid so a row is never blank.
  ///
  /// A nameless customer is a real possibility (signup can complete before a
  /// display name is set), and an empty list tile reads as a rendering bug
  /// rather than as missing data.
  String get displayName =>
      customerName.isNotEmpty ? customerName : customerUid;

  /// Cadence with the trailing "s", for compact display.
  String get cadenceLabel => cadence.isEmpty ? '' : '${cadence}s';
}
