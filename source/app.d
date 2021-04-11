import std.stdio;
import std.experimental.logger;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.til;


void main()
{
    // Enable language debugging:
    debug
    {
        globalLogLevel = LogLevel.trace;
    }
    else
    {
        globalLogLevel = LogLevel.warning;
    }

    // There must be a better way of doing this:
    string code = "";
    foreach(line; stdin.byLine)
    {
        code ~= line ~ "\n";
    }

    auto tree = Til(code);
    trace(tree);

    // TODO: check if the parsing was successful.

    SubProgram program;
    try {
        program = analyse(tree);
    }
    catch (Exception e) {
        trace(e);
        trace("==== ERROR ====");
    }
    trace("======OK=======");

    program.registerGlobalCommands(commands);

    // "Third-party" modules:
    import til.std.io;
    program.addModule("std.io", til.std.io.commands);
    import til.std.math;
    program.addModule("std.math", til.std.math.commands);
    import til.std.stack;
    program.addModule("std.stack", til.std.stack.commands);
    import til.std.ranges;
    program.addModule("std.ranges", til.std.ranges.commands);
    import til.std.sharedlibs;
    program.addModule("std.sharedlibs", til.std.sharedlibs.commands);

    auto process = new Process(null, program);
    auto returnedValue = process.run();
    trace("returnedValue: ", returnedValue);
    trace(process);
}
