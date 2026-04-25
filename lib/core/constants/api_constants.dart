/// Central repository for all API endpoints used in the GitHub Store app.
class ApiConstants {
  ApiConstants._();

  // ── Base URLs ──────────────────────────────────────────────────────────
  static const String githubApiBaseUrl = 'https://api.github.com';
  static const String githubGraphQlUrl = 'https://api.github.com/graphql';
  static const String githubRawContentUrl = 'https://raw.githubusercontent.com';
  static const String githubWebUrl = 'https://github.com';

  // ── Rate Limiting ──────────────────────────────────────────────────────
  static const int maxRequestsPerHour = 5000;
  static const int maxRequestsPerHourUnauthenticated = 60;
  static const Duration requestCooldown = Duration(milliseconds: 100);

  // ── Authentication ─────────────────────────────────────────────────────
  static const String authUrl = '/authorizations';
  static const String userUrl = '/user';
  static const String userReposUrl = '/user/repos';
  static const String userStarredUrl = '/user/starred';
  static const String userSubscriptionsUrl = '/user/subscriptions';
  static const String userEmailsUrl = '/user/emails';

  // ── Device Flow ────────────────────────────────────────────────────────
  static const String deviceCodeUrl = '/login/device/code';
  static const String deviceTokenUrl = '/login/oauth/access_token';
  static const String clientId = 'github_store_desktop';

  // ── Repositories ───────────────────────────────────────────────────────
  static const String repositoriesUrl = '/repositories';
  static const String searchRepositoriesUrl = '/search/repositories';
  static const String trendingRepositoriesUrl = '/search/repositories';
  static const String repositoryUrl = '/repos/{owner}/{repo}';
  static const String repositoryReadmeUrl = '/repos/{owner}/{repo}/readme';
  static const String repositoryTopicsUrl = '/repos/{owner}/{repo}/topics';
  static const String repositoryLanguagesUrl = '/repos/{owner}/{repo}/languages';
  static const String repositoryContributorsUrl = '/repos/{owner}/{repo}/contributors';
  static const String repositoryReleasesUrl = '/repos/{owner}/{repo}/releases';
  static const String repositoryLatestReleaseUrl = '/repos/{owner}/{repo}/releases/latest';
  static const String repositoryForksUrl = '/repos/{owner}/{repo}/forks';
  static const String repositoryIssuesUrl = '/repos/{owner}/{repo}/issues';
  static const String repositoryPullRequestsUrl = '/repos/{owner}/{repo}/pulls';
  static const String repositoryStargazersUrl = '/repos/{owner}/{repo}/stargazers';
  static const String repositorySubscribersUrl = '/repos/{owner}/{repo}/subscribers';

  // ── Users / Profiles ───────────────────────────────────────────────────
  static const String usersUrl = '/users';
  static const String userProfileUrl = '/users/{username}';
  static const String userRepositoriesUrl = '/users/{username}/repos';
  static const String userStarredReposUrl = '/users/{username}/starred';
  static const String userFollowersUrl = '/users/{username}/followers';
  static const String userFollowingUrl = '/users/{username}/following';
  static const String userOrganizationsUrl = '/users/{username}/orgs';
  static const String userReceivedEventsUrl = '/users/{username}/received_events';

  // ── Search ─────────────────────────────────────────────────────────────
  static const String searchCodeUrl = '/search/code';
  static const String searchCommitsUrl = '/search/commits';
  static const String searchIssuesUrl = '/search/issues';
  static const String searchUsersUrl = '/search/users';
  static const String searchLabelsUrl = '/search/labels';

  // ── Releases & Downloads ───────────────────────────────────────────────
  static const String releasesUrl = '/repos/{owner}/{repo}/releases';
  static const String releaseByIdUrl = '/repos/{owner}/{repo}/releases/{releaseId}';
  static const String releaseAssetUrl = '/repos/{owner}/{repo}/releases/assets/{assetId}';
  static const String releaseLatestUrl = '/repos/{owner}/{repo}/releases/latest';
  static const String downloadReleaseUrl = 'https://github.com/{owner}/{repo}/releases/download/{tag}/{asset}';

  // ── Contents ───────────────────────────────────────────────────────────
  static const String contentsUrl = '/repos/{owner}/{repo}/contents/{path}';
  static const String rawContentBaseUrl = 'https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}';

  // ── Topics ─────────────────────────────────────────────────────────────
  static const String topicsUrl = '/topics/{topic}';
  static const String topicsRepositoriesUrl = '/search/repositories?q=topic:{topic}';

  // ── Notifications ──────────────────────────────────────────────────────
  static const String notificationsUrl = '/notifications';
  static const String notificationThreadUrl = '/notifications/threads/{threadId}';

  // ── Gists ──────────────────────────────────────────────────────────────
  static const String gistsUrl = '/gists';
  static const String userGistsUrl = '/users/{username}/gists';
  static const String gistUrl = '/gists/{gistId}';

  // ── GraphQL ────────────────────────────────────────────────────────────
  static const String graphqlSearchQuery = r'''
    query SearchRepositories($query: String!, $first: Int!, $after: String) {
      search(query: $query, type: REPOSITORY, first: $first, after: $after) {
        repositoryCount
        pageInfo {
          hasNextPage
          endCursor
        }
        edges {
          node {
            ... on Repository {
              id
              name
              nameWithOwner
              description
              url
              stargazerCount
              forkCount
              primaryLanguage {
                name
                color
              }
              owner {
                avatarUrl
                login
              }
              updatedAt
              isArchived
              isFork
              licenseInfo {
                name
                spdxId
              }
              releases(first: 1, orderBy: {field: CREATED_AT, direction: DESC}) {
                nodes {
                  tagName
                  name
                  publishedAt
                  releaseAssets(first: 5) {
                    nodes {
                      name
                      size
                      downloadUrl
                    }
                  }
                }
              }
              repositoryTopics(first: 10) {
                nodes {
                  topic {
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
  ''';

  static const String graphqlRepositoryDetail = r'''
    query RepositoryDetail($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        id
        name
        nameWithOwner
        description
        url
        homepageUrl
        stargazerCount
        forkCount
        diskUsage
        isArchived
        isFork
        isTemplate
        mirrorUrl
        createdAt
        updatedAt
        pushedAt
        primaryLanguage {
          name
          color
        }
        licenseInfo {
          name
          spdxId
        }
        owner {
          avatarUrl
          login
          ... on User {
            bio
            company
            location
            websiteUrl
            twitterUsername
          }
          ... on Organization {
            description
            location
            websiteUrl
            twitterUsername
          }
        }
        languages(first: 10, orderBy: {field: SIZE, direction: DESC}) {
          edges {
            size
            node {
              name
              color
            }
          }
        }
        releases(first: 5, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
            tagName
            name
            description
            isLatest
            isPrerelease
            publishedAt
            releaseAssets(first: 10) {
              nodes {
                name
                size
                contentType
                downloadUrl
              }
            }
          }
        }
        repositoryTopics(first: 15) {
          nodes {
            topic {
              name
            }
          }
        }
        defaultBranchRef {
          name
        }
        watchers {
          totalCount
        }
      }
    }
  ''';

  // ── GitHub Store Backend (custom) ─────────────────────────────────────
  static const String storeApiBaseUrl = 'https://store-api.githubstore.app/v1';
  static const String storeAppsList = '/apps';
  static const String storeAppDetail = '/apps/{appId}';
  static const String storeAppVersions = '/apps/{appId}/versions';
  static const String storeAppReviews = '/apps/{appId}/reviews';
  static const String storeCategories = '/categories';
  static const String storeFeatured = '/featured';
  static const String storeTrending = '/trending';
  static const String storeInstallAttestation = '/apps/{appId}/attest';

  // ── Headers ────────────────────────────────────────────────────────────
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/vnd.github.v3+json',
    'Accept-Encoding': 'gzip',
    'User-Agent': 'GitHubStore-Desktop/1.0',
  };

  static Map<String, String> authHeaders(String token) {
    return {
      ...defaultHeaders,
      'Authorization': 'Bearer $token',
    };
  }

  // ── Helper Methods ─────────────────────────────────────────────────────
  static String repositoryPath(String owner, String repo) => '$owner/$repo';
  static String repositoryUrlPath(String owner, String repo) =>
      repositoryUrl.replaceAll('{owner}', owner).replaceAll('{repo}', repo);
  static String userProfilePath(String username) => '/users/$username';
  static String releaseDownloadUrl({
    required String owner,
    required String repo,
    required String tag,
    required String asset,
  }) =>
      downloadReleaseUrl
          .replaceAll('{owner}', owner)
          .replaceAll('{repo}', repo)
          .replaceAll('{tag}', tag)
          .replaceAll('{asset}', asset);
}
