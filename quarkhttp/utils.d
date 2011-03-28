module quarkhttp.utils;

import std.array;
import std.string;


shared immutable string
    CRLF = "\r\n";


S1 skip(S1, S2)(S1 s, in S2 pattern)
{
    if (!s.empty && !pattern.empty)
    {
        size_t i = 0;

        while (i < s.length && indexOf(pattern, s[i]) >= 0)
            ++i;

        return s[i .. $];
    }

    return s;
}
