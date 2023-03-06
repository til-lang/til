import std.array : array, join, split;
import std.datetime.stopwatch;
import std.file;
import std.process : environment;
import std.range : retro;
import std.stdio;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.procedures;
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
        parser = new Parser(stdin.byLine.join("\n").to!string);
    }
    else
    {
        try
        {
            parser = new Parser(read(filename).to!string);
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
    program.initialize(commands, envVars);

    debug
    {
        sw.stop();
        stderr.writeln(
            "Semantic analysis took ",
            sw.peek.total!"msecs", " miliseconds"
        );
    }

    // The scope:
    auto escopo = new Escopo(program);
    escopo["args"] = argumentsList;
    escopo["env"] = envVars;

    // The main command:
    // TODO: allow the user to select commands!
    Command subCommand;
    string subCommandName = null;

    auto subCommandPtr = ("default" in program.subCommands);
    if (subCommandPtr !is null)
    {
        subCommand = *subCommandPtr;
        subCommandName = "default";
    }
    else
    {
        foreach (name, sc; program.subCommands)
        {
            // Take the first one:
            subCommand = sc;
            subCommandName = name;
            break;
        }
    }
    if (subCommandName is null)
    {
        stderr.writeln("No command found!");
        // XXX: is it the correct code for this situation???
        return -1;
    }

    // The main Process:
    auto process = new Process("main");

    // Start!
    debug {sw.start();}

    auto context = Context(process, escopo);

    // Push all command line arguments into the stack:
    /*
    [commands/default]
    parameters {
        name { type string }
        times {
            type integer
            default 1
        }
    }
    ---
    $ til program.til Fulano
    Hello, Fulano!
    */
    foreach (arg; args[2..$].retro)
    {
        if (arg[0..2] == "--")
        {
            // TODO: add support to escaping, etc, etc.
            auto pair = arg[2..$].split("=");
            auto key = pair[0];
            auto value = pair[1..$].join("=");
            // TODO: check for "--help"

            auto p = new Parser(value);

            context.push(new SimpleList([
                new String(key),
                p.consumeItem()
            ]));
        }
        else
        {
            // TODO: cast into correct type!
            context.push(arg);
        }
    }

    debug {
        stderr.writeln("cli stack: ", context.process.stack);
    }
    // Run the main process:
    context = subCommand.run(subCommandName, context);

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
