module til.scheduler;

import core.thread.fiber;
import std.algorithm : filter;
import std.algorithm.searching : canFind;
import std.array : array;

import til.nodes;


class ProcessFiber : Fiber
{
    Process process = null;
    Context context = null;

    this(Process process)
    {
        this.process = process;
        super(&run);
    }
    private void run()
    {
        context = process.run();
    }
}


class Scheduler
{
    ProcessFiber[] fibers = null;
    ProcessFiber[] activeFibers = null;

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
        auto processFiber = new ProcessFiber(process);
        this.fibers ~= processFiber;
        this.activeFibers ~= processFiber;
        return new Pid(processFiber);
    }

    ExitCode run()
    {
        uint activeCounter;
        do
        {
            activeCounter = 0;
            ProcessFiber[] finishedFibers;

            foreach(fiber; activeFibers)
            {
                if (fiber.state == Fiber.State.TERM)
                {
                    fiber.process.state = ProcessState.Finished;
                    finishedFibers ~= fiber;
                    continue;
                }
                activeCounter++;
                fiber.call();
            }

            // Clean up finished fibers:
            if (finishedFibers.length != 0)
            {
                activeFibers = array(
                    activeFibers.filter!(item => !finishedFibers.canFind(item))
                );
            }
        } while (activeCounter > 0);

        /*
        In the end, check if any of the processes
        was terminated with failure:
        */
        foreach(fiber; fibers)
        {
            if (fiber.context.exitCode == ExitCode.Failure)
            {
                return fiber.context.exitCode;
            }
        }
        return ExitCode.CommandSuccess;
    }

    Context[] failingContexts()
    {
        Context[] contexts;
        foreach(fiber; fibers)
        {
            if (fiber.context.exitCode == ExitCode.Failure)
            {
                contexts ~= fiber.context;
            }
        }
        return contexts;
    }

    void yield()
    {
        if (fibers.length == 1) return;
        Fiber.yield();
    }
}
