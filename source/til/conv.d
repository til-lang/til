module til.conv;

import std.math : pow;
import std.range : enumerate, retro;

debug
{
    import std.stdio;
}

struct LongValue {
    bool success = true;
    long value = 0;
}


LongValue toLong(string s)
{
    if (s.length >= 2 && s[0..2] == "0x")
    {
        return toLongFromHex(s);
    }
    else
    {
        return toLongFromDecimal(s);
    }
}

LongValue toLongFromDecimal(string s)
{
    LongValue returnValue;

    long x;
    foreach (index, chr; s.retro.enumerate)
    {
        x = chr - '0';
        debug {stderr.writeln("chr:", chr, "; x:", x, "; index:", index);}
        if (x < 10)
        {
            returnValue.value += x * pow(10, index);
            continue;
        }

        returnValue.success = false;
        break;
    }

    debug {stderr.writeln(" value:", returnValue.value);}
    return returnValue;
}

LongValue toLongFromHex(string s)
{
    LongValue returnValue;

    long x;
    foreach (index, chr; s[2..$].retro.enumerate)
    {
        x = chr - '0';
        if (x < 10)
        {
            returnValue.value += x * pow(16, index);
            continue;
        }

        x = chr - 'A';
        if (x < 6)
        {
            returnValue.value += (x + 10) * pow(16, index);
            continue;
        }

        x = chr - 'a';
        if (x < 6)
        {
            returnValue.value += (x + 10) * pow(16, index);
            continue;
        }

        returnValue.success = false;
        break;
    }

    debug {stderr.writeln(" value:", returnValue.value);}
    return returnValue;
}
