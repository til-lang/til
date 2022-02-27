module til.commands.simplelist;

import std.algorithm : map, sort;
import std.algorithm.searching : canFind;
import std.array;

import til.nodes;
import til.commands;


// Commands:
static this()
{
    commands["list"] = new Command((string path, Context context)
    {
        /*
        set l [list 1 2 3 4]
        # l = (1 2 3 4)
        */
        context.exitCode = ExitCode.CommandSuccess;
        return context.push(new SimpleList(context.items));
    });
    simpleListCommands["set"] = new Command((string path, Context context)
    {
        string[] names;

        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` must receive at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto l1 = context.pop!SimpleList();
        auto l2 = context.pop!SimpleList();

        if (l2.type != ObjectType.SimpleList)
        {
            auto msg = "You can only use `" ~ path ~ "` with two SimpleLists";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        names = l1.items.map!(x => to!string(x)).array;

        Items values;
        context = l2.forceEvaluate(context);
        values = l2.items;

        if (values.length < names.length)
        {
            auto msg = "Insuficient number of items in the second list";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        string lastName;
        foreach(name; names)
        {
            auto nextValue = values.front;
            if (!values.empty) values.popFront();

            context.escopo[name] = nextValue;
            lastName = name;
        }
        while(!values.empty)
        {
            // Everything else goes to the last name:
            context.escopo[lastName] = context.escopo[lastName] ~ values.front;
            values.popFront();
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    simpleListCommands["as"] = simpleListCommands["set"];

    simpleListCommands["range"] = new Command((string path, Context context)
    {
        /*
        range (1 2 3 4 5)
        */
        class ItemsRange : Item
        {
            Items list;
            int currentIndex = 0;
            ulong _length;

            this(Items list)
            {
                this.list = list;
                this._length = list.length;
            }
            override string toString()
            {
                return "ItemsRange";
            }
            override Context next(Context context)
            {
                if (this.currentIndex >= this._length)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    auto item = this.list[this.currentIndex++];
                    context.push(item);
                    context.exitCode = ExitCode.Continue;
                }
                return context;
            }
        }

        SimpleList list = context.pop!SimpleList();
        context.push(new ItemsRange(list.items));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    simpleListCommands["range.enumerate"] = new Command((string path, Context context)
    {
        /*
        range.enumerate (1 2 3 4 5)
        -> 0 1 , 1 2 , 2 3 , 3 4 , 4 5
        */
        // TODO: make ItemsRange from "range" accessible here.
        class ItemsRangeEnumerate : Item
        {
            Items list;
            int currentIndex = 0;
            ulong _length;

            this(Items list)
            {
                this.list = list;
                this._length = list.length;
            }
            override string toString()
            {
                return "ItemsRangeEnumerate";
            }
            override Context next(Context context)
            {
                if (this.currentIndex >= this._length)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    auto item = this.list[this.currentIndex];
                    context.push(item);
                    context.push(currentIndex);
                    this.currentIndex++;
                    context.exitCode = ExitCode.Continue;
                }
                return context;
            }
        }

        SimpleList list = context.pop!SimpleList();
        context.push(new ItemsRangeEnumerate(list.items));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    simpleListCommands["extract"] = new Command((string path, Context context)
    {
        SimpleList l = context.pop!SimpleList();

        if (context.size == 0) return context.push(l);

        // start:
        auto start = context.pop().toInt();

        if (start < 0)
        {
            start = l.items.length + start;
        }

        // end:
        auto end = start + 1;
        if (context.size)
        {
            end = context.pop().toInt();
            if (end < 0)
            {
                end = l.items.length + end;
            }
        }

        // slice:
        context.push(new SimpleList(l.items[start..end]));

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    simpleListCommands["eval"] = new Command((string path, Context context)
    {
        auto list = context.pop();

        // Force evaluation:
        auto newContext = list.evaluate(context, true);

        newContext.exitCode = ExitCode.CommandSuccess;
        return newContext;
    });
    simpleListCommands["expand"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();

        foreach (item; list.items.retro)
        {
            context.push(item);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    simpleListCommands["push"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();

        Items items = context.items;
        list.items ~= items;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    simpleListCommands["pop"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();

        if (list.items.length == 0)
        {
            auto msg = "Cannot pop: the list is empty";
            return context.error(msg, ErrorCode.Empty, "");
        }

        auto lastItem = list.items[$-1];
        context.push(lastItem);
        list.items.popBack;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    simpleListCommands["sort"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();

        class Comparator
        {
            ListItem item;
            Context context;
            this(Context context, ListItem item)
            {
                this.context = context;
                this.item = item;
            }

            override int opCmp(Object o)
            {
                Comparator other = cast(Comparator)o;

                context.push(other.item);
                context.push(">");
                context = item.operate(context);
                auto result = cast(BooleanAtom)context.pop();

                if (result.value)
                {
                    return -1;
                }
                else
                {
                    return 0;
                }
            }
        }

        Comparator[] comparators = list.items.map!(x => new Comparator(context, x)).array;
        Items sorted = comparators.sort.map!(x => x.item).array;
        context.push(new SimpleList(sorted));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    simpleListCommands["reverse"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();
        Items reversed = list.items.retro.array;
        context.push(new SimpleList(reversed));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    simpleListCommands["contains"] = new Command((string path, Context context)
    {
        if (context.size != 2)
        {
            auto msg = "`send` expects two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        SimpleList list = context.pop!SimpleList();
        ListItem item = context.pop();

        context.exitCode = ExitCode.CommandSuccess;
        return context.push(
            list.items
                .map!(x => to!string(x))
                .canFind(to!string(item))
        );
    });
    simpleListCommands["length"] = new Command((string path, Context context)
    {
        auto l = context.pop!SimpleList();
        context.exitCode = ExitCode.CommandSuccess;
        return context.push(l.items.length);
    });
    simpleListCommands["operate"] = new Command((string path, Context context)
    {
        SimpleList rhs = context.pop!SimpleList();
        string op = context.pop!string();

        Item other = context.pop();
        if (other.type != ObjectType.SimpleList)
        {
            auto msg = "Cannot operate " ~ to!string(other.type) ~ " and SimpleList";
            return context.error(msg, ErrorCode.NotImplemented, "");
        }
        SimpleList lhs = cast(SimpleList)other;

        if (op == "==")
        {
            // TODO, maybe: compare item by item instead of relying on toString
            if (lhs.items.length != rhs.items.length)
            {
                return context.push(false);
            }
            return context.push(lhs.toString() == rhs.toString());
        }

        auto msg = "Operator " ~ op ~ " not implemented for SimpleList";
        return context.error(msg, ErrorCode.NotImplemented, "");
    });
}
