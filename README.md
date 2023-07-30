
# SQLPlusX

![SQLPlusX Logo](./images/main-icon/flat/SQLPlusX-256.png)

[Gallery](./gallery.md)

SQLPlusX is a command line Oracle tool that follows the spirit of
SQL\*Plus (specifically the deprecated sqlplusw.exe) and is compatible
with many SQL\*Plus commands.  The name derives from “one after sqlplusw”
as well as implying “Extended”.

The goal is to provide the rapid workflow of a command line with some of
the power of heavier programs like TOAD or SQL Developer while being much
faster and more fluid than any of these offerings. 

SQLPlusX was written from the ground up in D following handmade
principles.  It does not use the JVM or .NET and so has instant start up
times.  The only third party libraries it uses are SDL for graphics/IO,
and OCI directly for Oracle.  The user interface is drawn using game 
programming principles and so benefits include visual fidelity and an 
ultra-low latency workflow.

## Features

### Multithreaded Database Access, Cancellation

All database calls are executed against a worker thread.  This means any
blocking calls do not interrupt user activity.  The user is free to work
on a follow up query aiding workflow, copy results, and most importantly
cancel the query.  Cancellation uses OCIBreak() from another thread so
will cancel a query even when no results are being returned.  It does
not do any parallelisation of queries outside of what Oracle already offers.

SQLPlusX also tries to keep sessions open by sending a silent 
`SELECT 1 FROM DUAL;` if there has been no activity in a while.  There is 
a new RECON\[NECT\] command that quickly re-establishes a connection if 
one has been lost.

### Results Layout

Although SQLPlusX follows a command line model, the buffer history is
not stored internally as plain text like in most terminal applications. 
This means a table of results is free to balance its column widths even
while results are still being returned.  It can then make best use of
the horizontal space available while still giving the plain-text
selection and copy feel.

The buffer is designed to be aritrarily wide, so you can do the obvious 
`SELECT * FROM wide_table;` and have readable results without needing 
to configure client options accordingly.

Column values wider than the displayed width can display their full text
on mouse rollover rather than being truncated.  Furthermore, CLOBs are
fetched for you and can be viewed in the same way.  Ctrl-Shift-C copies
the whole result set in MS-Excel designed format (as formulae, so “3-5” isn’t
turned into a date).  Ctrl-Alt-C copies a full field for easy access to
a CLOB or a large VARCHAR2.

Record history is retained based on the memory footprint, so narrow
results can story more rows.  Large result sets are truncated first, so
you don’t lose previous commands and results above just because the last 
query returned 1m rows.

### Queued Commands

SQLPlusX includes a command queue so you can write commands while others
are still running.  You can also paste in a bunch of commands to have
them queued.  SQL\*Plus sort of “accidentally” does this by caching the
pasted text but hits a low arbitrary limit.  SQLPlusX has this feature
specifically designed in.


### Command History

A history of commands is retained in a way similar to most command
lines.  ACCEPT prompts also hold their own histories based on the name
of the define variable.  So re-running the same or similar scripts
allows easy access to previous arguments used.

You can use Alt-Up/Alt-Down to change the selection.  Many users may 
expect Up/Down to do this, but that hampers multiline editing which I 
felt was more important.

### Statement Completion

When a session connects, a background thread collects data on database
objects.  Once this has completed the data is cached to provide
instantaneous query completion.  This does not cover the SQL or PL/SQL
languages, but does cover tables in a FROM clause or columns in a WHERE
clause for example.  Statement Completion is also used by several client
commands.  For example EXEC\[UTE\] will list packages and @ will list
files in all search paths.

You can use Ctrl-Up/Ctrl-Down to change the selection.  Many users may 
expect Up/Down to do this, but that hampers multiline editing which I 
felt was more important.

### SQL\*Plus Compatibility

SQLPlusX is designed to replace SQL\*Plus and so many common commands
continue to work as-is.  Some examples are @, ACC\[EPT\], ED\[IT\],
EXEC\[UTE\], EXIT, BRE\[AK\], COMP\[UTE\], CL\[EAR\], COL\[UMN\], CONN\[ECT\],
DESC\[RIBE\], DISC\[ONNECT\], HELP, HOST, PASSW\[ORD\], PAU\[SE\], PRO\[MPT\],
SET, SHOW, SP\[OOL\], TIMI\[NG\].

The list is not currently conclusive (i.e. report formatting commands
are mostly unsupported at the time of writing).  There are also new
commands such as RECON\[NECT\] (useful after being kicked out), SOURCE
(see below), and DESCRIBE works on more objects now.  Use HELP for a 
full list.

### Syntax Highlighting, Source Code

SQLPlusX includes syntax highlighting for SQL and PL/SQL, including
database objects like DESC\[RIBE\] against a package.  The SOURCE command
queries ALL\_SOURCE and/or ALL\_VIEWS and highlights the results.

## Deployment

Several DLLs are required for OCI (Oracle) and SDL (graphics).  These must 
be in the same directory as the executable.  

### Oracle

If an Oracle client is installed and the correct environment variables are
configured, that should be sufficient to connect to Oracle without needing 
to include these.  

However, if these files are present it can be run directly from the 
executable with no other installations.  The version numbers below (11 
in this example) can be different as long as all DLLs come from the same 
release.

They can be downloaded from Oracle as the _Instant Client Light_.  Oracle 
people are usually familiar with TNSNames so please perform separate 
research if this is new to you.

|File             |Description
|:----------------|:----------
|oci.dll          |Forwarding functions that applications link with.
|oci.sym          |Forwarding functions (Symbols)
|orannzsbb11.dll  |Security Library
|orannzsbb11.sym  |Security Library (Symbols)
|oraociei11.dll   |Data and code
|oraociei11.sym   |Data and code (Symbols)
|tnsnames.ora     |This can go in the target directory, or you can specify the TNSNames directly in the connection.

## SDL

SDL is used for graphics.  The following can be downloaded from:
[SDL](https://github.com/libsdl-org/SDL/releases/tag/release-2.28.1), 
[SDL TTF](https://github.com/libsdl-org/SDL_ttf/releases), and 
[FreeType](https://freetype.org/download.html).

|File             |Description             |
|:----------------|:----------             |
|SDL2.dll         |Base library            |
|SDL2_image.dll   |Image routines          |
|SDL2_ttf.dll     |Font routines           |
|libfreetype-6.dll|Font routines           |
|zlib1.dll        |Data compression library|
