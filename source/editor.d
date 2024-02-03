module editor;

import std.algorithm : min, max, countUntil, all, filter, map, splitter;
import std.array : array, join, replace;
import std.conv :to, ConvException;
import std.range : repeat, retro, appender, enumerate;
import std.datetime : Clock;
import std.datetime.systime;
import std.string : strip, splitLines, rightJustify, lineSplitter, toUpper, toLower, isNumeric;
import std.typecons : Flag, Yes, No, tuple;
import std.uni : isAlphaNum, isWhite;
import std.utf : byDchar;

import program;
import range_extensions;
import utf8_slice;

public final class AcceptPrompt
{
    public enum ContentType { SubstitutionVariable, Username, PressAnyKey, Password, NewPasswordFirstEntry, NewPasswordSecondEntry, Host, ClearScreen, Find }
    public enum InputType { Text, Number, Date }

    private string name;
    public string Name() const @nogc nothrow => name;
    
    private string prompt;
    public string Prompt() const @nogc nothrow => prompt;
    
    private ContentType content;
    public ContentType Content() const @nogc nothrow => content;
    
    private InputType type;
    public InputType Type() const @nogc nothrow => type;
    
    private bool isHidden;
    public bool IsHidden() const @nogc nothrow => isHidden;
    
    private bool hasResult = false;
    public bool HasResult() const @nogc nothrow => hasResult;
    
    private string result;
    public string Result() const @nogc nothrow => result;
    
    private string defaultValue;
    public string DefaultValue() const @nogc nothrow => defaultValue;
    
    private string format;
    public string Format() const @nogc nothrow => format;
    
    public void SetResult(string result)
    {
        // If we allow substitution characters inside a substitution, we could 
        // have infinite recursion.
        if (Program.Settings.SubstitutionEnabled)
            this.result = result.replace(Program.Settings.SubstitutionCharacter, ' ');
        else
            this.result = result;
        
        if (this.result == "")
            this.result = defaultValue;
        
        // TODO: Validate format if it's provided.
        
        hasResult = true;
    }
    
    public this(
        const string name, 
        const string prompt = null, 
        const ContentType content = ContentType.SubstitutionVariable, 
        const InputType type = InputType.Text, 
        const bool isHidden = false, 
        const string defaultValue = "", 
        const string format = "") nothrow
    {
        this.name = name;
        
        if (prompt == "")
            this.prompt = "Enter value for " ~ name ~ ":";
        else
            this.prompt = prompt;
            
        this.content = content;
        this.type = type;
        this.defaultValue = defaultValue;
        this.format = format;
        this.isHidden = isHidden;
    }
}

private final class CommandHistory
{
    string[] commandHistory;
    auto commandHistoryIndex = 0; // This can be after the end of the commandHistory array.
    
    enum CurrentLocation { MoveToEnd, Keep }
    
    void AddCommand(CurrentLocation currentLocation)(const string command) nothrow
    {
        auto text = command.strip;
        
        if (text.length < 2)
            return;
        
        auto historyIndex = 
             commandHistory
            .enumerate!int
            .filter!(item => item.value == text)
            .map!(item => item.index)
            .firstOrDefault(-1);
        
        if (historyIndex >= 0)
        {
            static if (currentLocation == CurrentLocation.Keep)
                return;
            else
            {
                // Remove the old version so we don't have duplicates in the history.
                commandHistory = commandHistory[0 .. historyIndex] ~
                                 commandHistory[historyIndex + 1 .. $];
                
                if (commandHistoryIndex >= historyIndex)
                    commandHistoryIndex--;
            }
        }
        
        commandHistory ~= text;
        
        static if (currentLocation == CurrentLocation.MoveToEnd)
            commandHistoryIndex = commandHistory.intLength;
    }
    
    string MovePrevious() @nogc nothrow
    {
        if (commandHistoryIndex <= 0) 
            return null;
        
        commandHistoryIndex--;
        return commandHistory[commandHistoryIndex];
    }
    
    string MoveNext() @nogc nothrow
    {
        if (commandHistoryIndex >= commandHistory.length)
            return null;
        
        commandHistoryIndex++;
        
        if (commandHistoryIndex == commandHistory.length)
            return "";
        
        return commandHistory[commandHistoryIndex];
    }
    
    void Clear() @nogc nothrow
    {
        commandHistoryIndex = 0;
        commandHistory = [];
    }
    
    string LastCommand() @nogc nothrow
    {
        if (commandHistoryIndex == 0)
            return "";
        
        return commandHistory[commandHistoryIndex - 1];
    }
    
    void AppendToLastCommand(string text) nothrow
    {
        if (commandHistoryIndex == 0)
            return;
        
        commandHistory[commandHistoryIndex - 1] ~= text;
    }
    
    void ReplaceTextInLastCommand(string oldText, string newText) nothrow
    {
        if (commandHistoryIndex == 0)
            return;
        
        commandHistory[commandHistoryIndex - 1] = commandHistory[commandHistoryIndex - 1].replace(oldText, newText);
    }
    
    void DeleteLinesInLastCommand(int firstLine, int lastLine) nothrow
    {
        if (commandHistoryIndex == 0)
            return;
        
        auto commandLines = commandHistory[commandHistoryIndex - 1].lineSplitter.array;
    
        commandHistory[commandHistoryIndex - 1] = (commandLines[0 .. firstLine] ~ commandLines[lastLine .. $]).join(lineEnding);
    }
    
    auto HistoryDescending() @nogc nothrow
    {
        return commandHistory.retro;
    }
}

public final class EditorBufferItem : BufferItem
{
    private auto cursorPositionLine = 0;
    public auto CursorPositionLine() const @nogc nothrow => cursorPositionLine;
    
    // The cursor is before the character indicated by this index.  Note, 
    // this means it could equal lines[cursorPositionLine].toUtf8Slice.length, 
    // and therefore be AFTER the last character index.
    private auto cursorPositionColumn = 0;
    public auto CursorPositionColumn() const @nogc nothrow => Indentation + cursorPositionColumn;
    
    private int currentBufferLine = -1;
    
    public int GetOffsetFrom(const int lineNumber, const int column) const @nogc nothrow
    {
        if (lineNumber < 0)
            return 0;
        
        auto offset = 0;
        foreach (line; lines[0 .. min(lineNumber, $)])
            offset += line.toUtf8Slice.intLength + lineEnding.intLength;
        
        if (lineNumber >= lines.length)
            return offset;
        
        return offset + min(max(0, column), lines[lineNumber].toUtf8Slice.intLength);
    }
    
    immutable struct TextLocation
    {
        immutable int line;
        immutable int column;
    }
    
    TextLocation GetLocationFromOffset(int offset) @nogc nothrow
    {
        foreach (lineNumber, line; lines)
        {
            auto utf8 = line.toUtf8Slice;
        
            if (offset < utf8.length + lineEnding.length)
                return TextLocation(cast(int)lineNumber, max(0, offset));
            
            offset -= utf8.intLength + lineEnding.intLength;
        }
        
        return TextLocation(lines.intLength - 1, lines[$ - 1].toUtf8Slice.intLength);
    }
    
    public auto CursorOffset() const @nogc nothrow => GetOffsetFrom(cursorPositionLine, cursorPositionColumn);
    
    private auto selectionStartLine = 0;
    public auto SelectionStartLine() const @nogc nothrow => selectionStartLine;
    
    // Same semantics as CursorPositionColumn.
    private auto selectionStartColumn = 0;
    public auto SelectionStartColumn() const @nogc nothrow => Indentation + selectionStartColumn;
    
    private auto selectionEndLine = 0;
    public auto SelectionEndLine() const @nogc nothrow => selectionEndLine;
    
    // Same semantics as CursorPositionColumn.
    private auto selectionEndColumn = 0;
    public auto SelectionEndColumn() const @nogc nothrow => Indentation + selectionEndColumn;
    
    private class UndoFrame
    {
        private auto cursorPositionLine   = 0;
        private auto cursorPositionColumn = 0;
        private auto selectionStartLine   = 0;
        private auto selectionStartColumn = 0;
        private auto selectionEndLine     = 0;
        private auto selectionEndColumn   = 0;
        
        private string[] lines;
        auto Lines() const @nogc nothrow => lines;
        
        private bool isTypedText = false;
        auto IsTypedText() const @nogc nothrow => isTypedText;
        
        public this(bool isTypedText) nothrow
        {
            this.isTypedText           = isTypedText;
            this.lines                 = this.outer.lines.dup;
            this.cursorPositionLine    = this.outer.cursorPositionLine;
            this.cursorPositionColumn  = this.outer.cursorPositionColumn;
            this.selectionStartLine    = this.outer.selectionStartLine;
            this.selectionStartColumn  = this.outer.selectionStartColumn;
            this.selectionEndLine      = this.outer.selectionEndLine;
            this.selectionEndColumn    = this.outer.selectionEndColumn;
        }
        
        public void Load() nothrow
        {
            this.outer.lines                 = this.lines.dup;
            this.outer.cursorPositionLine    = this.cursorPositionLine;
            this.outer.cursorPositionColumn  = this.cursorPositionColumn;
            this.outer.selectionStartLine    = this.selectionStartLine;
            this.outer.selectionStartColumn  = this.selectionStartColumn;
            this.outer.selectionEndLine      = this.selectionEndLine;
            this.outer.selectionEndColumn    = this.selectionEndColumn;
            this.outer.InvalidateFormatting;
            Program.Screen.Invalidate;
        }
    }
    
    private auto lines = new string[1];
    private UndoFrame[] undoHistory;
    private auto undoHistoryIndex = -1;
    
    this() nothrow
    {
        mainCommandHistory = new CommandHistory;
        currentCommandHistory = mainCommandHistory;
        AddUndoHistoryFrame;
    }
    
    private void ClearUndoHistory() nothrow
    {
        undoHistoryIndex = -1;
        AddUndoHistoryFrame;
        RecalculateWidth;
    }
    
    // Call this after changing "lines".
    private void AddUndoHistoryFrame(bool isTyping = false)() nothrow
    {
        if (undoHistoryIndex >= 0 && lines == undoHistory[undoHistoryIndex].Lines)
            return;
        
        if (!isTyping || 
            undoHistoryIndex != undoHistory.length - 1 || 
            !undoHistory[undoHistoryIndex].IsTypedText)
        {
            undoHistoryIndex++;
        }
        
        undoHistory = undoHistory[0 .. undoHistoryIndex] ~ new UndoFrame(isTyping);
    }
    
    public void Undo() nothrow
    {
        if (undoHistoryIndex <= 0)
            return;
        
        undoHistoryIndex--;
        undoHistory[undoHistoryIndex].Load;
    }
    
    public void Redo() nothrow
    {
        if (undoHistoryIndex >= undoHistory.length - 1)
            return;
        
        undoHistoryIndex++;
        undoHistory[undoHistoryIndex].Load;
    }
    
    public override StringReference TextAt(const int lineNumber, const int start, const int length, const int screenLine) const @nogc nothrow
    {
        if (lineNumber >= lines.length)
            return "";
        
        const text = lines[lineNumber].toUtf8Slice;
        const textLength = text.intLength;
        
        if (lineNumber > 0 && lines[lineNumber].length == 0)
            return "";
        
        auto prompt = Prompt.toUtf8Slice;
        auto promptLength = prompt.intLength;
        
        if (start >= promptLength + textLength)
            return "";
        
        static char[BufferItem.MaxTemporaryTextWidth] destination;
        int destinationPosition = 0;
        int left = start;
        
        if (left >= promptLength)
            left -= promptLength;
        else
        {
            const copyLength = promptLength - left;
            
            if (lineNumber > 0)
                destination[0 .. copyLength] = ' ';
            else
            {
                const copyText = prompt[left .. $];
                destination[0 .. min($, copyText.length)] = copyText[0 .. min($, destination.length)];
            }
            
            destinationPosition = copyLength;
            left = 0;
        }
        
        int remainingLength = length - promptLength;
        if (remainingLength > 0)
        {
            const copyLength = min(textLength - left, remainingLength);
            
            if (acceptPrompt !is null && acceptPrompt.IsHidden)
                destination[destinationPosition .. min($, destinationPosition + copyLength)] = '*';
            else
            {
                const copyText = text[left .. left + copyLength];
                destination[destinationPosition .. min($, destinationPosition + copyText.length)] = copyText[0 .. min($, destination.length - destinationPosition)];
            }
            
            destinationPosition += copyLength;
        }
        
        return destination.toUtf8Slice[0 .. min(length, destinationPosition)];
    }
    
    public override int LineCount() const @nogc nothrow => lines.intLength;
    
    public bool isMultiLine() const @nogc nothrow => lines.intLength > 1;
    
    private auto widthInCharacters = 0;
    public override int WidthInCharacters() const @nogc nothrow => widthInCharacters;
    
    private void RecalculateWidth() @nogc nothrow
    {
        auto width = 0;
        foreach (line; lines)
            width = max(width, Indentation + line.toUtf8Slice.intLength);
        
        widthInCharacters = width;
    }
    
    // Return rubbish for this.  It can't be collected and so is a 
    // waste of time maintaining a count for it.
    public override size_t IndicativeTotalSize() const @nogc nothrow => 0;
    
    public override string CopyWholeItem() const nothrow => Text;
    
    private auto basePrompt = "SQL>";
    public string BasePrompt() const @nogc nothrow => basePrompt;
    public void BasePrompt(string value) @nogc nothrow 
    {
        auto utf8 = value.toUtf8Slice;
        basePrompt = utf8[0 .. min(utf8.length, BufferItem.MaxTemporaryTextWidth)];
        
        cachedTimePromptLength = promptTimePrefixLength + basePrompt.intLength;
        cachedTimePrompt[promptTimePrefixLength .. cachedTimePromptLength] = basePrompt;
    }
    
    private bool isPromptTimeOn = false;
    public bool IsPromptTimeOn() const @nogc nothrow => isPromptTimeOn;
    public void IsPromptTimeOn(bool value) @nogc nothrow { isPromptTimeOn = value; }
    
    enum promptTimePrefixLength                                     = "00:00:00 ".intLength;
    private char[BufferItem.MaxTemporaryTextWidth] cachedTimePrompt = "00:00:00 SQL>";
    private int cachedTimePromptLength                              = "00:00:00 SQL>".intLength;
    
    private SysTime promptTime;
    
    // This is separate to Prompt() because Clock.currTime is non-@nogc?
    public void UpdatePromptTimeIfNecessary()
    {
        if (!IsPromptTimeOn)
            return;
    
        auto now = Clock.currTime;
        if (promptTime == now)
            return;
        
        cachedTimePrompt[0] = cast(char)(now.hour   / 10 + 48);
        cachedTimePrompt[1] = cast(char)(now.hour   % 10 + 48);
        
        cachedTimePrompt[3] = cast(char)(now.minute / 10 + 48);
        cachedTimePrompt[4] = cast(char)(now.minute % 10 + 48);
        
        cachedTimePrompt[6] = cast(char)(now.second / 10 + 48);
        cachedTimePrompt[7] = cast(char)(now.second % 10 + 48);
    }
    
    public StringReference Prompt() const @nogc nothrow
    { 
        if (acceptPrompt !is null)
            return acceptPrompt.Prompt;
        
        if (IsPromptTimeOn)
            return cachedTimePrompt[0 .. cachedTimePromptLength];
        else
            return BasePrompt;
    }
    
    public auto Indentation() const @nogc nothrow => Prompt.intLength;
    
    public StringReference IndentationSpace(const size_t lineNumber) @nogc nothrow const
    {
        static char[BufferItem.MaxTemporaryTextWidth] allBlanks = ' ';
        static char[BufferItem.MaxTemporaryTextWidth] indentationPlaceholder = ' ';
        
        if (!Program.Settings.IsPromptNumberingOn || Indentation < 3)
            return allBlanks[0 .. Indentation];
        
        auto charactersWritten = toStringEmplace!3(lineNumber + 1, indentationPlaceholder).length;
        indentationPlaceholder[charactersWritten .. Indentation] = ' ';
        return indentationPlaceholder[0 .. Indentation];
    }
    
    private CommandHistory mainCommandHistory;
    private CommandHistory currentCommandHistory;
    private CommandHistory[string] commandHistoriesByAcceptPromptName;
    
    public auto CommandHistoryDescending() @nogc nothrow => currentCommandHistory.HistoryDescending;
    
    public void ClearCommandHistory() @nogc nothrow { currentCommandHistory.Clear; }
    
    public void PreviousCommandInHistory()
    {
        auto previous = currentCommandHistory.MovePrevious;
        
        if (previous is null)
            return;
        
        currentCommandHistory.AddCommand!(currentCommandHistory.CurrentLocation.Keep)(Text);
        
        Clear;
        ResetText(previous);
    }
    
    public void NextCommandInHistory()
    {
        auto next = currentCommandHistory.MoveNext;
        
        // Null means "no change".
        // "" means "advanced past the last element".
        if (next is null)
            return;
        
        currentCommandHistory.AddCommand!(currentCommandHistory.CurrentLocation.Keep)(Text);
        
        Clear;
        ResetText(next);
    }
    
    private auto isInsertModeOn = false;
    public int IsInsertModeOn() const @nogc nothrow => isInsertModeOn;
    
    public void ToggleInsertMode() @nogc nothrow 
    {
        Program.Screen.Invalidate;
        isInsertModeOn = !isInsertModeOn;
    }
    
    private class CapturedState
    {
        private string[] lines;
        private UndoFrame[] undoHistory;
        private auto undoHistoryIndex = -1;
        private auto cursorPositionLine    = 0;
        private auto cursorPositionColumn  = 0;      
        private auto selectionStartLine    = 0;
        private auto selectionStartColumn  = 0;
        private auto selectionEndLine      = 0;
        private auto selectionEndColumn    = 0;
        
        public this() nothrow
        {
            this.lines                 = this.outer.lines.dup;
            this.undoHistory           = this.outer.undoHistory.dup;
            this.undoHistoryIndex      = this.outer.undoHistoryIndex;
            this.cursorPositionLine    = this.outer.cursorPositionLine;
            this.cursorPositionColumn  = this.outer.cursorPositionColumn;  
            this.selectionStartLine    = this.outer.selectionStartLine;
            this.selectionStartColumn  = this.outer.selectionStartColumn;
            this.selectionEndLine      = this.outer.selectionEndLine;
            this.selectionEndColumn    = this.outer.selectionEndColumn;
            this.outer.InvalidateFormatting;
        }
        
        public void Revert() @nogc nothrow
        {
            this.outer.lines                 = this.lines;
            this.outer.undoHistory           = this.undoHistory;
            this.outer.undoHistoryIndex      = this.undoHistoryIndex;
            this.outer.cursorPositionLine    = this.cursorPositionLine;
            this.outer.cursorPositionColumn  = this.cursorPositionColumn;
            this.outer.selectionStartLine    = this.selectionStartLine;
            this.outer.selectionStartColumn  = this.selectionStartColumn;
            this.outer.selectionEndLine      = this.selectionEndLine;
            this.outer.selectionEndColumn    = this.selectionEndColumn;
            this.outer.InvalidateFormatting;
        }
    }
    
    
    private AcceptPrompt acceptPrompt;
    private CapturedState capturedState;
    
    public void SetAcceptPrompt(AcceptPrompt prompt)
    {
       capturedState = new CapturedState;
       acceptPrompt = prompt;
       Clear;
       ClearUndoHistory;
       currentCommandHistory = commandHistoriesByAcceptPromptName.require(prompt.Name, new CommandHistory);
    }
    
    public bool HasAcceptPrompt() @nogc nothrow => acceptPrompt !is null;
    
    public bool CheckPressAnyKey()
    {
        if (acceptPrompt is null)
            return false;
        
        if (acceptPrompt.Content != AcceptPrompt.ContentType.PressAnyKey)
            return false;
        
        acceptPrompt.SetResult(null);
        ClearAcceptPrompt;
        return true;
    }
    
    public FormattedText[] formattedLines;
    private bool isFormattingValid = false;
    
    public void InvalidateFormatting() @nogc nothrow { isFormattingValid = false; }
    
    public void RefreshFormatting()
    {
        if (isFormattingValid)
            return;
        
        isFormattingValid = true;
        
        auto isMultiLineCommand = false;
        foreach (line; lines)
            if (Interpreter.IsMultiLineCommand(line) || Interpreter.StartsWithCommandWord!("EXEC", "EXECUTE")(line))
            {
                isMultiLineCommand = true;
                break;
            }
        
        if (isMultiLineCommand)
            formattedLines = Program.Syntax.Highlight(lines, cursorPositionLine, cursorPositionColumn);
        else
        {
           formattedLines = null;
           foreach (line; lines)
               formattedLines ~= [FormattedText(line, NamedColor.Normal, FontStyle.Normal, 255)];
        }
    }
        
    public FormattedText.Span[] FormattedTextAt(
        const int lineNumber, 
        const int start, 
        const int width, 
        const int screenLine) const @nogc
    {
        if (lineNumber >= formattedLines.length)
            return null;
        
        const prompt = Prompt.toUtf8Slice;
        const int promptWidth = prompt.intLength;
        const sourceLine = formattedLines[lineNumber];
        
        if (start >= prompt.length + sourceLine.Text.toUtf8Slice.length)
            return null;
        
        static FormattedText.Span[128] spans;
        size_t spanCount = 0;
        
        const promptEnd = min(start + width, promptWidth);
        if (start < promptEnd)
        {
            if (lineNumber == 0)
                spans[spanCount] = FormattedText.Span(prompt[start .. promptEnd], 0, NamedColor.Normal, FontStyle.Normal, Program.Settings.PromptOpacity);
            else
                spans[spanCount] = FormattedText.Span(IndentationSpace(lineNumber)[start .. promptEnd], 0, NamedColor.Normal, FontStyle.Normal, Program.Settings.PromptNumbersOpacity);
            
            spanCount++;
        }
        
        const screenLeft  = start - promptWidth;
        const screenRight = start + width - promptWidth;
        
        if (acceptPrompt !is null && acceptPrompt.IsHidden)
        {
            const starsStart = max(0, screenLeft);
            const starsEnd   = min(screenRight, cast(int)sourceLine.Text.toUtf8Slice.intLength);
            
            if (starsEnd > starsStart)
            {
                static immutable char[BufferItem.MaxTemporaryTextWidth] stars  = '*';            
                spans[spanCount] = FormattedText.Span(stars[0 .. starsEnd - starsStart], starsStart + promptWidth - start, NamedColor.Normal, FontStyle.Normal, 255);
                spanCount++;
            }
            
            return spans[0 .. spanCount];
        }
        
        foreach (span; formattedLines[lineNumber].Spans)
        {
            const textStart = max(screenLeft,  cast(int)span.StartColumn);
            const textEnd   = min(screenRight, cast(int)span.StartColumn + cast(int)span.Text.intLength);
            
            if (textStart >= textEnd)
                continue;
            
            spans[spanCount] = FormattedText.Span(sourceLine.Text.toUtf8Slice[textStart .. textEnd], textStart + promptWidth - start, span.Color, span.Style, span.Opacity);
            spanCount++;
            
            if (spanCount >= spans.length)
            {
                // Patch up the last entry so the formatting may be lost, but the text isn't.
                const oldStart = spans[$ - 1].StartColumn;
                const left = oldStart - promptWidth + start;
                spans[$ - 1] = FormattedText.Span(sourceLine.Text.toUtf8Slice[left .. $], oldStart, NamedColor.Normal, FontStyle.Normal, 255);
                return spans;
            }
        }
        
        return spans[0 .. spanCount];
    }
    
    public void Clear() nothrow
    {
        lines = new string[1];
        MoveCursorTo(0, 0);
        AddUndoHistoryFrame;
        RecalculateWidth;
        InvalidateFormatting;
    }
    
    private bool IsTextSelected() const @nogc nothrow =>
        selectionStartLine   != selectionEndLine || 
        selectionStartColumn != selectionEndColumn;
    
    public bool IsLineSelected(const int lineNumber) const =>
        selectionStartLine <= lineNumber && lineNumber <= selectionEndLine;
    
    public int SelectionStartOnLine(const int lineNumber) const
    {
        if (lineNumber == selectionStartLine)
            return Indentation + selectionStartColumn;
        
        return Indentation;
    }
    
    public int SelectionEndOnLine(const int lineNumber) const
    {
        if (lineNumber == selectionEndLine)
            return Indentation + selectionEndColumn;
        
        return Indentation + lines[lineNumber].toUtf8Slice.intLength + 1;
    }
    
    public string SelectedText() const
    {
        if (selectionStartLine == selectionEndLine)
            return lines[selectionStartLine].toUtf8Slice[selectionStartColumn .. selectionEndColumn];
        
        auto selectedText = appender!string;
        
        selectedText.put(lines[selectionStartLine].toUtf8Slice[selectionStartColumn .. $]);
        selectedText.put(lineEnding);
        
        foreach (line; selectionStartLine + 1 .. selectionEndLine)
        {
            selectedText.put(lines[line]);
            selectedText.put(lineEnding);
        }
        
        selectedText.put(lines[selectionEndLine].toUtf8Slice[0 .. selectionEndColumn]);
               
        return selectedText.data;
    }
    
    public string Text() const nothrow
    {
        auto text = appender!string;
        
        foreach (lineNumber, line; lines)
        {
            if (lineNumber > 0)
                text.put(lineEnding);
            
            text.put(line);
        }
        
        return text.data;
    }
    
    public bool DeleteSelection() nothrow
    {
        if (!IsTextSelected)
            return false;
        
        auto textBeforeSelection = lines[selectionStartLine].toUtf8Slice[0 .. selectionStartColumn];
        auto textAfterSelection  = lines[selectionEndLine].toUtf8Slice[selectionEndColumn .. $];
        
        lines[selectionStartLine] = textBeforeSelection ~ textAfterSelection;
        
        if (selectionEndLine > selectionStartLine)
            lines = lines[0 .. selectionStartLine + 1] ~ lines[selectionEndLine + 1 .. $];
        
        selectionEndLine     = selectionStartLine;
        selectionEndColumn   = selectionStartColumn;
        cursorPositionLine   = selectionStartLine;
        cursorPositionColumn = selectionStartColumn;
        
        AddUndoHistoryFrame;
        RecalculateWidth;
        InvalidateFormatting;
        return true;
    }
    
    public void ResetSelection() @nogc nothrow
    {
        if (selectionEndLine     == cursorPositionLine && 
            selectionEndColumn   == cursorPositionColumn && 
            selectionStartLine   == cursorPositionLine && 
            selectionStartColumn == cursorPositionColumn)
            return;
        
        Program.Screen.Invalidate;
        
        selectionEndLine     = cursorPositionLine;
        selectionEndColumn   = cursorPositionColumn;
        selectionStartLine   = cursorPositionLine;
        selectionStartColumn = cursorPositionColumn;
        InvalidateFormatting;
    }
    
    public void MoveSelectedText(const int newLine, const int newColumn)
    {
        const selectionStartOffset = GetOffsetFrom(selectionStartLine, selectionStartColumn);
        const selectionEndOffset   = GetOffsetFrom(selectionEndLine, selectionEndColumn);
        auto targetOffset          = GetOffsetFrom(newLine, newColumn);
        
        if (selectionStartOffset <= targetOffset && targetOffset < selectionEndOffset)
            return;
        
        const oldText = Text.toUtf8Slice;
        const selectedText = oldText[selectionStartOffset .. selectionEndOffset];
        
        if (targetOffset >= selectionEndOffset)
            targetOffset -= selectedText.intLength;
        
        auto newText = oldText[0 .. selectionStartOffset] ~ oldText[selectionEndOffset .. $];
        newText = newText.toUtf8Slice[0 .. targetOffset] ~ selectedText ~ newText.toUtf8Slice[targetOffset .. $];
        
        ResetText(newText);
        
        immutable newSelectionStart = GetLocationFromOffset(targetOffset);
        immutable newSelectionEnd   = GetLocationFromOffset(targetOffset + selectedText.intLength);
        
        SelectInternal(
            newSelectionStart.line, 
            newSelectionStart.column, 
            newSelectionEnd.line, 
            newSelectionEnd.column, 
            newSelectionEnd.line, 
            newSelectionEnd.column);
        
        AddUndoHistoryFrame;
        RecalculateWidth;
        InvalidateFormatting;
    }
    
    public void AddCharacter(const dchar character)
    {
        auto overwriteNextCharacter = !DeleteSelection && isInsertModeOn;
        
        if (cursorPositionColumn == lines[cursorPositionLine].toUtf8Slice.length)
        {
            lines[cursorPositionLine] ~= character.to!string;
        }
        else
        {
            auto followingTextStart = overwriteNextCharacter ? cursorPositionColumn + 1 : cursorPositionColumn;
        
            lines[cursorPositionLine] = lines[cursorPositionLine].toUtf8Slice[0 .. cursorPositionColumn] ~ 
                                        character.to!string ~ 
                                        lines[cursorPositionLine].toUtf8Slice[followingTextStart .. $];
        }
        
        cursorPositionColumn++;
        ResetSelection;
        AddUndoHistoryFrame!true;
        RecalculateWidth;
        InvalidateFormatting;
    }
    
    public void ResetText(const string newText)
    {
        lines = newText.length == 0 ? [""] : newText.splitLines;
        cursorPositionLine   = lines.intLength - 1;
        cursorPositionColumn = lines[cursorPositionLine].toUtf8Slice.intLength;
        ResetSelection;
        Program.Buffer.ScrollScreenToBottom;
        InvalidateFormatting;
    }
    
    public void AddText(const string newText)
    {
        if (newText.length == 0)
            return;
        
        DeleteSelection;
        
        auto newTextSimple = newText.strip(" ");
        
        auto returnRequired = newTextSimple.length > 0 && newTextSimple[$ - 1] == '\n';
        
        auto newLines = newText.splitLines;
        
        // This is where we will want the horizontal 
        // cursor position to be after the text is copied 
        // across.  Save it for later.
        auto lastNewLineLength = newLines[$ - 1].toUtf8Slice.intLength;
        
        // Copy the remaining text on the current line 
        // to the end of the new text.
        newLines[$ - 1] ~= lines[cursorPositionLine].toUtf8Slice[cursorPositionColumn .. $];
        
        // Copy the first line of new text into the 
        // currently selected line.
        lines[cursorPositionLine] = lines[cursorPositionLine].toUtf8Slice[0 .. cursorPositionColumn] ~ 
                                    newLines[0];
        
        if (newLines.length > 1)
        {
            // Copy across the remaining new text.
            lines = lines[0 .. cursorPositionLine + 1] ~
                    newLines[1 .. $] ~ 
                    lines[cursorPositionLine + 1 .. $];
        }
        
        cursorPositionLine = cursorPositionLine + newLines.intLength - 1;
        
        if (newLines.length == 1)
            cursorPositionColumn += lastNewLineLength;
        else
            cursorPositionColumn = lastNewLineLength;
        
        ResetSelection;
        AddUndoHistoryFrame;
        RecalculateWidth;
        InvalidateFormatting;
        
        Program.Buffer.ScrollScreenToBottom;
        
        if (returnRequired && !IsInFindMode)
            Return(false, false);
    }
    
    public void Tab()
    {
        if (selectionStartLine == selectionEndLine)
        {
            AddText("    ");
        }
        else
        {
            foreach (lineIndex; selectionStartLine .. selectionEndLine + 1)
                lines[lineIndex] = "    " ~ lines[lineIndex];
            
            selectionStartColumn = 0;
            selectionEndColumn   = lines[selectionEndLine].toUtf8Slice.intLength;
            cursorPositionLine   = selectionEndLine;
            cursorPositionColumn = selectionEndColumn;
            AddUndoHistoryFrame;
            InvalidateFormatting;
        }
    }
    
    public void BackTab()
    {
        if (selectionStartLine == selectionEndLine)
        {
            auto newStart = max(cursorPositionColumn - 4, 0);
            
            if (newStart == cursorPositionColumn)
                return;
            
            if (lines[cursorPositionLine].toUtf8Slice[newStart .. cursorPositionColumn].all!(c => c == ' '))
            {
                lines[cursorPositionLine] = lines[cursorPositionLine].toUtf8Slice[0 .. newStart] ~ 
                                            lines[cursorPositionLine].toUtf8Slice[cursorPositionColumn .. $];
                
                AddUndoHistoryFrame;
                InvalidateFormatting;
            }
            
            MoveCursorTo(cursorPositionLine, newStart);
        }
        else
        {
            foreach (line; selectionStartLine .. selectionEndLine + 1)
            {
                immutable start = min(4, max(0, lines[line].byDchar.countUntil!(a => a != ' ')));
                lines[line] = lines[line].toUtf8Slice[start .. $];
            }
            
            selectionStartColumn = 0;
            selectionEndColumn   = lines[selectionEndLine].toUtf8Slice.intLength;
            cursorPositionLine   = selectionEndLine;
            cursorPositionColumn = selectionEndColumn;
            AddUndoHistoryFrame;
            InvalidateFormatting;
        }
    }
    
    public void ConvertCase(Flag!"toUpperCase" toUpperCase = Yes.toUpperCase)()
    {
        auto changedMade = false;
        
        foreach (lineNumber; selectionStartLine .. selectionEndLine + 1)
        {
            const start = lineNumber == selectionStartLine ? selectionStartColumn : 0;
            const end   = lineNumber == selectionEndLine   ? selectionEndColumn : lines[lineNumber].toUtf8Slice.intLength;
            
            if (start >= end)
                continue;
            
            static if (toUpperCase)
                lines[lineNumber] = lines[lineNumber].toUtf8Slice[0 .. start] ~ 
                                    lines[lineNumber].toUtf8Slice[start .. end].toUpper ~ 
                                    lines[lineNumber].toUtf8Slice[end .. $];
            else
                lines[lineNumber] = lines[lineNumber].toUtf8Slice[0 .. start] ~ 
                                    lines[lineNumber].toUtf8Slice[start .. end].toLower ~ 
                                    lines[lineNumber].toUtf8Slice[end .. $];
            
            changedMade = true;
        }
        
        if (changedMade)
        {
            AddUndoHistoryFrame;
            Program.Screen.Invalidate;
            InvalidateFormatting;
        }
    }
    
    private static bool IsIdentifierCharacter(const dchar c) pure @nogc nothrow =>
        c.IsOracleIdentifierCharacter!(ValidateCase.Either, ValidateDot.SingleWordOnly, ValidateQuote.SimpleIdentifierOnly);
    
    private auto StartOfPreviousWord() const
    {
        const text = lines[cursorPositionLine].toUtf8Slice;
        
        if (cursorPositionColumn == 0 || text.length == 0)
            return 0;
        
        int index = cursorPositionColumn - 1;
        
        if (text[index] == ' ')
        {
            const startOfSpaceOffset = text[0 .. index].byDchar.retro.countUntil!(c => c != ' ');
            if (startOfSpaceOffset < 0)
                return 0;
            
            index -= startOfSpaceOffset + 1;
        }
        
        const offset = IsIdentifierCharacter(text[index]) ? 
            text[0 .. index].byDchar.retro.countUntil!(c => !IsIdentifierCharacter(c)) : 
            text[0 .. index].byDchar.retro.countUntil!(c => IsIdentifierCharacter(c) || c == ' ');
        
        if (offset < 0)
            return 0;
        
        index -= offset;
        return index;
    }
    
    private auto StartOfNextWord() const
    {
        const text = lines[cursorPositionLine].toUtf8Slice;
        
        if (cursorPositionColumn >= text.length)
            return text.intLength;
        
        int index = cursorPositionColumn;
        
        if (text[index] != ' ')
        {
            const offset = IsIdentifierCharacter(text[index]) ? 
                text[index .. $].byDchar.countUntil!(c => !IsIdentifierCharacter(c)) : 
                text[index .. $].byDchar.countUntil!(c => IsIdentifierCharacter(c) || c == ' ');
                
            if (offset < 0)
                return text.intLength;
            
            index += offset;
        }
        
        const endOfSpaceOffset = text[index .. $].byDchar.countUntil!(c => c != ' ');
        if (endOfSpaceOffset < 0)
            return text.intLength;
        
        index += endOfSpaceOffset;
        return index;
    }
    
    private auto StartOfWord() const
    {
        if (cursorPositionColumn == 0)
            return 0;
        
        auto currentCharacter = lines[cursorPositionLine].toUtf8Slice[cursorPositionColumn - 1];
        
        int startOfWordOffset;
        if (currentCharacter.isAlphaNum || currentCharacter == '_')
            startOfWordOffset = cast(int)(
                lines[cursorPositionLine].toUtf8Slice[0 .. cursorPositionColumn]
                .byDchar
                .retro
                .countUntil!(c => !IsIdentifierCharacter(c)));
        else
            startOfWordOffset = cast(int)(
                lines[cursorPositionLine].toUtf8Slice[0 .. cursorPositionColumn]
                .byDchar
                .retro
                .countUntil!(c => IsIdentifierCharacter(c)));
            
        if (startOfWordOffset < 0)
            return 0;
        else
            return cursorPositionColumn - startOfWordOffset;
    }
    
    private auto EndOfWord() const
    {
        const text = lines[cursorPositionLine].toUtf8Slice[cursorPositionColumn .. $].toUtf8Slice;
        
        if (text.length == 0)
            return cursorPositionColumn;
        
        const character = text[0];
        
        int endOfWordOffset;
        
        if (IsIdentifierCharacter(character))
            endOfWordOffset = cast(int)text.content.byDchar.countUntil!(c => !IsIdentifierCharacter(c));
        else if (character == ' ')
            endOfWordOffset = cast(int)text.content.byDchar.countUntil!(c => c != ' ');
        else 
            endOfWordOffset = cast(int)text.content.byDchar.countUntil!(c => IsIdentifierCharacter(c));
        
        if (endOfWordOffset < 0)
            return lines[cursorPositionLine].toUtf8Slice.intLength;
        else
            return cursorPositionColumn + endOfWordOffset;
    }
    
    public void MoveCursorColumnTo(Flag!"resetSelection" resetSelection = Yes.resetSelection)(const int column) @nogc nothrow
    {   
        Program.Screen.Invalidate;
        InvalidateFormatting;
        cursorPositionColumn = min(max(0, column), lines[cursorPositionLine].toUtf8Slice.intLength);
        
        static if (resetSelection)
            ResetSelection;
    }
    
    public void MoveCursorTo(Flag!"resetSelection" resetSelection = Yes.resetSelection)(const int line, const int column) @nogc nothrow
    {
        cursorPositionLine = min(max(0, line), lines.intLength - 1);
        
        MoveCursorColumnTo!resetSelection(column);
    }
    
    public void MoveCursorToOffset(const int offset) @nogc nothrow
    {
        auto location = GetLocationFromOffset(offset);
        MoveCursorTo(location.line, location.column);
    }
    
    public void MoveCursorToLineStart() @nogc
    {
        immutable textStart = cast(int)lines[cursorPositionLine].byDchar.countUntil!(c => c != ' ');
        
        if (cursorPositionColumn == textStart)
            MoveCursorColumnTo(0);
        else
            MoveCursorColumnTo(textStart);
    }
    
    public void MoveCursorLeft() @nogc nothrow =>
        MoveCursorColumnTo(cursorPositionColumn - 1);
    
    public void MoveCursorRight() @nogc nothrow =>
        MoveCursorColumnTo(cursorPositionColumn + 1);
    
    public void MoveCursorUp() @nogc nothrow =>
        MoveCursorTo(cursorPositionLine - 1, cursorPositionColumn);
    
    public void MoveCursorDown() @nogc nothrow =>
        MoveCursorTo(cursorPositionLine + 1, cursorPositionColumn);
    
    public void MoveCursorToLineEnd() @nogc nothrow =>
        MoveCursorColumnTo(lines[cursorPositionLine].toUtf8Slice.intLength);
    
    public void MoveCursorToWordLeft() =>
        MoveCursorColumnTo(StartOfPreviousWord);
    
    public void MoveCursorToWordRight() =>
        MoveCursorColumnTo(StartOfNextWord);
    
    public void MoveCursorToTop() @nogc nothrow =>
        MoveCursorTo(0, 0);
    
    public void MoveCursorToBottom() @nogc nothrow =>
        MoveCursorTo(lines.intLength - 1, lines[$ - 1].toUtf8Slice.intLength);
    
    private void DeleteLine(int line)
    {
        if (line == lines.length - 1)
            lines = lines[0 .. $ - 1];
        else
            lines = lines[0 .. line] ~ lines[line + 1 .. $];
        
        InvalidateFormatting;
    }
    
    public void DeleteCharacterLeft()
    {
        if (DeleteSelection)
            return;
        
        if (cursorPositionColumn > 0)
        {
            lines[cursorPositionLine] = lines[cursorPositionLine].toUtf8Slice[0 .. cursorPositionColumn - 1] ~ 
                                        lines[cursorPositionLine].toUtf8Slice[cursorPositionColumn .. $];
            MoveCursorLeft;
            AddUndoHistoryFrame;
            RecalculateWidth;
            InvalidateFormatting;
            return;
        }
        
        if (cursorPositionLine == 0)
            return;
        
        cursorPositionLine--;
        auto newCursorPositionColumn = lines[cursorPositionLine].toUtf8Slice.intLength;
        
        lines[cursorPositionLine] = lines[cursorPositionLine] ~ 
                                    lines[cursorPositionLine + 1];
        
        DeleteLine(cursorPositionLine + 1);
        
        MoveCursorTo(cursorPositionLine, newCursorPositionColumn);
        AddUndoHistoryFrame;
        RecalculateWidth;
        InvalidateFormatting;
    }
    
    public void DeleteCharacterRight()
    {
        if (DeleteSelection)
            return;
        
        if (cursorPositionColumn < lines[cursorPositionLine].toUtf8Slice.length)
        {
            lines[cursorPositionLine] = lines[cursorPositionLine].toUtf8Slice[0 .. cursorPositionColumn] ~ 
                                        lines[cursorPositionLine].toUtf8Slice[cursorPositionColumn + 1.. $];
            AddUndoHistoryFrame;
            RecalculateWidth;
            InvalidateFormatting;
            return;
        }
        
        if (cursorPositionLine == lines.length - 1)
            return;
        
        lines[cursorPositionLine] = lines[cursorPositionLine] ~ 
                                    lines[cursorPositionLine + 1];
        
        DeleteLine(cursorPositionLine + 1);
        AddUndoHistoryFrame;
        RecalculateWidth;
        InvalidateFormatting;
    }
    
    public void DeleteWordLeft()
    {
        if (DeleteSelection)
            return;
        
        if (cursorPositionColumn == 0)
        {
            DeleteCharacterLeft;
            return;
        }
        
        auto startOfWord = StartOfPreviousWord;
        
        lines[cursorPositionLine] = lines[cursorPositionLine].toUtf8Slice[0 .. startOfWord] ~ 
                                    lines[cursorPositionLine].toUtf8Slice[cursorPositionColumn .. $];
        
        MoveCursorColumnTo(startOfWord);
        AddUndoHistoryFrame;
        RecalculateWidth;
        InvalidateFormatting;
    }
    
    public void DeleteWordRight()
    {
        if (DeleteSelection)
            return;
        
        if (cursorPositionColumn == lines[cursorPositionLine].toUtf8Slice.length)
        {
            DeleteCharacterRight;
            return;
        }
        
        lines[cursorPositionLine] = lines[cursorPositionLine].toUtf8Slice[0 .. cursorPositionColumn] ~ 
                                    lines[cursorPositionLine].toUtf8Slice[EndOfWord .. $];
        AddUndoHistoryFrame;
        RecalculateWidth;
        InvalidateFormatting;
    }
    
    public bool ClearAcceptPrompt() @nogc nothrow
    {
        if (acceptPrompt is null)
            return false;
        
        Program.Screen.Invalidate;
        
        acceptPrompt = null;
        capturedState.Revert;
        capturedState = null;
        currentCommandHistory = mainCommandHistory;
        return true;
    }
    
    public bool EnableFindPrompt(lazy string defaultSearchText = "")
    {
        if (acceptPrompt !is null)
            return IsInFindMode;
        
        SetAcceptPrompt(new AcceptPrompt("current_find_text", "Find>", AcceptPrompt.ContentType.Find));
        
        AddText(defaultSearchText.strip.lineSplitter.firstOrDefault("").strip);
        SelectAll;
        return true;
    }
    
    public bool IsInFindMode() const @nogc nothrow =>
        acceptPrompt !is null && acceptPrompt.Content == AcceptPrompt.ContentType.Find;
    
    public string CurrentFindText() const nothrow
    {
        if (!IsInFindMode)
            return null;
        
        return Text;
    }
    
    public void Return(bool directlyFromKeyboard, bool isShiftKeyDown)
    {
        DeleteSelection;
        
        auto text = Text;
        const originalCursorOffset = CursorOffset;
        
        if (acceptPrompt !is null)
        {
            if (IsInFindMode)
                return;
            
            currentCommandHistory.AddCommand!(CommandHistory.CurrentLocation.MoveToEnd)(text);
            acceptPrompt.SetResult(text);
            ClearAcceptPrompt;
            return;
        }
        
        if (!isShiftKeyDown && text.length == 0)
        {
            Program.Buffer.AddText(lineEnding ~ lineEnding ~ lineEnding ~ lineEnding);
            return;
        }
        
        void printLines(
            string[] commandLines, 
            int firstLine, 
            int lastLine)
        {
            // How wide should the first column be to allow for all row numbers?
            const rowHeadersWidth = lastLine.to!string.intLength;
            
            if (Interpreter.IsMultiLineCommand(commandLines[0]))
                foreach (lineNumber; firstLine .. lastLine)
                {
                    const textWithHeader = (lineNumber + 1).to!string.rightJustify(rowHeadersWidth, '0') ~ ": " ~ commandLines[lineNumber];
                    Program.Buffer.AddFormattedText(Program.Syntax.Highlight(textWithHeader));
                }
            else
                foreach (lineNumber; firstLine .. lastLine)
                {
                    const textWithHeader = (lineNumber + 1).to!string.rightJustify(rowHeadersWidth, '0') ~ ": " ~ commandLines[lineNumber];
                    Program.Buffer.AddText(textWithHeader);
                }
        }
        
        // The user may be using SQL*Plus line editing numerals.  Try to 
        // support this, but not if commands are in progress.  It's possible 
        // that these include ACCEPT commands and the user wants this value 
        // to be used.  I can't check for ACCEPT commands in the queue because 
        // they may be lazily loaded from files later.
        if (text.isNumeric && !Program.Interpreter.CommandsInProgress)
        {
            Clear;
            
            int targetLineNumber;
            try
                targetLineNumber = text.to!int - 1;
            catch (ConvException)
            {
                currentCommandHistory.AddCommand!(CommandHistory.CurrentLocation.MoveToEnd)(text);
                Program.Buffer.AddText("Invalid line number.");
                return;
            }
            
            auto lastCommandLines = currentCommandHistory.LastCommand.lineSplitter.array;
            
            Program.Buffer.AddBlankLine;
            if (targetLineNumber < 0 || targetLineNumber >= lastCommandLines.length)
            {
                currentCommandHistory.AddCommand!(CommandHistory.CurrentLocation.MoveToEnd)(text);
                Program.Buffer.AddText("Invalid line number.");
                return;
            }
            
            currentBufferLine = targetLineNumber;
            
            auto firstLine = max(0, targetLineNumber - 3);
            auto lastLine  = min(lastCommandLines.intLength, targetLineNumber + 3);
            
            printLines(lastCommandLines, firstLine, lastLine);
            return;
        }
        
        string remainingCommand;
        
        if (Interpreter.StartsWithCommandWord!("L", "LIST")(text, remainingCommand))
        {
            Clear;
            
            auto lastCommandLines = currentCommandHistory.LastCommand.lineSplitter.array;
            
            if (lastCommandLines.length == 0)
            {
                currentCommandHistory.AddCommand!(CommandHistory.CurrentLocation.MoveToEnd)(text);
                Program.Buffer.AddText("No previous command to list.");
                return;
            }
            
            auto firstParameterText = Interpreter.ConsumeToken(remainingCommand);
            int firstLine;
            
            if (firstParameterText.length == 0)
                firstLine = 0;
            else if (firstParameterText.toUpper == "LAST")
                firstLine = lastCommandLines.intLength - 1;
            else if (firstParameterText.isNumeric)
                try
                    firstLine = max(0, min(firstParameterText.to!int - 1, lastCommandLines.intLength - 1));
                catch (ConvException)
                {
                    currentCommandHistory.AddCommand!(CommandHistory.CurrentLocation.MoveToEnd)(text);
                    Program.Buffer.AddText("Invalid line number.");
                    return;
                }
            
            auto secondParameterText = Interpreter.ConsumeToken(remainingCommand);
            int lastLine;
            
            if (secondParameterText.length == 0)
                lastLine = lastCommandLines.intLength;
            else if (secondParameterText.toUpper == "LAST")
                lastLine = lastCommandLines.intLength;
            else if (secondParameterText.isNumeric)
                try
                    lastLine = max(0, min(secondParameterText.to!int, lastCommandLines.intLength));
                catch (ConvException)
                {
                    currentCommandHistory.AddCommand!(CommandHistory.CurrentLocation.MoveToEnd)(text);
                    Program.Buffer.AddText("Invalid line number.");
                    return;
                }
            
            printLines(lastCommandLines, firstLine, lastLine);
            return;
        }
        
        // In SQL*Plus the "EDIT" command would open Notepad.exe, be we already have a better 
        // editor here.  Unfortunately Interpreter cannot just call PreviousCommandInHistory 
        // because we are currently trampling over the editor at that point.  
        // 
        // Instead check here and if it is the simple command (no filename), deal with it locally.
            
        if (Interpreter.StartsWithCommandWord!("ED", "EDIT")(text, remainingCommand))
        {
            auto filename = Interpreter.ConsumeToken(remainingCommand);
            if (filename == "")
            {
                Clear;
                PreviousCommandInHistory;
                return;
            }
        }
        
        if (Interpreter.StartsWithCommandWord!("A", "APPEND")(text, remainingCommand))
        {
            Clear;
            currentCommandHistory.AppendToLastCommand(remainingCommand);
            return;
        }
        
        if (Interpreter.StartsWithCommandWord!("C", "CHANGE")(text, remainingCommand))
        {
            Clear;
            
            if (remainingCommand.length == 0)
                return;
            
            if (remainingCommand[0] != '/')
            {
                commands.CommandUsage.OutputFor!(commands.Commands.ChangeTextInBufferDummySignature);
                return;
            }
            
            auto parameters = remainingCommand[1 .. $].splitter('/');
            auto oldText = parameters.empty ? "" : parameters.front;
            
            parameters.popFront;
            
            auto newText = parameters.empty ? "" : parameters.front;
            
            currentCommandHistory.ReplaceTextInLastCommand(oldText, newText);
            return;
        }
        
        if (Interpreter.StartsWithCommandWord!"DEL"(text, remainingCommand))
        {
            Clear;
            
            if (remainingCommand.length == 0)
            {
                commands.CommandUsage.OutputFor!(commands.Commands.DeleteLinesFromTheBufferDummySignature);
                return;
            }
            
            auto startParameter = Interpreter.ConsumeToken(remainingCommand);
            auto endParameter   = Interpreter.ConsumeToken(remainingCommand);
            
            auto firstLineNumber = 1;
            auto lastLineNumber = 1;
            const totalLines = currentCommandHistory.LastCommand.lineSplitter.array.intLength;
            
            try
                firstLineNumber = startParameter.to!int - 1;
            catch (ConvException)
            {
                if (startParameter == "*")
                    firstLineNumber = currentBufferLine;
                else if (startParameter.toUpper == "LAST")
                    firstLineNumber = totalLines - 1;
                else
                {
                    commands.CommandUsage.OutputFor!(commands.Commands.DeleteLinesFromTheBufferDummySignature);
                    return;
                }
            }
            
            try
                lastLineNumber = endParameter.to!int - 1;
            catch (ConvException)
            {
                if (endParameter == "*")
                    lastLineNumber = currentBufferLine;
                else if (endParameter.toUpper == "LAST")
                    lastLineNumber = totalLines - 1;
                else
                    lastLineNumber = firstLineNumber;
            }
            
            firstLineNumber = min(totalLines, max(0, firstLineNumber   ));
            lastLineNumber  = min(totalLines, max(0, lastLineNumber + 1));
            
            currentCommandHistory.DeleteLinesInLastCommand(firstLineNumber, lastLineNumber);
            return;
        }
        
        if (directlyFromKeyboard && 
            !isShiftKeyDown && 
            text.length >= lineEnding.length && text[$ - lineEnding.length .. $] == lineEnding &&
            cursorPositionLine == lines.length - 1 && 
            cursorPositionColumn == lines[cursorPositionLine].toUtf8Slice.length)
        {
            currentCommandHistory.AddCommand!(CommandHistory.CurrentLocation.MoveToEnd)(Text);
            Clear;
            return;
        }
        
        auto isLaterText = false;
        laterTextCheckLoop: 
        for (auto lineNumber = cursorPositionLine; lineNumber < lines.length; lineNumber++)
        {
            auto startColumn = lineNumber == cursorPositionLine ? cursorPositionColumn : 0;
            
            for (auto column = startColumn; column < lines[lineNumber].toUtf8Slice.length; column++)
            {
                if (!isWhite(lines[lineNumber].toUtf8Slice[column]))
                {
                    isLaterText = true;
                    break laterTextCheckLoop;
                }
            }
        }
        
        if (!isShiftKeyDown && !isLaterText)
        {
            const executedCommandResult = Program.Interpreter.Execute!(CommandSource.User)(text);
            
            if (executedCommandResult.ExecutedCommands.length > 0)
            {
                currentCommandHistory.AddCommand!(CommandHistory.CurrentLocation.MoveToEnd)(executedCommandResult.ExecutedCommands);
                Clear;
                ClearUndoHistory;
                AddText(executedCommandResult.TrailingIncompleteCommands);
                MoveCursorToOffset(originalCursorOffset - executedCommandResult.ExecutedCommands.intLength);
                return;
            }
        }
        
        scope (exit) 
        {
            AddUndoHistoryFrame;
            RecalculateWidth;
            InvalidateFormatting;
        }
        
        auto cursorPositionValid = true;
        
        immutable newLineIndentation = 
            ' '.repeat(
            (lines[cursorPositionLine].toUtf8Slice[0 .. cursorPositionColumn].byDchar.countUntil!(c => c != ' ') / 4) * 4)            
            .to!string;
        
        lines = lines[0 .. cursorPositionLine] ~                                          // Any previous lines
                lines[cursorPositionLine].toUtf8Slice[0 .. cursorPositionColumn] ~        // First half of this line
                (newLineIndentation ~                                                     // New Line Indentation
                    lines[cursorPositionLine].toUtf8Slice[cursorPositionColumn .. $]) ~   // Second half of this line
                lines[min($, cursorPositionLine + 1) .. $];                               // Any following lines            
        
        MoveCursorTo(cursorPositionLine + 1, newLineIndentation.intLength);
    }
    
    public void SelectAll() @nogc nothrow
    {
        selectionStartLine = 0;
        selectionStartColumn = 0;
        selectionEndLine = lines.intLength - 1;
        selectionEndColumn = lines[selectionEndLine].toUtf8Slice.intLength;
        cursorPositionLine = selectionEndLine;
        cursorPositionColumn = selectionEndColumn;
        InvalidateFormatting;
    }
    
    public void SelectAbsolute(
        const int startLine, 
        const int startColumn, 
        const int endLine, 
        const int endColumn, 
        const int cursorLine, 
        const int cursorColumn) @nogc nothrow
    {
        SelectInternal(
            startLine, 
            startColumn  - cast(int)Indentation, 
            endLine, 
            endColumn    - cast(int)Indentation, 
            cursorLine, 
            cursorColumn - cast(int)Indentation);
    }
    
    public void SelectInternal(
        const int startLine, 
        const int startColumn, 
        const int endLine, 
        const int endColumn, 
        const int cursorLine, 
        const int cursorColumn) @nogc nothrow
    {
        auto newSelectionStartLine   = max(0, min(lines.intLength - 1,                                startLine));
        auto newSelectionStartColumn = max(0, min(lines[newSelectionStartLine].toUtf8Slice.intLength, startColumn));
        auto newSelectionEndLine     = max(0, min(lines.intLength - 1,                                endLine));
        auto newSelectionEndColumn   = max(0, min(lines[newSelectionEndLine].toUtf8Slice.intLength,   endColumn));
        auto newCursorPositionLine   = max(0, min(lines.intLength - 1,                                cursorLine));
        auto newCursorPositionColumn = max(0, min(lines[newCursorPositionLine].toUtf8Slice.intLength, cursorColumn));
        
        if (selectionStartLine   == newSelectionStartLine && 
            selectionStartColumn == newSelectionStartColumn && 
            selectionEndLine     == newSelectionEndLine && 
            selectionEndColumn   == newSelectionEndColumn && 
            cursorPositionLine   == newCursorPositionLine && 
            cursorPositionColumn == newCursorPositionColumn)
            return;
        
        selectionStartLine   = newSelectionStartLine;
        selectionStartColumn = newSelectionStartColumn;
        selectionEndLine     = newSelectionEndLine;
        selectionEndColumn   = newSelectionEndColumn;
        cursorPositionLine   = newCursorPositionLine;
        cursorPositionColumn = newCursorPositionColumn;
        
        Program.Screen.Invalidate;
        InvalidateFormatting;
    }
    
    private void ExtendSelection(void delegate() moveCursorAction)
    {
        int otherPositionLine;
        int otherPositionColumn;
    
        if (cursorPositionLine   == selectionStartLine  &&
            cursorPositionColumn == selectionStartColumn)
        {
            otherPositionLine   = selectionEndLine;
            otherPositionColumn = selectionEndColumn;
        }
        else
        {
            otherPositionLine   = selectionStartLine;
            otherPositionColumn = selectionStartColumn;
        }
        
        moveCursorAction();
        
        if (cursorPositionLine < otherPositionLine || 
               (cursorPositionLine  == otherPositionLine &&
                cursorPositionColumn < otherPositionColumn))
        {
            selectionStartLine   = cursorPositionLine;
            selectionStartColumn = cursorPositionColumn;
            selectionEndLine     = otherPositionLine;
            selectionEndColumn   = otherPositionColumn;
        }
        else
        {
            selectionStartLine   = otherPositionLine;
            selectionStartColumn = otherPositionColumn;
            selectionEndLine     = cursorPositionLine;
            selectionEndColumn   = cursorPositionColumn;
        }
    }
    
    public void ExtendSelectionUp()
    {
        ExtendSelection(&MoveCursorUp);
    }
    
    public void ExtendSelectionDown()
    {
        ExtendSelection(&MoveCursorDown);
    }
    
    public void ExtendSelectionLeft()
    {
        ExtendSelection(&MoveCursorLeft);
    }
    
    public void ExtendSelectionRight()
    {
        ExtendSelection(&MoveCursorRight);
    }
    
    public void ExtendSelectionToLineStart()
    {
        ExtendSelection(&MoveCursorToLineStart);
    }
    
    public void ExtendSelectionToLineEnd()
    {
        ExtendSelection(&MoveCursorToLineEnd);
    }
    
    public void ExtendSelectionToWordLeft()
    {
        ExtendSelection(&MoveCursorToWordLeft);
    }
    
    public void ExtendSelectionToWordRight()
    {
        ExtendSelection(&MoveCursorToWordRight);
    }
    
    public void ExtendSelectionToTop()
    {
        ExtendSelection(&MoveCursorToTop);
    }
    
    public void ExtendSelectionToBottom()
    {
        ExtendSelection(&MoveCursorToBottom);
    }
}
