import '../models/question.dart';

final List<QuizQuestion> kQuestions = [
  QuizQuestion(
    category: "Jurisdiction",
    type: QuestionType.mountain,
    question:
        "Which court has original jurisdiction over a case between a citizen of Texas and a citizen of California where the amount in controversy exceeds \$75,000?",
    options: [
      "State court",
      "Federal district court",
      "Supreme Court",
      "Court of appeals",
    ],
    correctIndex: 1,
    explanation:
        "This is diversity jurisdiction — different states plus over \$75,000 lets a federal district court hear it.",
  ),
  QuizQuestion(
    category: "Statutes",
    type: QuestionType.cave,
    question:
        "The official compilation of the general and permanent statutes of the United States is known as the:",
    options: [
      "Federal Rules of Civil Procedure",
      "United States Code (U.S.C.)",
      "Code of Federal Regulations (C.F.R.)",
      "U.S. Constitution",
    ],
    correctIndex: 1,
    explanation:
        "The U.S.C. organizes federal statutes by subject into titles.",
  ),
  QuizQuestion(
    category: "Civil Litigation",
    type: QuestionType.mountain,
    question:
        "What document officially starts a civil lawsuit by stating the plaintiff's claims?",
    options: [
      "The answer",
      "The complaint (or petition)",
      "The verdict",
      "The subpoena",
    ],
    correctIndex: 1,
    explanation:
        "The complaint (called a petition in Texas) lays out the claims and starts the case.",
  ),
  QuizQuestion(
    category: "Civil Litigation",
    type: QuestionType.mountain,
    question:
        "The defendant's formal written response to the complaint is called the:",
    options: ["Answer", "Motion", "Brief", "Deposition"],
    correctIndex: 0,
    explanation:
        "The answer admits or denies the allegations and may raise defenses.",
  ),
  QuizQuestion(
    category: "Court Procedures",
    type: QuestionType.cave,
    question:
        "The pretrial phase where both sides exchange evidence and information is called:",
    options: ["Arraignment", "Discovery", "Voir dire", "Allocution"],
    correctIndex: 1,
    explanation:
        "Discovery includes interrogatories, depositions, and document requests.",
  ),
  QuizQuestion(
    category: "Court Procedures",
    type: QuestionType.cave,
    question:
        "Written questions sent to an opposing party that must be answered in writing under oath are:",
    options: ["Interrogatories", "Affidavits", "Pleadings", "Citations"],
    correctIndex: 0,
    explanation:
        "Interrogatories are a written discovery tool answered under oath.",
  ),
  QuizQuestion(
    category: "Evidence",
    type: QuestionType.cave,
    question:
        "Sworn out-of-court testimony taken before trial, recorded by a court reporter, is a:",
    options: ["Affidavit", "Deposition", "Stipulation", "Demurrer"],
    correctIndex: 1,
    explanation:
        "A deposition captures live testimony before trial and can be used later.",
  ),
  QuizQuestion(
    category: "Jurisdiction",
    type: QuestionType.mountain,
    question:
        "A court's authority over the specific people involved in a lawsuit is called:",
    options: [
      "Subject matter jurisdiction",
      "Personal jurisdiction",
      "Appellate jurisdiction",
      "Venue",
    ],
    correctIndex: 1,
    explanation:
        "Personal (in personam) jurisdiction is power over the parties themselves.",
  ),
  QuizQuestion(
    category: "Jurisdiction",
    type: QuestionType.mountain,
    question:
        "A court's authority to hear a particular type of case is called:",
    options: [
      "Personal jurisdiction",
      "Subject matter jurisdiction",
      "Venue",
      "Standing",
    ],
    correctIndex: 1,
    explanation:
        "Subject matter jurisdiction concerns the kind of dispute the court may decide.",
  ),
  QuizQuestion(
    category: "Court Procedures",
    type: QuestionType.mountain,
    question: "Venue refers to:",
    options: [
      "Whether the court can decide the type of case",
      "The proper geographic location for the trial",
      "The amount in controversy",
      "The standard of proof",
    ],
    correctIndex: 1,
    explanation:
        "Venue is about which court location is proper, not the court's power to hear the case.",
  ),
  QuizQuestion(
    category: "Court Procedures",
    type: QuestionType.cave,
    question:
        "A request asking the court to decide the case without a full trial because there is no genuine dispute of material fact is a motion for:",
    options: ["Summary judgment", "Continuance", "Mistrial", "Default"],
    correctIndex: 0,
    explanation:
        "Summary judgment resolves a case (or issue) when the facts are not genuinely disputed.",
  ),
  QuizQuestion(
    category: "Civil Litigation",
    type: QuestionType.mountain,
    question: "In most civil cases, the plaintiff must prove the claim by a:",
    options: [
      "Preponderance of the evidence",
      "Beyond a reasonable doubt",
      "Clear and convincing evidence",
      "Probable cause",
    ],
    correctIndex: 0,
    explanation:
        "Civil cases use 'more likely than not' — the preponderance standard.",
  ),
  QuizQuestion(
    category: "Codes & Rules",
    type: QuestionType.cave,
    question: "Codified rules issued by federal agencies are published in the:",
    options: [
      "United States Code",
      "Code of Federal Regulations (C.F.R.)",
      "Federal Register only",
      "Restatement of the Law",
    ],
    correctIndex: 1,
    explanation:
        "The C.F.R. is the codified body of federal agency regulations.",
  ),
  QuizQuestion(
    category: "Federal Laws",
    type: QuestionType.mountain,
    question:
        "The doctrine that courts should follow precedent set by prior decisions is called:",
    options: ["Res judicata", "Stare decisis", "Habeas corpus", "Mens rea"],
    correctIndex: 1,
    explanation:
        "Stare decisis means 'to stand by things decided' — following precedent.",
  ),
  QuizQuestion(
    category: "Civil Litigation",
    type: QuestionType.mountain,
    question:
        "A claim brought by the defendant back against the plaintiff in the same lawsuit is a:",
    options: [
      "Cross-claim",
      "Counterclaim",
      "Third-party claim",
      "Class action",
    ],
    correctIndex: 1,
    explanation:
        "A counterclaim is the defendant's own claim against the plaintiff.",
  ),
  QuizQuestion(
    category: "Civil Litigation",
    type: QuestionType.mountain,
    question: "The party who initiates a civil lawsuit is the:",
    options: ["Defendant", "Plaintiff", "Respondent", "Bailiff"],
    correctIndex: 1,
    explanation: "The plaintiff brings the suit; the defendant responds to it.",
  ),
  QuizQuestion(
    category: "Court Procedures",
    type: QuestionType.cave,
    question:
        "Formally delivering a summons and complaint to give a party legal notice is called:",
    options: ["Service of process", "Filing", "Docketing", "Arraignment"],
    correctIndex: 0,
    explanation:
        "Service of process gives the defendant required notice of the suit.",
  ),
  QuizQuestion(
    category: "Evidence",
    type: QuestionType.cave,
    question: "Hearsay is generally defined as:",
    options: [
      "Any spoken testimony",
      "An out-of-court statement offered to prove the truth of what it asserts",
      "Expert opinion testimony",
      "Physical evidence",
    ],
    correctIndex: 1,
    explanation:
        "Hearsay is an out-of-court statement offered for its truth, and is generally inadmissible unless an exception applies.",
  ),
  QuizQuestion(
    category: "Civil Litigation",
    type: QuestionType.mountain,
    question: "The deadline by which a lawsuit must be filed is set by the:",
    options: [
      "Statute of limitations",
      "Burden of proof",
      "Rules of evidence",
      "Standard of review",
    ],
    correctIndex: 0,
    explanation:
        "The statute of limitations bars claims filed after the deadline.",
  ),
  QuizQuestion(
    category: "Codes & Rules",
    type: QuestionType.cave,
    question:
        "The rules that govern procedure in U.S. federal trial courts are the:",
    options: [
      "Federal Rules of Civil Procedure",
      "Model Rules of Professional Conduct",
      "Federal Rules of Evidence",
      "Bluebook",
    ],
    correctIndex: 0,
    explanation:
        "The FRCP govern how civil cases proceed in federal district courts.",
  ),
];
