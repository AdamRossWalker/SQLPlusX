module computes; @safe:

import std.math : isNaN;

enum BreakTypes { Column, Row, Report }
enum SkipTypes { Lines, Page }

public struct BreakDefinition
{
    auto BreakType = BreakTypes.Column;
    auto ColumnName = "";
    
    auto SkipType = SkipTypes.Lines;
    auto LinesToSkip = 0;
    auto PrintFollowingValue = false;
}

enum Types { Average, Count, Minimum, Maximum, Number, Sum, StandardDeviation, Variance }

public struct ComputeFunction
{
    auto ComputeType = Types.Sum;
    auto Label = "";
}

public struct ComputeDefinition
{
    ComputeFunction[] Functions;
    string[] ValuesColumnNames;
    
    auto BreakType = BreakTypes.Column;
    string[] BreakColumnNames;
}

abstract class IncrementalCompute
{
    abstract void Clear() @nogc nothrow;
    abstract void AddValue(double value) @nogc nothrow;
    abstract double Result() @nogc nothrow;
    
    static IncrementalCompute FromType(Types type)
    {
        final switch (type) with (Types)
        {
            case Average:           return new MeanCompute; 
            case Count:             return new CountCompute; 
            case Minimum:           return new MinimumCompute; 
            case Maximum:           return new MaximumCompute; 
            case Number:            return new NumberCompute;
            case Sum:               return new SumCompute; 
            case StandardDeviation: return new StandardDeviationCompute; 
            case Variance:          return new VarianceCompute; 
        }
    }
}

final class MeanCompute : IncrementalCompute
{
    private double total = 0.0;
    private int count = 0;
    
    override void Clear() @nogc nothrow
    {
        total = 0.0;
        count = 0;
    }
    
    override void AddValue(double value) @nogc nothrow
    {
        if (isNaN(value))
            return;
        
        total += value;
        count++;
    }
    
    override double Result() @nogc nothrow
    {
        if (count == 0)
            return double.init;
        
        return total / count;
    }
}

final class CountCompute : IncrementalCompute
{
    private int count = 0;
    
    override void Clear() @nogc nothrow
    {
        count = 0;
    }
    
    override void AddValue(double value) @nogc nothrow
    {
        if (isNaN(value))
            return;
        
        count++;
    }
    
    override double Result() @nogc nothrow { return count; }
}

final class NumberCompute : IncrementalCompute
{
    private int count = 0;
    
    override void Clear() @nogc nothrow
    {
        count = 0;
    }
    
    override void AddValue(double value) @nogc nothrow { count++; }
    
    override double Result() @nogc nothrow { return count; }
}

final class MinimumCompute : IncrementalCompute
{
    private double minimum;
    
    override void Clear() @nogc nothrow
    {
        minimum = double.init;
    }
    
    override void AddValue(double value) @nogc nothrow
    {
        if (isNaN(value))
            return;
        
        if (isNaN(minimum) || value < minimum)
            minimum = value;
    }
    
    override double Result() @nogc nothrow { return minimum; }
}

final class MaximumCompute : IncrementalCompute
{
    private double maximum;
    
    override void Clear() @nogc nothrow
    {
        maximum = double.init;
    }
    
    override void AddValue(double value) @nogc nothrow
    {
        if (isNaN(value))
            return;
        
        if (isNaN(maximum) || value > maximum)
            maximum = value;
    }
    
    override double Result() @nogc nothrow { return maximum; }
}

final class SumCompute : IncrementalCompute
{
    private double total = 0.0;
    
    override void Clear() @nogc nothrow
    {
        total = 0.0;
    }
    
    override void AddValue(double value) @nogc nothrow
    {
        if (isNaN(value))
            return;
        
        total += value;
    }
    
    override double Result() @nogc nothrow { return total; }
}

final class VarianceCompute : IncrementalCompute
{
    private double mean = double.init;
    private double sigma = double.init;
    private int count = 0;
    
    override void Clear() @nogc nothrow
    {
        mean = double.init;
        sigma = double.init;
        count = 0;
    }
    
    override void AddValue(double value) @nogc nothrow
    {
        if (count == 0)
        {
            mean = value;
            sigma = 0.0;
            count = 1;
            return;
        }
        
        count++;
        auto newMean  = mean + (value - mean) / count;
        auto newSigma = sigma + (value - mean) * (value - newMean);
        
        mean = newMean;
        sigma = newSigma;
    }
    
    override double Result() @nogc nothrow
    {
        if (count < 2)
            return 0.0;
        
        return sigma / (count - 1);
    }
}


final class StandardDeviationCompute : IncrementalCompute
{
    // I can't have "= new VarianceCompute" here, the child instance gets re-used across parent instances.  WTF?
    private VarianceCompute variance; 
    
    this()
    {
        variance = new VarianceCompute;
    }
    
    override void Clear() @nogc nothrow { variance.Clear; }
    
    override void AddValue(double value) @nogc nothrow
    {
        variance.AddValue(value);
    }
    
    override double Result() @nogc nothrow
    {
        import std.math : sqrt;
        return sqrt(variance.Result);
    }
}

unittest
{
    void harness(T : IncrementalCompute)(double expectedResult, double[] values...)
    {
        auto c = new T;
        
        //c.Clear;
        
        foreach (value; values)
            c.AddValue(value);
        
        auto result = c.Result;
        
        if (isNaN(result) && isNaN(expectedResult))
            return;
        
        import std.math : isClose;
        import std.conv : to;
        assert(isClose(result, expectedResult, 1e-6), result.to!string ~ " expected " ~ expectedResult.to!string);
    }
    
    harness!MeanCompute(double.init);
    harness!MeanCompute(1.0, 1.0);
    harness!MeanCompute(1.0, 1.0, 1.0, 1.0);
    harness!MeanCompute(2.0, 1.0, 2.0, 3.0);
    
    harness!SumCompute(0.0);
    harness!SumCompute(1.0, 1.0);
    harness!SumCompute(3.0, 1.0, 1.0, 1.0);
    harness!SumCompute(6.0, 1.0, 2.0, 3.0);
    
    harness!CountCompute(0.0);
    harness!CountCompute(1.0, 1.0);
    harness!CountCompute(3.0, 1.0, 1.0, 1.0);
    harness!CountCompute(3.0, 1.0, 2.0, 3.0);
    harness!CountCompute(3.0, double.init, 1.0, double.init, 2.0, double.init, 3.0, double.init);
    
    harness!NumberCompute(0.0);
    harness!NumberCompute(1.0, 1.0);
    harness!NumberCompute(3.0, 1.0, 1.0, 1.0);
    harness!NumberCompute(3.0, 1.0, 2.0, 3.0);
    harness!NumberCompute(7.0, double.init, 1.0, double.init, 2.0, double.init, 3.0, double.init);
    
    harness!MinimumCompute(double.init);
    harness!MinimumCompute(1.0, 1.0);
    harness!MinimumCompute(1.0, 1.0, 1.0, 1.0);
    harness!MinimumCompute(1.0, 1.0, 2.0, 3.0);
    
    harness!MaximumCompute(double.init);
    harness!MaximumCompute(1.0, 1.0);
    harness!MaximumCompute(1.0, 1.0, 1.0, 1.0);
    harness!MaximumCompute(3.0, 1.0, 2.0, 3.0);
    
    harness!VarianceCompute(0.0);
    harness!VarianceCompute(0.0, 1.0);
    harness!VarianceCompute(0.0, 1.0, 1.0, 1.0);
    harness!VarianceCompute(1.0, 1.0, 2.0, 3.0);
    harness!VarianceCompute(690.33333, 1.0, 2.0, 47.0);
    
    harness!StandardDeviationCompute(0.0);
    harness!StandardDeviationCompute(0.0, 1.0);
    harness!StandardDeviationCompute(0.0, 1.0, 1.0, 1.0);
    harness!StandardDeviationCompute(26.2742, 1.0, 2.0, 47.0);
    
}