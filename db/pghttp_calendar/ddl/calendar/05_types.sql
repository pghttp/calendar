CREATE TYPE calendar.location_kind AS ENUM (
    'physical',
    'virtual',
    'global'
);

ALTER TYPE calendar.location_kind OWNER TO pghttp_calendar_db_owner;