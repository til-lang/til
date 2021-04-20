import std.datetime.stopwatch;
import std.file;
import std.stdio : stderr, stdin, writeln;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.semantics;


void main()
{
    auto sw = StopWatch(AutoStart.no);

    sw.start();
    // There must be a better way of doing this:
    auto tree = Til(to!string(stdin.byLine.join("\n")));
    if (!tree.successful)
    {
        // TODO: print a better explanation of what happened.
        throw new Exception("Program seems invalid.");
    }
    sw.stop();
    stderr.writeln("Code was loaded and parsed in ", sw.peek.total!"msecs", " miliseconds");

    sw.start();
    SubProgram program;
    try {
        program = analyse(tree);
    }
    catch (Exception e) {
        throw new Exception("==== ERROR ====");
    }
    sw.stop();
    stderr.writeln("Semantic analysis took ", sw.peek.total!"msecs", " miliseconds");

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

    sw.start();
    auto process = new Process(null, program);
    auto context = process.run();

    // Print everything remaining in the stack:
    foreach(item; context.items)
    {
        writeln(item.asString);
    }
    sw.stop();
    stderr.writeln("Program was run in ", sw.peek.total!"msecs", " miliseconds");
}
