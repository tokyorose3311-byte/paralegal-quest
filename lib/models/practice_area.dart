import 'package:flutter/material.dart';

/// A practice area, as stored in the Firestore `practiceAreas` collection.
///
/// Each document's ID *is* the practice area key (e.g. `family_law`) --
/// this is the exact same string used to tag documents in the `questions`
/// collection's `practiceArea` field (see QuestionService.getByPracticeArea
/// and scripts/bulk_upload/bulk_upload_questions.js, which is unaffected by
/// this collection and keeps tagging questions the same way it always has).
///
/// This is the single source of truth for which practice areas appear on
/// the setup screen's menu and whether they're playable ("active") or shown
/// as a locked "Coming soon" card. Unlocking a new area (or relocking one)
/// is now just a Firestore write -- via the Admin panel's toggle switch, or
/// directly in the Firebase console -- with NO app rebuild required.
class PracticeAreaDoc {
  /// Firestore document id, e.g. 'civil_litigation'. Also the exact string
  /// used to tag/query the `questions` collection for this area.
  final String id;
  final String displayName;
  final bool active;

  /// A loose icon-name key (matches Tabler icon naming, e.g. 'scale',
  /// 'users', 'bank') describing which icon to show on the menu tile. See
  /// [practiceAreaIcon] / [practiceAreaEmoji] below for how this is
  /// rendered -- the app doesn't depend on the Tabler icon package itself,
  /// so any reasonable name works and unknown names fall back gracefully.
  final String icon;

  /// Optional total question count for this area, shown in the tile's
  /// subtitle (e.g. "60 questions") when the area is active. Purely
  /// cosmetic -- not used to drive gameplay logic.
  final int? questionCount;

  /// Controls display order on the setup screen's practice-area menu,
  /// ascending (lower numbers first).
  final int order;

  const PracticeAreaDoc({
    required this.id,
    required this.displayName,
    required this.active,
    required this.icon,
    required this.order,
    this.questionCount,
  });

  factory PracticeAreaDoc.fromDoc(String id, Map<String, dynamic> d) {
    return PracticeAreaDoc(
      id: id,
      displayName: (d['displayName'] as String?) ?? id,
      active: (d['active'] as bool?) ?? false,
      icon: (d['icon'] as String?) ?? 'scale',
      questionCount: (d['questionCount'] as num?)?.toInt(),
      order: (d['order'] as num?)?.toInt() ?? 999,
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'active': active,
    'icon': icon,
    'order': order,
    if (questionCount != null) 'questionCount': questionCount,
  };

  PracticeAreaDoc copyWith({bool? active}) => PracticeAreaDoc(
    id: id,
    displayName: displayName,
    active: active ?? this.active,
    icon: icon,
    order: order,
    questionCount: questionCount,
  );
}

/// The practice area key used before the very first Firestore fetch
/// completes, or if it fails (offline, etc). Keeps existing behavior
/// (Civil Litigation) working even without network access.
const String kDefaultPracticeAreaKey = 'civil_litigation';

/// Local fallback practice areas, used only if the live Firestore
/// `practiceAreas` collection can't be reached or is empty (e.g. offline on
/// first launch, before seeding). Mirrors whatever was most recently seeded
/// so the menu never renders blank. Kept intentionally small/simple -- the
/// live Firestore collection is the real source of truth going forward.
final List<PracticeAreaDoc> kLocalFallbackPracticeAreas = [
  const PracticeAreaDoc(
    id: 'civil_litigation',
    displayName: 'Civil Litigation',
    active: true,
    icon: 'scale',
    order: 1,
  ),
  const PracticeAreaDoc(
    id: 'family_law',
    displayName: 'Family Law',
    active: true,
    icon: 'users',
    order: 2,
  ),
  const PracticeAreaDoc(
    id: 'estate_law',
    displayName: 'Estate Law',
    active: false,
    icon: 'bank',
    order: 3,
  ),
  const PracticeAreaDoc(
    id: 'criminal_law',
    displayName: 'Criminal Law',
    active: false,
    icon: 'police-badge',
    order: 4,
  ),
  const PracticeAreaDoc(
    id: 'consumer_law',
    displayName: 'Consumer Law',
    active: false,
    icon: 'shopping-cart',
    order: 5,
  ),
];

/// Loose mapping from the Tabler-style icon name stored in each Firestore
/// `practiceAreas` document to a bundled Material icon. This avoids adding
/// a new icon-font package as a dependency (keeping the pinned/locked
/// dependency set untouched) while still letting new practice areas pick
/// any reasonable icon name from the Admin/Firebase console side. Unknown
/// names fall back to a gavel icon.
IconData practiceAreaIcon(String icon) {
  switch (icon) {
    case 'scale':
    case 'gavel':
      return Icons.gavel;
    case 'users':
    case 'family':
      return Icons.family_restroom;
    case 'bank':
    case 'building-bank':
      return Icons.account_balance;
    case 'scroll':
    case 'file-text':
      return Icons.description;
    case 'police-badge':
    case 'shield':
    case 'car-4wd':
      return Icons.local_police;
    case 'shopping-cart':
      return Icons.shopping_cart;
    case 'band-aid':
    case 'bandage':
    case 'first-aid-kit':
      return Icons.healing;
    default:
      return Icons.gavel;
  }
}

/// Emoji equivalent of [practiceAreaIcon], for screens (like the setup
/// screen's ChoiceCard tiles) that render an emoji glyph rather than an
/// IconData widget, to match the rest of the app's existing menu style.
String practiceAreaEmoji(String icon) {
  switch (icon) {
    case 'scale':
    case 'gavel':
      return '⚖️';
    case 'users':
    case 'family':
      return '👨‍👩‍👧';
    case 'bank':
    case 'building-bank':
      return '🏦';
    case 'scroll':
    case 'file-text':
      return '📜';
    case 'police-badge':
    case 'shield':
    case 'car-4wd':
      return '🚔';
    case 'shopping-cart':
      return '🛒';
    case 'band-aid':
    case 'bandage':
    case 'first-aid-kit':
      return '🩹';
    default:
      return '⚖️';
  }
}
