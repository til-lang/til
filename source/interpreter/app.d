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

    if (!tree.successful)
    {
        // TODO: print a better explanation of what happened.
        throw new Exception("Program seems invalid.");
    }

    SubProgram program;
    try {
        program = analyse(tree);
    }
    catch (Exception e) {
        trace(e);
        throw new Exception("==== ERROR ====");
    }
    trace("======OK=======");

    program.registerGlobalCommands(commands);

    // "Third-party" modules:
    import libs.std.dict;
    program.addModule("std.dict", libs.std.dict.commands);
    import libs.std.io;
    program.addModule("std.io", libs.std.io.commands);
    import libs.std.lists;
    program.addModule("std.lists", libs.std.lists.commands);
    import libs.std.math;
    program.addModule("std.math", libs.std.math.commands);
    import libs.std.range;
    program.addModule("std.range", libs.std.range.commands);
    import libs.std.stack;
    program.addModule("std.stack", libs.std.stack.commands);
    import libs.std.sharedlib;
    program.addModule("std.sharedlib", libs.std.sharedlib.commands);

    auto process = new Process(null, program);
    auto context = process.run();
    trace(process);

    // Print everything remaining in the stack:
    foreach(item; context.items)
    {
        writeln(item.asString);
    }
}
