module buffer_item;

import std.array : replicate, split;
import std.algorithm : max, min, map, cartesianProduct, filter, reverse, fold, multiSort, sort, countUntil, findAmong;
import std.container.array : Array;
import std.conv : to, ConvException;
import std.datetime;
import std.math : isNaN;
import std.range : repeat, appender, array, iota, enumerate, retro, choose;
import std.string : lineSplitter, lastIndexOf, toUpper, replace;
import std.sumtype : match;
import std.traits : ReturnType;
import std.typecons : Tuple, tuple, Nullable, nullable;
import std.utf : byDchar;
import core.memory : GC;

import program;
import range_extensions;
import utf8_slice;

public class BufferItem
{
    public FontStyle Style() const @nogc nothrow => FontStyle.Normal;
    public NamedColor Color() const @nogc nothrow => NamedColor.Normal;
    public int LineCount() const @nogc nothrow => 1;
    public int WidthInCharacters() const @nogc nothrow => 1;
    public size_t IndicativeTotalSize() const @nogc nothrow => __traits(classInstanceSize, BufferItem);
    public string CopyWholeItem() const => "";
    public enum MaxTemporaryTextWidth = 4096;
    
    public void Free() => GC.free(cast(void*)this);
    
    public const (char)[] TextAt(const int lineNumber, const int start, const int width, const int screenLine) const => "";
    
    public string FindNextInLine(
        const string searchTextUpperCase, 
        const int lineNumber, 
        ref int matchStart, 
        ref int matchEnd, 
        ref int matchColumn, 
        ref int columnMatchStart, 
        ref int columnMatchEnd) const
    {
        matchColumn = -1;
        columnMatchStart = 0;
        columnMatchEnd = 0;
        
        const currentText = TextAt(lineNumber, matchStart, WidthInCharacters, -1);
        
        auto searchTextUpperCaseUtf32 = searchTextUpperCase.to!dstring;
        auto matchOffset = currentText.toUpper.byDchar.countUntil(searchTextUpperCaseUtf32);
        if (matchOffset < 0)
            return "";
        
        matchStart += matchOffset;
        matchEnd = matchStart + searchTextUpperCaseUtf32.intLength;
        return currentText.toUtf8Slice[matchOffset .. matchOffset + searchTextUpperCaseUtf32.length].to!string;
    }
    
    public string FindPreviousInLine(
        const string searchTextUpperCase, 
        const int lineNumber, 
        ref int matchStart, 
        ref int matchEnd, 
        ref int matchColumn, 
        ref int columnMatchStart, 
        ref int columnMatchEnd) const
    {
        matchColumn = -1;
        columnMatchStart = 0;
        columnMatchEnd = 0;
        
        const currentText = TextAt(lineNumber, 0, matchEnd, -1);
        
        auto searchTextUpperCaseUtf32 = searchTextUpperCase.to!dstring;
        auto matchOffset = cast(int)currentText.toUpper.byDchar.retro.countUntil(searchTextUpperCaseUtf32.retro);
        if (matchOffset < 0)
            return "";
        
        matchEnd = currentText.toUtf8Slice.intLength - matchOffset;
        matchStart = matchEnd - searchTextUpperCaseUtf32.intLength;
        return currentText.toUtf8Slice[matchStart .. matchEnd].array.to!string;
    }
}

public class SimpleTextBufferItem : BufferItem
{
    protected immutable string text;
    protected immutable int widthInCharacters;
    public override int WidthInCharacters() const => widthInCharacters;
    public override size_t IndicativeTotalSize() const => super.IndicativeTotalSize + text.intLength * 2;
    public override string CopyWholeItem() const => text;
    
    public override void Free()
    {
        GC.free(GC.addrOf(cast(void*)text.ptr));
        super.Free;
    }
    
    public override const (char)[] TextAt(const int lineNumber, const int start, const int width, const int screenLine) const @nogc nothrow
    {
        if (lineNumber > 0)
            return "";
        
        if (start >= widthInCharacters)
            return "";
        
        return text.toUtf8Slice[start .. min(start + width, widthInCharacters)];
    }
    
    this(StringReference text)
    {
        this.text = text.to!string;
        widthInCharacters = text.toUtf8Slice.intLength;
        Program.Buffer.Spool(this.text);
    }
}

public final class FormattedTextBufferItem : SimpleTextBufferItem
{
    public FormattedText Formatting;
    
    private auto showFormatting = FormattingMode.Apply;
    public auto ShowFormatting() const => showFormatting;
    public void ShowFormatting(FormattingMode value) { showFormatting = value; }
    public override size_t IndicativeTotalSize() const => super.IndicativeTotalSize + Formatting.Spans.intLength * cast(int)FormattedText.Span.sizeof;
    
    public this(StringReference text) 
    { 
        super(text); 
        Formatting = FormattedText(text);
    }
    
    public this(StringReference text, const NamedColor color, const FontStyle style, const ubyte opacity = 255) 
    {
        this(text); 
        Formatting = FormattedText(text, color, style, opacity);
    }
    
    public this(FormattedText formatting) 
    { 
        super(formatting.Text); 
        Formatting = formatting;
    }
    
    public void Add(const int startColumn, const int width, const NamedColor color = NamedColor.Normal, const FontStyle style = FontStyle.Normal, const ubyte opacity = 255)
    {
        assert(startColumn >= 0, "FormattedText startColumn must be positive.");
        assert(startColumn + width <= widthInCharacters, "FormattedText span must exist within the source text.");
        Formatting.Spans ~= FormattedText.Span(text.toUtf8Slice[startColumn .. startColumn + width], startColumn, color, style, opacity);
    }
    
    public override void Free()
    {
        GC.free(GC.addrOf(cast(void*)Formatting.Spans.ptr));
        super.Free;
    }
    
    public FormattedText.Span[] FormattedTextAt(
        const int start, 
        const int width, 
        const int screenLine) const @nogc
    {
        static FormattedText.Span[128] spans;
        size_t spanCount = 0;
        
        foreach (span; Formatting.Spans)
        {
            const textStart = max(start,         span.StartColumn);
            const textEnd   = min(start + width, span.StartColumn + span.Text.toUtf8Slice.intLength);
            
            if (textStart >= textEnd)
                continue;
            
            NamedColor color;
            FontStyle style;
            
            final switch (showFormatting) with (FormattingMode)
            {
                case Apply:    color = span.Color;          style = span.Style;       break;
                case Hidden:   color = NamedColor.Normal;   style = FontStyle.Normal; break;
                case Disabled: color = NamedColor.Disabled; style = FontStyle.Normal; break;
            }
            
            spans[spanCount] = FormattedText.Span(text.toUtf8Slice[textStart .. textEnd], textStart - start, color, style, span.Opacity);
            spanCount++;
            
            if (spanCount >= spans.length)
            {
                // Patch up the last entry so the formatting may be lost, but the text isn't.
                const oldStart = spans[$ - 1].StartColumn;
                const left = oldStart + start;
                spans[$ - 1] = FormattedText.Span(text.toUtf8Slice[left .. $], oldStart, NamedColor.Normal, FontStyle.Normal, 255);
                return spans;
            }
        }
        
        return spans[0 .. spanCount];
    }
}

public final class TableBufferItem : BufferItem
{
    private alias SubstituteRecord = OracleField[size_t];
    
    private struct Line
    {
        enum Types { Record, Text, Substitute, Heading }
        Types             Type;
        string            Text;
        OracleRecord      Record;
        SubstituteRecord  Substitute;
        
        private this(Types type, string text, OracleRecord record, SubstituteRecord substitute) @nogc nothrow
        {
            Type       = type;
            Text       = text;
            Record     = record;
            Substitute = substitute;
        }
        
        public this(string text)                                      @nogc nothrow { this(Types.Text,     text, null,   null      ); } 
        public this(OracleRecord record)                              @nogc nothrow { this(Types.Record,     "", record, null      ); } 
        public this(OracleRecord record, SubstituteRecord substitute) @nogc nothrow { this(Types.Substitute, "", record, substitute); } 
        
        static Line Heading() @nogc nothrow { return Line(Types.Heading,    "", null,   null); }
        
        string TextAt(WidthMode mode)(const TableBufferItem tableItem, const size_t columnIndex) const
        {
            final switch (Type)
            {
                case Types.Text:
                    return columnIndex == 0 ? Text : "";
                    
                case Types.Heading:
                    return tableItem.HeadingAt(columnIndex);
                    
                case Types.Record, Types.Substitute:
                    
                    auto fieldRef = columnIndex in Substitute;
                    if (fieldRef !is null)
                    {
                        auto field = *fieldRef;
                        return tableItem.FieldToString!mode(columnIndex, field);
                    }
                    
                    return Record is null ? "" : tableItem.FieldToString!mode(columnIndex, Record[columnIndex]);
            }
        }
        
        void Free(ref size_t indicativeTotalSize)
        {
            if (Record.length > 0)
                indicativeTotalSize -= RecordSize(Record);
            
            GC.free(GC.addrOf(cast(void*)Text.ptr));
            
            foreach (field; Record)
                field.match!(
                    (string         text) => GC.free(GC.addrOf(cast(void*)text.ptr)), 
                    (OracleDate     date) => GC.free(GC.addrOf(cast(void*)date.Text.ptr)), 
                    (OracleNumber number) => number.free, 
                    (_) { }
                );
            
            GC.free(GC.addrOf(cast(void*)Record.ptr));
            
            foreach (field; Substitute)
                field.match!(
                    (string         text) => GC.free(GC.addrOf(cast(void*)text.ptr)), 
                    (OracleDate     date) => GC.free(GC.addrOf(cast(void*)date.Text.ptr)), 
                    (OracleNumber number) => number.free, 
                    (_) { }
                );
            
            GC.free(GC.addrOf(cast(void*)Substitute));
        }
    }
    
    private Array!Line lines;
    private auto totalRecordCount = 0;
    private auto pendingDiscardLineCount = 0;
    private auto discardedLineCount = 0;
    private OracleRecord lastRecord;
    
    public auto TotalRecordCount() const => totalRecordCount;
    
    private OracleColumns columns;
    public auto Columns() const @nogc nothrow => columns;
    
    public UserDefinedColumn[] UserColumns;
    
    struct ColumnDimension
    {
        int Min;
        int Max;
        int Extra;
        
        int CurrentWidth() const pure @nogc nothrow => Min + Extra;
        
        this(string headerName)
        {
            Min = 1;
            Max = headerName.toUtf8Slice.intLength;
            Extra = 0;
        }
    }
    
    private ColumnDimension[] columnWidths;
    public auto ColumnWidth(bool isSpooling = false, bool includePadding = false)(const size_t columnIndex) const @nogc nothrow
    {
        static if (includePadding)
            const padding = Program.Settings.ColumnSeparatorDString.length;
        else
            enum padding = 0;
        
        auto userColumn = UserColumns[columnIndex];
        
        if (userColumn !is null &&
            userColumn.IsEnabled)
        {
            if (!userColumn.IsVisible)
                return 0;
            
            if (userColumn.Width >= 0) 
                return userColumn.Width + padding;
        }
        
        static if (isSpooling)
            if (isSpoolingDuringCollection)
                return min(2000, columns[columnIndex].MaxSize) + padding;
        
        return columnWidths[columnIndex].CurrentWidth + padding;
    }
    
    public bool UpdateObservedColumnWidth(const size_t columnIndex, int dataWidth)
    {
        if (dataWidth <= columnWidths[columnIndex].Min)
            return false;
        
        // Keep this data up to date even if there is a user column.
        columnWidths[columnIndex].Min = max(columnWidths[columnIndex].Min, min(50, dataWidth));
        columnWidths[columnIndex].Max = max(columnWidths[columnIndex].Max, dataWidth);
        
        auto userColumn = UserColumns[columnIndex];
        
        // This change applies if...
        return userColumn is null ||    // There is no overriding user column, or:
              !userColumn.IsEnabled ||  // There is a column, but it's disabled, or:
              (userColumn.IsVisible && userColumn.Width < 0);  // The column is visible but with no size set.
    }
    
    public void BalanceExtraColumnSpaceAndRecalculateFullWidth() @nogc nothrow
    {
        if (columnWidths.length == 0)
            return;
        
        scope (exit)
        {
            // No matter what, make the last column as wide as it wants to be.
            auto columnWidth = &columnWidths[$ - 1];
            columnWidth.Extra = columnWidth.Max - columnWidth.Min;
            
            widthInCharacters = 1;
            if (columns.length > 0)
            {
                foreach (columnIndex; 0 .. columns.length - 1)
                    widthInCharacters += ColumnWidth!(false, true)(columnIndex);
                
                widthInCharacters += ColumnWidth!(false)(columns.length - 1);
            }
        }
        
        auto takenWidth = 0;
        foreach (ref columnWidth; columnWidths)
        {
            takenWidth += columnWidth.Min + Program.Settings.ColumnSeparatorDString.intLength;
            columnWidth.Extra = 0;
        }
        
        auto availableWidth = Program.Buffer.ScreenWidthInCharacters - 3;
        
        if (takenWidth >= availableWidth)
            return;
        
        auto unsatisfiedColumnCount = 0;
        foreach (ref columnWidth; columnWidths)
            if (columnWidth.Max > columnWidth.Min)
            {
                columnWidth.Extra = -1;
                unsatisfiedColumnCount++;
            }
        
        while (unsatisfiedColumnCount > 0)
        {
            auto extraWidthPerColumn = (availableWidth - takenWidth) / unsatisfiedColumnCount;
            auto changesMade = false;
            
            bool tryAssignExtraWidth(scope ref ColumnDimension columnWidth, int extraWidth)
            {
                if (columnWidth.Extra >= 0)
                    return false;
                
                columnWidth.Extra = extraWidth;
                takenWidth += extraWidth;
                unsatisfiedColumnCount--;
                changesMade = true;
                
                if (unsatisfiedColumnCount == 0)
                    return true;
                
                extraWidthPerColumn = (availableWidth - takenWidth) / unsatisfiedColumnCount;
                return false;
            }
            
            foreach (ref columnWidth; columnWidths)
                if (extraWidthPerColumn > columnWidth.Max - columnWidth.Min)
                    if (tryAssignExtraWidth(columnWidth, columnWidth.Max - columnWidth.Min))
                        return;
            
            if (changesMade)
                continue;
            
            foreach (ref columnWidth; columnWidths)
                if (tryAssignExtraWidth(columnWidth, min(extraWidthPerColumn, columnWidth.Max - columnWidth.Min)))
                    return;
            
            return;
        }
    }
    
    alias ColumnBreakDefinition = Tuple!(int, "ColumnIndex", BreakDefinition, "Break");
    private ColumnBreakDefinition[] columnBreaks;
    private Nullable!BreakDefinition rowBreak;
    private Nullable!BreakDefinition reportBreak;
    
    alias ComputeDefinition = Tuple!(
        string, "Label", 
        int, "FunctionOrder", 
        IncrementalCompute, "Computer", 
        int, "BreakColumnIndex", 
        int, "ValueColumnIndex");
    
    private ReturnType!CalculateComputeDefinitions currentComputes;
    
    private auto CalculateComputeDefinitions()
    {
        return
            Program.Settings.Computes
            .map!((compute)
            {
                return choose(compute.BreakType == computes.BreakTypes.Column, 
                    cartesianProduct(compute.Functions, compute.BreakColumnNames, compute.ValuesColumnNames)
                    .map!(set => 
                        ComputeDefinition
                        (
                            set[0].Label, 
                            cast(int)set[0].ComputeType, 
                            IncrementalCompute.FromType(set[0].ComputeType), 
                            columns
                                .enumerate!int
                                .filter!(column => column.value.Name == set[1])
                                .map!(column => column.index)
                                .firstOrDefault(-1), 
                            columns
                                .enumerate!int
                                .filter!(column => column.value.Name == set[2])
                                .map!(column => column.index)
                                .firstOrDefault(-1)
                        )
                    )
                    .filter!(c => c.BreakColumnIndex >= 0 && c.ValueColumnIndex >= 0)
                , 
                    cartesianProduct(compute.Functions, compute.ValuesColumnNames)
                    .map!(set => 
                        ComputeDefinition
                        (
                            set[0].Label, 
                            cast(int)set[0].ComputeType, 
                            IncrementalCompute.FromType(set[0].ComputeType), 
                            compute.BreakType == computes.BreakTypes.Row ? -1 : -2, 
                            columns
                                .enumerate!int
                                .filter!(column => column.value.Name == set[1])
                                .map!(column => column.index)
                                .firstOrDefault(-1)
                        )
                    )
                    .filter!(c => c.ValueColumnIndex >= 0)
                );
            })
            .joiner
            .array
            .multiSort!((c1, c2) => c1.BreakColumnIndex < c2.BreakColumnIndex, 
                        (c1, c2) => c1.FunctionOrder    < c2.FunctionOrder, 
                        (c1, c2) => c1.Label            < c2.Label, 
                        (c1, c2) => c1.ValueColumnIndex < c2.ValueColumnIndex);
    }
    
    private void OutputComputes(int breakColumnIndex, ref bool columnWidthChanged)
    {
        SubstituteRecord newRecord = null;
        auto previousLabel = "";
        
        foreach (currentCompute; currentComputes)
        {
            if (currentCompute.BreakColumnIndex != breakColumnIndex)
                continue;
            
            if (previousLabel != currentCompute.Label)
            {
                newRecord = null;
                
                auto labelIndex = max(breakColumnIndex, 0);
                
                newRecord[labelIndex] = OracleField(currentCompute.Label);
                
                lines ~= Line(null, newRecord);
                
                columnWidthChanged |= UpdateObservedColumnWidth(labelIndex, currentCompute.Label.toUtf8Slice.intLength);
                
                previousLabel = currentCompute.Label;
            }
            
            auto field = DoubleToField(currentCompute.Computer.Result, columns[currentCompute.ValueColumnIndex]);
            
            newRecord[currentCompute.ValueColumnIndex] = field;
            
            auto text = FieldToString!(WidthMode.Unrestricted)(currentCompute.ValueColumnIndex, field);
            columnWidthChanged |= UpdateObservedColumnWidth(currentCompute.ValueColumnIndex, text.toUtf8Slice.intLength);
            
            currentCompute.Computer.Clear;
        }
    }
    
    void OutputBreak(BreakDefinition breakDefinition)
    {
        final switch (breakDefinition.SkipType) with (computes.SkipTypes)
        {
            case Lines:
                foreach(dummy; breakDefinition.LinesToSkip.iota)
                    lines ~= Line("");
                
                return;
                
            case Page:
                lines ~= Line("");
                lines ~= Line.Heading;
                
                return;
        }
    }
    
    this(OracleColumns columns)
    {
        this.columns = columns;
        this.columnWidths = 
            columns
            .map!(oracleColumn => ColumnDimension(oracleColumn.Name))
            .array;
        
        this.UserColumns = 
            columns
            .map!(oracleColumn => UserDefinedColumn.Columns.get(oracleColumn.Name, null))
            .array;
        
        columnBreaks = 
            Program.Settings.Breaks
            .filter!(b => b.BreakType == computes.BreakTypes.Column)
            .cartesianProduct(columns.enumerate!int)
            .filter!(pair => pair[0].ColumnName == pair[1].value.Name)
            .map!(pair => ColumnBreakDefinition(pair[1].index, pair[0]))
            .array;
        
        rowBreak = 
            Program.Settings.Breaks
            .filter!(b => b.BreakType == computes.BreakTypes.Row)
            .map!(b => nullable(b))
            .firstOrDefault(Nullable!BreakDefinition.init);
        
        reportBreak = 
            Program.Settings.Breaks
            .filter!(b => b.BreakType == computes.BreakTypes.Report)
            .map!(b => nullable(b))
            .firstOrDefault(Nullable!BreakDefinition.init);
        
        currentComputes = CalculateComputeDefinitions;
        BalanceExtraColumnSpaceAndRecalculateFullWidth;
    }
    
    private size_t indicativeTotalSize = __traits(classInstanceSize, TableBufferItem);
    public override size_t IndicativeTotalSize() const @nogc nothrow => indicativeTotalSize;
    
    private static auto RecordSize(OracleRecord fields)
    {
        auto size = OracleRecord.sizeof + OracleField.sizeof * fields.intLength;
        
        foreach (field; fields)
            size += field.sizeof + field.match!(
                (string         text) => text.intLength * 2, 
                (OracleDate     date) => date.Text.intLength * 2, 
                (OracleNumber number) => number.sizeof, 
                _ => 0
            );
        
        return size;
    }
    
    public void AddRecord(OracleRecord record)
    {
        scope(exit) lastRecord = record;
        
        totalRecordCount++;
        
        indicativeTotalSize += RecordSize(record);
        
        if (indicativeTotalSize >= MemorySettings.TrimTableSize)
        {
            auto discardLine = Program.Settings.PageSize == 0 ? 0 : 1;
            // TODO: I'm pretty sure there is a bug around here somewhere.
            // I've seen corruption in the output but I'm not sure how to 
            // replicate.  This block or SpoolLine requires a proper review.
            
            if (spooledLineCount == 0 && Program.Settings.PageSize != 0)
            {
                isSpoolingDuringCollection = true;
                SpoolLine(0);
                SpoolLine(1);
            }
            
            SpoolLine(pendingDiscardLineCount + 2);
            discardedLineCount++;
            pendingDiscardLineCount++;
            
            if (lines[discardLine].Type != Line.Types.Text)
            {
                lines[discardLine].Free(indicativeTotalSize);
                // Note, this line should never actually be visible because it is overridden
                // later by a more specific string.  However, it is useful to replace this 
                // record with text so it can be used in the correct manner.
                lines[discardLine] = Line("Earlier records were discarded to same memory."); 
            }
            
            if (indicativeTotalSize >= MemorySettings.MaxTableSize)
                TrimLinesPendingDiscard;
        }
        
        if (lines.length == 0 && Program.Settings.PageSize != 0)
            lines ~= Line.Heading;
        else if (Program.Settings.RecordSeparatorMode == Program.Settings.RecordSeparatorModes.Each)
            lines ~= Line(Program.Settings.RecordSeparatorCharacter[0].repeat(Program.Settings.LineSize).to!string);
        
        SubstituteRecord overrideRecord = null;
        auto columnWidthChanged = false;
        
        if (lastRecord != null)
        {
            auto firstApplicableBreakIndex = -1;
            
            if (!rowBreak.isNull)
            {
                auto breakDefinition = rowBreak.get;
                
                OutputComputes(-1, columnWidthChanged);
                OutputBreak(breakDefinition);
            }
            else
            {
                foreach (index, columnBreak; columnBreaks)
                    if (lastRecord[columnBreak.ColumnIndex] == record[columnBreak.ColumnIndex])
                    {
                        if (columnBreak.Break.PrintFollowingValue)
                            continue;
                        
                        overrideRecord[columnBreak.ColumnIndex] = OracleField();
                    }
                    else
                    {
                        firstApplicableBreakIndex = cast(int)index;
                        break;
                    }
                
                if (firstApplicableBreakIndex >= 0)
                    foreach (columnBreak; columnBreaks[firstApplicableBreakIndex .. $].retro)
                    {
                        OutputComputes(columnBreak.ColumnIndex, columnWidthChanged);
                        OutputBreak(columnBreak.Break);
                    }
            }
        }
        
        foreach (currentCompute; currentComputes)
            currentCompute.Computer.AddValue(FieldToDouble(record, currentCompute.ValueColumnIndex));
        
        if (overrideRecord.length == 0)
            lines ~= Line(record);
        else
            lines ~= Line(record, overrideRecord);
        
        foreach (columnIndex, column; columns)
        {
            auto text = FieldToString!(WidthMode.Unrestricted)(columnIndex, record[columnIndex]);
            columnWidthChanged |= UpdateObservedColumnWidth(columnIndex, text.toUtf8Slice.intLength);
            
            auto userColumn = UserColumns[columnIndex];
            if (userColumn !is null && userColumn.IsEnabled)
            {
                if (userColumn.NewValueVariableName.length > 0)
                    Program.Settings.SetSubstitutionVariable(userColumn.NewValueVariableName, text);
                
                if (userColumn.OldValueVariableName.length > 0 && lastRecord != null)
                {
                    text = FieldToString!(WidthMode.Unrestricted)(columnIndex, lastRecord[columnIndex]);
                    Program.Settings.SetSubstitutionVariable(userColumn.OldValueVariableName, text);
                }
            }
        }
        
        if (columnWidthChanged)
            BalanceExtraColumnSpaceAndRecalculateFullWidth;
    }
    
    public auto IsQueryComplete = false;
    private auto spooledLineCount = 0;
    private auto isSpoolingDuringCollection = false;
    
    public void QueryComplete()
    {
        if (IsQueryComplete)
            return;
        
        IsQueryComplete = true;
        
        auto columnWidthChanged = false;
        
        if (!rowBreak.isNull)
        {
            OutputComputes(-1, columnWidthChanged);
            OutputBreak(rowBreak.get);
        }
        
        if (!reportBreak.isNull)
        {
            OutputComputes(-2, columnWidthChanged);
            OutputBreak(reportBreak.get);
        }
        
        foreach (columnBreak; columnBreaks.retro)
            OutputComputes(columnBreak.ColumnIndex, columnWidthChanged);
        
        if (columnWidthChanged)
            BalanceExtraColumnSpaceAndRecalculateFullWidth;
        
        TrimLinesPendingDiscard;
        Spool;
    }
    
    public override int LineCount() const => lines.intLength - pendingDiscardLineCount;
    
    private auto widthInCharacters = 0;
    public override int WidthInCharacters() const => widthInCharacters;
    
    private void TrimLinesPendingDiscard()
    {
        if (pendingDiscardLineCount == 0)
            return;
        
        // First line should be header.  // TODO: not if PageSize == 0.
        // Second line should be the discarded line warning.
        
        assert (lines.length > pendingDiscardLineCount + 2, "Lines pending discard was expected to be less than lines collected.");
        
        foreach (pendingDiscardLineIndex; 2 .. pendingDiscardLineCount + 2)
            lines[pendingDiscardLineIndex].Free(indicativeTotalSize);
        
        lines.linearRemove(lines[2 .. pendingDiscardLineCount + 2]);
        pendingDiscardLineCount = 0;
    }
    
    public override void Free()
    {   
        foreach (line; lines)
            line.Free(indicativeTotalSize);
        
        lines.clear;
        
        foreach (column; columns)
            column.Free;
        
        super.Free;
    }
    
    public bool IsHeaderRow(const int lineNumber) const => lines[lineNumber].Type == Line.Types.Heading;
    
    public bool IsTextRow(const int lineNumber) const => lines[lineNumber].Type == Line.Types.Text;
    
    public override const (char)[] TextAt(const int lineNumber, const int start, const int width, const int screenLine) const
    {
        static char[MaxTemporaryTextWidth] destination;
        int startOffset = start;
        int destinationPosition = 0;
        
        void Append(string text, int requiredWidth)
        {
            if (startOffset >= requiredWidth)
            {
                startOffset -= requiredWidth;
                return;
            }
            
            const textLength = text.toUtf8Slice.length;
            
            if (startOffset > 0)
            {
                auto oldStartOffset = startOffset;
                startOffset = 0;
                
                if (textLength <= oldStartOffset)
                    Append("", requiredWidth - oldStartOffset);
                else
                    Append(text.toUtf8Slice[oldStartOffset .. $], requiredWidth - oldStartOffset);
                
                return;
            }
            
            text = text.toUtf8Slice[0 .. min(textLength, requiredWidth)];
            
            auto newDestinationPosition = min(destination.intLength, destinationPosition + text.intLength);
            destination[destinationPosition .. newDestinationPosition] = text[0 .. (newDestinationPosition - destinationPosition)];
            destinationPosition = newDestinationPosition;
            
            requiredWidth -= text.toUtf8Slice.intLength;
            
            if (requiredWidth <= 0)
                return;
            
            newDestinationPosition = min(destination.intLength, destinationPosition + requiredWidth);
            destination[destinationPosition .. newDestinationPosition] = ' ';
            destinationPosition = newDestinationPosition;
        }
        
        auto line = lines[lineNumber];
        
        const lastColumnIndex = columns.intLength - 1;
        if (line.Type == Line.Types.Heading || (screenLine == 0 && Program.Settings.PageSize != 0))
        {
            foreach (columnIndex, column; columns)
            {
                if (destination[0 .. destinationPosition].toUtf8Slice.length >= width)
                    break;
                
                Append(HeadingAt(columnIndex), ColumnWidth(columnIndex));
                
                if (columnIndex < lastColumnIndex)
                {
                    auto userColumn = UserColumns[columnIndex];
                    
                    if (userColumn is null || !userColumn.IsEnabled || userColumn.IsVisible)
                        Append(Program.Settings.ColumnSeparatorString, Program.Settings.ColumnSeparatorDString.intLength);
                }
            }
        }
        else if (lineNumber == 1 && discardedLineCount > 0)
        {
            static char[59] discardedRecordCountAsStringLocation = "             earlier records were discarded to save memory.";
            static int discardedLineCountCache = 0;
            
            const tempDiscardedLineCount = discardedLineCount + 1;
            
            if (discardedLineCountCache != tempDiscardedLineCount)
            {
                toStringEmplace!12(tempDiscardedLineCount, discardedRecordCountAsStringLocation);
                discardedLineCountCache = tempDiscardedLineCount;
            }
            
            const charactersToSkip = (cast(const(char)[])discardedRecordCountAsStringLocation).countUntil!(c => c != ' ');
            
            return discardedRecordCountAsStringLocation[charactersToSkip .. $][0 .. min($, width)];
        }
        else
        {
            if (line.Type == Line.Types.Text)
            {
                if (start > line.Text.toUtf8Slice.length)
                    return "";
                
                return line.Text.toUtf8Slice[start .. min(line.Text.toUtf8Slice.length, start + width)];
            }
            
            foreach (columnIndex, column; columns)
            {
                if (destination[0 .. destinationPosition].toUtf8Slice.length >= width)
                    break;
                
                Append(line.TextAt!(WidthMode.RestrictToColumn)(this, columnIndex), ColumnWidth(cast(int)columnIndex));
                
                if (columnIndex < lastColumnIndex)
                {
                    auto userColumn = UserColumns[columnIndex];
                    
                    if (userColumn is null || !userColumn.IsEnabled || userColumn.IsVisible)
                        Append(Program.Settings.ColumnSeparatorString, Program.Settings.ColumnSeparatorDString.intLength);
                }
            }
        }
        
        auto destinationUtf8 = destination[0 .. destinationPosition].toUtf8Slice;
        return destinationUtf8[0 .. min(width, destinationUtf8.length)];
    }
    
    public int ColumnIndexAt(
        const int columnInCharacters, 
        out int columnStartInCharacters, 
        out int columnWidth) const @nogc nothrow
    {
        columnStartInCharacters = 0;
        foreach (columnIndex, _; columns)
        {
            columnWidth = ColumnWidth(columnIndex);
            immutable columnEndInCharacters = columnStartInCharacters + columnWidth + Program.Settings.ColumnSeparatorDString.intLength;
            
            if (columnStartInCharacters <= columnInCharacters && columnInCharacters < columnEndInCharacters)
                return cast(int)columnIndex;
            
            columnStartInCharacters = columnEndInCharacters;
        }
        
        return -1;
    }
    
    public string FullColumnTextAt(
        const int lineNumber, 
        const int screenLine, 
        const int columnInCharacters, 
        out int columnStartInCharacters, 
        out int columnWidth) const 
    {
        if (lineNumber == 1 && discardedLineCount > 0)
            return null;
        
        const columnIndex = ColumnIndexAt(columnInCharacters, columnStartInCharacters, columnWidth);
        if (columnIndex < 0)
            return null;
        
        auto line = lines[lineNumber];
        if (line.Type == Line.Types.Text)
            return null;
        
        if (line.Type == Line.Types.Heading || lineNumber == 0 || screenLine == 0)
            return HeadingAt(columnIndex);
        else
            return line.TextAt!(WidthMode.Unrestricted)(this, columnIndex);
    }
    
    public string[] RolloverText(
        const int lineNumber, 
        const int screenLine, 
        const int columnInCharacters, 
        const int windowWidthInCharacters, 
        out int columnStartInCharacters, 
        out int rolloverTextWidthInCharacters) const
    {
        rolloverTextWidthInCharacters = 0;
        int columnWidth;
        
        const text = FullColumnTextAt(lineNumber, screenLine, columnInCharacters, columnStartInCharacters, columnWidth);
        if (text.toUtf8Slice.length <= columnWidth && !text.any!(c => c == '\n'))
            return null;
        
        auto textLines = text.split('\n');
        
        foreach (textLine; textLines)
            rolloverTextWidthInCharacters = max(rolloverTextWidthInCharacters, textLine.toUtf8Slice.intLength);
        
        return textLines;
    }
    
    private string HeadingAt(const size_t columnIndex) const pure @nogc nothrow
    {
        auto userColumn = UserColumns[columnIndex];
        
        if (userColumn !is null &&
            userColumn.IsEnabled && 
            userColumn.Heading.length > 0)
            return userColumn.Heading;
        
        return columns[columnIndex].Name;
    }
    
    public override string FindNextInLine(
        const string searchTextUpperCase, 
        const int lineNumber, 
        ref int matchStart, 
        ref int matchEnd, 
        ref int matchColumn, 
        ref int columnMatchStart, 
        ref int columnMatchEnd) const
    {
        if (lineNumber >= lines.length)
            return "";
    
        auto lineSource = lines[lineNumber];
        if (lineSource.Type == Line.Types.Text)
            return super.FindNextInLine(
                searchTextUpperCase, 
                lineNumber, 
                matchStart, 
                matchEnd, 
                matchColumn, 
                columnMatchStart, 
                columnMatchEnd);
        
        auto columnStart = 0;
        foreach (columnIndex, column; columns)
        {
            const columnWidth = ColumnWidth(columnIndex);
            
            scope (exit)
                columnStart += columnWidth + Program.Settings.ColumnSeparatorDString.intLength;
            
            if (columnIndex < matchColumn)
                continue;
            
            auto fieldText = lineSource.TextAt!(WidthMode.Unrestricted)(this, columnIndex);
            
            columnMatchStart = max(0, min(columnMatchStart, fieldText.toUtf8Slice.intLength));
            fieldText = fieldText.toUtf8Slice[columnMatchStart .. $];
            
            auto searchTextUpperCaseUtf32 = searchTextUpperCase.to!dstring;
            auto matchOffset = fieldText.toUpper.byDchar.countUntil(searchTextUpperCaseUtf32);
            if (matchOffset >= 0)
            {
                matchColumn = cast(int)columnIndex;
                columnMatchStart += matchOffset;
                columnMatchEnd = columnMatchStart + searchTextUpperCaseUtf32.intLength;
                
                matchStart = columnStart + min(columnWidth - 1, columnMatchStart);
                matchEnd   = columnStart + min(columnWidth,     columnMatchEnd);
                return fieldText.toUtf8Slice[matchOffset .. matchOffset + searchTextUpperCaseUtf32.length];
            }
            
            columnMatchStart = 0;
        }
        
        return "";
    }
    
    
    public override string FindPreviousInLine(
        const string searchTextUpperCase, 
        const int lineNumber, 
        ref int matchStart, 
        ref int matchEnd, 
        ref int matchColumn, 
        ref int columnMatchStart, 
        ref int columnMatchEnd) const
    {
        if (lineNumber >= lines.length)
            return "";
        
        auto lineSource = lines[lineNumber];
        if (lineSource.Type == Line.Types.Text)
            return super.FindPreviousInLine(
                searchTextUpperCase, 
                lineNumber, 
                matchStart, 
                matchEnd, 
                matchColumn, 
                columnMatchStart, 
                columnMatchEnd);
        
        // Calculate the full table width first.
        auto columnStart = 0;
        foreach (columnIndex, column; columns)
        {
            if (columnIndex > 0)
                columnStart += Program.Settings.ColumnSeparatorDString.intLength;
            
            columnStart += ColumnWidth(columnIndex);
        }
        
        auto columnIndex = columns.intLength;
        foreach (column; columns.retro)
        {
            columnIndex--;
         
            if (columnIndex < columns.length - 1)
                columnStart -= Program.Settings.ColumnSeparatorDString.intLength;
            
            const columnWidth = ColumnWidth(columnIndex);
            columnStart -= columnWidth;
            
            if (columnIndex > matchColumn)
                continue;
            
            auto fieldText = lineSource.TextAt!(WidthMode.Unrestricted)(this, columnIndex);
            
            columnMatchEnd = max(0, min(columnMatchEnd, fieldText.toUtf8Slice.intLength));
            fieldText = fieldText.toUtf8Slice[0 .. columnMatchEnd];
            
            auto searchTextUpperCaseUtf32 = searchTextUpperCase.to!dstring;
            auto matchOffset = fieldText.toUpper.byDchar.retro.countUntil(searchTextUpperCaseUtf32.retro);
            if (matchOffset >= 0)
            {
                matchColumn = columnIndex;
                columnMatchEnd -= matchOffset;
                columnMatchStart = columnMatchEnd - searchTextUpperCaseUtf32.intLength;
                
                matchStart = columnStart + min(columnWidth - 1, columnMatchStart);
                matchEnd   = columnStart + min(columnWidth,     columnMatchEnd);
                return fieldText.toUtf8Slice[columnMatchStart .. columnMatchEnd];
            }
            
            columnMatchEnd = int.max;
        }
        
        return "";
    }
    
    private void SpoolLine(const int lineNumber)
    {
        if (!Program.Buffer.IsSpooling)
            return;
    
        auto line = lines[lineNumber];
        spooledLineCount++;
        
        if (line.Type == Line.Types.Heading)
        {
            auto text = appender!string;
            auto underLine = appender!string;
            foreach (columnIndex, column; columns)
            {
                if (columnIndex > 0)
                {
                    text.put(Program.Settings.ColumnSeparatorString);
                    underLine.put(Program.Settings.ColumnSeparatorString);
                }
                
                auto width = ColumnWidth!true(columnIndex);
                auto heading = HeadingAt(columnIndex);
                
                underLine.put(repeat(Program.Settings.UnderlineCharacter, width));
                
                if (heading.toUtf8Slice.length > width)
                    heading = heading.toUtf8Slice[0 .. width];
                
                text.put(heading);
                
                if (columnIndex == columns.length - 1)
                    break;
                
                if (width > heading.toUtf8Slice.length)
                    text.put(repeat(' ', width - heading.toUtf8Slice.intLength));
            }
            
            Program.Buffer.Spool(text.data);
            
            if (Program.Settings.IsUnderlineEnabled)
                Program.Buffer.Spool(underLine.data);
            
            return;
        }
        
        if (line.Type == Line.Types.Text)
        {
            Program.Buffer.Spool(line.Text);
            return;
        }
        
        auto text = appender!string;
        foreach (columnIndex, column; columns)
        {
            if (columnIndex > 0)
                text.put(Program.Settings.ColumnSeparatorString);
            
            auto width = ColumnWidth!true(columnIndex);
            
            auto fieldText = line.TextAt!(WidthMode.RestrictToColumn)(this, columnIndex);
            
            if (fieldText.toUtf8Slice.length > width)
                fieldText = fieldText.toUtf8Slice[0 .. width];
            
            text.put(fieldText);
            
            if (columnIndex == columns.length - 1)
                break;
            
            if (width > fieldText.toUtf8Slice.length)
                text.put(repeat(' ', width - fieldText.toUtf8Slice.intLength));
        }
        
        Program.Buffer.Spool(text.data);
    }
    
    private void Spool()
    {
        if (!Program.Buffer.IsSpooling)
            return;
        
        const firstRow = isSpoolingDuringCollection ? pendingDiscardLineCount + 2 : 0;
        
        foreach (lineIndex; firstRow .. lines.intLength)
            SpoolLine(lineIndex);
    }
    
    public override string CopyWholeItem() const 
    {
        auto fullText = appender!string;
        
        foreach (line; lines)
        {
            foreach (columnIndex, column; columns)
            {
                if (columnIndex > 0)
                    fullText.put('\t');
                
                if (line.Type == Line.Types.Record && 
                    line.Record[columnIndex].match!(
                        (date)
                        {
                            const isoDate = date.Value.toISOExtString;
                            
                            // So Excel will try and parse anything into a date like "3-5"
                            // or whatever, except ISO dates.  WTF?
                            fullText.put(isoDate[0 .. 10]);
                            fullText.put(' ');
                            fullText.put(isoDate[11 .. $]);
                            
                            return true;
                        }, 
                        _ => false
                    ))
                    continue;
                
                const text = line.TextAt!(WidthMode.Unrestricted)(this, columnIndex);
                
                // Forcing an excel formula fixes many of the issues caused by Excel 
                // trying to be clever and parsing cells incorrectly.  However, this 
                // breaks nested carriage returns FFS.
                
                if (text.findAmong("\r\n").length == 0)
                    fullText.put('=');
                
                fullText.put('\"');
                fullText.put(text.replace("\"", "\"\""));
                fullText.put('\"');                
            }
            
            fullText.put(lineEnding);
        }
        
        return fullText.data;
    }
    
    
    enum WidthMode { RestrictToColumn, Unrestricted }
    
    private string FieldToString(WidthMode restrictWidthToColumn)(const size_t columnIndex, immutable OracleField value) const
    {
        auto column = columns[columnIndex];
        auto userColumn = UserColumns[columnIndex];
        auto hasUserColumn = userColumn !is null && 
                             userColumn.IsEnabled;
        
        auto text = value.match!(
            (NullField _) 
            {
                if (hasUserColumn)
                    return userColumn.NullPlaceHolder;
                else
                    return "";
            }, 
            (const string         text) => text, 
            (const OracleDate     date) => date.Text, 
            (const OracleNumber number) 
            {
                string format = "";
                int width = -1;
                
                if (userColumn !is null && 
                    userColumn.IsEnabled)
                {
                    if (userColumn.isNumericFormat)
                        format = userColumn.FormatSpecifier;
                    else
                        width = userColumn.Width;
                }
                
                if (format.length == 0)
                    format = column.DefaultFormat;
                
                if (width < 0)
                    width = columnWidths[columnIndex].Max;
                
                auto text = number.formatNumber(format);
                static if (restrictWidthToColumn == WidthMode.RestrictToColumn)
                {
                    // I'm not sure how I'm supposed to know what the actual length is 
                    // without parsing all possible format codes.  
                    
                    if (text.toUtf8Slice.length > width)
                        return replicate("#", width);
                }
                
                return text.to!string; // TODO consider making this const(char)[].
            }, 
        );
        
        if (!hasUserColumn || !userColumn.IsEnabled || userColumn.Justify == JustificationMode.Left)
            return text;
        
        int width = ColumnWidth(columnIndex);
        
        import std.string : center, rightJustify; 
        
        final switch (userColumn.Justify) with (JustificationMode)
        {
            case Centre:
                return center(text, width);
            
            case Right:
                return rightJustify(text, width);
            
            case Left:
                assert(false, "Logic error in user defined column with Left alignment.");
        }
    }
    
    private static immutable SysTime baseSysTime = SysTime(DateTime(1900, 1, 1), UTC());
    
    double FieldToDouble(const OracleRecord record, const size_t columnIndex)
    {
        return record[columnIndex].match!(
            (NullField         _) => double.init, 
            (OracleNumber number) => number.to!double, 
            (OracleDate     date) => cast(double)((date.Value - baseSysTime).total!"hnsecs"), 
            (string         text) 
            {
                try
                    return text.to!double;
                catch (ConvException) 
                    return double.init;
            }
        );
    }
    
    OracleField DoubleToField(const double value, immutable OracleColumn column)
    {
        if (isNaN(value))
            return OracleField(NullField());
        
        switch (column.Type)
        {
            case OracleColumn.Types.Number: return OracleField(OracleNumber(value));
            case OracleColumn.Types.DateTime:
                import oracle : toOracleDate;
                return OracleField((baseSysTime + dur!"hnsecs"(cast(long)value)).toOracleDate);
            case OracleColumn.Types.String:  
                return OracleField(value.to!string);
            
            default: return OracleField(NullField());
        }
    }
}
