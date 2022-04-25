module til.conv;

import std.format;


long toLong(string s)
{
    long result;
    if (s.length >= 2 && s[0..2] == "0x")
    {
        s[2..$].formattedRead("%x", result);
    }
    else
    {
        s.formattedRead("%d", result);
    }
    return result;
}
