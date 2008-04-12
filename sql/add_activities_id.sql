create sequence activities_id_seq;
alter table activities alter column id set default nextval('activities_id_seq');
