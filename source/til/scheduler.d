module til.scheduler;

import core.thread.fiber;

import til.nodes;


debug
{
    import std.stdio;
}

class ProcessFiber : Fiber
{
    Process process = null;
    CommandContext context = null;

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
        fibers ~= new ProcessFiber(process);
        return new Pid(process);
    }

    ExitCode run()
    {
        uint activeCounter;
        do
        {
            activeCounter = 0;
            foreach(fiber; fibers)
            {
                if (fiber.state == Fiber.State.TERM)
                {
                    debug {
                        stderr.writeln(" FIBER TERM: ", fiber.process.index);
                    }
                    // That's the only safe place to determine
                    // if the process is actually
                    // in Finished state:
                    fiber.process.state = ProcessState.Finished;

                    // TODO: remove from fibers list!!!
                    continue;
                }
                activeCounter++;
                debug {stderr.writeln(" FIBER CALL: ", fiber.process.index);}
                fiber.call();
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

    CommandContext[] failingContexts()
    {
        CommandContext[] contexts;
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
        debug {stderr.writeln(" FIBER YIELD ");}
        Fiber.yield();
    }
}
