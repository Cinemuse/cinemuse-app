// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CachedMediaItemsTable extends CachedMediaItems
    with TableInfo<$CachedMediaItemsTable, CachedMediaItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleItMeta = const VerificationMeta(
    'titleIt',
  );
  @override
  late final GeneratedColumn<String> titleIt = GeneratedColumn<String>(
    'title_it',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleEnMeta = const VerificationMeta(
    'titleEn',
  );
  @override
  late final GeneratedColumn<String> titleEn = GeneratedColumn<String>(
    'title_en',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posterPathMeta = const VerificationMeta(
    'posterPath',
  );
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
    'poster_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropPathMeta = const VerificationMeta(
    'backdropPath',
  );
  @override
  late final GeneratedColumn<String> backdropPath = GeneratedColumn<String>(
    'backdrop_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runtimeMinutesMeta = const VerificationMeta(
    'runtimeMinutes',
  );
  @override
  late final GeneratedColumn<int> runtimeMinutes = GeneratedColumn<int>(
    'runtime_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genresMeta = const VerificationMeta('genres');
  @override
  late final GeneratedColumn<String> genres = GeneratedColumn<String>(
    'genres',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _castMembersMeta = const VerificationMeta(
    'castMembers',
  );
  @override
  late final GeneratedColumn<String> castMembers = GeneratedColumn<String>(
    'cast_members',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<DateTime> releaseDate = GeneratedColumn<DateTime>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voteAverageMeta = const VerificationMeta(
    'voteAverage',
  );
  @override
  late final GeneratedColumn<double> voteAverage = GeneratedColumn<double>(
    'vote_average',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tmdbId,
    mediaType,
    titleIt,
    titleEn,
    posterPath,
    backdropPath,
    runtimeMinutes,
    genres,
    castMembers,
    releaseDate,
    voteAverage,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_media_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedMediaItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tmdbIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('title_it')) {
      context.handle(
        _titleItMeta,
        titleIt.isAcceptableOrUnknown(data['title_it']!, _titleItMeta),
      );
    }
    if (data.containsKey('title_en')) {
      context.handle(
        _titleEnMeta,
        titleEn.isAcceptableOrUnknown(data['title_en']!, _titleEnMeta),
      );
    }
    if (data.containsKey('poster_path')) {
      context.handle(
        _posterPathMeta,
        posterPath.isAcceptableOrUnknown(data['poster_path']!, _posterPathMeta),
      );
    }
    if (data.containsKey('backdrop_path')) {
      context.handle(
        _backdropPathMeta,
        backdropPath.isAcceptableOrUnknown(
          data['backdrop_path']!,
          _backdropPathMeta,
        ),
      );
    }
    if (data.containsKey('runtime_minutes')) {
      context.handle(
        _runtimeMinutesMeta,
        runtimeMinutes.isAcceptableOrUnknown(
          data['runtime_minutes']!,
          _runtimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('genres')) {
      context.handle(
        _genresMeta,
        genres.isAcceptableOrUnknown(data['genres']!, _genresMeta),
      );
    }
    if (data.containsKey('cast_members')) {
      context.handle(
        _castMembersMeta,
        castMembers.isAcceptableOrUnknown(
          data['cast_members']!,
          _castMembersMeta,
        ),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('vote_average')) {
      context.handle(
        _voteAverageMeta,
        voteAverage.isAcceptableOrUnknown(
          data['vote_average']!,
          _voteAverageMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tmdbId, mediaType};
  @override
  CachedMediaItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMediaItem(
      tmdbId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}tmdb_id'],
          )!,
      mediaType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}media_type'],
          )!,
      titleIt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_it'],
      ),
      titleEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_en'],
      ),
      posterPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_path'],
      ),
      backdropPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_path'],
      ),
      runtimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}runtime_minutes'],
      ),
      genres: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genres'],
      ),
      castMembers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cast_members'],
      ),
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}release_date'],
      ),
      voteAverage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vote_average'],
      ),
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $CachedMediaItemsTable createAlias(String alias) {
    return $CachedMediaItemsTable(attachedDatabase, alias);
  }
}

class CachedMediaItem extends DataClass implements Insertable<CachedMediaItem> {
  final int tmdbId;
  final String mediaType;
  final String? titleIt;
  final String? titleEn;
  final String? posterPath;
  final String? backdropPath;
  final int? runtimeMinutes;
  final String? genres;
  final String? castMembers;
  final DateTime? releaseDate;
  final double? voteAverage;
  final DateTime updatedAt;
  const CachedMediaItem({
    required this.tmdbId,
    required this.mediaType,
    this.titleIt,
    this.titleEn,
    this.posterPath,
    this.backdropPath,
    this.runtimeMinutes,
    this.genres,
    this.castMembers,
    this.releaseDate,
    this.voteAverage,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tmdb_id'] = Variable<int>(tmdbId);
    map['media_type'] = Variable<String>(mediaType);
    if (!nullToAbsent || titleIt != null) {
      map['title_it'] = Variable<String>(titleIt);
    }
    if (!nullToAbsent || titleEn != null) {
      map['title_en'] = Variable<String>(titleEn);
    }
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    if (!nullToAbsent || backdropPath != null) {
      map['backdrop_path'] = Variable<String>(backdropPath);
    }
    if (!nullToAbsent || runtimeMinutes != null) {
      map['runtime_minutes'] = Variable<int>(runtimeMinutes);
    }
    if (!nullToAbsent || genres != null) {
      map['genres'] = Variable<String>(genres);
    }
    if (!nullToAbsent || castMembers != null) {
      map['cast_members'] = Variable<String>(castMembers);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<DateTime>(releaseDate);
    }
    if (!nullToAbsent || voteAverage != null) {
      map['vote_average'] = Variable<double>(voteAverage);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedMediaItemsCompanion toCompanion(bool nullToAbsent) {
    return CachedMediaItemsCompanion(
      tmdbId: Value(tmdbId),
      mediaType: Value(mediaType),
      titleIt:
          titleIt == null && nullToAbsent
              ? const Value.absent()
              : Value(titleIt),
      titleEn:
          titleEn == null && nullToAbsent
              ? const Value.absent()
              : Value(titleEn),
      posterPath:
          posterPath == null && nullToAbsent
              ? const Value.absent()
              : Value(posterPath),
      backdropPath:
          backdropPath == null && nullToAbsent
              ? const Value.absent()
              : Value(backdropPath),
      runtimeMinutes:
          runtimeMinutes == null && nullToAbsent
              ? const Value.absent()
              : Value(runtimeMinutes),
      genres:
          genres == null && nullToAbsent ? const Value.absent() : Value(genres),
      castMembers:
          castMembers == null && nullToAbsent
              ? const Value.absent()
              : Value(castMembers),
      releaseDate:
          releaseDate == null && nullToAbsent
              ? const Value.absent()
              : Value(releaseDate),
      voteAverage:
          voteAverage == null && nullToAbsent
              ? const Value.absent()
              : Value(voteAverage),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedMediaItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMediaItem(
      tmdbId: serializer.fromJson<int>(json['tmdbId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      titleIt: serializer.fromJson<String?>(json['titleIt']),
      titleEn: serializer.fromJson<String?>(json['titleEn']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      backdropPath: serializer.fromJson<String?>(json['backdropPath']),
      runtimeMinutes: serializer.fromJson<int?>(json['runtimeMinutes']),
      genres: serializer.fromJson<String?>(json['genres']),
      castMembers: serializer.fromJson<String?>(json['castMembers']),
      releaseDate: serializer.fromJson<DateTime?>(json['releaseDate']),
      voteAverage: serializer.fromJson<double?>(json['voteAverage']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tmdbId': serializer.toJson<int>(tmdbId),
      'mediaType': serializer.toJson<String>(mediaType),
      'titleIt': serializer.toJson<String?>(titleIt),
      'titleEn': serializer.toJson<String?>(titleEn),
      'posterPath': serializer.toJson<String?>(posterPath),
      'backdropPath': serializer.toJson<String?>(backdropPath),
      'runtimeMinutes': serializer.toJson<int?>(runtimeMinutes),
      'genres': serializer.toJson<String?>(genres),
      'castMembers': serializer.toJson<String?>(castMembers),
      'releaseDate': serializer.toJson<DateTime?>(releaseDate),
      'voteAverage': serializer.toJson<double?>(voteAverage),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedMediaItem copyWith({
    int? tmdbId,
    String? mediaType,
    Value<String?> titleIt = const Value.absent(),
    Value<String?> titleEn = const Value.absent(),
    Value<String?> posterPath = const Value.absent(),
    Value<String?> backdropPath = const Value.absent(),
    Value<int?> runtimeMinutes = const Value.absent(),
    Value<String?> genres = const Value.absent(),
    Value<String?> castMembers = const Value.absent(),
    Value<DateTime?> releaseDate = const Value.absent(),
    Value<double?> voteAverage = const Value.absent(),
    DateTime? updatedAt,
  }) => CachedMediaItem(
    tmdbId: tmdbId ?? this.tmdbId,
    mediaType: mediaType ?? this.mediaType,
    titleIt: titleIt.present ? titleIt.value : this.titleIt,
    titleEn: titleEn.present ? titleEn.value : this.titleEn,
    posterPath: posterPath.present ? posterPath.value : this.posterPath,
    backdropPath: backdropPath.present ? backdropPath.value : this.backdropPath,
    runtimeMinutes:
        runtimeMinutes.present ? runtimeMinutes.value : this.runtimeMinutes,
    genres: genres.present ? genres.value : this.genres,
    castMembers: castMembers.present ? castMembers.value : this.castMembers,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    voteAverage: voteAverage.present ? voteAverage.value : this.voteAverage,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedMediaItem copyWithCompanion(CachedMediaItemsCompanion data) {
    return CachedMediaItem(
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      titleIt: data.titleIt.present ? data.titleIt.value : this.titleIt,
      titleEn: data.titleEn.present ? data.titleEn.value : this.titleEn,
      posterPath:
          data.posterPath.present ? data.posterPath.value : this.posterPath,
      backdropPath:
          data.backdropPath.present
              ? data.backdropPath.value
              : this.backdropPath,
      runtimeMinutes:
          data.runtimeMinutes.present
              ? data.runtimeMinutes.value
              : this.runtimeMinutes,
      genres: data.genres.present ? data.genres.value : this.genres,
      castMembers:
          data.castMembers.present ? data.castMembers.value : this.castMembers,
      releaseDate:
          data.releaseDate.present ? data.releaseDate.value : this.releaseDate,
      voteAverage:
          data.voteAverage.present ? data.voteAverage.value : this.voteAverage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMediaItem(')
          ..write('tmdbId: $tmdbId, ')
          ..write('mediaType: $mediaType, ')
          ..write('titleIt: $titleIt, ')
          ..write('titleEn: $titleEn, ')
          ..write('posterPath: $posterPath, ')
          ..write('backdropPath: $backdropPath, ')
          ..write('runtimeMinutes: $runtimeMinutes, ')
          ..write('genres: $genres, ')
          ..write('castMembers: $castMembers, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('voteAverage: $voteAverage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tmdbId,
    mediaType,
    titleIt,
    titleEn,
    posterPath,
    backdropPath,
    runtimeMinutes,
    genres,
    castMembers,
    releaseDate,
    voteAverage,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMediaItem &&
          other.tmdbId == this.tmdbId &&
          other.mediaType == this.mediaType &&
          other.titleIt == this.titleIt &&
          other.titleEn == this.titleEn &&
          other.posterPath == this.posterPath &&
          other.backdropPath == this.backdropPath &&
          other.runtimeMinutes == this.runtimeMinutes &&
          other.genres == this.genres &&
          other.castMembers == this.castMembers &&
          other.releaseDate == this.releaseDate &&
          other.voteAverage == this.voteAverage &&
          other.updatedAt == this.updatedAt);
}

class CachedMediaItemsCompanion extends UpdateCompanion<CachedMediaItem> {
  final Value<int> tmdbId;
  final Value<String> mediaType;
  final Value<String?> titleIt;
  final Value<String?> titleEn;
  final Value<String?> posterPath;
  final Value<String?> backdropPath;
  final Value<int?> runtimeMinutes;
  final Value<String?> genres;
  final Value<String?> castMembers;
  final Value<DateTime?> releaseDate;
  final Value<double?> voteAverage;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedMediaItemsCompanion({
    this.tmdbId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.titleIt = const Value.absent(),
    this.titleEn = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.backdropPath = const Value.absent(),
    this.runtimeMinutes = const Value.absent(),
    this.genres = const Value.absent(),
    this.castMembers = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.voteAverage = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMediaItemsCompanion.insert({
    required int tmdbId,
    required String mediaType,
    this.titleIt = const Value.absent(),
    this.titleEn = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.backdropPath = const Value.absent(),
    this.runtimeMinutes = const Value.absent(),
    this.genres = const Value.absent(),
    this.castMembers = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.voteAverage = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : tmdbId = Value(tmdbId),
       mediaType = Value(mediaType),
       updatedAt = Value(updatedAt);
  static Insertable<CachedMediaItem> custom({
    Expression<int>? tmdbId,
    Expression<String>? mediaType,
    Expression<String>? titleIt,
    Expression<String>? titleEn,
    Expression<String>? posterPath,
    Expression<String>? backdropPath,
    Expression<int>? runtimeMinutes,
    Expression<String>? genres,
    Expression<String>? castMembers,
    Expression<DateTime>? releaseDate,
    Expression<double>? voteAverage,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (mediaType != null) 'media_type': mediaType,
      if (titleIt != null) 'title_it': titleIt,
      if (titleEn != null) 'title_en': titleEn,
      if (posterPath != null) 'poster_path': posterPath,
      if (backdropPath != null) 'backdrop_path': backdropPath,
      if (runtimeMinutes != null) 'runtime_minutes': runtimeMinutes,
      if (genres != null) 'genres': genres,
      if (castMembers != null) 'cast_members': castMembers,
      if (releaseDate != null) 'release_date': releaseDate,
      if (voteAverage != null) 'vote_average': voteAverage,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMediaItemsCompanion copyWith({
    Value<int>? tmdbId,
    Value<String>? mediaType,
    Value<String?>? titleIt,
    Value<String?>? titleEn,
    Value<String?>? posterPath,
    Value<String?>? backdropPath,
    Value<int?>? runtimeMinutes,
    Value<String?>? genres,
    Value<String?>? castMembers,
    Value<DateTime?>? releaseDate,
    Value<double?>? voteAverage,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedMediaItemsCompanion(
      tmdbId: tmdbId ?? this.tmdbId,
      mediaType: mediaType ?? this.mediaType,
      titleIt: titleIt ?? this.titleIt,
      titleEn: titleEn ?? this.titleEn,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      genres: genres ?? this.genres,
      castMembers: castMembers ?? this.castMembers,
      releaseDate: releaseDate ?? this.releaseDate,
      voteAverage: voteAverage ?? this.voteAverage,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (titleIt.present) {
      map['title_it'] = Variable<String>(titleIt.value);
    }
    if (titleEn.present) {
      map['title_en'] = Variable<String>(titleEn.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (backdropPath.present) {
      map['backdrop_path'] = Variable<String>(backdropPath.value);
    }
    if (runtimeMinutes.present) {
      map['runtime_minutes'] = Variable<int>(runtimeMinutes.value);
    }
    if (genres.present) {
      map['genres'] = Variable<String>(genres.value);
    }
    if (castMembers.present) {
      map['cast_members'] = Variable<String>(castMembers.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<DateTime>(releaseDate.value);
    }
    if (voteAverage.present) {
      map['vote_average'] = Variable<double>(voteAverage.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMediaItemsCompanion(')
          ..write('tmdbId: $tmdbId, ')
          ..write('mediaType: $mediaType, ')
          ..write('titleIt: $titleIt, ')
          ..write('titleEn: $titleEn, ')
          ..write('posterPath: $posterPath, ')
          ..write('backdropPath: $backdropPath, ')
          ..write('runtimeMinutes: $runtimeMinutes, ')
          ..write('genres: $genres, ')
          ..write('castMembers: $castMembers, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('voteAverage: $voteAverage, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalWatchHistoriesTable extends LocalWatchHistories
    with TableInfo<$LocalWatchHistoriesTable, LocalWatchHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalWatchHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tmdbIdMeta = const VerificationMeta('tmdbId');
  @override
  late final GeneratedColumn<int> tmdbId = GeneratedColumn<int>(
    'tmdb_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressSecondsMeta = const VerificationMeta(
    'progressSeconds',
  );
  @override
  late final GeneratedColumn<int> progressSeconds = GeneratedColumn<int>(
    'progress_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalDurationMeta = const VerificationMeta(
    'totalDuration',
  );
  @override
  late final GeneratedColumn<int> totalDuration = GeneratedColumn<int>(
    'total_duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastWatchedAtMeta = const VerificationMeta(
    'lastWatchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastWatchedAt =
      GeneratedColumn<DateTime>(
        'last_watched_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    tmdbId,
    mediaType,
    season,
    episode,
    status,
    progressSeconds,
    totalDuration,
    lastWatchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_watch_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalWatchHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('tmdb_id')) {
      context.handle(
        _tmdbIdMeta,
        tmdbId.isAcceptableOrUnknown(data['tmdb_id']!, _tmdbIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tmdbIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('progress_seconds')) {
      context.handle(
        _progressSecondsMeta,
        progressSeconds.isAcceptableOrUnknown(
          data['progress_seconds']!,
          _progressSecondsMeta,
        ),
      );
    }
    if (data.containsKey('total_duration')) {
      context.handle(
        _totalDurationMeta,
        totalDuration.isAcceptableOrUnknown(
          data['total_duration']!,
          _totalDurationMeta,
        ),
      );
    }
    if (data.containsKey('last_watched_at')) {
      context.handle(
        _lastWatchedAtMeta,
        lastWatchedAt.isAcceptableOrUnknown(
          data['last_watched_at']!,
          _lastWatchedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastWatchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    userId,
    tmdbId,
    mediaType,
    season,
    episode,
  };
  @override
  LocalWatchHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalWatchHistory(
      userId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}user_id'],
          )!,
      tmdbId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}tmdb_id'],
          )!,
      mediaType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}media_type'],
          )!,
      season:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}season'],
          )!,
      episode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}episode'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      progressSeconds:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}progress_seconds'],
          )!,
      totalDuration:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}total_duration'],
          )!,
      lastWatchedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}last_watched_at'],
          )!,
    );
  }

  @override
  $LocalWatchHistoriesTable createAlias(String alias) {
    return $LocalWatchHistoriesTable(attachedDatabase, alias);
  }
}

class LocalWatchHistory extends DataClass
    implements Insertable<LocalWatchHistory> {
  final String userId;
  final int tmdbId;
  final String mediaType;
  final int season;
  final int episode;
  final String status;
  final int progressSeconds;
  final int totalDuration;
  final DateTime lastWatchedAt;
  const LocalWatchHistory({
    required this.userId,
    required this.tmdbId,
    required this.mediaType,
    required this.season,
    required this.episode,
    required this.status,
    required this.progressSeconds,
    required this.totalDuration,
    required this.lastWatchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['tmdb_id'] = Variable<int>(tmdbId);
    map['media_type'] = Variable<String>(mediaType);
    map['season'] = Variable<int>(season);
    map['episode'] = Variable<int>(episode);
    map['status'] = Variable<String>(status);
    map['progress_seconds'] = Variable<int>(progressSeconds);
    map['total_duration'] = Variable<int>(totalDuration);
    map['last_watched_at'] = Variable<DateTime>(lastWatchedAt);
    return map;
  }

  LocalWatchHistoriesCompanion toCompanion(bool nullToAbsent) {
    return LocalWatchHistoriesCompanion(
      userId: Value(userId),
      tmdbId: Value(tmdbId),
      mediaType: Value(mediaType),
      season: Value(season),
      episode: Value(episode),
      status: Value(status),
      progressSeconds: Value(progressSeconds),
      totalDuration: Value(totalDuration),
      lastWatchedAt: Value(lastWatchedAt),
    );
  }

  factory LocalWatchHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalWatchHistory(
      userId: serializer.fromJson<String>(json['userId']),
      tmdbId: serializer.fromJson<int>(json['tmdbId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      season: serializer.fromJson<int>(json['season']),
      episode: serializer.fromJson<int>(json['episode']),
      status: serializer.fromJson<String>(json['status']),
      progressSeconds: serializer.fromJson<int>(json['progressSeconds']),
      totalDuration: serializer.fromJson<int>(json['totalDuration']),
      lastWatchedAt: serializer.fromJson<DateTime>(json['lastWatchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'tmdbId': serializer.toJson<int>(tmdbId),
      'mediaType': serializer.toJson<String>(mediaType),
      'season': serializer.toJson<int>(season),
      'episode': serializer.toJson<int>(episode),
      'status': serializer.toJson<String>(status),
      'progressSeconds': serializer.toJson<int>(progressSeconds),
      'totalDuration': serializer.toJson<int>(totalDuration),
      'lastWatchedAt': serializer.toJson<DateTime>(lastWatchedAt),
    };
  }

  LocalWatchHistory copyWith({
    String? userId,
    int? tmdbId,
    String? mediaType,
    int? season,
    int? episode,
    String? status,
    int? progressSeconds,
    int? totalDuration,
    DateTime? lastWatchedAt,
  }) => LocalWatchHistory(
    userId: userId ?? this.userId,
    tmdbId: tmdbId ?? this.tmdbId,
    mediaType: mediaType ?? this.mediaType,
    season: season ?? this.season,
    episode: episode ?? this.episode,
    status: status ?? this.status,
    progressSeconds: progressSeconds ?? this.progressSeconds,
    totalDuration: totalDuration ?? this.totalDuration,
    lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
  );
  LocalWatchHistory copyWithCompanion(LocalWatchHistoriesCompanion data) {
    return LocalWatchHistory(
      userId: data.userId.present ? data.userId.value : this.userId,
      tmdbId: data.tmdbId.present ? data.tmdbId.value : this.tmdbId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      status: data.status.present ? data.status.value : this.status,
      progressSeconds:
          data.progressSeconds.present
              ? data.progressSeconds.value
              : this.progressSeconds,
      totalDuration:
          data.totalDuration.present
              ? data.totalDuration.value
              : this.totalDuration,
      lastWatchedAt:
          data.lastWatchedAt.present
              ? data.lastWatchedAt.value
              : this.lastWatchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalWatchHistory(')
          ..write('userId: $userId, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('mediaType: $mediaType, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('status: $status, ')
          ..write('progressSeconds: $progressSeconds, ')
          ..write('totalDuration: $totalDuration, ')
          ..write('lastWatchedAt: $lastWatchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    tmdbId,
    mediaType,
    season,
    episode,
    status,
    progressSeconds,
    totalDuration,
    lastWatchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalWatchHistory &&
          other.userId == this.userId &&
          other.tmdbId == this.tmdbId &&
          other.mediaType == this.mediaType &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.status == this.status &&
          other.progressSeconds == this.progressSeconds &&
          other.totalDuration == this.totalDuration &&
          other.lastWatchedAt == this.lastWatchedAt);
}

class LocalWatchHistoriesCompanion extends UpdateCompanion<LocalWatchHistory> {
  final Value<String> userId;
  final Value<int> tmdbId;
  final Value<String> mediaType;
  final Value<int> season;
  final Value<int> episode;
  final Value<String> status;
  final Value<int> progressSeconds;
  final Value<int> totalDuration;
  final Value<DateTime> lastWatchedAt;
  final Value<int> rowid;
  const LocalWatchHistoriesCompanion({
    this.userId = const Value.absent(),
    this.tmdbId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.status = const Value.absent(),
    this.progressSeconds = const Value.absent(),
    this.totalDuration = const Value.absent(),
    this.lastWatchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalWatchHistoriesCompanion.insert({
    required String userId,
    required int tmdbId,
    required String mediaType,
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    required String status,
    this.progressSeconds = const Value.absent(),
    this.totalDuration = const Value.absent(),
    required DateTime lastWatchedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       tmdbId = Value(tmdbId),
       mediaType = Value(mediaType),
       status = Value(status),
       lastWatchedAt = Value(lastWatchedAt);
  static Insertable<LocalWatchHistory> custom({
    Expression<String>? userId,
    Expression<int>? tmdbId,
    Expression<String>? mediaType,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<String>? status,
    Expression<int>? progressSeconds,
    Expression<int>? totalDuration,
    Expression<DateTime>? lastWatchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (tmdbId != null) 'tmdb_id': tmdbId,
      if (mediaType != null) 'media_type': mediaType,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (status != null) 'status': status,
      if (progressSeconds != null) 'progress_seconds': progressSeconds,
      if (totalDuration != null) 'total_duration': totalDuration,
      if (lastWatchedAt != null) 'last_watched_at': lastWatchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalWatchHistoriesCompanion copyWith({
    Value<String>? userId,
    Value<int>? tmdbId,
    Value<String>? mediaType,
    Value<int>? season,
    Value<int>? episode,
    Value<String>? status,
    Value<int>? progressSeconds,
    Value<int>? totalDuration,
    Value<DateTime>? lastWatchedAt,
    Value<int>? rowid,
  }) {
    return LocalWatchHistoriesCompanion(
      userId: userId ?? this.userId,
      tmdbId: tmdbId ?? this.tmdbId,
      mediaType: mediaType ?? this.mediaType,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      status: status ?? this.status,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      totalDuration: totalDuration ?? this.totalDuration,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (tmdbId.present) {
      map['tmdb_id'] = Variable<int>(tmdbId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progressSeconds.present) {
      map['progress_seconds'] = Variable<int>(progressSeconds.value);
    }
    if (totalDuration.present) {
      map['total_duration'] = Variable<int>(totalDuration.value);
    }
    if (lastWatchedAt.present) {
      map['last_watched_at'] = Variable<DateTime>(lastWatchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalWatchHistoriesCompanion(')
          ..write('userId: $userId, ')
          ..write('tmdbId: $tmdbId, ')
          ..write('mediaType: $mediaType, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('status: $status, ')
          ..write('progressSeconds: $progressSeconds, ')
          ..write('totalDuration: $totalDuration, ')
          ..write('lastWatchedAt: $lastWatchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedUserListsTable extends CachedUserLists
    with TableInfo<$CachedUserListsTable, CachedUserList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedUserListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    type,
    description,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_user_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedUserList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedUserList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedUserList(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      userId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}user_id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}type'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      sortOrder:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sort_order'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $CachedUserListsTable createAlias(String alias) {
    return $CachedUserListsTable(attachedDatabase, alias);
  }
}

class CachedUserList extends DataClass implements Insertable<CachedUserList> {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String? description;
  final int sortOrder;
  final DateTime createdAt;
  const CachedUserList({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.description,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CachedUserListsCompanion toCompanion(bool nullToAbsent) {
    return CachedUserListsCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      type: Value(type),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory CachedUserList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedUserList(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      description: serializer.fromJson<String?>(json['description']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'description': serializer.toJson<String?>(description),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CachedUserList copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    Value<String?> description = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
  }) => CachedUserList(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    type: type ?? this.type,
    description: description.present ? description.value : this.description,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  CachedUserList copyWithCompanion(CachedUserListsCompanion data) {
    return CachedUserList(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      description:
          data.description.present ? data.description.value : this.description,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedUserList(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, name, type, description, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedUserList &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.type == this.type &&
          other.description == this.description &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class CachedUserListsCompanion extends UpdateCompanion<CachedUserList> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> description;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CachedUserListsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedUserListsCompanion.insert({
    required String id,
    required String userId,
    required String name,
    required String type,
    this.description = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       name = Value(name),
       type = Value(type);
  static Insertable<CachedUserList> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? description,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedUserListsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? description,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CachedUserListsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedUserListsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedListItemsTable extends CachedListItems
    with TableInfo<$CachedListItemsTable, CachedListItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedListItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTmdbIdMeta = const VerificationMeta(
    'mediaTmdbId',
  );
  @override
  late final GeneratedColumn<int> mediaTmdbId = GeneratedColumn<int>(
    'media_tmdb_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
    'meta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    listId,
    mediaTmdbId,
    mediaType,
    meta,
    sortOrder,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_list_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedListItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('media_tmdb_id')) {
      context.handle(
        _mediaTmdbIdMeta,
        mediaTmdbId.isAcceptableOrUnknown(
          data['media_tmdb_id']!,
          _mediaTmdbIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaTmdbIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('meta')) {
      context.handle(
        _metaMeta,
        meta.isAcceptableOrUnknown(data['meta']!, _metaMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {listId, mediaTmdbId, mediaType};
  @override
  CachedListItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedListItem(
      listId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}list_id'],
          )!,
      mediaTmdbId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}media_tmdb_id'],
          )!,
      mediaType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}media_type'],
          )!,
      meta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta'],
      ),
      sortOrder:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sort_order'],
          )!,
      addedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}added_at'],
          )!,
    );
  }

  @override
  $CachedListItemsTable createAlias(String alias) {
    return $CachedListItemsTable(attachedDatabase, alias);
  }
}

class CachedListItem extends DataClass implements Insertable<CachedListItem> {
  final String listId;
  final int mediaTmdbId;
  final String mediaType;
  final String? meta;
  final int sortOrder;
  final DateTime addedAt;
  const CachedListItem({
    required this.listId,
    required this.mediaTmdbId,
    required this.mediaType,
    this.meta,
    required this.sortOrder,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['list_id'] = Variable<String>(listId);
    map['media_tmdb_id'] = Variable<int>(mediaTmdbId);
    map['media_type'] = Variable<String>(mediaType);
    if (!nullToAbsent || meta != null) {
      map['meta'] = Variable<String>(meta);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  CachedListItemsCompanion toCompanion(bool nullToAbsent) {
    return CachedListItemsCompanion(
      listId: Value(listId),
      mediaTmdbId: Value(mediaTmdbId),
      mediaType: Value(mediaType),
      meta: meta == null && nullToAbsent ? const Value.absent() : Value(meta),
      sortOrder: Value(sortOrder),
      addedAt: Value(addedAt),
    );
  }

  factory CachedListItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedListItem(
      listId: serializer.fromJson<String>(json['listId']),
      mediaTmdbId: serializer.fromJson<int>(json['mediaTmdbId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      meta: serializer.fromJson<String?>(json['meta']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'listId': serializer.toJson<String>(listId),
      'mediaTmdbId': serializer.toJson<int>(mediaTmdbId),
      'mediaType': serializer.toJson<String>(mediaType),
      'meta': serializer.toJson<String?>(meta),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  CachedListItem copyWith({
    String? listId,
    int? mediaTmdbId,
    String? mediaType,
    Value<String?> meta = const Value.absent(),
    int? sortOrder,
    DateTime? addedAt,
  }) => CachedListItem(
    listId: listId ?? this.listId,
    mediaTmdbId: mediaTmdbId ?? this.mediaTmdbId,
    mediaType: mediaType ?? this.mediaType,
    meta: meta.present ? meta.value : this.meta,
    sortOrder: sortOrder ?? this.sortOrder,
    addedAt: addedAt ?? this.addedAt,
  );
  CachedListItem copyWithCompanion(CachedListItemsCompanion data) {
    return CachedListItem(
      listId: data.listId.present ? data.listId.value : this.listId,
      mediaTmdbId:
          data.mediaTmdbId.present ? data.mediaTmdbId.value : this.mediaTmdbId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      meta: data.meta.present ? data.meta.value : this.meta,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedListItem(')
          ..write('listId: $listId, ')
          ..write('mediaTmdbId: $mediaTmdbId, ')
          ..write('mediaType: $mediaType, ')
          ..write('meta: $meta, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(listId, mediaTmdbId, mediaType, meta, sortOrder, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedListItem &&
          other.listId == this.listId &&
          other.mediaTmdbId == this.mediaTmdbId &&
          other.mediaType == this.mediaType &&
          other.meta == this.meta &&
          other.sortOrder == this.sortOrder &&
          other.addedAt == this.addedAt);
}

class CachedListItemsCompanion extends UpdateCompanion<CachedListItem> {
  final Value<String> listId;
  final Value<int> mediaTmdbId;
  final Value<String> mediaType;
  final Value<String?> meta;
  final Value<int> sortOrder;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const CachedListItemsCompanion({
    this.listId = const Value.absent(),
    this.mediaTmdbId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.meta = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedListItemsCompanion.insert({
    required String listId,
    required int mediaTmdbId,
    required String mediaType,
    this.meta = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : listId = Value(listId),
       mediaTmdbId = Value(mediaTmdbId),
       mediaType = Value(mediaType);
  static Insertable<CachedListItem> custom({
    Expression<String>? listId,
    Expression<int>? mediaTmdbId,
    Expression<String>? mediaType,
    Expression<String>? meta,
    Expression<int>? sortOrder,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (listId != null) 'list_id': listId,
      if (mediaTmdbId != null) 'media_tmdb_id': mediaTmdbId,
      if (mediaType != null) 'media_type': mediaType,
      if (meta != null) 'meta': meta,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedListItemsCompanion copyWith({
    Value<String>? listId,
    Value<int>? mediaTmdbId,
    Value<String>? mediaType,
    Value<String?>? meta,
    Value<int>? sortOrder,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return CachedListItemsCompanion(
      listId: listId ?? this.listId,
      mediaTmdbId: mediaTmdbId ?? this.mediaTmdbId,
      mediaType: mediaType ?? this.mediaType,
      meta: meta ?? this.meta,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (mediaTmdbId.present) {
      map['media_tmdb_id'] = Variable<int>(mediaTmdbId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedListItemsCompanion(')
          ..write('listId: $listId, ')
          ..write('mediaTmdbId: $mediaTmdbId, ')
          ..write('mediaType: $mediaType, ')
          ..write('meta: $meta, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnimeExternalMappingsTable extends AnimeExternalMappings
    with TableInfo<$AnimeExternalMappingsTable, AnimeExternalMapping> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnimeExternalMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anilistIdMeta = const VerificationMeta(
    'anilistId',
  );
  @override
  late final GeneratedColumn<int> anilistId = GeneratedColumn<int>(
    'anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _anidbIdMeta = const VerificationMeta(
    'anidbId',
  );
  @override
  late final GeneratedColumn<int> anidbId = GeneratedColumn<int>(
    'anidb_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbShowIdMeta = const VerificationMeta(
    'tmdbShowId',
  );
  @override
  late final GeneratedColumn<int> tmdbShowId = GeneratedColumn<int>(
    'tmdb_show_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tmdbMovieIdMeta = const VerificationMeta(
    'tmdbMovieId',
  );
  @override
  late final GeneratedColumn<int> tmdbMovieId = GeneratedColumn<int>(
    'tmdb_movie_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tvdbIdMeta = const VerificationMeta('tvdbId');
  @override
  late final GeneratedColumn<int> tvdbId = GeneratedColumn<int>(
    'tvdb_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mappingsDataMeta = const VerificationMeta(
    'mappingsData',
  );
  @override
  late final GeneratedColumn<String> mappingsData = GeneratedColumn<String>(
    'mappings_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    anilistId,
    anidbId,
    tmdbShowId,
    tmdbMovieId,
    tvdbId,
    mappingsData,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anime_external_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnimeExternalMapping> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anilist_id')) {
      context.handle(
        _anilistIdMeta,
        anilistId.isAcceptableOrUnknown(data['anilist_id']!, _anilistIdMeta),
      );
    }
    if (data.containsKey('anidb_id')) {
      context.handle(
        _anidbIdMeta,
        anidbId.isAcceptableOrUnknown(data['anidb_id']!, _anidbIdMeta),
      );
    }
    if (data.containsKey('tmdb_show_id')) {
      context.handle(
        _tmdbShowIdMeta,
        tmdbShowId.isAcceptableOrUnknown(
          data['tmdb_show_id']!,
          _tmdbShowIdMeta,
        ),
      );
    }
    if (data.containsKey('tmdb_movie_id')) {
      context.handle(
        _tmdbMovieIdMeta,
        tmdbMovieId.isAcceptableOrUnknown(
          data['tmdb_movie_id']!,
          _tmdbMovieIdMeta,
        ),
      );
    }
    if (data.containsKey('tvdb_id')) {
      context.handle(
        _tvdbIdMeta,
        tvdbId.isAcceptableOrUnknown(data['tvdb_id']!, _tvdbIdMeta),
      );
    }
    if (data.containsKey('mappings_data')) {
      context.handle(
        _mappingsDataMeta,
        mappingsData.isAcceptableOrUnknown(
          data['mappings_data']!,
          _mappingsDataMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {anilistId};
  @override
  AnimeExternalMapping map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnimeExternalMapping(
      anilistId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}anilist_id'],
          )!,
      anidbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anidb_id'],
      ),
      tmdbShowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_show_id'],
      ),
      tmdbMovieId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tmdb_movie_id'],
      ),
      tvdbId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tvdb_id'],
      ),
      mappingsData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mappings_data'],
      ),
    );
  }

  @override
  $AnimeExternalMappingsTable createAlias(String alias) {
    return $AnimeExternalMappingsTable(attachedDatabase, alias);
  }
}

class AnimeExternalMapping extends DataClass
    implements Insertable<AnimeExternalMapping> {
  final int anilistId;
  final int? anidbId;
  final int? tmdbShowId;
  final int? tmdbMovieId;
  final int? tvdbId;
  final String? mappingsData;
  const AnimeExternalMapping({
    required this.anilistId,
    this.anidbId,
    this.tmdbShowId,
    this.tmdbMovieId,
    this.tvdbId,
    this.mappingsData,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    if (!nullToAbsent || anidbId != null) {
      map['anidb_id'] = Variable<int>(anidbId);
    }
    if (!nullToAbsent || tmdbShowId != null) {
      map['tmdb_show_id'] = Variable<int>(tmdbShowId);
    }
    if (!nullToAbsent || tmdbMovieId != null) {
      map['tmdb_movie_id'] = Variable<int>(tmdbMovieId);
    }
    if (!nullToAbsent || tvdbId != null) {
      map['tvdb_id'] = Variable<int>(tvdbId);
    }
    if (!nullToAbsent || mappingsData != null) {
      map['mappings_data'] = Variable<String>(mappingsData);
    }
    return map;
  }

  AnimeExternalMappingsCompanion toCompanion(bool nullToAbsent) {
    return AnimeExternalMappingsCompanion(
      anilistId: Value(anilistId),
      anidbId:
          anidbId == null && nullToAbsent
              ? const Value.absent()
              : Value(anidbId),
      tmdbShowId:
          tmdbShowId == null && nullToAbsent
              ? const Value.absent()
              : Value(tmdbShowId),
      tmdbMovieId:
          tmdbMovieId == null && nullToAbsent
              ? const Value.absent()
              : Value(tmdbMovieId),
      tvdbId:
          tvdbId == null && nullToAbsent ? const Value.absent() : Value(tvdbId),
      mappingsData:
          mappingsData == null && nullToAbsent
              ? const Value.absent()
              : Value(mappingsData),
    );
  }

  factory AnimeExternalMapping.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnimeExternalMapping(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      anidbId: serializer.fromJson<int?>(json['anidbId']),
      tmdbShowId: serializer.fromJson<int?>(json['tmdbShowId']),
      tmdbMovieId: serializer.fromJson<int?>(json['tmdbMovieId']),
      tvdbId: serializer.fromJson<int?>(json['tvdbId']),
      mappingsData: serializer.fromJson<String?>(json['mappingsData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'anidbId': serializer.toJson<int?>(anidbId),
      'tmdbShowId': serializer.toJson<int?>(tmdbShowId),
      'tmdbMovieId': serializer.toJson<int?>(tmdbMovieId),
      'tvdbId': serializer.toJson<int?>(tvdbId),
      'mappingsData': serializer.toJson<String?>(mappingsData),
    };
  }

  AnimeExternalMapping copyWith({
    int? anilistId,
    Value<int?> anidbId = const Value.absent(),
    Value<int?> tmdbShowId = const Value.absent(),
    Value<int?> tmdbMovieId = const Value.absent(),
    Value<int?> tvdbId = const Value.absent(),
    Value<String?> mappingsData = const Value.absent(),
  }) => AnimeExternalMapping(
    anilistId: anilistId ?? this.anilistId,
    anidbId: anidbId.present ? anidbId.value : this.anidbId,
    tmdbShowId: tmdbShowId.present ? tmdbShowId.value : this.tmdbShowId,
    tmdbMovieId: tmdbMovieId.present ? tmdbMovieId.value : this.tmdbMovieId,
    tvdbId: tvdbId.present ? tvdbId.value : this.tvdbId,
    mappingsData: mappingsData.present ? mappingsData.value : this.mappingsData,
  );
  AnimeExternalMapping copyWithCompanion(AnimeExternalMappingsCompanion data) {
    return AnimeExternalMapping(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      anidbId: data.anidbId.present ? data.anidbId.value : this.anidbId,
      tmdbShowId:
          data.tmdbShowId.present ? data.tmdbShowId.value : this.tmdbShowId,
      tmdbMovieId:
          data.tmdbMovieId.present ? data.tmdbMovieId.value : this.tmdbMovieId,
      tvdbId: data.tvdbId.present ? data.tvdbId.value : this.tvdbId,
      mappingsData:
          data.mappingsData.present
              ? data.mappingsData.value
              : this.mappingsData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnimeExternalMapping(')
          ..write('anilistId: $anilistId, ')
          ..write('anidbId: $anidbId, ')
          ..write('tmdbShowId: $tmdbShowId, ')
          ..write('tmdbMovieId: $tmdbMovieId, ')
          ..write('tvdbId: $tvdbId, ')
          ..write('mappingsData: $mappingsData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    anilistId,
    anidbId,
    tmdbShowId,
    tmdbMovieId,
    tvdbId,
    mappingsData,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnimeExternalMapping &&
          other.anilistId == this.anilistId &&
          other.anidbId == this.anidbId &&
          other.tmdbShowId == this.tmdbShowId &&
          other.tmdbMovieId == this.tmdbMovieId &&
          other.tvdbId == this.tvdbId &&
          other.mappingsData == this.mappingsData);
}

class AnimeExternalMappingsCompanion
    extends UpdateCompanion<AnimeExternalMapping> {
  final Value<int> anilistId;
  final Value<int?> anidbId;
  final Value<int?> tmdbShowId;
  final Value<int?> tmdbMovieId;
  final Value<int?> tvdbId;
  final Value<String?> mappingsData;
  const AnimeExternalMappingsCompanion({
    this.anilistId = const Value.absent(),
    this.anidbId = const Value.absent(),
    this.tmdbShowId = const Value.absent(),
    this.tmdbMovieId = const Value.absent(),
    this.tvdbId = const Value.absent(),
    this.mappingsData = const Value.absent(),
  });
  AnimeExternalMappingsCompanion.insert({
    this.anilistId = const Value.absent(),
    this.anidbId = const Value.absent(),
    this.tmdbShowId = const Value.absent(),
    this.tmdbMovieId = const Value.absent(),
    this.tvdbId = const Value.absent(),
    this.mappingsData = const Value.absent(),
  });
  static Insertable<AnimeExternalMapping> custom({
    Expression<int>? anilistId,
    Expression<int>? anidbId,
    Expression<int>? tmdbShowId,
    Expression<int>? tmdbMovieId,
    Expression<int>? tvdbId,
    Expression<String>? mappingsData,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (anidbId != null) 'anidb_id': anidbId,
      if (tmdbShowId != null) 'tmdb_show_id': tmdbShowId,
      if (tmdbMovieId != null) 'tmdb_movie_id': tmdbMovieId,
      if (tvdbId != null) 'tvdb_id': tvdbId,
      if (mappingsData != null) 'mappings_data': mappingsData,
    });
  }

  AnimeExternalMappingsCompanion copyWith({
    Value<int>? anilistId,
    Value<int?>? anidbId,
    Value<int?>? tmdbShowId,
    Value<int?>? tmdbMovieId,
    Value<int?>? tvdbId,
    Value<String?>? mappingsData,
  }) {
    return AnimeExternalMappingsCompanion(
      anilistId: anilistId ?? this.anilistId,
      anidbId: anidbId ?? this.anidbId,
      tmdbShowId: tmdbShowId ?? this.tmdbShowId,
      tmdbMovieId: tmdbMovieId ?? this.tmdbMovieId,
      tvdbId: tvdbId ?? this.tvdbId,
      mappingsData: mappingsData ?? this.mappingsData,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (anidbId.present) {
      map['anidb_id'] = Variable<int>(anidbId.value);
    }
    if (tmdbShowId.present) {
      map['tmdb_show_id'] = Variable<int>(tmdbShowId.value);
    }
    if (tmdbMovieId.present) {
      map['tmdb_movie_id'] = Variable<int>(tmdbMovieId.value);
    }
    if (tvdbId.present) {
      map['tvdb_id'] = Variable<int>(tvdbId.value);
    }
    if (mappingsData.present) {
      map['mappings_data'] = Variable<String>(mappingsData.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnimeExternalMappingsCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('anidbId: $anidbId, ')
          ..write('tmdbShowId: $tmdbShowId, ')
          ..write('tmdbMovieId: $tmdbMovieId, ')
          ..write('tvdbId: $tvdbId, ')
          ..write('mappingsData: $mappingsData')
          ..write(')'))
        .toString();
  }
}

class $AnimeKitsuMappingsTable extends AnimeKitsuMappings
    with TableInfo<$AnimeKitsuMappingsTable, AnimeKitsuMapping> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnimeKitsuMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anilistIdMeta = const VerificationMeta(
    'anilistId',
  );
  @override
  late final GeneratedColumn<int> anilistId = GeneratedColumn<int>(
    'anilist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kitsuIdMeta = const VerificationMeta(
    'kitsuId',
  );
  @override
  late final GeneratedColumn<String> kitsuId = GeneratedColumn<String>(
    'kitsu_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeCountMeta = const VerificationMeta(
    'episodeCount',
  );
  @override
  late final GeneratedColumn<int> episodeCount = GeneratedColumn<int>(
    'episode_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    anilistId,
    kitsuId,
    episodeCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anime_kitsu_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnimeKitsuMapping> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anilist_id')) {
      context.handle(
        _anilistIdMeta,
        anilistId.isAcceptableOrUnknown(data['anilist_id']!, _anilistIdMeta),
      );
    }
    if (data.containsKey('kitsu_id')) {
      context.handle(
        _kitsuIdMeta,
        kitsuId.isAcceptableOrUnknown(data['kitsu_id']!, _kitsuIdMeta),
      );
    } else if (isInserting) {
      context.missing(_kitsuIdMeta);
    }
    if (data.containsKey('episode_count')) {
      context.handle(
        _episodeCountMeta,
        episodeCount.isAcceptableOrUnknown(
          data['episode_count']!,
          _episodeCountMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {anilistId};
  @override
  AnimeKitsuMapping map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnimeKitsuMapping(
      anilistId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}anilist_id'],
          )!,
      kitsuId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}kitsu_id'],
          )!,
      episodeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_count'],
      ),
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $AnimeKitsuMappingsTable createAlias(String alias) {
    return $AnimeKitsuMappingsTable(attachedDatabase, alias);
  }
}

class AnimeKitsuMapping extends DataClass
    implements Insertable<AnimeKitsuMapping> {
  final int anilistId;
  final String kitsuId;
  final int? episodeCount;
  final DateTime updatedAt;
  const AnimeKitsuMapping({
    required this.anilistId,
    required this.kitsuId,
    this.episodeCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anilist_id'] = Variable<int>(anilistId);
    map['kitsu_id'] = Variable<String>(kitsuId);
    if (!nullToAbsent || episodeCount != null) {
      map['episode_count'] = Variable<int>(episodeCount);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AnimeKitsuMappingsCompanion toCompanion(bool nullToAbsent) {
    return AnimeKitsuMappingsCompanion(
      anilistId: Value(anilistId),
      kitsuId: Value(kitsuId),
      episodeCount:
          episodeCount == null && nullToAbsent
              ? const Value.absent()
              : Value(episodeCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory AnimeKitsuMapping.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnimeKitsuMapping(
      anilistId: serializer.fromJson<int>(json['anilistId']),
      kitsuId: serializer.fromJson<String>(json['kitsuId']),
      episodeCount: serializer.fromJson<int?>(json['episodeCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anilistId': serializer.toJson<int>(anilistId),
      'kitsuId': serializer.toJson<String>(kitsuId),
      'episodeCount': serializer.toJson<int?>(episodeCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AnimeKitsuMapping copyWith({
    int? anilistId,
    String? kitsuId,
    Value<int?> episodeCount = const Value.absent(),
    DateTime? updatedAt,
  }) => AnimeKitsuMapping(
    anilistId: anilistId ?? this.anilistId,
    kitsuId: kitsuId ?? this.kitsuId,
    episodeCount: episodeCount.present ? episodeCount.value : this.episodeCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AnimeKitsuMapping copyWithCompanion(AnimeKitsuMappingsCompanion data) {
    return AnimeKitsuMapping(
      anilistId: data.anilistId.present ? data.anilistId.value : this.anilistId,
      kitsuId: data.kitsuId.present ? data.kitsuId.value : this.kitsuId,
      episodeCount:
          data.episodeCount.present
              ? data.episodeCount.value
              : this.episodeCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnimeKitsuMapping(')
          ..write('anilistId: $anilistId, ')
          ..write('kitsuId: $kitsuId, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(anilistId, kitsuId, episodeCount, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnimeKitsuMapping &&
          other.anilistId == this.anilistId &&
          other.kitsuId == this.kitsuId &&
          other.episodeCount == this.episodeCount &&
          other.updatedAt == this.updatedAt);
}

class AnimeKitsuMappingsCompanion extends UpdateCompanion<AnimeKitsuMapping> {
  final Value<int> anilistId;
  final Value<String> kitsuId;
  final Value<int?> episodeCount;
  final Value<DateTime> updatedAt;
  const AnimeKitsuMappingsCompanion({
    this.anilistId = const Value.absent(),
    this.kitsuId = const Value.absent(),
    this.episodeCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AnimeKitsuMappingsCompanion.insert({
    this.anilistId = const Value.absent(),
    required String kitsuId,
    this.episodeCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : kitsuId = Value(kitsuId);
  static Insertable<AnimeKitsuMapping> custom({
    Expression<int>? anilistId,
    Expression<String>? kitsuId,
    Expression<int>? episodeCount,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (anilistId != null) 'anilist_id': anilistId,
      if (kitsuId != null) 'kitsu_id': kitsuId,
      if (episodeCount != null) 'episode_count': episodeCount,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AnimeKitsuMappingsCompanion copyWith({
    Value<int>? anilistId,
    Value<String>? kitsuId,
    Value<int?>? episodeCount,
    Value<DateTime>? updatedAt,
  }) {
    return AnimeKitsuMappingsCompanion(
      anilistId: anilistId ?? this.anilistId,
      kitsuId: kitsuId ?? this.kitsuId,
      episodeCount: episodeCount ?? this.episodeCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anilistId.present) {
      map['anilist_id'] = Variable<int>(anilistId.value);
    }
    if (kitsuId.present) {
      map['kitsu_id'] = Variable<String>(kitsuId.value);
    }
    if (episodeCount.present) {
      map['episode_count'] = Variable<int>(episodeCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnimeKitsuMappingsCompanion(')
          ..write('anilistId: $anilistId, ')
          ..write('kitsuId: $kitsuId, ')
          ..write('episodeCount: $episodeCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedMediaItemsTable cachedMediaItems = $CachedMediaItemsTable(
    this,
  );
  late final $LocalWatchHistoriesTable localWatchHistories =
      $LocalWatchHistoriesTable(this);
  late final $CachedUserListsTable cachedUserLists = $CachedUserListsTable(
    this,
  );
  late final $CachedListItemsTable cachedListItems = $CachedListItemsTable(
    this,
  );
  late final $AnimeExternalMappingsTable animeExternalMappings =
      $AnimeExternalMappingsTable(this);
  late final $AnimeKitsuMappingsTable animeKitsuMappings =
      $AnimeKitsuMappingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedMediaItems,
    localWatchHistories,
    cachedUserLists,
    cachedListItems,
    animeExternalMappings,
    animeKitsuMappings,
  ];
}

typedef $$CachedMediaItemsTableCreateCompanionBuilder =
    CachedMediaItemsCompanion Function({
      required int tmdbId,
      required String mediaType,
      Value<String?> titleIt,
      Value<String?> titleEn,
      Value<String?> posterPath,
      Value<String?> backdropPath,
      Value<int?> runtimeMinutes,
      Value<String?> genres,
      Value<String?> castMembers,
      Value<DateTime?> releaseDate,
      Value<double?> voteAverage,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CachedMediaItemsTableUpdateCompanionBuilder =
    CachedMediaItemsCompanion Function({
      Value<int> tmdbId,
      Value<String> mediaType,
      Value<String?> titleIt,
      Value<String?> titleEn,
      Value<String?> posterPath,
      Value<String?> backdropPath,
      Value<int?> runtimeMinutes,
      Value<String?> genres,
      Value<String?> castMembers,
      Value<DateTime?> releaseDate,
      Value<double?> voteAverage,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedMediaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMediaItemsTable> {
  $$CachedMediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleIt => $composableBuilder(
    column: $table.titleIt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleEn => $composableBuilder(
    column: $table.titleEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropPath => $composableBuilder(
    column: $table.backdropPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runtimeMinutes => $composableBuilder(
    column: $table.runtimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get castMembers => $composableBuilder(
    column: $table.castMembers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get voteAverage => $composableBuilder(
    column: $table.voteAverage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedMediaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMediaItemsTable> {
  $$CachedMediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleIt => $composableBuilder(
    column: $table.titleIt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleEn => $composableBuilder(
    column: $table.titleEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropPath => $composableBuilder(
    column: $table.backdropPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runtimeMinutes => $composableBuilder(
    column: $table.runtimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genres => $composableBuilder(
    column: $table.genres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get castMembers => $composableBuilder(
    column: $table.castMembers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get voteAverage => $composableBuilder(
    column: $table.voteAverage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedMediaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMediaItemsTable> {
  $$CachedMediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get titleIt =>
      $composableBuilder(column: $table.titleIt, builder: (column) => column);

  GeneratedColumn<String> get titleEn =>
      $composableBuilder(column: $table.titleEn, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backdropPath => $composableBuilder(
    column: $table.backdropPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get runtimeMinutes => $composableBuilder(
    column: $table.runtimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genres =>
      $composableBuilder(column: $table.genres, builder: (column) => column);

  GeneratedColumn<String> get castMembers => $composableBuilder(
    column: $table.castMembers,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get voteAverage => $composableBuilder(
    column: $table.voteAverage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedMediaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedMediaItemsTable,
          CachedMediaItem,
          $$CachedMediaItemsTableFilterComposer,
          $$CachedMediaItemsTableOrderingComposer,
          $$CachedMediaItemsTableAnnotationComposer,
          $$CachedMediaItemsTableCreateCompanionBuilder,
          $$CachedMediaItemsTableUpdateCompanionBuilder,
          (
            CachedMediaItem,
            BaseReferences<
              _$AppDatabase,
              $CachedMediaItemsTable,
              CachedMediaItem
            >,
          ),
          CachedMediaItem,
          PrefetchHooks Function()
        > {
  $$CachedMediaItemsTableTableManager(
    _$AppDatabase db,
    $CachedMediaItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$CachedMediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CachedMediaItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$CachedMediaItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> tmdbId = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String?> titleIt = const Value.absent(),
                Value<String?> titleEn = const Value.absent(),
                Value<String?> posterPath = const Value.absent(),
                Value<String?> backdropPath = const Value.absent(),
                Value<int?> runtimeMinutes = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> castMembers = const Value.absent(),
                Value<DateTime?> releaseDate = const Value.absent(),
                Value<double?> voteAverage = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMediaItemsCompanion(
                tmdbId: tmdbId,
                mediaType: mediaType,
                titleIt: titleIt,
                titleEn: titleEn,
                posterPath: posterPath,
                backdropPath: backdropPath,
                runtimeMinutes: runtimeMinutes,
                genres: genres,
                castMembers: castMembers,
                releaseDate: releaseDate,
                voteAverage: voteAverage,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int tmdbId,
                required String mediaType,
                Value<String?> titleIt = const Value.absent(),
                Value<String?> titleEn = const Value.absent(),
                Value<String?> posterPath = const Value.absent(),
                Value<String?> backdropPath = const Value.absent(),
                Value<int?> runtimeMinutes = const Value.absent(),
                Value<String?> genres = const Value.absent(),
                Value<String?> castMembers = const Value.absent(),
                Value<DateTime?> releaseDate = const Value.absent(),
                Value<double?> voteAverage = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedMediaItemsCompanion.insert(
                tmdbId: tmdbId,
                mediaType: mediaType,
                titleIt: titleIt,
                titleEn: titleEn,
                posterPath: posterPath,
                backdropPath: backdropPath,
                runtimeMinutes: runtimeMinutes,
                genres: genres,
                castMembers: castMembers,
                releaseDate: releaseDate,
                voteAverage: voteAverage,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMediaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedMediaItemsTable,
      CachedMediaItem,
      $$CachedMediaItemsTableFilterComposer,
      $$CachedMediaItemsTableOrderingComposer,
      $$CachedMediaItemsTableAnnotationComposer,
      $$CachedMediaItemsTableCreateCompanionBuilder,
      $$CachedMediaItemsTableUpdateCompanionBuilder,
      (
        CachedMediaItem,
        BaseReferences<_$AppDatabase, $CachedMediaItemsTable, CachedMediaItem>,
      ),
      CachedMediaItem,
      PrefetchHooks Function()
    >;
typedef $$LocalWatchHistoriesTableCreateCompanionBuilder =
    LocalWatchHistoriesCompanion Function({
      required String userId,
      required int tmdbId,
      required String mediaType,
      Value<int> season,
      Value<int> episode,
      required String status,
      Value<int> progressSeconds,
      Value<int> totalDuration,
      required DateTime lastWatchedAt,
      Value<int> rowid,
    });
typedef $$LocalWatchHistoriesTableUpdateCompanionBuilder =
    LocalWatchHistoriesCompanion Function({
      Value<String> userId,
      Value<int> tmdbId,
      Value<String> mediaType,
      Value<int> season,
      Value<int> episode,
      Value<String> status,
      Value<int> progressSeconds,
      Value<int> totalDuration,
      Value<DateTime> lastWatchedAt,
      Value<int> rowid,
    });

class $$LocalWatchHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalWatchHistoriesTable> {
  $$LocalWatchHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progressSeconds => $composableBuilder(
    column: $table.progressSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalDuration => $composableBuilder(
    column: $table.totalDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalWatchHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalWatchHistoriesTable> {
  $$LocalWatchHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbId => $composableBuilder(
    column: $table.tmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progressSeconds => $composableBuilder(
    column: $table.progressSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalDuration => $composableBuilder(
    column: $table.totalDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalWatchHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalWatchHistoriesTable> {
  $$LocalWatchHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get tmdbId =>
      $composableBuilder(column: $table.tmdbId, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progressSeconds => $composableBuilder(
    column: $table.progressSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalDuration => $composableBuilder(
    column: $table.totalDuration,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastWatchedAt => $composableBuilder(
    column: $table.lastWatchedAt,
    builder: (column) => column,
  );
}

class $$LocalWatchHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalWatchHistoriesTable,
          LocalWatchHistory,
          $$LocalWatchHistoriesTableFilterComposer,
          $$LocalWatchHistoriesTableOrderingComposer,
          $$LocalWatchHistoriesTableAnnotationComposer,
          $$LocalWatchHistoriesTableCreateCompanionBuilder,
          $$LocalWatchHistoriesTableUpdateCompanionBuilder,
          (
            LocalWatchHistory,
            BaseReferences<
              _$AppDatabase,
              $LocalWatchHistoriesTable,
              LocalWatchHistory
            >,
          ),
          LocalWatchHistory,
          PrefetchHooks Function()
        > {
  $$LocalWatchHistoriesTableTableManager(
    _$AppDatabase db,
    $LocalWatchHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$LocalWatchHistoriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$LocalWatchHistoriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$LocalWatchHistoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<int> tmdbId = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<int> season = const Value.absent(),
                Value<int> episode = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> progressSeconds = const Value.absent(),
                Value<int> totalDuration = const Value.absent(),
                Value<DateTime> lastWatchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWatchHistoriesCompanion(
                userId: userId,
                tmdbId: tmdbId,
                mediaType: mediaType,
                season: season,
                episode: episode,
                status: status,
                progressSeconds: progressSeconds,
                totalDuration: totalDuration,
                lastWatchedAt: lastWatchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required int tmdbId,
                required String mediaType,
                Value<int> season = const Value.absent(),
                Value<int> episode = const Value.absent(),
                required String status,
                Value<int> progressSeconds = const Value.absent(),
                Value<int> totalDuration = const Value.absent(),
                required DateTime lastWatchedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalWatchHistoriesCompanion.insert(
                userId: userId,
                tmdbId: tmdbId,
                mediaType: mediaType,
                season: season,
                episode: episode,
                status: status,
                progressSeconds: progressSeconds,
                totalDuration: totalDuration,
                lastWatchedAt: lastWatchedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalWatchHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalWatchHistoriesTable,
      LocalWatchHistory,
      $$LocalWatchHistoriesTableFilterComposer,
      $$LocalWatchHistoriesTableOrderingComposer,
      $$LocalWatchHistoriesTableAnnotationComposer,
      $$LocalWatchHistoriesTableCreateCompanionBuilder,
      $$LocalWatchHistoriesTableUpdateCompanionBuilder,
      (
        LocalWatchHistory,
        BaseReferences<
          _$AppDatabase,
          $LocalWatchHistoriesTable,
          LocalWatchHistory
        >,
      ),
      LocalWatchHistory,
      PrefetchHooks Function()
    >;
typedef $$CachedUserListsTableCreateCompanionBuilder =
    CachedUserListsCompanion Function({
      required String id,
      required String userId,
      required String name,
      required String type,
      Value<String?> description,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$CachedUserListsTableUpdateCompanionBuilder =
    CachedUserListsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> name,
      Value<String> type,
      Value<String?> description,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$CachedUserListsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedUserListsTable> {
  $$CachedUserListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedUserListsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedUserListsTable> {
  $$CachedUserListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedUserListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedUserListsTable> {
  $$CachedUserListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CachedUserListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedUserListsTable,
          CachedUserList,
          $$CachedUserListsTableFilterComposer,
          $$CachedUserListsTableOrderingComposer,
          $$CachedUserListsTableAnnotationComposer,
          $$CachedUserListsTableCreateCompanionBuilder,
          $$CachedUserListsTableUpdateCompanionBuilder,
          (
            CachedUserList,
            BaseReferences<
              _$AppDatabase,
              $CachedUserListsTable,
              CachedUserList
            >,
          ),
          CachedUserList,
          PrefetchHooks Function()
        > {
  $$CachedUserListsTableTableManager(
    _$AppDatabase db,
    $CachedUserListsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$CachedUserListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CachedUserListsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$CachedUserListsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedUserListsCompanion(
                id: id,
                userId: userId,
                name: name,
                type: type,
                description: description,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String name,
                required String type,
                Value<String?> description = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedUserListsCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                type: type,
                description: description,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedUserListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedUserListsTable,
      CachedUserList,
      $$CachedUserListsTableFilterComposer,
      $$CachedUserListsTableOrderingComposer,
      $$CachedUserListsTableAnnotationComposer,
      $$CachedUserListsTableCreateCompanionBuilder,
      $$CachedUserListsTableUpdateCompanionBuilder,
      (
        CachedUserList,
        BaseReferences<_$AppDatabase, $CachedUserListsTable, CachedUserList>,
      ),
      CachedUserList,
      PrefetchHooks Function()
    >;
typedef $$CachedListItemsTableCreateCompanionBuilder =
    CachedListItemsCompanion Function({
      required String listId,
      required int mediaTmdbId,
      required String mediaType,
      Value<String?> meta,
      Value<int> sortOrder,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$CachedListItemsTableUpdateCompanionBuilder =
    CachedListItemsCompanion Function({
      Value<String> listId,
      Value<int> mediaTmdbId,
      Value<String> mediaType,
      Value<String?> meta,
      Value<int> sortOrder,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$CachedListItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedListItemsTable> {
  $$CachedListItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaTmdbId => $composableBuilder(
    column: $table.mediaTmdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedListItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedListItemsTable> {
  $$CachedListItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get listId => $composableBuilder(
    column: $table.listId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaTmdbId => $composableBuilder(
    column: $table.mediaTmdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedListItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedListItemsTable> {
  $$CachedListItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<int> get mediaTmdbId => $composableBuilder(
    column: $table.mediaTmdbId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$CachedListItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedListItemsTable,
          CachedListItem,
          $$CachedListItemsTableFilterComposer,
          $$CachedListItemsTableOrderingComposer,
          $$CachedListItemsTableAnnotationComposer,
          $$CachedListItemsTableCreateCompanionBuilder,
          $$CachedListItemsTableUpdateCompanionBuilder,
          (
            CachedListItem,
            BaseReferences<
              _$AppDatabase,
              $CachedListItemsTable,
              CachedListItem
            >,
          ),
          CachedListItem,
          PrefetchHooks Function()
        > {
  $$CachedListItemsTableTableManager(
    _$AppDatabase db,
    $CachedListItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$CachedListItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CachedListItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$CachedListItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> listId = const Value.absent(),
                Value<int> mediaTmdbId = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String?> meta = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedListItemsCompanion(
                listId: listId,
                mediaTmdbId: mediaTmdbId,
                mediaType: mediaType,
                meta: meta,
                sortOrder: sortOrder,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String listId,
                required int mediaTmdbId,
                required String mediaType,
                Value<String?> meta = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedListItemsCompanion.insert(
                listId: listId,
                mediaTmdbId: mediaTmdbId,
                mediaType: mediaType,
                meta: meta,
                sortOrder: sortOrder,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedListItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedListItemsTable,
      CachedListItem,
      $$CachedListItemsTableFilterComposer,
      $$CachedListItemsTableOrderingComposer,
      $$CachedListItemsTableAnnotationComposer,
      $$CachedListItemsTableCreateCompanionBuilder,
      $$CachedListItemsTableUpdateCompanionBuilder,
      (
        CachedListItem,
        BaseReferences<_$AppDatabase, $CachedListItemsTable, CachedListItem>,
      ),
      CachedListItem,
      PrefetchHooks Function()
    >;
typedef $$AnimeExternalMappingsTableCreateCompanionBuilder =
    AnimeExternalMappingsCompanion Function({
      Value<int> anilistId,
      Value<int?> anidbId,
      Value<int?> tmdbShowId,
      Value<int?> tmdbMovieId,
      Value<int?> tvdbId,
      Value<String?> mappingsData,
    });
typedef $$AnimeExternalMappingsTableUpdateCompanionBuilder =
    AnimeExternalMappingsCompanion Function({
      Value<int> anilistId,
      Value<int?> anidbId,
      Value<int?> tmdbShowId,
      Value<int?> tmdbMovieId,
      Value<int?> tvdbId,
      Value<String?> mappingsData,
    });

class $$AnimeExternalMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $AnimeExternalMappingsTable> {
  $$AnimeExternalMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anidbId => $composableBuilder(
    column: $table.anidbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbShowId => $composableBuilder(
    column: $table.tmdbShowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tmdbMovieId => $composableBuilder(
    column: $table.tmdbMovieId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tvdbId => $composableBuilder(
    column: $table.tvdbId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mappingsData => $composableBuilder(
    column: $table.mappingsData,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnimeExternalMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnimeExternalMappingsTable> {
  $$AnimeExternalMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anidbId => $composableBuilder(
    column: $table.anidbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbShowId => $composableBuilder(
    column: $table.tmdbShowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tmdbMovieId => $composableBuilder(
    column: $table.tmdbMovieId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tvdbId => $composableBuilder(
    column: $table.tvdbId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mappingsData => $composableBuilder(
    column: $table.mappingsData,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnimeExternalMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnimeExternalMappingsTable> {
  $$AnimeExternalMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<int> get anidbId =>
      $composableBuilder(column: $table.anidbId, builder: (column) => column);

  GeneratedColumn<int> get tmdbShowId => $composableBuilder(
    column: $table.tmdbShowId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tmdbMovieId => $composableBuilder(
    column: $table.tmdbMovieId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tvdbId =>
      $composableBuilder(column: $table.tvdbId, builder: (column) => column);

  GeneratedColumn<String> get mappingsData => $composableBuilder(
    column: $table.mappingsData,
    builder: (column) => column,
  );
}

class $$AnimeExternalMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnimeExternalMappingsTable,
          AnimeExternalMapping,
          $$AnimeExternalMappingsTableFilterComposer,
          $$AnimeExternalMappingsTableOrderingComposer,
          $$AnimeExternalMappingsTableAnnotationComposer,
          $$AnimeExternalMappingsTableCreateCompanionBuilder,
          $$AnimeExternalMappingsTableUpdateCompanionBuilder,
          (
            AnimeExternalMapping,
            BaseReferences<
              _$AppDatabase,
              $AnimeExternalMappingsTable,
              AnimeExternalMapping
            >,
          ),
          AnimeExternalMapping,
          PrefetchHooks Function()
        > {
  $$AnimeExternalMappingsTableTableManager(
    _$AppDatabase db,
    $AnimeExternalMappingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AnimeExternalMappingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$AnimeExternalMappingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$AnimeExternalMappingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<int?> anidbId = const Value.absent(),
                Value<int?> tmdbShowId = const Value.absent(),
                Value<int?> tmdbMovieId = const Value.absent(),
                Value<int?> tvdbId = const Value.absent(),
                Value<String?> mappingsData = const Value.absent(),
              }) => AnimeExternalMappingsCompanion(
                anilistId: anilistId,
                anidbId: anidbId,
                tmdbShowId: tmdbShowId,
                tmdbMovieId: tmdbMovieId,
                tvdbId: tvdbId,
                mappingsData: mappingsData,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<int?> anidbId = const Value.absent(),
                Value<int?> tmdbShowId = const Value.absent(),
                Value<int?> tmdbMovieId = const Value.absent(),
                Value<int?> tvdbId = const Value.absent(),
                Value<String?> mappingsData = const Value.absent(),
              }) => AnimeExternalMappingsCompanion.insert(
                anilistId: anilistId,
                anidbId: anidbId,
                tmdbShowId: tmdbShowId,
                tmdbMovieId: tmdbMovieId,
                tvdbId: tvdbId,
                mappingsData: mappingsData,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnimeExternalMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnimeExternalMappingsTable,
      AnimeExternalMapping,
      $$AnimeExternalMappingsTableFilterComposer,
      $$AnimeExternalMappingsTableOrderingComposer,
      $$AnimeExternalMappingsTableAnnotationComposer,
      $$AnimeExternalMappingsTableCreateCompanionBuilder,
      $$AnimeExternalMappingsTableUpdateCompanionBuilder,
      (
        AnimeExternalMapping,
        BaseReferences<
          _$AppDatabase,
          $AnimeExternalMappingsTable,
          AnimeExternalMapping
        >,
      ),
      AnimeExternalMapping,
      PrefetchHooks Function()
    >;
typedef $$AnimeKitsuMappingsTableCreateCompanionBuilder =
    AnimeKitsuMappingsCompanion Function({
      Value<int> anilistId,
      required String kitsuId,
      Value<int?> episodeCount,
      Value<DateTime> updatedAt,
    });
typedef $$AnimeKitsuMappingsTableUpdateCompanionBuilder =
    AnimeKitsuMappingsCompanion Function({
      Value<int> anilistId,
      Value<String> kitsuId,
      Value<int?> episodeCount,
      Value<DateTime> updatedAt,
    });

class $$AnimeKitsuMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $AnimeKitsuMappingsTable> {
  $$AnimeKitsuMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitsuId => $composableBuilder(
    column: $table.kitsuId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnimeKitsuMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnimeKitsuMappingsTable> {
  $$AnimeKitsuMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get anilistId => $composableBuilder(
    column: $table.anilistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitsuId => $composableBuilder(
    column: $table.kitsuId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnimeKitsuMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnimeKitsuMappingsTable> {
  $$AnimeKitsuMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anilistId =>
      $composableBuilder(column: $table.anilistId, builder: (column) => column);

  GeneratedColumn<String> get kitsuId =>
      $composableBuilder(column: $table.kitsuId, builder: (column) => column);

  GeneratedColumn<int> get episodeCount => $composableBuilder(
    column: $table.episodeCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AnimeKitsuMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnimeKitsuMappingsTable,
          AnimeKitsuMapping,
          $$AnimeKitsuMappingsTableFilterComposer,
          $$AnimeKitsuMappingsTableOrderingComposer,
          $$AnimeKitsuMappingsTableAnnotationComposer,
          $$AnimeKitsuMappingsTableCreateCompanionBuilder,
          $$AnimeKitsuMappingsTableUpdateCompanionBuilder,
          (
            AnimeKitsuMapping,
            BaseReferences<
              _$AppDatabase,
              $AnimeKitsuMappingsTable,
              AnimeKitsuMapping
            >,
          ),
          AnimeKitsuMapping,
          PrefetchHooks Function()
        > {
  $$AnimeKitsuMappingsTableTableManager(
    _$AppDatabase db,
    $AnimeKitsuMappingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AnimeKitsuMappingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$AnimeKitsuMappingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$AnimeKitsuMappingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                Value<String> kitsuId = const Value.absent(),
                Value<int?> episodeCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AnimeKitsuMappingsCompanion(
                anilistId: anilistId,
                kitsuId: kitsuId,
                episodeCount: episodeCount,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> anilistId = const Value.absent(),
                required String kitsuId,
                Value<int?> episodeCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AnimeKitsuMappingsCompanion.insert(
                anilistId: anilistId,
                kitsuId: kitsuId,
                episodeCount: episodeCount,
                updatedAt: updatedAt,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnimeKitsuMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnimeKitsuMappingsTable,
      AnimeKitsuMapping,
      $$AnimeKitsuMappingsTableFilterComposer,
      $$AnimeKitsuMappingsTableOrderingComposer,
      $$AnimeKitsuMappingsTableAnnotationComposer,
      $$AnimeKitsuMappingsTableCreateCompanionBuilder,
      $$AnimeKitsuMappingsTableUpdateCompanionBuilder,
      (
        AnimeKitsuMapping,
        BaseReferences<
          _$AppDatabase,
          $AnimeKitsuMappingsTable,
          AnimeKitsuMapping
        >,
      ),
      AnimeKitsuMapping,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedMediaItemsTableTableManager get cachedMediaItems =>
      $$CachedMediaItemsTableTableManager(_db, _db.cachedMediaItems);
  $$LocalWatchHistoriesTableTableManager get localWatchHistories =>
      $$LocalWatchHistoriesTableTableManager(_db, _db.localWatchHistories);
  $$CachedUserListsTableTableManager get cachedUserLists =>
      $$CachedUserListsTableTableManager(_db, _db.cachedUserLists);
  $$CachedListItemsTableTableManager get cachedListItems =>
      $$CachedListItemsTableTableManager(_db, _db.cachedListItems);
  $$AnimeExternalMappingsTableTableManager get animeExternalMappings =>
      $$AnimeExternalMappingsTableTableManager(_db, _db.animeExternalMappings);
  $$AnimeKitsuMappingsTableTableManager get animeKitsuMappings =>
      $$AnimeKitsuMappingsTableTableManager(_db, _db.animeKitsuMappings);
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appDatabaseHash() => r'105bd8a8ef41e172ff5db2d8e451479a0697fd42';

/// See also [appDatabase].
@ProviderFor(appDatabase)
final appDatabaseProvider = Provider<AppDatabase>.internal(
  appDatabase,
  name: r'appDatabaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppDatabaseRef = ProviderRef<AppDatabase>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
