module most_recently_used_cache; @safe: nothrow: 

import std.traits : isCallable;

public struct MostRecentlyUsedCache(
    TKey, 
    TValue, 
    int cacheSize, 
    alias disposeValueCallback = void)
if (is(typeof(disposeValueCallback(TValue.init))) || is(disposeValueCallback : void))
{
    @safe: nothrow: 

    private struct CacheEntry
    {
        TValue value;
        ulong epochIndex;
    }
    
    private struct EpochEntry
    {
        TKey key;
        ulong epoch;
    }
    
    CacheEntry[TKey] cache;
    EpochEntry[cacheSize] epochs;
    ulong currentEpoch = 0;
    int count = 0;
    
    bool tryGetValue(scope TKey key, out TValue value)
    {
        auto entryRef = key in cache;
        auto exists = entryRef !is null;
        
        if (exists)
        {
            auto entry = *entryRef;
            value = entry.value;
            currentEpoch++;
            epochs[entry.epochIndex].epoch = currentEpoch;
        }
        
        return exists;
    }
    
    void add(TKey key, TValue value)
    {
        currentEpoch++;
        if (currentEpoch == 0)
            reset;
        
        if (count < cacheSize)
        {
            count++;
            const epochIndex = count - 1;
            epochs[epochIndex] = EpochEntry(key, currentEpoch);
            cache[key] = CacheEntry(value, epochIndex);
        }
        else
        {
            auto minEpochIndex = 0UL;
            auto minEpochEntry = EpochEntry(TKey.init, ulong.max);
            foreach (epochIndex, epochEntry; epochs)
            {
                if (epochEntry.epoch >= minEpochEntry.epoch)
                    continue;
                
                minEpochIndex = epochIndex;
                minEpochEntry = epochEntry;
            }
            
            remove(minEpochEntry.key);
            
            epochs[minEpochIndex] = EpochEntry(key, currentEpoch);
            cache[key] = CacheEntry(value, minEpochIndex);
        }
    }
    
    private void remove(TKey key)
    {
        static if (is(typeof(disposeValueCallback(TValue.init))))
            disposeValueCallback(cache[key].value);
        
        cache.remove(key);
    }
    
    void reset()
    {
        while (cache.length > 0)
            remove(cache.keys[0]);
        
        count = 0;
        epochs[] = EpochEntry.init;
    }
}

unittest
{
    string lastDisposedValue;

    auto subjectUnderTest = MostRecentlyUsedCache!(int, string, 3, value => lastDisposedValue = value)();
    
    void assertMissing(int key) @safe nothrow
    {
        string result;
        assert (!subjectUnderTest.tryGetValue(key, result));
    }
    
    void assertPresent(int key, string expectedValue) @safe nothrow
    {
        string result;
        assert (subjectUnderTest.tryGetValue(key, result));
        assert (result == expectedValue);
    }
    
    assertMissing(1);
    assertMissing(1);
    assertMissing(2);

    subjectUnderTest.add(1, "One");
    assertPresent(1, "One");
    
    subjectUnderTest.add(2, "Two");
    assertPresent(2, "Two");
    
    subjectUnderTest.add(3, "Three");
    assertPresent(3, "Three");
    
    lastDisposedValue = null;
    subjectUnderTest.add(4, "Four");
    
    assertMissing(1);
    assert (lastDisposedValue == "One");
    assertPresent(2, "Two");
    assertPresent(3, "Three");
    assertPresent(4, "Four");
    
    lastDisposedValue = null;
    subjectUnderTest.reset;
    assert (lastDisposedValue == "Two" || lastDisposedValue == "Three" || lastDisposedValue == "Four", lastDisposedValue);
    assert (subjectUnderTest.count == 0);
}
