module buffer;

import std.stdio : File;
import std.array: array;
import std.algorithm : max, min, find, countUntil;
import std.ascii : isWhite;
import std.conv : to;
import std.range : appender, retro;
import std.string : lineSplitter, endsWith, strip, toUpper, lineSplitter;
import std.typecons : tuple;

import program;
import range_extensions;

public static class MemorySettings
{
    // Set this is to control how much memory is used by the buffer.
    public immutable static CollectThreshold = 15 * 1024 * 1024;
    
    // My memory estimations are apparently WAY off (like x10 or more).
    // I have no clue why.  Compensate by setting this 10 smaller than 
    // what I actually mean.  I hate my life.
    public immutable static MaxTableSize = 10 * 1024 * 1024;
    public immutable static TrimTableSize = 7 * 1024 * 1024;
}

public final class Buffer
{
    private BufferItem[] items;
    
    // The item that may still be changing.
    private TableBufferItem activeTableItem;
    public TableBufferItem ActiveTableItem() @nogc nothrow
    {
        return activeTableItem;
    }
    
    public void ActiveTableItem(TableBufferItem newItem) @nogc nothrow
    {
        if (activeTableItem !is null)
        {
            indicativeTotalSizeOfAllElementsExceptActive += activeTableItem.IndicativeTotalSize;
            totalLinesOfAllElementsExceptActive += activeTableItem.LineCount;
            widthInCharacters = max(widthInCharacters, activeTableItem.WidthInCharacters);
        }
        
        activeTableItem = newItem;
    }
    
    // The end of the linked list.
    private EditorBufferItem editorItem;
    public auto EditorItem() @nogc nothrow { return editorItem; }
    
    // Where has the screen been scrolled to?  This is the first item
    // visible.  However, it may not be fully visible (the top
    // and/or bottom could be hidden).
    private auto screenFirstIndex = 0;
    public BufferItem ScreenFirst() @nogc nothrow { return items[screenFirstIndex]; }
    
    // This is the portion of the first screen item than cannot be seen 
    // off the top of the screen.
    private auto screenFirst_LineNumberOffset = 0;
    public auto ScreenFirst_LineNumberOffset() @nogc nothrow { return screenFirst_LineNumberOffset; }
    
    
    public this(EditorBufferItem editor)
    {
        ActiveTableItem = null;
        editorItem = editor;
        screenFirstIndex = 0;
        screenFirst_LineNumberOffset = 0;
        
        items = [editor];
    }
    
    private File spoolFile;
    public auto IsSpooling() nothrow { return spoolFile.isOpen; }
    
    public void StartSpooling(string filename)
    {
        import std.path : dirName, isValidPath;
        import std.file : exists;
        
        if (!filename.isValidPath)
            throw new RecoverableException("Invalid path: " ~ filename ~ ".");
        
        auto baseDirectory = filename.dirName;
        
        if (!baseDirectory.exists)
            throw new RecoverableException("Folder not found: " ~ baseDirectory ~ ".");
        
        try
            spoolFile = File(filename, "w");
        catch (Exception)
            throw new RecoverableException("File cannot be written to.");
    }
    
    public void Spool(StringReference text)
    {
        if (!spoolFile.isOpen)
            return;
        
        spoolFile.writeln(text);
    }
    
    public void StopSpooling()
    {
        if (!spoolFile.isOpen)
            throw new RecoverableException("Not currently spooling.");
        
        spoolFile.close;
    }
    
    
    // This is a rough counter of memory used by the buffer.
    private size_t indicativeTotalSizeOfAllElementsExceptActive = 0;
    public auto IndicativeTotalSize() const @nogc nothrow
    { 
        return indicativeTotalSizeOfAllElementsExceptActive + 
               (activeTableItem is null ? 0 : activeTableItem.IndicativeTotalSize) + 
               editorItem.IndicativeTotalSize;
    }
    
    
    private bool isActiveItemLineCountFrozen = false;
    private auto frozenActiveItemLineCount = 0;
    
    public void FreezeVerticalScrollingValues() @nogc nothrow
    {
        if (isActiveItemLineCountFrozen)
            return;
    
        frozenActiveItemLineCount = activeTableItem is null ? 0 : activeTableItem.LineCount;
        isActiveItemLineCountFrozen = true;
    }
    
    public void UnFreezeVerticalScrollingValues()
    {
        isActiveItemLineCountFrozen = false;
    }
    
    private auto ActiveTableItemLineCount() const
    {
        if (isActiveItemLineCountFrozen)
            return frozenActiveItemLineCount;
        
        if (activeTableItem is null)
            return 0;
        
        return activeTableItem.LineCount;
    }
    
    
    // This is a counter of lines in the buffer.
    private auto totalLinesOfAllElementsExceptActive = 0;
    public auto TotalLines() const @nogc nothrow
    { 
        return totalLinesOfAllElementsExceptActive + 
               ActiveTableItemLineCount + 
               editorItem.LineCount;
    }
    
    // This is a counter of lines in the buffer above the screen.
    private auto totalLinesAboveScreenFirstBufferItem = 0;
    public auto TotalLinesAboveScreenStart() const @nogc nothrow
    { 
        return totalLinesAboveScreenFirstBufferItem + 
               screenFirst_LineNumberOffset; 
    }
    
    public auto TotalLinesBelowScreenStart() const @nogc nothrow
    { 
        return TotalLines - TotalLinesAboveScreenStart;
    }
    
    private void RecalculateTotalLinesAboveScreenFirstBufferItem() @nogc nothrow
    {
        totalLinesAboveScreenFirstBufferItem = 0;
        foreach (itemIndex; 0..screenFirstIndex)
            totalLinesAboveScreenFirstBufferItem += items[itemIndex].LineCount;
    }
    
    // This is the total characters to the left of the screen when 
    // the screen has been scrolled to the right.
    private auto horizontalCharacterCountOffset = 0;
    public auto HorizontalCharacterCountOffset() const @nogc nothrow { return horizontalCharacterCountOffset; }
    
    // This is the total horizontal character count.
    private auto widthInCharacters = 0;
    public auto WidthInCharacters() const @nogc nothrow
    { 
        return max(
            widthInCharacters, 
            (activeTableItem is null ? 0 : activeTableItem.WidthInCharacters), 
            editorItem.WidthInCharacters);
    }
    
    // These are populated with the screen portal dimensions.
    private auto screenHeightInLines = 0;
    public auto ScreenHeightInLines() const @nogc nothrow { return screenHeightInLines; }
    public void ScreenHeightInLines(const int value) @nogc nothrow { screenHeightInLines = value; }
    
    private auto screenWidthInCharacters = 0;
    public auto ScreenWidthInCharacters() const @nogc nothrow { return screenWidthInCharacters; }
    public void ScreenWidthInCharacters(const int value) @nogc nothrow { screenWidthInCharacters = value; }
    
    public void BalanceExtraColumnSpace() @nogc nothrow
    {
        foreach (item; items)
        {
            auto table = cast(TableBufferItem)item;
            
            if (table is null)
                continue;
            
            table.BalanceExtraColumnSpaceAndRecalculateFullWidth;
        }
    }
    
    public enum SelectionTypes { EditorOnly, BufferOnly, EditorAndBuffer }
    
    private auto selectionType = SelectionTypes.EditorOnly;
    private auto selectionStartIndex = 0;
    private auto selectionStartLine = 0;
    private auto selectionStartLeftColumn = 0;
    private auto selectionStartRightColumn = 0;
    private auto selectionEndIndex = 0;
    private auto selectionEndLine = 0;
    private auto selectionEndLeftColumn = 0;
    private auto selectionEndRightColumn = 0;
    
    // This is populated when the selected text does not line up with the screen.
    // This might be because the text is partially or totally obscured.    
    private auto selectionOverrideText = ""; 
    
    // These are populated when a search action finds hits in query results.  This 
    // is because those hits may not be visible on the screen due to column sizing.
    // These allow a subsequent (or reverse) search to jump to the next result correctly.
    private int selectionFindColumnIndex;
    private int selectionFindColumnMatchStart;
    private int selectionFindColumnMatchEnd;
    
    public auto SelectionType() const { return selectionType; }
    public auto SelectionType(SelectionTypes value) { selectionType = value; }
    
    public auto SelectionTopIndex() const { return min(selectionStartIndex, selectionEndIndex); }
    
    public auto SelectionBottomIndex() const { return max(selectionStartIndex, selectionEndIndex); }
    
    public auto SelectionTopLine() const 
    {
        if (selectionStartIndex < selectionEndIndex)
            return selectionStartLine;
        
        if (selectionEndIndex < selectionStartIndex)
            return selectionEndLine;
        
        return min(selectionStartLine, selectionEndLine); 
    }
    
    public auto SelectionBottomLine() const 
    {
        if (selectionStartIndex < selectionEndIndex)
            return selectionEndLine;
        
        if (selectionEndIndex < selectionStartIndex)
            return selectionStartLine;
        
        return max(selectionStartLine, selectionEndLine); 
    }
    
    public auto SelectionLeft() const { return min(selectionStartLeftColumn, selectionEndLeftColumn); }
    
    public auto SelectionRight() const { return max(selectionStartRightColumn, selectionEndRightColumn); }
    
    public auto SelectionLeftScreen() const 
    {
        return max(0, min(screenWidthInCharacters, SelectionLeft - horizontalCharacterCountOffset)); 
    }
    
    public auto SelectionRightScreen() const
    {
        return max(0, min(screenWidthInCharacters, SelectionRight - horizontalCharacterCountOffset)); 
    }
    
    public struct Location
    {
        const int BufferItemIndex;
        const BufferItem Item;
        const int Line;
    }
    
    public auto LocationAtScreenLine(bool constrainToBuffer)(const int screenLine) const @nogc nothrow
    {
        int itemIndex = screenFirstIndex;
        int lineOffset = screenFirst_LineNumberOffset + screenLine;
        
        foreach (item; items[screenFirstIndex .. $])
        {
            if (lineOffset < item.LineCount)
                return Location(itemIndex, item, lineOffset);
            
            itemIndex++;
            lineOffset -= item.LineCount;
        }
        
        static if (constrainToBuffer)
        {
            const item = items[$ - 1];
            return Location(items.intLength - 1, item, item.LineCount); 
        }
        else
            return Location();
    }
    
    enum SelectingMethods { BandBox, ByWord, ByLine }
    
    SelectingMethods selectingMethod;
    
    public void SetSelectionStartScreen(
        const int screenLine, 
        const int screenLeftColumn, 
        const int screenRightColumn, 
        SelectingMethods selectingMethod, 
        const string overrideText = "") @nogc nothrow
    {
        this.selectingMethod = selectingMethod;
        auto location = LocationAtScreenLine!true(screenLine);
        
        SetSelectionStart(
            location.BufferItemIndex, 
            location.Line, 
            horizontalCharacterCountOffset + screenLeftColumn, 
            horizontalCharacterCountOffset + screenRightColumn, 
            overrideText);
    }
    
    public void SetSelectionStart(const int itemIndex, const int line, const int left, const int right, const string overrideText = "") @nogc nothrow
    {
        Program.Screen.Invalidate;
        
        selectionOverrideText = overrideText;
        selectionStartIndex  = selectionEndIndex  = itemIndex;
        selectionStartLine   = selectionEndLine   = line;
        
        selectionStartLeftColumn  = left;
        selectionStartRightColumn = right;
        selectionEndLeftColumn    = left;
        selectionEndRightColumn   = right;
        
        if (items[itemIndex] is editorItem)
        {
            selectionType = SelectionTypes.EditorOnly;
            editorItem.SelectAbsolute(
                selectionStartLine, 
                selectionStartLeftColumn, 
                selectionStartLine, 
                selectionStartRightColumn,
                selectionStartLine, 
                selectionStartRightColumn);
        }
        else
        {
            selectionType = SelectionTypes.BufferOnly;
            editorItem.ResetSelection;
        }
    }
    
    public void SetSelectionEndScreen(const int screenLine, const int screenLeftColumn, const int screenRightColumn)
    {
        auto location = LocationAtScreenLine!true(screenLine);
        int newEndLeftColumn;
        int newEndRightColumn;
        
        final switch (selectingMethod) with (SelectingMethods)
        {
            case BandBox:
                newEndLeftColumn  = horizontalCharacterCountOffset + screenLeftColumn;
                newEndRightColumn = horizontalCharacterCountOffset + screenRightColumn;
                break;
                
            case ByWord:
                const position = WholeWordAt(screenLine, screenLeftColumn);
                
                // Are we in the middle of whitespace?
                if (position.isSpace)
                {
                    newEndLeftColumn  = horizontalCharacterCountOffset + screenLeftColumn;
                    newEndRightColumn = horizontalCharacterCountOffset + screenRightColumn;
                }
                else
                {
                    // Snap to the whole word.
                    newEndLeftColumn  = horizontalCharacterCountOffset + position.start;
                    newEndRightColumn = horizontalCharacterCountOffset + position.end;
                }
                break;
                
            case ByLine:
                newEndLeftColumn = 0;
                newEndRightColumn = WidthInCharacters;
                break;
        }
        
        if (selectionEndIndex       != location.BufferItemIndex || 
            selectionEndLine        != location.Line || 
            selectionEndLeftColumn  != newEndLeftColumn || 
            selectionEndRightColumn != newEndRightColumn)
        {
            Program.Screen.Invalidate;
            
            selectionEndIndex       = location.BufferItemIndex;
            selectionEndLine        = location.Line;
            selectionEndLeftColumn  = newEndLeftColumn;
            selectionEndRightColumn = newEndRightColumn;
        }
        
        if (SelectionTopIndex < items.length - 1)
        {
            selectionType = SelectionTypes.BufferOnly;
            editorItem.ResetSelection;
        }
        else
        {
            selectionType = SelectionTypes.EditorOnly;
            
            auto startColumn = 0;
            auto endColumn = 0;
            auto cursorColumn = 0;
            
            if (selectionStartLine < selectionEndLine)
            {
                startColumn  = selectionStartLeftColumn;
                endColumn    = selectionEndRightColumn;
                cursorColumn = selectionEndRightColumn;
            }
            else if (selectionStartLine > selectionEndLine)
            {
                startColumn  = selectionEndLeftColumn;
                endColumn    = selectionStartRightColumn;
                cursorColumn = selectionEndLeftColumn;
            }
            else
            {
                startColumn = min(selectionStartLeftColumn, selectionEndLeftColumn);
                endColumn   = max(selectionStartRightColumn, selectionEndRightColumn);
                cursorColumn = selectionEndRightColumn;
            }
            
            editorItem.SelectAbsolute(
                SelectionTopLine, 
                startColumn, 
                SelectionBottomLine, 
                endColumn, 
                selectionEndLine, 
                cursorColumn); 
        }
    }
    
    public struct WordPosition
    {
        string overrideText;
        int start;
        int end;
        bool isSpace;
    }
    
    public WordPosition WholeWordAt(const int screenLine, const int screenColumn)
    {
        const location = LocationAtScreenLine!false(screenLine);
        if (location.Item is null)
            return WordPosition("", screenColumn, screenColumn + 1, true);
        
        enum CharacterType { Space, Text, Other }
        
        CharacterType characterTypeAt(const StringReference text, const int index)
        {
            import std.ascii;
            
            auto character = text[index];
            
            if (character == ' ')
                return CharacterType.Space;
            
            if (character.isAlphaNum || character == '_')
                return CharacterType.Text;
            
            return CharacterType.Other;
        }
        
        immutable absoluteColumn = horizontalCharacterCountOffset + screenColumn;
        
        int rightCutOff;
        StringReference text;
        
        if (const tableBufferItem = cast(TableBufferItem)location.Item)
        {
            int columnStartInCharacters;
            int columnWidth;
            text = tableBufferItem.FullColumnTextAt(location.Line, screenLine, absoluteColumn, columnStartInCharacters, columnWidth);
            
            auto leftPadding = new char[columnStartInCharacters];
            leftPadding[] = ' ';
            text = cast(const(char)[])leftPadding ~ text;
            rightCutOff = columnStartInCharacters + columnWidth;
        }
        else
        {
            text = location.Item.TextAt(location.Line, 0, BufferItem.MaxTemporaryTextWidth, screenLine);
            rightCutOff = text.intLength;
        }
        
        if (absoluteColumn >= text.length)
            return WordPosition("", screenColumn, screenColumn + 1, true);
        
        immutable characterTypeUnderMouse = characterTypeAt(text, absoluteColumn);
        
        int start = absoluteColumn;
        while (true)
        {
            if (start == 0)
                break;
            
            if (characterTypeAt(text, start - 1) != characterTypeUnderMouse)
                break;
            
            start--;
        }
        
        int end = absoluteColumn + 1;
        while (true)
        {
            if (end >= text.intLength)
                break;
            
            if (characterTypeAt(text, end) != characterTypeUnderMouse)
                break;
            
            end++;
        }
        
        return WordPosition(text[start .. end].to!string, start - horizontalCharacterCountOffset, min(end, rightCutOff) - horizontalCharacterCountOffset, characterTypeUnderMouse == CharacterType.Space);
    }
    
    public void SelectWholeWordAt(const int screenLine, const int screenColumn)
    {
        const position = WholeWordAt(screenLine, screenColumn);
        SetSelectionStartScreen(screenLine, position.start, position.end, SelectingMethods.ByWord, position.overrideText);
        SetSelectionEndScreen(screenLine, position.start, position.end);
    }
    
    public void SelectWholeLineAt(const int screenLine)
    {
        SetSelectionStartScreen(screenLine, 0, WidthInCharacters, SelectingMethods.ByLine);
        SetSelectionEndScreen(screenLine, 0, WidthInCharacters);
    }
    
    public auto IsLineSelected(const int screenLine) const
    {
        auto location = LocationAtScreenLine!true(screenLine);
        auto firstIndex = SelectionTopIndex;
        auto lastIndex  = SelectionBottomIndex;
        
        return (firstIndex < location.BufferItemIndex || 
                    (firstIndex == location.BufferItemIndex && SelectionTopLine <= location.Line))
            && (lastIndex > location.BufferItemIndex || 
                    (lastIndex == location.BufferItemIndex && SelectionBottomLine >= location.Line));
    }
    
    public auto CopyWholeItems()
    {
        auto text = appender!string;
        foreach (index; SelectionTopIndex .. SelectionBottomIndex + 1)
        {
            text.put(items[index].CopyWholeItem);
            text.put(lineEnding);
        }
        
        return text.data;
    }
    
    public auto CopyField()
    {
        auto table = cast(TableBufferItem)items[SelectionTopIndex];
        
        if (table is null)
            return CopyWholeItems;
        
        int columnStartInCharacters;
        int columnWidth;
        
        return table.FullColumnTextAt(
            SelectionTopLine, 
            -1, 
            SelectionLeft, 
            columnStartInCharacters, 
            columnWidth);
    }
    
    public auto SelectedText()
    {
        if (selectionType == SelectionTypes.EditorOnly)
            return editorItem.SelectedText;
        
        auto topIndex = SelectionTopIndex;
        auto bottomIndex = SelectionBottomIndex;
        auto topLine = SelectionTopLine;
        auto bottomLine = SelectionBottomLine;
        auto left = SelectionLeft;
        auto right = SelectionRight;
        auto width = right - left;
        
        // The screen may draw a table header row on the first visible
        // line.  The user might intend to select/copy this.  However, 
        // If they have selected a big section and scrolled, then the 
        // selection could span this pseudo-header and we wouldn't want 
        // to copy that.  
        // 
        // If the first (or only) selected line is the first on the screen,  
        // then set fakeScreenLine to 0 just for this line.  BufferItem.TextAt
        // can then decide whether it needs to output the header row or not.
        
        auto firstScreenLocation = LocationAtScreenLine!true(0);
        auto fakeScreenLine = (
            topIndex == firstScreenLocation.BufferItemIndex && 
            topLine == firstScreenLocation.Line) ? 0 : -1;
        
        if (topIndex == bottomIndex &&
            topLine == bottomLine)
        {
            const text = items[topIndex].TextAt(topLine, left, width, fakeScreenLine);
            
            if (selectionOverrideText.length > width && selectionOverrideText[0 .. width] == text)
                return selectionOverrideText;
            else
                return text.to!string;
        }
        
        auto outputText = appender!string;
        auto containsText = false;
        
        foreach (index; topIndex .. bottomIndex + 1)
        {
            auto item = items[index];
            auto lineStart = index == topIndex ? topLine : 0;
            auto lineEnd   = index == bottomIndex ? bottomLine + 1 : item.LineCount;
            
            foreach (line; lineStart .. lineEnd)
            {
                if (containsText)
                    outputText.put(lineEnding);
                
                outputText.put(item.TextAt(line, left, width, fakeScreenLine));
                containsText = true;
                
                if (fakeScreenLine == 0)
                    fakeScreenLine = -1;
            }
        }
        
        return outputText.data;
    }
    
    
    // Adds a new item to the end of the collection.
    private void Add(BufferItem newItem)
    {
        immutable atScreenBottom = TotalLinesBelowScreenStart <= ScreenHeightInLines;
        
        Program.Screen.Invalidate;
        items[$ - 1] = newItem;
        items ~= editorItem;
        
        auto newTableItem = cast(TableBufferItem)newItem;
        if (newTableItem !is null)
            ActiveTableItem = newTableItem;
        else
        {
            indicativeTotalSizeOfAllElementsExceptActive += newItem.IndicativeTotalSize;
            totalLinesOfAllElementsExceptActive += newItem.LineCount;
            widthInCharacters = max(widthInCharacters, newItem.WidthInCharacters);
        }

        if (atScreenBottom)
            ScrollScreenToBottom;
        
        CheckBufferSizeAndTrimOldItems;
        InvalidateScrollbarMap;
    }
    
    public void AddBlankLine()
    {
        Add(new BufferItem);
    }
    
    public void AddText(bool includeTrailingBlankLine = true)(immutable(string)[] lines)
    {
        foreach (line; lines)
            Add(new SimpleTextBufferItem(line));
        
        static if (includeTrailingBlankLine)
            AddBlankLine;
    }
    
    public void AddText(StringReference text)
    {
        foreach (line; text.lineSplitter)
            Add(new SimpleTextBufferItem(line));
        
        if (text.length == 0 || text.endsWith('\n'))
            AddBlankLine;
    }
    
    public void AddText(string text, NamedColor color, FontStyle style)
    {
        foreach (line; text.lineSplitter)
            Add(new FormattedTextBufferItem(line, color, style));
        
        if (text.endsWith('\n'))
            AddBlankLine;
    }
    
    public void AddText(string text, NamedColor color)
    {
        AddText(text, color, color == NamedColor.Normal ? FontStyle.Normal : FontStyle.Bold);
    }

    public void AddText(string text, FontStyle style)
    {
        AddText(text, NamedColor.Normal, style);
    }
    
    public void AddTextWithPrompt(immutable(string) prompt, immutable(string) text)
    {
        string fullText;
        
        FormattedText.Span[] spans;
        fullText = prompt ~ text;
        spans ~= FormattedText.Span(fullText[0 .. prompt.length], 0, NamedColor.Normal, FontStyle.Normal, Program.Settings.PromptOpacity);
        spans ~= FormattedText.Span(fullText[prompt.length .. $], prompt.intLength, NamedColor.Normal, FontStyle.Normal, 255);
        
        AddFormattedText(FormattedText(fullText, spans));
    }
    
    public void AddTextWithPrompt(immutable(string) text)
    {
        auto lineNumber = 0;
        foreach (line; text.lineSplitter)
        {
            string fullText;
            
            FormattedText.Span[] spans;
            
            const indentation = Program.Editor.Indentation;
            
            if (lineNumber == 0)
            {
                fullText = (Program.Editor.Prompt ~ line).to!string;
                spans ~= FormattedText.Span(fullText[0 .. indentation], 0, NamedColor.Normal, FontStyle.Normal, Program.Settings.PromptOpacity);
            }
            else
            {
                fullText = (Program.Editor.IndentationSpace(lineNumber) ~ line).to!string;
                spans ~= FormattedText.Span(fullText[0 .. indentation], 0, NamedColor.Normal, FontStyle.Normal, Program.Settings.PromptNumbersOpacity);
            }
            
            spans ~= FormattedText.Span(fullText[indentation .. $], indentation, NamedColor.Normal, FontStyle.Normal, 255);
            lineNumber++;
            
            AddFormattedText(FormattedText(fullText, spans));
        }
    }
    
    public void AddFormattedText(FormattedText formattedText)
    {
        Add(new FormattedTextBufferItem(formattedText));
    }
    
    public void AddTextWithPrompt(FormattedText[] formattedLines)
    {
        foreach (lineNumber, formattedLine; formattedLines)
        {
            StringReference text;
            
            FormattedText.Span[] spans;
            
            if (lineNumber == 0)
            {
                text = Program.Editor.Prompt ~ formattedLine.Text;
                spans ~= FormattedText.Span(Program.Editor.Prompt, 0, NamedColor.Normal, FontStyle.Normal, Program.Settings.PromptOpacity);
            }
            else
            {
                text = Program.Editor.IndentationSpace(lineNumber) ~ formattedLine.Text;
                spans ~= FormattedText.Span(Program.Editor.IndentationSpace(lineNumber), 0, NamedColor.Normal, FontStyle.Normal, Program.Settings.PromptNumbersOpacity);
            }
            
            foreach (span; formattedLine.Spans)
            {
                const start = Program.Editor.Indentation + span.StartColumn;
                const end = start + span.Text.intLength;
                spans ~= FormattedText.Span(text[start .. end], start, span.Color, span.Style, span.Opacity);
            }
            
            AddFormattedText(FormattedText(text, spans));
        }
    }
    
    public void AddFormattedText(FormattedText[] formattedLines)
    {
        foreach (line; formattedLines)
            AddFormattedText(line);
    }
    
    public void AddColumns(OracleColumns columns)
    {
        Add(new TableBufferItem(columns));
    }
    
    public void AddRecord(OracleRecord fields)
    {
        Program.Screen.Invalidate;
        
        // This can be null in a race condition between the record coming back
        // after the user has cancelled.
        if (activeTableItem is null)
            return;
        
        immutable atScreenBottom = TotalLinesBelowScreenStart <= ScreenHeightInLines;
        
        auto oldLineCount = activeTableItem.LineCount;
        
        activeTableItem.AddRecord(fields);
        
        auto newLineCount = activeTableItem.LineCount;
        
        // Were records discarded?
        if (newLineCount < oldLineCount && activeTableItem == items[screenFirstIndex])
            screenFirst_LineNumberOffset = min(screenFirst_LineNumberOffset, newLineCount);
        
        if (atScreenBottom)
            ScrollScreenToBottom;
        
        InvalidateScrollbarMap;
    }
    
    public void QueryComplete()
    {
        if (activeTableItem is null)
            return;
        
        activeTableItem.QueryComplete;
    }
    
    public void AddSqlError(SqlError error)
    {
        QueryComplete;
        
        // ORA-04068 clears session state apparently in all packages which is news to me.  
        // Anyway, this causes DBMS_OUTPUT to disable too.  the Internet told me TOAD had 
        // the same problem and this was their solution too.
        if (error.ErrorCode == 4068)
            Program.Settings.SetServerOutputValue = Program.Settings.GetServerOutputValue("");
        
        if (error.IsSilent)
            return;
        
        Program.Screen.Invalidate;
        
        const offset = error.RowHeadersWidth + error.ErrorColumn - 1;
        auto formattedCommand = Program.Syntax.Highlight(error.CommandLines, -1, -1, 127);
      
        foreach (lineNumber, line; formattedCommand)
            if (lineNumber == error.RelativeErrorLine)
            {
                FormattedText.Span[] newSpans;
                foreach (span; line.Spans)
                    if (span.StartColumn + span.Text.intLength <= offset)
                        newSpans ~= span;
                    else if (span.StartColumn >= offset)
                        newSpans ~= FormattedText.Span(span.Text, span.StartColumn, NamedColor.Error, FontStyle.Bold, 255);
                    else
                    {
                        const wordEnd = offset - span.StartColumn;
                        newSpans ~= FormattedText.Span(span.Text[0 .. wordEnd], span.StartColumn, span.Color, span.Style, span.Opacity);
                        newSpans ~= FormattedText.Span(span.Text[wordEnd .. $], span.StartColumn + wordEnd, NamedColor.Error, FontStyle.Bold, 255);
                    }
                
                AddFormattedText(FormattedText(line.Text, newSpans));
            }
            else
                AddFormattedText(line);
        
        AddBlankLine;
        
        auto errorMessageLines = 
            ("Error on line " ~ 
                error.AbsoluteErrorLine.to!string ~ ", column " ~ 
                error.ErrorColumn.to!string ~ ": " ~ lineEnding ~ "    " ~ 
                error.Error)
            .lineSplitter;
        foreach (errorMessageLine; errorMessageLines)
            AddText(errorMessageLine);
        
        AddBlankLine;
    }
    
    private FormattedTextBufferItem[] uncommittedResultItems;
    
    public void AddSqlSuccess(SqlSuccess success)
    {
        QueryComplete;
        
        if (success.IsSilent)
            return;
        
        Program.Screen.Invalidate;
        
        if (success.WasCommitted != CommitState.Uncommitted)
        {
            FormattingMode mode;
            
            final switch (success.WasCommitted) with (CommitState)
            {
                case Committed:     mode = FormattingMode.Hidden;   break;
                case RolledBack:    mode = FormattingMode.Disabled; break;
                case Uncommitted:   break; // Can't get here but included for final.
            }
            
            foreach (previousResultItem; uncommittedResultItems)
                previousResultItem.ShowFormatting = mode;
                
            uncommittedResultItems = [];
        }
        
        
        if (!Program.Settings.IsFeedbackOn)
            return;
        
        if (success.AffectedRowCount > 0 &&
            success.AffectedRowCount < Program.Settings.FeedbackTheshold)
            return;
        
        NamedColor color;
        
        if (!success.WasUpdate)
            color = NamedColor.Normal;
        else if (success.AffectedRowCount == 0)
            color = NamedColor.Warning;
        else if (success.AffectedRowCount == 1)
            color = NamedColor.Good;
        else if (success.AffectedRowCount < 10)
            color = NamedColor.Warning;
        else if (success.AffectedRowCount < 100)
            color = NamedColor.Alert;
        else
            color = NamedColor.Danger;
        
        auto style = color == NamedColor.Normal ? FontStyle.Normal : FontStyle.Bold;
        
        AddBlankLine;
        
        foreach (line; success.Description.lineSplitter)
        {
            auto item = new FormattedTextBufferItem(line, color, style);
            Add(item);
            if (success.WasUpdate)
                uncommittedResultItems ~= item;
        }
        
        AddBlankLine;
        
        if (Program.Settings.IsTimingOn)
            AddText("Elapsed: " ~ success.Duration.DurationToPrettyString);
    }
    
    private void CheckBufferSizeAndTrimOldItems()
    {
        // Each GC is relatively slow, so only start when we have 
        // accumulated greater than MemorySettings.CollectThreshold,
        // and trim a large chunk before calling the GC.
        if (IndicativeTotalSize < MemorySettings.CollectThreshold)
            return;
        
        auto trimThreshold = MemorySettings.CollectThreshold / 2;
        auto itemsWereTrimmed = false;
        while (IndicativeTotalSize > trimThreshold)
        {
            if (screenFirstIndex == 0)
                break;
            
            auto firstItem = items[0];
            if (firstItem == activeTableItem)
                break;
            
            indicativeTotalSizeOfAllElementsExceptActive -= firstItem.IndicativeTotalSize;
            totalLinesOfAllElementsExceptActive -= firstItem.LineCount;
            totalLinesAboveScreenFirstBufferItem -= firstItem.LineCount;
            screenFirstIndex--;
            
            items = items[1 .. $];
            firstItem.Free;
            itemsWereTrimmed = true;
        }
        
        if (itemsWereTrimmed)
        {
            import core.memory;
            GC.collect;
        }
        
        widthInCharacters = 0;
        if (items.length > 2)
            foreach (item; items[0 .. $ - 2])
                widthInCharacters = max(widthInCharacters, item.WidthInCharacters);
        
        horizontalCharacterCountOffset = min(horizontalCharacterCountOffset, 
                                             widthInCharacters - screenWidthInCharacters);
    }
    
    public void Clear()
    {
        Program.Screen.Invalidate;
        ActiveTableItem = null;
        screenFirstIndex = 0;
        screenFirst_LineNumberOffset = 0;
        selectionStartIndex = 0;
        selectionEndIndex = 0;
        selectionStartLine = 0;
        selectionEndLine = 0;
        selectionStartLeftColumn = 0;
        selectionStartRightColumn = 0;
        selectionEndLeftColumn = 0;
        selectionEndRightColumn = 0;
        
        indicativeTotalSizeOfAllElementsExceptActive = 0;
        totalLinesOfAllElementsExceptActive = 0;
        totalLinesAboveScreenFirstBufferItem = 0;
        horizontalCharacterCountOffset = 0;
        widthInCharacters = 0;
        
        foreach (item; items[0 .. $ - 1])
            item.Free;
        
        import core.memory : GC;
        GC.free(GC.addrOf(items.ptr));
        items = [editorItem];
    }
    
    public void ScrollScreenVerticallyBy(int numberOfLines) @nogc nothrow
    {
        Program.Screen.Invalidate;
        if (numberOfLines > 0) // Then scrolling down
        {
            numberOfLines = min(numberOfLines, 
                                max(0, 
                                    TotalLinesBelowScreenStart - 
                                        screenHeightInLines
                                )
                            );
            
            screenFirst_LineNumberOffset += numberOfLines;
        
            while (true)
            {
                auto screenFirst = items[screenFirstIndex];
            
                if (screenFirst_LineNumberOffset < screenFirst.LineCount) return;
                
                if (screenFirstIndex == items.length - 1)
                {
                    screenFirst_LineNumberOffset = screenFirst.LineCount - 1;
                    return;
                }
                
                screenFirst_LineNumberOffset -= screenFirst.LineCount;
                totalLinesAboveScreenFirstBufferItem += screenFirst.LineCount;
                screenFirstIndex++;
            }
        }
        else if (numberOfLines < 0) // Then scrolling up
        {
            screenFirst_LineNumberOffset += numberOfLines; // Don't forget this is negative
        
            while (true)
            {
                auto screenFirst = items[screenFirstIndex];
            
                if (screenFirst_LineNumberOffset >= 0) return;
                
                if (screenFirstIndex == 0)
                {
                    screenFirst_LineNumberOffset = 0;
                    return;
                }
                
                screenFirstIndex--;
                screenFirst_LineNumberOffset += items[screenFirstIndex].LineCount;
                totalLinesAboveScreenFirstBufferItem -= items[screenFirstIndex].LineCount;
            }
        }
    }
    
    public void ScrollScreenVerticallyTo(const int newTotalLinesAboveScreenStart) @nogc nothrow
    {
        ScrollScreenVerticallyBy(newTotalLinesAboveScreenStart - TotalLinesAboveScreenStart);
    }
    
    public void ScrollScreenToTop() @nogc nothrow
    {
        ScrollScreenVerticallyTo(0);
    }
    
    public void ScrollScreenToShow(const int itemIndex, const int line, const int left, const int right) @nogc nothrow
    {
        screenFirstIndex = itemIndex;
        screenFirst_LineNumberOffset = line;
        RecalculateTotalLinesAboveScreenFirstBufferItem;
        ScrollScreenVerticallyBy(-ScreenHeightInLines / 2);
        
        if (left >= horizontalCharacterCountOffset && 
            right < horizontalCharacterCountOffset + ScreenWidthInCharacters)
            return;
        
        if (right < ScreenWidthInCharacters)
            ScrollScreenHorizontallyTo(0);
        else
            ScrollScreenHorizontallyTo(max(0, (right + left - ScreenWidthInCharacters) / 2));
    }
    
    public void ScrollScreenToBottom() @nogc nothrow
    {
        // Sometimes we are "further down" than the bottom if 
        // the screen has been resized.  In such a case, don't
        // scroll up.
        
        auto currentVerticalPosition = TotalLinesAboveScreenStart;
        auto proposedVerticalPosition = max(0, TotalLines - screenHeightInLines);
        
        if (proposedVerticalPosition > currentVerticalPosition || 
            (ScreenFirst is editorItem && screenFirst_LineNumberOffset > editorItem.LineCount))
            ScrollScreenVerticallyTo(proposedVerticalPosition);
        
        // We need to make sure the cursor is visible.
        auto cursorPosition = editorItem.CursorPositionColumn;
        
        if (cursorPosition < screenWidthInCharacters / 2)
            ScrollScreenHorizontallyTo(0);
        //else if (cursorPosition < horizontalCharacterCountOffset)
        //    
        else if (cursorPosition < horizontalCharacterCountOffset + screenWidthInCharacters / 4)
            ScrollScreenHorizontallyTo(max(0, cast(int)(cursorPosition - screenWidthInCharacters / 2)));
        else if (cursorPosition + 4 > horizontalCharacterCountOffset + screenWidthInCharacters)
            ScrollScreenHorizontallyTo(max(0, cast(int)(cursorPosition + 4 - screenWidthInCharacters)));
    }
    
    public void ScrollScreenUpByOnePage() @nogc nothrow
    {
        ScrollScreenVerticallyBy(-screenHeightInLines);
    }
    
    public void ScrollScreenDownByOnePage() @nogc nothrow
    {
        ScrollScreenVerticallyBy(screenHeightInLines);
    }
    
    public void ScrollScreenHorizontallyTo(const int offset) @nogc nothrow
    {
        Program.Screen.Invalidate;
        horizontalCharacterCountOffset = max(0, min(offset, WidthInCharacters + 4 - screenWidthInCharacters));
    }
    
    public void ScrollScreenHorizontallyBy(const int offset) @nogc nothrow
    {
        Program.Screen.Invalidate;
        horizontalCharacterCountOffset = max(0, min(horizontalCharacterCountOffset + offset, WidthInCharacters + 4 - screenWidthInCharacters));
    }
    
    public void ScrollScreenLeftByOnePage() @nogc nothrow
    {
        ScrollScreenHorizontallyBy(-screenWidthInCharacters);
    }
    
    public void ScrollScreenRightByOnePage() @nogc nothrow
    {
        ScrollScreenHorizontallyBy(screenWidthInCharacters);
    }
    
    public auto FindNext()
    {
        immutable searchText = Program.Editor.CurrentFindText.strip.lineSplitter.firstOrDefault("").strip.to!string.toUpper;
        
        if (searchText.length == 0)
            return false;
        
        int itemIndex = SelectionTopIndex;
        int line = SelectionTopLine;
        int left = SelectionLeft;
        int right = (SelectionBottomIndex == itemIndex && 
                     SelectionBottomLine == line) ? 
                        SelectionRight : 
                        left;
        auto hasAlreadyLoopedToTop = false;
        
        while (true)
        {
            const item = items[itemIndex];
            
            if (item is editorItem)
                left = right = 0;
            else
            {
                int matchStart = left;
                int matchEnd = right;
                
                auto matchingText = item.FindNextInLine(searchText, line, matchStart, matchEnd, selectionFindColumnIndex, selectionFindColumnMatchStart, selectionFindColumnMatchEnd);
                if (matchingText.length > 0)
                {
                    if (matchStart == left && matchEnd == right)
                    {
                        left++;
                        selectionFindColumnMatchStart++;
                        continue;
                    }
                    
                    SetSelectionStart(itemIndex, line, matchStart, matchEnd, matchingText);
                    ScrollScreenToShow(itemIndex, line, matchStart, matchEnd);
                    return true;
                }
                
                selectionFindColumnIndex      = 0; 
                selectionFindColumnMatchStart = 0;
                selectionFindColumnMatchEnd   = 0;
                left = right = 0;
                
                line++;
                if (line < item.LineCount)
                    continue;
            }
            
            line = 0;
            itemIndex++;
            
            if (itemIndex < items.length)
                continue;
            
            if (hasAlreadyLoopedToTop)
                return false;
            
            itemIndex = 0;
            hasAlreadyLoopedToTop = true;
        }
    }
    
    public auto FindPrevious()
    {
        immutable searchText = Program.Editor.CurrentFindText.strip.lineSplitter.firstOrDefault("").strip.to!string.toUpper;
        
        if (searchText.length == 0)
            return false;
        
        int itemIndex = SelectionBottomIndex;
        int line = SelectionBottomLine;
        int right = SelectionRight;
        int left = (SelectionTopIndex == itemIndex && 
                    SelectionTopLine == line) ? 
                        SelectionLeft : 
                        right;
        
        auto hasAlreadyLoopedToBottom = false;
        auto item = items[itemIndex];
        
        while (true)
        {
            if (item !is editorItem)
            {
                int matchStart = left;
                int matchEnd   = right;
            
                auto matchingText = item.FindPreviousInLine(searchText, line, matchStart, matchEnd, selectionFindColumnIndex, selectionFindColumnMatchStart, selectionFindColumnMatchEnd);
                if (matchingText.length > 0)
                {
                    if (matchStart == left && matchEnd == right)
                    {
                        right--;
                        selectionFindColumnMatchEnd--;
                        continue;
                    }
                    
                    SetSelectionStart(itemIndex, line, matchStart, matchEnd, matchingText);
                    ScrollScreenToShow(itemIndex, line, matchStart, matchEnd);
                    return true;
                }
                
                selectionFindColumnIndex      = int.max;
                selectionFindColumnMatchStart = int.max;
                selectionFindColumnMatchEnd   = int.max;
                left = right                  = int.max;
                
                line--;
                if (line >= 0)
                    continue;
            }
            
            itemIndex--;
            
            if (itemIndex < 0)
            {
                if (hasAlreadyLoopedToBottom)
                    return false;
                
                hasAlreadyLoopedToBottom = true;
                itemIndex = items.intLength - 1;
            }
            
            item = items[itemIndex];
            left = right = item.WidthInCharacters;
            line = item.LineCount - 1;
        }
    }
    
    struct ScrollbarMapLocation
    {
        NamedColor color;
        // int start;
        int width;
        int tableHeight;
    }
    
    public bool isScrollbarMapValid = false;
    private ScrollbarMapLocation[] scrollbarMapLocations;
    
    // TODO: Consider refactoring this into screen.d depending on where the callers are.
    public void InvalidateScrollbarMap() @nogc nothrow
    {
        isScrollbarMapValid = false;
    }
    
    public void DrawScrollbarMap(const int scrollbarWidth, const int scrollbarHeight, const int windowHeightInLines, ref uint[] pixels)
    {
        enum mapWidthInCharacters = 60;
    
        isScrollbarMapValid = true;
        
        pixels[] = 0;
        
        const lineCount = TotalLines;
        
        if (lineCount <= windowHeightInLines)
            return;
        
        assert (scrollbarHeight >= 0, "Vertical scrollbar height cannot be negative: " ~ scrollbarHeight.to!string);
        
        
        immutable characterHeight = scrollbarHeight / cast(double)lineCount;
        immutable characterWidth  = scrollbarWidth  / cast(double)mapWidthInCharacters;
        immutable headerColor = Program.Screen.LookupNamedColor(NamedColor.HeaderUnderline, 0).pixelValue;
        
        void AddToMap(bool isTable = false)(
            const NamedColor color, 
            const long lineNumber, 
            const int startInCharacters, 
            const StringReference text, 
            const int tableWidthInCharacters = 0, 
            const int tableLineCount = 0)
        {
            if (lineNumber >= lineCount)
                return;
            
            immutable topY = cast(int)(characterHeight * lineNumber);
            
            static if (isTable)
                immutable bottomY = min(topY + cast(int)(characterHeight * tableLineCount), scrollbarHeight);
            else
                immutable bottomY = min(topY + max(1, cast(int)characterHeight), scrollbarHeight);
            
            if (startInCharacters >= mapWidthInCharacters)
                return;
            
            immutable pixel = (color == NamedColor.Normal ? 
                                   Program.Screen.AdjustOpacity(Program.Screen.LookupNamedColor(color, 0), 127) : 
                                   Program.Screen.LookupNamedColor(color, 0))
                              .pixelValue;
            
            static if (isTable)
            {
                immutable startX = cast(int)(characterWidth * startInCharacters);
                immutable endX   = cast(int)(characterWidth * min(mapWidthInCharacters, tableWidthInCharacters));
                immutable headerStartOffset = topY * scrollbarWidth + startX;
                immutable headerEndOffset   = topY * scrollbarWidth + endX;
                
                pixels[headerStartOffset .. headerEndOffset] = headerColor;
                
                for (int y = topY + 2; y < bottomY; y += 2)
                {
                    immutable startOffset = min(y * scrollbarWidth + startX, pixels.length);
                    immutable endOffset   = min(y * scrollbarWidth + endX,   pixels.length);
                    
                    pixels[startOffset .. endOffset] = pixel;
                }
            }
            else
            {
                int characterPosition = startInCharacters;
                
                foreach (character; text)
                {
                    scope (exit) characterPosition++;
                
                    if (character.isWhite)
                        continue;
                    
                    if (characterPosition >= mapWidthInCharacters)
                        break;
                    
                    for (int y = topY; y < bottomY; y++)
                    {
                        immutable startOffset = min(cast(int)(y * scrollbarWidth + characterPosition * characterWidth), pixels.length);
                        immutable endOffset   = min(startOffset + max(1, cast(int)characterWidth),                      pixels.length);
                        
                        pixels[startOffset .. endOffset] = pixel;
                    }
                }
            }
            
            // if (scrollbarMapLocations[y].width > 0 &&
            //      (scrollbarMapLocations[y].tableHeight > tableLineCount || 
            //        (tableLineCount == 0 && scrollbarMapLocations[y].color > color)))
            //     return;
        }
        
        auto lineNumber = 0;
        
        foreach (item; items)
        {
            auto color = NamedColor.Normal;
            auto widthInCharacters = 0;
            
            if (auto formattedItem = cast(FormattedTextBufferItem)item)
            {
                foreach (span; formattedItem.Formatting.Spans)
                    AddToMap(span.Color, lineNumber, span.StartColumn, span.Text);
            }
            else if (auto simpleItem = cast(SimpleTextBufferItem)item)
            {
                if (simpleItem.WidthInCharacters > 0)
                    AddToMap(NamedColor.Normal, lineNumber, 0, simpleItem.TextAt(0, 0, mapWidthInCharacters, 0));
            }
            else if (auto table = cast(TableBufferItem)item)
            {
                AddToMap!true(NamedColor.HeaderUnderline, lineNumber, 0, "", table.WidthInCharacters, table.LineCount);
            }
            else if (auto editor = cast(EditorBufferItem)item)
            {
                foreach (subLineNumber, line; editor.formattedLines)
                    foreach (span; line.Spans)
                        AddToMap(span.Color, lineNumber + subLineNumber, span.StartColumn, span.Text);
            }
            
            lineNumber += item.LineCount;
        }
    }
    
    debug public void AddTestData()
    {
        AddText("First  item");
        AddText("Second item");
        AddText("Third  item");
        
        foreach (int i; 1 .. 256)
        {
            AddText(i.to!string ~ " \"" ~ cast(char)i ~ "\"");
        }
        
        foreach (int i; 0 .. 1001)
        {
            // AddText("\n\n        " ~ i.to!string ~ "\n\n");
            AddText(i.to!string ~ "\n");
            
            AddText("Hic voluptates nulla doloremque exercitationem aut unde laudantium    officia. Impedit officia non vitae qui sunt et minus. Omnis ratione   \n" ~ 
                    "officia tenetur qui illo exercitationem est inventore. Consequuntur   quisquam commodi et rerum quis. Magnam voluptatem aspernatur consect  \n" ~ 
                    "etur quos eius ut eius et. Doloremque consectetur ipsa ab nihil.      Atque non quidem libero. Aliquid asperiores accusantium et possimus   \n" ~ 
                    "veniam provident voluptas sit. Aspernatur et ipsam enim ut sed debitisRerum consequuntur vel quia ad eos. Repudiandae exercitationem \n" ~ 
                    "electus quibusdam exercitationem magnam.                            \n\n");
            
            
            AddText("Atque non quidem libero. Aliquid asperiores accusantium et possimus   veniam provident voluptas sit. Aspernatur et ipsam enim ut sed debitis\n" ~ 
                    ". Rerum consequuntur vel quia ad eos. Repudiandae exercitationem d    electus quibusdam exercitationem magnam.\n" ~ 
                    "Corrupti commodi harum ut. Qui exercitationem qui suscipit            aspernatur omnis. Vel libero deserunt rem temporibus. Dolor quisquam  \n" ~ 
                    "quam ut in. Incidunt aut et qui molestias rerum                       voluptates. Adipisci est dolor ut.                                  \n\n");
            
            AddText("Adipisci qui facilis ut. Ea sunt voluptatem                           fugiat perferendis inventore animi. Quisquam nihil nam at et totam    \n" ~ 
                    "ratione. Praesentium debitis id veniam quis repudiandae voluptatem eosModi sapiente recusandae soluta quo minus accusamus. Aut voluptatem   \n" ~ 
                    "sint ut consequuntur.\n\n");
            
            AddText("Distinctio rerum delectus ut inventore voluptatem voluptate aliquam.  Qui animi et amet assumenda. Aut quae esse aut molestias voluptate non\n" ~ 
                    "Ipsam voluptatum vitae in sapiente omnis. Et voluptatem enim non      in. Sed voluptatum pariatur voluptatem magnam autem suscipit sit.   \n\n");
       }
       
       AddText("Good\n",      NamedColor.Good);
       AddText("Warning\n",   NamedColor.Warning);
       AddText("Alert\n",     NamedColor.Alert);
       AddText("Danger\n",    NamedColor.Danger);
       AddText("Popup\n",     NamedColor.Popup);
       AddText("Disabled\n",  NamedColor.Disabled);
    }                         
}

