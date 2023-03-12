import std.algorithm.searching : canFind;
import std.array : array, join, replace, split;
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

    auto filepath = args[1];
    string subCommandName = null;
    Command subCommand = null;

    if (filepath.canFind(":"))
    {
        auto parts = filepath.split(":");
        filepath = parts[0];
        subCommandName = parts[1..$].join(":");
    }

    try
    {
        parser = new Parser(read(filepath).to!string);
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

    if (subCommandName !is null)
    {
        auto subCommandPtr = (subCommandName in program.subCommands);
        if (subCommandPtr !is null)
        {
            subCommand = *subCommandPtr;
        }
    }
    else
    {
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
                // Take any one...
                // (hashmaps have no order!)
                subCommand = sc;
                subCommandName = name;
                break;
            }
        }
    }
    if (subCommand is null)
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
            // alfa-beta -> alfa_beta
            auto key = pair[0].replace("-", "_");

            if (key == "help")
            {
                return show_help_text(args, program);
            }

            // alfa-beta=1=2=3 -> alfa_beta = "1=2=3"
            auto value = pair[1..$].join("=");

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

int show_help_text(string[] args, Program program)
{
    stdout.writeln(program["name"].toString());
    stdout.writeln(program["description"].toString());
    stdout.writeln();

    auto programDict = cast(Dict)program;
    auto commands = cast(Dict)(programDict["commands"]);
    foreach (commandName; program.subCommands.keys)
    {
        auto command = cast(Dict)(commands[commandName]);

        if (auto descriptionPtr = ("description" in command.values))
        {
            auto description = *descriptionPtr;
            stdout.writeln(" ", commandName, "    ", description.toString());
        }
        else
        {
            stdout.writeln(" ", commandName);
        }

        auto parameters = cast(Dict)(command["parameters"]);
        foreach (parameter; parameters.order)
        {
            auto info = cast(Dict)(parameters[parameter]);
            auto type = info["type"];
            auto defaultPtr = ("default" in info.values);
            string defaultStr = "";
            if (defaultPtr !is null)
            {
                auto d = *defaultPtr;
                defaultStr = " = " ~ d.toString();
            }
            stdout.writeln("    ", parameter, " : ", type, defaultStr);
        }
        if (parameters.order.length == 0)
        {
            // stdout.writeln("    (no parameters)");
        }
    }

    return 0;
}
