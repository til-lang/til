import std.stdio;
import std.experimental.logger;

import til.escopo;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.til;


void main()
{
    // Enable language debugging:
    globalLogLevel = LogLevel.trace;

    // There must be a better way of doing this:
    string code = "";
    foreach(line; stdin.byLine)
    {
        code ~= line ~ "\n";
    }

    auto tree = Til(code);
    trace(tree);

    ExecList program;
    try {
        program = analyse(tree);
    }
    catch (Exception e) {
        trace(e);
        trace("==== ERROR ====");
    }
    trace("======OK=======");

    auto escopo = new DefaultEscopo();
    auto returnedValue = escopo.run(program);
    trace("returnedValue: ", returnedValue);
    trace(escopo);
}
