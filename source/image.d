module image;

import std.conv : to;

import std.windows.syserror;

import bindbc.sdl;
import bindbc.sdl.image;

import errors;

public interface Image
{
    immutable int Width() pure @nogc nothrow;
    immutable int Height() pure @nogc nothrow;
    public void DrawCenteredAt(const double x, const double y,  ubyte opacity = 255, const ubyte r = 255, const ubyte g = 255, const ubyte b = 255, const double scale = 1.0);
    public void Draw(const double x, const double y, const ubyte opacity = 255, const ubyte r = 255, const ubyte g = 255, const ubyte b = 255, const double scale = 1.0);
    
    public static Image Load(string filename)(SDL_Renderer* renderer)
    {
        return new ImageSource!filename(renderer);
    }
}

private final class ImageSource(string filename) : Image
{
    private immutable int width;
    immutable int Width() pure @nogc nothrow { return width; }
    
    private immutable int height;
    immutable int Height() pure @nogc nothrow { return height; }
    
    private SDL_Renderer* renderer;
    private SDL_Texture* texture;
    
    this(SDL_Renderer* renderer)
    {
        this.renderer = renderer;
        immutable file = import(filename);
        
        auto memory = SDL_RWFromConstMem(cast(const void*)file, file.length);
        if (memory is null)
            ThrowSDLError("SDL_LoadBMP, " ~ filename);
        
        auto surface = SDL_LoadBMP_RW(memory, 1);    
        if (surface is null)
            ThrowSDLError("SDL_LoadBMP, " ~ filename);
        
        scope(exit) surface.SDL_FreeSurface;
        
        width = surface.clip_rect.w;
        height = surface.clip_rect.h;
        CheckSDLError(surface.SDL_SetColorKey(SDL_FALSE, 0), filename);
        
        texture = SDL_CreateTextureFromSurface(renderer, surface);
        
        if (texture is null)
            ThrowSDLError;
    }
    
    // ~this()
    // {
    //     texture.SDL_DestroyTexture;
    // }
    
    public void DrawCenteredAt(const double x, const double y,  ubyte opacity = 255, const ubyte r = 255, const ubyte g = 255, const ubyte b = 255, const double scale = 1.0) 
    {
        Draw(x - width / 2, y - height / 2, opacity, r, g, b, scale);
    }
    
    public void Draw(const double x, const double y, const ubyte opacity = 255, const ubyte r = 255, const ubyte g = 255, const ubyte b = 255, const double scale = 1.0)
    {
        auto destination = SDL_Rect(x.to!int, 
                                    y.to!int, 
                                    (width * scale).to!int, 
                                    (height * scale).to!int); 
        
        CheckSDLError(SDL_SetTextureAlphaMod(texture, opacity), filename);
        CheckSDLError(SDL_SetTextureColorMod(texture, r, g, b), filename);
        CheckSDLError(SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND), filename);
        CheckSDLError(SDL_RenderCopy(renderer, texture, null, &destination), filename);
    }
}
