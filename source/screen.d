module screen;

import std.array: array;
import std.algorithm : max, min, map;
import std.conv : to;
import std.math : abs, ceil, pow;
import std.string : toStringz;
import std.traits : EnumMembers;
import std.typecons : Nullable, Flag, Yes, No;
import std.datetime : Duration, dur;
import std.utf : byDchar;

import bindbc.sdl;
import bindbc.sdl.image;
import bindbc.sdl.ttf;

import program;
import logo;
import image;
import most_recently_used_cache;
import utf8_slice;

debug public static string DebugText;

extern (C)
int SDLFilterEventHandler(void* userdata, SDL_Event* event) nothrow
{
    if (event.type == SDL_RENDER_DEVICE_RESET)
    {
        DebugLog("SDL_RENDER_DEVICE_RESET");
        auto screen = cast(Screen)userdata;
        screen.InvalidateImages;
        return 0;
    }
    
    if (event.type == SDL_WINDOWEVENT)
    {    
        // DebugLog("event.window.event PREVIEW", event.window.event);
        
        if (event.window.event == SDL_WINDOWEVENT_MINIMIZED)
        {
            auto screen = cast(Screen)userdata;
            return 0;
        }
        
        if (event.window.event == SDL_WINDOWEVENT_RESIZED)
        {
            // string eventName;
            // switch (event.window.event)
            // {
            //     case SDL_WINDOWEVENT_RESIZED:   eventName = "SDL_WINDOWEVENT_RESIZED";    break;
            //     case SDL_WINDOWEVENT_MAXIMIZED: eventName = "SDL_WINDOWEVENT_MAXIMIZED";  break;
            //     case SDL_WINDOWEVENT_MINIMIZED: eventName = "SDL_WINDOWEVENT_MINIMIZED";  break;
            //     case SDL_WINDOWEVENT_RESTORED:  eventName = "SDL_WINDOWEVENT_RESTORED";   break;
            //    // case SDL_WINDOWEVENT_HIDDEN:    eventName = "SDL_WINDOWEVENT_HIDDEN";     break;
            //    // case SDL_WINDOWEVENT_EXPOSED:   eventName = "SDL_WINDOWEVENT_EXPOSED";    break;
            //     default:                        eventName = "UNKNOWN WINDOWEVENT";        break;
            // }
            // 
            // DebugLog(eventName);
            
            // The message pump runs something that handles the screen 
            // re-size and this blocks the main thread while the mouse 
            // button is down.  
            // 
            // This handler gives a preview of the message before it's 
            // posted to the main queue for filtering purposes.  I'm
            // using it as a hacky work around so I can call the draw 
            // method during the resize.
            // 
            // https://stackoverflow.com/a/50858339
            // 
            // There is also a suggestion that this may be called from 
            // another thread.  That doesn't seem to be the case for 
            // me (hence the problem) and other sources say the Windows
            // version is synchronous.  However, if this is not the case
            // in the future, then we can just remove the Update line 
            // below and InvalidateWindowSizes (with synchronization) 
            // will do the trick.
            
            auto screen = cast(Screen)userdata;
            screen.InvalidateWindowSizes;
            
            try
                screen.Update(0, 0);
            catch (Throwable) 
            { 
                // I can't make Update() nothrow, and I certainly can't 
                // handle it here.  If something does go wrong here, we 
                // should be seeing it in the main loop version too.
            }
            
            return 0; // Signals the message as handled.
        }
    }
    
    return 1;
}

public enum InterfaceTheme { SqlPlus, Sky, Space, Dark, Terminal, SpaceTerminal, Pink, Lilac, Production }
public enum BackgroundTexture { None, Hash, Confetti, Swirl, Noise, NoiseFine, HorizontalBrush }

version (LittleEndian)
    public enum nativePixelFormat = SDL_PIXELFORMAT_ABGR8888;
else
    public enum nativePixelFormat = SDL_PIXELFORMAT_RGBA8888;

public uint pixelValue(SDL_Color color)
{
    // The header comment on SDL_Color says this is OK.
    // https://github.com/libsdl-org/SDL/blob/main/include/SDL_pixels.h
    return *cast(uint*)&color;
}

private void Destroy(SDL_Texture* texture) @trusted nothrow
{
    if (texture is null)
        return;
        
    texture.SDL_DestroyTexture;
    
    // Sometimes the texture has already been freed/lost (but we have a pointer.
    // Call clear error.
    if (SDL_GetError().FromCString == "Invalid texture")
        SDL_ClearError();
}

private struct Popup
{
    private auto isVisible = false;
    private auto totalLineCount = 0;
    private auto totalWidthInCharacters = 0;
    private auto visibleCharacterCount = 0;
    private auto visibleLineCount = 0;
    public auto verticalScrollOffset = 0;
    public auto horizontalScrollOffset = 0;
    
    public auto isVerticallyScrollable()
    {
        return isVisible && visibleLineCount < totalLineCount;
    }
    
    public auto isHorizontallyScrollable()
    {
        return isVisible && visibleCharacterCount < totalWidthInCharacters;
    }
    
    public auto moveVerticallyBy(int numberOfLines)
    {
        if (!isVerticallyScrollable)
            return false;
        
        Program.Screen.Invalidate;
        verticalScrollOffset = max(0, min(verticalScrollOffset + numberOfLines, totalLineCount - visibleLineCount));
        return true;
    }
    
    public auto moveHorizontallyBy(int numberOfCharacters)
    {
        if (!isHorizontallyScrollable)
            return false;
        
        Program.Screen.Invalidate;
        horizontalScrollOffset = max(0, min(horizontalScrollOffset + numberOfCharacters, totalWidthInCharacters - visibleCharacterCount));
        return true;
    }
    
    public auto moveUpByOnePage()
    {
        return moveVerticallyBy(-visibleLineCount);
    }
    
    public auto moveDownByOnePage()
    {
        return moveVerticallyBy(visibleLineCount);
    }
}

public final class Screen
{
    private Buffer buffer;
    private SDL_Renderer* renderer;
    private SDL_Window* window;
    
    private SDL_Cursor* activeMouseCursor;
    private SDL_Cursor* defaultMouseCursor;
    private SDL_Cursor* iBeamMouseCursor;
    private SDL_Cursor* gripSizingMouseCursor;
    
    mixin template ColorSetting()
    {
        private SDL_Color _color;
        
        public const SDL_Color color() @nogc nothrow { return _color; }
        
        public void color(ubyte r, ubyte g, ubyte b, ubyte a) @nogc nothrow { _color = SDL_Color(r, g, b, a); }
        
        public void color(SDL_Color color) @nogc nothrow { _color = color; }
    }
    
    public static enum ColorNames 
    {
        background,
        scanLine,
        selection,
        cursor,
        headerBackground,
        headerUnderLine,
        scrollBarBackground,
        scrollBarButton,
        popupBackground,
        popupBorder,
        popupDropShadow,
        
        normalText,
        normalTextOutline,
        identifierText,
        identifierTextOutline,
        quotedIdentifierText,
        quotedIdentifierTextOutline,
        commentText,
        commentTextOutline,
        functionText,
        functionTextOutline,
        packageText,
        packageTextOutline,
        databaseLinkText,
        databaseLinkTextOutline,
        stringText,
        stringTextOutline,
        keywordText,
        keywordTextOutline,
        goodText,
        goodTextOutline,
        warningText,
        warningTextOutline,
        errorText,
        errorTextOutline,
        alertText,
        alertTextOutline,
        popupText,
        popupTextOutline,
        disabledText,
        disabledTextOutline,
        dangerTextOutline,
        dangerTextGlow, 
    };
    
    static foreach (colorName; EnumMembers!(ColorNames))
        mixin("mixin ColorSetting " ~ colorName.to!string ~ ";");
    
    enum white = SDL_Color(255, 255, 255, 255);
    enum black = SDL_Color(  0,   0,   0, 255);
    private auto isOutliningNormalText = false;
    
    public auto windowLeft   = 800;
    public auto windowTop    = 100;
    public auto windowWidth  = 1024;
    public auto windowHeight = 600; 
    
    private auto mouseX = 0; 
    private auto mouseY = 0; 
    
    enum FontDrawModes { Solid, Blend, Shade }
    private auto fontDrawMode = FontDrawModes.Blend;
    public auto FontDrawMode() @nogc nothrow { return fontDrawMode; }
    public auto FontDrawMode(FontDrawModes newFontDrawMode) @nogc nothrow
    { 
        fontDrawMode = newFontDrawMode; 
        Invalidate;
        InvalidateFont;
    }
    
    enum FontHints { None, Normal, Light, Mono, LightSubPixel }
    private auto fontHint = FontHints.Mono;
    public auto FontHint() const @nogc nothrow { return fontHint; }
    public void FontHint(FontHints newFontHint) @nogc nothrow
    {
        fontHint = newFontHint;
        Invalidate;
        InvalidateFont;
    }

    public auto FontSize() const @nogc nothrow { return fontSize; }
    public void FontSize(int size) @nogc nothrow
    {
        fontSize = size;
        
        immutable oldIconButtonSize = iconButtonSize;
        
        if (fontSize <= 28)
        {
            iconSize = IconSize.Pixels16x16;
            iconButtonSize = 16;
        }
        else
        {
            iconSize = IconSize.Pixels32x32;
            iconButtonSize = 32;
        }
        
        if (iconButtonSize != oldIconButtonSize)
            InvalidateWindowSizes;
        
        Invalidate;
        InvalidateFont;
    }
    
    public void AdjustFontSizeBy(int delta) @nogc nothrow
    {
        FontSize = min(max(fontSize + delta, 4), 100);
    }
    
    private auto fontSize = 16;
    private auto isCachedFontDataValid = false;
    public void InvalidateFont() @nogc nothrow { isCachedFontDataValid = false; }
    
    private auto characterWidth  = 0;
    private auto characterHeight = 0;
    private auto characterCenterX = 0;
    private auto characterCenterY = 0;
    private SDL_Rect characterRectangle;
    
    private struct Glyph
    {
        enum Variant { Normal, Glow }
        
        SDL_Texture*[Variant.max + 1][FontStyle.max + 1] textures;
        
        static void dispose(Glyph glyph) @trusted nothrow
        {
            static foreach (fontStyle; EnumMembers!FontStyle)        
                static foreach (glyphVariant; EnumMembers!Variant)
                    glyph.textures[fontStyle][glyphVariant].Destroy;
        }
    }
    
    private TTF_Font*[FontStyle.max + 1] font;
    private auto characterGlyphs = MostRecentlyUsedCache!(dchar, Glyph, 1024, Glyph.dispose)();
    
    private SDL_Texture* getCharacter(dchar character, FontStyle fontStyle = FontStyle.Normal, Glyph.Variant glyphVariant = Glyph.Variant.Normal)
    {
        Glyph glyph;
        if (!characterGlyphs.tryGetValue(character, glyph))
        {
            glyph = renderGlyph(character);
            characterGlyphs.add(character, glyph);
        }
        
        auto texture = glyph.textures[fontStyle][glyphVariant];
        
        if (texture is null)
            return glyphMissingTexture;
        else
            return texture;
    }
    
    private auto glowCharacterWidth = 0;
    private auto glowCharacterHeight = 0;
    private auto glowCharacterOffset = 0;
    private SDL_Rect glowCharacterRectangle;
    private SDL_Texture* glyphMissingTexture;
    
    private enum marginWidth = 4;
    private auto memoHeight = 0;
    private auto memoWidth = 0;
    private auto memoWidthInCharacters = 0;
    private auto memoHeightInLines = 0;
    private auto windowWidthInCharacters = 0;
    private auto partiallyVisibleCharacterHeight = 0;
    private auto verticalScrollBarSliderSpace = 0;
    private auto horizontalScrollBarSliderSpace = 0;
    
    public bool isEditorVisible = false;
    
    enum closeButtonTop = 0;
    private auto closeButtonLeft = 0;
    private auto closeButtonRight = 0;
    private auto closeButtonBottom = 0;
    
    private auto gripButtonLeft = 0;
    private auto gripButtonTop = 0;
    private auto gripButtonRight = 0;
    private auto gripButtonBottom = 0;
    
    private auto isDraggingVerticalScrollBar         = false;
    private auto isDraggingHorizontalScrollBar       = false;
    private auto isVerticalScrollBarVisible          = false;
    private auto isHorizontalScrollBarVisible        = false;
    private auto verticalScrollBarDragOffset         = 0;
    private auto verticalScrollBarWidth              = 0;
    private auto verticalScrollBarLeft               = 0;
    private auto verticalScrollBarRight              = 0;
    private auto verticalScrollBarTop                = 0;
    private auto verticalScrollBarBottom             = 0;
    private auto verticalScrollBarTopButtonTop       = 0;
    private auto verticalScrollBarTopButtonBottom    = 0;
    private auto verticalScrollBarBottomButtonTop    = 0;
    private auto verticalScrollBarBottomButtonBottom = 0;
    private auto verticalScrollBarBackgroundTop      = 0;
    private auto verticalScrollBarBackgroundBottom   = 0;
    private auto verticalScrollBarScrubberTop        = 0;
    private auto verticalScrollBarScrubberBottom     = 0;
    private auto verticalScrollBarIconLeft           = 0;
    
    private enum horizontalScrollBarLeft             = 0;
    private auto horizontalScrollBarRight            = 0;
    private auto horizontalScrollBarTop              = 0;
    private auto horizontalScrollBarBottom           = 0;
    
    private enum horizontalScrollBarLeftButtonLeft   = 0;
    private auto horizontalScrollBarLeftButtonRight  = 0;
    private auto horizontalScrollBarRightButtonLeft  = 0;
    private auto horizontalScrollBarRightButtonRight = 0;
    
    private auto horizontalScrollBarBackgroundLeft   = 0;
    private auto horizontalScrollBarBackgroundRight  = 0;
    
    private auto horizontalScrollBarDragOffset       = 0;
    private auto horizontalScrollBarScrubberLeft     = 0;
    private auto horizontalScrollBarScrubberRight    = 0;
    private auto isDraggingGrip = false;
    private auto verticalGripMouseOffset = 0;
    private auto horizontalGripMouseOffset = 0;
    
    private auto isDraggingText = false;
    
    private auto isSelecting = false;
    private auto selectionDragScrollVerticalAccumulator = 0.0;
    private auto selectionDragScrollVerticalVelocity = 0.0;
    private auto selectionDragScrollHorizontalAccumulator = 0.0;
    private auto selectionDragScrollHorizontalVelocity = 0.0;
    private immutable selectionDragScrollAcceleration = 0.1;
    
    private auto oldCursorTop = 0;
    private auto oldCursorLeft = 0;
    private auto oldPopupCursorTop = 0;
    private auto oldPopupCursorLeft = 0;
    
    public Popup rollover;
    //public Popup pinnedRollover;
    public Popup queuedCommands;
       
    private auto isQueuedCommandPopupVisible = false;
    
    private auto isShowingScanLines = false;
    public auto IsShowingScanLines() const @nogc nothrow { return isShowingScanLines; }
    public void IsShowingScanLines(bool value) @nogc nothrow { isShowingScanLines = value; InvalidateFont; }
    
    public auto isScreenUpToDate = false;
    public void Invalidate() @nogc nothrow { isScreenUpToDate = false; }
    
    private enum scanLineStride = 2;
    
    private auto iconButtonSize = 16;
    private enum IconSize { Pixels16x16, Pixels32x32 } // Note that the last two digits map to file names.
    private enum ArrowDirection { Up, Down, Left, Right };
    private enum ButtonState { Normal, Rollover, Pressed };
    
    private enum backgroundTextureSize = 256;
    private auto backgroundTexture = BackgroundTexture.None;
    private Image[BackgroundTexture.max + 1] backgroundTextures;
    private Image[IconSize.max + 1] sizingGripImages;
    private Image[BlockType] blockImages;
    
    auto showLogo = true;
    auto logoTimeout = dur!"seconds"(5);
    private auto logoOpacity = 0.0;
    private enum logoBlocks = logo.CreateLogoBlocks;
    private BlockState[logoBlocks.length] blockStates;
    
    private IconSize iconSize;
    private Image[ButtonState][IconSize.max + 1] closeButtonImages;
    private ButtonState closeButtonState;
    private auto isCloseButtonClicked = false;
    private Image[ButtonState][ArrowDirection.max + 1][IconSize.max + 1] arrowButtonImages;
    private ButtonState[ArrowDirection.max + 1] arrowButtonStates;
    
    private SDL_Rect     verticalScrollbarMapImageSize;
    private SDL_Rect     verticalScrollbarMapDestination;
    private SDL_Texture* verticalScrollbarMapImage;
    
    this(Buffer buffer)
    {
        this.buffer = buffer;
        
        const initTTFResult = TTF_Init();
        if (initTTFResult != 0)
            ThrowSDLError;
        
        auto initResult = SDL_Init(SDL_INIT_VIDEO); // SDL_INIT_AUDIO
        if (initResult != 0)
            ThrowSDLError;
        
        window = SDL_CreateWindow("SQLPlusX", windowLeft, windowTop, windowWidth, windowHeight, SDL_WINDOW_ALLOW_HIGHDPI + SDL_WINDOW_RESIZABLE);
        if (window is null)
            ThrowSDLError;
        
        // Paranoia.  I don't know if Windows can disregard my values or not.
        SDL_GetWindowPosition(window, &windowLeft, &windowTop);
        CheckSDLError;
        
        SDL_GetWindowSize(window, &windowWidth, &windowHeight);
        CheckSDLError;
        
        SDL_SetEventFilter(&SDLFilterEventHandler, cast(void*)this);
        
        version (Windows)
        {
            enum PROCESS_DPI_AWARENESS {
                PROCESS_DPI_UNAWARE = 0,
                PROCESS_SYSTEM_DPI_AWARE = 1,
                PROCESS_PER_MONITOR_DPI_AWARE = 2
            }
            
            // HRESULT(WINAPI *SetProcessDpiAwareness)(PROCESS_DPI_AWARENESS dpiAwareness); // Windows 8.1 and later
            alias SetProcessDpiAwarenessType = extern (Windows) int function(PROCESS_DPI_AWARENESS dpiAwareness);
            SetProcessDpiAwarenessType SetProcessDpiAwareness;
            
            auto ShCoreDll = SDL_LoadObject("SHCORE.DLL");
            if (ShCoreDll)
                SetProcessDpiAwareness = cast(SetProcessDpiAwarenessType)ShCoreDll.SDL_LoadFunction("SetProcessDpiAwareness");
            
            if (SetProcessDpiAwareness !is null)
            {
                // Try Windows 8.1+ version
                auto result = SetProcessDpiAwareness(PROCESS_DPI_AWARENESS.PROCESS_PER_MONITOR_DPI_AWARE);
                if (result)
                    throw new RecoverableException("SetProcessDpiAwareness failed: " ~ result.to!string(16));
            }
            else 
            {
                // Try Vista - Windows 8 version.
                // This has a constant scale factor for all monitors.
                alias SetProcessDPIAwareType = extern (Windows) bool function(); // BOOL(WINAPI *SetProcessDPIAware)(void);
                SetProcessDPIAwareType SetProcessDPIAware;
                
                auto userDLL = SDL_LoadObject("USER32.DLL");
                if (userDLL)
                    SetProcessDPIAware = cast(SetProcessDPIAwareType)SDL_LoadFunction(userDLL, "SetProcessDPIAware");
                
                if (SetProcessDPIAware !is null && !SetProcessDPIAware())
                    throw new RecoverableException("SetProcessDPIAware failed.");
            }
        }
        
        CreateRenderer;
        CreateCursors;
        ResetStars;
        SetTheme(InterfaceTheme.SqlPlus);
    }
    
    public bool IsImagesValid = false;
    
    public void InvalidateImages() @nogc nothrow
    {
        IsImagesValid = false;
    }
    
    private void CreateRenderer()
    {
        DebugLog("Creating renderer.");
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC);
        if (renderer is null)
            ThrowSDLError;
        
        CheckSDLError();
        DebugLog("Renderer Created.");
        
        SDL_SetHint(SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH, "1");
        SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0");
        renderer.SDL_RenderSetIntegerScale(SDL_bool.SDL_TRUE);
    }
    
    private void CreateCursors()
    {
        DebugLog("Creating cursors.");
        
        defaultMouseCursor = SDL_GetDefaultCursor();
        if (defaultMouseCursor is null)
            ThrowSDLError;
        
        activeMouseCursor = defaultMouseCursor;
        
        iBeamMouseCursor = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_IBEAM);
        if (iBeamMouseCursor is null)
            ThrowSDLError;
        
        gripSizingMouseCursor = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZENWSE);
        if (gripSizingMouseCursor is null)
            ThrowSDLError;
    }
    
    public void RefreshImages()
    {
        DebugLog("RefreshImages Started.");
        if (IsImagesValid)
            return;
        
        IsImagesValid = true;
        
        CreateScollBarMapImage;
        
        DebugLog("Generating background textures.");
        
        static foreach (texture; EnumMembers!BackgroundTexture) 
            static if (texture != BackgroundTexture.None)
                backgroundTextures[texture] = Image.Load!(texture.to!string ~ "BackgroundTexture.bmp")(renderer);
        
        static foreach (size; EnumMembers!IconSize)
        {{
            enum sizeNumberText = size.to!string[$ - 2 .. $];
            
            sizingGripImages[size] = Image.Load!("SizingGrip" ~ sizeNumberText ~ ".bmp")(renderer);
            
            DebugLog("Generating arrow textures.");
            static foreach (direction; EnumMembers!ArrowDirection)
            {
                arrowButtonStates[direction] = ButtonState.Normal;
                static foreach (state; EnumMembers!ButtonState)
                    arrowButtonImages[size][direction][state] = Image.Load!(direction.to!string ~ "Arrow" ~ state.to!string ~ sizeNumberText ~ ".bmp")(renderer);
            }
            
            static foreach (state; EnumMembers!ButtonState)
                closeButtonImages[size][state] = Image.Load!("Close" ~ state.to!string ~ sizeNumberText ~ ".bmp")(renderer);
        }}
        
        DebugLog("Clearing font textures.");
        characterGlyphs.reset;
        
        DebugLog("Generating logo block textures.");
        static foreach (type; EnumMembers!(logo.BlockType))
            blockImages[type] = Image.Load!(type.to!string ~ ".bmp")(renderer);        
        
        foreach (i, ref blockState; blockStates)
            blockState.Reset;
    }
    
    ~this()
    {
        renderer.SDL_DestroyRenderer; 
        window.SDL_DestroyWindow;
        SDL_Quit();
    }
    
    public void HideWindow()
    {
        window.SDL_HideWindow;
    }
    
    private bool isFullScreen = false;
    public bool IsFullScreen() @nogc nothrow { return isFullScreen; }
    
    public void IsFullScreen(bool value) @nogc 
    {
        if (isFullScreen == value)
            return;
        
        isFullScreen = value;
        const mode = isFullScreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0;
        SDL_SetWindowFullscreen(window, mode);
        InvalidateWindowSizes;
    }
    
    public void ToggleFullScreen()
    {
        IsFullScreen = !isFullScreen;
    }
    
    public void SetTitle(string text)
    {
        auto title = "SQLPlusX";
        
        if (text.length > 0)
            title ~= " - " ~ text;
        
        SDL_SetWindowTitle(window, title.ToCString);
        CheckSDLError;
    }
    
    private auto windowSizesValid = false;
    
    public void InvalidateWindowSizes() @nogc nothrow
    {
        Invalidate;
        buffer.InvalidateScrollbarMap;
        windowSizesValid = false;
    }
    
    enum WindowDimensions { Reuse, Refresh }
    
    private void CreateScollBarMapImage()
    {
        buffer.InvalidateScrollbarMap;
        verticalScrollbarMapImageSize   = SDL_Rect(0, 0, verticalScrollBarWidth - 1, verticalScrollBarBackgroundBottom - verticalScrollBarBackgroundTop);
        verticalScrollbarMapDestination = SDL_Rect(verticalScrollBarLeft + 1, verticalScrollBarBackgroundTop, verticalScrollbarMapImageSize.w, verticalScrollbarMapImageSize.h);
        
        if (verticalScrollbarMapImage !is null)
            verticalScrollbarMapImage.Destroy;
        
        if (verticalScrollbarMapImageSize.w == 0 || verticalScrollbarMapImageSize.h == 0)
        {
            verticalScrollbarMapImage = null;
            return;
        }
        
        verticalScrollbarMapImage = renderer.SDL_CreateTexture(nativePixelFormat, SDL_TEXTUREACCESS_STREAMING, verticalScrollbarMapImageSize.w, verticalScrollbarMapImageSize.h);
        if (verticalScrollbarMapImage is null)
            ThrowSDLError;
        
        verticalScrollbarMapImage.SDL_SetTextureAlphaMod(127);
        verticalScrollbarMapImage.SDL_SetTextureBlendMode(SDL_BLENDMODE_BLEND);
    }
    
    public void RefreshWindowSizes(WindowDimensions dimensions)()
    {
        static if (dimensions == WindowDimensions.Refresh)
        {
            SDL_GetWindowPosition(window, &windowLeft, &windowTop);
            SDL_GetWindowSize(window, &windowWidth, &windowHeight);
        }
        
        if (Program.Settings.VerticalScrollBarMode == Program.Settings.VerticalScrollBarModes.Wide)
            verticalScrollBarWidth = iconButtonSize * 4;
        else
            verticalScrollBarWidth = iconButtonSize;
        
        memoHeight = windowHeight - iconButtonSize;
        memoWidth  = windowWidth  - verticalScrollBarWidth;
        memoHeightInLines = memoHeight / characterHeight;
        windowWidthInCharacters = windowWidth / characterWidth + 1;
        
        buffer.ScreenHeightInLines = memoHeightInLines;
        
        if (isFullScreen)
        {
            closeButtonLeft   = windowWidth - iconButtonSize;
            closeButtonRight  = windowWidth;
            closeButtonBottom = closeButtonTop + iconButtonSize;
        }
        else
        {
            closeButtonLeft   = 0;
            closeButtonRight  = 0;
            closeButtonBottom = 0;
        }
        
        // Calculate vertical scroll bar dimensions
        verticalScrollBarLeft               = memoWidth;
        verticalScrollBarRight              = windowWidth;
        verticalScrollBarTop                = isFullScreen ? iconButtonSize : 0;
        verticalScrollBarBottom             = memoHeight;
        
        verticalScrollBarTopButtonTop       = verticalScrollBarTop;
        verticalScrollBarTopButtonBottom    = verticalScrollBarTop    + iconButtonSize;
        verticalScrollBarBottomButtonTop    = verticalScrollBarBottom - iconButtonSize;
        verticalScrollBarBottomButtonBottom = verticalScrollBarBottom;
        verticalScrollBarIconLeft           = verticalScrollBarLeft + (verticalScrollBarWidth - iconButtonSize) / 2;
        
        verticalScrollBarBackgroundTop      = verticalScrollBarTopButtonBottom;
        verticalScrollBarBackgroundBottom   = verticalScrollBarBottomButtonTop;
        
        // Calculate horizontal scroll bar dimensions
      //horizontalScrollBarLeft             = 0;
        horizontalScrollBarRight            = windowWidth - iconButtonSize;
        horizontalScrollBarTop              = memoHeight;
        horizontalScrollBarBottom           = windowHeight;
        
      //horizontalScrollBarLeftButtonLeft   = horizontalScrollBarLeft;
        horizontalScrollBarLeftButtonRight  = horizontalScrollBarLeft  + iconButtonSize;
        horizontalScrollBarRightButtonLeft  = horizontalScrollBarRight - iconButtonSize;
        horizontalScrollBarRightButtonRight = horizontalScrollBarRight;
        
        horizontalScrollBarBackgroundLeft   = horizontalScrollBarLeftButtonRight;
        horizontalScrollBarBackgroundRight  = horizontalScrollBarRightButtonLeft;
        
        partiallyVisibleCharacterHeight     = memoHeight - memoHeightInLines * characterHeight;
        verticalScrollBarSliderSpace        = verticalScrollBarBackgroundBottom - verticalScrollBarBackgroundTop;
        horizontalScrollBarSliderSpace      = horizontalScrollBarBackgroundRight - horizontalScrollBarBackgroundLeft;
        
        gripButtonLeft   = horizontalScrollBarRight;
        gripButtonTop    = horizontalScrollBarTop;
        gripButtonRight  = windowWidth;
        gripButtonBottom = windowHeight;
        
        InvalidateImages;
        
        buffer.BalanceExtraColumnSpace;
    }
    
    public void Update(const int timeInMilliseconds, const int lastFrameDurationInMilliseconds)
    {
        if (isScreenUpToDate)
            return;
        
        isScreenUpToDate = true;
        
        try
        {
            RefreshCachedFontData;
            
            if (!windowSizesValid)
            {
                RefreshWindowSizes!(WindowDimensions.Refresh);
                windowSizesValid = true;
            }
            
            RefreshImages;
            
            SetDrawColor(background.color);
            renderer.SDL_RenderClear.CheckSDLError;
            SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND).CheckSDLError;
            
            if (isShowingStars)
            {
                Invalidate;
                
                foreach (ref star; stars)
                {
                    immutable x1 = cast(int)star.x;
                    immutable y1 = cast(int)star.y;
                    star.Advance(lastFrameDurationInMilliseconds);
                    immutable x2 = cast(int)star.x;
                    immutable y2 = cast(int)star.y;
                    
                    immutable opacity = cast(ubyte)max(1, min(255, 255.0 / (y1 - y2)));
                    SetDrawColor(AdjustOpacity(star.color, opacity));
                    DrawLine(x1, y1, x2, y2);
                    SetDrawColor(star.color);
                    DrawPixel(x1, y2);
                    
                    star.Check(windowWidth, windowHeight);
                }
            }
            
            if (backgroundTexture != BackgroundTexture.None)
            {
                auto x = 0;
                
                while (x < windowWidth)
                {
                    auto y = 0;
                    while (y < windowHeight)
                    {
                        backgroundTextures[backgroundTexture].Draw(x, y);
                        y += backgroundTextureSize;
                    }
                    
                    x += backgroundTextureSize;
                }
            }
            
            if (showLogo)
            {
                if (logoTimeout > Duration.zero)
                {
                    logoTimeout -= dur!"msecs"(lastFrameDurationInMilliseconds);
                    
                    if (logoOpacity < 1.0)
                        logoOpacity += lastFrameDurationInMilliseconds / 5000.0;
                }
                else
                {
                    if (logoOpacity > 0.0)
                        logoOpacity -= lastFrameDurationInMilliseconds / 10000.0;
                    else
                        showLogo = false;
                }
                
                immutable pixelsAboveScreenStart = buffer.TotalLinesAboveScreenStart * characterHeight;
                
                if (pixelsAboveScreenStart < 10 + logo.fullHeight)
                {
                    immutable logoTop = 10 - pixelsAboveScreenStart;
                    immutable logoLeft = max(0, memoWidth - logo.fullWidth);
                    
                    foreach (i, block; logoBlocks)
                    {
                        auto color = blockStates[i].isNormalColor ? normalText.color : selection.color;
                        
                        blockImages[block.Type].Draw(logoLeft + block.X, logoTop + block.Y, blockStates[i].Opacity(logoOpacity), color.r, color.g, color.b);
                        blockStates[i].Advance;
                        Invalidate;
                    }
                }
            }
            
            isVerticalScrollBarVisible = buffer.TotalLines > memoHeightInLines && memoHeight > 2 * iconButtonSize;
            
            if (isVerticalScrollBarVisible)
                memoWidthInCharacters = windowWidthInCharacters - cast(int)ceil(cast(float)verticalScrollBarWidth / characterWidth);
            else
                memoWidthInCharacters = windowWidthInCharacters;
            
            buffer.ScreenWidthInCharacters = memoWidthInCharacters;
            isHorizontalScrollBarVisible = buffer.WidthInCharacters > memoWidthInCharacters && memoWidth > 2 * iconButtonSize;
            
            // Draw main buffer
            immutable memoRectange = isHorizontalScrollBarVisible ? 
                SDL_Rect(0, 0, windowWidth, memoHeight) : 
                SDL_Rect(0, 0, windowWidth, windowHeight);
            
            SDL_RenderSetViewport(renderer, &memoRectange).CheckSDLError;
            
            immutable screenYOffset = 0;
            
            int textTop = screenYOffset;
            int textBottom = textTop + characterHeight;
            int cursorTop = -1;
            int cursorLeft = -1;
            isEditorVisible = false;
            
            foreach (screenLine; 0 .. memoHeightInLines + 1)
            {
                const location = buffer.LocationAtScreenLine!false(screenLine);
                
                const bufferItem = location.Item;
                if (bufferItem is null) break;
                
                immutable bufferItemLineNumber = location.Line;
                
                const table = cast(TableBufferItem)location.Item;
                const formattedBufferItem = cast(FormattedTextBufferItem)bufferItem;
                const editor = cast(EditorBufferItem)bufferItem;
                
                immutable isHeaderRow = table !is null && (table.IsHeaderRow(location.Line) || (screenLine == 0 && Program.Settings.PageSize != 0));
                immutable isTextRow = table !is null && table.IsTextRow(location.Line);
                
                if (isHeaderRow)
                {
                    SetDrawColor(headerBackground.color);
                    FillRectangle(0, textTop, marginWidth + (table.WidthInCharacters - buffer.HorizontalCharacterCountOffset - 1) * characterWidth + characterCenterX + 1, textBottom);
                }
                
                if (table !is null && !isHeaderRow && buffer.HorizontalCharacterCountOffset == 0)
                {
                    // Draw margin
                    SetDrawColor(headerBackground.color);
                    //DrawLine(1, textTop, 1, textBottom);
                    FillRectangle(0, textTop, min(2, marginWidth), textBottom);
                    //FillRectangle(0, textTop, 2, textBottom);
                }
                
                if (formattedBufferItem !is null)
                    printText(
                        formattedBufferItem.FormattedTextAt(buffer.HorizontalCharacterCountOffset, windowWidthInCharacters + 1, screenLine), 
                        marginWidth, 
                        textTop, 
                        timeInMilliseconds);
                else if (editor !is null)
                    printText(
                        editor.FormattedTextAt(bufferItemLineNumber, buffer.HorizontalCharacterCountOffset, windowWidthInCharacters + 1, screenLine), 
                        marginWidth, 
                        textTop, 
                        timeInMilliseconds);
                else
                    printText(
                        bufferItem.TextAt(bufferItemLineNumber, buffer.HorizontalCharacterCountOffset, windowWidthInCharacters + 1, screenLine), 
                        marginWidth, 
                        textTop, 
                        timeInMilliseconds, 
                        bufferItem.Color, 
                        isHeaderRow ? FontStyle.Bold : bufferItem.Style);
                
                if (isHeaderRow)
                {
                    SetDrawColor(headerUnderLine.color);
                    auto underlineScreenStartCharacter = 0;
                    auto headerRecordHorizontalPosition = 0;
                    
                    foreach (tableColumnIndex, tableColumn; table.Columns)
                    {
                        headerRecordHorizontalPosition += table.ColumnWidth(tableColumnIndex);

                        const userColumn = table.UserColumns[tableColumnIndex];
                        if (userColumn !is null && !userColumn.IsVisible)
                            continue;
                        
                        if (headerRecordHorizontalPosition < buffer.HorizontalCharacterCountOffset)
                        {
                            headerRecordHorizontalPosition += Program.Settings.ColumnSeparatorDString.intLength;
                            continue;
                        }
                        
                        immutable underlineScreenEndCharacter = headerRecordHorizontalPosition - buffer.HorizontalCharacterCountOffset;
                        
                        DrawLine(marginWidth + underlineScreenStartCharacter * characterWidth, textBottom - 1, marginWidth + underlineScreenEndCharacter * characterWidth - 1, textBottom - 1);
                        
                        headerRecordHorizontalPosition += Program.Settings.ColumnSeparatorDString.intLength;
                        underlineScreenStartCharacter = underlineScreenEndCharacter + Program.Settings.ColumnSeparatorDString.intLength;
                        
                        if (underlineScreenStartCharacter > windowWidthInCharacters)
                            break;
                    }
                }
                
                if (table !is null && !isHeaderRow && !isTextRow && Program.Settings.ColumnSeparatorString == " ")
                {
                    SetDrawColor(headerBackground.color);
                    auto headerRecordHorizontalPosition = 0;
                    
                    foreach (tableColumnIndex, tableColumn; table.Columns)
                    {
                        const userColumn = table.UserColumns[tableColumnIndex];
                        if (userColumn !is null && !userColumn.IsVisible)
                            continue;
                        
                        headerRecordHorizontalPosition += table.ColumnWidth(tableColumnIndex);
                        
                        if (headerRecordHorizontalPosition < buffer.HorizontalCharacterCountOffset)
                        {
                            headerRecordHorizontalPosition++;
                            continue;
                        }
                        
                        immutable dividerX = marginWidth + (headerRecordHorizontalPosition - buffer.HorizontalCharacterCountOffset) * characterWidth + characterCenterX;
                        
                        DrawLine(dividerX, textTop, dividerX, textBottom - 1);
                        
                        headerRecordHorizontalPosition++;
                        if (headerRecordHorizontalPosition - buffer.HorizontalCharacterCountOffset > windowWidthInCharacters)
                            break;
                    }
                }
                
                // Draw band-box selection
                if (buffer.SelectionType != Buffer.SelectionTypes.EditorOnly && buffer.IsLineSelected(screenLine)) 
                {
                    immutable selectionLeft  = marginWidth + buffer.SelectionLeftScreen  * characterWidth;
                    immutable selectionRight = marginWidth + buffer.SelectionRightScreen * characterWidth;
                    
                    SetDrawColor(selection.color);
                    FillRectangle(selectionLeft, textTop, selectionRight, textBottom);
                }
                
                if (editor !is null)
                {
                    isEditorVisible = true;
                    // Draw range selection
                    if (buffer.SelectionType != Buffer.SelectionTypes.BufferOnly && editor.IsLineSelected(bufferItemLineNumber))
                    {
                        immutable selectionLeft  = marginWidth + (editor.SelectionStartOnLine(bufferItemLineNumber) - buffer.HorizontalCharacterCountOffset) * characterWidth;
                        immutable selectionRight = marginWidth + (editor.SelectionEndOnLine  (bufferItemLineNumber) - buffer.HorizontalCharacterCountOffset) * characterWidth;
                        
                        SetDrawColor(selection.color);
                        FillRectangle(selectionLeft, textTop, selectionRight, textBottom);
                    }
                    
                    // Draw cursor
                    if (editor.CursorPositionLine == bufferItemLineNumber)
                    {
                        cursorTop = textTop;
                        cursorLeft = marginWidth + (editor.CursorPositionColumn - buffer.HorizontalCharacterCountOffset) * characterWidth;
                        
                        DrawCursor(
                            cursorLeft, 
                            textTop, 
                            oldCursorTop, 
                            oldCursorLeft);
                    }
                }
                
                textTop    += characterHeight;
                textBottom += characterHeight;
            }
            
            SDL_RenderSetViewport(renderer, null);

            // Draw close button.
            if (isFullScreen)
            {
                SetDrawColor(scrollBarButton.color);
                FillRectangle(closeButtonLeft, closeButtonTop, closeButtonRight, closeButtonBottom);
                closeButtonImages[iconSize][closeButtonState].Draw(closeButtonLeft, closeButtonTop);
            }
            
            if (isVerticalScrollBarVisible)
            {
                immutable verticalScrollBarPixelsPerLine = verticalScrollBarSliderSpace / cast(double)buffer.TotalLines;
                
                verticalScrollBarScrubberTop    = verticalScrollBarBackgroundTop    + cast(int)(verticalScrollBarPixelsPerLine *        buffer.TotalLinesAboveScreenStart);
                verticalScrollBarScrubberBottom = verticalScrollBarBackgroundBottom - cast(int)(verticalScrollBarPixelsPerLine * max(0, buffer.TotalLinesBelowScreenStart - memoHeightInLines));
                
                if (verticalScrollBarScrubberBottom - verticalScrollBarScrubberTop < iconButtonSize)
                {
                    if (verticalScrollBarScrubberBottom <= verticalScrollBarBackgroundTop + iconButtonSize / 2)
                    {
                        verticalScrollBarScrubberTop    = verticalScrollBarBackgroundTop;
                        verticalScrollBarScrubberBottom = verticalScrollBarScrubberTop + iconButtonSize;
                    }
                    else if (verticalScrollBarScrubberTop >= verticalScrollBarBackgroundBottom - iconButtonSize / 2)
                    {
                        verticalScrollBarScrubberBottom = verticalScrollBarBackgroundBottom;
                        verticalScrollBarScrubberTop    = verticalScrollBarScrubberBottom - iconButtonSize;
                    }
                    else
                    {
                        immutable midPoint = verticalScrollBarScrubberTop + (verticalScrollBarScrubberBottom - verticalScrollBarScrubberTop) / 2;
                        verticalScrollBarScrubberTop    = midPoint - iconButtonSize / 2;
                        verticalScrollBarScrubberBottom = verticalScrollBarScrubberTop + iconButtonSize;
                    }
                }
                
                verticalScrollBarScrubberTop    = max(verticalScrollBarScrubberTop,    verticalScrollBarBackgroundTop);
                verticalScrollBarScrubberBottom = min(verticalScrollBarScrubberBottom, verticalScrollBarBackgroundBottom);
                
                // Draw vertical scroll bar
                
                // Draw vertical scroll bar background
                SetDrawColor(AdjustOpacity(background.color, 192));
                FillRectangle(verticalScrollBarLeft, verticalScrollBarTop, verticalScrollBarRight, verticalScrollBarBottom);
                
                SetDrawColor(scrollBarBackground.color);
                
                if (verticalScrollBarBackgroundTop < verticalScrollBarScrubberTop - 1)
                    DrawLine(verticalScrollBarLeft, verticalScrollBarBackgroundTop,  verticalScrollBarLeft, verticalScrollBarScrubberTop - 1);
                
                if (verticalScrollBarScrubberBottom < verticalScrollBarBackgroundBottom - 1)
                    DrawLine(verticalScrollBarLeft, verticalScrollBarScrubberBottom, verticalScrollBarLeft, verticalScrollBarBackgroundBottom - 1);
                
                SetDrawColor(scrollBarButton.color);
                
                // Vertical scroll bar top button
                FillRectangle(verticalScrollBarLeft, verticalScrollBarTopButtonTop, verticalScrollBarRight, verticalScrollBarTopButtonBottom);
                arrowButtonImages[iconSize][ArrowDirection.Up][arrowButtonStates[ArrowDirection.Up]].Draw(verticalScrollBarIconLeft, verticalScrollBarTopButtonTop);
                
                // Vertical scroll bar bottom button
                FillRectangle(verticalScrollBarLeft, verticalScrollBarBottomButtonTop, verticalScrollBarRight, verticalScrollBarBottom);
                arrowButtonImages[iconSize][ArrowDirection.Down][arrowButtonStates[ArrowDirection.Down]].Draw(verticalScrollBarIconLeft, verticalScrollBarBottomButtonTop);
                
                // Draw scroll bar map
                if (Program.Settings.VerticalScrollBarMode == Program.Settings.VerticalScrollBarModes.Simple)
                {
                    // Draw vertical scroll bar scrubber
                    FillRectangle(verticalScrollBarLeft, verticalScrollBarScrubberTop, verticalScrollBarRight, verticalScrollBarScrubberBottom);
                }
                else
                {
                    if (!buffer.isScrollbarMapValid)
                    {
                        void* rawPixels;
                        int pitch;
                        verticalScrollbarMapImage.SDL_LockTexture(&verticalScrollbarMapImageSize, &rawPixels, &pitch).CheckSDLError;
                        try
                        {
                            assert (pitch == verticalScrollbarMapImageSize.w * uint.sizeof, "Scrollbar map size doesn't match pitch returned from SDL_LockTexture.");
                            
                            auto pixels = (cast(uint*)rawPixels)[0 .. verticalScrollbarMapImageSize.w * verticalScrollbarMapImageSize.h];
                            
                            buffer.DrawScrollbarMap(verticalScrollbarMapImageSize.w, verticalScrollbarMapImageSize.h, memoHeightInLines, pixels);
                        }
                        finally
                            verticalScrollbarMapImage.SDL_UnlockTexture;
                    }
                    
                    renderer.SDL_RenderCopy(verticalScrollbarMapImage, &verticalScrollbarMapImageSize, &verticalScrollbarMapDestination);
                    
                    // Draw vertical scroll bar scrubber
                    SetDrawColor(AdjustOpacity(scrollBarButton.color, 63));
                    FillRectangle(verticalScrollBarLeft, verticalScrollBarScrubberTop, verticalScrollBarRight, verticalScrollBarScrubberBottom);
                    
                    SetDrawColor(normalText.color);
                    DrawRectangle(verticalScrollBarLeft,     verticalScrollBarScrubberTop,     verticalScrollBarRight - 1, verticalScrollBarScrubberBottom - 1);
                    DrawRectangle(verticalScrollBarLeft + 1, verticalScrollBarScrubberTop + 1, verticalScrollBarRight - 2, verticalScrollBarScrubberBottom - 2);
                    
                    if (isDraggingVerticalScrollBar || 
                        (verticalScrollBarLeft < mouseX && mouseX < verticalScrollBarRight && 
                         verticalScrollBarScrubberTop < mouseY && mouseY < verticalScrollBarScrubberBottom))
                    {
                        SetDrawColor(AdjustOpacity(normalText.color, 127));
                        DrawRectangle(verticalScrollBarLeft + 2, verticalScrollBarScrubberTop + 2, verticalScrollBarRight - 3, verticalScrollBarScrubberBottom - 3);
                        SetDrawColor(AdjustOpacity(normalText.color, 63));
                        DrawRectangle(verticalScrollBarLeft + 3, verticalScrollBarScrubberTop + 3, verticalScrollBarRight - 4, verticalScrollBarScrubberBottom - 4);
                        SetDrawColor(AdjustOpacity(normalText.color, 31));
                        DrawRectangle(verticalScrollBarLeft + 4, verticalScrollBarScrubberTop + 4, verticalScrollBarRight - 5, verticalScrollBarScrubberBottom - 5);
                        SetDrawColor(AdjustOpacity(normalText.color, 15));
                        DrawRectangle(verticalScrollBarLeft + 5, verticalScrollBarScrubberTop + 5, verticalScrollBarRight - 6, verticalScrollBarScrubberBottom - 6);
                    }
                }
            }
            
            if (isHorizontalScrollBarVisible)
            {
                immutable horizontalScrollBarPixelsPerCharacter = horizontalScrollBarSliderSpace / cast(double)buffer.WidthInCharacters;
                
                horizontalScrollBarScrubberLeft  = horizontalScrollBarBackgroundLeft  + cast(int)(horizontalScrollBarPixelsPerCharacter *        buffer.HorizontalCharacterCountOffset);
                horizontalScrollBarScrubberRight = horizontalScrollBarBackgroundRight - cast(int)(horizontalScrollBarPixelsPerCharacter * max(0, buffer.WidthInCharacters - (buffer.HorizontalCharacterCountOffset + memoWidthInCharacters)));
                
                if (horizontalScrollBarScrubberRight - horizontalScrollBarScrubberLeft < iconButtonSize)
                {
                    if (horizontalScrollBarScrubberRight <= horizontalScrollBarBackgroundLeft + iconButtonSize / 2)
                    {
                        horizontalScrollBarScrubberLeft  = horizontalScrollBarBackgroundLeft;
                        horizontalScrollBarScrubberRight = horizontalScrollBarScrubberLeft + iconButtonSize;
                    }
                    else if (horizontalScrollBarScrubberLeft >= horizontalScrollBarBackgroundRight - iconButtonSize / 2)
                    {
                        horizontalScrollBarScrubberRight = horizontalScrollBarBackgroundRight;
                        horizontalScrollBarScrubberLeft  = horizontalScrollBarScrubberRight - iconButtonSize;
                    }
                    else
                    {
                        immutable midPoint = horizontalScrollBarScrubberLeft + (horizontalScrollBarScrubberRight - horizontalScrollBarScrubberLeft) / 2;
                        horizontalScrollBarScrubberLeft  = midPoint - iconButtonSize / 2;
                        horizontalScrollBarScrubberRight = horizontalScrollBarScrubberLeft + iconButtonSize;
                    }
                }
                
                horizontalScrollBarScrubberLeft  = max(horizontalScrollBarScrubberLeft,  horizontalScrollBarBackgroundLeft);
                horizontalScrollBarScrubberRight = min(horizontalScrollBarScrubberRight, horizontalScrollBarBackgroundRight);
                
                // Draw horizontal bar
                
                // Draw horizontal scroll bar background
                SetDrawColor(AdjustOpacity(background.color, 192));
                FillRectangle(horizontalScrollBarLeft, horizontalScrollBarTop, horizontalScrollBarRight, horizontalScrollBarBottom);
                
                SetDrawColor(scrollBarBackground.color);
                
                if (horizontalScrollBarBackgroundLeft < horizontalScrollBarScrubberLeft - 1)
                    DrawLine(horizontalScrollBarBackgroundLeft, horizontalScrollBarTop, horizontalScrollBarScrubberLeft - 1, horizontalScrollBarTop);
                
                if (horizontalScrollBarScrubberRight < horizontalScrollBarBackgroundRight - 1)
                    DrawLine(horizontalScrollBarScrubberRight,  horizontalScrollBarTop, horizontalScrollBarBackgroundRight - 1, horizontalScrollBarTop);
                
                SetDrawColor(scrollBarButton.color);
                
                // Horizontal scroll bar left button
                FillRectangle(horizontalScrollBarLeftButtonLeft, horizontalScrollBarTop, horizontalScrollBarLeftButtonRight, horizontalScrollBarBottom);
                arrowButtonImages[iconSize][ArrowDirection.Left][arrowButtonStates[ArrowDirection.Left]].Draw(horizontalScrollBarLeftButtonLeft, horizontalScrollBarTop);
                
                // Horizontal scroll bar right button
                FillRectangle(horizontalScrollBarRightButtonLeft, horizontalScrollBarTop, horizontalScrollBarRightButtonRight, horizontalScrollBarBottom);
                arrowButtonImages[iconSize][ArrowDirection.Right][arrowButtonStates[ArrowDirection.Right]].Draw(horizontalScrollBarRightButtonLeft, horizontalScrollBarTop);
                
                // Draw horizontal scroll bar scrubber
                FillRectangle(horizontalScrollBarScrubberLeft, horizontalScrollBarTop, horizontalScrollBarScrubberRight, horizontalScrollBarBottom);
            }
            
            
            // Draw grip background
            if (isHorizontalScrollBarVisible)
            {
                SetDrawColor(scrollBarButton.color);
                FillRectangle(gripButtonLeft, gripButtonTop, gripButtonRight, gripButtonBottom);
            }

            if (!isFullScreen)
                sizingGripImages[iconSize].Draw(gripButtonLeft, gripButtonTop);
            
            // Draw autocomplete suggestions
            Program.AutoCompleteDatabase.UpdateSuggestions;
            const allSuggestions = Program.AutoCompleteDatabase.AutoCompleteSuggestions;
            if (allSuggestions.length > 0 && cursorTop >= 0 && Program.AutoCompleteDatabase.SuggestionPopupVisible)
            {
                auto suggestionWindowTop    = 0;
                auto suggestionWindowBottom = 0;
                
                const isSuggestionWindowBelowCursor = cursorTop < memoHeight / 2;
                if (isSuggestionWindowBelowCursor)
                {
                    suggestionWindowTop = cursorTop + characterHeight + characterCenterY;
                    suggestionWindowBottom = memoHeight - characterCenterY;
                }
                else
                {
                    suggestionWindowTop    = characterCenterY;
                    suggestionWindowBottom = cursorTop - characterCenterY;
                }
                
                immutable maximumVisibleSuggestionCount = (suggestionWindowBottom - suggestionWindowTop) / characterHeight;
                immutable int visibleSuggestionCount = min(allSuggestions.intLength, maximumVisibleSuggestionCount);
                
                Program.AutoCompleteDatabase.VisibleSuggestionCount = visibleSuggestionCount;
                
                if (isSuggestionWindowBelowCursor)
                    suggestionWindowBottom = min(suggestionWindowBottom, suggestionWindowTop + visibleSuggestionCount * characterHeight);
                else
                    suggestionWindowTop = max(suggestionWindowTop, suggestionWindowBottom - visibleSuggestionCount * characterHeight);
                
                int selectedSuggestionIndex = Program.AutoCompleteDatabase.SelectedSuggestionIndex;
                
                immutable firstVisibleSuggestionIndex = min(max(0, selectedSuggestionIndex - visibleSuggestionCount / 2), allSuggestions.intLength - visibleSuggestionCount);
                immutable lastVisibleSuggestionIndex = firstVisibleSuggestionIndex + visibleSuggestionCount;
                
                const visibleSuggestions = allSuggestions[firstVisibleSuggestionIndex .. firstVisibleSuggestionIndex + visibleSuggestionCount];
                
                selectedSuggestionIndex -= firstVisibleSuggestionIndex;
                
                immutable maxWidthInCharacters = min(Program.AutoCompleteDatabase.SuggestionMaxWidth + 1, windowWidthInCharacters - 3);
                
                immutable suggestionWindowLeft   = iconButtonSize;
                immutable suggestionWindowRight  = suggestionWindowLeft + maxWidthInCharacters * characterWidth + 6;
                immutable suggestionLeft         = suggestionWindowLeft + characterCenterX;
                auto      suggestionTop          = suggestionWindowTop;
                immutable suggestionWindowHeight = suggestionWindowBottom - suggestionWindowTop - 3;
                
                DrawPopUpBox(suggestionWindowLeft, suggestionWindowTop, suggestionWindowRight, suggestionWindowBottom);
                
                // Draw shortcut hint.
                enum shortcutHint = "Ctrl+↑↓";
                enum shortcutHintWidthInCharacters = 7;
            
                if (allSuggestions.intLength > 1 &&
                    maxWidthInCharacters + shortcutHintWidthInCharacters + 4 < windowWidthInCharacters)
                {
                    immutable shortcutHintWindowLeft   = suggestionWindowRight + 7;
                    immutable shortcutHintWindowRight  = shortcutHintWindowLeft + (shortcutHintWidthInCharacters + 1) * characterWidth;
                    immutable shortcutHintLeft         = shortcutHintWindowLeft + characterCenterX;
                    immutable shortcutHintWindowTop    = suggestionWindowTop;
                    immutable shortcutHintWindowBottom = shortcutHintWindowTop + characterHeight;
                    
                    DrawPopUpBox(shortcutHintWindowLeft, shortcutHintWindowTop, shortcutHintWindowRight, shortcutHintWindowBottom, 96);
                    printText(shortcutHint, shortcutHintLeft, shortcutHintWindowTop, timeInMilliseconds, NamedColor.Popup, FontStyle.Normal, 127);
                }
                
                int suggestionSelectionRight;
                DrawPopUpScrollBar(
                    suggestionWindowTop, 
                    suggestionWindowRight, 
                    suggestionWindowHeight, 
                    firstVisibleSuggestionIndex, 
                    lastVisibleSuggestionIndex, 
                    allSuggestions.intLength, 
                    suggestionSelectionRight);
                
                foreach (index, suggestion; visibleSuggestions)
                {
                    immutable suggestionBottom = suggestionTop + characterHeight;
                    
                    printText(suggestion, suggestionLeft, suggestionTop, timeInMilliseconds, NamedColor.Popup, FontStyle.Normal);
                    
                    if (index == selectedSuggestionIndex)
                    {
                        SetDrawColor(selection.color);
                        FillRectangle(suggestionWindowLeft, suggestionTop, suggestionSelectionRight, suggestionBottom);                    
                    }
                    
                    suggestionTop = suggestionBottom;
                    
                    if (suggestionTop >= suggestionWindowBottom)
                        break;
                }
            }
            
            // Status messages
            struct StatusLine
            {
                char[BufferItem.MaxTemporaryTextWidth] text;
                auto length = 0;
                auto isSearch = false;
            }
            StatusLine[8] statusLines;
            auto statusLineCount = 0;
            auto queuedCommandsStatusLine       = -1;
            auto queuedCommandsStatusLineTop    = -1;
            auto queuedCommandsStatusLineBottom = -1;
            auto queuedCommandsStatusLineLeft   = -1;
            auto queuedCommandsStatusLineRight  = -1;
            auto queuedCommandsPopupBottom = memoHeight;
            
            void AppendStatusLine(StringReference text, bool isSearch = false)
            {
                statusLines[statusLineCount].text[0 .. text.length] = text[0 .. $];
                statusLines[statusLineCount].length = text.intLength;
                statusLines[statusLineCount].isSearch = isSearch;
                statusLineCount++;
            }
            
            if (Program.diagnosticInformation.length > 0)
                AppendStatusLine(Program.diagnosticInformation);
            
            if (Program.Settings.IsFrameCounterOn)
                AppendStatusLine("FPS " ~ Program.FramesPerSecond.to!string);
            
            auto currentActivityDescription = Program.Database.CurrentActivityDescription;
            
            if (currentActivityDescription.length > 0)
                AppendStatusLine(currentActivityDescription);
            
            if (Program.AutoCompleteDatabase.Status == Program.AutoCompleteDatabase.States.DataCollectionInProgress)
                AppendStatusLine("Collecting data...");
            
            auto uncommittedChangeCount = Program.Database.UncommittedChangeCount;
            if (uncommittedChangeCount > 0)
                AppendStatusLine(uncommittedChangeCount.to!string ~ " uncommitted change" ~ (uncommittedChangeCount == 1 ? "" : "s"));
            
            auto queuedCommandCount = Program.Interpreter.QueuedCommandCount;
            if (queuedCommandCount > 0)
            {
                queuedCommandsStatusLine = statusLineCount;
                AppendStatusLine(queuedCommandCount.to!string ~ " command" ~ (queuedCommandCount == 1 ? "" : "s") ~ " queued");
            }
            
            auto activeTableItem = Program.Buffer.ActiveTableItem;
            if (activeTableItem !is null && !activeTableItem.IsQueryComplete && activeTableItem.TotalRecordCount > 0)
                AppendStatusLine(activeTableItem.TotalRecordCount.to!string ~ " record" ~ (activeTableItem.TotalRecordCount == 1 ? "" : "s") ~ " returned");
            
            auto searchCursorOffset = 0;
            auto searchSelectionStartOffset = 0;
            auto searchSelectionEndOffset = 0;
            
            if (Program.Editor.IsInFindMode)
            {
                const left = max(0, cast(int)Program.Editor.CursorPositionColumn - cast(int)windowWidthInCharacters + 5 + 5);
                const maxWidth = min(windowWidthInCharacters - 5, BufferItem.MaxTemporaryTextWidth);
                searchCursorOffset         = Program.Editor.CursorPositionColumn - left;
                searchSelectionStartOffset = Program.Editor.SelectionStartColumn - left;
                searchSelectionEndOffset   = Program.Editor.SelectionEndColumn   - left;
                
                AppendStatusLine(Program.Editor.TextAt(0, left, maxWidth, -1), true);

                auto line = &statusLines[statusLineCount - 1];
                const padding = min(max(0, cast(int)(searchCursorOffset + 5 - BufferItem.MaxTemporaryTextWidth)), 
                                    max(0, cast(int)(maxWidth - line.length)), 
                                    BufferItem.MaxTemporaryTextWidth - line.length);
                line.text[line.length .. line.length + padding] = ' ';
                line.length += padding;
            }
            
            if (statusLineCount > 0)
            {
                auto maxWidthInCharacters = 0;
                foreach (line; statusLines[0 .. statusLineCount])
                    maxWidthInCharacters = max(maxWidthInCharacters, line.length);
                
                immutable statusWindowRight  = memoWidth  - 5;
                immutable statusWindowBottom = memoHeight - 5;
                immutable statusWindowTop    = max(0, statusWindowBottom - statusLineCount * characterHeight - 1);
                immutable statusWindowLeft   = max(0, statusWindowRight - maxWidthInCharacters * characterWidth - characterWidth - 1);
                
                int statusLineTop = statusWindowTop;
                
                ubyte statusWindowOpacity = 255;
                
                if (cursorTop >= 0 && 
                    cursorTop + characterHeight >= statusWindowTop && 
                    cursorLeft >= 0 &&
                    cursorLeft + characterWidth >= statusWindowLeft)
                {
                    statusWindowOpacity = 32;
                }
            
                DrawPopUpBox(statusWindowLeft, statusWindowTop, statusWindowRight, statusWindowBottom, statusWindowOpacity);
                
                foreach (statusLineNumber, line; statusLines[0 .. statusLineCount])
                {
                    auto textLeft = max(0, statusWindowRight - line.length * characterWidth - characterCenterX);
                    printText(line.text[0 .. line.length], textLeft, statusLineTop, timeInMilliseconds, NamedColor.Popup, FontStyle.Normal, statusWindowOpacity);
                    
                    if (statusLineNumber == queuedCommandsStatusLine)
                    {
                        queuedCommandsStatusLineTop    = statusLineTop;
                        queuedCommandsStatusLineBottom = statusLineTop + characterHeight;
                        queuedCommandsStatusLineLeft   = textLeft;
                        queuedCommandsStatusLineRight  = statusWindowRight;
                        queuedCommandsPopupBottom      = statusWindowTop - 2;
                    }
                    
                    if (line.isSearch)
                    {
                        DrawCursor(
                            textLeft + searchCursorOffset * characterWidth, 
                            statusLineTop, 
                            oldPopupCursorTop, 
                            oldPopupCursorLeft, 
                            statusWindowOpacity);
                        
                        SetDrawColor(AdjustOpacity(selection.color, statusWindowOpacity));
                        FillRectangle(
                            textLeft + searchSelectionStartOffset * characterWidth, 
                            statusLineTop, 
                            textLeft + searchSelectionEndOffset * characterWidth, 
                            statusLineTop + characterHeight);
                    }
                    
                    statusLineTop += characterHeight;
                }
            }
            
            rollover.isVisible = false;
            
            // Draw rollover popup
            
            if (mouseY < memoHeight && mouseX < memoWidth)
            {
                auto mouseLine = (mouseY - screenYOffset) / characterHeight;
                auto mouseColumn = (mouseX - marginWidth) / characterWidth;
                
                if (0 <= mouseLine && mouseLine < memoHeightInLines &&
                    0 <= mouseColumn && mouseColumn < windowWidthInCharacters)
                {
                    auto location = buffer.LocationAtScreenLine!false(mouseLine);
                    auto table = cast(TableBufferItem)location.Item;
                    
                    if (table !is null)
                    {
                        int columnStartInCharacters;
                        auto rolloverTextLines = table.RolloverText(
                            location.Line, 
                            mouseLine, 
                            mouseColumn + buffer.HorizontalCharacterCountOffset, 
                            windowWidthInCharacters, 
                            columnStartInCharacters, 
                            rollover.totalWidthInCharacters);
                        
                        if (rolloverTextLines.length > 0)
                        {
                            rollover.isVisible = true;
                            columnStartInCharacters -= buffer.HorizontalCharacterCountOffset;
                            
                            rollover.totalLineCount             = rolloverTextLines.intLength;
                            rollover.visibleLineCount       = min(memoHeightInLines, rollover.totalLineCount);
                            rollover.visibleCharacterCount  = min(rollover.totalWidthInCharacters, windowWidthInCharacters - 3);
                            rollover.verticalScrollOffset   = min(rollover.verticalScrollOffset,   max(0, rollover.totalLineCount             - rollover.visibleLineCount));
                            rollover.horizontalScrollOffset = min(rollover.horizontalScrollOffset, max(0, rollover.totalWidthInCharacters - rollover.visibleCharacterCount));
                            
                            immutable isOverlaidOnMatchingText = 
                                windowWidthInCharacters - rollover.visibleCharacterCount - 3 > columnStartInCharacters && 
                                memoHeightInLines - rollover.totalLineCount > mouseLine;
                            
                            immutable left = max(0, min(cast(int)(windowWidthInCharacters - rollover.visibleCharacterCount - 3), columnStartInCharacters));
                            immutable top  = max(0, min(cast(int)(memoHeightInLines - rollover.totalLineCount), mouseLine + (isOverlaidOnMatchingText ? 0 : 1)));
                            
                            immutable popupTop    = screenYOffset + top * characterHeight + (isOverlaidOnMatchingText ? 0 : characterCenterY);
                            immutable popupLeft   = marginWidth   + left * characterWidth + (isOverlaidOnMatchingText ? -characterCenterX : characterCenterX);
                            immutable popupRight  = marginWidth + popupLeft + rollover.visibleCharacterCount * characterWidth + characterWidth;
                            immutable popupBottom = popupTop + rollover.visibleLineCount * characterHeight;
                            immutable popupHeight = popupBottom - popupTop - 3;
                            
                            immutable firstVisibleLine = rollover.verticalScrollOffset;
                            immutable lastVisibleLine  = min(rollover.totalLineCount, firstVisibleLine + rollover.visibleLineCount);
                            
                            DrawPopUpBox(popupLeft, popupTop, popupRight, popupBottom);
                            
                            int dummy;
                            DrawPopUpScrollBar(
                                popupTop, 
                                popupRight, 
                                popupHeight, 
                                firstVisibleLine, 
                                lastVisibleLine, 
                                rollover.totalLineCount, 
                                dummy);
                            
                            int lineTop = popupTop;
                            immutable lineLeft = popupLeft + characterCenterX;
                            foreach (line; rolloverTextLines[firstVisibleLine .. lastVisibleLine])
                            {
                                if (line.length > rollover.horizontalScrollOffset)
                                    printText(
                                        line.toUtf8Slice[rollover.horizontalScrollOffset .. min(line.toUtf8Slice.length, rollover.horizontalScrollOffset + rollover.visibleCharacterCount)], 
                                        lineLeft, 
                                        lineTop, 
                                        timeInMilliseconds, 
                                        NamedColor.Popup, 
                                        FontStyle.Normal);
                                
                                lineTop += characterHeight;
                            }
                        }
                    }
                }
            }
            
            queuedCommands.isVisible = false;
            
            if (queuedCommandsStatusLineLeft <= mouseX && mouseX < queuedCommandsStatusLineRight &&
                queuedCommandsStatusLineTop  <= mouseY && mouseY < queuedCommandsStatusLineBottom)
            {
                queuedCommands.isVisible = true;
                queuedCommands.totalLineCount         = Program.Interpreter.commandQueue.totalLines;
                queuedCommands.totalWidthInCharacters = Program.Interpreter.commandQueue.width;
                queuedCommands.visibleLineCount       = min(queuedCommandsPopupBottom / characterHeight, queuedCommands.totalLineCount);
                queuedCommands.visibleCharacterCount  = min(Program.Interpreter.commandQueue.width, windowWidthInCharacters - 3);
                queuedCommands.verticalScrollOffset   = min(queuedCommands.verticalScrollOffset,   max(0, queuedCommands.totalLineCount             - queuedCommands.visibleLineCount));
                queuedCommands.horizontalScrollOffset = min(queuedCommands.horizontalScrollOffset, max(0, queuedCommands.totalWidthInCharacters - queuedCommands.totalWidthInCharacters));
                
                immutable queuedCommandsPopupRight  = memoWidth  - 4;
                immutable queuedCommandsPopupTop    = max(0, queuedCommandsPopupBottom - queuedCommands.visibleLineCount       * characterHeight - 4);
                immutable queuedCommandsPopupLeft   = max(0, queuedCommandsPopupRight  - queuedCommands.totalWidthInCharacters * characterWidth - characterWidth - 1);
                immutable queuedCommandsPopupHeight = queuedCommandsPopupBottom - queuedCommandsPopupTop - 3;
                
                immutable firstVisibleLine = queuedCommands.verticalScrollOffset;
                immutable lastVisibleLine  = min(queuedCommands.totalLineCount, firstVisibleLine + queuedCommands.visibleLineCount);
                
                int queuedLineTop = queuedCommandsPopupTop;
                
                DrawPopUpBox(queuedCommandsPopupLeft, queuedCommandsPopupTop, queuedCommandsPopupRight, queuedCommandsPopupBottom, 255);
                
                int queryDividerRight;
                DrawPopUpScrollBar(
                    queuedCommandsPopupTop, 
                    queuedCommandsPopupRight, 
                    queuedCommandsPopupHeight, 
                    firstVisibleLine, 
                    lastVisibleLine, 
                    queuedCommands.totalLineCount, 
                    queryDividerRight);
                
                queryDividerRight -= characterCenterX;
                
                foreach (line; Program.Interpreter.commandQueue.visibleLines(queuedCommands.visibleLineCount))
                {
                    printText(line.Spans, queuedCommandsPopupLeft + 2, queuedLineTop, timeInMilliseconds);
                    queuedLineTop += characterHeight;
                }
                
                SetDrawColor(AdjustOpacity(popupText.color, 92));
                
                int absoluteCommandQueueLineNumber = 0;
                foreach (queryLineCount; Program.Interpreter.commandQueue.formattedSectionsLengths)
                {
                    absoluteCommandQueueLineNumber += queryLineCount;
                    
                    if (absoluteCommandQueueLineNumber <= queuedCommands.verticalScrollOffset)
                        continue;
                    
                    if (absoluteCommandQueueLineNumber >= queuedCommands.verticalScrollOffset + queuedCommands.visibleLineCount)
                        break;
                    
                    immutable queryDividerY = queuedCommandsPopupTop + (absoluteCommandQueueLineNumber - queuedCommands.verticalScrollOffset) * characterHeight;
                    immutable queryDividerLeft = queuedCommandsPopupLeft + characterCenterX;
                    
                    DrawLine(queryDividerLeft, queryDividerY, queryDividerRight, queryDividerY);
                }
            }
            
            if (isDraggingText)
            {
                immutable selectedLines = buffer.EditorItem.SelectionEndLine + 1 - buffer.EditorItem.SelectionStartLine;
                
                auto selectedWidth = 0;
                foreach (lineNumber; buffer.EditorItem.SelectionStartLine .. buffer.EditorItem.SelectionEndLine + 1)
                    selectedWidth = max(selectedWidth, buffer.EditorItem.SelectionEndOnLine(lineNumber) - buffer.EditorItem.SelectionStartOnLine(lineNumber));
                
                immutable dragBoxLeft         = mouseX;
                immutable dragBoxTop          = mouseY;
                immutable dragBoxRight        = mouseX + selectedWidth * characterWidth + characterWidth;
                immutable dragBoxBottom       = mouseY + selectedLines * characterHeight;
                int       dragBoxLineTextLeft = dragBoxLeft + characterCenterX;
                int       dragBoxLineTextTop  = dragBoxTop;
                
                DrawPopUpBox(dragBoxLeft, dragBoxTop, dragBoxRight, dragBoxBottom, 127);
                
                foreach (lineNumber; buffer.EditorItem.SelectionStartLine .. buffer.EditorItem.SelectionEndLine + 1)
                {
                    printText(
                        buffer.EditorItem.FormattedTextAt(
                            lineNumber, 
                            buffer.EditorItem.SelectionStartOnLine(lineNumber), 
                            selectedWidth, 
                            -1), 
                        dragBoxLineTextLeft, 
                        dragBoxLineTextTop, 
                        timeInMilliseconds, 
                        127);
                    
                    dragBoxLineTextTop += characterHeight;
                }
            }
            
            debug if (DebugText.length > 0)
                printText(DebugText, horizontalScrollBarBackgroundLeft, windowHeight - characterHeight, timeInMilliseconds);
            
            CheckSDLError;
            
            SDL_RenderPresent(renderer);
        }
        catch (SDLException exception) 
        {
            DebugLog("Exception " ~ exception.InnerMessage ~ exception.msg);
            DebugLog(exception.msg);
            InvalidateImages;
            if (exception.InnerMessage != "Present(): DEVICELOST" &&
                // exception.InnerMessage != "BeginScene(): INVALIDCALL" &&
                // exception.InnerMessage != "Reset(): INVALIDCALL" &&
                // exception.InnerMessage != "Invalid renderer" &&
                exception.InnerMessage != "Invalid texture")
                throw exception;
        }
    }
    
    private void DrawCursor(int left, int top, ref int oldLeft, ref int oldTop, const ubyte opacity = 255)
    {
        immutable bottom = top + characterHeight - 1;
        
        SetDrawColor(AdjustOpacity(cursor.color, opacity));
        if (Program.Editor.IsInsertModeOn)
        {
            // Draw underscore style cursor.
            if (Program.Settings.IsSnapCursorOn && (oldLeft != left || oldTop != top))
            {
                if (oldTop == top)
                {
                    // Draw a single horizontal line of trailing pixels.
                    immutable animationWidth = cast(double)abs(left - oldLeft);
                    immutable xIncrement = oldLeft < left ? 1 : -1;
                    immutable aIncrement = opacity / (1.0 * animationWidth);
                    immutable startX = oldLeft < left ? oldLeft : oldLeft + characterWidth;
                    immutable endX   = oldLeft < left ? left    : left    + characterWidth;
                    
                    auto a = 0.0;
                    for (int x = startX; x != endX; x += xIncrement)
                    {
                        SetDrawColor(AdjustOpacity(cursor.color, cast(ubyte)a));
                        DrawPixel(x, bottom);
                        
                        a += aIncrement;
                    }
                }
                else
                {
                    // Draw a smeared underscore vertically, and shifting across as necessary.
                    immutable oldBottom = oldTop + characterHeight - 1;
                    
                    immutable animationHeight = cast(double)abs(bottom - oldBottom);
                    immutable yIncrement = oldBottom < bottom ? 1 : -1;
                    immutable xIncrement = (left - oldLeft) / animationHeight;
                    immutable aIncrement = opacity / (3.0 * animationHeight);
                    
                    auto x = cast(double)oldLeft;
                    auto a = 0.0;
                    for (int y = oldBottom; y != bottom; y += yIncrement)
                    {
                        SetDrawColor(AdjustOpacity(cursor.color, cast(ubyte)a / 2));
                        DrawPixel(cast(int)x, y);
                        DrawPixel(cast(int)x + characterWidth, y);
                        
                        SetDrawColor(AdjustOpacity(cursor.color, cast(ubyte)a));
                        DrawLine(cast(int)x + 1, y, cast(int)x + characterWidth - 1, y);
                        
                        a += aIncrement;
                        x += xIncrement;
                    }
                }
                
                Invalidate;
            }
            
            SetDrawColor(AdjustOpacity(cursor.color, opacity));
            DrawLine(left, bottom, left + characterWidth, bottom);
        }
        else
        {
            // Draw insertion style cursor.
            if (Program.Settings.IsSnapCursorOn && (oldLeft != left || oldTop != top))
            {
                if (oldLeft == left)
                {
                    // Draw a single vertical line of trailing pixels.
                    immutable animationHeight = cast(double)abs(top - oldTop);
                    immutable yIncrement = oldTop < top ? 1 : -1;
                    immutable aIncrement = opacity / (1.0 * animationHeight);
                    immutable startY = oldTop < top ? oldTop : oldTop + characterHeight - 1;
                    immutable endY   = oldTop < top ? top    : top    + characterHeight - 1;
                    
                    auto a = 0.0;
                    for (int y = startY; y != endY; y += yIncrement)
                    {
                        SetDrawColor(AdjustOpacity(cursor.color, cast(ubyte)a));
                        DrawPixel(left, cast(int)y);
                        
                        a += aIncrement;
                    }
                }
                else
                {
                    // Draw a smeared insertion bar horizontally, also shifting vertically as necessary.
                    immutable animationWidth = cast(double)abs(left - oldLeft);
                    immutable xIncrement = oldLeft < left ? 1 : -1;
                    immutable yIncrement = (top - oldTop) / animationWidth;
                    immutable aIncrement = opacity / (3.0 * animationWidth);
                    
                    auto y = cast(double)oldTop;
                    auto a = 0.0;
                    for (int x = oldLeft; x != left; x += xIncrement)
                    {
                        SetDrawColor(AdjustOpacity(cursor.color, cast(ubyte)a / 2));
                        DrawPixel(x, cast(int)y);
                        DrawPixel(x, cast(int)y + characterHeight);
                        
                        SetDrawColor(AdjustOpacity(cursor.color, cast(ubyte)a));
                        DrawLine(x, cast(int)y + 1, x, cast(int)y + characterHeight - 1);
                        
                        a += aIncrement;
                        y += yIncrement;
                    }
                }
                
                Invalidate;
            }
            
            SetDrawColor(AdjustOpacity(cursor.color, opacity));
            DrawLine(left, top, left, bottom);
        }
        
        if (abs(left - oldLeft) < 3)
            oldLeft = left;
        else
            oldLeft += (left - oldLeft) / 3;
        
        if (abs(top - oldTop) < 3)
            oldTop = top;
        else
            oldTop += (top - oldTop) / 3;
    }
    
    private void DrawPopUpBox(
        const int popupLeft, 
        const int popupTop, 
        const int popupRight, 
        const int popupBottom, 
        const ubyte borderOpacity = 255,
        const ubyte backgroundOpacity = 255)
    {
        SetDrawColor(AdjustOpacity(popupBackground.color, backgroundOpacity));
        FillRectangle(popupLeft, popupTop, popupRight, popupBottom);
        
        SetDrawColor(AdjustOpacity(popupBorder.color, borderOpacity));
        DrawRectangle(popupLeft - 1, popupTop - 1, popupRight, popupBottom);
        
        SetDrawColor(AdjustOpacity(popupDropShadow.color, borderOpacity));
        FillRectangle(popupRight + 1, popupTop    + 2, popupRight + 4, popupBottom + 4);
        FillRectangle(popupLeft  + 2, popupBottom + 1, popupRight + 1, popupBottom + 4);
    }
    
    private void DrawPopUpScrollBar(
        const int popupTop, 
        const int popupRight, 
        const int popupHeight, 
        const int firstVisibleLine, 
        const int lastVisibleLine, 
        const int totalLineCount, 
        out int selectionRight)
    {
        immutable scrollBarTop    = popupTop + popupHeight * firstVisibleLine / totalLineCount + 1;
        immutable scrollBarBottom = popupTop + popupHeight *  lastVisibleLine / totalLineCount + 2;
        
        selectionRight = popupRight;
        
        if (firstVisibleLine > 0 ||
            lastVisibleLine  < totalLineCount - 1)
        {
            SetDrawColor(popupText.color);
            FillRectangle(popupRight - 4, scrollBarTop, popupRight - 2, scrollBarBottom);
            
            selectionRight -= 6;
        }
    }
    
    // This is a convolution matrix for the glow effect.  Yes I know a shader would be 
    // way faster and less code, but it looks like I need OpenGL or DirectX, and it 
    // appears to be a can of worms for a simple effect.
    
    enum matrixSize = 7;
    enum matrixHalfSize = matrixSize / 2;
    enum matrix = ()
    {
        import std.math : sqrt;
        
        float[matrixSize + 1][matrixSize] matrix = 0.0F;
        
        static assert(matrixSize % 2 == 1);
        
        float sum = 0.0;
        enum maxRadius = sqrt(cast(float)(matrixHalfSize ^^ 2 + matrixHalfSize ^^ 2));
        
        foreach (matrixY; 0 .. matrixSize)
        {
            foreach (matrixX; 0 .. matrixSize)
            {
                const radius = sqrt(cast(float)((matrixX - matrixHalfSize) ^^ 2 + (matrixY - matrixHalfSize) ^^ 2));
                float value;
                
                if (radius >= maxRadius)
                    value = 0.0;
                else
                    value = 1.0 - radius / maxRadius;
                    
                sum += value;
                matrix[matrixY][matrixX] = value;
            }
        }
        
        if (sum <= 0.0 || sum > matrixSize ^^ 2)
            throw new Exception("Convolution matrix calculation failure.");
        
        foreach (matrixY; 0 .. matrixSize)
            foreach (matrixX; 0 .. matrixSize)
                matrix[matrixY][matrixX] /= sum;
        
        return matrix;
    }();
    
    private void RefreshCachedFontData()
    {
        if (isCachedFontDataValid)
            return;
        
        isCachedFontDataValid = true;
        characterGlyphs.reset;
        
        if (font[FontStyle.Normal] !is null)
        {
            font[FontStyle.Normal].TTF_CloseFont;
            font[FontStyle.Normal].destroy;
            font[FontStyle.Normal] = null;
        }
        
        if (font[FontStyle.Bold] !is null)
        {
            font[FontStyle.Bold].TTF_CloseFont;
            font[FontStyle.Bold].destroy;
            font[FontStyle.Bold] = null;
        }

        static foreach (fontStyle; EnumMembers!FontStyle)
        {{
            static if (fontStyle == FontStyle.Normal)
                auto fontData = import ("sono/desktop/Sono-Medium.ttf");
            else
                auto fontData = import ("sono/desktop/Sono-SemiBold.ttf");
            
            auto fontMemory = SDL_RWFromConstMem(cast(const void *)fontData, fontData.intLength);
            if (fontMemory is null)
                ThrowSDLError("Loading font.");
            
            font[fontStyle] = TTF_OpenFontRW(fontMemory, 1, fontSize);
            if (font[fontStyle] is null)
                ThrowSDLError("Creating font.");
            
            final switch (fontHint) with (FontHints)
            {
                case None:          TTF_SetFontHinting(font[fontStyle], TTF_HINTING_NONE);           break;
                case Normal:        TTF_SetFontHinting(font[fontStyle], TTF_HINTING_NORMAL);         break;
                case Light:         TTF_SetFontHinting(font[fontStyle], TTF_HINTING_LIGHT);          break;
                case Mono:          TTF_SetFontHinting(font[fontStyle], TTF_HINTING_MONO);           break;
                case LightSubPixel: TTF_SetFontHinting(font[fontStyle], TTF_HINTING_LIGHT_SUBPIXEL); break;
            }
        }}
        
        enum nullPointer = cast(int*)0;
        
        TTF_GlyphMetrics(font[FontStyle.Bold], 'W', nullPointer, nullPointer, nullPointer, nullPointer, &characterWidth);
        characterHeight = TTF_FontHeight(font[FontStyle.Bold]);
        characterRectangle = SDL_Rect(0, 0, characterWidth, characterHeight);
        
        characterCenterX = characterWidth / 2;
        characterCenterY = characterHeight / 2;
        
        glowCharacterWidth  = characterWidth  + 2 * matrixHalfSize;
        glowCharacterHeight = characterHeight + 2 * matrixHalfSize;
        glowCharacterOffset = matrixHalfSize;
        glowCharacterRectangle = SDL_Rect(0, 0, glowCharacterWidth, glowCharacterHeight);
        
        CheckSDLError;
        
        auto glyphMissingSurface = SDL_CreateRGBSurface(0, characterWidth, characterHeight, 32, 0, 0, 0, 0);
        scope (exit) glyphMissingSurface.SDL_FreeSurface;
        
        if (glyphMissingSurface is null)
            ThrowSDLError;
        
        glyphMissingSurface.SDL_SetColorKey(SDL_TRUE, 0);
        SDL_FillRect(glyphMissingSurface, null, SDL_MapRGBA(glyphMissingSurface.format, 255, 255, 255, 127));
        
        CheckSDLError;
        
        glyphMissingTexture = SDL_CreateTextureFromSurface(renderer, glyphMissingSurface);
        
        RefreshWindowSizes!(WindowDimensions.Reuse);
    }
    
    private Glyph renderGlyph(dchar rawCharacter)
    {
        auto glyph = Glyph();
    
        // import std.datetime.stopwatch : StopWatch, AutoStart;
        // auto stopWatch = StopWatch(AutoStart.yes);
        
        static foreach (fontStyle; EnumMembers!FontStyle)
        {{
            try
            {
                // This framed work area is so we can scan the matrix area over this data
                // without worrying about boundary conditions.  Combined with static foreach 
                // below, this is noticeably quicker.
                const framedPixelsWidth  = glowCharacterWidth  + 2 * matrixHalfSize + 1;
                const framedPixelsHeight = glowCharacterHeight + 2 * matrixHalfSize;
                
                immutable character = (rawCharacter >= 10 && rawCharacter <= 13) ? 182 :
                                      (rawCharacter == 9) ? 8594 : // Unicode for a right arrow.
                                       rawCharacter;
                
                immutable opacity = (rawCharacter == 10 || rawCharacter == 13 || rawCharacter == 9) ? 127 : 255;
                
                SDL_Surface* surface;
                
                final switch (FontDrawMode) with (FontDrawModes)
                {
                    case Blend:
                        surface = TTF_RenderGlyph32_Blended(font[fontStyle], character, SDL_Color(255, 255, 255, opacity));
                        break;
                      
                    case Solid:
                        surface = TTF_RenderGlyph32_Solid(font[fontStyle], character, SDL_Color(255, 255, 255, opacity));
                        break;
                
                    case Shade:
                        surface = TTF_RenderGlyph32_Shaded(font[fontStyle], character, SDL_Color(255, 255, 255, opacity), SDL_Color(0, 0, 0, 0));
                        break;
                }
                
                if (surface is null)
                    ThrowSDLError;
                
                surface.SDL_SetColorKey(SDL_TRUE, 0);
                CheckSDLError;
                
                auto pixelFormat = SDL_AllocFormat(nativePixelFormat);
                surface = SDL_ConvertSurface(surface, pixelFormat, 0);
                CheckSDLError;
                
                auto surfacePixels = (cast(int*)surface.pixels)[0 .. surface.w * surface.h];
                
                scope (exit) surface.SDL_FreeSurface;
                
                auto surfaceIndex = 0;
                
                auto framedPixels = new float[framedPixelsWidth * framedPixelsHeight];
                framedPixels[] = 0.0;
                
                version (D_SIMD)
                {
                    const surfaceRowEndDivisibleByFour = 4 * (surface.w / 4);
                    const glowEndDivisibleByFour       = 4 * (glowCharacterHeight * glowCharacterWidth / 4);
                }
                
                {
                    auto framedPixelsIndex = 2 * matrixHalfSize * framedPixelsWidth + 2 * matrixHalfSize;
                    const frameRowPadding = framedPixelsWidth - surface.w;
                    
                    foreach (surfaceY; 0 .. surface.h)
                    {
                        // I tried vectorizing this one too, but it went slower.
                        
                        foreach (surfaceX; 0 .. surface.w)
                        {
                            version (LittleEndian)
                                framedPixels[framedPixelsIndex] = float(surfacePixels[surfaceIndex] >>> 24);
                            else
                                framedPixels[framedPixelsIndex] = float(surfacePixels[surfaceIndex] & 0x000000FF);
                            
                            surfaceIndex++;
                            framedPixelsIndex++;
                        }
                        
                        framedPixelsIndex += frameRowPadding;
                        
                        // The rendered glyph may be larger than our framed work area (and is at larger font sizes). 
                        // I suspect this is the bold font style causing the problem.  If it looks like we're about 
                        // to overflow, skip out here.
                        if (framedPixelsIndex > framedPixels.length - surface.w)
                            break;
                    }
                }
                
                if (IsShowingScanLines)
                {
                    surfaceIndex = 0;
                    for (int surfaceY = 0; surfaceY < surface.h; surfaceY += 2)
                    {
                        version (D_SIMD)
                        {
                            import core.simd;
                            
                            for (auto surfaceX = 0; surfaceX < surfaceRowEndDivisibleByFour; surfaceX += 4)
                            {
                                int4 pixelsVector = loadUnaligned(cast(int4*)surfacePixels[surfaceIndex .. $].ptr);
                                
                                version (LittleEndian)
                                {
                                    const int4 alphaMask = [0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000];
                                    const int4 rgbMask   = [0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF];
                                    
                                    int4 newAlpha = cast(int4)__simd_ib(XMM.PSRLD, pixelsVector, 1); // Shift right 32-bit numbers.  // Halve the alpha channel. 
                                    newAlpha      = cast(int4)__simd(XMM.PAND, newAlpha, alphaMask); // Logical AND.
                                    
                                    int4 originalRGB = cast(int4)__simd(XMM.PAND, pixelsVector, rgbMask);
                                }
                                else
                                {
                                    const int4 alphaMask = [0x000000FF, 0x000000FF, 0x000000FF, 0x000000FF];
                                    const int4 rgbMask   = [0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00, 0xFFFFFF00];
                                    
                                    int4 newAlpha = cast(int4)__simd(XMM.PAND, pixelsVector, alphaMask); // Logical AND.
                                    newAlpha      = cast(int4)__simd_ib(XMM.PSRLD, newAlpha, 1); // Shift right 32-bit numbers.  // Halve the alpha channel. 
                                    
                                    int4 originalRGB = cast(int4)__simd(XMM.PAND, pixelsVector, rgbMask);
                                }
                                
                                pixelsVector = cast(int4)__simd(XMM.POR, newAlpha, originalRGB); // Logical OR.
                                surfacePixels[surfaceIndex .. surfaceIndex + 4] = cast(int[4])pixelsVector;
                                
                                surfaceIndex += 4;
                            }
                            
                            for (int surfaceX = surfaceRowEndDivisibleByFour; surfaceX < surface.w; surfaceX++)
                            {
                                version (LittleEndian)
                                {
                                    const newAlpha    = (surfacePixels[surfaceIndex] >>> 1) & 0xFF000000; // Halve the alpha channel. 
                                    const originalRGB =  surfacePixels[surfaceIndex]        & 0x00FFFFFF;
                                }
                                else
                                {
                                    const newAlpha    = (surfacePixels[surfaceIndex] & 0x000000FF) >>> 1; // Halve the alpha channel. 
                                    const originalRGB =  surfacePixels[surfaceIndex] & 0xFFFFFF00       ;
                                }
                                
                                surfacePixels[surfaceIndex] = originalRGB | newAlpha;
                                surfaceIndex++;
                            }
                        }
                        else
                        {
                            foreach (surfaceX; 0 .. surface.w)
                            {
                                version (LittleEndian)
                                {
                                    const newAlpha    = (surfacePixels[surfaceIndex] >>> 1) & 0xFF000000; // Halve the alpha channel. 
                                    const originalRGB =  surfacePixels[surfaceIndex]        & 0x00FFFFFF;
                                }
                                else
                                {
                                    const newAlpha    = (surfacePixels[surfaceIndex] & 0x000000FF) >>> 1; // Halve the alpha channel. 
                                    const originalRGB =  surfacePixels[surfaceIndex] & 0xFFFFFF00       ;
                                }
                                
                                surfacePixels[surfaceIndex] = originalRGB | newAlpha;
                                surfaceIndex++;
                            }
                        }
                        
                        surfaceIndex += surface.w;
                    }
                }
                
                auto glowPixels = new int[glowCharacterHeight * glowCharacterWidth];
                auto glowPixelIndex = 0;
                auto framedPixelsMatrixStartY = 0;
                
                foreach (glowY; 0 .. glowCharacterHeight)
                {
                    auto framedPixelsMatrixStartX = framedPixelsMatrixStartY;
                    
                    foreach (glowX; 0 .. glowCharacterWidth)
                    {
                        auto framedPixelsIndex = framedPixelsMatrixStartX;                     
                        
                        version (D_SIMD)
                        {
                            import core.simd;
                            
                            float4 matrixRowLeft;
                            float4 matrixRowRight;
                            float4 rowLeft;
                            float4 rowRight;
                            float4 sumGrid = 0;
                            
                            static foreach (matrixY; 0 .. matrixSize)
                            {
                                matrixRowLeft  = loadUnaligned(cast(float4*)matrix[matrixY][0 .. 4].ptr);
                                matrixRowRight = loadUnaligned(cast(float4*)matrix[matrixY][4 .. 8].ptr);
                        
                                rowLeft  = loadUnaligned(cast(float4*)framedPixels[framedPixelsIndex     .. $].ptr);
                                rowRight = loadUnaligned(cast(float4*)framedPixels[framedPixelsIndex + 4 .. $].ptr);
                                
                                rowLeft  *= matrixRowLeft;
                                rowRight *= matrixRowRight;
                                sumGrid += cast(float4)__simd(XMM.HADDPS, rowLeft, rowRight);  // HorizontalAddFloat
                                framedPixelsIndex += framedPixelsWidth;
                            }
                            
                            float4 sumPairs = cast(float4)__simd(XMM.HADDPS, sumGrid);
                            sumPairs = cast(float4)__simd(XMM.HADDPS, sumPairs);
                            
                            glowPixels[glowPixelIndex] = cast(int)sumPairs[3];
                        }
                        else
                        {
                            auto sum = 0.0;
                            
                            static foreach (matrixY; 0 .. matrixSize)
                            {
                                static foreach (matrixX; 0 .. matrixSize)
                                    sum += framedPixels[framedPixelsIndex + matrixX] * matrix[matrixY][matrixX];
                                
                                framedPixelsIndex += framedPixelsWidth;
                            }
                            
                            version (LittleEndian)
                                glowPixels[glowPixelIndex] = (cast(ubyte)(sum) << 24) | 0x00FF_FFFF;
                            else
                                glowPixels[glowPixelIndex] =  cast(ubyte)(sum)        | 0xFFFF_FF00;
                        }
                        
                        glowPixelIndex++;
                        framedPixelsMatrixStartX++;
                    }
                    
                    framedPixelsMatrixStartY += framedPixelsWidth;
                }
                
                version (D_SIMD)
                {
                    import core.simd;
                    
                    // Convert the blurring value into an alpha over white pixels.
                    
                    for (auto index = 0; index < glowEndDivisibleByFour; index += 4)
                    {
                        int4 vector = loadUnaligned(cast(int4*)glowPixels[index .. $].ptr);
                        
                        version (LittleEndian)
                        {
                            const int4 rgbMask = [0x00FF_FFFF, 0x00FF_FFFF, 0x00FF_FFFF, 0x00FF_FFFF];
                            vector = cast(int4)__simd_ib(XMM.PSLLD, vector, 24); // Shift left 32-bit numbers.
                        }
                        else
                        {
                            const int4 rgbMask = [0xFFFF_FF00, 0xFFFF_FF00, 0xFFFF_FF00, 0xFFFF_FF00];
                        }
                        
                        vector = cast(int4)__simd(XMM.POR, vector, rgbMask); // Logical OR.
                        glowPixels[index .. index + 4] = cast(int[4])vector;
                    }
                    
                    for (int index = glowEndDivisibleByFour; index < glowCharacterHeight * glowCharacterWidth; index++)
                    {
                        version (LittleEndian)
                            glowPixels[index] = (cast(ubyte)(glowPixels[index]) << 24) | 0x00FF_FFFF;
                        else
                            glowPixels[index] =  cast(ubyte)(glowPixels[index])        | 0xFFFF_FF00;
                    }
                }
                
                auto glowCharacterRect = SDL_Rect(0, 0, glowCharacterWidth, glowCharacterHeight);
                
                auto newCharacterTexture = SDL_CreateTextureFromSurface(renderer, surface);
                if (newCharacterTexture is null)
                    ThrowSDLError;
                
                CheckSDLError;
                
                glyph.textures[fontStyle][Glyph.Variant.Normal] = newCharacterTexture;
                
                auto glowCharacterTexture = SDL_CreateTexture(renderer, nativePixelFormat, SDL_TEXTUREACCESS_STATIC, glowCharacterWidth, glowCharacterHeight);
                glowCharacterTexture.SDL_SetTextureBlendMode(SDL_BLENDMODE_BLEND);
                glowCharacterTexture.SDL_UpdateTexture(&glowCharacterRect, glowPixels.ptr, glowCharacterWidth * 4);
                
                CheckSDLError;
                
                glyph.textures[fontStyle][Glyph.Variant.Glow] = glowCharacterTexture;
            }
            catch (SDLException)
            {
                SDL_ClearError();
                glyph.textures[fontStyle][Glyph.Variant.Normal] = null;
                glyph.textures[fontStyle][Glyph.Variant.Glow] = null;
            }
        }}
        
        // stopWatch.stop;
        // Program.diagnosticInformation = stopWatch.peek.DurationToPrettyString;
        
        return glyph;
    }
    
    private void SetDrawColor(const SDL_Color color)
    {
        SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a).CheckSDLError;
    }
    
    private void SetDrawColor(const SDL_Color color, const ubyte alphaOverride)
    {
        SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, alphaOverride).CheckSDLError;
    }
    
    private auto LinearInterpolate(const SDL_Color colorA, const SDL_Color colorB, const double t) @nogc nothrow
    {
        return SDL_Color
        (
            cast(ubyte)(colorA.r + (colorB.r - colorA.r) * t), 
            cast(ubyte)(colorA.g + (colorB.g - colorA.g) * t), 
            cast(ubyte)(colorA.b + (colorB.b - colorA.b) * t), 
            cast(ubyte)(colorA.a + (colorB.a - colorA.a) * t)
        );
    }
    
    private static auto InvertColor(const SDL_Color source, const ubyte opacity) @nogc nothrow
    {
        return SDL_Color
        (
            255 - source.r, 
            255 - source.g, 
            255 - source.b, 
            opacity
        );
    }
    
    public static auto AdjustOpacity(const SDL_Color source, const ubyte opacity) @nogc nothrow pure
    {
        return SDL_Color(source.r, source.g, source.b, source.a * opacity / 255);
    }
    
    public static auto AdjustOpacity(const ubyte opacity1, const ubyte opacity2) @nogc nothrow pure
    {
        return cast(ubyte)(opacity1 * opacity2 / 255);
    }
    
    private void printText(
        const StringReference text, 
        const int x, 
        const int y, 
        const int timeInMilliseconds, 
        const NamedColor fontColor = NamedColor.Normal, 
        const FontStyle fontStyle = FontStyle.Normal, 
        const ubyte opacity = 255)
    {
        auto color        = LookupNamedColor!( No.isOutline)(fontColor, timeInMilliseconds);
        auto outlineColor = LookupNamedColor!(Yes.isOutline)(fontColor, timeInMilliseconds);
        
        int characterX = x;
        foreach (character; text.byDchar)
        {
            if (character == 32 || character == 0)
            {
                characterX += characterWidth;
                continue;
            }

            if (isOutliningNormalText || fontColor != NamedColor.Normal || fontStyle != FontStyle.Normal)
            {
                auto glowCharacterTexture = getCharacter(character, fontStyle, Glyph.Variant.Glow);
                
                SDL_SetTextureColorMod(glowCharacterTexture, outlineColor.r, outlineColor.g, outlineColor.b);
                SDL_SetTextureAlphaMod(glowCharacterTexture, cast(ubyte)(outlineColor.a * opacity / 255));
                
                auto glowDestinationRectangle = SDL_Rect(cast(int)characterX - cast(int)glowCharacterOffset, cast(int)y - cast(int)glowCharacterOffset, glowCharacterWidth, glowCharacterHeight);
                
                SDL_RenderCopy(renderer, glowCharacterTexture, &glowCharacterRectangle, &glowDestinationRectangle).CheckSDLError;
            }
            
            auto characterDestinationRectangle = SDL_Rect(characterX, y, characterWidth, characterHeight);
            auto characterTexture = getCharacter(character, fontStyle);
            
            SDL_SetTextureColorMod(characterTexture, color.r, color.g, color.b);
            SDL_SetTextureAlphaMod(characterTexture, cast(ubyte)(color.a * opacity / 255));
            
            SDL_RenderCopy(renderer, characterTexture, &characterRectangle, &characterDestinationRectangle).CheckSDLError;
            
            characterX += characterWidth;
        }
    }
    
    private void printText(
        const FormattedText.Span[] spans, 
        const int x, 
        const int y, 
        const int timeInMilliseconds, 
        const ubyte opacity = 255)
    {
        foreach (span; spans)
            printText(
                span.Text, 
                x + span.StartColumn * characterWidth, 
                y, 
                timeInMilliseconds, 
                span.Color, 
                span.Style, 
                AdjustOpacity(span.Opacity, opacity));
    }
    
    private void FillRectangle(const int left, const int top, const int right, const int bottom)
    {
        auto rectangle = const SDL_Rect(left, top, right - left, bottom - top);
        SDL_RenderFillRect(renderer, &rectangle).CheckSDLError;
    }
    
    private void DrawLine(const int left, const int top, const int right, const int bottom)
    {
        SDL_RenderDrawLine(renderer, left, top, right, bottom).CheckSDLError;
    }
    
    private void DrawPixel(const int x, const int y)
    {
        SDL_RenderDrawPoint(renderer, x, y);
    }
    
    private void DrawRectangle(const int left, const int top, const int right, const int bottom)
    {
        // Top line
        SDL_RenderDrawLine(renderer, left, top, right, top).CheckSDLError;
        
        // Bottom Line
        SDL_RenderDrawLine(renderer, left, bottom, right, bottom).CheckSDLError;
        
        // Left Line
        SDL_RenderDrawLine(renderer, left, top + 1, left, bottom - 1).CheckSDLError;
        
        // Right Line
        SDL_RenderDrawLine(renderer, right, top + 1, right, bottom - 1).CheckSDLError;
    }
    
    public void MouseButtonDown(const int x, const int y, const int button)
    {
        if (button == SDL_BUTTON_LEFT)
        {
            Invalidate;
            
            if (isFullScreen &&
                closeButtonLeft <= x && x < closeButtonRight && 
                closeButtonTop  <= y && y < closeButtonBottom)
            {
                isCloseButtonClicked = true;
                return;
            }
            
            if (x >= verticalScrollBarLeft && 
                x <= verticalScrollBarRight && 
                y >= verticalScrollBarBackgroundTop && 
                y <= verticalScrollBarBackgroundBottom)
            {
                isDraggingVerticalScrollBar = verticalScrollBarScrubberTop <= y && y <= verticalScrollBarScrubberBottom;
                
                if (isDraggingVerticalScrollBar)
                {
                    verticalScrollBarDragOffset = y - verticalScrollBarScrubberTop;
                    buffer.FreezeVerticalScrollingValues;
                }
                else if (Program.Settings.VerticalScrollBarMode != Program.Settings.VerticalScrollBarModes.Simple)
                {
                    isDraggingVerticalScrollBar = true;
                    verticalScrollBarDragOffset = (verticalScrollBarScrubberBottom - verticalScrollBarScrubberTop) / 2;
                    ScrollScreenToVerticalPixel(y);
                }
            }
            else
                isDraggingVerticalScrollBar = false;
            
            isDraggingHorizontalScrollBar = horizontalScrollBarScrubberLeft <= x && x <= horizontalScrollBarScrubberRight &&
                                            horizontalScrollBarTop <= y && y <= horizontalScrollBarBottom;
            
            if (isDraggingHorizontalScrollBar)
                horizontalScrollBarDragOffset = x - horizontalScrollBarScrubberLeft;
            
            isDraggingGrip = gripButtonLeft < x && x < gripButtonRight && 
                             gripButtonTop  < y && y < gripButtonBottom;
            
            if (isDraggingGrip)
            {
                horizontalGripMouseOffset = windowWidth  - x;
                verticalGripMouseOffset   = windowHeight - y;
            }
            
            if (x <= marginWidth)
            {
                buffer.SelectWholeLineAt(mouseY / characterHeight);
                isSelecting = true;
            }
            else if (x < memoWidth && y < memoHeight)
            {
                immutable clickLine = y / characterHeight;
                immutable clickColumn = (x - marginWidth) / characterWidth;
                
                const location = buffer.LocationAtScreenLine!false(clickLine);
                immutable targetColumn = clickColumn + buffer.HorizontalCharacterCountOffset;
                
                isDraggingText = 
                    buffer.SelectionType == Buffer.SelectionTypes.EditorOnly && 
                    location.Item is buffer.EditorItem && 
                    buffer.EditorItem.IsLineSelected(location.Line) && 
                    buffer.EditorItem.SelectionStartOnLine(location.Line) <= targetColumn && 
                    buffer.EditorItem.SelectionEndOnLine(location.Line) > targetColumn;
                
                if (!isDraggingText)
                {
                    buffer.EditorItem.ResetSelection;
                    
                    isSelecting = true;
                    
                    buffer.SetSelectionStartScreen(clickLine, clickColumn, clickColumn + 1, buffer.SelectingMethods.BandBox);
                    buffer.SetSelectionEndScreen  (clickLine, clickColumn, clickColumn + 1);
                }
            }
        }
    }
    
    public void MouseButtonDownRepeat(const int x, const int y, const int button)
    {
        if (isSelecting || 
            isDraggingVerticalScrollBar || 
            isDraggingHorizontalScrollBar || 
            isDraggingGrip || 
            isCloseButtonClicked)
            return;
        
        if (button == SDL_BUTTON_LEFT)
        {
            // Vertical scroll bar
            if (isVerticalScrollBarVisible && verticalScrollBarLeft <= x && x <= verticalScrollBarRight) 
            {
                if (verticalScrollBarTopButtonTop <= y && y <= verticalScrollBarTopButtonBottom)   
                    buffer.ScrollScreenVerticallyBy(-1);
                else if (Program.Settings.VerticalScrollBarMode == Program.Settings.VerticalScrollBarModes.Simple && 
                         verticalScrollBarTopButtonBottom < y && y < verticalScrollBarScrubberTop)
                    buffer.ScrollScreenUpByOnePage;
                else if (Program.Settings.VerticalScrollBarMode == Program.Settings.VerticalScrollBarModes.Simple && 
                         verticalScrollBarScrubberBottom < y && y < verticalScrollBarBottomButtonTop)
                    buffer.ScrollScreenDownByOnePage;
                else if (verticalScrollBarBottomButtonTop <= y && y <= verticalScrollBarBottomButtonBottom)
                    buffer.ScrollScreenVerticallyBy(1);
            }
            
            // Horizontal scroll bar
            if (isHorizontalScrollBarVisible && horizontalScrollBarTop <= y && y <= horizontalScrollBarBottom) 
            {
                if (horizontalScrollBarLeftButtonLeft <= x && x <= horizontalScrollBarLeftButtonRight)
                    buffer.ScrollScreenHorizontallyBy(-1);
                else if (horizontalScrollBarLeftButtonRight < x && x < horizontalScrollBarScrubberLeft)
                    buffer.ScrollScreenLeftByOnePage;
                else if (horizontalScrollBarScrubberRight < x && x < horizontalScrollBarRightButtonLeft)
                    buffer.ScrollScreenRightByOnePage;
                else if (horizontalScrollBarRightButtonLeft <= x && x <= horizontalScrollBarRightButtonRight)
                    buffer.ScrollScreenHorizontallyBy(1);
            }
        }
    }
    
    
    public void MouseButtonUp(const int x, const int y, const int button)
    {
        if (button == SDL_BUTTON_LEFT)
        {
            if (isDraggingText)
            {
                immutable clickLine   = max(0, min(memoHeightInLines, y / characterHeight));
                immutable clickColumn = max(0, min(windowWidthInCharacters, x / characterWidth));
                
                const location = buffer.LocationAtScreenLine!false(clickLine);
                if (location.Item is buffer.EditorItem)
                    buffer.EditorItem.MoveSelectedText(location.Line, clickColumn + buffer.HorizontalCharacterCountOffset - buffer.EditorItem.Indentation);
            }
            
            Invalidate;
            isDraggingVerticalScrollBar = false;
            isDraggingHorizontalScrollBar = false;
            isDraggingGrip = false;
            isSelecting = false;
            isDraggingText = false;
            buffer.UnFreezeVerticalScrollingValues;
            
            // Has the mouse button been released over the close button?
            if (isFullScreen && 
                isCloseButtonClicked &&
                closeButtonLeft <= x && x < closeButtonRight && 
                closeButtonTop  <= y && y < closeButtonBottom)
            {
                isCloseButtonClicked = false;
                IsFullScreen = false;
            }
        }
    }
    
    public void UpdateMouse(const int x, const int y, const bool leftButtonDown)
    {
        if (x == mouseX && y == mouseY)
            return;
        
        Invalidate;
        Program.AutoCompleteDatabase.HideSuggestionPopup;
        
        mouseX = x;
        mouseY = y;
        
        isMouseOverText = marginWidth < x && x < memoWidth && y < memoHeight;
        isMouseOverGrip = gripButtonLeft < x && x < gripButtonRight - 1 && gripButtonTop < y && y < gripButtonBottom - 1;
        RefreshMouseCursor;
        
        Nullable!ArrowDirection mouseOverScrollBarButton;
        
        // Vertical scroll bar
        if (isVerticalScrollBarVisible && verticalScrollBarLeft <= x && x < verticalScrollBarRight - 1) 
        {
            if (verticalScrollBarTopButtonTop <= y && y <= verticalScrollBarTopButtonBottom)
                mouseOverScrollBarButton = ArrowDirection.Up;
            else if (verticalScrollBarBottomButtonTop <= y && y <= verticalScrollBarBottomButtonBottom)
                mouseOverScrollBarButton = ArrowDirection.Down;
        }
        
        // Horizontal scroll bar
        if (isHorizontalScrollBarVisible && horizontalScrollBarTop <= y && y < horizontalScrollBarBottom - 1) 
        {
            if (horizontalScrollBarLeftButtonLeft < x && x <= horizontalScrollBarLeftButtonRight)
                mouseOverScrollBarButton = ArrowDirection.Left;
            else if (horizontalScrollBarRightButtonLeft <= x && x <= horizontalScrollBarRightButtonRight)
                mouseOverScrollBarButton = ArrowDirection.Right;
        }
        
        if (isFullScreen &&
            closeButtonLeft <= x && x < closeButtonRight && 
            closeButtonTop  <= y && y < closeButtonBottom)
        {
            closeButtonState = leftButtonDown ? ButtonState.Pressed : ButtonState.Rollover;
        }
        else
            closeButtonState = ButtonState.Normal;
        
        static foreach (direction; EnumMembers!ArrowDirection)
            arrowButtonStates[direction] = ButtonState.Normal;
        
        if (!mouseOverScrollBarButton.isNull)
        {
            Invalidate;
            arrowButtonStates[mouseOverScrollBarButton.get] = leftButtonDown ? ButtonState.Pressed : ButtonState.Rollover;
        }
        
        if (isDraggingVerticalScrollBar)
        {
            ScrollScreenToVerticalPixel(y);
        }
        
        if (isDraggingHorizontalScrollBar)
        {
            Invalidate;
            auto newHorizontalScrollBarScrubberLeft = x - horizontalScrollBarDragOffset;
            auto horizontalScrollBarPixelsPerCharacter = horizontalScrollBarSliderSpace / cast(double)buffer.WidthInCharacters;
            auto newCharactersBeforeScreenStart = cast(int)((newHorizontalScrollBarScrubberLeft - iconButtonSize) / horizontalScrollBarPixelsPerCharacter);
            
            buffer.ScrollScreenHorizontallyTo(newCharactersBeforeScreenStart);
        }
        
        if (isDraggingGrip)
        {
            Invalidate;
            int oldOuterWindowWidth;
            int oldOuterWindowHeight;
            SDL_GetWindowSize(window, &oldOuterWindowWidth, &oldOuterWindowHeight);
            
            auto windowPaddingWidth  = oldOuterWindowWidth  - windowWidth;
            auto windowPaddingHeight = oldOuterWindowHeight - windowHeight;
            
            SDL_SetWindowSize(window, x + horizontalGripMouseOffset + windowPaddingWidth, y + verticalGripMouseOffset + windowPaddingHeight);
            InvalidateWindowSizes;
        }
        
        if (isDraggingText)
        {
            immutable clickLine   = max(0, min(memoHeightInLines, y / characterHeight));
            immutable clickColumn = max(0, min(windowWidthInCharacters, x / characterWidth));
            
            const location = buffer.LocationAtScreenLine!false(clickLine);
            
            if (location.Item is buffer.EditorItem)
                buffer.EditorItem.MoveCursorTo!(No.resetSelection)(location.Line, clickColumn + buffer.HorizontalCharacterCountOffset - buffer.EditorItem.Indentation);
        }
        
        if (isSelecting)
        {
            immutable clickLine   = max(0, min(memoHeightInLines, y / characterHeight));
            immutable clickColumn = max(0, min(windowWidthInCharacters, (x - marginWidth) / characterWidth));
            
            if (x < 0)
            {
                Invalidate;
                if (selectionDragScrollHorizontalVelocity > 0)
                {
                    selectionDragScrollHorizontalAccumulator = 0.0;
                    selectionDragScrollHorizontalVelocity = -selectionDragScrollAcceleration;
                }
                else
                    selectionDragScrollHorizontalVelocity -= selectionDragScrollAcceleration;
                
                selectionDragScrollHorizontalAccumulator += selectionDragScrollHorizontalVelocity;
                
                auto offset = cast(int)selectionDragScrollHorizontalAccumulator;
                buffer.ScrollScreenHorizontallyBy(offset);
                selectionDragScrollHorizontalAccumulator -= offset;
            }
            else if (x > windowWidth)
            {
                Invalidate;
                if (selectionDragScrollHorizontalVelocity < 0)
                {
                    selectionDragScrollHorizontalAccumulator = 0.0;
                    selectionDragScrollHorizontalVelocity = selectionDragScrollAcceleration;
                }
                else
                    selectionDragScrollHorizontalVelocity += selectionDragScrollAcceleration;
                
                selectionDragScrollHorizontalAccumulator += selectionDragScrollHorizontalVelocity;
                
                auto offset = cast(int)selectionDragScrollHorizontalAccumulator;
                buffer.ScrollScreenHorizontallyBy(offset);
                selectionDragScrollHorizontalAccumulator -= offset;
            }
            else
            {
                selectionDragScrollHorizontalAccumulator = 0.0;
                selectionDragScrollHorizontalVelocity = 0.0;
            }
            
            if (y < 0)
            {
                Invalidate;
                if (selectionDragScrollVerticalVelocity > 0)
                {
                    selectionDragScrollVerticalAccumulator = 0.0;
                    selectionDragScrollVerticalVelocity = -selectionDragScrollAcceleration;
                }
                else
                    selectionDragScrollVerticalVelocity -= selectionDragScrollAcceleration;
                
                selectionDragScrollVerticalAccumulator += selectionDragScrollVerticalVelocity;
                
                auto offset = cast(int)selectionDragScrollVerticalAccumulator;
                buffer.ScrollScreenVerticallyBy(offset);
                selectionDragScrollVerticalAccumulator -= offset;
            }
            else if (y > windowHeight)
            {
                Invalidate;
                if (selectionDragScrollVerticalVelocity < 0)
                {
                    selectionDragScrollVerticalAccumulator = 0.0;
                    selectionDragScrollVerticalVelocity = selectionDragScrollAcceleration;
                }
                else
                    selectionDragScrollVerticalVelocity += selectionDragScrollAcceleration;
                
                selectionDragScrollVerticalAccumulator += selectionDragScrollVerticalVelocity;
                
                auto offset = cast(int)selectionDragScrollVerticalAccumulator;
                buffer.ScrollScreenVerticallyBy(offset);
                selectionDragScrollVerticalAccumulator -= offset;
            }
            else
            {
                selectionDragScrollVerticalAccumulator = 0.0;
                selectionDragScrollVerticalVelocity = 0.0;
            }
            
            buffer.SetSelectionEndScreen(clickLine, clickColumn, clickColumn + 1);
        }
    }
    
    private void ScrollScreenToVerticalPixel(const int y)
    {
        Invalidate;
        immutable newVerticalScrollBarScrubberTop = y - verticalScrollBarDragOffset;
        immutable verticalScrollBarPixelsPerLine = verticalScrollBarSliderSpace / cast(double)buffer.TotalLines;
        immutable newTotalLinesAboveScreenStart = cast(int)((newVerticalScrollBarScrubberTop - iconButtonSize) / verticalScrollBarPixelsPerLine);
        
        if (newVerticalScrollBarScrubberTop >= memoHeight - 2 * iconButtonSize)
            buffer.UnFreezeVerticalScrollingValues;
        else
            buffer.FreezeVerticalScrollingValues;
        
        buffer.ScrollScreenVerticallyTo(newTotalLinesAboveScreenStart);
    }
    
    public void SetWindowSize(
        int left, 
        int top, 
        int width, 
        int height)
    {
        SDL_SetWindowPosition(window, left, top);
        SDL_SetWindowSize(window, width, height);
        InvalidateWindowSizes;
    }
    
    public void MaximizeWindow()
    {
        SDL_MaximizeWindow(window);
        InvalidateWindowSizes;
    }
    
    public void MinimizeWindow()
    {
        SDL_MinimizeWindow(window);
        InvalidateWindowSizes;
    }
    
    public void RestoreWindow()
    {
        SDL_RestoreWindow(window);
        InvalidateWindowSizes;
    }
    
    public void SelectWholeWordAt(const int mouseX, const int mouseY)
    {
        if (mouseX >= memoWidth || mouseY >= memoHeight)
            return;
        
        buffer.SelectWholeWordAt(mouseY / characterHeight, mouseX / characterWidth);
        isSelecting = true;
        isDraggingText = false;
    }
    
    private auto isMouseOverText = false;
    private auto isMouseOverGrip = false;
    
    public void RefreshMouseCursor()
    {
        void SetMouseCursor(SDL_Cursor* newMouseCursor)
        {
            if (activeMouseCursor == newMouseCursor)
                return;
            
            activeMouseCursor = newMouseCursor;
            SDL_SetCursor(newMouseCursor);
        }
        
        if (isMouseOverGrip)
            SetMouseCursor(gripSizingMouseCursor);
        else if (isMouseOverText)
            SetMouseCursor(iBeamMouseCursor);
        else
            SetMouseCursor(defaultMouseCursor);
    }
    
    private auto isShowingStars = false;
    private auto starsCount = 100;
    public auto StarsCount() const @nogc nothrow { return starsCount; }
    public void StarsCount(int value) 
    { 
        starsCount = value; 
        ResetStars;
    }
    
    private Star[] stars;
    
    private struct Star
    {
        double x;
        double y;
        double speedInPixelsPerMillisecond;
        SDL_Color color;
        
        public void Reset(bool isStartingAtBottom)(int width, int height)
        {
            import std.random : uniform;
            x = uniform(0, width);
            
            static if (isStartingAtBottom)
            {
                y = height;
            }
            else
            {
                speedInPixelsPerMillisecond = (pow(2, uniform(1.0, 8.0)) - 1) / 255;
                y = uniform(0, height);
            }
            
            ubyte r = 0;
            ubyte g = 0;
            ubyte b = 0;
            ubyte a = uniform(ubyte(0), ubyte(128));
            
            final switch (uniform(0, 3))
            {
                case 0:
                    // Red dwarf, red giant, or red shifted whatever star.
                    r = uniform(ubyte(0), ubyte(255));
                    break;
                case 1:
                    // A whatever star.
                    r = uniform(ubyte(196), ubyte(255));
                    g = uniform(ubyte(196), ubyte(255));
                    b = uniform(ubyte(196), ubyte(255));
                    break;
                case 2:
                    // Blue giant or blue-shifted whatever star.
                    r = uniform(ubyte(127), ubyte(255));
                    g = r;
                    b = 255;
                    
                    break;
            }
            
            color = SDL_Color(r, g, b, a);
        }
        
        public void Check(int width, int height)
        {
            if (y <= 0.0)
                Reset!true(width, height);
        }
        
        public void Advance(double lastFrameDurationInMilliseconds)
        {
            y -= speedInPixelsPerMillisecond * lastFrameDurationInMilliseconds;
        }
    }
    
    private void ResetStars()
    {
        if (!isShowingStars)
            return;
        
        if (stars.length != starsCount)
            stars = new Star[starsCount];
        
        foreach (ref star; stars)
            star.Reset!false(windowWidth, windowHeight);    
    }
    
    public auto LookupNamedColor(Flag!"isOutline" isOutline = No.isOutline)(NamedColor color, const int timeInMilliseconds) @nogc nothrow
    {
        final switch (color) with (NamedColor)
        {
            static if (isOutline)
            {
                case Normal:           return normalTextOutline.color;
                case Identifier:       return identifierTextOutline.color;
                case QuotedIdentifier: return quotedIdentifierTextOutline.color;
                case Disabled:         return disabledTextOutline.color;
                case Popup:            return popupTextOutline.color;
                case HeaderUnderline:  return headerUnderLine.color;
                case Comment:          return commentTextOutline.color;
                case Function:         return functionTextOutline.color;
                case Package:          return packageTextOutline.color;
                case DatabaseLink:     return databaseLinkTextOutline.color;
                case String:           return stringTextOutline.color;
                case Keyword:          return keywordTextOutline.color;
                case Good:             return goodTextOutline.color;
                case Warning:          return warningTextOutline.color;
                case Error:            return errorTextOutline.color;
                case Alert:            return alertTextOutline.color;
                case Danger:           return dangerTextOutline.color;
            }
            else
            {
                case Normal:           return normalText.color;
                case Identifier:       return identifierText.color;
                case QuotedIdentifier: return quotedIdentifierText.color;
                case Disabled:         return disabledText.color;
                case Popup:            return popupText.color;
                case HeaderUnderline:  return headerUnderLine.color;
                case Comment:          return commentText.color;
                case Function:         return functionText.color;
                case Package:          return packageText.color;
                case DatabaseLink:     return databaseLinkText.color;
                case String:           return stringText.color;
                case Keyword:          return keywordText.color;
                case Good:             return goodText.color;
                case Warning:          return warningText.color;
                case Error:            return errorText.color;
                case Alert:            return alertText.color;
                case Danger:  
                    
                    if (timeInMilliseconds < 0)
                        return alertText.color;
                    else
                    {
                        Invalidate;
                        
                        auto f = timeInMilliseconds % 512;
                        
                        double t;
                        if (f < 256)
                            t = f / 256.0;
                        else
                            t = 1.0 - (f - 256) / 256.0;
                        
                        return LinearInterpolate(alertText.color, dangerTextGlow.color, t);
                    }
            }
        }
    }
    
    public void SetTheme(InterfaceTheme theme) 
    {
        Invalidate;
        isOutliningNormalText = false;
        isShowingStars = false;
        IsShowingScanLines = false;
        backgroundTexture = BackgroundTexture.None;
        
        final switch (theme) with (InterfaceTheme)
        {
            case SqlPlus:
                
                background.color                  = white;
                normalText.color                  = SDL_Color( 31,  31,  31, 255);
                identifierText.color              = SDL_Color(  0,   0, 127, 255);
                quotedIdentifierText.color        = SDL_Color( 63,  63,  63, 255);
                commentText.color                 = SDL_Color(  0, 127,   0, 255);
                functionText.color                = SDL_Color(127, 127,  63, 255);
                packageText.color                 = SDL_Color(  0,   0, 127, 255);
                databaseLinkText.color            = SDL_Color(127,   0, 127, 255);
                stringText.color                  = SDL_Color( 63, 127, 127, 255);
                keywordText.color                 = SDL_Color(  0, 127, 255, 255);
                goodText.color                    = SDL_Color(  0, 196,   0, 255);
                warningText.color                 = SDL_Color(255, 255,   0, 255);
                errorText.color                   = SDL_Color(255,   0,   0, 255);
                alertText.color                   = SDL_Color(255,   0,   0, 255);
                selection.color                   = SDL_Color(168, 205, 241, 127);
                headerBackground.color            = SDL_Color(  0,   0,   0,  31);
                headerUnderLine.color             = SDL_Color(  0,   0,   0, 196);
                cursor.color                      = black;
                scrollBarBackground.color         = SDL_Color(  0,   0,   0,  31);
                scrollBarButton.color             = SDL_Color(  0,   0,   0,  96);
                popupBackground.color             = SDL_Color(240, 240, 240, 225);
                popupDropShadow.color             = SDL_Color(  0,   0,   0, 127);
                popupBorder.color                 = black;
                
                normalTextOutline.color           = white;
                identifierTextOutline.color       = white;
                quotedIdentifierTextOutline.color = white;
                commentTextOutline.color          = white;
                functionTextOutline.color         = white;
                packageTextOutline.color          = white;
                databaseLinkTextOutline.color     = white;
                stringTextOutline.color           = white;
                keywordTextOutline.color          = white;
                goodTextOutline.color             = white;
                warningTextOutline.color          = black;
                errorTextOutline.color            = white;
                alertTextOutline.color            = white;
                dangerTextOutline.color           = SDL_Color(255,   0,   0, 255);                
                
                break;
                
            case Sky:
                
                background.color                  = SDL_Color(210, 230, 235, 255);
                normalText.color                  = SDL_Color( 31,  31,  31, 255);
                identifierText.color              = SDL_Color(  0,   0, 127, 255);
                quotedIdentifierText.color        = SDL_Color( 63,  63,  63, 255);
                commentText.color                 = SDL_Color(  0, 127,   0, 255);
                functionText.color                = SDL_Color(127, 127,  63, 255);
                packageText.color                 = SDL_Color(  0,   0, 127, 255);
                databaseLinkText.color            = SDL_Color(127,   0, 127, 255);
                stringText.color                  = SDL_Color( 63, 127, 127, 255);
                keywordText.color                 = SDL_Color(  0, 127, 255, 255);
                goodText.color                    = SDL_Color(  0, 255,   0, 255);
                warningText.color                 = SDL_Color(255, 255,   0, 255);
                errorText.color                   = SDL_Color(255,   0,   0, 255);
                alertText.color                   = SDL_Color(255,   0,   0, 255);
                selection.color                   = SDL_Color(168, 205, 241, 127);
                headerBackground.color            = SDL_Color(  0,   0,   0,  31);
                headerUnderLine.color             = SDL_Color(  0,   0,   0, 196);
                cursor.color                      = black;
                scrollBarBackground.color         = SDL_Color(  0,   0,   0,  31);
                scrollBarButton.color             = SDL_Color(  0,   0,   0,  96);
                popupBackground.color             = SDL_Color(255, 255, 255, 225);
                popupDropShadow.color             = SDL_Color(  0,   0,   0,  31);
                popupBorder.color                 = white;
                
                normalTextOutline.color           = SDL_Color(255, 255, 255, 127);
                identifierTextOutline.color       = white;
                quotedIdentifierTextOutline.color = white;
                commentTextOutline.color          = white;
                functionTextOutline.color         = white;
                packageTextOutline.color          = white;
                databaseLinkTextOutline.color     = white;
                stringTextOutline.color           = white;
                keywordTextOutline.color          = white;
                goodTextOutline.color             = black;
                warningTextOutline.color          = black;
                errorTextOutline.color            = white;
                alertTextOutline.color            = white;
                dangerTextOutline.color           = SDL_Color(255,   0,   0, 255);                
                
                break;
                
            case Space:
                
                isShowingStars = true;
                background.color                  = black;
                normalText.color                  = SDL_Color(196, 196, 196, 255);
                identifierText.color              = white;
                quotedIdentifierText.color        = SDL_Color(127, 127, 127, 255);
                commentText.color                 = SDL_Color(  0, 127,   0, 255);
                functionText.color                = SDL_Color(127, 127,  63, 255);
                packageText.color                 = SDL_Color(196, 196, 255, 255);
                databaseLinkText.color            = SDL_Color(225,   0, 225, 255);
                stringText.color                  = SDL_Color( 63, 196, 196, 255);
                keywordText.color                 = SDL_Color(  0, 127, 255, 255);
                goodText.color                    = SDL_Color(  0, 196,   0, 255);
                warningText.color                 = SDL_Color(255, 255,   0, 255);
                errorText.color                   = SDL_Color(255,   0,   0, 255);
                alertText.color                   = SDL_Color(255,   0,   0, 255);
                selection.color                   = SDL_Color(168, 205, 241, 127);
                headerBackground.color            = SDL_Color(255, 225, 127,  31);
                headerUnderLine.color             = SDL_Color(255, 225, 127, 196);
                cursor.color                      = SDL_Color(255, 225, 127, 255);
                scrollBarBackground.color         = SDL_Color(255, 255, 255,  31);
                scrollBarButton.color             = SDL_Color(255, 255, 255,  96);
                popupBackground.color             = SDL_Color( 63,  63,  63, 225);
                popupDropShadow.color             = SDL_Color(  0,   0,   0, 127);
                popupBorder.color                 = SDL_Color(127, 127, 127, 255);
                
                normalTextOutline.color           = background.color;
                identifierTextOutline.color       = black;
                quotedIdentifierTextOutline.color = black;
                commentTextOutline.color          = black;
                functionTextOutline.color         = black;
                packageTextOutline.color          = black;
                databaseLinkTextOutline.color     = black;
                stringTextOutline.color           = black;
                keywordTextOutline.color          = black;
                goodTextOutline.color             = black;
                warningTextOutline.color          = black;
                errorTextOutline.color            = black;
                alertTextOutline.color            = black;
                dangerTextOutline.color           = SDL_Color(255,   0,   0, 255);
                break;
            
            case Dark:
                
                isOutliningNormalText = true;
                backgroundTexture = BackgroundTexture.NoiseFine;
                background.color                  = SDL_Color( 63,  63,  63, 255);
                normalText.color                  = SDL_Color(196, 196, 196, 255);
                identifierText.color              = white;
                quotedIdentifierText.color        = SDL_Color(196, 196, 196, 255);
                commentText.color                 = SDL_Color(  0, 196,   0, 255);
                functionText.color                = SDL_Color(127, 127,  63, 255);
                packageText.color                 = SDL_Color(196, 196, 255, 255);
                databaseLinkText.color            = SDL_Color(255, 127, 255, 255);
                stringText.color                  = SDL_Color( 63, 196, 196, 255);
                keywordText.color                 = SDL_Color(  0, 196, 255, 255);
                goodText.color                    = SDL_Color(  0, 196,   0, 255);
                warningText.color                 = SDL_Color(255, 255,   0, 255);
                errorText.color                   = SDL_Color(255,   0,   0, 255);
                alertText.color                   = SDL_Color(255,   0,   0, 255);
                selection.color                   = SDL_Color(192, 192, 192, 127);
                headerBackground.color            = SDL_Color(255, 225, 127,  31);
                headerUnderLine.color             = SDL_Color(255, 225, 127, 196);
                cursor.color                      = SDL_Color(255, 225, 127, 255);
                scrollBarBackground.color         = SDL_Color(255, 255, 255,  31);
                scrollBarButton.color             = SDL_Color(255, 255, 255,  96);
                popupBackground.color             = SDL_Color(  0,   0,   0, 225);
                popupDropShadow.color             = SDL_Color(  0,   0,   0,  63);
                popupBorder.color                 = black;
                
                normalTextOutline.color           = black;
                identifierTextOutline.color       = black;
                quotedIdentifierTextOutline.color = black;
                commentTextOutline.color          = black;
                functionTextOutline.color         = black;
                packageTextOutline.color          = black;
                databaseLinkTextOutline.color     = black;
                stringTextOutline.color           = black;
                keywordTextOutline.color          = black;
                goodTextOutline.color             = black;
                warningTextOutline.color          = black;
                errorTextOutline.color            = black;
                alertTextOutline.color            = black;
                dangerTextOutline.color           = SDL_Color(255,   0,   0, 255);
                
                break;
                
            case SpaceTerminal:
                
                isShowingStars = true;
                goto case Terminal;
            
            case Terminal:
                
                isOutliningNormalText = true;
                IsShowingScanLines = true;
                background.color                  = black;
                normalText.color                  = SDL_Color(  0, 196,   0, 255);
                identifierText.color              = SDL_Color(  0, 255,   0, 255);
                quotedIdentifierText.color        = SDL_Color(196, 255, 196, 255);
                commentText.color                 = SDL_Color(  0, 127,   0, 255);
                functionText.color                = SDL_Color(127, 127,  63, 255);
                packageText.color                 = SDL_Color(196, 255, 196, 255);
                databaseLinkText.color            = SDL_Color(255,   0, 255, 255);
                stringText.color                  = SDL_Color( 96, 163, 163, 255);
                keywordText.color                 = SDL_Color(  0, 127, 255, 255);
                goodText.color                    = SDL_Color(  0, 255,   0, 255);
                warningText.color                 = SDL_Color(255, 255,   0, 255);
                errorText.color                   = SDL_Color(255,   0,   0, 255);
                alertText.color                   = SDL_Color(255,   0,   0, 255);
                selection.color                   = SDL_Color(168, 205, 241, 127);
                headerBackground.color            = SDL_Color(  0, 255,   0,  31);
                headerUnderLine.color             = SDL_Color(  0, 255,   0, 196);
                cursor.color                      = SDL_Color(  0, 255,   0, 255);
                scrollBarBackground.color         = SDL_Color(  0, 255,   0,  31);
                scrollBarButton.color             = SDL_Color(  0, 255,   0,  96);
                popupBackground.color             = SDL_Color(  0,   0,   0, 225);
                popupDropShadow.color             = SDL_Color(  0,   0,   0, 127);
                popupBorder.color                 = SDL_Color(  0,  63,   0, 255);
                
                normalTextOutline.color           = SDL_Color(  0,  92,   0, 255);
                identifierTextOutline.color       = SDL_Color(  0, 255,   0, 255);
                quotedIdentifierTextOutline.color = white;
                commentTextOutline.color          = black;
                functionTextOutline.color         = black;
                packageTextOutline.color          = black;
                databaseLinkTextOutline.color     = black;
                stringTextOutline.color           = black;
                keywordTextOutline.color          = black;
                goodTextOutline.color             = SDL_Color(  0, 255,   0, 255);
                warningTextOutline.color          = black;
                errorTextOutline.color            = black;
                alertTextOutline.color            = black;
                dangerTextOutline.color           = SDL_Color(255,   0,   0, 255);

                break;
                
            case Pink:
                
                isOutliningNormalText = true;
                backgroundTexture = BackgroundTexture.Hash;
                background.color                  = SDL_Color(255, 196, 225, 255);
                normalText.color                  = SDL_Color( 15,  15,  15, 255);
                identifierText.color              = SDL_Color(  0,   0, 127, 255);
                quotedIdentifierText.color        = SDL_Color( 63,  63,  63, 255);
                commentText.color                 = SDL_Color(  0, 127,   0, 255);
                functionText.color                = SDL_Color(127, 127,  63, 255);
                packageText.color                 = SDL_Color(  0,   0, 127, 255);
                databaseLinkText.color            = SDL_Color(225,   0, 225, 255);
                stringText.color                  = SDL_Color( 63, 127, 127, 255);
                keywordText.color                 = SDL_Color(  0, 127, 255, 255);
                goodText.color                    = SDL_Color(  0, 255,   0, 255);
                warningText.color                 = SDL_Color(255, 255,   0, 255);
                errorText.color                   = SDL_Color(255,   0,   0, 255);
                alertText.color                   = SDL_Color(255,   0,   0, 255);
                selection.color                   = SDL_Color(255,  63, 196, 127);
                headerBackground.color            = SDL_Color(255,   0, 255,  31);
                headerUnderLine.color             = SDL_Color(255,   0, 255, 196);
                cursor.color                      = SDL_Color(255,   0, 255, 255);
                scrollBarBackground.color         = SDL_Color(255,   0, 255,  31);
                scrollBarButton.color             = SDL_Color(255,   0, 255,  96);
                popupBackground.color             = SDL_Color(255, 255, 255, 225);
                popupDropShadow.color             = SDL_Color(  0,   0,   0,  63);
                popupBorder.color                 = black;
                
                normalTextOutline.color           = background.color;
                identifierTextOutline.color       = white;
                quotedIdentifierTextOutline.color = white;
                commentTextOutline.color          = white;
                functionTextOutline.color         = white;
                packageTextOutline.color          = white;
                databaseLinkTextOutline.color     = white;
                stringTextOutline.color           = white;
                keywordTextOutline.color          = white;
                goodTextOutline.color             = black;
                warningTextOutline.color          = black;
                errorTextOutline.color            = white;
                alertTextOutline.color            = white;
                dangerTextOutline.color           = SDL_Color(255,   0,   0, 255);                
                break;
                
            case Lilac:
                
                isOutliningNormalText = true;
                backgroundTexture = BackgroundTexture.Swirl;
                background.color                  = SDL_Color(127, 127, 196, 255);
                normalText.color                  = white;
                identifierText.color              = SDL_Color(255, 255, 205, 255);
                quotedIdentifierText.color        = SDL_Color(196, 196, 196, 255);
                commentText.color                 = SDL_Color( 63, 255,  63, 255);
                functionText.color                = SDL_Color(196, 196, 127, 255);
                packageText.color                 = SDL_Color(  0,   0, 127, 255);
                databaseLinkText.color            = SDL_Color(255, 127, 255, 255);
                stringText.color                  = SDL_Color(127, 255, 255, 255);
                keywordText.color                 = SDL_Color( 63, 192, 255, 255);
                goodText.color                    = SDL_Color(  0, 255,   0, 255);
                warningText.color                 = SDL_Color(255, 255,   0, 255);
                errorText.color                   = SDL_Color(255,  63,   0, 255);
                alertText.color                   = SDL_Color(255,  63,   0, 255);
                selection.color                   = SDL_Color( 63,  63, 196, 127);
                headerBackground.color            = SDL_Color( 63,   0,  96,  31);
                headerUnderLine.color             = SDL_Color( 63,   0,  96, 196);
                cursor.color                      = SDL_Color( 63,   0,  96, 255);
                scrollBarBackground.color         = SDL_Color( 63,   0,  96,  31);
                scrollBarButton.color             = SDL_Color( 63,   0,  96,  96);
                popupBackground.color             = SDL_Color(  0,   0,   0, 225);
                popupDropShadow.color             = SDL_Color(  0,   0,   0,  63);
                popupBorder.color                 = black;
                
                normalTextOutline.color           = black;
                identifierTextOutline.color       = black;
                quotedIdentifierTextOutline.color = black;
                commentTextOutline.color          = black;
                functionTextOutline.color         = black;
                packageTextOutline.color          = white;
                databaseLinkTextOutline.color     = black;
                stringTextOutline.color           = black;
                keywordTextOutline.color          = black;
                goodTextOutline.color             = black;
                warningTextOutline.color          = black;
                errorTextOutline.color            = black;
                alertTextOutline.color            = black;
                dangerTextOutline.color           = SDL_Color(255,   0,   0, 255);
                break;
                
            case Production:
                
                isOutliningNormalText = true;
                backgroundTexture = BackgroundTexture.HorizontalBrush;
                background.color                  = SDL_Color( 63,   0,   0, 255);
                normalText.color                  = SDL_Color(225, 225, 225, 255);
                identifierText.color              = white;
                quotedIdentifierText.color        = SDL_Color(127, 127, 127, 255);
                commentText.color                 = SDL_Color(  0, 163,   0, 255);
                functionText.color                = SDL_Color(127, 127,  63, 255);
                packageText.color                 = SDL_Color(196, 196, 255, 255);
                databaseLinkText.color            = SDL_Color(255, 127, 255, 255);
                stringText.color                  = SDL_Color( 96, 163, 163, 255);
                keywordText.color                 = SDL_Color(  0, 127, 255, 255);
                goodText.color                    = SDL_Color(  0, 196,   0, 255);
                warningText.color                 = SDL_Color(255, 255,   0, 255);
                errorText.color                   = SDL_Color(255,   0,   0, 255);
                alertText.color                   = SDL_Color(255,   0,   0, 255);
                selection.color                   = SDL_Color(127,   0,   0, 127);
                headerBackground.color            = SDL_Color(255,   0,   0,  31);
                headerUnderLine.color             = SDL_Color(255,   0,   0, 196);
                cursor.color                      = SDL_Color(255,   0,   0, 255);
                scrollBarBackground.color         = SDL_Color(255,   0,   0,  31);
                scrollBarButton.color             = SDL_Color(255,   0,   0,  96);
                popupBackground.color             = SDL_Color(  0,   0,   0, 225);
                popupDropShadow.color             = SDL_Color(  0,   0,   0, 127);
                popupBorder.color                 = SDL_Color( 31,   0,   0, 255);
                
                normalTextOutline.color           = black;
                identifierTextOutline.color       = SDL_Color(255, 255, 255, 127);
                quotedIdentifierTextOutline.color = black;
                commentTextOutline.color          = black;
                functionTextOutline.color         = black;
                packageTextOutline.color          = black;
                databaseLinkTextOutline.color     = black;
                stringTextOutline.color           = black;
                keywordTextOutline.color          = black;
                goodTextOutline.color             = black;
                warningTextOutline.color          = black;
                errorTextOutline.color            = black;
                alertTextOutline.color            = black;
                dangerTextOutline.color           = SDL_Color(255,   0,   0, 255);
                break;
        }
        
        dangerTextGlow.color      = white;
        popupText.color           = normalText.color;
        popupTextOutline.color    = AdjustOpacity(popupBackground.color, 255);
        
        scanLine.color            = AdjustOpacity(background.color,  96);
        disabledText.color        = AdjustOpacity(normalText.color, 127);
        disabledTextOutline.color = background.color;
        
        if (isShowingStars)
            ResetStars;
    }
}

