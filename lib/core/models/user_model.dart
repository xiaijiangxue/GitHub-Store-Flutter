import 'dart:convert';

/// Represents a GitHub user profile.
class UserModel {
  UserModel({
    required this.id,
    required this.login,
    this.name,
    this.avatarUrl,
    this.bio,
    this.publicRepos = 0,
    this.followers = 0,
    this.following = 0,
    this.company,
    this.location,
    this.blog,
    this.twitterUsername,
    this.email,
    this.hireable,
    this.createdAt,
    this.updatedAt,
    this.type = 'User',
    this.isPro = false,
    this.totalPrivateRepos = 0,
    this.ownedPrivateRepos = 0,
    this.diskUsage,
    this.collaborators,
    this.twoFactorAuthentication,
    this.plan,
    this.url,
    this.htmlUrl,
    this.followersUrl,
    this.followingUrl,
    this.gistsUrl,
    this.starredUrl,
    this.subscriptionsUrl,
    this.organizationsUrl,
    this.reposUrl,
    this.eventsUrl,
    this.receivedEventsUrl,
  });

  final int id;
  final String login;
  final String? name;
  final String? avatarUrl;
  final String? bio;
  final int publicRepos;
  final int followers;
  final int following;
  final String? company;
  final String? location;
  final String? blog;
  final String? twitterUsername;
  final String? email;
  final bool? hireable;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String type;
  final bool isPro;
  final int totalPrivateRepos;
  final int ownedPrivateRepos;
  final int? diskUsage;
  final int? collaborators;
  final bool? twoFactorAuthentication;
  final String? plan;
  final String? url;
  final String? htmlUrl;
  final String? followersUrl;
  final String? followingUrl;
  final String? gistsUrl;
  final String? starredUrl;
  final String? subscriptionsUrl;
  final String? organizationsUrl;
  final String? reposUrl;
  final String? eventsUrl;
  final String? receivedEventsUrl;

  /// Display name: falls back to login if name is null.
  String get displayName => name?.isNotEmpty == true ? name! : login;

  /// Formatted follower count.
  String get formattedFollowers => _formatCount(followers);

  /// Formatted following count.
  String get formattedFollowing => _formatCount(following);

  /// Whether the user has a bio.
  bool get hasBio => bio != null && bio!.isNotEmpty;

  /// Whether the user has a location.
  bool get hasLocation => location != null && location!.isNotEmpty;

  /// Whether the user has a company.
  bool get hasCompany => company != null && company!.isNotEmpty;

  /// Whether the user has a blog/website.
  bool get hasBlog => blog != null && blog!.isNotEmpty;

  /// Whether this user is an organization.
  bool get isOrganization => type == 'Organization';

  UserModel copyWith({
    int? id,
    String? login,
    String? name,
    String? avatarUrl,
    String? bio,
    int? publicRepos,
    int? followers,
    int? following,
    String? company,
    String? location,
    String? blog,
    String? twitterUsername,
    String? email,
    bool? hireable,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? type,
    bool? isPro,
    int? totalPrivateRepos,
    int? ownedPrivateRepos,
    int? diskUsage,
    int? collaborators,
    bool? twoFactorAuthentication,
    String? plan,
    String? url,
    String? htmlUrl,
    String? followersUrl,
    String? followingUrl,
    String? gistsUrl,
    String? starredUrl,
    String? subscriptionsUrl,
    String? organizationsUrl,
    String? reposUrl,
    String? eventsUrl,
    String? receivedEventsUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      login: login ?? this.login,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      publicRepos: publicRepos ?? this.publicRepos,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      company: company ?? this.company,
      location: location ?? this.location,
      blog: blog ?? this.blog,
      twitterUsername: twitterUsername ?? this.twitterUsername,
      email: email ?? this.email,
      hireable: hireable ?? this.hireable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      isPro: isPro ?? this.isPro,
      totalPrivateRepos: totalPrivateRepos ?? this.totalPrivateRepos,
      ownedPrivateRepos: ownedPrivateRepos ?? this.ownedPrivateRepos,
      diskUsage: diskUsage ?? this.diskUsage,
      collaborators: collaborators ?? this.collaborators,
      twoFactorAuthentication:
          twoFactorAuthentication ?? this.twoFactorAuthentication,
      plan: plan ?? this.plan,
      url: url ?? this.url,
      htmlUrl: htmlUrl ?? this.htmlUrl,
      followersUrl: followersUrl ?? this.followersUrl,
      followingUrl: followingUrl ?? this.followingUrl,
      gistsUrl: gistsUrl ?? this.gistsUrl,
      starredUrl: starredUrl ?? this.starredUrl,
      subscriptionsUrl: subscriptionsUrl ?? this.subscriptionsUrl,
      organizationsUrl: organizationsUrl ?? this.organizationsUrl,
      reposUrl: reposUrl ?? this.reposUrl,
      eventsUrl: eventsUrl ?? this.eventsUrl,
      receivedEventsUrl: receivedEventsUrl ?? this.receivedEventsUrl,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      login: json['login'] as String? ?? '',
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      publicRepos: json['public_repos'] as int? ?? 0,
      followers: json['followers'] as int? ?? 0,
      following: json['following'] as int? ?? 0,
      company: json['company'] as String?,
      location: json['location'] as String?,
      blog: json['blog'] as String?,
      twitterUsername: json['twitter_username'] as String?,
      email: json['email'] as String?,
      hireable: json['hireable'] as bool?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      type: json['type'] as String? ?? 'User',
      isPro: json['plan'] is Map &&
          (json['plan'] as Map)['name'] != null &&
          (json['plan'] as Map)['name'] != 'free',
      totalPrivateRepos: json['total_private_repos'] as int? ?? 0,
      ownedPrivateRepos: json['owned_private_repos'] as int? ?? 0,
      diskUsage: json['disk_usage'] as int?,
      collaborators: json['collaborators'] as int?,
      twoFactorAuthentication: json['two_factor_authentication'] as bool?,
      plan: json['plan'] is Map
          ? (json['plan'] as Map)['name'] as String?
          : null,
      url: json['url'] as String?,
      htmlUrl: json['html_url'] as String?,
      followersUrl: json['followers_url'] as String?,
      followingUrl: json['following_url'] as String?,
      gistsUrl: json['gists_url'] as String?,
      starredUrl: json['starred_url'] as String?,
      subscriptionsUrl: json['subscriptions_url'] as String?,
      organizationsUrl: json['organizations_url'] as String?,
      reposUrl: json['repos_url'] as String?,
      eventsUrl: json['events_url'] as String?,
      receivedEventsUrl: json['received_events_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'login': login,
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (bio != null) 'bio': bio,
      'public_repos': publicRepos,
      'followers': followers,
      'following': following,
      if (company != null) 'company': company,
      if (location != null) 'location': location,
      if (blog != null) 'blog': blog,
      if (twitterUsername != null) 'twitter_username': twitterUsername,
      if (email != null) 'email': email,
      if (hireable != null) 'hireable': hireable,
      if (createdAt != null)
        'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null)
        'updated_at': updatedAt!.toUtc().toIso8601String(),
      'type': type,
      'total_private_repos': totalPrivateRepos,
      'owned_private_repos': ownedPrivateRepos,
      if (diskUsage != null) 'disk_usage': diskUsage,
      if (collaborators != null) 'collaborators': collaborators,
      if (twoFactorAuthentication != null)
        'two_factor_authentication': twoFactorAuthentication,
      if (url != null) 'url': url,
      if (htmlUrl != null) 'html_url': htmlUrl,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String source) =>
      UserModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  static String _formatCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}m';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          login == other.login;

  @override
  int get hashCode => Object.hash(id, login);

  @override
  String toString() =>
      'UserModel(login: $login, name: $name, followers: $followers)';
}
