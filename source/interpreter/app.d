import std.file;
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

    string importModule(string path)
    {
        string result = "import libs." ~ path ~ ";";
        result ~= "program.addModule(\"" ~ path ~ "\", libs." ~ path ~ ".commands);";
        return result;
    }

    // "Third-party" modules:
    mixin(importModule("std.dict"));
    mixin(importModule("std.io"));
    mixin(importModule("std.lists"));
    mixin(importModule("std.math"));
    mixin(importModule("std.range"));
    mixin(importModule("std.stack"));
    mixin(importModule("std.sharedlib"));

    auto process = new Process(null, program);
    auto context = process.run();
    trace(process);

    // Print everything remaining in the stack:
    foreach(item; context.items)
    {
        writeln(item.asString);
    }
}
