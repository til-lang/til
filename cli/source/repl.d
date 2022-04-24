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

    auto process = new MainProcess(scheduler, null, escopo);

    int returnCode = 0;

    string command;

    Item* promptString = ("TIL_PROMPT" in envVars.values);
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

        scheduler.reset();

        // Run the main process:
        debug {stderr.writeln("Running main process..."); }
        auto context = process.run();

        // Reset the returnCode:
        returnCode = 0;

        // Find failed sub-processes:
        foreach (p; scheduler.processes)
        {
            returnCode = finishProcess(p, returnCode);
        }

        returnCode = finishProcess(process, returnCode);
        if (returnCode != 0) break;
    }
    clear_history();

    return returnCode;
}

int finishProcess(Process p, int returnCode)
{
    File output;

    // Search for errors:
    if (p.context.exitCode != ExitCode.Proceed)
    {
        stdout.writeln(p.description, ":");
        stderr.writeln(" exitCode ", p.context.exitCode);

        if (p.context.exitCode == ExitCode.Failure)
        {
            auto e = p.context.pop!Erro();
            stderr.writeln(e);
            returnCode = e.code;
        }
        output = stderr;
    }
    else
    {
        output = stdout;
    }

    // Print the stack:
    foreach (item; p.context.items)
    {
        output.writeln(" ", item);
    }

    return returnCode;
}
