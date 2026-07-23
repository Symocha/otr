/// Locally-stored playlist/track metadata (see OffTheRecord_HANDOFF.md §5).
/// Never stores audio — only Spotify track IDs and display metadata.
class LocalTrack {
  final String spotifyTrackId;
  final String title;
  final String artist;
  final String? albumArtUrl;
  final int? durationMs;

  const LocalTrack({
    required this.spotifyTrackId,
    required this.title,
    required this.artist,
    this.albumArtUrl,
    this.durationMs,
  });

  Map<String, dynamic> toJson() => {
        'spotifyTrackId': spotifyTrackId,
        'title': title,
        'artist': artist,
        if (albumArtUrl != null) 'albumArtUrl': albumArtUrl,
        if (durationMs != null) 'durationMs': durationMs,
      };

  factory LocalTrack.fromJson(Map<String, dynamic> json) => LocalTrack(
        spotifyTrackId: json['spotifyTrackId'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        albumArtUrl: json['albumArtUrl'] as String?,
        durationMs: json['durationMs'] as int?,
      );
}

class LocalPlaylist {
  final String id;
  final String name;
  final String? spotifyPlaylistId;
  final bool isPremade;
  final List<LocalTrack> tracks;

  const LocalPlaylist({
    required this.id,
    required this.name,
    this.spotifyPlaylistId,
    this.isPremade = false,
    this.tracks = const [],
  });

  LocalPlaylist copyWith({
    String? id,
    String? name,
    String? spotifyPlaylistId,
    bool? isPremade,
    List<LocalTrack>? tracks,
  }) =>
      LocalPlaylist(
        id: id ?? this.id,
        name: name ?? this.name,
        spotifyPlaylistId: spotifyPlaylistId ?? this.spotifyPlaylistId,
        isPremade: isPremade ?? this.isPremade,
        tracks: tracks ?? this.tracks,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (spotifyPlaylistId != null) 'spotifyPlaylistId': spotifyPlaylistId,
        'isPremade': isPremade,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) => LocalPlaylist(
        id: json['id'] as String,
        name: json['name'] as String,
        spotifyPlaylistId: json['spotifyPlaylistId'] as String?,
        isPremade: json['isPremade'] as bool? ?? false,
        tracks: (json['tracks'] as List)
            .map((t) => LocalTrack.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
