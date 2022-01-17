module til.exec;

import std.process;
import std.stdio : readln;
import std.string : stripRight;

import til.nodes;

debug
{
    import std.stdio;
}


class SystemProcess : ListItem
{
    ProcessPipes pipes;
    std.process.Pid pid;
    ListItem inputStream;
    string[] command;
    int returnCode = 0;
    bool isRunning;

    this(string[] command, ListItem inputStream)
    {
        debug {stderr.writeln("SystemProcess:", command, " ", inputStream);}
        this.command = command;
        this.inputStream = inputStream;

        if (inputStream is null)
        {
            pipes = pipeProcess(command, Redirect.stdout | Redirect.stderr);
        }
        else
        {
            pipes = pipeProcess(command, Redirect.all);
        }
        this.pid = pipes.pid;
        this.isRunning = true;
    }

    override string toString()
    {
        return this.command.join(" ");
    }

    override CommandContext next(CommandContext context)
    {
        if (!isRunning)
        {
            context.exitCode = ExitCode.Break;
            return context;
        }

        // For the output:
        string line = null;

        while (true)
        {
            // Send from inputStream, first:
            if (inputStream !is null)
            {
                debug {stderr.writeln(" inputStream:", inputStream);}
                auto inputContext = this.inputStream.next(context);
                if (inputContext.exitCode == ExitCode.Break)
                {
                    this.inputStream = null;
                    pipes.stdin.close();
                    continue;
                }
                else if (inputContext.exitCode != ExitCode.Continue)
                {
                    auto msg = "Error while reading from " ~ this.toString();
                    return context.error(msg, returnCode, "exec");
                }

                foreach (item; inputContext.items)
                {
                    string s = item.toString();
                    debug {stderr.writeln(" stdin:", s);}
                    pipes.stdin.writeln(s);
                    pipes.stdin.flush();
                }
                continue;
            }

            if (pipes.stdout.eof)
            {
                debug {stderr.writeln(" waiting for termination");}
                while (!pid.tryWait().terminated)
                {
                    context.yield();
                }

                debug {stderr.writeln(" terminated");}
                returnCode = pid.wait();
                isRunning = false;

                if (returnCode != 0)
                {
                    auto msg = "Error while executing " ~ this.toString();
                    return context.error(msg, returnCode, "exec", this);
                }
                else
                {
                    context.exitCode = ExitCode.Break;
                    return context;
                }
            }

            line = pipes.stdout.readln();
            debug {stderr.writeln(" line:", line);}

            if (line is null)
            {
                context.yield();
                continue;
            }
            else
            {
                break;
            }
        }

        context.push(line.stripRight("\n"));
        context.exitCode = ExitCode.Continue;
        return context;
    }

    override CommandContext extract(CommandContext context)
    {
        if (context.size == 0)
        {
            context.push(this);
            context.exitCode = ExitCode.CommandSuccess;
            return context;
        }

        string argument = context.pop!string();

        switch (argument)
        {
            case "is_running":
                context.push(this.isRunning);
                break;
            case "command":
                foreach (item; command)
                {
                    context.push(item);
                }
                break;
            case "pid":
                context.push(this.pid.processID());
                break;
            case "returncode":
                context.push(this.returnCode);
                break;
            case "error":
                context.push(new SystemProcessError(this));
                break;
            /*
            case "time":
                // For how long this process is running
                context.push(t);
                break;
            */
            default:
                break;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    }
}

class SystemProcessError : ListItem
{
    SystemProcess parent;
    ProcessPipes pipes;
    this(SystemProcess parent)
    {
        this.parent = parent;
        this.pipes = parent.pipes;
    }

    override string toString()
    {
        return "error stream for " ~ this.parent.toString();
    }

    override CommandContext next(CommandContext context)
    {
        // For the output:
        string line = null;

        while (true)
        {
            if (!pipes.stderr.eof)
            {
                line = pipes.stderr.readln();
                if (line is null)
                {
                    context.yield();
                    continue;
                }
                else
                {
                    break;
                }
            }
            else 
            {
                context.exitCode = ExitCode.Break;
                return context;
            }
        }

        context.push(line.stripRight("\n"));
        context.exitCode = ExitCode.Continue;
        return context;
    }
}
