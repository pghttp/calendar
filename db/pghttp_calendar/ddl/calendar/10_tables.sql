create table calendar.calendar (
    id          integer not null generated always as identity primary key,
    title       text not null unique
);
alter table calendar.calendar owner to pghttp_calendar_db_owner;


create table calendar.event (
    id              integer not null generated always as identity primary key,
    calendar_id     int not null references calendar.calendar(id) on delete cascade,
    title           text not null,
    description     text,
    url             text,
    event_time      tsrange not null
);
alter table calendar.event owner to pghttp_calendar_db_owner;


create table calendar.location_physical (
    event_id        int not null references calendar.event(id) on delete cascade,
    iso             text,
    city            text,
    venue           text,
    address         text,
    instructions    text
);
alter table calendar.location_physical owner to pghttp_calendar_db_owner;


create table calendar.location_virtual (
    event_id        int not null references calendar.event(id) on delete cascade,
    join_url        text,
    instructions    text
);
alter table calendar.location_virtual owner to pghttp_calendar_db_owner;

