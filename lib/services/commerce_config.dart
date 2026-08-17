// ===================== COMMERCE CONFIG — edit these =====================
// Centralized Stripe Payment Link URLs, shared by setup_screen.dart (pricing
// cards) and student_account_panel.dart (the Individual Pilot registration
// form's "pay $20" shortcut link) -- kept in one file to avoid a circular
// import between those two.
const String kStripeSeasonUrl =
    "https://buy.stripe.com/3cI14p64O979cXO8kcdMI00";
const String kStripeSchoolUrl =
    "https://buy.stripe.com/aFa00l0Ku1EH7Du9ogdMI02";
const String kStripeClassroomUrl =
    "https://buy.stripe.com/3cI28t0Ku0AD8HygQIdMI01";
// Individual Pilot -- $20 promotional price for early testers giving
// feedback. Option A (manual): the admin sees the Stripe payment and
// manually issues a one-time access code from the Admin > INDIVIDUAL PILOT
// CODES panel, then emails it to the student. There is no webhook auto-
// generating codes for this plan (unlike School/Classroom/Season above).
// TODO: replace with your real Stripe Payment Link for the $20 pilot price.
const String kStripePilotUrl =
    "https://buy.stripe.com/4gM14peBk2ILf5WfMEdMI03";
// =========================================================================
