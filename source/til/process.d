module til.process;

import core.thread.fiber : Fiber;

import til.nodes;
import til.scheduler;
import til.stack;


class Process : Fiber
{
    Scheduler scheduler;
    SubProgram subprogram;

    // To store the execution results:
    Context context;

    // Stack:
    Stack stack;

    // Process identification:
    static uint counter = 0;
    string description;
    uint index;

    // I/O:
    Item input = null;
    Item output = null;

    this(Scheduler scheduler)
    {
        this(scheduler, null, null, description);
    }
    this(Scheduler scheduler, SubProgram subprogram, Escopo escopo=null, string description=null)
    {
        this.scheduler = scheduler;
        this.subprogram = subprogram;
        this.stack = new Stack();
        this.index = this.counter++;
        this.description = description;

        if (escopo is null)
        {
            escopo = new Escopo();
        }
        this.context = Context(this, escopo);
        super(&fiberRun);
    }

    // Scheduler-related things
    void yield()
    {
        this.scheduler.yield();
    }

    void fiberRun()
    {
        this.context = this.run();
    }

    // SubProgram execution:
    Context run()
    {
        return run(this.subprogram, this.context);
    }
    Context run(Context context)
    {
        return run(this.subprogram, context);
    }
    Context run(SubProgram subprogram, Context context)
    {
        foreach(index, pipeline; subprogram.pipelines)
        {
            context = pipeline.run(context);

            final switch(context.exitCode)
            {
                case ExitCode.Undefined:
                    throw new Exception(to!string(pipeline) ~ " returned Undefined");

                case ExitCode.Proceed:
                    // That is the expected result.
                    // So we just proceed.
                    break;

                // -----------------
                // Proc execution:
                case ExitCode.ReturnSuccess:
                    // ReturnSuccess should keep stopping
                    // processes until properly
                    // handled.
                    return context;

                case ExitCode.Failure:
                    /*
                    Error handling:
                    1- Call **local** procedure `on.error`, if
                       it exists and analyse ITS exitCode.
                    2- Or, if it doesn't exist, return `context`
                       as we would already do.
                    */
                    Command* errorHandlerPtr = ("on.error" in context.escopo.commands);
                    if (errorHandlerPtr !is null)
                    {
                        auto errorHandler = *errorHandlerPtr;
                        debug {
                            stderr.writeln("Calling on.error");
                            stderr.writeln(" context: ", context);
                            stderr.writeln(" ...");
                        }
                        context = errorHandler.run("on.error", context);
                        debug {stderr.writeln(" returned context:", context);}
                        /*
                        errorHandler can simply "rethrow"
                        the Error or even return a new
                        one. That's ok. We aren't
                        trying to do anything
                        much fancy, here.
                        */
                    }
                    /*
                    Wheter we called errorHandler or not,
                    we ARE going to exit the current
                    scope right now. The idea of
                    a errorHandler is NOT to
                    allow continuing in the
                    same scope.
                    */
                    return context;

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                case ExitCode.Skip:
                    return context;

                // -----------------
                // Pipeline execution:
                case ExitCode.CommandSuccess:
                    throw new Exception(
                        to!string(pipeline) ~ " returned CommandSuccess."
                        ~ " Expected a Proceed exit code."
                    );
            }
            // Each N pipelines we yield fiber/thread control:
            if ((index & 0x07) == 0x07) this.yield();
        }

        // Returns the context of the last expression:
        return context;
    }
}


class MainProcess : Process
{
    this(Scheduler scheduler, SubProgram subprogram, Escopo escopo=null)
    {
        super(scheduler, subprogram, escopo, "main");
    }

    override void yield()
    {
        // Give a run on the scheduler.
        this.scheduler.run();
    }

    override void fiberRun()
    {
        throw new Exception("MainProcess is not supposed to run as a Fiber");
    }

    override Context run()
    {
        context = super.run();

        // Wait until all processes die:
        uint activeCounter = 0;
        do
        {
            activeCounter = this.scheduler.run();
        }
        while (activeCounter != 0);

        return context;
    }
}
