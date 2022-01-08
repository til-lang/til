module til.conv;

import std.conv : to, ConvException;
import std.math : pow;
import std.range : enumerate, retro;


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
        if (s.length == 0)
        {
            s = "0";
        }
        return toLongFromDecimal(s);
    }
}

LongValue toLongFromDecimal(string s)
{
    LongValue returnValue;

    try
    {
        returnValue.value = to!long(s);
    }
    catch (ConvException)
    {
        returnValue.success = false;
    }

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

    return returnValue;
}
