module program; //                                                        ____      ____  
               //                                                         \   \    /   /  
              // _________ _________    ___       _________ ___            \   \  /   /   
             // / _______//  ___   /   /  /      /  ___   //  /             \   \/   /    
            //  \  \     /  /  /  /   /  /      /  /__/  //  /___   ___  ____\______/___  
           //    \  \   /  /  /  /   /  /      /  ______//  //  /  /  / / _____________/  
          // _____\  \ /  /__/  /__ /  /_____ /  /      /  //  /__/  /__\ \  /      \     
         // /________//___________//________//__/      /__//________//____/ /   /\   \    
        // ________________________________________________________________/   /  \   \   
       // /___________________________________________________________________/    \___\  

enum staticSDL = true;
import std.algorithm : max, min, startsWith, canFind;
import std.conv : to;
import std.format : format;
import std.functional : toDelegate;
import std.string : splitLines, strip, toUpper, toLower;
import std.sumtype : match;
import std.typecons : Flag, Yes, No, Tuple, Nullable;
import std.utf : byDchar;

import core.runtime;
import core.sys.windows.windows;
import core.sys.windows.winuser;

import bindbc.sdl;

public import common;
public import errors;
public import screen;
public import buffer;
public import buffer_item;
public import editor;
public import keyboard;
public import interpreter;
public import database;
public import commands;
public import settings;
public import autocomplete;
public import syntax;
public import computes;

debug public import screen : DebugText;

public abstract final class Program
{
    private static interpreter.Settings _settings;
    public static Settings() @nogc nothrow => _settings;
    
    private static database.DatabaseManager _database;
    public static Database() @nogc nothrow => _database;
    
    private static autocomplete.AutoCompleteManager _autoCompleteDatabase;
    public static AutoCompleteDatabase() @nogc nothrow => _autoCompleteDatabase;
    
    private static interpreter.Interpreter _interpreter;
    public static Interpreter() @nogc nothrow => _interpreter;
    
    private static editor.EditorBufferItem _editor;
    public static Editor() @nogc nothrow => _editor;
    
    private static buffer.Buffer _buffer;
    public static Buffer() @nogc nothrow => _buffer;
    
    private static screen.Screen _screen;
    public static Screen() @nogc nothrow => _screen;
    
    private static syntax.Syntax _syntax;
    public static Syntax() @nogc nothrow => _syntax;
    
    private static auto isRunning = true;
    public static void Exit() @nogc nothrow { isRunning = false; }
    
    private static auto currentFrameCount = 0;
    private static auto accumulatedMilliseconds = 0;
    
    private static auto framesPerSecond = 0;
    public static auto FramesPerSecond() @nogc nothrow { return framesPerSecond; }
    
    private static Syntax.CarryOverHighlightingState currentHighlightingState;
    private static resetHighlightingState() { currentHighlightingState = Syntax.CarryOverHighlightingState(); }
    
    // This will be displayed in the bottom right hand corner.  This is separate to DebugText so it can be used in release builds.
    public static StringReference diagnosticInformation;
    
    private static void ProcessMainDatabaseThreadResult(InstructionResult result)
    {
        Program.Screen.Invalidate;
        
        result.match!(
            (OracleColumns  oracleColumns) => Program.Buffer.AddColumns(oracleColumns), 
            (OracleRecord   oracleRecord ) => Program.Buffer.AddRecord(oracleRecord), 
            (SqlSuccess     sqlSuccess   ) { Program.Buffer.AddSqlSuccess(sqlSuccess);  resetHighlightingState; }, 
            (SqlError       sqlError     ) { Program.Buffer.AddSqlError(sqlError);      resetHighlightingState; }, 
            (StatusFlags    statusFlags  ) { }, 
            (MessageResult  messageResult)
            {
                final switch (messageResult.Type) with (MessageResultType)
                {
                    case Information:
                        
                        if (messageResult.IsSyntaxHighlightable)
                            Program.Buffer.AddFormattedText(Syntax.Highlight(messageResult.Message, currentHighlightingState));
                        else
                            Program.Buffer.AddText(messageResult.Message);
                        break;
                    
                    case Warning:
                        
                        if (Program.Settings.IsShowingSqlWarnings)
                            Program.Buffer.AddText(messageResult.Message, NamedColor.Warning);
                        
                        break;
                    
                    case NlsDateFormat:
                        import oracle : threadLocalNlsDateFormat;
                        threadLocalNlsDateFormat = messageResult.Message;
                        break;
                    
                    case Connected:
                        Program.Screen.SetTitle(messageResult.Message);
                        Program.AutoCompleteDatabase.Connect(Program.Database.connectionDetails);
                        break;
                        
                    case Disconnected:
                        Program.Buffer.QueryComplete;
                        Program.Screen.SetTitle("Disconnected");
                        Program.Buffer.AddText(messageResult.Message);
                        break;
                    
                    case Cancelled:
                        auto activeTableItem = Program.Buffer.ActiveTableItem;
                        if (activeTableItem is null || activeTableItem.IsQueryComplete)
                            Program.Buffer.AddText("Cancelled");
                        else
                        {
                            immutable rowCount = activeTableItem.TotalRecordCount;
                            Program.Buffer.QueryComplete;
                            Program.Buffer.AddText("Cancelled with " ~ format("%,d", rowCount) ~ " record" ~ (rowCount == 1 ? "" : "s") ~ " returned.");
                        }
                        
                        break;
                    
                    case PasswordExpired:
                        Program.Buffer.QueryComplete;
                        Program.Buffer.AddText("Password expired");
                        Program.Interpreter.BeginConnection!(Interpreter.ConnectionPrompt.NewPasswordFirstEntry)(Program.Database.connectionDetails);
                        break;
                    
                    case Failure:
                        Program.Buffer.QueryComplete;
                        Program.Buffer.AddText(messageResult.Message);
                        break;
                        
                    case ThreadFailure:
                        throw new NonRecoverableException(messageResult.Message);
                }
            }
        );
    }
    
    private static void processInput(dchar character, Action action)
    {
        enum searchMode { None, Forward, Backward }
        
        void activateEditor(searchMode searching = searchMode.None)()
        {
            Program.Screen.Invalidate;
            
            if (Program.Editor.CurrentFindText.length > 0)
            {
                Program.Buffer.SelectionType = Buffer.SelectionTypes.EditorAndBuffer;
                
                static if (searching == searchMode.Forward)
                    Program.Buffer.FindNext;
                else static if (searching == searchMode.Backward)
                    Program.Buffer.FindPrevious;
            }
            else
            {
                Program.Buffer.SelectionType = Buffer.SelectionTypes.EditorOnly;
                Program.Buffer.ScrollScreenToBottom;
            }
        }
        
        final switch (action)
        {
            case Action.Nothing:
                break;
            
            case Action.Cancel:
                if (Program.AutoCompleteDatabase.HideSuggestionPopup)
                    break;
                
                if (Program.Editor.CurrentFindText.length > 0)
                {
                    Program.Editor.Clear;
                    Program.Editor.ClearAcceptPrompt;
                    break;
                }
                
                if (Program.Editor.Text.length > 0)
                {
                    Program.Editor.Clear;
                    break;
                }
                
                if (Program.Interpreter.ClearAcceptPrompt)
                    break;
                
                Program.Interpreter.Cancel;
                
                break;
                
            case Action.MoveScreenUp:
                Program.Buffer.ScrollScreenVerticallyBy(-1);
                break;
                
            case Action.MoveScreenDown:
                Program.Buffer.ScrollScreenVerticallyBy(1);
                break;
                
            case Action.MoveScreenLeft:
                if (!Program.Screen.queuedCommands.moveHorizontallyBy(-1) && 
                    !Program.Screen.rollover.moveHorizontallyBy(-1))
                    Program.Buffer.ScrollScreenHorizontallyBy(-1);
                break;
                
            case Action.MoveScreenRight:
                if (!Program.Screen.queuedCommands.moveHorizontallyBy(1) && 
                    !Program.Screen.rollover.moveHorizontallyBy(1))
                    Program.Buffer.ScrollScreenHorizontallyBy(1);
                break;
                
            case Action.MoveCursorUp:
                if (Program.Screen.queuedCommands.moveVerticallyBy(-1))
                    break;
                
                if (Program.Screen.rollover.moveVerticallyBy(-1))
                    break;
                
                if (!Program.Screen.isEditorVisible)
                {
                    Program.Buffer.ScrollScreenVerticallyBy(-1);
                    break;
                }
                
                if (Program.Editor.isMultiLine)
                {
                    Program.Editor.MoveCursorUp;
                    Program.Buffer.ScrollScreenToBottom;
                    break;
                }
                
                if (Program.AutoCompleteDatabase.SuggestionPopupVisible)
                {
                    Program.AutoCompleteDatabase.MoveSuggestionUp;
                    break;
                }
                
                Program.Editor.PreviousCommandInHistory;
                break;
                
            case Action.MoveCursorDown:
                if (Program.Screen.queuedCommands.moveVerticallyBy(1))
                    break;
                
                if (Program.Screen.rollover.moveVerticallyBy(1))
                    break;
                
                if (!Program.Screen.isEditorVisible)
                {
                    Program.Buffer.ScrollScreenVerticallyBy(1);
                    break;
                }
                
                if (Program.Editor.isMultiLine)
                {
                    Program.Editor.MoveCursorDown;
                    Program.Buffer.ScrollScreenToBottom;
                    break;
                }
                
                if (Program.AutoCompleteDatabase.SuggestionPopupVisible)
                {
                    Program.AutoCompleteDatabase.MoveSuggestionDown;
                    break;
                }
                
                Program.Editor.NextCommandInHistory;
                break;
                
            case Action.MoveCursorLeft:
                if (Program.Screen.queuedCommands.moveHorizontallyBy(-1))
                    break;
                    
                if (Program.Screen.rollover.moveHorizontallyBy(-1))
                    break;
                    
                if (!Program.Screen.isEditorVisible)
                {
                    Program.Buffer.ScrollScreenHorizontallyBy(-1);
                    break;
                }
                
                Program.Editor.MoveCursorLeft;
                Program.Buffer.ScrollScreenToBottom;
                break;
                
            case Action.MoveCursorRight:
                if (Program.Screen.queuedCommands.moveHorizontallyBy(1))
                    break;
                    
                if (Program.Screen.rollover.moveHorizontallyBy(1))
                    break;
                    
                if (!Program.Screen.isEditorVisible)
                {
                    Program.Buffer.ScrollScreenHorizontallyBy(1);
                    break;
                }
                
                Program.Editor.MoveCursorRight;
                Program.Buffer.ScrollScreenToBottom;
                break;
                
            case Action.MoveToTop:
                if (Program.Buffer.SelectionType == Program.Buffer.SelectionTypes.EditorOnly)
                    Program.Editor.MoveCursorToTop;
                else
                    Program.Buffer.ScrollScreenToTop;
                break;
                
            case Action.MoveToBottom:
                Program.Buffer.ScrollScreenToBottom;
                Program.Editor.MoveCursorToBottom;
                break;
            
            case Action.MoveCursorToLineStart:
                Program.Editor.MoveCursorToLineStart;
                Program.Buffer.ScrollScreenToBottom;
                break;
            
            case Action.MoveCursorToLineEnd:
                Program.Editor.MoveCursorToLineEnd;
                Program.Buffer.ScrollScreenToBottom;
                break;
            
            case Action.MoveToWordLeft:
                Program.Editor.MoveCursorToWordLeft;
                Program.Buffer.ScrollScreenToBottom;
                break;
            
            case Action.MoveToWordRight:
                Program.Editor.MoveCursorToWordRight;
                Program.Buffer.ScrollScreenToBottom;
                break;
            
            case Action.PageUp:
                
                if (!Program.Screen.queuedCommands.moveUpByOnePage && 
                    !Program.Screen.rollover.moveUpByOnePage && 
                    !Program.AutoCompleteDatabase.MoveSuggestionPageUp)
                    Program.Buffer.ScrollScreenUpByOnePage;
                
                break;
            
            case Action.PageDown:
                
                if (!Program.Screen.queuedCommands.moveDownByOnePage && 
                    !Program.Screen.rollover.moveDownByOnePage && 
                    !Program.AutoCompleteDatabase.MoveSuggestionPageDown)
                    Program.Buffer.ScrollScreenDownByOnePage;
                
                break;
            
            case Action.SelectAll:
                Program.Editor.SelectAll;
                activateEditor;
                break;
            
            case Action.ExtendSelectionUp:
                Program.Editor.ExtendSelectionUp;
                activateEditor;
                break;
            
            case Action.ExtendSelectionDown:
                Program.Editor.ExtendSelectionDown;
                activateEditor;
                break;
            
            case Action.ExtendSelectionLeft:
                Program.Editor.ExtendSelectionLeft;
                activateEditor;
                break;
            
            case Action.ExtendSelectionRight:
                Program.Editor.ExtendSelectionRight;
                activateEditor;
                break;
            
            case Action.ExtendSelectionPageUp:
                break;
            
            case Action.ExtendSelectionPageDown:
                break;
            
            case Action.ExtendSelectionToLineStart:
                Program.Editor.ExtendSelectionToLineStart;
                activateEditor;
                break;
            
            case Action.ExtendSelectionToLineEnd:
                Program.Editor.ExtendSelectionToLineEnd;
                activateEditor;
                break;
            
            case Action.ExtendSelectionToTop:
                Program.Editor.ExtendSelectionToTop;
                break;
            
            case Action.ExtendSelectionToBottom:
                Program.Editor.ExtendSelectionToBottom;
                break;
            
            case Action.ExtendSelectionToWordLeft:
                Program.Editor.ExtendSelectionToWordLeft;
                activateEditor;
                break;
            
            case Action.ExtendSelectionToWordRight:
                Program.Editor.ExtendSelectionToWordRight;
                activateEditor;
                break;
            
            case Action.DeleteCharacterLeft:
                Program.Editor.DeleteCharacterLeft;
                activateEditor!(searchMode.Forward);
                break;
            
            case Action.DeleteCharacterRight:
                Program.Editor.DeleteCharacterRight;
                activateEditor!(searchMode.Forward);
                break;
            
            case Action.DeleteWordLeft:
                Program.Editor.DeleteWordLeft;
                activateEditor!(searchMode.Forward);
                break;
            
            case Action.DeleteWordRight:
                Program.Editor.DeleteWordRight;
                activateEditor!(searchMode.Forward);
                break;
            
            case Action.ClearScreen:
                
                if (!Program.Editor.HasAcceptPrompt)
                    Program.Interpreter.SetAcceptPrompt(new AcceptPrompt("clear_screen", "Clear screen (Y):", AcceptPrompt.ContentType.ClearScreen));
                break;
            
            case Action.TypeText:
                
                // I wanted to commit on space or return, but this actually requires a deep understanding of whether 
                // and identifier makes sense here because it's annoying if the user actually wants a space.
                // 
                // if ((character != ' ' && character != '\r' && character != '\n') || !Program.AutoCompleteDatabase.CompleteSuggestion)
                if ((character != '\r' && character != '\n') || !Program.AutoCompleteDatabase.CompleteSuggestion)
                    Program.Editor.AddCharacter(character);
                
                activateEditor!(searchMode.Forward);
                break;
                
            case Action.Tab:
                
                if (!Program.AutoCompleteDatabase.CompleteSuggestion)
                    Program.Editor.Tab;
                
                activateEditor!(searchMode.Forward);
                break;
            
            case Action.BackTab:
                Program.Editor.BackTab;
                activateEditor;
                break;
            
            case Action.Return:
                //if (!Program.AutoCompleteDatabase.CompleteSuggestion)
                    Program.Editor.Return(true, false);
                
                activateEditor!(searchMode.Forward);
                break;
            
            case Action.ShiftReturn:
                Program.Editor.Return(true, true);
                activateEditor!(searchMode.Backward);
                break;
            
            case Action.ConvertToUpperCase:
                Program.Editor.ConvertCase!(Yes.toUpperCase);
                break;
            
            case Action.ConvertToLowerCase:
                Program.Editor.ConvertCase!(No.toUpperCase);
                break;
            
            case Action.Cut:
                auto selectedText = Program.Editor.SelectedText;
                if (selectedText.length > 0)
                    SDL_SetClipboardText(selectedText.ToCString).CheckSDLError;
                
                Program.Editor.DeleteSelection;
                activateEditor!(searchMode.Forward);
                break;
            
            case Action.CopyOrBreak:
                auto selectedText = Program.Buffer.SelectedText;
                if (selectedText.length == 0)
                    Program.Interpreter.ControlCBreak;
                else
                    SDL_SetClipboardText(selectedText.ToCString).CheckSDLError;
                
                break;
            
            case Action.FullCopy:
                auto text = Program.Buffer.CopyWholeItems;
                if (text.length > 0)
                    SDL_SetClipboardText(text.ToCString).CheckSDLError;
                
                break;
            
            case Action.CopyField:
                auto text = Program.Buffer.CopyField;
                if (text.length > 0)
                    SDL_SetClipboardText(text.ToCString).CheckSDLError;
                
                break;
            
            case Action.Paste:
                auto clipboardText = SDL_GetClipboardText();
                if (clipboardText is null)
                    CheckSDLError;
                else
                    Program.Editor.AddText(clipboardText.FromCString);
                
                activateEditor!(searchMode.Forward);
                break;
            
            case Action.Save:
                break;
            
            case Action.FindNext:
                Program.Editor.EnableFindPrompt(Program.Buffer.SelectedText);
                activateEditor!(searchMode.Forward);
                break;
            
            case Action.FindPrevious:
                Program.Editor.EnableFindPrompt(Program.Buffer.SelectedText);
                activateEditor!(searchMode.Backward);
                break;
            
            case Action.Undo:
                Program.Editor.Undo;
                break;
            
            case Action.Redo:
                Program.Editor.Redo;
                break;
            
            case Action.ToggleInsertMode:
                Program.Editor.ToggleInsertMode;
                break;
            
            case Action.HistoryPrevious:
                Program.Editor.PreviousCommandInHistory;
                break;
            
            case Action.HistoryNext:
                Program.Editor.NextCommandInHistory;
                break;
            
            case Action.ZoomIn:
                Program.Screen.AdjustFontSizeBy(1);
                break;
            
            case Action.ZoomOut:
                Program.Screen.AdjustFontSizeBy(-1);
                break;
            
            case Action.ToggleFullScreen:
                Program.Screen.ToggleFullScreen;
                break;
            
            case Action.ShowAutoComplete:
                Program.AutoCompleteDatabase.ShowSuggestionPopup;
                break;
            
            case Action.MoveAutoCompleteSuggestionUp:
                Program.AutoCompleteDatabase.MoveSuggestionUp;
                break;
            
            case Action.MoveAutoCompleteSuggestionDown:
                Program.AutoCompleteDatabase.MoveSuggestionDown;
                break;
            
            case Action.F1: break;
            case Action.F2: break;
            case Action.F4: break;
            case Action.F5: break;
            case Action.F6: break;
            case Action.F7: 
                debug
                {
                    Program.AutoCompleteDatabase.UpdateSuggestions;
                    
                    foreach (suggestion; Program.AutoCompleteDatabase.tableSchemasAndSimpleNames.Items)
                        Buffer.AddText(suggestion);
                }
                break;
            
            case Action.F8: 
                // debug throw new NonRecoverableException("Test Exception");
                break;
                
            case Action.F9:
                debug
                {
                    import autocomplete;
                    auto a = new AutoCompleteManager;
                    a.Attempt(Program.Editor.Text);
                }
                break;
                
            case Action.F10:
                break;
            
            case Action.F11:
                debug Buffer.AddTestData;
                break;
            
            case Action.F12:
                break;
        }
    }
    
    public static auto Start(string commandLine)
    {
        Runtime.initialize();
        scope (exit) Runtime.terminate();
        
        try
        {
            debug DebugLog!(debugLogType.Reset)("Started");
            
            _syntax               = new syntax.Syntax;
            _settings             = new interpreter.Settings;
            _editor               = new EditorBufferItem;
            _buffer               = new buffer.Buffer(_editor);
            _screen               = new screen.Screen(_buffer);
            _database             = new DatabaseManager(toDelegate(&ProcessMainDatabaseThreadResult));
            _autoCompleteDatabase = new autocomplete.AutoCompleteManager;
            _interpreter          = new interpreter.Interpreter;
            
            DatabaseManager.GlobalInitialisation;
            
            scope (exit)
            {
                _screen.HideWindow;
                _interpreter.ClearQueue;
                _database.Kill;
                _autoCompleteDatabase.Kill;
                DatabaseManager.ClearAllMessages;
                DatabaseManager.GlobalFinalisation;
            }
            
            Screen.Update(0, 0);
            Buffer.AddText("\n\n\n\n\n\n");
            Buffer.ScrollScreenToBottom;
            
            const(string)[] parameters = splitLines(commandLine);
            
            auto connectionString = "";
            auto commandLineScripts = new string[0];
            
            auto loginScriptPath1 = Commands.FindFile("Login.sql");
            if (loginScriptPath1 != "")
                commandLineScripts ~= "@\"" ~ loginScriptPath1 ~ '\"';
            
            // Use a second login file for SQLPlusX if it exists.  This is 
            // so SQLPlusX commands can be placed here and won't fail old SQL*Plus.
            auto loginScriptPath2 = Commands.FindFile("SQLPlusXLogin.sql");
            if (loginScriptPath2 != "")
                commandLineScripts ~= "@\"" ~ loginScriptPath2 ~ '\"';
            
            foreach (parameterIndex, parameter; parameters)
            {
                if (parameter.startsWith('@'))
                {
                    commandLineScripts ~= parameter;
                }
                else if (parameter == "/")
                {
                    connectionString = "/";
                }
                else if (parameter.canFind('@'))
                {
                    connectionString = parameter;
                    
                    if (parameterIndex + 2 < parameters.length &&
                        parameters[parameterIndex + 1].toUpper == "AS")
                    {
                        connectionString ~= " AS " ~ parameters[parameterIndex + 2];
                    }
                }
            }
            
            if (connectionString.length > 0)
                Program.Interpreter.Execute!(CommandSource.ScriptFile)("CONNECT " ~ connectionString);
            
            foreach (script; commandLineScripts)
                Program.Interpreter.Execute!(CommandSource.ScriptFile)(script);
            
            auto isLeftControlKeyDown  = false;
            auto isRightControlKeyDown = false;
            auto isLeftShiftKeyDown    = false;
            auto isRightShiftKeyDown   = false;
            auto isLeftAltKeyDown      = false;
            auto isRightAltKeyDown     = false;
            auto isControlKeyDown      = false;       
            auto isShiftKeyDown        = false;       
            auto isAltKeyDown          = false;       
            
            auto mouseButtonHeldDown = 0;
            auto mouseButtonHeldDownNextClickTime = 0;
            auto mouseButtonHeldDownIsFirstClick = true;
            auto oldMouseX = 0;
            auto oldMouseY = 0;
            
            enum firstMouseClickDuration = 400;
            enum repeatMouseClickDuration = 10;
            enum targetFramesPerSecond = 60;
            enum targetMillisecondsPerFrame = 1000 / targetFramesPerSecond;
            
            enum targetChecksPerSecond = 30;
            enum targetMillisecondsPerCheck = 1000 / targetChecksPerSecond;
            
            SDL_StartTextInput;
            
            auto frameStartTime = SDL_GetTicks();
            MainLoop: while (isRunning)
            {
                try
                {
                    auto newStartTime = SDL_GetTicks();
                    auto lastFrameDuration = newStartTime - frameStartTime;
                    frameStartTime = newStartTime;
                    
                    // If the frame rate drops too far (it could be a pause due to window dragging or other delay) 
                    // limit the time so animations don't go crazy.
                    if (lastFrameDuration > 250)
                        lastFrameDuration = 250;
                    
                    InstructionResult result;

                    DatabaseManager.ProcessResultsAcrossAllThreads;
                    
                    Program.Editor.UpdatePromptTimeIfNecessary;
                    
                    Program.Database.KeepConnectionAliveIfNecessary;
                    
                    Program.Interpreter.CheckCommandQueue;
                    
                    auto mouseX = 0;
                    auto mouseY = 0;
                    auto mouseButtonState = SDL_GetMouseState(&mouseX, &mouseY);
                    
                    enum leftMouseButtonMask = SDL_BUTTON!SDL_BUTTON_LEFT;
                    // enum middleMouseButtonMask = SDL_BUTTON!SDL_BUTTON_MIDDLE;
                    // enum rightMouseButtonMask  = SDL_BUTTON!SDL_BUTTON_RIGHT;
                    
                    auto hasReceivedUserInput = oldMouseX != mouseX || oldMouseY != mouseY;
                    oldMouseX = mouseX;
                    oldMouseY = mouseY;
                    
                    
                    Program.Screen.UpdateMouse(mouseX, mouseY, mouseButtonState & leftMouseButtonMask);
                    
                    if (mouseButtonHeldDown != 0 && mouseButtonHeldDownNextClickTime <= SDL_GetTicks())
                    {
                        mouseButtonHeldDownNextClickTime = SDL_GetTicks() + repeatMouseClickDuration;
                        Program.Screen.MouseButtonDownRepeat(mouseX, mouseY, mouseButtonHeldDown);
                    }
                    
                    
                    SDL_Event event;
                    while (SDL_PollEvent(&event))
                    {
                        switch (event.type)
                        {
                            case SDL_QUIT, SDL_APP_TERMINATING:
                                Program.Exit;
                                break MainLoop;
                            
                            case SDL_WINDOWEVENT:
                                if (event.window.event == SDL_WINDOWEVENT_FOCUS_GAINED || event.window.event == SDL_WINDOWEVENT_ENTER)
                                    Program.Screen.Invalidate;
                                
                                if (event.window.event == SDL_WINDOWEVENT_MAXIMIZED || 
                                    event.window.event == SDL_WINDOWEVENT_RESTORED)
                                    Program.Screen.InvalidateWindowSizes;
                                
                                // This fires all the time, when partially obscured, moved, all sorts.
                                // But I remove the IsRendererValid check, I still see texture corruption sometimes.
                                if (event.window.event == SDL_WINDOWEVENT_EXPOSED && !Program.Screen.IsRendererValid)
                                    Program.Screen.CreateRenderer;
                                
                                break;
                                
                            case SDL_MULTIGESTURE:
                                hasReceivedUserInput = true;
                                if (event.mgesture.numFingers == 2)
                                    Program.Screen.AdjustFontSizeBy(cast(int)(-event.mgesture.dDist));
                                break;
                                
                            case SDL_FINGERMOTION:
                                hasReceivedUserInput = true;
                                Program.Buffer.ScrollScreenVerticallyBy(cast(int)(-100 * event.tfinger.dy));
                                Program.Buffer.ScrollScreenHorizontallyBy(cast(int)(-100 * event.tfinger.dx));
                                
                                break;
                            
                            case SDL_DROPFILE:
                                Program.Interpreter.Execute!(CommandSource.ScriptFile)("@\"" ~ event.drop.file.FromCString ~ '\"');
                                SDL_free(event.drop.file);
                                break;
                                
                            case SDL_MOUSEBUTTONDOWN:
                                hasReceivedUserInput = true;
                                // The following line captures mouse events even if 
                                // the user drags outside the window.
                                SDL_CaptureMouse(SDL_TRUE).CheckSDLError;
                                
                                auto mouseEvent = event.button;
                                
                                if (mouseEvent.button == SDL_BUTTON_RIGHT)
                                {
                                    auto selectedText = Program.Buffer.SelectedText;
                                    
                                    if (selectedText.length > 0)
                                    {
                                        if (Program.Buffer.SelectionType == Program.Buffer.SelectionTypes.EditorOnly)
                                            Program.Editor.MoveCursorToBottom;
                                        
                                        Program.Editor.AddText(selectedText);
                                    }
                                    continue;
                                }
                                
                                mouseButtonHeldDown = mouseEvent.button;
                                mouseButtonHeldDownNextClickTime = SDL_GetTicks() + firstMouseClickDuration;
                                Program.Screen.MouseButtonDown(mouseX, mouseY, mouseButtonHeldDown);
                                Program.Screen.MouseButtonDownRepeat(mouseX, mouseY, mouseButtonHeldDown);
                                
                                if (mouseEvent.clicks == 2)
                                    Program.Screen.SelectWholeWordAt(mouseX, mouseY);
                                
                                break;
                                
                            case SDL_MOUSEBUTTONUP:
                                hasReceivedUserInput = true;
                                // Revert the capture mouse state.
                                SDL_CaptureMouse(SDL_FALSE).CheckSDLError;
                                
                                auto mouseEvent = event.button;
                                
                                if (mouseButtonHeldDown == mouseEvent.button)
                                    mouseButtonHeldDown = 0;
                                
                                Program.Screen.MouseButtonUp(mouseEvent.x, mouseEvent.y, mouseEvent.button);
                                
                                continue;
                            
                            case SDL_MOUSEWHEEL:
                                hasReceivedUserInput = true;
                                auto wheelEvent = event.wheel;
                                auto coefficient = wheelEvent.direction == SDL_MOUSEWHEEL_FLIPPED ? -1 : 1;
                                
                                if (isControlKeyDown)
                                    Program.Screen.AdjustFontSizeBy(wheelEvent.y * coefficient);
                                else
                                {
                                    immutable verticalLines        = -wheelEvent.y * coefficient;
                                    immutable horizontalCharacters = 8 * wheelEvent.x * coefficient;
                                    
                                    if (Program.Screen.queuedCommands.isVerticallyScrollable)
                                        Program.Screen.queuedCommands.moveVerticallyBy(verticalLines);
                                    else if (Program.Screen.rollover.isVerticallyScrollable)
                                        Program.Screen.rollover.moveVerticallyBy(verticalLines);
                                    else
                                        Program.Buffer.ScrollScreenVerticallyBy(verticalLines);
                                    
                                    if (Program.Screen.queuedCommands.isHorizontallyScrollable)
                                        Program.Screen.queuedCommands.moveHorizontallyBy(verticalLines);
                                    else if (Program.Screen.rollover.isHorizontallyScrollable)
                                        Program.Screen.rollover.moveHorizontallyBy(horizontalCharacters);
                                    else
                                        Program.Buffer.ScrollScreenHorizontallyBy(horizontalCharacters);
                                }
                                
                                continue;
                                
                            case SDL_TEXTINPUT:
                                hasReceivedUserInput = true;
                                
                                foreach (character; event.edit.text.ptr.FromCString.byDchar)
                                {
                                    if (Program.Editor.CheckPressAnyKey)
                                        continue;
                                    
                                    processInput(character, Action.TypeText); 
                                }
                                
                                Program.Screen.Invalidate;
                                break;
                                
                            case SDL_KEYDOWN:
                                hasReceivedUserInput = true;
                                auto key = event.key.keysym.sym;
                                
                                switch (key)
                                {
                                    case SDLK_LCTRL:  isLeftControlKeyDown  = true; isControlKeyDown = true; continue;
                                    case SDLK_RCTRL:  isRightControlKeyDown = true; isControlKeyDown = true; continue;
                                    case SDLK_LSHIFT: isLeftShiftKeyDown    = true; isShiftKeyDown   = true; continue;
                                    case SDLK_RSHIFT: isRightShiftKeyDown   = true; isShiftKeyDown   = true; continue;
                                    case SDLK_LALT:   isLeftAltKeyDown      = true; isAltKeyDown     = true; continue;
                                    case SDLK_RALT:   isRightAltKeyDown     = true; isAltKeyDown     = true; continue;
                                    default: break;
                                }
                                
                                if (Program.Editor.CheckPressAnyKey)
                                    continue;
                                
                                processInput('\0', ParseKey(key, isControlKeyDown, isShiftKeyDown, isAltKeyDown)); 
                                
                                break;
                                
                            case SDL_KEYUP:
                                hasReceivedUserInput = true;
                                switch (event.key.keysym.sym)
                                {
                                    case SDLK_LCTRL:  isLeftControlKeyDown  = false; isControlKeyDown = isLeftControlKeyDown || isRightControlKeyDown; continue;
                                    case SDLK_RCTRL:  isRightControlKeyDown = false; isControlKeyDown = isLeftControlKeyDown || isRightControlKeyDown; continue;
                                    case SDLK_LSHIFT: isLeftShiftKeyDown    = false; isShiftKeyDown   = isLeftShiftKeyDown   || isRightShiftKeyDown;   continue;
                                    case SDLK_RSHIFT: isRightShiftKeyDown   = false; isShiftKeyDown   = isLeftShiftKeyDown   || isRightShiftKeyDown;   continue;
                                    case SDLK_LALT:   isLeftAltKeyDown      = false; isAltKeyDown     = isLeftAltKeyDown     || isRightAltKeyDown;     continue;
                                    case SDLK_RALT:   isRightAltKeyDown     = false; isAltKeyDown     = isLeftAltKeyDown     || isRightAltKeyDown;     continue;
                                    default: continue;
                                }
                                
                            default:
                                break;
                        }
                    }
                    
                    Program.Editor.RefreshFormatting;
                    Program.Screen.Update(frameStartTime, lastFrameDuration);
                   
                    // Only delay if there was no user action this frame.
                    if (!hasReceivedUserInput)
                    {
                        // Animations leave the screen invalid for an immediate redraw.
                        const targetMilliseconds = 
                            Program.Screen.isScreenUpToDate ? 
                                targetMillisecondsPerCheck : 
                                targetMillisecondsPerFrame;
                        
                        auto frameDurationInMilliseconds = max(0, SDL_GetTicks() - frameStartTime);
                        if (frameDurationInMilliseconds < targetMilliseconds)
                            SDL_Delay(targetMilliseconds - frameDurationInMilliseconds);
                    }
                    
                    currentFrameCount++;
                    accumulatedMilliseconds += SDL_GetTicks() - frameStartTime;
                    
                    while (accumulatedMilliseconds > 1000)
                    {
                        accumulatedMilliseconds -= 1000;
                        framesPerSecond = currentFrameCount;
                        currentFrameCount = 0;
                    }
                }
                catch (RecoverableException exception) 
                {
                    Program.Buffer.AddText(exception.msg);
                }
            }
            
            return 0;
        }
        catch (Throwable e) 
        {
            SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Critical Error!".ptr, e.toString().ToCString, null);
            return 1;
        }
    }
}