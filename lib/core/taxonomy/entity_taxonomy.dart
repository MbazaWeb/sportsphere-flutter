/// Composable Playify taxonomy. Do not collapse into one mega-enum.
class TaxonomyTerm {
  const TaxonomyTerm(this.domain, this.slug, this.label, [this.parentSlug]);
  final String domain;
  final String slug;
  final String label;
  final String? parentSlug;
}

abstract final class Taxonomy {
  static const competitiveLevel = [
    TaxonomyTerm('competitive_level', 'professional', 'Professional'),
    TaxonomyTerm('competitive_level', 'semi_professional', 'Semi-professional'),
    TaxonomyTerm('competitive_level', 'amateur', 'Amateur'),
    TaxonomyTerm('competitive_level', 'recreational', 'Recreational'),
  ];

  static const organizationType = [
    TaxonomyTerm('organization_type', 'club', 'Club'),
    TaxonomyTerm('organization_type', 'academy', 'Academy'),
    TaxonomyTerm('organization_type', 'university', 'University'),
    TaxonomyTerm('organization_type', 'college', 'College'),
    TaxonomyTerm('organization_type', 'school', 'School'),
    TaxonomyTerm('organization_type', 'community', 'Community'),
    TaxonomyTerm('organization_type', 'company', 'Company'),
    TaxonomyTerm('organization_type', 'national_team', 'National team'),
  ];

  static const gender = [
    TaxonomyTerm('gender', 'men', 'Men'),
    TaxonomyTerm('gender', 'women', 'Women'),
    TaxonomyTerm('gender', 'mixed', 'Mixed'),
    TaxonomyTerm('gender', 'open', 'Open'),
  ];

  static const ageCategory = [
    TaxonomyTerm('age_category', 'u15', 'U15'),
    TaxonomyTerm('age_category', 'u17', 'U17'),
    TaxonomyTerm('age_category', 'u20', 'U20'),
    TaxonomyTerm('age_category', 'u23', 'U23'),
    TaxonomyTerm('age_category', 'senior', 'Senior'),
    TaxonomyTerm('age_category', 'veteran', 'Veteran'),
  ];

  static const geographicScope = [
    TaxonomyTerm('geographic_scope', 'local', 'Local'),
    TaxonomyTerm('geographic_scope', 'regional', 'Regional'),
    TaxonomyTerm('geographic_scope', 'national', 'National'),
    TaxonomyTerm('geographic_scope', 'continental', 'Continental'),
    TaxonomyTerm('geographic_scope', 'international', 'International'),
  ];

  static const sports = [
    TaxonomyTerm('sport', 'football', 'Football'),
    TaxonomyTerm('sport', 'basketball', 'Basketball'),
    TaxonomyTerm('sport', 'athletics', 'Athletics'),
    TaxonomyTerm('sport', 'netball', 'Netball'),
    TaxonomyTerm('sport', 'volleyball', 'Volleyball'),
  ];

  static const competitionType = [
    TaxonomyTerm('competition_type', 'league', 'League'),
    TaxonomyTerm('competition_type', 'cup', 'Cup'),
    TaxonomyTerm('competition_type', 'tournament', 'Tournament'),
    TaxonomyTerm('competition_type', 'friendly', 'Friendly'),
  ];
}

class TeamTaxonomy {
  const TeamTaxonomy({
    this.competitiveLevel = 'professional',
    this.organizationType = 'club',
    this.gender = 'men',
    this.ageCategory = 'senior',
    this.geographicScope = 'national',
    this.sportSlug = 'football',
    this.sportVariant = 'association_football',
  });

  final String competitiveLevel;
  final String organizationType;
  final String gender;
  final String ageCategory;
  final String geographicScope;
  final String sportSlug;
  final String sportVariant;
}

class PlayerTaxonomy {
  const PlayerTaxonomy({
    this.playerType = 'professional',
    this.gender,
    this.ageCategory = 'senior',
    this.careerLevel = 'professional',
    this.sportSlug = 'football',
    this.position,
  });

  final String playerType;
  final String? gender;
  final String ageCategory;
  final String careerLevel;
  final String sportSlug;
  final String? position;
}
