-- The keys and installed addons live in user_secrets since
-- 20261016185318_user_secrets; the app no longer reads the old copies in
-- profiles.preferences. Remove them (compared first on production: none
-- held anything user_secrets lacks). patch_preferences keeps dropping these
-- keys if anything sends them.

update public.profiles
set preferences = preferences - array[
  'realDebridKey', 'torBoxKey', 'openSubtitlesKey', 'installedAddons'
]
where jsonb_typeof(preferences) = 'object'
  and preferences ?| array[
    'realDebridKey', 'torBoxKey', 'openSubtitlesKey', 'installedAddons'
  ];
