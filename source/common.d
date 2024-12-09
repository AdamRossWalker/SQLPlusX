module common; @safe

import std.algorithm : max, min, any;
import std.conv : to, toChars, LetterCase;
import std.datetime : Duration;
import std.stdio : File;
import std.range : padLeft, padRight, walkLength;
import std.traits : Unqual;
import std.typecons : Tuple, Flag, Yes, No;
import std.utf : byDchar;

import utf8_slice;

public enum FormattingMode { Apply, Hidden, Disabled }
public enum FontStyle { Normal, Bold }
public enum NamedColor { Normal, Identifier, QuotedIdentifier, Disabled, Popup, HeaderUnderline, Comment, Function, Package, DatabaseLink, String, Keyword, Good, Warning, Error, Alert, Danger }
public enum SearchDirection { Forward, Backward }

public alias StringReference = const(char)[];

version (Windows)
    enum lineEnding = "\r\n" ;
else
    enum lineEnding = "\n" ;

struct FormattedText
{
    alias Span = Tuple!(StringReference, "Text", int, "StartColumn", NamedColor, "Color", FontStyle, "Style", ubyte, "Opacity");

    StringReference Text;
    const(Span)[] Spans;
    
    this(StringReference text,
        const NamedColor color = NamedColor.Normal, 
        const FontStyle style = FontStyle.Normal, 
        const ubyte opacity = 255)
    {
        this(text, [Span(text, 0, color, style, opacity)]);
    }
    
    this(StringReference text, Span[] spans)
    {
        Text = text;
        Spans = spans;
    }
    
    public void Add(
        const int startOffset, 
        const int endOffset, 
        const NamedColor color = NamedColor.Normal, 
        const FontStyle style = FontStyle.Normal, 
        const ubyte opacity = 255) nothrow
    {
        Spans ~= Span(Text.toUtf8Slice[startOffset .. endOffset], startOffset, color, style, opacity);
    }
}

public string FromCString(const char* source) pure nothrow
{
    import std.conv : to;
    import std.string : fromStringz;

    return source.fromStringz.to!string;
}

public const (char)* ToCString(string source) pure nothrow
{
    import std.string : toStringz;

    return source.toStringz;
}

const(char)[] toStringEmplace(
    int numberLength, 
    char leadingCharacter = ' ', 
    int maxLength, 
    T)
   (T number, 
    return ref char[maxLength] destination) @nogc nothrow
if (is(typeof(T.init % 10 == 0) == bool) &&
    numberLength <= maxLength)
{
    Unqual!T value = number;

    auto isNegative = false;
    if (value < 0)
    {
        isNegative = true;
        value *= -1;
    }
    
    int index = numberLength - 1;
    while (index >= 0)
    {
        destination[index] = cast(char)(value % 10 + 48);
        index--;
        value /= 10;
        
        if (value == 0)
            break;
    }
    
    auto overflow = index < 0 && value > 0;
    
    if (isNegative)
    {
        if (index < 0)
            overflow = true;
        else
        {
            destination[index] = '-';
            index--;
        }
    }
    
    if (overflow)
        destination[0 .. numberLength] = '#';
    else if (index >= 0)
        destination[0 .. index + 1] = leadingCharacter;
    
    return destination[0 .. numberLength];
}

public string DurationToPrettyString(Duration duration)
{
    auto times = duration.split!("hours", "minutes", "seconds", "msecs");
    
    return 
        times.hours  .to!string.padLeft('0', 2).to!string ~ ":" ~ 
        times.minutes.to!string.padLeft('0', 2).to!string ~ ":" ~  
        times.seconds.to!string.padLeft('0', 2).to!string ~ "." ~ 
        times.msecs  .to!string.padLeft('0', 3).to!string;
}


public void DurationToPrettyStringEmplace(Flag!"includeMsecs" includeMsecs = No.includeMsecs)(Duration duration, char[] destination) @nogc nothrow pure
{
    auto times = duration.split!("hours", "minutes", "seconds", "msecs");
    
    //  012345678901
    // "00:00:00.000"
    
    destination[2] = ':';
    destination[5] = ':';
    
    static if (includeMsecs)
        destination[8] = '.';
    
    toStringEmplace!(2, '0', 2)(cast(int)times.hours,   destination[0 .. 2]);
    toStringEmplace!(2, '0', 2)(cast(int)times.minutes, destination[3 .. 5]);
    toStringEmplace!(2, '0', 2)(cast(int)times.seconds, destination[6 .. 8]);
    
    static if (includeMsecs)
        toStringEmplace!(3, '0', 3)(cast(int)times.msecs,   destination[9 .. 12]);
}


public int intLength(T)(const scope ref T array) pure nothrow @safe @nogc
    if (is(typeof(array.length) == size_t))
{
    return cast(int)array.length;
}

public int intLength(T)(const scope T[] array) pure nothrow @safe @nogc
{
    return cast(int)array.length;
}

enum debugLogFileName = "DebugLog.txt";
enum debugLogType { Append, Reset }

private File debugLogFile;

public void DebugLog(string file = __FILE__, int line = __LINE__, T)(lazy string text, T value) nothrow =>
    DebugLog!(debugLogType.Append, file, line)(text ~ " = \"" ~ value.to!string ~ "\"");

public void DebugLog(debugLogType type = debugLogType.Append, string file = __FILE__, int line = __LINE__)(lazy string text) nothrow
{
    try
    {
        import std.datetime.systime : Clock;
        import std.concurrency : thisTid;
        auto output = 
            Clock.currTime.toSimpleString.padRight(' ', 32).to!string ~ 
            file.padRight(' ', 32).to!string ~ 
            line.to!string.padLeft(' ', 8).to!string ~ " " ~ 
            thisTid.to!string.padRight(' ', 16).to!string ~ 
            text;
        
        if (type == debugLogType.Reset || !debugLogFile.isOpen)
            debugLogFile = File(debugLogFileName, "w");
        
        debugLogFile.writeln(output);
        debugLogFile.flush;
    }
    catch(Throwable) { }
}

unittest
{
    char[32] textLocation;
    assert(toStringEmplace!5(0, textLocation) == "    0");
    assert(textLocation[0 .. 5] == "    0");
    
    assert(toStringEmplace!5(123,  textLocation) == "  123");
    assert(textLocation[0 .. 5] == "  123");
    
    assert(toStringEmplace!5(-123, textLocation) == " -123");
    assert(textLocation[0 .. 5] == " -123");

    assert(toStringEmplace!5(1234567, textLocation) == "#####");
    assert(textLocation[0 .. 5] == "#####");

    assert(toStringEmplace!5(12345, textLocation) == "12345");
    assert(textLocation[0 .. 5] == "12345");

    assert(toStringEmplace!5(-12345, textLocation) == "#####");
    assert(textLocation[0 .. 5] ==  "#####");
    
    assert("123".any!(i => i == '2'));
    assert(!"123".any!(i => i == '5'));
}
