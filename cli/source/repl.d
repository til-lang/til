module cli.repl;

import std.stdio;
import std.string : fromStringz, toStringz;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.process;
import til.scheduler;

import editline;


int repl(Dict envVars, SimpleList argumentsList)
{
    auto scheduler = new Scheduler();
    auto escopo = new Escopo();
    escopo["args"] = argumentsList;
    escopo["env"] = envVars;
    escopo.commands = commands;
    auto process = new Process(scheduler, null, escopo, "repl");

    string command;

    ListItem* promptString = ("TIL_PROMPT" in envVars.values);
    if (promptString !is null)
    {
        escopo["prompt"] = *promptString;
    }
    else
    {
        escopo["prompt"] = new String("> ");
    }

mainLoop:
    while (true)
    {
        auto prompt = escopo["prompt"][0].toString();

        while (true)
        {
            auto line = readline(prompt.toStringz());
            if (line is null)
            {
                break mainLoop;
            }
            command ~= to!string(line.fromStringz()) ~ "\n";
            if (command.length == 0)
            {
                continue;
            }
            auto parser = new Parser(command);
            try
            {
                process.subprogram = parser.consumeSubProgram();
            }
            catch (IncompleteInputException)
            {
                prompt = "... ";
                continue;
            }
            catch (Exception ex)
            {
                stdout.writeln("Exception: ", ex.msg);
                process.subprogram = null;
            }
            break;
        }

        if (command.length > 1)
        {
            add_history(command.toStringz());
        }
        command = "";

        if (process.subprogram is null)
        {
            continue;
        }

        debug {stderr.writeln("Running scheduler..."); }
        process.reset();
        scheduler.reset();
        scheduler.add(process);
        ExitCode exitCode = scheduler.run();

        File output;
        foreach (p; scheduler.processes)
        {
            if (p.context.exitCode != ExitCode.Proceed)
            {
                stdout.writeln(p.description, ":");
                stderr.writeln(" exitCode ", p.context.exitCode);
                output = stderr;
            }
            else
            {
                output = stdout;
            }

            foreach (item; p.context.items)
            {
                output.writeln(" ", item);
            }
        }
    }
    clear_history();

    return 0;
}
