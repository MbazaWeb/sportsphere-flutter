// Allowed admin profile fields; synchronized with admin role forms.
export const roleProfiles: Record<string, {table: string; fields: string[]}> = {
  "player": {
    "table": "PlayerProfile",
    "fields": [
      "position",
      "secondaryPosition",
      "preferredFoot",
      "jerseyNumber",
      "height",
      "weight",
      "nationality",
      "playerType",
      "careerStatus",
      "currentClub",
      "contractUntil"
    ]
  },
  "coach": {
    "table": "CoachProfile",
    "fields": [
      "coachingRole",
      "currentTeam",
      "license",
      "nationality",
      "yearsCoaching",
      "matchesManaged",
      "wins",
      "preferredFormation",
      "playingPhilosophy"
    ]
  },
  "team": {
    "table": "TeamProfile",
    "fields": [
      "nickname",
      "foundedYear",
      "country",
      "city",
      "stadium",
      "capacity",
      "league",
      "coach"
    ]
  },
  "scout": {
    "table": "ScoutProfile",
    "fields": [
      "scoutType",
      "organization",
      "geographicCoverage",
      "sportsCovered",
      "yearsExperience"
    ]
  },
  "agent": {
    "table": "AgentProfile",
    "fields": [
      "agentType",
      "agency",
      "license",
      "federation"
    ]
  },
  "journalist": {
    "table": "JournalistProfile",
    "fields": [
      "publication",
      "beat",
      "location",
      "yearsActive"
    ]
  },
  "creator": {
    "table": "CreatorProfile",
    "fields": [
      "creatorType",
      "platforms",
      "niche",
      "followers"
    ]
  },
  "analyst": {
    "table": "AnalystProfile",
    "fields": [
      "analystType",
      "organization",
      "expertise"
    ]
  },
  "commentator": {
    "table": "CommentatorProfile",
    "fields": [
      "commentatorType",
      "broadcaster",
      "languages",
      "sports"
    ]
  },
  "official": {
    "table": "OfficialProfile",
    "fields": [
      "officialType",
      "federation",
      "license",
      "yearsActive"
    ]
  },
  "academy": {
    "table": "AcademyProfile",
    "fields": [
      "academyName",
      "parentOrg",
      "location",
      "foundedYear"
    ]
  },
  "league": {
    "table": "LeagueProfile",
    "fields": [
      "leagueName",
      "country",
      "division",
      "currentSeason"
    ]
  },
  "competition": {
    "table": "CompetitionProfile",
    "fields": [
      "competitionName",
      "season",
      "organizer",
      "country"
    ]
  },
  "organization": {
    "table": "OrganizationProfile",
    "fields": [
      "orgType",
      "country",
      "headquarters",
      "foundedYear"
    ]
  },
  "media_broadcast": {
    "table": "MediaBroadcastProfile",
    "fields": [
      "outlet",
      "platform",
      "coverage"
    ]
  },
  "community": {
    "table": "CommunityProfile",
    "fields": [
      "communityName",
      "communityType",
      "location",
      "supportedTeam",
      "description"
    ]
  },
  "business": {
    "table": "BusinessProfile",
    "fields": [
      "companyName",
      "industry",
      "headquarters",
      "website"
    ]
  },
  "sponsor": {
    "table": "SponsorProfile",
    "fields": [
      "brand",
      "industry",
      "website"
    ]
  },
  "commercial_partner": {
    "table": "CommercialPartnerProfile",
    "fields": [
      "partnerType",
      "brand",
      "sportsCategory",
      "website"
    ]
  },
  "venue": {
    "table": "VenueProfile",
    "fields": [
      "venueName",
      "venueType",
      "location",
      "capacity"
    ]
  },
  "support_staff": {
    "table": "SupportStaffProfile",
    "fields": [
      "staffRole",
      "organization",
      "specialty"
    ]
  },
  "moderator": {
    "table": "ModeratorProfile",
    "fields": [
      "scope",
      "communities"
    ]
  }
}
