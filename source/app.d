import std.stdio;

import til.escopo;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.til;


void main()
{
    // There must be a better way of doing this:
    string code = "";
    foreach(line; stdin.byLine)
    {
        code ~= line ~ "\n";
    }

    auto tree = Til(code);
    writeln(tree);
    Program program;
    try {
        program = analyse(tree);
    }
    catch (Exception e) {
        writeln(e);
        writeln("==== ERROR ====");
    }
    writeln("======OK=======");

    auto escopo = new DefaultEscopo();
    auto returnedValue = escopo.run(program);
    writeln("returnedValue: ", returnedValue);
}
