/// The practice areas a game can be played in. Each maps to a Firestore
/// `practiceArea` tag on documents in the `questions` collection (see
/// data/question_banks/ and scripts/bulk_upload/ for how question banks are
/// tagged and uploaded).
///
/// Only [civilLitigation] and [familyLaw] are playable today. The others are
/// declared here so the "Coming soon" cards on the setup screen have a
/// consistent source of truth, and so wiring up a new practice area later is
/// just: add a value here, tag its Firestore docs with the matching key, add
/// a ChoiceCard on the setup screen -- no other plumbing changes needed.
enum PracticeArea {
  civilLitigation,
  familyLaw,
  estateLaw,
  willsAndProbate,
  criminalLaw,
  consumerLaw,
  tortLaw,
}

/// The exact string stored in each question document's `practiceArea`
/// field in Firestore. Must match scripts/bulk_upload/ and the values used
/// when tagging the existing Civil Litigation question bank.
String practiceAreaKey(PracticeArea a) {
  switch (a) {
    case PracticeArea.civilLitigation:
      return 'civil_litigation';
    case PracticeArea.familyLaw:
      return 'family_law';
    case PracticeArea.estateLaw:
      return 'estate_law';
    case PracticeArea.willsAndProbate:
      return 'wills_and_probate';
    case PracticeArea.criminalLaw:
      return 'criminal_law';
    case PracticeArea.consumerLaw:
      return 'consumer_law';
    case PracticeArea.tortLaw:
      return 'tort_law';
  }
}

/// Human-readable label shown in the UI.
String practiceAreaLabel(PracticeArea a) {
  switch (a) {
    case PracticeArea.civilLitigation:
      return 'Civil Litigation';
    case PracticeArea.familyLaw:
      return 'Family Law';
    case PracticeArea.estateLaw:
      return 'Estate Law';
    case PracticeArea.willsAndProbate:
      return 'Wills & Probate';
    case PracticeArea.criminalLaw:
      return 'Criminal Law';
    case PracticeArea.consumerLaw:
      return 'Consumer Law';
    case PracticeArea.tortLaw:
      return 'Tort Law';
  }
}

/// Practice areas with a live, playable question bank in Firestore today.
/// Everything else in the enum renders as a locked "Coming soon" card.
const Set<PracticeArea> kPlayablePracticeAreas = {
  PracticeArea.civilLitigation,
  PracticeArea.familyLaw,
};
