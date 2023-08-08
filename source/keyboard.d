module keyboard;

import bindbc.sdl;

enum Action
{
    Nothing, 
    Cancel, 
    MoveScreenUp, 
    MoveScreenDown, 
    MoveScreenLeft, 
    MoveScreenRight, 
    MoveCursorUp, 
    MoveCursorDown, 
    MoveCursorLeft, 
    MoveCursorRight, 
    MoveToTop, 
    MoveToBottom, 
    MoveCursorToLineStart, 
    MoveCursorToLineEnd, 
    MoveToWordLeft, 
    MoveToWordRight, 
    PageUp, 
    PageDown, 
    SelectAll, 
    ExtendSelectionUp, 
    ExtendSelectionDown, 
    ExtendSelectionLeft, 
    ExtendSelectionRight, 
    ExtendSelectionPageUp, 
    ExtendSelectionPageDown, 
    ExtendSelectionToLineStart, 
    ExtendSelectionToLineEnd, 
    ExtendSelectionToTop,
    ExtendSelectionToBottom,
    ExtendSelectionToWordLeft,
    ExtendSelectionToWordRight,
    DeleteCharacterLeft, 
    DeleteCharacterRight, 
    DeleteWordLeft, 
    DeleteWordRight, 
    ClearScreen, 
    TypeText, 
    Tab, 
    BackTab, 
    Return, 
    ShiftReturn, 
    ConvertToUpperCase, 
    ConvertToLowerCase, 
    Cut, 
    CopyOrBreak, 
    FullCopy, 
    CopyField, 
    Paste, 
    Save, 
    FindNext, 
    FindPrevious, 
    Undo, 
    Redo, 
    ToggleInsertMode, 
    HistoryPrevious, 
    HistoryNext, 
    ZoomIn, 
    ZoomOut, 
    ToggleFullScreen, 
    ShowAutoComplete, 
    MoveAutoCompleteSuggestionUp, 
    MoveAutoCompleteSuggestionDown, 
    F1, 
    F2, 
    F4, 
    F5, 
    F6, 
    F7, 
    F8, 
    F9, 
    F10, 
    F11, 
    F12
}

public Action ParseKey(
    SDL_Keycode keyCode, 
    bool isControlKeyDown, 
    bool isShiftKeyDown, 
    bool isAltKeyDown) @nogc nothrow
{
    if ((SDL_GetModState() & KMOD_NUM) == 0)
        switch (keyCode)
        {
            case SDLK_KP_0: keyCode = SDLK_INSERT;    break;
            case SDLK_KP_1: keyCode = SDLK_END;       break;
            case SDLK_KP_2: keyCode = SDLK_DOWN;      break;
            case SDLK_KP_3: keyCode = SDLK_PAGEDOWN;  break;
            case SDLK_KP_4: keyCode = SDLK_LEFT;      break;
            case SDLK_KP_5: keyCode = SDLK_UNKNOWN;   break;
            case SDLK_KP_6: keyCode = SDLK_RIGHT;     break;
            case SDLK_KP_7: keyCode = SDLK_HOME;      break;
            case SDLK_KP_8: keyCode = SDLK_UP;        break;
            case SDLK_KP_9: keyCode = SDLK_PAGEUP;    break;
            default: break;
        }
   
    switch (keyCode)
    {
        case SDLK_F1:           return Action.F1;
        case SDLK_F2:           return Action.F2;
        case SDLK_F3: 
        {
            if (isShiftKeyDown)
                return Action.FindPrevious;
            else
                return Action.FindNext;
        }
        
        case SDLK_F4: return Action.F4;
        case SDLK_F5:        return Action.F5;
        case SDLK_F6:        return Action.F6;
        case SDLK_F7:        return Action.F7;
        case SDLK_F8:        return Action.F8;
        case SDLK_F9:        return Action.F9;
        case SDLK_F10:       return Action.F10;
        case SDLK_F11:       return Action.F11;
        case SDLK_F12:       return Action.F12;
        
        case SDLK_a: 
            if (isControlKeyDown) 
                return Action.SelectAll;
            
            break;
            
        case SDLK_c: 
            if (isControlKeyDown) 
            {
                if (isShiftKeyDown)
                    return Action.FullCopy;
                
                if (isAltKeyDown)
                    return Action.CopyField;
                
                return Action.CopyOrBreak;
            }
            
            break;
            
        case SDLK_f: 
            if (isControlKeyDown) 
            {
                if (isShiftKeyDown)
                    return Action.FindPrevious;
                else
                    return Action.FindNext;
            }
            
            break;
            
        case SDLK_u:
            if (isControlKeyDown)
            {
                if (isShiftKeyDown)
                    return Action.ConvertToUpperCase;
                else
                    return Action.ConvertToLowerCase;
            }
            
            break;
            
        case SDLK_v: 
            if (isControlKeyDown) 
                return Action.Paste;
            
            break;
            
        case SDLK_x: 
            if (isControlKeyDown) 
                return Action.Cut;
            
            break;
            
        case SDLK_y: 
            if (isControlKeyDown) 
                return Action.Redo;
            
            break;
            
        case SDLK_z: 
            if (isControlKeyDown) 
            {
                if (isShiftKeyDown)
                    return Action.Redo;
                else
                    return Action.Undo;
            }
            break;
        
        case SDLK_EQUALS, SDLK_PLUS, SDLK_KP_PLUS:
            if (isControlKeyDown) 
                return Action.ZoomIn;
            break;
        
        case SDLK_MINUS, SDLK_UNDERSCORE, SDLK_KP_MINUS:
            if (isControlKeyDown) 
                return Action.ZoomOut;
            break;
        
        case SDLK_SPACE, SDLK_PERIOD:
            if (isControlKeyDown) 
                return Action.ShowAutoComplete;
            break;
        
        case SDLK_CANCEL:    return Action.Cancel;
        case SDLK_ESCAPE:    return Action.Cancel;
        
        case SDLK_RETURN, SDLK_RETURN2, SDLK_KP_ENTER: 
        {
            if (isAltKeyDown)
                return Action.ToggleFullScreen;
            else if (isShiftKeyDown)
                return Action.ShiftReturn;
            else
                return Action.Return;
        }
        
        case SDLK_UNDO:      return Action.Undo;
        case SDLK_FIND:
            if (isShiftKeyDown)
                return Action.FindPrevious;
            else
                return Action.FindNext;
        
        case SDLK_CUT:       return Action.Cut;
        case SDLK_COPY:      return isShiftKeyDown ? Action.FullCopy : Action.CopyOrBreak;
        case SDLK_PASTE:     return Action.Paste;
        
        case SDLK_TAB: 
        case SDLK_KP_TAB:
            if (isShiftKeyDown)
                return Action.BackTab;
            
            return Action.Tab;
            
        case SDLK_INSERT: 
            if (isShiftKeyDown)
                return Action.Paste;
            
            return Action.ToggleInsertMode;
            
        case SDLK_BACKSPACE:
        case SDLK_KP_BACKSPACE: 
            if (isControlKeyDown)
                return Action.DeleteWordLeft;
            
            return Action.DeleteCharacterLeft;
            
        case SDLK_CLEAR:
        case SDLK_CLEARAGAIN:
        case SDLK_DELETE:
        case SDLK_KP_CLEARENTRY:
        case SDLK_KP_CLEAR: 
            if (isControlKeyDown)
                return Action.DeleteWordRight;
            
            if (isShiftKeyDown)
                return Action.ClearScreen;
            
            return Action.DeleteCharacterRight;
        
        // The pause key works, but not in combination with CTRL.
        // SDLK_BREAK doesn't seem to exist even though it's in the documentation.
        case SDLK_PAUSE: 
            if (isControlKeyDown)
                return Action.Cancel;
            
            return Action.Nothing;
            
        case SDLK_HOME:
            if (isShiftKeyDown && isControlKeyDown)
                return Action.ExtendSelectionToTop;
            
            if (isShiftKeyDown)
                return Action.ExtendSelectionToLineStart;
            
            if (isControlKeyDown)
                return Action.MoveToTop;
            
            return Action.MoveCursorToLineStart;
        
        case SDLK_END:
            if (isShiftKeyDown && isControlKeyDown)
                return Action.ExtendSelectionToBottom;
            
            if (isShiftKeyDown)
                return Action.ExtendSelectionToLineEnd;
            
            if (isControlKeyDown)
                return Action.MoveToBottom;
            
            return Action.MoveCursorToLineEnd;
        
        case SDLK_LEFT:
            if (isAltKeyDown)
                return Action.MoveScreenLeft;
            
            if (isShiftKeyDown && isControlKeyDown)
                return Action.ExtendSelectionToWordLeft;
            
            if (isShiftKeyDown)
                return Action.ExtendSelectionLeft;
            
            if (isControlKeyDown)
                return Action.MoveToWordLeft;
            
            return Action.MoveCursorLeft;
            
        case SDLK_RIGHT:
            if (isAltKeyDown)
                return Action.MoveScreenRight;
            
            if (isShiftKeyDown && isControlKeyDown)
                return Action.ExtendSelectionToWordRight;
            
            if (isShiftKeyDown)
                return Action.ExtendSelectionRight;
            
            if (isControlKeyDown)
                return Action.MoveToWordRight;
            
            return Action.MoveCursorRight;
            
        case SDLK_UP:
            if (isControlKeyDown && isAltKeyDown)
                return Action.MoveScreenUp;
            
            if (isControlKeyDown)
                return Action.MoveAutoCompleteSuggestionUp;
            
            if (isShiftKeyDown)
                return Action.ExtendSelectionUp;
            
            if (isAltKeyDown)
                return Action.HistoryPrevious;
            
            return Action.MoveCursorUp;
            
        case SDLK_DOWN:
            if (isControlKeyDown && isAltKeyDown)
                return Action.MoveScreenDown;
            
            if (isControlKeyDown)
                return Action.MoveAutoCompleteSuggestionDown;
            
            if (isShiftKeyDown)
                return Action.ExtendSelectionDown;
            
            if (isAltKeyDown)
                return Action.HistoryNext;
            
            return Action.MoveCursorDown;
            
        case SDLK_PAGEDOWN:
            if (isShiftKeyDown)
                return Action.ExtendSelectionPageDown;
            
            return Action.PageDown;
            
        case SDLK_PAGEUP:
            if (isShiftKeyDown)
                return Action.ExtendSelectionPageUp;
            
            return Action.PageUp;
        
        default: 
            break;
    }
    
    return Action.Nothing;
}
