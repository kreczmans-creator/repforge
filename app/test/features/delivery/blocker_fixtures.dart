import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';

OwnerBlocker testBlocker(
  String id, {
  BlockerWorkPackage wp = BlockerWorkPackage.wp8,
  BlockerPriority priority = BlockerPriority.medium,
  BlockerCategory category = BlockerCategory.ownerDecision,
  BlockerStatus status = BlockerStatus.awaitingOwner,
  BlockerAssignee assignee = BlockerAssignee.owner,
  List<String> dependencies = const [],
}) => OwnerBlocker(
  id: id,
  workPackage: wp,
  stage: 'S-$id',
  reference: 'REF-$id',
  title: 'Title $id',
  description: 'Description $id',
  category: category,
  priority: priority,
  initialStatus: status,
  assignee: assignee,
  whyBlocked: 'Why $id',
  actionRequired: 'Action $id',
  recommendation: 'Recommend $id',
  consequences: 'Consequences $id',
  dependencies: dependencies,
  evidence: const [
    BlockerEvidence('Delivery record', reference: 'D04 §7'),
    BlockerEvidence('CI run'),
  ],
  deliveryRecord: 'docs/delivery-record/$id.md',
);

/// Five entries across WP 8, WP 15 and WP 17.
final List<OwnerBlocker> testRegister = [
  testBlocker(
    'OB-A',
    priority: BlockerPriority.high,
    category: BlockerCategory.scopeApproval,
  ),
  testBlocker(
    'OB-B',
    priority: BlockerPriority.low,
    status: BlockerStatus.resolved,
  ),
  testBlocker(
    'OB-C',
    wp: BlockerWorkPackage.wp15,
    priority: BlockerPriority.high,
    category: BlockerCategory.physicalDeviceAction,
    status: BlockerStatus.open,
    assignee: BlockerAssignee.agent,
  ),
  testBlocker(
    'OB-D',
    wp: BlockerWorkPackage.wp17,
    category: BlockerCategory.independentVerification,
    status: BlockerStatus.awaitingExternalVerification,
    dependencies: ['OB-A'],
  ),
  testBlocker(
    'OB-E',
    wp: BlockerWorkPackage.wp17,
    priority: BlockerPriority.low,
    category: BlockerCategory.ownerAcceptance,
    status: BlockerStatus.inProgress,
  ),
];

/// A clock that moves forward one minute on every reading, so two saves get
/// distinct, ordered times.
final class AdvancingClock implements Clock {
  AdvancingClock(this._next);
  DateTime _next;

  @override
  DateTime now() {
    final value = _next;
    _next = _next.add(const Duration(minutes: 1));
    return value;
  }
}
