module keyboard;

import derelict.sdl2.sdl;

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
    bool isAltKeyDown, 
    out char character) @nogc nothrow
{
    Action Output(char lowerCase, char upperCase = '\0', bool checkCapsLock = false)
    {
        switch (lowerCase)
        {
            case 'a': 
                if (isControlKeyDown) 
                    return Action.SelectAll;
                
                break;
                
            case 'c': 
                if (isControlKeyDown) 
                {
                    if (isShiftKeyDown)
                        return Action.FullCopy;
                    
                    if (isAltKeyDown)
                        return Action.CopyField;
                    
                    return Action.CopyOrBreak;
                }
                
                break;
                
            case 'f': 
                if (isControlKeyDown) 
                {
                    if (isShiftKeyDown)
                        return Action.FindPrevious;
                    else
                        return Action.FindNext;
                }
                
                break;
                
            case 'u':
                if (isControlKeyDown)
                {
                    if (isShiftKeyDown)
                        return Action.ConvertToUpperCase;
                    else
                        return Action.ConvertToLowerCase;
                }
                
                break;
                
            case 'v': 
                if (isControlKeyDown) 
                    return Action.Paste;
                
                break;
                
            case 'x': 
                if (isControlKeyDown) 
                    return Action.Cut;
                
                break;
                
            case 'y': 
                if (isControlKeyDown) 
                    return Action.Redo;
                
                break;
                
            case 'z': 
                if (isControlKeyDown) 
                {
                    if (isShiftKeyDown)
                        return Action.Redo;
                    else
                        return Action.Undo;
                }
                break;
            
            case '=', '+':
                if (isControlKeyDown) 
                    return Action.ZoomIn;
                break;
            
            case '-', '_':
                if (isControlKeyDown) 
                    return Action.ZoomOut;
                break;
            
            case ' ', '.':
                if (isControlKeyDown) 
                    return Action.ShowAutoComplete;
                break;
            
            default: break;
        }
        
        if (upperCase == '\0')
            character = lowerCase;
        else
        {
            if ((checkCapsLock && (SDL_GetModState() & KMOD_CAPS) > 0) ^ isShiftKeyDown)
                character = upperCase;
            else
                character = lowerCase;
        }
        
        return Action.TypeText;
    }
    
    if ((SDL_GetModState() & KMOD_NUM) == 0)
        switch (keyCode)
        {
            case SDLK_KP_0: keyCode = SDLK_INSERT   ; break;
            case SDLK_KP_1: keyCode = SDLK_END      ; break;
            case SDLK_KP_2: keyCode = SDLK_DOWN     ; break;
            case SDLK_KP_3: keyCode = SDLK_PAGEDOWN ; break;
            case SDLK_KP_4: keyCode = SDLK_LEFT     ; break;
            case SDLK_KP_5: keyCode = SDLK_UNKNOWN  ; break;
            case SDLK_KP_6: keyCode = SDLK_RIGHT    ; break;
            case SDLK_KP_7: keyCode = SDLK_HOME     ; break;
            case SDLK_KP_8: keyCode = SDLK_UP       ; break;
            case SDLK_KP_9: keyCode = SDLK_PAGEUP   ; break;
            default: break;
        }
    
    switch (keyCode)
    {
        case SDLK_0: return Output('0', ')');
        case SDLK_1: return Output('1', '!');
        case SDLK_2: return Output('2', '"');
        case SDLK_3: return Output('3', 163);
        case SDLK_4: return Output('4', '$');
        case SDLK_5: return Output('5', '%');
        case SDLK_6: return Output('6', '^');
        case SDLK_7: return Output('7', '&');
        case SDLK_8: return Output('8', '*');
        case SDLK_9: return Output('9', '(');
        
        case SDLK_KP_0: return Output('0');
        case SDLK_KP_1: return Output('1');
        case SDLK_KP_2: return Output('2');
        case SDLK_KP_3: return Output('3');
        case SDLK_KP_4: return Output('4');
        case SDLK_KP_5: return Output('5');
        case SDLK_KP_6: return Output('6');
        case SDLK_KP_7: return Output('7');
        case SDLK_KP_8: return Output('8');
        case SDLK_KP_9: return Output('9');
        
        case SDLK_a: return Output('a', 'A', true);
        case SDLK_b: return Output('b', 'B', true);
        case SDLK_c: return Output('c', 'C', true);
        case SDLK_d: return Output('d', 'D', true);
        case SDLK_e: return Output('e', 'E', true);
        case SDLK_f: return Output('f', 'F', true);
        case SDLK_g: return Output('g', 'G', true);
        case SDLK_h: return Output('h', 'H', true);
        case SDLK_i: return Output('i', 'I', true);
        case SDLK_j: return Output('j', 'J', true);
        case SDLK_k: return Output('k', 'K', true);
        case SDLK_l: return Output('l', 'L', true);
        case SDLK_m: return Output('m', 'M', true);
        case SDLK_n: return Output('n', 'N', true);
        case SDLK_o: return Output('o', 'O', true);
        case SDLK_p: return Output('p', 'P', true);
        case SDLK_q: return Output('q', 'Q', true);
        case SDLK_r: return Output('r', 'R', true);
        case SDLK_s: return Output('s', 'S', true);
        case SDLK_t: return Output('t', 'T', true);
        case SDLK_u: return Output('u', 'U', true);
        case SDLK_v: return Output('v', 'V', true);
        case SDLK_w: return Output('w', 'W', true);
        case SDLK_x: return Output('x', 'X', true);
        case SDLK_y: return Output('y', 'Y', true);
        case SDLK_z: return Output('z', 'Z', true);
        
        case SDLK_KP_AMPERSAND:  return Output('&');
        case SDLK_KP_AT:         return Output('@');
        case SDLK_KP_COLON:      return Output(':');
        case SDLK_KP_COMMA:      return Output(',');
        case SDLK_KP_DECIMAL:    return Output('.');
        case SDLK_KP_DIVIDE:     return Output('/');
        case SDLK_KP_EXCLAM:     return Output('!');
        case SDLK_KP_GREATER:    return Output('>');
        case SDLK_KP_HASH:       return Output('#');
        case SDLK_KP_LEFTBRACE:  return Output('{');
        case SDLK_KP_LEFTPAREN:  return Output('(');
        case SDLK_KP_LESS:       return Output('<');
        case SDLK_KP_MINUS:      return Output('-');
        case SDLK_KP_MULTIPLY:   return Output('*');
        case SDLK_KP_PERCENT:    return Output('%');
        case SDLK_KP_PERIOD:     return Output('.');
        case SDLK_KP_PLUS:       return Output('+');
        case SDLK_KP_RIGHTBRACE: return Output('}');
        case SDLK_KP_RIGHTPAREN: return Output(')');
        case SDLK_KP_SPACE:      return Output(' ');

        case SDLK_SPACE:        return Output(' ');
        case SDLK_BACKQUOTE:    return Output('`', 172);
        case SDLK_MINUS:        return Output('-',  '_');
        case SDLK_EQUALS:       return Output('=',  '+');
        case SDLK_LEFTBRACKET:  return Output('[',  '{');
        case SDLK_RIGHTBRACKET: return Output(']',  '}');
        case SDLK_SEMICOLON:    return Output(';',  ':');
        case SDLK_QUOTE:        return Output('\'', '@');
        case SDLK_HASH:         return Output('#',  '~');
        case SDLK_BACKSLASH:    return Output('\\', '|');
        case SDLK_COMMA:        return Output(',',  '<');
        case SDLK_PERIOD:       return Output('.',  '>');
        case SDLK_SLASH:        return Output('/',  '?');
        
        case SDLK_AMPERSAND:    return Output('&');
        case SDLK_ASTERISK:     return Output('*');
        case SDLK_AT:           return Output('@');
        case SDLK_CARET:        return Output('^');
        case SDLK_COLON:        return Output(':');
        case SDLK_DOLLAR:       return Output('$');
        case SDLK_EXCLAIM:      return Output('!');
        case SDLK_GREATER:      return Output('>');
        case SDLK_LEFTPAREN:    return Output('(');
        case SDLK_LESS:         return Output('<');
        case SDLK_PERCENT:      return Output('%');
        case SDLK_PLUS:         return Output('+');
        case SDLK_QUESTION:     return Output('?');
        case SDLK_QUOTEDBL:     return Output('"');
        case SDLK_RIGHTPAREN:   return Output(')');
        case SDLK_UNDERSCORE:   return Output('_');
        case SDLK_KP_EQUALS:    return Output('=');
        
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
        //case SDLK_F13:     return Action.F13;
        //case SDLK_F14:     return Action.F14;
        //case SDLK_F15:     return Action.F15;
        //case SDLK_F16:     return Action.F16;
        //case SDLK_F17:     return Action.F17;
        //case SDLK_F18:     return Action.F18;
        //case SDLK_F19:     return Action.F19;
        //case SDLK_F20:     return Action.F20;
        //case SDLK_F21:     return Action.F21;
        //case SDLK_F22:     return Action.F22;
        //case SDLK_F23:     return Action.F23;
        //case SDLK_F24:     return Action.F24;
        
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
        
        default : return Action.Nothing;
    }
}