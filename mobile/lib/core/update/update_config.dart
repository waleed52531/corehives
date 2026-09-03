class UpdateConfig {
  // TODO: Set this to your GitHub username or organization.
  static const String githubOwner = 'waleed52531';

  // TODO: Set this to the GitHub repository that hosts CoreHives releases.
  static const String githubRepo = 'corehives';

  // Public GitHub repositories can be checked and downloaded without a token.
  // Do not embed a GitHub Personal Access Token in this app for private repos.
  static const String releaseApiBaseUrl = 'https://api.github.com';
  static const String rawContentBaseUrl = 'https://raw.githubusercontent.com';
  static const String updatePolicyBranch = 'main';
  static const String updatePolicyPath = 'update.json';

  static Uri get latestReleaseUri => Uri.parse(
        '$releaseApiBaseUrl/repos/$githubOwner/$githubRepo/releases/latest',
      );

  static Uri get updatePolicyUri => Uri.parse(
        '$rawContentBaseUrl/$githubOwner/$githubRepo/$updatePolicyBranch/$updatePolicyPath',
      );
}
