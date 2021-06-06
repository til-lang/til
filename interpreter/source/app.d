import std.datetime.stopwatch;
import std.file;
import std.stdio : stderr, stdin, write, writeln;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.scheduler;

debug
{
}

int main(string[] args)
{
    Parser parser;

    debug
    {
        auto sw = StopWatch(AutoStart.no);
        sw.start();
    }

    auto filename = args[1];
    if (filename == "-")
    {
        parser = new Parser(to!string(stdin.byLine.join("\n")));
    }
    else
    {
        parser = new Parser(to!string(read(filename)));
    }

    debug
    {
        sw.stop();
        stderr.writeln(
            "Code was loaded and parsed in ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    SubProgram program;
    debug {sw.start();}

    program = parser.run();

    debug
    {
        sw.stop();
        stderr.writeln(
            "Semantic analysis took ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    auto process = new Process(null, program);
    process.commands = commands;

    debug {sw.start();}
    auto scheduler = new Scheduler(process);
    scheduler.run();

    // Print everything remaining in the stack:
    int returnCode = 0;
    foreach(fiber; scheduler.fibers)
    {
        stderr.write("Process ", fiber.process.index, ": ");
        if (fiber.context.exitCode == ExitCode.Failure)
        {
            stderr.writeln("ERROR");
            auto e = cast(Erro)fiber.context.pop();
            stderr.writeln(e);
            returnCode = e.code;
        }
        else
        {
            stderr.writeln("Success");
            foreach(item; fiber.context.items)
            {
                stderr.writeln(item);
            }
        }
    }
    debug
    {
        sw.stop();
        stderr.writeln(
            "Program was run in ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }
    return returnCode;
}
