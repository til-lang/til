import std.stdio;
import std.experimental.logger;

import til.escopo;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.til;

// Modules:
import til.std.io;
import til.libs.posix.shell;


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

    // "Third-party" modules:
    escopo.availableModules["posix.shell"] = new Shell();
    escopo.availableModules["std.io"] = new IO();

    auto returnedValue = escopo.run(program);
    trace("returnedValue: ", returnedValue);
    trace(escopo);
}
