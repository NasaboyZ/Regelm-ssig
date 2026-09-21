/// Stable codes are persisted; German labels can change independently.
class TrackingOption {
  const TrackingOption(this.code, this.label);
  final String code;
  final String label;
}

class TrackingGroup {
  const TrackingGroup(this.id, this.title, this.options, {this.single = false});
  final String id;
  final String title;
  final List<TrackingOption> options;
  final bool single;
}

class TrackingCategory {
  const TrackingCategory(this.id, this.title, this.groups);
  final String id;
  final String title;
  final List<TrackingGroup> groups;
}

const trackingCategories = [
  TrackingCategory('bleeding', 'Blutung', [
    TrackingGroup('flow', 'Stärke', [
      TrackingOption('spotting', 'Schmierblutung'),
      TrackingOption('light', 'Leichte Blutung'),
      TrackingOption('medium', 'Mittlere Blutung'),
      TrackingOption('heavy', 'Starke Blutung'),
    ], single: true),
    TrackingGroup('clots', 'Gerinnsel', [
      TrackingOption('small', 'Kleine Gerinnsel'),
      TrackingOption('big', 'Grosse Gerinnsel'),
    ]),
    TrackingGroup('products', 'Produkte', [
      TrackingOption('reusable_pad', 'Wiederverwendbare Binde'),
      TrackingOption('disposable_pad', 'Einweg-Binde'),
      TrackingOption('tampon', 'Tampon'),
      TrackingOption('cup', 'Menstruationstasse'),
      TrackingOption('disc', 'Menstruationsscheibe'),
      TrackingOption('sponge', 'Menstruationsschwamm'),
      TrackingOption('underwear', 'Periodenunterwäsche'),
      TrackingOption('liner', 'Slipeinlage'),
    ]),
  ]),
  TrackingCategory('symptoms', 'Körperliche Symptome', [
    TrackingGroup('symptoms', '', [
      TrackingOption('acne', 'Akne'),
      TrackingOption('bloating', 'Blähungen'),
      TrackingOption('cramps', 'Krämpfe'),
      TrackingOption('cravings', 'Heisshunger'),
      TrackingOption('discharge', 'Ausfluss'),
      TrackingOption('fatigue', 'Müdigkeit'),
      TrackingOption('fever', 'Fieber'),
      TrackingOption('headache', 'Kopfschmerzen'),
      TrackingOption('itchiness', 'Juckreiz'),
      TrackingOption('nausea', 'Übelkeit'),
      TrackingOption('severe_pain', 'Starke Schmerzen'),
      TrackingOption('stomachache', 'Bauchschmerzen'),
      TrackingOption('tender_chest', 'Empfindliche Brust'),
      TrackingOption('ovulation', 'Eisprung'),
    ]),
  ]),
  TrackingCategory('sexual', 'Sexuelle Aktivität', [
    TrackingGroup('sti_protection', 'Schutz vor STIs', [
      TrackingOption('protected', 'Geschützt'),
      TrackingOption('unprotected', 'Ungeschützt'),
    ], single: true),
    TrackingGroup('pregnancy_protection', 'Schutz vor Schwangerschaft', [
      TrackingOption('protected', 'Geschützt'),
      TrackingOption('unprotected', 'Ungeschützt'),
    ], single: true),
    TrackingGroup('activities', 'Weitere Aktivitäten', [
      TrackingOption('masturbation', 'Masturbation'),
      TrackingOption('oral', 'Oralsex'),
      TrackingOption('orgasm', 'Orgasmus'),
      TrackingOption('toys', 'Sexspielzeug'),
      TrackingOption('anal', 'Analsex'),
    ]),
  ]),
  TrackingCategory('contraception', 'Verhütung', [
    TrackingGroup('pill', 'Tägliche Methoden · Pille', [
      TrackingOption('took', 'Eingenommen'),
      TrackingOption('missed', 'Vergessen'),
      TrackingOption('double', 'Doppelte Einnahme'),
    ], single: true),
    TrackingGroup('daily_methods', 'Weitere tägliche Methoden', [
      TrackingOption('condom', 'Kondom'),
      TrackingOption('diaphragm', 'Diaphragma'),
      TrackingOption('cervical_cap', 'Portiokappe'),
      TrackingOption('sponge', 'Verhütungsschwamm'),
      TrackingOption('spermicide', 'Spermizid'),
      TrackingOption('pull_out', 'Coitus interruptus'),
      TrackingOption('emergency', 'Notfallverhütung'),
    ]),
    TrackingGroup('iud', 'Langfristige Methoden · Spirale', [
      TrackingOption('new', 'Neu'),
      TrackingOption('checked_strings', 'Fäden kontrolliert'),
      TrackingOption('removed', 'Entfernt'),
    ]),
    TrackingGroup('implant', 'Implantat', [
      TrackingOption('new', 'Neu'),
      TrackingOption('removed', 'Entfernt'),
    ]),
    TrackingGroup('patch', 'Pflaster', [
      TrackingOption('new', 'Neu'),
      TrackingOption('removed', 'Entfernt'),
    ]),
    TrackingGroup('ring', 'Ring', [
      TrackingOption('new', 'Neu'),
      TrackingOption('removed', 'Entfernt'),
    ]),
    TrackingGroup('shot', 'Spritze', [TrackingOption('shot', 'Erhalten')]),
  ]),
  TrackingCategory('tests', 'Tests', [
    TrackingGroup('sti_test', 'STI-Test', [
      TrackingOption('positive', 'Positiv'),
      TrackingOption('negative', 'Negativ'),
    ], single: true),
    TrackingGroup('pregnancy_test', 'Schwangerschaftstest', [
      TrackingOption('positive', 'Positiv'),
      TrackingOption('negative', 'Negativ'),
    ], single: true),
  ]),
  TrackingCategory('mood', 'Stimmung', [
    TrackingGroup('mood', '', [
      TrackingOption('calm', 'Ruhig'),
      TrackingOption('stressed', 'Gestresst'),
      TrackingOption('unmotivated', 'Unmotiviert'),
      TrackingOption('sad', 'Traurig'),
      TrackingOption('happy', 'Glücklich'),
      TrackingOption('irritable', 'Reizbar'),
      TrackingOption('angry', 'Wütend'),
      TrackingOption('energetic', 'Energiegeladen'),
      TrackingOption('horny', 'Erregt'),
    ]),
  ]),
  TrackingCategory('measurements', 'Temperatur & Gewicht', []),
  TrackingCategory('appointments', 'Termine', []),
  TrackingCategory('notes', 'Notizen', []),
];
