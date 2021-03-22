import std.stdio;

import til.exceptions;
import til.grammar;
import til.nodes;
import til.til;


void main()
{
    // There must be a better way of doing this:
    string program = "";
    foreach(line; stdin.byLine)
    {
        program ~= line ~ "\n";
    }

    auto tree = Til(program);
    writeln(tree);
    try {
        execute(tree);
    }
    catch (Exception e) {
        writeln(e);
        writeln("==== ERROR ====");
    }
    writeln("======OK=======");
}
