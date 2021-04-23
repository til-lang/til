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
    this(Process[] processes)
    {
        foreach(process; processes)
        {
            add(process);
        }
    }

    void add(Process process)
    {
        process.scheduler = this;
        fibers ~= new ProcessFiber(process);
    }

    void run()
    {
        uint activeCounter;
        do
        {
            activeCounter = 0;
            foreach(fiber; fibers)
            {
                debug {stderr.writeln(" FIBER CALL ");}
                if (fiber.state == Fiber.State.TERM)
                {
                    continue;
                }
                activeCounter++;
                fiber.call();
            }
        } while (activeCounter > 0);
    }

    void yield()
    {
        debug {stderr.writeln(" FIBER YIELD ");}
        Fiber.yield();
    }
}
