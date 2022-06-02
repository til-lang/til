module til.nodes.simplelist;

import std.array : array;
import std.range : empty, front, popFront;

import til.nodes;


CommandsMap simpleListCommands;

class SimpleList : BaseList
{
    /*
       A SimpleList contains only ONE List inside it.
       Its primary use is for passing parameters,
       like `if ($x > 10) {...}`.
    */

    long currentItemIndex;

    this(Items items)
    {
        super();
        this.items = items;
        this.commands = simpleListCommands;
        this.type = ObjectType.SimpleList;
        this.typeName = "list";
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "(" ~ to!string(this.items
            .map!(x => to!string(x))
            .join(" ")) ~ ")";
    }

    override Context evaluate(Context context, bool force)
    {
        if (!force)
        {
            return this.evaluate(context);
        }
        else
        {
            return this.forceEvaluate(context);
        }
    }
    override Context evaluate(Context context)
    {
        return context.push(this);
    }
    Context forceEvaluate(Context context)
    {
        long listSize = 0;
        foreach(item; this.items.retro)
        {
            context = item.evaluate(context.next());
            listSize += context.size;
        }

        /*
        What resides in the stack, at the end, is not
        the items inside the original SimpleList,
        but a new SimpleList with its original
        items already evaluated. We are only
        using the stack as temporary space.
        */
        auto newList = new SimpleList(context.pop(listSize));
        context = context.next();
        context.push(newList);
        return context;
    }
    ExecList infixProgram()
    {
        string[] commandNames;
        Items arguments;

        foreach (index, item; items)
        {
            // 1 + 2 + 3 + 4 / 5 * 6
            // [+ 1 2]
            // [+ [+ 1 2] 3]
            // [+ [+ [+ 1 2] 3] 4]
            // Alternative:
            // [+ 1 2 3 4]
            // [/ [+ 1 2 3 4] 5]
            // [* [/ [+ 1 2 3 4] 5] 6]
            if (index % 2 == 0)
            {
                if (item.type == ObjectType.SimpleList)
                {
                    // Inner SimpleLists also become InfixPrograms:
                    arguments ~= (cast(SimpleList)item).infixProgram();
                }
                else
                {
                    arguments ~= item;
                }
            }
            else
            {
                commandNames ~= item.toString();
            }
        }

        string lastCommandName = null;
        auto argumentsIndex = 0;
        auto commandsIndex = 0;
        ExecList execList = null;

        while (argumentsIndex < arguments.length && commandsIndex < commandNames.length)
        {
            Items commandArgs = [arguments[argumentsIndex++]];
            string commandName = commandNames[commandsIndex++];

            while (argumentsIndex < arguments.length)
            {
                commandArgs ~= arguments[argumentsIndex++];
                if (commandsIndex < commandNames.length && commandNames[commandsIndex] == commandName)
                {
                    commandsIndex++;
                    continue;
                }
                else
                {
                    break;
                }
            }
            auto commandCalls = [
                new CommandCall(commandName, commandArgs)
            ];
            auto pipeline = new Pipeline(commandCalls);
            auto subprogram = new SubProgram([pipeline]);
            execList = new ExecList(subprogram);

            // This ExecList replaces the last seen argument:
            arguments[--argumentsIndex] = execList;
            // [0 1 2]
            //      ^
            // [0 [+ 0 1] 2]
            //       ^
        }

        if (execList is null)
        {
            if (arguments.length == 1)
            {
                auto argument = arguments[0];
                if (argument.type == ObjectType.SimpleList)
                {
                    return (cast(SimpleList)argument).infixProgram();
                }
                else
                {
                    /*
                    Example:
                        if (true)
                    Becomes:
                        if ([push true])
                    */
                    auto commandCalls = [new CommandCall("stack.push", arguments)];
                    auto pipeline = new Pipeline(commandCalls);
                    auto subprogram = new SubProgram([pipeline]);
                    return new ExecList(subprogram);
                }
            }
            throw new Exception("execList cannot be null!");
        }
        return execList;
    }
    Context runAsInfixProgram(Context context)
    {
        return this.infixProgram().evaluate(context);
    }
}
