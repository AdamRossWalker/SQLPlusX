module syntax;

import std.array : split;
import std.ascii : isAlpha, isAlphaNum;
import std.string : toUpper;
import std.typecons : Tuple;

import program;

public final class Syntax
{
    private const NamedColor[string] keywordLookUp;
    
    public struct CarryOverHighlightingState
    {
        public bool isInMultiLineComment = false;
        public bool isInMultiLineSingleQuotes = false;
        public bool isInMultiLineDoubleQuotes = false;
    }
    
    public FormattedText[] Highlight(const string text)
    {
        return Highlight(text.split(lineEnding));
    }
    
    public FormattedText[] Highlight(const string text, ref CarryOverHighlightingState state, const int cursorLine = -1, const int cursorColumn = -1, ubyte opacity = 255)
    {
        return Highlight(text.split(lineEnding), state, cursorLine, cursorColumn, opacity);
    }
    
    public FormattedText[] Highlight(const string[] lines, const int cursorLine = -1, const int cursorColumn = -1, ubyte opacity = 255)
    {
        auto state = CarryOverHighlightingState();
        return Highlight(lines, state, cursorLine, cursorColumn, opacity);
    }
    
    public FormattedText[] Highlight(const string[] lines, ref CarryOverHighlightingState state, const int cursorLine = -1, const int cursorColumn = -1, ubyte opacity = 255)
    {
        if (lines.length == 0)
            return [FormattedText("")];
        
        alias Location = Tuple!(int, "Line", int, "Column");
        
        Location[4] bracketLocations = Location(-1, -1);
        auto bracketLocationCount = 0;
        
        void AddTwoLocations(const Location location1, const Location location2)
        {
            if (location1.Line   >= 0 && 
                location1.Line   < lines.length && 
                location1.Column >= 0 && 
                location1.Column < lines[location1.Line].length &&
                location2.Line   >= 0 && 
                location2.Line   < lines.length && 
                location2.Column >= 0 && 
                location2.Column < lines[location2.Line].length)
            {
                bracketLocations[bracketLocationCount] = location1;
                bracketLocationCount++;
                
                bracketLocations[bracketLocationCount] = location2;
                bracketLocationCount++;
            }
        }
        
        if (cursorLine   >= 0 && cursorLine   < lines.length && 
            cursorColumn >= 0 && cursorColumn < lines[cursorLine].length)
        {
            Location findNext(const char character, const int startLine, const int startColumn)
            {
                for (int line = startLine; line < lines.length; line++)
                {
                    const lineStartColumn = line == startLine ? startColumn : 0;
                    
                    for (int column = lineStartColumn; line < lines.length && column < lines[line].length; column++)
                    {
                        if (lines[line][column] == character &&
                               (character != '*' ||
                                   (column + 1 < lines[line].length && 
                                    lines[line][column + 1] == '/')))
                        {
                            return Location(line, column);
                        }
                        
                        if (character == '\'' || character == '\"' || character == '*')
                            continue;
                        
                        if (lines[line][column] == '\'')
                        {
                            const match = findNext('\'', line, column + 1);
                            line   = match.Line;
                            column = match.Column;
                            continue;
                        }
                        
                        if (lines[line][column] == '\"')
                        {
                            const match = findNext('\"', line, column + 1);
                            line   = match.Line;
                            column = match.Column;
                            continue;
                        }
                        
                        if (lines[line][column] == '(')
                        {
                            const match = findNext(')', line, column + 1);
                            line   = match.Line;
                            column = match.Column;
                            continue;
                        }
                        
                        if (lines[line][column] == '[')
                        {
                            const match = findNext(']', line, column + 1);
                            line   = match.Line;
                            column = match.Column;
                            continue;
                        }
                        
                        if (lines[line][column] == '{')
                        {
                            const match = findNext('}', line, column + 1);
                            line   = match.Line;
                            column = match.Column;
                            continue;
                        }
                        
                        if (lines[line][column] == '/' && column + 1 < lines[line].length && lines[line][column + 1] == '*')
                        {
                            const match = findNext('*', line, column + 2);
                            line   = match.Line;
                            column = match.Column;
                            continue;
                        }
                    }
                }
                
                return Location(lines.intLength, 0);
            }
            
            
            Location findPrevious(const char character, const int startLine, const int startColumn)
            {
                if (startLine >= 0)
                    for (int line = startLine; line >= 0; line--)
                    {
                        const lineStartColumn = line == startLine ? startColumn : lines[line].intLength - 1;
                        
                        for (int column = lineStartColumn; line >= 0 && column >= 0; column--)
                        {
                            if (lines[line][column] == character &&
                                   (character != '*' ||
                                       (column > 0 && 
                                        lines[line][column - 1] == '/')))
                            {
                                return Location(line, column);
                            }
                            
                            if (character == '\'' || character == '\"' || character == '*')
                                continue;
                            
                            if (lines[line][column] == ')')
                            {
                                const match = findPrevious('(', line, column - 1);
                                line   = match.Line;
                                column = match.Column;
                                continue;
                            }
                            
                            if (lines[line][column] == ']')
                            {
                                const match = findPrevious('[', line, column - 1);
                                line   = match.Line;
                                column = match.Column;
                                continue;
                            }
                            
                            if (lines[line][column] == '}')
                            {
                                const match = findPrevious('{', line, column - 1);
                                line   = match.Line;
                                column = match.Column;
                                continue;
                            }
                            
                            if (lines[line][column] == '\'')
                            {
                                const match = findPrevious('\'', line, column - 1);
                                line   = match.Line;
                                column = match.Column;
                                continue;
                            }
                            
                            if (lines[line][column] == '\"')
                            {
                                const match = findPrevious('\"', line, column - 1);
                                line   = match.Line;
                                column = match.Column;
                                continue;
                            }
                            
                            if (lines[line][column] == '/' && column > 0 && lines[line][column - 1] == '*')
                            {
                                const match = findPrevious('*', line, column - 2);
                                line   = match.Line;
                                column = match.Column;
                                continue;
                            }
                        }
                    }
                
                return Location(-1, 0);
            }
            
            const characterLeft  = cursorColumn == 0 ? ' ' : lines[cursorLine][cursorColumn - 1];
            const characterRight = lines[cursorLine][cursorColumn];
            
            if      (characterLeft  == '(') AddTwoLocations(findNext(')', cursorLine, cursorColumn), Location(cursorLine, cursorColumn - 1));
            else if (characterLeft  == '[') AddTwoLocations(findNext(']', cursorLine, cursorColumn), Location(cursorLine, cursorColumn - 1));
            else if (characterLeft  == '{') AddTwoLocations(findNext('}', cursorLine, cursorColumn), Location(cursorLine, cursorColumn - 1));
            
            if      (characterRight == ')') AddTwoLocations(findPrevious('(', cursorLine, cursorColumn - 1), Location(cursorLine, cursorColumn));
            else if (characterRight == ']') AddTwoLocations(findPrevious('[', cursorLine, cursorColumn - 1), Location(cursorLine, cursorColumn));
            else if (characterRight == '}') AddTwoLocations(findPrevious('{', cursorLine, cursorColumn - 1), Location(cursorLine, cursorColumn));
        }
        
        FormattedText[] formattedLines;
        formattedLines.reserve(lines.length);
        
        nextLineLoop: 
        foreach (lineNumber, text; lines)
        {
            auto formattedLine = FormattedText(text, null);
            scope(exit) formattedLines ~= formattedLine;
            
            auto index = 0;
            auto unformattedTextStart = 0;
            
            void AddFormatting(const int formattingStartIndex, const int formattingEndIndex, const NamedColor color, const FontStyle style) nothrow
            {
                if (unformattedTextStart < formattingStartIndex)
                    formattedLine.Add(unformattedTextStart, formattingStartIndex, NamedColor.Normal, FontStyle.Normal, opacity);
                
                if (formattingStartIndex < formattingEndIndex)
                    formattedLine.Add(formattingStartIndex, formattingEndIndex, color, style, opacity);
                
                unformattedTextStart = formattingEndIndex;
            }
            
            thisLineLoop: 
            while (index < text.length)
            {
                const startIndex = index;
                const character = text[index];
                
                if (state.isInMultiLineComment ||
                     (character == '/' && 
                     index + 1 < text.length && 
                     text[index + 1] == '*'))
                {   
                    if (!state.isInMultiLineComment)
                        index += 2;
                    
                    while (index < text.length)
                    {
                        const nextCharacter = text[index];
                        
                        if (nextCharacter == '*' &&
                            index + 1 < text.length &&
                            text[index + 1] == '/')
                        {
                            index += 2;
                            AddFormatting(startIndex, index, NamedColor.Comment, FontStyle.Normal);
                            state.isInMultiLineComment = false;
                            continue thisLineLoop;
                        }
                        
                        index++;
                    }
                    
                    // Here, we didn't see the end of this comment on this line.
                    state.isInMultiLineComment = true;
                    AddFormatting(startIndex, text.intLength, NamedColor.Comment, FontStyle.Normal);
                    continue nextLineLoop;
                }
                
                if (character == '-' && 
                         index + 1 < text.length && 
                         text[index + 1] == '-')
                {
                    AddFormatting(startIndex, text.intLength, NamedColor.Comment, FontStyle.Normal);
                    continue nextLineLoop;
                }
                
                if (character.isAlpha || character == '_')
                {
                    index++;
                    
                    while (index < text.length)
                    {
                        const nextCharacter = text[index];
                        
                        if (!nextCharacter.isAlphaNum && nextCharacter != '_')
                            break;
                        
                        index++;
                    }
                    
                    const word = text[startIndex .. index].toUpper;
                    
                    if (const colorRef = word in keywordLookUp)
                        AddFormatting(startIndex, index, *colorRef, FontStyle.Bold);
                    else if (const colorRef = word in Program.AutoCompleteDatabase.IdentifierLookup)
                        AddFormatting(startIndex, index, *colorRef, FontStyle.Normal);
                    
                    continue thisLineLoop;
                }
                
                if (state.isInMultiLineSingleQuotes || character == '\'')
                {
                    if (!state.isInMultiLineSingleQuotes)
                        index++;
                    
                    while (index < text.length && text[index] != '\'')
                        index++;
                    
                    state.isInMultiLineSingleQuotes = index == text.length;
                    
                    if (!state.isInMultiLineSingleQuotes)
                        index++;
                    
                    AddFormatting(startIndex, index, NamedColor.String, FontStyle.Normal);
                    
                    continue thisLineLoop;
                }
                
                if (state.isInMultiLineDoubleQuotes || character == '"')
                {
                    if (!state.isInMultiLineDoubleQuotes)
                        index++;
                    
                    while (index < text.length && text[index] != '"')
                        index++;
                    
                    state.isInMultiLineDoubleQuotes = index == text.length;
                    
                    if (!state.isInMultiLineDoubleQuotes)
                        index++;
                    
                    const word = text[startIndex .. index];
                    
                    if (const colorRef = word in Program.AutoCompleteDatabase.IdentifierLookup)
                        AddFormatting(startIndex, index, *colorRef, FontStyle.Bold);
                    else
                        AddFormatting(startIndex, index, NamedColor.QuotedIdentifier, FontStyle.Bold);
                    
                    continue thisLineLoop;
                }
                
                if (character == '(' || character == ')' || 
                    character == '[' || character == ']' || 
                    character == '{' || character == '}')
                {
                    foreach (location; bracketLocations)
                        if (location.Line == lineNumber && 
                            location.Column == index)
                        {
                            AddFormatting(index, index + 1, NamedColor.Alert, FontStyle.Bold);
                            index++;
                            continue thisLineLoop;
                        }
                }
                
                index++;
            }
            
            AddFormatting(text.intLength, text.intLength, NamedColor.Normal, FontStyle.Normal);
        }
        
        return formattedLines;
    }
    
    this()
    {
        keywordLookUp = 
        [
            "ABORT":                         NamedColor.Keyword, 
            "ACCEPT":                        NamedColor.Keyword, 
            "ACCESS":                        NamedColor.Keyword, 
            "ADD":                           NamedColor.Keyword, 
            "ALL":                           NamedColor.Keyword, 
            "AND":                           NamedColor.Keyword, 
            "ANY":                           NamedColor.Keyword, 
            "ARRAY":                         NamedColor.Keyword, 
            "ARRAYLEN":                      NamedColor.Keyword, 
            "AS":                            NamedColor.Keyword, 
            "ASC":                           NamedColor.Keyword, 
            "ASSERT":                        NamedColor.Keyword, 
            "ASSIGN":                        NamedColor.Keyword, 
            "AT":                            NamedColor.Keyword, 
            "AUDIT":                         NamedColor.Keyword, 
            "AUTHID":                        NamedColor.Keyword, 
            "AUTHORIZATION":                 NamedColor.Keyword, 
            "BASE_TABLE":                    NamedColor.Keyword, 
            "BEGIN":                         NamedColor.Keyword, 
            "BETWEEN":                       NamedColor.Keyword, 
            "BFILENAME":                     NamedColor.Keyword, 
            "BINARY_FLOAT":                  NamedColor.Keyword, 
            "BINARY_INTEGER":                NamedColor.Keyword, 
            "BLOB":                          NamedColor.Keyword, 
            "BODY":                          NamedColor.Keyword, 
            "BOOLEAN":                       NamedColor.Keyword, 
            "BULK":                          NamedColor.Keyword, 
            "BY":                            NamedColor.Keyword, 
            "CASE":                          NamedColor.Keyword, 
            "CHAR":                          NamedColor.Keyword, 
            "CHAR_BASE":                     NamedColor.Keyword, 
            "CHECK":                         NamedColor.Keyword, 
            "CLOB":                          NamedColor.Keyword, 
            "CLOSE":                         NamedColor.Keyword, 
            "CLUSTER":                       NamedColor.Keyword, 
            "CLUSTERS":                      NamedColor.Keyword, 
            "COLAUTH":                       NamedColor.Keyword, 
            "COLLECT":                       NamedColor.Keyword, 
            "COLUMN":                        NamedColor.Keyword, 
            "COLUMNS":                       NamedColor.Keyword, 
            "COMMENT":                       NamedColor.Keyword, 
            "COMPRESS":                      NamedColor.Keyword, 
            "CONNECT":                       NamedColor.Keyword, 
            "CONSTANT":                      NamedColor.Keyword, 
            "CONSTRAINT":                    NamedColor.Keyword, 
            "CONTINUE":                      NamedColor.Keyword, 
            "CRASH":                         NamedColor.Keyword, 
            "CROSS":                         NamedColor.Keyword, 
            "CURRENT":                       NamedColor.Keyword, 
            "CURRENT_TIMESTAMP":             NamedColor.Keyword, 
            "CURRVAL":                       NamedColor.Keyword, 
            "CURSOR":                        NamedColor.Keyword, 
            "DATABASE":                      NamedColor.Keyword, 
            "DATA_BASE":                     NamedColor.Keyword, 
            "DATE":                          NamedColor.Keyword, 
            "DBA":                           NamedColor.Keyword, 
            "DEBUGOFF":                      NamedColor.Keyword, 
            "DEBUGON":                       NamedColor.Keyword, 
            "DECIMAL":                       NamedColor.Keyword, 
            "DECLARE":                       NamedColor.Keyword, 
            "DEFAULT":                       NamedColor.Keyword, 
            "DEFINER":                       NamedColor.Keyword, 
            "DEFINITION":                    NamedColor.Keyword, 
            "DELAY":                         NamedColor.Keyword, 
            "DELTA":                         NamedColor.Keyword, 
            "DENSE_RANK":                    NamedColor.Keyword, 
            "DESC":                          NamedColor.Keyword, 
            "DETERMINISTIC":                 NamedColor.Keyword, 
            "DIRECTORY":                     NamedColor.Keyword, 
            "DISPOSE":                       NamedColor.Keyword, 
            "DISTINCT":                      NamedColor.Keyword, 
            "DO":                            NamedColor.Keyword, 
            "ELSE":                          NamedColor.Keyword, 
            "ELSIF":                         NamedColor.Keyword, 
            "EMPTY_BLOB":                    NamedColor.Keyword, 
            "EMPTY_CLOB":                    NamedColor.Keyword, 
            "END":                           NamedColor.Keyword, 
            "ENTRY":                         NamedColor.Keyword, 
            "ESCAPE":                        NamedColor.Keyword, 
            "ESCEIPTION_INIT":               NamedColor.Keyword, 
            "EXCEPTION":                     NamedColor.Keyword, 
            "EXECUTE":                       NamedColor.Keyword, 
            "EXISTS":                        NamedColor.Keyword, 
            "EXIT":                          NamedColor.Keyword, 
            "EXTEND":                        NamedColor.Keyword, 
            "EXTEND":                        NamedColor.Keyword, 
            "EXTRACT":                       NamedColor.Keyword, 
            "FALSE":                         NamedColor.Keyword, 
            "FETCH":                         NamedColor.Keyword, 
            "FILE":                          NamedColor.Keyword, 
            "FIRST":                         NamedColor.Keyword, 
            "FLOAT":                         NamedColor.Keyword, 
            "FOLLOWING":                     NamedColor.Keyword, 
            "FOR":                           NamedColor.Keyword, 
            "FORALL":                        NamedColor.Keyword, 
            "FOREIGN":                       NamedColor.Keyword, 
            "FORMAT":                        NamedColor.Keyword, 
            "FOUND":                         NamedColor.Keyword, 
            "FROM":                          NamedColor.Keyword, 
            "FULL":                          NamedColor.Keyword, 
            "FUNCTION":                      NamedColor.Keyword, 
            "GENERIC":                       NamedColor.Keyword, 
            "GLOBAL":                        NamedColor.Keyword, 
            "GOTO":                          NamedColor.Keyword, 
            "GRANT":                         NamedColor.Keyword, 
            "GROUP":                         NamedColor.Keyword, 
            "HAVING":                        NamedColor.Keyword, 
            "HEADING":                       NamedColor.Keyword, 
            "IDENTIFIED":                    NamedColor.Keyword, 
            "IF":                            NamedColor.Keyword, 
            "IMMEDIATE":                     NamedColor.Keyword, 
            "IN":                            NamedColor.Keyword, 
            "INDEX":                         NamedColor.Keyword, 
            "INDEXES":                       NamedColor.Keyword, 
            "INDICATOR":                     NamedColor.Keyword, 
            "INDICES":                       NamedColor.Keyword, 
            "INITIAL":                       NamedColor.Keyword, 
            "INNER":                         NamedColor.Keyword, 
            "INTEGER":                       NamedColor.Keyword, 
            "INTERFACE":                     NamedColor.Keyword, 
            "INTERMINATE":                   NamedColor.Keyword, 
            "INTERSECT":                     NamedColor.Keyword, 
            "INTO":                          NamedColor.Keyword, 
            "IS":                            NamedColor.Keyword, 
            "ISOPEN":                        NamedColor.Keyword, 
            "JOIN":                          NamedColor.Keyword, 
            "KEEP":                          NamedColor.Keyword, 
            "KEY":                           NamedColor.Keyword, 
            "LAST":                          NamedColor.Keyword, 
            "LEFT":                          NamedColor.Keyword, 
            "LESS":                          NamedColor.Keyword, 
            "LEVEL":                         NamedColor.Keyword, 
            "LIKE":                          NamedColor.Keyword, 
            "LIMIT":                         NamedColor.Keyword, 
            "LIMITED":                       NamedColor.Keyword, 
            "LOCAL":                         NamedColor.Keyword, 
            "LOCK":                          NamedColor.Keyword, 
            "LONG":                          NamedColor.Keyword, 
            "LOOP":                          NamedColor.Keyword, 
            "MAXEXTENTS":                    NamedColor.Keyword, 
            "MEMBER":                        NamedColor.Keyword, 
            "MINUS":                         NamedColor.Keyword, 
            "MLSLABEL":                      NamedColor.Keyword, 
            "MOD":                           NamedColor.Keyword, 
            "MODE":                          NamedColor.Keyword, 
            "MODIFY":                        NamedColor.Keyword, 
            "NATURAL":                       NamedColor.Keyword, 
            "NATURALN":                      NamedColor.Keyword, 
            "NEW":                           NamedColor.Keyword, 
            "NEXT":                          NamedColor.Keyword, 
            "NEXTVAL":                       NamedColor.Keyword, 
            "NOAUDIT":                       NamedColor.Keyword, 
            "NOCOMPRESS":                    NamedColor.Keyword, 
            "NOCOPY":                        NamedColor.Keyword, 
            "NOT":                           NamedColor.Keyword, 
            "NOTFOUND":                      NamedColor.Keyword, 
            "NOWAIT":                        NamedColor.Keyword, 
            "NULL":                          NamedColor.Keyword, 
            "NULLS":                         NamedColor.Keyword, 
            "NUMBER":                        NamedColor.Keyword, 
            "NUMBER_BASE":                   NamedColor.Keyword, 
            "OBJECT":                        NamedColor.Keyword, 
            "OF":                            NamedColor.Keyword, 
            "OFF":                           NamedColor.Keyword, 
            "OFFLINE":                       NamedColor.Keyword, 
            "ON":                            NamedColor.Keyword, 
            "ONLINE":                        NamedColor.Keyword, 
            "OPEN":                          NamedColor.Keyword, 
            "OPTION":                        NamedColor.Keyword, 
            "OR":                            NamedColor.Keyword, 
            "ORDER":                         NamedColor.Keyword, 
            "ORGANIZATION":                  NamedColor.Keyword, 
            "OTHERS":                        NamedColor.Keyword, 
            "OUT":                           NamedColor.Keyword, 
            "OUTER":                         NamedColor.Keyword, 
            "OVER":                          NamedColor.Keyword, 
            "PACKAGE":                       NamedColor.Keyword, 
            "PARTITION":                     NamedColor.Keyword, 
            "PASSING":                       NamedColor.Keyword, 
            "PATH":                          NamedColor.Keyword, 
            "PCTFREE":                       NamedColor.Keyword, 
            "PIPE":                          NamedColor.Keyword, 
            "PIPELINED":                     NamedColor.Keyword, 
            "PIVOT":                         NamedColor.Keyword, 
            "PLS_INTEGER":                   NamedColor.Keyword, 
            "POSITIVE":                      NamedColor.Keyword, 
            "PRAGMA":                        NamedColor.Keyword, 
            "PRECEDING":                     NamedColor.Keyword, 
            "PRIMARY":                       NamedColor.Keyword, 
            "PRIOR":                         NamedColor.Keyword, 
            "PRIVIATE":                      NamedColor.Keyword, 
            "PRIVILEGES":                    NamedColor.Keyword, 
            "PROCEDURE":                     NamedColor.Keyword, 
            "PROMPT":                        NamedColor.Keyword, 
            "PUBLIC":                        NamedColor.Keyword, 
            "RAISE":                         NamedColor.Keyword, 
            "RANGE":                         NamedColor.Keyword, 
            "RAW":                           NamedColor.Keyword, 
            "REAL":                          NamedColor.Keyword, 
            "RECORD":                        NamedColor.Keyword, 
            "REF":                           NamedColor.Keyword, 
            "REFERENCES":                    NamedColor.Keyword, 
            "RELIES_ON":                     NamedColor.Keyword, 
            "REMR":                          NamedColor.Keyword, 
            "RENAME":                        NamedColor.Keyword, 
            "RESOURCE":                      NamedColor.Keyword, 
            "RESULT_CACHE":                  NamedColor.Keyword, 
            "RETURN":                        NamedColor.Keyword, 
            "RETURNING":                     NamedColor.Keyword, 
            "REVERSE":                       NamedColor.Keyword, 
            "REVOKE":                        NamedColor.Keyword, 
            "RIGHT":                         NamedColor.Keyword, 
            "ROLLUP":                        NamedColor.Keyword, 
            "ROW":                           NamedColor.Keyword, 
            "ROWCOUNT":                      NamedColor.Keyword, 
            "ROWID":                         NamedColor.Keyword, 
            "ROWLABEL":                      NamedColor.Keyword, 
            "ROWNUM":                        NamedColor.Keyword, 
            "ROWS":                          NamedColor.Keyword, 
            "ROWTYPE":                       NamedColor.Keyword, 
            "RUN":                           NamedColor.Keyword, 
            "SAMPLE":                        NamedColor.Keyword, 
            "SCHEMA":                        NamedColor.Keyword, 
            "SELECT":                        NamedColor.Keyword, 
            "SEPARATE":                      NamedColor.Keyword, 
            "SEQUENCE":                      NamedColor.Keyword, 
            "SET":                           NamedColor.Keyword, 
            "SHARE":                         NamedColor.Keyword, 
            "SIZE":                          NamedColor.Keyword, 
            "SMALLINT":                      NamedColor.Keyword, 
            "SPACE":                         NamedColor.Keyword, 
            "SQL":                           NamedColor.Keyword, 
            "SQLCODE":                       NamedColor.Keyword, 
            "SQLERRM":                       NamedColor.Keyword, 
            "START":                         NamedColor.Keyword, 
            "STATEMENT":                     NamedColor.Keyword, 
            "STATIC":                        NamedColor.Keyword, 
            "STDDEV":                        NamedColor.Keyword, 
            "SUBTYPE":                       NamedColor.Keyword, 
            "SUCCESSFUL":                    NamedColor.Keyword, 
            "SYNONYM":                       NamedColor.Keyword, 
            "SYSDATE":                       NamedColor.Keyword, 
            "TABAUTH":                       NamedColor.Keyword, 
            "TABLE":                         NamedColor.Keyword, 
            "TABLES":                        NamedColor.Keyword, 
            "TABLESPACE":                    NamedColor.Keyword, 
            "TASK":                          NamedColor.Keyword, 
            "THAN":                          NamedColor.Keyword, 
            "THEN":                          NamedColor.Keyword, 
            "TIMESTAMP":                     NamedColor.Keyword, 
            "TO":                            NamedColor.Keyword, 
            "TRIGGER":                       NamedColor.Keyword, 
            "TRUE":                          NamedColor.Keyword, 
            "TYPE":                          NamedColor.Keyword, 
            "UID":                           NamedColor.Keyword, 
            "UNBOUNDED":                     NamedColor.Keyword, 
            "UNION":                         NamedColor.Keyword, 
            "UNIQUE":                        NamedColor.Keyword, 
            "UNPIVOT":                       NamedColor.Keyword, 
            "USE":                           NamedColor.Keyword, 
            "USER":                          NamedColor.Keyword, 
            "USING":                         NamedColor.Keyword, 
            "VALIDATE":                      NamedColor.Keyword, 
            "VALUES":                        NamedColor.Keyword, 
            "VAR":                           NamedColor.Keyword, 
            "VARCHAR":                       NamedColor.Keyword, 
            "VARCHAR2":                      NamedColor.Keyword, 
            "VARIABLE":                      NamedColor.Keyword, 
            "VARIANCE":                      NamedColor.Keyword, 
            "VARRAY":                        NamedColor.Keyword, 
            "VIEW":                          NamedColor.Keyword, 
            "VIEWS":                         NamedColor.Keyword, 
            "WHEN":                          NamedColor.Keyword, 
            "WHENEVER":                      NamedColor.Keyword, 
            "WHERE":                         NamedColor.Keyword, 
            "WHILE":                         NamedColor.Keyword, 
            "WITH":                          NamedColor.Keyword, 
            "WITHIN":                        NamedColor.Keyword, 
            "WORK":                          NamedColor.Keyword, 
            "WRITE":                         NamedColor.Keyword, 
            "XMLNAMESPACES":                 NamedColor.Keyword, 
            "XMLTABLE":                      NamedColor.Keyword, 
            "XMLTYPE":                       NamedColor.Keyword, 
            "XOR":                           NamedColor.Keyword, 
            
         // "ALLOCATE_UNIQUE":               NamedColor.Package, 
         // "APPEND":                        NamedColor.Package, 
         // "CAST_TO_VARCHAR2":              NamedColor.Package, 
         // "CREATETEMPORARY":               NamedColor.Package, 
         // "CURSOR_ALREADY_OPEN":           NamedColor.Package, 
         // "DBMS_LOB":                      NamedColor.Package, 
         // "DBMS_LOCK":                     NamedColor.Package, 
         // "DBMS_OUTPUT":                   NamedColor.Package, 
         // "DBMS_UTILITY":                  NamedColor.Package, 
         // "DUP_VAL_ON_INDEX":              NamedColor.Package, 
         // "FCLOSE":                        NamedColor.Package, 
         // "FCOPY":                         NamedColor.Package, 
         // "FFLUSH":                        NamedColor.Package, 
         // "FGETATTR":                      NamedColor.Package, 
         // "FILECLOSE":                     NamedColor.Package, 
         // "FILEOPEN":                      NamedColor.Package, 
         // "FILE_TYPE":                     NamedColor.Package, 
         // "FOPEN":                         NamedColor.Package, 
         // "FORMAT_ERROR_BACKTRACE":        NamedColor.Package, 
         // "FREETEMPORARY":                 NamedColor.Package, 
         // "FREMOVE":                       NamedColor.Package, 
         // "FRENAME":                       NamedColor.Package, 
         // "GETATTR":                       NamedColor.Package, 
         // "GETLENGTH":                     NamedColor.Package, 
         // "GET_LINE":                      NamedColor.Package, 
         // "GET_RAW":                       NamedColor.Package, 
         // "GET_TIME":                      NamedColor.Package, 
         // "INVALID_CURSOR":                NamedColor.Package, 
         // "INVALID_NUMBER":                NamedColor.Package, 
         // "IS_OPEN":                       NamedColor.Package, 
         // "LOADFROMFILE":                  NamedColor.Package, 
         // "LOGIN_DENIED":                  NamedColor.Package, 
         // "NEW_LINE":                      NamedColor.Package, 
         // "NOT_LOGGED_ON":                 NamedColor.Package, 
         // "NO_DATA_FOUND":                 NamedColor.Package, 
         // "PROGRAM_ERROR":                 NamedColor.Package, 
         // "PUT":                           NamedColor.Package, 
         // "PUT_LINE":                      NamedColor.Package, 
         // "RAISE_APPLICATION_ERROR":       NamedColor.Package, 
         // "RELEASE":                       NamedColor.Package, 
         // "REQUEST":                       NamedColor.Package, 
         // "SLEEP":                         NamedColor.Package, 
         // "STORAGE_ERROR":                 NamedColor.Package, 
         // "TIMEOUT_ON_RESOURCE":           NamedColor.Package, 
         // "TIMESTAMP_TZ":                  NamedColor.Package, 
         // "TOO_MANY_ROWS":                 NamedColor.Package, 
         // "TO_DSINTERVAL":                 NamedColor.Package, 
         // "TO_TIMESTAMP":                  NamedColor.Package, 
         // "TO_YMINTERVAL":                 NamedColor.Package, 
         // "TRANSACTION_BACKED_OUT":        NamedColor.Package, 
         // "UTL_FILE":                      NamedColor.Package, 
         // "UTL_RAW":                       NamedColor.Package, 
         // "VALUE_ERROR":                   NamedColor.Package, 
         // "X_MODE":                        NamedColor.Package, 
         // "ZERO_DIVIDE":                   NamedColor.Package, 
            
            "ALTER":                         NamedColor.Alert, 
            "COMMIT":                        NamedColor.Alert, 
            "CREATE":                        NamedColor.Alert, 
            "DELETE":                        NamedColor.Alert, 
            "DROP":                          NamedColor.Alert, 
            "INSERT":                        NamedColor.Alert, 
            "MERGE":                         NamedColor.Alert, 
            "ROLL":                          NamedColor.Alert, 
            "ROLLBACK":                      NamedColor.Alert, 
            "SAVEPOINT":                     NamedColor.Alert, 
            "UPDATE":                        NamedColor.Alert, 
            
            "ABS":                           NamedColor.Function, 
            "ADD_MONTHS":                    NamedColor.Function, 
            "ASCII":                         NamedColor.Function, 
            "AVG":                           NamedColor.Function, 
            "BITAND":                        NamedColor.Function, 
            "CAST":                          NamedColor.Function, 
            "CHR":                           NamedColor.Function, 
            "COALESCE":                      NamedColor.Function, 
            "COUNT":                         NamedColor.Function, 
            "DECODE":                        NamedColor.Function, 
            "DUMP":                          NamedColor.Function, 
            "FIRST_VALUE":                   NamedColor.Function, 
            "GREATEST":                      NamedColor.Function, 
            "INITCAP":                       NamedColor.Function, 
            "INSTR":                         NamedColor.Function, 
            "LAG":                           NamedColor.Function, 
            "LAST_DAY":                      NamedColor.Function, 
            "LAST_VALUE":                    NamedColor.Function, 
            "LEAD":                          NamedColor.Function, 
            "LEAST":                         NamedColor.Function, 
            "LENGTH":                        NamedColor.Function, 
            "LISTAGG":                       NamedColor.Function, 
            "LOWER":                         NamedColor.Function, 
            "LPAD":                          NamedColor.Function, 
            "LTRIM":                         NamedColor.Function, 
            "MAX":                           NamedColor.Function, 
            "MIN":                           NamedColor.Function, 
            "NEXT_DAY":                      NamedColor.Function, 
            "NEXT_DAY":                      NamedColor.Function, 
            "NULLIF":                        NamedColor.Function, 
            "NVL":                           NamedColor.Function, 
            "NVL2":                          NamedColor.Function, 
            "POWER":                         NamedColor.Function, 
            "REGEXP_LIKE":                   NamedColor.Function, 
            "REPLACE":                       NamedColor.Function, 
            "ROUND":                         NamedColor.Function, 
            "ROW_NUMBER":                    NamedColor.Function, 
            "RPAD":                          NamedColor.Function, 
            "RTRIM":                         NamedColor.Function, 
            "SUBSTR":                        NamedColor.Function, 
            "SUM":                           NamedColor.Function, 
            "SYS_CONTEXT":                   NamedColor.Function, 
            "TO_CHAR":                       NamedColor.Function, 
            "TO_DATE":                       NamedColor.Function, 
            "TO_NUMBER":                     NamedColor.Function, 
            "TO_TIMESTAMP_TZ":               NamedColor.Function, 
            "TRANSLATE":                     NamedColor.Function, 
            "TRIM":                          NamedColor.Function, 
            "TRUNC":                         NamedColor.Function, 
            "UPPER":                         NamedColor.Function, 
            "WM_CONCAT":                     NamedColor.Function, 
        ];
    }
}