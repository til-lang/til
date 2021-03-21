import std.stdio : writeln;

import til.exceptions;
import til.grammar;
import til.nodes;

// ---------------------------------------

void main()
{
    string[7] code = [
        "{$a + $b} > fill > math.run",
        "set y {10 + 10 > math.run}",
        "run x {
            run y {run z {
                f 23}}
        }",
        "{$a + $b}",
        "{$a $b $c} > fill < std.out",
        "\"x:$x\" > fill > std.out",
        "\"x:$x\"",
    ];

    foreach (index, line; code)
    {
        auto tree = Til(line);
        writeln(index, ": ", line);
        // writeln(index, ": ", line, " :\n", tree);
        try {
            execute(tree);
        }
        catch (Exception e) {
            writeln(e);
            writeln("==== ERROR ====");
            continue;
        }
        writeln("======OK=======");
    }
}
