-- REV-360: the advisor's "unindexed foreign key" on tv_channels.link_service.
-- Renaming or deleting a tv_link_services row looks up its channels by it.

create index tv_channels_link_service_idx on public.tv_channels (link_service);
