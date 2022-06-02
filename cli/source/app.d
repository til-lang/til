import std.array : array;
import std.datetime.stopwatch;
import std.file;
import std.process : environment;
import std.stdio;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.process;

import cli.repl;


int main(string[] args)
{
    Parser parser;

    SimpleList argumentsList = new SimpleList(
        cast(Items)args.map!(x => new String(x)).array
    );
    Dict envVars = new Dict();
    foreach(key, value; environment.toAA())
    {
        envVars[key] = new String(value);
    }

    debug
    {
        auto sw = StopWatch(AutoStart.no);
        sw.start();
    }

    // Potential small speed-up:
    commands.rehash;

    if (args.length == 1)
    {
        return repl(envVars, argumentsList);
    }

    auto filename = args[1];
    if (filename == "-")
    {
        parser = new Parser(to!string(stdin.byLine.join("\n")));
    }
    else
    {
        try
        {
            parser = new Parser(to!string(read(filename)));
        }
        catch (FileException ex)
        {
            stderr.writeln(
                "Error ",
                ex.errno, ": ",
                ex.msg
            );
            return ex.errno;
        }
    }

    debug
    {
        sw.stop();
        stderr.writeln(
            "Code was loaded in ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    debug {sw.start();}

    auto program = parser.run();

    debug
    {
        sw.stop();
        stderr.writeln(
            "Semantic analysis took ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    // The scope:
    auto escopo = new Escopo();
    escopo["args"] = argumentsList;
    escopo["env"] = envVars;
    escopo.commands = commands;

    // The main Process:
    auto process = new Process("main");

    // Start!
    debug {sw.start();}

    // Run the main process:
    auto context = process.run(program, escopo);

    // Print everything remaining in the stack:
    int returnCode = finishProcess(process, context);

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
