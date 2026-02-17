## Schema Info                                                                                                                 
| TABLE: list_items
  - list_id (uuid) NOT NULL
  - media_tmdb_id (bigint) NOT NULL
  - media_type (USER-DEFINED) NOT NULL
  - sort_order (integer) NOT NULL
  - meta (jsonb) NULL
  - added_at (timestamp with time zone) NULL

TRIGGERS:
  - None
-------------------                                                                                                                                                  |
| TABLE: lists
  - id (uuid) NOT NULL
  - user_id (uuid) NOT NULL
  - type (USER-DEFINED) NULL
  - name (text) NOT NULL
  - description (text) NULL
  - sort_order (integer) NULL
  - settings (jsonb) NULL
  - created_at (timestamp with time zone) NULL

TRIGGERS:
  - None
-------------------                                                                                                                       |
| TABLE: media_cache
  - tmdb_id (bigint) NOT NULL
  - media_type (USER-DEFINED) NOT NULL
  - title (text) NOT NULL
  - poster_path (text) NULL
  - backdrop_path (text) NULL
  - runtime_minutes (integer) NULL
  - genres (jsonb) NULL
  - release_date (date) NULL
  - cast_members (jsonb) NULL
  - crew_members (jsonb) NULL
  - updated_at (timestamp with time zone) NULL

TRIGGERS:
  - None
------------------- |
| TABLE: profiles
  - id (uuid) NOT NULL
  - username (text) NULL
  - avatar_url (text) NULL
  - preferences (jsonb) NULL
  - created_at (timestamp with time zone) NULL
  - updated_at (timestamp with time zone) NULL

TRIGGERS:
  - None
-------------------                                                                                                                                                          |
| TABLE: reviews
  - id (uuid) NOT NULL
  - user_id (uuid) NOT NULL
  - tmdb_id (bigint) NOT NULL
  - target_type (USER-DEFINED) NOT NULL
  - rating (numeric) NULL
  - review_text (text) NULL
  - spoilers (boolean) NULL
  - created_at (timestamp with time zone) NULL

TRIGGERS:
  - None
-------------------                                                                                                       |
| TABLE: watch_history
  - user_id (uuid) NOT NULL
  - tmdb_id (bigint) NOT NULL
  - media_type (USER-DEFINED) NOT NULL
  - status (text) NULL
  - progress_seconds (integer) NULL
  - total_duration (integer) NULL
  - watch_count (integer) NULL
  - last_watched_at (timestamp with time zone) NULL
  - season (integer) NOT NULL
  - episode (integer) NOT NULL

TRIGGERS:
  - None
-------------------             |
| TABLE: watch_logs
  - id (uuid) NOT NULL
  - user_id (uuid) NOT NULL
  - tmdb_id (bigint) NOT NULL
  - media_type (USER-DEFINED) NOT NULL
  - logged_at (timestamp with time zone) NULL
  - duration_watched_seconds (integer) NULL
  - season (integer) NULL
  - episode (integer) NULL

TRIGGERS:
  - on_log_sync_history (Type: AFTER)
-------------------                                                          |