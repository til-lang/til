import std.file;
import std.stdio;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.semantics;


void main()
{
    // There must be a better way of doing this:
    string code = "";
    foreach(line; stdin.byLine)
    {
        code ~= line ~ "\n";
    }

    auto tree = Til(code);

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
        throw new Exception("==== ERROR ====");
    }

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

    // Print everything remaining in the stack:
    foreach(item; context.items)
    {
        writeln(item.asString);
    }
}
