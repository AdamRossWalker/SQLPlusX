
# SQLPlusX Developers

## Coding Style

This is a hacky code base which many programmers will call a mess and wrong.  I 
feel the need to justify my actions and hopefully lessen your wrath.  The program 
was a solo passion project and therefore an opportunity to perfom several experiments
which I will detail below.  However, the main reason is that I think the product is 
more important than the code base.  James Hague has an inspiring blog and he returns
to this concept many times.  A good read is _Write Code Like You Just Learned How to Program_.

### 1. Can Just Hacking Work?

How well will this work with straight up hacking and without conforming to SOLID, 
OO everywhere, information hiding, and no complex up-front design.  If you think 
this is crazy, check out Casey Muratori on _Clean Code, Horrible Performance_.

The result?  Yeah, some of the code and structure is not great.  But all programs 
have those problems.  On the plus side; it's fast.  It opens fast, collects data 
fast, performs statement completion fast, everything.  This is a large win in an 
era where some modern programs can't even keep up with typing and every click can be 
measured in whole seconds.  There's lots of room for refactorings though.

### 2. My first large program in DLang

A lot of the coding style is not idiomatic D.  This is my fault for still having
one foot in the C# camp, and also just not understanding D's idioms.  Some places 
I have started to rectify, and now the code is fairly inconsistent with itself.

D templates are wonderful.  The Commands and Settings are all fully described by 
attributes, and these are processed at compile time to create a parser, help 
commands, etc.  The release build has become exceptionally slow, but debug is fast 
and so fixing it has never become a priority.

### 3. Game programming graphics

The UI is drawn frame by frame using game techniques.
Retained mode desktop UI frameworks need to waste time with INotifyPropertyChanged
and similar kludges.  Immeditate mode just draws the value at that instant.  It's 
also naturally asynchronous.

The result?  It's a clear performance win with the cost of more manual effort.  An immediate 
mode library would be good if this did more than a command line UI.

## Build

I don't understand build systems very well.  I have a batch file and dub and that 
seems to work fine.  I have never tried building on Linux or anywhere other than 
Windows.  In theory there's no reason why it won't work because D, SDL, and OCI are 
all portable.  However there are a few dependencies in the code base which should be 
fixable.
