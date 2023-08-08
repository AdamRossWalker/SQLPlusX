module utf8_slice; @safe:

import std.algorithm : min;
import std.conv : to;
import std.utf : byDchar;
import core.bitop : bsr;

public auto toUtf8Slice(string source) @nogc pure nothrow => Utf8Slice!string(source);
public auto toUtf8Slice(const(char)[] source) @nogc pure nothrow => Utf8Slice!(const(char)[])(source);

public struct Utf8Slice(TString)
    if (is(TString == string) || is(TString == const(char)[]))
{
    @safe: @nogc: pure: nothrow:
    
    TString content;

    this(TString content)
    {
        this.content = content;
    }
    
    private size_t lengthInBytes() const => content.length;
    
    size_t length() const
    {
        size_t index = 0;
        size_t length = 0;
        while (index < lengthInBytes)
        {
            index += stride(content[index]);
            length++;
        }
        
        return length;
    }
    
    int intLength() const => cast(int)length;
    
    // Assume we have no strings larger than half the total machine memory.  
    // Then we can use $ without double calculating every string.
    size_t opDollar() const => size_t.max;
    
    dchar opIndex(const size_t index) const => content[indexOf(index) .. $].byDchar.front;
    
    // Because this struct does not validate (and throw) invalid UTF-8, then the 
    // calculated indexes may be incorrect.  Swallow any potential overflows here.
    TString opSlice(size_t start, size_t end) const =>
        content[indexOf(start) .. min($, indexOf(end))];
    
    private size_t stride(const char c) const => c < 0b1000_0000 ? 1 : (7 - bsr((~uint(c)) & 0xFF)); // Copied from Phobos.
    
    private size_t isContinuationByte(const char c) const => c > 0b0111_1111 && c < 0b1100_0000;
    
    private size_t indexOf(size_t characterIndex) const
    {
        size_t newIndex;
        
        if (characterIndex < size_t.max / 2)
        {
            newIndex = 0;
            for (auto remainingCharacters = characterIndex; remainingCharacters > 0 && newIndex < content.length; remainingCharacters--)
                newIndex += stride(content[newIndex]);
        }
        else if (content.length == 0) // Simulate $ here.
        {
            newIndex = 0;
        }
        else // Simulate $ here.
        {
            newIndex = lengthInBytes;
            for (auto remainingCharacters = size_t.max - characterIndex; remainingCharacters > 0; remainingCharacters--)
            {
                while (newIndex > 0 && isContinuationByte(content[newIndex - 1]))
                    newIndex--;
                
                if (newIndex > 0)
                    newIndex--;
            }
        }
        
        return newIndex;
    }
}

unittest
{
    void test(TValue, TExpected)(TValue value, TExpected expected) => 
        assert(value == expected, "value = " ~ value.to!string ~ ", expected = " ~ expected.to!string ~ ".");
    
    test("".toUtf8Slice.length, 0);
    test("".toUtf8Slice.intLength, 0);
    test("0123456".toUtf8Slice.length, 7);
    test("012£4¬6".toUtf8Slice.length, 7);
    test("0123456".toUtf8Slice.intLength, 7);
    test("012£4¬6".toUtf8Slice.intLength, 7);
    
    test("".toUtf8Slice[0 .. $], "");
    test("0123456".toUtf8Slice[0], '0');
    test("012£4¬6".toUtf8Slice[0], '0');
    test("0123456".toUtf8Slice[1], '1');
    test("012£4¬6".toUtf8Slice[1], '1');
    test("0123456".toUtf8Slice[2], '2');
    test("012£4¬6".toUtf8Slice[2], '2');
    test("0123456".toUtf8Slice[3], '3');
    test("012£4¬6".toUtf8Slice[3], '£');
    test("0123456".toUtf8Slice[4], '4');
    test("012£4¬6".toUtf8Slice[4], '4');
    test("0123456".toUtf8Slice[5], '5');
    test("012£4¬6".toUtf8Slice[5], '¬');
    test("0123456".toUtf8Slice[6], '6');
    test("012£4¬6".toUtf8Slice[6], '6');
    
    test("0123456".toUtf8Slice[0 .. 7], "0123456");
    test("012£4¬6".toUtf8Slice[0 .. 7], "012£4¬6");
    test("0123456".toUtf8Slice[2 .. 7], "23456");
    test("012£4¬6".toUtf8Slice[2 .. 7], "2£4¬6");
    test("0123456".toUtf8Slice[3 .. 7], "3456");
    test("012£4¬6".toUtf8Slice[3 .. 7], "£4¬6");
    test("0123456".toUtf8Slice[4 .. 7], "456");
    test("012£4¬6".toUtf8Slice[4 .. 7], "4¬6");
    test("0123456".toUtf8Slice[2 .. 3], "2");
    test("012£4¬6".toUtf8Slice[2 .. 3], "2");
    test("0123456".toUtf8Slice[3 .. 4], "3");
    test("012£4¬6".toUtf8Slice[3 .. 4], "£");
    test("0123456".toUtf8Slice[3 .. 3], "");
    test("012£4¬6".toUtf8Slice[3 .. 3], "");
    test("0123456".toUtf8Slice[6 .. 7], "6");
    test("012£4¬6".toUtf8Slice[6 .. 7], "6");
    test("0123456".toUtf8Slice[7 .. 7], "");
    test("012£4¬6".toUtf8Slice[7 .. 7], "");
    
    test("0123456".toUtf8Slice[1 .. 6], "12345");
    test("012£4¬6".toUtf8Slice[1 .. 6], "12£4¬");
    test("0123456".toUtf8Slice[2 .. 5], "234");
    test("012£4¬6".toUtf8Slice[2 .. 5], "2£4");
    
    test("0123456".toUtf8Slice[0 .. $], "0123456");
    test("012£4¬6".toUtf8Slice[0 .. $], "012£4¬6");
    test("0123456".toUtf8Slice[2 .. $], "23456");
    test("012£4¬6".toUtf8Slice[2 .. $], "2£4¬6");
    test("0123456".toUtf8Slice[3 .. $], "3456");
    test("012£4¬6".toUtf8Slice[3 .. $], "£4¬6");
    test("0123456".toUtf8Slice[4 .. $], "456");
    test("012£4¬6".toUtf8Slice[4 .. $], "4¬6");
    test("0123456".toUtf8Slice[6 .. $], "6");
    test("012£4¬6".toUtf8Slice[6 .. $], "6");
    test("0123456".toUtf8Slice[7 .. $], "");
    test("012£4¬6".toUtf8Slice[7 .. $], "");
    
    test("012£4¬6".toUtf8Slice[0 .. $    ], "012£4¬6");
    test("0123456".toUtf8Slice[0 .. $ - 1], "012345");
    test("012£4¬6".toUtf8Slice[0 .. $ - 1], "012£4¬");
    test("0123456".toUtf8Slice[0 .. $ - 2], "01234");
    test("012£4¬6".toUtf8Slice[0 .. $ - 2], "012£4");
    test("0123456".toUtf8Slice[0 .. $ - 3], "0123");
    test("012£4¬6".toUtf8Slice[0 .. $ - 3], "012£");
    test("0123456".toUtf8Slice[0 .. $ - 4], "012");
    test("012£4¬6".toUtf8Slice[0 .. $ - 4], "012");
    test("0123456".toUtf8Slice[0 .. $ - 5], "01");
    test("012£4¬6".toUtf8Slice[0 .. $ - 5], "01");
    test("0123456".toUtf8Slice[0 .. $ - 6], "0");
    test("012£4¬6".toUtf8Slice[0 .. $ - 6], "0");
    test("0123456".toUtf8Slice[0 .. $ - 7], "");
    test("012£4¬6".toUtf8Slice[0 .. $ - 7], "");
    test("0123456".toUtf8Slice[0 .. $ - 8], "");
    test("012£4¬6".toUtf8Slice[0 .. $ - 8], "");
}
