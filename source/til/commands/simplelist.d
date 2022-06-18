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
                this.type = ObjectType.Range;
                this.typeName = "list_range";
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
        return context.push(new ItemsRange(list.items));
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
                this.type = ObjectType.Range;
                this.typeName = "list_range_enumerate";
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
        return context.push(new ItemsRangeEnumerate(list.items));
    });
    simpleListCommands["extract"] = new Command((string path, Context context)
    {
        SimpleList l = context.pop!SimpleList();

        if (context.size == 0) return context.push(l);

        // start:
        long s = context.pop().toInt();
        if (s < 0)
        {
            s = l.items.length + s;
        }
        size_t start = cast(size_t)s;

        if (context.size == 0)
        {
            return context.push(l.items[start]);
        }

        // end:
        long e = context.pop().toInt();
        if (e < 0)
        {
            e = l.items.length + e;
        }
        size_t end = cast(size_t)e;

        // slice:
        return context.push(new SimpleList(l.items[start..end]));
    });
    simpleListCommands["eval"] = new Command((string path, Context context)
    {
        auto list = context.pop();

        // Force evaluation:
        auto newContext = list.evaluate(context, true);

        return newContext;
    });
    simpleListCommands["infix"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();
        context = list.runAsInfixProgram(context);
        return context;
    });
    simpleListCommands["expand"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();

        foreach (item; list.items.retro)
        {
            context.push(item);
        }

        return context;
    });
    simpleListCommands["push"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();

        Items items = context.items;
        list.items ~= items;

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

        return context;
    });
    simpleListCommands["sort"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();

        class Comparator
        {
            Item item;
            Context context;
            this(Context context, Item item)
            {
                this.context = context;
                this.item = item;
            }

            override int opCmp(Object o)
            {
                Comparator other = cast(Comparator)o;

                context.push(other.item);
                context = item.runCommand("<", context);
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
        return context.push(new SimpleList(sorted));
    });
    simpleListCommands["reverse"] = new Command((string path, Context context)
    {
        SimpleList list = context.pop!SimpleList();
        Items reversed = list.items.retro.array;
        return context.push(new SimpleList(reversed));
    });
    simpleListCommands["contains"] = new Command((string path, Context context)
    {
        if (context.size != 2)
        {
            auto msg = "`send` expects two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        SimpleList list = context.pop!SimpleList();
        Item item = context.pop();

        return context.push(
            list.items
                .map!(x => to!string(x))
                .canFind(to!string(item))
        );
    });
    simpleListCommands["length"] = new Command((string path, Context context)
    {
        auto l = context.pop!SimpleList();
        return context.push(l.items.length);
    });
    simpleListCommands["eq"] = new Command((string path, Context context)
    {
        SimpleList rhs = context.pop!SimpleList();

        Item other = context.pop();
        if (other.type != ObjectType.SimpleList)
        {
            return context.push(false);
        }
        SimpleList lhs = cast(SimpleList)other;

        // TODO, maybe: compare item by item instead of relying on toString
        if (lhs.items.length != rhs.items.length)
        {
            return context.push(false);
        }
        return context.push(lhs.toString() == rhs.toString());
    });
    simpleListCommands["=="] = simpleListCommands["eq"];

    simpleListCommands["neq"] = new Command((string path, Context context)
    {
        SimpleList rhs = context.pop!SimpleList();

        Item other = context.pop();
        if (other.type != ObjectType.SimpleList)
        {
            return context.push(true);
        }
        SimpleList lhs = cast(SimpleList)other;

        // TODO, maybe: compare item by item instead of relying on toString
        if (lhs.items.length != rhs.items.length)
        {
            return context.push(true);
        }
        return context.push(lhs.toString() != rhs.toString());
    });
    simpleListCommands["!="] = simpleListCommands["neq"];
}
