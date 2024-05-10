-- Events that last one day ("all day event") have the upper bound 'inf', so we need to convert them to (day, day+1) 
-- in order to match correctly with the query for past events. The past event must be strictly left of the queried
-- interval to be considered past (that is, must be finished) so we can't have single-day events with infinite upper bound.
-- We can of course change that and disallow upper bound to be empty, always forcing the upper bound. That'd possibly
-- gain us up to ~2ms. We'd have to signal 'all day event' differently, then. To be revisited later if the performance becomes 
-- an issue.
create or replace function calendar.full_range(p_range tsrange)
returns tsrange
language sql stable
return 
    case when upper_inf(p_range) 
         then tsrange(lower(p_range), lower(p_range) + '1 day') 
         else p_range 
    end;

alter function calendar.full_range(tsrange) owner to :owner_role;

-- We list all events starting after a given date range, including those that are only overlapping with the specified
-- range. (That is, that started before the specified range but are still ongoing as of the lower bound of the range,
-- and will finish after the upper bound of the range).
create or replace function calendar.list_events(p_calendars int[], p_after tsrange = tsrange('today', null))
returns table (
    id          int
  , event_time  tsrange
  , title       text
  , description text
  , calendar    text
  , locations   record[]
)
language sql stable
begin atomic
with locations as (
    select 'physical' as kind, event_id, iso, city, venue, address, instructions
      from calendar.location_physical
     union all
    select 'virtual', event_id, null, null, null, join_url, instructions
      from calendar.location_virtual
)
select e.id
     , e.event_time
     , e.title
     , e.description
     , c.title calendar
     , array_agg(row(l.kind, l.venue, l.address, l.iso, l.city, l.instructions)) locations
  from calendar.event e
  join calendar.calendar c on c.id = e.calendar_id
  left join locations l on e.id = l.event_id
 where e.calendar_id = any(p_calendars) 
   and calendar.full_range(event_time) && p_after
 group by e.id, c.title
 order by event_time
;
end;

alter function calendar.list_events(int[], tsrange) owner to :owner_role;


create or replace function calendar.list_events_paged(p_calendars int[],  p_page int = 1, p_page_size int = 100, p_after tsrange = tsrange('today', null))
returns table (
    id          int
  , event_time  tsrange
  , title       text
  , description text
  , calendar    text
  , locations   record[]
)
language sql stable
begin atomic
    select id
         , event_time
         , title
         , description
         , calendar
         , locations
      from calendar.list_events(p_calendars, p_after) with ordinality
     where ordinality > paging.offset(p_page, p_page_size)
     order by ordinality
     limit p_page_size;
end;

alter function calendar.list_events_paged(int[], int, int, tsrange) owner to :owner_role;


create or replace function calendar.events_paging_info(p_calendars int[], p_page_size int, p_after tsrange = tsrange('today', null))
returns table (item_count int, page_size int, page_count int)
language sql stable
begin atomic
select count(*)::int item_count
     , p_page_size
     , ceiling(count(*)::float/p_page_size)::int as page_count
  from calendar.list_events(p_calendars, p_after);
end;

alter function calendar.events_paging_info(int[], int, tsrange) owner to  :owner_role;


create or replace function calendar.list_past_events(p_calendars int[], p_before tsrange = tsrange(null, 'today'))
returns table (
    id          int
  , event_time  tsrange
  , title       text
  , description text
  , calendar    text
  , locations   record[]
)
language sql stable
begin atomic
    select id
         , event_time
         , title
         , description
         , calendar
         , locations
      from calendar.list_events(p_calendars, p_before) e
      -- Past event must be strictly to the left, that is, must be finished. This excludes
      -- events that started in the past but are still not finished as of upper(p_before)
     where calendar.full_range(e.event_time) << tsrange(upper(p_before),null, '[)')
     order by event_time desc
    ;
end;

alter function calendar.list_past_events(int[], tsrange) owner to :owner_role;


create or replace function calendar.list_past_events_paged(p_calendars int[],  p_page int = 1, p_page_size int = 100, p_before tsrange = tsrange(null, 'today'))
returns table (
    id          int
  , event_time  tsrange
  , title       text
  , description text
  , calendar    text
  , locations   record[]
)
language sql stable
begin atomic
    select id
         , event_time
         , title
         , description
         , calendar
         , locations
      from calendar.list_past_events(p_calendars, p_before) with ordinality
     where ordinality > paging.offset(p_page, p_page_size)
     order by ordinality
     limit p_page_size;
end;

alter function calendar.list_past_events_paged(int[], int, int, tsrange) owner to :owner_role;


create or replace function calendar.past_events_paging_info(p_calendars int[], p_page_size int, p_before tsrange = tsrange(null, 'today'))
returns table (item_count int, page_size int, page_count int)
language sql stable
begin atomic
select count(*)::int item_count
     , p_page_size
     , ceiling(count(*)::float/p_page_size)::int as page_count
  from calendar.list_past_events(p_calendars, p_before);
end;

alter function calendar.past_events_paging_info(int[], int, tsrange) owner to :owner_role;


create or replace function calendar.list_calendars()
returns table (
    id int
  , title           text
  , event_count     int
  , date_range      daterange
)
language sql stable
begin atomic
select c.id
     , c.title
     , count(e.*)::int as event_count
     , daterange(min(lower(event_time)::date), max(upper(event_time))::date) date_range
  from calendar.calendar c
  join calendar.event e on e.calendar_id = c.id
  group by c.id, c.title
 order by title, date_range;
end;

alter function calendar.list_calendars() owner to :owner_role;


create or replace function calendar.calendars_paging_info(p_page_size int)
returns table (item_count int, page_size int, page_count int)
language sql stable
begin atomic
select count(*)::int item_count
     , p_page_size
     , ceiling(count(*)::float/p_page_size)::int as page_count
  from calendar.list_calendars();
end;

alter function calendar.calendars_paging_info(int) owner to :owner_role;


create or replace function calendar.list_calendars_paged(p_page int, p_page_size int = 100)
returns table (
    id int
  , title           text
  , event_count     int
  , date_range      daterange
)
language sql stable
begin atomic
select id
     , title
     , event_count
     , date_range
  from calendar.list_calendars() with ordinality
     where ordinality > paging.offset(p_page, p_page_size)
     order by ordinality
     limit p_page_size;
end;

alter function calendar.list_calendars_paged(int, int) owner to :owner_role;
