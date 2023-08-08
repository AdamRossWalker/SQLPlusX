module range_extensions;

import std.range.primitives : isInputRange, ElementType;
import std.algorithm : max, min;

import common;

auto joiner(RoR)(RoR r) @trusted
if (isInputRange!RoR && isInputRange!(ElementType!RoR))
{
    import std.algorithm : apparentlyUnsafeImplementation = joiner;
    return apparentlyUnsafeImplementation!RoR(r);
}


T firstOrDefault(Range, T)(Range range, T defaultValue = T.init) @nogc nothrow
if (isInputRange!Range && is(typeof(range.front) : T))
{
    if (range.empty)
        return defaultValue;
    
    return range.front;
}

auto reduceMax(Range, T)(Range range, T defaultValue) @nogc nothrow
if (isInputRange!Range && is(typeof(range.front) : T))
{
    if (range.empty)
        return defaultValue;

    auto maxValue = range.front;

    while (true)
    {
        range.popFront;
        
        if (range.empty)
        	return maxValue;
        
        maxValue = max(maxValue, range.front);
    }
}

auto reduceMin(Range, T)(Range range, T defaultValue) @nogc nothrow
if (isInputRange!Range && is(typeof(range.front) : T))
{
    if (range.empty)
        return defaultValue;

    auto minValue = range.front;

    while (true)
    {
        range.popFront;
        
        if (range.empty)
        	return minValue;
        
        minValue = min(minValue, range.front);
    }
}

// Because std.algorithm.any can't handle my ASCII strings.
bool any(alias Predicate, T)(const T[] items)
// I have no idea how I'm supposed to do this properly with 
// an actual typesafe parameter that can accept a lambda.  
if (is(typeof(Predicate(items[0])) == bool))
{
    foreach (item; items)
        if (Predicate(item))
            return true;
    
    return false;
}
