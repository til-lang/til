import std.stdio;
import std.experimental.logger;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.semantics;


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
    import libs.std.io;
    program.addModule("std.io", libs.std.io.commands);
    import libs.std.math;
    program.addModule("std.math", libs.std.math.commands);
    import libs.std.stack;
    program.addModule("std.stack", libs.std.stack.commands);
    import libs.std.ranges;
    program.addModule("std.ranges", libs.std.ranges.commands);
    import libs.std.sharedlibs;
    program.addModule("std.sharedlibs", libs.std.sharedlibs.commands);

    auto process = new Process(null, program);
    auto context = process.run();
    trace(process);

    // Print everything remaining in the stack:
    foreach(item; context.items)
    {
        writeln(item.asString);
    }
}
