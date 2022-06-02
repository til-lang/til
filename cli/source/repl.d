module cli.repl;

import std.stdio;
import std.string : fromStringz, toStringz;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.process;

import editline;


int repl(Dict envVars, SimpleList argumentsList)
{
    auto escopo = new Escopo();
    escopo["args"] = argumentsList;
    escopo["env"] = envVars;
    escopo.commands = commands;

    auto process = new Process("repl");

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

    SubProgram subprogram;

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
                subprogram = parser.consumeSubProgram();
            }
            catch (IncompleteInputException)
            {
                prompt = "... ";
                continue;
            }
            catch (Exception ex)
            {
                stdout.writeln("Exception: ", ex.msg);
                subprogram = null;
            }
            break;
        }

        if (command.length > 1)
        {
            add_history(command.toStringz());
        }
        command = "";

        if (subprogram is null)
        {
            continue;
        }

        // Run the main process:
        debug {stderr.writeln("Running main process..."); }
        auto context = process.run(subprogram, escopo);

        // Reset the returnCode:
        returnCode = finishProcess(process, context);
        if (returnCode != 0) break;
    }
    clear_history();

    return returnCode;
}

int finishProcess(Process p, Context context)
{
    int returnCode = p.unixExitStatus(context);

    // Search for errors:
    if (context.exitCode == ExitCode.Failure)
    {
        // Log the error:
        auto e = context.pop!Erro();
        stderr.writeln(e);
    }
    else
    {
        // Return the stack values:
        foreach (item; context.items)
        {
            stdout.writeln(" ", item);
        }
    }

    return returnCode;
}
