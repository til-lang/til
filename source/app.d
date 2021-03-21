import std.stdio;

import til.exceptions;
import til.grammar;
import til.nodes;

// ---------------------------------------

void main()
{

    string program = "";

    foreach(line; stdin.byLine)
    {
        program ~= line ~ "\n";
    }

    auto tree = Til(program);
    try {
        execute(tree);
    }
    catch (Exception e) {
        writeln(e);
        writeln("==== ERROR ====");
    }
    writeln("======OK=======");
}
