# Calendar

Demo app for demonstrating pghttp

pghttp is all about _Elm, Postgres, and nothing inbetween_, so this tutorial demonstrates a
simple calendar database app and an Elm client application.

As of today, only the database is available, shortly to be followed with a pghttp API, and 
then the Elm client app.

## Setting Up

To install the database, one needs Postgres 14 or newer. We're dealing with a lot of dates,
and the design assumes the server operates in the 'UTC' time zone. Maybe that changes later
but for now make sure `timezone` setting in `postgresql.conf` is set to 'UTC'. The query to
check the current setting is `select current_setting('timezone')`.

From terminal, `cd` to `calendar/db/` and run `./resetdb pghttp_calendar`. That should create 
and populate a database named `pghttp_calendar`. To create a database with a different name, 
specify the name as the second parameter: `./resetdb pghttp_calendar my_calendar`. The first time
you run this, the script will generate new owner and access roles and create new password
for the owner. This will get stored in `db.env` in the `pghttp_calendar` folder. Subsequent
runs will reuse the same role names and passwords, and won't re-generate the `.env` file.

The default data consists of a list of a few imaginary conference names, and a list of 
public and school holidays in a bunch of EU countries. We just need a few thousand events
to play with, it's not that important what they are. These were just easily accessible to
import.

## Design

We're interested in tracking a list of events for a wide audience; unlike one's personal
calendar that mostly tracks daily appointments, here we're all about 'full day events,'
like conferences, holidays, etc. The calendar can of course track appointment-style events
but the initial app design is simple.

The central entity is the `event` record. Each event belongs to a single `calendar`,
and can happen at multiple locations. We differentiate between physical and virtual locations. 
A physical location must have at least the country code specified, while for the virtual we
expect at least the URL.

At first page visit, we want to list all ongoing and upcoming events, starting with the nearest 
ongoing or future event. A user can also list all past events, starting with the most recent
and going further into the past.

Since there are a lot of events, we want to limit the amount of data clients are pulling
in each request, so we introduce paging.

We'll list all available calendars, and let the user select which calendars to get the events
from.

There's not much to it beyond that at present.

As of this first iteration, we can only list events--there's no functionality yet to add
new events of manage data in any way from the user interface. Also, all calendars and their 
events are publicly accessible.

## API

We create the API by exposing certain SQL functions. Functions are nice as they remind us of
Elm functions, are more testable and composable, and generally make it more clear what's exposed.
Of course, pghttp API supports SQL queries as well, but we just like functions more.

How do we "expose" an API? Well, nothing really changes in the database. All we need to do is
let pghttp know which functions we want accessible from the web server, and it will
generate the appropriate lookup table for the web server. Each exposed function gets a 16-byte 
opaque ID, and if this ID is not available to the web server, it cannot call it. 

So, we give each function a unique ID and then create a lookup for the web server. Then, from that
same list of exposed functions we generate client-side Elm API code. That's possible since the
database is completely defined with metadata (also stored in the database), so we can query it
to get all the information we need about those functions to generate calling, serializing, 
and deserializing code.

The web server lookup table is generated in the database itself, with a query. It's 
a read-only hash table that the web server knows how to look up.

Where do we keep these API definitions? In our pghttp app, which itself is database-driven!