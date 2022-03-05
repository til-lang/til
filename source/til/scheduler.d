module til.scheduler;

import core.thread.fiber;
import std.algorithm : filter;
import std.algorithm.searching : canFind;
import std.array : array;

import til.nodes;
import til.process;


class Scheduler
{
    Process[] processes = null;
    Process[] activeProcesses = null;

    this()
    {
        this([]);
    }
    this(Process process)
    {
        this([process]);
    }
    this(Process[] processes)
    {
        foreach(process; processes)
        {
            add(process);
        }
    }

    Pid add(Process process)
    {
        process.scheduler = this;
        processes ~= process;
        activeProcesses ~= process;
        return new Pid(process);
    }

    // TODO: clean up: remove finished processes from .processes.
    void reset()
    {
        processes = [];
        activeProcesses = [];
    }

    ExitCode run()
    {
        uint activeCounter;
        do
        {
            activeCounter = 0;
            Process[] finishedProcesses;

            foreach(process; activeProcesses)
            {
                if (process.state == Fiber.State.TERM)
                {
                    finishedProcesses ~= process;
                    continue;
                }
                activeCounter++;
                process.call();
            }

            // Clean up finished processes:
            if (finishedProcesses.length != 0)
            {
                activeProcesses = array(
                    activeProcesses.filter!(item => !finishedProcesses.canFind(item))
                );
            }
        } while (activeCounter > 0);

        /*
        In the end, check if any of the processes
        was terminated with failure:
        */
        foreach(process; processes)
        {
            if (process.context.exitCode == ExitCode.Failure)
            {
                return process.context.exitCode;
            }
        }
        return ExitCode.CommandSuccess;
    }

    Context[] failingContexts()
    {
        Context[] contexts;
        foreach(process; processes)
        {
            if (process.context.exitCode == ExitCode.Failure)
            {
                contexts ~= process.context;
            }
        }
        return contexts;
    }

    void yield()
    {
        if (processes.length == 1) return;
        Fiber.yield();
    }
}
