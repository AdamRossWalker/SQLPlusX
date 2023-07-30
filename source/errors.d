module errors;

import std.conv : to;

import derelict.sdl2.sdl;

import common;

void CheckSDLError(string context = null, string file = __FILE__, size_t line = __LINE__) @trusted 
{
    if (SDL_GetError().FromCString == "")
        return;
    
    ThrowSDLError(context, 0, file, line);
}

void CheckSDLError(int returnCode, string context = null, string file = __FILE__, size_t line = __LINE__) @safe 
{
    if (returnCode == 0)
        return;
    
    ThrowSDLError(context, returnCode, file, line);
}

void ThrowSDLError(string context = null, int returnCode = 0, string file = __FILE__, size_t line = __LINE__) @trusted
{
    throw new SDLException(
        "\n\nSDL Error: " ~
        SDL_GetError().FromCString ~ 
        "\n" ~
        (returnCode == 0 ? "" : "\n\tCode: " ~ returnCode.to!string) ~ 
        (context == null ? "" : "\n\tContext: " ~ context) ~ 
        "\n\tFile: " ~ file ~ 
        "\n\tLine: " ~ line.to!string, 
        SDL_GetError().FromCString, 
        file, 
        line);
}

public final class SDLException : Exception
{
    public string InnerMessage;

    this(string s, string innerMessage, string file = __FILE__, size_t line = __LINE__) @safe 
    {
        InnerMessage = innerMessage;
        super(s, file, line);
    }
}

public final class NonRecoverableException : Exception
{
    this(string message, string file = __FILE__, size_t line = __LINE__) pure @safe @nogc nothrow
    {
        super(message, file, line);
    }
}

public class RecoverableException : Exception
{
    this(string message, string file = __FILE__, size_t line = __LINE__) pure @safe @nogc nothrow
    {
        super(message);
    }
}