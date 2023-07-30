module logo;

import std.algorithm : max, min;
import image;
import common;

public enum BlockType
{
    // Basic blocks:
    Full                      = 1, 
    
    // 50% split from top left to bottom right: [\]
    DialogalLeftFilled        = 2, 
    DialogalRightFilled       = 3, 
    
    // 50% split across two blocks stacked one on top of the other.  The 
    // dialoginal line is again from top left to bottom right, but is now 
    // not cleanly at the corners where the blocks meet: [\ ]
    //                                                   [ \]
    DialogalPairTopRightFilled    = 4, 
    DialogalPairBottomRightFilled = 5, 
    DialogalPairTopLeftFilled     = 6, 
    DialogalPairBottomLeftFilled  = 7, 
}

// The contents of this references BlockType values.
enum layout = [
[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 1, 1, 7, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0], 
[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 6, 1, 1, 1, 0, 0, 0, 0, 0, 0], 
[1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 1, 1, 7, 1, 1, 1, 0, 0, 0, 0, 0, 0], 
[1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0], 
[4, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0], 
[5, 1, 1, 6, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0], 
[0, 4, 1, 7, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0], 
[0, 5, 1, 1, 6, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1, 1, 1, 0, 0, 0, 0, 0, 0], 
[0, 0, 4, 1, 7, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 5, 1, 1, 1, 0, 0, 0, 0, 0, 0], 
[0, 0, 5, 1, 1, 6, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 6, 0, 0, 0, 0, 0], 
[0, 0, 0, 4, 1, 7, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 7, 0, 0, 0, 0, 0], 
[0, 0, 0, 5, 1, 1, 6, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 3, 1, 1, 2, 0, 0, 0, 1, 1, 1, 1, 6, 0, 0, 0, 0], 
[0, 0, 0, 0, 4, 1, 7, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 3, 1, 1, 2, 0, 0, 1, 1, 1, 1, 7, 0, 0, 0, 0], 
[0, 0, 0, 0, 5, 1, 1, 6, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 3, 1, 1, 2, 0, 1, 1, 1, 1, 1, 6, 0, 0, 0], 
[1, 1, 1, 1, 1, 1, 1, 7, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 7, 0, 0, 0], 
[1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 4, 1, 1, 6, 0, 0], 
[1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 5, 1, 1, 7, 0, 0], 
[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 4, 1, 1, 6, 0], 
[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 5, 1, 1, 7, 0], 
];

enum int fullWidth = (layout[0].intLength * (blockWidth + 1) + layout.intLength * logo.shearWidthPerBlock);
enum int fullHeight = layout.intLength * (blockHeight + 1);
enum int blockWidth = 4;
enum int blockHeight = 3;
enum int shearWidthPerBlock = 2;

public struct BlockLocation
{
    BlockType Type;
    int X;
    int Y;
}

public struct BlockState
{
    enum upperOpacity = 1.0;
    enum lowerOpacity = 0.25;
    private double currentOpacity = 0.0;
    private double speed = 0.0;
    public bool isNormalColor;
    
    public ubyte Opacity(double overallImageOpacity)
    {
        auto normalized = max(0.0, min(1.0, overallImageOpacity * currentOpacity));
    
        return cast(ubyte)(normalized * 255);
    }
    
    public void Reset()
    {
        import std.random : uniform;
        currentOpacity = uniform(0.0, 1.0);
        speed = uniform(0.001, 0.025);
        isNormalColor = uniform(1, 10) > 2;
    }
    
    public bool Advance()
    {
        currentOpacity += speed;
        
        if (currentOpacity > upperOpacity)
        {
            currentOpacity = upperOpacity;
            speed *= -1;
        }
        else if (currentOpacity < lowerOpacity)
        {
            currentOpacity = lowerOpacity;
            speed *= -1;
        }
            
        return true;
    }
}

public auto CreateLogoBlocks()
{
    assert (__ctfe);
    BlockLocation[] locations;
    
    foreach (y, row; layout)
        foreach (x, block; row)
            if (block > 0)
                locations ~= BlockLocation(
                    cast(BlockType)block, 
                    cast(int)(x * (blockWidth  + 1) + (layout.length - y) * shearWidthPerBlock), 
                    cast(int)(y * (blockHeight + 1)));
    
    return locations;
}

